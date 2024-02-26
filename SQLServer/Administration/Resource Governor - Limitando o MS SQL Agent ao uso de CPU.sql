/*
Limitando o MS SQL Agent ao uso de CPU
*/

/* Configuring the Resource Governor */

-- Criação do Pool com a configuração de uso de CPU
CREATE RESOURCE POOL ResPoolCPUCap_60
WITH (MAX_CPU_PERCENT = 60);

-- Mapeamento de grupo ao Pool
CREATE WORKLOAD GROUP wlGrpCPUCap_60
USING ResPoolCPUCap_60;

-- Função de mapeamento (classificação) do grupo ao(s) usuário(s)
CREATE FUNCTION dbo.fnResGovClassification ()
RETURNS sysname
WITH SCHEMABINDING
AS
BEGIN
     DECLARE @WorkloadGroup AS sysname
    
     -- Se for SQLAgent, move para o grupo CPUCap_60
     IF (SUSER_NAME () = 'CFOAB\OabSQLAgent')
     BEGIN         
          SET @WorkloadGroup = 'wlGrpCPUCap_60'
     END
    
     RETURN @WorkloadGroup
END

-- Registro do função de classificação com o Resource Governor
ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = dbo. fnResGovClassification);

-- Aplica as configurações in-memory
ALTER RESOURCE GOVERNOR RECONFIGURE;

-- Verificação do Pool (Group) para os usuários logados
USE master ;
SELECT sess. session_id, sess .login_name, sess.group_id , grps. name, est .*
FROM sys .dm_exec_sessions AS sess
     INNER JOIN
     sys.dm_resource_governor_workload_groups AS grps
          ON sess. group_id = grps .group_id
     LEFT JOIN
     sys.dm_exec_requests req
          ON sess. session_id = req .session_id
     OUTER APPLY
          sys.dm_exec_sql_text (req .sql_handle) est
WHERE sess. session_id > 50
ORDER BY CASE WHEN sess. login_name LIKE '%Agent%' -- Usuários em Grupos
              THEN 0
              ELSE 1
         END ASC ;
GO