#Automatic database restore script
$TimeStamp = Get-Date -Format yyyyMMdd_HHmmss

#Specify path and filename to write log files
$Logfile = 'C:\Temp\logs\SQLSERVERNAME_' + $TimeStamp + '.log'
Start-Transcript -Path $Logfile

# Enter the Backup (Copy) Job Name containing the Backups
# The name may not be what the Veeam application shows. Run "Get-VBRBackup | select Name" to see all job names to verify.

$JobName = "Servers SQL19 GMI Prod"

# Enter the name of the server that contains the database to be restored.
$SourceSQLServerName = "slgmisql21p.slsi.loc"
$SourceSQLInstanceName = "DE1P"

#Enter Credentials to use for restore
$User = "slsi\admin-jurek"
$PWord = ConvertTo-SecureString -String "geslo" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord

#Tried to use get-storedcrential, but did not have success
#$Credential = get-storedcredential -target "SQL Restore Account"

$AgentBackups = Get-VBRBackup -Name $JobName

$RestorePoint = Get-VBRRestorePoint -Backup $AgentBackups  | ?{$_.IsCorrupted -eq $False} | Sort-Object –Property CreationTime –Descending | Select -First 1

$ApplicationRestorePoint = Get-VBRApplicationRestorePoint -Id $RestorePoint.Id
$SQLRestoreSession = Start-VESQLRestoreSession -RestorePoint $ApplicationRestorePoint[0]

#Enter the Name of the database(s) to restore. Restore as many DBs as you want that exist on the source SQL server. You can specify a different destination server for each database.
#TargetDataFolder and TargetLogFolder can be whatever you have setup on your destination DR SQL server. They can be the same if you want.
$DBtoRestore = @(
[pscustomobject]@{DBName='ZDBA';TargetDataFolder='E:\Data';TargetLogFolder='F:\Logs';DestServerName='slgmisqlrep.slsi.loc'}
#[pscustomobject]@{DBName='DBName2';TargetDataFolder='E:\Data';TargetLogFolder='F:\Logs';DestServerName='DRSQLSERVERNAME.domain.com'}
)


foreach ($rDB in $DBtoRestore) {
  #Get the database needing to be restored
  $SQLRestoreDB = Get-VESQLDatabase $SQLRestoreSession -Name $rDB.DBName -InstanceName $SourceSQLInstanceName

  Write-Host $SQLRestoreDB
  #Get the Interval that is available for the database. This will be last backup with all recent transactional log backups.
  #Since the most recent transactional log backup may still be running, we are just going to use the last full/inc backup we have.
  #Was having issues using most recent vlb file because of locking. If there is a way to check and use one prior, we may be able to get a more recent restore daily.
  $SQLRestoreDBInterval = Get-VESQLDatabaseRestoreInterval -Database $SQLRestoreDB

  Write-Host $SQLRestoreDBInterval
  #Get all the database files
  $SQLRestoreDBFilePaths = Get-VESQLDatabaseFile -Database $SQLRestoreDB

  Write-Host $SQLRestoreDBFilePaths
  #Set proper paths for data vs log files on destination server. Check for mdf or ldf file and set new path based on that. Use the TargetDataFolder and TargetLogFolder specified above.
  $SQLRestoreDBNewFilePaths = @()
  foreach ($rDBFiles in $SQLRestoreDBFilePaths) {
   $SQLRestoreDBFileName = Split-Path $rDBFiles.Path -leaf
   if($SQLRestoreDBFileName -like '*.mdf') {
    $SQLRestoreDBNewFilePaths += $rDB.TargetDataFolder + '\' + $SQLRestoreDBFileName
   } elseif($SQLRestoreDBFileName -like '*.ldf') { 
    $SQLRestoreDBNewFilePaths += $rDB.TargetLogFolder + '\' + $SQLRestoreDBFileName
   } else {
    $SQLRestoreDBNewFilePaths += $rDB.TargetDataFolder + '\' + $SQLRestoreDBFileName
   }
  }
  #Restore the database and leave it operational.
  Restore-VESQLDatabase -Database $SQLRestoreDB -DatabaseName $rDB.DBName -ServerName $rDB.DestServerName -InstanceName "DE1P" -SqlCredentials $Credential -GuestCredentials $Credential -ToPointInTime $SQLRestoreDBInterval.FromUtc -File $SQLRestoreDBFilePaths -TargetPath $SQLRestoreDBNewFilePaths -RecoveryState "Recovery" -Force
}


Stop-VESQLRestoreSession $SQLRestoreSession
Write-Output 'End of Processing'

Stop-Transcript