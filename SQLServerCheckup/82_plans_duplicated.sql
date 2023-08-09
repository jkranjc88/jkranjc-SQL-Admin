WITH RedundantQueries AS 
        (SELECT TOP 10 query_hash, statement_start_offset, statement_end_offset,
            COUNT(query_hash) AS sort_order,
            COUNT(query_hash) AS PlansCached,
            COUNT(DISTINCT(query_hash)) AS DistinctPlansCached,
            MIN(creation_time) AS FirstPlanCreationTime,
            MAX(creation_time) AS LastPlanCreationTime,
			MAX(s.last_execution_time) AS LastExecutionTime,
            SUM(total_worker_time) AS Total_CPU_ms,
            SUM(total_elapsed_time) AS Total_Duration_ms,
            SUM(total_logical_reads) AS Total_Reads,
            SUM(total_logical_writes) AS Total_Writes,
			SUM(execution_count) AS Total_Executions
            FROM sys.dm_exec_query_stats s
            GROUP BY query_hash, statement_start_offset, statement_end_offset
			HAVING COUNT(query_hash) > 100
            ORDER BY 4 DESC)
SELECT r.query_hash, r.PlansCached, r.DistinctPlansCached, q.SampleQueryText,
        r.Total_Executions, r.Total_CPU_ms, r.Total_Duration_ms, r.Total_Reads, r.Total_Writes,
        r.FirstPlanCreationTime, r.LastPlanCreationTime, r.LastExecutionTime, 
		r.statement_start_offset, r.statement_end_offset, r.sort_order, q.SampleQueryPlan
    FROM RedundantQueries r
    CROSS APPLY (SELECT TOP 3 st.text AS SampleQueryText, qp.query_plan AS SampleQueryPlan, qs.total_elapsed_time
        FROM sys.dm_exec_query_stats qs 
        CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
        CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
        WHERE r.query_hash = qs.query_hash
            AND r.statement_start_offset = qs.statement_start_offset
            AND r.statement_end_offset = qs.statement_end_offset
        ORDER BY qs.total_elapsed_time DESC) q
    ORDER BY r.sort_order DESC, r.query_hash, r.statement_start_offset, r.statement_end_offset, q.total_elapsed_time DESC;