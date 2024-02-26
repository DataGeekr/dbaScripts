
```
SELECT
    TableName = tbl.table_schema + '.' + tbl.table_name, 
    TableDescription = tableProp.value,
    ColumnName = col.column_name, 
    ColumnDataType = col.data_type,
    ColumnDescription = colDesc.ColumnDescription
FROM information_schema.tables tbl
INNER JOIN information_schema.columns col 
    ON col.table_name = tbl.table_name
LEFT JOIN sys.extended_properties tableProp 
    ON tableProp.major_id = object_id(tbl.table_schema + '.' + tbl.table_name) 
        AND tableProp.minor_id = 0
        AND tableProp.name = 'MS_Description' 
LEFT JOIN (
    SELECT sc.object_id, sc.column_id, sc.name, colProp.[value] AS ColumnDescription
    FROM sys.columns sc
    INNER JOIN sys.extended_properties colProp
        ON colProp.major_id = sc.object_id
            AND colProp.minor_id = sc.column_id
            AND colProp.name = 'MS_Description' 
) colDesc
    ON colDesc.object_id = object_id(tbl.table_schema + '.' + tbl.table_name)
        AND colDesc.name = col.COLUMN_NAME
WHERE tbl.table_type = 'base table'
--AND tableProp.[value] IS NOT NULL OR colDesc.ColumnDescription IS NOT null
```
