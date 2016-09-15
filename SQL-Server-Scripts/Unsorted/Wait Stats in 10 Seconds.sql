use tempdb
go

if object_id('tempdb..#waits1') is not null
begin
  drop table tempdb..#waits1
  drop table tempdb..#waits2
end

if object_id('tempdb..#waits1') is null
begin
	select *, getdate() as insert_date into #waits1  from sys.dm_os_wait_stats
	waitfor delay '00:00:10'
	select *, getdate() as insert_date into #waits2  from sys.dm_os_wait_stats
end

select	w1.wait_type
      , w2.waiting_tasks_count - w1.waiting_tasks_count as waiting_tasks_count 
      , w2.wait_time_ms - w1.wait_time_ms as wait_time_ms 
      , w2.max_wait_time_ms - w1.max_wait_time_ms as max_wait_time_ms 
      , w2.signal_wait_time_ms - w1.signal_wait_time_ms as signal_wait_time_ms 

from	  #waits1 w1
		    left join #waits2 w2
			    on  w1.wait_type = w2.wait_type
where   w1.wait_type not like '%HADR%'
order by 3 desc