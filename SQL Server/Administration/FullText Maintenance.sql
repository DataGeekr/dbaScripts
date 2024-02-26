
```

-- Get base table names, FTCatalogNames and change tracking type
SELECT t.name AS [TableName], c.name AS [FTCatalogName], c.fulltext_catalog_id, 
       i.change_tracking_state_desc
FROM sys.tables AS t 
INNER JOIN sys.fulltext_indexes AS i 
ON t.object_id = i.object_id 
INNER JOIN sys.fulltext_catalogs AS c 
ON i.fulltext_catalog_id = c.fulltext_catalog_id;

-- Get all the non-system stoplists
SELECT stoplist_id, name 
FROM sys.fulltext_stoplists;

-- Create a stoplist from the system stoplist
CREATE FULLTEXT STOPLIST NewsGatorSL 
FROM SYSTEM STOPLIST; 

-- Look for a term in the stoplist
SELECT stoplist_id, stopword, [language], language_id 
FROM sys.fulltext_stopwords 
WHERE stopword = 're'

-- Drop a stoplist
DROP FULLTEXT STOPLIST TestSL;

-- Drop a term from a stoplist
ALTER FULLTEXT STOPLIST NewsGatorSL 
DROP 're' LANGUAGE 1033; 

-- Change the stoplist for a fulltext index
ALTER FULLTEXT INDEX ON CurrentPostFullTextMonday  -- This is base table name
SET STOPLIST NewsGatorSL

-- Repopulate FT Index after changing stoplist
ALTER FULLTEXT INDEX ON dbo.CurrentPostFullTextMonday START UPDATE POPULATION
GO

-- Get document counts for a display term
SELECT display_term, column_id, document_count 
FROM sys.dm_fts_index_keywords(DB_ID('ngfulltext1'), OBJECT_ID('CurrentPostFullTextMonday'))
WHERE display_term = 'Re'
```
