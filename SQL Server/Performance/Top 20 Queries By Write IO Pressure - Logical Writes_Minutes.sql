SELECT TOP 20
       qt.text AS 'SP Name'
     , db.name AS 'DB Name'
     , db.name AS 'DB Name'
     , qs.total_logical_writes
     , qs.total_logical_writes / qs.execution_count AS 'AvgLogicalWrites'
     , qs.total_logical_writes / DATEDIFF(MINUTE, qs.creation_time, GETDATE()) AS 'Logical Writes/Min'
     , qs.execution_count AS 'Execution Count'
     , qs.execution_count / DATEDIFF(SECOND, qs.creation_time, GETDATE()) AS 'Calls/Second'
     , qs.total_worker_time / qs.execution_count AS 'AvgWorkerTime'
     , qs.total_worker_time AS 'TotalWorkerTime'
     , qs.total_elapsed_time / qs.execution_count AS 'AvgElapsedTime'
     , qs.max_logical_reads
     , qs.max_logical_writes
     , qs.total_physical_reads
     , DATEDIFF(MINUTE, qs.creation_time, GETDATE()) AS 'Age in Cache'
     , qs.total_physical_reads / qs.execution_count AS 'Avg Physical Reads'
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
ORDER BY qs.total_logical_writes DESC;