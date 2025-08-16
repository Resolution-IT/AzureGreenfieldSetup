<#
.SYNOPSIS
    Associates a Microsoft Azure Partner ID with the current Azure subscription.

.DESCRIPTION
    This script verifies required Azure modules, authenticates to Azure, 
    and associates a Microsoft Partner ID (MPN ID) with the current subscription.
    
.NOTES
    Requires Az.Accounts, Az.Resources, and Az.Billing.
#>

param(
  [string]$PartnerId = "2101226"
)

# --- Logging helpers ---
$LogFile = "PartnerAssociation.log"
function Write-Log {
  param([string]$Message,[ValidateSet("INFO","WARN","ERROR")][string]$Level="INFO")
  $line = "[{0}] {1}" -f $Level, $Message
  Write-Host $line -ForegroundColor @{"INFO"="Cyan";"WARN"="Yellow";"ERROR"="Red"}[$Level]
  Add-Content -Path $LogFile -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $line)
}

# --- Ensure module ---
$required = @("Az.Accounts","Az.Resources","Az.ManagementPartner")
foreach ($m in $required) {
  if (-not (Get-Module -ListAvailable -Name $m)) {
    Write-Log "Installing module $m..." "INFO"
    try { Install-Module -Name $m -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop }
    catch { Write-Log "Failed to install $m. $_" "ERROR"; throw }
  }
}
foreach ($m in $required) {
  if (-not (Get-Module -Name $m)) {
    try { Import-Module $m -ErrorAction Stop }
    catch { Write-Log "Failed to import $m. $_" "ERROR"; throw }
  }
}

# --- Context guard ---
try {
  $ctx = Get-AzContext -ErrorAction Stop
  if (-not $ctx) { throw "No Az context. Please Connect-AzAccount first." }
} catch {
  Write-Log "No Azure context. $_" "ERROR"; throw
}

# --- Associate Partner ID (idempotent) ---
try {
  Write-Log "Checking existing partner association..." "INFO"
  $existing = Get-AzManagementPartner -ErrorAction SilentlyContinue
  if ($existing -and $existing.PartnerId -eq $PartnerId) {
    Write-Log "Partner ID $PartnerId already associated. Skipping." "INFO"
    return
  }

  Write-Log "Associating Partner ID $PartnerId ..." "INFO"
  New-AzManagementPartner -PartnerId $PartnerId -ErrorAction Stop
  Write-Log "Partner ID $PartnerId successfully associated." "INFO"
}
catch {
  Write-Log "Failed to associate Partner ID. $_" "ERROR"
  throw   # DO NOT use exit; bubble up for the caller to handle
}
