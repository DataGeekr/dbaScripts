SELECT node_id = node_id
     , physical_operator_name = physical_operator_name
     , row_count = SUM( row_count )
     , estimate_row_count = SUM( estimate_row_count )
     , estimate_percent_complete = CAST(SUM( row_count ) * 100 AS FLOAT) / SUM( IIF(estimate_row_count = 0, 1, estimate_row_count))
FROM sys.dm_exec_query_profiles
WHERE session_id = xxxx
GROUP BY node_id
       , physical_operator_name
ORDER BY node_id DESC;