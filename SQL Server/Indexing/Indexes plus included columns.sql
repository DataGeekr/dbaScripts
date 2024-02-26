USE OabProtheus;
GO
DECLARE @IndexName NVARCHAR(128);
SET @IndexName = '';
SELECT SCHEMA_NAME(o.schema_id) SchemaName
     , o.name ObjectName
     , i.name IndexName
     , i.type_desc
     , LEFT(indCol.list, ISNULL(indCol.splitter - 1, LEN(indCol.list))) Columns
     , SUBSTRING(indCol.list, indCol.splitter + 1, 100) includedColumns
     --len(name) - splitter-1) columns
     , COUNT(1) OVER ( PARTITION BY o.object_id )
FROM sys.indexes i
INNER JOIN
     sys.objects o
            ON i.object_id = o.object_id
CROSS APPLY
     (
     SELECT NULLIF(CHARINDEX('|', indexCols.list), 0) splitter
          , indexCols.list
     FROM (
          SELECT CAST((
                      SELECT  CASE WHEN sc.is_included_column = 1
                                    AND sc.ColPos = 1
                                   THEN '|'
                                   ELSE ''
                              END +
                              CASE WHEN sc.ColPos > 1
                                   THEN ', '
                                   ELSE ''
                              END +
                              sc.name
                       FROM (
                            SELECT sc.is_included_column
                                 , sc.index_column_id
                                 , c.name
                                 , ROW_NUMBER() OVER ( PARTITION BY sc.is_included_column ORDER BY sc.index_column_id ) ColPos
                            FROM sys.index_columns sc
                            INNER JOIN
                                 sys.columns c
                                        ON sc.object_id = c.object_id
                                        AND sc.column_id = c.column_id
                            WHERE sc.index_id = i.index_id
                            AND   sc.object_id = i.object_id
                            ) sc
          ORDER BY sc.is_included_column
                 , sc.ColPos
          FOR XML PATH(''), TYPE) AS VARCHAR(MAX)) list
          ) indexCols
      ) indCol
WHERE ISNULL(@IndexName, '') = '' OR i.name = @IndexName
ORDER BY SchemaName
       , ObjectName
       , IndexName;
 