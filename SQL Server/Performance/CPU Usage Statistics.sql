
WITH DB_CPU_Stats
      AS (
          SELECT    DatabaseID
                  , DB_NAME (DatabaseID) AS [DatabaseName]
                  , SUM (total_worker_time) AS [CPU_Time(Ms)]
          FROM      sys .dm_exec_query_stats AS qs
                    CROSS APPLY (
                                 SELECT CONVERT (INT, value) AS [DatabaseID]
                                 FROM   sys.dm_exec_plan_attributes (qs. plan_handle)
                                 WHERE  attribute = N'dbid'
                                ) AS epa
          GROUP BY   DatabaseID
         )
     SELECT    ROW_NUMBER () OVER (ORDER BY [CPU_Time(Ms)] DESC ) AS [row_num]
             , DatabaseName
             , [CPU_Time(Ms)]
             , CAST ([CPU_Time(Ms)] * 1.0 / SUM([CPU_Time(Ms)] ) OVER () * 100.0 AS DECIMAL(5 ,2)) AS [CPUPercent]
     FROM      DB_CPU_Stats
     WHERE     DatabaseID > 4 -- system databases
               AND DatabaseID <> 32767 -- ResourceDB
ORDER BY        row_num
OPTION    (RECOMPILE);


DECLARE @ts BIGINT
SELECT @ts =( SELECT cpu_ticks/( cpu_ticks/ms_ticks )
FROM sys .dm_os_sys_info);
SELECT TOP 100 PERCENT SQLProcessUtilization AS [SQLServer_Process_CPU_Utilization],
SystemIdle AS [System_Idle_Process] ,
100 - SystemIdle - SQLProcessUtilization AS [Other_Process_CPU_Utilization],
DATEADD(ms ,-1 *( @ts - [timestamp] ),GETDATE()) AS [Event_Time]
FROM (SELECT record.value ('(./Record/@id)[1]', 'int')AS record_id,
record.value ('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]','int' )AS [SystemIdle] ,
record.value ('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]','int' )AS [SQLProcessUtilization] ,
[timestamp]
     FROM (SELECT [timestamp],
convert(xml , record) AS [record]
            FROM sys .dm_os_ring_buffers
            WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
AND record LIKE '%%')AS x
)AS y
ORDER BY record_id DESC;