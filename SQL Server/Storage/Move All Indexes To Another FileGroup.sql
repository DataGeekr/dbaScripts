 
DECLARE @vcDrive CHAR(1) DECLARE @vcNovoFileGroup NVARCHAR(256)
SET @vcDrive = 'Drive do arquivo onde estão os índices a serem migrados' SET @vcNovoFileGroup = 'Nome do novo filegroup'
SELECT NomeTabela , 'CREATE ' + IsUnique + ' ' + TypeDesc + ' INDEX ' + QUOTENAME(NomeIndex) + ' ON dbo.' + QUOTENAME(NomeTabela) 
+ ' (' + ColsIndex + ') ' 
+ CASE WHEN LEN(ColsInclude) != 0 THEN 'INCLUDE(' + ColsInclude + ') ' ELSE '' END + FilterDef 
+ ' WITH (' 
+ 'PADINDEX = ' + IsPadded 
+ ' IGNOREDUPKEY = ' + IgnoreDupKey 
+ ' ALLOWROWLOCKS = ' + AllowRowLocks 
+ ' ALLOWPAGELOCKS = ' + AllowPageLocks 
+ ' SORTINTEMPDB = OFF,' 
+ ' DROPEXISTING = ON,' 
+ ' ONLINE = OFF,' 
+ ' FILLFACTOR = ' + CAST(FFactor AS VARCHAR(3)) 
+ ') ON ' + QUOTENAME(@vcNovoFileGroup) 
COLLATE SQLLatin1GeneralCP1CIAI TypeDesc , physicalname FROM ( SELECT sTab.name AS NomeTabela , sInd.name AS NomeIndex, Substring((SELECT ', ' + ac.name FROM sys.tables AS t INNER JOIN sys.indexes i ON t.objectid = i.objectid INNER JOIN sys.indexcolumns ic ON i.objectid = ic.objectid AND i.indexid = ic.indexid INNER JOIN sys.allcolumns ac ON t.objectid = ac.objectid AND ic.columnid = ac.columnid WHERE sInd.objectid = i.objectid AND sInd.indexid = i.indexid AND ic.isincludedcolumn = 0 ORDER BY ic.keyordinal FOR XML PATH('')), 2, 8000) AS ColsIndex , Substring((SELECT ', ' + ac.name FROM sys.tables AS t INNER JOIN sys.indexes i ON t.objectid = i.objectid INNER JOIN sys.indexcolumns ic ON i.objectid = ic.objectid AND i.indexid = ic.indexid INNER JOIN sys.allcolumns ac ON t.objectid = ac.objectid AND ic.columnid = ac.columnid WHERE sInd.objectid = i.objectid AND sInd.indexid = i.indexid AND ic.isincludedcolumn = 1 ORDER BY ic.keyordinal FOR XML PATH('')), 2, 8000) AS ColsInclude , TypeDesc = sInd.typedesc , IsUnique = CASE WHEN IsUnique = 1 THEN 'UNIQUE ' ELSE '' END 
, IsPadded = CASE WHEN IsPadded = 0 THEN 'OFF,' ELSE 'ON,' END 
, IgnoreDupKey = CASE WHEN IgnoreDupKey = 0 THEN 'OFF,' ELSE 'ON,' END 
, AllowRowLocks = CASE WHEN AllowRowLocks = 0 THEN 'OFF,' ELSE 'ON,' END , AllowPageLocks = CASE WHEN AllowPageLocks = 0 THEN 'OFF,' ELSE 'ON,' END 
, FFactor = CASE WHEN FillFactor = 0 THEN 100 ELSE FillFactor END 
, FilterDef = CASE WHEN HasFilter = 1 THEN (' WHERE ' + FilterDefinition) ELSE '' END 
, sDF.physicalname FROM sys.indexes sInd INNER JOIN sys.tables AS sTab ON sTab.objectid = sInd.objectid INNER JOIN sys.filegroups sFG ON sInd.dataspaceid = sFG.dataspaceid INNER JOIN sys.databasefiles sDF ON sFG.dataspaceid = sDF.dataspaceid WHERE sInd.name IS NOT NULL AND sInd.typedesc = 'NONCLUSTERED' AND sDF.physicalname like @vc_Drive + ':\%' ) AS IdxDef 
ORDER BY NomeTabela