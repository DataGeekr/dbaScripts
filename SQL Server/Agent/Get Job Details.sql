 
USE msdb
GO
DECLARE @JobName VARCHAR(MAX)
SELECT @JobName = [name] 
FROM msdb.dbo.sysjobs
WHERE job_id = CAST(0x157C1A2FBFB8ED4FACBE776BDF5E6A5D AS uniqueidentifier)
EXECUTE msdb..sp_help_job @job_name = @JobName
EXECUTE msdb..sp_help_jobstep @job_name = @JobName