DECLARE @StringToExecute NVARCHAR(4000), @TableName NVARCHAR(200), @minutes_passed INT, @deep_dive TINYINT;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

/* ------------------------------------------ */
/* BEGIN SECTION: Memory performance counters */
/* ------------------------------------------ */

	SELECT  object_name as [Object Name] ,
			instance_name AS [Instance Name] ,
			CASE WHEN counter_name = N'Page life expectancy' THEN N'Page life expectancy (seconds)' 
			ELSE counter_name END AS [Counter Name] ,
			cntr_value AS [Value]
	FROM    sys.dm_os_performance_counters
	WHERE   (object_name LIKE N'%Buffer Manager%'
			 AND counter_name = N'Page life expectancy'
			)
			OR (OBJECT_NAME LIKE N'%Memory Manager%')
	ORDER BY object_name ASC ,
			counter_name DESC
	OPTION (RECOMPILE)


/* ------------------------------------------ */
/* END SECTION: Memory performance counters	  */
/* ------------------------------------------ */


/* -------------------------------------------- */
/* BEGIN SECTION: Buffer page usage by database */
/* -------------------------------------------- */
/* How many minutes have we been running? */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @TableName = N' dbo.SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_waits w ';
ELSE
    SET @TableName = N' tempdb..SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_waits w ';
SET @StringToExecute = N'SELECT TOP 1 @minutes_passed = DATEDIFF(mi, w.collection_time, GETDATE()) FROM ' + @TableName; 
EXEC sp_executesql @StringToExecute, N'@minutes_passed INT OUTPUT', @minutes_passed = @minutes_passed OUTPUT;

/* Are we doing a deep dive? */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @TableName = N'dbo.SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_deep_dive';
ELSE
    SET @TableName = N'tempdb..SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_deep_dive';
SET @StringToExecute = N'IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL SET @deep_dive = 1 ELSE SET @deep_dive = 0;'; 
EXEC sp_executesql @StringToExecute, N'@deep_dive TINYINT OUTPUT', @deep_dive = @deep_dive OUTPUT;


IF @minutes_passed < 5 OR @deep_dive = 1
	BEGIN
	WITH    memory
			  AS (SELECT    CAST(COUNT(*) * 8 / 1024.0 AS NUMERIC(10, 2)) AS [Cached Data MB] ,
							CAST(SUM(CAST(free_space_in_bytes AS BIGINT)) / 1024. / 1024. AS NUMERIC(10, 2)) AS [Free MB] ,
							CASE database_id
							  WHEN 32767 THEN 'ResourceDb'
							  ELSE DB_NAME(database_id)
							END AS [DB Name]
				  FROM      sys.dm_os_buffer_descriptors
				  GROUP BY  DB_NAME(database_id) ,
							database_id
				 )
	--The detail by database
	SELECT  [Cached Data MB] ,
			[Free MB] ,
			CONVERT(NUMERIC(6, 2), ([Free MB] / [Cached Data MB]) * 100) AS [% Free] ,
			[DB Name]
	FROM    memory
	UNION
	--And now the total
	SELECT  SUM([Cached Data MB]) AS [Cached Data MB] ,
			SUM([Free MB]) AS [Free MB] ,
			CONVERT(NUMERIC(6, 2), (100 * SUM(CAST([Free MB] AS BIGINT)) / SUM(CAST([Cached Data MB] AS BIGINT)))) AS [% Free] ,
			N'***ALL DATABASES***' AS [DB Name]
	FROM    memory
	ORDER BY [Cached Data MB] DESC
	OPTION (RECOMPILE);
	END
ELSE
	BEGIN
	SELECT  0 AS [Cached Data MB] ,
			0 AS [Free MB] ,
			0 AS [% Free] ,
			N'Skipped because SQLServerCheckup took over 5 minutes to run. To gather this data, use the --deepdive configuration switch.' AS [DB Name];
	END

	

/* -------------------------------------------- */
/* END SECTION: Buffer page usage by database   */
/* -------------------------------------------- */


/* ---------------------------------------------------- */
/* BEGIN SECTION: Buffer page by database, by NUMA node */
/* This only works in SQL Server 2008+                  */
/* ---------------------------------------------------- */

