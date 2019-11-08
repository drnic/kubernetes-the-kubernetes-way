#!/bin/bash

set -eu

KUBE_VERSION=${KUBE_VERSION:-1.16.2}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[[ -f /usr/local/bin/kubelet && "$(kubelet --version)" == "Kubernetes v${KUBE_VERSION}" ]] || {
(
  set -x
  sudo apt-get update
  sudo apt-get -y install socat conntrack ipset

  sudo swapoff -a

  rm -rf crictl* runc* cni-plugins* containerd*

  wget -q --show-progress --https-only --timestamping \
    https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.16.1/crictl-v1.16.1-linux-amd64.tar.gz \
    https://github.com/opencontainers/runc/releases/download/v1.0.0-rc9/runc.amd64 \
    https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz \
    https://github.com/containerd/containerd/releases/download/v1.3.0/containerd-1.3.0.linux-amd64.tar.gz \
    https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl \
    https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubelet

  sudo mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes

  mkdir containerd
  tar -xvf crictl-*-linux-amd64.tar.gz
  tar -xvf containerd-*.linux-amd64.tar.gz -C containerd
  sudo tar -xvf cni-plugins-linux-amd64-*.tgz -C /opt/cni/bin/
  sudo mv runc.amd64 runc
  chmod +x crictl kubectl kubelet runc
  sudo mv crictl kubectl kubelet runc /usr/local/bin/
  sudo mv containerd/bin/* /bin/
)
}

kubelet --version
