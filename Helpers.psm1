<#
.SYNOPSIS
    Repetitively runs a script block to allow you to track changes in the command output. An example use would be for watching log inputs. Press CTRL+C to cancel script. It runs indefinitely.

.PARAMETER ScriptBlock
    Script to execute

.PARAMETER Interval
    How often to rerun scriptblock in seconds
  
.EXAMPLE
    &"Start-Watch.ps1" -ScriptBlock {Get-Content -Path "C:\Logs\SomeLog.log" -Tail 20} -Interval 10
#>
function Start-Watch
{
    Param([scriptblock]$ScriptBlock={Write-Warning "You did not supply a script block"}, [int32]$Interval=5)
    #Set lowest possible datetime, so that it will run script immediatly
    $Start = [DateTime]::MinValue
    Clear-Host
    #Infinite loop, cancel require user intervention (CTRL+C)
    while($true)
    {
        #If enough time has passed (Now - LastAttempt)>Selected interval
        if ([DateTime]::Now - $Start -ge [TimeSpan]::FromSeconds($Interval))
        {
            #Clear console and call function
            $Res = $ScriptBlock.Invoke()
            Clear-Host
            $Res
            #Set new start time/last attempt
            $Start = [DateTime]::Now
        }
        #Sleep the thread, prevents CPU from falsly registering as 100% utilized
        [System.Threading.Thread]::Sleep(1)
    }
}

<#
.SYNOPSIS
    Creates an array from a form that can be copy-pasted into

.EXAMPLE
    $MyArray = Show-ArrayForm
#>
function Show-ArrayForm
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

    #Create form
    $Form = New-Object System.Windows.Forms.Form
    $List = New-Object System.Windows.Forms.TextBox
    $List.Multiline = $true;
    $List.AutoSize = $true;
    $List.Dock = [System.Windows.Forms.DockStyle]::Fill;
    $DeDupButton = New-Object System.Windows.Forms.Button
    $DeDupButton.Dock=[System.Windows.Forms.DockStyle]::Bottom;
    $DeDupButton.Text = "Array-ify!";
    $ToReturn = $null
    #Add on click event. This does the deduping
    $DeDupButton.Add_Click({
        $Form.Close();
    })
    #Add controls to form
    $Form.Controls.Add($DeDupButton);
    $Form.Controls.Add($List);
    #Show form.
    $Form.ShowDialog()| Out-Null

    $ToReturn =$List.Lines;

    $Form.Dispose();

    return $ToReturn
}

<#
.SYNOPSIS
    Shows a form that can be copy-pasted into. Elements pasted will be deduped

.EXAMPLE
    Show-DeDupeForm
#>
function Show-DeDupeForm
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

    #Create form
    $Form = New-Object System.Windows.Forms.Form
    $List = New-Object System.Windows.Forms.TextBox
    $List.Multiline = $true;
    $List.AutoSize = $true;
    $List.Dock = [System.Windows.Forms.DockStyle]::Fill;
    $DeDupButton = New-Object System.Windows.Forms.Button
    $DeDupButton.Dock=[System.Windows.Forms.DockStyle]::Bottom;
    $DeDupButton.Text = "Dedup!";
    #Add on click event. This does the deduping
    $DeDupButton.Add_Click({
        $DeDuped="";
        $Before = $List.Lines.Length;
        $List.Lines | Sort-Object | Select -Unique | ForEach-Object -Process {$DeDuped+=$_+"`r`n"}
        if ($DeDuped.Length -gt 2) {
            $DeDuped = $DeDuped.Substring(0,$DeDuped.Length-2); #Remove trailing \r\n
        }
        $List.Text = $DeDuped
        $Form.Text = "DeDupe! "+($Before-$List.Lines.Length).ToString()+" removed!"
    })
    #Add controls to form
    $Form.Controls.Add($DeDupButton);
    $Form.Controls.Add($List);
    #Show form.
    $Form.ShowDialog();
    #Script ends when user closes the window.
}

<#
.SYNOPSIS
    Shorthand for {Sort-Object | Select -Unique}

.EXAMPLE
    Select-Unique -Objects $MyArray -Property Name

