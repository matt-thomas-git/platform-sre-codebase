#Requires -Version 5
#Requires -RunAsAdministrator

$global:LogPath = "C:\SchMaintenanceLogs"
Import-Module $PSScriptRoot\AzLogging.ps1

function Validate-InputServers(
    [Parameter(Mandatory=$true)]$Servers,
    [switch]$PingOnly
)
{
    <#
        .SYNOPSIS 
            Validate servers in Evn / Window / List are accessible

        .DESCRIPTION
            Runs network connective test on each server, testing PSRemoting & SMB Access
            Checks PS Version available on each server
            
            Returns True / False if all servers are valid or not
    #>

    

    $AllServersValid = $True
    foreach ($Server in $Servers){

        #Test Network connectivity
        try {
            $Ping = Test-Connection $Server -Quiet
            if(!$Ping){ Write-output "Server $Server Failed Ping Test" }
        } catch {
            Write-Verbose $_
            $Ping = $False
        }

        if(!$PingOnly){

            #Test open for PSRemote connectivity & Version
            try {

                $Version = (Invoke-Command -ComputerName $Server { $PSVersionTable.PSVersion } -ErrorAction SilentlyContinue).Major
        
                if ($Version -ge 5){ 
                    $Version = $True 
                    
                } elseif ($Version -lt 5) {
                    Write-Verbose "Server $Server is bellow minimum required powershell version"
                    $Version = $False
                    
                } else { 
                    Write-Verbose "Server $Server failed remote powershell check" 
                    $Version = $False
                }

            } catch {
                Write-Verbose $_
                $Version = $False
            }

            #Test SMB Connectivity
            try { 
                $SMB = Test-Path "\\$Server\c$"
                if(!$SMB){ Write-Verbose "Server $Server failed remote SMB check" } 
            } catch {
                Write-Verbose $_
                $SMB = $False
            }
        
            #Mark checks as failed if any test failed 
            if((!$Ping) -or (!$Version) -or (!$SMB)){
                $AllServersValid = $false    
            }

        } else { if((!$Ping)){ $AllServersValid = $false } }
    }

    if (!$AllServersValid){ Throw "Invalid Servers Detected. Aborting "}
    Return $AllServersValid
}

