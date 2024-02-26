 
CREATE PROCEDURE dbo.spu_GeraInsert
@pc_DataBaseDestino VARCHAR(30) , -- Nome do Database a ser impresso nos INSERT INTO
@pc_Owner VARCHAR(3) , -- Nome do Owner a ser impresso nos INSERT INTO
@pc_table VARCHAR(100) , -- Nome da Tabela de base para geração dos dados em INSERT INTO
@vc_Where VARCHAR(500) -- Cláusula de filtragem dos dados a serem gerados nos INSERT INTO
AS
--'dbSct', 'dbo', 'objeto' , ''
-- exemplo:
--SET @pc_DataBaseDestino = 'dbImagonWriter'
--SET @pc_Owner = 'dbo' 
--SET @pc_table = 'FormularioCampo' 
--SET @vc_Where = 'formularioNum = ''21.1783.X.X'' order by Sequencia'
BEGIN
 
 SET NOCOUNT ON
DECLARE @vc_Coluna VARCHAR(8000) ,
 @vc_Values VARCHAR(8000) ,
 @vc_Query VARCHAR(8000) ,
 @vc_Nome_Coluna VARCHAR(100) ,
 @vc_Tipo_Coluna VARCHAR(100) ,
 @vc_virgula VARCHAR(1) ,
 @vc_buffer VARCHAR(8000)
DECLARE c_Coluna CURSOR FOR
 SELECT COLUMN_NAME ,
 DATA_TYPE 
 FROM INFORMATION_SCHEMA.COLUMNS 
 WHERE TABLE_SCHEMA = @pc_Owner AND
 TABLE_NAME = @pc_Table 
 ORDER BY ORDINAL_POSITION
SET @vc_Where = CASE WHEN @vc_Where IS NULL THEN '' ELSE @vc_Where END
 SET @vc_Coluna = 'SELECT ' + CHAR(39) + 'INSERT INTO ' + @pc_DataBaseDestino + '.' + @pc_Owner + '.' + @pc_Table + ' ( ' 
 SET @vc_Values = ' ) VALUES( ' + CHAR(39) 
 SET @vc_virgula = ''
OPEN c_Coluna
FETCH
 FROM c_Coluna
 INTO @vc_Nome_Coluna ,
 @vc_Tipo_Coluna
WHILE @@FETCH_STATUS = 0
BEGIN
SET @vc_Coluna = @vc_coluna + @vc_virgula + @vc_Nome_Coluna
IF @vc_virgula <> ''
 
 BEGIN
SET @vc_Values = @vc_Values + CHAR(39) + ', ' + CHAR(39)
END
IF @vc_Tipo_coluna IN ( 'char','nchar','varchar','nvarchar' )
BEGIN
 
 SET @vc_Values = @vc_Values + ' + CASE WHEN ' + @vc_Nome_Coluna + ' IS NULL THEN ' + CHAR(39) + CHAR(39) + ' ELSE CHAR(39) END + ISNULL( CONVERT(VARCHAR(500),' + @vc_Nome_Coluna + ') , '+CHAR(39) + 'NULL' + CHAR(39)+' ) + CASE WHEN ' + @vc_Nome_Coluna + ' IS NULL THEN ' + CHAR(39) + CHAR(39) + ' ELSE CHAR(39) END + '
END
 
 ELSE
 
 BEGIN
IF @vc_Tipo_coluna IN ( 'datetime','smalldateTime' )
BEGIN
 
 SET @vc_Values = @vc_Values + ' + CASE WHEN ' + @vc_Nome_Coluna + ' IS NULL THEN ' + CHAR(39) + CHAR(39) + ' ELSE CHAR(39) END + ISNULL( CONVERT(VARCHAR(30),' + @vc_Nome_Coluna + ', 121 ), ' + CHAR(39)+ 'NULL' + CHAR(39) + ' ) + CASE WHEN ' + @vc_Nome_Coluna + ' IS NULL THEN ' + CHAR(39) + CHAR(39) + ' ELSE CHAR(39) END + '
 
 END
ELSE
BEGIN
SET @vc_Values = @vc_Values + ' + ISNULL( CONVERT(VARCHAR(30),' + @vc_Nome_Coluna + '), ' + CHAR(39) + 'NULL' + CHAR(39) + ' ) + '
END
END

 SET @vc_virgula = ', '
FETCH
 FROM c_Coluna
 INTO @vc_Nome_Coluna ,
 @vc_Tipo_Coluna
END
 
CLOSE c_Coluna
DEALLOCATE c_Coluna

 SET @vc_Buffer = @vc_Values + CHAR(39) + ' ) ' + CHAR(39) + ' FROM ' + @pc_Owner + '.' + @pc_Table + ' ' +
 CASE WHEN @vc_Where = '' THEN '' ELSE ' WHERE ' + @vc_Where END
EXEC( @vc_Coluna + @vc_buffer )
END