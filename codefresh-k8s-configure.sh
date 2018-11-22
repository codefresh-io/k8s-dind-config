#!/usr/bin/env bash
#
#---
echo -e "The script configures your Kubernetes cluster namespace to run codefresh.io builds \n\
Please ensure:
  - Kubernetes version is 1.6 or newer, kubectl is installed and confired to your cluster
  - service account of the namespace should have write permisions for services, pods, configmaps, secrets - see rbac.yaml
  - You have Codefresh API Access Token - see https://g.codefresh.io/api/
  - The cluster is registred in Codefresh - see https://docs.codefresh.io/v1.0/docs/codefresh-kubernetes-integration-beta#section-add-a-kubernetes-cluster
  - Your codefresh account enabled for CustomKubernetesCluster feature"

# Environment
API_HOST="https://g.codefresh.io"
DEFAULT_NAMESPACE=codefresh
FORCE=

fatal() {
   echo "ERROR: $1"
   exit 1
}

usage() {
  echo "Usage:
  $0 [ options ] cluster_name

  options:
  --api-token <codefresh api token> - default \$API_TOKEN
  --namespace <kubernetes namespace> - default codefresh
  --context <kubectl context>
  --image-tag <codefresh/k8s-dind-config image tag - default latest>

  "
}

[[ $# == 0 || $1 == "-h" ]] && usage && exit 0

set -e


while [[ $1 =~ ^(--(api-host|api-token|registry-token|namespace|context|image-tag|force)) ]]
do
  key=$1
  value=$2

  case $key in
    -h)
      usage
      exit 0
      ;;
    --force)
      FORCE="true"
      ;;
    --api-host)
      API_HOST=$value
      shift
      ;;
    --api-token)
      API_TOKEN=$value
      shift
      ;;
    --registry-token)
      REGISTRY_TOKEN=$value
      shift
      ;;
    --context)
      KUBECONTEXT=$value
      shift
      ;;
    --namespace)
      NAMESPACE=$value
      shift
      ;;
    --image-tag)
      IMAGE_TAG="$value"
      shift
      ;;
  esac
  shift
done

CLUSTER_NAME="${1}"
[[ -z ${CLUSTER_NAME} ]] && usage && exit 1

if [[ -z "$FORCE" ]]; then
    if [[ -z ${API_HOST} ]]; then
       echo "Enter Codefresh Address: ( example: https://g.codefresh.io ) "
       read -r -p "    " API_HOST
    fi
    [[ -z "${API_HOST}" ]] && fatal "API_HOST is not set"

    if [[ -z ${API_TOKEN} ]]; then
       echo "Enter Codefresh API token: (see ${API_HOST}/api ) "
       read -r -p "    " API_TOKEN
    fi

fi

if [[ -z "${API_TOKEN}" || -z "${CLUSTER_NAME}" ]]; then
  usage
  exit 1
fi


which kubectl || fatal kubectl not found

if [[ -z "${KUBECONTEXT}" ]]; then
  KUBECONTEXT=$(kubectl config current-context)
fi

## Checking if namespace exists
if [[ -z "${NAMESPACE}" ]]; then
  NAMESPACE="${DEFAULT_NAMESPACE}"
fi
if ! kubectl --context ${KUBECONTEXT} get namespace ${NAMESPACE} >&- ; then
  fatal namespace ${NAMESPACE} does not exist
fi

KUBECTL_OPTIONS="$KUBECTL_OPTIONS --context ${KUBECONTEXT} --namespace=${NAMESPACE}"

echo -e "\n--------------\n  Printing kubectl contexts:"
kubectl config get-contexts

KUBECTL="kubectl $KUBECTL_OPTIONS "

POD_NAME=codefresh-configure-$(date '+%Y-%m-%d-%H%M%S')
TMP_DIR=${TMPDIR:-/tmp}/codefresh
mkdir -p "${TMP_DIR}"
POD_DEF_FILE=${TMP_DIR}/${POD_NAME}-pod.yaml

cat <<EOF >${POD_DEF_FILE}
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
      - name: SLEEP_ON_ERROR
        value: "${SLEEP_ON_ERROR}"
EOF

echo -e "\n--------------\n  Printing kubectl contexts:"
kubectl config get-contexts

echo -e "\n--------------\n  Codefresh Configuration Pod:"
cat ${POD_DEF_FILE}

echo -e "\nWe are going to submit Codefresh Configuration Pod using:
   $KUBECTL apply -f <codefresh-config-pod>"

if [[ -z "$FORCE" ]]; then
    read -r -p "Would you like to continue? [Y/n]: " CONTINUE
    CONTINUE=${CONTINUE,,} # tolower
    if [[ ! $CONTINUE =~ ^(yes|y) ]]; then
      echo "Exiting ..."
      exit 0
    fi
fi

KUBECTL_COMMAND="$KUBECTL apply -f ${POD_DEF_FILE}"
echo $KUBECTL_COMMAND

eval $KUBECTL_COMMAND

$KUBECTL get pod $POD_NAME -a -owide