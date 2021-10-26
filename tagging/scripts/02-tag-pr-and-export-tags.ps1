param (
  [string]$organizationName = $(throw "-organizationName is required."),
  [string]$projectName = $(throw "-projectName is required."),
  [string]$pullRequestId = $(throw "-pullRequestId is required."),
  [string]$jiraBaseUrl = $(throw "-jiraBaseUrl is required."),
  [string]$pat = $(throw "-pat is required.")
)

$version = '6.0'
$instance = "https://dev.azure.com/$organizationName/$projectName" 
$azureDevOpsAuthenticationHeader = @{Authorization = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$($pat)")) }
$getPullRequestUri = "$instance/_apis/git/pullrequests/$($pullRequestId)?api-version=$version" 
$type = 'application/json'

Write-Host 'Getting PR content...'
$getPullRequestResponse = Invoke-RestMethod -Uri $getPullRequestUri -ContentType $type -Method Get -Headers $azureDevOpsAuthenticationHeader -Verbose
Write-Host "Done.`nRESPONSE: $getPullRequestResponse"

Write-Host 'Parsing PR description...'
# Escape special chars
$jiraBaseUriPattern = $jiraBaseUrl -replace '(\W)','\$1'
$matchesResult = [regex]::Matches($getPullRequestResponse.description, "$jiraBaseUriPattern\/browse\/(?<jiraId>[a-zA-Z]+\-\d+)");
[string[]] $jiraIdList = $matchesResult | % { $_.Groups['jiraId'] }
Write-Host "Done.`nFound $($jiraIdList.Length) JIRA ID(s): $jiraIdList" 

$repositoryId = $getPullRequestResponse.repository.id
$getPullRequestTagsUri = "$instance/_apis/git/repositories/$repositoryId/pullrequests/$pullRequestId/labels?api-version=$version" 
Write-Host 'Getting PR existing Tags...'
$getPullRequestTagsResponse = Invoke-RestMethod -Uri $getPullRequestTagsUri -ContentType $type -Method Get -Headers $azureDevOpsAuthenticationHeader -Verbose
Write-Host "Done.`nRESPONSE: $getPullRequestTagsResponse"

[string[]] $existingJiraIds = $getPullRequestTagsResponse.value | % { $_.name }
[string[]] $missingJiraIds = $jiraIdList | Where { $_ -notin $existingJiraIds }

$createPullRequestTagsUri = "$instance/_apis/git/repositories/$repositoryId/pullrequests/$pullRequestId/labels?api-version=$version" 
Write-Host "Tagging PR #$pullRequestId..."
Write-Host "To create: $missingJiraIds`nExcluded $($existingJiraIds.Length) entrie(s): $existingJiraIds"

foreach ($jiraId in $missingJiraIds) {
    Write-Host "Creating $jiraId..."
    $body = @{"name" = $jiraId } | ConvertTo-Json
    $createPullRequestTagsResponse = Invoke-RestMethod -Uri $createPullRequestTagsUri -ContentType $type -Method Post -Headers $azureDevOpsAuthenticationHeader -Body $body -Verbose
    Write-Host "Done.`nRESPONSE: $createPullRequestTagsResponse"
}

Write-Host "Export jira ids..."
Write-Host "##vso[task.setvariable variable=JiraIdList;isOutput=true]$(ConvertTo-Json -Compress $jiraIdList)"
Write-Host "##vso[task.setvariable variable=JiraIdListCount;isOutput=true]$($jiraIdList.Count)"
Write-Host "Done."

Write-Host "All done."
