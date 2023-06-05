DECLARE @RunDate datetime
SET @RunDate=GETDATE()
SELECT TOP 10000 IDENTITY(int,1,1) AS Number
    INTO NumbersT
    FROM sys.objects s1       --use sys.columns if you don't get enough rows returned to generate all the numbers you need
    CROSS JOIN sys.objects s2 --use sys.columns if you don't get enough rows returned to generate all the numbers you need
ALTER TABLE NumbersT ADD CONSTRAINT PK_NumbersT PRIMARY KEY CLUSTERED (Number)
PRINT CONVERT(varchar(20),datediff(ms,@RunDate,GETDATE()))+' milliseconds'
SELECT COUNT(*) FROM NumbersT