USE [master];
GO

/* Exclusão da sessão caso exista */
IF (SELECT COUNT(*)
    FROM [sys] .[dm_xe_sessions] AS [xes]
    WHERE [xes] .[name] = N'XE_Recompiles') = 1
BEGIN
    ALTER EVENT SESSION [XE_Recompiles]
        ON SERVER
        STATE = STOP;

    DROP EVENT SESSION [XE_Recompiles]
    ON SERVER;
END;
GO

/* Criação da nova sessão */
DECLARE @ExecString nvarchar(4000);

IF DATABASEPROPERTYEX (N'Credit', 'Status') = N'ONLINE'
BEGIN
    SELECT @ExecString =
        N'CREATE EVENT SESSION [XE_Recompiles] ON SERVER'
        + N' ADD EVENT sqlserver.sql_statement_recompile( '
        + N' WHERE ([package0].[equal_uint64]([source_database_id], ( '
                + CONVERT (VARCHAR(5), DB_ID(N'Credit' ))
        + ')) AND [object_type]=(8272)))'
        + ' ADD TARGET package0.ring_buffer'
        + ' WITH (MAX_MEMORY=4096 KB'
           + ' , MAX_DISPATCH_LATENCY=1 SECONDS)' ;
       
    EXEC ( @ExecString );
       
    ALTER EVENT SESSION [XE_Recompiles]
           ON SERVER
           STATE = START;
END;
ELSE
BEGIN
    RAISERROR ('The sample database:Credit does not exist.' , 16, -1 );
    RETURN;
END;
GO


/* Pesquisa de eventos */
SET NOCOUNT ON;
SELECT
       [event] .[value]( '(event/@name)[1]', 'VARCHAR(50)') AS [EventName]
       , DATEADD (hh, DATEDIFF( hh, GETUTCDATE(), CURRENT_TIMESTAMP)
       , [event]. [value]('(event/@timestamp)[1]' , 'DATETIME2' )) AS [EventTime]
       , [event]. [value]('(event/data[@name="recompile_cause"]/text)[1]' , 'VARCHAR(255)') AS [RecompileCause]
       , OBJECT_NAME ([event] .[value]( '(event/data[@name="object_id"]/value)[1]' , 'INT')
       , [event]. [value]('(event/data[@name="source_database_id"]/value)[1]' , 'INT')) AS [ObjectName]
       , [event]. [value]('(event/data[@name="offset"]/value)[1]' , 'INT' ) AS [offset]
       , [event]. [value]('(event/data[@name="offset_end"]/value)[1]' , 'INT' ) AS [offset_end]
FROM
     (   SELECT [n].[query] ('.') AS [event]
         FROM
         (
             SELECT CAST ([target_data] AS XML) AS [target_data]
             FROM [sys]. [dm_xe_sessions] AS [s]
             JOIN [sys]. [dm_xe_session_targets] AS [t]
                 ON [s]. [address] = [t] .[event_session_address]
             WHERE [s]. [name] = N'XE_Recompiles'
               AND [t]. [target_name] = N'ring_buffer'
         ) AS [sub]
         CROSS APPLY [target_data].[nodes] ('RingBufferTarget/event')
            AS [q]( [n])
     ) AS [tab];
GO

/* Finalização da sessão */
IF (SELECT COUNT(*)
    FROM [sys] .[dm_xe_sessions] AS [xes]
    WHERE [xes] .[name] = N'XE_Recompiles') = 1

BEGIN
    ALTER EVENT SESSION [XE_Recompiles]
        ON SERVER
        STATE = STOP;

    DROP EVENT SESSION [XE_Recompiles]
    ON SERVER;
END;
GO