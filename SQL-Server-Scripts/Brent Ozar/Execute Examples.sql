use master
go
declare @sp_BlitzCache bit = 0
      , @sp_BlitzFirst bit = 0
      , @sp_BlitzTrace bit = 1
/*dbo.sp_BlitzCache */ 
if @sp_BlitzCache = 1
exec dbo.sp_BlitzCache
    @Help = 0,
    @Top = 10,
    @SortOrder = 'CPU',
    @UseTriggersAnyway = NULL,
    @ExportToExcel = 0,
    @ExpertMode = 1,
    @OutputServerName = NULL ,
    @OutputDatabaseName = NULL ,
    @OutputSchemaName = NULL ,
    @OutputTableName = NULL ,
    @ConfigurationDatabaseName = NULL ,
    @ConfigurationSchemaName = NULL ,
    @ConfigurationTableName = NULL ,
    @DurationFilter = NULL ,
    @HideSummary = 0 ,
    @IgnoreSystemDBs = 1 ,
    @OnlyQueryHashes = NULL ,
    @IgnoreQueryHashes = NULL ,
    @OnlySqlHandles = NULL ,
    @QueryFilter = 'ALL' ,
    @DatabaseName = NULL ,
    @Reanalyze = 0 ,
    @SkipAnalysis = 0 ,
    @BringThePain = 0 /* This will forcibly set @Top to 2,147,483,647 */

if @sp_BlitzFirst = 1
exec [dbo].[sp_BlitzFirst]
    @Question= NULL ,
    @Help = 0 ,
    @AsOf = NULL ,
    @ExpertMode = 1 ,
    @Seconds = 5 ,
    @OutputType = 'TABLE' ,
    @OutputServerName = NULL ,
    @OutputDatabaseName = NULL ,
    @OutputSchemaName = NULL ,
    @OutputTableName = NULL ,
    @OutputTableNameFileStats = NULL ,
    @OutputTableNamePerfmonStats = NULL ,
    @OutputTableNameWaitStats = NULL ,
    @OutputXMLasNVARCHAR = 0 ,
    @FilterPlansByDatabase = NULL ,
    @CheckProcedureCache = 0 ,
    @FileLatencyThresholdMS = 100 ,
    @SinceStartup = 0 ,
    @VersionDate = NULL 


if @sp_BlitzTrace = 1
begin


  --List running sessions
  exec sp_BlitzTrace @Action='start';

  --Start a trace for a session. You specify the @SessionID and @TargetPath
  exec sp_BlitzTrace @SessionId=54, @TargetPath='D:\Temp\', @Action='start';

  --Stop a session
  exec sp_BlitzTrace @Action='stop';

  --Read the results. You can move the files to another server and read there by specifying a @TargetPath.
  exec sp_BlitzTrace @Action='read';

  --Drop the session. This does NOT delete files created in @TargetPath.
  exec sp_BlitzTrace @Action='drop';

end