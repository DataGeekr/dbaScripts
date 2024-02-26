
---
CREATE EVENT SESSION [ErrorsReported] ON DATABASE  
ADD EVENT sqlserver.error_reported 
( 
    ACTION 
    ( 
          sqlserver.client_app_name         
        , sqlserver.client_hostname         
        , sqlserver.sql_text                
        , sqlserver.tsql_stack              
    ) 
    WHERE 
    ( 
        severity > 10 
        AND     ([sqlserver].[database_id]=(5)) 
    ) 
) 
ADD TARGET package0.event_file(SET filename=N'https://stggclaimssecurity.blob.core.windows.net/sqltrace/GClaimsWIZ_ErrorsReported.xel') 
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
---
