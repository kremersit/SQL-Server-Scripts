select * from sys.dm_os_performance_counters where counter_name = 'Page Splits/sec' 
waitfor delay '00:00:05'
go 10

SELECT
    CAST ([s].[name] AS VARCHAR) + '.' + CAST ([o].[name] AS VARCHAR) + '.' + CAST ([i].[name] AS VARCHAR) AS [Index],
    [f].[SplitType],
    [f].[SplitCount]
FROM
    (
	SELECT
    [AllocUnitName] AS N'Index',
	AllocUnitId,
    (CASE [Context]
        WHEN N'LCX_INDEX_LEAF' THEN N'Nonclustered'
        WHEN N'LCX_CLUSTERED' THEN N'Clustered'
        ELSE N'Non-Leaf'
    END) AS [SplitType],
    COUNT (1) AS [SplitCount]
FROM
    fn_dblog (NULL, NULL)
WHERE
    [Operation] = N'LOP_DELETE_SPLIT'
GROUP BY [AllocUnitName], [Context], AllocUnitId
) f
JOIN sys.system_internals_allocation_units [a]
    ON [a].[allocation_unit_id] = [f].[AllocUnitId]
JOIN sys.partitions [p]
    ON [p].[partition_id] = [a].[container_id]
JOIN sys.indexes [i]
    ON [i].[index_id] = [p].[index_id] AND [i].[object_id] = [p].[object_id]
JOIN sys.objects [o]
    ON [o].[object_id] = [p].[object_id]
JOIN sys.schemas [s]
    ON [s].[schema_id] = [o].[schema_id];
GO
