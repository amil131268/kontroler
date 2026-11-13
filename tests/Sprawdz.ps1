#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
foreach ($file in @('Kontroler.ps1', 'Diagnostyka.ps1', 'tests/Sprawdz.ps1')) {
    $tokens = $null; $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file), [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
}
function Assert($condition, $message) { if (-not $condition) { throw $message } }
# Mock only the Windows data sources; execute the actual diagnostics collector.
function Get-Service { param($Name, $ErrorAction) [pscustomobject]@{Status='Running'} }
$script:scenario = 'normal'
function Get-CimInstance {
    param($ClassName, $OperationTimeoutSec)
    if ($script:scenario -eq 'failure') { throw 'Odmowa dostępu (test)' }
    switch ($ClassName) {
        'Win32_Printer' {
            if ($script:scenario -eq 'empty') { return }
            [pscustomobject]@{Name="Serwis, USB 'A'"; Default=$true; PortName='USB001'; DriverName='Driver [A]'; PrinterStatus=3; DetectedErrorState=2; PrinterState=0; ExtendedPrinterStatus=3; WorkOffline=($script:scenario -eq 'offline'); Network=$false; Shared=$false; Location='Serwis'}
        }
        'Win32_PrintJob' {
            if ($script:scenario -eq 'offline') {
                [pscustomobject]@{Name="Serwis, USB 'A', 42"; JobId=42; JobStatus=''; StatusMask=32; Document='Test'; TotalPages=1}
            }
        }
        'Win32_PrinterDriver' { return }
    }
}
$result = & (Join-Path $root 'Diagnostyka.ps1')
Assert (@($result.Printers).Count -eq 1) 'Nie odczytano drukarki.'
Assert ($result.Printers[0].Default) 'Błędna drukarka domyślna.'
Assert ($result.Printers[0].Connection -like 'USB*') 'Błędne rozpoznanie USB.'
Assert (@($result.Printers[0].Issues).Count -eq 0) 'Fałszywy alarm.'
Assert ($result.Printers[0].Version -eq 'Nie ustalono') 'Brak wersji powinien być jawny.'
$script:scenario = 'offline'
$result = & (Join-Path $root 'Diagnostyka.ps1')
Assert ($result.Printers[0].JobCount -eq '1') 'Nie dopasowano kolejki z przecinkiem w nazwie.'
Assert (@($result.Printers[0].Issues).Count -eq 2) 'Brak diagnostyki offline lub zadania.'
$script:scenario = 'empty'
$result = & (Join-Path $root 'Diagnostyka.ps1')
Assert (@($result.Printers).Count -eq 0) 'Błędna obsługa pustej listy.'
$script:scenario = 'failure'
$result = & (Join-Path $root 'Diagnostyka.ps1')
Assert (@($result.Warnings).Count -eq 3) 'Nie ujawniono błędów odczytu.'
Write-Host 'OK: składnia i scenariusze diagnostyki.' -ForegroundColor Green
