<#
    .SYNOPSIS
    Queries currently installed printers and sets a task sequence variable named "printer" for reinstallation
    .DESCRIPTION
    This script will query the local system for all printer objects installed and then any that have IP ports, will store those IPs for mapping new printer during OSD.
    .EXAMPLE
    .\Get-InstalledPrinters.ps1
    .NOTES
    FileName:    Get-InstalledPrinters.ps1
    Author:      John Yoakum
    Created:     2019-05-02
    
    Version history:
    1.0.0 - (2019-05-02) Script created

#>

# Toggle Debug Mode
$Debug = $False

# Create Archive folder if it doesn't exist for this log file and for sending logs
$TestPath = Test-Path -path c:\Archive
If (!$TestPath){ $LogsDirectory = New-Item -Path 'c:\Archive' -Force -ItemType Directory }
else { $LogsDirectory = 'c:\Archive' }

# Function to write to log file
function Write-CMLogEntry {
  param (
    [parameter(Mandatory = $true, HelpMessage = 'Value added to the log file.')]
    [ValidateNotNullOrEmpty()]
    [string]$Value,
    [parameter(Mandatory = $true, HelpMessage = 'Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.')]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('1', '2', '3')]
    [string]$Severity,
    [parameter(Mandatory = $false, HelpMessage = 'Name of the log file that the entry will written to.')]
    [ValidateNotNullOrEmpty()]
    [string]$FileName = 'PrinterMapping.log'
  )
  # Determine log file location
  $LogFilePath = Join-Path -Path $LogsDirectory -ChildPath $FileName
		
  # Construct time stamp for log entry
  $Time = -join @((Get-Date -Format 'HH:mm:ss.fff'), '+', (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
		
  # Construct date for log entry
  $Date = (Get-Date -Format 'MM-dd-yyyy')
		
  # Construct context for log entry
  $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
		
  # Construct final log entry
  $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""PackageMapping"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
		
  # Add value to log file
  try
  {
    Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
  }
  catch
  {
    Write-Warning -Message "Unable to append log entry to PackageMapping.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
  }
}

# Initialize the TS Environment
If (!$Debug) { $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment }

# Get all installed printer objects from registry
$PrintersInstalled = Get-ChildItem -Path HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers

# Declare the arrays to be used
$PrinterPorts =@()
$PrintPort=@()

# Enumerate the installed printers for printer name and port
Write-CMLogEntry -Value '-------------------------------------------------------------' -Severity 1
Write-CMLogEntry -Value 'Finding all installed printers....' -Severity 1

$Items = $PrintersInstalled | Foreach-Object {Get-ItemProperty $_.PsPath }

    ForEach ($Item in $Items)
        {
            $PrinterName = $Item.PSChildName
            $PPort = $Item.Port
            $LogText1 = "Found Printer: $PrinterName  ----  Port: $PPort"
            #Write-CMLogEntry -Value $LogText1 -Severity 1
            Write-CMLogEntry -Value "Found Printer: $PrinterName  ----  Port: $PPort" -Severity 1
            $comp_name = $Item.Port
            $IPAddress = $comp_name -replace "_","."
            $IPAddress -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | Out-Null
            if ( $matches.Values -notin $PrintPort.IPAddress )
                {
                    $PrintPort += [pscustomobject]@{
                        IPAddress = $matches.Values
                }
        }
    }

<#
    ForEach ($FoundPrinter in $PrinterPorts) {
        $LogText1 = "Found Printer: $FoundPrinter"
        Write-CMLogEntry -Value $LogText1 -Severity 1
    }
#>
# Parse the port for the IP Address. This will also replace any "_" with a "." for consistent checking
Write-CMLogEntry -Value 'Going through list of printers and retrieving only those associated with an IP Address' -Severity 1
#Write-CMLogEntry -Value 'Setting Unique Ports for no duplicates' -Severity 1
$UniquePorts = $PrintPort.IPAddress | Get-Unique -AsString

$TotalCountOfPorts = $PrintPort.Count

$LogText0 = "Found a total of $TotalCountOfPorts printers mapped by IP Address."
Write-CMLogEntry -Value $LogText0 -Severity 1

ForEach ($UniquePort in $UniquePorts) {
    $LogText2 = "Printer with IP Address Found at: $UniquePort"
    Write-CMLogEntry -Value $logText2 -Severity 1
}

$Count = 0

# Section of code to set the task sequence value to set installed printers
foreach ($Port in $UniquePorts)
{
  $Id = "{0:D2}" -f $Count
  $AppId = "Printer$Id" 
  If (!$Debug) { $TSEnv.Value($AppId) = $Port }
  $LogText3 = "Setting Task Sequence Variable $AppID to $Port"
  Write-CMLogEntry -Value $logText3 -Severity 1
  $Count = $Count + 1

    
}
