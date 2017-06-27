#---------------------------------# 
Write-Host 'Running AppVeyor build script: build.ps1' -ForegroundColor Yellow

$ProjectPath = Split-Path $PSScriptRoot

if ($env:APPVEYOR) {
    $ModuleName = $env:APPVEYOR_PROJECT_NAME
    $Version = $env:APPVEYOR_BUILD_VERSION
    $TestExit = $true
} else {
    $ModuleName = Split-Path $ProjectPath -Leaf
    $Version = '0.1.0'
    $TestExit = $false
}

$ModulePath = Join-Path $ProjectPath $ModuleName
#---------------------------------# 
Write-Host "build.ps1: ModulePath: $ModulePath" -ForegroundColor Yellow

#-------------------------------------# 
# Update manifest with version number #
#-------------------------------------#
$ManifestPath = Join-Path $ModulePath "$ModuleName.psd1"
#---------------------------------# 
Write-Host "build.ps1: ManifestPath: $ManifestPath" -ForegroundColor Yellow
Write-Host 'Updating new module manifest' -ForegroundColor Yellow
$ManifestData = Get-Content $ManifestPath
$ManifestData = $ManifestData -replace "ModuleVersion = `"\d+\.\d+\.\d+`"", "ModuleVersion = `"$Version`""
$ManifestData | Out-File $ManifestPath -Force -Encoding utf8

# Embeded help is/will be included in each exported function
#
# # build help file by PlatyPS
# $DocsPath = Join-Path $ProjectPath "docs"
# $DocsOutPutPath = Join-Path $ModulePath "en-US"
# $null = New-Item -ItemType Directory -Path $DocsOutPutPath -Force
# $null = New-ExternalHelp -Path $DocsPath -OutPutPath $DocsOutPutPath -Encoding ([System.Text.Encoding]::UTF8) -Force

# run tests
Invoke-Pester -EnableExit:$TestExit -PesterOption @{IncludeVSCodeMarker = $true}