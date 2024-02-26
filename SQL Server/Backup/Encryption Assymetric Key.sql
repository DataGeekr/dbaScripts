
```
USE master 
GO

-- Criacao do certificado 
CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''

SELECT * FROM sys.asymmetric_keys;

-- Enable advanced options.   
USE master;   
GO   
EXEC sp_configure 'show advanced options', 1;   
GO   
RECONFIGURE;   
GO  

-- Enable EKM provider   
EXEC sp_configure 'EKM provider enabled', 1;   
GO   
RECONFIGURE;

-- Reconfiguração 
-- Create the EKM provider   
CREATE CRYPTOGRAPHIC PROVIDER AzureKeyVault_EKM 
FROM FILE = 'C:\Program Files\SQL Server Connector for Microsoft Azure Key Vault\Microsoft.AzureKeyVaultService.EKM.dll';   
GO

-- Create the Azure EKM Credential 
DECLARE @appClientId uniqueidentifier = '96dd7475-31aa-408e-aa11-f2650709157c'; 
DECLARE @AuthClientSecret varchar(200) = '18ho1.JvLh8ssJ7.c4l9ExQjgq_3a.y1j-'; 
DECLARE @pwd VARCHAR(MAX) = REPLACE(CONVERT(VARCHAR(36), @appClientId) , '-', '') + @AuthClientSecret; 
PRINT ('CREATE CREDENTIAL AzureEKM_Cred_cfoabOabSQLServer 
        WITH IDENTITY = ''OabSQLServerEKMKeyVault'', SECRET = ''' + @pwd + ''' 
        FOR CRYPTOGRAPHIC PROVIDER AzureKeyVault_EKM ;');  

-- Add the credential to the SQL Server administrator's domain login 
ALTER LOGIN [CFOAB\OabSQLServer]   
ADD CREDENTIAL AzureEKM_Cred_cfoabOabSQLServer; 

-- Add the credential to the SQL Server administrator's domain login 
ALTER LOGIN [rafael.rodrigues]   
ADD CREDENTIAL AzureEKM_Cred_RafaelRodrigues; -- Use Credential name created in the previous step

-- Key Creation For TDS e Backup encryptin 
     -- Key for Transparent Database Encryption  
     -- Now create the asymmetric key in the SQL Server master database that will reference the key in Azure  
          -- For this to work we need:  
          -- The application registration in Azure that the credential references in its password needs access to the key vault  
CREATE ASYMMETRIC KEY OabSQLServer_TDEKey   
FROM PROVIDER AzureKeyVault_EKM --This is the Azure provider, so it will know how to comms to Azure Key Vaults   
WITH PROVIDER_KEY_NAME = 'OabSQLServerTDEKey', --Key for TDE Encryption  
CREATION_DISPOSITION = OPEN_EXISTING; --Key for TDE Encryption 

     --   Now create the asymmetric key in the SQL Server master database that will reference the key in Azure  
          -- For this to work we need:  
          -- The application registration in Azure that the credential references in its password needs access to the key vault  
CREATE ASYMMETRIC KEY OabSQLServerBKPKey 
FROM PROVIDER AzureKeyVault_EKM --This is the Azure provider, so it will know how to comms to Azure Key Vaults 
WITH PROVIDER_KEY_NAME = 'OabSQLServerBKPKey', --Key for Backup Encryption  
CREATION_DISPOSITION = OPEN_EXISTING; 
-- Obs.: Has to be created on Azure Key Vault > Keys

CREATE LOGIN usrOABEncryptBackup 
FROM ASYMMETRIC KEY OabSQLServerBKPKey;

CREATE CREDENTIAL AzureEKM_Cred_cryptBackupProvider 
WITH IDENTITY = 'OabSQLServerEKMKeyVault', 
SECRET = '96DD747531AA408EAA11F2650709157C18ho1.JvLh8ssJ7.c4l9ExQjgq_3a.y1j-' 
FOR CRYPTOGRAPHIC PROVIDER AzureKeyVault_EKM

ALTER LOGIN usrOABEncryptBackup 
 ADD CREDENTIAL AzureEKM_Cred_cryptBackupProvider

/* 
Referencias: 
https://argonsys.com/microsoft-cloud/library/part-4-sql-server-tde-and-extensible-key-management-using-azure-key-vault/ ??? 
*/ 
/* 
Erros: 
     Cannot open session for cryptographic provider 'AzureKeyVault_EKM'. Provider error code: 3900. (Provider Error - No explanation is available, consult EKM Provider for details) 
     Resolution: 
     Open regedit 
     1. Navigate to HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft 
     2. Create a new Key called "SQL Server Cryptographic Provider" (without quotes) 
     3. Right click the key, from the context menu select 'permissions'. 
     4. Give Full Control permissions to this key to the Windows service account that runs SQL Server 
*/      
/*  
Remocao: 
ALTER LOGIN encryptBackup DROP CREDENTIAL encryptBackupProviderCred 
GO 
DROP CREDENTIAL encryptBackupProviderCred 
GO 
DROP LOGIN encryptBackup 
GO  
DROP ASYMMETRIC KEY OabSQLServer_BKPKey 
GO 
DROP ASYMMETRIC KEY OabSQLServer_TDEKey   
GO 
ALTER LOGIN [CFOAB\OabSQLServer] DROP CREDENTIAL AzureEKM_Cred_cfoabOabSQLServer;  
GO 
DROP CREDENTIAL AzureEKM_Cred_cfoabOabSQLServer 
GO 
ALTER LOGIN [rafael.rodrigues] DROP CREDENTIAL AzureEKM_Cred_RafaelRodrigues;  
GO 
DROP CREDENTIAL AzureEKM_Cred_RafaelRodrigues 
GO  
DROP CRYPTOGRAPHIC PROVIDER AzureKeyVault_EKM  
*/

-- Adicionar ao SQL Job de Backup
, @Encrypt = 'N', @EncryptionAlgorithm = 'AES_256', @ServerAsymmetricKey = 'OabSQLServerBKPKey'
```
