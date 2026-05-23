This project demonstrates a production grade data warehouse built entirely in SQL. It follows modern data engineering best practices: layered architecture, idempotent ETL, consistent naming conventions, declarative data models, and documented lineage. The goal is to take messy data from multiple source systems (ERP and CRM) and turn it into clean, dimensional, business-ready datasets that analysts can query confidently.
It is designed to be a portfolio-quality reference for anyone learning how real data warehouses are organized — not just what SQL to write, but how to structure a warehouse project end-to-end.

🏛️ Architecture
The warehouse follows the Medallion Architecture — a layered approach popularized by modern data platforms — adapted here to SQL Server.

┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   SOURCES    │ ──► │   BRONZE     │ ──► │   SILVER     │ ──► │    GOLD      │
│  CRM + ERP   │     │   (Raw)      │     │  (Cleansed)  │     │  (Business)  │
│   CSV files  │     │  As-ingested │     │ Standardized │     │ Star schema  │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                          BULK             stored procs          views / facts
                         INSERT            transformations        & dimensions

