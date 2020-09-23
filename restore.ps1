# ############################################################ FUNCTIONS START ############################################################

function Restore-DatabaseFromBackup
{
	Param(
		[Parameter(Mandatory=$true)]
        [string]$dbname,
        
        [Parameter(Mandatory=$true)]
		[string]$containername
	)	

    docker exec -it $containername /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Pass@word" -Q "RESTORE FILELISTONLY FROM DISK = '/tmp/restore.bak'"
                    
    docker exec -it $containername /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Pass@word" -Q "RESTORE DATABASE $dbname FROM DISK = '/tmp/restore.bak' WITH MOVE 'WWI_Primary' TO '/var/opt/mssql/data/WideWorldImporters.mdf', MOVE 'WWI_UserData' TO '/var/opt/mssql/data/WideWorldImporters_userdata.ndf', MOVE 'WWI_Log' TO '/var/opt/mssql/data/WideWorldImporters.ldf', MOVE 'WWI_InMemory_Data_1' TO '/var/opt/mssql/data/WideWorldImporters_InMemory_Data_1'"

    docker exec -it $containername /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Pass@word" -Q "USE [$dbname]; ALTER DATABASE [$dbname] SET RECOVERY SIMPLE;"

	Write-Output "Restore done"	
}

# ############################################################ FUNCTIONS END ############################################################
$outputFile = "$($PSScriptRoot)/restore.bak"
if(![System.IO.File]::Exists($outputFile)){
    $wwiUrl = "https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak"
    $outputFile = "$($PSScriptRoot)/restore.bak"
    Invoke-WebRequest -Uri $wwiUrl -OutFile $outputFile
}

$toDbName = "TEST_DB";
$toDbInstance = "localhost,7433";

$imagename = "onpremise_data"
$containername = "onpremise_sql_data_base"
$bindMount = "$($PSScriptRoot):/tmp"

Write-Host "Trying to delete potentially dangling container ..."
docker rm -f $containername
docker run -v $bindMount -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Pass@word' --name $containername -p 7433:1433 -d mcr.microsoft.com/mssql/server:2019-latest

Start-Sleep -s 40
Write-Host "Started container $containername"

Write-Host "Restore $toDbInstance $toDbName ..."

Restore-DatabaseFromBackup -dbname $toDbName -containername $containername

# pause
Write-Host "Committing Image ..."
Start-Sleep -s 3
docker stop $containername
Start-Sleep -s 3
docker commit $containername $imagename
docker rm -f $containername