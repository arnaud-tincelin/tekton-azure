data "azurerm_client_config" "current" {}

resource "local_file" "patch_azure_workload_identity" {
  filename = "patch-azure-workload-identity.yaml"
  content  = <<EOT
- op: replace
  path: /data/AZURE_TENANT_ID
  value: ${data.azurerm_client_config.current.tenant_id}
EOT
}

resource "null_resource" "kapp" {
  triggers = {
    app        = "stack"
    timestamp  = timestamp() # Always execute this as we can't know if kube files have changed
    kubeconfig = local.kubeconfig_path
  }
  provisioner "local-exec" {
    command     = "kapp --kubeconfig ${self.triggers.kubeconfig} --yes deploy --wait=false --app ${self.triggers.app} -f <(kustomize build)"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [
    local_file.patch_azure_workload_identity,
  ]
}
