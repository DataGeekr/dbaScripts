# Execução: .\Backup-SqlAgentJobs.ps1 -servidor "" -pastaDestino ""

param([string]$servidor, [string]$pastaDestino)

# Carrega o SQL Server SMO Assemly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null

# Validação do destino (pasta aonde os arquivos serão persistidos
$destinoExistente = Test-Path $pastaDestino
if($pastaDestino.Substring($pastaDestino.Length-1,1) -ne "\")
{
    $pastaDestino += "\"
}

# Lista os arquivos existentes na pasta
#Get-ChildItem $pastaDestino | ForEach-Object {Write-Host $_.FullName}

#Remove os arquivos da pasta para inclusão dos jobs mais recentes em execução no servidor
Get-Childitem $pastaDestino | Foreach-Object {Remove-Item $_.FullName}

if (Test-Path -Path $pastaDestino)
{
	# Cria uma conexão SMO para o servidor 
	$srv = New-Object "Microsoft.SqlServer.Management.Smo.Server" $servidor

	# Criação de um único arquivo para todos os Jobs
	#$srv.JobServer.Jobs | foreach {$_.Script() + "GO`r`n"} | out-file ".\$OutputFolder\jobs.sql"

	# Criação de um arquivo por Job
        # Remoção do caracter backslash, normalmente existente em jobs do agente de replicação, para evitar problemas de caminho de arquivo
	$srv.JobServer.Jobs | foreach-object -process {out-file -FilePath $("$pastaDestino" + $srv.Name.toUpper() + "_" + $(((($_.Name -replace '\\', '') -replace ':', '') -replace '\[', '') -replace ']', '') + ".sql") -inputobject $_.Script() | write-host $("$pastaDestino" + $srv.Name + "_" + $($_.Name -replace '\\', '') + ".sql") }
}
else
{
    Write-Host "Pasta informada para criação dos arquivos não foi encontrada."
}