.EXAMPLE
    $MyArray | Select-Unique -Property Name -Descending
#>
function Select-Unique
{
    Param([Parameter(ValueFromPipeline=$true)]$Objects, $Property, [switch]$Descending)
    return ($Objects | Sort-Object -Property $Property -Descending:$Descending | Select -Unique)
}

<#
.SYNOPSIS
    Splits any single file into multiple parts, or, restores a file from multiple parts.
 
.DESCRIPTION
    When used with the "restore" switch, restores the specified file. Otherwise, it splits the specified file. This is a dumb fire script with little validation. If you select a file to restore, it will stitch it and any file named similiarly with seguential file names. For example, if you restore a file named "a.0", it will search for all a.# files and stitch them together, whether they were exported by this script or not.
 
.PARAMETER LoadFile
    The full path and name of the file to load. If restoring a file, please select the first segment. "The one ending in '.0'.
 
.PARAMETER SaveFile
    The full path and name of the file to save. If not restoring, then the base file name. The sequential numbers will be added automatically.
 
.PARAMETER SegmentSize
    The size that each of the file segments should be in megabytes. (Default 1024 or 1Gb)
 
.PARAMETER ReadBuffer
    The buffer that data is temporarily stored in while the file is being read in bytes. You do not need to change this usually. (Default 4096 or 4Kb)
 
.INPUTS
    LoadFile, and if restore, LoadFile+".#" where "#" represents a segment of the completed file.
 
.OUTPUTS
    If restore, the SaveFile path supplied. Otherwise, multiple files with SaveFile+".#" where "#" is the sequential number of that file segment.
 
.EXAMPLE
    Split-File -LoadFile "C:\OriginalFile.zip" -SaveFile "C:\OriginalFile.zip" -SegmentSize 4096
 
.EXAMPLE
    Split-File -LoadFile "C:\SomeSplitFile.zip.0" -SaveFile "C:\OriginalFile.zip" -Restore
