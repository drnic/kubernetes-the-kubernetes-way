# Differences from Kubernetes The Hard Way

The Kubernetes documentation for running Kubernetes differs from Kelsey's KTHW labs in many areas. In this chapter, I will attempt to itemise them, and comment on how and why they are different.

## Kubelet for Controllers and Workers

In KTHW we ran `etcd`, `kube-apiserver`, `kube-controller-manager`, and `kube-scheduler` CLIs as systemd-managed services on each of the controller instances.

The Kubernetes Documentation, and the `kubeadm` tool, recommend running them as static pods managed by a kubelet.

That is, our controller instances will have a kubelet running on them, like our worker instances. The controller instances' kubelet will each be standalone kubelets whose purpose is to run etcd, apiserver, controller manager, scheduler, and coredns as static pods.

One benefit of running services as static pods is we can later inspect them from `kubectl` and the Kubernetes API. Processes running via systemd are not viewable, nor are their logs inspectable, via Kubernetes itself.

The worker instances' kubelets will be similar to KTHW: they will register with the apiserver as worker nodes for end-user pods.

On the worker instances we will also run kube-proxy as a static pod rather than as a systemd-managed service.

As such, we need to download the `kubelet` CLI to both controller and worker instances, but do not need to download etcd, kube-apiserver, kube-controller-manager, kube-scheduler, nor kube-proxy CLIs. Instead, we will download these CLIs packaged as containerd-runnable images known as Open Container Images (OCIs), or Docker Images.

## Debian packages

The instructions for using `kubeadm` assume that `kubelet` has been downloaded and installed via an distribution package.

The `kubelet` package will:

* place the `kubelet` binary into the `$PATH` so it is immediately runnable
* create systemd configuration files

It does not configure nor start our kubelets. Instead `kubeadm init` and `kubeadm join` commands will configure the local kubelet, and then start the kubelet process via systemd.

Whilst we're using packages for the `kubelet`, we might as well use packages for `kubectl`, `kubeadm`, and `containerd` as well.

The `containerd` package is handy in that it will setup some default bridge network configuration files.

TODO: check what network configuration files are created.

## Kubeadm CLI will configure Kubernetes components

The `kubeadm` CLI is formerly part of the [Kubernetes source code](https://github.com/kubernetes/kubernetes/tree/master/cmd/kubeadm) project. As KTHW shows, using `kubeadm` is optional to running Kubernetes yourself. Kubernetes is just some software than needs somewhere to run.

In this tutorial we will use `kubeadm` to learn more about what it can do for us. Then you can decide to use it or not for yourself.

We will use `kubeadm init` to initialize the first controller instance, and `kubeadm join` to add worker nodes.

Later we use `kubeadm join --control-plane` to add more controller nodes for a high-availability control plane with multiple controller instances (running a high-availability etcd cluster).

## Enable GCE cloud provider

KTHW assumed you were deploying Kubernetes to Google Compute Engine (GCE), but it did not enable the GCE cloud provider for your Kubernetes cluster (pending [pull request](https://github.com/kelseyhightower/kubernetes-the-hard-way/pull/502)). This sadly meant that `LoadBalancer` services did not result in a [GCE load balancer](https://cloud.google.com/compute/docs/load-balancing-and-autoscaling), and `PersistentVolumeClaims` did not result in [GCE disks](https://cloud.google.com/compute/docs/disks/).

We will enable the GCE cloud provider as it will both give us the benefits of GCE integration with our Kubernetes.

This will also force us to move away from `kubeadm` CLI flags and to learn the `kubeadm` configuration file format. That is, it is an excuse to learn more about `kubeadm`.

## Allow kubeadm to generate certificates

In KTHW we used `cfssl` and `cfssljson` to generate a root certificate authority (CA) certificate and key; to generate server certificate/key pairs for etcd, apiserver, and kubelets; and generate client certificate/key pairs for the clients to the apiserver.

You now know how to do this yourself. So in this tutorial we will allow `kubeadm` to generate many of our certificates for us.

### TLS bootstrapping

We will only generate a shared root CA certificate/key pair, and a private/public key pair for service acccounts. These will only be uploaded to each controller instance.

Worker instances will use Kubernetes [TLS bootstrapping](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping/) to request client certificates be created for them.

## Software networking between pods

> Each worker instance requires a pod subnet allocation from the Kubernetes cluster CIDR range. -- KTHW [Kubernetes Workers section](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#kubernetes-workers)

In KTHW we manually allocated IP addresses to each controller and worker instance, and then we manually allocated IP ranges that each worker instance could use for its pods' "internal" IP addresses.

For example, worker-0 was given an IP of 10.240.0.20, and told it should only use CIDR 10.200.0.0/24 when allocating IPs to its pods. This would grant IP addresses from 10.200.0.0 to 10.200.0.255 (though first and last IPs may be reserved). NOTE: whilst we have 200+ IP addresses for pods in a /24 CIDR, it is recommended you limit the number of pods to half this number to mitigate IP address reuse as Pods are added to and removed from a node.

In KTHW, the allocated CIDR was used in configuration for [CNI networking](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md#configure-cni-networking), and configuring the [worker kubelet](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md#configure-the-kubelet).

Finally, in KTHW we asked [GCE to create routing](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/11-pod-network-routes.md) from the pod 10.200.X.Y IPs to their host worker instance 10.244.0.Z IPs.

With kubeadm you can continue to explicitly assign CIDRs to each worker kubelet, and use GCE routing. I've not yet tried it -- but I assume you pass the pod CIDR into `JoinConfiguration`'s `nodeRegistration.kubeletExtraArgs` field. I was going to say it wasn't possible (via `kubeadm` CLI flags) but its probably possible. We'll look at `JoinConfiguration` configuration files later.

Instead we will switch from GCE routing to software networking, and will try using `flannel` to allow intercommunication between pods.

## Allow API traffic via Public IP

It is a nuance to be sure -- in KTHW each controller manager and scheduler on connected to the apiserver that was collocated on their same instance.

We will use a public IP for all communication from internal components into the Kubernetes API (kube-apiserver).
