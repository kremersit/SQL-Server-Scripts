-- Querying the plan cache for plans that use parallelism, and worker time > elapsed time, with more details
-- The above can be completed with more details, such as below:

-- Querying the plan cache for plans that use parallelism, and worker time > elapsed time and more detailed output
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
    ParallelSearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, qs.[total_worker_time], qs.[total_elapsed_time], qs.[execution_count],
                            ix.query('.') AS StmtSimple, cp.plan_handle
                        FROM sys.dm_exec_cached_plans cp (NOLOCK)
                        INNER JOIN sys.dm_exec_query_stats qs (NOLOCK) ON cp.plan_handle = qs.plan_handle
                        CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
                        CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ix)
                        WHERE cp.cacheobjtype = 'Compiled Plan' 
                            AND ix.exist('//RelOp[@Parallel = "1"]') = 1
                            AND ix.exist('@QueryHash') = 1
                            AND (qs.[total_worker_time]/qs.[execution_count]) > (qs.[total_elapsed_time]/qs.[execution_count])
                        )
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
    StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
    c1.value('@NodeId','int') AS node_id,
    c2.value('@Database','sysname') AS database_name,
    c2.value('@Schema','sysname') AS [schema_name],
    c2.value('@Table','sysname') AS table_name,
    c2.value('@Index','sysname') AS [index],
    c2.value('@IndexKind','sysname') AS index_type,
    c1.value('@PhysicalOp','sysname') AS physical_op,
    c1.value('@LogicalOp','sysname') AS logical_op,
    c1.value('@TableCardinality','sysname') AS table_cardinality,
    c1.value('@EstimateRows','sysname') AS estimate_rows,
    c1.value('@AvgRowSize','sysname') AS avg_row_size,
    ps.objtype,
    ps.usecounts,
    ps.[total_worker_time]/ps.[execution_count] AS avg_worker_time,
    ps.[total_elapsed_time]/ps.[execution_count] As avg_elapsed_time,
    ps.query_plan,
    StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
    StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
    StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
    c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
    StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
    StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
    ps.plan_handle
FROM ParallelSearch ps
CROSS APPLY StmtSimple.nodes('//Parallelism//RelOp') AS q1(c1)
OUTER APPLY c1.nodes('.//IndexScan/Object') AS q2(c2)
WHERE c1.value('@Parallel','int') = 1
    AND (c1.exist('@PhysicalOp[. = "Index Scan"]') = 1
    OR c1.exist('@PhysicalOp[. = "Clustered Index Scan"]') = 1
    OR c1.exist('@PhysicalOp[. = "Index Seek"]') = 1
    OR c1.exist('@PhysicalOp[. = "Clustered Index Seek"]') = 1
    OR c1.exist('@PhysicalOp[. = "Table Scan"]') = 1)
    AND c2.value('@Schema','sysname') <> '[sys]'
OPTION(RECOMPILE, MAXDOP 1); 
GO