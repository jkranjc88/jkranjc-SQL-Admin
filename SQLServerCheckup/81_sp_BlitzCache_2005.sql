/*
Queries in the procedure cache, SQL Server 2005 version

First, I need to explain that if you're reading this, the code is going to seem
incredibly dumb. Mind-numbingly stupid. There's a reason for that: it has to 
fit into a very particular set of calling parameters, and we're never going to
change this code, so it can afford to be kinda ugly.
*/

DECLARE @SortOrder VARCHAR(50);
SET @SortOrder = 'CPU';

/* Bail out if we've had memory dumps since we started collection */

DECLARE @pmaj INT = 0;
DECLARE @pmin INT = 0;
DECLARE @dump_sql NVARCHAR(MAX) = N'';
DECLARE @dumper INT = 0

SELECT @pmaj = PARSENAME(x.v, 4), @pmin = PARSENAME(x.v, 3)
FROM   ( SELECT CONVERT(NVARCHAR(128), SERVERPROPERTY('productversion'))) AS x(v);

IF ( (@pmaj = 10 AND @pmin = 50) OR @pmaj > 10) AND NOT SERVERPROPERTY('EngineEdition') IN (5, 6, 7)
    BEGIN
        SET @dump_sql += N'IF EXISTS (
							SELECT * 
							FROM sys.dm_server_memory_dumps md
							INNER JOIN tempdb..sql_counters_data c 
							ON md.creation_time >= c.collection_time
							)
							BEGIN
								SELECT @dump = 1
							END
							ELSE
							BEGIN
								SELECT @dump = 0
							END';

        EXEC sp_executesql @dump_sql, N'@dump INT OUTPUT', @dump = @dumper OUTPUT;
    END; 
 
IF @dumper = 1 OR SERVERPROPERTY('EngineEdition') IN (5, 6, 7) RETURN;

