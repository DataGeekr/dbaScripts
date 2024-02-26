CREATE VIEW vw_GetDatabaseGrowth
AS
   SELECT a .ServerName
        , a. DatabaseName
        , a. LogicalName
        , a. PhysicalName
        , a. FreeSpaceMB
        , a. FreeSpacePct
        , ( c.FileSizeMB - a. FileSizeMB) AS growthSize
        , a. FileSizeMB AS previousSize
        , c. FileSizeMB AS newSize
        , DATEDIFF (day, a.PollDate , c. PollDate) AS periodDays
        , isGrowth = CASE WHEN a. FileSizeMB < c .FileSizeMB
                          THEN 1
                          ELSE 0
                     END
        , a. PollDate
   FROM dbo .DatabaseGrowth a
   CROSS APPLY
   (
   SELECT TOP 1 *
   FROM dbo .DatabaseGrowth b
   WHERE a .PollDate < b.PollDate
   AND a .ServerName = b.ServerName
   AND a .DatabaseName = b.DatabaseName
   AND a .LogicalName = b.LogicalName
   AND a .FileType = b.FileType
   ORDER BY b. PollDate
   ) c

  