function OpenClose-Transcript(
    $Type,
    $Name,
    [switch]$Close
)
{
    if($Close){

        Write-Output "`n"
        Stop-Transcript

    } else {

        #Check for log path and create as needed 
        If(!(Test-Path $LogPath)){ New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
        $LogFile = "$LogPath\$(Get-Date -UFormat "%Y-%m-%d")_$Type-$Name.log"
        Start-Transcript -Path $LogFile -Append
    }
}

function Get-RebootJobResults(
    [Parameter(Mandatory=$true)]$Jobs
)
{
    $Results = @()
    foreach ($Job in $Jobs){

        #Get Status Progress
        $StateProgress = $Job.ChildJobs[0].Progress | Select-Object -Last 1

        #Check Completed jobs for any failures  
        if($Job.State -eq 'Completed' -And !$Job.ChildJobs[0].Error){ 

            $StateMessage = $Job.State

            <#Test for pending updates for complete jobs
            If(!(Get-Member -InputObject $Job -Name 'UpdatesRemaining')){ 
                $Job | Add-Member NoteProperty 'UpdatesRemaining' $(Get-PendingServerUpdates $Job.Name)
                
            } #>
            
        # Change state to error if found
        } elseif($Job.ChildJobs[0].Error) {  $StateMessage = $Job.ChildJobs[0].Error.Exception 
        } else { $StateMessage =  $StateProgress.StatusDescription }

        #Ensure $nul states handled
        $Status = if(!$StateMessage -or $StateMessage -eq "") {"Initiating" } else { $StateMessage }
        $Progress = if(!$StateProgress.PercentComplete){ 0 } else { $StateProgress.PercentComplete }

        #Output Job Progress to screen
        #Write-Progress -id $Job.Id -Activity "  $($Job.Name) Reboot progress.." -Status "  $Status" -PercentComplete $Progress

        #Build Result Object
        $Results += [PSCustomObject]@{ Server = $Job.Name; Status = $Status; Progres = $Progress } #UpdatesRemaining = $Job.UpdatesRemaining}
    }

    Write-Output $Results | ft -AutoSize
}

function Get-UpdateJobResults(
    [Parameter(Mandatory=$true)]$Jobs,
    [switch]$NoOutput
)
{
#Get Current status of job's list
    $Results = @()
    foreach ($Job in $Jobs){

        #Check Completed jobs for any failures  
        $Status = if($Job.ChildJobs[0].Error) { "ERR: $($Job.ChildJobs[0].Error.Exception)" } else { $Job.State }
        $Results += [PSCustomObject]@{ Server = $Job.Name; Status = $Status; }
    }

    Write-Output $Results | ft -AutoSize
}

function Get-RebootResults(
    [Parameter(Mandatory=$true)]$Servers
 )
 {
    #Build Script for testing
    $ScriptBlock  = {

        param($Server)
        try {

            #Create Query Session and return Number of updates available to server
            $UpdateSession = [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session",$Server))
            $PendingUpdates =  $UpdateSession.CreateUpdateSearcher().Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0").updates.count

            #Format Count to make output more obvious
            if($PendingUpdates -gt 0){ $PendingUpdates = "YES: $PendingUpdates" }

            #Force WSUS Report
            wuauclt /reportnow; wuauclt.exe /resetauthorization /detectnow

        } catch { $PendingUpdates =  "Failed to Re-check for updates" } 

        Return $PendingUpdates
    }

    #Check for further update available on server
    $ServersPendingUpdates = @()
    foreach ($Server in $Servers){
        
        #Run Script on each server
        try { $PendingUpdates = Invoke-Command -ComputerName $Server -ScriptBlock $ScriptBlock -ArgumentList $Server
        } catch { $PendingUpdates = "Failed to Re-check for updates" }

        #Alter Format output for better visibility
        if($Servers.Count -gt 1){ $PendingUpdates = [PSCustomObject]@{ Server = $Server; UpdatesPending = $PendingUpdates } }

        #Append Results to array
        $ServersPendingUpdates += $PendingUpdates
    }

    Return $ServersPendingUpdates
 }

function Get-UpdateResults(
    [Parameter(Mandatory=$true)]$Servers,
    [switch]$HTMLFormat
)
{

    
    #Scheduled task query script
    $ScriptBlock = { 
        param($SchTaskName)
        Try {

            #Get Task Status
            $TaskState = (Get-ScheduledTask -TaskName $SchTaskName -ErrorAction SilentlyContinue).state
            if(!$TaskState){ $TaskState = "Err. Update Task not found" }

            #Convert Ready to completed
            if($TaskState -eq 'Ready'){ $TaskState = "Completed" }
            
        } catch { $TaskState = "Err. Update Task not found"} 
        Return $TaskState
    }

    $Results = @()
    foreach ($Server in $Servers){

        #Get Status of Update Scheduled task 
        $SchTaskName = "AutomatedUpdates"
        try {
             $UpdateTask = Invoke-Command -ComputerName $Server -ScriptBlock $ScriptBlock -ArgumentList $SchTaskName }
        catch {
            Write-Verbose "Failed to get remote task"
            $UpdateTask = "Err. Remove Svr not available"
        }

        #Parse log for completion state
        $LogPath = "\\$Server\C$\$(Get-Date -UFormat "%Y-%m")-PSWindowsUpdate.log"
        if((Test-Path $LogPath) -And (Get-Content $LogPath)){

            #Check Log file for status
            $States = @(1..3)
            $UpdateStates = @{}
            $UpdateLog = Get-Content $LogPath
            
            foreach ($Line in $UpdateLog){
                foreach ($State in $States){
                    #Group Events into corresponding Status 
                    if ($Line -like "$($State)*"){ $UpdateStates[$State] += @($Line) }
                }
            }

            #Output progress of Job
            $Available = $UpdateStates[1].Count
            $Progress = if(($Available -ge 1) -And ($UpdateStates[2] -ge 1 )){
                
                #Calculate progress of intall
                $Percent = (($UpdateStates[2].Count / $Available) / 2) + (($UpdateStates[3].Count / $Available) / 2 )
                $Percent.tostring("p")

            } else { "Searching" }

            #Generate Textual state message
            $UpdateResults =  "$Available Available; $($UpdateStates[2].count)/$Available Downloaded; $($UpdateStates[3].count)/$Available Installed"

        #Handle Blank Log file = No Updates Available
        } elseif ((Test-Path $LogPath) -And !(Get-Content $LogPath)) {

            $UpdateTask = "Running";  $Progress = '100%'; $UpdateResults = "No Updates Found"; $logPath = "N/A"; 

        #handle no update log found = Assume Task failed 
        } else { $UpdateTask = "Error";  $Progress = 'N/A'; $UpdateResults = "Update task log not found"; $logPath = "N/A";}


        #Translate LogPath to HTML format
        if (!($TaskStatus -Like '*Err*') -And $HTMLFormat ) { $LogPath = "<a href='$LogPath'>$Server</a>" }

        $Results += [PSCustomObject]@{'Server' = $Server; 'TaskStatus' = $UpdateTask; 'Progress' = $Progress; 'Results' = $UpdateResults; 'Logs' = $logPath}
    }

    Return $Results
}


function Get-UpdateCheckJobResults(
    [Parameter(Mandatory=$true)]$Jobs
)
{
    $Results = @()
    foreach ($Job in $Jobs){

        $Status = $Job.State
        $JobResults = $Job.ChildJobs[0].Output | Select-Object -Last 1
        $Results += [PSCustomObject]@{ Server = $Job.Name; Status = $Status; 'Outstanding' = $JobResults.UpdateStatus; } #'SQLStatus' = $JobResults.SQLStatus}

    }

    Return $Results

}


function Get-PendingServerUpdates(
    [Parameter(Mandatory=$true)]$Servers
)
{
    #Build Script for testing
    $ScriptBlock  = {
        param($Server)

        #Run Update checks 
        try {
            $PendingUpdates = $(Get-WUList -NotTitle "Microsoft Defender Antivirus" -NotCategory 'drivers').count

        } catch { $PendingUpdates =  "Failed" } 

        #Return results as habitable 
        $Results = @{'UpdateStatus' = $PendingUpdates}
        Return $Results
    }

    #Start Remote Job to Check for further update available on each server in list
    $Jobs = @()
    foreach ($Server in $Servers){
        
        #Run Script on each server
        try { $Jobs += Invoke-Command -ComputerName $Server -ScriptBlock $ScriptBlock -ArgumentList $Server -ASJob -JobName $Server
        } catch {Write-Host "Error: Failed to Re-check for updates on $Server" }

    }

    #Monitor & Outoput Progress of Remote Jobs until all completed 
    $Runlimit = (Get-Date).AddMinutes(5)
    Do {

        #Get Current Progress of Jobs
        write-output "$(Get-Date)"
        Write-output $(Get-UpdateCheckJobResults $Jobs | ft -Autosize)
     
        #Snooze for a bit
        Start-Sleep 10

    } until ((($Jobs | where State -eq "Running").Count -eq 0) -or ((Get-Date) -ge $Runlimit))

    #Return Completed Jobs
    write-output "$(Get-Date)"
    $Results = Get-UpdateCheckJobResults $Jobs
    Write-output $Results | FT -AutoSize

    #Highligh Any servers with updates outstnading:
    $FilteredResults = $Results | Where { $_.Outstanding -ne 0 }  #-OR $_.SQLStatus -ne 'Running' }

    if ($FilteredResults){ 
        Call-AzLogging -Type 'Warning' -Message "$($FilteredResults.count) Servers detected With ourstanding Updates" 
        $FilteredResults 
    }

 }

 function Run-ScheduledMaintenanceUpdate(
    [switch]$IncludeSQL,
    [switch]$NoConfirm,
    [switch]$SkipSQLPreChecks,
    $Servers
)
{
    <#
        .SYNOPSIS 
            Performs scheduled maintenance update on given servers

        .DESCRIPTION
            Performs scheduled maintenance update on given Environment / Window OR Specified servers 
            
            Runs though each server to start update process
                Checks and updates PSWindowsUpdate module on remote server
                Creates and start scheduled task on remote server to run update

            Monitors update task on each server until complete
                Checks for presence of update log file
                    If blank log file found, re checks available updates and reports 
                    Otherwise parses log file to determine update progress

            Emails out report linking to log files once complete

        .EXAMPLE
            Run-ScheduledMaintenanceUpdate -Env 'DR' -Window 1

            Installs updates on servers in specified environment window 

        .EXAMPLE
            Run-ScheduledMaintenanceUpdate -Env 'DR' -Servers @(ServerName) -NoConfirm

            Installs updates on provided servers without prompting for confirmation. 
            Environments tag is now only used for logging purposes 
    #>

    #Start Logging
    OpenClose-Transcript -Type "Update" -Name "Update"


    write-output "`n`n$(if($NoConfirm){"Starting"}else{"About to Start"}) Installing updates on the following servers:`n`t$($Servers -Join "`n`t")`n`n"
    if(!$NoConfirm) { $Confirm = read-host "`n`nContinue Y/N ?" }
    if ($Confirm -eq 'Y' -OR $NoConfirm){

        #Import WUPSModule Locally
        Import-Module PSWindowsUpdate

        #Check for log path and create as needed 
        If(!(Test-Path $LogPath)){ New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }

        
        #Command Used localy in Scheduled Task 
        $LocalUpdatecommand = { 
            Import-Module PSWindowsUpdate
            Get-WUList -NotTitle "SQL" -Install -IgnoreReboot -AcceptAll -Verbose | Out-File "C:\$(Get-Date -UFormat "%Y-%m")-PSWindowsUpdate.log" 
        }

        $JobScriptblock = { 
            
            param($Server,$LogPath,$LocalUpdatecommand,$IncludeSQL,$SkipSQLPreChecks)

            $LogFile = "$LogPath\$(Get-Date -UFormat "%Y-%m-%d")-$Server.log"

            #Check & Update PSWindwosUpdate Module available on remote server
            Write-Output "Checking PSWindowsUpdate Module Up-to-date" | Out-File  $LogFile -Append
            $ModInstalled = Invoke-Command -ComputerName $Server -ScriptBlock { Return $(Get-Module -ListAvailable | Where { $_.Name -eq 'PSWindowsUpdate'}) }
            $ExpectedVersion = New-Object -TypeName System.Version -ArgumentList 2.2.0.2
            if((!$ModInstalled) -Or ($ModInstalled.Version -lt $ExpectedVersion)){ 
                Write-Output "Updating PSWindowsUpdate module" | Out-File  $LogFile -Append
                Update-WUModule -ComputerName $Server -Local -Confirm:$false -Verbose | Out-File $LogFile -Append
            }

            #Check and Wait for Pre-Steps to be completed if doing SQL upaates
            if($IncludeSQL){

                #Skip pre-checks if requested 
                #Hacky way to overried Update comand to include SQL 
                if ($SkipSQLPreChecks){

                    $LocalUpdatecommand = { 
                        Import-Module PSWindowsUpdate
                        Get-WUList -Install -IgnoreReboot -AcceptAll -Verbose | Out-File "C:\$(Get-Date -UFormat "%Y-%m")-PSWindowsUpdate.log" 
                    }
                    
                } else {
                    
                    $LocalUpdatecommand = { 

                        if(Get-Service 'SQLSERVERAGENT'-ErrorAction SilentlyContinue){
                            do { 
                                $SQLAgentRunning = Get-Service 'SQLSERVERAGENT' | ? {$_.Status -like 'Running'}
                                Start-Sleep 60
                            } While ($SQLAgentRunning)
                        }
    
                        Import-Module PSWindowsUpdate
                        Get-WUList -Install -IgnoreReboot -AcceptAll -Verbose | Out-File "C:\$(Get-Date -UFormat "%Y-%m")-PSWindowsUpdate.log" 

                        #Stop SQL Server once Updates complete
                        Get-Service -Name 'MSSQLSERVER' | Stop-Service -Force
                    }
                }
            }
    
            #Invoke WU Job Remotly on each target server 
            $RemoteUpdateCommand = { param($LocalUpdatecommand) Invoke-WUJob -RunNow -TaskName "AutomatedUpdates" -Script $LocalUpdatecommand -Confirm:$false -Verbose }  
            Write-Output "Creating and launching update scheduled task on remote server" | Out-File  $LogFile -Append
            Invoke-Command -ComputerName $Server -scriptblock $RemoteUpdateCommand -ArgumentList $LocalUpdatecommand
            Write-Output "Finished" | Out-File  $LogFile -Append
        }

        #Launch background Job to update each server
        $Jobs = @()
        Write-Output "$(Get-Date) - Starting Updates as background Jobs "
        foreach ($Server in $Servers){ $Jobs +=  Start-Job -Name $Server -ScriptBlock $JobScriptblock -ArgumentList $Server,$LogPath,$LocalUpdatecommand,$IncludeSQL,$SkipSQLPreChecks}

        #Monitor starting of update tasks until all complete
        do { 
            
            #Process status for all Jobs
            write-output "$(Get-Date)"
            Get-UpdateJobResults -Jobs $Jobs

            #Snooze for a bit
            Start-Sleep 20

        } until (($Jobs | where State -eq "Running").Count -eq 0)

        #Monitor Remote Update Jobs until all complete
        Write-Output "$(Get-Date) - Checking Status of Remote Update Tasks"

        do {

            #Snooze for a bit
            Start-Sleep 60
            write-output "$(Get-Date)"
            $UpdateResults = Get-UpdateResults -Servers $Servers
            $UpdateResults | ft -AutoSize 
    
        #Until uses different syntax here to account for use of PSCustom Object 
        } until (($UpdateResults.TaskStatus | where { ($_.Value -eq "Starting") -Or ($_.Value -eq "Running") }).count -eq 0)


    }
        
    #Stop Logging
    OpenClose-Transcript -Close
 }

 function Run-SQLAgentRestart(
    $Servers
 )
 {
    #Launch background Job to reboot each server in window and wait for powershell to become available again 
    $Jobs = @()
    foreach ($Server in $Servers){

        $Scriptblock = { 
            param($Server) 
            Get-Service -Computer $Server -Name 'SQLSERVERAGENT' | Set-Service -StartupType Automatic -Status Running -PassThru 
        }

         $Jobs +=  Start-Job -Name $Server -ScriptBlock $Scriptblock -ArgumentList $Server
    }

    do { 
                    
        #Process status for all Jobs
        write-output "$(Get-Date)"
        $Jobs

        #Snooze for a bit
        Start-Sleep 60

    } until (($Jobs | where State -eq "Running").Count -eq 0)

 }

 function Run-ScheduledMaintenanceReboot(
    $Servers,
    [switch]$SkipPreChecks,
    [switch]$NoConfirm
 )
 {
    <#
        .SYNOPSIS 
            Performs scheduled maintenance reboot on given servers

        .DESCRIPTION
            Performs scheduled maintenance reboot on given Environment / Window OR Specified servers 
            After reboot, check for further updates and update WSUS status

            Emails report out on successful completion 

        .EXAMPLE
        Run-ScheduledMaintenanceReboot -Env 'DR'

        Reboots complete environment

        .EXAMPLE
            Run-ScheduledMaintenanceReboot -Env 'DR' -Window 1 -NoConfirm

            Reboots specified window in environment without prompting for confirmation
    #>

    #Start Logging
    OpenClose-Transcript -Type "Reboot" -Name "Reboot"

    write-output "`n`n$(if($NoConfirm){"Starting"}else{"About to start"}) reboot of the following servers:`n`t$($Servers -Join "`n`t")`n`n"
    if(!$NoConfirm) { $Confirm = read-host "`n`nContinue Y/N ?" }
    if ($Confirm -eq 'Y' -OR $NoConfirm){

        #Launch background Job to reboot each server in window and wait for powershell to become available again 
        $Jobs = @()
        foreach ($Server in $Servers){

            $Scriptblock = { 
                param($Server,$SkipPreChecks,$WorkingDir) 

                #Set location to import modules for Child Jobs
                Set-Location $WorkingDir
                
                #Only Procced is SQL Agent NOT running unless skipped
                If ($SkipPreChecks){  $SQLAgentRunning = $false
                
                #Skip check for servers without SQLAgent Installed 
                } else {

                    if(Get-Service -ComputerName $Server 'SQLSERVERAGENT'-ErrorAction SilentlyContinue){

                        #SQL Agent Runs until Pre-steps completed    
                        do { 
                            $SQLAgentRunning = Get-Service -ComputerName $Server 'SQLSERVERAGENT' | ? {$_.Status -like 'Running'}
                            Start-Sleep 60

                        } While ($SQLAgentRunning)

                        <#SQL Server run until SQL updates completed - Logic Reomoved
                        do {
                            $SQLServerRunning = Get-Service -ComputerName $Server 'MSSQLSERVER' | ? {$_.Status -like 'Running'}
                            Start-Sleep 60

                        } While ($SQLServerRunning)
                        #>

                    }
                }

                if(!$SQLAgentRunning){ Restart-Computer -ComputerName $Server -Wait -For PowerShell -Delay 2 -Force }
            }

            #Start reboot as Job
            Write-Output "$(Get-Date) - Starting Reboots as background Jobs "
            $Jobs +=  Start-Job -Name $Server -ScriptBlock $Scriptblock -ArgumentList $Server,$SkipPreChecks,$PWD
        }

        #Monitor Reboot tasks and output status to screen until all complete
        do { 
                
            #Process status for all Jobs
            write-output "$(Get-Date)"
            Get-RebootJobResults $Jobs

            #Snooze for a bit
            Start-Sleep 60

        } until (($Jobs | where State -eq "Running").Count -eq 0)

        #Output final status table
        write-output "$(Get-Date)"
        Get-RebootJobResults $Jobs

    #Stop Logging
    OpenClose-Transcript -Close

    }
 }
