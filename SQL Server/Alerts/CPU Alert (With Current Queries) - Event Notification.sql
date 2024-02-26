USE   MSDB
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
 
/*Using Extended stored procedures to write information to the HTML file*/
IF EXISTS (SELECT * FROM dbo. sysobjects WHERE id = OBJECT_ID(N'[dbo].[writetofile]' ) AND OBJECTPROPERTY( id, N'IsProcedure') = 1)
DROP Procedure [dbo].[writetofile]
go
CREATE procedure [dbo].[writetofile] (@filename varchar (255), @text1 varchar( 8000))
as
    declare @fs int, @oleresult int, @fileid int
 
    execute @oleresult = sp_OACreate 'scripting.filesystemobject', @fs out
 
    if @oleresult <> 0 print 'scripting.filesystemobject'
        execute @oleresult = sp_OAMethod @fs, 'opentextfile', @fileid out, @filename, 8, 1
 
    if @oleresult <> 0 print 'opentextfile'
        execute @oleresult = sp_OAMethod @fileid, 'writeline', null, @text1
 
    if @oleresult <> 0 print 'writeline'
        execute @oleresult = sp_OADestroy  @fileid
 
    execute @oleresult = sp_OADestroy   @fs
 
GO
 
/*capturing High CPU consuming queries (also included reads , writes and duration)*/
IF EXISTS (SELECT * FROM dbo. sysobjects WHERE id = OBJECT_ID(N'[dbo].[highcpureport]' ) AND OBJECTPROPERTY( id, N'IsProcedure') = 1)
DROP Procedure [dbo].[highcpureport]
GO
create procedure dbo.highcpureport as
DECLare
@tableHTML  NVARCHAR( MAX),
@subject1 varchar( 200),
@date datetime,
@total_worker_time    BIGINT,
@total_physical_reads BIGINT,
@total_logical_writes BIGINT,
@total_logical_reads  BIGINT,
@total_clr_time       BIGINT,
@percentage_of_total_clr_time BIGINT,
@total_elapsed_time   BIGINT,        
@printscr varchar( 8000),
@filestr varchar( 255),
@dbid int,
@procedure_id int,
@statement_text varchar( 1000),
@percentage_of_total_worker_time decimal(6 ,4),
@percentage_of_total_physical_read decimal(6 ,4),
@percentage_of_total_logical_writes decimal(6 ,4),   
@percentage_of_total_logical_reads decimal(6 ,4),
@percentage_of_total_elapsed_time decimal(6 ,4),
@total_recompiles int,
@impmeas FLOAT,
@DBNAME VARCHAR( 30),
@OBJECTID INT,
@execution_count int;      
 
Begin
      SELECT      @total_worker_time    = SUM(total_worker_time )    ,
 
                        @total_physical_reads = SUM (total_physical_reads) ,
 
                        @total_logical_writes = SUM (total_logical_writes) ,
 
                        @total_logical_reads  = SUM (total_logical_reads)   ,
 
                        @total_clr_time       = SUM (total_clr_time)        ,
 
                        @total_elapsed_time   = SUM (total_elapsed_time)
 
      FROM        sys. dm_exec_query_stats
 
 
 
      IF ISNULL (@total_worker_time    , 0) = 0 SET @total_worker_time    = 1
 
      IF ISNULL (@total_physical_reads , 0) = 0 SET @total_physical_reads = 1
 
      IF ISNULL (@total_logical_writes , 0) = 0 SET @total_logical_writes = 1
 
      IF ISNULL (@total_logical_reads  , 0) = 0 SET @total_logical_reads  = 1
 
      IF ISNULL (@total_clr_time       , 0 ) = 0 SET @total_clr_time       = 1
 
      IF ISNULL (@total_elapsed_time   , 0) = 0 SET @total_elapsed_time   = 1
 
      SELECT TOP 20 st.dbid , st .objectid as procedure_id ,  SUBSTRING(st .text, (qs. statement_start_offset/2 ) + 1,((CASE statement_end_offset WHEN -1 THEN DATALENGTH(st .text) ELSE qs .statement_end_offset END - qs.statement_start_offset)/ 2) + 1) AS statement_text ,
 
      total_worker_time ,
 
      cast( 100.00 * total_worker_time / @total_worker_time  as decimal (6 ,4) )  AS percentage_of_total_worker_time,
 
      total_physical_reads ,
 
      cast( 100.00 * total_physical_reads / @total_physical_reads  as decimal (6, 4) )  AS percentage_of_total_physical_reads,
 
      total_logical_writes ,
 
      cast( 100.00 * total_logical_writes / @total_logical_writes  as decimal (6, 4) )  AS percentage_of_total_logical_writes,
 
      total_logical_reads ,
 
      cast( 100.00 * total_logical_reads / @total_logical_reads as decimal (6 ,4) )  AS percentage_of_total_logical_reads,
 
      total_clr_time ,
 
      cast( 100.00 * total_clr_time / @total_clr_time as decimal (6 ,4) )  AS percentage_of_total_clr_time,
 
      total_elapsed_time ,
 
      cast( 100.00 * total_elapsed_time / @total_elapsed_time  as decimal (6 ,4) )  AS percentage_of_total_elapsed_time,
 
      plan_generation_num as total_recompiles,
 
      execution_count into #highcpu
 
      FROM sys .dm_exec_query_stats as qs
 
      CROSS APPLY sys. dm_exec_sql_text(qs .sql_handle) as st
 
      ORDER BY total_worker_time DESC
 
