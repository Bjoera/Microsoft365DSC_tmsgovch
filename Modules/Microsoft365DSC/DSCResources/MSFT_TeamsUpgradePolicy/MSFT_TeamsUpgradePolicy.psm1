function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [Parameter()]
        [System.String[]]
        $Users,

        [Parameter()]
        [System.Boolean]
        $MigrateMeetingsToTeams,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $GlobalAdminAccount
    )
    $ConnectionMode = New-M365DSCConnection -Platform 'MicrosoftTeams' `
        -InboundParameters $PSBoundParameters

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace("MSFT_", "")
    $data = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
    $data.Add("Resource", $ResourceName)
    $data.Add("Method", $MyInvocation.MyCommand)
    $data.Add("Principal", $GlobalAdminAccount.UserName)
    $data.Add("TenantId", $TenantId)
    $data.Add("ConnectionMode", $ConnectionMode)
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    Write-Verbose -Message "Checking the Teams Upgrade Policies"

    try
    {
        $policy = Get-CsTeamsUpgradePolicy -Identity $Identity `
            -ErrorAction SilentlyContinue

        try
        {
            [array]$users = Get-CsOnlineUser -Filter "TeamsUpgradePolicy -eq '$Identity'"
        }
        catch
        {
            [array]$users = Get-CsOnlineUser | Where-Object -Filter { $_.TeamsUpgradePolicy -eq $Identity }
        }

        if ($null -eq $policy)
        {
            throw "No Teams Upgrade Policy with Identity {$Identity} was found"
        }

        [array]$usersList = @()
        foreach ($user in $users)
        {
            $usersList += $user.UserPrincipalName
        }
        Write-Verbose -Message "Found Teams Upgrade Policy with Identity {$Identity}"
        return @{
            Identity               = $Identity
            Users                  = $usersList
            MigrateMeetingsToTeams = $MigrateMeetingsToTeams
            GlobalAdminAccount     = $GlobalAdminAccount
        }
    }
    catch
    {
        try
        {
            Write-Verbose -Message $_
            $tenantIdValue = ""
            if (-not [System.String]::IsNullOrEmpty($TenantId))
            {
                $tenantIdValue = $TenantId
            }
            elseif ($null -ne $GlobalAdminAccount)
            {
                $tenantIdValue = $GlobalAdminAccount.UserName.Split('@')[1]
            }
            Add-M365DSCEvent -Message $_ -EntryType 'Error' `
                -EventID 1 -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $tenantIdValue
        }
        catch
        {
            Write-Verbose -Message $_
        }
        throw $_
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [Parameter()]
        [System.String[]]
        $Users,

        [Parameter()]
        [System.Boolean]
        $MigrateMeetingsToTeams,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $GlobalAdminAccount
    )

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace("MSFT_", "")
    $data = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
    $data.Add("Resource", $ResourceName)
    $data.Add("Method", $MyInvocation.MyCommand)
    $data.Add("Principal", $GlobalAdminAccount.UserName)
    Add-M365DSCTelemetryEvent -Data $data
    #endregion
    Write-Verbose -Message "Updating Teams Upgrade Policy {$Identity}"

    $ConnectionMode = New-M365DSCConnection -Platform 'MicrosoftTeams' `
        -InboundParameters $PSBoundParameters

    foreach ($user in $Users)
    {
        Write-Verbose -Message "Granting TeamsUpgradePolicy {$Identity} to User {$user} with MigrateMeetingsToTeams=$MigrateMeetingsToTeams"
        Grant-CsTeamsUpgradePolicy -PolicyName $Identity -Identity $user -MigrateMeetingsToTeams:$MigrateMeetingsToTeams
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [Parameter()]
        [System.String[]]
        $Users,

        [Parameter()]
        [System.Boolean]
        $MigrateMeetingsToTeams,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $GlobalAdminAccount
    )
    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace("MSFT_", "")
    $data = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
    $data.Add("Resource", $ResourceName)
    $data.Add("Method", $MyInvocation.MyCommand)
    $data.Add("Principal", $GlobalAdminAccount.UserName)
    $data.Add("TenantId", $TenantId)
    Add-M365DSCTelemetryEvent -Data $data
    #endregion
    Write-Verbose -Message "Testing configuration of Team Upgrade Policy {$Identity}"

    $CurrentValues = Get-TargetResource @PSBoundParameters

    Write-Verbose -Message "Current Values: $(Convert-M365DscHashtableToString -Hashtable $CurrentValues)"
    Write-Verbose -Message "Target Values: $(Convert-M365DscHashtableToString -Hashtable $PSBoundParameters)"

    $ValuesToCheck = $PSBoundParameters
    $ValuesToCheck.Remove('GlobalAdminAccount') | Out-Null

    $TestResult = Test-M365DSCParameterState -CurrentValues $CurrentValues `
        -Source $($MyInvocation.MyCommand.Source) `
        -DesiredValues $PSBoundParameters `
        -ValuesToCheck $ValuesToCheck.Keys

    Write-Verbose -Message "Test-TargetResource returned $TestResult"

    return $TestResult
}

function Export-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $GlobalAdminAccount
    )
    $ConnectionMode = New-M365DSCConnection -Platform 'MicrosoftTeams' `
        -InboundParameters $PSBoundParameters

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace("MSFT_", "")
    $data = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
    $data.Add("Resource", $ResourceName)
    $data.Add("Method", $MyInvocation.MyCommand)
    $data.Add("Principal", $GlobalAdminAccount.UserName)
    $data.Add("TenantId", $TenantId)
    $data.Add("ConnectionMode", $ConnectionMode)
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $organization = ""
    if ($GlobalAdminAccount.UserName.Contains("@"))
    {
        $organization = $GlobalAdminAccount.UserName.Split("@")[1]
    }

    try
    {
        [array]$policies = Get-CsTeamsUpgradePolicy -ErrorAction Stop
        $i = 1
        $dscContent = ''
        Write-Host "`r`n" -NoNewline
        foreach ($policy in $policies)
        {
            Write-Host "    |---[$i/$($policies.Count)] $($policy.Identity.Replace('Tag:', ''))" -NoNewline
            $params = @{
                Identity           = $policy.Identity.Replace("Tag:", "")
                GlobalAdminAccount = $GlobalAdminAccount
            }
            $result = Get-TargetResource @params
            $result.GlobalAdminAccount = Resolve-Credentials -UserName "globaladmin"
            $currentDSCBlock = "        TeamsUpgradePolicy " + (New-Guid).ToString() + "`r`n"
            $currentDSCBlock += "        {`r`n"
            $partialContent = Get-DSCBlock -Params $result -ModulePath $PSScriptRoot
            $partialContent = Convert-DSCStringParamToVariable -DSCBlock $partialContent `
                -ParameterName "GlobalAdminAccount"
            if ($partialContent.ToLower().IndexOf($organization.ToLower()) -gt 0)
            {
                $partialContent = $partialContent -ireplace [regex]::Escape("@" + $organization), "@`$OrganizationName"
            }
            $currentDSCBlock += $partialContent
            $currentDSCBlock += "        }`r`n"
            $dscContent += $currentDSCBlock
            Save-M365DSCPartialExport -Content $currentDSCBlock `
                -FileName $Global:PartialExportFileName
            $i++
            Write-Host $Global:M365DSCEmojiGreenCheckMark
        }
        return $dscContent
    }
    catch
    {
        Write-Host $Global:M365DSCEmojiRedX
        try
        {
            Write-Verbose -Message $_
            $tenantIdValue = ""
            if (-not [System.String]::IsNullOrEmpty($TenantId))
            {
                $tenantIdValue = $TenantId
            }
            elseif ($null -ne $GlobalAdminAccount)
            {
                $tenantIdValue = $GlobalAdminAccount.UserName.Split('@')[1]
            }
            Add-M365DSCEvent -Message $_ -EntryType 'Error' `
                -EventID 1 -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $tenantIdValue
        }
        catch
        {
            Write-Verbose -Message $_
        }
        return ""
    }
}

Export-ModuleMember -Function *-TargetResource
