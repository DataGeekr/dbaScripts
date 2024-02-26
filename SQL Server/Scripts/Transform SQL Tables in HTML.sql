USE [msdb]
GO
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spu_ATPSmartDBA_TableToHTML]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spu_ATPSmartDBA_TableToHTML]
GO
USE [msdb]
GO
/****** Object: StoredProcedure [dbo].[spu_ATPSmartDBA_TableToHTML] Script Date: 11/28/2011 10:02:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spu_ATPSmartDBA_TableToHTML]
( 
 @pc_TabNome SYSNAME 
, @pc_HtmlCodeOutput NVARCHAR(MAX) OUT 
, @pc_ColunaFiltro SYSNAME = NULL
, @ps_Filtro SQL_VARIANT = NULL
, @pb_Documentacao BIT = 0 
) 
AS
BEGIN
-- Documentação
 IF @pb_Documentacao = CONVERT(BIT, 1)
 BEGIN
PRINT ' 
 /***********************************************************************************************
 **
 ** Name.........: spu_ATPSmartDBA_TableToHTML
 **
 ** Descrição....: Procedure que realiza a conversão do Results de uma tabela para código HTML
 **
 ** Return values: N/A
 ** 
 ** Chamada por..: Manual
 **
 ** Parâmetros:
 ** Entradas Descrição
 ** ------------------ -------------------------------------------------------------------------
 ** @pc_TabNome Nome da tabela da qual os dados serão extraídos
 **
 **
 **
 ** Saídas Descrição
 ** ------------------ -------------------------------------------------------------------------
 **
 ** Script para teste: CREATE TABLE ##Temp (Id SMALLINT, Nome VARCHAR(50));
 ** GO
 ** INSERT INTO ##Temp (Id, Nome) VALUES (1, ''João'');
 **
 ** DECLARE @pc_HtmlCodeOutput NVARCHAR(400)
 ** EXEC spu_ATPSmartDBA_TableToHTML @pc_TabNome = ##Temp
 ** , @pc_HtmlCodeOutput = @pc_HtmlCodeOutput;
 **
 ** Observações..: 
 **
 ** Autor........: Rafael Rodrigues
 ** Data.........: 14/09/2011
 ************************************************************************************************
 ** Histórico de Alterações
 ************************************************************************************************
 ** Data: Autor: Descrição: Versão
 ** -------- ------------------ --------------------------------------------------------- ------
 **
 ************************************************************************************************
 ** © 2011 ATP Tecnologia e Produtos S/A. Todos os direitos reservados.
 ************************************************************************************************/ 
 '
 
 RETURN 0;
 END
SET NOCOUNT ON
 SET CONCAT_NULL_YIELDS_NULL OFF
 
 DECLARE @vn_Error INT 
 , @vn_RowCount INT 
 , @vn_TranCount INT 
 , @vn_ErrorState INT 
 , @vn_ErrorSeverity INT 
 , @vc_ErrorProcedure VARCHAR(256)
 , @vc_ErrorMsg VARCHAR(MAX); 
 
 DECLARE @vc_HtmlScript VARCHAR(MAX)
 , @vc_HtmlDynamic VARCHAR(MAX)
 , @vc_HTMLOutput VARCHAR(MAX)
 , @vc_SQLCmd NVARCHAR(MAX)
 , @vc_SQLDynParam NVARCHAR(50)
 , @vc_SelectList VARCHAR(4000)
 , @vc_ColOrder SMALLINT; 
 
 DECLARE @vc_HtmlFontFace VARCHAR(30) 
 , @vc_HtmlTableHrBgColor CHAR(7)
 , @vc_HtmlTableHrFgColor CHAR(7)
 , @vc_HtmlTableRowBgColor CHAR(7); 
 
 DECLARE @vt_TabInfo TABLE ( Name SYSNAME
 , DataType SYSNAME
 , Ordering SMALLINT IDENTITY(1,1)
 ); 
 
 -- Inicialização de variáveis
 SET @vc_ColOrder = 1; 
 SET @vc_SelectList = '';
 SET @vc_HtmlDynamic = '';
 
 -- Definição de layout HTML
 SET @vc_HtmlFontFace = 'verdana'; -- Fonte a ser impressa na tabela
 SET @vc_HtmlTableHrBgColor = '#407753'; -- Cor de background do header da tabela
 SET @vc_HtmlTableHrFgColor = '#FFFFFF'; -- Cor de foreground do header da tabela
 SET @vc_HtmlTableRowBgColor = '#FFFFFF'; -- Cor de background das linhas da tabela
 
 -- Formação da estrutura HTML
 SET @vc_HtmlScript = '<html>
 <head>
 <title></title>
 </head>
 <body>
 ';
