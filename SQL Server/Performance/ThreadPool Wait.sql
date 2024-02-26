ThreadPool Waits ocorrem quando o limite de worker threads do servidor são esgotados, devido ao número de conexões ou locks/blocks que estão travando recursos e colocando novas conexões em espera até a liberação deste recurso.
Esse tipo de wait é específico para o mecanismo de scheduling thread interno do SQL Server.

Fonte: http://www.sqlservercentral.com/blogs/aschenbrenner/2011/10/25/troubleshooting-threadpool-waits/



-- ThreadPool Wait Stat

SELECT max_workers_count -- Quantidade de worker threads configuradas no servidor
FROM sys .dm_os_sys_info


-- Lock/Blocking Scenario
SELECT
resource_associated_entity_id ,
request_mode,
request_status,
request_session_id
FROM sys .dm_tran_locks
WHERE resource_database_id = DB_ID( 'ThreadPoolWaits')
AND resource_type = 'OBJECT'

-- Requisições que estão em espera
SELECT
r.command ,
e.text ,
r.plan_handle ,
r.wait_type ,
r.wait_resource ,
r.wait_time ,
r.session_id ,
r.blocking_session_id
FROM sys .dm_exec_requests r
     INNER JOIN sys. dm_exec_sessions s
            ON r. session_id = s .session_id
     CROSS APPLY sys. dm_exec_sql_text(r .sql_handle) e
WHERE s. is_user_process = 1
GO

-- Requisições pendentes que ainda não conseguiram Worker threads disponíveis
SELECT *
FROM sys .dm_os_waiting_tasks
WHERE wait_type = 'THREADPOOL'

  