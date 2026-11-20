$ErrorActionPreference = 'Stop'
$pecpitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pecpitDoc = Join-Path $pecpitRoot 'output\docx\PECPIT_lab1_Mudrea_Mihail_Licurici.docx'
$pecpitPdf = Join-Path $pecpitRoot 'output\pdf\PECPIT_lab1_Mudrea_Mihail_Licurici.pdf'
New-Item -ItemType Directory -Force (Split-Path $pecpitPdf) | Out-Null
Write-Output 'Starting Word'
$pecpitWord = New-Object -ComObject Word.Application
Write-Output 'Word started'
$pecpitWord.Visible = $false
$pecpitWord.DisplayAlerts = 0
try {
    Write-Output 'Opening document'
    $pecpitDocument = $pecpitWord.Documents.Open($pecpitDoc, $false, $false, $false)
    Write-Output 'Updating contents'
    $pecpitDocument.TablesOfContents.Item(1).Update()
    $pecpitDocument.Content.Font.Name = 'Times New Roman'
    Write-Output 'Repaginating'
    $pecpitDocument.Repaginate()
    $pecpitDocument.TablesOfContents.Item(1).UpdatePageNumbers()
    Write-Output 'Saving'
    $pecpitDocument.Save()
    $pecpitDocument.Close(0)
    $pecpitDocument = $pecpitWord.Documents.Open($pecpitDoc, $false, $true, $false)
    Write-Output 'Exporting PDF'
    $pecpitDocument.SaveAs2($pecpitPdf, 17)
    Write-Output ('Pages: ' + $pecpitDocument.ComputeStatistics(2))
    $pecpitDocument.Close(0)
} finally {
    $pecpitWord.Quit()
}
