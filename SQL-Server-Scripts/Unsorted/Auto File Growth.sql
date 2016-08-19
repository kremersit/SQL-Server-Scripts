use tempdb
DECLARE @path NVARCHAR(1000)
SELECT @path = Substring(PATH, 1, Len(PATH) - Charindex('\', Reverse(PATH))) +
                     '\log.trc'
FROM   sys.traces
WHERE  id = 1
SELECT databasename,
      e.name   AS eventname,
      cat.name AS [CategoryName],
      starttime,
      e.category_id,
      loginname,
      loginsid,
      spid,
      hostname,
      applicationname,
      servername,
      textdata,
      objectname,
      eventclass,
      eventsubclass
FROM   ::fn_trace_gettable(@path, 0)
      INNER JOIN sys.trace_events e
        ON eventclass = trace_event_id
      INNER JOIN sys.trace_categories AS cat
        ON e.category_id = cat.category_id
--WHERE  e.name = 'Data File Auto Grow'
WHERE  e.name IN( 'Data File Auto Grow','Log File Auto Grow' )
--WHERE  e.name IN ('Log File Auto Grow' )
AND    StartTime>=GETDATE()-14
ORDER  BY starttime DESC 