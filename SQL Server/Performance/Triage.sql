
```
DECLARE @schema VARCHAR(MAX);
EXEC dbo.sp_WhoIsActive @show_own_spid = 1       -- bit
                      , @get_full_inner_text = 1 -- bit
                      , @get_outer_command = 1   -- bit
                      , @get_locks = 1           -- bit
                      , @find_block_leaders = 1; -- bit


SELECT scheduler_id
     , cpu_id
     , current_tasks_count
     , runnable_tasks_count
     , current_workers_count
     , active_workers_count
     , work_queue_count
FROM  sys.dm_os_schedulers
WHERE scheduler_id < 255;


SELECT TOP ( 10 )
       wait_type
     , CAST(( [wait_time_ms] / 1000.0 ) AS DECIMAL(16, 2))                          AS [WaitS]
     , CAST(100.0 * [wait_time_ms] / SUM([wait_time_ms]) OVER () AS DECIMAL(16, 2)) AS [Percentage]
FROM  sys.dm_db_wait_stats
ORDER BY [Percentage] DESC;


-- Connection Pooling
SELECT DB_NAME(dbid) AS DBName
     , COUNT(dbid)   AS NumberOfConnections
     , loginame      AS LoginName
FROM  sys.sysprocesses
WHERE dbid > 0
GROUP BY dbid
       , loginame;
```
