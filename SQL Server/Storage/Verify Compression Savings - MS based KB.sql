
--Collect all index stats
IF OBJECT_ID('index_estimates') IS NOT NULL
    DROP TABLE index_estimates;
GO
CREATE TABLE index_estimates
(
    database_name sysname NOT NULL,
    [schema_name] sysname NOT NULL,
    table_name sysname NOT NULL,
    index_id INT NOT NULL,
    update_pct DECIMAL(5, 2) NOT NULL,
    select_pct DECIMAL(5, 2) NOT NULL,
    CONSTRAINT pk_index_estimates
        PRIMARY KEY (
                        database_name,
                        [schema_name],
                        table_name,
                        index_id
                    )
);
GO
INSERT INTO index_estimates
SELECT DB_NAME() AS database_name,
       SCHEMA_NAME(t.schema_id) AS [schema_name],
       t.name,
       i.index_id,
       i.leaf_update_count * 100.0
       / (i.leaf_delete_count + i.leaf_insert_count + i.leaf_update_count + i.range_scan_count
          + i.singleton_lookup_count + i.leaf_page_merge_count
         ) AS UpdatePct,
       i.range_scan_count * 100.0
       / (i.leaf_delete_count + i.leaf_insert_count + i.leaf_update_count + i.range_scan_count
          + i.singleton_lookup_count + i.leaf_page_merge_count
         ) AS SelectPct
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) i
    INNER JOIN sys.tables t
        ON i.object_id = t.object_id
    INNER JOIN sys.dm_db_partition_stats p
        ON t.object_id = p.object_id
WHERE i.leaf_delete_count + i.leaf_insert_count + i.leaf_update_count + i.range_scan_count + i.singleton_lookup_count
      + i.leaf_page_merge_count > 0
      AND p.used_page_count >= 100 -- only consider tables contain more than 100 pages
      AND p.index_id < 2
      AND i.range_scan_count
          / (i.leaf_delete_count + i.leaf_insert_count + i.leaf_update_count + i.range_scan_count
             + i.singleton_lookup_count + i.leaf_page_merge_count
            ) > .75 -- only consider tables with 75% or greater select percentage
ORDER BY t.name,
         i.index_id;
GO
--show data compression candidates
SELECT *
FROM index_estimates;

--Prepare 2 intermediate tables for row compression and page compression estimates
IF OBJECT_ID('page_compression_estimates') IS NOT NULL
    DROP TABLE page_compression_estimates;
GO
CREATE TABLE page_compression_estimates
(
    [object_name] sysname NOT NULL,
    [schema_name] sysname NOT NULL,
    index_id INT NOT NULL,
    partition_number INT NOT NULL,
    [size_with_current_compression_setting(KB)] BIGINT NOT NULL,
    [size_with_requested_compression_setting(KB)] BIGINT NOT NULL,
    [sample_size_with_current_compression_setting(KB)] BIGINT NOT NULL,
    [sample_size_with_requested_compression_setting(KB)] BIGINT NOT NULL,
    CONSTRAINT pk_page_compression_estimates
        PRIMARY KEY (
                        [object_name],
                        [schema_name],
                        index_id
                    )
);
GO
IF OBJECT_ID('row_compression_estimates') IS NOT NULL
    DROP TABLE row_compression_estimates;
GO
CREATE TABLE row_compression_estimates
(
    [object_name] sysname NOT NULL,
    [schema_name] sysname NOT NULL,
    index_id INT NOT NULL,
    partition_number INT NOT NULL,
    [size_with_current_compression_setting(KB)] BIGINT NOT NULL,
    [size_with_requested_compression_setting(KB)] BIGINT NOT NULL,
    [sample_size_with_current_compression_setting(KB)] BIGINT NOT NULL,
    [sample_size_with_requested_compression_setting(KB)] BIGINT NOT NULL,
    CONSTRAINT pk_row_compression_estimates
        PRIMARY KEY (
                        [object_name],
                        [schema_name],
                        index_id
                    )
);
GO


