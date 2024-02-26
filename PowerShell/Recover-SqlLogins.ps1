#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

# 
# Autor  : Rafael Rodrigues
# Data   : 05/02/2014
# Função : Script de logins do SQL Server
#
# Exemplo de execução : ./Recover-SqlLogins.ps1 -pSqlServer "SRVNOME"
#                                               -pWriteTo "File"
#                                               -pFileContainer "D:\Scripts\"
#                                               -pLoginSQL "LoginSQL"
#
# Versão : 01.01.00
# Data da última atualização : 17/07/2014
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

param 
(

  # Informa se a verificação do banco de dados deve ser realizada
  [Parameter(Mandatory=$true, Position=0, HelpMessage="Nome do servidor SQL Server..")] 
  [String]$pSqlServer,

  # O output da execução será enviado para a tela (Host) ou para um arquivo (File)
  [Parameter(Mandatory=$true, Position=0, HelpMessage="Enviar para ..: Tela (Host) ou Arquivo (File)")]
  [ValidateSet("Host","File")] 
  [String]$pWriteTo,

  # O output da execução será enviado para a tela (Host) ou para um arquivo (File)
  [Parameter(Mandatory=$false, Position=0, HelpMessage="Para criação em arquivo, informe o diretório de destino..")] 
  [String]$pFileWrapper,

  # Recuperação de um único login ou múltiplos logins
  [Parameter(Mandatory=$false, Position=0, HelpMessage="Informe o login (deixe em branco para listagem de todos os usuários do servidor informado..")] 
  [String]$pLoginSQL

)

# ~~ Carregamento de assemblies do Management Object
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null

<#
# ~~ Verifica dependências de módulos e caso não seja encontrado, realiza a importação
if (-not(Get-Module -name 'SQLPS')) 
{
    if (Get-Module -ListAvailable | Where-Object {$_.Name -eq 'SQLPS' }) 
    {
        Push-Location # O carregamento do módulo SQLPS altera o local do provedor, então salva o local atual
        Import-Module -Name SQLPS -DisableNameChecking
        Pop-Location # Retorna ao local original
   }
}
#>

$ErrorActionPreference = "Stop"

$sqlConn = New-Object Microsoft.SqlServer.Management.Smo.Server $pSqlServer 


if ([string]::IsNullOrEmpty($sqlConn))
{
    $sqlConn = Read-Host "Servidor não informado. Informe-o para prosseguir" 
}

If (-not $sqlConn.Databases.Count)
{
    Write-Output([System.String]::Format("Não foi possível conectar em {0}.", $sqlConn))
    return
}


$fileLocation = ""

