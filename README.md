# PowershellHelpers
These are a set of function generally usefull to have  on a day-to-day basis. When install.bat is run, this module will be placed in ``` %USERPROFILE%\Documents\WindowsPowerShell\Modules\Helpers\ ```. This will automatically import the module when a powershell window is opened allowing the user immediate access to those functions.

## Functions

### Start-Watch
Repetitively runs a script block to allow you to track changes in the command output. An example use would be for watching log inputs. Press CTRL+C to cancel script. It runs indefinitely.
  
```
Start-Watch -ScriptBlock {Get-Content -Path "C:\Logs\SomeLog.log" -Tail 20} -Interval 10
```

### Show-ArrayForm
Creates an array from a form that can be copy-pasted into

```
$MyArray = Show-ArrayForm
```

### Show-DeDupeForm
Shows a form that can be copy-pasted into. Elements pasted will be deduped

```
Show-DeDupeForm
```

### Select-Unique 
Shorthand for {Sort-Object | Select -Unique}

```
Select-Unique -Objects $MyArray -Property Name
```
or
```
$MyArray | Select-Unique -Property Name -Descending
```

### Split-File
When used with the "restore" switch, restores the specified file. Otherwise, it splits the specified file. This is a dumb fire script with little validation. If you select a file to restore, it will stitch it and any file named similiarly with seguential file names. For example, if you restore a file named "a.0", it will search for all a.# files and stitch them together, whether they were exported by this script or not.

This example splits OriginalFile.zip into OriginalFile.zip.0, OriginalFile.zip.1, OriginalFile.zip.x, where each piece is 4096MB large	
```
Split-File -LoadFile "C:\OriginalFile.zip" -SaveFile "C:\OriginalFile.zip" -SegmentSize 4096
```
This example takes a list of files named SomeSplitFile.zip.0, SomeSplitFile.zip.1, SomeSplitFile.zip.x, and restores them to a single file named OriginalFile.zip
```
Split-File -LoadFile "C:\SomeSplitFile.zip.0" -SaveFile "C:\OriginalFile.zip" -Restore
```
