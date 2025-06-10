
-- ========================================================
-- File: amazon_rfm_pipeline.sql
-- Purpose: End-to-end SQL pipeline for Amazon RFM Analysis
-- Author: [Vighnesh B]
-- ========================================================


-- Merge Purchase Data
-- Description: Union all tables into one base table
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.all_purchases` AS
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.amazon-purchases-1`
UNION ALL
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.amazon-purchases-2`
UNION ALL
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.amazon-purchases-3`
UNION ALL
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.amazon-purchases-4`;

-- Merge Survey Data
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.all_survey` AS
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.survey-1`
UNION ALL
SELECT * FROM `celestial-feat-462008-s7.Customer_Segmentation.survey-2`;

-- Clean & Prepare Data
-- Description: Remove nulls, outliers, and invalid transactions
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.cleaned_purchases` AS
SELECT
  Survey_ResponseID,
  Order_Date AS purchase_date,
  Purchase_Price_Per_Unit * Quantity AS amount
FROM `celestial-feat-462008-s7.Customer_Segmentation.all_purchases`
WHERE Survey_ResponseID IS NOT NULL
  AND Purchase_Price_Per_Unit IS NOT NULL;

-- RFM Feature Engineering
-- Description: Generate Recency, Frequency, Monetary scores
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_features` AS
WITH reference_date AS (
  SELECT DATE('2024-08-17') AS today
)
SELECT
  cp.Survey_ResponseID,
  DATE_DIFF((SELECT today FROM reference_date), MAX(cp.purchase_date), DAY) AS recency,
  COUNT(*) AS frequency,
  SUM(cp.amount) AS monetary
FROM `celestial-feat-462008-s7.Customer_Segmentation.cleaned_purchases` cp
GROUP BY cp.Survey_ResponseID;

-- Quantile-Based RFM Scoring and Segmentation
-- Description: Assign segment scores based on quantiles
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_segmented` AS
WITH rfm_vals AS (
  SELECT recency, frequency, monetary
  FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_features`
),
rfm_quintiles AS (
  SELECT
    ARRAY_REVERSE(APPROX_QUANTILES(recency, 5)) AS recency_q,
    APPROX_QUANTILES(frequency, 5)         AS freq_q,
    APPROX_QUANTILES(monetary, 5)          AS mon_q
  FROM rfm_vals
),
rfm_scored AS (
  SELECT
    f.Survey_ResponseID,
    CASE
      WHEN recency <= recency_q[OFFSET(0)] THEN 5
      WHEN recency <= recency_q[OFFSET(1)] THEN 4
      WHEN recency <= recency_q[OFFSET(2)] THEN 3
      WHEN recency <= recency_q[OFFSET(3)] THEN 2
      ELSE 1
    END AS recency_score,
    CASE
      WHEN frequency <= freq_q[OFFSET(1)] THEN 1
      WHEN frequency <= freq_q[OFFSET(2)] THEN 2
      WHEN frequency <= freq_q[OFFSET(3)] THEN 3
      WHEN frequency <= freq_q[OFFSET(4)] THEN 4
      ELSE 5
    END AS frequency_score,
    CASE
      WHEN monetary <= mon_q[OFFSET(1)] THEN 1
      WHEN monetary <= mon_q[OFFSET(2)] THEN 2
      WHEN monetary <= mon_q[OFFSET(3)] THEN 3
      WHEN monetary <= mon_q[OFFSET(4)] THEN 4
      ELSE 5
    END AS monetary_score,
    f.recency,
    f.frequency,
    f.monetary
  FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_features` f
  CROSS JOIN rfm_quintiles
),
rfm_segments AS (
  SELECT
    Survey_ResponseID,
    recency_score,
    frequency_score,
    monetary_score,
    recency,
    frequency,
    monetary,
    (recency_score + frequency_score + monetary_score) AS rfm_total,
    CASE
      WHEN recency_score >= 4
        AND frequency_score >= 4
        AND monetary_score >= 4 THEN 'Champions'
      WHEN (recency_score + frequency_score + monetary_score) BETWEEN 10 AND 11 THEN 'Loyal Customers'
      WHEN (recency_score + frequency_score + monetary_score) BETWEEN 7 AND 9 THEN 'Potential Loyalist'
      WHEN recency_score <= 2 THEN 'At Risk'
      ELSE 'Others'
    END AS segment
  FROM rfm_scored
)
SELECT * FROM rfm_segments;

-- Normalize for K-Means Clustering
-- Description: Use BigQuery ML to segment customers
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_normalized` AS
SELECT
  Survey_ResponseID,
  (recency - AVG(recency) OVER()) / STDDEV(recency) OVER()     AS recency_scaled,
  (frequency - AVG(frequency) OVER()) / STDDEV(frequency) OVER() AS frequency_scaled,
  (monetary - AVG(monetary) OVER()) / STDDEV(monetary) OVER()   AS monetary_scaled
FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_features`;

-- K-Means Clustering using BigQuery ML
CREATE OR REPLACE MODEL `celestial-feat-462008-s7.Customer_Segmentation.kmeans_rfm_model`
OPTIONS(
  model_type           = 'kmeans',
  num_clusters         = 4,
  standardize_features = FALSE
) AS
SELECT
  recency_scaled,
  frequency_scaled,
  monetary_scaled
FROM `celestial-feat-462008-s7.Customer_Segmentation.rfm_normalized`;

-- Assign Cluster Labels
CREATE OR REPLACE TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_clusters` AS
SELECT
  p.Survey_ResponseID,
  p.centroid_id AS cluster,
  f.recency,
  f.frequency,
  f.monetary
FROM ML.PREDICT(
      MODEL `celestial-feat-462008-s7.Customer_Segmentation.kmeans_rfm_model`,
      TABLE `celestial-feat-462008-s7.Customer_Segmentation.rfm_normalized`
     ) p
JOIN `celestial-feat-462008-s7.Customer_Segmentation.rfm_features` f
  ON p.Survey_ResponseID = f.Survey_ResponseID;
