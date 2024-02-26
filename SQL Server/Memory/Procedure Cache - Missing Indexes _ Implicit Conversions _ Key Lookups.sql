/*
-- Missing Indexes
*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan' )
SELECT dec .usecounts
     , dec .refcounts
     , dec .objtype
     , dec .cacheobjtype
     , des .dbid
     , des .text, deq.query_plan
FROM sys .dm_exec_cached_plans AS dec
     CROSS APPLY sys. dm_exec_sql_text(dec .plan_handle) AS des
     CROSS APPLY sys. dm_exec_query_plan(dec .plan_handle) AS deq
WHERE deq.query_plan. exist(N'/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes/MissingIndexGroup' ) <> 0
ORDER BY dec. usecounts DESC


/*
-- Implicit conversions
*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan' )
SELECT cp. query_hash
     , cp. query_plan_hash
     , ConvertIssue = operators.value ('@ConvertIssue','nvarchar(250)' )
     , Expression = operators.value ('@Expression','nvarchar(250)' )
     , qp. query_plan
FROM sys .dm_exec_query_stats cp
     CROSS APPLY sys. dm_exec_query_plan(cp .plan_handle) qp
     CROSS APPLY query_plan.nodes ('//Warnings/PlanAffectingConvert') rel(operators)


/*
-- Key Lookup
*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan' )
SELECT n. value('(@StatementText)[1]' , 'VARCHAR(4000)' ) AS sql_text
     , n. query('.' )
     , i. value('(@PhysicalOp)[1]' , 'VARCHAR(128)' ) AS PhysicalOp
     , i. value('(./IndexScan/Object/@Database)[1]' , 'VARCHAR(128)' ) AS DatabaseName
     , i. value('(./IndexScan/Object/@Schema)[1]' , 'VARCHAR(128)' ) AS SchemaName
     , i. value('(./IndexScan/Object/@Table)[1]' , 'VARCHAR(128)' ) AS TableName
     , i. value('(./IndexScan/Object/@Index)[1]' , 'VARCHAR(128)' ) as IndexName
     , i. query('.' )
     , STUFF ((SELECT DISTINCT ', ' + cg .value( '(@Column)[1]', 'VARCHAR(128)')
              FROM i. nodes('./OutputList/ColumnReference' ) AS t(cg )
              FOR  XML PATH( '')),1 ,2, '') AS output_columns
     , STUFF ((SELECT DISTINCT ', ' + cg .value( '(@Column)[1]', 'VARCHAR(128)')
              FROM i.nodes( './IndexScan/SeekPredicates/SeekPredicateNew//ColumnReference' ) AS t(cg )
              FOR  XML PATH( '')),1 ,2, '') AS seek_columns
     , i. value('(./IndexScan/Predicate/ScalarOperator/@ScalarString)[1]' , 'VARCHAR(4000)') as Predicate
     , cp. usecounts
     , query_plan
FROM (  SELECT plan_handle, query_plan
        FROM (
             SELECT DISTINCT plan_handle
             FROM sys .dm_exec_query_stats WITH(NOLOCK )
             ) AS qs
        OUTER APPLY sys. dm_exec_query_plan(qs .plan_handle) tp
      ) AS tab ( plan_handle, query_plan )
      INNER JOIN sys. dm_exec_cached_plans AS cp
           ON tab. plan_handle = cp .plan_handle
      CROSS APPLY query_plan.nodes( '/ShowPlanXML/BatchSequence/Batch/Statements/*' ) AS q(n )
      CROSS APPLY n.nodes ('.//RelOp[IndexScan[@Lookup="1"] and IndexScan/Object[@Schema!="[sys]"]]') as s (i)
OPTION(RECOMPILE , MAXDOP 1);