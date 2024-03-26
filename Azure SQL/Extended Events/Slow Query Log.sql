-- Create credential
CREATE DATABASE SCOPED CREDENTIAL [https://...]
WITH IDENTITY='SHARED ACCESS SIGNATURE'
   , SECRET = 'sv=...'
GO

-- Drop session
DROP EVENT SESSION [QueryExecutionDetails] ON DATABASE 
GO

-- Create session
CREATE EVENT SESSION [QueryExecutionDetails] ON DATABASE 
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.session_id,sqlserver.sql_text)
    WHERE ([sqlserver].[database_id]=(5) AND [duration]>(15000000))),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.session_id,sqlserver.sql_text)
    WHERE ([sqlserver].[database_id]=(5) AND [duration]>(15000000)))
ADD TARGET package0.event_file(SET filename=N'https://stggclaimssqlaudit.blob.core.windows.net/trace/SmartInsure-Producao_QueryExecutionDetails.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

-- Start session  
ALTER EVENT SESSION [QueryExecutionDetails] ON DATABASE  
STATE = START;  
GO  

-- Information Analysis
SELECT 
    EventDataXML.value('(event/@name)[1]', 'nvarchar(100)') AS EventName,
    EventDataXML.value('(event/@package)[1]', 'nvarchar(100)') AS EventPackage,
    EventDataXML.value('(event/@timestamp)[1]', 'datetime') AS EventTimestamp,
    EventDataXML.value('(event/data[@name="source_database_id"]/value)[1]', 'int') AS SourceDatabaseID,
    EventDataXML.value('(event/data[@name="object_id"]/value)[1]', 'bigint') AS ObjectID,
    EventDataXML.value('(event/data[@name="object_type"]/value)[1]', 'int') AS ObjectType,
    EventDataXML.value('(event/data[@name="duration"]/value)[1]', 'bigint') AS Duration,
    EventDataXML.value('(event/data[@name="cpu_time"]/value)[1]', 'bigint') AS CPUTime,
    EventDataXML.value('(event/data[@name="page_server_reads"]/value)[1]', 'bigint') AS PageServerReads,
    EventDataXML.value('(event/data[@name="physical_reads"]/value)[1]', 'bigint') AS PhysicalReads,
    EventDataXML.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint') AS LogicalReads,
    EventDataXML.value('(event/data[@name="writes"]/value)[1]', 'bigint') AS Writes,
    EventDataXML.value('(event/data[@name="spills"]/value)[1]', 'bigint') AS Spills,
    EventDataXML.value('(event/data[@name="row_count"]/value)[1]', 'bigint') AS [RowCount],
    EventDataXML.value('(event/data[@name="last_row_count"]/value)[1]', 'bigint') AS LastRowCount,
    EventDataXML.value('(event/data[@name="nest_level"]/value)[1]', 'int') AS NestLevel,
    EventDataXML.value('(event/data[@name="line_number"]/value)[1]', 'int') AS LineNumber,
    EventDataXML.value('(event/data[@name="offset"]/value)[1]', 'int') AS Offset,
    EventDataXML.value('(event/data[@name="offset_end"]/value)[1]', 'int') AS OffsetEnd,
    EventDataXML.value('(event/data[@name="object_name"]/value)[1]', 'nvarchar(100)') AS ObjectName,
    EventDataXML.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(max)') AS Statement,
    EventDataXML.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS SQLText,
    EventDataXML.value('(event/action[@name="session_id"]/value)[1]', 'int') AS SessionID,
    EventDataXML.value('(event/action[@name="client_hostname"]/value)[1]', 'nvarchar(100)') AS ClientHostname,
    EventDataXML.value('(event/action[@name="client_app_name"]/value)[1]', 'nvarchar(100)') AS ClientAppName
FROM (
    SELECT CAST(event_data AS XML) AS EventDataXML 
    FROM sys.fn_xe_file_target_read_file(N'https://stggclaimssqlaudit.blob.core.windows.net/trace/SmartInsure-Producao_QueryExecutionDetails_0_133559526562700000.xel', NULL, NULL, NULL)
) AS EventData
