/*
===============================================================================
 Script:      database_initialization.sql
 Purpose:     Initialize the DataWarehouse database and the three layered
              schemas (bronze, silver, gold) used by the medallion architecture.

 What it does:
   1. Switches to the [master] database.
   2. Drops the existing [DataWarehouse] database if it exists.
   3. Recreates the [DataWarehouse] database from scratch.
   4. Creates the bronze, silver, and gold schemas inside it.

 Run as:      A login with sysadmin or dbcreator privileges on the SQL Server
              instance (required for CREATE / DROP DATABASE).
===============================================================================

 !!  WARNING — DESTRUCTIVE OPERATION  !!
 -----------------------------------------------------------------------------
 This script DROPS the existing [DataWarehouse] database if one is present.
 ALL data, tables, views, stored procedures, users, and permissions inside
 that database will be PERMANENTLY LOST. There is no rollback.

 Before running:
   * Confirm you are connected to the correct SQL Server instance.
   * Make sure no production workload is pointing at [DataWarehouse].
   * Take a backup if there is any chance the data is needed.

 Only run this on a development or sandbox environment unless you have
 explicit approval to rebuild the warehouse.
===============================================================================
*/

USE master;
GO

-- Drop the database if it already exists. Force single-user mode first so
-- that any open connections are rolled back and the DROP can proceed.
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

-- Create the warehouse database.
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Create the three medallion-layer schemas.
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
