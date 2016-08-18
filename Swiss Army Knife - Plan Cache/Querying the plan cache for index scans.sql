-- Querying the plan cache for index scans

--  This one will allow you to find where we are doing index scans. Why is this important? As you might know, 
--  scans are not always a bad thing, namely if you are not being narrow enough in your search arguments 
--  (if any), where a scan may be cheaper than a few hundred or thousand seeks. You can read more on a post I
--  did some time ago, regarding a case of seeks and scans. 
--  The following code is most useful by allowing you to identify where scans are happening on tables with a 
--  high cardinality, and even look directly at the predicate for any tuning you might do on it.

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
 Scansearch AS (SELECT qp.query_plan, cp.usecounts, ss.query('.') AS StmtSimple, cp.plan_handle
     FROM sys.dm_exec_cached_plans cp (NOLOCK)
     CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
     CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ss)
     WHERE cp.cacheobjtype = 'Compiled Plan'
      AND (ss.exist('//RelOp[@PhysicalOp = "Index Scan"]') = 1
        OR ss.exist('//RelOp[@PhysicalOp = "Clustered Index Scan"]') = 1)
      AND ss.exist('@QueryHash') = 1
     )
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
 StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
 c1.value('@NodeId','int') AS node_id,
 c2.value('@Database','sysname') AS database_name,
 c2.value('@Schema','sysname') AS [schema_name],
 c2.value('@Table','sysname') AS table_name,
 c1.value('@PhysicalOp','sysname') as physical_operator, 
 c2.value('@Index','sysname') AS index_name,
 c3.value('@ScalarString[1]','VARCHAR(4000)') AS predicate,
 c1.value('@TableCardinality','sysname') AS table_cardinality,
 c1.value('@EstimateRows','sysname') AS estimate_rows,
 c1.value('@AvgRowSize','sysname') AS avg_row_size,
 ss.usecounts,
 ss.query_plan,
 StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
 StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
 StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
 c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
 StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
 StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
 ss.plan_handle
FROM Scansearch ss
CROSS APPLY query_plan.nodes('//RelOp') AS q1(c1)
CROSS APPLY c1.nodes('./IndexScan/Object') AS q2(c2)
OUTER APPLY c1.nodes('./IndexScan/Predicate/ScalarOperator[1]') AS q3(c3)
WHERE (c1.exist('@PhysicalOp[. = "Index Scan"]') = 1
  OR c1.exist('@PhysicalOp[. = "Clustered Index Scan"]') = 1)
 AND c2.value('@Schema','sysname') <> '[sys]'
OPTION(RECOMPILE, MAXDOP 1); 
GO