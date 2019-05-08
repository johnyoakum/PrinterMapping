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

# ---------------------------------------------------------------------------------------------------------------------

# Construct TSEnvironment object
$TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Stop

# Read current TSEnvironment variables
$TSEnvironmentVariables = $TSEnvironment.GetVariables()

# Get Only Printers to Install
$Printers = $TSEnvironmentVariables | Where-Object { $_ -like 'Printer*' }

ForEach ( $Printer in $Printers ) {
	$PrinterIP = $TSEnvironment.Value("$Printer")
    Write-CMLogEntry -Value "Found TS Variable: $Printer" -Severity 1
	Write-CMLogEntry -Value "Value of $Printer  ----  $PrinterIP" -Severity 1
	Add-Printer -ConnectionName \\anc-printserv01\$PrinterIP | Out-Null
}

