-- Check SQL logs on each server. In the event of a critical error, notify the DBA group and come to an agreement on how to resolve the problem.
-- Check Application log on each server. In the event of a critical or unusual error, notify the DBA group and the networking group to determine what needs to be done to fix the error.

DECLARE @FileNumber INT /* 0 - Recent */
DECLARE @LogType INT /* 1 - ErrorLog / 2 - AgentLog */
DECLARE @SearchStr1 NVARCHAR(50) /* String para pesquisa */
DECLARE @SearchStr2 NVARCHAR(50) /* String para pesquisa */
DECLARE @SrchDateSt DATETIME /* Pesquisa por data - Inicio */
DECLARE @SrchDateFn DATETIME /* Pesquisa por data - Final */

-- Definição de Parametros
SET @FileNumber     = 0
SET @LogType        = 1
SET @SearchStr1     = NULL
SET @SearchStr2     = NULL
SELECT @SrchDateSt = DATEADD(day , DATEDIFF (day, 0, GETDATE() -1), 0)
SELECT @SrchDateFn = GETDATE()

IF ( SELECT OBJECT_ID ('tempdb..#ErrorLog') ) IS NOT NULL
BEGIN
     DROP TABLE #ErrorLog      
END

CREATE TABLE #ErrorLog
(
  LogDate     DATETIME
, ProcessInfo VARCHAR(100)
, TextMsg      VARCHAR(MAX)
)

INSERT INTO #ErrorLog (LogDate, ProcessInfo, TextMsg)
     EXEC sys .xp_readerrorlog @FileNumber
                            , @LogType
                            , @SearchStr1
                            , @SearchStr2
                            , @SrchDateSt
                            , @SrchDateFn

SELECT LogDate
     , Summary = CASE WHEN TextMsg LIKE 'DBCC CHECKDB%'
                      THEN 'CHECKDB [' + SUBSTRING(TextMsg , 15, CHARINDEX(')', TextMsg, 1 ) - 15) + '] - '
                         + SUBSTRING (TextMsg, PATINDEX('%found%', TextMsg) + 5, 3) + ' errors and ' + SUBSTRING(TextMsg , PATINDEX ('%repaired%', TextMsg) + 8 , 3) + ' repairs'
                      WHEN TextMsg LIKE '%BackupIoRequest%'
                      THEN 'BACKUP Failed .. Low Disk Space'
                      ELSE ''
                 END
     , ProcessInfo
     , TextMsg
FROM #ErrorLog
WHERE TextMsg NOT LIKE 'DBCC TRACEON 3604%'
AND   TextMsg NOT LIKE 'DBCC TRACEON 3213%'
ORDER BY LogDate

IF ( SELECT OBJECT_ID ('tempdb..#ErrorLog') ) IS NOT NULL
BEGIN
     DROP TABLE #ErrorLog      
END
  