/*Deleting existing file from C:\temp\ and creating the same file again*/
Declare @str varchar (200)
Declare @File varchar (200)
--Declare @Filestr varchar(200)
Set @str = 'DEL '
SET @File = 'HighCPU.HTML'
SET @filestr= 'c:\temp\'
SET @filestr= @filestr+@File
select @filestr
Set @str = @str +@filestr
exec master ..xp_cmdshell @str
 
SET @filestr = 'c:\temp\'+ 'HighCPU.html'
        
/*Setting different headings using color combinations*/
print @filestr
set @printscr= '<html><head><title>High CPU Report</title><style type="text/css"> body {background-color: #DCDCDC;}'+
      'H1 {background-color:#FF0000;}'+
      'H2 {background-color:#C0C0C0;}'+
      'H3 {background-color:#FFFFFF;}'+
      'tr {background-color:#FFFFFF;}'+
      'th {background-color:#C0C0C0;}'+
    '</style></head>'
exec writetofile @filestr, @printscr
set @printscr= '<H1>Report generated on '+ CONVERT ( varchar, GETDATE())+ '</H1>'
exec writetofile @filestr,@printscr
set @printscr= '<H2>High CPU Report</H2>'
exec writetofile @filestr, @printscr
set @printscr= '<B>This report details the top CPU consuming queries which are responsible for high CPU utilization</b>'
exec writetofile @filestr, @printscr
 
set @printscr= '<table cellspacing="1" cellpadding="1" border="1">' +
N'<tr><th><strong>DBID</strong></th>' +
N'<th><strong>PROCEDURE_ID</strong></th>' +
N'<th><strong>STATEMENT TEXT</strong></th>' +
N'<th><strong>TOTAL CPU TIME</strong></th>' +
N'<th><strong>PERCENTAGE OF TOTAL CPU TIME</strong></th>' +
N'<th><strong>TOTAL PHYSICAL READS</strong></th>' +
N'<th><strong>PERCENTAGE OF TOTAL PHYSICAL READS</strong></th>' +
N'<th><strong>TOTAL LOGICAL WRITES</strong></th>' +
N'<th><strong>PERCENTAGE OF TOTAL LOGICAL WRITES</strong></th>' +
N'<th><strong>TOTAL LOGICAL READS</strong></th>' +
N'<th><strong>PERCENTAGE OF TOTAL LOGICAL READS</strong></th>' +
N'<th><strong>TOTAL CLR TIME</strong></th>' +
N'<th><strong>PERCENTAGE OF TOTAL CLR TIME</strong></th>' +
N'<th><strong>TOTAL ELAPSED TIME</strong></th>' +
N'<th><strong>PERCENTAGE OF TOTAL ELAPSED TIME</strong></th>' +
N'<th><strong>TOTAL RECOMPILES</strong></th>' +
N'<th><strong>EXECUTION COUNT</strong></th></tr>'
exec writetofile @filestr,@printscr
 
/*fetcing the information via cursor and writing it to the file we created above*/
declare Cur_result cursor for select * from #highcpu
open Cur_result
fetch Cur_result into @dbid,@procedure_id, @statement_text,@total_worker_time ,@percentage_of_total_worker_time, @total_physical_reads,@percentage_of_total_physical_read ,@total_logical_writes, @percentage_of_total_logical_writes,@total_logical_reads ,@percentage_of_total_logical_reads,
@total_clr_time,@percentage_of_total_clr_time ,@total_elapsed_time, @percentage_of_total_elapsed_time, @total_recompiles ,@execution_count
 
