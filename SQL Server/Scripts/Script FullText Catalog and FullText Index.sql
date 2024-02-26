DECLARE @Catalog NVARCHAR(128)
 , @SQL NVARCHAR(MAX)
 , @COLS NVARCHAR(4000)
 , @Owner NVARCHAR(128)
 , @Table NVARCHAR(128)
 , @ObjectID INT
 , @AccentOn BIT
 , @CatalogID INT
 , @IndexID INT
 , @Max_objectId INT
 , @NL CHAR(2)
 , @Path NVARCHAR(255);
-- Specify name of catalog to script
SELECT   @Catalog = 'ftCatEvento_Participante';
SELECT   @NL = CHAR(13) + CHAR(10);
 --Carriage Return
-- Check catalog exists
IF EXISTS ( SELECT   name
            FROM     sys.fulltext_catalogs
            WHERE    name = @Catalog )
BEGIN
-- Store the catalog details
   SELECT   @CatalogID = i.fulltext_catalog_id
          , @ObjectID = 0
          , @Max_objectId = MAX(i.object_id)
          , @AccentOn = c.is_accent_sensitivity_on
          , @Path = c.path
   FROM     sys.fulltext_index_catalog_usages AS i
            JOIN sys.fulltext_catalogs c
               ON i.fulltext_catalog_id = c.fulltext_catalog_id
   WHERE    c.name = @Catalog
   GROUP BY i.fulltext_catalog_id
          , c.path
          , c.is_accent_sensitivity_on;
-- Script out catalog
   PRINT 'CREATE FULLTEXT CATALOG ' + @Catalog + @NL;
   PRINT 'IN PATH N' + QUOTENAME(@Path, '''') + @NL;
   PRINT 'WITH ACCENT_SENSITIVITY = ' + CASE @AccentOn
                                          WHEN 1 THEN 'ON'
                                          ELSE 'OFF'
                                        END;
   PRINT 'GO';
-- Loop through all fulltext indexes within catalog
   WHILE @ObjectID < @Max_objectId
   BEGIN
      SELECT TOP 1
               @ObjectID = MIN(i.object_id)
             , @Owner = u.name
             , @Table = t.name
             , @IndexID = i.unique_index_id
      FROM     sys.objects AS t
               JOIN sys.sysusers AS u
                  ON u.uid = t.schema_id
               JOIN sys.fulltext_indexes i
                  ON t.object_id = i.object_id
               JOIN sys.fulltext_catalogs c
                  ON i.fulltext_catalog_id = c.fulltext_catalog_id
      WHERE    c.name = @Catalog
               AND i.object_id > @ObjectID
      GROUP BY i.object_id
             , u.name
             , t.name
             , i.unique_index_id
      ORDER BY i.object_id;
-- Script Fulltext Index
      SELECT   @COLS = NULL
             , @SQL = 'CREATE FULLTEXT INDEX ON ' + QUOTENAME(@Owner) + '.' + QUOTENAME(@Table) + ' (' + @NL;
-- Script columns in index
      SELECT   @COLS = COALESCE(@COLS + ',', '') + QUOTENAME(c.name) + ' Language ' + CAST(fi.language_id AS VARCHAR) + ' ' + @NL
      FROM     sys.fulltext_index_columns AS fi
               JOIN sys.columns AS c
                  ON c.object_id = fi.object_id
                     AND c.column_id = fi.column_id
      WHERE    fi.object_id = @ObjectID
      ORDER BY fi.column_id;
-- Script unique key index
      SELECT   @SQL = @SQL + @COLS + ') ' + @NL + 'KEY INDEX ' + QUOTENAME(i.name) + @NL + 'ON ' + QUOTENAME(@Catalog) + @NL + 'WITH CHANGE_TRACKING ' + fi.change_tracking_state_desc + @NL + 'GO' + @NL
      FROM     sys.indexes AS i
               JOIN sys.fulltext_indexes AS fi
                  ON i.object_id = fi.object_id
      WHERE    i.object_id = @ObjectID
               AND i.index_id = @IndexID;
-- Output script SQL
      PRINT @SQL;
   END;
END;