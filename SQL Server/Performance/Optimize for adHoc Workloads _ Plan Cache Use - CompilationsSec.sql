-- Porcentagem de uso do cache
DECLARE  @sumOfCacheEntries FLOAT = ( SELECT COUNT(*) FROM sys.dm_exec_cached_plans )
SELECT  objtype,
   ROUND(( CAST(COUNT (*) AS FLOAT) / @sumOfCacheEntries ) * 100,2 ) [pc_In_Cache]
FROM  sys .dm_exec_cached_plans p
GROUP BY objtype
ORDER BY 2

-- Porcentagem por quantidade de UseCounts
DECLARE @singleUse FLOAT , @multiUse FLOAT , @total FLOAT
SET @singleUse = ( SELECT COUNT (*)
     FROM sys .dm_exec_cached_plans
     WHERE cacheobjtype = 'Compiled Plan'
     AND usecounts = 1)
SET @multiUse =   ( SELECT COUNT (*)
     FROM sys .dm_exec_cached_plans
     WHERE cacheobjtype = 'Compiled Plan'
     AND usecounts > 1)
SET @total = @singleUse + @multiUse
SELECT 'Single Usecount' , ROUND ((@singleUse / @total) * 100, 2) [pc_single_usecount]
UNION ALL
SELECT 'Multiple Usecount' , ROUND ((@multiUse / @total) * 100, 2)


-- Queries com indice de compilação alto
SELECT TOP 10
          query_hash
        , query_plan_hash
        , st. text
        , db. name
        , P.*, q.*
        , *
FROM sys .dm_exec_query_stats qs
     INNER JOIN
     sys.dm_exec_cached_plans cp
          ON qs. plan_handle = cp .plan_handle
     CROSS APPLY
     sys.dm_exec_sql_text (qs. plan_handle) st
     CROSS APPLY
     sys.dm_exec_query_plan (cp . plan_handle) p
     CROSS APPLY
     sys. dm_exec_sql_text(cp .plan_handle) AS Q
     INNER JOIN master. sys.sysdatabases db
               ON st. dbid = db.dbid
     CROSS APPLY
     (
     SELECT value AS setoptions
     FROM sys .dm_exec_plan_attributes( cp .plan_handle )
     WHERE attribute = 'set_options'
     ) a   
WHERE     usecounts = 1
          AND cacheobjtype = 'Compiled Plan'
          AND objtype = 'Adhoc'
          AND st. [text] NOT LIKE '%SELECT%TOP%10%t%text%'

/*
Se existem queries idênticas com planos diferentes, verificar os atributos da conexão

SELECT * FROM sys.dm_exec_plan_attributes(0x06000B00C818370900904B171700000001000000000000000000000000000000000000000000000000000000)
SELECT * FROM sys.dm_exec_plan_attributes(0x06000B005FA5B12750AE4BC91700000001000000000000000000000000000000000000000000000000000000)

Documentation of dm_exec_plan_attributes: http://technet.microsoft.com/en-us/library/ms189472.aspx
OR
DECLARE @set_options_value INT = 251
PRINT 'Set options for value 251:'
IF @set_options_value & 1 = 1 PRINT 'ANSI_PADDING'
IF @set_options_value & 2 = 1 PRINT 'Parallel Plan'
IF @set_options_value & 4 = 4 PRINT 'FORCEPLAN'
IF @set_options_value & 8 = 8 PRINT 'CONCAT_NULL_YIELDS_NULL'
IF @set_options_value & 16 = 16 PRINT 'ANSI_WARNINGS'
IF @set_options_value & 32 = 32 PRINT 'ANSI_NULLS'
IF @set_options_value & 64 = 64 PRINT 'QUOTED_IDENTIFIER'
IF @set_options_value & 128 = 128 PRINT 'ANSI_NULL_DFLT_ON'
IF @set_options_value & 256 = 256 PRINT 'ANSI_NULL_DFLT_OFF'
IF @set_options_value & 512 = 512 PRINT 'NoBrowseTable'
IF @set_options_value & 1024 = 1024 PRINT 'TriggerOneRow'
IF @set_options_value & 2048 = 2048 PRINT 'ResyncQuery'
IF @set_options_value & 4096 = 4096 PRINT 'ARITHABORT'
IF @set_options_value & 8192 = 8192 PRINT 'NUMERIC_ROUNDABORT'
IF @set_options_value & 16384 = 16384 PRINT 'DATEFIRST'
IF @set_options_value & 32768 = 32768 PRINT 'DATEFORMAT'
IF @set_options_value & 65536 = 65536 PRINT 'LanguageId'
IF @set_options_value & 131072 = 131072 PRINT 'UPON'
*/

 

  