#>
function Split-File
{
    Param($LoadFile,$SaveFile=$LoadFile,[switch]$Restore, $SegmentSize=1024, $ReadBuffer = 4096)
    #Convert from MB to KB to B
    $SegmentSize = $SegmentSize * 1024 * 1024 
    #Initialize read buffer
    $Buffer = New-Object Byte[] $ReadBuffer
    #Amount read in a pass.
    $AmtRead=$null
    #Current file segment
    $I = 0;
    #DateTime for update
    $LastUpdate = [DateTime]::Now

    #SPLITTING
    if (!$Restore)
    {
        Write-Progress -Activity "Splitting" -Status "Starting" -PercentComplete 0
        $StreamReader = New-Object System.IO.FileStream -ArgumentList @($LoadFile, [System.IO.FileMode]::Open)
        $StreamWriter = New-Object System.IO.FileStream -ArgumentList @(($SaveFile+"."+$I.ToString()), [System.IO.FileMode]::Create)
 
        #CurrentSize of the file segment we are working on.
        $TotalSize = $StreamReader.Length
        $CurrentTotal = 0
        $CurrentSize=0
        while($AmtRead -ne 0 -or $AmtRead -eq $null)
        {
            #Read the file to memory
            $AmtRead=$StreamReader.Read($Buffer,0,$ReadBuffer)
            if ($AmtRead-gt 0)
            {
                #Write the file to the file segment
                $StreamWriter.Write($Buffer,0,$AmtRead);
                $CurrentSize +=$AmtRead;
                $CurrentTotal += $AmtRead;
                if ([DateTime]::Now - $LastUpdate -gt [TimeSpan]::FromSeconds(5))
                {
                    Write-Progress -Activity "Splitting" -Status "Writing" -PercentComplete (($CurrentTotal*100)/$TotalSize)
                    $LastUpdate = [DateTime]::Now
                }
            }
            if ($CurrentSize -ge $SegmentSize)
            {
                #Once the current segment is larger or equal to the specified size, finish the file and start a new segment.
                $CurrentSize =0;
                $StreamWriter.Close();
                $I++;
                $StreamWriter = New-Object System.IO.FileStream -ArgumentList @(($SaveFile+"."+$I.ToString()), [System.IO.FileMode]::Create)
                Write-Progress -Activity "Splitting" -Status "New-File" -PercentComplete (($CurrentTotal*100)/$TotalSize)
            }
        }
        #CleanUp
        $StreamWriter.Close();
        $StreamReader.Close();
        Write-Progress -Activity "Splitting" -Status "Completed" -PercentComplete 100 -Completed
    }
    else # RESTORING
    {
        #Cleanup LoadFile
        if (!$LoadFile.EndsWith(".0"))
        {
            #A poor attempt at ensuring that we are about to restore the right files.
            throw "The specified file to load does not end with a '.0'."
            return 1
        }
        $LoadFile = $LoadFile.Substring(0,$LoadFile.Length-2)

        $TotalSize =0;
        $CurrentTotal =0;
        Write-Progress -Activity "Restoring" -Status "Starting" -PercentComplete 0

        while($true)
        {
            $FI = New-Object System.IO.FileInfo -ArgumentList @($LoadFile+"."+$I.ToString())
            $TotalSize += $FI.Length
            $I++;
            if (-not [System.IO.File]::Exists($LoadFile+"."+$I.ToString()))
            {
                break;
            }
        }

        $I=0;
        $StreamWriter = New-Object System.IO.FileStream -ArgumentList @($SaveFile, [System.IO.FileMode]::Create)
        $StreamReader = New-Object System.IO.FileStream -ArgumentList @(($LoadFile+"."+$I.ToString()), [System.IO.FileMode]::Open)
        while($StreamReader -ne $null)
        {
            #Initialize
            $AmtRead=$null
            #While we have received data from a read attempt, keep looping
            while($AmtRead -ne 0 -or $AmtRead -eq $null)
            {
                #Read data from a file segment
                $AmtRead=$StreamReader.Read($Buffer,0,$ReadBuffer)
                if ($AmtRead-gt 0)
                {
                    #Write it to the restored file
                    $StreamWriter.Write($Buffer,0,$AmtRead);
                    $CurrentTotal+=$AmtRead;
                    if ([DateTime]::Now - $LastUpdate -gt [TimeSpan]::FromSeconds(5))
                    {
                        Write-Progress -Activity "Restoring" -Status "Writing" -PercentComplete (($CurrentTotal*100)/$TotalSize)
                        $LastUpdate = [DateTime]::Now
                    }
                }
            }
            #Close the current segment we are reading.
            $StreamReader.Close()
            $I++;
            if ([System.IO.File]::Exists($LoadFile+"."+$I.ToString()))
            {
                #If another segment exists, read it too.
                $StreamReader = New-Object System.IO.FileStream -ArgumentList @(($LoadFile+"."+$I.ToString()), [System.IO.FileMode]::Open)
                Write-Progress -Activity "Restoring" -Status "Open-File" -PercentComplete (($CurrentTotal*100)/$TotalSize)
            }
            else
            {
                #Otherwise, remove the StreamReader. This triggers the loop to end.
                $StreamReader = $null
            }
        }
        #CleanUp
        $StreamWriter.Close();
        Write-Progress -Activity "Restoring" -Status "Complete" -PercentComplete 100 -Completed
    }
}

<#
.SYNOPSIS
    Search a directory of files for some regex pattern.
 
.PARAMETER Path
    Directory containing files to search
 
.PARAMETER RegexPattern
    Pattern to find

.PARAMETER Include
    Files to search, defaults to txt, log and lo_ (*.txt, *.log, *.lo_)
 
.EXAMPLE
    Search-Files -Path "C:\MyLogs" -RegexPattern "0x00000001"

#>
function Search-Files
{
    Param($Path, $RegexPattern, $Include=@("*.txt","*.log",".lo_"))
    $Files = Get-ChildItem -Path $Path -Include $Include -Recurse
    $ToReturn = @()
    foreach ($File in $Files) {
        $Content = Get-Content -Path $File.FullName -Raw
        if ($Content -match $RegexPattern) {
            $ToReturn += $File.FullName
        }
    }
    return $ToReturn
}

<#
.SYNOPSIS
    Recursively hashes files in an array and returns results as an array
