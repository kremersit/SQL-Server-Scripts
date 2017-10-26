use master;
set nocount on;
/*-------------------------------------------------------------------------------------------------------------
--
--   Get VLF Information 
--   version 1 - Mark Kremers - 21-07-2017 : Initial commit
--   version 2 - Mark Kremers - 21-07-2017 : Added aggregated results and detailed information
--   version 3 - Mark Kremers - 24-07-2017 : Added filesize information and autogrowth settings
--   version 4 - Mark Kremers - 08-08-2017 : Best Amount of VLFs regarding the current Log File
--   version 5 - Mark Kremers - 26-10-2017 : Rewritten algorithms
--
--   Description: A high number of VLF's (Virtual Log Files) can have an impact on performance
--   For information on how to set the file growth of the Transaction Log see:
--   https://www.sqlskills.com/blogs/paul/important-change-vlf-creation-algorithm-sql-server-2014/
--   https://www.sqlskills.com/blogs/kimberly/transaction-log-vlfs-too-many-or-too-few/
--   https://www.sqlskills.com/blogs/kimberly/8-steps-to-better-transaction-log-throughput/
--   
--   "
--       Up to 2014, the algorithm for how many VLFs you get when you create, grow, or auto-grow 
--       the log is based on the size in question:
-- 
--       Less than 1 MB, complicated, ignore this case.
--       Up to 64 MB: 4 new VLFs, each roughly 1/4 the size of the growth
--       64 MB to 1 GB: 8 new VLFs, each roughly 1/8 the size of the growth
--       More than 1 GB: 16 new VLFs, each roughly 1/16 the size of the growth
--       So if you created your log at 1 GB and it auto-grew in chunks of 512 MB to 200 GB, 
--        you’d have 8 + ((200 – 1) x 2 x 8) = 3192 VLFs. 
--
--       (8 VLFs from the initial creation, then 
--        200 – 1 = 199 GB of growth at 512 MB per auto-grow = 398 auto-growths,
--        each producing 8 VLFs.)
-- 
--       For SQL Server 2014, the algorithm is now:
-- 
--       Is the growth size less than 1/8 the size of the current log size?
--       Yes: create 1 new VLF equal to the growth size
--       No: use the formula above
--   "
--   Transaction log Physical Architecture :
--   https://technet.microsoft.com/en-us/library/ms179355(v=sql.105).aspx
--
--   Check current Log File size -> probably the size that a logfile can become (in a managed environment),
--                                  the script should (or could) respect this size. When there are no
--                                  log backups the log file size should be 20/30% of the data file(s) size
--
--   Total amount of VLF's should then be:
--   For initial VLF's the formula above said 8 VLF's, tested on SQL Server 2016, only 4 VLF's were created on a new DB
--   Need more information about this
--
--    Initial VLF's for inital creation 
--    PLUS
--    when log file size >  1024 - 1 VLF will be 1/16th of the growsize
--    when log file size >  64
--     and log file size <= 1024 - 1 VLF will be 1/8th of the growsize
--    when log file size <= 64   - 1 VLF will be 1/4th of the growsize
--
-------------------------------------------------------------------------------------------------------------*/
declare @detailed_output bit = 0
---------------------------------------------------------------------------------------------------------------
-- Declare local variables
---------------------------------------------------------------------------------------------------------------
declare @totrow int
      , @currow int
      , @database_name sysname
      , @nsql nvarchar(max)
      , @server_version varchar(15)
      , @tracefile_path nvarchar(520);
---------------------------------------------------------------------------------------------------------------
-- Declare local constants
---------------------------------------------------------------------------------------------------------------
declare @vlf_initial_amount tinyint = 4   -- Initial amount of VLF's, this is under investigation
---------------------------------------------------------------------------------------------------------------
-- Declare local tables
---------------------------------------------------------------------------------------------------------------
declare @dbcc_loginfo_pre_SQL2012 table (
	FileId tinyint
, FileSize bigint
, StartOffset bigint
, FSeqNo int
, Status tinyint
, Parity tinyint
, CreateLSN numeric(25, 0)
, DatabaseName sysname null
);
declare @dbcc_loginfo_post_SQL2012 table (
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
  id int identity(1, 1)
, database_name sysname
);

declare @database_filesizes table (
	file_id tinyint
, filesize_in_mb numeric(25, 2)
, database_name sysname null
, growth_size_in_mb numeric(25, 2)
);

declare @database_logfile_growths table (
	database_name sysname null
, amount_of_growths int
);
---------------------------------------------------------------------------------------------------------------
-- Get server version
---------------------------------------------------------------------------------------------------------------
select  @server_version = case 
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '8%'    THEN 'SQL2000'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '9%'    THEN 'SQL2005'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '10.0%' THEN 'SQL2008'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '10.5%' THEN 'SQL2008'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '11%'   THEN 'SQL2012'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '12%'   THEN 'SQL2014'
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '13%'   THEN 'SQL2016'     
                           when cast(SERVERPROPERTY ('productversion') as varchar) like '14%'   THEN 'SQL2017'     
                          end 
