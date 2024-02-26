/*
declare @traceid int = 2

SELECT DISTINCT el.eventid, em.package_name, em.xe_event_name AS 'event'
   , el.columnid, ec.xe_action_name AS 'action'
FROM (sys.fn_trace_geteventinfo(@traceid) AS el
   LEFT OUTER JOIN sys.trace_xe_event_map AS em
      ON el.eventid = em.trace_event_id)
LEFT OUTER JOIN sys.trace_xe_action_map AS ec
   ON el.columnid = ec.trace_column_id
WHERE em.xe_event_name IS NOT NULL AND ec.xe_action_name IS NOT NULL;



SELECT xp.name package_name, xe.name event_name   ,xc.name event_field, xc.description
FROM sys.trace_xe_event_map AS em
INNER JOIN sys.dm_xe_objects AS xe
   ON em.xe_event_name collate SQL_Latin1_General_CP1_CI_AS = xe.name
INNER JOIN sys.dm_xe_packages AS xp
   ON xe.package_guid  = xp.guid AND em.package_name collate SQL_Latin1_General_CP1_CI_AS = xp.name
INNER JOIN sys.dm_xe_object_columns AS xc
   ON xe.name = xc.object_name
WHERE xe.object_type = 'event' AND xc.column_type <> 'readonly'
   AND em.xe_event_name in ('rpc_completed'
                           ,'sql_batch_completed'
                           ,'module_end'
                           ,'exec_prepared_sql' )
*/


IF EXISTS ( SELECT 1
            FROM sys .server_event_sessions
            WHERE name= 'session_name'
          )
   DROP EVENT SESSION [Session_Name] ON SERVER;
GO

CREATE EVENT SESSION [Session_Name]
ON SERVER
ADD EVENT sqlserver.rpc_completed
( ACTION
   ( sqlserver .client_app_name
   , sqlserver .server_principal_name
   , sqlserver .session_id
   , sqlserver .database_name
   )
--WHERE sqlserver.session_id = 00
WHERE ([package0] .[greater_than_uint64]( [duration],(5000 )))
),
ADD EVENT sqlserver.sql_batch_completed
( ACTION
   ( sqlserver .client_app_name
   , sqlserver .server_principal_name
   , sqlserver .session_id
   , sqlserver .database_name
   )
--WHERE sqlserver.session_id = 00
WHERE ([package0] .[greater_than_uint64]( [duration],(5000 )))
),
ADD EVENT sqlserver.exec_prepared_sql
( ACTION
   ( sqlserver .client_app_name
   , sqlserver .server_principal_name
   , sqlserver .session_id
   , sqlserver .database_name
   )
WHERE ([package0].[greater_than_uint64]( [sqlos.task_execution_time ],(5000 )))
)
-- Save to path location..
ADD TARGET package0.asynchronous_file_target
(
   SET filename      = 'Z:\temp\ExtendedEventsStoredProcs.xel'
     , metadatafile  = 'Z:\temp\ExtendedEventsStoredProcs.xem'
     , max_file_size = 100    
);

-- To start a session
ALTER EVENT SESSION[Session_Name] ON SERVER STATE = START;

/* -- To read events
SELECT *, CAST(event_data as XML) AS 'event_data_XML'
FROM sys.fn_xe_file_target_read_file('c:\temp\ExtendedEventsStoredProcs*.xel', 'c:\temp\ExtendedEventsStoredProcs*.xem', NULL, NULL);
*/