set nocount on;
/*-------------------------------------------------------------------------------------------------------------
--
--   Get VLF Information 
--   Mark Kremers - 21-07-2017
--
--   Description: A high number of VLF's (Virtual Log Files) can have an impact on performance
--   For information on how to set the file growth of the Transaction Log see:
--   https://www.sqlskills.com/blogs/paul/important-change-vlf-creation-algorithm-sql-server-2014/
--            
-------------------------------------------------------------------------------------------------------------*/
---------------------------------------------------------------------------------------------------------------
-- Declare local variables
---------------------------------------------------------------------------------------------------------------
declare @totrow int
      , @currow int
      , @database_name sysname
      , @nsql nvarchar(max)
      , @server_version varchar(15);
---------------------------------------------------------------------------------------------------------------
-- Declare local tables
---------------------------------------------------------------------------------------------------------------
declare @dbcc_loginfo_pre table (
	FileId tinyint
, FileSize bigint
, StartOffset bigint
, FSeqNo int
, Status tinyint
, Parity tinyint
, CreateLSN numeric(25, 0)
, DatabaseName sysname null
);
declare @dbcc_loginfo_post table (
  ReoveryUnitId bigint
, FileId tinyint
, FileSize bigint
, StartOffset bigint
, FSeqNo int
, Status tinyint
, Parity tinyint
, CreateLSN numeric(25, 0)
, DatabaseName sysname null
);

declare @databases table (
  Id int identity(1, 1)
, DatabaseName sysname
);
---------------------------------------------------------------------------------------------------------------
-- Get server version
---------------------------------------------------------------------------------------------------------------
select  @server_version = case 
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '8%' THEN 'SQL2000'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '9%' THEN 'SQL2005'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '10.0%' THEN 'SQL2008'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '10.5%' THEN 'SQL2008'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '11%' THEN 'SQL2012'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '12%' THEN 'SQL2014'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '13%' THEN 'SQL2016'     
                          end 
---------------------------------------------------------------------------------------------------------------
-- Get databases to process
---------------------------------------------------------------------------------------------------------------
insert
into    @databases
select  name
from    sys.databases
where   database_id not in (1, 2, 3, 4, 32767) -- Exclude master, tempdb, model, msdb and resourcedb
and     HAS_DBACCESS(name) = 1;

set @totrow = @@ROWCOUNT
set @currow = 1;
---------------------------------------------------------------------------------------------------------------
-- Loop through databases
---------------------------------------------------------------------------------------------------------------
while @totrow > 0 and @currow <= @totrow
begin
  select  @database_name = DatabaseName
  from    @databases
  where   Id = @currow
  -------------------------------------------------------------------------------------------------------------
  -- Create SQL Statement for VLF information
  -------------------------------------------------------------------------------------------------------------
  set @nsql = 'use [[database_name]]; dbcc loginfo() with no_infomsgs'
  set @nsql = replace(@nsql, '[database_name]', @database_name)
  
  begin try
    -----------------------------------------------------------------------------------------------------------
    -- Process SQL Statement for SQL Server 2000, SQL Server 2005, SQL Server 2008 and SQL Server 2008 R2
    -----------------------------------------------------------------------------------------------------------
    if @server_version in ('SQL2000', 'SQL2005', 'SQL2008')
    begin
      insert
      into    @dbcc_loginfo_pre (FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN)
      exec sp_executesql @nsql

      update  @dbcc_loginfo_pre
      set     DatabaseName = @database_name
      where   DatabaseName is null
    end
    -----------------------------------------------------------------------------------------------------------
    -- Process SQL Statement for SQL Server 2012, SQL Server 2014 and SQL Server 2016
    -----------------------------------------------------------------------------------------------------------
    if @server_version in ('SQL2012', 'SQL2014', 'SQL2016')
    begin
      insert
      into    @dbcc_loginfo_post (ReoveryUnitId, FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN)
      exec sp_executesql @nsql

      update  @dbcc_loginfo_post
      set     DatabaseName = @database_name
      where   DatabaseName is null
    end

  end try
  begin catch
    print 'Error' 
    print error_message()
  end catch
  -------------------------------------------------------------------------------------------------------------
  -- Set next row to process
  -------------------------------------------------------------------------------------------------------------
  set @currow = @currow + 1;
end
---------------------------------------------------------------------------------------------------------------
-- Output result
---------------------------------------------------------------------------------------------------------------
select  FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN, DatabaseName
from    @dbcc_loginfo_pre
union all
select  FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN, DatabaseName
from    @dbcc_loginfo_post
