provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x.
  # If you are using version 1.x, the "features" block is not allowed.
  version = "=2.20.0"
  features {}
}
locals {
  rgname        = format("%s%s", "aks-sd-rg-", tostring(formatdate("YYYYMMDD'-'hhmm", timestamp())))
  managedrgname = "MC_${azurerm_resource_group.rg.name}_aks-sd_westus2"
  idname        = "aks-sd-id"
}

resource "azurerm_resource_group" "rg" {
  name     = local.rgname
  location = "westus2"
}

resource "azurerm_kubernetes_cluster" "aks-sd" {
  name                = "contoso-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "contoso-aks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}


# Create User Assigned Managed Identity. We'll use this for the AAD pod identity to delete the RG.
resource "azurerm_user_assigned_identity" "delete-id" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  name = format("%s%s", "aks-sd-id-", tostring(formatdate("YYYYMMDD'-'hhmm", timestamp())))
}

# Get managed RG. Use depends_on to wait until AKS cluster is created
data "azurerm_resource_group" "managed-rg" {
  name = "MC_${azurerm_resource_group.rg.name}_${azurerm_kubernetes_cluster.aks-sd.name}_westus2"
  depends_on = [
    azurerm_kubernetes_cluster.aks-sd
  ]
}

# Get managed identity created by AKS creation process. Use depends_on to wait until AKS cluster is created
data "azurerm_user_assigned_identity" "created-id" {
  name                = "${azurerm_kubernetes_cluster.aks-sd.name}-agentpool"
  resource_group_name = data.azurerm_resource_group.managed-rg.name
  depends_on = [
    azurerm_kubernetes_cluster.aks-sd
  ]
}

# Create RBAC assignments. We'll create 3 in total
# our MI --> our RG
resource "azurerm_role_assignment" "user-id-rg" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.delete-id.principal_id
}
# created MI --> our RG
resource "azurerm_role_assignment" "created-id-rg" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_user_assigned_identity.created-id.principal_id
}
# created MI --> AKS managed RG
resource "azurerm_role_assignment" "created-id-managed-rg" {
  scope                = data.azurerm_resource_group.managed-rg.id
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_user_assigned_identity.created-id.principal_id
}




output "RGNAME" {
  value = "${azurerm_resource_group.rg.name}"
}
output "IDNAME" {
  value = "${azurerm_user_assigned_identity.delete-id.name}"
}
output "IDENTITY_CLIENT_ID" {
  value = "${azurerm_user_assigned_identity.delete-id.client_id}"
}
output "IDENTITY_RESOURCE_ID" {
  value = "${azurerm_user_assigned_identity.delete-id.id}"
}
