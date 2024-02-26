/* Criação da tabela */ 

USE [MonitorDBA]
GO

IF EXISTS ( SELECT 1
            FROM INFORMATION_SCHEMA .TABLES
            WHERE TABLE_NAME = 'DatabaseGrowth'
          )
BEGIN
   DROP TABLE dbo. DatabaseGrowth;
END
 
CREATE TABLE [dbo].[DatabaseGrowth]
(
  [ServerName]       VARCHAR(100 )
, [DatabaseName]     VARCHAR(100)
, [LogicalName]      SYSNAME NOT NULL
, [PollDate]         SMALLDATETIME
, [FileType]         VARCHAR(4)
, [FileSizeMB]       INT NULL
, [FreeSpaceMB]      INT NULL
, [FreeSpacePct]     VARCHAR(8) NULL
, [PhysicalName]     NVARCHAR(520) NULL
, [Status]           SYSNAME NOT NULL
, [Updateability]    SYSNAME NOT NULL
, [RecoveryMode]     SYSNAME NOT NULL
, CONSTRAINT [PK_DatabaseGrowth] PRIMARY KEY CLUSTERED
(
  [ServerName]   ASC
, [DatabaseName] ASC
, [LogicalName]  ASC
, [PollDate]     ASC
) WITH (PAD_INDEX  = OFF , STATISTICS_NORECOMPUTE   = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON ) ON [PRIMARY]
) ON [PRIMARY]
