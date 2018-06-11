### Configure K8s for Codefresh builds

The script configures your Kubernetes cluster namespace to run codefresh.io builds 
Please ensure:
  - Kubernetes version is 1.6 or newer, kubectl is installed and confired to your cluster
  - For RBAC enabled clusters service-account of the namespace should have write permisions for "services","pods","configmaps","secrets" - see rbac.yaml
  - You have Codefresh API Access Token - see https://g.codefresh.io/api/
  - The cluster is registred in Codefresh - see https://codefresh.io/docs/docs/deploy-to-kubernetes/adding-non-gke-kubernetes-cluster/
  - You
  
Simplest way to create codefresh namespace with required permissions:
```
kubectl create namespace codefresh
kubectl apply -f rbac.yaml
```

Usage:
```sh
  ./codefresh-k8s-configure.sh [ options ] cluster_name

  options:
  --api-token <codefresh api token> - default $API_TOKEN
  --namespace <kubernetes namespace> - default codefresh
  --context <kubectl context>
  --image-tag <codefresh/k8s-dind-config image tag - default latest>
```
  
It will submit pod with codefresh-configure-$(date '+%Y-%m-%d-%H%M%S'):

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  annotations:
    forceRedeployUniqId: "N/A"
  labels:
    app: codefresh-config
spec:
  restartPolicy: Never
  containers:
  - image: codefresh/k8s-dind-config:${IMAGE_TAG:-latest}
    name: k8s-dind-config
    imagePullPolicy: Always
    command:
      - "/app/k8s-dind-config"
    env:
      - name: NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
      - name: API_HOST
        value: "${API_HOST}"
      - name: API_TOKEN
        value: "${API_TOKEN}"
      - name: REGISTRY_TOKEN
        value: "${REGISTRY_TOKEN}"
      - name: CLUSTER_NAME
        value: "${CLUSTER_NAME}"
```
