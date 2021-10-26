param (
    [string]$buildId = $(throw "-buildId is required."), 
    [string]$buildReason = $(throw "-buildReason is required."), 
    [string]$organizationName = $(throw "-organizationName is required."),
    [string]$projectName = $(throw "-projectName is required."),
    [string]$pat = $(throw "-pat is required.")
)

$version = '6.0'
$instance = "https://dev.azure.com/$organizationName/$projectName" 
$azureDevOpsAuthenticationHeader = @{Authorization = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$($pat)")) }

$isPullRequest = $buildReason -eq 'PullRequest'
if ($isPullRequest) {
    $tag = 'PullRequest'
} else {
    $tag = 'Release'
}

$addTagUrl = "$instance/_apis/build/builds/$buildId/tags/$($tag)?api-version=$version" 
$type = 'application/json'

Write-Host 'Adding the tag $($tag)...'      
$callResponse = Invoke-RestMethod -Uri $addTagUrl -ContentType $type -Method Put -Headers $azureDevOpsAuthenticationHeader -Verbose
Write-Host "Done.`nRESPONSE: $callResponse"
Write-Host 'All done.'