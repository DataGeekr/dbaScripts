CREATE TABLE #backupset (
        backup_set_id INT
        ,database_name NVARCHAR(128 )
        ,backup_finish_date DATETIME
        ,type CHAR(1 )
        ,next_backup_finish_date DATETIME
        );

INSERT INTO #backupset (
        backup_set_id
        ,database_name
        ,backup_finish_date
        ,type
        )
SELECT backup_set_id
        ,database_name
        ,backup_finish_date
        ,type
FROM msdb .dbo. backupset WITH (NOLOCK)
WHERE backup_finish_date >= DATEADD(dd , - 14, GETDATE())
        AND database_name NOT IN (
               'master'
               ,'model'
               ,'msdb'
               );

CREATE CLUSTERED INDEX CL_database_name_backup_finish_date ON #backupset (
        database_name
        ,backup_finish_date
        );

UPDATE #backupset
SET next_backup_finish_date = (
               SELECT TOP 1 backup_finish_date
               FROM #backupset bsNext
               WHERE bs .database_name = bsNext .database_name
                      AND bs .backup_finish_date < bsNext .backup_finish_date
               ORDER BY bsNext. backup_finish_date
               )
FROM #backupset bs;

SELECT bs1 .database_name
        ,MAX( DATEDIFF(mi , bs1 .backup_finish_date, bs1. next_backup_finish_date)) AS max_minutes_of_data_loss
        ,'SELECT bs.database_name, bs.type, bs.backup_start_date, bs.backup_finish_date, DATEDIFF(mi, COALESCE((SELECT TOP 1 bsPrior.backup_finish_date FROM msdb.dbo.backupset bsPrior WHERE bs.database_name = bsPrior.database_name AND bs.backup_finish_date > bsPrior.backup_finish_date ORDER BY bsPrior.backup_finish_date DESC), ''1900/1/1''), bs.backup_finish_date) AS minutes_since_last_backup, DATEDIFF(mi, bs.backup_start_date, bs.backup_finish_date) AS backup_duration_minutes, CASE DATEDIFF(ss, bs.backup_start_date, bs.backup_finish_date) WHEN 0 THEN 0 ELSE CAST(( bs.backup_size / ( DATEDIFF(ss, bs.backup_start_date, bs.backup_finish_date) ) / 1048576 ) AS INT) END AS throughput_mb_sec FROM msdb.dbo.backupset bs WHERE database_name = ''' + database_name + ''' AND bs.backup_start_date > DATEADD(dd, -14, GETDATE()) ORDER BY bs.backup_start_date' AS more_info_query
FROM #backupset bs1
GROUP BY bs1. database_name
ORDER BY bs1. database_name

DROP TABLE #backupset;
GO

  