IF DB_ID('TEX_Sales_Intelligence') IS NULL
    CREATE DATABASE TEX_Sales_Intelligence;
GO

USE TEX_Sales_Intelligence;
GO

CREATE SCHEMA dim;
GO
CREATE SCHEMA fact;
GO
CREATE SCHEMA vw;
GO
