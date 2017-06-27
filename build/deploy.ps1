#---------------------------------# 
Write-Host 'Running AppVeyor deploy script: deploy.ps1' -ForegroundColor Yellow

if ($env:APPVEYOR_REPO_COMMIT_MESSAGE -match "^!Deploy") {
    $ModulePath = Join-Path $env:APPVEYOR_BUILD_FOLDER $env:APPVEYOR_PROJECT_NAME
    Import-Module PowerShellGet -Force
    Publish-Module -Path $ModulePath -NuGetApiKey ($env:PSGallery_Api_Key) -Confirm:$false
    Write-Host "Published: $ModulePath to Respository PSGallery"  -ForegroundColor Yellow
} else {
    Write-Host "Commit Message: $env:APPVEYOR_REPO_COMMIT_MESSAGE" -ForegroundColor Yellow
    Write-Host "   Branch: $env:APPVEYOR_REPO_BRANCH"  -ForegroundColor Yellow
    Write-Host "   Skipping Publish-Module since commit messsage didn't start with '!Deploy'" -ForegroundColor Yellow
}