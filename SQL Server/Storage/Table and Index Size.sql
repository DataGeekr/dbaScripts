SELECT t.name AS tablename,
       s.name AS schemaname,
       p.rows AS rowcounts,
       (SUM(a.total_pages) * 8 / 1024) AS totalspacemb,
       (SUM(a.used_pages) * 8 / 1024) AS usedspacemb,
       ((SUM(a.total_pages) - SUM(a.used_pages)) * 8 / 1024) AS unusedspacekb,
       fg.name AS filegroupname,
       fg.type AS filegrouptype
FROM sys.tables t
    INNER JOIN sys.indexes i
        ON t.object_id = i.object_id
    INNER JOIN sys.partitions p
        ON i.object_id = p.object_id
           AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a
        ON p.partition_id = a.container_id
    LEFT OUTER JOIN sys.partition_schemes ps
        ON i.data_space_id = ps.data_space_id
    LEFT OUTER JOIN sys.destination_data_spaces dds
        ON ps.data_space_id = dds.partition_scheme_id
           AND p.partition_number = dds.destination_id
    INNER JOIN sys.filegroups fg
        ON COALESCE(dds.data_space_id, i.data_space_id) = fg.data_space_id
    LEFT OUTER JOIN sys.schemas s
        ON t.schema_id = s.schema_id
WHERE t.name NOT LIKE 'dt%'
      AND t.is_ms_shipped = 0
      AND i.object_id > 255
GROUP BY t.name, s.name, p.rows, fg.name, fg.type
ORDER BY 4 DESC, 1;

-- Indexes
SELECT   Object_name( i.object_id ) AS tablename ,
        i.NAME                     AS indexname ,
        i.index_id                 AS indexid ,
        8 * Sum( a.used_pages )    AS 'IndexSize(KB)'
FROM     sys.indexes                AS i
JOIN     sys.partitions             AS p
ON       p.object_id = i.object_id
AND      p.index_id = i.index_id
JOIN     sys.allocation_units AS a
ON       a.container_id = p.partition_id
GROUP BY i.object_id, i.index_id, i.nameorder 
BY object_name( i.object_id ),
        i.index_id;
