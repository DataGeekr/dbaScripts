/***********   
#  
#  Tables - BlockingHistory  
#  
***********/


USE [dbMonitorDBA];
GO

IF NOT EXISTS
(
    SELECT 1
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo'
          AND TABLE_NAME = 'BlockingHistory'
)
BEGIN
    CREATE TABLE [dbMonitorDBA].[dbo].[BlockingHistory]
    (
        [BlockingHistoryID] INT IDENTITY(1, 1) NOT NULL
            CONSTRAINT PK_BlockingHistory
            PRIMARY KEY CLUSTERED ([BlockingHistoryID]),
        [DateStamp] DATETIME NOT NULL
            CONSTRAINT [DF_BlockingHistory_DateStamp]
                DEFAULT (GETDATE()),
        Blocked_SPID SMALLINT NOT NULL,
        Blocking_SPID SMALLINT NOT NULL,
        Blocked_Login NVARCHAR(128) NOT NULL,
        Blocked_HostName NVARCHAR(128) NOT NULL,
        Blocked_WaitTime_Seconds NUMERIC(12, 2) NULL,
        Blocked_LastWaitType NVARCHAR(32) NOT NULL,
        Blocked_Status NVARCHAR(30) NOT NULL,
        Blocked_Program NVARCHAR(128) NOT NULL,
        Blocked_SQL_Text NVARCHAR(MAX) NULL,
        Offending_SPID SMALLINT NOT NULL,
        Offending_Login NVARCHAR(128) NOT NULL,
        Offending_NTUser NVARCHAR(128) NOT NULL,
        Offending_HostName NVARCHAR(128) NOT NULL,
        Offending_WaitType BIGINT NOT NULL,
        Offending_LastWaitType NVARCHAR(32) NOT NULL,
        Offending_Status NVARCHAR(30) NOT NULL,
        Offending_Program NVARCHAR(128) NOT NULL,
        Offending_SQL_Text NVARCHAR(MAX) NULL,
        [DatabaseName] NVARCHAR(128) NULL
    );
END;
GO



/***********   
#  
#  Triggers - ti_blockinghistory  
#  
***********/


