$ErrorActionPreference = 'Stop'
$rootLab = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$docPathLab = Join-Path $rootLab 'output\docx\Laborator_3_PSI_Mudrea_Mihail_Licurici.docx'
$pdfPathLab = Join-Path $rootLab 'tmp\lab3\word-preview.pdf'
$wordLab = New-Object -ComObject Word.Application
$wordLab.Visible = $false
$wordLab.DisplayAlerts = 0
try {
    $labDoc = $wordLab.Documents.Open($docPathLab)
    $labDoc.EmbedTrueTypeFonts = $true
    $labDoc.SaveSubsetFonts = $false
    $labDoc.DoNotEmbedSystemFonts = $false
    $labDoc.TablesOfContents.Item(1).Update()
    $labDoc.Content.Font.Name = 'Times New Roman'
    $labDoc.Repaginate()
    $labDoc.TablesOfContents.Item(1).UpdatePageNumbers()
    $labDoc.Content.Font.Name = 'Times New Roman'
    $labDoc.Save()
    $labDoc.ExportAsFixedFormat($pdfPathLab, 17)
    Write-Output ('Pages: ' + $labDoc.ComputeStatistics(2))
    $labDoc.Close(0)
} finally {
    $wordLab.Quit()
}
