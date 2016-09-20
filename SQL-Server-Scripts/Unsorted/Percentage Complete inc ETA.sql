/*   Returns an Estimated Time of Arrival (ETA) on a longer running query  */

;with  
    dm_exec_requests as (
select  percent_complete
      , start_time
      , getdate() as current_date_time
      , datediff(s, start_time, getdate()) as elapsed_time_seconds
from    sys.dm_exec_requests 
where   percent_complete > 0 
),  calculated_dm_exec_requests as (
select  *
      , percent_complete / elapsed_time_seconds as percent_per_second
      , (100 / (percent_complete / elapsed_time_seconds)) / 60 / 60 as total_running_time
from    dm_exec_requests
)
select  *
      , dateadd(hour, total_running_time, dateadd(minute, total_running_time, start_time)) as ETA
from    calculated_dm_exec_requests