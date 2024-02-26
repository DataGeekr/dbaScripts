/* Job Execution History */

SELECT JobName
     , StartTime
     , EndTime
     , RunDurationSecs
FROM (
       SELECT JobName = j.name
            , StartTime = CAST( CONVERT( VARCHAR, jh.run_date )
                                + ' ' + STUFF(STUFF (RIGHT('000000'
                                + CONVERT(VARCHAR ,jh. run_time),6 ),5, 0,':' ),3, 0,':' )
                                AS DATETIME
                                )
            , EndTime = DATEADD( SECOND, jh.run_duration , CAST ( CONVERT ( VARCHAR , jh.run_date )
                                                              + ' ' + STUFF(STUFF (RIGHT('000000'
                                                              + CONVERT(VARCHAR ,jh. run_time),6 ),5, 0,':' ),3, 0,':' )
                                                              AS DATETIME
                                                              ) )
            , RunDurationSecs = CAST(FLOOR (run_duration / 86400) AS VARCHAR(10 ))+'d ' + CONVERT (VARCHAR(8), DATEADD(SECOND , run_duration , '19000101' ), 8)
       FROM msdb ..sysjobhistory jh
            INNER JOIN msdb.. sysjobs j
                      ON  j .job_id = jh .job_id
       WHERE jh .step_name = '(Job outcome)'
     ) AS Jobs
-- /*
WHERE StartTime BETWEEN '2014-10-22 23:00' AND '2014-10-23 01:00'
-- */