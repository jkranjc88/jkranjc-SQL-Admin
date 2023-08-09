/********************************* 
Clear out past runs.
*********************************/
DECLARE @StringToExecute NVARCHAR(4000), @TableName NVARCHAR(100);

/* Azure SQL DB: no direct access to tempdb, so we have to work in the current database */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @TableName = N'dbo.SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_deep_dive';
ELSE
    SET @TableName = N'tempdb..SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_deep_dive';

SET @StringToExecute = N'IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL 
        DROP TABLE ' + @TableName + N';';
EXEC(@StringToExecute);


/********************************* 
Log wait stats at the start of the sample
*********************************/    
/* Azure SQL DB: no direct access to tempdb, so we have to work in the current database */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @TableName = N'dbo.SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_waits';
ELSE
    SET @TableName = N'tempdb..SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_waits';

SET @StringToExecute = N'IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL 
        DROP TABLE ' + @TableName + N';

    CREATE TABLE ' + @TableName + N'(batch_id INT NOT NULL ,
	collection_time DATETIME NOT NULL DEFAULT GETDATE() ,
    wait_type NVARCHAR(256) NOT NULL ,
    wait_time_ms BIGINT NOT NULL ,
    waiting_tasks BIGINT NOT NULL
);

    INSERT  ' + @TableName + N' (batch_id, wait_type, wait_time_ms, waiting_tasks)
    SELECT  1,
            os.wait_type, 
            SUM(os.wait_time_ms) OVER (PARTITION BY os.wait_type) AS sum_wait_time_ms, 
            SUM(os.waiting_tasks_count) OVER (PARTITION BY os.wait_type) AS sum_waiting_tasks
    FROM    sys.dm_os_wait_stats os
    WHERE   os.wait_type NOT IN (''BROKER_EVENTHANDLER''
, ''BROKER_RECEIVE_WAITFOR''
, ''BROKER_TASK_STOP''
, ''BROKER_TO_FLUSH''
, ''BROKER_TRANSMITTER''
, ''CHECKPOINT_QUEUE''
, ''DBMIRROR_DBM_EVENT''
, ''DBMIRROR_DBM_MUTEX''
, ''DBMIRROR_EVENTS_QUEUE''
, ''DBMIRROR_WORKER_QUEUE''
, ''DBMIRRORING_CMD''
, ''DIRTY_PAGE_POLL''
, ''DISPATCHER_QUEUE_SEMAPHORE''
, ''FT_IFTS_SCHEDULER_IDLE_WAIT''
, ''FT_IFTSHC_MUTEX''
, ''HADR_CLUSAPI_CALL''
, ''HADR_FILESTREAM_IOMGR_IOCOMPLETION''
, ''HADR_LOGCAPTURE_WAIT''
, ''HADR_NOTIFICATION_DEQUEUE''
, ''HADR_TIMER_TASK''
, ''HADR_WORK_QUEUE''
, ''LAZYWRITER_SLEEP''
, ''LOGMGR_QUEUE''
, ''ONDEMAND_TASK_QUEUE''
, ''PREEMPTIVE_HADR_LEASE_MECHANISM''
, ''PREEMPTIVE_SP_SERVER_DIAGNOSTICS''
, ''QDS_ASYNC_QUEUE''
, ''QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP''
, ''QDS_PERSIST_TASK_MAIN_LOOP_SLEEP''
, ''QDS_SHUTDOWN_QUEUE''
, ''REDO_THREAD_PENDING_WORK''
, ''REQUEST_FOR_DEADLOCK_SEARCH''
, ''SLEEP_SYSTEMTASK''
, ''SLEEP_TASK''
, ''SP_SERVER_DIAGNOSTICS_SLEEP''
, ''SQLTRACE_BUFFER_FLUSH''
, ''SQLTRACE_INCREMENTAL_FLUSH_SLEEP''
, ''UCS_SESSION_REGISTRATION''
, ''WAIT_XTP_OFFLINE_CKPT_NEW_LOG''
, ''WAITFOR''
, ''XE_DISPATCHER_WAIT''
, ''XE_LIVE_TARGET_TVF''
, ''XE_TIMER_EVENT'');';

EXEC(@StringToExecute);







/* Azure SQL DB: no direct access to tempdb, so we have to work in the current database */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @TableName = N'dbo.SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_perfmon';
ELSE
    SET @TableName = N'tempdb..SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_perfmon';

SET @StringToExecute = N'IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL 
        DROP TABLE ' + @TableName + N';

    CREATE TABLE ' + @TableName + N'([batch_id] TINYINT NOT NULL ,
		[collection_time] DATETIME NOT NULL DEFAULT GETDATE() ,
		[object_name] VARCHAR(128) NOT NULL ,
		[counter_name] VARCHAR(128) NOT NULL ,
		[instance_name] VARCHAR(128) NULL ,
		[cntr_value] BIGINT NOT NULL,
        [cntr_type] BIGINT NOT NULL
	);

/*Collect first sample.*/
INSERT  ' + @TableName + N' ( [batch_id] , [object_name] , [counter_name] , [instance_name] , [cntr_value], [cntr_type] )
		SELECT  1 AS [batch_id] ,
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
