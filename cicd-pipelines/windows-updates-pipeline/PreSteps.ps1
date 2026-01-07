#SQL To Check is any ETL Process running from Azure Data facotry (Checks the Config option set by the Overnight job when starting )
$ETLCheck = "SELECT [OptionItemDetail_Value] FROM [app].[SYS_Config] WHERE OptionItem_ID = 189 AND OptionItemDetail_Value = 1"

$SQLPreDeploy1 = "EXEC setup.Helper_MergeIntoSYSConfig
@OptionItem 			= 'Configuration'
, @OptionItemDetail 		= 'IsDeploying'
, @OptionItemDetail_Value = '1'
, @Description 			= 'Indicates if the database is currently under deployment'
, @IsEditable 			= 0
, @IsAppBased 			= '0'"

$SQLPreDeploy2 = "DECLARE @MAX_ATTEMPT_COUNT INT = 60;
DECLARE @I INT = 0;
DECLARE @JOB_NOT_RUNNING BIT = 0;

WHILE (@I < @MAX_ATTEMPT_COUNT)
BEGIN
	IF NOT EXISTS (SELECT 1 FROM APP.SYS_Locks WHERE StoredProcedure = 'ACCRUAL_Queue_Control' AND Locked = 1)
	BEGIN
		SET @JOB_NOT_RUNNING = 1;
		BREAK;
	END

	WAITFOR DELAY '00:00:30';
	SET @I = @I + 1;
END

IF (@JOB_NOT_RUNNING = 0)
	THROW 51000, 'ACCRUAL_Queue_Control is still running', 1"

Function Invoke-APPV4SQLPreSteps(
    $Servers
){
    foreach ($Server in $Servers){

        # Check Overnight ETL Process not running, and awaitig completion if it is 
        # Unlike APPV3 this is done per database

        $DBConnection = Connect-DbaInstance -SqlInstance $Server -TrustServerCertificate -DisableException
        $DBs = Get-DbaDatabase -SqlInstance $DBConnection -ExcludeDatabase 'SSISDB' -ExcludeSystem

        #Build Script Block to run jobs for each DB 
        $ScriptBlock  = {

            param($Server,$DBName,$ETLCheck,$SQLPreDeploy1,$SQLPreDeploy2)

            #Establish New DB connection Per DB 
            $DBConnection = Connect-DbaInstance -SqlInstance $Server -Database $DBName -TrustServerCertificate -DisableException

            #Check & Wait for any Running ETL Jobs to complete 
            $Runlimit = (Get-Date).AddMinutes(30)
            do {
                $RunningJobs = Invoke-DbaQuery -SqlInstance $DBConnection -query $ETLCheck

                if ($RunningJobs) { Start-Sleep 5 }

            } until (!$RunningJobs -or (Get-Date) -le $Runlimit)

            #Set Deployment Flag 
            Invoke-DbaQuery -SqlInstance $DBConnection -query $SQLPreDeploy1

            #Check & Wait for any running Acurruls Jobs to complete
            $Runlimit = (Get-Date).AddMinutes(30)
            do {
                $RunningJobs = Invoke-DbaQuery -SqlInstance $DBConnection -query $SQLPreDeploy2

                if ($RunningJobs) { Start-Sleep 10 }

            } until (!$RunningJobs -or ((Get-Date) -ge $Runlimit))
        }

        $Jobs = @()
        write-host "$(Get-Date) - Starting DB Check on $Server"
        foreach ($DB in $DBs){ $Jobs += Start-Job -Name $DB.Name -ScriptBlock $Scriptblock -ArgumentList $Server,$DB.Name,$ETLCheck,$SQLPreDeploy1,$SQLPreDeploy2}
        
        do {
            $Results = @()
            foreach ($Job in $Jobs){
                
                #Check Completed jobs for any failures  
                $Status = if($Job.ChildJobs[0].Error) { "ERR: $($Job.ChildJobs[0].Error.Exception)" } else { $Job.State }
                $Results += [PSCustomObject]@{ Server = $Job.Name; Status = $Status; }
                }
        
                write-output "$(Get-Date)"
                Write-Output $Results | ft -AutoSize
                Start-Sleep 30
        
        } until (($Jobs | where State -eq "Running").Count -eq 0)

        write-output "$(Get-Date)"
        Write-Output $Results | ft -AutoSize

        #Disable ETL from starting until updates completed 
        Write-Host "$(Get-Date) - locking ETL User to prevent New ETL's Queing"
        Get-Service -Computer $Server -Name 'SQLSERVERAGENT' | Stop-Service -Force
        $DBConnection = Connect-DbaInstance -SqlInstance $Server -TrustServerCertificate -DisableException
        Set-DbaLogin -SqlInstance $DBConnection -Login APPV4ETL -Disable
    }
}
