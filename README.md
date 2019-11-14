# Kubernetes the Kubernetes Way

* debian packages
* kubeadm
* systemd
* GCE
* single controller/master, with many workers
* multiple controller/masters, with many workers
* different names/sets of certificates/private keys


## Examples

3 controllers, 3 workers

```plain
$ MASTERS=3 WORKERS=3 bootstrap-ktkw
...
$ kubectl get nodes,pods --all-namespaces
NAME                STATUS   ROLES    AGE     VERSION   INTERNAL-IP   EXTERNAL-IP       OS-IMAGE             KERNEL-VERSION   CONTAINER-RUNTIME
node/controller-0   Ready    master   11m     v1.16.3   10.240.0.10   35.233.134.26     Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/controller-1   Ready    master   8m51s   v1.16.3   10.240.0.11   104.196.241.199   Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/controller-2   Ready    master   6m6s    v1.16.3   10.240.0.12   35.227.139.140    Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/worker-0       Ready    <none>   3m49s   v1.16.3   10.240.0.20   34.82.228.203     Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/worker-1       Ready    <none>   119s    v1.16.3   10.240.0.21   34.82.91.107      Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10
node/worker-2       Ready    <none>   11s     v1.16.3   10.240.0.22   35.230.85.80      Ubuntu 18.04.3 LTS   5.0.0-1025-gcp   containerd://1.2.10

NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE     IP            NODE           NOMINATED NODE   READINESS GATES
kube-system   pod/coredns-5644d7b6d9-4mjz8               1/1     Running   0          4m58s   10.244.2.2    controller-2   <none>           <none>
kube-system   pod/coredns-5644d7b6d9-8qt8p               1/1     Running   0          87s     10.244.4.2    worker-1       <none>           <none>
kube-system   pod/coredns-5644d7b6d9-tzdb6               1/1     Running   0          10m     10.22.0.2     controller-0   <none>           <none>
kube-system   pod/etcd-controller-0                      1/1     Running   0          9m56s   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/etcd-controller-1                      1/1     Running   0          8m50s   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/etcd-controller-2                      1/1     Running   0          6m6s    10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-apiserver-controller-0            1/1     Running   0          10m     10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-apiserver-controller-1            1/1     Running   1          8m40s   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-apiserver-controller-2            1/1     Running   0          4m53s   10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-controller-manager-controller-0   1/1     Running   1          9m57s   10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-controller-manager-controller-1   1/1     Running   0          7m42s   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-controller-manager-controller-2   1/1     Running   0          5m11s   10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-22jl4            1/1     Running   0          118s    10.240.0.21   worker-1       <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-8q2rn            1/1     Running   0          11s     10.240.0.22   worker-2       <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-fp854            1/1     Running   1          8m51s   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-ldgtw            1/1     Running   0          10m     10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-tqx2x            1/1     Running   0          6m6s    10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-flannel-ds-amd64-tx96q            1/1     Running   0          3m49s   10.240.0.20   worker-0       <none>           <none>
kube-system   pod/kube-proxy-5225f                       1/1     Running   0          11s     10.240.0.22   worker-2       <none>           <none>
kube-system   pod/kube-proxy-b44q4                       1/1     Running   0          3m49s   10.240.0.20   worker-0       <none>           <none>
kube-system   pod/kube-proxy-bnx7v                       1/1     Running   0          8m51s   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-proxy-g5j2r                       1/1     Running   0          10m     10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-proxy-gmw96                       1/1     Running   0          6m6s    10.240.0.12   controller-2   <none>           <none>
kube-system   pod/kube-proxy-pqc7s                       1/1     Running   0          118s    10.240.0.21   worker-1       <none>           <none>
kube-system   pod/kube-scheduler-controller-0            1/1     Running   1          10m     10.240.0.10   controller-0   <none>           <none>
kube-system   pod/kube-scheduler-controller-1            1/1     Running   0          7m34s   10.240.0.11   controller-1   <none>           <none>
kube-system   pod/kube-scheduler-controller-2            1/1     Running   0          4m54s   10.240.0.12   controller-2   <none>           <none>
```

## Cleanup

To delete the instances and all GCE networking:

```plain
destroy-ktkw
```
