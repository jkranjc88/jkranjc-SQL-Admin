DECLARE @StringToExecute NVARCHAR(4000), @TableName NVARCHAR(100);

/********************************* 
Log wait stats at the end of the sample
*********************************/    
/* Azure SQL DB: no direct access to tempdb, so we have to work in the current database */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 8)
    SET @TableName = N'dbo.SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_waits';
ELSE
    SET @TableName = N'tempdb..SQLServerCheckup_2A98B846_4179_496B_AAF8_60B405E3ED68_waits';

SET @StringToExecute = N'
IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL
INSERT  ' + @TableName + N' (batch_id, wait_type, wait_time_ms, waiting_tasks)
    SELECT  2,
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


/* 
What were we waiting on?
This query compares the most recent two samples.
*/
SET @StringToExecute = N'
IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL
SELECT 
    wd2.collection_time AS [Second Sample Time],
    DATEDIFF(ss,wd1.collection_time, wd2.collection_time) AS [Sample Duration in Seconds],
    wd1.wait_type AS [Wait Stat],
    CAST((wd2.wait_time_ms-wd1.wait_time_ms) /1000. AS DECIMAL(38,1)) AS [Wait Time (Seconds)],
    (wd2.waiting_tasks-wd1.waiting_tasks) AS [Number of Waits],
    CASE WHEN (wd2.waiting_tasks-wd1.waiting_tasks) > 0 
    THEN
        CAST((wd2.wait_time_ms-wd1.wait_time_ms)/
            (1.0*(wd2.waiting_tasks-wd1.waiting_tasks)) AS DECIMAL(38,1))
    ELSE 0 END AS [Avg ms Per Wait]
FROM ' + @TableName + N' wd2 
INNER JOIN ' + @TableName + N' wd1 ON
    wd1.wait_type=wd2.wait_type AND
    wd1.batch_id = 1
WHERE wd2.batch_id = 2 AND (wd2.waiting_tasks-wd1.waiting_tasks) > 0
ORDER BY [Wait Time (Seconds)] DESC;'

EXEC(@StringToExecute);

SET @StringToExecute = N'IF OBJECT_ID(''' + @TableName + N''') IS NOT NULL DROP TABLE ' + @TableName;
EXEC(@StringToExecute);


IF 2 = (SELECT COUNT(*) FROM sys.all_objects WHERE name IN ('dm_os_ring_buffers', 'dm_os_sys_info'))
    BEGIN
    SET @StringToExecute = N'DECLARE @ts_now BIGINT;
SELECT @ts_now = ms_ticks FROM sys.dm_os_sys_info;

SELECT CAST(DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS DATETIME) AS Sample_Time,
    record.value(''(Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'', ''int'') AS SQLServer_CPU_Utilization,
    (100 - record.value(''(Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'', ''int'')
         - record.value(''(Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'', ''int'')) AS Other_Process_CPU_Utilization,
    (100 - record.value(''(Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'', ''int'')) AS Total_CPU_Utilization
FROM sys.dm_os_sys_info inf CROSS JOIN (
SELECT timestamp, CONVERT (xml, record) AS record
FROM sys.dm_os_ring_buffers
WHERE ring_buffer_type = ''RING_BUFFER_SCHEDULER_MONITOR''
AND record LIKE ''%<SystemHealth>%'') AS t
ORDER BY record.value(''(Record/@id)[1]'', ''int'');';
    EXEC(@StringToExecute);

    END
ELSE /* Missing DMVs */
    SELECT NULL AS Sample_Time, NULL AS SQLServer_CPU_Utilization, NULL AS Other_Process_CPU_Utilization, NULL AS Total_CPU_Utilization
    WHERE 1 = 0;