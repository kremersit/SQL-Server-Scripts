-- Querying the plan cache for specific implicit conversions

-- Implicit conversions are “evil”. Now that I got that out, let me tell you why it is good to look for these, 
-- and code in such a way that we can get rid of them. 
-- An implicit conversion will have an overhead in your code execution because it will cause CPU cycles to be wasted, 
-- and may also limit the query optimizer to make the most appropriate choices when coming up with the execution plan. 
-- This is mostly because the optimizer will not be able to do correct cardinality estimations, and with that, it will 
-- leverage scans where seeks would be more suitable (this is a generalization). Just look at the following example 
-- that will illustrate what I’m saying:

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
 Convertsearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, cp.plan_handle, cs.query('.') AS StmtSimple
     FROM sys.dm_exec_cached_plans cp (NOLOCK)
     CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
     CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(cs)
     WHERE cp.cacheobjtype = 'Compiled Plan' 
       AND cs.exist('@QueryHash') = 1
       AND cs.exist('.//ScalarOperator[contains(@ScalarString, "CONVERT_IMPLICIT")]') = 1
       AND cs.exist('.[contains(@StatementText, "Convertsearch")]') = 0
     )
SELECT c2.value('@StatementText', 'VARCHAR(4000)') AS sql_text,
 c2.value('@StatementId', 'int') AS StatementId,
 c3.value('@ScalarString[1]','VARCHAR(4000)') AS expression,
 ss.usecounts,
 ss.query_plan,
 StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
 StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
 StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
 c2.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
 StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
 StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
 ss.plan_handle
FROM Convertsearch ss
CROSS APPLY query_plan.nodes('//StmtSimple') AS q2(c2)
CROSS APPLY c2.nodes('.//ScalarOperator[contains(@ScalarString, "CONVERT_IMPLICIT")]') AS q3(c3)
OPTION(RECOMPILE, MAXDOP 1); 
GO