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

POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)

cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF

sudo mkdir -p /etc/containerd/

cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo cp ca.pem /var/lib/kubernetes/
sudo mkdir -p /var/kubernetes/manifests

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: false
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: AlwaysAllow
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
staticPodPath: "/var/kubernetes/manifests"
EOF

HOSTNAME_OVERRIDE=$(curl -sS http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --network-plugin=cni \\
  \\
  --hostname-override=$HOSTNAME_OVERRIDE \\
  ${ENABLE_GCE:+--cloud-provider=gce} \\
  \\
  ${IS_WORKER:+--kubeconfig=/var/lib/kubelet/kubeconfig} \\
  ${IS_WORKER:+--register-node=true} \\
  \\
  --v=${DEBUG_LEVEL:-2}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

(
  set -x
  sudo systemctl daemon-reload
  sudo systemctl enable containerd kubelet
  sudo systemctl start containerd kubelet
)

systemctl status kubelet --no-pager -l

kubelet --version
exit 0