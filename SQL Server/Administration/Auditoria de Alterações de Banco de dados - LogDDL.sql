IF NOT EXISTS (
              SELECT 1 FROM sys .databases WHERE name = 'dbaMonitor'
              )
BEGIN
     CREATE DATABASE dbaMonitor
END
GO

USE [dbaMonitor]
GO
/*  Cria a tabela de log de alterações */
CREATE TABLE [dbo].[ObjectChangeLog] ( [EventType] [varchar](250) NULL
                                    , [PostTime] [datetime] NULL
                                    , [ServerName] [varchar](250) NULL
                                    , [LoginName] [varchar](250) NULL
                                    , [UserName] [varchar](250) NULL
                                    , [DatabaseName] [varchar](250) NULL
                                    , [SchemaName] [varchar](250) NULL
                                    , [ObjectName] [varchar](250) NULL
                                    , [ObjectType] [varchar](250) NULL
                                    , [TSQLCommand] [varchar](MAX) NULL
) ON [PRIMARY]
 
GO
                          
-- Habilita Service Broker
IF EXISTS ( SELECT  *
            FROM    sys .databases
            WHERE   name = 'dbaMonitor'
                    AND is_broker_enabled = 0 )
BEGIN
    ALTER DATABASE dbaMonitor SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE;
    PRINT '-- Broker habilitado: dbaMonitor';
END
GO

-- Cria a procedure que irá inserir os dados do evento na tabela DDLEventLog
USE [dbaMonitor]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spu_ObjectChangeLogDDL]
WITH EXECUTE AS OWNER
AS
BEGIN
   DECLARE @MessageBody XML

   WHILE ( 1 = 1 )
   BEGIN

      BEGIN TRANSACTION
      -- Recebe a próxima mensagem disponível existente na fila
         WAITFOR ( RECEIVE TOP ( 1 ) -- trata somente 1 mensagem por vez
                          @MessageBody =  CONVERT ( XML , CONVERT (NVARCHAR (MAX), message_body))
                   FROM dbo. ObjectChangeLogDDL_BrokerQueue ), TIMEOUT 1000  -- se a fila estiver vazia, atualiza e finaliza

      -- Finaliza se nada foi recebido ou alteração realizada pelo Agent
      IF ( @@ROWCOUNT = 0 )
      BEGIN
         ROLLBACK TRANSACTION
         BREAK
      END

      IF (SELECT @MessageBody.value ('(/EVENT_INSTANCE/LoginName)[1]', 'varchar(128)')) != 'CFOAB\OabSQLAgent'
      BEGIN

           -- Processa dados da fila
           INSERT INTO dbo.ObjectChangeLog
                     ( EventType
                     , PostTime
                     , ServerName
                     , LoginName
                     , UserName
                     , DatabaseName
                     , SchemaName
                     , ObjectName
                     , ObjectType
                     , TSQLCommand
                     )
              SELECT @MessageBody .value( '(/EVENT_INSTANCE/EventType)[1]', 'varchar(128)') AS EventType
                   , CONVERT (DATETIME , @MessageBody.value ('(/EVENT_INSTANCE/PostTime)[1]', 'varchar(128)')) AS PostTime
                   , @MessageBody .value( '(/EVENT_INSTANCE/ServerName)[1]', 'varchar(128)') AS ServerName
                   , @MessageBody .value( '(/EVENT_INSTANCE/LoginName)[1]', 'varchar(128)') AS LoginName
                   , @MessageBody .value( '(/EVENT_INSTANCE/UserName)[1]', 'varchar(128)') AS UserName
                   , @MessageBody .value( '(/EVENT_INSTANCE/DatabaseName)[1]' , 'varchar(128)') AS DatabaseName
                   , @MessageBody .value( '(/EVENT_INSTANCE/SchemaName)[1]', 'varchar(128)') AS SchemaName
                   , @MessageBody .value( '(/EVENT_INSTANCE/ObjectName)[1]', 'varchar(128)') AS ObjectName
                   , @MessageBody .value( '(/EVENT_INSTANCE/ObjectType)[1]', 'varchar(128)') AS ObjectType
                   , @MessageBody .value( '(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]' , 'nvarchar(max)') AS TSQLCommand
         
     END

      COMMIT TRANSACTION
   END
END
  



-- Cria a fila que receberá as mensagens
CREATE QUEUE [ObjectChangeLogDDL_BrokerQueue]
WITH ACTIVATION -- Procedimento de ativação
( STATUS = ON
, PROCEDURE_NAME = dbaMonitor.dbo .spu_ObjectChangeLogDDL
, MAX_QUEUE_READERS = 2 -- máx. execuções concorrentes da procedure
, EXECUTE AS OWNER
) -- conta que executará o procedimento
GO

-- Cria o serviço
CREATE SERVICE [ObjectChangeLogDDL_BrokerService]
AUTHORIZATION dbo
ON QUEUE [dbo].[ObjectChangeLogDDL_BrokerQueue] ([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification])
GO

 
/*************** TARGET DATABASE *********************/
-- Habilita service broker no database de usuários
IF EXISTS ( SELECT  name, is_broker_enabled
            FROM    sys .databases
            WHERE  name = 'Geral'
                    AND is_broker_enabled = 0 )
    ALTER DATABASE Geral SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE;
GO
--
USE Geral
GO
-- Cria notificação de evento
IF EXISTS (
          SELECT 1
          FROM sys .event_notifications
          WHERE name = 'ObjectChangeLog_QueueDatabaseNotifier'
          )
BEGIN
     DROP EVENT NOTIFICATION [ObjectChangeLog_QueueDatabaseNotifier] ON DATABASE
END
GO
CREATE EVENT NOTIFICATION [ObjectChangeLog_QueueDatabaseNotifier]
ON DATABASE
   FOR --DDL_DATABASE_LEVEL_EVENTS, -- descomentar para buscar todos os eventos relacionados ao database
       CREATE_TABLE
     , ALTER_TABLE
     , DROP_TABLE
     , CREATE_VIEW
     , ALTER_VIEW
     , DROP_VIEW
     , CREATE_FUNCTION
     , ALTER_FUNCTION
     , DROP_FUNCTION
     , CREATE_PROCEDURE
     , ALTER_PROCEDURE
     , DROP_PROCEDURE
     , CREATE_TRIGGER
     , ALTER_TRIGGER
     , DROP_TRIGGER
     , CREATE_SCHEMA
     , ALTER_SCHEMA
     , DROP_SCHEMA
     , CREATE_USER
     , ALTER_USER
     , DROP_USER
     , CREATE_ROLE
     , ALTER_ROLE
     , DROP_ROLE
     , DROP_DEFAULT
    TO SERVICE 'ObjectChangeLogDDL_BrokerService'
             , 'D8531B79-9759-4F17-8D3D-336965B5CD7B' -- Service_broker_guid do banco de dados dbaMonitor
    -- SELECT name, service_broker_guid FROM sys.databases WHERE name = 'dbaMonitor'
GO

SELECT * FROM master.sys .event_notification_event_types


 
SELECT  name, is_broker_enabled
FROM    sys .databases
WHERE  is_broker_enabled = 1