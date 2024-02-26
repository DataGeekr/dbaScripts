/* System Sessions Waits - Ignorable */
SELECT DISTINCT
       wt .wait_type
FROM sys .dm_os_waiting_tasks AS wt
     INNER JOIN
     sys.dm_exec_sessions AS s
          ON wt. session_id = s .session_id
WHERE s. is_user_process = 0

/* TOP 10 Cumulative Wait Events */
;WITH [Waits]
AS (
   SELECT wait_type
        , wait_time_ms / 1000.0 AS [WaitS] -- ver também max_wait_time_ms
        , ( wait_time_ms - signal_wait_time_ms ) / 1000.0 AS [ResourceS]
        , signal_wait_time_ms / 1000.0 AS [SignalS]
        , waiting_tasks_count AS [WaitCount]
        , 100.0 * wait_time_ms / SUM(wait_time_ms ) OVER () AS [Percentage]
        , ROW_NUMBER () OVER (ORDER BY wait_time_ms DESC ) AS [RowNum]
   FROM sys.dm_os_wait_stats WITH ( NOLOCK)
   WHERE waiting_tasks_count > 0
   AND   [wait_type] NOT IN (N'BROKER_EVENTHANDLER' ,
                             N'BROKER_RECEIVE_WAITFOR',
                             N'BROKER_TASK_STOP',
                             N'BROKER_TO_FLUSH',
                             N'BROKER_TRANSMITTER',
                             N'CHECKPOINT_QUEUE', N'CHKPT',
                             N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT',
                             N'CLR_SEMAPHORE',
                             N'DBMIRROR_DBM_EVENT',
                             N'DBMIRROR_EVENTS_QUEUE',
                             N'DBMIRROR_WORKER_QUEUE',
                             N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL',
                             N'DISPATCHER_QUEUE_SEMAPHORE',
                             N'EXECSYNC', N'FSAGENT',
                             N'FT_IFTS_SCHEDULER_IDLE_WAIT',
                             N'FT_IFTSHC_MUTEX',
                             N'HADR_CLUSAPI_CALL',
                             N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
                             N'HADR_LOGCAPTURE_WAIT',
                             N'HADR_NOTIFICATION_DEQUEUE',
                             N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
                             N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP',
                             N'LOGMGR_QUEUE',
                             N'ONDEMAND_TASK_QUEUE',
                             N'PWAIT_ALL_COMPONENTS_INITIALIZED',
                             N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
                             N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP' ,
                             N'REQUEST_FOR_DEADLOCK_SEARCH',
                             N'RESOURCE_QUEUE',
                             N'SERVER_IDLE_CHECK',
                             N'SLEEP_BPOOL_FLUSH',
                             N'SLEEP_DBSTARTUP',
                             N'SLEEP_DCOMSTARTUP',
                             N'SLEEP_MASTERDBREADY',
                             N'SLEEP_MASTERMDREADY',
                             N'SLEEP_MASTERUPGRADED',
                             N'SLEEP_MSDBSTARTUP',
                             N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
                             N'SLEEP_TEMPDBSTARTUP',
                             N'SNI_HTTP_ACCEPT',
                             N'SP_SERVER_DIAGNOSTICS_SLEEP',
                             N'SQLTRACE_BUFFER_FLUSH',
                             N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
                             N'SQLTRACE_WAIT_ENTRIES',
                             N'WAIT_FOR_RESULTS', N'WAITFOR',
                             N'WAITFOR_TASKSHUTDOWN',
                             N'WAIT_XTP_HOST_WAIT',
                             N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
                             N'WAIT_XTP_CKPT_CLOSE',
                             N'XE_DISPATCHER_JOIN',
                             N'XE_DISPATCHER_WAIT',
                             N'XE_TIMER_EVENT',
                             N'QDS_SHUTDOWN_QUEUE')
         )

