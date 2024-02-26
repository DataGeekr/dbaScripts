USE master
GO
CREATE TABLE BlobDocument (Id INT IDENTITY (1, 1) PRIMARY KEY , Document VARBINARY(MAX ))

INSERT INTO BlobDocument(Document)
     SELECT *
     FROM OPENROWSET (BULK N'C:\OAB_PB.jpg', SINGLE_BLOB) AS Blob

USE IdentidadeDoAdvogado
GO

SELECT *
FROM IdentidadeDoAdvogado .dbo. AssinaturaDocumento
WHERE IdenOgan = 15
AND   Pres = 'ODON BEZERRA CAVALCANTI SOBRINHO'

BEGIN TRANSACTION

     UPDATE IdentidadeDoAdvogado .dbo. AssinaturaDocumento
        SET Assi = ( SELECT Document FROM master .dbo. BlobDocument WHERE Id = 1 )
          , Pres = 'VITAL BEZERRA LOPES'
          , DataAtua = GETDATE()
     WHERE IdenOgan = 15
     AND   Pres = 'ODON BEZERRA CAVALCANTI SOBRINHO'

COMMIT TRANSACTION

USE master
GO

DROP TABLE BlobDocument
  