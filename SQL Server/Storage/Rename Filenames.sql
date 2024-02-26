
USE [MonitorDBA];
GO
-- ##
-- Recupera as informações dos arquivos do banco de dados
-- ##
SELECT DB_NAME ()
     , logical_name = name
     , physical_name
FROM sys .master_files
WHERE database_id = DB_ID( DB_NAME())

-- ##
-- Altera os arquivos físicos do banco de dados
-- ##
ALTER DATABASE [MonitorDBA] MODIFY FILE (NAME = 'MonitorDBA_Data' , FILENAME = 'D:\SQLServer\Data\dbaMonitor_Data01.MDF' );
ALTER DATABASE [MonitorDBA] MODIFY FILE (NAME = 'MonitorDBA_Log' , FILENAME = 'E:\SQLServer\Log\dbaMonitor_Log01.LDF' );
GO
-- ##
-- Altera os arquivos lógicos do banco de dados
-- ##
ALTER DATABASE [MonitorDBA] MODIFY FILE (NAME = MonitorDBA_Data, NEWNAME = dbaMonitor_Data01);
ALTER DATABASE [MonitorDBA] MODIFY FILE (NAME = MonitorDBA_Log, NEWNAME = dbaMonitor_Log01);
GO
USE master ;
GO
ALTER DATABASE MonitorDBA SET OFFLINE WITH ROLLBACK IMMEDIATE;
GO
-- ##
-- Change physical filename
-- ##
ALTER DATABASE MonitorDBA SET ONLINE
GO

ALTER DATABASE MonitorDBA SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
EXEC master ..sp_renamedb 'MonitorDBA','dbaMonitor'
GO
ALTER DATABASE dbaMonitor SET MULTI_USER
GO
  