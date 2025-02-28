data "azurerm_client_config" "current" {}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

### Policy to enforce NSP to configure only allowed IP ranges. In this case, its the machine that the code is running from
### If you dno wish to have this policy, ignore the variable - configure_nsp_policy while running Terraform
resource "azurerm_policy_definition" "nsp_policy" {
  for_each     = var.configure_nsp_policy ? toset(["nsp_access_rule_policy"]) : toset([])
  name         = "NSP-AllowedIP-AccessRules-Policy"
  policy_type  = "Custom"
  mode         = local.nsp_policy_file.mode
  display_name = "NSP Inbound Access Rules should use allowed IP ranges"
  policy_rule  = jsonencode(local.nsp_policy_file.policyRule)
  parameters   = jsonencode(local.nsp_policy_file.parameters)
}

resource "azurerm_subscription_policy_assignment" "nsp_policy_assignment" {
  for_each             = var.configure_nsp_policy ? toset(["nsp_access_rule_policy"]) : toset([])
  name                 = "NSP-AllowedIP-AccessRules-Policy"
  policy_definition_id = azurerm_policy_definition.nsp_policy[each.value].id
  subscription_id      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  parameters           = <<PARAMETERS
{
  "allowedIPAddresses": {
    "value": ${jsonencode(["${chomp(data.http.myip.response_body)}/32"])}
  }
} 
PARAMETERS
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-nsp-eus"
  location = var.location
  tags = {
    purpose = "Network_Security_Perimeter"
  }
}

### User Assigned Identity for Storage Account to access keys in key vault
resource "azurerm_user_assigned_identity" "uai" {
  location            = var.location
  name                = "uai-nsp-eus"
  resource_group_name = azurerm_resource_group.rg.name
}

# assign UAI sufficient permissions to retrieve keys from key vault
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
  name                             = "stonspeus01"
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
  name                          = "kvnspeus01"
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

resource "azurerm_eventhub_namespace" "ehn" {
  name                          = "ehnnspeus01"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  sku                           = "Standard"
  capacity                      = 1
  public_network_access_enabled = false
}

resource "azurerm_eventhub" "eh" {
  name                = "ehnspeus01"
  resource_group_name = azurerm_resource_group.rg.name
  namespace_name      = azurerm_eventhub_namespace.ehn.name
  partition_count     = 2
  message_retention   = 1
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

resource "azapi_resource" "resource_associations" {
  depends_on = [azapi_resource.inbound_access_rules]
  for_each   = var.enable_nsp ? local.resources_to_associate : {}
  type       = "Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2023-08-01-preview"
  name       = "nsp-associations-${each.value.name}"
  parent_id  = azapi_resource.nsp["nsp"].id
  location   = var.location
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

#### NSP Logging
resource "azurerm_log_analytics_workspace" "law" {
  name                = "lawnspeus01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "nsp-logging" {
  for_each                   = var.enable_nsp ? toset(["nsp"]) : toset([])
  name                       = "nsp-diag"
  target_resource_id         = azapi_resource.nsp[each.value].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "paas_resources" {
  for_each                   = { for k, v in local.resources_to_associate : k => v if k != "storage" }
  name                       = "diag"
  target_resource_id         = each.value.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  enabled_log {
    category_group = "allLogs"
  }
  metric {
    category = "AllMetrics"
    enabled  = false
  }
}

locals {
  nsp_policy_file = jsondecode(file("azure-policy-definition/deny-nsp-ip-rules.json"))
  resources_to_associate = {
    kv = {
      name = azurerm_key_vault.kv.name
      id   = azurerm_key_vault.kv.id
    }
    storage = {
      name = azurerm_storage_account.sa.name
      id   = azurerm_storage_account.sa.id
    }
    eventhub = {
      name = azurerm_eventhub_namespace.ehn.name
      id   = azurerm_eventhub_namespace.ehn.id
    }
    law = {
      name = azurerm_log_analytics_workspace.law.name
      id   = azurerm_log_analytics_workspace.law.id
    }
  }
}
