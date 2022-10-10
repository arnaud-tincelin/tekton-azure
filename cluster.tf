resource "azurerm_resource_group" "tekton" {
  name     = "tekton"
  location = "West Europe"
}

resource "azurerm_kubernetes_cluster" "tekton" {
  name                = "tekton"
  location            = azurerm_resource_group.tekton.location
  resource_group_name = azurerm_resource_group.tekton.name
  dns_prefix          = "tekton"
  oidc_issuer_enabled = true

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

locals {
  kubeconfig_file_to_create = "kubeconfig"
  kubeconfig_path           = null_resource.kubeconfig.triggers.kubeconfig_path
}

resource "null_resource" "kubeconfig" {
  triggers = {
    kubeconfig_raw     = azurerm_kubernetes_cluster.tekton.kube_config_raw
    kubeconfig_path    = local.kubeconfig_file_to_create
    kubeconfig_content = fileexists(local.kubeconfig_file_to_create) ? sha1(file(local.kubeconfig_file_to_create)) : ""
  }
  provisioner "local-exec" {
    command = <<EOT
      echo '${self.triggers.kubeconfig_raw}' > ${self.triggers.kubeconfig_path}
    EOT
  }
}
