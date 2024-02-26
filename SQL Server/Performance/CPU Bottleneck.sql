Performance Monitor 

-- http://www.mssqltips.com/sqlservertip/2316/how-to-identify-sql-server-cpu-bottlenecks/

 Processor:% Processor Time > 80%
- SQL Server: SQL Statistics: SQL Compilations/sec
- SQL Server: SQL Statistics: SQL Recompilations/sec
- SQL Server: SQL Statistics: Batch Requests/sec
ratio: Recompilation / Batch Requests

SQL Server: Cursor Manager By Type – Cursor Requests/Sec (>100/sec : poor cursor usage)
Obs.: SQL Statistics: Batch Requests/sec (low number of batches per sec = parallelism

Dynamic Management Views
```

select plan_handle,
      sum(total_worker_time) as total_worker_time, 
      sum(execution_count) as total_execution_count,
      count(*) as  number_of_statements 
from sys.dm_exec_query_stats
group by plan_handle
order by sum(total_worker_time), sum(execution_count) desc

```

```


```
SQL Profiler
 
SP:Recompile, CursorRecompile, SQL:StmtRecompile: 
Showplan XML For Query Compile (if SQL Compilations/sec is high)
