-- Querying the plan cache for plans that have warnings
-- Note that SpillToTempDb warnings are only found in actual execution plans

-- This one is especially useful in SQL Server 2012 and above, where we have many more and 
-- quite useful warnings about the plan execution. Bob Beauchemin wrote a post about those here. 
-- Still, you can use from SQL Server 2005 to 2008R2 to find warnings regarding 
-- ColumnsWithNoStatistics and NoJoinPredicate. 
-- In SQL Server 2012 and above, this can also get warnings such as UnmatchedIndexes (where a 
-- filtered index could not be used due to parameterization) and convert issues (PlanAffectingConvert) 
-- that affect either Cardinality Estimate or the ability to choose a Seek Plan. 
-- Also note that we cannot leverage this type of cache exploration queries to know where 
-- SpillToTempDb warnings occur, as they are only found when we output an actual execution plan, 
-- and not in cached execution plans.

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
 WarningSearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, wn.query('.') AS StmtSimple, cp.plan_handle
      FROM sys.dm_exec_cached_plans cp (NOLOCK)
      CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
      CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(wn)
      WHERE wn.exist('//Warnings') = 1
       AND wn.exist('@QueryHash') = 1
      )
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
 StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
 c1.value('@NodeId','int') AS node_id,
 c1.value('@PhysicalOp','sysname') AS physical_op,
 c1.value('@LogicalOp','sysname') AS logical_op,
 CASE WHEN c2.exist('@NoJoinPredicate[. = "1"]') = 1 THEN 'NoJoinPredicate' 
  WHEN c3.exist('@Database') = 1 THEN 'ColumnsWithNoStatistics' END AS warning,
 ws.objtype,
 ws.usecounts,
 ws.query_plan,
 StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
 StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
 StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
 c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
 StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
 StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
 ws.plan_handle
FROM WarningSearch ws
CROSS APPLY StmtSimple.nodes('//RelOp') AS q1(c1)
CROSS APPLY c1.nodes('./Warnings') AS q2(c2)
OUTER APPLY c2.nodes('./ColumnsWithNoStatistics/ColumnReference') AS q3(c3)
UNION ALL
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
 StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
 c3.value('@NodeId','int') AS node_id,
 c3.value('@PhysicalOp','sysname') AS physical_op,
 c3.value('@LogicalOp','sysname') AS logical_op,
 CASE WHEN c2.exist('@UnmatchedIndexes[. = "1"]') = 1 THEN 'UnmatchedIndexes' 
  WHEN (c4.exist('@ConvertIssue[. = "Cardinality Estimate"]') = 1 OR c4.exist('@ConvertIssue[. = "Seek Plan"]') = 1) 
  THEN 'ConvertIssue_' + c4.value('@ConvertIssue','sysname') END AS warning,
 ws.objtype,
 ws.usecounts,
 ws.query_plan,
 StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
 StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
 StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
 c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
 StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
 StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
 ws.plan_handle
FROM WarningSearch ws
CROSS APPLY StmtSimple.nodes('//QueryPlan') AS q1(c1)
CROSS APPLY c1.nodes('./Warnings') AS q2(c2)
CROSS APPLY c1.nodes('./RelOp') AS q3(c3)
OUTER APPLY c2.nodes('./PlanAffectingConvert') AS q4(c4)
order by usecounts desc
OPTION(RECOMPILE, MAXDOP 1); 
GO