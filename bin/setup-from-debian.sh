#!/bin/bash

set -eu

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --public-ip)
      shift
      export KUBERNETES_PUBLIC_ADDRESS=$1
      ;;
  esac
  shift
done

as_root() {
set -x

### Install packages to allow apt to use a repository over HTTPS
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

### Add Docker apt repository.
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update

## Install containerd
apt-get install -y containerd.io kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Configure containerd
mkdir -p /etc/containerd /etc/cni/net.d
containerd config default > /etc/containerd/config.toml

cat >/etc/cni/net.d/10-mynet.conf <<EOF
{
	"cniVersion": "0.3.1",
	"name": "mynet",
	"type": "bridge",
	"bridge": "cni0",
	"isGateway": true,
	"ipMasq": true,
	"ipam": {
		"type": "host-local",
		"subnet": "10.22.0.0/16",
		"routes": [
			{ "dst": "0.0.0.0/0" }
		]
	}
}
EOF

cat >/etc/cni/net.d/99-loopback.conf <<EOF
{
	"cniVersion": "0.3.1",
	"name": "lo",
	"type": "loopback"
}
EOF

# Restart containerd
systemctl restart containerd
sleep 3
journalctl -t containerd -l --no-pager


(
  set -x
  kubeadm config images pull

  cp *.{crt,pem,key} /etc/kubernetes/pki/

  # TODO - only 'init' for 'controller-0'
  kubeadm init \
    -v 5 \
    --ignore-preflight-errors=NumCPU,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,FileContent--proc-sys-net-ipv4-ip_forward \
    --upload-certs \
    ${KUBERNETES_PUBLIC_ADDRESS:+--apiserver-cert-extra-sans=${KUBERNETES_PUBLIC_ADDRESS:-}}
)

}
# end as_root()

AS_ROOT=$(declare -f as_root)
sudo bash -c "$AS_ROOT; as_root"
