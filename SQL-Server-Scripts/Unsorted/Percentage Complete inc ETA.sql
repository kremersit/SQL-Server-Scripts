;with  
    dm_exec_requests as (
select  d.percent_complete
      , d.start_time
      , getdate() as current_date_time
      , datediff(s, d.start_time, getdate()) as elapsed_time_seconds
      , d.session_id
      , case when d.statement_start_offset = 0 and d.statement_end_offset = -1 
          then t.text
          else substring(t.text, (d.statement_start_offset / 2), (d.statement_end_offset / 2)) 
        end as sql_text
from    sys.dm_exec_requests d
        cross apply sys.dm_exec_sql_text(d.sql_handle) t
where   d.percent_complete > 0 
),  calculated_dm_exec_requests as (
select  percent_complete 
      , percent_complete / elapsed_time_seconds as percent_per_second
      , (100 / (percent_complete / elapsed_time_seconds)) as total_running_time
	  , start_time
	  , current_date_time
	  , elapsed_time_seconds
	  , session_id
	  , sql_text
from    dm_exec_requests
)
select  dateadd(SECOND, total_running_time, start_time) as ETA
	  , *
from    calculated_dm_exec_requests

