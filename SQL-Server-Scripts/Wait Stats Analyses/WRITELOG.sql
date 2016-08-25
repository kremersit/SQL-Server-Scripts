-- Why is the WRITELOG wait stat high?
-------------------------------------------------------------------------------------------------
-- How much percentage of all wait stats is WRITELOG
-------------------------------------------------------------------------------------------------
WITH [Waits] AS
    (SELECT
        [wait_type],
        [wait_time_ms] / 1000.0 AS [WaitS],
        ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
        [signal_wait_time_ms] / 1000.0 AS [SignalS],
        [waiting_tasks_count] AS [WaitCount],
       100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
        ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_os_wait_stats
    WHERE [wait_type] NOT IN (       N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR',         N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',         N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',         N'CHKPT', N'CLR_AUTO_EVENT',         N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',  
         -- Maybe uncomment these four if you have mirroring issues
         N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',         N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD',          N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',         N'EXECSYNC', N'FSAGENT',
         N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX', 
         -- Maybe uncomment these six if you have AG issues
         N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',         N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE',         N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',           N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP',
         N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT',         N'ONDEMAND_TASK_QUEUE',         N'PREEMPTIVE_XE_GETTARGETSTATE',         N'PWAIT_ALL_COMPONENTS_INITIALIZED',         N'PWAIT_DIRECTLOGCONSUMER_GETNEXT',
         N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', N'QDS_ASYNC_QUEUE',         N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',         N'QDS_SHUTDOWN_QUEUE', N'REDO_THREAD_PENDING_WORK',         N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE',         N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
         N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP',         N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',         N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP',         N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',         N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT',
         N'SP_SERVER_DIAGNOSTICS_SLEEP', N'SQLTRACE_BUFFER_FLUSH',         N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',         N'SQLTRACE_WAIT_ENTRIES', N'WAIT_FOR_RESULTS',         N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',         N'WAIT_XTP_RECOVERY',
         N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',         N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',         N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT')
             AND [waiting_tasks_count] > 0
    )
SELECT
    MAX ([W1].[wait_type]) AS [WaitType],
    CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
    CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
    CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
    MAX ([W1].[WaitCount]) AS [WaitCount],
    CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
    CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_S],
    CAST ((MAX ([W1].[ResourceS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgRes_S],
    CAST ((MAX ([W1].[SignalS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgSig_S],
    CAST ('https://www.sqlskills.com/help/waits/' + MAX ([W1].[wait_type]) as XML) AS [Help/Info URL]
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2]
    ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM ([W2].[Percentage]) - MAX( [W1].[Percentage] ) < 95; -- percentage threshold
GO
go
-------------------------------------------------------------------------------------------------
-- In scenarios where the SQL Server transaction log file is not on a dedicated volume 
-- this DMV can be used to track the number of outstanding I/O’s at the file level.
-- If the transaction log is on a dedicated logical volume this information can be obtained
-- using Performance Monitor counters. More details on both are given below.
-------------------------------------------------------------------------------------------------
set nocount on
go
if object_id('dm_io_pending_io_requests_temp') is not null
begin
	drop table dm_io_pending_io_requests_temp
end
go

select *, getdate() as insertdate into dm_io_pending_io_requests_temp 
from sys.dm_io_pending_io_requests where io_type <> 'network' 
go


insert
into dm_io_pending_io_requests_temp 
select *, getdate() as insertdate from sys.dm_io_pending_io_requests where io_type <> 'network' 
 
waitfor delay '00:00:00.01' 
go 1000

select	*
from	dm_io_pending_io_requests_temp
where io_handle_path like '%.ldf' 

-------------------------------------------------------------------------------------------------
-- Window Performance Monitor “SQL Server:Databases” Object
-- This performance monitor object contains several counters specific to performance of a 
-- transaction log for a specific database. In many cases these can provide more detailed 
-- information about log performance as the granularity is at the log level regardless of 
-- the logical storage configuration. The specific counters are:
-- a. Log Bytes Flushed/sec
-- b. Log Flushes/sec – (i.e. I/O operation to flush a log record to the transaction log)
-- c. Log Flush Wait Time
--
-- monitor over 10 seconds, every 0.1 second
-------------------------------------------------------------------------------------------------
declare @instance_name sysname = 'plixaSearch'

if object_id('dm_os_performance_counters') is not null
begin
  drop table dm_os_performance_counters
end

select  *
into    dm_os_performance_counters
from    sys.dm_os_performance_counters
where   counter_name in ('Log Bytes Flushed/sec', 'Log Flushes/sec', 'Log Flush Wait Time')
and     instance_name = @instance_name

waitfor delay '00:00:10'

select  c.object_name
      , c.counter_name
      , c.instance_name
      , c.cntr_value - d.cntr_value as cntr_value
from    sys.dm_os_performance_counters c
        inner join dm_os_performance_counters d
          on  d.object_name = c.object_name
          and d.counter_name = c.counter_name
          and d.instance_name = c.instance_name
          and d.cntr_type = c.cntr_type
where   c.counter_name in ('Log Bytes Flushed/sec', 'Log Flushes/sec', 'Log Flush Wait Time')
and     c.instance_name = @instance_name



-------------------------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------------------------
select * from sys.dm_tran_database_transactions
