/***********************
   Size of Data Files
************************/
IF ( OBJECT_ID( 'TempDB..#datafileSize' ) IS NOT NULL )
BEGIN
     DROP TABLE #datafileSize;
END;
CREATE TABLE #datafileSize
(
dbName           sysname
, dbStatus       VARCHAR(20)
, RecoveryModel  VARCHAR(20)    DEFAULT ( 'NA' )
, dataFileSizeMB DECIMAL(20, 2) DEFAULT ( 0 )
, SpaceUsedMB    DECIMAL(20, 2) DEFAULT ( 0 )
, FreeSpaceMB    DECIMAL(20, 2) DEFAULT ( 0 )
);
INSERT INTO #datafileSize ( dbName, dbStatus, RecoveryModel, dataFileSizeMB, SpaceUsedMB, FreeSpaceMB )
EXEC sp_MSforeachdb 'USE [?];
    SELECT DB_NAME() AS DbName
         , CONVERT(varchar(20),DatabasePropertyEx(DB_NAME(),''Status''))
         , CONVERT(varchar(20),DatabasePropertyEx(DB_NAME(),''Recovery''))
         , CONVERT(DECIMAL(20,2), ROUND(SUM(size)/128.0, 2)) AS dataFileSizeMB
         , CONVERT(DECIMAL(20,2), ROUND(SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT))/128.0, 2)) AS SpaceUsedMB
         , CONVERT(DECIMAL(20,2), ROUND((SUM(size)/128.0 - SUM(CAST(FILEPROPERTY(name,''SpaceUsed'') AS INT))/128.0), 2)) AS FreeSpaceMB
    FROM sys.database_files
    WHERE Type = 0
    GROUP BY Type;';
GO
/***********************
   Size of Log Files
************************/
IF ( OBJECT_ID( 'TempDB..#logfileSize' ) IS NOT NULL )
BEGIN
     DROP TABLE #logfileSize;
END;
CREATE TABLE #logfileSize
(
dbName           sysname
, logFileSizeMB DECIMAL(20, 2) DEFAULT ( 0 )
, logSpaceUsedMB DECIMAL(20, 2) DEFAULT ( 0 )
, logFreeSpaceMB DECIMAL(20, 2) DEFAULT ( 0 )
);
INSERT INTO #logfileSize ( dbName, logFileSizeMB, logSpaceUsedMB, logFreeSpaceMB )
EXEC sp_MSforeachdb 'USE [?];
    SELECT DB_NAME() AS dbName
         , CONVERT(DECIMAL(20,2), ROUND(SUM(size)/128.0, 2)) AS logFileSizeMB
         , CONVERT(DECIMAL(20,2), ROUND(SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT))/128.0, 2)) as logSpaceUsedMB
         , CONVERT(DECIMAL(20,2), ROUND(SUM(size)/128.0 - SUM(CAST(FILEPROPERTY(name,''SpaceUsed'') AS INT))/128.0, 2)) AS logFreeSpaceMB
    FROM sys.database_files
    WHERE Type = 1
    GROUP BY Type;';
GO
/***********************
   Size of Free Space
************************/
IF ( OBJECT_ID( 'TempDB..#dbFreeSize' ) IS NOT NULL )
BEGIN
     DROP TABLE #dbFreeSize;
END;
CREATE TABLE #dbFreeSize
(
dbName      sysname
, dbSize    VARCHAR(50)
, Freespace VARCHAR(50) DEFAULT ( 0.00 )
);
INSERT INTO #dbFreeSize ( dbName, dbSize, Freespace )
EXEC sp_MSforeachdb 'USE [?];
    SELECT dbName = db_name()
         , dbSize = LTRIM(STR((CONVERT(DECIMAL(15, 2), dbSize) + CONVERT(DECIMAL(15, 2), logsize)) * 8192 / 1048576, 15, 2) + ''MB'')
         , ''unallocated space'' = LTRIM(STR((CASE WHEN dbSize >= reservedpages
                                                   THEN (convert(DECIMAL(15, 2), dbSize) - convert(DECIMAL(15, 2), reservedpages)) * 8192 / 1048576
                                                   ELSE 0
                                              END), 15, 2) + '' MB'')
    FROM (
           SELECT dbSize = SUM(CONVERT(BIGINT, CASE WHEN type = 0
                                                    THEN size
                                                    ELSE 0
                                               END))
                , logsize = SUM(CONVERT(BIGINT, CASE WHEN type <> 0
                                                     THEN size
                                                     ELSE 0
                                                END))
           FROM sys.database_files
         ) AS files
       , (
           SELECT reservedpages = sum(a.total_pages)
                , usedpages = sum(a.used_pages)
                , pages = SUM(CASE WHEN it.internal_type IN ( 202, 204, 211, 212, 213, 214, 215, 216)
                                   THEN 0
                                   WHEN a.type <> 1
                                   THEN a.used_pages
                                   WHEN p.index_id < 2
                                   THEN a.data_pages
                                   ELSE 0
                              END)
           FROM sys.partitions p
                INNER JOIN sys.allocation_units a
                      ON p.partition_id = a.container_id
                LEFT JOIN sys.internal_tables it
                      ON p.object_id = it.object_id
         ) AS partitions';
GO
/***********************
   Reporting Sizes
************************/
IF ( OBJECT_ID( 'TempDB..#allDBState' ) IS NOT NULL )
BEGIN
     DROP TABLE #allDBState;
END;
CREATE TABLE #allDBState ( dbName sysname, dbStatus VARCHAR(25), RecoveryModel VARCHAR(20));
INSERT INTO #allDBState ( dbName, dbStatus, RecoveryModel )
            SELECT name
                 , CONVERT( VARCHAR(20), DATABASEPROPERTYEX( name, 'status' ))
                 , recovery_model_desc
            FROM sys.databases;
INSERT INTO #datafileSize ( dbName, dbStatus, RecoveryModel )
            SELECT dbName
                 , dbStatus
                 , RecoveryModel
            FROM #allDBState
            WHERE dbStatus != 'online';
INSERT INTO #logfileSize ( dbName )
            SELECT dbName
            FROM #allDBState
            WHERE dbStatus != 'online';
INSERT INTO #dbFreeSize ( dbName )
            SELECT dbName
            FROM #allDBState
            WHERE dbStatus != 'online';
SELECT d.dbName
     , d.dbStatus
     , d.RecoveryModel
     , d.dataFileSizeMB
     , d.SpaceUsedMB
     , d.FreeSpaceMB
     , CONVERT(DECIMAL(5,2), (d.FreeSpaceMB / d.dataFileSizeMB) * 100.0) AS [Data Free %]
     , l.logFileSizeMB
     , logSpaceUsedMB
     , l.logFreeSpaceMB
     , CONVERT(DECIMAL(5,2), (l.logFreeSpaceMB / l.logFileSizeMB) * 100.0) AS [Log Free %]
     , ( dataFileSizeMB + logFileSizeMB ) AS dbSize
     , fs.Freespace AS dbFreespace
FROM #datafileSize d
     INNER JOIN
          #logfileSize l
               ON d.dbName = l.dbName
     INNER JOIN
          #dbFreeSize fs
               ON d.dbName = fs.dbName
ORDER BY dbStatus
       , dbName;