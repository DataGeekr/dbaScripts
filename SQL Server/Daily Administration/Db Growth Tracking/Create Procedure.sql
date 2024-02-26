/* Criação da Procedure */ 

USE MonitorDBA
GO
IF NOT EXISTS( SELECT 1
               FROM INFORMATION_SCHEMA .ROUTINES
               WHERE ROUTINE_NAME = 'spu_GatherDatabaseGrowth' 
               AND ROUTINE_SCHEMA = 'dbo'
               AND ROUTINE_TYPE = 'PROCEDURE'
               )
BEGIN
   EXEC ('CREATE PROCEDURE [dbo].[spu_GatherDatabaseGrowth] AS SELECT 1' );
END            
GO

ALTER PROCEDURE [dbo].[spu_GatherDatabaseGrowth]
(
 @Documentacao INT = 0
)
AS
BEGIN
   /*
   # Visualização da Documentação da Procedure
   */
   IF @Documentacao = CONVERT (BIT, 1)  
   BEGIN 
  
       PRINT '  
       /***********************************************************************************************  
       **  
       **  Name         : spu_GatherDatabaseGrowth
       **
       **  Database     : MonitorDBA
       **  
       **  Descrição....:
       **  
       **  Return values: N/A  
       **   
       **  Chamada por..:
       **  
       **  Parâmetros:  
       **  Entradas           Descrição  
       **  ------------------ -------------------------------------------------------------------------  
       **  
       **  
       **  Saídas             Descrição  
       **  ------------------ -------------------------------------------------------------------------  
       **  
       **  
       **  
       **  Autor........: Rafael Rodrigues
       **  Data.........: 16/12/2013
       **
       ************************************************************************************************  
       **  Histórico de Alterações  
       ************************************************************************************************  
       **  Data:    Autor:             Descrição:                                                Versão  
       **  -------- ------------------ --------------------------------------------------------- ------  
       **  
       ************************************************************************************************  
       **      © Conselho Federal da Ordem dos Advogados do Brasil. Todos os direitos reservados.  
       ************************************************************************************************/     
       '  
         
      RETURN 0;   
   END -- End. Documentação      

   SET NOCOUNT ON
  
   DECLARE @vn_Error          INT  
         , @vn_RowCount       INT  
         , @vn_TranCount      INT  
         , @vn_ErrorState     INT  
         , @vn_ErrorSeverity  INT  
         , @vc_ErrorProcedure VARCHAR(256)   
         , @vc_ErrorMsg       VARCHAR(MAX);

   DECLARE @vc_SQLCmd VARCHAR(4000 );

   -- Criação de tabela temporária para filtro e ordenação
   DECLARE @vt_DBGrowth TABLE
   ( [ServerName]    VARCHAR(100 )  NULL
   , [DatabaseName]  VARCHAR(100 )  NULL
   , [LogicalName]   SYSNAME       NOT NULL
   , [PollDate]      SMALLDATETIME NULL
   , [FileType]      VARCHAR(4 )    NULL
   , [FileSizeMB]    INT           NULL
   , [FreeSpaceMB]   INT           NULL
   , [FreeSpacePct]  VARCHAR(8 )    NULL
   , [PhysicalName]  NVARCHAR(520 ) NULL
   , [Status]        SYSNAME       NOT NULL
   , [Updateability] SYSNAME       NOT NULL
   , [RecoveryMode]  SYSNAME       NOT NULL
   );

   -- Controle de Transações
   SET @vn_TranCount = @@TRANCOUNT ;
  
   BEGIN TRY;
  
      SET @vc_SQLCmd = 'USE [?];
                        SELECT [ServerName]     = @@ServerName
                             , [DatabaseName]   = DB_NAME()
                             , [LogicalName]    = name   
                             , [PollDate]       = GETDATE()
                             , [FileType]       = type_desc
                             , [FileSizeMB]     = CAST((Size/128.0) AS INT)
                             , [FreeSpaceMB]    = CAST(Size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'') AS int)/128.0 AS INT)
                             , [FreeSpacePct]   = CAST(100 * (CAST (((size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'' ) AS INT)/128.0)/(Size/128.0)) AS DECIMAL(4,2))) AS VARCHAR(8)) + '' '' + ''%''
                             , [PhysicalName]   = physical_name
                             , [Status]         = CONVERT(sysname,DatabasePropertyEx(DB_NAME(), ''Status''))
                             , [Updateability]  = CONVERT(sysname,DatabasePropertyEx(DB_NAME(), ''Updateability''))
                             , [RecoveryMode]   = CONVERT(sysname,DatabasePropertyEx(DB_NAME(), ''Recovery''))
                        FROM sys.database_files'

      IF ( @vn_TranCount = 0 )
         BEGIN TRANSACTION ;

      BEGIN TRY

         INSERT INTO @vt_DBGrowth ( [ServerName]   
                                  , [DatabaseName] 
                                  , [LogicalName]  
                                  , [PollDate]     
                                  , [FileType]    
                                  , [FileSizeMB]   
                                  , [FreeSpaceMB]  
                                  , [FreeSpacePct] 
                                  , [PhysicalName] 
                                  , [Status]       
                                  , [Updateability]
                                  , [RecoveryMode] 
                                  )
            EXEC sp_MSForEachDB @vc_SQLCmd;

      END TRY
      BEGIN CATCH

         SET @vc_ErrorMsg = ERROR_MESSAGE();

         RAISERROR('Falha ao recuperar informações de arquivos em [spu_GatherDatabaseGrowth]. Erro: %s', 16, 1 , @vc_ErrorMsg);
        
      END CATCH
     
      INSERT INTO dbo.DatabaseGrowth ( [ServerName]   
                                     , [DatabaseName] 
                                     , [LogicalName]  
                                     , [PollDate]              
                                     , [FileType]    
                                     , [FileSizeMB]   
                                     , [FreeSpaceMB]  
                                     , [FreeSpacePct] 
                                     , [PhysicalName] 
                                     , [Status]       
                                     , [Updateability]
                                     , [RecoveryMode] 
                                     )
         SELECT [ServerName]   
              , [DatabaseName] 
              , [LogicalName]  
              , [PollDate]     
              , [FileType]    
              , [FileSizeMB]   
              , [FreeSpaceMB]  
              , [FreeSpacePct] 
              , [PhysicalName] 
              , [Status]       
              , [Updateability]
              , [RecoveryMode] 
         FROM @vt_DBGrowth
         ORDER BY ServerName, DatabaseName ;

   END TRY
 
   BEGIN CATCH
 
      -- Recupera informações originais do erro
      SELECT @vc_ErrorMsg       = ERROR_MESSAGE()
           , @vn_ErrorSeverity  = ERROR_SEVERITY()
           , @vn_ErrorState     = ERROR_STATE()
           , @vc_ErrorProcedure = ERROR_PROCEDURE();
 
      -- Tratamento Para ErrorState, retorna a procedure de execução em junção com o erro.
      SELECT @vc_ErrorMsg = CASE WHEN @vn_ErrorState = 1
                                 THEN @vc_ErrorMsg + CHAR( 13) + 'O erro ocorreu em ' + @vc_ErrorProcedure + ' ( ' + LTRIM( RTRIM( STR( ERROR_LINE() ) ) ) + ' )'
                                 WHEN @vn_ErrorState = 3
                                 THEN @vc_ErrorProcedure + ' - ' + @vc_ErrorMsg
                                 ELSE @vc_ErrorMsg
                            END;
 
      RAISERROR ( @vc_ErrorMsg
                , @vn_ErrorSeverity
                , @vn_ErrorState );
 
        IF @vn_TranCount  = 0 AND  -- Transação feita no escopo da procedure
            XACT_STATE() != 0      -- Transação ativa existente
        BEGIN
            ROLLBACK TRANSACTION ;
        END
 
   END CATCH
    
   IF @vn_TranCount  = 0 AND -- Transação feita no escopo da procedure
      XACT_STATE()  = 1     -- Transação com sucesso de execução
   BEGIN
      COMMIT TRANSACTION ;
   END
 
END
GO
  