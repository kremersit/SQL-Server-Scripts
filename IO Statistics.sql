select	file_id
      , num_of_reads
	  , io_stall_read_ms
	  , io_stall_read_ms / (num_of_reads * 1.0) as avg_io_stall_read_ms 
	  , (num_of_bytes_read / (num_of_reads * 1.0) / 1024) / 1024 as avg_num_of_Mbytes_read 

	  , num_of_writes
	  , io_stall_write_ms
	  , io_stall_write_ms / (num_of_writes * 1.0) as avg_io_stall_write_ms 
	  , (num_of_bytes_written / (num_of_writes * 1.0) / 1024) / 1024 as avg_num_of_Mbytes_written 

from	sys.dm_io_virtual_file_stats(db_id(), null)