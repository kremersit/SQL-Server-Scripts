set nocount on;
DECLARE @total BIGINT
SELECT  @total = SUM(CAST(cpu as BigInt)) 
FROM    sys.sysprocesses sp (NOLOCK)
        join sys.sysdatabases sb (NOLOCK) 
          ON  sp.dbid = sb.dbid
where   sb.name <> 'DBA'
AND     sb.name <> 'SQLMonitor3'

IF (@total > 0)
BEGIN
  SELECT  sb.name 'database'
        , @total 'total_sql_server_cpu'
        , ISNULL(SUM(cast(sp.cpu as BigInt)),0) 'database_cpu'
        , getDate() as insert_date
  FROM    sys.sysdatabases sb (NOLOCK) 
          LEFT JOIN sys.sysprocesses sp (NOLOCK) 
            ON  sp.dbid = sb.dbid
  WHERE   sb.name <> 'DBA'
  AND     sb.name <> 'SQLMonitor3'
  AND     sb.dbid > 4
  GROUP BY sb.name
  ORDER BY  CONVERT(DECIMAL(5,2)
          , CONVERT(DECIMAL(17,2)
          , SUM(cast(cpu as BigInt))) / CONVERT(DECIMAL(17,2),@total)*CONVERT(DECIMAL(17,2),100)) DESC
END
