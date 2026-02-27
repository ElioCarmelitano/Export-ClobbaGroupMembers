Created specifically named groups for a Clobba deployment. This script was to report on groups members for licence reconciliation.
Change the prefix and suffix filters as needed.

# Export-ClobbaGroupMembers
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
