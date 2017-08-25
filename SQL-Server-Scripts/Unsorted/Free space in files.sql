use tempdb
go
set nocount on;
------------------------------------------------------------------------------------------------------------------------
-- Drop table if it exists
------------------------------------------------------------------------------------------------------------------------
if object_id('tempdb..#database_files') is not null
begin
  drop table #database_files
end
go
------------------------------------------------------------------------------------------------------------------------
-- Create table definition
------------------------------------------------------------------------------------------------------------------------
select  top 0
        db_name() AS database_name
      , name AS file_name
      , size / 128.0 AS file_size_in_mb
      , size / 128.0 - cast(fileproperty(name, 'SpaceUsed') as int) / 128.0 as free_space_in_file_in_mb
      , ((size / 128.0 - cast(fileproperty(name, 'SpaceUsed') as int) / 128.0) / (size / 128.0)) * 100.0 as percentage_free
      , physical_name
      , type_desc
into	  #database_files
from    sys.database_files; ; 
------------------------------------------------------------------------------------------------------------------------
-- Fill temp table with result
------------------------------------------------------------------------------------------------------------------------
insert
into	#database_files
exec sp_msforeachdb N' 
use [?];
select  db_name() AS database_name
      , name AS file_name
      , size / 128.0 AS file_size_in_mb
      , size / 128.0 - cast(fileproperty(name, ''SpaceUsed'') as int) / 128.0 as free_space_in_file_in_mb
      , ((size / 128.0 - cast(fileproperty(name, ''SpaceUsed'') as int) / 128.0) / (size / 128.0)) * 100.0 as percentage_free
      , physical_name
      , type_desc
FROM    sys.database_files; '
------------------------------------------------------------------------------------------------------------------------
-- Output results
------------------------------------------------------------------------------------------------------------------------
select	*
from  	#database_files
where   type_desc = 'ROWS'
order by free_space_in_file_in_mb desc
