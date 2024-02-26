 Grant 'Perform Volume Maintenance Tasks' right to the account that will be used for the SQL Server service (the engine, not the agent). 


/* Testing */

USE master ;
 
--Set Trace Flags 3004 and 3605 to On.
DBCC TRACEON( 3004,-1 );
DBCC TRACEON( 3605,-1 );
 
--Create a dummy database to see what output is sent to the SQL Server Error Log
CREATE DATABASE DummyDB ON  PRIMARY
(NAME = N'DummyDB', FILENAME = N'D:\SQLServer\Data\DummyDB.mdf' , SIZE = 256MB)
 LOG ON
( NAME = N'DummyDB_log', FILENAME = N'D:\SQLServer\Data\DummyDB_log.ldf' , SIZE = 1MB)
 
--Turn the two Trace Flags to OFF.
DBCC TRACEOFF( 3004,3605 ,-1);
 
--Remove the DummyDB
DROP DATABASE DummyDB;
 
--Now go check the output in the SQL Server Error Log File
  