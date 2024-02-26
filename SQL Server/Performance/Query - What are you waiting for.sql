
```

-- Let's get queries ordered by total waiting time
select 
 qt.query_text_id,
   q.query_id,
 p.plan_id,
  sum(total_query_wait_time_ms) as sum_total_wait_ms
from sys.query_store_wait_stats ws
join sys.query_store_plan p on ws.plan_id = p.plan_id
join sys.query_store_query q on p.query_id = q.query_id
join sys.query_store_query_text qt on q.query_text_id = qt.query_text_id
group by qt.query_text_id, q.query_id, p.plan_id
order by sum_total_wait_ms desc


-- Query with plan id = 8 has highest wait time, let's what wait categories contribute 
-- to this total time
select wait_category_desc, sum(total_query_wait_time_ms)
from sys.query_store_wait_stats
where plan_id = 7589
group by wait_category_desc

-- Aha, it's locking, let's see actual query text for the above plan
select query_sql_text
from sys.query_store_query_text
where query_text_id = 4236

-- Query text is (@2 tinyint,@1 int)UPDATE [testtbl] set [c1] = @1  WHERE [id]<@2 
-- Let's see other queries that access this table

select query_text_id, query_sql_text
from sys.query_store_query_text
where query_sql_text like '%testtbl%'

-- Now we have list of queries that could try to access this table at the same time,
-- so consider changing the application logic to improve concurrency, or use a less restrictive isolation level.
```
