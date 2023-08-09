DECLARE @StringToExecute NVARCHAR(4000)

/* Last startup */
SELECT
    CAST(create_date AS VARCHAR(100)) as Last_Startup,
    CAST(DATEDIFF(hh,create_date,getdate())/24. as numeric (23,2)) AS days_uptime
FROM    sys.databases
WHERE   database_id = 2;


IF EXISTS (SELECT * FROM sys.dm_os_performance_counters)
	SELECT
		TOP 1 COALESCE(CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(100)),LEFT(object_name, (CHARINDEX(':', object_name) - 1))) as MachineName,
		ISNULL(CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(100)),'(default instance)') as InstanceName,
		CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100)) as ProductVersion,
        CASE WHEN CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(2)) IN ('10', '11', '12', '13')
              AND SERVERPROPERTY('EngineEdition') NOT IN (5, 6, 8)
            THEN CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(100)) 
            ELSE ''
        END as PatchLevel,
		CAST(SERVERPROPERTY('Edition') AS VARCHAR(100)) as Edition,
		CAST(SERVERPROPERTY('IsClustered') AS VARCHAR(100)) as IsClustered,
		CAST(COALESCE(SERVERPROPERTY('IsHadrEnabled'),0) AS VARCHAR(100)) as AlwaysOnEnabled,
		'' AS Warning
	FROM sys.dm_os_performance_counters;
ELSE
	SELECT
		TOP 1 (CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(100))) as MachineName,
		ISNULL(CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(100)),'(default instance)') as InstanceName,
		CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100)) as ProductVersion,
		CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(100)) as PatchLevel,
		CAST(SERVERPROPERTY('Edition') AS VARCHAR(100)) as Edition,
		CAST(SERVERPROPERTY('IsClustered') AS VARCHAR(100)) as IsClustered,
		CAST(COALESCE(SERVERPROPERTY('IsHadrEnabled'),0) AS VARCHAR(100)) as AlwaysOnEnabled,
		'WARNING - No records found in sys.dm_os_performance_counters' AS Warning


/* Sys info, SQL 2012 and higher */
IF EXISTS ( SELECT  *
			FROM    sys.all_objects o
					INNER JOIN sys.all_columns c ON o.object_id = c.object_id
			WHERE   o.name = 'dm_os_sys_info'
					AND c.name = 'physical_memory_kb' )
	BEGIN
		SET @StringToExecute = '
        SELECT
            cpu_count,
            CAST(ROUND((physical_memory_kb / 1024.0 / 1024), 1) AS INT) as physical_memory_GB
        FROM sys.dm_os_sys_info';
		EXECUTE(@StringToExecute);
	END
/* Sys info, SQL 2008R2 and prior */
ELSE IF EXISTS ( SELECT  *
			FROM    sys.all_objects o
					INNER JOIN sys.all_columns c ON o.object_id = c.object_id
			WHERE   o.name = 'dm_os_sys_info'
					AND c.name = 'physical_memory_in_bytes' )
    BEGIN
		    SET @StringToExecute = '
            SELECT
                cpu_count,
                CAST(ROUND((physical_memory_in_bytes / 1024.0 / 1024.0 / 1024.0 ), 1) AS INT) as physical_memory_GB
            FROM sys.dm_os_sys_info';
			    EXECUTE(@StringToExecute);
    END
ELSE IF SERVERPROPERTY('EngineEdition') IN (5, 6, 7)
    BEGIN
    SELECT COUNT(*) AS cpu_count, 'Unknown' AS physical_memory_GB
      FROM sys.dm_os_schedulers 
      WHERE status = 'VISIBLE ONLINE'
    END
ELSE
    SELECT 'Unknown' AS cpu_count, 'Unknown' AS physical_memory_GB;

CREATE TABLE #AutomaticallyGeneratedNotes (Advice NVARCHAR(4000));

INSERT INTO #AutomaticallyGeneratedNotes (Advice)
	SELECT N'This server was restarted in the last 24 hours. Gather data again when the server has been up for at least one business day because most of the performance and reliability data is erased when the server is restarted.'
	FROM    sys.databases
	WHERE   database_id = 2
		AND CAST(DATEDIFF(hh,create_date,getdate())/24. as numeric (23,2)) < 24;

