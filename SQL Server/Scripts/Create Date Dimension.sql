IF EXISTS( SELECT 1
           FROM INFORMATION_SCHEMA .TABLES
           WHERE TABLE_NAME = 'DimensaoData'
         )
BEGIN
   DROP TABLE dbo. DimensaoData
END  
GO

CREATE TABLE dbo.DimensaoData
(
  ChaveData         INT
, Data              DATE
, DataPTBR          CHAR( 10)
, NumeroDiaDaSemana TINYINT
, NomeDiaDaSemana   VARCHAR (13)
, DiaAbrevDaSemana  VARCHAR (5)
, NumeroDiaDoMes    TINYINT
, NumeroDiaDoAno    SMALLINT
, NumeroSemanaDoAno TINYINT
, NomeDoMes         VARCHAR( 10)
, NumeroMesDoAno    TINYINT
, Trimestre         TINYINT
, AnoCalendario     SMALLINT
)

SET NOCOUNT ON

DECLARE @t SMALLINT
DECLARE @ChaveData INT
DECLARE @Data DATETIME
DECLARE @DataPTBR CHAR (10)
DECLARE @NumDiaSemana TINYINT
DECLARE @NomeDiaSemana VARCHAR (13)
DECLARE @DiaAbrev VARCHAR (5)
DECLARE @NumDiaMes TINYINT
DECLARE @nomeDiaAno SMALLINT
DECLARE @semanaAno TINYINT
DECLARE @nomeMes VARCHAR (10)
DECLARE @numMes TINYINT
DECLARE @trimestre TINYINT
DECLARE @anoCalendario   SMALLINT
DECLARE @fQtr TINYINT
DECLARE @fYr SMALLINT
DECLARE @cQFN VARCHAR (20)
DECLARE @cMFN VARCHAR (20)
DECLARE @fQFN VARCHAR (20)
DECLARE @fYFN VARCHAR (20)

-- Determina o dia antes do primeiro dia da tabela
SET @Data = '1989-12-31'

-- Definir o último dia aqui
WHILE @Data < '2035-12-31'
BEGIN

   /*
   # Vamos adicionar todas as funções de data primeiro. Estas são todas as maneiras de expressar a data
   # sem concatenação ou manuseio especial
   */

   SET @Data          = DATEADD (day, 1, @Data );
   SET @DataPTBR      = CONVERT (CHAR( 10), CONVERT(DATETIME , @Data), 103)
   SET @NumDiaSemana  = DATEPART (dw, @Data);
   SET @NumDiaMes     = DATEPART (d, @Data);
   SET @nomeDiaAno    = DATEPART (y, @Data);
   SET @semanaAno     = DATEPART (wk, @Data);
   SET @numMes        = DATEPART (m, @Data);
   SET @trimestre     = DATEPART (q, @Data);
   SET @anoCalendario = DATEPART (yy, @Data);

   SET LANGUAGE 'brazilian' ;
      SET @NomeDiaSemana    = DATENAME( dw, @Data );
      SET @DiaAbrev         = LEFT(@NomeDiaSemana, 3);
      SET @nomeMes          = DATENAME(m , @Data);
   SET LANGUAGE 'us_english' ;


   /*
   # Vamos adicionar também uma data formatada em yyyymmdd como int para eficiência em joins e indexação quando necessário
   */

   SET @ChaveData = CAST (CAST( @anoCalendario AS CHAR(4 )) +
                    CASE WHEN @numMes > 9
                         THEN CAST (@numMes AS CHAR( 2))
                         ELSE '0' + CAST(@numMes AS CHAR (1))
                    END +
                    CASE WHEN @NumDiaMes > 9
                         THEN CAST (@NumDiaMes AS CHAR( 2))
                         ELSE '0' + CAST(@NumDiaMes AS CHAR (1))
                    END AS INT)

   -- Inclusão dos dados na tabela
   INSERT INTO dbo. DimensaoData
             ( ChaveData        
             , Data     
             , DataPTBR
             , NumeroDiaDaSemana
             , NomeDiaDaSemana  
             , DiaAbrevDaSemana 
             , NumeroDiaDoMes   
             , NumeroDiaDoAno
             , NumeroSemanaDoAno
             , NomeDoMes        
             , NumeroMesDoAno   
             , Trimestre        
             , AnoCalendario    
             )
      VALUES ( @ChaveData
             , @Data
             , @DataPTBR
             , @NumDiaSemana
             , @NomeDiaSemana
             , @DiaAbrev
             , @NumDiaMes
             , @NomeDiaAno
             , @semanaAno
             , @nomeMes
             , @numMes
             , @trimestre
             , @anoCalendario
             );
END
GO

CREATE INDEX ixNCL_ChaveData ON dbo .DimensaoData (ChaveData ASC );
CREATE INDEX ixNCL_Data ON dbo .DimensaoData (Data ASC , ChaveData ASC );



/*


SELECT *
FROM dbo.DimensaoData

*/