SELECT DB_NAME() AS DatabaseName,
       OBJECT_NAME(s.object_id) AS table_name,
       SCHEMA_NAME(obj.schema_id) AS schema_name,
       ISNULL(i.name, 'System Or User Statistic') AS index_name,
       c.name AS column_name,
       s.name AS statistics_name,
       CONVERT(DATETIME, STATS_DATE(s.object_id, s.stats_id)) AS last_statistics_update,
       DATEDIFF(DAY, STATS_DATE(s.object_id, s.stats_id), SYSDATETIME()) AS days_since_last_stats_update,
       si.rowcnt,
       si.rowmodctr,
       CASE
           WHEN si.rowmodctr > 0 THEN
               CAST(si.rowmodctr / (1. * NULLIF(si.rowcnt, 0)) * 100 AS DECIMAL(18, 1))
           ELSE
               si.rowmodctr
       END AS percent_modifications,
       CASE
           WHEN si.rowcnt < 500 THEN
               500
           ELSE
               CAST((si.rowcnt * .20) + 500 AS INT)
       END AS modifications_before_auto_update,
       ISNULL(i.type_desc, 'System Or User Statistic - N/A') AS index_type_desc,
       CONVERT(DATE, obj.create_date) AS table_create_date,
       CONVERT(DATE, obj.modify_date) AS table_modify_date,
       s.no_recompute,
       s.has_filter,
       s.filter_definition
FROM sys.stats AS s
    LEFT JOIN sys.stats_columns sc
        ON sc.object_id = s.object_id
           AND sc.stats_id = s.stats_id
    LEFT JOIN sys.columns c
        ON c.object_id = sc.object_id
           AND c.column_id = sc.column_id
    LEFT JOIN sys.objects obj
        ON s.object_id = obj.object_id
    LEFT JOIN sys.indexes AS i
        ON i.object_id = s.object_id
           AND i.index_id = s.stats_id
    JOIN sys.sysindexes AS si
        ON si.name = s.name
WHERE obj.is_ms_shipped = 0;