IF CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100)) LIKE '10%' OR CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100)) LIKE '9%'
	INSERT INTO #AutomaticallyGeneratedNotes (Advice)
	VALUES (N'This version of SQL Server is no longer supported by Microsoft.');

WITH TopWaitType AS (SELECT TOP 1 wait_type, wait_time_ms 
	FROM sys.dm_os_wait_stats 
	WHERE wait_type NOT IN ('BROKER_EVENTHANDLER', 
	'BROKER_RECEIVE_WAITFOR', 
	'BROKER_TASK_STOP', 
	'BROKER_TO_FLUSH', 
	'BROKER_TRANSMITTER', 
	'CHECKPOINT_QUEUE', 
	'CLR_AUTO_EVENT', 
	'CLR_MANUAL_EVENT', 
	'CLR_SEMAPHORE', 
	'DBMIRROR_DBM_EVENT', 
	'DBMIRROR_DBM_MUTEX', 
	'DBMIRROR_EVENTS_QUEUE', 
	'DBMIRROR_WORKER_QUEUE', 
	'DBMIRRORING_CMD', 
	'DIRTY_PAGE_POLL', 
	'DISPATCHER_QUEUE_SEMAPHORE', 
	'FT_IFTS_SCHEDULER_IDLE_WAIT', 
	'FT_IFTSHC_MUTEX', 
	'FT_IFTSISM_MUTEX', 
	'HADR_CLUSAPI_CALL', 
	'HADR_FABRIC_CALLBACK', 
	'HADR_FILESTREAM_IOMGR_IOCOMPLETION', 
	'HADR_LOGCAPTURE_WAIT', 
	'HADR_NOTIFICATION_DEQUEUE', 
	'HADR_TIMER_TASK', 
	'HADR_WORK_QUEUE', 
	'LAZYWRITER_SLEEP', 
	'LOGMGR_QUEUE', 
	'ONDEMAND_TASK_QUEUE', 
	'PARALLEL_REDO_DRAIN_WORKER', 
	'PARALLEL_REDO_LOG_CACHE', 
	'PARALLEL_REDO_TRAN_LIST', 
	'PARALLEL_REDO_TRAN_TURN', 
	'PARALLEL_REDO_WORKER_SYNC', 
	'PARALLEL_REDO_WORKER_WAIT_WORK', 
	'PREEMPTIVE_HADR_LEASE_MECHANISM', 
	'PREEMPTIVE_SP_SERVER_DIAGNOSTICS', 
	'PREEMPTIVE_XE_DISPATCHER', 
	'QDS_ASYNC_QUEUE', 
	'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', 
	'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', 
	'QDS_SHUTDOWN_QUEUE', 
	'REDO_THREAD_PENDING_WORK', 
	'REQUEST_FOR_DEADLOCK_SEARCH', 
	'SLEEP_SYSTEMTASK', 
	'SLEEP_TASK', 
	'SOS_WORK_DISPATCHER', 
	'SP_SERVER_DIAGNOSTICS_SLEEP', 
	'SQLTRACE_BUFFER_FLUSH', 
	'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', 
	'UCS_SESSION_REGISTRATION', 
	'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', 
	'WAITFOR', 
	'XE_DISPATCHER_WAIT', 
	'XE_LIVE_TARGET_TVF', 
	'XE_TIMER_EVENT'
		)
	ORDER BY wait_time_ms DESC
)
SELECT N'Is this perhaps a development or non-production server? It has fairly low wait time, indicating that relatively little workload is happening here.'
FROM    sys.databases db /* needed for system uptime */
	CROSS JOIN TopWaitType tw
WHERE   db.database_id = 2
	AND CAST(DATEDIFF(hh,db.create_date,getdate())/24. as numeric (23,2)) >= 24
	AND tw.wait_time_ms / 100.0 / 60 / 60 <= CAST(DATEDIFF(hh,db.create_date,getdate())/24. as numeric (23,2));

SELECT Advice
	FROM #AutomaticallyGeneratedNotes
	ORDER BY Advice;