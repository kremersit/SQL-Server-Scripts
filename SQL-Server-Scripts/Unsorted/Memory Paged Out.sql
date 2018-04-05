/*
https://blogs.msdn.microsoft.com/karthick_pk/2012/06/22/a-significant-part-of-sql-server-process-memory-has-been-paged-out/
We can use the below query to extract information about the condition of OS memory and SQL memory using a query like the following. 
Looking at this query, you will be able to easily determine the various indicators that would have triggered the Windows to 
page various processes including SQL Server. Use the following query to obtain the memory notification-related information 
from the XML data of the ring buffer
*/

SELECT 
CONVERT (varchar(30), GETDATE(), 121) as runtime,
DATEADD (ms, a.[Record Time] - sys.ms_ticks, GETDATE()) AS Notification_time,  
a.* ,
sys.ms_ticks AS [Current Time]
FROM 
(SELECT x.value('(//Record/ResourceMonitor/Notification)[1]', 'varchar(30)') AS [Notification_type], 
x.value('(//Record/MemoryRecord/MemoryUtilization)[1]', 'int') AS [MemoryUtilization %], 
x.value('(//Record/MemoryRecord/TotalPhysicalMemory)[1]', 'bigint') AS [TotalPhysicalMemory_KB], 
x.value('(//Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'bigint') AS [AvailablePhysicalMemory_KB], 
x.value('(//Record/MemoryRecord/TotalPageFile)[1]', 'bigint') AS [TotalPageFile_KB], 
x.value('(//Record/MemoryRecord/AvailablePageFile)[1]', 'bigint') AS [AvailablePageFile_KB], 
x.value('(//Record/MemoryRecord/TotalVirtualAddressSpace)[1]', 'bigint') AS [TotalVirtualAddressSpace_KB], 
x.value('(//Record/MemoryRecord/AvailableVirtualAddressSpace)[1]', 'bigint') AS [AvailableVirtualAddressSpace_KB], 
x.value('(//Record/MemoryNode/@id)[1]', 'int') AS [Node Id], 
x.value('(//Record/MemoryNode/ReservedMemory)[1]', 'bigint') AS [SQL_ReservedMemory_KB], 
x.value('(//Record/MemoryNode/CommittedMemory)[1]', 'bigint') AS [SQL_CommittedMemory_KB], 
x.value('(//Record/@id)[1]', 'bigint') AS [Record Id], 
x.value('(//Record/@type)[1]', 'varchar(30)') AS [Type], 
x.value('(//Record/ResourceMonitor/Indicators)[1]', 'int') AS [Indicators], 
x.value('(//Record/@time)[1]', 'bigint') AS [Record Time]
FROM (SELECT CAST (record as xml) FROM sys.dm_os_ring_buffers 
WHERE ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR') AS R(x)) a 
CROSS JOIN sys.dm_os_sys_info sys
ORDER BY DATEADD (ms, a.[Record Time] - sys.ms_ticks, GETDATE())
