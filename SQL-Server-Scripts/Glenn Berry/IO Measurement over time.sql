------------------------------------------------------------------------------------------
-- Based on a script from Glenn Berry
--
-- Returns the amount of IO time over a period (10 seconds)
------------------------------------------------------------------------------------------


if object_id('tempdb..#first') is not null
begin
  drop table #first
end

-- Get I/O utilization by database (Query 29) (IO Usage By Database)
;WITH Aggregate_IO_Statistics AS (
SELECT  DB_NAME(database_id) AS [Database Name]
      , CAST(SUM(num_of_bytes_read + num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_in_mb
      , CAST(SUM(num_of_bytes_read)/1048576 AS DECIMAL(12, 2)) AS io_reads_in_mb
      , CAST(SUM(num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_writes_in_mb
FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS [DM_IO_STATS]
GROUP BY database_id)
SELECT  ROW_NUMBER() OVER(ORDER BY io_in_mb DESC) AS [I/O Rank]
      , [Database Name]
      , io_in_mb AS [Total I/O (MB)]
      , io_reads_in_mb AS io_reads_in_mb
      , io_writes_in_mb AS io_writes_in_mb
      , CAST(io_in_mb/ SUM(io_in_mb) OVER() * 100.0 AS DECIMAL(5,2)) AS [I/O Percent]
into    #first
FROM    Aggregate_IO_Statistics
ORDER BY [I/O Rank] 
OPTION (RECOMPILE);
------

waitfor delay '00:00:10'

-- Get I/O utilization by database (Query 29) (IO Usage By Database)
;WITH Aggregate_IO_Statistics AS (
SELECT  DB_NAME(database_id) AS [Database Name]
      , CAST(SUM(num_of_bytes_read + num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_in_mb
      , CAST(SUM(num_of_bytes_read)/1048576 AS DECIMAL(12, 2)) AS io_reads_in_mb
      , CAST(SUM(num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_writes_in_mb
FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS [DM_IO_STATS]
GROUP BY database_id)
select  f.[database name]
      , a.io_in_mb - f.[Total I/O (MB)] as [Total I/O (MB)]
      , a.io_reads_in_mb - f.io_reads_in_mb as [Total Reads I/O (MB)]
      , a.io_writes_in_mb - f.io_writes_in_mb as [Total Writes I/O (MB)]
      
FROM    Aggregate_IO_Statistics A
        inner join #first f
          on  f.[database name] = a.[database name]
ORDER BY [Total I/O (MB)] desc OPTION (RECOMPILE);
------