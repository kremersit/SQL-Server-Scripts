use master
go
set nocount on

declare @totrow int
      , @currow int
      , @database_name nvarchar(1024)
      , @nsql nvarchar(4000)

declare @databases table (
  Id int identity(1, 1) not null
, database_name nvarchar(1024) not null
)

insert
into    @databases (database_name)
select  d.name as database_name
from    sys.databases d
where   d.database_id > 4
and     d.replica_id is null
and     d.state = 0

set @totrow = @@rowcount

if object_id('tempdb..#CompressionOnDatabases') is not null
begin
  drop table #CompressionOnDatabases
end

CREATE TABLE #CompressionOnDatabases (
	[sql_statement] [nvarchar](464) NULL,
	[schema_name] [sysname] NOT NULL,
	[table_name] [sysname] NOT NULL,
	[index_name] [sysname]  NULL,
  [database_name] nvarchar(1024) not null,
	[total_gb] [numeric](33, 12) NULL,
	[used_gb] [numeric](33, 12) NULL,
	[object_id] [int] NOT NULL,
	[partition_id] [bigint] NOT NULL,
	[partition_number] [int] NOT NULL,
	[data_compression] [tinyint] NOT NULL,
	[data_compression_desc] [nvarchar](60) NULL
) ON [PRIMARY]

set @currow = 1
while @totrow > 0 and @currow <= @totrow
begin
  select  @database_name = database_name
  from    @databases
  where   Id = @currow

  set @nsql = N'
  USE [[DATABASENAME]];
  SELECT	case 
            when data_compression = 0 and i.type = 0
				then ''USE [[DATABASENAME]];BEGIN TRY ALTER TABLE ['' + s.name + ''].['' + t.name + ''] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE, ONLINE = ON) END TRY BEGIN CATCH PRINT error_message() END CATCH ''
            when data_compression = 0 and i.type > 0
				then ''USE [[DATABASENAME]];BEGIN TRY ALTER INDEX ['' + i.name + ''] on ['' + s.name + ''].['' + t.name + ''] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE, ONLINE = ON) END TRY BEGIN CATCH PRINT error_message() END CATCH ''
            else ''''
          end as sql_statement
        , s.name as schema_name
        , t.name as table_name
        , i.name as index_name
        , ''[DATABASENAME]'' as database_name

        , a.total_pages * 8 / 1024.00 / 1024 AS total_gb
        , a.used_pages  * 8 / 1024.00 / 1024 AS used_gb
	      , t.object_id
        , p.partition_id
        , p.partition_number
        , p.data_compression
        , p.data_compression_desc
  FROM    [[DATABASENAME]].sys.partitions p with (nolock)
          inner join [[DATABASENAME]].sys.tables t with (nolock)
            on  t.object_id = p.object_id
          inner join [[DATABASENAME]].sys.schemas s with (nolock)
            on  s.schema_id = t.schema_id
          inner join [[DATABASENAME]].sys.allocation_units a with (nolock)
            on  a.container_id = p.partition_id 
          left join [[DATABASENAME]].sys.indexes i with (nolock)
            on  i.object_id = t.object_id
  order by total_gb desc '
  set @nsql = replace(@nsql, '[DATABASENAME]', @database_name)
  
  insert
  into    #CompressionOnDatabases
  exec sp_executesql @nsql

  set @currow = @currow + 1
end


select  distinct 
        c.sql_statement
      , c.total_gb
from    #CompressionOnDatabases c
where	  c.data_compression = 0
order by c.total_gb 
       , c.sql_statement