DECLARE @SQLServerProductVersion NVARCHAR(128);
SELECT @SQLServerProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));
IF (SELECT LEFT(@SQLServerProductVersion,
    CHARINDEX('.',@SQLServerProductVersion,0)-1
    )) > 9
	AND (@minutes_passed < 5 OR @deep_dive = 1)
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    /*This is run as dynamic SQL as it will not compile on SQL Server 2005. */
    DECLARE @TSQL NVARCHAR(MAX)
    SET @TSQL=N'
	WITH    memory
			  AS (SELECT    CAST(COUNT(*) * 8 / 1024.0 AS NUMERIC(10, 2)) AS [Cached Data MB] ,
							CAST(SUM(CAST(free_space_in_bytes AS BIGINT)) / 1024. / 1024. AS NUMERIC(10, 2)) AS [Free MB] ,
							CASE database_id
							  WHEN 32767 THEN ''ResourceDb''
							  ELSE DB_NAME(database_id)
							END AS [DB Name],
							numa_node
				  FROM      sys.dm_os_buffer_descriptors
				  GROUP BY  DB_NAME(database_id) ,
							database_id,
							numa_node
				 )
	--The detail by database
	SELECT  numa_node as [NUMA Node] ,
			[Cached Data MB] ,
			[Free MB] ,
			CONVERT(NUMERIC(6, 2), ([Free MB] / [Cached Data MB]) * 100) AS [% Free] ,
			[DB Name]
	FROM    memory
	UNION
	--And now the total
	SELECT  numa_node as [NUMA Node],
			SUM([Cached Data MB]) AS [Cached Data MB] ,
			SUM([Free MB]) AS [Free MB] ,
			CONVERT(NUMERIC(6, 2), (100 * SUM(CAST([Free MB] AS BIGINT)) / SUM(CAST([Cached Data MB] AS BIGINT)))) AS [% Free] ,
			N''***ALL DATABASES***'' AS [DB Name]
	FROM    memory
	GROUP BY numa_node
	ORDER BY numa_node, [Cached Data MB] DESC
	OPTION (RECOMPILE);'

    print @TSQL
    EXEC sp_executesql @TSQL	
END
ELSE
	SELECT NULL AS [NUMA Node], NULL AS [Cached Data MB], NULL AS [Free MB], NULL AS [% Free], 'No results for SQL Server 2005 or long-running SQLServerCheckup without --deepdive switch' AS [DB Name];


/* -------------------------------------------------- */
/* END SECTION: Buffer page by database, by NUMA node */
/* -------------------------------------------------- */


/* ---------------------------------------------- */
/* BEGIN SECTION: Memory usage for the plan cache */
/* ---------------------------------------------- */
	WITH    plancache
			  AS (SELECT    objtype ,
							COUNT(*) count_of_plans ,
							CAST(SUM(CAST(size_in_bytes AS BIGINT)) / 1024. / 1024. AS NUMERIC(10, 1)) AS mb_all_plans ,
							SUM(CAST(usecounts AS BIGINT)) AS total_usecount ,
							AVG(CAST(usecounts AS BIGINT)) AS avg_usecount ,
							SUM(CASE WHEN usecounts = 1
										  AND cacheobjtype <> 'Compiled Plan Stub' THEN 1
									 ELSE 0
								END) AS count_single_use_plans ,
							CAST(SUM(CASE WHEN usecounts = 1 THEN CAST(size_in_bytes AS BIGINT)
										  ELSE 0
									 END) / 1024. / 1024. AS NUMERIC(10, 1)) AS total_mb_single_use_plans
				  FROM      sys.dm_exec_cached_plans
				  GROUP BY  objtype
				 )
		SELECT  objtype as [Object Type] ,
				count_of_plans AS [Plan Count] ,
				mb_all_plans AS [Total MB] ,
				total_usecount AS [Total Use Count] ,
				avg_usecount AS [Avg Use Count] ,
				count_single_use_plans AS [Count Single-Use Plans] ,
				total_mb_single_use_plans AS [Total MB Single-Use Plans] ,
				CASE WHEN mb_all_plans > 0 THEN CAST(100 * total_mb_single_use_plans / mb_all_plans AS NUMERIC(10, 1))
					 ELSE 0
				END AS [% Space Single-Use Plans]
		FROM    plancache
		UNION ALL
		SELECT  '***Entire Cache***' ,
				SUM(count_of_plans) ,
				SUM(mb_all_plans) ,
				SUM(total_usecount) ,
				AVG(total_usecount) ,
				SUM(count_single_use_plans) ,
				SUM(total_mb_single_use_plans) ,
				CASE WHEN SUM(mb_all_plans) > 0
					 THEN CAST(100 * SUM(total_mb_single_use_plans) / SUM(mb_all_plans) AS NUMERIC(10, 1))
					 ELSE 0
				END AS percent_space_single_use_plans
		FROM    plancache
		ORDER BY mb_all_plans DESC
	OPTION  (RECOMPILE) ;


