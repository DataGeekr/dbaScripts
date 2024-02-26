IF EXISTS( SELECT 1 FROM sys .server_triggers WHERE name = 'tgs_ServerLogon_SSMS' )
BEGIN
     DROP TRIGGER [tgs_ServerLogon_SSMS] ON ALL SERVER
END
GO
CREATE TRIGGER [tgs_ServerLogon_SSMS]
ON ALL SERVER
FOR LOGON
AS
BEGIN

     DECLARE @vc_ProgramName NVARCHAR (256)
           , @vc_LoginName   NVARCHAR (256) = ORIGINAL_LOGIN();

     /*
     # Cria a lista de usu·rios que ter„o acesso pelo Microsoft SQL Server Management Studio
     */
     CREATE TABLE #allowedLogins
     (
       LoginName VARCHAR(128 )
     );

     INSERT INTO #allowedLogins
               ( LoginName )
     VALUES -- Inserir usu·rios liberados aqui
          ('sa'),
          ('RSB\totvs.migracao1'),
          ('rafael.rodrigues'),
          ('RSB\rafael.rodrigues'),
          ('RSB\luiz.nobrega'),
          ('RSB\ruann.lima' ),
          ('RSB\felipe.silva' ),
          ('RSB\juscelio.reis');

     /*
     # Recupera dados do processo do usu·rio
     */
     SELECT @vc_ProgramName = program_name
     FROM sys .dm_exec_sessions
     WHERE session_id = @@SPID;

     IF ( @vc_ProgramName LIKE '%Management%Studio%' /* Microsoft SQL Server Management Studio  */
     OR   @vc_ProgramName LIKE '%SQL%Data%Tools%'    /* Microsoft SQL Server Data Tools, T-SQL Editor */
        )
     AND NOT EXISTS ( SELECT 1
                      FROM #allowedLogins
                      WHERE LoginName = @vc_LoginName
                    )
    BEGIN
        RAISERROR('O acesso ao Microsoft SQL Server Management Studio não está permitido para este usuário [%s].', 16, 1 , @vc_LoginName);
        ROLLBACK;
    END
END;







  