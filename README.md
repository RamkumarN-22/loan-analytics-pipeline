# 💳 Loan Analytics Pipeline — End-to-End Data Project

### 🚀 SQL → Python (ETL, ML) → SQL (Write-back) → Power BI (Reporting)

This project demonstrates a **full-stack data analytics pipeline** for banking loan analysis — from raw SQL data modeling to Python-based machine learning and Power BI dashboards for business insights.  
It’s designed as an **interview-ready, reproducible portfolio project** that mirrors real-world financial analytics workflows.

---

## 🧠 Project Summary

**Objective:**  
To predict loan approval likelihood using customer and repayment data, integrating all stages of a modern analytics workflow:
1. **SQL Layer:** Create clean and consistent analytical views (`vw_CleanLoans`).
2. **Python Layer:** Perform ETL, feature engineering, model training, and write predictions back to SQL.
3. **Visualization Layer:** Build Power BI dashboards to monitor portfolio risk, model outcomes, and business KPIs.

**Outcome:**  
A complete, auditable pipeline that demonstrates:
- SQL data engineering  
- Python machine learning with scikit-learn  
- Power BI analytics storytelling  
- Reproducibility and data governance (ModelVersion, ModelRunDate)

---

## 🧩 Tech Stack

| Layer | Tools / Tech |
|-------|---------------|
| **Database** | SQL Server (T-SQL), Views, Constraints, Joins |
| **Python** | Pandas, SQLAlchemy, PyODBC, Scikit-Learn, Joblib |
| **Visualization** | Power BI (DAX, visuals, conditional formatting) |
| **Version Control** | Git, GitHub |
| **Optional** | SQLite (for local testing) |

---

## 🏗️ Architecture Overview
    +----------------+
    |  SQL Database  |
    | (Customers,    |
    |  Applications, |
    |  Repayments)   |
    +--------+-------+
             |
             |  vw_CleanLoans
             v
    +--------+-------+
    |   Python ETL   |
    | (train_and_    |
    | predict.ipynb) |
    +--------+-------+
             |
             | LoanPredictions
             v
    +--------+-------+
    |   Power BI     |
    | (Loan Report)  |
    +----------------+


---

## 📁 Repository Structure

loan-pipeline/

├─ sql/
│ ├─ loan_analytics.sql

├─ notebooks/
│ └─ train_and_predict.ipynb

├─ artifacts/
│ ├─ rf_model_v1.0.joblib
│ ├─ scaler_v1.0.joblib
│ └─ feature_importances_v1.0.csv

├─ powerbi/
│ ├─ screenshots/
│ └─ LoanPipeline_Report.pbix

├─ demo_pipeline.py
└─ README.md

---

## 🧮 Data Model Summary

**Tables created:**
- `Customers` — demographics and financial profile  
- `Applications` — loan applications  
- `Repayments` — payment history  

**Analytical View:**
`vw_CleanLoans` combines all relevant information and adds engineered features:
- `LoanToIncome` = LoanAmount / Income  
- `MissedPaymentsCount` = number of missed repayments per application  
- `LastPaymentDate` = recency feature  

**Predictions Table:**
`LoanPredictions` holds output from ML model:
| Column | Description |
|---------|-------------|
| ApplicationID | Loan application identifier |
| Pred_Prob | Predicted probability of approval |
| Pred_Label | Binary predicted outcome |
| ModelVersion | Model version tag |
| ModelRunDate | Timestamp of scoring run |

---

## ⚙️ How to Run

1. **Run SQL scripts** (create tables & views) in SQL Server.  
2. **Update connection** in `demo_pipeline.py` or notebook (`db_connect.py`).  
3. **Run Python:**
   ```bash
   python demo_pipeline.py
4.Open Power BI and connect to vw_Loans_With_Preds view.

## 📊 Dashboard Highlights

Loan approval probabilities

High-risk customer segmentation

KPI cards and risk distribution charts

Feature importance visualization

## 🧾 Author

Ramkumar N |
Data Analyst | Banking & Financial Services
📧 ramkumar.n.data@gmail.com

🔗 LinkedIn 

## 🏁 Summary

Loan Analytics Pipeline integrates SQL, Python, and Power BI into one seamless workflow — from raw data to business-ready insights.
