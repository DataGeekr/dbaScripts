DROP EVENT SESSION [DeadlockTracking] ON SERVER
GO

CREATE EVENT SESSION [DeadlockTracking] ON SERVER
ADD EVENT sqlserver.xml_deadlock_report(
    ACTION(sqlos.task_time,sqlserver.client_hostname,sqlserver.sql_text))
ADD TARGET package0.event_file(SET filename=N'Z:\dbaTraces\DeadlockTracking.xel',max_file_size=(262144))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

