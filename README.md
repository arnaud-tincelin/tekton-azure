# Tekton test repo

This repository creates an AKS cluster & [tekton pipelines](https://tekton.dev/) to deploy [this repository](https://github.com/arnaud-tincelin/sampleapp).

The pipeline can be triggered using a kubectl command or using an HTTP trigger.

## Required tools

[Kustomize](https://kustomize.io/)
[Kapp](https://carvel.dev/kapp/)
[Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
[Terraform](https://www.terraform.io/downloads)

## Deploy the cluster

```bash
az login
terraform init
terraform apply --var=subscription_id="" -auto-approve
```

## Tekton dashboard

To access the dashboard, run:

```bash
kubectl --kubeconfig kubeconfig -n tekton-pipelines port-forward svc/tekton-dashboard 9097:9097
```

## Start a pipeline using a kubectl command

```bash
REPO_URL="https://github.com/arnaud-tincelin/sampleapp.git"
NAME="ati01"
SUBSCRIPTION_ID=""

kubectl create -f <(
cat <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: kubectl-run-
  namespace: tekton-pipelines
spec:
  serviceAccountName: tekton-workload-identity
  pipelineRef:
    name: deploy-func-app
  podTemplate:
    securityContext:
      fsGroup: 65532
  workspaces:
  - name: shared-data
    volumeClaimTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
  params:
  - name: repo-url
    value: ${REPO_URL}
  - name: name
    value: ${NAME}
  - name: subscription_id
    value: ${SUBSCRIPTION_ID}
EOF
)
```

## Trigger a pipeline using curl

```bash
REPO_URL="https://github.com/arnaud-tincelin/sampleapp.git"
NAME="ati02"
SUBSCRIPTION_ID=""
CLUSTER_ADDRESS="http://$(kubectl -n tekton-pipelines get ing func-app-listener-ingress -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')"

data=$(
  cat <<EOF
{
  "name": "${NAME}",
  "repo_url": "${REPO_URL}",
  "subscription_id": "${SUBSCRIPTION_ID}"
}
EOF
)

curl -v \
  -H 'content-Type: application/json' \
  -d "${data}" \
  ${CLUSTER_ADDRESS}
```

## References

[Kubernetes Workload Identity](https://azure.github.io/azure-workload-identity/docs/introduction.html)
[Terraform AzureRM with OIDC](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc#configuring-the-service-principal-in-terraform)
[Tekton Quick Start](https://azure.github.io/azure-workload-identity/docs/quick-start.html)
