# SQL Customer Segmentation Using K-Means Clustering

This project applies customer segmentation techniques on Amazon purchase data using SQL and K-Means clustering. It is designed to help businesses better understand customer behavior using RFM (Recency, Frequency, Monetary) analysis and derive actionable insights via clustering and visualization.

## 🚀 Project Objective

This project aims to segment customers based on their purchasing behavior using a combination of:

- **SQL (BigQuery)** for data extraction, preprocessing, and RFM scoring  
- **Quantile-based RFM** to avoid hard-coded thresholds and adapt to the distribution of real-world data  
- **K-Means Clustering** to group customers into meaningful segments based on their RFM scores  
- **Tableau** for building an interactive RFM dashboard that visualizes the segments

## 🧠 Why Quantile-Based RFM?

Rather than relying on static thresholds (e.g., "Recency > 30 days = inactive"), we use **quantiles** to dynamically categorize each customer’s Recency, Frequency, and Monetary values. This ensures:

- Fair segmentation based on data distribution  
- Adaptability to different datasets  
- More statistically balanced clusters  
- Eliminates manual bias and hardcoded cutoffs

## 🛠️ Why K‑Means Clustering?

 **Beyond Rules: While RFM rules assign segments by fixed cutoffs, K‑Means identifies data‑driven groupings, capturing nuanced patterns in recency, frequency, and spend simultaneously.

 **Scalability: K‑Means handles large volumes of customer records efficiently in BigQuery ML.

 **Interpretability: Cluster centroids provide clear profiles (avg RFM scores) to label each group meaningfully.

 **Flexibility: You can adjust num_clusters (chosen as 5) based on business needs and silhouette or elbow analysis.

## 📈 Tableau Dashboard

The final dashboard includes:

 - **KPI Cards: Total unique customers, average purchase frequency, recency (days since last purchase), and monetary value.

 - **Scatter Plot: Customer recency vs. frequency, sized by total spend and colored by cluster.

 - **Bar Chart: Percentage of customers in each RFM segment (Champions, Loyal Customers, Potential Loyalists, At Risk, Others).

## 🧰 Tools & Technologies

- **SQL (Google BigQuery)** – RFM scoring & pipeline creation  
- **SQL** – Sampling and data preprocessing ( USING BIG QUERY) 
- **K-Means Clustering** – Customer segmentation  ( USING BIG QUERY) 
- **Tableau** – Visualizing RFM segments and KPIs  
- **Git / GitHub** – Version control and collaboration

## 📈 Key Observations (dashboard insights)

 - Customer Distribution

 - Champions (~16.5%) and Loyal Customers (~18.8%) represent your most engaged buyers.

 - Potential Loyalists (~35.9%) form the largest group—underscoring an opportunity to nurture these moderately engaged customers into higher tiers.

 - At Risk & Others make up under 30% combined, indicating a focused re‑engagement target.

 - Recency vs. Frequency Trade‑off

 - High‑frequency customers cluster at low recency values (left side of scatter).

 - Some high‑spend customers (large circles) have moderate frequency—ideal targets for loyalty programs.

 - Monetary Highlights

 - Circle sizes reveal a small subset of very high spenders (top‑right in scatter).

 - These high‑value outliers are potential brand advocates or VIP members.

 - Actionable Segmentation

 - Champions: Reward with VIP access and premium promotions.

 - Loyal Customers: Upsell and cross‑sell with tailored bundles.

 - Potential Loyalists: Introduce loyalty incentives and personalized communications.

 - At Risk / Others: Run win‑back campaigns and discount offers to re‑engage.

## 📁 Folder Structure

SQL-CustomerSegmentation/
├── Data/
│ ├── amazon_purchase_sample.csv
│ └── amazon_survey_sample.csv
├── SQL-BigQueryScripts/
│ └── amazon_rfm_pipeline.sql
├── Tableau/
│ └── Amazon_RFM_Dashboard.png
