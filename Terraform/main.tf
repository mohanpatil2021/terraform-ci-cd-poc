terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.10.0"
    }
  }

  backend "azurerm" {
    resource_group_name = "TerraformBackend"
    storage_account_name = "terraformpocbackend"
    container_name = "backend-container"
    key = "backendConfig.tfstate"
  }

    required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}

  client_id = "0dacc793-78f6-442b-832b-f6160295b19b"
  client_secret = "krm8Q~cGCCS~FrY7Pw7Vu9u4s0PfqQZ0iNOr9ayi"
  tenant_id = "8ac76c91-e7f1-41ff-a89c-3553b2da2c17"
  subscription_id = "c4b0529f-c67d-491f-bbb4-137663eeb04c"
}

data "azurerm_client_config" "current" {}

module "ContainerApp_ResourceGroup" {
    source = "git::https://github.com/Ajay-Shrivastava/terraform-modules.git//Azure_Resource_Group?ref=main"
    resource_group_name = "TerraformPoc-App"
    resource_group_location = "East US"
}

module "ACR_ResourceGroup" {
    depends_on = [ module.ContainerApp_ResourceGroup ]
    source = "git::https://github.com/Ajay-Shrivastava/terraform-modules.git//Azure_Resource_Group?ref=main"
    resource_group_name = "TerraformPoc-ACR"
    resource_group_location = "East US"
}

resource "azurerm_container_registry" "acr" {
  depends_on = [ module.ACR_ResourceGroup ]
  name                     = "acrpocterraform"
  resource_group_name      = module.ACR_ResourceGroup.name
  location                 = module.ACR_ResourceGroup.location
  sku                      = "Basic"
  admin_enabled            = false
}

resource "azurerm_user_assigned_identity" "container_identity" {
  depends_on = [ azurerm_container_registry.acr ]
  name                = "container-app-identity"
  resource_group_name = "TerraformPoc-App"
  location            = "East US"
}

resource "azurerm_role_assignment" "acr_pull" {
  depends_on = [ azurerm_user_assigned_identity.container_identity ]
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_identity.principal_id
}

module "ContainerApp" {
    depends_on = [ azurerm_role_assignment.acr_pull ]
    source = "git::https://github.com/Ajay-Shrivastava/terraform-modules.git//Container_App?ref=main"
    container_app_environment_name = "mycontainerappenv"
    environment = "dev"
    container_app_name = "mycontainerapp"
    resource_group_name = "TerraformPoc-App"
    location = "East US"
    revision_mode = "Single"
    ContainerRegistry_loginServer = azurerm_container_registry.acr.login_server
    identityId = azurerm_user_assigned_identity.container_identity.id
    # DOCKER_REGISTRY_SERVER_URL = "https://${azurerm_container_registry.acr.login_server}"
    # DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.acr.admin_username
    # DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.acr.admin_password
}

#module "AcrPull_RoleAssignment" {
#    depends_on = [ module.ContainerApp ]
#    source = "git::https://github.com/Ajay-Shrivastava/terraform-modules.git//ACR_RoleAssignment?ref=main"
#    principal_id = module.ContainerApp.principal_id
#    acr_id = azurerm_container_registry.acr.id
#}
