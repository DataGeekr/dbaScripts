
```
SELECT b.database_name 
     , key_algorithm 
     , encryptor_thumbprint 
     , encryptor_type 
     , b.media_set_id 
     , is_encrypted 
     , type 
     , is_compressed 
     , bf.physical_device_name 
FROM msdb.dbo.backupset        b 
    INNER JOIN 
    msdb.dbo.backupmediaset    m 
        ON b.media_set_id = m.media_set_id 
    INNER JOIN 
    msdb.dbo.backupmediafamily bf 
        ON bf.media_set_id = b.media_set_id 
WHERE database_name = 'Geral' 
ORDER BY b.backup_start_date DESC;
```
