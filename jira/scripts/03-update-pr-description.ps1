param (
    [string]$currentPullRequestDescription = $(throw "-currentPullRequestDescription is required."),
    [string]$jiraBaseUrl = $(throw "-jiraBaseUrl is required."),
    [string]$jiraCreatedCardKey = $(throw "-jiraCreatedCardKey is required."), 
    [string]$organizationName = $(throw "-organizationName is required."),
    [string]$projectName = $(throw "-projectName is required."),
    [string]$repositoryName = $(throw "-repositoryName is required."),
    [string]$pullRequestId = $(throw "-pullRequestId is required."),    
    [string]$pat = $(throw "-pat is required.")
)

$version = '6.0'
$instance = "https://dev.azure.com/$organizationName/$projectName" 
$azureDevOpsAuthenticationHeader = @{Authorization = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$($pat)")) }
$getPullRequestUri = "$instance/_apis/git/repositories/$repositoryName/pullrequests/$pullRequestId/?api-version=$version" 
$jsonType = 'application/json'

$newDescription = "$currentPullRequestDescription\n\n------\n\n_Technical Story: [$jiraCreatedCardKey]($jiraBaseUrl/browse/$jiraCreatedCardKey)_"
$body = "{`"description`":`"$newDescription`"}"

Write-Host "Updating the PR description (appending new JIRA card) '$newDescription'..."
Invoke-RestMethod -Uri $getPullRequestUri -ContentType $jsonType -Method PATCH -Headers $azureDevOpsAuthenticationHeader -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Verbose
Write-Host "Done."

Write-Host "All done."
