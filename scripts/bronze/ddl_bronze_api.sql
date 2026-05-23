/*
    Bronze DDL — API-sourced tables.

    These tables land raw rows from REST APIs (see scripts/ingest/).
    They follow the same conventions as CRM/ERP bronze tables but use
    the `api_` source prefix to distinguish them in lineage.
*/

IF OBJECT_ID('bronze.api_fx_rates', 'U') IS NOT NULL
    DROP TABLE bronze.api_fx_rates;
GO

CREATE TABLE bronze.api_fx_rates (
    rate_date        DATE           NOT NULL,
    base_currency    CHAR(3)        NOT NULL,
    quote_currency   CHAR(3)        NOT NULL,
    rate             DECIMAL(18, 8) NOT NULL,
    dwh_load_dts     DATETIME2      NOT NULL
        CONSTRAINT df_api_fx_rates_load_dts DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX ix_api_fx_rates_date
    ON bronze.api_fx_rates (rate_date, quote_currency);
GO
