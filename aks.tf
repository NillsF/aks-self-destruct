provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x.
  # If you are using version 1.x, the "features" block is not allowed.
  version = "=2.20.0"
  features {}
}
locals {
  rgname = format("%s%s", "aks-sd-rg-", tostring(formatdate("YYYYMMDD'-'hhmm", timestamp())))
}

resource "azurerm_resource_group" "rg" {
        name = local.rgname
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