use master
go
set nocount on;

if object_id('tempdb..#statistics_information') is not null
begin
  drop table #statistics_information
end

select  top 0
        db_name() as database_name

      , o.name as table_name
     
      , p.last_updated
      , p.rows_sampled                        -- Total number of rows sampled for statistics calculations.
      , p.steps                               -- Number of steps in the histogram. For more information, 
                                              --    see DBCC SHOW_STATISTICS (Transact-SQL).
      , p.unfiltered_rows                     -- Total number of rows in the table before applying the filter expression (for filtered statistics).
                                              --    If statistics are not filtered, unfiltered_rows is equal to 
                                              --    the value returns in the rows column.
      , p.rows as row_count_last_stats_update -- Total number of rows in the table or indexed view when statistics were last updated. 
                                              --    If the statistics are filtered or correspond to a filtered index, 
                                              --    the number of rows might be less than the number of rows in the table.
      , t.row_count as row_count_in_partition
      , t.row_count - p.rows as row_count_diff
      , o.type_desc
      , o.create_date
      , o.modify_date
into    #statistics_information
from    sys.stats s
        outer apply sys.dm_db_stats_properties(s.object_id, s.stats_id) p
        left join sys.dm_db_partition_stats t
          on  t.object_id = s.object_id
        left join sys.objects o
          on  o.object_id = s.object_id
-- Filter out System tables (S) and Internal tables (IT)
where   o.type not in ('S', 'IT')

insert
into    #statistics_information
exec master..sp_MSforeachdb N'
use [?];

select  ''?'' as database_name

      , o.name as table_name
     
      , p.last_updated
      , p.rows_sampled                        -- Total number of rows sampled for statistics calculations.
      , p.steps                               -- Number of steps in the histogram. For more information, 
                                              --    see DBCC SHOW_STATISTICS (Transact-SQL).
      , p.unfiltered_rows                     -- Total number of rows in the table before applying the filter expression (for filtered statistics).
                                              --    If statistics are not filtered, unfiltered_rows is equal to 
                                              --    the value returns in the rows column.
      , p.rows as row_count_last_stats_update -- Total number of rows in the table or indexed view when statistics were last updated. 
                                              --    If the statistics are filtered or correspond to a filtered index, 
                                              --    the number of rows might be less than the number of rows in the table.
      , t.row_count as row_count_in_partition
      , t.row_count - p.rows as row_count_diff
      , o.type_desc
      , o.create_date
      , o.modify_date
from    ?.sys.stats s
        outer apply ?.sys.dm_db_stats_properties(s.object_id, s.stats_id) p
        left join ?.sys.dm_db_partition_stats t
          on  t.object_id = s.object_id
        left join ?.sys.objects o
          on  o.object_id = s.object_id
-- Filter out System tables (S) and Internal tables (IT)
where   o.type not in (''S'', ''IT'')
'

select  *
from    #statistics_information
order by row_count_in_partition desc
