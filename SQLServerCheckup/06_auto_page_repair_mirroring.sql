SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
DECLARE @StringToExecute NVARCHAR(4000);

/* Azure SQL DB: no direct access to this table */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @StringToExecute = N'SELECT NULL AS modification_time, NULL AS database_name, NULL AS file_id, NULL AS page_id, NULL AS error_type, NULL AS page_status
  WHERE 1 = 2';
ELSE
    SET @StringToExecute = N'SELECT TOP 1000 r.modification_time, d.name AS database_name, r.file_id, r.page_id, r.error_type, r.page_status
  FROM sys.dm_db_mirroring_auto_page_repair r
  INNER JOIN sys.databases d ON r.database_id = d.database_id
  ORDER BY r.modification_time DESC;';

EXEC(@StringToExecute);