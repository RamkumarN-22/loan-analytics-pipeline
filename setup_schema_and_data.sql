/* ===================================================================
   Loan Analytics — Full setup + robust Repayments generator
   - Creates DB loan_analytics_dev if missing
   - Creates Customers, Applications, Repayments (schema)
   - Populates Customers (500) and Applications (1000)
   - Populates Repayments (set-based) with overall cap (default 5000)
   =================================================================== */

-- 0) Create DB if missing and switch to it
IF DB_ID('loan_analytics_dev') IS NULL
BEGIN
    CREATE DATABASE loan_analytics_dev;
    PRINT 'Created database loan_analytics_dev';
END
GO

USE loan_analytics_dev;
GO

-- 1) Drop existing demo tables (safe for repeated runs)
IF OBJECT_ID('dbo.Repayments') IS NOT NULL DROP TABLE dbo.Repayments;
IF OBJECT_ID('dbo.Applications') IS NOT NULL DROP TABLE dbo.Applications;
IF OBJECT_ID('dbo.Customers') IS NOT NULL DROP TABLE dbo.Customers;
GO

-- 2) Create tables (Age computed from DOB)
CREATE TABLE dbo.Customers (
  CustomerID INT PRIMARY KEY,
  Name NVARCHAR(100) NOT NULL,
  DOB DATE NOT NULL,
  Income BIGINT NOT NULL,
  EmploymentYears INT NOT NULL,
  Age AS DATEDIFF(YEAR, DOB, GETDATE())
);
GO

CREATE TABLE dbo.Applications (
  ApplicationID INT PRIMARY KEY,
  CustomerID INT NOT NULL,
  ApplicationDate DATE NOT NULL,
  LoanAmount BIGINT NOT NULL,
  LoanTermMonths INT NOT NULL,
  Purpose NVARCHAR(50) NOT NULL,
  CONSTRAINT FK_Applications_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID)
);
GO

CREATE TABLE dbo.Repayments (
  RepaymentID INT PRIMARY KEY,
  ApplicationID INT NOT NULL,
  PaymentDate DATE NOT NULL,
  Paid BIT NOT NULL,
  AmountPaid BIGINT NOT NULL,
  CONSTRAINT FK_Repayments_Applications FOREIGN KEY (ApplicationID) REFERENCES dbo.Applications(ApplicationID)
);
GO

-- 3) Populate Customers (500 rows)
SET NOCOUNT ON;

DECLARE @NumCustomers INT = 500;

;WITH nums AS (
  SELECT TOP (@NumCustomers)
         ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
  FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Customers (CustomerID, Name, DOB, Income, EmploymentYears)
SELECT
  1000 + n,
  CONCAT(N'Cust_', 1000 + n),
  DATEADD(DAY, - (18*365 + (ABS(seed) % (50*365))), CAST(GETDATE() AS DATE)) AS DOB,
  (ABS(seed) % 2950000) + 50000 AS Income,
  ABS(seed2) % 30 AS EmploymentYears
FROM (
  SELECT n,
         CHECKSUM(NEWID()) AS seed,
         CHECKSUM(NEWID()) AS seed2
  FROM nums
) s;
GO

-- 4) Populate Applications (1000 rows)
DECLARE @StartAppID INT = 2000, @NumApps INT = 1000, @NumCustomersLocal INT = 500;

;WITH Tally AS (
  SELECT TOP (@NumApps) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
  FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
, RandomSeeds AS (
  SELECT rn,
         CHECKSUM(NEWID()) AS seed,
         CHECKSUM(NEWID()) AS seed2,
         CHECKSUM(NEWID()) AS seed3,
         CHECKSUM(NEWID()) AS seed4,
         CHECKSUM(NEWID()) AS seed5
  FROM Tally
)
INSERT INTO dbo.Applications (ApplicationID, CustomerID, ApplicationDate, LoanAmount, LoanTermMonths, Purpose)
SELECT
  @StartAppID + rn AS ApplicationID,
  1000 + (ABS(seed) % @NumCustomersLocal) AS CustomerID,
  DATEADD(DAY, (ABS(seed2) % 1095), DATEFROMPARTS(2022,1,1)) AS ApplicationDate,
  (ABS(seed3) % 1900000) + 20000 AS LoanAmount,
  CASE (ABS(seed4) % 5)
     WHEN 0 THEN 12 WHEN 1 THEN 24 WHEN 2 THEN 36 WHEN 3 THEN 48 ELSE 60 END AS LoanTermMonths,
  CHOOSE((ABS(seed5) % 5) + 1, N'Home', N'Car', N'Personal', N'Education', N'Business') AS Purpose
FROM RandomSeeds;
GO

-- 5) OPTIONAL: indexes for performance (recommended)
CREATE INDEX IX_Applications_CustomerID ON dbo.Applications(CustomerID);
CREATE INDEX IX_Applications_AppDate ON dbo.Applications(ApplicationDate);
GO

-- 6) Populate Repayments (robust, set-based) with overall cap
--     Adjust @MaxPaymentsPerApp or @MaxTotalInsert if you want different density
DECLARE 
    @StartRepayID INT     = 500000,  -- starting offset for RepaymentID
    @MaxPaymentsPerApp INT= 12,      -- per-app maximum candidate payments
    @MaxTotalInsert INT   = 5000;    -- overall cap for total inserted repayment rows

