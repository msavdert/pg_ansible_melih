terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # backend "azurerm" {
  #   resource_group_name  = "your-terraform-state-rg"
  #   storage_account_name = "yourterraformstateaccount"
  #   container_name       = "tfstate"
  #   key                  = "azure-postgres/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  # subscription_id = var.subscription_id # Configure via env var ARM_SUBSCRIPTION_ID or here
  # client_id       = var.client_id       # Configure via env var ARM_CLIENT_ID or here
  # client_secret   = var.client_secret   # Configure via env var ARM_CLIENT_SECRET or here
  # tenant_id       = var.tenant_id       # Configure via env var ARM_TENANT_ID or here
}

resource "random_password" "pg_password" {
  length           = 16
  special          = true
  override_special = "_%@!?" # Azure has stricter rules sometimes
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "azurerm_resource_group" "default" {
  name     = var.resource_group_name == "" ? "${var.project_name}-${var.environment}-rg" : var.resource_group_name
  location = var.location
  tags     = var.common_tags
}

# Example for Azure Database for PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "default" {
  name                   = var.pg_server_name == "" ? "${var.project_name}-${var.environment}-pgflex" : var.pg_server_name
  resource_group_name    = azurerm_resource_group.default.name
  location               = azurerm_resource_group.default.location
  version                = var.pg_version
  administrator_login    = var.pg_admin_login
  administrator_password = var.pg_admin_password_override != "" ? var.pg_admin_password_override : random_password.pg_password.result
  sku_name               = var.pg_sku_name # e.g., "GP_Standard_D2s_v3" or "B_Standard_B1ms"

  storage_mb = var.pg_storage_mb
  # backup_retention_days  = var.backup_retention_days
  # geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  # Networking - for private access, you would configure delegation to a subnet
  # delegate_subnet_id = azurerm_subnet.default.id # If creating VNet and subnet here
  # private_dns_zone_id = azurerm_private_dns_zone.default.id # If using private DNS zone

  # For public access (not recommended for production without proper firewall rules)
  public_network_access_enabled = var.public_network_access_enabled

  tags = merge(
    var.common_tags,
    {
      Name        = var.pg_server_name == "" ? "${var.project_name}-${var.environment}-pgflex" : var.pg_server_name,
      Project     = var.project_name,
      Environment = var.environment
    }
  )

  # zone = var.availability_zone # e.g., "1"

  # High availability
  # high_availability {
  #   mode                      = var.ha_mode # "ZoneRedundant" or "SameZone"
  #   standby_availability_zone = var.ha_standby_availability_zone # Required if mode is ZoneRedundant
  # }

  depends_on = [azurerm_resource_group.default]
}

# Example Firewall rule - allows access from a specific IP or Azure services
# Be very careful with firewall rules, especially 0.0.0.0/0
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_specific_ip" {
  count = var.allow_ip_address != "" ? 1 : 0

  name                = "allow-ip-${replace(var.allow_ip_address, ".", "-")}"
  server_id           = azurerm_postgresql_flexible_server.default.id
  start_ip_address    = var.allow_ip_address
  end_ip_address      = var.allow_ip_address
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  count = var.allow_azure_services ? 1 : 0

  name                = "allow-azure-internal"
  server_id           = azurerm_postgresql_flexible_server.default.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0" # Special value for Azure services
}


# Note: For a production setup, you would integrate with VNet, Subnets, Private DNS Zones, etc.
# This example is simplified.
#
# resource "azurerm_virtual_network" "default" {
#   name                = "${var.project_name}-vnet"
#   address_space       = ["10.0.0.0/16"]
#   location            = azurerm_resource_group.default.location
#   resource_group_name = azurerm_resource_group.default.name
# }

# resource "azurerm_subnet" "default" {
#   name                 = "${var.project_name}-pgsubnet"
#   resource_group_name  = azurerm_resource_group.default.name
#   virtual_network_name = azurerm_virtual_network.default.name
#   address_prefixes     = ["10.0.1.0/24"]
#   delegation {
#     name = "fs"
#     service_delegation {
#       name = "Microsoft.DBforPostgreSQL/flexibleServers"
#       actions = [
#         "Microsoft.Network/virtualNetworks/subnets/join/action",
#       ]
#     }
#   }
# }
