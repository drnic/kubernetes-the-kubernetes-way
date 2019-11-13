#!/bin/bash

set -eu

as_root() {
  set -eu
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
)

# control-plane/controllers need ca.crt/ca.key
cp *.{crt,key} /etc/kubernetes/pki/

if [[ "$HOSTNAME" == "controller-0" ]]; then
  echo "Configuring and starting apiserver and friends"
  (
    cat >kubeadm.yaml <<EOF
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
controlPlaneEndpoint: "$(cat kube-apiserver-public-ip):6443"
networking:
  podSubnet: "10.244.0.0/16"
apiServer:
  extraArgs:
    cloud-provider: gce
controllerManager:
  extraArgs:
    cloud-provider: gce
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: gce
EOF
# apiserver-cert-extra-sans pod-network-cidr
    set -x
    kubeadm init \
      -v 5 \
      --config=kubeadm.yaml \
      --ignore-preflight-errors=NumCPU,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,FileContent--proc-sys-net-ipv4-ip_forward \
      --upload-certs

    export KUBECONFIG=/etc/kubernetes/admin.conf
    kubectl get nodes

  )
  echo "Installing flannel networking"
  # flannel networking, cni version 0.3.1, network 10.244.0.0/16
  (
    set -x
    export KUBECONFIG=/etc/kubernetes/admin.conf
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/960b3243b9a7faccdfe7b3c09097105e68030ea7/Documentation/kube-flannel.yml
  )

  echo "Collecting data required for other masters/workers to join cluster:"
  (
  set -x
  kubeadm token list | grep authentication | awk '{print $1}' > bootstrap-token-auth

  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
    openssl rsa -pubin -outform der 2>/dev/null | \
    openssl dgst -sha256 -hex | sed 's/^.* //' > \
      discovery-token-ca-cert-hash
  )

  echo "Setup nginx for HTTPS /healthz checks"
  apt-get install nginx -y

  cat > /etc/nginx/sites-available/kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
  ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/ || echo skipping...

  systemctl restart nginx
  systemctl enable nginx

  curl localhost/healthz -H 'Host: kubernetes.default.svc.cluster.local'
else
  # other controllers and workers
  (
    [[ $HOSTNAME =~ ^controller ]] && { export control_plane=1; }
    cat >kubeadm.yaml <<EOF
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: $(cat kube-apiserver-public-ip):6443
    token: $(cat bootstrap-token-auth)
    caCertHashes:
    - sha256:$(cat discovery-token-ca-cert-hash)
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: gce
${control_plane:+controlPlane: {}}
EOF

  set -x
  kubeadm join \
    -v 5 \
    --config=kubeadm.yaml \
    --ignore-preflight-errors=NumCPU,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,FileContent--proc-sys-net-ipv4-ip_forward \
  )
fi
}
# end as_root()

AS_ROOT=$(declare -f as_root)
sudo bash -c "$AS_ROOT; as_root"

echo

[[ -f /etc/kubernetes/admin.conf ]] && {
  echo "Create local user admin kubeconfig:"
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