
declare @totrow int
      , @currow int
      , @sql_statement nvarchar(max)
      , @message nvarchar(max)
      , @test_only bit;

set @test_only = 1;

if object_id('tempdb..#sqlstatements') is not null
begin
  drop table #sqlstatements
end;


;with compression_on_tables as (
select	case 
          when data_compression = 0 and i.type = 0 then 
            '/*' + cast((a.total_pages * 8 / 1024.00 / 1024) as char(20)) + '*/ USE [' + db_name(db_id()) + '];BEGIN TRY ALTER TABLE [' + s.name + '].[' + t.name + '] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE, ONLINE = ON) END TRY BEGIN CATCH PRINT error_message() END CATCH; '
          when data_compression = 0 and i.type > 0 then 
            '/*' + cast((a.total_pages * 8 / 1024.00 / 1024) as char(20)) + '*/ USE [' + db_name(db_id()) + '];BEGIN TRY ALTER INDEX [' + i.name + '] on [' + s.name + '].[' + t.name + '] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE, ONLINE = ON) END TRY BEGIN CATCH PRINT error_message() END CATCH; '
          else ''
        end as sql_statement
      , s.name as schema_name
      , t.name as table_name
      , i.name as index_name
      , a.total_pages * 8 / 1024.00 / 1024 AS total_gb
      , a.used_pages  * 8 / 1024.00 / 1024 AS used_gb
	    , t.object_id
      , p.partition_id
      , p.partition_number
      , p.data_compression
      , p.data_compression_desc
from    sys.partitions p with (nolock)
        inner join sys.tables t with (nolock)
          on  t.object_id = p.object_id
        inner join sys.schemas s with (nolock)
          on  s.schema_id = t.schema_id
        inner join sys.allocation_units a with (nolock)
          on  a.container_id = p.partition_id 
        left join sys.indexes i with (nolock)
          on  i.object_id = t.object_id
)
select  row_number() over (order by used_gb) as id
      , *
into    #sqlstatements
from    compression_on_tables
where   sql_statement <> ''
order by used_gb desc;

set @totrow = @@ROWCOUNT
set @currow = 1


set @message = convert(varchar, getdate(), 113)
raiserror(@message, 0, 0) with nowait
set @message = cast(@totrow as varchar)
raiserror(@message, 0, 0) with nowait

if @test_only = 1
begin
  set @message = replicate('#', 150)
  raiserror(@message, 0, 0) with nowait
  
  set @message = 'TEST ONLY, set @test_only flag to 0 to execute'
  raiserror(@message, 0, 0) with nowait

  set @message = replicate('#', 150)
  raiserror(@message, 0, 0) with nowait
end

while @totrow > 0 and @currow <= @totrow
begin
  select  @sql_statement = sql_statement 
  from    #sqlstatements 
  where   id = @currow
  
  set @message = replicate('#', 150)
  raiserror(@message, 0, 0) with nowait
  
  set @message = convert(varchar, getdate(), 113)
  raiserror(@message, 0, 0) with nowait
  
  set @message = cast(@currow as varchar)
  raiserror(@message, 0, 0) with nowait

  set @message = @sql_statement
  raiserror(@message, 0, 0) with nowait
  
  if @test_only = 0
  begin
    exec sp_executesql @sql_statement
  end
  
  set @message = convert(varchar, getdate(), 113)
  raiserror(@message, 0, 0) with nowait

  set @currow = @currow + 1
end
