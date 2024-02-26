
```
USE [msdb] 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'ba350f97-1b6a-492b-a54d-21d926ea499b', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'a767d3b7-cfc9-4a7a-80d6-dfbfc65e964b', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'1ce01c62-3d4b-465e-9ffe-23793286b5c4', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'e7e1c4e3-764a-4ff8-88ad-22c4a7b18c12', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'bca105d6-112b-4dd9-b327-cc5c4b0ebd23', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'8698c74a-998e-4edc-9398-02992cadfd1f', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'1b57d52b-29c7-4ed9-be74-c97fc1f51a0a', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'b39170aa-758f-4b44-bf98-2b1faf2a49bd', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'b84207c1-c302-4536-886f-253c1a6d65e0', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'70e2b617-6b73-4bb9-b419-7d750175e87c', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'dcc5534f-1e64-4599-ac42-b9dbced272da', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'8ce4945a-3251-465c-807e-60b7141201ea', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'db5e2b0b-2305-4038-99a7-4fdae78de280', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'5ccefed0-fb99-4877-a923-d464f8bb6e5a', @delete_unused_schedule=1 
GO 
EXEC msdb.dbo.sp_delete_job @job_id=N'20303f8c-8021-429c-8f34-36438348ee8b', @delete_unused_schedule=1 
GO 
USE master 
GO 
DROP DATABASE [dbaSQLWatch] 
GO 
CREATE DATABASE [dbaSQLWatch] 
 CONTAINMENT = NONE 
 ON  PRIMARY  
( NAME = N'dbaSQLWatch', FILENAME = N'D:\SQLServer\Data\dbaSQLWatch_Data01.mdf' , SIZE = 2097152KB , FILEGROWTH = 524288KB ) 
 LOG ON  
( NAME = N'dbaSQLWatch_log', FILENAME = N'E:\SQLServer\Log\dbaSQLWatch_Log01.ldf' , SIZE = 262144KB , FILEGROWTH = 65536KB ) 
 COLLATE Latin1_General_CI_AS 
GO 
ALTER DATABASE [dbaSQLWatch] SET COMPATIBILITY_LEVEL = 150 
GO 
ALTER DATABASE [dbaSQLWatch] SET ANSI_NULL_DEFAULT OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET ANSI_NULLS OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET ANSI_PADDING OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET ANSI_WARNINGS OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET ARITHABORT OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET AUTO_CLOSE OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET AUTO_SHRINK OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF) 
GO 
ALTER DATABASE [dbaSQLWatch] SET AUTO_UPDATE_STATISTICS ON  
GO 
ALTER DATABASE [dbaSQLWatch] SET CURSOR_CLOSE_ON_COMMIT OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET CURSOR_DEFAULT  GLOBAL  
GO 
ALTER DATABASE [dbaSQLWatch] SET CONCAT_NULL_YIELDS_NULL OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET NUMERIC_ROUNDABORT OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET QUOTED_IDENTIFIER OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET RECURSIVE_TRIGGERS OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET  DISABLE_BROKER  
GO 
ALTER DATABASE [dbaSQLWatch] SET AUTO_UPDATE_STATISTICS_ASYNC OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET DATE_CORRELATION_OPTIMIZATION OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET PARAMETERIZATION SIMPLE  
GO 
ALTER DATABASE [dbaSQLWatch] SET READ_COMMITTED_SNAPSHOT OFF  
GO 
ALTER DATABASE [dbaSQLWatch] SET  READ_WRITE  
GO 
ALTER DATABASE [dbaSQLWatch] SET RECOVERY SIMPLE  
GO 
ALTER DATABASE [dbaSQLWatch] SET  MULTI_USER  
GO 
ALTER DATABASE [dbaSQLWatch] SET PAGE_VERIFY CHECKSUM   
GO 
ALTER DATABASE [dbaSQLWatch] SET TARGET_RECOVERY_TIME = 60 SECONDS  
GO 
ALTER DATABASE [dbaSQLWatch] SET DELAYED_DURABILITY = DISABLED  
GO 
USE [dbaSQLWatch] 
GO 
ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = Off; 
GO 
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET LEGACY_CARDINALITY_ESTIMATION = Primary; 
GO 
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 0; 
GO 
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET MAXDOP = PRIMARY; 
GO 
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = On; 
GO 
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET PARAMETER_SNIFFING = Primary; 
GO 
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = Off; 
GO 
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET QUERY_OPTIMIZER_HOTFIXES = Primary; 
GO 
USE [dbaSQLWatch] 
GO 
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [dbaSQLWatch] MODIFY FILEGROUP [PRIMARY] DEFAULT 
GO
```

```
C:\Program Files\Microsoft SQL Server\160\DAC\bin> ./SqlPackage.exe 
    /Action:Publish 
    /SourceFile:"C:\Users\rafael_dba\Downloads\SQLWATCH\SQLWATCH.dacpac" 
    /TargetDatabaseName:dbaSQLWatch 
    /TargetServerName:CORVETTE 
    /p:RegisterDataTierApplication=True 
    /p:CommandTimeout=240 
    /TargetUser:rafael.rodrigues 
    /TargetPassword:Luna8188
```

SqlPackage Download