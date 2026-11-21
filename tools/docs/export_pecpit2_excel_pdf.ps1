$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$source = Join-Path $root 'output/xlsx/PECPIT_lab2_Mudrea_Mihail_Licurici.xlsx'
$target = Join-Path $root 'output/pdf/PECPIT_lab2_Mudrea_Mihail_Licurici_Excel.pdf'
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
try {
    $book = $excel.Workbooks.Open($source, 0, $true)
    $excel.CalculateFullRebuild()
    foreach ($sheet in $book.Worksheets) {
        $setup = $sheet.PageSetup
        $setup.PrintArea = $sheet.UsedRange.Address()
        $setup.Orientation = 2 # landscape
        $setup.PaperSize = 8 # A3: retains readable type on wide tables
        $setup.Zoom = $false
        $setup.FitToPagesWide = 1
        $setup.FitToPagesTall = $false
        $setup.PrintTitleRows = '$1:$4'
        $setup.LeftMargin = $excel.CentimetersToPoints(1)
        $setup.RightMargin = $excel.CentimetersToPoints(1)
        $setup.TopMargin = $excel.CentimetersToPoints(1.2)
        $setup.BottomMargin = $excel.CentimetersToPoints(1.2)
        $setup.HeaderMargin = $excel.CentimetersToPoints(0.4)
        $setup.FooterMargin = $excel.CentimetersToPoints(0.4)
        $setup.CenterHorizontally = $true
        $setup.PrintGridlines = $false
        $setup.PrintHeadings = $false
        $setup.LeftFooter = '&"Arial"&8Licurici | Mudrea Mihail, TI-233'
        $setup.CenterFooter = '&"Arial"&8&A'
        $setup.RightFooter = '&"Arial"&8Pagina &P din &N'
    }
    $book.ExportAsFixedFormat(0, $target, 0, $true, $false)
    $book.Close($false)
    Write-Output $target
} finally {
    $excel.Quit()
}