---------------------------------------------------------------------------------------------------------------
-- Get Autogrowth settings (if available)
---------------------------------------------------------------------------------------------------------------
select  @tracefile_path = substring(path, 1, Len(path) - charindex('\', reverse(path))) + '\log.trc'
from    sys.traces
where   id = 1

insert
into    @database_logfile_growths
select  t.databasename
      , count(t.databasename) as amount_of_growths
from   ::fn_trace_gettable(@tracefile_path, 0) t
        inner join sys.trace_events e
          on  e.trace_event_id = t.EventClass
          -- filter on 'Log File Auto Grow' (trace_event_id = 93 / category_id = 2)
          and e.category_id = 2
          and e.trace_event_id = 93
group by t.databasename
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
  select  @database_name = database_name
  from    @databases
  where   id = @currow
  
  begin try
    -----------------------------------------------------------------------------------------------------------
    -- Create SQL Statement for VLF information
    -----------------------------------------------------------------------------------------------------------
    set @nsql = 'use [[database_name]]; dbcc loginfo() with no_infomsgs'
    set @nsql = replace(@nsql, '[database_name]', @database_name)
    -----------------------------------------------------------------------------------------------------------
    -- Process SQL Statement for SQL Server 2000, SQL Server 2005, SQL Server 2008 and SQL Server 2008 R2
    -----------------------------------------------------------------------------------------------------------
    if @server_version in ('SQL2000', 'SQL2005', 'SQL2008')
    begin
      insert
      into    @dbcc_loginfo_pre_SQL2012 (FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN)
      exec sp_executesql @nsql

      update  @dbcc_loginfo_pre_SQL2012
      set     DatabaseName = @database_name
      where   DatabaseName is null
    end
    -----------------------------------------------------------------------------------------------------------
    -- Process SQL Statement for SQL Server 2012, SQL Server 2014, SQL Server 2016 and SQL Server 2017
    -----------------------------------------------------------------------------------------------------------
    if @server_version in ('SQL2012', 'SQL2014', 'SQL2016', 'SQL2017')
    begin
      insert
      into    @dbcc_loginfo_post_SQL2012 (ReoveryUnitId, FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN)
      exec sp_executesql @nsql

      update  @dbcc_loginfo_post_SQL2012
      set     DatabaseName = @database_name
      where   DatabaseName is null
    end
    -----------------------------------------------------------------------------------------------------------
    -- Process SQL Statement for SQL Server 2012, SQL Server 2014, SQL Server 2016 and SQL Server 2017
    -----------------------------------------------------------------------------------------------------------
    if @server_version in ('SQL2008', 'SQL2012', 'SQL2014', 'SQL2016', 'SQL2017')
    begin
      ---------------------------------------------------------------------------------------------------------
      -- Create SQL Statement for database file sizes
      ---------------------------------------------------------------------------------------------------------
      set @nsql = '
      use [[database_name]]; 
      select  file_id
            , (((size * 8192.0) / 1024) / 1024)
            , ''[database_name]'' 
            , case
                when is_percent_growth = 0 then (((growth * 8192.0) / 1024) / 1024)
                when is_percent_growth = 1 then ((((size * (growth / 100)) * 8192.0) / 1024) / 1024)
              end as growth_size_in_mb
      from    [[database_name]].sys.database_files 
      where   type = 1'
      set @nsql = replace(@nsql, '[database_name]', @database_name)

      insert
      into    @database_filesizes
      exec sp_executesql @nsql
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
-- Output Totals
---------------------------------------------------------------------------------------------------------------
select  d.DatabaseName as database_name
      , f.filesize_in_mb as current_logfile_size_in_mb
      , f.growth_size_in_mb as current_autogrowth_size_in_mb
      , count(d.DatabaseName) as current_number_of_vlfs

      , case
          -- >=8GB make 16 512MB VLF's
          when                                      (f.filesize_in_mb >= (8 * 1024)) then 8192 -- 8192: 16 VLF's of 512MB

          --  >1GB make 16 (Autogrowth/16) VLF's
          when (f.filesize_in_mb <  (8 * 1024)) and (f.filesize_in_mb >= (4 * 1024)) then 4096 -- 4096: 16 VLF's of 256MB
          when (f.filesize_in_mb <  (4 * 1024)) and (f.filesize_in_mb >= (2 * 1024)) then 2048 -- 2048: 16 VLF's of 128MB
          when (f.filesize_in_mb <  (2 * 1024)) and (f.filesize_in_mb >= (1 * 1024)) then 1024 -- 1024: 16 VLF's of 64MB

          --  <1GB && >=64MB make 8 (Autogrowth/8) VLF's
          when (f.filesize_in_mb <  (1 * 1024)) and (f.filesize_in_mb >= (     512)) then  512 --  512: 8 VLF's of 64MB
          when (f.filesize_in_mb <  (1 *  512)) and (f.filesize_in_mb >= (     256)) then  256 --  256: 8 VLF's of 32MB
          when (f.filesize_in_mb <  (1 *  256)) and (f.filesize_in_mb >= (     128)) then  128 --  128: 8 VLF's of 16MB
          when (f.filesize_in_mb <  (1 *  128)) and (f.filesize_in_mb >= (      64)) then   64 --   64: 8 VLF's of 8MB

          --  <64MB && >=1MB make 4 (Autogrowth/4) VLF's
          when (f.filesize_in_mb <  (      64)) and (f.filesize_in_mb >= (      32)) then   32 --   32: 4 VLF's of 8MB
          when (f.filesize_in_mb <  (      32)) and (f.filesize_in_mb >= (      16)) then   16 --   16: 4 VLF's of 4MB
          when (f.filesize_in_mb <  (      16)) and (f.filesize_in_mb >= (       8)) then    8 --    8: 4 VLF's of 2MB
          when                                      (f.filesize_in_mb >= (       1)) then    8 --    8: 4 VLF's of 2MB

        end as possible_autogrowth_size_in_mb

      , case
          -- >=8GB make 16 512MB VLF's
          when                                      (f.filesize_in_mb >= (8 * 1024)) then ceiling(f.filesize_in_mb / 8192) * 16 -- 8192: 16 VLF's of 512MB

          --  >1GB make 16 (Autogrowth/16) VLF's
          when (f.filesize_in_mb <  (8 * 1024)) and (f.filesize_in_mb >= (4 * 1024)) then ceiling(f.filesize_in_mb / 4096) * 16 -- 4096: 16 VLF's of 256MB
          when (f.filesize_in_mb <  (4 * 1024)) and (f.filesize_in_mb >= (2 * 1024)) then ceiling(f.filesize_in_mb / 2048) * 16 -- 2048: 16 VLF's of 128MB
          when (f.filesize_in_mb <  (2 * 1024)) and (f.filesize_in_mb >= (1 * 1024)) then ceiling(f.filesize_in_mb / 1024) * 16 -- 1024: 16 VLF's of 64MB

          --  <1GB && >=64MB make 8 (Autogrowth/8) VLF's
          when (f.filesize_in_mb <  (1 * 1024)) and (f.filesize_in_mb >= (     512)) then ceiling(f.filesize_in_mb /  512) * 8 --  512: 8 VLF's of 64MB
          when (f.filesize_in_mb <  (1 *  512)) and (f.filesize_in_mb >= (     256)) then ceiling(f.filesize_in_mb /  256) * 8 --  256: 8 VLF's of 32MB
          when (f.filesize_in_mb <  (1 *  256)) and (f.filesize_in_mb >= (     128)) then ceiling(f.filesize_in_mb /  128) * 8 --  128: 8 VLF's of 16MB
          when (f.filesize_in_mb <  (1 *  128)) and (f.filesize_in_mb >= (      64)) then ceiling(f.filesize_in_mb /   64) * 8 --   64: 8 VLF's of 8MB

          --  <64MB && >=1MB make 4 (Autogrowth/4) VLF's
          when (f.filesize_in_mb <  (      64)) and (f.filesize_in_mb >= (      32)) then ceiling(f.filesize_in_mb /   32) * 4 --   32: 4 VLF's of 8MB
          when (f.filesize_in_mb <  (      32)) and (f.filesize_in_mb >= (      16)) then ceiling(f.filesize_in_mb /   16) * 4 --   16: 4 VLF's of 4MB
          when (f.filesize_in_mb <  (      16)) and (f.filesize_in_mb >= (       8)) then ceiling(f.filesize_in_mb /    8) * 4 --    8: 4 VLF's of 2MB
          when                                      (f.filesize_in_mb >= (       1)) then ceiling(f.filesize_in_mb /    8) * 4 --    8: 4 VLF's of 2MB

        end + @vlf_initial_amount as possible_number_of_vlfs_after_growth

from   (select  FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN, DatabaseName
        from    @dbcc_loginfo_pre_SQL2012
        union all
        select  FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN, DatabaseName
        from    @dbcc_loginfo_post_SQL2012) d
        inner join @database_filesizes f
          on  f.database_name = d.DatabaseName
group by  d.DatabaseName
        , f.filesize_in_mb
        , f.growth_size_in_mb
order by 2 desc
---------------------------------------------------------------------------------------------------------------
-- Output detailed result
---------------------------------------------------------------------------------------------------------------
if @detailed_output = 1
begin
  select @server_version as server_version

  select  *
  from    @database_logfile_growths

  select  d.FileId
        , d.FileSize
        , d.StartOffset
        , d.FSeqNo
        , d.Status
        , d.Parity
        , d.CreateLSN
        , d.DatabaseName
        , f.filesize_in_mb
  from   (select  FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN, DatabaseName
          from    @dbcc_loginfo_pre_SQL2012
          union all
          select  FileId, FileSize, StartOffset, FSeqNo, Status, Parity, CreateLSN, DatabaseName
          from    @dbcc_loginfo_post_SQL2012) d
          inner join @database_filesizes f
            on  f.database_name = d.DatabaseName
end
