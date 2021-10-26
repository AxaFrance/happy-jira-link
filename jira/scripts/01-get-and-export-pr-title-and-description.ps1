param (
    [string]$pullRequestId = $(throw "-pullRequestId is required."), 
    [string]$organizationName = $(throw "-organizationName is required."), 
    [string]$repositoryName = $(throw "-repositoryName is required."),    
    [string]$projectName = $(throw "-projectName is required."),
    [string]$pat = $(throw "-pat is required.")
)

$version = '6.0'
$instance = "https://dev.azure.com/$organizationName/$projectName" 
$azureDevOpsAuthenticationHeader = @{Authorization = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$($pat)")) }
$getPullRequestUri = "$instance/_apis/git/repositories/$repositoryName/pullrequests/$pullRequestId/?api-version=$version" 
$jsonType = 'application/json'

Write-Host 'Getting PR content...'
$getPullRequestResponse = Invoke-RestMethod -Uri $getPullRequestUri -ContentType $jsonType -Method Get -Headers $azureDevOpsAuthenticationHeader -Verbose
Write-Host "Done."

# Export to pipeline 
# Replace ' by " to avoid over-complicated escaping
Write-Host "##vso[task.setvariable variable=Title;isOutput=true]$($getPullRequestResponse.title -replace '"','\"' -replace "'",'\"')"
# Powershell does not like the CRs here, however it does not interpret \n (while the API does when receiving a JSON) so we can just use a regexp to change `n to \n
Write-Host "##vso[task.setvariable variable=Description;isOutput=true]$($getPullRequestResponse.description -replace '"','\"' -replace "'",'\"' -replace '\n','\n')"
    
Write-Host "All done."