IF (@dumper = 0 AND @pmaj >= 10)
  SELECT NULL AS [Database], 
		NULL AS [Query Plan Cost],
		NULL AS [Query Type],
		NULL AS [Warnings],
		NULL AS [% Executions (Type)],
		NULL AS [Serial Desired Memory],
		NULL AS [Serial Required Memory],
		NULL AS [% Duration (Type)],
		NULL AS [% Reads (Type)],
		NULL AS [% Writes (Type)],
		NULL AS [Total Writes],
		NULL AS [Average Writes],
		NULL AS [Write Weight],
		NULL AS [Total Rows],
		NULL AS [Avg Rows],
		NULL AS [Min Rows],
		NULL AS [Max Rows],
		NULL AS [# Plans],
		NULL AS [# Distinct Plans],
		NULL AS [StatementStartOffset],
		NULL AS [StatementEndOffset],
		NULL AS [Query Hash],
		NULL AS [Query Plan Hash] /* Hacking to give something unique for file name */,
		NULL AS [SET Options],
		NULL AS [Cached Plan Size (KB)],
		NULL AS [Compile Time (ms)],
		NULL AS [Compile CPU (ms)],
		NULL AS [Compile memory (KB)],
		NULL AS [Plan Handle],
		NULL AS [SQL Handle],
		NULL AS [Avg CPU (ms)] ,
        NULL AS [Total CPU (ms)] ,
		NULL AS [CPU Weight],
        NULL AS [Avg Duration (ms)],
        NULL AS [Total Duration (ms)] ,
		NULL AS [Duration Weight],
        NULL AS [Average Reads] ,
        NULL AS [Total Reads] ,
		NULL AS [Read Weight],
        NULL AS [# Executions] ,
		NULL AS [Execution Weight],
	    NULL AS [Executions / Minute],
        NULL AS [Created At],
        NULL AS [Last Execution],
        NULL AS [Query Text] ,
        NULL AS [Query Plan]
	WHERE 1 = 0;
ELSE
SELECT TOP 20 
		DB_NAME(qp.dbid) AS [Database], 
		NULL AS [Query Plan Cost],
		NULL AS [Query Type],
		NULL AS [Warnings],
		NULL AS [% Executions (Type)],
		NULL AS [Serial Desired Memory],
		NULL AS [Serial Required Memory],
		NULL AS [% Duration (Type)],
		NULL AS [% Reads (Type)],
		NULL AS [% Writes (Type)],
		NULL AS [Total Writes],
		NULL AS [Average Writes],
		NULL AS [Write Weight],
		NULL AS [Total Rows],
		NULL AS [Avg Rows],
		NULL AS [Min Rows],
		NULL AS [Max Rows],
		NULL AS [# Plans],
		NULL AS [# Distinct Plans],
		qs.statement_start_offset AS [StatementStartOffset],
		qs.statement_end_offset AS [StatementEndOffset],
		NULL AS [Query Hash],
		NEWID() AS [Query Plan Hash] /* Hacking to give something unique for file name */,
		NULL AS [SET Options],
		NULL AS [Cached Plan Size (KB)],
		NULL AS [Compile Time (ms)],
		NULL AS [Compile CPU (ms)],
		NULL AS [Compile memory (KB)],
		qs.plan_handle AS [Plan Handle],
		qs.sql_handle AS [SQL Handle],
		total_worker_time / 1000 / execution_count AS [Avg CPU (ms)] ,
        total_worker_time / 1000 AS [Total CPU (ms)] ,
		CAST(ROUND(100.00 * total_worker_time / (SELECT SUM(total_worker_time) FROM sys.dm_exec_query_stats), 2) AS MONEY) AS [CPU Weight],
        total_elapsed_time / 1000 / execution_count AS [Avg Duration (ms)],
        total_elapsed_time / 1000 AS [Total Duration (ms)] ,
		CAST(ROUND(100.00 * total_elapsed_time / (SELECT SUM(total_elapsed_time) FROM sys.dm_exec_query_stats), 2) AS MONEY) AS [Duration Weight],
        total_logical_reads / execution_count AS [Average Reads] ,
        total_logical_reads AS [Total Reads] ,
		CAST(ROUND(100.00 * total_logical_reads / (SELECT SUM(total_logical_reads) FROM sys.dm_exec_query_stats), 2) AS MONEY) AS [Read Weight],
        execution_count AS [# Executions] ,
		CAST(ROUND(100.00 * execution_count / (SELECT SUM(execution_count) FROM sys.dm_exec_query_stats), 2) AS MONEY) AS [Execution Weight],
	[Executions / Minute] = CASE  DATEDIFF(mi, creation_time, qs.last_execution_time)
		WHEN 0 THEN 0
		ELSE CAST((1.00 * execution_count / DATEDIFF(mi, creation_time, qs.last_execution_time)) AS money)
	END,
        qs.creation_time AS [Created At],
        qs.last_execution_time AS [Last Execution],
        SUBSTRING(st.text, ( qs.statement_start_offset / 2 ) + 1, ( ( CASE qs.statement_end_offset
                                                                        WHEN -1 THEN DATALENGTH(st.text)
                                                                        ELSE qs.statement_end_offset
                                                                      END - qs.statement_start_offset ) / 2 ) + 1) AS [Query Text] ,
        query_plan AS [Query Plan]
    FROM sys.dm_exec_query_stats AS qs
        CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st 
        CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
    ORDER BY CASE @SortOrder
		WHEN 'CPU' THEN total_worker_time
		WHEN 'duration' THEN total_elapsed_time
		WHEN 'executions' THEN  execution_count
		WHEN 'reads' THEN total_logical_writes
		WHEN 'writes' THEN total_logical_writes
		WHEN 'xpm' THEN CASE  DATEDIFF(mi, creation_time, qs.last_execution_time)
								WHEN 0 THEN 0
								ELSE CAST((1.00 * execution_count / DATEDIFF(mi, creation_time, qs.last_execution_time)) AS money)
							END
		ELSE total_worker_time
		END DESC
