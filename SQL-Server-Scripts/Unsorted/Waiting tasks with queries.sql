set nocount on;

use tempdb
go
----------------------------------------------------------------------------------------------------
-- Drop the results table if it exists
----------------------------------------------------------------------------------------------------
if object_id('udv_exec_blocking_queries_results') is not null
begin
  drop table udv_exec_blocking_queries_results
end
go
----------------------------------------------------------------------------------------------------
-- Drop the dm_os_performance_counters table if it exists
----------------------------------------------------------------------------------------------------
if object_id('dm_os_performance_counters') is not null
begin
  drop table dm_os_performance_counters
end
go
----------------------------------------------------------------------------------------------------
-- Drop the view if it exists
----------------------------------------------------------------------------------------------------
if object_id('udv_exec_blocking_queries') is not null
begin
  drop view udv_exec_blocking_queries
end
go
----------------------------------------------------------------------------------------------------
-- The view that contains the details
----------------------------------------------------------------------------------------------------
create view udv_exec_blocking_queries
as
select  s.host_name
      , s.program_name
      , w.wait_type
      , w.wait_duration_ms

      , w.session_id
      , w.blocking_session_id

      , substring(t.text, r.statement_start_offset / 2, isnull(nullif(r.statement_end_offset, '-1'), len(t.text))) as source_sql
      , substring(x.text, q.statement_start_offset / 2, isnull(nullif(q.statement_end_offset, '-1'), len(x.text))) as blocking_sql
      
      , w.resource_description
      
      , db_name(s.database_id) as source_database
      , s.reads
      , s.logical_reads
      , s.writes
      , s.cpu_time
      , s.memory_usage
      , s.total_scheduled_time
      , c.client_net_address


      , db_name(s.database_id) as blocking_database
      , b.reads as blocking_reads 
      , b.logical_reads as blocking_logical_reads 
      , b.writes as blocking_writes 
      , s.cpu_time as blocking_cpu_time 
      , s.memory_usage as blocking_memory_usage 
      , s.total_scheduled_time as blocking_total_scheduled_time 
      , o.client_net_address as blocking_client_net_address

      , getdate() as insert_date
from    sys.dm_os_waiting_tasks w
        inner join sys.dm_exec_sessions s
          on  s.session_id = w.session_id
        inner join sys.dm_exec_connections c
          on  c.session_id = s.session_id
        inner join sys.dm_exec_requests r
          on  r.session_id = s.session_id
        cross apply sys.dm_exec_sql_text(r.sql_handle) t

        inner join sys.dm_exec_sessions b
          on  b.session_id = w.blocking_session_id
        inner join sys.dm_exec_connections o
          on  o.session_id = s.session_id
        inner join sys.dm_exec_requests q
          on  q.session_id = b.session_id
        cross apply sys.dm_exec_sql_text(q.sql_handle) x
/*
where   s.program_name not in  ('Microsoft SQL Server Management Studio'
                              , 'SQLAgent - Generic Refresher'
                              , 'SQLAgent - Email Logger'
                              , 'SQLServerCEIP'
                              , 'Microsoft SQL Server Management Studio - Query')
*/
go
----------------------------------------------------------------------------------------------------
-- Create the result table
----------------------------------------------------------------------------------------------------
select  *
into    udv_exec_blocking_queries_results
from    udv_exec_blocking_queries
----------------------------------------------------------------------------------------------------
-- Create the batch requests result
----------------------------------------------------------------------------------------------------
select  *, getdate() as insert_date
into    dm_os_performance_counters
from    sys.dm_os_performance_counters
where   counter_name = 'Batch Requests/sec'
go
----------------------------------------------------------------------------------------------------
-- Insert the results every .1 second
----------------------------------------------------------------------------------------------------
insert
into    udv_exec_blocking_queries_results
select  *
from    udv_exec_blocking_queries

waitfor delay '00:00:00.1'
go 1000
----------------------------------------------------------------------------------------------------
-- update the batch requests result
----------------------------------------------------------------------------------------------------
insert
into    dm_os_performance_counters
select  *, getdate() as insert_date
from    sys.dm_os_performance_counters
where   counter_name = 'Batch Requests/sec'
----------------------------------------------------------------------------------------------------
-- Output the result
----------------------------------------------------------------------------------------------------
select  case
          when q.session_id =  q.blocking_session_id then ''
          when q.session_id <> q.blocking_session_id then 'X'
        end wait_for_other
      , *
from    udv_exec_blocking_queries_results q
----------------------------------------------------------------------------------------------------
-- Output the performance counters
----------------------------------------------------------------------------------------------------
;with dm_os_performance_counters_results as (
select  *
      , datediff(second, insert_date, lead(insert_date,1 , 0) over (order by insert_date)) as total_running_seconds
      , (lead(cntr_value, 1, 0) over (order by insert_date) - cntr_value) as [Batch Requests/sec]
from    dm_os_performance_counters
)
select  object_name
      , counter_name
      , [Batch Requests/sec] / total_running_seconds as [Batch Requests/sec]
from    dm_os_performance_counters_results
where   [Batch Requests/sec] > 0
----------------------------------------------------------------------------------------------------
-- Clean up after execution
----------------------------------------------------------------------------------------------------
if object_id('udv_exec_blocking_queries') is not null
begin
  drop view udv_exec_blocking_queries
end
if object_id('udv_exec_blocking_queries_results') is not null
begin
  drop table udv_exec_blocking_queries_results
end
if object_id('dm_os_performance_counters') is not null
begin
  drop table dm_os_performance_counters
end
go