SELECT MAX (W1. wait_type) AS [WaitType]
     , CAST (MAX (W1. WaitS) AS DECIMAL (16, 2)) AS [WaitSec]
     , CAST (MAX (W1. ResourceS) AS DECIMAL (16, 2)) AS [ResourceWait_Sec]
     , CAST (MAX (W1. SignalS) AS DECIMAL (16, 2)) AS [SignalWaitSec]
     , MAX (W1. WaitCount) AS [Wait Count]
     , CAST (MAX (W1. Percentage) AS DECIMAL (5, 2)) AS [Wait Percentage]
     , CAST ((MAX (W1. WaitS) / MAX (W1. WaitCount)) AS DECIMAL (16, 4)) AS [AvgWait_Sec]
     , CAST ((MAX (W1. ResourceS) / MAX (W1. WaitCount)) AS DECIMAL (16, 4)) AS [AvgRes_Sec]
     , CAST ((MAX (W1. SignalS) / MAX (W1. WaitCount)) AS DECIMAL (16, 4)) AS [AvgSig_Sec]
     , [Description] = CASE
                            WHEN MAX (W1. wait_type) = 'CXPACKET'
                            THEN 'Queries executadas em paralelismo. Tempo de espera para entre o DistributeStream e o GatherStream. (Professor)'
                            WHEN MAX (W1. wait_type) = 'SOS_SCHEDULER_YIELD'
                            THEN 'Espera em que um processo libera a thread para outro utilizar enquanto permanece na fila de runnable. (Esteira)'
                            WHEN MAX (W1. wait_type) = 'THREADPOOL'
                            THEN 'Espera de worker para atender a thread para iniciar execução. Falta de CPU para atender todas as threads ou muitos blocks.'
                            WHEN MAX (W1. wait_type) LIKE 'LCK_%'
                            THEN 'Significa que blocking está ocorrendo e as sessões necessitam esperar para adquirir um lock no recursos. Investigação: sys.dm_db_index_operational_stats.'
                            WHEN MAX (W1. wait_type) LIKE 'PAGEIOLATCH_%'
                            THEN 'Normalmente associado a gargalo de I/O. Queries com baixa performance ou falta de índices. Atraso na capacidade de ler ou escrever dados no disco.'
                            WHEN MAX (W1. wait_type) IN ( 'IO_COMPLETION', 'WRITELOG')
                            THEN 'Normalmente associado a gargalo de I/O. WRITELOG é relacionado a problemas em escrever em arquivos de log, validar em conjunto com Virtual File Stats.'
                            WHEN MAX (W1. wait_type) LIKE 'PAGELATCH_%'
                            THEN 'Espera não relacionada a I/O com lag em data pages no Buffer Pool. Comumente associada a problemas de contenção de alocação. Ver contenção na tempdb e páginas SGAM, GAM ou FPS.'
                            WHEN MAX (W1. wait_type) LIKE 'LATCH_%'
                            THEN 'Esta espera é associada com sincronização de objetos de curta duração que são usados para proteção de caches internos mas não do buffer cache. Para identificar qual a classe de latch que está com problema, verificar em sys.dm_os_latch_stats.'
                            WHEN MAX (W1. wait_type) = 'ASYNC_NETWORK_IO'
                            THEN 'Provavelmente, a aplicação está realizando uma processamento Linha-a-Linha dos registros retornados pelo SQL Server (O cliente aceita um registro, processa, aceita um novo e assim vai).'
                            ELSE MAX (W1. wait_type)
                       END   
FROM Waits AS W1
     INNER JOIN
     Waits AS W2
          ON W2. RowNum <= W1 .RowNum
GROUP BY W1.RowNum
HAVING   SUM (W2. Percentage) - MAX (W1. Percentage) < 99 -- percentage threshold OPTION (RECOMPILE);

/* Clearing the wait statistics on a server */
DBCC SQLPERF( 'sys.dm_os_wait_stats', clear);

/* Virtual File Statistics */
SELECT  DB_NAME (vfs. database_id) AS database_name ,
        vfs .database_id ,
        vfs .FILE_ID ,
        io_stall_read_ms / NULLIF (num_of_reads, 0) AS avg_read_latency ,
        io_stall_write_ms / NULLIF (num_of_writes, 0)
                                               AS avg_write_latency ,
        io_stall / NULLIF (num_of_reads + num_of_writes, 0 )
                                               AS avg_total_latency ,
        num_of_bytes_read / NULLIF (num_of_reads, 0)
                                               AS avg_bytes_per_read ,
        num_of_bytes_written / NULLIF (num_of_writes, 0)
                                               AS avg_bytes_per_write ,
        vfs .io_stall ,
        vfs .num_of_reads ,
        vfs .num_of_bytes_read ,
        vfs .io_stall_read_ms ,
        vfs .num_of_writes ,
        vfs .num_of_bytes_written ,
        vfs .io_stall_write_ms ,
        size_on_disk_bytes / 1024 / 1024. AS size_on_disk_mbytes ,
        physical_name
FROM    sys .dm_io_virtual_file_stats(NULL, NULL) AS vfs
        JOIN sys .master_files AS mf ON vfs.database_id = mf. database_id
                                       AND vfs. FILE_ID = mf.FILE_ID
ORDER BY avg_total_latency DESC

