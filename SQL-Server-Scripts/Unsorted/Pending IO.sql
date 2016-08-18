SELECT vfs.database_id, df.name, df.physical_name
,vfs.FILE_ID, ior.io_pending
FROM sys.dm_io_pending_io_requests ior
INNER JOIN sys.dm_io_virtual_file_stats (DB_ID(), NULL) vfs
ON (vfs.file_handle = ior.io_handle)
INNER JOIN sys.database_files df ON (df.FILE_ID = vfs.FILE_ID)

select * from sys.dm_io_pending_io_requests

SELECT	ipir.io_type, ipir.io_pending,
	ipir.scheduler_address, ipir.io_handle,
	os.scheduler_id, os.cpu_id, os.pending_disk_io_count
FROM sys.dm_io_pending_io_requests ipir
INNER JOIN sys.dm_os_schedulers os
ON ipir.scheduler_address = os.scheduler_address

go 3
