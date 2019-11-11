#!/bin/bash

set -eu

KUBERNETES_PUBLIC_ADDRESS=$(cat kube-apiserver-public-ip)

as_root() {
(
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

  kubeadm config images pull

  mkdir -p /etc/kubernetes/pki/
  cp *.{crt,key} /etc/kubernetes/pki/
)

if [[ "$HOSTNAME" == "controller-0" ]]; then
  echo "Configuring and starting apiserver and friends"
  (
    set -x
    kubeadm init \
      -v 5 \
      --ignore-preflight-errors=NumCPU,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,FileContent--proc-sys-net-ipv4-ip_forward \
      --upload-certs \
      --apiserver-cert-extra-sans=${KUBERNETES_PUBLIC_ADDRESS}

    export KUBECONFIG=/etc/kubernetes/admin.conf
    kubectl get nodes
  )
  echo "Collecting data required for other masters/workers to join cluster:"

  (
  set -x
  kubeadm token list | grep authentication | awk '{print $1}' > bootstrap-token-auth

  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
    openssl rsa -pubin -outform der 2>/dev/null | \
    openssl dgst -sha256 -hex | sed 's/^.* //' > \
      discovery-token-ca-cert-hash

  dig $HOSTNAME +short | head -n1 > controller-0-ip
  )
else
  (
  set -x
  kubeadm join "$(cat controller-0-ip):6443" \
    -v 5 \
    --ignore-preflight-errors=NumCPU,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,FileContent--proc-sys-net-ipv4-ip_forward \
    --token "$(cat bootstrap-token-auth)" \
    --discovery-token-ca-cert-hash "sha256:$(cat discovery-token-ca-cert-hash)"
  )
fi
}
# end as_root()

AS_ROOT=$(declare -f as_root)
sudo bash -c "$AS_ROOT; as_root"

[[ -f /etc/kubernetes/admin.conf ]] && {
  echo "Create local user kubeconfig:"
  (
  set -x
  sudo rm -rf $HOME/.kube
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  )
  kubectl get nodes
  kubectl get pods -n kube-system
}

exit 0