/* Perfmon Counter Analysis

Access Methods: Modo como as tabelas estão sendo acessadas (FullScans * 800-1000 = IndexSearch)   
     SQLServer:Access Methods\Full Scans/sec
     SQLServer:Access Methods\Index Searches/sec

Buffer Manager: Memory Pressure
SQLServer:Buffer Manager\Lazy Writes/sec
SQLServer:Buffer Manager\Page life expectancy ('sp_configure max server memory'/4 * 300, 4 means 4GB)
SQLServer:Buffer Manager\Free list stalls/sec

SQLServer:General Statistics\Processes Blocked
SQLServer:General Statistics\User Connections
SQLServer:Locks\Lock Waits/sec
SQLServer:Locks\Lock Wait Time (ms)

Memory Manager: Falta de memória ou grande uso de sorts e hashes (spill)
     SQLServer:Memory Manager\Memory Grants Pending

SQL Statistics: Proporção entre Batch Requests e Compilações (Ad Hoc Workload sem uso adequado do plan cache) e ReCompilações (Codicação pobre)
     SQLServer:SQL Statistics\Batch Requests/sec
     SQLServer:SQL Statistics\SQL Compilations/sec
     SQLServer:SQL Statistics\SQL Re-Compilations/sec

*/
DECLARE @CounterPrefix NVARCHAR (30)
SET @CounterPrefix = CASE
    WHEN @@SERVICENAME = 'MSSQLSERVER'
    THEN 'SQLServer:'
    ELSE 'MSSQL$'+@@SERVICENAME +':'
    END;


-- Capture the first counter set
SELECT CAST (1 AS INT) AS collection_instance ,
      [OBJECT_NAME] ,
      counter_name ,
      instance_name ,
      cntr_value ,
      cntr_type ,
      CURRENT_TIMESTAMP AS collection_time
INTO #perf_counters_init
FROM sys .dm_os_performance_counters
WHERE ( OBJECT_NAME = @CounterPrefix+'Access Methods'
         AND counter_name = 'Full Scans/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Access Methods'
           AND counter_name = 'Index Searches/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Buffer Manager'
           AND counter_name = 'Lazy Writes/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Buffer Manager'
      AND counter_name = 'Page life expectancy'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'General Statistics'
           AND counter_name = 'Processes Blocked'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'General Statistics'
           AND counter_name = 'User Connections'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Locks'
           AND counter_name = 'Lock Waits/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Locks'
           AND counter_name = 'Lock Wait Time (ms)'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'SQL Statistics'
           AND counter_name = 'SQL Re-Compilations/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Memory Manager'
           AND counter_name = 'Memory Grants Pending'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'SQL Statistics'
           AND counter_name = 'Batch Requests/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'SQL Statistics'
           AND counter_name = 'SQL Compilations/sec'
)

-- Wait on Second between data collection
WAITFOR DELAY '00:00:05'

-- Capture the second counter set
SELECT CAST (2 AS INT) AS collection_instance ,
       OBJECT_NAME ,
       counter_name ,
       instance_name ,
       cntr_value ,
       cntr_type ,
       CURRENT_TIMESTAMP AS collection_time
INTO #perf_counters_second
FROM sys .dm_os_performance_counters
WHERE ( OBJECT_NAME = @CounterPrefix+'Access Methods'
      AND counter_name = 'Full Scans/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Access Methods'
           AND counter_name = 'Index Searches/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Buffer Manager'
           AND counter_name = 'Lazy Writes/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Buffer Manager'
           AND counter_name = 'Page life expectancy'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'General Statistics'
           AND counter_name = 'Processes Blocked'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'General Statistics'
           AND counter_name = 'User Connections'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Locks'
           AND counter_name = 'Lock Waits/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Locks'
           AND counter_name = 'Lock Wait Time (ms)'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'SQL Statistics'
           AND counter_name = 'SQL Re-Compilations/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'Memory Manager'
           AND counter_name = 'Memory Grants Pending'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'SQL Statistics'
           AND counter_name = 'Batch Requests/sec'
      )
      OR ( OBJECT_NAME = @CounterPrefix+ 'SQL Statistics'
           AND counter_name = 'SQL Compilations/sec'
)

-- Calculate the cumulative counter values
SELECT  i. OBJECT_NAME ,
        i .counter_name ,
        i .instance_name ,
        CASE WHEN i.cntr_type = 272696576
          THEN s. cntr_value - i .cntr_value
          WHEN i. cntr_type = 65792 THEN s. cntr_value
        END AS cntr_value
FROM #perf_counters_init AS i
  JOIN  #perf_counters_second AS s
    ON i .collection_instance + 1 = s .collection_instance
      AND i. OBJECT_NAME = s.OBJECT_NAME
      AND i. counter_name = s .counter_name
      AND i. instance_name = s .instance_name
ORDER BY OBJECT_NAME

-- Cleanup tables
DROP TABLE #perf_counters_init
DROP TABLE #perf_counters_second


/* SQL Server Execution Stats */
SELECT TOP 10
        execution_count ,
        statement_start_offset AS stmt_start_offset ,
        sql_handle ,
        plan_handle ,
        total_logical_reads / execution_count AS avg_logical_reads ,
        total_logical_writes / execution_count AS avg_logical_writes ,
        total_physical_reads / execution_count AS avg_physical_reads ,
        t .TEXT
FROM    sys .dm_exec_query_stats AS s
        CROSS APPLY sys. dm_exec_sql_text(s .sql_handle) AS t
ORDER BY avg_physical_reads DESC -- Alterar a ordenação