------------------------------------------------------------------------------------------
-- Based on a script from Glenn Berry
--
-- Returns the amount of CPU time over a period (10 seconds)
-- Beware, the results may be skewed, since the scripts usses the total worker time
-- which will be higher on parallel queries (every worker is added, so every active
-- instruction on any core will add up)
------------------------------------------------------------------------------------------

if object_id('tempdb..#first') is not null
begin 
  drop table #first
end


;WITH DB_CPU_Stats AS (
SELECT  pa.DatabaseID
      , DB_Name(pa.DatabaseID) AS [Database Name]
      , SUM(qs.total_worker_time/1000) AS [CPU_Time_Ms]
FROM    sys.dm_exec_query_stats AS qs WITH (NOLOCK)
        CROSS APPLY  (SELECT  CONVERT(int, value) AS [DatabaseID] 
                      FROM    sys.dm_exec_plan_attributes(qs.plan_handle)
                      WHERE   attribute = N'dbid') AS pa
GROUP BY DatabaseID)
SELECT  ROW_NUMBER() OVER(ORDER BY [CPU_Time_Ms] DESC) AS [CPU Rank]
      , [Database Name]
      , [CPU_Time_Ms] AS [CPU Time (ms)]
      , CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CPU Percent]
into    #first
FROM    DB_CPU_Stats
WHERE   DatabaseID <> 32767 -- ResourceDB
ORDER BY [CPU Rank] OPTION (RECOMPILE);

waitfor delay '00:00:10'

;WITH DB_CPU_Stats AS (
SELECT  pa.DatabaseID
      , DB_Name(pa.DatabaseID) AS [Database Name]
      , SUM(qs.total_worker_time/1000) AS [CPU_Time_Ms]
FROM    sys.dm_exec_query_stats AS qs WITH (NOLOCK)
        CROSS APPLY  (SELECT  CONVERT(int, value) AS [DatabaseID] 
                      FROM    sys.dm_exec_plan_attributes(qs.plan_handle)
                      WHERE   attribute = N'dbid') AS pa
GROUP BY DatabaseID)
select  c.[Database Name]
      , c.[CPU_Time_Ms] - f.[CPU Time (ms)] as [CPU Time (ms)]
      , cast((c.[CPU_Time_Ms] - f.[CPU Time (ms)] ) / 1000.0 as decimal(5,2))as [CPU Time (s)]
FROM    DB_CPU_Stats c
        inner join #first f
          on  f.[Database Name] = c.[Database Name]
WHERE   DatabaseID <> 32767 -- ResourceDB
ORDER BY 2 desc OPTION (RECOMPILE);