-- Criação da tabela de Output 
 SET @vc_HtmlScript = @vc_HtmlScript + '<table style="BORDER-COLLAPSE: collapse" 
 borderColor="#111111" 
 height="40" 
 cellSpacing="0" 
 cellPadding="0" 
 width="70%" 
 border="1">
 <tr align="center">
 </tr>
 '; 
 
 ----------------------------------------------------------------------
 -- Recupera colunas da tabela para criação de cabeçalho da tabela HTML
 ----------------------------------------------------------------------
 
 IF LEFT(@pc_TabNome, 1) = '#' -- Verifica se é tabela temporária
 BEGIN
 
 INSERT INTO @vt_TabInfo ( Name, DataType )
 SELECT Col.name, Typ.name
 FROM TempDB.dbo.SysObjects AS Obj
 INNER JOIN TempDB.dbo.SysColumns AS Col 
 ON Obj.id = Col.id
 INNER JOIN TempDB.dbo.SysTypes AS Typ
 ON Col.xusertype = Typ.xusertype
 WHERE Obj.name = @pc_TabNome
 ORDER BY Col.colid 
 
 SET @vn_RowCount = @@ROWCOUNT;
END
 ELSE
 BEGIN
INSERT INTO @vt_TabInfo ( Name, DataType )
 SELECT Col.name, Typ.name
 FROM SysObjects AS Obj
 INNER JOIN SysColumns AS Col
 ON Obj.id = Col.id
 INNER JOIN SysTypes AS Typ
 ON Col.xusertype = Typ.xusertype
 WHERE ISNULL(OBJECTPROPERTY(Obj.id, 'IsMSShipped'),1) = 0 -- Não é tabela de sistema
 AND RTRIM(Obj.type) IN ('U','V','IF','TF') -- Não é diferente de User Table, View ou Table Valued Function
 AND Obj.name = @pc_TabNome
 ORDER BY Col.colid 
 
 SET @vn_RowCount = @@ROWCOUNT; 
 
 END 
 
 -- Inserção de linha para Header da tabela
 SET @vc_HtmlScript = @vc_HtmlScript + '<tr align="center">'; 
 
 ---------------------------------------------------------------------------------------
 -- Formação das colunas da tabela e consulta de dados a serem inputados na tabela HTML
 -- Neste momento:
 -- 1º linha ( @vc_HtmlScript ) -> monta o cabeçalho da tabela HTML
 -- 2º linha ( @vc_HtmlDynamic ) -> monta a consulta com tags HTML
 ---------------------------------------------------------------------------------------
WHILE @vn_RowCount >= @vc_ColOrder
 BEGIN
 SELECT @vc_HtmlScript = @vc_HtmlScript + '<td nowrap height="27" bgColor="' + @vc_HtmlTableHrBgColor + '"><font face="' + @vc_HtmlFontFace + '" color="' + @vc_HtmlTableHrFgColor + '" size="1">' + Name + '</font></td>' 
 , @vc_HtmlDynamic = @vc_HtmlDynamic + CASE WHEN @vc_ColOrder = 1
 THEN '''<tr>' 
 ELSE ''''
 END
 + '<td nowrap height="27" bgColor="' + @vc_HtmlTableRowBgColor + '"><font face="' + @vc_HtmlFontFace + '" size="1">'' + ISNULL(' 
 + CASE WHEN DataType LIKE '%int%'
 OR DataType IN ('numeric', 'decimal', 'money')
 THEN ' CONVERT(VARCHAR(20), ' + Name + ')'
 WHEN DataType IN ('bit')
 THEN ' CONVERT(CHAR(1), ' + Name + ')' 
 WHEN DataType LIKE '%date%'
 THEN ' CONVERT(CHAR(10), ' + Name + ', 103)'
 ELSE Name
 END 
 + ', '''') + ''</font></td>''' 
 + CASE WHEN @vn_RowCount > @vc_ColOrder 
 THEN ' + '
 ELSE ''
 END
 , @vc_SelectList = @vc_SelectList + Name + CASE WHEN @vn_RowCount > @vc_ColOrder 
 THEN ', '
 ELSE ''
 END
 FROM @vt_TabInfo
 WHERE Ordering = @vc_ColOrder; 
 
 SET @vc_ColOrder = @vc_ColOrder + 1;
 
 END 
 
 SET @vc_HtmlDynamic = @vc_HtmlDynamic + ' + ''</tr>''';
 
 -- Fechamento e Inclusão de nova linha para Header da tabela
 SET @vc_HtmlScript = @vc_HtmlScript + '</tr>'; 
 
 SET @vc_SQLCmd = N'SET CONCAT_NULL_YIELDS_NULL OFF
 SELECT @vc_HTMLOutput = @vc_HTMLOutput + '
 + @vc_HtmlDynamic + ' '
 + 'FROM ' + @pc_TabNome;
 
-- Realiza filtro de pesquisa na consulta caso seja necessário
 IF @pc_ColunaFiltro IS NOT NULL
 BEGIN 
 
 SET @vc_SQLCmd = @vc_SQLCmd + ' WHERE ' + @pc_ColunaFiltro + ' = ''' + CONVERT(VARCHAR(MAX), @ps_Filtro) + ''';';
 
 END 
 
 SET @vc_SQLDynParam = N'@vc_HTMLOutput NVARCHAR(MAX) OUTPUT';
EXEC Master.dbo.sp_ExecuteSql @vc_SQLCmd, @vc_SQLDynParam, @vc_HTMLOutput = @vc_HTMLOutput OUTPUT;
 
 -- Finalização de Parâmetros 
 SET @vc_HtmlScript = @vc_HtmlScript 
 + @vc_HTMLOutput
 + '</body>
 </html> 
 ';
-- Carga de variável de Output 
 SET @pc_HtmlCodeOutput = @vc_HtmlScript; 
 
END

GO