
```
      SELECT CheckDay 
           , MIN([Batch Requests per Sec]) BatchRequestSecMin 
           , AVG([Batch Requests per Sec]) BatchRequestSecAvg 
           , MAX([Batch Requests per Sec]) BatchRequestSecMax 
           , MIN([Wait Time per Core per Sec]) WaitTimeCoreSecMin 
           , AVG([Wait Time per Core per Sec]) WaitTimeCoreSecAvg 
           , MAX([Wait Time per Core per Sec]) WaitTimeCoreSecMax 
           , MIN([CPU Utilization]) ProcessorUsageMin 
           , AVG([CPU Utilization]) ProcessorUsageAvg 
           , MAX([CPU Utilization]) ProcessorUsageMax 
      FROM ( 
          SELECT CheckDay = CONVERT(VARCHAR(10), CheckDate, 113) 
               , [Batch Requests per Sec] 
               , [Wait Time per Core per Sec] 
               , [CPU Utilization] 
          FROM ( 
               SELECT FORMAT(CheckDate, 'dd/MM/yyyy hh:mm:ss') AS CheckDate 
                    , Finding 
                    , Details = CASE WHEN Finding = 'CPU Utilization'  
                                     THEN CONVERT(FLOAT, SUBSTRING(Details, 1, CHARINDEX('%', Details, 1) -1 )) 
                                     ELSE Details  
                                END 
               FROM dbaMonitor.dbo.BlitzFirst 
               WHERE Finding IN ('Batch Requests per Sec', 'Wait Time per Core per Sec', 'CPU Utilization')  
               ) blitz 
          PIVOT ( 
                    MAX(Details)  
                    FOR Finding IN ([Batch Requests per Sec], [Wait Time per Core per Sec], [CPU Utilization]) 
                ) pvtBlitz 
          ) grpBlitz 
     GROUP BY CheckDay
```
