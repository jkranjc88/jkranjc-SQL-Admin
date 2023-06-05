SELECT * FROM sys.dm_os_waiting_tasks
WHERE resource_description IN ('2:1:1','2:1:2','2:1:3')
AND wait_type Like 'PAGE%LATCH_%'

SELECT transaction_id ,
 database_transaction_begin_time ,
 DATEDIFF(SECOND, database_transaction_begin_time, GETDATE()) AS 'Transaction Time(Seconds)',
 CASE database_transaction_type
 WHEN 1 THEN 'Read/write'
 WHEN 2 THEN 'Read-only'
 WHEN 3 THEN 'System'
 END AS 'Type',
 CASE database_transaction_state
 WHEN 1 THEN 'The transaction has not been initialized.'
 WHEN 2 THEN 'The transaction is active.'
 WHEN 3 THEN 'The transaction has been initialized but has not generated any log records.'
 WHEN 4 THEN 'The transaction has generated log records.'
 WHEN 5 THEN 'The transaction has been prepared.'
 WHEN 10 THEN 'The transaction has been committed.'
 WHEN 11 THEN 'The transaction has been rolled back.'
 WHEN 12 THEN 'The transaction is being committed. In this state the log record is being generated, but it has not been materialized or persisted.'
 END AS 'Description',
 database_transaction_log_record_count AS [Number of Log Records],
 database_transaction_begin_lsn,
 database_transaction_last_lsn,
 database_transaction_most_recent_savepoint_lsn,
 database_transaction_commit_lsn
FROM sys.dm_tran_database_transactions
WHERE database_id = 2


SELECT TST.session_id AS [Session Id],
 EST.[text] AS [SQL Query Text], [statement] = COALESCE(NULLIF(
 SUBSTRING(
 EST.[text],
 ER.statement_start_offset / 2,
 CASE WHEN ER.statement_end_offset < ER.statement_start_offset
 THEN 0
 ELSE( ER.statement_end_offset - ER.statement_start_offset ) / 2 END
 ), ''
 ), EST.[text]),
 DBT.database_transaction_log_bytes_reserved AS [DB Transaction Log byte reserved]
 , ER.Status
 ,CASE ER.TRANSACTION_ISOLATION_LEVEL
 WHEN 0 THEN 'UNSPECIFIED'
 WHEN 1 THEN 'READUNCOMITTED'
 WHEN 2 THEN 'READCOMMITTED'
 WHEN 3 THEN 'REPEATABLE'
 WHEN 4 THEN 'SERIALIZABLE'
 WHEN 5 THEN 'SNAPSHOT'
 ELSE CAST(ER.TRANSACTION_ISOLATION_LEVEL AS VARCHAR(32))
 END AS [Isolation Level Name],
 QP.QUERY_PLAN AS [XML Query Plan]
FROM
 sys.dm_tran_database_transactions AS DBT
 INNER JOIN sys.dm_tran_session_transactions AS TST
 ON DBT.transaction_id = TST.transaction_id
 LEFT OUTER JOIN sys.dm_exec_requests AS ER
 ON TST.session_id = ER.session_id
 OUTER APPLY sys.dm_exec_sql_text(ER.plan_handle) AS EST
 CROSS APPLY SYS.DM_EXEC_QUERY_PLAN(ER.PLAN_HANDLE) QP
WHERE DBT.database_id = 2;