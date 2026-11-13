#requires -version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:snapshot = $null
$script:job = $null
$script:started = $null
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Kontroler 0.1 — diagnostyka drukarek'
$form.Size = New-Object System.Drawing.Size(1100, 760)
$form.MinimumSize = New-Object System.Drawing.Size(800, 580)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'; $layout.RowCount = 4; $layout.ColumnCount = 1
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 50)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 42)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 58)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 45)))
$form.Controls.Add($layout)
$toolbar = New-Object System.Windows.Forms.FlowLayoutPanel
$toolbar.Dock = 'Fill'
$refresh = New-Object System.Windows.Forms.Button
$refresh.Text = 'Odśwież'; $refresh.Width = 125; $refresh.Height = 36
$export = New-Object System.Windows.Forms.Button
$export.Text = 'Zapisz raport'; $export.Width = 145; $export.Height = 36; $export.Enabled = $false
$print = New-Object System.Windows.Forms.Button
$print.Text = 'Strona testowa'; $print.Width = 155; $print.Height = 36; $print.Enabled = $false
$toolbar.Controls.AddRange(@($refresh, $export, $print))
$layout.Controls.Add($toolbar, 0, 0)
$list = New-Object System.Windows.Forms.ListView
$list.Dock = 'Fill'; $list.View = 'Details'; $list.FullRowSelect = $true; $list.MultiSelect = $false; $list.HideSelection = $false
foreach ($col in @(@('Drukarka',280), @('Domyślna',85), @('Połączenie',175), @('Status Windows',140), @('Ocena',230))) { [void]$list.Columns.Add($col[0], $col[1]) }
$layout.Controls.Add($list, 0, 1)
$details = New-Object System.Windows.Forms.TextBox
$details.Dock = 'Fill'; $details.Multiline = $true; $details.ReadOnly = $true; $details.ScrollBars = 'Both'; $details.WordWrap = $false
$details.BackColor = [System.Drawing.Color]::White
$layout.Controls.Add($details, 0, 2)
$footer = New-Object System.Windows.Forms.Label
$footer.Dock = 'Fill'; $footer.Text = 'Gotowy'; $footer.AutoEllipsis = $true
$layout.Controls.Add($footer, 0, 3)
function Describe-Printer($p) {
    $lines = @("DRUKARKA: $($p.Name)", "Ocena: $($p.Summary)", "Domyślna: $(if ($p.Default) {'Tak'} else {'Nie'})", "Połączenie: $($p.Connection)", "Port: $($p.Port)", "Sterownik: $($p.Driver)", "Wersja pliku sterownika: $($p.Version)", "Status Windows: $($p.Status)", "Udostępniona: $(if ($p.Shared) {'Tak'} else {'Nie'})", "Lokalizacja: $($p.Location)", "Zadań w kolejce: $($p.JobCount)", '', 'WYKRYTE PROBLEMY:')
    if (@($p.Issues).Count) { $lines += @($p.Issues) } else { $lines += 'Brak zgłoszonych problemów.' }
    $lines += @('', 'OGRANICZENIA ODCZYTU:')
    $lines += @($p.Unknown)
    $lines += @('Status systemu nie potwierdza fizycznego podłączenia USB ani poprawnego wydruku.', '', 'KOLEJKA WYDRUKU:')
    $lines += @($p.Jobs)
    return ($lines -join "`r`n")
}
function Show-Error([string]$message) { [void][System.Windows.Forms.MessageBox]::Show($form, $message, 'Kontroler', 'OK', 'Error') }
function Start-Refresh {
    if ($script:job) { return }
    $refresh.Enabled = $false; $export.Enabled = $false; $print.Enabled = $false
    $list.Items.Clear(); $details.Clear(); $script:snapshot = $null
    $footer.Text = 'Odczytywanie danych...'
    try {
        $script:started = Get-Date
        $script:job = Start-Job -FilePath (Join-Path $PSScriptRoot 'Diagnostyka.ps1')
    } catch { $refresh.Enabled = $true; $footer.Text = 'Odczyt nie powiódł się.'; Show-Error $_.Exception.Message }
}
$list.Add_SelectedIndexChanged({
    $print.Enabled = $list.SelectedItems.Count -eq 1 -and -not $script:job
    if ($list.SelectedItems.Count -eq 1) { $details.Text = Describe-Printer $list.SelectedItems[0].Tag }
})
$refresh.Add_Click({ Start-Refresh })
$export.Add_Click({
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = 'Raport tekstowy (*.txt)|*.txt'; $dialog.FileName = "kontroler-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    if ($dialog.ShowDialog($form) -eq 'OK') {
        try {
            $s = $script:snapshot
            $report = @('KONTROLER 0.1', "Odczyt: $($s.Time)", "Komputer: $($s.Computer)", "Użytkownik: $($s.User)", "Bufor wydruku: $($s.Spooler)", "Liczba drukarek: $(@($s.Printers).Count)", '', 'UWAGI ODCZYTU:') + @($s.Warnings)
            foreach ($p in @($s.Printers)) { $report += @('', ('=' * 65), (Describe-Printer $p)) }
            [System.IO.File]::WriteAllText($dialog.FileName, ($report -join "`r`n"), [System.Text.UTF8Encoding]::new($true))
            $footer.Text = "Zapisano raport: $($dialog.FileName)"
        } catch { Show-Error $_.Exception.Message }
    }
    $dialog.Dispose()
})
$print.Add_Click({
    if ($list.SelectedItems.Count -ne 1) { return }
    $name = $list.SelectedItems[0].Tag.Name
    if ([System.Windows.Forms.MessageBox]::Show($form, "Wysłać stronę testową Windows do drukarki:`r`n$name ?", 'Strona testowa', 'YesNo', 'Question') -ne 'Yes') { return }
    try {
        $printer = Get-CimInstance Win32_Printer -OperationTimeoutSec 15 | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $printer) { throw 'Drukarka nie jest już dostępna. Odśwież listę.' }
        $result = Invoke-CimMethod -InputObject $printer -MethodName PrintTestPage -OperationTimeoutSec 20
        if ($result.ReturnValue -ne 0) { throw "Windows odrzucił żądanie. Kod: $($result.ReturnValue)." }
        $footer.Text = 'Wysłano stronę testową. Sprawdź fizyczny wydruk, a następnie odśwież dane.'
    } catch { Show-Error $_.Exception.Message }
})
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250
$timer.Add_Tick({
    if (-not $script:job) { return }
    if (((Get-Date) - $script:started).TotalSeconds -gt 90) {
        Stop-Job $script:job; Remove-Job $script:job -Force; $script:job = $null
        $refresh.Enabled = $true; $footer.Text = 'Przekroczono limit 90 sekund. Spróbuj odświeżyć dane.'
        return
    }
    if ($script:job.State -notin @('Completed', 'Failed', 'Stopped')) { return }
    try {
        if ($script:job.State -ne 'Completed') { throw "Odczyt zakończony błędem: $($script:job.ChildJobs[0].JobStateInfo.Reason)" }
        $script:snapshot = Receive-Job $script:job -ErrorAction Stop
        if (-not $script:snapshot) { throw 'Brak wyniku diagnostyki.' }
        $s = $script:snapshot
        foreach ($p in @($s.Printers)) {
            $row = New-Object System.Windows.Forms.ListViewItem([string]$p.Name)
            [void]$row.SubItems.Add($(if ($p.Default) { 'Tak' } else { '' }))
            [void]$row.SubItems.Add([string]$p.Connection); [void]$row.SubItems.Add([string]$p.Status); [void]$row.SubItems.Add([string]$p.Summary)
            $row.Tag = $p
            if (@($p.Issues).Count) { $row.ForeColor = [System.Drawing.Color]::Firebrick }
            [void]$list.Items.Add($row)
        }
        $footer.Text = "Odczyt: $($s.Time) | Drukarki: $(@($s.Printers).Count) | Bufor: $($s.Spooler)"
        $details.Text = (@($s.Warnings) -join "`r`n")
        if (@($s.Warnings).Count) { $footer.Text += ' | Niepełny odczyt — szczegóły w raporcie.' }
        if ($list.Items.Count -eq 0) { $details.Text = "Brak drukarek do wyświetlenia.`r`n$($details.Text)" }
        $export.Enabled = $true
    } catch { $footer.Text = 'Odczyt nie powiódł się.'; Show-Error $_.Exception.Message }
    finally { Remove-Job $script:job -Force; $script:job = $null; $refresh.Enabled = $true }
    if ($list.Items.Count -gt 0) { $list.Items[0].Selected = $true }
})
$form.Add_Shown({ $timer.Start(); Start-Refresh })
$form.Add_FormClosed({
    $timer.Stop(); $timer.Dispose()
    if ($script:job) { Stop-Job $script:job; Remove-Job $script:job -Force }
})
[void]$form.ShowDialog()
$form.Dispose()