--Use cursor and dynamic sql to get estimates 9:18 on my laptop
DECLARE @script_template NVARCHAR(MAX)
    = N'insert ##compression_mode##_compression_estimates exec sp_estimate_data_compression_savings ''##schema_name##'',''##table_name##'',NULL,NULL,''##compression_mode##''';
DECLARE @executable_script NVARCHAR(MAX);
DECLARE @schema sysname,
        @table sysname,
        @compression_mode NVARCHAR(20);
DECLARE cur CURSOR FAST_FORWARD FOR
SELECT i.[schema_name],
       i.[table_name],
       em.estimate_mode
FROM index_estimates i
    CROSS JOIN
    (
        VALUES
            ('row'),
            ('page')
    ) AS em (estimate_mode)
GROUP BY i.[schema_name],
         i.[table_name],
         em.estimate_mode;

OPEN cur;
FETCH NEXT FROM cur
INTO @schema,
     @table,
     @compression_mode;
WHILE (@@FETCH_STATUS = 0)
BEGIN
    SET @executable_script
        = REPLACE(
                     REPLACE(REPLACE(@script_template, '##schema_name##', @schema), '##table_name##', @table),
                     '##compression_mode##',
                     @compression_mode
                 );
    PRINT @executable_script;
    EXEC (@executable_script);
    FETCH NEXT FROM cur
    INTO @schema,
         @table,
         @compression_mode;

END;

CLOSE cur;
DEALLOCATE cur;

--Show estimates and proposed data compression
WITH all_estimates
AS (SELECT '[' + i.schema_name + '].[' + i.table_name + ']' AS table_name,
           CASE
               WHEN i.index_id > 0 THEN
                   '[' + idx.name + ']'
               ELSE
                   NULL
           END AS index_name,
           i.select_pct,
           i.update_pct,
           CASE
               WHEN r.[sample_size_with_current_compression_setting(KB)] > 0 THEN
                   100 - r.[sample_size_with_requested_compression_setting(KB)] * 100.0
                   / r.[sample_size_with_current_compression_setting(KB)]
               ELSE
                   0.0
           END AS row_compression_saving_pct,
           CASE
               WHEN p.[sample_size_with_current_compression_setting(KB)] > 0 THEN
                   100 - p.[sample_size_with_requested_compression_setting(KB)] * 100.0
                   / p.[sample_size_with_current_compression_setting(KB)]
               ELSE
                   0.0
           END AS page_compression_saving_pct
    FROM index_estimates i
        INNER JOIN row_compression_estimates r
            ON i.schema_name = r.schema_name
               AND i.table_name = r.object_name
               AND i.index_id = r.index_id
        INNER JOIN page_compression_estimates p
            ON i.schema_name = p.schema_name
               AND i.table_name = p.object_name
               AND i.index_id = p.index_id
        INNER JOIN sys.indexes idx
            ON i.index_id = idx.index_id
               AND OBJECT_NAME(idx.object_id) = i.table_name),
     recommend_compression
AS (SELECT table_name,
           index_name,
           select_pct,
           update_pct,
           row_compression_saving_pct,
           page_compression_saving_pct,
           CASE
               WHEN update_pct = 0 THEN
                   'Page'
               WHEN update_pct >= 20 THEN
                   'Row'
               WHEN update_pct > 0
                    AND update_pct < 20
                    AND page_compression_saving_pct - row_compression_saving_pct < 10 THEN
                   'Row'
               ELSE
                   'Page'
           END AS recommended_data_compression
    FROM all_estimates
    WHERE row_compression_saving_pct > 0
          AND page_compression_saving_pct > 0)
SELECT table_name,
       index_name,
       select_pct,
       update_pct,
       row_compression_saving_pct,
       page_compression_saving_pct,
       recommended_data_compression,
       CASE
           WHEN index_name IS NULL THEN
               'alter table ' + table_name + ' rebuild with ( data_compression = ' + recommended_data_compression + ')'
           ELSE
               'alter index ' + index_name + ' on ' + table_name + ' rebuild with ( data_compression = '
               + recommended_data_compression + ')'
       END AS [statement]
FROM recommend_compression
ORDER BY table_name;

--Clean up
DROP TABLE index_estimates;