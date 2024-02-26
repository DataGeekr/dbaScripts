SELECT TOP 20
       qt.text AS 'SP Name'
     , db.name AS 'DBName'
     , qs.total_logical_reads
     , qs.execution_count AS 'Execution Count'
     , qs.total_logical_reads / qs.execution_count AS 'AvgLogicalReads'
     , qs.execution_count / DATEDIFF(SECOND, qs.creation_time, GETDATE()) AS 'Calls/Second'
     , qs.total_worker_time / qs.execution_count AS 'AvgWorkerTime'
     , qs.total_worker_time AS 'TotalWorkerTime'
     , qs.total_elapsed_time / qs.execution_count AS 'AvgElapsedTime'
     , qs.total_logical_writes
     , qs.max_logical_reads
     , qs.max_logical_writes
     , qs.total_physical_reads
     , DATEDIFF(MINUTE, qs.creation_time, GETDATE()) AS 'Age in Cache'
     , qp.query_plan
     , qs.query_plan_hash
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY
     sys.dm_exec_sql_text(qs.sql_handle) AS qt
CROSS APPLY
     sys.dm_exec_query_plan((qs.plan_handle)) AS qp
LEFT JOIN
     sys.databases db
            ON qt.dbid = db.database_id
--WHERE    qt.dbid = DB_ID()
ORDER BY total_logical_reads DESC