/* -------------------------------------------- */
/* END SECTION: Memory usage for the plan cache */
/* -------------------------------------------- */


	/* ---------------------------------------------- */
	/* BEGIN SECTION: Plan cache history by date/hour */
	/* ---------------------------------------------- */

	SELECT TOP 50
		creation_date = CAST(creation_time AS date),
		creation_hour = 
		    CASE WHEN CAST(creation_time AS date) <> CAST(GETDATE() AS date) THEN 0
		    ELSE DATEPART(hh, creation_time)
		    END,
		SUM(1) AS plans
	FROM sys.dm_exec_query_stats
	GROUP BY CAST(creation_time AS date), CASE WHEN CAST(creation_time AS date) <> CAST(GETDATE() AS date) THEN 0
		    ELSE DATEPART(hh, creation_time)
		    END
	ORDER BY 1 DESC, 2 DESC


	/* -------------------------------------------- */
	/* END SECTION: Plan cache history by date/hour */
	/* -------------------------------------------- */


	/* ---------------------------------------------- */
	/* BEGIN SECTION: Error log */
	/* ---------------------------------------------- */
	
	IF OBJECT_ID('tempdb..#ErrorLog') IS NOT NULL
		BEGIN
			DROP TABLE #ErrorLog
		END

	IF OBJECT_ID('tempdb..#SearchMessages') IS NOT NULL
		BEGIN
			DROP TABLE #SearchMessages
		END

	CREATE TABLE #ErrorLog
     (
         LogDate DATETIME ,
         ProcessInfo NVARCHAR(100) ,
         Text NVARCHAR(4000) 
     ) ;

	 CREATE TABLE #SearchMessages
     (
         Id INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
		 SearchString NVARCHAR(1000),
		 DaysBack NVARCHAR(100),
		 CurrentDate NVARCHAR(100) DEFAULT N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, 1, SYSDATETIME()), 112) + N'"',
		 SearchOrder NVARCHAR(100) DEFAULT N'"DESC"',
		 Command AS CONVERT(NVARCHAR(4000), 
			N'EXEC master.dbo.xp_readerrorlog 0, 1, '
			+ SearchString
			+ N', '
			+ N'" "'
			+ N', '
			+ DaysBack
			+ N', '
			+ CurrentDate
			+ N', '
			+ SearchOrder
			+ N';'
		 )
     ) ;

	 INSERT #SearchMessages ( SearchString, DaysBack )
	 SELECT x.SearchString, x.DaysBack
	 FROM (VALUES
			(N'"I/O is frozen on database"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -2, GETDATE()), 112) + N'"') ,
			(N'"I/O was resumed on database"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -2, GETDATE()), 112) + N'"') ,
			(N'"I/O requests taking longer than"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"A system assertion check has failed"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"SQL Server is terminating because of fatal exception"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -7, GETDATE()), 112) + N'"'),
			(N'"A significant part of sql server process memory has been paged out"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"occurrence(s) of cachestore flush for the"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"This is a severe system-level error condition"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"SQL Server detected a logical consistency-based I/O error"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"This error condition threatens database integrity and must be corrected"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"Run DBCC CHECK"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"Contact Technical Support"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"SQL Server failed with error code"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"The thread pool for Always On Availability Groups"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"New parallel operation cannot be started"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"SQL Server could not spawn"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"SQL Server failed with error code"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"New queries assigned to process on Node"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"All schedulers on Node"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"There was a memory allocation failure"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"SQL Server has insufficient memory"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"SQL Server was unable to run"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"corruption"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"Timeout occurred while waiting for latch"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"yielding"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"FlushCache"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"Time-out occurred while waiting for buffer"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"IOCP"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"detected"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
			(N'"Autogrow of file"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"'),
            (N'"Buffer Pool Scan"', N'"' + CONVERT(NVARCHAR(30), DATEADD(DAY, -30, GETDATE()), 112) + N'"')
		  ) AS x (SearchString, DaysBack);
		  

    /* Skip these checks on Azure SQL DB and Amazon RDS since we won't have permission to read the log */
	IF LEFT(CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS VARCHAR(8000)), 8) <> 'EC2AMAZ-'
		AND LEFT(CAST(SERVERPROPERTY('MachineName') AS VARCHAR(8000)), 8) <> 'EC2AMAZ-'
		AND LEFT(CAST(SERVERPROPERTY('ServerName') AS VARCHAR(8000)), 8) <> 'EC2AMAZ-'
		AND db_id('rdsadmin') IS NULL
		AND SERVERPROPERTY('EngineEdition') NOT IN (5, 6, 8) /* Azure */
        BEGIN
	    DECLARE @Command NVARCHAR(4000);
	    DECLARE result_cursor CURSOR FOR
	    SELECT Command FROM #SearchMessages;

	    OPEN result_cursor;
	    FETCH NEXT FROM result_cursor INTO @Command;
	    WHILE @@FETCH_STATUS = 0
	    BEGIN 
	
		    INSERT #ErrorLog ( LogDate, ProcessInfo, Text )
		    EXEC(@Command);
	
	    FETCH NEXT FROM result_cursor INTO @Command;
	    END;

	    CLOSE result_cursor;
	    DEALLOCATE result_cursor;
        END

	SELECT TOP 10000 el.LogDate, el.ProcessInfo, el.Text FROM #ErrorLog AS el ORDER BY el.LogDate DESC;

	/* -------------------------------------------- */
	/* END SECTION: Error Log */
	/* -------------------------------------------- */
	




	/* ---------------------------------------- */
	/* BEGIN SECTION: Plans duplicated in cache */
	/* ---------------------------------------- */


	SELECT TOP 10 qs.query_hash, SUM(1) AS query_stats_rows,
	    SUM(qs.execution_count) AS executions,
	    SUM(qs.total_logical_reads) AS total_logical_reads,
	    SUM(qs.total_worker_time) AS total_worker_time,
	    SUM(qs.total_elapsed_time) AS total_elapsed_time,
	    COUNT(DISTINCT qs.query_plan_hash) AS plan_hashes,
	    MIN(qs.creation_time) AS creation_time_min,
	    MAX(qs.creation_time) AS creation_time_max,
	    MAX(qs.last_execution_time) AS last_execution_time,
	    query_plan_worst = (SELECT TOP 1 qpWorst.query_plan
	                            FROM sys.dm_exec_query_stats qsWorst
	                            CROSS APPLY sys.dm_exec_query_plan(qsWorst.plan_handle) qpWorst
	                            WHERE qsWorst.query_hash = qs.query_hash
	                            ORDER BY qsWorst.total_logical_reads DESC)
	FROM sys.dm_exec_query_stats qs WITH (NOLOCK)
	GROUP BY qs.query_hash
    HAVING COUNT(*) > 100
	UNION ALL
	SELECT NULL AS query_hash, SUM(1) AS query_stats_rows,
	    SUM(qsT.execution_count) AS executions,
	    SUM(qsT.total_logical_reads) AS total_logical_reads,
	    SUM(qsT.total_worker_time) AS total_worker_time,
	    SUM(qsT.total_elapsed_time) AS total_elapsed_time,
	    0 AS plan_hashes,
	    MIN(qsT.creation_time) AS creation_time_min,
	    MAX(qsT.creation_time) AS creation_time_max,
	    MAX(qsT.last_execution_time) AS last_execution_time,
	    NULL AS query_plan_worst
	FROM sys.dm_exec_query_stats qsT WITH (NOLOCK)
	ORDER BY 2 DESC;


	/* -------------------------------------- */
	/* END SECTION: Plans duplicated in cache */
	/* -------------------------------------- */
	