while @@fetch_status >= 0
begin
set @printscr='<tr><td>'+ convert(varchar ,@dbid)+ '</td><td>'+convert (varchar, @procedure_id)+'</td><td>' +@statement_text+ '</td><td>'+convert (varchar, @total_worker_time)+'</td><td>' +convert( varchar,@percentage_of_total_worker_time )+'</td><td>'+ convert(varchar ,@total_physical_reads)+ '</td><td>'+convert (varchar, @percentage_of_total_physical_read)+'</td><td>' +convert( varchar,@total_logical_writes )+'</td><td>'+ convert(varchar ,@percentage_of_total_logical_writes)+ '</td><td>'+convert (varchar, @total_logical_reads)+'</td><td>' +convert( varchar,@percentage_of_total_logical_reads )+'</td><td>'+ convert(varchar ,@total_clr_time)+ '</td><td>'+convert (varchar, @percentage_of_total_clr_time)+'</td><td>' +convert( varchar,@total_elapsed_time )+'</td><td>'+ convert(varchar ,@percentage_of_total_elapsed_time)+ '</td><td>'+convert (varchar, @total_recompiles)+'</td><td>' +convert( varchar,@execution_count )+'</td></tr>'
exec writetofile @filestr, @printscr
print @printscr
fetch Cur_result into @dbid,@procedure_id, @statement_text,@total_worker_time ,@percentage_of_total_worker_time, @total_physical_reads,@percentage_of_total_physical_read ,@total_logical_writes, @percentage_of_total_logical_writes,@total_logical_reads ,@percentage_of_total_logical_reads,
@total_clr_time,@percentage_of_total_clr_time ,@total_elapsed_time, @percentage_of_total_elapsed_time, @total_recompiles ,@execution_count
end
set @printscr= '</table>'
exec writetofile @filestr, @printscr
close Cur_result
deallocate Cur_result
 
/*Capturing Missing indexes information for more help and writing it to the same HTML file*/
set @printscr= '<H2>Missing Indexes Report</H2>'
exec writetofile @filestr, @printscr
set @printscr= '<B>This report details the indexes which are found missing by SQL Server optimizer abd creating the indexes with high improvement measure can improve performance </b>'
exec writetofile @filestr, @printscr
declare Cur_missindx cursor for
SELECT
 
  migs.avg_total_user_cost * ( migs.avg_user_impact / 100.0) * (migs. user_seeks + migs.user_scans) AS improvement_measure ,
 
  'CREATE INDEX [missing_index_' + CONVERT (varchar , mig. index_group_handle) + '_' + CONVERT (varchar , mid. index_handle)
 
  + '_' + LEFT (PARSENAME( mid.statement , 1), 32) + ']'
 
  + ' ON ' + mid.statement
 
  + ' (' + ISNULL (mid. equality_columns,'' )
 
    + CASE WHEN mid.equality_columns IS NOT NULL AND mid. inequality_columns IS NOT NULL THEN ',' ELSE '' END
 
    + ISNULL ( mid.inequality_columns , '' )  + ')'
 
  + ISNULL ( ' INCLUDE (' + mid.included_columns + ')' , '' ) AS create_index_statement,
 
  --migs.*,
   DB_NAME( mid.database_id ) as dbname, mid .[object_id]
 
FROM sys .dm_db_missing_index_groups mig
 
INNER JOIN sys. dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
 
INNER JOIN sys. dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
 
WHERE migs. avg_total_user_cost * (migs. avg_user_impact / 100.0 ) * (migs .user_seeks + migs. user_scans) > 0
 
ORDER BY migs.avg_total_user_cost * migs. avg_user_impact * (migs. user_seeks + migs.user_scans) DESC
 
set @printscr= '<b>Missing Indexes</b>'
exec writetofile @filestr, @printscr
 
set @printscr= '<table cellspacing="1" cellpadding="1" border="1">' +
N'<tr><th><strong>IMPROVEMENT MEASURE</strong></th>' +
N'<th><strong>CREATE INDEX STATEMENT</strong></th>' +
N'<th><strong>DBNAME</strong></th>' +
N'<th><strong>OBJECT NAME</strong></th></tr>'
exec writetofile @filestr,@printscr
open Cur_missindx
fetch Cur_missindx into @impmeas,@statement_text ,@dbname, @objectID
while @@fetch_status >= 0
begin
set @printscr= '<tr><td>'+CAST (@impmeas AS VARCHAR)+'</td><td>' +@statement_text+ '</td><td>'+@dbname +'</td><td>'+ OBJECT_NAME(@objectID )+'</td></tr>'
exec writetofile @filestr, @printscr
fetch Cur_missindx into @impmeas,@statement_text ,@dbname, @objectID
end
set @printscr= '</table></html>'
exec writetofile @filestr, @printscr
close Cur_missindx
deallocate Cur_missindx
end
 
go
 
 
 
 
/*Creating the Job that will execute above queries and also sends mail to the DBA with the HTML report*/
 
USE [msdb]
GO
 
IF EXISTS (SELECT job_id FROM msdb .dbo. sysjobs_view WHERE name = N'Capture High CPU event')
EXEC msdb. dbo.sp_delete_job @job_name = N'Capture High CPU event', @delete_unused_schedule=1
 
GO
 
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
 
