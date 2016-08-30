SELECT	
        case 
          when data_compression = 0 
          then 'USE [' + db_name(db_id()) + ']; ALTER TABLE [' + s.name + '].[' + st.name + '] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)'
          else ''
        end as sql_statement
      , s.name
      , st.name

      , a.total_pages * 8 / 1024.00 / 1024 AS total_gb
      , a.used_pages  * 8 / 1024.00 / 1024 AS used_gb
	    , st.object_id
      , sp.partition_id
      , sp.partition_number
      , sp.data_compression
      , sp.data_compression_desc
FROM    sys.partitions SP
        INNER JOIN sys.tables ST 
          ON  st.object_id = sp.object_id
        inner join sys.schemas s
          on  s.schema_id = st.schema_id
        INNER JOIN sys.allocation_units a ON a.container_id = sp.partition_id 
order by total_gb desc