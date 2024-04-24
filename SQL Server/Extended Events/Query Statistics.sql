USE [master];
GO

/*
Create a master key to protect the secret of the credential
IF NOT EXISTS (
              SELECT 1
              FROM sys.symmetric_keys
              WHERE name = '##MS_DatabaseMasterKey##'
              )
CREATE MASTER KEY;
*/
    
/*
(Re-)create a database scoped credential.
The name of the credential must match the URL of the blob container.
*/
IF EXISTS (
          SELECT 1
          FROM sys.database_credentials
          WHERE name = 'https://exampleaccount4xe.blob.core.windows.net/xe-example-container'
          )
    DROP DATABASE SCOPED CREDENTIAL [https://exampleaccount4xe.blob.core.windows.net/xe-example-container];

/*
The secret is the SAS token for the container. The Read, Write, and List permissions are set.
*/
CREATE DATABASE SCOPED CREDENTIAL [https://exampleaccount4xe.blob.core.windows.net/xe-example-container]
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
     SECRET = 'sp=rwl&st=2023-10-17T23:28:32Z&se=2023-10-18T07:28:32Z&spr=https&sv=2022-11-02&sr=c&sig=REDACTED';    
    

/* Exclusão da sessão caso exista */
IF (SELECT COUNT(*)
    FROM [sys].[dm_xe_sessions] AS [xes]
    WHERE [xes].[name] = N'QueryBaseline') = 1
BEGIN
    ALTER EVENT SESSION [QueryBaseline]
        ON SERVER
        STATE = STOP;

    DROP EVENT SESSION [QueryBaseline]
    ON SERVER;
END;
GO

/* Criação da sessão */
CREATE EVENT SESSION [QueryBaseline] ON SERVER
ADD EVENT sqlserver.error_reported (
    ACTION ( sqlserver.client_app_name , sqlserver. database_id,
    sqlserver.query_hash, sqlserver.session_id , sqlserver. sql_text )
    WHERE ( [package0].[greater_than_uint64] ([sqlserver]. [database_id], ( 4 ))
            AND [package0]. [equal_boolean]([sqlserver].[is_system], ( 0 ))
            AND [package0]. [equal_uint64]([sqlserver].[database_id], ( 5 ))
            AND [package0]. [not_equal_uint64]([sqlserver].[query_hash], ( 0 ))
            AND [package0]. [not_equal_boolean]([sqlserver].[is_system], ( 1 ))
          ) ),
ADD EVENT sqlserver.module_end ( SET collect_statement = ( 1 )
    ACTION ( sqlserver.client_app_name , sqlserver. database_id,
    sqlserver.query_hash, sqlserver.session_id , sqlserver. sql_text )
    WHERE ( [package0].[greater_than_uint64] ([sqlserver]. [database_id], ( 4 ))
            AND [package0]. [equal_boolean]([sqlserver].[is_system], ( 0 ))
            AND [package0]. [equal_uint64]([sqlserver].[database_id], ( 5 ))
            AND [package0]. [not_equal_uint64]([sqlserver].[query_hash], ( 0 ))
            AND [package0]. [not_equal_boolean]([sqlserver].[is_system], ( 1 ))
          ) ),
ADD EVENT sqlserver.rpc_completed (
    ACTION ( sqlserver.client_app_name , sqlserver. database_id,
    sqlserver.query_hash, sqlserver.session_id , sqlserver. sql_text )
    WHERE ( [package0].[greater_than_uint64] ([sqlserver]. [database_id], ( 4 ))
            AND [package0]. [equal_boolean]([sqlserver].[is_system], ( 0 ))
            AND [package0]. [equal_uint64]([sqlserver].[database_id], ( 5 ))
            AND [package0]. [not_equal_uint64]([sqlserver].[query_hash], ( 0 ))
            AND [package0]. [not_equal_boolean]([sqlserver].[is_system], ( 1 ))
          ) ),
ADD EVENT sqlserver.sp_statement_completed ( SET collect_object_name = ( 1 )
    ACTION ( sqlserver.client_app_name , sqlserver. database_id,
    sqlserver.query_hash, sqlserver.query_plan_hash , sqlserver. session_id,
    sqlserver.sql_text )
    WHERE ( [package0].[greater_than_uint64] ([sqlserver]. [database_id], ( 4 ))
            AND [package0]. [equal_boolean]([sqlserver].[is_system], ( 0 ))
            AND [package0]. [equal_uint64]([sqlserver].[database_id], ( 5 ))
            AND [package0]. [not_equal_uint64]([sqlserver].[query_hash], ( 0 ))
            AND [package0]. [not_equal_boolean]([sqlserver].[is_system], ( 1 ))
          ) ),
ADD EVENT sqlserver.sql_batch_completed (
    ACTION ( sqlserver.client_app_name , sqlserver. database_id,
    sqlserver.query_hash, sqlserver.session_id , sqlserver. sql_text )
    WHERE ( [package0].[greater_than_uint64] ([sqlserver]. [database_id], ( 4 ))
            AND [package0]. [equal_boolean]([sqlserver].[is_system], ( 0 ))
            AND [package0]. [equal_uint64]([sqlserver].[database_id], ( 5 ))
            AND [package0]. [not_equal_uint64]([sqlserver].[query_hash], ( 0 ))
            AND [package0]. [not_equal_boolean]([sqlserver].[is_system], ( 1 ))
          ) ),
ADD EVENT sqlserver.sql_statement_completed (
    ACTION ( sqlserver.client_app_name , sqlserver. database_id,
    sqlserver.query_hash, sqlserver.query_plan_hash , sqlserver. session_id,
    sqlserver.sql_text )
    WHERE ( [package0].[greater_than_uint64] ([sqlserver]. [database_id], ( 4 ))
            AND [package0]. [equal_boolean]([sqlserver].[is_system], ( 0 ))
            AND [package0]. [equal_uint64]([sqlserver].[database_id], ( 5 ))
            AND [package0]. [not_equal_uint64]([sqlserver].[query_hash], ( 0 ))
            AND [package0]. [not_equal_boolean]([sqlserver].[is_system], ( 1 ))
          ) )
ADD TARGET package0.ring_buffer
WITH ( MAX_MEMORY = 4096 KB ,
        EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS ,
        MAX_DISPATCH_LATENCY = 30 SECONDS ,
        MAX_EVENT_SIZE = 0 KB ,
        MEMORY_PARTITION_MODE = NONE ,
        TRACK_CAUSALITY = ON ,
        STARTUP_STATE = OFF )
/*
ADD TARGET package0.event_file(SET filename=N'D:\rdsdbdata\Log\QueryBaseline.xel',max_file_size=(100),max_rollover_files=(5))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO
*/
GO

/* Inicialização / paralização da sessão */

ALTER EVENT SESSION [QueryBaseline]
ON SERVER
STATE = START;




/* Pesquisa de eventos */
SET NOCOUNT ON;
SELECT [EventName] = event.value('(event/@name)[1]' , 'VARCHAR(50)' )
     , [object_name] = event.value('(/event/data[@name = "object_name"]/value)[1]', 'NVARCHAR(256)')
     , [EventTime] = DATEADD(hh, DATEDIFF(hh , GETUTCDATE (), CURRENT_TIMESTAMP ), event.value ('(event/@timestamp)[1]' , 'DATETIME2' ))
     , [sql_text] = event.value('(event/action[@name = "sql_text"]/value)[1]' , 'NVARCHAR(MAX)')
     , [statetment] = event.value('(event/data[@name = "statement"]/value)[1]' , 'NVARCHAR(MAX)')
     , [duration] = event.value('(/event/data[@name = "duration"]/value)[1]' , 'INT') / 1000.0
     , [cpu_time] = event.value('(/event/data[@name = "cpu_time"]/value)[1]' , 'INT')
     , [logical_reads] = event.value('(/event/data[@name = "logical_reads"]/value)[1]', 'INT')
     , [physical_reads] = event.value('(/event/data[@name = "physical_reads"]/value)[1]', 'INT')
     , [writes] = event.value('(/event/data[@name = "writes"]/value)[1]' , 'INT' )
     , [row_count] = event.value('(/event/data[@name = "row_count"]/value)[1]' , 'INT')
     , [database_id] = event.value('(/event/action[@name = "database_id"]/value)[1]', 'INT')
     , [query_hash] = event.value('(/event/action[@name = "query_hash"]/value)[1]', 'VARCHAR(25)')
     , [query_hash_dmv] = CASE WHEN event .value( '(/event/action[@name = "query_hash"]/value)[1]', 'VARCHAR(25)') < CONVERT(DECIMAL (20, 0), CONVERT(BIGINT , 0x8000000000000000))*- 1
                               THEN CONVERT (BINARY(8),CONVERT (BIGINT, event.value ('(/event/action[@name = "query_hash"]/value)[1]', 'VARCHAR(25)')))
                            ELSE CONVERT(BINARY (8), CONVERT(BIGINT ,event.value('(/event/action[@name = "query_hash"]/value)[1]', 'VARCHAR(25)') - CONVERT(DECIMAL (20, 0), CONVERT(BIGINT , 0x8000000000000000))*- 1) | CONVERT (BIGINT, 0x8000000000000000 ))
                            END
     , [query_plan_hash] = event.value('(/event/action[@name = "query_plan_hash"]/value)[1]', 'VARCHAR(25)')
     , [client_app_name] = event.value('(/event/action[@name = "client_app_name"]/value)[1]', 'NVARCHAR(MAX)')
     , [offset] = event.value('(/event/data[@name = "offset"]/value)[1]' , 'INT' )
     , [offset_end] = event.value('(/event/data[@name = "offset_end"]/value)[1]' , 'INT')
     , [session_id] = event.value('(/event/action[@name = "session_id"]/value)[1]', 'INT')
FROM (
     SELECT [n]. [query]('.' ) AS [event]
     FROM (
          SELECT CAST ([target_data] AS XML ) AS [target_data]
          FROM [sys]. [dm_xe_sessions] AS [xeSession]
               INNER JOIN
               [sys] .[dm_xe_session_targets] AS [xeTarget]
                         ON [xeSession].[address] = [xeTarget].[event_session_address]
               WHERE [xeSession].[name] = N'QueryBaseline'
               AND   [xeTarget].[target_name] = N'ring_buffer'
          ) AS [sub]
          CROSS APPLY [target_data].[nodes] ('RingBufferTarget/event' ) AS [q] ( [n] )
     ) AS [tab]
WHERE event .value( '(/event/data[@name = "duration"]/value)[1]' , 'INT' ) / 1000.0 > 10
GO
    
  

/* Finalização da sessão */
IF (SELECT COUNT(*)
    FROM [sys].[dm_xe_sessions] AS [xes]
    WHERE [xes].[name] = N'QueryBaseline') = 1

BEGIN
    ALTER EVENT SESSION [QueryBaseline]
        ON SERVER
        STATE = STOP;

    DROP EVENT SESSION [QueryBaseline]
    ON SERVER;
END;
GO

/*
– Turn off most significant bit by  AND’ing with 0x7fffffffffffffff
– 0x7fffffffffffffff represents the MSB turned off in max value for UNIT 64
declare @xeHash decimal(20,0)
– Replace the value with the value of the XE query_plan_hash
set @xehash = cast(16026647133934493185 as decimal(20,0))
declare @a as bigint
declare @NoMSBBitset varbinary
select @a = 0x7fffffffffffffff
select @NoMSBBitset= cast((0xF21482B006395C19 & @a) as bigint)
– Compare hash after turning off MSB on both places
– The line 9223372036854775808 = 0x80000000`00000000 which subtracts MSB.
select b.text,c.query_plan,a.* from sys.dm_exec_query_stats a
cross apply sys.dm_exec_sql_text(a.sql_handle) b
cross apply sys.dm_exec_query_plan(a.plan_handle) c
where cast((cast(cast(query_plan_hash as varbinary) as bigint) & @a) as bigint) = cast( (@xeHash -cast(9223372036854775808 as decimal(20,0))) as decimal(20,0))
*/

  
