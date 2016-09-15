;with compression_on_tables as (
select	case 
          when data_compression = 0 and i.type = 0 then 
            '/*' + cast((a.total_pages * 8 / 1024.00 / 1024) as char(20)) + '*/ USE [' + db_name(db_id()) + '];BEGIN TRY ALTER TABLE [' + s.name + '].[' + t.name + '] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE, ONLINE = ON) END TRY BEGIN CATCH PRINT error_message() END CATCH '
          when data_compression = 0 and i.type > 0 then 
            '/*' + cast((a.total_pages * 8 / 1024.00 / 1024) as char(20)) + '*/ USE [' + db_name(db_id()) + '];BEGIN TRY ALTER INDEX [' + i.name + '] on [' + s.name + '].[' + t.name + '] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE, ONLINE = ON) END TRY BEGIN CATCH PRINT error_message() END CATCH '
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
select  *
from    compression_on_tables
where   sql_statement <> ''
order by index_name, table_name desc 