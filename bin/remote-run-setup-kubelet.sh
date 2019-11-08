#!/bin/bash

set -eu

MASTERS=${MASTERS:-1}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

i=0
while [ $i -lt $MASTERS ]; do
  instance=controller-$i
  (
  set -x
  gcloud compute scp \
    ca.pem \
    $DIR/setup-kubelet.sh \
    ${instance}:~/

  gcloud compute ssh ${instance} -- bash setup-kubelet.sh

  )
  ((i++))
done
