SET NOCOUNT ON
DECLARE @backupFolder         VARCHAR(250)
DECLARE @dbName               VARCHAR(128)
DECLARE @dbRestoreTo          VARCHAR(128) /* Restaurar com novo nome ou sobre um novo banco de dados */
DECLARE @dbBackup             VARCHAR(250)
DECLARE @restorePoint         DATETIME2(0)
DECLARE @lastBackupFullTaken  DATETIME2(0)
DECLARE @BackupPath           VARCHAR(200)
DECLARE @BackupType           CHAR(4)
DECLARE @BackupDate           VARCHAR(20)
DECLARE @cmdSQLBackup         NVARCHAR(MAX);
SET @dbName        = 'IdentidadeDoAdvogado'
SET @dbRestoreTo   = NULL
SET @backupFolder  = 'Z:\SQLBackup\Backup\'
SET @backupFolder  = IIF(RIGHT(@backupFolder, 1) = '\', '', '\') + CONCAT(@backupFolder, @@SERVERNAME, '\', @dbName, '\')
SET @restorePoint  = '2016-12-31';
IF (SELECT ISNULL(OBJECT_ID('tempdb..#_OSFiles'), 0)) != 0
BEGIN
    DROP TABLE #_OSFiles;
END
CREATE TABLE #_OSFiles
(
  subdirectory VARCHAR(200)
, depth        SMALLINT
, filetype     BIT
, backuptype   CHAR(4)
);
IF (SELECT ISNULL(OBJECT_ID('tempdb..#_BackupFiles'), 0)) != 0
BEGIN
    DROP TABLE #_BackupFiles;
END
CREATE TABLE #_BackupFiles
(
  BackupName VARCHAR(200)
, BackupType CHAR(4)
, BackupDate DATETIME2(0)
);
-- Recupera os arquivos do sistema operacional
INSERT INTO #_OSFiles
         ( subdirectory
         , depth
         , filetype
         )
EXEC xp_dirtree @backupFolder, 2, 1
-- Monta o caminho completo do arquivo e data de criação
INSERT INTO #_BackupFiles
          (
            BackupName
          , BackupType
          , BackupDate
          )
     SELECT CONCAT(@backupFolder, BackupType, '\', BackupFile)
          , backupFiles.BackupType
          , backupFiles.BackupDate
     FROM (
          SELECT BackupFile = subdirectory
               , BackupType = SUBSTRING(subdirectory, 1 + LenToType.size, LenToDate.Pos - (1 + LenToType.size))
               , BackupDate = CAST(CONCAT(SUBSTRING(subdirectory, 1 + LenToDate.Pos, (LenToHour.Pos - LenToDate.Pos) - 1), ' ', STUFF(STUFF(SUBSTRING(subdirectory, 1 + LenToHour.Pos, 6), 3, 0, ':'), 6, 0, ':')) AS DATETIME2(0))
          FROM #_OSFiles
               CROSS APPLY
               (
               SELECT CONCAT(@@SERVERNAME, '_', @dbName, '_') tag
               ) AS Suffix
               CROSS APPLY
               (
               SELECT LEN(Suffix.tag) size
               ) AS LenToType
               CROSS APPLY
               (
               SELECT CHARINDEX('_', subdirectory, LenToType.size + 1) Pos
               ) AS LenToDate
               CROSS APPLY
               (
               SELECT CHARINDEX('_', subdirectory, LenToDate.Pos + 2) Pos
               ) AS LenToHour
          WHERE filetype = 1
          ) backupFiles;
-- Recupera a data do último backup FULL anterior a data solicitada
SELECT @backupType = BackupType
     , @backupDate = CAST(BackupDate AS VARCHAR(20))
     , @cmdSQLBackup = CONCAT( '/* [', BackupType, '] ', BackupDate, '*/', CHAR(13)
                             , 'RESTORE BACKUP ', IIF(ISNULL(@dbRestoreTo, '') != '', @dbRestoreTo, @dbName), CHAR(13)
                             , 'FROM DISK ''', BackupName, '''', CHAR(13)
                             , 'WITH CHECKSUM, NORECOVERY, STATS = 10;', CHAR(13)
                             , 'GO')
FROM (
     SELECT BackupName
          , BackupType
          , BackupDate
          , ROW_NUMBER() OVER (ORDER BY BackupDate DESC) rn
     FROM #_BackupFiles
     WHERE BackupType = 'FULL'
     AND   BackupDate <= @restorePoint
     ) backupFull
WHERE rn = 1;
SELECT [Restore] = @cmdSQLBackup;
-- Recupera a data do último backup DIFF anterior a data solicitada
SELECT @backupType = BackupType
     , @backupDate = CAST(BackupDate AS VARCHAR(20))
     , @cmdSQLBackup = CONCAT( '/* [', BackupType, '] ', BackupDate, '*/', CHAR(13)
                             , 'RESTORE BACKUP ', IIF(ISNULL(@dbRestoreTo, '') != '', @dbRestoreTo, @dbName), CHAR(13)
                             , 'FROM DISK ''', BackupName, '''', CHAR(13)
                             , 'WITH NORECOVERY, STATS = 10;', CHAR(13)
                             , 'GO')
FROM (
     SELECT BackupName
          , BackupType
          , BackupDate
          , ROW_NUMBER() OVER (ORDER BY BackupDate DESC) rn
     FROM #_BackupFiles
     WHERE BackupType = 'DIFF'
     AND   BackupDate > @BackupDate
     AND   BackupDate <= @restorePoint
     ) backupFull
WHERE rn = 1;
SELECT [Restore] = @cmdSQLBackup;
-- Recupera os backups de transaction log no intervalo
SELECT [Restore] = CONCAT( '/* [', LTRIM(RTRIM(BackupType)), '] ', BackupDate, '*/', CHAR(13)
                         , 'RESTORE BACKUP ', IIF(ISNULL(@dbRestoreTo, '') != '', @dbRestoreTo, @dbName), CHAR(13)
                         , 'FROM DISK ''', BackupName, '''', CHAR(13)
                         , 'WITH STATS = 10, ', IIF(rn = 1, 'RECOVERY', 'NORECOVERY'), ';', CHAR(13)
                         , 'GO')
FROM (
     SELECT BackupName
          , BackupType
          , BackupDate
          , ROW_NUMBER() OVER (ORDER BY BackupDate DESC) rn
     FROM #_BackupFiles
     WHERE BackupType = 'LOG'
     AND   BackupDate BETWEEN @backupDate AND @restorePoint
     ) backupFull
ORDER BY BackupDate ASC;