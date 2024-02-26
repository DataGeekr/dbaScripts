SET NOCOUNT ON;  
DECLARE @RunDate DATETIME;  
SET @RunDate = GETDATE();  
WITH BackupInfo ( backup_start_date  
                , backup_finish_date  
                , backup_type  
                , backup_size  
                , database_name  
                , has_backup_checksums  
                , is_damaged  
                , compressed_backup_size  
                , logical_device_name  
                , physical_device_name  
                , device_type  
                , is_copy_only  
                , key_algorithm  
                , encryptor_type  
                )  
   AS (  
        SELECT bs.backup_start_date  
             , bs.backup_finish_date  
             , CASE bs.type  
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
             , bs.backup_size  
             , bs.database_name  
             , bs.has_backup_checksums  
             , bs.is_damaged  
             , bs.compressed_backup_size  
             , bmf.logical_device_name  
             , bmf.physical_device_name  
             , CASE WHEN bmf.device_type IN (2, 102)  
                    THEN 'DISK'  
                    WHEN bmf.device_type IN (5, 105)  
                    THEN 'TAPE'   
                    WHEN bmf.device_type = 9  
                    THEN 'URL'  
               END  
             , is_copy_only  
             , key_algorithm  
             , encryptor_type  
        FROM msdb..backupset bs   
             LEFT JOIN msdb..backupmediafamily bmf  
                  ON bs.media_set_id = bmf.media_set_id  
      )  
SELECT [DatabaseId]    = d.database_id  
     , [DatabaseName]  = d.name  
     , [BackupFileNo]  = ROW_NUMBER() OVER (PARTITION BY d.database_id, bak.backup_type ORDER BY mx.backup_start_date) 
     , [MostRecentBackup] = bak.backup_start_date  
     , [MostRecentType] = bak.backup_type  
     , [SQLVersion]    = CASE d.[compatibility_level]  
                              WHEN 70  
                              THEN '7'  
                              WHEN 80  
                              THEN '2000'  
                              WHEN 90  
                              THEN '2005'  
                              WHEN 100  
                              THEN '2008'  
                              WHEN NULL  
                              THEN 'OFFLINE'  
                         END  
     , [RecoveryModel] = d.recovery_model_desc  
     , [DatabaseState] = d.state_desc  
     , [RecoveryState] = CASE d.state  
                              WHEN 0 THEN 'N/A'  
                              ELSE CASE d.is_cleanly_shutdown  
                                        WHEN 1  
                                        THEN 'NO RECOVERY'  
                                        WHEN 0  
                                        THEN 'RECOVERY'  
                                   END  
                         END  
     , [CopyOnly] = bak.is_copy_only  
     , [Encrypted] = IIF(key_algorithm IS NULL, 'No', CONCAT(UPPER(bak.key_algorithm), ' by ', bak.encryptor_type))  
     , [BackupsLast30Days] = mx.backup_last_30  
     , [MostRecentSize_MB] = CONVERT(INT, bak.compressed_backup_size / 1024 /*KB*/ / 1024 /*MB*/)  
     , [CompressionRatio] = CONVERT(NUMERIC(4,1), (1 - (bak.compressed_backup_size * 1.0 / NULLIF(bak.backup_size, 0))) * 100)  
     , [Last30AvgSize_MB] = CONVERT(INT, mx.backup_avg_size / 1024 /*KB*/ / 1024 /*MB*/)  
     , [MostRecentDuration_sec] = DATEDIFF(SS, bak.backup_start_date, bak.backup_finish_date)  
     , [Last30AvgDuration_sec] = mx.backup_avg_duration  
     , [MostRecentLogicalDevice] = bak.logical_device_name  
     , [MostRecentPhysicalDevice] = bak.physical_device_name  
     , [MostRecentDeviceType] = bak.device_type  
     , [UsedCHECKSUM] = bak.has_backup_checksums  
     , [BackupDamaged] = bak.is_damaged  
     , [LogBackupCheck] = CASE WHEN d.recovery_model = 3 /*SIMPLE*/  
                               THEN 0  
                               ELSE 1  
                          END  
FROM master.sys.databases d  
     LEFT JOIN (  
                  SELECT database_id = DB_ID(database_name)  
                        , backup_type  
                        , backup_start_date = MAX(backup_start_date)  
                        , backup_last_30 = SUM( CASE WHEN backup_start_date BETWEEN DATEADD(DD, -30, @RunDate)  
                                                      AND @RunDate  
                                                     THEN 1  
                                                     ELSE 0  
                                                END )  
                        , backup_avg_duration = AVG(DATEDIFF(SS, backup_start_date, backup_finish_date))  
                        , backup_avg_size = AVG(compressed_backup_size)  
                  FROM BackupInfo  
                  GROUP BY DB_ID(database_name)  
                        , backup_type  
                     ) mx  
          ON d.database_id = mx.database_id  
     LEFT JOIN  
     BackupInfo bak  
          ON  mx.database_id = DB_ID(bak.database_name)  
          AND mx.backup_start_date = bak.backup_start_date  
ORDER BY MostRecentBackup 
       , d.name  
       , BackupFileNo 
