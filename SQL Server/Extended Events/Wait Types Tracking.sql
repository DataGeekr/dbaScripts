
---
CREATE EVENT SESSION WaitTypeTracking ON DATABASE  
ADD EVENT sqlos.wait_completed( 
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.sql_text) 
    WHERE ([sqlserver].[database_id]=(5))), 
ADD EVENT sqlos.wait_info_external( 
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.sql_text) 
    WHERE ([sqlserver].[database_id]=(5))), 
ADD EVENT sqlserver.rpc_completed( 
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.sql_text) 
    WHERE ([sqlserver].[database_id]=(5))), 
ADD EVENT sqlserver.sql_batch_completed( 
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.sql_text) 
    WHERE ([sqlserver].[database_id]=(5))) 
ADD TARGET package0.event_file(SET FILENAME=N'https://stggclaimssecurity.blob.core.windows.net/sqltrace/dbOnPointPRD_WaitTypeTracking.xel') 
WITH 
( 
    TRACK_CAUSALITY = ON 
); 
GO

ALTER EVENT SESSION WaitTypeTracking ON DATABASE   
STATE = start;   
GO  

/* 
CREATE MASTER KEY;  
OPEN MASTER KEY DECRYPTION BY PASSWORD = '@#g3n3R4LC74iMs&$'   	 
     -- SELECT * FROM sys.symmetric_keys  
CREATE DATABASE SCOPED CREDENTIAL [https://stggclaimssecurity.blob.core.windows.net/sqltrace]  
WITH IDENTITY = 'SHARED ACCESS SIGNATURE'   
   , SECRET = 'sp=racwdli&st=2022-09-28T14:59:00Z&se=2024-12-31T22:59:00Z&spr=https&sv=2021-06-08&sr=c&sig=ggSaLJgscx3Y9rwJbwJSBhK76qdB6%2FxWIxFBX%2F2mcpU%3D' 
               
*/
---