USE [dbMonitorDBA];
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.triggers
    WHERE [name] = 'ti_blockinghistory'
)
BEGIN
    EXEC ('CREATE TRIGGER ti_blockinghistory   
              ON BlockingHistory   
          INSTEAD OF INSERT AS SELECT 1');
END;
GO

ALTER TRIGGER [dbo].[ti_blockinghistory]
ON [dbo].[BlockingHistory]
AFTER INSERT
AS
BEGIN

    /******************************************************************************  
**  
**  Name.........: ti_blockinghistory  
**  
**  Descrição....: Gera histórico de bloqueios  
**  
**  
**  Observações..:  
**  
**  Autor........: Rafael Rodrigues  
**  Data.........: 25/04/2013  
*******************************************************************************  
**  Histórico de Alterações  
*******************************************************************************  
**  Data:    Autor:        Descrição:                                    Versão  
**  -------- ------------- --------------------------------------------- ------  
**  
******************************************************************************/

    DECLARE @c_HtmlCode NVARCHAR(MAX),
            @n_QueryValue INT,
            @n_QueryValue2 INT,
            @c_EmailList NVARCHAR(255),
            @c_CelList NVARCHAR(255),
            @c_ServerName NVARCHAR(50),
            @c_EmailSubject NVARCHAR(100);

    SELECT @c_ServerName = CONVERT(NVARCHAR(50), SERVERPROPERTY('servername'));

    SELECT @n_QueryValue = QueryValue,
           @n_QueryValue2 = QueryValue2,
           @c_EmailList = EmailList,
           @c_CelList = CellList
    FROM [dbMonitorDBA].dbo.AlertSettings
    WHERE Name = 'BlockingAlert';

    SELECT *
    INTO #Inserted
    FROM Inserted;

    IF EXISTS
    (
        SELECT 1
        FROM #Inserted
        WHERE CAST(Blocked_WaitTime_Seconds AS DECIMAL) > @n_QueryValue
    )
    BEGIN

        SET @c_HtmlCode
            = N'<html><head><style type="text/css">  
      table { border: 0px; border-spacing: 0px; border-collapse: collapse;}  
      th {color:#FFFFFF; font-size:12px; font-family:arial; background-color:#7394B0; font-weight:bold;border: 0;}  
      th.header {color:#FFFFFF; font-size:13px; font-family:arial; background-color:#41627E; font-weight:bold;border: 0;}  
      td {font-size:11px; font-family:arial;border-right: 0;border-bottom: 1px solid #C1DAD7;padding: 5px 5px 5px 8px;}  
      </style></head><body>  
      <table width="1150"> <tr><th class="header" width="1150">Recent Blocking</th></tr></table>  
      <table width="1150">  
      <tr>   
      <th width="150">Date Stamp</th>   
      <th width="150">Database</th>   
      <th width="60">Time(ss)</th>   
      <th width="60">Victim SPID</th>  
      <th width="145">Victim Login</th>  
      <th width="190">Victim SQL Text</th>   
      <th width="60">Blocking SPID</th>   
  
      <th width="145">Blocking Login</th>  
      <th width="190">Blocking SQL Text</th>   
      </tr>';

        SELECT @c_HtmlCode
            = @c_HtmlCode + N'<tr>  
      <td width="150" bgcolor="#E0E0E0">' + CAST(DateStamp AS NVARCHAR)
              + N'</td>  
      <td width="130" bgcolor="#F0F0F0">' + [DatabaseName] + N'</td>  
      <td width="60" bgcolor="#E0E0E0">' + CAST(Blocked_WaitTime_Seconds AS NVARCHAR)
              + N'</td>  
      <td width="60" bgcolor="#F0F0F0">' + CAST(Blocked_SPID AS NVARCHAR)
              + N'</td>  
      <td width="145" bgcolor="#E0E0E0">' + Blocked_Login + N'</td>   
      <td width="200" bgcolor="#F0F0F0">'
              + REPLACE(REPLACE(REPLACE(LEFT(Blocked_SQL_Text, 100), 'CREATE', ''), 'TRIGGER', ''), 'PROCEDURE', '')
              + N'</td>  
      <td width="60" bgcolor="#E0E0E0">' + CAST(Blocking_SPID AS NVARCHAR)
              + N'</td>  
      <td width="145" bgcolor="#F0F0F0">' + Offending_Login + N'</td>  
      <td width="200" bgcolor="#E0E0E0">'
              + REPLACE(REPLACE(REPLACE(LEFT(Offending_SQL_Text, 100), 'CREATE', ''), 'TRIGGER', ''), 'PROCEDURE', '')
              + N'</td>   
      </tr>'
        FROM #Inserted
        WHERE CAST(Blocked_WaitTime_Seconds AS DECIMAL) > @n_QueryValue;

        SELECT @c_HtmlCode = @c_HtmlCode + N'</table></body></html>';

        SELECT @c_EmailSubject = N'Blocked Process [' + @c_ServerName + N']';

        EXEC msdb.dbo.sp_send_dbmail @recipients = @c_EmailList,
                                     @subject = @c_EmailSubject,
                                     @body = @c_HtmlCode,
                                     @body_format = 'HTML';

    END;

    IF @c_CelList IS NOT NULL
    BEGIN

        SELECT @c_EmailSubject = N'Blocking - ' + @c_ServerName;

        IF @n_QueryValue2 IS NOT NULL
        BEGIN

            IF EXISTS
            (
                SELECT 1
                FROM #Inserted
                WHERE CAST(Blocked_WaitTime_Seconds AS DECIMAL) > @n_QueryValue2
            )
            BEGIN

                SET @c_HtmlCode
                    = N'<html><head></head><body><table><tr><td>BlockingSPID,</td><td>Login,</td><td>Time</td></tr>';

                SELECT @c_HtmlCode
                    = @c_HtmlCode + N'<tr><td>' + CAST(Offending_SPID AS NVARCHAR) + N',</td><td>'
                      + LEFT(Offending_Login, 7) + N',</td><td>' + CAST(Blocked_WaitTime_Seconds AS NVARCHAR)
                      + N'</td></tr>'
                FROM #Inserted
                WHERE Blocked_WaitTime_Seconds > @n_QueryValue2;

                SELECT @c_HtmlCode = @c_HtmlCode + N'</table></body></html>';

                EXEC msdb.dbo.sp_send_dbmail @recipients = @c_CelList,
                                             @subject = @c_EmailSubject,
                                             @body = @c_HtmlCode,
                                             @body_format = 'HTML';

            END;

        END;

    END;

    IF @n_QueryValue2 IS NULL
       AND @c_CelList IS NOT NULL
    BEGIN
        /*TEXT MESSAGE*/
        SET @c_HtmlCode
            = N'<html><head></head><body><table><tr><td>BlockingSPID,</td><td>Login,</td><td>Time</td></tr>';

        SELECT @c_HtmlCode
            = @c_HtmlCode + N'<tr><td>' + CAST(Offending_SPID AS NVARCHAR) + N',</td><td>' + LEFT(Offending_Login, 7)
              + N',</td><td>' + CAST(Blocked_WaitTime_Seconds AS NVARCHAR) + N'</td></tr>'
        FROM #Inserted
        WHERE Blocked_WaitTime_Seconds > @n_QueryValue;

        SELECT @c_HtmlCode = @c_HtmlCode + N'</table></body></html>';


        EXEC msdb.dbo.sp_send_dbmail @recipients = @c_CelList,
                                     @subject = @c_EmailSubject,
                                     @body = @c_HtmlCode,
                                     @body_format = 'HTML';
    END;


    DROP TABLE #Inserted;
END;
GO

/***********   
#  
#  Procedures - usp_CheckBlocking  
#  
***********/

USE [dbMonitorDBA];
GO

IF NOT EXISTS
(
    SELECT 1
    FROM INFORMATION_SCHEMA.ROUTINES
    WHERE ROUTINE_NAME = 'usp_CheckBlocking'
          AND ROUTINE_SCHEMA = 'dbo'
          AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
    EXEC ('CREATE PROC dbo.usp_CheckBlocking AS SELECT 1');
END;
GO

ALTER PROCEDURE [dbo].[usp_CheckBlocking]
AS
BEGIN
    /******************************************************************************  
**  
**  Name.........: usp_CheckBlocking  
**  
**  Descrição....:   
**  
**  
**  Observações..:  
**  
**  Autor........: Rafael Rodrigues  
**  Data.........: 25/04/2013  
*******************************************************************************  
**  Histórico de Alterações  
*******************************************************************************  
**  Data:    Autor:        Descrição:                                    Versão  
**  -------- ------------- --------------------------------------------- ------  
**  
******************************************************************************/

    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM master..sysprocesses
        WHERE spid > 50
              AND blocked != 0
              AND ((CAST(waittime AS DECIMAL) / 1000) > 0)
    )
    BEGIN

        INSERT INTO [dbMonitorDBA].dbo.BlockingHistory
        (
            Blocked_SPID,
            Blocking_SPID,
            Blocked_Login,
            Blocked_HostName,
            Blocked_WaitTime_Seconds,
            Blocked_LastWaitType,
            Blocked_Status,
            Blocked_Program,
            Blocked_SQL_Text,
            Offending_SPID,
            Offending_Login,
            Offending_NTUser,
            Offending_HostName,
            Offending_WaitType,
            Offending_LastWaitType,
            Offending_Status,
            Offending_Program,
            Offending_SQL_Text,
            [DatabaseName]
        )
        SELECT a.spid AS Blocked_SPID,
               a.blocked AS Blocking_SPID,
               a.loginame AS Blocked_Login,
               a.hostname AS Blocked_HostName,
               (CAST(a.waittime AS DECIMAL) / 1000) AS Blocked_WaitTime_Seconds,
               a.lastwaittype AS Blocked_LastWaitType,
               a.[status] AS Blocked_Status,
               a.[program_name] AS Blocked_Program,
               CAST(st1.[text] AS NVARCHAR(MAX)) AS Blocked_SQL_Text,
               b.spid AS Offending_SPID,
               b.loginame AS Offending_Login,
               b.nt_username AS Offending_NTUser,
               b.hostname AS Offending_HostName,
               b.waittime AS Offending_WaitType,
               b.lastwaittype AS Offending_LastWaitType,
               b.[status] AS Offending_Status,
               b.[program_name] AS Offending_Program,
               CAST(st2.text AS NVARCHAR(MAX)) AS Offending_SQL_Text,
               (
                   SELECT name FROM master..sysdatabases WHERE [dbid] = a.[dbid]
               ) AS [DatabaseName]
        FROM master..sysprocesses AS a
            CROSS APPLY sys.dm_exec_sql_text(a.sql_handle) AS st1
            INNER JOIN master..sysprocesses AS b
                CROSS APPLY sys.dm_exec_sql_text(b.sql_handle) AS st2
                ON a.blocked = b.spid
        WHERE a.spid > 50
              AND a.blocked != 0
              AND ((CAST(a.waittime AS DECIMAL) / 1000) > 0);


    END;
END;
GO




/*********** /  
#  
#  Report Procedures - usp_rpt_Blocking  
#  
***********/


USE [dbMonitorDBA];
GO


IF NOT EXISTS
(
    SELECT 1
    FROM INFORMATION_SCHEMA.ROUTINES
    WHERE ROUTINE_NAME = 'usp_rpt_Blocking'
          AND ROUTINE_SCHEMA = 'dbo'
          AND ROUTINE_TYPE = 'PROCEDURE'
)
BEGIN
    EXEC ('CREATE PROC dbo.usp_rpt_Blocking AS SELECT 1');
END;
GO


ALTER PROC dbo.usp_rpt_Blocking
(@DateRangeInDays INT)
AS
BEGIN


    /******************************************************************************  
**  
**  Name.........: usp_rpt_Blocking  
**  
**  Descrição....:   
**  
**  
**  Observações..:  
**  
**  Autor........: Rafael Rodrigues  
**  Data.........: 29/04/2013  
*******************************************************************************  
**  Histórico de Alterações  
*******************************************************************************  
**  Data:    Autor:        Descrição:                                    Versão  
**  -------- ------------- --------------------------------------------- ------  
**  
******************************************************************************/

    SET NOCOUNT ON;

    SELECT DateStamp,
           [DatabaseName],
           Blocked_WaitTime_Seconds AS [ElapsedTime(ss)],
           Blocked_SPID AS VictimSPID,
           Blocked_Login AS VictimLogin,
           Blocked_SQL_Text AS Victim_SQL,
           Blocking_SPID AS BlockerSPID,
           Offending_Login AS BlockerLogin,
           Offending_SQL_Text AS Blocker_SQL
    FROM [dbMonitorDBA].dbo.BlockingHistory (NOLOCK)
    WHERE (DATEDIFF(dd, DateStamp, GETDATE())) <= @DateRangeInDays
    ORDER BY DateStamp DESC;

END;
GO
? ?;