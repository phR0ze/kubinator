# Kubinator
***Kubinator*** provides deployment automation for Kubernetes

<img align="left" width="48" height="48" src="https://github.com/phR0ze/cyberlinux/blob/master/art/logo_256x256.png">
<b><i>Kubinator</i></b> is a <a href="https://github.com/phR0ze/cyberlinux">cyberlinux</a> backed project leveraging the pre-packed
<a href="https://app.vagrantup.com/phR0ze/boxes/cyberlinux-k8snode">cyberlinux Vagrant box</a> to
quickly deploy a configurable number of Vagrant Virtual Machines as a Kubernetes cluster in <b><i>under 8 minutes</i></b>

time results: `real	7m27.789s, user 0m35.066s, sys 0m24.183s`

***Kubinator*** can quickly deploy a K8s cluster with customizable VMs, manage vm snapshots and
automate cluster customizations all from a single simple command line.

[![Build Status](https://travis-ci.org/phR0ze/kubinator.svg)](https://travis-ci.org/phR0ze/kubinator)

## Do it!

Deploy distro dependencies:
* [Deploy on cyberlinux](#deploy-on-cyberlinux)
* [Deploy on Arch Linux](#deploy-on-arch-linux)
* [Deploy on Ubuntu](#deploy-on-ubuntu)

One liner to deploy your new shiny Kubernetes 1.11.2 cluster:
```bash
./kubinator deploy cluster all
```

[![Kubinator Demo](doc/images/kubinator-demo.jpg)](doc/videos/kubinator-demo-2018-08-15_19.29.41.mkv)

## Disclaimer
***kubinator*** comes with absolutely no guarantees or support of any kind. It is to be used at
your own risk.  Any damages, issues, losses or problems caused by the use of ***kubinator*** are
strictly the responsiblity of the user and not the developer/creator of ***kubinator***.

### Table of Contents
* [Kubinator Overview](#kubinator-overview)
  * [Kubeadm](#kubeadm)
  * [CNI Plugins](#cni-plugins)
* [Deploy Kubinator](#deploy-kubinator)
  * [Deploy on cyberlinux](#deploy-on-cyberlinux)
  * [Deploy on Arch Linux](#deploy-on-arch-linux)
  * [Deploy on Ubuntu](#deploy-on-ubuntu)
* [Deploy Kubernetes](#deploy-kubernetes)
  * [Vagrant Node Access](#vagrant-node-access)
* [Troubleshooting](#trouble-shooting)
  * [kubeadm config](#kubeadm-config)
  * [Networking Validation](#networking-validation)
  * [Cross Node Connectivity Fails](#cross-node-connectivity-fails)
  * [DNS Not Resolving](#dns-not-resolving)

## Kubinator Overview <a name="kubinator-overview"/></a>
***Kubinator*** uses Ruby to automate the management/orchestration of the Virtual Machines backing
the Kubernetes cluster. ***Kubinator*** orchestrates [Vagrant](https://www.vagrantup.com/intro/index.html)
to then in turn pull the strings of [VirtualBox](https://www.virtualbox.org/). Kubinator is able to
get a new Kubernetes cluster up and running in under 8 minutes by using a pre-built [Vagrant
box](https://app.vagrantup.com/phR0ze/boxes/cyberlinux-k8snode) as the base of the Virtual Machines
backing the K8s cluster.
<a href="doc/images/vagrantup-k8snode.jpg"><img src="doc/images/vagrantup-k8snode.jpg"></a>

### Kubeadm <a name="kubeadm"/></a>
https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/

***Kubinator*** leverages ***kubeadm*** which is a Kubernetes project designed to be a simple way
for new users to start trying Kubernetes out, possibly for the first time, a way for existing users
to test their application on and stitch together a cluster easily, and also to be a building block
in other ecosystem and/or installer tool with a larger scope.

***kubeadm*** is currently in Beta but expecred to graduate to ***General Availability (GA) in
2018***

### CNI Plugins <a name="cni-plugins"/></a>
Documentation on how to get container networking up and running is not detailed enough for how
complicated the process is.  I spent a few house trying to determine why I was missing either the
***loopback*** plugin when attempting to configure weave or the ***portmap*** plugin when attempting
to configure flannel.  I finally realized that the Container Networking project was split into two
pieces, the CNI utility and the [CNI plugins](https://github.com/containernetworking/plugins).

The ***cyberlinux*** project contains packaging of CNI include the plugins to avoid this issue
https://github.com/phR0ze/cyberlinux/blob/master/aur/kubernetes/PKGBUILD

## Deploy Kubinator <a name="deploy-kubinator"/></a>
There is no ***host*** Linux distribution requirements here other than something that supports
***VirtualBox***, ***Vagrant*** and ***Ruby***, however [cyberlinux](http://github.com/phR0ze/cyberlinux)
is the fastest way to get up and running as most of the dependencies are baked in.

***kubectl*** and ***helm*** are required to be installed on the host environment to manage the
cluster remotely.

### Deploy on cyberlinux <a name="deploy-on-cyberlinux"/></a>
```bash
# Install deps, run:
sudo pacman -S kubectl helm

# Clone kubinator
git clone https://github.com/phR0ze/kubinator.git

# Install ruby gems
cd kubinator
bundle install --system
```

### Deploy on Arch Linux <a name="deploy-on-arch-linux"/></a>
```bash
# Add cyberlinux repo to pacman config
sudo tee -a /etc/pacman.conf <<EOL
[cyberlinux]
SigLevel = Optional TrustAll
Server = https://phr0ze.github.io/cyberlinux-repo/$repo/$arch
EOL

# Install deps, run:
sudo pacman -Sy
sudo pacman -S virtualbox vagrant ruby ruby-bundler kubectl helm

# Clone kubinator
git clone https://github.com/phR0ze/kubinator.git

# Install ruby gems
cd kubinator
bundle install --system
```

### Deploy on Ubuntu <a name="deploy-on-unbutu"/></a>
I've validated with Ubuntu 16.04 and the following versions

* ruby 2.3.1
* vagrant 1.8.1
* virtualbox 5.0.32

```bash
# Install deps, run:
sudo apt-get install virtualbox vagrant ruby ruby-dev

# Install kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh

# Clone kubinator
git clone https://github.com/phR0ze/kubinator.git

# Install ruby gems
sudo gem install bundler --no-user-install
bundle install --system
```

## Deploy Kubernetes <a name="deploy-kubernetes"/></a>
By default ***Kubinator*** will deploy 3 ***cyberlinux-k8snode*** vms with 2 cpus and 2GB RAM ea. on
which to deploy Kubernetes.

Deploying a development Kubernetes cluster with kubinator is a few simple steps:

1. Deploy vagrant nodes
  ```bash
  ./kubinator deploy
  ```

2. Take snapshot of nodes prior to clustering  
  ```bash
  ./kubinator snap save
  ```

3. Deploy K8s on vagrant nodes  
  ```bash
  ./kubinator cluster all
  ```

4. Access k8s cluster  
  The deployment process will download the ***KUBECONFIG*** as `~/.kube/config.kubinator` and create
  a link as `~/.kube/config` so that ***kubectl*** commands will just work.

  Example:
  ```bash
  kubectl get po --all-namespaces -o wide
  ```

### Node Networking <a name="node-networking"/></a>
Each node is configured with two network interface cards:  
1. One configured as a NAT with the host for access to the external world
2. One configured on a host-only network for node to node communication

### Vagrant Node Access
You can access the nodes using *vagrant* for your username and password  
```bash
# Example shell into a node:
ssh vagrant@192.168.56.10

# Example scp out a file:
scp vagrant@192.168.56.10:/etc/kubernetes/kubelet.conf .
```

## Troubleshooting <a name="troubleshooting"/></a>

### kubeadm config <a name="kubeadm-config"/></a>
https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-config/

Creating a kubeadm config really seems to be the only way to configure all options needed to have a
running cluster.

Working with kubeadm config:
```bash
# Print out the current config
sudo kubeadm config view

# Print out the default config
sudo kubeadm config print-default
```

### Networking Validation <a name="networking-validation"/></a>
https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

Typically if your having weird time out issues with Kubernetes, like dashboard connections timing
out or other services timing out it is usually a networking issue. At this point the best thing to
do is validate your networking.

Shell into each of your nodes:
```bash
# Validate kernel networking settings below are enabled:
sysctl net.ipv4.ip_forward
# net.ipv4.ip_forward = 1
sysctl net.bridge.bridge-nf-call-iptables
# net.bridge.bridge-nf-call-iptables = 1

# Validate that docker dns works
docker run --rm busybox nslookup google.com
# Server:		10.0.2.3
# Address:	10.0.2.3:53
# 
# Non-authoritative answer:
# Name:	google.com
# Address: 172.217.1.206

# Validate that the expected Kubernetes services are running
kubectl get svc --all-namespaces
# NAMESPACE     NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
# default       kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP         3h
# kube-system   kube-dns     ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP   3h

# Validate that the CoreDNS pods have connectivity to the DNS server
kubectl -n kube-system exec coredns-78fcdf6894-mkdck -- nc 10.96.0.10 53 -v
# 10.96.0.10 (10.96.0.10:53) open

# Validate that CoreDNS can perform nslookups
kubectl -n kube-system exec coredns-78fcdf6894-mkdck -- nslookup google.com
# Server:		10.0.2.3
# Address:	10.0.2.3#53
# 
# Non-authoritative answer:
# Name:	google.com
# Address: 172.217.12.14
# Name:	google.com
# Address: 2607:f8b0:400f:801::200e

kubectl -n kube-system exec coredns-78fcdf6894-mkdck -- nslookup kubernetes.default
# Server:		10.0.2.3
# Address:	10.0.2.3#53
# 
# ** server can't find kubernetes.default: NXDOMAIN
# 
# command terminated with exit code 
```

From host deploy BusyBox Daemonset:
```bash
# Deploy BusyBox daemon set
kubectl apply -f manifest/busybox.yaml

# Check pod on master node to DNS:
kubectl exec busybox-m2t8q -- nc 10.96.0.10 53 -v
# 10.96.0.10 (10.96.0.10:53) open

# Check nslookups:
kubectl exec busybox-m2t8q -- nslookup kubernetes.default
# Server:		10.96.0.10
# Address:	10.96.0.10:53
#
# ** server can't find kubernetes.default: NXDOMAIN
# 
# *** Can't find kubernetes.default: No answer

# Check pod on non master node to DNS:
kubectl exec busybox-p26pt -- nc 10.96.0.10 53 -v
# nc: 10.96.0.10 (10.96.0.10:53): No route to host
# command terminated with exit code 1

# Check nslookups:
kubectl exec busybox-m2t8q -- nslookup kubernetes.default
# ;; connection timed out; no servers could be reached
# 
# command terminated with exit code 1
```

Summary of results:
* No connectivity cross nodes - solved see [Cross Node Connectivity Fails](#cross-node-connectivity-fails)
* DNS doesn't seem to work at all in busybox despite connectivity
* DNS works for localhost on CoreDNS node but not for kubernetes.default

### Cross Node Connectivity Fails <a name="cross-node-connectivity-fails"/></a>
Typically when there is a lack of connectivity across nodes it is a ***kube-proxy*** problem.

Flannel Solution:  
Note this issue occurred for me because I'd configured each vagrant node with a NAT interface (for
internet connectivity) and a Host-Only interface (for node to node communication).  Flannel was
choosing my NAT interface for node to node communication by default which obviously wouldn't work now
that I understand what was happening.  By explicitly setting the ***--iface*** being used to my
Host-Only node to node network this issue was resolved.

Research:
* https://github.com/kubernetes/kubernetes/issues/52783
  * suggests adding --cluster-cidr to kube-proxy, well what cidr?
  * Use `kubectl cluster-info dump | grep cidr` to see what current cidr is
    * See version: `kubectl version --short`
    * [kubectl 1.11.2 has a bug](https://github.com/kubernetes/kubernetes/pull/66652) so this doesn't work
    * Downgrade to [kubectl 1.10.5](https://github.com/phR0ze/cyberlinux-repo/blob/f02bb33ca2538ec92c26c968bcd310026d0df86e/cyberlinux/x86_64/kubectl-1.10.5-1-x86_64.pkg.tar.xz)
      ```bash
      wget https://github.com/phR0ze/cyberlinux-repo/raw/f02bb33ca2538ec92c26c968bcd310026d0df86e/cyberlinux/x86_64/kubectl-1.10.5-1-x86_64.pkg.tar.xz
      sudo pacman -U kubectl-1.10.5-1-x86_64.pkg.tar.xz
      ```
    * Finally get results: `--cluster-cidr=10.244.0.0/16`
    * This is the same cidr what I gave for `--pod-network-cidr` for flannel to work
  * When attempting to add this to ***kube-proxy*** I found out since kube-proxy is deployed as a
    pod non of the existing documentation works. You actually need to modify the manifest of the pod
    and restart it.
  * suggested running https://scanner.heptio.com/
    * https://scanner.heptio.com/ee168a38ae9833e522af2db4f7b5887e/
    * was taking too long, maybe I'll revisit this someday
  * kubeadm init --pod-network-cidr= should apparently be setting the --cluster-cidr for kube-proxy
    * I'm manually setting this post deployment using json edits to the manifest
  * Set Flannl arguments --iface and --ip-masq
    * Was going down the route of post deployment modifying when I realized that this was a
      downloaded manifest anyway so I'll just edit first
    * Validate results
      ```bash
      kubectl -n kube-system get ds kube-flannel-ds -o json | jq '.spec.template.spec.containers[0].command'
      ```
    * --ip-masq was already being set, but ***--iface*** was not, I set it to my host-only iface
      ***enp0s8*** and bingo I now have node to node communication even with ***VXLAN***
* https://github.com/kubernetes/kubernetes/issues/45459

### DNS Not Resolving <a name="dns-not-resolving"/></a>
Now that I've solved the issue with cross node communication, DNS is still not resolving
***kubernetes.default*** or ***kubernetes***. 

Solution:  
It was actually working since I fixed the node to node communication. BusyBox has some issues in its
nslookup implementation causing it to not resolve correctly. Alpline also has a poor nslookup
configuation that gave issues.  After deploying [cyberlinux](https://hub.docker.com/r/phr0ze/cyberlinux-net/)
as a daemonset I was able to verify proper functionality.

Research:
* https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/#does-the-service-work-by-dns
  * Can't resolve DNS by the DNS service IP 10.96.0.10 or CoreDNS pod address
  * Tried all forms of dns name qualification - all fail
    ```bash
    kubectl exec busybox-5hvbx -- nslookup kubernetes
    # Server:		10.96.0.10
    # Address:	10.96.0.10:53
    # 
    # ** server can't find kubernetes: NXDOMAIN
    # 
    # *** Can't find kubernetes: No answer
    
    # Namespace qualified version
    kubectl exec busybox-5hvbx -- nslookup kubernetes.default
    # Server:		10.96.0.10
    # Address:	10.96.0.10:53
    # 
    # ** server can't find kubernetes.default: NXDOMAIN
    # 
    # *** Can't find kubernetes.default: No answer
    
    # Fully qualified version
    kubectl exec busybox-5hvbx -- nslookup kubernetes.default.svc.cluster.local
    # Server:		10.96.0.10
    # Address:	10.96.0.10:53
    # 
    # *** Can't find kubernetes.default.svc.cluster.local: No answer

    # Using IP address
    kubectl exec busybox-5hvbx -- nslookup 10.96.0.1
    ```

  * Validated /etc/resolv.conf looks correct
    ```bash
    kubectl exec busybox-m2t8q -- cat /etc/resolv.conf
    # nameserver 10.96.0.10
    # search default.svc.cluster.local svc.cluster.local cluster.local
    # options ndots:5
    ```
* https://github.com/kubernetes/dns/issues/169
  * Suggests that busybox nslookup may be broken so try alpine instead
  * https://github.com/kubernetes/dns/issues/118
    ```bash
    kubectl apply -f manifest/cyberlinux.yaml
    kubectl exec -it alpine-p7jcw sh
    apk update && apk add bind-tools
    dig +trace @10.96.0.10 google.com

    # Lookup kubernetes
    kubectl exec alpine-p7jcw nslookup kubernetes
    # nslookup: can't resolve '(null)': Name does not resolve
    # Name:      kubernetes
    # Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
    ```
  * Although its working alpine has flaws as well what up with ***null*** error
  * Using a real distribution - Arch Linux based [cyberlinux](https://hub.docker.com/r/phr0ze/cyberlinux-net/)
    ```bash
    kubectl apply -f manifest/cyberlinux.yaml

    # Lookup kubernetes
    kubectl exec cyberlinux-bccn7 nslookup kubernetes
    # Server:		10.96.0.10
    # Address:	10.96.0.10#53
    # 
    # Name:	kubernetes.default.svc.cluster.local
    # Address: 10.96.0.1

    # Lookup kubernetes.default
    kubectl exec cyberlinux-bccn7 nslookup kubernetes
    # Server:		10.96.0.10
    # Address:	10.96.0.10#53
    # 
    # Name:	kubernetes.default.svc.cluster.local
    # Address: 10.96.0.1

    kubectl exec cyberlinux-bccn7 nslookup google.com
    # Server:		10.96.0.10
    # Address:	10.96.0.10#53
    #
    # Non-authoritative answer:
    # Name:	google.com
    # Address: 172.217.12.14
    # Name:	google.com
    # Address: 2607:f8b0:400f:801::200e
    ```

<!-- 
vim: ts=2:sw=2:sts=2
-->
