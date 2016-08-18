-- Querying the plan cache for parameterization
-- Has I said before, I use some of these queries in PTO Clinic engagements. As part of the Clinic, 
-- we capture workload in production and replay it in a test server. As such, we need to get values to run 
-- parameterized queries, and while we can get to those values by other means, I am especially keen on 
-- using the values in which a plan was compiled. 
-- This is also useful if you suspect you might be experiencing a parameter sniffing issue, and want to 
-- quickly list the parameterized values in query plans.
-- The xquery below gets us just that:

-- Querying the plan cache for parameterization

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
    PlanParameters AS (SELECT cp.plan_handle, qp.query_plan, qp.dbid, qp.objectid
                        FROM sys.dm_exec_cached_plans cp (NOLOCK)
                        CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
                        WHERE qp.query_plan.exist('//ParameterList')=1
                            AND cp.cacheobjtype = 'Compiled Plan'
                        )
SELECT QUOTENAME(DB_NAME(pp.dbid)) AS database_name,
    ISNULL(OBJECT_NAME(pp.objectid, pp.dbid), 'No_Associated_Object') AS [object_name],
    c2.value('(@Column)[1]','sysname') AS parameter_name,
    c2.value('(@ParameterCompiledValue)[1]','VARCHAR(max)') AS parameter_compiled_value,
    pp.query_plan,
    pp.plan_handle
FROM PlanParameters pp
CROSS APPLY query_plan.nodes('//ParameterList') AS q1(c1)
CROSS APPLY c1.nodes('ColumnReference') as q2(c2)
WHERE pp.dbid > 4 AND pp.dbid < 32767
OPTION(RECOMPILE, MAXDOP 1); 
GO