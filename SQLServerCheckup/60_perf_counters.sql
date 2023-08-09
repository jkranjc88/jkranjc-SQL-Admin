/* ----------------------------------- */
/* BEGIN SECTION: Performance counters */
/* ----------------------------------- */
DECLARE @StringToExecute NVARCHAR(4000), @TableName NVARCHAR(100);


/*Collect second sample.*/
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @TableName = N'dbo.SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_perfmon';
ELSE
    SET @TableName = N'tempdb..SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_perfmon';

SET @StringToExecute = N'IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL 
INSERT  ' + @TableName + N' ( [batch_id] , [object_name] , [counter_name] , [instance_name] , [cntr_value], [cntr_type] )
		SELECT  2 AS [batch_id] ,
		        CAST(RTRIM(perf.[object_name]) AS VARCHAR(128)) ,
		        CAST(RTRIM(perf.[counter_name]) AS VARCHAR(128)) ,
		        CAST(RTRIM(perf.[instance_name]) AS VARCHAR(128)) ,
		        perf.[cntr_value],
                perf.[cntr_type]
		FROM    sys.[dm_os_performance_counters] AS perf
		WHERE   RTRIM(perf.counter_name) IN (''Auto-Param Attempts/sec''
, ''Batch Requests/sec''
, ''Checkpoint pages/sec''
, ''Connection Resets/sec''
, ''Data File(s) Size(KB)''
, ''Extent Deallocations/sec''
, ''Extents Allocated/sec''
, ''Failed Auto-Params/sec''
, ''Forced Parameterizations/sec''
, ''Forwarded Records/sec''
, ''Free list stalls/sec''
, ''Full Scans/sec''
, ''Guided Plan Executions/sec''
, ''Lazy writes/sec''
, ''Lock Requests/sec''
, ''Lock Waits/sec''
, ''Log Bytes Flushed/sec''
, ''Log Flush Wait Time''
, ''Log Flush Waits/sec''
, ''Log Flushes/sec''
, ''Logins/sec''
, ''Logouts/sec''
, ''Memory Grants Outstanding''
, ''Memory Grants Pending''
, ''Misguided Plan Executions/sec''
, ''Number of Deadlocks/sec''
, ''Page life expectancy''
, ''Page lookups/sec''
, ''Page reads/sec''
, ''Probe Scans/sec''
, ''Range Scans/sec''
, ''Readahead pages/sec''
, ''Safe Auto-Params/sec''
, ''Skipped Ghosted Records/sec''
, ''SQL Attention rate''
, ''SQL Compilations/sec''
, ''SQL Re-Compilations/sec''
, ''Target Server Memory (KB)''
, ''Total Server Memory (KB)''
, ''Unsafe Auto-Params/sec''
, ''User Connections'');';

EXEC(@StringToExecute);




/*Return the difference*/
SET @StringToExecute = N'IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL 
WITH    [perf_sample]
          AS ( SELECT   [batch_id] ,
                        [collection_time] ,
                        [object_name] ,
                        [counter_name] ,
                        [instance_name] ,
                        [cntr_value] ,
                        [cntr_type]
               FROM ' + @TableName + N'
             )
    SELECT  COALESCE(DATEDIFF(ss, [sample_1].[collection_time], [sample_2].[collection_time]),0) AS [Seconds] ,
            [sample_1].[object_name] AS [Perf Object] ,
            [sample_1].[counter_name] AS [Perf Counter] ,
            [sample_1].[instance_name] AS [Perf Instance] ,
			CASE WHEN [sample_1].cntr_type = 272696576 /*per-sec counters, cumulative*/ THEN
				CASE WHEN [sample_2].[cntr_value] > [sample_1].[cntr_value]
					 THEN [sample_2].[cntr_value] - [sample_1].[cntr_value]
					 ELSE 0
				END 
			ELSE [sample_2].[cntr_value] /*if not a per-sec counter, just take the second sample value*/
			END
				AS [Total Count] ,
			CASE WHEN [sample_1].cntr_type = 272696576 /*per-sec counters, cumulative*/ THEN
				CASE WHEN [sample_2].[cntr_value] > [sample_1].[cntr_value]
					 THEN CAST(( [sample_2].[cntr_value] - [sample_1].[cntr_value] ) / 
						( 1.0 * DATEDIFF(ss,[sample_1].[collection_time],[sample_2].[collection_time]) ) 
						AS NUMERIC(20,1))
					 ELSE 0
				END
			ELSE NULL /*Not a per-sec counter-- leave it blank*/
            END AS [Average Per Sec]
    FROM   [perf_sample] AS sample_1 
        LEFT OUTER JOIN [perf_sample] AS sample_2 ON [sample_2].[batch_id] = 2
			AND [sample_2].[object_name] = [sample_1].[object_name]
            AND [sample_2].[counter_name] = [sample_1].[counter_name]
            AND [sample_2].[instance_name] = [sample_1].[instance_name]
	WHERE sample_1.batch_id = 1
    ORDER BY sample_1.object_name, sample_1.counter_name, sample_1.instance_name;';
EXEC(@StringToExecute);

SET @StringToExecute = N'IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL DROP TABLE ' + @TableName;
EXEC(@StringToExecute);
