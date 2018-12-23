#!/usr/bin/env bash

getRandomName() {
	declare -a words=("astra" "abby" "book" "bad" "bold" "camp" "call" "crack" "doom" "dog" "drill" "elf" "enter" "fake" "full" "form" "fun" "girl" "good" "goblin" "grand" "groom" "goose" "king" "kind" "loop" "lame" "lamer" "little" "lost" "moon" "monk" "mark" "noon" "nord" "odd" "oven" "plain" "pirate" "pitty" "pool" "pasta" "pretty" "room" "rast" "rock" "sun" "toon" "ten" "tik" "tape" "wild" "ugly" "urgent" "who") 

	echo ${words[$RANDOM % ${#words[@]}]}-${words[$RANDOM % ${#words[@]}]}
}

name=$(getRandomName)

echo "Generated name: $name"

echo "-----"
createNsCmd="kubectl create namespace $name"
echo "Running command: $createNsCmd"
eval $createNsCmd

echo "-----"
createClusterInCfCmd="codefresh create clusters --kube-context $KUBE_CONTEXT --name-overwrite $name --behind-firewall --namespace $name"
echo "Running command: $createClusterInCfCmd"
eval $createClusterInCfCmd


echo "-----"
createReInCfCmd="./codefresh-k8s-configure.sh --api-token 5bfe9cae7dbaec0100df3bc9.ed452bf263f6282cb372fbd2d5068954 --namespace $name --api-host $API_HOST --image-tag agent $name_overwrite"
echo "Running command: $createReInCfCmd"
eval $createReInCfCmd

