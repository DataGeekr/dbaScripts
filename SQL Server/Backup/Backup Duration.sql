
DECLARE @dbname sysname; 
SET @dbname = NULL; --set this to be whatever dbname you want 
SELECT bup.user_name                                                                                                  AS [User] 
     , bup.database_name                                                                                              AS [Database] 
     , type 
     , bup.server_name                                                                                                AS [Server] 
     , bup.backup_start_date                                                                                          AS [Backup Started] 
     , bup.backup_finish_date                                                                                         AS [Backup Finished] 
     , DATEDIFF(s, bup.backup_start_date, bup.backup_finish_date)
     --, CAST((CAST(DATEDIFF(s, bup.backup_start_date, bup.backup_finish_date) AS INT)) / 3600 AS VARCHAR) + ' hours, ' 
     --  + CAST((CAST(DATEDIFF(s, bup.backup_start_date, bup.backup_finish_date) AS INT)) / 60 AS VARCHAR) + ' minutes, ' 
     --  + CAST((CAST(DATEDIFF(s, bup.backup_start_date, bup.backup_finish_date) AS INT)) % 60 AS VARCHAR) + ' seconds' AS [Total Time] 
FROM msdb.dbo.backupset bup 
WHERE  bup.database_name IN 
        ( 
            SELECT name FROM master.dbo.sysdatabases 
        ) 
AND Type = 'I'
ORDER BY bup.database_name, 7 DESC ;


SELECT bup.database_name AS [Database] 
     , CASE type WHEN 'D' THEN 'Full'  
                 WHEN 'I' THEN 'Differential'
                 WHEN 'L' THEN 'Transacion Log'
       END AS Type
     , CAST(AVG(DATEDIFF(SECOND, bup.backup_start_date, bup.backup_finish_date)) / 3600 AS VARCHAR) + ' hs ' 
     + CAST(AVG(DATEDIFF(SECOND, bup.backup_start_date, bup.backup_finish_date)) / 60 AS VARCHAR) + ' mins ' 
     + CAST(AVG(DATEDIFF(SECOND, bup.backup_start_date, bup.backup_finish_date)) % 60 AS VARCHAR) + ' secs' AS [Avg Elapsed Time] 
     , CAST(MAX(DATEDIFF(SECOND, bup.backup_start_date, bup.backup_finish_date)) / 3600 AS VARCHAR) + ' hs ' 
     + CAST(MAX(DATEDIFF(SECOND, bup.backup_start_date, bup.backup_finish_date)) / 60 AS VARCHAR) + ' mins ' 
     + CAST(MAX(DATEDIFF(SECOND, bup.backup_start_date, bup.backup_finish_date)) % 60 AS VARCHAR) + ' secs' AS [Max Elapsed Time] 
FROM msdb.dbo.backupset bup 
WHERE bup.backup_start_date >= DATEADD(MONTH, -1, SYSDATETIME())
AND   bup.database_name IN 
        ( 
            SELECT name FROM master.dbo.sysdatabases 
        ) 
GROUP BY bup.database_name
       , bup.type
ORDER BY bup.database_name
       , CASE type WHEN 'D' THEN 0
                   WHEN 'I' THEN 1
                   WHEN 'L' THEN 2
         END ASC;

