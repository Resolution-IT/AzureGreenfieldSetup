<#
.SYNOPSIS
    Ensures required Azure Resource Providers are registered across all subscriptions in the tenant.

.DESCRIPTION
    For each subscription, checks if each listed resource provider is registered.
    If not, attempts to register it.

.NOTES
    Requires Az.Resources module.
#>

# Log in to Azure
Connect-AzAccount

# List of required resource providers
$requiredProviders = @(
    "Microsoft.ADHybridHealthService",
    "Microsoft.Advisor",
    "Microsoft.AlertsManagement",
    "Microsoft.App",
    "Microsoft.AppConfiguration",
    "Microsoft.Authorization",
    "Microsoft.Automation",
    "Microsoft.AzureTerraform",
    "Microsoft.Cache",
    "Microsoft.Capacity",
    "Microsoft.ChangeAnalysis",
    "Microsoft.CloudShell",
    "Microsoft.Compute",
    "Microsoft.Consumption",
    "Microsoft.ContainerInstance",
    "Microsoft.ContainerService",
    "Microsoft.CostManagement",
    "Microsoft.CostManagementExports",
    "Microsoft.DataProtection",
    "Microsoft.DesktopVirtualization",
    "Microsoft.DevTestLap",
    "Microsoft.EventGrid",
    "Microsoft.Fabric",
    "Microsoft.Features",
    "Microsoft.GuestConfidugration",
    "Microsoft.Help",
    "Microsoft.IoTSecurity",
    "Microsoft.KeyVault",
    "Microsoft.Logic",
    "Microsoft.Maintenance",
    "Microsoft.ManagedIdentity",
    "Microsoft.MarketplaceOrdering",
    "Microsoft.Migrate",
    "Microsoft.Monitor",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
    "Microsoft.OperationsManagement",
    "Microsoft.PolicyInsights",
    "Microsoft.Portal",
    "Microsoft.RecoveryServices",
    "Microsoft.ResourceGraph",
    "Microsoft.ResourceHealth",
    "Microsoft.ResourceNotifications",
    "Microsoft.Resources",
    "Microsoft.SaaS",
    "Microsoft.Security",
    "Microsoft.SecurityInsights",
    "Microsoft.SerialConsole",
    "Microsoft.Sql",
    "Microsoft.SqlVirtualMachine",
    "Microsoft.Storage",
    "Microsoft.StorageMover",
    "Microsoft.StorageSync",
    "Microsoft.VirtualMachineImages",
    "Microsoft.Web",
    "microsoft.insights",
    "microsoft.support"
)

# Get all subscriptions the user has access to
$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {
    Write-Host "==========================" -ForegroundColor Yellow
    Write-Host "Processing Subscription: $($sub.Name) [$($sub.Id)]" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Yellow

    # Set the context to the current subscription
    Set-AzContext -SubscriptionId $sub.Id | Out-Null

    foreach ($provider in $requiredProviders) {
        try {
            $registration = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop
            if ($registration.RegistrationState -ne "Registered") {
                Write-Host "Registering provider: $provider" -ForegroundColor White
                Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop
            } else {
                Write-Host "Already registered: $provider" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Failed to process provider '$provider'- $_"
        }
    }
}
