-- Tested SQL 2005 - 2012.
 DECLARE @perfcond NVARCHAR(100);
 DECLARE @sqlversion TINYINT;
 
 -- get the major version of sql running
 SELECT  @sqlversion = ca2.Ver
 FROM    (SELECT CONVERT(VARCHAR(20), 
                         SERVERPROPERTY('ProductVersion')) AS Ver) dt1
         CROSS APPLY (SELECT CHARINDEX('.', dt1.Ver) AS Pos) ca1
         CROSS APPLY (SELECT SUBSTRING(dt1.Ver, 1, ca1.Pos-1) AS Ver) ca2;
 
 -- handle the performance condition depending on the version of sql running
 -- and whether this is a named instance or a default instance.
 SELECT  @perfcond = 
         CASE WHEN @sqlversion >= 11 THEN ''
         ELSE ISNULL(N'MSSQL$' + 
                 CONVERT(sysname, SERVERPROPERTY('InstanceName')), N'SQLServer') +N':'
         END +
         N'Locks|Number of Deadlocks/sec|_Total|>|0';
 
 EXEC msdb.dbo.sp_add_alert 
     @name=N’Custom 001 - Deadlock Alert', 
     @message_id=0, 
     @severity=0, 
     @enabled=1, 
    @delay_between_responses=0, 
    @include_event_description_in=0, 
    @category_name=N'[Uncategorized]’, — syscategories (msdb)
    @performance_condition=@perfcond, 
     --@job_name=N'Job to run when a deadlock happens, if applicable'
     -- or 
     @job_id=N'00000000-0000-0000-0000-000000000000'
 GO
 
 EXEC msdb.dbo.sp_add_notification 
     @alert_name = N'Deadlock Alert',
     @notification_method = 1, --email
     @operator_name = N'General'; -- name of the operator to notify
 GO