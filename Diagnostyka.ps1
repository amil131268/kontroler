$ErrorActionPreference = 'Stop'
$warnings = [System.Collections.Generic.List[string]]::new()
$spooler = 'Nie ustalono'
try { $spooler = [string](Get-Service Spooler -ErrorAction Stop).Status }
catch { $warnings.Add("Nie odczytano bufora wydruku: $($_.Exception.Message)") }
$printers = @()
try { $printers = @(Get-CimInstance Win32_Printer -OperationTimeoutSec 20) }
catch { $warnings.Add("Nie odczytano listy drukarek: $($_.Exception.Message)") }
$drivers = @()
try { $drivers = @(Get-CimInstance Win32_PrinterDriver -OperationTimeoutSec 20) }
catch { $warnings.Add("Nie odczytano sterowników: $($_.Exception.Message)") }
$jobs = @(); $jobsKnown = $true
try { $jobs = @(Get-CimInstance Win32_PrintJob -OperationTimeoutSec 20) }
catch { $jobsKnown = $false; $warnings.Add("Nie odczytano kolejki wydruku: $($_.Exception.Message)") }
$statusNames = @{1='Inny'; 2='Nieznany'; 3='Bezczynna'; 4='Drukowanie'; 5='Rozgrzewanie'; 6='Zatrzymana'; 7='Offline'}
$errorNames = @{0='Nieznany'; 1='Inny'; 2='Brak błędu'; 3='Mało papieru'; 4='Brak papieru'; 5='Mało tonera'; 6='Brak tonera'; 7='Otwarta pokrywa'; 8='Zacięcie papieru'; 9='Offline'; 10='Wymagana interwencja'; 11='Zablokowany podajnik'; 12='Zablokowany odbiornik'; 13='Problem ze stroną testową'}
$items = @(foreach ($p in $printers) {
    $issues = [System.Collections.Generic.List[string]]::new()
    $unknown = [System.Collections.Generic.List[string]]::new()
    if ($spooler -ne 'Running') { $issues.Add("Bufor wydruku: $spooler") }
    if ($p.WorkOffline -or $p.PrinterStatus -eq 7) { $issues.Add('Drukarka w trybie offline') }
    if (([int]$p.PrinterState -band 1) -ne 0 -or $p.ExtendedPrinterStatus -eq 8) { $issues.Add('Drukowanie wstrzymane') }
    if ($p.PrinterStatus -eq 6) { $issues.Add('Drukarka zatrzymana') }
    if ($null -ne $p.DetectedErrorState -and $p.DetectedErrorState -gt 2) {
        $description = $errorNames[[int]$p.DetectedErrorState]
        if (-not $description) { $description = "Kod $($p.DetectedErrorState)" }
        $issues.Add($description)
    } elseif ($null -eq $p.DetectedErrorState -or $p.DetectedErrorState -lt 2) { $unknown.Add('Sterownik nie przekazał jednoznacznej informacji o błędach urządzenia.') }
    $printerJobs = @($jobs | Where-Object {
        $separator = ([string]$_.Name).LastIndexOf(',')
        $separator -ge 0 -and ([string]$_.Name).Substring(0, $separator) -eq $p.Name
    })
    $jobLines = @(foreach ($j in $printerJobs) {
        if ($j.JobStatus -match 'Error|Offline|Paperout|Blocked|User_Intervention' -or ([int]$j.StatusMask -band 1634) -ne 0) { $issues.Add("Problem zadania $($j.JobId): $($j.JobStatus)") }
        "ID $($j.JobId) | $($j.Document) | status: $($j.JobStatus) | stron: $($j.TotalPages)"
    })
    if (-not $jobsKnown) { $unknown.Add('Nie udało się odczytać kolejki.') }
    $driver = $drivers | Where-Object { $_.Name -eq $p.DriverName -or ([string]$_.Name).StartsWith("$($p.DriverName),", [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
    $version = 'Nie ustalono'
    if ($driver -and $driver.DriverPath) {
        try { $v = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($driver.DriverPath).FileVersion; if ($v) { $version = $v } } catch { }
    }
    if ($version -eq 'Nie ustalono') { $unknown.Add('Wersja pliku sterownika niedostępna.') }
    $connection = 'Inne / nie ustalono'
    if ($p.PortName -match '(^|,)\s*USB\d+') { $connection = 'USB (według portu)' }
    elseif ($p.Network -or $p.PortName -match '^IP_|^WSD') { $connection = 'Sieciowe' }
    elseif ($p.PortName -match 'PORTPROMPT:|FILE:|nul:') { $connection = 'Wirtualne / plik' }
    $status = $statusNames[[int]$p.PrinterStatus]
    if (-not $status) { $status = 'Nie ustalono' }
    $summary = 'Brak zgłoszonych problemów'
    if ($unknown.Count -gt 0) { $summary = 'Niepełna diagnostyka' }
    if ($issues.Count -gt 0) { $summary = 'Wymaga sprawdzenia' }
    [pscustomobject]@{
        Name=[string]$p.Name; Default=[bool]$p.Default; Connection=$connection
        Driver=[string]$p.DriverName; Version=$version; Port=[string]$p.PortName
        Status=$status; Summary=$summary; Issues=@($issues); Unknown=@($unknown)
        Jobs=$jobLines; JobCount= $(if ($jobsKnown) { [string]$printerJobs.Count } else { 'Nie ustalono' })
        Shared=[bool]$p.Shared; Location=[string]$p.Location
    }
})
[pscustomobject]@{ Time=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Computer=$env:COMPUTERNAME; User=$env:USERNAME; Spooler=$spooler; Printers=$items; Warnings=@($warnings) }
