
-- Source (Backup) 
USE master 
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = '@U7JBiEA3HXVstNuDiLWtGP@qL72b3z7kEa4LRA7LfPFtP.F9j' 
OPEN MASTER KEY DECRYPTION BY PASSWORD = '@U7JBiEA3HXVstNuDiLWtGP@qL72b3z7kEa4LRA7LfPFtP.F9j' 




CREATE CERTIFICATE backupCert_Prod
   ENCRYPTION BY PASSWORD = 'n6rXP@Z*8n6r.J8wdZRUEnnhLVR-.dEA'  
   WITH SUBJECT = 'Certificado de criptografia de backup' 
GO

     -- Backup algorithm = AES_256
  
BACKUP CERTIFICATE backupCert_Prod  
   TO FILE = 'Z:\SQLServer\CertificatesSQL\backupCert_Prod.cer' -- Public 
   WITH PRIVATE KEY 
   ( 
      FILE = 'Z:\SQLServer\CertificatesSQL\backupCert_Prod.ppk', -- Private 
      DECRYPTION BY PASSWORD = 'n6rXP@Z*8n6r.J8wdZRUEnnhLVR-.dEA'  
   ) 


```
-- Destination Restore 
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<Z[P>aXU8^3?9bF8`?K1M[G93>OQLC@Q'
-- OPEN MASTER KEY DECRYPTION BY PASSWORD = '<Z[P>aXU8^3?9bF8`?K1M[G93>OQLC@Q'   

CREATE CERTIFICATE BackupCertificateTETIS  
   FROM FILE = 'Z:\SQLServer\CertificatesSQL\BackupCertificateTETIS.cer' 
   WITH PRIVATE KEY( 
      FILE = 'Z:\SQLServer\CertificatesSQL\BackupCertificateTETIS.ppk',  
      DECRYPTION BY PASSWORD = 'n6rXP@Z*8n6r.J8wdZRUEnnhLVR-.dEA' 
   ) 


   -- Se der erro, provavelmente será por causa das permissões NTFS do certificado 
   Command Prompt (Administrator): icacls Z:\SQLServer\CertificatesSQL\ /grant MSSQLSERVER:(GR) /T
```

```

USE MASTER
OPEN MASTER KEY DECRYPTION BY PASSWORD = '@U7JBiEA3HXVstNuDiLWtGP@qL72b3z7kEa4LRA7LfPFtP.F9j' 



--create the TDETestCertificate, with a password
IF EXISTS (SELECT 1 FROM sys.certificates c WHERE c.name = N'backupCert_Prod')
BEGIN
    DROP CERTIFICATE backupCert_Prod;
END
CREATE CERTIFICATE backupCert_Prod 
AUTHORIZATION dbo
WITH SUBJECT = N'Backup Certificate POLUS'
    , START_DATE = '2024-02-03'
    , EXPIRY_DATE = '2027-12-31T00:00:00';
GO

-- Backup the Service Master Key
USE master
GO
BACKUP SERVICE MASTER KEY
TO FILE = 'Z:\SQLServer\CertificateSQL\serv_masterkey_draco.key'
ENCRYPTION BY PASSWORD = '@U7JBiEA3HXVstNuDiLWtGP@qL72b3z7kEa4LRA7LfPFtP.F9j';
GO

BACKUP MASTER KEY
TO FILE = 'Z:\SQLServer\CertificateSQL\masterkey_draco.key'
ENCRYPTION BY PASSWORD = '@U7JBiEA3HXVstNuDiLWtGP@qL72b3z7kEa4LRA7LfPFtP.F9j';

GO


BACKUP CERTIFICATE backupCert_Prod
TO FILE = 'Z:\SQLServer\CertificateSQL\backupCert_Prod.cer'
WITH PRIVATE KEY (
    FILE = 'Z:\SQLServer\CertificateSQL\backupCert_Prod.ppk',
	--DECRYPTION BY PASSWORD = 'n6rXP@Z*8n6r.J8wdZRUEnnhLVR-.dEA',
    ENCRYPTION BY PASSWORD = 'n6rXP@Z*8n6r.J8wdZRUEnnhLVR-.dEA'
);
