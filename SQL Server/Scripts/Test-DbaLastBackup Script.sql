
```
-- Test-DbaLastBackup Script  
SET NOCOUNT ON;  
WITH BackupInfo ( backup_type, database_name, device_type, backup_start_date)  
   AS (  
        SELECT CASE bs.type  
                    WHEN 'D' THEN 'Full backup'  
                    WHEN 'I' THEN 'Differential'  
                    WHEN 'L' THEN 'Transaction Log'  
                    WHEN 'F' THEN 'File/Filegroup'  
                    WHEN 'G' THEN 'Differential file'  
                    WHEN 'P' THEN 'Partial'  
                    WHEN 'Q' THEN 'Differential partial'  
                    WHEN NULL THEN 'No backups'  
                    ELSE 'Unknown (' + bs.[type] + ')'  
               END  
             , bs.database_name  
             , CASE WHEN bmf.device_type IN (2, 102)  
                    THEN 'DISK'  
                    WHEN bmf.device_type IN (5, 105)  
                    THEN 'TAPE'   
                    WHEN bmf.device_type = 9  
                    THEN 'URL'  
               END  
             , bs.backup_start_date  
        FROM msdb..backupset bs  
             LEFT JOIN msdb..backupmediafamily bmf  
                  ON bs.media_set_id = bmf.media_set_id  
      ),  
BackupStorage  
AS (  
     SELECT [Storage] = 'Azure Blob Storage'  
          , [Command] = 'Test-DbaLastBackup -SqlInstance ' + @@SERVERNAME +  ' -SqlCredential rafael.rodrigues -Destination < ** ???? ** > -DestinationCredential rafael.rodrigues - IgnoreLogBackup -DataDirectory Z:\Restore -LogDirectory Z:\Restore -Database ' + STUFF((  
                 SELECT DISTINCT CONCAT(N',', d.name )  
                 FROM Master.sys.databases d  
                      LEFT JOIN (  
                                SELECT database_id = DB_ID(database_name)  
                                      , backup_type  
                                      , backup_start_date = MAX(backup_start_date)  
                                FROM BackupInfo  
                                GROUP BY DB_ID(database_name)  
                                      , backup_type  
                                ) mx  
                           ON d.database_id = mx.database_id  
                      LEFT JOIN BackupInfo bak  
                           ON  mx.database_id = DB_ID(bak.database_name)  
                           AND mx.backup_start_date = bak.backup_start_date  
                 WHERE bak.device_type = 'URL'  
                 AND   bak.backup_type = 'Full Backup'  
                 FOR XML PATH (''), TYPE).value('text()[1]','nvarchar(max)'),1,1,N'') + ' | Export-Csv "Z:\Restore\' + @@SERVERNAME + '.RestorePlan.Cloud.' + CONVERT(CHAR(8), GETDATE(), 112) + '.csv"'  
     UNION   
     SELECT [Storage] = 'Disk'  
          , [Command] = 'Test-DbaLastBackup -SqlInstance ' + @@SERVERNAME + ' -SqlCredential rafael.rodrigues -Destination < ** ???? ** > -DestinationCredential rafael.rodrigues -IgnoreLogBackup -DataDirectory Z:\Restore -LogDirectory Z:\Restore -CopyFile -CopyPath "\\CANIS\Restore" -Database ' + STUFF((  
                 SELECT DISTINCT CONCAT(N',', d.name )  
                 FROM Master.sys.databases d  
                      LEFT JOIN (  
                                SELECT DISTINCT   
                                       database_id = DB_ID(database_name)  
                                     , backup_type  
                                     , backup_start_date = MAX(backup_start_date)  
                                FROM BackupInfo  
                                GROUP BY DB_ID(database_name)  
                                      , backup_type  
                                ) mx  
                           ON d.database_id = mx.database_id  
                      LEFT JOIN BackupInfo bak  
                           ON  mx.database_id = DB_ID(bak.database_name)  
                           AND mx.backup_start_date = bak.backup_start_date  
                 WHERE bak.device_type = 'DISK'  
                 AND   bak.backup_type = 'Full Backup'  
                 AND   d.name NOT IN ('LogArquivo')  
                 FOR XML PATH (''), TYPE).value('text()[1]','nvarchar(max)'),1,1,N'') + ' | Export-Csv "Z:\Restore\' + @@SERVERNAME + '.RestorePlan.Local.' + CONVERT(CHAR(8), GETDATE(), 112) + '.csv"'  
     )  
SELECT * FROM BackupStorage WHERE Command IS NOT NULL
```
