use tempdb
go
if object_id('tempdb..#dm_db_index_physical_stats') is not null
begin
  drop table #dm_db_index_physical_stats
end;

select  distinct
        e.name + '.' + o.name as table_name
      , i.name as index_name
      , s.avg_fragmentation_in_percent
      , s.avg_fragment_size_in_pages
      , s.page_count
     , case
         when avg_fragmentation_in_percent < 31 then 'reorganize'
         else 'rebuild'
       end as choice
     , case
         when avg_fragmentation_in_percent < 31 then replace(replace('use ?; alter index [[INDEXNAME]] on [OBJECTNAME] reorganize', '[INDEXNAME]', i.name), '[OBJECTNAME]', e.name + '.' + o.name)
         else replace(replace('use ?; alter index [[INDEXNAME]] on [OBJECTNAME] rebuild', '[INDEXNAME]', i.name), '[OBJECTNAME]', e.name + '.' + o.name)
       end as choice_script
     , replace(replace('use ?; alter index [[INDEXNAME]] on [OBJECTNAME] rebuild', '[INDEXNAME]', i.name), '[OBJECTNAME]', e.name + '.' + o.name) as statement_rebuild
     , replace(replace('use ?; alter index [[INDEXNAME]] on [OBJECTNAME] reorganize', '[INDEXNAME]', i.name), '[OBJECTNAME]', e.name + '.' + o.name) as statement_reorganize
     , replace(replace(replace('dbcc indexdefrag([DATABASE_ID], ''[OBJECTNAME]'', ''[[INDEXNAME]]'')'
     , '[DATABASE_ID]', db_id())
     , '[INDEXNAME]', i.name)
     , '[OBJECTNAME]', e.name + '.' + o.name) as statement_defrag
into    #dm_db_index_physical_stats
from   sys.dm_db_index_physical_stats(db_id(), null, null, null, null) s
       inner join sys.tables o
         on  o.object_id = s.object_id
       inner join sys.schemas e
         on  e.schema_id = o.schema_id
       inner join sys.indexes i
         on  i.object_id = o.object_id
       inner join sys.index_columns c
         on  c.object_id = o.object_id
         and c.index_id = i.index_id
       inner join sys.columns u
         on  u.column_id = c.column_id
         and u.object_id = o.object_id
order by 3, 1

insert
into    #dm_db_index_physical_stats
exec sp_msforeachdb N'
select  distinct
        e.name + ''.'' + o.name as table_name
      , i.name as index_name
      , s.avg_fragmentation_in_percent
      , s.avg_fragment_size_in_pages
      , s.page_count
     , case
         when avg_fragmentation_in_percent < 31 then ''reorganize''
         else ''rebuild''
       end as choice
     , case
         when avg_fragmentation_in_percent < 31 then replace(replace(''use ?; alter index [[INDEXNAME]] on [OBJECTNAME] reorganize'', ''[INDEXNAME]'', i.name), ''[OBJECTNAME]'', e.name + ''.'' + o.name)
         else replace(replace(''use ?; alter index [[INDEXNAME]] on [OBJECTNAME] rebuild'', ''[INDEXNAME]'', i.name), ''[OBJECTNAME]'', e.name + ''.'' + o.name)
       end as choice_script
     , replace(replace(''use ?; alter index [[INDEXNAME]] on [OBJECTNAME] rebuild'', ''[INDEXNAME]'', i.name), ''[OBJECTNAME]'', e.name + ''.'' + o.name) as statement_rebuild
     , replace(replace(''use ?; alter index [[INDEXNAME]] on [OBJECTNAME] reorganize'', ''[INDEXNAME]'', i.name), ''[OBJECTNAME]'', e.name + ''.'' + o.name) as statement_reorganize
     , replace(replace(replace(''dbcc indexdefrag([DATABASE_ID], ''''[OBJECTNAME]'''', ''''[[INDEXNAME]]'''')''
     , ''[DATABASE_ID]'', db_id(''?''))
     , ''[INDEXNAME]'', i.name)
     , ''[OBJECTNAME]'', e.name + ''.'' + o.name) as statement_defrag
into    #dm_db_index_physical_stats
from   ?.sys.dm_db_index_physical_stats(db_id(''?''), null, null, null, null) s
       inner join ?.sys.tables o
         on  o.object_id = s.object_id
       inner join ?.sys.schemas e
         on  e.schema_id = o.schema_id
       inner join ?.sys.indexes i
         on  i.object_id = o.object_id
       inner join ?.sys.index_columns c
         on  c.object_id = o.object_id
         and c.index_id = i.index_id
       inner join ?.sys.columns u
         on  u.column_id = c.column_id
         and u.object_id = o.object_id
order by 3, 1

'


select   *
from    #dm_db_index_physical_stats