# {($_.Name -eq "OabIntegracao")})  #
ForEach ($sqlLogin in $sqlConn.Logins | Where-Object {($_.Name -eq $pLoginSQL -or ([string]::IsNullOrEmpty($pLoginSQL)))})
{

    If ("sa", "NT AUTHORITY\SYSTEM", "BUILTIN\ADMINISTRATORS" -contains $sqlLogin.Name)
    {
        continue
    }


    # ~~ Limpa a variável de script
    $loginScript = @()
    $loginScript += ("/* ~~")
    $loginScript += ($($sqlLogin.Name)) 
    $loginScript += ("~~ */ `r`n")

    $defaultDB = "master"

    #Usuário SQL? Recupera as credenciais
    $sqlLoginSID = ""

    If ($sqlLogin.LoginType -eq "SqlLogin")
    {
        $sqlLogin.Sid | % {$sqlLoginSID += ("{0:X}" -f $_).PadLeft(2, "0")} 
        [byte[]] $pwdHash = $sqlConn.Databases["master"].ExecuteWithResults("select hash=cast(loginproperty('$($sqlLogin.Name)', 'PasswordHash') as varbinary(256))").Tables[0].Rows[0].Hash
        $sqlLoginPWD = ""
        $pwdHash | % {$sqlLoginPWD += ("{0:X}" -f $_).PadLeft(2, "0")}
    }


    #Usuário Windows?
    $loginScript += If ("WindowsGroup", "WindowsUser" -contains $sqlLogin.LoginType) 
                    { 
                            ("CREATE LOGIN [$($sqlLogin.Name)]").TrimStart() 
                            ("FROM WINDOWS WITH DEFAULT_DATABASE = [$defaultDB];").TrimStart()
                            ("GO `n").TrimStart() 
                    } 
                    Else 
                    { 
                        #Expiração de senha?
                        If ($sqlLogin.PasswordExpirationEnabled) 
                        { 
                                $checkExpiration = "ON" 
                        } 
                        Else 
                        { 
                                $checkExpiration = "OFF" 
                        } 
                        #Possui GPO?
                        If ($sqlLogin.PasswordPolicyEnforced) 
                        { 
                                $checkPolicy = "ON" 
                        } 
                        Else 
                        { 
                                $checkPolicy = "OFF" 
                        } 
                        
                        #Script de criação do login 
                        ("CREATE LOGIN [$($sqlLogin.Name)]").TrimStart() 
                        ("WITH PASSWORD         = 0x$sqlLoginPWD HASHED").TrimStart()
                        (",    SID              = 0x$sqlLoginSID").TrimStart()
                        (",    DEFAULT_DATABASE = [$defaultDB]").TrimStart()
                        (",    CHECK_POLICY     = $checkPolicy").TrimStart()
                        (",    CHECK_EXPIRATION = $checkExpiration;").TrimStart()
                        ("GO `n").TrimStart()
 
                        #Login negado?
                        If ($sqlLogin.DenyWindowsLogin) 
                        { 
                                ("DENY CONNECT Sql TO [$($sqlLogin.Name)];").TrimStart() 
                        } 
 
                        #Possui acesso?
                        If (-not $sqlLogin.HasAccess) 
                        { 
                                ("REVOKE CONNECT sql TO [$($sqlLogin.Name)];").TrimStart() 
                        } 
 
                        #Desabilitado?
                        If ($sqlLogin.IsDisabled) 
                        { 
                                ("ALTER LOGIN [$($sqlLogin.Name)] DISABLE;").TrimStart()
                        } 
                    } 

 
    # Server roles
    $loginScript += foreach ($role in $sqlConn.Roles | Where-Object {$_.Name -ne "public"}) 
    { 
            $addRole = $false 

            If ($sqlConn.Logins[$sqlLogin.Name].IsMember($role.Name)) 
            {
                $addRole = $sqlLogin.IsMember($role.Name) 
            }

            If ($addRole) 
            { 
                    ("EXEC sp_addsrvrolemember @loginame = N'$($sqlLogin.Name)', @rolename = N'$($role.Name)';").TrimStart()
                    ("GO `n").TrimStart() 
            } 
    } 

    # DB User
    $loginScript += foreach ($db in $sqlConn.Databases | Where-Object {$_.Status -eq "Normal"}) 
    { 
        $dbUser = $null 
        $dbUser = $db.Users | Where-Object {$_.Login -eq $sqlLogin.Name} 

        If ($dbUser) 
        { 
            $userSID = "" 
            $dbUser.Sid | % {$userSID += ("{0:X}" -f $_).PadLeft(2, "0")} 
            If ($userSID -eq $sqlLoginSID) 
            { 
                    ("USE $($db.Name);").TrimStart()
                    ("IF NOT EXISTS ( SELECT 1 FROM sys.sysusers WHERE name = '$($dbUser.Name)')").TrimStart()
                    ("BEGIN").TrimStart()
                    ("   CREATE USER $($dbUser.Name) FOR LOGIN [$($sqlLogin.Name)];")
                    ("END").TrimStart()
                    ("ELSE").TrimStart()
                    ("BEGIN").TrimStart()
                    ("   ALTER USER [$($dbUser.Name)] WITH LOGIN = [$($sqlLogin.Name)];")
                    ("END").TrimStart()
                    ("GO `n").TrimStart() 
                    
            } 
        } 
    } 


    # ~~ Processamento da saída
    If ($pWriteTo -eq "Host")
    {

        $loginScript | Out-String
    }
    Else # ~~ Arquivo
    {
        If ([string]::IsNullOrEmpty($pFileWrapper))
        {
            "Local de armazenamento do arquivo não informado!" | Write-Host -ForegroundColor "Red"
            break
        }

        try
        {

            $fileName = (($sqlLogin.Name -replace "\\", "_") -replace " ", "-").Trim() + ".sql"
            $filePath = $pFileWrapper + "\" + $fileName

            If (Test-Path $filePath)
            {
	            Remove-Item $filePath
            }

            $loginScript | Out-File $filePath

        }
        catch 
        {
            $error[0] | format-list –force
        }
    }



}

    
    
