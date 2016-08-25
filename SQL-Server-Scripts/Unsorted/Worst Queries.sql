
-- Worst performing CPU bound queries
SELECT TOP 25
'Worst CPU', 
	st.text,
	qp.query_plan,
  total_worker_time / qs.execution_count  * 1.0,
	qs.*
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY 4 desc --total_worker_time DESC
GO

-- Worst performing I/O bound queries
SELECT TOP 25
'Worst I/O', 
	st.text,
	qp.query_plan,
	qs.*
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY total_logical_reads DESC
GO