-- Querying the plan cache for index usage (change @IndexName below)


-- Using the missing index xquery in the previous post, let’s say we found an index that has great potential, 
-- and after we create it, we want to see where it is being used – perhaps it is even being used in other queries.
-- So, this one will allow you to search for usage information about a specific index. This can of course 
-- be achieved by other means other than an xquery, but in this fashion we get many useful information such as 
-- the type of operators in which indexes are used, predicates used and estimations.

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IndexName sysname = 'IX_TestSearchIndex';

SET @IndexName = QUOTENAME(@IndexName,'[');
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
    IndexSearch AS (SELECT qp.query_plan, cp.usecounts, ix.query('.') AS StmtSimple, cp.plan_handle
                    FROM sys.dm_exec_cached_plans cp (NOLOCK)
                    CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
                    CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ix)
                    WHERE cp.cacheobjtype = 'Compiled Plan' 
                        AND ix.exist('//Object[@Index = sql:variable("@IndexName")]') = 1 
                    )
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
    c2.value('@Database','sysname') AS database_name,
    c2.value('@Schema','sysname') AS [schema_name],
    c2.value('@Table','sysname') AS table_name,
    c2.value('@Index','sysname') AS index_name,
    c1.value('@PhysicalOp','NVARCHAR(50)') as physical_operator,
    c3.value('@ScalarString[1]','VARCHAR(4000)') AS predicate,
    c4.value('@Column[1]','VARCHAR(256)') AS seek_columns,
    c1.value('@EstimateRows','sysname') AS estimate_rows,
    c1.value('@AvgRowSize','sysname') AS avg_row_size,
    ixs.query_plan,
    StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
    StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
    StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
    c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
    StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
    StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
    ixs.plan_handle
FROM IndexSearch ixs
CROSS APPLY StmtSimple.nodes('//RelOp') AS q1(c1)
CROSS APPLY c1.nodes('IndexScan/Object[@Index = sql:variable("@IndexName")]') AS q2(c2)
OUTER APPLY c1.nodes('IndexScan/Predicate/ScalarOperator') AS q3(c3)
OUTER APPLY c1.nodes('IndexScan/SeekPredicates/SeekPredicateNew//ColumnReference') AS q4(c4)
OPTION(RECOMPILE, MAXDOP 1); 
GO