--  Querying the plan cache for plans that use parallelism and their cost
--  The next few retrieve information about query plans that use parallelism.

--  DISCLAIMER: Although I refer to the Cost Threshold for Parallelism in the next example, I do not advise to change 
--  this value just because you might have read somewhere that the default value is low. If you are not having 
--  an issue that might warrant changes, there’s really no need to change this setting.

--  The above being said, let’s say we want to tune the Cost Threshold for Parallelism in your OLTP system. 
--  Would you just guess which value you would configure? 
--  Or would you prefer to make an informed decision based on actual query costs in your system?

--  Most reasonable people would choose the second, and the next xquery allows us to list costs for 
--  cached query plans that are using parallelism.

 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
 WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
 ParallelSearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, ix.query('.') AS StmtSimple, cp.plan_handle
      FROM sys.dm_exec_cached_plans cp (NOLOCK)
      CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
      CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ix)
      WHERE ix.exist('//RelOp[@Parallel = "1"]') = 1
       AND ix.exist('@QueryHash') = 1
      )
 SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
 ps.plan_handle,
 ps.objtype,
 ps.usecounts,
 StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
 ps.query_plan,
 StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
 StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
 c1.value('@CachedPlanSize','sysname') AS CachedPlanSize,
 c2.value('@SerialRequiredMemory','sysname') AS SerialRequiredMemory,
 c2.value('@SerialDesiredMemory','sysname') AS SerialDesiredMemory,
 c3.value('@EstimatedAvailableMemoryGrant','sysname') AS EstimatedAvailableMemoryGrant,
 c3.value('@EstimatedPagesCached','sysname') AS EstimatedPagesCached,
 c3.value('@EstimatedAvailableDegreeOfParallelism','sysname') AS EstimatedAvailableDegreeOfParallelism,
 StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
 StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash
FROM ParallelSearch ps
CROSS APPLY StmtSimple.nodes('//QueryPlan') AS q1(c1)
CROSS APPLY c1.nodes('.//MemoryGrantInfo') AS q2(c2)
CROSS APPLY c1.nodes('.//OptimizerHardwareDependentProperties') AS q3(c3)
ORDER BY 5 DESC
OPTION(RECOMPILE, MAXDOP 1); 
GO