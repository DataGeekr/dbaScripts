USE [MonitorDBA]
GO

IF NOT EXISTS( SELECT 1
               FROM INFORMATION_SCHEMA.ROUTINES
               WHERE ROUTINE_NAME = 'spu_ServerBackupRoutine' 
               AND ROUTINE_SCHEMA = 'dbo'
               AND ROUTINE_TYPE = 'PROCEDURE'
               )
BEGIN
   EXEC ('CREATE PROCEDURE dbo.[spu_ServerBackupRoutine] AS SELECT 1' );
END            
GO

ALTER PROCEDURE [dbo].[spu_ServerBackupRoutine]
(
  @pc_DbNome       SYSNAME       = NULL   -- < NULL > Backup de todos os databases
, @pc_Diretorio    NVARCHAR(255) = NULL   -- Path Absoluto : D:\MSSQL\Backup
, @pc_TipoBackup   NCHAR(1)       = 'F'    -- < F > Full / < D > Diferencial / < L > Log / < S > System
, @pb_ApenasCopia  BIT           = 0      -- < 1 > Apenas cópia / < 0 > Mantêm estratégia de Backup
, @pb_Compressao   BIT           = 0      -- < 1 > Utiliza Backup Compression - SQL2005 Sp2+ Apenas / < 0 > Backup normal
, @pb_Documentacao BIT           = 0      -- < 1 > Lista Documentação / < 0 > Execução normal da procedure
, @pb_EnviaErro    BIT           = 0      -- < 1 > Envia Email de Erro / < 0 > Não envia
, @pn_BufferCount  TINYINT       = 0      -- < 0 > Default
)
AS
BEGIN

   -- Documentação
   IF @pb_Documentacao = CONVERT (BIT, 1)
   BEGIN

      PRINT '
      /***********************************************************************************************
      **
      **  Name.........: spu_ServerBackupRoutine
      **
      **  Descrição....: Procedure que realiza a execução das rotinas de backup do servidor.
      **
      **  Return values: N/A
      **
      **  Chamada por..: Job / Manual
      **
      **  Parâmetros:
      **  Entradas           Descrição
      **  ------------------ -------------------------------------------------------------------------
      **  @pc_DbNome         Nome do banco de dados a ser realizado backup
      **  @pc_Diretorio      Diretório Local de Armazenamento do Arquivo
      **  @pc_DirRemoto      Diretório Remoto para Cópia dos Arquivos                                                                                  
      **  @pc_TipoBackup     Tipo de Backup < F > Full / < D > Diferencial / < L > Log
      **  @pb_ApenasCopia    Gera cópia do backup sem alterar a sequência de backups
      **  @pb_Compressao     Gera backup comprimido
      **  @pb_Documentacao   Lista a documentação da procedure
      **  @pb_EnviaErro      Gera relatório em HTML de execução / erro
      **  @pn_BufferCount    Define quantidade de I/O Buffers a serem usados no processo de backup
      **
      **
      **  Saídas             Descrição
      **  ------------------ -------------------------------------------------------------------------
      **
      **  Script para teste: EXEC dbo.spu_ServerBackupRoutine
      **                         @pc_DbNome     = ''Database Name'',
      **                         @pc_Diretorio   = ''G:\Program Files\...\SQLLAB01\BACKUP'',
      **                         @pc_DirRemoto  = ''\\10.161.2.1\D$'',
      **                         @pc_TipoBackup = ''F''
      **
      **  Observações..: Para execução de backups comprimidos, é necessário definir no servidor
      **                 a opção default para o parâmetro: backup compression default
      **
      **                 [EXEC] sp_configure ''backup compression default'', 1
      **                 Go
      **                 Reconfigure With Override
      **
      **  Autor........: Rafael Rodrigues
      **  Data.........: 01/08/2011
      ************************************************************************************************
      **  Histórico de Alterações
      ************************************************************************************************
      **  Data:    Autor:             Descrição:                                                Versão
      **  -------- ------------------ --------------------------------------------------------- ------
      **  21/11/11 Rafael Rodrigues   Inclusão de output de falha de backup                     1.0.01
      **
      ************************************************************************************************
      **             © Conselho Federal da OAB .Todos os direitos reservados.
      ************************************************************************************************/
      '
  
      RETURN 0;
   END  

   SET NOCOUNT ON

   DECLARE @vn_Error             INT
         , @vn_RowCount          INT
         , @vn_TranCount         INT
         , @vn_ErrorState        INT
         , @vn_ErrorSeverity     INT
         , @vc_ErrorProcedure    VARCHAR(256)
         , @vc_ErrorMsg          VARCHAR(MAX);
     
   DECLARE @vc_DbNome         SYSNAME
         , @vc_ServerName     SYSNAME
         , @vc_Assunto        VARCHAR(100)
         , @vc_HtmlTableStyle VARCHAR(MAX)
         , @vc_HtmlThStyle    VARCHAR(MAX)
         , @vc_HtmlTdStyle    VARCHAR(MAX);          

   DECLARE @vc_SQLServerVersion CHAR(12 );

   DECLARE @vc_NomeArquivo       NVARCHAR(255 )
         , @vc_PathNomeArquivo   NVARCHAR(255)
         , @vc_PathDiretorio     NVARCHAR(255)
         , @vc_CmdBackup         NVARCHAR(500)
         , @vc_HtmlCodeOutput    NVARCHAR(MAX)
         , @vb_BackupValidado    CHAR(3)
         , @vb_Compressao        BIT
         , @vn_IndExistDiretorio INT
         , @vn_RetornoExecCmd    INT
         , @vc_DataCriacao       CHAR( 13)
         , @vd_DataHoraInicio    DATETIME;

   -- Criação da tabela de controle de execução de backup
    DECLARE @vt_DbBackup TABLE
    ( DbNome          SYSNAME
    , Executado       BIT DEFAULT (0)
    , DataHoraInicio  DATETIME
    , DataHoraTermino DATETIME
    , Validado        CHAR(3 ) DEFAULT ('')
    , Erro            VARCHAR(4000 ) NULL
    , SPID            INT DEFAULT (@@SPID)
    );

   -- Verificação de versão do SQL Server
   SELECT @vc_SQLServerVersion = CONVERT (CHAR( 12), SERVERPROPERTY('ProductVersion' ));

   -- Definição de variáveis
   SELECT @vc_Assunto = 'OAB MonitorDBA - Alerta de falha de execução de backup - SQL Server ( '+ CONVERT ( VARCHAR (50), SERVERPROPERTY('ServerName' )) + ' )'
   SELECT @vc_ServerName = REPLACE (@@SERVERNAME, '\', '-');

   -- Montagem da Data Pertinente à criação do arquivo
   SET @vc_DataCriacao = CONVERT ( CHAR (8), GETDATE(), 112 ) + '-' +
                         CONVERT( VARCHAR(2 ),( REPLICATE ( 0, ( 2 - LEN ( DATENAME ( HOUR, GETDATE() ) ) ) ) ) ) + DATENAME ( HOUR , GETDATE () ) +
                         CONVERT( VARCHAR(2 ),( REPLICATE ( 0, ( 2 - LEN ( DATENAME ( MINUTE, GETDATE() ) ) ) ) ) ) + DATENAME ( MINUTE , GETDATE () )

   -- Estrutura do CSS - Formatação HTML
   SELECT @vc_HtmlTableStyle = valor FROM MonitorDBA.dbo.EstiloHTML WHERE atributo = 'table' ;

   SELECT @vc_HtmlThStyle = valor FROM MonitorDBA.dbo.EstiloHTML WHERE atributo = 'th';

   SELECT @vc_HtmlTdStyle = valor FROM MonitorDBA.dbo.EstiloHTML WHERE atributo = 'td';

   ---------------------
   -- Validação de Dados
   ---------------------

   -- Verificação de diretório
   IF NOT ( @pc_Diretorio LIKE '_:'
       OR  @pc_Diretorio LIKE '_:\%'
       OR  @pc_Diretorio LIKE '\\%\%'
          )
       OR ISNULL (@pc_Diretorio, '' ) = ''
       OR LEFT( @pc_Diretorio, 1 ) = ' '
       OR RIGHT( @pc_Diretorio, 1 ) = ' '
   BEGIN
      SET @vc_ErrorMsg = 'Valor definido para o parâmetro @pc_Diretorio não é suportado.' + CHAR(13 ) + CHAR( 10) + ' ' ;
      SET @vn_Error = @@ERROR;
      RAISERROR(@vc_ErrorMsg ,16 , 1) WITH NOWAIT ;
      RETURN @vn_Error;
   END

   SET @vc_PathDiretorio = REPLACE (@pc_Diretorio + '\', '\\', '\') + '\nul'
   EXEC Master.dbo.xp_FileExist @vc_PathDiretorio, @vn_IndExistDiretorio OUTPUT;
                   
   IF @vn_IndExistDiretorio = 0
   BEGIN
      -- Se o diretório não existir, utiliza o configurado na instalação
      EXECUTE [master].dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer' , N'BackupDirectory' , @pc_Diretorio OUTPUT
   END

   -- Compressão de backup
   SELECT @vb_Compressao = CASE WHEN @pb_Compressao = CONVERT (bit, 1)   -- Compressão solicitada como parâmetro
                                 OR  EXISTS (SELECT 1 -- Compressão configurada e versão suportada
                                             FROM sys.Configurations
                                             WHERE name = 'backup compression default'
                                             AND   value_in_use = 1
                                            )
                                THEN 1
                                ELSE 0
                           END;
                       
   ---------------------------------
   -- Verifica parâmetros informados
   ---------------------------------
   IF ISNULL(@pc_TipoBackup , '' ) NOT IN ('F' , 'D' , 'L' , 'S' )
   BEGIN
      SET @vc_ErrorMsg = 'Valor definido para o parâmetro @pc_TipoBackup não é suportado.' + CHAR(13 ) + CHAR( 10) + ' ' ;
      SET @vn_Error = @@ERROR;
      RAISERROR(@vc_ErrorMsg ,16 , 1) WITH NOWAIT ;
      RETURN @vn_Error;
  END


   IF  @pc_TipoBackup NOT IN ('F' , 'S' )
   AND @pb_ApenasCopia = CONVERT (BIT, 1)
   BEGIN
      SET @vc_ErrorMsg = 'Parâmetro COPY_ONLY é somente permitido para execução do backup full.' + CHAR(13 ) + CHAR( 10) + ' ' ;
      SET @vn_Error = @@ERROR;
      RAISERROR(@vc_ErrorMsg ,16 , 1) WITH NOWAIT ;
      RETURN @vn_Error;
   END

    -----------------------------------
   -- Seleção de Databases para Backup
   -----------------------------------

   IF ISNULL(@pc_DbNome , '' ) != ''
   BEGIN

      IF ( SELECT state_desc
           FROM sys.Databases
           WHERE name = @pc_DbNome
         ) = 'ONLINE'
      BEGIN

         INSERT INTO @vt_DbBackup ( DbNome ) VALUES ( @pc_DbNome );
  
      END
      ELSE
      BEGIN


         SET @vc_ErrorMsg = 'O banco de dados %s precisa estar ONLINE para execução do backup.' + CHAR (13) + CHAR(10 ) + ' ';
         SET @vn_Error = @@ERROR;
         RAISERROR(@vc_ErrorMsg ,16 , 1, @pc_DbNome ) WITH NOWAIT;
         RETURN @vn_Error;   
  
      END
  
   END
   ELSE   -- Backup de todos os databases
   BEGIN

      INSERT INTO @vt_DbBackup ( DbNome )
         SELECT name
         FROM sys  .Databases
         WHERE state_desc = 'ONLINE'
         AND   (( @pc_TipoBackup = 'S'
         AND      name IN ('master' ,'model','msdb')
                )
         OR     ( @pc_TipoBackup IN ( 'F' , 'D' )
         AND      name NOT IN ('master','model','msdb' , 'tempdb' )
                )
         OR     ( @pc_TipoBackup  = 'L'
         AND      recovery_model_desc IN ('FULL', 'BULK_LOGGED')
         AND      name NOT IN ('master','model','msdb' , 'tempdb' )     
               ));
     
   END

   ----------------------------------------------------
   -- Loop para realização do backup para cada database
   ----------------------------------------------------

   WHILE EXISTS ( SELECT 1
                  FROM @vt_DbBackup
                  WHERE Executado = CONVERT( BIT, 0 )
                  AND   SPID      = @@SPID
                )
   BEGIN

      -- Limpa variáveis de controle de validação de backup
      SET @vb_BackupValidado = 'Não';
      SET @vc_ErrorMsg       = NULL;

      -- Recupera o primeiro database a ser processado
      SELECT TOP 1 @vc_DbNome = DbNome
      FROM @vt_DbBackup
      WHERE Executado = CONVERT( BIT, 0 )
      AND   SPID      = @@SPID;
  
      -- Verifica se o diretório de backup para o database existe, e se não, o mesmo é criado
      SET @vc_PathDiretorio = REPLACE( @pc_Diretorio + '\' + @vc_DbNome,'\\' ,'\') + '\nul';
      EXECUTE master  .dbo.xp_create_subdir @vc_PathDiretorio ;

      -----------------------------------------------------------------
      -- Montagem da estrutura final de armazenamento - Nome do Arquivo
      -----------------------------------------------------------------
  
      SELECT @vc_NomeArquivo = @vc_ServerName + '_' +
                             + @vc_DbNome + '_' +
                               CASE WHEN @pc_TipoBackup IN ('F', 'S') -- Full
                                    THEN 'db'
                                    WHEN @pc_TipoBackup = 'D' -- Diferencial
                                    THEN 'dif'
                                    WHEN @pc_TipoBackup = 'L' -- Log
                                    THEN 'log'
                               END + '_' +
                               CASE WHEN @pb_ApenasCopia = CONVERT(BIT , 1)    
                                    THEN 'CopyOnly_'
                                    ELSE ''
                               END +
                               @vc_DataCriacao + '.' +
                               CASE WHEN @pc_TipoBackup IN ('F', 'S') -- Full
                                      OR @pb_ApenasCopia = CONVERT( BIT, 1 ) -- Cópia
                                    THEN 'BAK'
                                    WHEN @pc_TipoBackup = 'D' -- Diferencial
                                    THEN 'BKD'
                                    WHEN @pc_TipoBackup = 'L' -- Log
                                    THEN 'TRN'
                               END;  
                                 
      -------------------------------                           
      -- Criação do Comando de Backup
      -------------------------------

      SET @vc_PathNomeArquivo = REPLACE( @pc_Diretorio + '\' + @vc_DbNome,'\\' ,'\') + '\' + @vc_NomeArquivo ;
  
      SELECT @vc_CmdBackup = 'BACKUP ' +
                              CASE @pc_TipoBackup WHEN 'L'                  -- Tipo de Backup
                                                  THEN 'LOG '
                                                  ELSE 'DATABASE '
                              END +
                              @vc_DbNome + ' ' +                             -- Nome do Banco de Dados
                              'TO DISK = ''' + @vc_PathNomeArquivo + ''' ' + -- Nome completo do arquivo com path
                              'WITH NAME = ''' + 'Backup '                   -- Nome Descritivo do Backup
                                               + CASE WHEN @pc_TipoBackup IN ( 'F', 'S') -- Full
                                                      THEN 'Full '
                                                      WHEN @pc_TipoBackup = 'D' -- Diferencial
                                                      THEN 'Diferencial '
                                                      WHEN @pc_TipoBackup = 'L' -- Log
                                                      THEN 'Log '
                                                      WHEN @pb_ApenasCopia = CONVERT(BIT , 1)    
                                                      THEN 'Copy Only '
                                                 END + @vc_DbNome + ' - ' + CONVERT( CHAR(19 ), GETDATE (), 120 ) + '''' +
                              CASE WHEN @pc_TipoBackup = 'D'             -- Tipo de Backup < Complemento >
                                   THEN ', DIFFERENTIAL'
                                   WHEN @pb_ApenasCopia = CONVERT( BIT, 1 )
                                   THEN ', COPY_ONLY'
                                   ELSE ''
                              END +
                              CASE WHEN @vc_SQLServerVersion LIKE '%10.0%'  -- SQL Server 2008
                                     OR @vc_SQLServerVersion LIKE '%10.5%'  -- SQL Server 2008 R2
                                     OR @vc_SQLServerVersion LIKE '%11.0%'  -- SQL Server 2012
                                   THEN CASE WHEN @vb_Compressao = CONVERT ( BIT , 1 )
                                             THEN ', COMPRESSION'
                                             ELSE ', NO_COMPRESSION'
                                        END
                                   ELSE ''
                              END +
                              CASE WHEN @vc_SQLServerVersion LIKE '%10.0%'  -- SQL Server 2008
                                     OR @vc_SQLServerVersion LIKE '%10.5%'  -- SQL Server 2008 R2
                                     OR @vc_SQLServerVersion LIKE '%11.0%'  -- SQL Server 2012
                                   THEN CASE WHEN @vb_Compressao = CONVERT ( BIT , 1 )
                                             THEN ', CHECKSUM, STOP_ON_ERROR'
                                             ELSE ''
                                        END
                                   ELSE ''
                              END +
                              CASE WHEN @vc_SQLServerVersion LIKE '%10.0%'  -- SQL Server 2008
                                     OR @vc_SQLServerVersion LIKE '%10.5%'  -- SQL Server 2008 R2
                                     OR @vc_SQLServerVersion LIKE '%11.0%'  -- SQL Server 2012
                                   THEN CASE WHEN @pn_BufferCount > 0
                                             THEN ', BUFFERCOUNT = ' + CONVERT( CHAR(3 ), @pn_BufferCount)
                                             ELSE ''
                        END
                                   ELSE ''
                              END;

      -------------------------------------------
      -- Execução do Comando de criação de Backup
      -------------------------------------------

      BEGIN TRY

         SET @vd_DataHoraInicio = GETDATE();
         EXEC @vn_RetornoExecCmd = Master.dbo.sp_ExecuteSql @vc_CmdBackup;

      END TRY
      BEGIN CATCH
  
         SET @vn_Error    = @@ERROR;
         SET @vc_ErrorMsg = ERROR_MESSAGE();
         GOTO ErrorHandle;

      END CATCH

      -----------------------------
      -- Validação do Backup criado
      -----------------------------

      BEGIN TRY

         SET @vc_PathNomeArquivo = @vc_PathNomeArquivo

         RESTORE VERIFYONLY
         FROM DISK = @vc_PathNomeArquivo
         WITH CHECKSUM ;
  
         SET @vb_BackupValidado = 'Sim';


      END TRY
      BEGIN CATCH

         SET @vc_ErrorMsg = ERROR_MESSAGE();
         GOTO ErrorHandle;

      END CATCH

      ----------------------------------------------------
      -- Alimenta tabela de controle de execução de backup
      ----------------------------------------------------
  
      UPDATE @vt_DbBackup
         SET Executado       = CONVERT(BIT , 1)
           , DataHoraInicio  = @vd_DataHoraInicio
           , DataHoraTermino = GETDATE()
           , Validado        = @vb_BackupValidado
      WHERE DbNome = @vc_DbNome
      AND   SPID   = @@SPID;
  
      GOTO NextRow;
  
      ErrorHandle:
  
         UPDATE @vt_DbBackup
            SET Executado       = CONVERT(BIT , 1)
              , DataHoraInicio  = @vd_DataHoraInicio
              , DataHoraTermino = GETDATE()
              , Erro            = @vc_ErrorMsg
              , Validado        = @vb_BackupValidado
         WHERE DbNome = @vc_DbNome
         AND   SPID   = @@SPID;
     
      NextRow:
   
   END

   -------------------------------------------------------------
   -- Alimenta tabela de controle de execução de backup
   -------------------------------------------------------------
   IF @pb_EnviaErro = 1
   AND EXISTS( SELECT 1
               FROM @vt_DbBackup
               WHERE Erro IS NOT NULL
               AND   SPID = @@SPID
             )
   BEGIN

      -- Envia e-mail listando os databases cujo backup não foi realizado
      DELETE FROM @vt_DbBackup
      WHERE Erro IS NULL
      AND   SPID = @@SPID;

      -- Formata o retorno do e-mail para HTML
      SET @vc_HtmlCodeOutput =                                                       
         '<font face="Verdana" size="3">Falhas durante a execução da rotina de Backup</font>
         <br>
         <br>
         <table width="850" ' + @vc_HtmlTableStyle + '  height="50">
         <tr align="center">
            <th width="20%" ' + @vc_HtmlThStyle + ' ><b>
               <b><font face="Verdana" size="1" color="#FFFFFF">Banco de Dados</font></b>
            </th>
            <th width="20%" ' + @vc_HtmlThStyle + '><b>
               <b><font face="Verdana" size="1" color="#FFFFFF">Data e Hora do Início</font></b>
            </th>
            <th width="10%" ' + @vc_HtmlThStyle + '><b>
               <b><font face="Verdana" size="1" color="#FFFFFF">Backup validado</font></b>
            </th>        
            <th width="50%" ' + @vc_HtmlThStyle + '><b>
               <b><font face="Verdana" size="1" color="#FFFFFF">Erro</font></b>
            </th>        
         </tr>'


      SELECT @vc_HtmlCodeOutput = @vc_HtmlCodeOutput +
     '<tr><td ' + @vc_HtmlTdStyle + 'height="50"><font face="Verdana" size="1">' + ISNULL( DbNome , '' ) +'</font></td>' +
     '<td ' + @vc_HtmlTdStyle + 'height="50"><font face="Verdana" size="1">' + CONVERT( VARCHAR(23 ), DataHoraInicio, 120) + '</font></td>' +
     '<td ' + @vc_HtmlTdStyle + 'height="50"><font face="Verdana" size="1">' + ISNULL( Validado , '' )  + '</font></td>' +
     '<td ' + @vc_HtmlTdStyle + 'height="50"><font face="Verdana" size="1">' + ISNULL( Erro , '' ) +'</font></td>'
      FROM @vt_DbBackup
      WHERE Erro IS NOT NULL;


      -- Rodapé do E-mail  
      SELECT @vc_HtmlCodeOutput = @vc_HtmlCodeOutput + '</table>' +
     '<p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>
     <hr color="#000000" size="1">
        <p><font face="Verdana" size="2"><b>Responsável pelo Servidor: </b>Rafael Rodrigues</font></p>
        <p style="margin-top: 0; margin-bottom: 0"><font face="Verdana" size="2">DBA - Conselho Federal da OAB</font></p>
     <p>&nbsp;</p>'


      EXEC msdb.dbo.sp_send_dbmail
           @profile_name = 'Conselho Federal da OAB'
         , @recipients   = 'rafael.rodrigues@oab.org.br'
         , @body_format  = 'HTML'
         , @subject      = @vc_Assunto
         , @body         = @vc_HtmlCodeOutput ;

    END

   ------------------------------------------------------------------
   -- Elimina os dados da tabela de controle após a execução
   -------------------------------------------------------------------
   IF EXISTS( SELECT 1
              FROM @vt_DbBackup
              WHERE SPID != @@SPID
            )
   BEGIN

      -- Limpa a tabela temporária para execução posterior/concorrente
      DELETE FROM @vt_DbBackup
      WHERE SPID = @@SPID;            
  
   END

END
  