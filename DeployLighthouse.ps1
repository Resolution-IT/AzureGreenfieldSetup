<#
.SYNOPSIS
Deploy Azure Lighthouse registration definitions/assignments to one or many subscriptions,
pulling ARM templates from fixed (hard-coded) GitHub Raw URLs.

.REQUIREMENTS
- Azure CLI (az) installed and logged in
- PowerShell 7+ recommended

.EXAMPLES
.\Deploy-Lighthouse.ps1 -Mode Single -SubscriptionId "00000000-0000-0000-0000-000000000000" -Location "uksouth"
.\Deploy-Lighthouse.ps1 -Mode All -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateSet("Single","All")]
  [string]$Mode = "Single",

  [Parameter(Mandatory = $false)]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $false)]
  [string]$Location = "westeurope",

  [switch]$WhatIf
)

$GitHubOrg   = "Resolution-IT"
$GitHubRepo  = "AzureGreenfieldSetup"
$GitBranch   = "main"
$GitHubRawBase = "https://raw.githubusercontent.com/$GitHubOrg/$GitHubRepo/$GitBranch"

# File names in the repo (change if you rename them)
$TemplateFiles = @(
  "Lighthouse-RIT-Tier1.json",
  "Lighthouse-RIT-Tier2.json",
  "Lighthouse-RIT-Tier3.json"
)
# ========================================

# ---- Helpers ----
function Ensure-AzLogin {
  Write-Host "Checking Azure login..." -ForegroundColor Cyan
  try {
    $null = az account show 2>$null
  } catch {
    Write-Host "Not logged in. Opening browser..." -ForegroundColor Yellow
    az login | Out-Null
  }
  $null = az account show | Out-Null
}

function Get-TemplateUris {
  param([string]$RawBase,[string[]]$Files)
  return $Files | ForEach-Object { "$RawBase/$($_)" }
}

function Invoke-Deployment {
  param(
    [string]$SubscriptionId,
    [string]$Location,
    [string[]]$TemplateUris,
    [switch]$WhatIfSwitch
  )

  Write-Host "`n==> Switching to subscription $SubscriptionId" -ForegroundColor Cyan
  az account set --subscription $SubscriptionId | Out-Null

  foreach ($tpl in $TemplateUris) {
    $tierName = [System.IO.Path]::GetFileNameWithoutExtension($tpl)
    $stamp    = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $deployName = "$($tierName)-$stamp"

    Write-Host "Deploying template: $tpl" -ForegroundColor Green

    if ($WhatIfSwitch) {
      $cmd = @(
        "deployment","sub","what-if",
        "--name",$deployName,
        "--location",$Location,
        "--template-uri",$tpl,
        "--only-show-errors",
        "--query","{status:status,changes:changes[].{type:changeType,resourceType:targetResource.resourceType,name:targetResource.resourceName}}"
      )
    } else {
      $cmd = @(
        "deployment","sub","create",
        "--name",$deployName,
        "--location",$Location,
        "--template-uri",$tpl,
        "--only-show-errors"
      )
    }

    try {
      $result = az $cmd 2>&1
      if ($LASTEXITCODE -ne 0) {
        Write-Host "Deployment failed for $tierName in $SubscriptionId" -ForegroundColor Red
        Write-Host $result
        continue
      }

      Write-Host "Success: $tierName => $deployName" -ForegroundColor Green
      if (-not $WhatIfSwitch) {
        try {
          $outputs = ($result | ConvertFrom-Json).properties.outputs
          if ($outputs) {
            Write-Host "Outputs:" -ForegroundColor Cyan
            $outputs.GetEnumerator() | ForEach-Object {
              Write-Host ("  {0}: {1}" -f $_.Key, ($_.Value.value | ConvertTo-Json -Compress))
            }
          }
        } catch { }
      } else {
        Write-Host "What-If plan above for $tierName." -ForegroundColor Yellow
      }
    } catch {
      Write-Host "Unexpected error during deployment of $tierName -" -ForegroundColor Red
      Write-Host $_
    }
  }
}

# ---- Main ----
try {
  Ensure-AzLogin

  # Quick reachability probe so we fail fast if URLs are wrong
  $probeUrl = "$GitHubRawBase/$($TemplateFiles[0])"
  try {
    $probe = Invoke-WebRequest -Uri $probeUrl -Method Head -UseBasicParsing -TimeoutSec 15
    if ($probe.StatusCode -lt 200 -or $probe.StatusCode -ge 400) {
      throw "Templates not reachable at $GitHubRawBase (HTTP $($probe.StatusCode))."
    }
  } catch {
    throw "Could not reach $probeUrl. Check GitHubOrg/Repo/Branch or file path."
  }

  $templateUris = Get-TemplateUris -RawBase $GitHubRawBase -Files $TemplateFiles

  switch ($Mode) {
    "Single" {
      if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
        throw "Missing required value: SubscriptionId (in Single mode)."
      }
      Invoke-Deployment -SubscriptionId $SubscriptionId -Location $Location -TemplateUris $templateUris -WhatIfSwitch:$WhatIf
    }
    "All" {
      Write-Host "Retrieving all accessible subscriptions..." -ForegroundColor Yellow
      $subs = az account list --query "[].id" -o tsv
      if (-not $subs) { throw "No accessible subscriptions found for current identity." }
      foreach ($sub in $subs) {
        Invoke-Deployment -SubscriptionId $sub -Location $Location -TemplateUris $templateUris -WhatIfSwitch:$WhatIf
      }
    }
  }

  Write-Host "`nFinished." -ForegroundColor Cyan

} catch {
  Write-Host "Fatal error: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
