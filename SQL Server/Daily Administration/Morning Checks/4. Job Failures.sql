/***************/
/* Failed jobs */
/***************/
USE msdb
GO
SELECT h.server as [Server]
     , j.[name] as [Name]
     , CASE h.run_status
            WHEN 1
            THEN 'Sucesso'
            WHEN 0
            THEN 'Falha'
            WHEN 2
            THEN 'Tentar Novamente'
            WHEN 3
            THEN 'Cancelado'            
       END as [Status]
     , LastRunDate = FORMAT( CONVERT( DATE, CONVERT(CHAR (8), h.run_date )), 'd' , 'pt-br')
     , LastRunTime = STUFF( STUFF(REPLACE (STR( h.run_time ,6, 0),' ' ,'0'), 3,0 ,':'), 6,0, ':')
     , [Duration]  = STUFF( STUFF(REPLACE (STR( h.run_duration , 6, 0),' ' ,'0'), 3,0, ':'), 6 ,0, ':')
     , [Message]   = h.message  
FROM sysjobhistory h
         INNER JOIN sysjobs j
           ON h. job_id = j .job_id
WHERE j. enabled = 1
AND   h. instance_id IN ( SELECT MAX( h.instance_id )
                                     FROM sysjobhistory h
                         GROUP BY (h. job_id)
                       )
AND   h. run_date >= CONVERT(CHAR (8), DATEADD( day, -1, GETDATE()), 112)
ORDER BY h.run_date ASC
       , h. run_time ASC
       , CASE WHEN h . run_status != 1
              THEN 0
              ELSE 1
         END ASC
,        Name;


 
  