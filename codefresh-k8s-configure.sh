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
REMOTE=

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
  --remote <set if we want to download the files from git repository - default false>
  "
}

[[ $# == 0 || $1 == "-h" ]] && usage && exit 0

set -e

DIR=$(dirname $0)
REPO_URL="https://api.github.com/codefresh-io/k8s-dind-config"

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
    --remote)
      REMOTE="true"
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

if [[ "${REMOTE}" ]]; then
  curl ${REPO_URL}/pod.yaml.tmpl > ${DIR}/pod.yaml.tmpl
  curl ${REPO_URL}/rbac.yaml > ${DIR}/rbac.yaml
  curl ${REPO_URL}/template.sh > ${DIR}/template.sh
fi

POD_TEMPLATE_FILE=${DIR}/pod.yaml.tmpl
RBAC_FILE=${DIR}/rbac.yaml
TEMPLATE_FILE=${DIR}/template.sh


which kubectl || fatal kubectl not found

if [[ -z "${KUBECONTEXT}" ]]; then
  KUBECONTEXT=$(kubectl config current-context)
fi

## Checking if namespace exists
if [[ -z "${NAMESPACE}" ]]; then
  NAMESPACE="${DEFAULT_NAMESPACE}"
fi


KUBECTL_OPTIONS="$KUBECTL_OPTIONS --context ${KUBECONTEXT} --namespace=${NAMESPACE}"

echo -e "\n--------------\n  Printing kubectl contexts:"
kubectl config get-contexts

KUBECTL="kubectl $KUBECTL_OPTIONS "


POD_NAME=codefresh-configure-$(date '+%Y-%m-%d-%H%M%S')
TMP_DIR=${TMPDIR:-/tmp}/codefresh
mkdir -p "${TMP_DIR}"
POD_DEF_FILE=${TMP_DIR}/${POD_NAME}-pod.yaml

IMAGE_TAG=${IMAGE_TAG:-latest} API_HOST=${API_HOST} API_TOKEN=${API_TOKEN} CLUSTER_NAME=${CLUSTER_NAME} \
${TEMPLATE_FILE} ${POD_TEMPLATE_FILE} > ${POD_DEF_FILE}

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

if ! kubectl --context ${KUBECONTEXT} get namespace ${NAMESPACE} >&- ; then
  echo -e "\n--------------\n  Create namespace:"
  kubectl --context ${KUBECONTEXT} create namespace ${NAMESPACE}
fi

echo -e "\n--------------\n  Set required permissions:"
$KUBECTL apply -f ${RBAC_FILE}

KUBECTL_COMMAND="$KUBECTL apply -f ${POD_DEF_FILE}"
echo $KUBECTL_COMMAND

eval $KUBECTL_COMMAND

$KUBECTL get pod $POD_NAME -a -owide