IF NOT EXISTS (SELECT name FROM msdb. dbo.syscategories WHERE name= N'[Uncategorized (Local)]' AND category_class =1)
BEGIN
EXEC @ReturnCode = msdb.dbo .sp_add_category @class=N'JOB' , @type= N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END
 
DECLARE @jobId BINARY (16)
EXEC @ReturnCode = msdb.dbo .sp_add_job @job_name=N'Capture High CPU event' ,
@enabled=1 ,
@notify_level_eventlog=2 ,
@notify_level_email=3 ,
@notify_level_netsend=0 ,
@notify_level_page=0 ,
@delete_level=0 ,
@description=N'Job for responding to Capture High CPU events' ,
@category_name=N'[Uncategorized (Local)]' ,
@job_id = @jobId OUTPUT
 
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
 
/*Step 3: Insert graph into LogEvents*/
 
EXEC @ReturnCode = msdb.dbo .sp_add_jobstep @job_id=@jobId , @step_name= N'Executing the High CPU Script and generating the HTML file',
@step_id=1 ,
@cmdexec_success_code=0 ,
@on_success_action=3 ,
@on_success_step_id=0 ,
@on_fail_action=2 ,
@on_fail_step_id=0 ,
@retry_attempts=0 ,
@retry_interval=0 ,
@os_run_priority=0 , @subsystem= N'TSQL',
@command=N'
USE MSDB ; exec highCPUreport;
'
 
 
/*Adding the job step 2 to execute the SPs for sending mail */
declare @command1 nvarchar (200)
set @command1= 'use  MSDB' + '; exec HighCPU_rpt;'
EXEC @ReturnCode = msdb.dbo .sp_add_jobstep @job_id=@jobId , @step_name= N'Sending mail',
@step_id=2 ,
@cmdexec_success_code=0 ,
@on_success_action=1 ,
@on_success_step_id=0 ,
@on_fail_action=2 ,
@on_fail_step_id=0 ,
@retry_attempts=0 ,
@retry_interval=0 ,
@os_run_priority=0 , @subsystem= N'TSQL',
@command=@command1
 
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo .sp_update_job @job_id = @jobId , @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo .sp_add_jobserver @job_id = @jobId , @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
 
GOTO EndSave
 
QuitWithRollback:
IF (@@TRANCOUNT > 0 ) ROLLBACK TRANSACTION
EndSave:
GO
 
/* Creating the alert and associating it with the Job to be fired */
 
USE [msdb]
GO
 
IF EXISTS (SELECT name FROM msdb .dbo. sysalerts WHERE name = N'Respond to HIGH CPU Event')
EXEC msdb. dbo.sp_delete_alert @name= N'Respond to HIGH CPU Event'
 
GO
declare @count int
declare @instance nvarchar (50)
declare @server nvarchar (50)
DECLARE @server_namespace varchar (255)
select @instance= convert(nvarchar (50),( SERVERPROPERTY('instancename' )))
select @server=convert( nvarchar(50 ),(SERVERPROPERTY( 'ComputerNamePhysicalNetBIOS')))
SET @server_namespace = N'\\'+ @server+'\root\CIMV2'
 
 
EXEC msdb. dbo.sp_add_alert @name= N'Custom 002 - Alerta de CPU',
@enabled=1 ,
@notification_message=N'Your Message' ,
@wmi_namespace='\\.\root\CIMV2' ,
@wmi_query=N'SELECT * FROM __InstanceModificationEvent WITHIN 300 WHERE TargetInstance ISA ''Win32_Processor'' AND TargetInstance.LoadPercentage > 60';
 
/*adding an operator is optional*/
--EXEC msdb.dbo.sp_add_notification @alert_name=N'Custom 002 - Alerta de CPU', @operator_name=N'SysAdmin', @notification_method = 1
GO
 
/* Create a stored proc for sending the High CPU information as .HTML file using DBMail */
USE  MSDB
go
IF EXISTS (SELECT * FROM dbo. sysobjects WHERE id = OBJECT_ID(N'dbo.HighCPU_rpt' ) AND OBJECTPROPERTY (id, N'IsProcedure') = 1 )
DROP proc dbo.HighCPU_rpt
go
Create proc [dbo].[HighCPU_rpt]
as
DECLARE @SQL varchar (2000)
DECLARE @date varchar (2000)
DECLARE @Attachments varchar (2000)
select @date= convert( varchar,GETDATE ())
SET @attachments = 'C:\temp\HighCPU.HTML'
 
EXECUTE msdb. dbo.sp_send_dbmail
@profile_name = 'MSDBPfl' ,
@recipients = 'abcdef.123456@qq.rr.com' ,
@subject = 'HIGH CPU Events Report',
@body = '***URGENT***Attached Please Find HIGH CPU Events Report' ,
@file_attachments=@attachments
go