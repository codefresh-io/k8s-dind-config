#!/usr/bin/env bash

getRandomName() {
	declare -a words=("astra" "abby" "book" "bad" "bold" "camp" "call" "crack" "doom" "dog" "drill" "elf" "enter" "fake" "full" "form" "fun" "girl" "good" "goblin" "grand" "groom" "goose" "king" "kind" "loop" "lame" "lamer" "little" "lost" "moon" "monk" "mark" "noon" "nord" "odd" "oven" "plain" "pirate" "pitty" "pool" "pasta" "pretty" "room" "rast" "rock" "sun" "toon" "ten" "tik" "tape" "wild" "ugly" "urgent" "who") 

	echo ${words[$RANDOM % ${#words[@]}]}-${words[$RANDOM % ${#words[@]}]}
}

namespace=$(getRandomName)

cluster=$(getRandomName)

echo "Generated namespace  name: $namespace"
echo "Generated cluster name: $cluster"

echo "-----"
createNsCmd="kubectl create namespace $namespace"
echo "Running command: $createNsCmd"
eval $createNsCmd

echo "-----"
createClusterInCfCmd="codefresh create clusters --kube-context $KUBE_CONTEXT --name-overwrite $cluster --behind-firewall --namespace $namespace"
echo "Running command: $createClusterInCfCmd"
eval $createClusterInCfCmd


echo "-----"
createReInCfCmd="./codefresh-k8s-configure.sh --api-token $TOKEN --namespace $namespace --api-host $API_HOST --image-tag agent $cluster"
echo "Running command: $createReInCfCmd"
eval $createReInCfCmd
