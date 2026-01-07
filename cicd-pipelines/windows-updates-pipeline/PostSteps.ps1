#SQL To Check is any ETL Process running from Azure Data facotry (Checks the Config option set by the Overnight job when starting )
#TODO - Reffrence and call the SQL Script directly from ADO rather than coppy & Pata 

$SQLPostDeploy = "EXEC setup.Helper_MergeIntoSYSConfig
@OptionItem 			= 'Configuration'
, @OptionItemDetail 		= 'IsDeploying'
, @OptionItemDetail_Value = '0'
, @Description 			= 'Indicates if the database is currently under deployment'
, @IsEditable 			= 0
, @IsAppBased 			= '0'"


Function Invoke-APPV4SQLPostSteps(
    $Servers
){
    foreach ($Server in $Servers){

        $DBConnection = Connect-DbaInstance -SqlInstance $Server -TrustServerCertificate -DisableException
        $DBs = Get-DbaDatabase -SqlInstance $DBConnection -ExcludeDatabase 'SSISDB' -ExcludeSystem

        #Build Script Block to run jobs for each DB 
        $ScriptBlock  = {

            param($Server,$DBName,$SQLPostDeploy)

            $MaxRetries = 3
            $RetryDelay = 1  # seconds
            $Success = $false

            for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
                try {
                    #Establish New DB connection Per DB 
                    $DBConnection = Connect-DbaInstance -SqlInstance $Server -Database $DBName -TrustServerCertificate -DisableException
                    Invoke-DbaQuery -SqlInstance $DBConnection -query $SQLPostDeploy
                    
                    # Validate flag was reset
                    $Check = Invoke-DbaQuery -SqlInstance $DBConnection -query "SELECT OptionItemDetail_Value FROM app.SYS_Config WHERE OptionItem = 'Configuration' AND OptionItemDetail = 'IsDeploying'"
                    
                    if ($Check.OptionItemDetail_Value -eq '0') {
                        $Success = $true
                        if ($attempt -gt 1) {
                            Write-Host "Success on attempt $attempt for $DBName"
                        }
                        break
                    } else {
                        throw "IsDeploying flag is $($Check.OptionItemDetail_Value), expected 0"
                    }
                } catch {
                    if ($attempt -lt $MaxRetries) {
                        Write-Host "Attempt $attempt failed for $DBName : $($_.Exception.Message). Retrying in $RetryDelay seconds..."
                        Start-Sleep -Seconds $RetryDelay
                    } else {
                        throw "Failed after $MaxRetries attempts: $($_.Exception.Message)"
                    }
                }
            }

            if (-not $Success) {
                throw "IsDeploying flag not reset after $MaxRetries attempts"
            }
        }

        write-host "$(Get-Date) - Starting Post Deploy Scripts on $Server"
        write-host "$(Get-Date) - Server Context: $Server"
        write-host "$(Get-Date) - Total databases to process: $($DBs.Count)"

        # Process databases in batches to avoid overwhelming the server
        $BatchSize = 15
        $AllDBs = $DBs
        $TotalBatches = [Math]::Ceiling($AllDBs.Count / $BatchSize)
        $AllResults = @()

        for ($batchNum = 0; $batchNum -lt $TotalBatches; $batchNum++) {
            $StartIndex = $batchNum * $BatchSize
            $CurrentBatch = $AllDBs | Select-Object -Skip $StartIndex -First $BatchSize
            
            write-host "$(Get-Date) - Processing batch $($batchNum + 1) of $TotalBatches ($($CurrentBatch.Count) databases)"
            
            $Jobs = @()
            foreach ($DB in $CurrentBatch) {
                $Jobs += Start-Job -Name "$Server-$($DB.Name)" -ScriptBlock $Scriptblock -ArgumentList $Server,$DB.Name,$SQLPostDeploy
            }
            
            # Wait for batch to complete
            do {
                $Results = @()
                foreach ($Job in $Jobs){
                    #Check Completed jobs for any failures  
                    $Status = if($Job.ChildJobs[0].Error) { "ERR: $($Job.ChildJobs[0].Error.Exception)" } else { $Job.State }
                    $Results += [PSCustomObject]@{ 
                        Server = $Server; 
                        Database = ($Job.Name -split '-', 2)[1]; 
                        Status = $Status; 
                    }
                }
            
                Write-Output $Results | ft Server, Database, Status -AutoSize
                Start-Sleep 10
            
            } until (($Jobs | where State -eq "Running").Count -eq 0)

            # Add batch results to overall results
            $AllResults += $Results
            
            # Clean up completed jobs
            Remove-Job -Job $Jobs
            
            write-host "$(Get-Date) - Batch $($batchNum + 1) completed"
        }

        write-output "$(Get-Date) - All batches completed"
        Write-Output $AllResults | ft Server, Database, Status -AutoSize

        # Fail pipeline if any errors
        $Failed = $AllResults | Where-Object { $_.Status -like "ERR:*" }
        if ($Failed) { 
            Write-Host "##vso[task.logissue type=error]$($Failed.Count) database(s) failed on $Server after retries"
            throw "Post-deployment failed for $($Failed.Count) database(s) after retry attempts"
        }

        #Enable ETL from starting until updates completed 
        Write-Host "$(Get-Date) - Unlocking ETL User "
        $DBConnection = Connect-DbaInstance -SqlInstance $Server -TrustServerCertificate -DisableException
        Set-DbaLogin -SqlInstance $DBConnection -Login APPV4ETL -Enable
        
        write-host "$(Get-Date) - Post-deployment completed successfully for $Server"
    }
}
