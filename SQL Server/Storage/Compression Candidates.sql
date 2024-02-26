/*
U: The percentage of update operations on a specific table, index, or partition, relative to total operations on that object. The lower the value of U (that is, the table, index, or partition is infrequently updated), the better candidate it is for page compression.
S: The percentage of scan operations on a table, index, or partition, relative to total operations on that object. The higher the value of S (that is, the table, index, or partition is mostly scanned), the better candidate it is for page compression.
*/
-- U: Percent of Update Operations on the Object
SELECT o. name AS [Table_Name] , x. name AS [Index_Name] ,
       i .partition_number AS [Partition],
       i .index_id AS [Index_ID], x .type_desc AS [Index_Type],
       i .leaf_update_count * 100.0 /
           (i. range_scan_count + i .leaf_insert_count
            + i. leaf_delete_count + i .leaf_update_count
            + i. leaf_page_merge_count + i .singleton_lookup_count
           ) AS [Percent_Update]
FROM sys .dm_db_index_operational_stats (db_id(), NULL, NULL, NULL) i
JOIN sys .objects o ON o. object_id = i.object_id
JOIN sys .indexes x ON x. object_id = i.object_id AND x .index_id = i.index_id
WHERE (i .range_scan_count + i.leaf_insert_count
       + i. leaf_delete_count + leaf_update_count
       + i. leaf_page_merge_count + i .singleton_lookup_count) != 0
AND objectproperty (i. object_id,'IsUserTable' ) = 1
ORDER BY [Percent_Update] ASC

-- S: Percent of Scan Operations on the Object
SELECT o. name AS [Table_Name] , x. name AS [Index_Name] ,
       i .partition_number AS [Partition],
       i .index_id AS [Index_ID], x .type_desc AS [Index_Type],
       i .range_scan_count * 100.0 /
           (i. range_scan_count + i .leaf_insert_count
            + i. leaf_delete_count + i .leaf_update_count
            + i. leaf_page_merge_count + i .singleton_lookup_count
           ) AS [Percent_Scan]
FROM sys .dm_db_index_operational_stats (db_id(), NULL, NULL, NULL) i
JOIN sys .objects o ON o. object_id = i.object_id
JOIN sys .indexes x ON x. object_id = i.object_id AND x .index_id = i.index_id
WHERE (i .range_scan_count + i.leaf_insert_count
       + i. leaf_delete_count + leaf_update_count
       + i. leaf_page_merge_count + i .singleton_lookup_count) != 0
AND objectproperty (i. object_id,'IsUserTable' ) = 1
ORDER BY [Percent_Scan] DESC