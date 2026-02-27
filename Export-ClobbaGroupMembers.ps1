<#
.SYNOPSIS
Exports Microsoft Entra ID (Azure AD) group membership for Clobba-named groups to CSV and HTML.

.DESCRIPTION
Connects to Microsoft Graph and retrieves all groups whose DisplayName starts with "Clobba".
From those, it filters groups whose names end with "Agents", "Supervisors", or "Users", then
enumerates user members for each matching group and outputs a consolidated membership report.

The script:
- Connects to Microsoft Graph with read-only scopes for Groups and Users.
- Retrieves matching groups (DisplayName starts with 'Clobba').
- Filters groups to those ending with: Agents / Supervisors / Users.
- Enumerates user members for each group (non-user members are excluded by design).
- Outputs results to the console (sorted).
- Exports results to timestamped CSV and HTML files in the current directory.

PREREQUISITES
1) Microsoft Graph PowerShell SDK installed:
   Install-Module Microsoft.Graph -Scope CurrentUser

2) Appropriate permissions / consent:
   - Delegated scopes used by this script: Group.Read.All, User.Read.All
   - You may need admin consent depending on your tenant policies.

3) Network access to Microsoft Graph endpoints.

SAMPLE USAGE
- Run interactively (prompts for sign-in):
  PS> .\Export-ClobbaGroupMembers.ps1

- If you want to run non-interactively (example only; not implemented here):
  Use Connect-MgGraph with a managed identity / certificate and the relevant app permissions.

.NOTES
- This is a read-only reporting script; it does not modify tenant configuration.
- Group membership can include objects that are not users (devices, service principals, groups).
  This script intentionally uses Get-MgGroupMemberAsUser, so only *user* objects are returned.
- The group query uses -All and a server-side filter for startswith(displayName,'Clobba') to
  reduce payload. Additional suffix filtering is done client-side via regex.
#>

# Connect to Microsoft Graph (Delegated permissions).
# You will be prompted to sign in and consent if required by tenant policy.
Connect-MgGraph -Scopes "Group.Read.All","User.Read.All"

# Retrieve all groups with a DisplayName starting with "Clobba".
# Note: -Filter is evaluated server-side; -All pages through the full result set.
$groups = Get-MgGroup -All -Filter "startswith(displayName,'Clobba')" -Property Id,DisplayName

# Filter to only the group suffixes we want to report on.
# Regex matches names ending with Agents, Supervisors, or Users.
$filteredGroups = $groups | Where-Object { $_.DisplayName -match 'Agents$|Supervisors$|Users$' }

# Enumerate user members for each matching group and emit a flat list of objects.
# Using Get-MgGroupMemberAsUser intentionally excludes non-user objects.
$results = foreach ($group in $filteredGroups) {

    # Query user members and request only the properties we need for the report.
    $users = Get-MgGroupMemberAsUser -GroupId $group.Id -All -Property Id,DisplayName,UserPrincipalName

    foreach ($u in $users) {
        [PSCustomObject]@{
            GroupDisplayName  = $group.DisplayName
            MemberDisplayName = $u.DisplayName
            MemberUPN         = $u.UserPrincipalName
        }
    }
}

# Sort once (used for screen + exports) to keep output stable and easy to compare between runs.
$resultsSorted = $results | Sort-Object GroupDisplayName, MemberDisplayName

# ===== Output to screen =====
# Display an at-a-glance view in the console.
$resultsSorted | Format-Table -AutoSize

# ===== Export files =====
# Timestamped filenames make it safe to run multiple times without overwriting previous reports.
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvPath  = ".\Clobba-GroupMembers-$timestamp.csv"
$htmlPath = ".\Clobba-GroupMembers-$timestamp.html"

# CSV
# UTF-8 is used to preserve international characters in names/UPNs.
$resultsSorted | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# HTML
# Embedded CSS keeps the report portable as a single file.
$style = @"
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; }
h1 { font-size: 20px; margin-bottom: 6px; }
p { color: #444; margin-top: 0; }
table { border-collapse: collapse; width: 100%; font-size: 13px; }
th, td { border: 1px solid #ddd; padding: 8px; }
th { background: #f3f3f3; text-align: left; position: sticky; top: 0; }
tr:nth-child(even) { background: #fafafa; }
tr:hover { background: #f1f7ff; }
.badge { display: inline-block; padding: 2px 8px; border-radius: 999px; background: #eef2ff; }
.small { font-size: 12px; color: #666; }
</style>
"@

# PreContent adds a header block above the HTML table including counts for quick validation.
$pre = @"
<h1>Clobba Group Membership Report</h1>
<p class='small'>Generated: $(Get-Date) &nbsp;|&nbsp; Groups matched: $($filteredGroups.Count) &nbsp;|&nbsp; Rows: $($resultsSorted.Count)</p>
"@

# Convert to HTML table and write to disk.
$resultsSorted |
ConvertTo-Html -Property GroupDisplayName, MemberDisplayName, MemberUPN -Head $style -PreContent $pre |
Out-File -FilePath $htmlPath -Encoding UTF8

# Final status output (paths are relative to the current working directory).
Write-Host "CSV saved to:  $csvPath"
Write-Host "HTML saved to: $htmlPath"