use nocount on;

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
from    sys.dm_os_waiting_tasks w
        inner join sys.dm_exec_sessions s
          on  s.session_id = w.session_id
        inner join sys.dm_exec_requests r
          on  r.session_id = s.session_id
        cross apply sys.dm_exec_sql_text(r.sql_handle) t

        inner join sys.dm_exec_sessions b
          on  b.session_id = w.blocking_session_id
        inner join sys.dm_exec_requests q
          on  q.session_id = b.session_id
        cross apply sys.dm_exec_sql_text(q.sql_handle) x

where   s.program_name not in  ('Microsoft SQL Server Management Studio'
                              , 'SQLAgent - Generic Refresher'
                              , 'SQLAgent - Email Logger'
                              , 'SQLServerCEIP'
                              , 'Microsoft SQL Server Management Studio - Query')
go
----------------------------------------------------------------------------------------------------
-- Create the result table
----------------------------------------------------------------------------------------------------
select  *
into    udv_exec_blocking_queries_results
from    udv_exec_blocking_queries
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
-- Output the result
----------------------------------------------------------------------------------------------------
select  *
from    udv_exec_blocking_queries_results
----------------------------------------------------------------------------------------------------
-- Clean up after execution
----------------------------------------------------------------------------------------------------
if object_id('udv_exec_blocking_queries') is not null
begin
  drop view udv_exec_blocking_queries
end
go
if object_id('udv_exec_blocking_queries_results') is not null
begin
  drop table udv_exec_blocking_queries_results
end
go
