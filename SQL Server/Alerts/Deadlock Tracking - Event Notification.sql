Esta rotina irá criar todos os objetos necessários para utilizar o Service Broker para capturar Event Notifications (do SQL Trace) de deadlocks. Com isso, as informações serão registradas em uma tabela no banco de dados administrativo e posteriormente enviados por e-mail para o DBA.



USE MonitorDBA
GO
ALTER DATABASE MonitorDBA SET TRUSTWORTHY ON;
GO

-- Criação da tabela de deadlocks
CREATE TABLE dbo.Deadlocks
( RowId             INT IDENTITY(1,1) 
, DeadlockGraph     XML
, VictimPlan        XML
, ContributionPlan  XML
, CaptureDate       DATETIME DEFAULT(GETDATE())
, CONSTRAINT PK_Deadlocks PRIMARY KEY (RowId)
);
GO

-- Procedure que irá escrever o evento do deadlock na tabela e enviar o e-mail 
CREATE PROCEDURE dbo.spu_EventBrokerDeadlock 
WITH EXECUTE AS OWNER
AS
BEGIN   

   SET NOCOUNT ON

   DECLARE @Error             INT   
         , @RowCount          INT   
         , @TranCount         INT   
         , @ErrorState        INT   
         , @ErrorSeverity     INT   
         , @ErrorProcedure    VARCHAR(256)   
         , @ErrorMsg          VARCHAR(MAX);

   DECLARE @MessageBody       XML
         , @DialogId          UNIQUEIDENTIFIER
			, @Victim            VARCHAR(50)
	      , @DeadlockInfo      XML
			, @VictimPlan        XML 
			, @ContributionPlan  XML
         , @MailBody          NVARCHAR(MAX)
         , @EmailProfile      VARCHAR(256)
         , @Subject           VARCHAR(100)
         , @Recipients        VARCHAR(MAX);

   WHILE ( 1 = 1 )
   BEGIN

      BEGIN TRANSACTION 
       
      BEGIN TRY;        

         -- Recebe a próxima mensagem disponível existente na fila
         WAITFOR( RECEIVE TOP ( 1 ) -- trata somente 1 mensagem por vez
                          @MessageBody = CONVERT( XML, CONVERT(NVARCHAR (MAX), message_body))
                        , @DialogId    = conversation_handle
                  FROM dbo.Deadlock_BrokerQueue
                ), TIMEOUT 1000; -- Se a fila estiver vazia por mais de um segundo, desiste ..
            
         -- Não recebeu nada, vaza..
         IF (@@ROWCOUNT = 0)
		   BEGIN
            IF (@@TRANCOUNT > 0 )
            BEGIN
   			   ROLLBACK TRANSACTION;
            END
		
      	   BREAK;
		   END 

	      -- Estamos tratando de um DEADLOCK_GRAPH?
      	IF (@MessageBody.value('(/EVENT_INSTANCE/EventType)[1]', 'varchar(128)' ) != 'DEADLOCK_GRAPH')
            RETURN;

         -- Recupera os dados e planos de execução dos nós envolvidos no deadlock
         SELECT @DeadlockInfo = @MessageBody.query('/EVENT_INSTANCE/TextData/*');

	      SELECT @Victim = @DeadlockInfo.value('(deadlock-list/deadlock/@victim)[1]', 'varchar(50)')

	      -- Busca o plano de execução do processo vitima
         SELECT @VictimPlan = [query_plan] 
         FROM sys.dm_exec_query_stats qs
         CROSS APPLY sys.dm_exec_query_plan([plan_handle])
         WHERE [sql_handle] = @DeadlockInfo.value('xs:hexBinary(substring((
		                                             deadlock-list/deadlock/process-list/process[@id=sql:variable("@Victim")]/executionStack/frame/@sqlhandle)[1], 
		                                             3))', 'varbinary(max)');

      	-- Busca o plano de execução do processo envolvido
         SELECT @ContributionPlan = [query_plan] 
	      FROM sys.dm_exec_query_stats qs
         CROSS APPLY sys.dm_exec_query_plan([plan_handle])
         WHERE [sql_handle] = @DeadlockInfo.value('xs:hexBinary(substring((
		                                             deadlock-list/deadlock/process-list/process[@id!=sql:variable("@Victim")]/executionStack/frame/@sqlhandle)[1],
                                                   3))', 'varbinary(max)');

         -- Persiste as informações capturadas na tabela de Deadlocks
         INSERT INTO MonitorDBA.dbo.Deadlocks
                   ( DeadlockGraph
                   , VictimPlan
                   , ContributionPlan
                   )
	      VALUES ( @DeadlockInfo, @VictimPlan, @ContributionPlan );


         -- Dispara o e-mail de notificação para o DBA	
         SELECT @MailBody   = 'Notificação de deadlock ...' + CHAR(13) + CHAR(13)
                            + ' >> Segue abaixo o trace registrado para o deadlock ... ' + CHAR(13) + CHAR(13)
                            + CAST(@MessageBody AS NVARCHAR(MAX));
         SELECT @EmailProfile = 'Conselho Federal da OAB';
         SELECT @Subject    = 'Notificação de evento (Deadlock) - Servidor: ' + RTRIM(LTRIM(CONVERT(VARCHAR(50),SERVERPROPERTY('ServerName'))));
         SELECT @Recipients = 'rafael.rodrigues@oab.org.br'
  
         EXEC msdb.dbo.sp_send_dbmail
                       @profile_name = @EmailProfile  
                     , @recipients   = @Recipients  
                     , @subject      = @Subject
                     , @body         = @MailBody
                     , @importance   = 'High';  
      


         IF @@TRANCOUNT > 0 -- Transação feita no escopo da procedure 
         BEGIN
            COMMIT TRANSACTION; 
         END

      END TRY 
      BEGIN CATCH 
         
         IF @@TRANCOUNT > 0 -- Transação feita no escopo da procedure 
         BEGIN
            ROLLBACK TRANSACTION; 
         END
  
         -- Recupera informações originais do erro 
         SELECT @ErrorMsg       = ERROR_MESSAGE() 
              , @ErrorSeverity  = ERROR_SEVERITY() 
              , @ErrorState     = ERROR_STATE() 
              , @ErrorProcedure = ERROR_PROCEDURE(); 
  
         -- Tratamento Para ErrorState, retorna a procedure de execução em junção com o erro. 
         SELECT @ErrorMsg = CASE WHEN @ErrorState = 1 
                                    THEN @ErrorMsg + CHAR(13) + 'Erro ao receber mensagem do Service Broker da fila Deadlock_BrokerQueue em ' + @ErrorProcedure + ' ( ' + LTRIM( RTRIM( STR( ERROR_LINE() ) ) ) + ' )'
                                    WHEN @ErrorState = 3 
                                    THEN @ErrorProcedure + ' - ' + @ErrorMsg 
                                    ELSE @ErrorMsg 
                               END; 
  
         RAISERROR ( @ErrorMsg 
                   , @ErrorSeverity 
                   , @ErrorState ); 
  
      END CATCH 
     
   END
  
