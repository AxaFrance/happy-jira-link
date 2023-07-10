param (
  [string]$jiraIdListCount = $(throw "-jiraIdListCount is required."),
  [string]$jiraCreatedCardKey = $(throw "-jiraCreatedCardKey is required."),
  [string]$jiraCardList = $(throw "-jiraCardList is required."),
  [string]$organizationName = $(throw "-organizationName is required."),
  [string]$projectName = $(throw "-projectName is required."),
  [string]$repositoryName = $(throw "-repositoryName is required."),
  [string]$pullRequestId = $(throw "-pullRequestId is required."),    
  [string]$pat = $(throw "-pat is required.")
)

$parsedJiraCards = New-Object 'Collections.Generic.List[string]'
if ( ( '0' -ne $jiraIdListCount -or -not [string]::IsNullOrEmpty($jiraCreatedCardKey) ) -and -not [string]::IsNullOrEmpty($jiraCardList) ) {
  $parsedJiraCards = $jiraCardList | ConvertFrom-Json
}

$activeThreadStatus = 'active'
$resolvedThreadStatus = 'fixed'

$version = '6.0'
$instance = "https://dev.azure.com/$organizationName/$projectName"
$azureDevOpsAuthenticationHeader = @{Authorization = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$($pat)")) }
$getPullRequestThreadsUri = "$instance/_apis/git/repositories/$repositoryName/pullrequests/$pullRequestId/threads/?api-version=$version" 
$jsonType = 'application/json'

Write-Host 'Getting PR Threads content...'
$getPullRequestThreadsResponse = Invoke-RestMethod -Uri $getPullRequestThreadsUri -ContentType $jsonType -Method Get -Headers $azureDevOpsAuthenticationHeader -Verbose
Write-Host "Done."

$getUserDataUri = "https://dev.azure.com/$organizationName/_apis/connectionData"

Write-Host 'Getting the PAT user data...'
$getUserResponse = Invoke-RestMethod -Uri $getUserDataUri -ContentType $jsonType -Method Get -Headers $azureDevOpsAuthenticationHeader -Verbose
Write-Host "Done."

$automationUserName = $getUserResponse.authorizedUser.providerDisplayName
$automationUserId = $getUserResponse.authorizedUser.id

Write-Host "Found data for the user '$automationUserName'!"

Write-Host 'Clean self comments...'
foreach ( $thread in $getPullRequestThreadsResponse.value ) {
  if ( ( $activeThreadStatus -eq $thread.status -or $resolvedThreadStatus -eq $thread.status ) -and $automationUserId -eq $thread.comments[0].author.id ) {
    foreach ( $comment in $thread.comments ) {
      $commentUri = $comment._links.self.href + "?api-version=$version"
      
      try {
        Invoke-RestMethod -Uri $commentUri -ContentType $jsonType -Method DELETE -Headers $azureDevOpsAuthenticationHeader -Verbose
      } catch {
        Write-Host "Unable to remove comment '$commentUri' (check the logs for more information)."
      }
    }
  }
}
Write-Host "Done."

if ( 0 -eq $parsedJiraCards.Count ) {
  $message = "The PR description does not contain any JIRA Card!"
  $body = "{ `"comments`": [ { `"parentCommentId`": 0, `"content`": `"$message`", `"commentType`": 1 } ], `"status`": 1 }"
    
  Write-Host "Posting comment '$message'..."
  Invoke-RestMethod -Uri $getPullRequestThreadsUri -ContentType $jsonType -Method POST -Headers $azureDevOpsAuthenticationHeader -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Verbose
  Write-Host "Done."
} else {
  foreach ($card in $parsedJiraCards) {
    $parsedCard = $card | ConvertFrom-Json
    
    if ( $true -eq $parsedCard.MustUpdateCard ) {
      $message = "The status for the $($parsedCard.CardType) $($parsedCard.Id) assigned to / created by $($parsedCard.UserFullName) must be updated."
      $body = "{ `"comments`": [ { `"parentCommentId`": 0, `"content`": `"$message`", `"commentType`": 1 } ], `"status`": 1 }"
      
      Write-Host "Posting comment '$message'..."
      Invoke-RestMethod -Uri $getPullRequestThreadsUri -ContentType $jsonType -Method POST -Headers $azureDevOpsAuthenticationHeader -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Verbose
      Write-Host "Done."
    } else {
      $message = "The status for the $($parsedCard.CardType) $($parsedCard.Id) assigned to $($parsedCard.UserFullName) is up to date, thank you!\nDon't forget to move your card to the next status once the PR is closed :)"
      $body = "{ `"comments`": [ { `"parentCommentId`": 0, `"content`": `"$message`", `"commentType`": 1 } ], `"status`": 2 }"
      
      Write-Host "Posting comment '$message'..."
      Invoke-RestMethod -Uri $getPullRequestThreadsUri -ContentType $jsonType -Method POST -Headers $azureDevOpsAuthenticationHeader -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Verbose
      Write-Host "Done."
    }
  }
}

Write-Host "All done."
