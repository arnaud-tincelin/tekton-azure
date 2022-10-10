data "azurerm_subscription" "primary" {
}

resource "azurerm_user_assigned_identity" "tekton_workload_identity" {
  name                = "tekton-workload-identity"
  location            = azurerm_resource_group.tekton.location
  resource_group_name = azurerm_resource_group.tekton.name
}

resource "azurerm_role_assignment" "tekton_sub_contributor" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.tekton_workload_identity.principal_id
}

# https://azure.github.io/azure-workload-identity/docs/topics/federated-identity-credential.html#federated-identity-credential-for-a-user-assigned-managed-identity
resource "null_resource" "federated_identity_credential" {
  triggers = {
    identity_name = azurerm_user_assigned_identity.tekton_workload_identity.name
    rg_name       = azurerm_user_assigned_identity.tekton_workload_identity.resource_group_name
    sa_namespace  = kubernetes_service_account.tekton_workload_identity.metadata[0].namespace
    sa_name       = kubernetes_service_account.tekton_workload_identity.metadata[0].name
    issuer        = azurerm_kubernetes_cluster.tekton.oidc_issuer_url
  }
  provisioner "local-exec" {
    command = <<EOT
      az identity federated-credential create \
        --name "tekton-workload-federated-credential" \
        --identity-name "${self.triggers.identity_name}" \
        --resource-group "${self.triggers.rg_name}" \
        --issuer "${self.triggers.issuer}" \
        --subject "system:serviceaccount:${self.triggers.sa_namespace}:${self.triggers.sa_name}"
    EOT
  }
}

# https://azure.github.io/azure-workload-identity/docs/quick-start.html#5-create-a-kubernetes-service-account 
resource "kubernetes_service_account" "tekton_workload_identity" {
  metadata {
    name      = "tekton-workload-identity"
    namespace = "tekton-pipelines"
    annotations = {
      "azure.workload.identity/client-id" = "${azurerm_user_assigned_identity.tekton_workload_identity.client_id}"
    }
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
  depends_on = [
    null_resource.kapp
  ]
}
