SELECT OBJECT_NAME(s.[object_id]) as [object name]
      , i.[name] as [index name]
      , user_seeks
      , user_scans
      , user_lookups
      , user_updates
FROM sys.dm_db_index_usage_stats as s
      INNER JOIN sys.indexes as i
              ON i.[object_id] = s.[object_id]
             AND i.index_id = s.index_id
WHERE OBJECT_NAME(s.[object_id]) = 'tablename'
