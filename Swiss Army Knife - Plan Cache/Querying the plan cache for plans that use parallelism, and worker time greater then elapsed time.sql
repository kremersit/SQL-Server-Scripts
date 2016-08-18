-- Querying the plan cache for plans that use parallelism, and worker time > elapsed time
-- One of the ways to find inefficient query plans in an OLTP environment is to look for parallel plans 
-- that use more scheduler time than the elapsed time it took to run a query. Although this is not always 
-- the case, looking for such patterns might allow us to identify opportunities to fix queries 
-- where parallelism is not being used to the workloads benefit.

-- Querying the plan cache for plans that use parallelism, and worker time > elapsed time
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
    ParallelSearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, qs.[total_worker_time], 
                            qs.[total_elapsed_time], qs.[execution_count],
                            ix.query('.') AS StmtSimple, cp.plan_handle
                        FROM sys.dm_exec_cached_plans cp (NOLOCK)
                        INNER JOIN sys.dm_exec_query_stats qs (NOLOCK) ON cp.plan_handle = qs.plan_handle
                        CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
                        CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ix)
                        WHERE cp.cacheobjtype = 'Compiled Plan' 
                            AND ix.exist('//RelOp[@Parallel = "1"]') = 1
                            AND ix.exist('@QueryHash') = 1
                            AND (qs.[total_worker_time]/qs.[execution_count]) > 
                                (qs.[total_elapsed_time]/qs.[execution_count])
                        )
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
    ps.objtype,
    ps.usecounts,
    ps.[total_worker_time]/ps.[execution_count] AS avg_worker_time,
    ps.[total_elapsed_time]/ps.[execution_count] As avg_elapsed_time,
    ps.query_plan,
    StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
    StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
    StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
    StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
    StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
    ps.plan_handle
FROM ParallelSearch ps
CROSS APPLY StmtSimple.nodes('//RelOp[1]') AS q1(c1)
WHERE c1.value('@Parallel','int') = 1 AND c1.value('@NodeId','int') = 0
OPTION(RECOMPILE, MAXDOP 1); 
GO