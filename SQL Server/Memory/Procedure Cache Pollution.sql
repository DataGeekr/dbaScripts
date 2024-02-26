/* Procedure Cache Pollution */

/* 
Limits: 
     SQLServer 2005 SP2 and higher
          - 75% of visible target memory from 0-4 GB
          - 10% of visible target memory from 4-64 GB
          - 5% of visible target memory > 64 GB

     SQLServer 2005 RTM/SP1
          - 75% of visible target memory from 0-8 GB
          - 50% of visible target memory from 8-64 GB
          - 25% of visible target memory > 64 GB

     SQLServer 2000
          - 4GB upper cap on the plan cache

     Current Versions
          Memory | Plan Cache
          4 GB   | 3.0 GB
          8 GB   | 3.5 GB
          16 GB  | 4.2 GB
          32 GB  | 5.8 GB
          64 GB  | 9.0 GB
          128 GB | 12.2 GB
          256 GB | 30.0 GB
*/



/* Check For Procedure Cache Pollution */
-- What's consuming more memory on Plan cache
SELECT [Cache Type] = [cp].[objtype] 
, [Total Plans] = COUNT_BIG (*) 
, [Total MBs] = SUM (CAST ([cp].[size_in_bytes] AS DECIMAL (18, 2))) / 1024.0 / 1024.0 
, [Avg Use Count] = AVG ([cp].[usecounts]) 
, [Total MBs - USE Count 1] = SUM (CAST ((CASE WHEN [cp].[usecounts] = 1 
                                         THEN [cp].[size_in_bytes] ELSE 0 END) AS DECIMAL (18, 2))) / 1024.0 / 1024.0
, [Total Plans - USE Count 1] = SUM (CASE WHEN [cp].[usecounts] = 1 
                          THEN 1 
                                               ELSE 0 END) 
, [Percent Wasted] = (SUM (CAST ((CASE WHEN [cp].[usecounts] = 1 
                            THEN [cp].[size_in_bytes] 
                                            ELSE 0 
                                       END) AS DECIMAL (18, 2))) / SUM(CONVERT(BIGINT, [cp].[size_in_bytes])) * 100)
FROM [sys].[dm_exec_cached_plans] AS [cp]
GROUP BY [cp].[objtype]
ORDER BY [Total MBs - USE Count 1] DESC;
GO

/* Procedure Cache System Behavior: Stable (1 plan for hash) vs. Unstable (# plans for hash)  */
-- Which queries to go first
SELECT [query_hash]
     , [# Distinct of Plans] = COUNT(DISTINCT [query_plan_hash])
     , [Execution Total] = SUM([execution_count])
     , [Total MB] = SUM(ECP.size_in_bytes) / 1024. / 1024.0
FROM sys.dm_exec_query_stats EQS
     INNER JOIN 
     sys.dm_exec_cached_plans ECP ON ECP.plan_handle = EQS.plan_handle
GROUP BY [query_hash]
ORDER BY [Execution Total] DESC;


/* Check For Query Stats */
-- What's the status for the queries
SELECT [qh].*, [qp].query_plan
FROM (
     SELECT [cp].[objtype]
, [Query Hash] = [qs2].[query_hash] 
, [Query Plan Hash] = [qs2].[query_plan_hash] 
, [Total MB] = SUM ([cp].[size_in_bytes]) / 1024.00 / 1024.00
, [Avg CPU Time] = SUM ([qs2]. [total_worker_time]) / SUM ([qs2] .[execution_count])
, [Avg Logical Reads] = SUM ([qs2]. [total_logical_reads]) / SUM ([qs2]. [execution_count])
, [Avg Physical Reads] = SUM ([qs2]. total_physical_reads) / SUM ([qs2]. [execution_count])
, [Avg Logical Writes] = SUM ([qs2]. total_logical_writes) / SUM ([qs2]. [execution_count])
, [Avg Elapsed Time] = SUM ([qs2]. total_elapsed_time) / SUM ([qs2]. [execution_count])
, [Execution Total] = SUM ([qs2]. [execution_count])
, [Total CPU Cost] = SUM ([qs2]. [total_worker_time])
, [Total Logical Reads] = SUM ([qs2]. [total_logical_reads])
, [Total Physical Reads] = SUM ([qs2]. total_physical_reads)
, [Total Logical Writes] = SUM ([qs2]. total_logical_writes)
, [Total Elapsed Time] = SUM ([qs2]. total_elapsed_time)
, [Example Statement Text] = MIN ([qs2].[statement_text]) 
, [plan_handle] = MIN ([qs2].[plan_handle])
, [statement_start_offset] = MIN ([qs2].[statement_start_offset]) 
FROM (
          SELECT [qs].*
               , SUBSTRING ([st].[text]
               , ([qs].[statement_start_offset] / 2) + 1
               , ((CASE [statement_end_offset] 
                        WHEN -1 
                        THEN DATALENGTH ([st].[text]) 
                        ELSE [qs].[statement_end_offset] 
                    END - [qs].[statement_start_offset]) / 2) + 1
                 ) AS [statement_text]
FROM [sys].[dm_exec_query_stats] AS [qs] 
               CROSS APPLY 
               [sys].[dm_exec_sql_text]([qs].[sql_handle]) AS [st]
WHERE [st].[text] NOT LIKE '%dm_exec%'
               AND   [st].[text] LIKE '%member%lastname%' -- << Termo de pesquisa
               AND ([st].[text] NOT LIKE N'%syscacheobjects%' OR [st].[text] NOT LIKE N'SELECT%cp.objecttype%')
           ) AS [qs2]
INNER JOIN 
           [sys].[dm_exec_cached_plans] AS [cp] ON [qs2].[plan_handle] = [cp].[plan_handle]
     GROUP BY [cp].[objtype], [qs2].[query_hash]
            , [qs2].[query_plan_hash]
     ) AS [qh]
     CROSS APPLY [sys].[dm_exec_query_plan] ([qh].[plan_handle]) AS [qp]
ORDER BY [qh].[Total CPU Cost] DESC;


/* AdHoc Statements in Cache by Size in Bytes (Most Allocation Usage) */
-- Which plans are consuming most space
SELECT TOP (100) [st].[text]
, [cp].[size_in_bytes]
, [cp].[plan_handle]
FROM [sys].[dm_Exec_cached_plans] AS [cp]
    CROSS APPLY [sys].[dm_exec_sql_text]
([cp].[plan_handle]) AS [st]
WHERE [cp].[objtype] = N'Adhoc' 
    AND [cp].[usecounts] = 1
ORDER BY [cp].[size_in_bytes] DESC;
GO