.PARAMETER Path
    Path to search through
.PARAMETER IgnoreEmptyDirectories
    If set, will not report on directories that are empty
  
.EXAMPLE
    Get-DirectoryHashArray -Path C:\Users -IgnoreEmptyDirectories
#>
function Get-DirectoryHashArray {
    Param($Path, [switch]$IgnoreEmptyDirectories)
    #Cleanup and root path
    $Path = [System.IO.Path]::GetFullPath($Path).ToUpper()
    if (-not $Path.EndsWith("\")) {
        $Path = $Path+"\"
    }

    #Store results in this
    $Results = @()

    Write-Progress -Activity "Searching $Path" -Status "Files" -PercentComplete 0
    $Files = Get-ChildItem -Path $Path -Recurse -File
    Write-Progress -Activity "Searching $Path" -Status "Folders" -PercentComplete 33
    if ($IgnoreEmptyDirectories) {
        $Folders = $Files | ForEach-Object {$_.Directory}
    } else {
        $Folders = Get-ChildItem -Path $Path -Recurse -Directory        
    }

    Write-Progress -Activity "Searching $Path" -Status "Writing Folders to results" -PercentComplete 66
    #Log each directory
    foreach ($Folder in $Folders) {
        $Results += New-Object -TypeName PSObject -Property @{Type="Directory"; Path=$Folder.FullName.ToUpper().Replace($Path, ""); Hash=""}
    }
    Write-Progress -Activity "Searching $Path" -Completed

    $I=0
    #File results
    foreach ($File in $Files) {
        #Cleanup path for report
        $FilePath = $File.FullName.ToUpper().Replace($Path, "")

        Write-Progress -Activity "Hashing files from $Path" -Status "$FilePath" -PercentComplete ($I*100/$Files.Length)
        $Hash = Get-FileHash -Path $File.FullName -Algorithm SHA256
        
        $Results += New-Object -TypeName PSObject -Property @{Type="File"; Path=$FilePath; Hash=$Hash.Hash}
        $I++;
    }

    return $Results
}

<#
.SYNOPSIS
    Compares two file hash arrays and reports the differences.
.PARAMETER OldHashArray
    The original results as returned from Get-DirectoryHashArray
.PARAMETER NewHashArray
    New set of results to compare againt OldHashArray
.PARAMETER VerboseReport
    Reports on files/directories that are the same vs just the differences
  
.EXAMPLE
    Compare-HashArrays -OldHashArray $OldArray -NewHashArray $NewArray
#>
function Compare-HashArrays {
    Param([Alias("HashArrayA", "OriginalHashArray")]$OldHashArray, [Alias("HashArrayB")]$NewHashArray, [switch]$VerboseReport)
    #Store results in this
    $Results = @()

    #Build some hashtables to speed up comparisons
    Write-Progress -Activity "Optimizing Data" -PercentComplete ($I*100/($OldHashArray.Length+$NewHashArray.Length));
    $OldDirectoryHashTable= @{}
    $NewDirectoryHashTable = @{}
    $OldFileHashTable = @{}
    $NewFileHashTable = @{}

    foreach ($OldHash in $OldHashArray) {
        Write-Progress -Activity "Indexing Data" -Status "OldHashArray" -PercentComplete ($I*100/($OldHashArray.Length+$NewHashArray.Length));
        $I++;
        if ($_.Type -eq "Directory") {
            $OldDirectoryHashTable.Add($OldHash.Path,$OldHash)
        } else {
            $OldFileHashTable.Add($OldHash.Path,$OldHash)
        }
    }
    foreach ($NewHash in $NewHashArray) {
        Write-Progress -Activity "Indexing Data" -Status "NewHashArray" -PercentComplete ($I*100/($OldHashArray.Length+$NewHashArray.Length));
        $I++;
        if ($_.Type -eq "Directory") {
            $NewDirectoryHashTable.Add($NewHash.Path,$NewHash)
        } else {
            $NewFileHashTable.Add($NewHash.Path,$NewHash)
        }
    }

    Write-Progress -Activity "Comparing Arrays"
    #Verify Directories
    $I=0;
    foreach ($HashItemKey in $OldDirectoryHashTable.Keys) {
        $HashItem = $OldDirectoryHashTable[$HashItemKey]
        Write-Progress -Activity "Comparing Arrays" -Status "Directories in old vs new" -CurrentOperation "$($I*100/($OldDirectoryHashTable.Count+$NewDirectoryHashTable.Count))%" -PercentComplete ($I*100/($OldDirectoryHashTable.Count+$NewDirectoryHashTable.Count))
        $I++

        $Found = $NewDirectoryHashTable.ContainsKey($HashItemKey)
        if ($Found -eq $false) {
            $Results+= New-Object -TypeName PSObject -Property @{Path=$HashItem.Path; Type=$HashItem.Type; InOld=$true; InNew=$false; HashMatch=""}
        } elseif ($VerboseReport) {
            $Results+= New-Object -TypeName PSObject -Property @{Path=$HashItem.Path; Type=$HashItem.Type; InOld=$true; InNew=$true; HashMatch=""}
        }
    }
    foreach ($HashItemKey in $NewDirectoryHashTable.Keys) {
        $HashItem = $NewDirectoryHashTable[$HashItemKey]

        Write-Progress -Activity "Comparing Arrays" -Status "Directories in new vs old" -CurrentOperation "$($I*100/($OldDirectoryHashTable.Count+$NewDirectoryHashTable.Count))%" -PercentComplete ($I*100/($OldDirectoryHashTable.Count+$NewDirectoryHashTable.Count))
        $I++

        $Found = $OldDirectoryHashTable.ContainsKey($HashItemKey)
        if ($Found -eq $false) {
            $Results+= New-Object -TypeName PSObject -Property @{Path=$HashItem.Path; Type=$HashItem.Type; InOld=$false; InNew=$true; HashMatch=""}
        }
    }
    
    $I=0; #Reset progress
    #Verify Files
    foreach ($HashItem in $OldHashArray) {
        Write-Progress -Activity "Comparing Arrays" -Status "Files in old vs new" -CurrentOperation "$($I*100/($OldHashArray.Length+$NewHashArray.Length))%" -PercentComplete ($I*100/($OldHashArray.Length+$NewHashArray.Length))
        $I++
        if ($HashItem.Type -eq "File") {
            $FoundFile = $null

            if ($NewFileHashTable.ContainsKey($HashItem.Path)) {
                $FoundFile = $NewFileHashTable[$HashItem.Path]
            }
            if ($FoundFile -ne $null -and $FoundFile.Hash -eq $HashItem.Hash) {
                if ($VerboseReport) {
                    $Results+= New-Object -TypeName PSObject -Property @{Path=$HashItem.Path; Type=$HashItem.Type; InOld=$true; InNew=$true; HashMatch=$true}
                }
            } elseif ($FoundFile -ne $null) {
                $Results+= New-Object -TypeName PSObject -Property @{Path=$HashItem.Path; Type=$HashItem.Type; InOld=$true; InNew=$true; HashMatch=$false}
            } else {
                $Results+= New-Object -TypeName PSObject -Property @{Path=$HashItem.Path; Type=$HashItem.Type; InOld=$true; InNew=$false; HashMatch=$false}
            }
        }
    }
    foreach ($HashItem in $NewHashArray) {
        Write-Progress -Activity "Comparing Arrays" -Status "Files in new vs old" -CurrentOperation "$($I*100/($OldHashArray.Length+$NewHashArray.Length))%" -PercentComplete ($I*100/($OldHashArray.Length+$NewHashArray.Length))
        $I++
        if ($HashItem.Type -eq "File") {
            $FoundFile = $OldFileHashTable.ContainsKey($HashItem.Path)
            if ($FoundFile -eq $null) {
                $Results+= New-Object -TypeName PSObject -Property @{Path=$HashItem.Path; Type=$HashItem.Type; InOld=$true; InNew=$false; HashMatch=$false}
            }
        }
    }

    return $Results
}


Export-ModuleMember -Function Split-File, Search-Files, Start-Watch, Show-ArrayForm, Show-DeDupeForm, Select-Unique, Get-DirectoryHashArray, Compare-HashTables
