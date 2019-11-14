# Kubernetes the Kubernetes Way

* debian packages
* kubeadm
* systemd
* GCE
* single controller/master, with many workers
* multiple controller/masters, with many workers
* different names/sets of certificates/private keys


## Examples

Default 1 controller, 2 workers:

```plain
$ bootstrap-ktkw
...
$ kubectl get nodes,pods --all-namespaces
NAME                STATUS   ROLES    AGE     VERSION   INTERNAL-IP   EXTERNAL-IP      OS-IMAGE             KERNEL-VERSION   CONTAINER-RUNTIME
node/controller-0   Ready    master   4m21s   v1.16.3   10.240.0.10   35.230.85.80     Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/worker-0       Ready    <none>   2m      v1.16.3   10.240.0.20   35.227.139.140   Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/worker-1       Ready    <none>   7s      v1.16.3   10.240.0.21   34.82.228.203    Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10

NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE     IP            NODE           NOMINATED NODE   READINESS GATES
kube-system   pod/coredns-5644d7b6d9-8h7kg               1/1     Running   0          4m3s    10.22.0.2     controller-0   <none>           <none>
kube-system   pod/coredns-5644d7b6d9-9hm5t               1/1     Running   0          4m3s    10.22.0.3     controller-0   <none>           <none>
kube-system   pod/etcd-controller-0                      1/1     Running   0          3m11s   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-apiserver-controller-0            1/1     Running   0          3m21s   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-controller-manager-controller-0   1/1     Running   0          3m7s    10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-dvrs6            1/1     Running   0          7s      10.240.0.21   worker-1       <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-n64mm            1/1     Running   0          2m      10.240.0.20   worker-0       <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-rz7f2            1/1     Running   0          4m3s    10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-proxy-kz8g4                       1/1     Running   0          4m3s    10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-proxy-t4mvk                       1/1     Running   0          2m      10.240.0.20   worker-0       <none>           <none>
kube-system   pod/kube-proxy-xqpwp                       1/1     Running   0          7s      10.240.0.21   worker-1       <none>           <none>
```

3 controllers, 3 workers:

```plain
$ MASTERS=3 WORKERS=3 bootstrap-ktkw
...
$ kubectl get nodes,pods --all-namespaces
NAME                STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP       OS-IMAGE             KERNEL-VERSION   CONTAINER-RUNTIME
node/controller-0   Ready    master   26m   v1.16.3   10.240.0.10   35.227.139.140    Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/controller-1   Ready    master   23m   v1.16.3   10.240.0.11   35.230.85.80      Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/controller-2   Ready    master   21m   v1.16.3   10.240.0.12   104.196.241.199   Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/worker-0       Ready    <none>   19m   v1.16.3   10.240.0.20   34.82.228.203     Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/worker-1       Ready    <none>   17m   v1.16.3   10.240.0.21   34.82.91.107      Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/worker-2       Ready    <none>   15m   v1.16.3   10.240.0.22   35.233.134.26     Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10

NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE   IP            NODE           NOMINATED NODE   READINESS GATES
kube-system   pod/coredns-5644d7b6d9-cmk9k               1/1     Running   0          25m   10.244.0.3    controller-0   <none>           <none>
kube-system   pod/coredns-5644d7b6d9-xbql2               1/1     Running   0          25m   10.244.0.2    controller-0   <none>           <none>
kube-system   pod/etcd-controller-0                      1/1     Running   0          25m   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/etcd-controller-1                      1/1     Running   0          23m   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/etcd-controller-2                      1/1     Running   0          21m   10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-apiserver-controller-0            1/1     Running   0          25m   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-apiserver-controller-1            1/1     Running   1          23m   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-apiserver-controller-2            1/1     Running   0          21m   10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-controller-manager-controller-0   1/1     Running   1          24m   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-controller-manager-controller-1   1/1     Running   0          22m   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-controller-manager-controller-2   1/1     Running   0          21m   10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-5xt7c            1/1     Running   0          21m   10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-8qfg6            1/1     Running   0          19m   10.240.0.20   worker-0       <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-dlccw            1/1     Running   0          15m   10.240.0.22   worker-2       <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-jxhst            1/1     Running   1          23m   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-k5jfs            1/1     Running   0          17m   10.240.0.21   worker-1       <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-sxvbk            1/1     Running   0          25m   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-proxy-6b2pn                       1/1     Running   0          17m   10.240.0.21   worker-1       <none>           <none>
kube-system   pod/kube-proxy-8r6ft                       1/1     Running   0          15m   10.240.0.22   worker-2       <none>           <none>
kube-system   pod/kube-proxy-bhn4g                       1/1     Running   0          25m   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-proxy-cnmmh                       1/1     Running   0          23m   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-proxy-gwwcv                       1/1     Running   0          19m   10.240.0.20   worker-0       <none>           <none>
kube-system   pod/kube-proxy-hwzbl                       1/1     Running   0          21m   10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-scheduler-controller-0            1/1     Running   1          25m   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-scheduler-controller-1            1/1     Running   0          22m   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-scheduler-controller-2            1/1     Running   0          21m   10.240.0.12   controller-2   <none>           <none>
```

## Cleanup

To delete the instances and all GCE networking:

```plain
destroy-ktkw
```
