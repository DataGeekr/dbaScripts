
---
/* 
DROP EVENT SESSION [PageSplits] 
ON SERVER 
GO 
CREATE EVENT SESSION [PageSplits] 
ON SERVER 
      ADD EVENT sqlserver.page_split 
      ( 
      WHERE ( ([database_id]> 5) 
      )) 
      ADD TARGET package0.event_file 
      ( SET filename = N'Z:\SQLServer\TracesSQL\XEvents\PageSplits\PageSplits.xel', max_file_size = ( 250 ), max_rollover_files = ( 3 )) 
WITH ( 
           MAX_MEMORY = 4096KB 
         , EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS 
         , MAX_DISPATCH_LATENCY = 30 SECONDS 
         , MAX_EVENT_SIZE = 0KB 
         , MEMORY_PARTITION_MODE = NONE 
         , TRACK_CAUSALITY = ON 
         , STARTUP_STATE = ON 
     ); 
GO 
ALTER EVENT SESSION [PageSplits] ON SERVER STATE = START; 
GO 
*/ 
SET NOCOUNT ON; 
DECLARE @control_id INT; 
DECLARE @database_id INT; 
DECLARE @file_id INT; 
DECLARE @page_id VARCHAR(20); 
DECLARE @sql VARCHAR(100); 
DECLARE @objName VARCHAR(100); 
DECLARE @indexId VARCHAR(5) 
DROP TABLE IF EXISTS #PagesFromSplits; 
CREATE TABLE #PagesFromSplits 
( 
  controlId   INT NOT NULL IDENTITY(1,1) 
, databaseId  INT 
, fileId      INT 
, pageId      VARCHAR(30) 
, objectName  VARCHAR(100) DEFAULT('') 
, indexId     VARCHAR(5) DEFAULT('') 
, CONSTRAINT PK_PagesFromSplits PRIMARY KEY (controlId) 
); 
-- Query de retorno do Extended Events de Page Splits 
DROP TABLE IF EXISTS #ExEvents; 
;WITH cteXE  
AS ( 
   SELECT CONVERT(XML, event_data) AS event_data 
   --FROM sys.fn_xe_file_target_read_file(N'D:\Program Files\Microsoft SQL Server\MSSQL14.IPBD002\MSSQL\Log\PageSplits*.xel', NULL, NULL, NULL) 
   FROM sys.fn_xe_file_target_read_file(N'Z:\SQLServer\TracesSQL\XEvents\PageSplits\PageSplits*.xel', NULL, NULL, NULL) 
   ) 
SELECT cteXE.event_data.value('(//event/@timestamp)[1]', 'datetime') AS DataEvento 
	 , cteXE.event_data 
INTO #ExEvents 
FROM cteXE 
     
INSERT INTO #PagesFromSplits (databaseId, fileId, pageId) 
SELECT  xed.event_data.value('(data[@name="database_id"]/value)[1]', 'int') AS DatabaseId 
     ,  xed.event_data.value('(data[@name="file_id"]/value)[1]', 'int') AS FileId 
     ,  xed.event_data.value('(data[@name="page_id"]/value)[1]', 'int') AS PageId 
     --,  xed.event_data.value('(data[@name="splitOperation"]/value)[1]', 'int') AS splitOperation 
     --,  xed.event_data.value('(data[@name="new_page_file_id"]/value)[1]', 'int') AS NewPageFileId 
     --,  xed.event_data.value('(data[@name="new_page_page_id"]/value)[1]', 'int') AS NewPageId 
FROM #ExEvents ExEv 
     CROSS APPLY  
	ExEv.event_data.nodes('//event') AS xed (event_data) 
ORDER BY DatabaseId 
DECLARE @outTable TABLE 
( 
      parentObject VARCHAR(100) 
    , objectName VARCHAR(150) 
    , field VARCHAR(100) 
    , objectValue VARCHAR(100) 
); 
DECLARE _curPages CURSOR FOR 
     SELECT controlId  
          , databaseId 
          , fileId 
          , pageId 
     FROM  #PagesFromSplits; 
OPEN _curPages; 
FETCH NEXT FROM _curPages 
INTO @control_id 
   , @database_id 
   , @file_id 
   , @page_id; 
WHILE @@FETCH_STATUS = 0 
BEGIN 
       
      IF @database_id > 5 AND @file_id > 0 AND @page_id > 0 
      BEGIN 
           SELECT @sql = 'DBCC PAGE(' + CAST(@database_id AS VARCHAR(100)) + ',' + CAST(@file_id AS VARCHAR(100)) + ',' + @page_id + ') WITH TABLERESULTS'; 
           INSERT INTO @outTable 
           EXEC ( @sql ); 
           SELECT @objName = OBJECT_NAME(objectValue, @database_id) 
           FROM  @outTable 
           WHERE field = 'Metadata: ObjectId'; 
           SELECT @indexId = objectValue 
           FROM  @outTable 
           WHERE field = 'Metadata: IndexId'; 
           UPDATE #PagesFromSplits 
           SET   objectName = @objName 
             ,   indexId    = @indexId 
           WHERE controlId = @control_id; 
           DELETE @outTable; 
     END;  
     FETCH NEXT FROM _curPages 
     INTO @control_id 
     , @database_id 
     , @file_id 
     , @page_id; 
END; 
CLOSE _curPages; 
DEALLOCATE _curPages; 
SELECT db.database_id 
     , db.name 
     , pg.objectName 
     , pg.indexId 
     , pg.fileId 
FROM sys.databases db 
     INNER JOIN 
     ( 
     SELECT DISTINCT databaseId, objectName, indexId, fileId 
     FROM #PagesFromSplits 
     ) pg 
          ON pg.databaseId = db.database_id 
ORDER BY db.database_id 
       , pg.objectName;
---
