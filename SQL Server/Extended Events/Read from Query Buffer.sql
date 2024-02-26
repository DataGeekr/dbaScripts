
---
CREATE EVENT SESSION [CaptureADF]
ON DATABASE
    ADD EVENT sqlserver.rpc_completed,
    ADD EVENT sqlserver.sql_batch_completed
    (ACTION
     (
         sqlserver.sql_text
     )
    ),
    ADD EVENT sqlserver.sql_batch_starting,
    ADD EVENT sqlserver.sql_statement_completed
    ADD TARGET package0.ring_buffer
    (SET max_events_limit = (3000))
WITH
(
    MAX_MEMORY = 4096KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 30 SECONDS,
    MAX_EVENT_SIZE = 0KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = OFF
);
GO
---

---
DECLARE @ExtendedEventsSessionName sysname = N'CaptureADF';
DECLARE @StartTime DATETIMEOFFSET;
DECLARE @EndTime DATETIMEOFFSET;
DECLARE @Offset INT;

DROP TABLE IF EXISTS #xmlResults;
CREATE TABLE #xmlResults
(
    xeTimeStamp DATETIMEOFFSET NOT NULL,
    xeXML XML NOT NULL,
    xeQuery VARCHAR(MAX),
    xeEvent VARCHAR(MAX)
);

SET @StartTime = DATEADD(HOUR, -4, GETDATE()); --modify this to suit your needs
SET @EndTime = GETDATE();
SET @Offset = DATEDIFF(MINUTE, GETDATE(), GETUTCDATE());
SET @StartTime = DATEADD(MINUTE, @Offset, @StartTime);
SET @EndTime = DATEADD(MINUTE, @Offset, @EndTime);

SELECT StartTimeUTC = CONVERT(VARCHAR(30), @StartTime, 127),
       StartTimeLocal = CONVERT(VARCHAR(30), DATEADD(MINUTE, 0 - @Offset, @StartTime), 120),
       EndTimeUTC = CONVERT(VARCHAR(30), @EndTime, 127),
       EndTimeLocal = CONVERT(VARCHAR(30), DATEADD(MINUTE, 0 - @Offset, @EndTime), 120);

DECLARE @target_data XML;
SELECT @target_data = CONVERT(XML, target_data)
FROM sys.dm_xe_database_sessions AS s
    JOIN sys.dm_xe_database_session_targets AS t
        ON t.event_session_address = s.address
WHERE s.name = @ExtendedEventsSessionName
      AND t.target_name = N'ring_buffer';

;WITH src
AS (SELECT xeXML = xm.s.query('.')
    FROM @target_data.nodes('/RingBufferTarget/event') AS xm(s) )
INSERT INTO #xmlResults
(
    xeXML,
    xeTimeStamp,
    xeQuery,
    xeEvent
)
SELECT src.xeXML,
       [xeTimeStamp] = src.xeXML.value('(/event/@timestamp)[1]', 'datetimeoffset(7)'),
       xeQuery = src.xeXML.value('(/event/data[@name="statement"]/value/text())[1]', 'varchar(max)'),
       xeEvent = src.xeXML.value('(/event/@name)[1]', 'varchar(max)')
FROM src;

SELECT [TimeStamp] = CONVERT(VARCHAR(30), DATEADD(MINUTE, 0 - @Offset, xr.xeTimeStamp), 120),
       xr.xeQuery,
       xr.xeXML,
       xr.xeEvent
FROM #xmlResults xr
WHERE xr.xeTimeStamp >= @StartTime
      AND xr.xeTimeStamp <= @EndTime
      AND xr.xeQuery NOT IN ( 'exec sp_reset_connection' );
--AND xr.xeQuery LIKE '%spu_%'
----AND xr.xeQuery NOT LIKE '%Extended%'
--ORDER BY xr.xeTimeStamp DESC ;
---
