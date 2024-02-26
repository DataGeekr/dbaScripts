SELECT [Volume] = LEFT(mf.physical_name, 2)
     , [Database] = DB_NAME(vfs.database_id)
     , [Filename] = mf.physical_name
     --virtual file latency
     , [AvgReadLatency] = CASE WHEN vfs.num_of_reads = 0 THEN 0 ELSE ( vfs.io_stall_read_ms / vfs.num_of_reads ) END
     , [AvgWriteLatency] = CASE WHEN vfs.num_of_writes = 0 THEN 0 ELSE ( vfs.io_stall_write_ms / vfs.num_of_writes ) END
     , [Latency] = CASE WHEN (vfs.num_of_reads = 0 AND vfs.num_of_writes = 0) THEN 0 ELSE (vfs.io_stall / (vfs.num_of_reads + vfs.num_of_writes)) END
     -- IO per sec
     , [kBytesReadsPerSec] = CASE WHEN vfs.num_of_reads = 0 THEN 0 ELSE ((vfs.num_of_bytes_read / ( vfs.sample_ms / 1000)) * 1.0 / 1024 ) END
     , [kBytesWritesPerSec] = CASE WHEN vfs.num_of_reads = 0 THEN 0 ELSE ((vfs.num_of_bytes_written / ( vfs.sample_ms / 1000)) * 1.0 / 1024 ) END
     -- Avg bytes per IOP
     , [AvgBPerRead] = CASE WHEN vfs.num_of_reads = 0 THEN 0 ELSE ( vfs.num_of_bytes_read / vfs.num_of_reads ) END
     , [AvgBPerWrite] = CASE WHEN vfs.io_stall_write_ms = 0 THEN 0 ELSE ( vfs.num_of_bytes_written / vfs.num_of_writes ) END
     , [AvgBPerTransfer] = CASE WHEN (vfs.num_of_reads = 0 AND vfs.num_of_writes = 0) THEN 0 ELSE ((vfs.num_of_bytes_read + vfs.num_of_bytes_written) / (vfs.num_of_reads + vfs.num_of_writes )) END
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS [vfs]
INNER JOIN
     sys.master_files AS [mf]
          ON  vfs.database_id = mf.database_id
          AND vfs.file_id = mf.file_id
ORDER BY [Database] ASC, [Type] DESC;
GO