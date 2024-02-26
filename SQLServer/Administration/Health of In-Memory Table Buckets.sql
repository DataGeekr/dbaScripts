 
SELECT
QUOTENAME
(SCHEMA_NAME(t.schema_id)) + N'.'
 + 
QUOTENAME
(OBJECT_NAME(h.object_id)) 
as
 [
table
],       i.name                   
as
 [
index
],       h.total_bucket_count,      h.empty_bucket_count,      
FLOOR
((        
CAST
(h.empty_bucket_count 
as
 
float
) /          h.total_bucket_count) * 
100
)                               
as
 [empty_bucket_percent],      h.avg_chain_length,       h.max_chain_length    
FROM
           sys.dm_db_xtp_hash_index_stats  
as
 h       
JOIN
 sys.indexes                     
as
 i              
ON
 h.object_id = i.object_id             
AND
 h.index_id  = i.index_id      
JOIN
 sys.memory_optimized_tables_internal_attributes ia 
ON
 h.xtp_object_id=ia.xtp_object_id    
JOIN
 sys.tables t 
on
 h.object_id=t.object_id  
WHERE
 ia.type=
1

  
ORDER
 
BY
 [
table
], [
index
];  


/*
Compare the SELECT results to the following statistical guidelines:
- Empty buckets:
	- 33% is a good target value, but a larger percentage (even 90%) is usually fine.
	- When the bucket count equals the number of distinct key values, approximately 33% of the buckets are empty.
	- A value below 10% is too low.
- Chains within buckets:
	- An average chain length of 1 is ideal in case there are no duplicate index key values. Chain lengths up to 10 are usually acceptable.
	- If the average chain length is greater than 10, and the empty bucket percent is greater than 10%, the data has so many duplicates that a hash index might not be the most appropriate type.

*/