END
GO

-- Cria a fila que receberá as mensagens de notificação de evento e adiciona a procedure que irá processar a mensagem
CREATE QUEUE Deadlock_BrokerQueue
    WITH STATUS = ON,
    ACTIVATION (
        PROCEDURE_NAME = spu_EventBrokerDeadlock,
        MAX_QUEUE_READERS = 1,
        EXECUTE AS OWNER );
GO

-- Cria o serviço com uma mensagem pré-definida
CREATE SERVICE Deadlock_BrokerService
    ON QUEUE Deadlock_BrokerQueue ([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]);
                                    
                                    
GO

-- Cria a rota para o serviço
CREATE ROUTE Deadlock_NotificationsRoute
    WITH SERVICE_NAME = 'Deadlock_BrokerService',
    ADDRESS = 'LOCAL';
GO

-- Cria o notificação de evento para o evento DEADLOCK_GRAPH. 
-- outros eventos de lock podem ser adicionados
CREATE EVENT NOTIFICATION DeadLock_NotificationEvent
ON SERVER 
WITH FAN_IN
FOR DEADLOCK_GRAPH --, LOCK_DEADLOCK_CHAIN, LOCK_DEADLOCK
TO SERVICE 'Deadlock_BrokerService', 
            'current database' -- CASE sensitive string that specifies USE OF server broker IN CURRENT db
GO

-- check to see if our event notification has been created ok
SELECT * FROM sys.server_event_notifications WHERE name = 'DeadLock_NotificationEvent';
GO


-- clean up
/*
DROP TABLE Deadlocks
DROP PROCEDURE spu_EventBrokerDeadlock
DROP EVENT NOTIFICATION DeadLock_NotificationEvent ON SERVER 
DROP ROUTE Deadlock_NotificationsRoute
DROP SERVICE Deadlock_BrokerService
DROP QUEUE Deadlock_BrokerQueue
*/
             


            select * from sys.event_notifications
