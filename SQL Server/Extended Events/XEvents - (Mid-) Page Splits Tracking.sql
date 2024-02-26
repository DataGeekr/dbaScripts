-- 1º - Criação do extended event para identificar o banco de dados que está causando os splits 

-- If the Event Session exists DROP it
IF EXISTS ( SELECT 1
               FROM sys .server_event_sessions
               WHERE name = 'PageSplitsTracking' )
   DROP EVENT SESSION [PageSplitsTracking] ON SERVER

-- Create the Event Session to track LOP_DELETE_SPLIT transaction_log operations in the server
CREATE EVENT SESSION [PageSplitsTracking] ON SERVER
ADD EVENT
sqlserver.transaction_log
(
     WHERE Operation = 11 -- LOP_DELETE_SPLIT
)
ADD TARGET package0.histogram
(  SET filtering_event_name = 'sqlserver.transaction_log'
,                           source_type = 0
, -- Event Column
source = 'database_id' );
GO
       
-- Start the Event Session
ALTER EVENT SESSION [PageSplitsTracking]
ON SERVER
STATE=START ;
GO

2º - Consulta os eventos para identificar o banco de dados
/* Query - histogram target para identificar o banco de dados causando a maior parte dos splits */
SELECT n.value('(value)[1]' , 'bigint' ) AS database_id
     ,DB_NAME (n. value('(value)[1]' , 'bigint' )) AS database_name
     ,n. value('(@count)[1]' , 'bigint' ) AS split_count
FROM (
     SELECT CAST (target_data AS XML) target_data
     FROM sys.dm_xe_sessions AS s
          JOIN sys.dm_xe_session_targets t
               ON s.address = t.event_session_address
     WHERE s. name = 'PageSplitsTracking'
     AND t. target_name = 'histogram'
     ) AS tab
CROSS APPLY target_data.nodes ('HistogramTarget/Slot') AS q (n )

3º - Com o banco de dados em mãos, realizamos a alteração do Xevents para verificar o banco de dados
e então, alterar o alvo do histogram para separar (bucket) sobre o alloc_unit_id a fim de identificar
os piores índices que estão ocasionando mid-page splits.

DROP EVENT SESSION [PageSplitsTracking]
ON SERVER

-- Create the Event Session to track LOP_DELETE_SPLIT transaction_log operations in the server
CREATE EVENT SESSION [PageSplitsTracking] ON SERVER
ADD EVENT sqlserver.transaction_log (
     WHERE Operation = 11  -- LOP_DELETE_SPLIT
     AND database_id = 8 -- CHANGE THIS BASED ON TOP SPLITTING DATABASE!
)
ADD TARGET package0.histogram (  SET filtering_event_name = 'sqlserver.transaction_log'
     ,                           source_type = 0
     , -- Event Column
                                 source = 'alloc_unit_id' );
GO

-- Start the Event Session Again
ALTER EVENT SESSION [PageSplitsTracking]
ON SERVER
STATE=START ;
GO

4º - Com a nova definição dos eventos, podemos rodar novamente o workload problemático e 
identificar os piores indices com base no alloc_unit_id que estão no histogram.

-- Query Target Data to get the top splitting objects in the database:
SELECT    o. name AS table_name
        , i. name AS index_name
        , tab. split_count
        , i. fill_factor
FROM      (
           SELECT   n. value('(value)[1]' , 'bigint' ) AS alloc_unit_id
                  , n. value('(@count)[1]' , 'bigint' ) AS split_count
           FROM     (
                     SELECT   CAST (target_data AS XML) target_data
                     FROM     sys .dm_xe_sessions AS s
                              JOIN sys .dm_xe_session_targets t
                                   ON s. address = t.event_session_address
                     WHERE    s. name = 'PageSplitsTrackingDetails'
                              AND t. target_name = 'histogram'
                    ) AS tab
                    CROSS APPLY target_data.nodes ('HistogramTarget/Slot') AS q (n )
          ) AS tab
          JOIN sys .allocation_units AS au
               ON tab. alloc_unit_id = au .allocation_unit_id
          JOIN sys .partitions AS p
               ON au. container_id = p .partition_id
          JOIN sys .indexes AS i
               ON p. object_id = i.object_id
                  AND p. index_id = i .index_id
          JOIN sys .objects AS o
               ON p. object_id = o.object_id
WHERE     o. is_ms_shipped = 0 ;

5º - Após identificar os indices, realizamos a alteração do Fillfactor e resetamos a sessão
para podermos novamente identificar se o problema foi solucionado.

-- Change FillFactor based on split occurences
ALTER INDEX IX_EndSplitsPK_ChangeDate ON EndSplitsPK REBUILD WITH (FILLFACTOR=80)
GO
 
-- Stop the Event Session to clear the target
ALTER EVENT SESSION [SQLskills_TrackPageSplits]
ON SERVER
 STATE=STOP;
 GO
 
 -- Start the Event Session AgainALTER EVENT SESSION [SQLskills_TrackPageSplits]
 ON SERVER
 STATE=START;
 GO
