<#
.SYNOPSIS
    Create Azure Management Group hierarchy with user-specified production and DR regions.

.DESCRIPTION
    Prompts user for Azure production and disaster recovery regions, validates inputs,
    and uses those to create a management group structure.

.NOTES
    Requires Az.Accounts and Az.Resources modules.
#>


# Get Azure regions dynamically
$locationObjects = Get-AzLocation
$azureRegions = $locationObjects.DisplayName | Sort-Object -Unique

# Map normalized variants to canonical DisplayName
$regionMap = @{}
foreach ($region in $azureRegions) {
    $normalized = $region.ToLower().Replace(" ", "")
    $regionMap[$normalized] = $region
}

# Function to normalize and validate region input
function Get-ValidatedRegion {
    param (
        [string]$Prompt
    )

    do {
        $input = Read-Host $Prompt
        $normalizedInput = $input.ToLower().Replace(" ", "")

        if ($regionMap.ContainsKey($normalizedInput)) {
            $resolvedRegion = $regionMap[$normalizedInput]
            Write-Host "Region accepted: $resolvedRegion" -ForegroundColor Green
            return $resolvedRegion
        } else {
            Write-Warning "Invalid region: '$input'. Try again using a format like 'UK South', 'North Europe', 'West Europe'."
        }
    } while ($true)
}

# Ask for Production and Disaster Recovery Regions
$prodRegion = Get-ValidatedRegion -Prompt "Enter your **PRODUCTION** Azure region (e.g. UK South, North Europe):"
$drRegion   = Get-ValidatedRegion -Prompt "Enter your **DISASTER RECOVERY** Azure region (e.g. West Europe, UK West):"

# Set the root management group ID
$tenantId = (Get-AzTenant | Select-Object -ExpandProperty Id)
$rootId   = "/providers/Microsoft.Management/managementGroups/$tenantId"


# Define hierarchy
$managementGroups = @(
    @{ Id="0101"; Name="Decommissioned"; Parent=$rootId },
    @{ Id="1101"; Name="Platform"; Parent="0101" },
    @{ Id="1102"; Name="Application"; Parent="0101" },

    @{ Id="0201"; Name="Development"; Parent=$rootId },
    @{ Id="1201"; Name="Platform"; Parent="0201" },
    @{ Id="2201"; Name=$prodRegion; Parent="1201" },
    @{ Id="3201"; Name="Connectivity"; Parent="2201" },
    @{ Id="3202"; Name="End User Compute"; Parent="2201" },
    @{ Id="3203"; Name="Identity"; Parent="2201" },
    @{ Id="3204"; Name="Management"; Parent="2201" },
    @{ Id="3205"; Name="Monitoring"; Parent="2201" },
    @{ Id="1202"; Name="Application"; Parent="0201" },
    @{ Id="2202"; Name=$prodRegion; Parent="1202" },

    @{ Id="0301"; Name="Disaster Recovery"; Parent=$rootId },
    @{ Id="1301"; Name="Platform"; Parent="0301" },
    @{ Id="2301"; Name=$drRegion; Parent="1301" },
    @{ Id="3301"; Name="Connectivity"; Parent="2301" },
    @{ Id="3302"; Name="End User Compute"; Parent="2301" },
    @{ Id="3303"; Name="Identity"; Parent="2301" },
    @{ Id="3304"; Name="Management"; Parent="2301" },
    @{ Id="3305"; Name="Monitoring"; Parent="2301" },
    @{ Id="1302"; Name="Application"; Parent="0301" },
    @{ Id="2302"; Name=$drRegion; Parent="1302" },

    @{ Id="0401"; Name="Production"; Parent=$rootId },
    @{ Id="1401"; Name="Platform"; Parent="0401" },
    @{ Id="2401"; Name=$prodRegion; Parent="1401" },
    @{ Id="3401"; Name="Connectivity"; Parent="2401" },
    @{ Id="3402"; Name="End User Compute"; Parent="2401" },
    @{ Id="3403"; Name="Identity"; Parent="2401" },
    @{ Id="3404"; Name="Management"; Parent="2401" },
    @{ Id="3405"; Name="Monitoring"; Parent="2401" },
    @{ Id="1402"; Name="Application"; Parent="0401" },
    @{ Id="2402"; Name=$prodRegion; Parent="1402" },

    @{ Id="0501"; Name="Staging"; Parent=$rootId },
    @{ Id="1501"; Name="Platform"; Parent="0501" },
    @{ Id="2501"; Name=$prodRegion; Parent="1501" },
    @{ Id="3501"; Name="Connectivity"; Parent="2501" },
    @{ Id="3502"; Name="End User Compute"; Parent="2501" },
    @{ Id="3503"; Name="Identity"; Parent="2501" },
    @{ Id="3504"; Name="Management"; Parent="2501" },
    @{ Id="3506"; Name="Monitoring"; Parent="2501" },
    @{ Id="1502"; Name="Application"; Parent="0501" },
    @{ Id="2502"; Name=$prodRegion; Parent="1502" },

    @{ Id="0601"; Name="User Acceptance"; Parent=$rootId },
    @{ Id="1601"; Name="Platform"; Parent="0601" },
    @{ Id="2601"; Name=$prodRegion; Parent="1601" },
    @{ Id="3601"; Name="Connectivity"; Parent="2601" },
    @{ Id="3602"; Name="End User Compute"; Parent="2601" },
    @{ Id="3603"; Name="Identity"; Parent="2601" },
    @{ Id="3604"; Name="Management"; Parent="2601" },
    @{ Id="3605"; Name="Monitoring"; Parent="2601" },
    @{ Id="1602"; Name="Application"; Parent="0601" },
    @{ Id="2602"; Name=$prodRegion; Parent="1602" }
)

# Track created groups
$createdGroups = @{}

# Create management groups
foreach ($mg in $managementGroups) {
    $parentId = if ($mg.Parent -eq $rootId) {
        $rootId
    } else {
        "/providers/Microsoft.Management/managementGroups/$($mg.Parent)"
    }

    try {
        New-AzManagementGroup -GroupName $mg.Id -DisplayName $mg.Name -ParentId $parentId -ErrorAction Stop
        $createdGroups[$mg.Id] = $mg.Name
        Write-Host "Created: $($mg.Name) ($($mg.Id))" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Failed to create $($mg.Name) ($($mg.Id)): $_"
    }
}

