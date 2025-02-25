function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$LogPath,

        [Parameter(Mandatory=$true)]
        [string]$Message   
    )

    [string]$MessageTimeStamp=(get-date).ToString('yyyy-MM-dd HH:mm:ss')
    $Message1 = "$MessageTimeStamp -[Line $($MyInvocation.ScriptLineNumber)] $Message"
    $Line = $Env:Username+", "+ $Message1
    $Line | Out-File -FilePath $LogPath -Append
}

#try to set the remote server as a drive

#Specify the location of the FILEWATCHER.LOG
$LogPath = "$PSScriptRoot\Filewatcher.log"

# specify the path to the folder you want to monitor:
$Path = "$PSScriptRoot\WatchFolder"

# specify which files you want to monitor
$FileFilter = '*.*'

# specify whether you want to monitor subfolders as well:
$IncludeSubfolders = $true

# specify the file or folder properties you want to monitor:
$AttributeFilter = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastWrite 

try{

    #Set up file watcher 
    $watcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
        Path = $Path
        Filter = $FileFilter
        IncludeSubdirectories = $IncludeSubfolders
        NotifyFilter = $AttributeFilter
    }

    # define the code that should execute when a change occurs:
    $action = {
        function Write-Log {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory=$true)]
                [string]$LogPath,
        
                [Parameter(Mandatory=$true)]
                [string]$Message   
            )
        
            [string]$MessageTimeStamp=(get-date).ToString('yyyy-MM-dd HH:mm:ss')
            $Message1 = "$MessageTimeStamp -[Line $($MyInvocation.ScriptLineNumber)] $Message"
            $Line = $Env:Username+", "+ $Message1
            $Line | Out-File -FilePath $LogPath -Append
        }

        # change type information:
        $details = $event.SourceEventArgs
        $FullPath = $details.FullPath
        
        # type of change:
        $ChangeType = $details.ChangeType
        
        # when the change occured:
        $Timestamp = $event.TimeGenerated
        
        # you can also execute code based on change type here:
        switch ($ChangeType) {
            'Created'{

                $Folders = @(
                    "User1",
                    "User2",
                    "User3"
                )

                #Set Condition to make sure the folder is in one of the specified folders
                $condition = $null -ne ($Folders | Where-Object { $FullPath -match $_ })

                $filetype = $FullPath[-4..-1]

                #intake\user1\test.txt ----> Destination\TextDocs\User1\test.txt
                If($condition -and $FullPath -like "*\Intake*" -and $filetype -like ".txt"){ 

                    $message = "{0} was {1} at {2}" -f $FullPath, $ChangeType, $Timestamp
                    Write-Log -Logpath $LogPath -message $message

                    #user a little string manipulation to create your destination Folder by taking your source and replacing files names in the string. 
                    $Destination = $FullPath -replace [regex]::Escape("\Intake"),"\Destination\TextDocs"

                    #COPY of Move?
                    Move-Item filesystem::$FullPath -Destination filesystem::$Destination -Force
                    
                    $ChangeType = "Moved"
                    $message = "{0} was {1} to {2} at {3}" -f $FullPath, $ChangeType, $Destination,$Timestamp
                    Write-Log -Logpath $LogPath -message $message

                }
                #intake\user1\test.ps1 ----> Destination\PowershellScripts\User1\test.ps1
                Elseif($condition -and $FullPath -like "*\Intake*" -and $filetype -like ".ps1"){

                    $message = "{0} was {1} at {2}" -f $FullPath, $ChangeType, $Timestamp
                    Write-Log -Logpath $LogPath -message $message
                    
                    $Destination = $FullPath -replace [regex]::Escape("\Intake"),"\Destination\PowershellScripts"
                    
                    #COPY of Move?
                    Copy-Item filesystem::$FullPath -Destination filesystem::$Destination -Force

                    $ChangeType = "Copied"
                    $message = "{0} was {1} to {2} at {3}" -f $FullPath, $ChangeType, $Destination,$Timestamp
                    Write-Log -Logpath $LogPath -message $message
                }                
                #intake\user1\test.pdf ----> Destination\other\User1\test.pdf
                Elseif($condition -and $FullPath -like "*\Intake*"){

                    $message = "{0} was {1} at {2}" -f $FullPath, $ChangeType, $Timestamp
                    Write-Log -Logpath $LogPath -message $message
                    
                    $Destination = $FullPath -replace [regex]::Escape("\Intake"),"\Destination\Other"
                    
                    #COPY of Move?
                    Copy-Item filesystem::$FullPath -Destination filesystem::$Destination -Force

                    $ChangeType = "Copied"
                    $message = "{0} was {1} to {2} at {3}" -f $FullPath, $ChangeType, $Destination,$Timestamp
                    Write-Log -Logpath $LogPath -message $message
                }
                
            }
            'Deleted' { "DELETED" }
            'Renamed' { "RENAMED" }    
            # any unhandled change types surface here:
            default { Write-Log -Logpath $LogPath -message $_}
        }
    }

    # subscribe your event handler to all event types that are
    # important to you. Do this as a scriptblock so all returned
    # event handlers can be easily stored in $handlers:
    $handlers = . {
        Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action 
        Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action 
        Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action 
    }

    # monitoring starts now:
    $watcher.EnableRaisingEvents = $true

    Write-Log -Logpath $LogPath -message "Watching for changes to $Path"

    do{
        # Wait-Event waits for a second and stays responsive to events
        # Start-Sleep in contrast would NOT work and ignore incoming events
        Wait-Event -Timeout 1   
    } while ($true)
}
finally{
    # this gets executed when user presses CTRL+C:
    
    # stop monitoring
    $watcher.EnableRaisingEvents = $false
    
    # remove the event handlers
    $handlers | ForEach-Object {
        Unregister-Event -SourceIdentifier $_.Name
    }
    
    # event handlers are technically implemented as a special kind
    # of background job, so remove the jobs now:
    $handlers | Remove-Job
    
    # properly dispose the FileSystemWatcher:
    $watcher.Dispose()
    
    Write-Log -Logpath $LogPath -message "Event Handler disabled, monitoring ends."
}