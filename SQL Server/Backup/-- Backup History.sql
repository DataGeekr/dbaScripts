SELECT [DatabaseName] = db.name  
     , [RecoveryModel] = CONVERT(SYSNAME , DATABASEPROPERTYEX ( db.name , 'Recovery' ))  
     , [Full] = COALESCE(( SELECT CONVERT (VARCHAR(10), MAX(backup_finish_date ), 103) + ' ' + CONVERT( CHAR(5), CONVERT (TIME, MAX( backup_finish_date))) 
                           FROM msdb.dbo.backupset 
                           WHERE    database_name = db.name 
                           AND type = 'D' AND is_copy_only = '0' 
                        ), 'No Full' )  
     , [Diff] = COALESCE(( SELECT CONVERT (VARCHAR(10), MAX(backup_finish_date ), 103) + ' ' + CONVERT( CHAR(5), CONVERT (time, MAX( backup_finish_date))) 
                           FROM msdb.dbo.backupset 
                           WHERE database_name = db.name 
                           AND type = 'I' 
                           AND is_copy_only = '0' 
                         ), 'No Diff' )  
      , [LastLog] = COALESCE(( SELECT CONVERT (VARCHAR(10), MAX(backup_finish_date ), 103) + ' ' + CONVERT( CHAR(5), CONVERT (time, MAX( backup_finish_date))) 
                               FROM msdb.dbo.backupset 
                               WHERE database_name = db.name 
                               AND   type = 'L' 
                             ), 'No Log' )  
      , [LastLog2] = COALESCE(( SELECT CONVERT (VARCHAR(10), MAX(backup_finish_date ), 103) + ' ' + CONVERT( CHAR(5), CONVERT (time, MAX( backup_finish_date))) 
                                FROM (  
                                     SELECT ROW_NUMBER () OVER ( ORDER BY backup_finish_date DESC ) AS 'rownum'  
                                          , backup_finish_date 
                                     FROM msdb.dbo.backupset 
                                     WHERE database_name = db.name 
                                     AND type = 'L' 
                                     ) withrownum 
                                WHERE    rownum = 2 
                              ), 'No Log' )   
FROM sys.databases db 
     LEFT OUTER JOIN  
     msdb.dbo.backupset b  
        ON b .database_name = db.name 
WHERE db.name <> 'tempdb' 
AND   db.state_desc = 'online' 
GROUP BY db.Name  
       , db.compatibility_level 
ORDER BY CASE WHEN db.Name IN ( 'master', 'msdb', 'tempdb', 'model') 
              THEN 1 
              ELSE 0 
         END ASC 
       , CONVERT (SYSNAME , DATABASEPROPERTYEX ( db.name , 'Recovery' )) 
       , db.name



       