-- Generate and insert repayments
;WITH Apps AS (
    SELECT 
      ApplicationID,
      ApplicationDate,
      LoanAmount,
      LoanTermMonths,
      ABS(CHECKSUM(NEWID())) AS app_seed
    FROM dbo.Applications
),
Nums AS (
    -- numbers 0..(@MaxPaymentsPerApp-1)
    SELECT TOP (@MaxPaymentsPerApp)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects
),
AppPaymentCounts AS (
    -- per-application number of payments: 0..@MaxPaymentsPerApp
    SELECT
      a.ApplicationID,
      a.ApplicationDate,
      a.LoanAmount,
      a.LoanTermMonths,
      a.app_seed,
      (ABS(a.app_seed) % (@MaxPaymentsPerApp + 1)) AS NumPayments
    FROM Apps a
),
CandidatePayments AS (
    -- produce candidate payment rows for every application (n rows each), then limit later
    SELECT
      ap.ApplicationID,
      ap.ApplicationDate,
      ap.LoanAmount,
      ap.LoanTermMonths,
      ap.app_seed,
      n,
      DATEADD(DAY, 30 * n + ((ABS(CHECKSUM(ap.app_seed, n)) % 7) - 3), ap.ApplicationDate) AS PaymentDate,
      CASE WHEN (ABS(CHECKSUM(ap.app_seed, n, 'paid')) % 100) < 12 THEN 0 ELSE 1 END AS Paid,
      CAST( (ap.LoanAmount * 1.0 / NULLIF(ap.LoanTermMonths,1)) *
            (0.85 + (ABS(CHECKSUM(ap.app_seed, n, 'amt')) % 31)/100.0) AS BIGINT) AS AmountPaid
    FROM AppPaymentCounts ap
    CROSS JOIN Nums
    WHERE n < ap.NumPayments
),
NumberedCandidates AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY ApplicationID, n) AS rn,
      ApplicationID,
      PaymentDate,
      Paid,
      AmountPaid
    FROM CandidatePayments
)
INSERT INTO dbo.Repayments (RepaymentID, ApplicationID, PaymentDate, Paid, AmountPaid)
SELECT
    rn + @StartRepayID AS RepaymentID,
    ApplicationID,
    PaymentDate,
    Paid,
    AmountPaid
FROM NumberedCandidates
WHERE rn <= @MaxTotalInsert
ORDER BY rn
OPTION (MAXDOP 1);
GO

PRINT '✅ Repayments inserted (capped to @MaxTotalInsert).';
GO


-- 7) Create the reporting view (vw_CleanLoans)
CREATE OR ALTER VIEW dbo.vw_CleanLoans AS
WITH latest_repayment AS (
  SELECT
    r.ApplicationID,
    MAX(r.PaymentDate) AS LastPaymentDate,
    SUM(CASE WHEN r.Paid = 0 THEN 1 ELSE 0 END) AS MissedPaymentsCount
  FROM dbo.Repayments r
  GROUP BY r.ApplicationID
)
SELECT
  a.ApplicationID,
  a.CustomerID,
  a.ApplicationDate,
  c.Age,
  c.Income,
  c.EmploymentYears,
  a.LoanAmount,
  a.LoanTermMonths,
  a.Purpose,
  CAST(a.LoanAmount * 1.0 / NULLIF(c.Income,0) AS DECIMAL(18,4)) AS LoanToIncome,
  COALESCE(lr.MissedPaymentsCount, 0) AS MissedPaymentsCount,
  lr.LastPaymentDate
FROM dbo.Applications a
JOIN dbo.Customers c ON a.CustomerID = c.CustomerID
LEFT JOIN latest_repayment lr ON a.ApplicationID = lr.ApplicationID
WHERE a.LoanAmount IS NOT NULL;
GO

-- 8) Predictions table
IF OBJECT_ID('dbo.LoanPredictions') IS NOT NULL DROP TABLE dbo.LoanPredictions;
CREATE TABLE dbo.LoanPredictions (
  PredictionID INT IDENTITY(1,1) PRIMARY KEY,
  ApplicationID INT NOT NULL,
  CustomerID INT NOT NULL,
  ApplicationDate DATE NOT NULL,
  Pred_Prob FLOAT NOT NULL,
  Pred_Label BIT NOT NULL,
  ModelVersion VARCHAR(50) NOT NULL,
  ModelRunDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE INDEX IX_LoanPredictions_AppID_ModelRunDate ON dbo.LoanPredictions(ApplicationID, ModelRunDate);
GO

-- 9) Final sanity checks & samples
SELECT COUNT(*) AS CustomersCount   FROM dbo.Customers;
SELECT COUNT(*) AS ApplicationsCount FROM dbo.Applications;
SELECT COUNT(*) AS RepaymentsCount  FROM dbo.Repayments;

SELECT TOP 10 * FROM dbo.Applications ORDER BY ApplicationDate DESC;
SELECT TOP 10 * FROM dbo.Repayments  ORDER BY RepaymentID DESC;
SELECT TOP 10 * FROM dbo.vw_CleanLoans ORDER BY ApplicationDate DESC;
GO

-- Example: insert a tiny demo model run into LoanPredictions (optional)
INSERT INTO dbo.LoanPredictions (ApplicationID, CustomerID, ApplicationDate, Pred_Prob, Pred_Label, ModelVersion)
SELECT TOP (10) ApplicationID, CustomerID, ApplicationDate, 0.12 AS Pred_Prob, 0 AS Pred_Label, 'v1_demo'
FROM dbo.vw_CleanLoans
ORDER BY ApplicationDate DESC;
GO

SELECT TOP 10 * FROM dbo.LoanPredictions ORDER BY ModelRunDate DESC;
GO

/* End of script */
