 SET NOCOUNT ON

 USE Intranet
 GO

 IF EXISTS ( SELECT 1
             FROM TempDB..sysobjects
             WHERE name LIKE '%#Permission%'
           )
 BEGIN
    DROP TABLE #Permission
 END

 CREATE TABLE #Permission
 (
   [Owner]       VARCHAR(128)
 , [Object]      VARCHAR(128)
 , [Grantee]     VARCHAR(128)
 , [Grantor]     VARCHAR(128)
 , [ProtectType] VARCHAR(128)
 , [Action]      VARCHAR(128)
 , [Column]      VARCHAR(128)
 )


 INSERT INTO #Permission
    EXEC sp_helprotect @username = 'Intranet'

     SELECT 'USE ' + DB_NAME() + '
     GO'

     SELECT RTRIM(UPPER(ProtectType)) + ' ' + UPPER(Action) + ' ON ' + Owner + '.' + Object + ' TO ' + Grantee + ' '
     FROM #Permission
     WHERE Action != 'CONNECT'


 DECLARE @GrantCmd NVARCHAR(MAX)

 DECLARE cur_Grant CURSOR
 FOR
     SELECT RTRIM(UPPER(ProtectType)) + ' ' + UPPER(Action) + ' ON ' + Owner + '.' + Object + ' TO ' + Grantee + ' '
     FROM #Permission
     WHERE Action != 'CONNECT'

 OPEN cur_Grant

 FETCH NEXT FROM cur_Grant
 INTO @GrantCmd

 WHILE ( @@FETCH_STATUS = 0 )
 BEGIN

    EXEC ( @GrantCmd )

    FETCH NEXT FROM cur_Grant
    INTO @GrantCmd


 END

 CLOSE cur_Grant
 DEALLOCATE cur_Grant

