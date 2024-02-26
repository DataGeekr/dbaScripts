https://www.sqlskills.com/blogs/jonathan/implicit-conversions-that-cause-index-scans/

/* Implicit conversion */
-- Conversão de data types no execution plan. A coluna ou variável será convertida para o datatype de hierarquia superior CHAR -> NCHAR
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @dbname SYSNAME
SET @dbname = QUOTENAME( DB_NAME());

WITH XMLNAMESPACES
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT
   stmt.value ('(@StatementText)[1]', 'varchar(max)'),
   t.value ('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'varchar(128)'),
   t.value ('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'varchar(128)'),
   t.value ('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'varchar(128)'),
   ic.DATA_TYPE AS ConvertFrom,
   ic.CHARACTER_MAXIMUM_LENGTH AS ConvertFromLength,
   t.value ('(@DataType)[1]', 'varchar(128)') AS ConvertTo ,
   t.value ('(@Length)[1]', 'int') AS ConvertToLength ,
   query_plan
FROM sys .dm_exec_cached_plans AS cp
CROSS APPLY sys. dm_exec_query_plan(plan_handle ) AS qp
CROSS APPLY query_plan.nodes( '/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple' ) AS batch(stmt)
CROSS APPLY stmt.nodes ('.//Convert[@Implicit="1"]') AS n (t)
JOIN INFORMATION_SCHEMA .COLUMNS AS ic
   ON QUOTENAME(ic .TABLE_SCHEMA) = t.value( '(ScalarOperator/Identifier/ColumnReference/@Schema)[1]' , 'varchar(128)' )
   AND QUOTENAME(ic .TABLE_NAME) = t.value( '(ScalarOperator/Identifier/ColumnReference/@Table)[1]' , 'varchar(128)' )
   AND ic .COLUMN_NAME = t.value( '(ScalarOperator/Identifier/ColumnReference/@Column)[1]' , 'varchar(128)' )
WHERE t.exist( 'ScalarOperator/Identifier/ColumnReference[@Database=sql:variable("@dbname")][@Schema!="[sys]"]' ) = 1



/* Probe Residual */
-- Conversão de data types no join. A coluna ou variável será convertida para o datatype de hierarquia superior CHAR -> NCHAR
SET STATISTICS PROFILE OFF;
GO
   
DECLARE @dbname sysname = QUOTENAME(DB_NAME ());

WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan' )
SELECT [query_plan]
     , [BuildSchema]
     , [BuildTable]
     , [BuildColumn]
     , [ic]. [DATA_TYPE] AS [BuildColumnType]
     , ISNULL (CAST ([ic] .[CHARACTER_MAXIMUM_LENGTH] AS NVARCHAR)
     , ( CAST ( [ic].[NUMERIC_PRECISION] AS NVARCHAR ) + N',' + CAST ([ic]. [NUMERIC_SCALE] AS NVARCHAR))) AS [BuildColumnLength]
     , [ProbeSchema]
     , [ProbeTable]
     , [ProbeColumn]
     , [ic2]. [DATA_TYPE] AS [ProbeColumnType]
     , ISNULL (CAST ([ic2] .[CHARACTER_MAXIMUM_LENGTH] AS NVARCHAR)
     , ( CAST ( [ic2].[NUMERIC_PRECISION] AS NVARCHAR ) + N',' + CAST ([ic2]. [NUMERIC_SCALE] AS NVARCHAR))) AS [ProbeColumnLength]
FROM (
        SELECT
          [query_plan] ,
          [t] .[value]( N'(../HashKeysBuild/ColumnReference/@Schema)[1]' , N'NVARCHAR(128)') AS [BuildSchema],
          [t] .[value]( N'(../HashKeysBuild/ColumnReference/@Table)[1]' , N'nvarchar(128)') AS [BuildTable],
          [t] .[value]( N'(../HashKeysBuild/ColumnReference/@Column)[1]' , N'nvarchar(128)') AS [BuildColumn],
          [t] .[value]( N'(../HashKeysProbe/ColumnReference/@Schema)[1]' , N'nvarchar(128)') AS [ProbeSchema],
          [t] .[value]( N'(../HashKeysProbe/ColumnReference/@Table)[1]' , N'nvarchar(128)') AS [ProbeTable],
          [t] .[value]( N'(../HashKeysProbe/ColumnReference/@Column)[1]' , N'nvarchar(128)') AS [ProbeColumn]
        FROM [sys]. [dm_exec_cached_plans] AS [cp]
               CROSS APPLY
          [sys] .[dm_exec_query_plan]([plan_handle]) AS [qp]
               CROSS APPLY
          [query_plan].[nodes]( N'/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple' ) AS batch(stmt)
               CROSS APPLY
          [stmt] .[nodes]( N'.//Hash/ProbeResidual') AS [n]( [t])
        WHERE [t].[exist]( N'../HashKeysProbe/ColumnReference[@Database=sql:variable("@dbname")][@Schema!="[sys]"]' ) = 1
        ) AS [Probes]
     LEFT JOIN
     [INFORMATION_SCHEMA] .[COLUMNS] AS [ic]
        ON  QUOTENAME ([ic] .[TABLE_SCHEMA]) = [Probes] .[BuildSchema]
        AND QUOTENAME ([ic] .[TABLE_NAME]) = [Probes] .[BuildTable]
        AND [ic]. [COLUMN_NAME] = [Probes] .[BuildColumn]
     LEFT JOIN
     [INFORMATION_SCHEMA] .[COLUMNS] AS [ic2]
        ON QUOTENAME ([ic2] .[TABLE_SCHEMA]) = [Probes] .[ProbeSchema]
        AND QUOTENAME ([ic2] .[TABLE_NAME]) = [Probes] .[ProbeTable]
        AND [ic2]. [COLUMN_NAME] = [Probes] .[ProbeColumn]
WHERE [ic]. [DATA_TYPE] <> [ic2] .[DATA_TYPE]
OR (
    [ic] .[DATA_TYPE] = [ic2].[DATA_TYPE]
AND ISNULL (CAST ([ic] .[CHARACTER_MAXIMUM_LENGTH] AS NVARCHAR), (CAST ([ic]. [NUMERIC_PRECISION] AS NVARCHAR)+ N',' + CAST ([ic]. [NUMERIC_SCALE] AS NVARCHAR)))
    <> ISNULL ( CAST ( [ic2].[CHARACTER_MAXIMUM_LENGTH] AS NVARCHAR ), ( CAST ([ic2]. [NUMERIC_PRECISION] AS NVARCHAR) + N',' + CAST ( [ic2].[NUMERIC_SCALE] AS NVARCHAR)))
   )
OPTION (MAXDOP 1);
GO