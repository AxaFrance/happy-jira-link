param (
  [string]$jiraCardList = $(throw "-jiraCardList is required."),
  [string]$organizationName = $(throw "-organizationName is required."),
  [string]$projectName = $(throw "-projectName is required."),
  [string]$pullRequestId = $(throw "-pullRequestId is required."),    
  [string]$pat = $(throw "-pat is required.")
)

$parsedJiraCards = $jiraCardList | ConvertFrom-Json

$version = '6.0'
$instance = "https://dev.azure.com/$organizationName/$projectName"
$azureDevOpsAuthenticationHeader = @{Authorization = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$($pat)")) }
$getPullRequestUri = "$instance/_apis/git/pullrequests/$($pullRequestId)?api-version=$version"
$jsonType = 'application/json'

Write-Host 'Getting PR content...'
$getPullRequestResponse = Invoke-RestMethod -Uri $getPullRequestUri -ContentType $jsonType -Method Get -Headers $azureDevOpsAuthenticationHeader -Verbose
Write-Host "Done."

$repositoryId = $getPullRequestResponse.repository.id
$getPullRequestTagsUri = "$instance/_apis/git/repositories/$repositoryId/pullrequests/$pullRequestId/labels?api-version=$version" 
Write-Host 'Getting PR existing Tags...'
$getPullRequestTagsResponse = Invoke-RestMethod -Uri $getPullRequestTagsUri -ContentType $jsonType -Method Get -Headers $azureDevOpsAuthenticationHeader -Verbose
Write-Host "Done."

[string[]] $existingTags = $getPullRequestTagsResponse.value | % { $_.name }
$newTags = New-Object 'Collections.Generic.List[string]'

foreach ( $card in $parsedJiraCards ) {
  $parsedCard = $card | ConvertFrom-Json
  
  if ( -not [string]::IsNullOrEmpty($parsedCard.Id) -and $parsedCard.Id -notin $existingTags -and $parsedCard.Id -notin $newTags ) {
    $newTags.Add($parsedCard.Id)
  }
  
  if ( -not [string]::IsNullOrEmpty($parsedCard.CardVersion) -and $parsedCard.CardVersion -notin $existingTags -and $parsedCard.CardVersion -notin $newTags ) {
    $newTags.Add($parsedCard.CardVersion)
  }
  
  if ( -not [string]::IsNullOrEmpty($parsedCard.CardType) -and $parsedCard.CardType -notin $existingTags -and $parsedCard.CardType -notin $newTags ) {
    $newTags.Add($parsedCard.CardType)
  }
  
  if ( -not [string]::IsNullOrEmpty($parsedCard.CardMmf) -and $parsedCard.CardMmf -notin $existingTags -and $parsedCard.CardMmf -notin $newTags ) {
    $newTags.Add($parsedCard.CardMmf)
  }
}

$createPullRequestTagsUri = "$instance/_apis/git/repositories/$repositoryId/pullrequests/$pullRequestId/labels?api-version=$version" 
Write-Host "Tagging PR #$pullRequestId...`nFound $($newTags.Count) tag(s): '$newTags'"
foreach ( $newTag in $newTags ) {
  $body = @{"name" = $newTag } | ConvertTo-Json -Compress
  Write-Host "Creating '$newTag'...`nBody: '$body'"
  Invoke-RestMethod -Uri $createPullRequestTagsUri -ContentType $jsonType -Method Post -Headers $azureDevOpsAuthenticationHeader -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Verbose
  Write-Host "Done."
}
Write-Host "Done."

Write-Host "All done."
