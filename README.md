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

## 📈 Tableau Dashboard

The final dashboard includes:

- **Cluster Distribution Bar Chart** to show customer counts in each segment  
- **RFM Score Visualizations** using box plots and histograms  
- **Segment Summary** with filters to analyze customer behavior across segments dynamically

## 🧰 Tools & Technologies

- **SQL (Google BigQuery)** – RFM scoring & pipeline creation  
- **SQL** – Sampling and data preprocessing ( USING BIG QUERY) 
- **K-Means Clustering** – Customer segmentation  ( USING BIG QUERY) 
- **Tableau** – Visualizing RFM segments and KPIs  
- **Git / GitHub** – Version control and collaboration  

## 📁 Folder Structure

SQL-CustomerSegmentation/
├── Data/
│ ├── amazon_purchase_sample.csv
│ └── amazon_survey_sample.csv
├── SQL-BigQueryScripts/
│ └── amazon_rfm_pipeline.sql
├── Tableau/
│ └── Amazon_RFM_Dashboard.twbx
