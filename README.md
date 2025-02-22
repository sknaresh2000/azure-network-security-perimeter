## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | =2.2.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | =4.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | 2.2.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.1.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.4.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azapi_resource.inbound_access_rules](https://registry.terraform.io/providers/azure/azapi/2.2.0/docs/resources/resource) | resource |
| [azapi_resource.nsp](https://registry.terraform.io/providers/azure/azapi/2.2.0/docs/resources/resource) | resource |
| [azapi_resource.nsp_profile](https://registry.terraform.io/providers/azure/azapi/2.2.0/docs/resources/resource) | resource |
| [azapi_resource.resource_associations](https://registry.terraform.io/providers/azure/azapi/2.2.0/docs/resources/resource) | resource |
| [azurerm_eventhub.eh](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/resources/eventhub) | resource |
| [azurerm_eventhub_namespace.ehn](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/resources/eventhub_namespace) | resource |
| [azurerm_key_vault.kv](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/resources/key_vault) | resource |
| [azurerm_key_vault_key.key](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/resources/key_vault_key) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.cmk_role_assignment](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.key_role_assignment](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.sa](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/resources/storage_account) | resource |
| [azurerm_user_assigned_identity.uai](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/resources/user_assigned_identity) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/4.1.0/docs/data-sources/client_config) | data source |
| [http_http.myip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Enable encryption on storage account ? | `bool` | `false` | no |
| <a name="input_enable_nsp"></a> [enable\_nsp](#input\_enable\_nsp) | Enabled Network Security Perimeter | `bool` | `false` | no |
| <a name="input_enable_remote_access"></a> [enable\_remote\_access](#input\_enable\_remote\_access) | Enable access to connect from local machine | `bool` | `false` | no |
| <a name="input_location"></a> [location](#input\_location) | Location of the resources that will be deployed in Azure | `string` | `"East US"` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | ID of the subscription where the resources will be deployed | `string` | n/a | yes |

## Outputs

No outputs.
