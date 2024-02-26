--sp_helptext 'web.sp_Blitz'


/* buffer pool usage by database */
SELECT CASE database_id WHEN 32767 THEN 'ResourceDB'
                                   ELSE db_name (database_id)
       END AS database_name
     , COUNT (1) AS cached_pages_count
     , CONVERT (DECIMAL( 13,2 ), COUNT (1) * .0078125 ) as cached_megabytes
FROM sys .dm_os_buffer_descriptors
GROUP BY db_name( database_id), database_id
ORDER BY cached_pages_count DESC

/* Page life expectancy in secs */
-- Page Life Expectancy (PLE) value for each NUMA node in current instance  (Query 41) (PLE by NUMA Node)
SELECT @@SERVERNAME AS [Server Name] , [object_name], instance_name, cntr_value AS [Page Life Expectancy]
FROM sys .dm_os_performance_counters WITH (NOLOCK )
WHERE [object_name] LIKE N'%Buffer Node%' -- Handles named instances
AND counter_name = N'Page life expectancy' OPTION (RECOMPILE );

/* Latency of data files */

-- Calculates average stalls per read, per write, and per total input/output for each database file  (Query 25) (IO Stalls by File)
SELECT DB_NAME (fs. database_id) AS [Database Name], CAST( fs.io_stall_read_ms /(1.0 + fs.num_of_reads) AS NUMERIC(10 ,1)) AS [avg_read_stall_ms] ,
CAST(fs .io_stall_write_ms/( 1.0 + fs .num_of_writes) AS NUMERIC(10 ,1)) AS [avg_write_stall_ms],
CAST((fs .io_stall_read_ms + fs.io_stall_write_ms )/(1.0 + fs.num_of_reads + fs.num_of_writes) AS NUMERIC(10 ,1)) AS [avg_io_stall_ms] ,
CONVERT(DECIMAL (18, 2), mf .size/ 128.0) AS [File Size (MB)], mf.physical_name , mf.type_desc, fs.io_stall_read_ms , fs. num_of_reads,
fs.io_stall_write_ms , fs. num_of_writes, fs .io_stall_read_ms + fs.io_stall_write_ms AS [io_stalls], fs.num_of_reads + fs. num_of_writes AS [total_io]
FROM sys .dm_io_virtual_file_stats(null,null) AS fs
INNER JOIN sys. master_files AS mf WITH ( NOLOCK)
ON fs. database_id = mf .database_id
AND fs. [file_id] = mf .[file_id]
WHERE num_of_reads > 10000
AND num_of_writes > 1000
ORDER BY avg_read_stall_ms DESC OPTION (RECOMPILE );

-- Metrics: http://technet.microsoft.com/en-us/library/cc966401.aspx
-- SQLCat: https://blogs.msdn.com/b/sqlcat/archive/2006/06/23/tom-davidson-sqlcat-best-practices.aspx

/* Backups */

SELECT [ServerName] = @@SERVERNAME
     , [BackupYear] = YEAR( backup_finish_date)
     , [BackupMonth] = MONTH( backup_finish_date)
     , [Throughput_MB_sec_AVG] = CAST( AVG(backup_size / ( DATEDIFF(ss , bset.backup_start_date, bset.backup_finish_date ))) / 1048576 AS DECIMAL(15 ,2))
     , [Throughput_MB_sec_MIN] = CAST( MIN(backup_size / ( DATEDIFF(ss , bset.backup_start_date, bset.backup_finish_date ))) / 1048576 AS DECIMAL(15 ,2))
     , [Throughput_MB_sec_MAX] = CAST( MAX(backup_size / ( DATEDIFF(ss , bset.backup_start_date, bset.backup_finish_date ))) / 1048576 AS DECIMAL(15 ,2))
FROM msdb. dbo.backupset bset
WHERE bset. type = 'D' -- backup fulls
AND   bset. backup_size > 5368709120 -- >= 5GB
AND   DATEDIFF (ss, bset.backup_start_date , bset. backup_finish_date) > 1
GROUP BY YEAR( backup_finish_date), MONTH(backup_finish_date )
ORDER BY @@SERVERNAME, YEAR( backup_finish_date) DESC, MONTH(backup_finish_date ) DESC