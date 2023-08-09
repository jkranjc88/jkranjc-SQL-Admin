SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
DECLARE @StringToExecute NVARCHAR(4000);

/* Azure SQL DB: no direct access to this table */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @StringToExecute = N'SELECT NULL AS last_update_date, NULL AS database_name, NULL AS database_id, NULL AS file_id, NULL AS page_id, NULL AS event_type, NULL AS error_count
      WHERE 1 = 2';
ELSE
    SET @StringToExecute = N'SELECT TOP 1000 sp.last_update_date, d.name AS database_name, sp.database_id, sp.file_id, sp.page_id, sp.event_type, sp.error_count
      FROM msdb.dbo.suspect_pages sp
      INNER JOIN sys.databases d ON sp.database_id = d.database_id
      ORDER BY sp.last_update_date DESC;';

EXEC(@StringToExecute);