SELECT t1.name AS [Service_Name]
,      t3.name AS [Schema_Name]
,      t2.name AS [Queue_Name]
,      CASE WHEN t4.state IS NULL THEN 'Not available'
                                  ELSE t4.state END AS [Queue_State]
,      CASE WHEN t4.tasks_waiting IS NULL THEN '--'
                                          ELSE CONVERT(VARCHAR, t4.tasks_waiting) END AS tasks_waiting
,      CASE WHEN t4.last_activated_time IS NULL THEN '--'
                                                ELSE CONVERT(varchar, t4.last_activated_time) END AS last_activated_time
,      CASE WHEN t4.last_empty_rowset_time IS NULL THEN '--'
                                                   ELSE CONVERT(varchar,t4.last_empty_rowset_time) END AS last_empty_rowset_time
,      (
SELECT COUNT(*)
FROM sys.transmission_queue t6
WHERE (t6.from_service_name = t1.name) ) AS [Tran_Message_Count]
FROM            sys.services                 t1
INNER JOIN      sys.service_queues           t2 ON ( t1.service_queue_id = t2.object_id )
INNER JOIN      sys.schemas                  t3 ON ( t2.schema_id = t3.schema_id )
LEFT OUTER JOIN sys.dm_broker_queue_monitors t4 ON ( t2.object_id = t4.queue_id AND t4.database_id = DB_ID() )
INNER JOIN      sys.databases                t5 ON ( t5.database_id = DB_ID() )


/*
-- Quantas mensagens em cada fila
SELECT queues.Name
,      parti.Rows
FROM sys.objects AS SysObj
INNER JOIN sys.partitions AS parti  
      ON parti.object_id = SysObj.object_id
INNER JOIN sys.objects AS queues 
      ON SysObj.parent_object_id = queues.object_id
WHERE parti.index_id = 1
GO


select * from sys.transmission_queue
select * from sys.services

select * from sys.conversation_endpoints  where service_id =65551 
declare @h uniqueidentifier = '620DBF84-A3C1-E411-9416-00155D014116'
END CONVERSATION @h WITH CLEANUP
*/


Futuras modificações...

declare @Victim VARCHAR(50) , @DeadlockInfo XML, @Plan varbinary(max), @Info VARCHAR(50)
 
 
SELECT TOP 1 @DeadlockInfo = DeadlockGraph FROM Deadlocks
 
       SELECT @Victim = @DeadlockInfo.value('(deadlock-list/deadlock/@victim)[1]', 'varchar(50)')
          SELECT @Info = @DeadlockInfo.value('(deadlock-list/deadlock/@victim)[1]', 'varchar(50)')
 
;with xmlReport as
(
-- extract informaton about the deadlock VICTIM using XQuery
select
     data.value('(/deadlock-list/deadlock/resource-list/process/@id)[1]', 'varchar(50)')  as [id]
   , data.value('(/deadlock-list/deadlock/process-list/process/@lasttranstarted)[1]', 'datetime')  as [Event Time]
   , data.value('(/deadlock-list/deadlock/resource-list/keylock/@objectname)[1]', 'nvarchar(max)')  as [object]
   , data.value('(/deadlock-list/deadlock/process-list/process/@clientapp)[1]', 'nvarchar(256)')    as [Application]
   , data.value('(/deadlock-list/deadlock/process-list/process/@hostname)[1]', 'nvarchar(256)')    as [Hostname]
   , data.value('(/deadlock-list/deadlock/process-list/process/@loginname)[1]', 'nvarchar(256)')    as [Login]
   , data.value('(/deadlock-list/deadlock/resource-list/keylock/@indexname)[1]', 'nvarchar(256)')  as [Index]
   , data.value('(/deadlock-list/deadlock/process-list/process/@waittime)[1]', 'int')              as [Wait Time (ms)]
   , data.value('(/deadlock-list/deadlock/resource-list/keylock/@mode)[1]', 'char(1)')              as [Lock Mode]
   , data.query('(event/data/value/deadlock)[1]')                                                      as [Deadlock Graph]
from @DeadlockInfo.nodes('/deadlock-list') AS DL(data)
)
select  id,
     [Event Time]
   , parsename(object, 3)    as [Database]
   , parsename(object, 2)    as [Schema]
   , parsename(object, 1)    as [Table]
   , [Application]
   , [Hostname]
   , [Login]
   , [Index]
   , [Wait Time (ms)]
   , [Lock Mode]
   , [Deadlock Graph]
from xmlReport
order by [Event Time] desc;
