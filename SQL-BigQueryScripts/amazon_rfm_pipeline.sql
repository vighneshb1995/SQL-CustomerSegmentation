-- RFM & K-Means Pipeline 
-- Author: Vighnesh B

-- 1. Merge Purchase Data( Since I am performing in BigQuery console Free ver-- )
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.all_purchases` AS
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.amazon-purchases-1`
UNION ALL
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.amazon-purchases-2`
UNION ALL
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.amazon-purchases-3`
UNION ALL
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.amazon-purchases-4`;

-- 2. Merge Survey Data( Since I am performing in BigQuery console Free ver-- )
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.all_survey` AS
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.survey-1`
UNION ALL
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.survey-2`;

-- 3. Clean & Prepare Data
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.cleaned_purchases` AS
SELECT
  cp.Survey_ResponseID,
  cp.Order_Date AS purchase_date,
  SAFE_CAST(cp.Purchase_Price_Per_Unit AS FLOAT64) * SAFE_CAST(cp.Quantity AS INT64) AS amount
FROM `celestial-feat-462008-s7.Customer_Segmentation.all_purchases` cp
WHERE cp.Survey_ResponseID IS NOT NULL
  AND cp.Purchase_Price_Per_Unit IS NOT NULL;

-- 4. RFM Feature Engineering
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_features` AS
WITH reference_date AS (
  SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AS today
)
SELECT
  f.Survey_ResponseID,
  DATE_DIFF((SELECT today FROM reference_date), MAX(f.purchase_date), DAY) AS recency,
  COUNT(*) AS frequency,
  SUM(f.amount) AS monetary
FROM `celestial-feat-462008-s7.Customer_Segmentation.cleaned_purchases` f
GROUP BY f.Survey_ResponseID;

-- 5. Quantile-Based RFM Scoring
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_scored` AS
WITH vals AS (
  SELECT recency, frequency, monetary FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_features`
),
quintiles AS (
  SELECT
    ARRAY_REVERSE(APPROX_QUANTILES(recency,5)) AS r_q,
    APPROX_QUANTILES(frequency,5)         AS f_q,
    APPROX_QUANTILES(monetary,5)          AS m_q
  FROM vals
)
SELECT
  r.Survey_ResponseID,
  CASE WHEN r.recency <= quintiles.r_q[OFFSET(0)] THEN 5
       WHEN r.recency <= quintiles.r_q[OFFSET(1)] THEN 4
       WHEN r.recency <= quintiles.r_q[OFFSET(2)] THEN 3
       WHEN r.recency <= quintiles.r_q[OFFSET(3)] THEN 2 ELSE 1 END AS recency_score,
  CASE WHEN r.frequency <= quintiles.f_q[OFFSET(1)] THEN 1
       WHEN r.frequency <= quintiles.f_q[OFFSET(2)] THEN 2
       WHEN r.frequency <= quintiles.f_q[OFFSET(3)] THEN 3
       WHEN r.frequency <= quintiles.f_q[OFFSET(4)] THEN 4 ELSE 5 END AS frequency_score,
  CASE WHEN r.monetary <= quintiles.m_q[OFFSET(1)] THEN 1
       WHEN r.monetary <= quintiles.m_q[OFFSET(2)] THEN 2
       WHEN r.monetary <= quintiles.m_q[OFFSET(3)] THEN 3
       WHEN r.monetary <= quintiles.m_q[OFFSET(4)] THEN 4 ELSE 5 END AS monetary_score,
  r.recency,
  r.frequency,
  r.monetary
FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_features` r
CROSS JOIN quintiles;

-- 6. RFM Segmentation with Strict Hierarchy
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_segments` AS
SELECT
  s.Survey_ResponseID,
  s.recency_score,
  s.frequency_score,
  s.monetary_score,
  (s.recency_score + s.frequency_score + s.monetary_score) AS rfm_total,
  CASE
    WHEN s.recency_score = 5 AND s.frequency_score = 5 AND s.monetary_score = 5 THEN 'Champions'
    WHEN s.recency_score >= 4 AND s.frequency_score >= 4 AND s.monetary_score >= 4 THEN 'Loyal Customers'
    WHEN (s.recency_score + s.frequency_score + s.monetary_score) BETWEEN 7 AND 9 THEN 'Potential Loyalist'
    WHEN s.recency_score <= 2 THEN 'At Risk'
    ELSE 'Others'
  END AS segment
FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_scored` s;

-- 7. Normalize for Clustering
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_normalized` AS
SELECT
  nf.Survey_ResponseID,
  (nf.recency - AVG(nf.recency) OVER()) / STDDEV(nf.recency) OVER()     AS recency_scaled,
  (nf.frequency - AVG(nf.frequency) OVER()) / STDDEV(nf.frequency) OVER() AS frequency_scaled,
  (nf.monetary - AVG(nf.monetary) OVER()) / STDDEV(nf.monetary) OVER()   AS monetary_scaled
FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_features` nf;

-- Silhouette Analysis 
-- Exported a sample of your 5-cluster assignments into Python, computed silhouette scores, and saw the highest average silhouette coefficient at k=5, indicating better-separated clusters.

-- 8. K-Means Clustering (final k = 5)
CREATE OR REPLACE MODEL `celestial-feat-462008-s7.Customer_Segmentation.kmeans_rfm_model`
OPTIONS(
  model_type = 'kmeans',
  num_clusters = 5,
  standardize_features = FALSE
) AS
SELECT recency_scaled, frequency_scaled, monetary_scaled
FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_normalized`;

-- 9. Assign Cluster Labels
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_clusters` AS
SELECT
  p.Survey_ResponseID,
  p.centroid_id AS cluster,
  f.recency,
  f.frequency,
  f.monetary,
  seg.segment
FROM ML.PREDICT(
       MODEL `celestial-feat-462008-s7.Customer_Segmentation.kmeans_rfm_model`,
       TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_normalized`
     ) p
JOIN `celestial-feat-462008-s7.Customer_Segmentation.rfm_features` f
  ON p.Survey_ResponseID = f.Survey_ResponseID
JOIN `celestial-feat-462008-s7.Customer_Segmentation.rfm_segments` seg
  ON p.Survey_ResponseID = seg.Survey_ResponseID;

-- 10. Cluster Profiles Summary
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.cluster_profiles` AS
SELECT
  cluster,
  COUNT(*) AS customer_count,
  ROUND(AVG(recency),1) AS avg_recency,
  ROUND(AVG(frequency),1) AS avg_frequency,
  ROUND(AVG(monetary),2) AS avg_monetary,
  ARRAY_TO_STRING(ARRAY_AGG(DISTINCT segment), ', ') AS rfm_segment_label
FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_clusters`
GROUP BY cluster;

-- End of Pipeline
