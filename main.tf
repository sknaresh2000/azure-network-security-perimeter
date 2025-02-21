data "azurerm_client_config" "current" {}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-nsp-micro-hack-eus"
  location = var.location
  tags = {
    purpose = "NSP-Micro-Hack"
  }
}

resource "azapi_resource" "nsp" {
  for_each  = var.enable_nsp ? toset(["nsp"]) : toset([])
  type      = "Microsoft.Network/networkSecurityPerimeters@2023-08-01-preview"
  parent_id = azurerm_resource_group.rg.id
  name      = "nsp-eus"
  location  = var.location
}

resource "azapi_resource" "nsp_profile" {
  for_each  = var.enable_nsp ? toset(["nsp"]) : toset([])
  type      = "Microsoft.Network/networkSecurityPerimeters/profiles@2023-08-01-preview"
  parent_id = azapi_resource.nsp[each.key].id
  name      = "paas_boundary"
  location  = var.location
}

resource "azapi_resource" "inbound_access_rules" {
  for_each  = var.enable_nsp ? toset(["access_rule"]) : toset([])
  parent_id = azapi_resource.nsp_profile["nsp"].id
  type      = "Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2023-08-01-preview"
  name      = "inbound_access_rules"
  location  = var.location
  body = {
    properties = {
      addressPrefixes = ["${chomp(data.http.myip.response_body)}/32"]
      direction       = "Inbound"
    }
  }
}
resource "azurerm_user_assigned_identity" "uai" {
  location            = var.location
  name                = "uai-nsp-eus"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "cmk_role_assignment" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id
}

### assign current SPN/user principal ID to provide RBAC access for creation of keys
resource "azurerm_role_assignment" "key_role_assignment" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_account" "sa" {
  name                             = "stonspeus001"
  resource_group_name              = azurerm_resource_group.rg.name
  location                         = var.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  cross_tenant_replication_enabled = false
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  public_network_access_enabled    = false
  dynamic "identity" {
    for_each = var.enable_encryption ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.uai.id]
    }
  }
  dynamic "customer_managed_key" {
    for_each = var.enable_encryption ? [1] : []
    content {
      key_vault_key_id          = azurerm_key_vault_key.key.id
      user_assigned_identity_id = azurerm_user_assigned_identity.uai.id
    }
  }
}

resource "azurerm_key_vault" "kv" {
  name                          = "kvnspeus001"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  sku_name                      = "standard"
  public_network_access_enabled = true
  enable_rbac_authorization     = true
  network_acls {
    default_action = "Deny"
    bypass         = "None"
    ip_rules       = ["${chomp(data.http.myip.response_body)}/32"]
  }
}

resource "azurerm_key_vault_key" "key" {
  depends_on   = [azurerm_role_assignment.key_role_assignment]
  name         = "sa-cmk"
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = "RSA"
  key_size     = 3072
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }
}

resource "azapi_resource" "resource_associations" {
  for_each  = var.enable_nsp ? local.resources_to_associate : {}
  type      = "Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2023-08-01-preview"
  name      = "nsp-associations-${each.value.name}"
  parent_id = azapi_resource.nsp["nsp"].id
  location  = var.location
  body = {
    properties = {
      accessMode = "Enforced"
      privateLinkResource = {
        id = each.value.id
      }
      profile = {
        id = azapi_resource.nsp_profile["nsp"].id
      }
    }
  }
}

locals {
  resources_to_associate = {
    kv = {
      name = azurerm_key_vault.kv.name
      id   = azurerm_key_vault.kv.id
    }
    storage = {
      name = azurerm_storage_account.sa.name
      id   = azurerm_storage_account.sa.id
    }
  }
}
