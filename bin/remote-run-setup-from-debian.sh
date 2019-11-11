#!/bin/bash

set -eu

MASTERS=${MASTERS:-1}
REGION=$(gcloud config get-value compute/region)

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-kubernetes-way \
  --region "$REGION" \
  --format 'value(address)')

i=0
while [ $i -lt $MASTERS ]; do
  instance=controller-$i
  (
  set -x
  gcloud compute scp \
    $DIR/setup-from-debian.sh \
    ${instance}:~/

  gcloud compute ssh ${instance} -- ./setup-from-debian.sh --public-ip "$KUBERNETES_PUBLIC_ADDRESS"

  )
  ((i++))
done
