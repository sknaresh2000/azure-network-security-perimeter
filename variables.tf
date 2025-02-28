variable "location" {
  type        = string
  description = "Location of the resources that will be deployed in Azure"
  default     = "East US"
}

variable "enable_remote_access" {
  type        = bool
  description = "Enable access to connect from local machine"
  default     = false
}

variable "subscription_id" {
  type        = string
  description = "ID of the subscription where the resources will be deployed"
}

variable "enable_encryption" {
  type        = bool
  description = "Enable encryption on storage account ?"
  default     = false
}

variable "enable_nsp" {
  type        = bool
  description = "Enabled Network Security Perimeter"
  default     = false
}

variable "configure_nsp_policy" {
  type        = bool
  description = "Configure Azure Policy for NSP Access Rules ?"
  default     = false
}