use master
go
set nocount on;

if object_id('tempdb..#dm_io_virtual_file_stats') is not null
begin
  drop table #dm_io_virtual_file_stats
end
go

select  top 0
        db_name() as database_name 
      , type_desc
      , sum(num_of_reads) as num_of_reads
      , sum(io_stall_read_ms) as io_stall_read_ms
      , sum(num_of_writes) as num_of_writes
      , sum(io_stall_write_ms) as io_stall_write_ms
      , cast((sum(num_of_reads) / (sum(num_of_reads) + sum(num_of_writes) * 1.0)) * 100 as money) as read_percentage
      , cast((sum(num_of_writes) / (sum(num_of_reads) + sum(num_of_writes) * 1.0)) * 100 as money) as write_percentage 
into    #dm_io_virtual_file_stats
from    sys.dm_io_virtual_file_stats(db_id(), null) f
        inner join sys.database_files d  
          on d.file_id = f.file_id  
group by d.type_desc

insert
into    #dm_io_virtual_file_stats
exec sp_msforeachdb N'
use [?];

select  ''?'' as database_name 
      , type_desc
      , sum(num_of_reads) as num_of_reads
      , sum(io_stall_read_ms) as io_stall_read_ms
      , sum(num_of_writes) as num_of_writes
      , sum(io_stall_write_ms) as io_stall_write_ms
      , cast((sum(num_of_reads) / (sum(num_of_reads) + sum(num_of_writes) * 1.0)) * 100 as money) as read_percentage
      , cast((sum(num_of_writes) / (sum(num_of_reads) + sum(num_of_writes) * 1.0)) * 100 as money) as write_percentage 
       
from    [?].sys.dm_io_virtual_file_stats(db_id(), null) f  
        inner join [?].sys.database_files d  
          on d.file_id = f.file_id  
group by d.type_desc
'



select  *
from    #dm_io_virtual_file_stats
order by database_name
