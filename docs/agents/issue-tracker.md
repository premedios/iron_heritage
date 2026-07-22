# Issue tracker: YouTrack

Issues and PRDs for this repository live in YouTrack project `IH`.
GitHub remains the code host and pull-request target, but GitHub Issues are not
used for project work.

## Configuration

- Base URL: `http://192.168.1.67:8880`
- Project short name: `IH`
- Transport: YouTrack REST API; no YouTrack CLI is required.
- Authentication: permanent token from the `YOUTRACK_TOKEN` environment
  variable.

Never store, print, log, or commit the permanent token. Stop and ask the user to
set `YOUTRACK_TOKEN` when it is missing.

Initialize each PowerShell session before using the examples below:

~~~powershell
$ytBaseUrl = 'http://192.168.1.67:8880'
$ytProjectShortName = 'IH'

if ([string]::IsNullOrWhiteSpace($env:YOUTRACK_TOKEN)) {
  throw 'Set YOUTRACK_TOKEN before accessing YouTrack.'
}

$ytHeaders = @{
  Authorization = "Bearer $env:YOUTRACK_TOKEN"
  Accept = 'application/json'
  'Content-Type' = 'application/json'
}

$projectQuery = [Uri]::EscapeDataString($ytProjectShortName)
$projects = @(
  Invoke-RestMethod `
    -Uri "$ytBaseUrl/api/admin/projects?fields=id,name,shortName&query=$projectQuery" `
    -Headers $ytHeaders
)
$ytProject = $projects |
  Where-Object { $_.shortName -eq $ytProjectShortName } |
  Select-Object -First 1

if ($null -eq $ytProject) {
  throw "YouTrack project $ytProjectShortName was not found."
}
~~~

## Issue implementation workflow

This policy applies to future issues; existing in-progress work does not need to
move branches.

- Implement each issue on its own dedicated branch created from the latest
  `main`.
- Keep one issue per branch. Do not reuse that branch for another issue.
- Commit the completed issue to its branch and open a pull request targeting
  `main` before starting the next issue.

## Core operations

### Create an issue

~~~powershell
$payload = @{
  project = @{ id = $ytProject.id }
  summary = '<summary>'
  description = '<markdown description>'
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
  -Method Post `
  -Uri "$ytBaseUrl/api/issues?fields=id,idReadable,summary" `
  -Headers $ytHeaders `
  -Body $payload
~~~

### Read an issue and its comments

~~~powershell
$issueId = 'IH-1'
$issueFields = 'id,idReadable,summary,description,resolved,tags(id,name),customFields(name,value(name,login))'
$issue = Invoke-RestMethod `
  -Uri "$ytBaseUrl/api/issues/$issueId?fields=$issueFields" `
  -Headers $ytHeaders

$comments = Invoke-RestMethod `
  -Uri "$ytBaseUrl/api/issues/$issueId/comments?fields=id,text,created,author(login,name)&%24top=100" `
  -Headers $ytHeaders
~~~

### List or search issues

Use YouTrack search syntax and URL-encode the query:

~~~powershell
$query = [Uri]::EscapeDataString('project: IH #Unresolved')
$fields = 'id,idReadable,summary,description,resolved,tags(id,name),customFields(name,value(name,login))'

Invoke-RestMethod `
  -Uri "$ytBaseUrl/api/issues?fields=$fields&query=$query&%24top=100" `
  -Headers $ytHeaders
~~~

### Comment on an issue

~~~powershell
$payload = @{ text = '<comment>' } | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$ytBaseUrl/api/issues/$issueId/comments?fields=id,text" `
  -Headers $ytHeaders `
  -Body $payload
~~~

### Apply or remove a triage tag

The tags in `docs/agents/triage-labels.md` must already exist in YouTrack and
be shared with the project team.

~~~powershell
$tagName = 'ready-for-agent'
$tagQuery = [Uri]::EscapeDataString($tagName)
$tags = @(
  Invoke-RestMethod `
    -Uri "$ytBaseUrl/api/tags?fields=id,name&query=$tagQuery" `
    -Headers $ytHeaders
)
$tag = $tags | Where-Object { $_.name -eq $tagName } | Select-Object -First 1

if ($null -eq $tag) {
  throw "YouTrack tag $tagName was not found or is not shared."
}

$payload = @{ id = $tag.id } | ConvertTo-Json
Invoke-RestMethod `
  -Method Post `
  -Uri "$ytBaseUrl/api/issues/$issueId/tags?fields=id,name" `
  -Headers $ytHeaders `
  -Body $payload

# Remove the tag when required:
Invoke-RestMethod `
  -Method Delete `
  -Uri "$ytBaseUrl/api/issues/$issueId/tags/$($tag.id)" `
  -Headers $ytHeaders
~~~

### Apply commands, claim, link, or resolve

YouTrack commands handle state changes, assignment, and issue links:

~~~powershell
$payload = @{
  query = 'for me'
  issues = @(@{ idReadable = $issueId })
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
  -Method Post `
  -Uri "$ytBaseUrl/api/commands" `
  -Headers $ytHeaders `
  -Body $payload
~~~

Change `query` as needed:

- Claim: `for me`
- Blocked by another issue: `depends on IH-2`
- Child of a map issue: `subtask of IH-1`
- Resolve: `Fixed`

If project `IH` uses a different resolved-state value, replace `Fixed` with that
project command. Verify links through
`GET /api/issues/{issueID}/links?fields=linkType(name,sourceToTarget,targetToSource),issues(id,idReadable,summary,resolved)`.

## Skill semantics

- When a skill says **publish to the issue tracker**, create an issue in
  YouTrack project `IH`.
- When a skill says **fetch the relevant ticket**, read the issue, comments,
  tags, custom fields, and links from YouTrack.
- When a skill references a bare issue ID, use the human-readable YouTrack ID
  such as `IH-15`.
- Do not create, edit, label, comment on, or close GitHub Issues for project
  work.

## Wayfinding operations

- **Map**: one YouTrack issue tagged `wayfinder:map` containing Notes,
  Decisions-so-far, and Fog.
- **Child ticket**: a YouTrack issue tagged `wayfinder:<type>`
  (`research`, `prototype`, `grilling`, or `task`) and linked to the map with
  `subtask of <map-id>`.
- **Blocking**: link the child with `depends on <blocker-id>`. A ticket is
  unblocked only when all linked blockers are resolved.
- **Frontier query**: search open map children, exclude assigned issues and
  issues with unresolved `depends on` links, then take the first in map order.
- **Claim**: apply `for me`. This is the session's first tracker write.
- **Resolve**: comment with the answer, apply the project's resolved-state
  command, then add a context pointer to the map's Decisions-so-far.

## API references

- https://www.jetbrains.com/help/youtrack/devportal/youtrack-rest-api.html
- https://www.jetbrains.com/help/youtrack/devportal/api-howto-create-issue.html
- https://www.jetbrains.com/help/youtrack/devportal/api-usecase-add-remove-tags.html
- https://www.jetbrains.com/help/youtrack/devportal/resource-api-commands.html
- https://www.jetbrains.com/help/youtrack/devportal/api-howto-link-issues.html
