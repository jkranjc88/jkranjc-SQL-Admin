WITH 
overall_waits AS (
    SELECT  cast(100* SUM(CAST(CONVERT(BIGINT, signal_wait_time_ms) AS NUMERIC(38,1)))
                / SUM(CONVERT(BIGINT, wait_time_ms)) AS NUMERIC(38,0)) AS percent_signal_waits
    FROM    sys.dm_os_wait_stats os),
uptime AS (
    SELECT  DATEDIFF(HH, create_date, CURRENT_TIMESTAMP) AS hours_since_startup
    FROM    sys.databases
    WHERE   name='tempdb'
)
SELECT  percent_signal_waits AS [% Signal Waits],
        hours_since_startup AS [Hours Since Startup],
        CAST(hours_since_startup / 24. AS NUMERIC(38,1)) AS [Days Since Startup]
FROM    overall_waits o
LEFT OUTER JOIN uptime u ON 1 = 1;

