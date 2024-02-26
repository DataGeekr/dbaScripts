USE IdentidadeDoAdvogado
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD ='<Z[P>aXU8^3?9bF8`?K1M[G93>OQLC@Q';

DROP DATABASE SCOPED CREDENTIAL crMongoAtlasCERES

CREATE DATABASE SCOPED CREDENTIAL crMongoAtlasCERES
WITH  IDENTITY = 'usrCnaBiometrico'
    , SECRET = 'rlQwokUEEU1f8AbC';

DROP EXTERNAL DATA SOURCE dsMongoAtlasCERES
GO
CREATE EXTERNAL DATA SOURCE dsMongoAtlasCERES
WITH ( LOCATION = 'mongodb://ceres-shard-00-00.7y1gc.mongodb.net:27017'
     , CONNECTION_OPTIONS = 'replicaSet=replicaSet=atlas-94t87i-shard-0; tls=true'
     , CREDENTIAL = crMongoAtlasCERES
     , PUSHDOWN = ON);

DROP EXTERNAL TABLE AdvogadoBiometricoExterno
GO
CREATE EXTERNAL TABLE AdvogadoBiometricoExterno
(
  [_id] NVARCHAR(24) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
, [cpf] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AI
, [biometrico_foto] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AI
, [biometrico_assinatura] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AI
, [biometrico_digital] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AI
)
WITH (
  LOCATION='CadastroNacional.biometrico',
  DATA_SOURCE=dsMongoAtlasCERES)


SELECT * FROM AdvogadoBiometricoExterno OPTION (FORCE EXTERNALPUSHDOWN)