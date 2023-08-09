DECLARE @cpu_ms_since_startup DECIMAL (38, 0), @hours_since_startup DECIMAL(38, 1), @StringToExecute NVARCHAR(4000);

IF SERVERPROPERTY('EngineEdition') IN (5, 6, 7)
    BEGIN
    WITH schedulers AS (SELECT COUNT(*) AS cpu_count FROM sys.dm_os_schedulers WHERE status = 'VISIBLE ONLINE'),
         system_waits AS (SELECT AVG(wait_time_ms) wait_time_ms FROM sys.dm_os_wait_stats WHERE  wait_type IN ('DIRTY_PAGE_POLL','HADR_FILESTREAM_IOMGR_IOCOMPLETION','LAZYWRITER_SLEEP','LOGMGR_QUEUE','REQUEST_FOR_DEADLOCK_SEARCH','XE_DISPATCHER_WAIT','XE_TIMER_EVENT'))
    SELECT  TOP 1 @hours_since_startup = AVG(w.wait_time_ms) / 3600000.0,
            @cpu_ms_since_startup = (AVG(w.wait_time_ms) * s.cpu_count)
    FROM schedulers s, system_waits w
    GROUP BY s.cpu_count
    END
ELSE
    BEGIN
    SET @StringToExecute = N'WITH cpu_count AS (
        SELECT cpu_count
        FROM sys.dm_os_sys_info
    ), 
    uptime AS (
        SELECT  DATEDIFF(MI, create_date, CURRENT_TIMESTAMP) / 60.0 AS hours_since_startup
        FROM    sys.databases
        WHERE   name=''tempdb''
    )
    SELECT  TOP 1 @hours_since_startup = hours_since_startup,
            @cpu_ms_since_startup = CAST(hours_since_startup AS DECIMAL(38,0)) * 3600000 * cpu_count
    FROM    uptime, cpu_count;'

    EXEC sp_executesql @StringToExecute, N'@cpu_ms_since_startup DECIMAL(38, 0) OUTPUT, @hours_since_startup DECIMAL(38,1) OUTPUT', @cpu_ms_since_startup = @cpu_ms_since_startup OUTPUT, @hours_since_startup = @hours_since_startup OUTPUT;
    END;

SELECT
        os.wait_type AS [Wait Stat], 
        SUM(CONVERT(BIGINT, os.wait_time_ms) / 1000.0 / 60 / 60) OVER (PARTITION BY os.wait_type) AS [Total Hours of Wait],
        100.0 * (SUM(CONVERT(BIGINT, os.wait_time_ms)) OVER (PARTITION BY os.wait_type) / NULLIF((@cpu_ms_since_startup), 0)) AS [Wait % of CPU Time] ,
        CAST(
            100.* SUM(CONVERT(BIGINT, os.wait_time_ms)) OVER (PARTITION BY os.wait_type) 
            / NULLIF((1. * SUM(CONVERT(BIGINT, os.wait_time_ms)) OVER () ), 0)
            AS DECIMAL(38,1)) AS [% of Total Waits],
        CAST(
            100. * SUM(CONVERT(BIGINT, os.signal_wait_time_ms)) OVER (PARTITION BY os.wait_type) 
            / NULLIF((1. * SUM(CONVERT(BIGINT, os.wait_time_ms)) OVER ()), 0)
            AS DECIMAL(38,1)) AS [% Signal Wait],
        SUM(CONVERT(BIGINT, os.waiting_tasks_count)) OVER (PARTITION BY os.wait_type) AS [Waiting Tasks Count],
        CASE WHEN  SUM(CONVERT(BIGINT, os.waiting_tasks_count)) OVER (PARTITION BY os.wait_type) > 0
        THEN
            CAST(
                SUM(CONVERT(BIGINT, os.wait_time_ms)) OVER (PARTITION BY os.wait_type)
                    / NULLIF((1. * SUM(CONVERT(BIGINT, os.waiting_tasks_count)) OVER (PARTITION BY os.wait_type)), 0)
                AS DECIMAL(38,1))
        ELSE 0 END AS [Avg ms Per Wait],
        CURRENT_TIMESTAMP AS [Sample Time],
        @hours_since_startup AS [Hours Since Reset]
FROM    sys.dm_os_wait_stats os
WHERE   os.wait_time_ms > 0
    AND   os.wait_type NOT IN ('BROKER_EVENTHANDLER',
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
            'XE_TIMER_EVENT')
ORDER BY SUM(CONVERT(BIGINT, os.wait_time_ms) / 1000.0 / 60 / 60) OVER (PARTITION BY os.wait_type) DESC;