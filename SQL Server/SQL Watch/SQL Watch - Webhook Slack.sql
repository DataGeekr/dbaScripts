
```
USE dbaSQLWatch 
GO 
-- Add Action 
DECLARE @WebHookAPIUrl VARCHAR(MAX) 
-- Edebe 
SET @WebHookAPIUrl = 'https://hooks.slack.com/services/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' 
-- RSB 
SET IDENTITY_INSERT dbo.sqlwatch_config_action ON; 
 INSERT INTO [dbo].[sqlwatch_config_action] ( 
	action_id, action_description, action_exec_type, action_exec, action_enabled 
	) 
  VALUES ( 2, 
	'Send Slack via Webhook', 
	'PowerShell', 
	'$webhookurl = "https://hooks.slack.com/services/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"  
Invoke-RestMethod ` 
    -Uri $webhookurl ` 
    -Method Post ` 
    -Body ''{"text":"{BODY}", "title":"{SUBJECT}"}'' ` 
    -ContentType ''application/json''', 
	1 
	) 
SET IDENTITY_INSERT dbo.sqlwatch_config_action OFF; 
select * from sqlwatch_config_action 
-- Associate Action with Checks 
INSERT INTO [dbo].[sqlwatch_config_check_action]  
          ( 
	 	  [check_id] 
	     , [action_id] 
          , [action_every_failure] 
          , [action_recovery] 
          , [action_repeat_period_minutes] 
          , [action_hourly_limit] 
          , [action_template_id] 
	     ) 
SELECT DISTINCT 
       sqlCheck.check_id 
	, action_id = 2 
     , action_every_failure = CASE WHEN sqlCheck.check_name LIKE '%Backup%' THEN 1 ELSE 0 END 
     , action_recovery = ISNULL(action_recovery, 0) 
     , action_repeat_period_minutes 
     , action_hourly_limit = ISNULL(action_hourly_limit, 60) 
     , action_template_id = -4 --plain text template 
     --, sqlCheck.check_name 
FROM dbo.sqlwatch_config_check sqlCheck 
     LEFT JOIN 
     dbo.sqlwatch_config_check_action sqlCheckAction 
          ON sqlCheckAction.check_id = sqlCheck.check_id 
WHERE ( sqlCheck.base_object_type IN ( 'Job', 'Disk') 
OR      sqlCheck.check_name LIKE '%backup%' 
OR      sqlCheck.check_name LIKE 'Blocked Process' 
OR      sqlCheck.check_name LIKE 'CPU Utilistaion' -- 1104 
OR      sqlCheck.check_name LIKE 'Number of Deadlocks/sec' -- 1117 
OR      sqlCheck.check_name LIKE 'dbachecks failed' -- 1105 
        ) 
AND    sqlCheck.check_name NOT LIKE '%dbatools%' 
AND NOT EXISTS ( SELECT 1  
                 FROM dbo.sqlwatch_config_check_action chac 
                 WHERE chac.check_id = sqlCheck.check_id  
                 AND   chac.action_id = 2) 
                 select * from sqlwatch_config_check 
USE dbaSQLWatch; 
UPDATE dbo.sqlwatch_config_check 
    SET check_threshold_critical = '>60', check_threshold_warning = '>25', check_frequency_minutes = '5', check_enabled = 1, user_modified = 1 
WHERE check_name LIKE '%Log Backup%' 
UPDATE dbo.[sqlwatch_meta_check] 
    SET check_threshold_critical = '>60', check_threshold_warning = '>25', check_frequency_minutes = '5', check_enabled = 1 
WHERE check_name LIKE '%Log Backup%' 
SELECT check_threshold_critical  
     , check_threshold_warning  
     , check_frequency_minutes  
     , check_enabled  
     , * 
FROM [sqlwatch_meta_check] 
WHERE check_name LIKE '%Log Backup%' 
SELECT check_threshold_critical  
     , check_threshold_warning  
     , check_frequency_minutes  
     , check_enabled  
     , user_modified 
     , * 
FROM sqlwatch_config_check 
WHERE check_name LIKE '%Log Backup%' 
UPDATE dbo.sqlwatch_config_check 
    SET check_threshold_critical = '>5', check_enabled = 1 
WHERE check_id = -2 -- Blocked Process 
-- SELECT * FROM dbo.sqlwatch_config_check WHERE check_name LIKE '%Log Backup%' 
SELECT DISTINCT 
       sqlCheck.check_id 
     , sqlCheck.check_name 
     , sqlAct.action_id 
     , sqlAct.action_description 
	, action_id = sqlAct.action_id  
     , action_every_failure = CASE WHEN sqlCheck.check_name LIKE '%Backup%' THEN 1 ELSE 0 END 
     , action_recovery = ISNULL(action_recovery, 0) 
     , action_repeat_period_minutes 
     , action_hourly_limit = ISNULL(action_hourly_limit, 60) 
     , action_template_id = -4 --plain text template 
--     , * 
FROM dbo.sqlwatch_config_check sqlCheck 
     LEFT JOIN 
     dbo.sqlwatch_config_check_action sqlCheckAction 
          ON sqlCheckAction.check_id = sqlCheck.check_id 
     LEFT JOIN 
     dbo.sqlwatch_config_action sqlAct 
          ON sqlAct.action_id = sqlCheckAction.action_id 
--WHERE   (( sqlCheck.base_object_type IN ( 'Job', 'Disk') 
--OR       sqlCheck.check_name LIKE '%backup%' 
--OR       sqlCheck.check_name LIKE 'Blocked Process' 
--OR       sqlCheck.check_name LIKE 'CPU Utilistaion' 
--         ) 
--AND    sqlCheck.check_name NOT LIKE '%dbatools%') 
AND sqlCheckAction.check_id IS NULL  
SELECT * FROM sqlwatch_config_check 
WHERE check_id > 1000 
SELECT * 
from [dbo].[sqlwatch_config_action] 
WHERE base_object_type = 'job' 
--where check_id in (-2) 
SELECT * 
FROM dbo.sqlwatch_config_check_action 
WHERE check_id = -2 
AND action_id = 1
```
