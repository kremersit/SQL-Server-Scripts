/*
The graphical "Execution Plan" is a great help to analyse the query execution path to find performance issues.
But for complexe queries you'll get large confusing plans and it's not very handy to get detail information;
 you either have to hover with the mouse over a node or you have to open the "Property" window and mark the node of your interest.

The "SET SHOWPLAN_TEXT ON" option gives a brief overview of the execution path, but it contains to less information.

The "SET SHOWPLAN_ALL ON" option gives also a brief overview with more detailed informations.
Similar to SHOWPLAN_ALL, this Transact-SQL script queries the same common information for all nodes as a list from the XML data of a cached query plan (sys.dm_exec_query_plan).
With this you can start analysing queries by starting with an overview and dig deeper into the single execution node.
And: You can advance/modify this script to get further specialiced detail information of the different node types.

Remark:
  Please modify the first query to get the handle for the plan of your interest.

Note:
  The xml data of the cached query plans is not indexed in the DMV, therefore the query can run up to several minutes.

Works with SQL Server 2005 and higher versions in all editions.
Requires VIEW SERVER STATE permissions.

Links:
  MSDN SET SHOWPLAN_TEXT: http://msdn.microsoft.com/en-us/library/aa259226.aspx
  MSDN SET SHOWPLAN_ALL:  http://msdn.microsoft.com/en-us/library/aa259203.aspx
*/

-- SHOWPLAN_ALL-like Query for a Cached Query Plan.

-- Get the handle of the plan of your interest.
DECLARE @plan_handle varbinary(64);

-- Please modify the first query to get the handle for the plan of your interest !!!
-- Select e.g. from query stats ...
SET @plan_handle = (SELECT TOP 1 EQS.plan_handle FROM sys.dm_exec_query_stats AS EQS ORDER BY EQS.total_worker_time DESC);
-- or define a know handle plan
SET @plan_handle = 0x05001500BF266E0EB801F617000000000000000000000000;


-- First select the ShowPlan to compare; click on the link to open the graphical execution plan.
SELECT EQP.query_plan AS QueryPlan_ClickLinkToOpen
FROM sys.dm_exec_query_plan(@plan_handle) AS EQP;


