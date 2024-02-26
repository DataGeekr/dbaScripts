Para verificação de erros no Service Broker… 
PS C:\Program Files\Microsoft SQL Server\110\Tools\Binn> .\SSBDiagnose.exe -E -S "DRACO" -d "MonitorDBA" CONFIGURATION FROM SERVICE http://schemas.microsoft.com/SQL/Notifications/EventNotificationService  TO SERVICE Deadlock_BrokerService ON CONTRACT http://schemas.microsoft.com/SQL/Notifications/PostEventNotification

Para verificação de existência de master key...
sys.symetric_keys 

Para criação da chave...
CREATE MASTER KEY ENCRYPTION BY PASSWORD = `strong password’;

Fila de transmissão
SELECT * FROM sys.transmission_queue;

Verificação de mensagens nas filas
SELECT queues.Name
,      parti.Rows
 FROM sys.objects AS SysObj
INNER JOIN sys.partitions AS parti 
       ON parti.object_id = SysObj.object_id
 INNER JOIN sys.objects AS queues
       ON SysObj.parent_object_id = queues.object_id
 WHERE parti.index_id = 1
GO
