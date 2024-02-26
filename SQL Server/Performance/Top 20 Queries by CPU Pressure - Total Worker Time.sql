
SELECT TOP 20
       qt.text AS 'SP Name'
     , db.name AS 'DBName'
     , qs.total_worker_time AS 'TotalWorkerTime'
     , qs.total_worker_time / qs.execution_count AS 'AvgWorkerTime'
     , qs.execution_count AS 'Execution Count'
     , ISNULL(qs.execution_count / DATEDIFF(SECOND, qs.creation_time, GETDATE()), 0) AS 'Calls/Second'
     , ISNULL(qs.total_elapsed_time / qs.execution_count, 0) AS 'AvgElapsedTime'
     , qs.max_logical_reads
     , qs.max_logical_writes
     , DATEDIFF(MINUTE, qs.creation_time, GETDATE()) AS 'Age in Cache (minutes)'
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
--WHERE qt.dbid = db_id()
ORDER BY qs.total_worker_time DESC;