-- Select the SQL statements included in the batch with statistic information.
;WITH
 XMLNAMESPACES
    (DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
            ,N'http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS ShowPlan)
,Stmt AS
   (SELECT Stmt.node.value(N'@StatementId[1]', N'int') AS StmtId
          ,ISNULL(Stmt.node.value(N'@StatementSubTreeCost[1]', N'float'), 0.0) AS StmtSubTreeCost
          ,Stmt.node.value(N'@StatementEstRows[1]', N'float') AS StmtEstRows
          ,Stmt.node.value(N'@StatementOptmLevel[1]',  N'nvarchar(100)') AS StmtOptmLevel
          ,Stmt.node.value(N'@StatementOptmEarlyAbortReason[1]',  N'nvarchar(100)') AS StmtOptmAbort
          ,Stmt.node.value(N'@StatementType[1]',  N'nvarchar(100)') AS StmtType
          ,ISNULL(Stmt.node.value(N'(//*/QueryPlan/@DegreeOfParallelism)[1]', N'int'), 0) AS Parallel
          ,Stmt.node.value(N'count(//*/QueryPlan/MissingIndexes/MissingIndexGroup)', 'int') AS MissIdx
          ,Stmt.node.value(N'(//*/QueryPlan/@CachedPlanSize)[1]', N'int') AS PlanSize
          ,Stmt.node.value(N'(//*/QueryPlan/@CompileTime)[1]', N'int') AS CmplTime
          ,Stmt.node.value(N'(//*/QueryPlan/@CompileCPU)[1]', N'int') AS CmplCPU
          ,Stmt.node.value(N'(//*/QueryPlan/@CompileMemory)[1]', N'int') AS CmplMem
          ,Stmt.node.value(N'@StatementText[1]', N'nvarchar(max)') AS StmtText
    FROM sys.dm_exec_query_plan(@plan_handle) AS EQP
         CROSS APPLY EQP.[query_plan].nodes(N'/ShowPlanXML/BatchSequence/Batch/Statements/*') AS Stmt(node))
SELECT *
FROM Stmt
ORDER BY Stmt.StmtId;


-- Now split the xml data into separate nodes.
;WITH
 XMLNAMESPACES
    (DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
            ,N'http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS ShowPlan)
,RelOp AS
    (SELECT Stmt.node.value(N'@StatementId[1]', N'int') AS [StatementId]
           ,ISNULL(Stmt.node.value(N'@StatementSubTreeCost[1]', N'float'), 0.0) AS [StatementSubTreeCost]
           ,RelOp.node.value(N'@NodeId[1]', N'int') AS [NodeId]
           ,RelOp.node.value(N'../../@NodeId[1]', N'int') AS [ParentNodeId]
           ,RelOp.node.value(N'@PhysicalOp[1]', N'varchar(255)') AS [PhysicalOp]
           ,RelOp.node.value(N'@LogicalOp[1]', N'varchar(255)') AS [LogicalOp]
           ,RelOp.node.value(N'@EstimateRows[1]', N'float') AS [EstRows]
           ,RelOp.node.value(N'@AvgRowSize[1]', N'float') AS [AvgRowSize]
           ,CONVERT(decimal(38, 3)
                   ,RelOp.node.value(N'@EstimateRows[1]', N'float')
                    * RelOp.node.value(N'@AvgRowSize[1]', N'float') / 1024) AS [AvgSize KB]
           ,CONVERT(decimal(38, 7)
                   ,RelOp.node.value(N'@EstimateIO[1]', N'float')) AS [EstIO]
           ,CONVERT(decimal(38, 7)
                   ,RelOp.node.value(N'@EstimateCPU[1]', N'float')) AS [EstCPU]
           ,CONVERT(decimal(38, 7)
                   ,RelOp.node.value(N'@EstimateIO[1]', N'float')
                    + RelOp.node.value(N'@EstimateCPU[1]', N'float')) AS [EstNodeCost]
           ,CONVERT(decimal(38, 7)
                   ,RelOp.node.value(N'@EstimatedTotalSubtreeCost[1]', N'float')) AS [EstSubtreeCost]
           ,RelOp.node.value(N'@Parallel[1]', N'int') AS [Parallel]
           ,RelOp.node.value(N'@EstimateRebinds[1]', N'float') AS [EstRebinds]
           ,RelOp.node.value(N'@EstimateRewinds[1]', N'float') AS [EstRewinds]
           ,N'Dir=' + RelOp.node.value(N'./IndexScan[1]/@ScanDirection[1]', N'varchar(20)')
            + N',Ordered=' + CASE WHEN RelOp.node.value(N'./IndexScan[1]/@Ordered[1]', N'int') = 0 THEN N'False' ELSE N'True' END
            + N',Forced=' + CASE WHEN RelOp.node.value(N'./IndexScan[1]/@ForcedIndex[1]', N'int') = 0 THEN N'False' ELSE N'True' END
           AS IdxScan
           ,N'In=' + RelOp.node.value(N'./MemoryFractions[1]/@Input[1]', N'varchar(20)') + N', '
            + N',Out=' + RelOp.node.value(N'./MemoryFractions[1]/@Output[1]', N'varchar(20)') + N', '
           AS MemFraction
     FROM sys.dm_exec_query_plan(@plan_handle) AS EQP
          CROSS APPLY EQP.[query_plan].nodes(N'/ShowPlanXML/BatchSequence/Batch/Statements/*') AS Stmt(node)
          CROSS APPLY Stmt.node.nodes(N'(.//RelOp)') AS RelOp(node))
,RelSum AS
    (SELECT RelOp.[StatementId]
           ,SUM(RelOp.[EstIO]) AS [EstIoSum]
           ,SUM(RelOp.[EstCPU]) AS [EstCPUSum]
           ,SUM(RelOp.[EstRebinds]) AS [EstRebindsSum]
           ,SUM(RelOp.[EstRewinds]) AS [EstRewindsSum]
           ,SUM(RelOp.[AvgSize KB]) AS [AvgSizeSum]
     FROM RelOp
     GROUP BY RelOp.[StatementId])
,OutputList AS
    (SELECT Stmt.node.value(N'@StatementId[1]', N'int') AS [StatementId]
           ,OutLs.node.value(N'../../@NodeId[1]', N'int') AS [NodeId]
           ,ISNULL(OutLs.node.value(N'@Database[1]', N'varchar(255)') + N'.', '')
            + ISNULL(OutLs.node.value(N'@Schema[1]', N'varchar(255)') + N'.', '')
            + ISNULL(OutLs.node.value(N'@Table[1]', N'varchar(255)') + N'.', '')
            + ISNULL(OutLs.node.value(N'@Column[1]', N'varchar(255)'), '') AS Cols
     FROM sys.dm_exec_query_plan(@plan_handle) AS EQP
          CROSS APPLY EQP.[query_plan].nodes(N'/ShowPlanXML/BatchSequence/Batch/Statements/*') AS Stmt(node)
          CROSS APPLY Stmt.node.nodes(N'(.//RelOp/OutputList/ColumnReference)') AS OutLs(node)
          )
,IndexList AS
    (SELECT Stmt.node.value(N'@StatementId[1]', N'int') AS [StatementId]
           ,IdxLs.node.value(N'../../../../@NodeId[1]', N'int') AS [NodeId]
           ,ISNULL(IdxLs.node.value(N'@Database[1]', N'varchar(255)') + N'.', '')
            + ISNULL(IdxLs.node.value(N'@Schema[1]', N'varchar(255)') + N'.', '')
            + ISNULL(IdxLs.node.value(N'@Table[1]', N'varchar(255)') + N'.', '')
            + ISNULL(IdxLs.node.value(N'@Column[1]', N'varchar(255)'), '') AS Cols
     FROM sys.dm_exec_query_plan(@plan_handle) AS EQP
          CROSS APPLY EQP.[query_plan].nodes(N'/ShowPlanXML/BatchSequence/Batch/Statements/*') AS Stmt(node)
          CROSS APPLY Stmt.node.nodes(N'(.//RelOp/IndexScan/DefinedValues/DefinedValue/ColumnReference)') AS IdxLs(node)
          )
SELECT RelOp.[StatementId]
      ,RelOp.[NodeID]
      ,RelOp.[ParentNodeID]
      ,RelOp.[PhysicalOp]
      ,RelOp.[LogicalOp]
      -- Cost of the actual node
      ,RelOp.[EstNodeCost] AS [Node $]
      ,CASE WHEN RelOp.[StatementSubTreeCost] = 0 THEN 0.0
            ELSE CONVERT(decimal(38, 2)
                        ,100.0 * RelOp.[EstNodeCost] / RelOp.[StatementSubTreeCost]) END AS [Node %]
      -- Cost of the subtree up to this node
      ,RelOp.[EstSubtreeCost] AS [Subtree $]
      ,CASE WHEN RelOp.[StatementSubTreeCost] = 0 THEN 0.0
            ELSE CONVERT(decimal(38, 2)
                        ,100.0 * RelOp.[EstSubtreeCost] / RelOp.[StatementSubTreeCost]) END AS [Subtree %]
      -- IO costs
      ,RelOp.[EstIO]
      ,CASE WHEN RelSum.[EstIoSum] = 0 THEN 0.0
            ELSE CONVERT(decimal(38, 2)
                        ,100.0 * RelOp.[EstIO] / RelSum.[EstIoSum]) END AS [IO %]
      -- Cpu costs
      ,RelOp.[EstCPU]
      ,CASE WHEN RelSum.[EstCPUSum] = 0 THEN 0.0
            ELSE CONVERT(decimal(38, 2)
                        ,100.0 * RelOp.[EstCPU] / RelSum.[EstCPUSum]) END AS [CPU %]
      -- Estimated data size handled by node
      ,RelOp.[AvgSize KB]
      ,CASE WHEN RelSum.[AvgSizeSum] = 0 THEN 0.0
            ELSE CONVERT(decimal(38, 2)
                        ,100.0 * RelOp.[AvgSize KB] / RelSum.[AvgSizeSum]) END AS [AvgSize %]
      ,RelOp.EstRows
      ,(SELECT CAST((SELECT (SELECT OL.Cols + ','
                     FROM OutputList AS OL
                     WHERE OL.StatementId = RelOp.StatementId
                           AND OL.NodeId = RelOp.NodeId
                     FOR XML PATH (''), Type
                    ) AS Cols
                   ) AS nvarchar(MAX)
       )) AS OutputList
       ,RelOp.Parallel
       ,RelOp.EstRebinds
       ,RelOp.EstRewinds
       ,RelOp.IdxScan
      ,(SELECT CAST((SELECT (SELECT IL.Cols + ','
                     FROM IndexList AS IL
                     WHERE IL.StatementId = RelOp.StatementId
                           AND IL.NodeId = RelOp.NodeId
                     FOR XML PATH (''), Type
                    ) AS Cols
                   ) AS nvarchar(MAX)
       )) AS IndexList
       ,RelOp.MemFraction
FROM RelOp
     INNER JOIN RelSum
         ON RelOp.[StatementId] = RelSum.[StatementId]
ORDER BY RelOp.[StatementId]
        ,RelOp.NodeID;