DECLARE @StringToExecute NVARCHAR(4000), @TableName NVARCHAR(100);

/* Azure SQL DB: no direct access to tempdb, so we have to work in the current database */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @TableName = N'dbo.SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_deep_dive';
ELSE
    SET @TableName = N'tempdb..SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_deep_dive';

SET @StringToExecute = N'IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL 
        DROP TABLE ' + @TableName + N';

    CREATE TABLE ' + @TableName + N'(start_date DATETIME);
    INSERT INTO ' + @TableName + N'(start_date) VALUES (GETDATE());';

EXEC(@StringToExecute);

SELECT  dols.latch_class AS [Latch Class] ,
        dols.wait_time_ms AS [Wait Time (ms)],
        dols.waiting_requests_count AS [Waiting Requests Count],
        CASE WHEN dols.waiting_requests_count = 0 THEN 0
                WHEN dols.wait_time_ms = 0 THEN 0
                ELSE dols.wait_time_ms / dols.waiting_requests_count
        END AS [Avg Latch Wait (ms)],
        dols.max_wait_time_ms AS [Max Wait Time (ms)] ,
        CURRENT_TIMESTAMP AS  [Sample Time]
FROM    sys.dm_os_latch_stats dols
WHERE   dols.wait_time_ms > 0
ORDER BY dols.wait_time_ms DESC;

