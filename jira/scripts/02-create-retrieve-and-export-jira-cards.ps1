param (
    [string]$jiraBaseUrl = $(throw "-jiraBaseUrl is required."),
    [string]$jiraAppCodeKey = $(throw "- is required."),
    [string]$jiraTribeKey = $(throw "-jiraTribeKey is required."),
    [string]$jiraDomainKey = $(throw "-jiraDomainKey is required."),
    [string]$jiraSquadKey = $(throw "-jiraSquadKey is required."),
    [string]$jiraProjectId = $(throw "-jiraProjectId is required."),
    [string]$jiraAppCode = $(throw "-jiraAppCode is required."),
    [string]$jiraTribeId = $(throw "-jiraTribeId is required."),
    [string]$jiraDomainId = $(throw "-jiraDomainId is required."),
    [string]$jiraSquadId = $(throw "-jiraSquadId is required."),
    [string]$jiraStatusIdCodeReviewInProgress = $(throw "-jiraStatusIdCodeReviewInProgress is required."),
    [string]$jiraStatusIdCodeReviewDone = $(throw "-jiraStatusIdCodeReviewDone is required."),
    [string]$jiraIdListCount = $(throw "-jiraIdListCount is required."), 
    [string]$jiraIdList = $(throw "-jiraIdList is required."),    
    [string]$sourceRepositoryUri = $(throw "-sourceRepositoryUri is required."),
    [string]$pullRequestId = $(throw "-pullRequestId is required."),
    [string]$currentPullRequestContentTitle = $(throw "-buildRequestedFor is required."),
    [string]$buildRequestedFor = $(throw "-currentPullRequestContentTitle is required."),
    [string]$jiraPat = $(throw "-jiraPat is required.")
)

$jiraCardIds = New-Object 'Collections.Generic.List[string]'
if ( '0' -ne $jiraIdListCount -and -not [string]::IsNullOrEmpty($jiraIdList) ) {
    $jiraCardIds = $jiraIdList | ConvertFrom-Json
}

$jiraCardApiUri = "$jiraBaseUrl/rest/api/latest/issue/"

$jiraAuthenticationHeader = @{Authorization = 'Bearer ' + $jiraPat }
$jsonType = 'application/json'

$codeReviewInProgress = @{ Name = 'Code review - In Progress'; Id = $jiraStatusIdCodeReviewInProgress }
$codeReviewDone = @{ Name = 'Code review - Done'; Id = $jiraStatusIdCodeReviewDone }

$jiraCards = New-Object 'Collections.Generic.List[string]'
if ( 0 -eq $jiraCardIds.Count ) {
    $repository = $sourceRepositoryUri -replace '(https?://).*@', '$1'
    $pullRequestUri = "$repository/pullrequest/$pullRequestId";
    $labelToUse = $currentPullRequestContentTitle -replace '.*(?:build|ci|docs|feat|fix|perf|refactor|style|test)(?:\(?([^\(\)]*)?\)?): ', '$1 - '

    $title = "[Generated] $($labelToUse.TrimStart(' - '))"
    $description = "Have a look at $pullRequestUri (or reach $buildRequestedFor)"

    $project = "`"project`": { `"id`": `"$jiraProjectId`" }"
    
    # This is organization-specific
    $appCode = "`"$jiraAppCodeKey`": $jiraAppCode"
    $tribe = "`"$jiraTribeKey`": `"$jiraTribeId`""
    $domain = "`"$jiraDomainKey`": [ `"$jiraDomainId`" ]"
    $squad = "`"$jiraSquadKey`": `"$jiraSquadId`""

    # To avoid creating an over-complexified model and serializing it, I used an already built JSON based on a previous request
    $body = "{ `"fields`": { `"priority`": { `"id`": `"4`" }, `"issuetype`": { `"id`": `"14601`" }, $project, `"description`": `"$description`", `"summary`": `"$title`", $appCode, $tribe, $domain, $squad } }"

    Write-Host "Creating new Technical Story..."
    $createTechnicalStoryResponse = Invoke-RestMethod -Uri $jiraCardApiUri -ContentType $jsonType -Method POST -Headers $jiraAuthenticationHeader -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Verbose
    Write-Host "Done.`nCreated the TS #$($createTechnicalStoryResponse.key)"

    $jiraCardIds.Add($createTechnicalStoryResponse.key)
    
    # Export the created key to the pipeline
    Write-Host "##vso[task.setvariable variable=CreatedCardKey;isOutput=true]$($createTechnicalStoryResponse.key)"
}

foreach ($jiraCardId in $jiraCardIds) {
    $getJiraCardApiUri = "$jiraCardApiUri$jiraCardId"

    Write-Host "Getting JIRA content for $jiraCardId..."
    $getJiraCardResponse = Invoke-RestMethod -Uri $getJiraCardApiUri -ContentType $jsonType -Method Get -Headers $jiraAuthenticationHeader -Verbose
    Write-Host "Done."

    $userFullName = $getJiraCardResponse.fields.assignee.displayName
    if ( [string]::IsNullOrEmpty($userFullName) ) {
        $userFullName = $getJiraCardResponse.fields.reporter.displayName
    }

    $status = $getJiraCardResponse.fields.status
    $mustUpdateCard = $false
    if ( $codeReviewInProgress.Id -ne $status.id -and $codeReviewDone.Id -ne $status.id ) {
        Write-Host "$userFullName should update the card.`nFound status '$($status.name)' while '$($codeReviewInProgress.Name)' or '$($codeReviewDone.Name)' were expected!"
        $mustUpdateCard = $true

        # 2022-10-18 > Cards cannot be moved automatically yet, please have a look at https://jira.atlassian.com/browse/JRACLOUD-70305
    } else {
        Write-Host "$userFullName has updated the card.`nFound status '$($status.name)'."
    }
    Write-Host "A comment will be posted."

    $cardVersion = ""
    if ( $getJiraCardResponse.fields.fixVersions.name ) {
        $cardVersion = $getJiraCardResponse.fields.fixVersions.name
    }
    $cardType = ""
    if ( $getJiraCardResponse.fields.issuetype.name ) {
        $cardType = $getJiraCardResponse.fields.issuetype.name
    }
    $cardMmf = ""
    if ( $getJiraCardResponse.fields.epic.name ) {
        $cardMmf = $getJiraCardResponse.fields.epic.name
    }

    $jiraCards.Add((@{ Id = $jiraCardId; CardVersion = $cardVersion; CardType = $cardType; CardMmf = $cardMmf; UserFullName = $userFullName; MustUpdateCard = $mustUpdateCard; } | ConvertTo-Json -Compress))
}

# Export the serialized result for future use
Write-Host "##vso[task.setvariable variable=JiraCards;isOutput=true]$(ConvertTo-Json -Compress $jiraCards)"
Write-Host "##vso[task.setvariable variable=JiraCardsCount;isOutput=true]$($jiraCards.Count)"
Write-Host "All done."
