# Kubinator
***Kubinator*** provides deployment automation for Kubernetes  
***Kubinator*** can quickly deploy a K8s cluster with customizable VMs, manage vm snapshots and
automate cluster customizations all from a single simple command line. Kubinator accomplishes this
by leveraging Vagrant's excellent cross platform VM automation with VirtualBox as the provider
backend. Kubinator can ***deploy a new K8s cluster in under 10min*** using an opensource pre-baked
Vagrant box https://app.vagrantup.com/phR0ze/boxes/cyberlinux-k8snode

[![Build Status](https://travis-ci.org/phR0ze/kubinator.svg)](https://travis-ci.org/phR0ze/kubinator)

## Disclaimer
***kubinator*** comes with absolutely no guarantees or support of any kind. It is to be used at
your own risk.  Any damages, issues, losses or problems caused by the use of ***kubinator*** are
strictly the responsiblity of the user and not the developer/creator of ***kubinator***.

### Table of Contents
* [Kubinator Overview](#kubinator-overview)
* [Deploy Kubinator](#deploy-kubinator)
  * [Deploy on cyberlinux](#deploy-on-cyberlinux)
  * [Deploy on Arch Linux](#deploy-on-arch-linux)
  * [Deploy on Ubuntu](#deploy-on-ubuntu)
* [Deploy Kubernetes](#deploy-kubernetes)
  * [Vagrant Node Access](#vagrant-node-access)
 
## Kubinator Overview <a name="kubinator-overview"/></a>
***Kubinator*** uses Ruby to automate the management/orchestration of the Virtual Machines backing
the Kubernetes cluster. ***Kubinator*** orchestrates [Vagrant](https://www.vagrantup.com/intro/index.html)
to then in turn pull the strings of [VirtualBox](https://www.virtualbox.org/). Kubinator is able to
get a new Kubernetes cluster up and running in under 10min by using a pre-built [Vagrant
box](https://app.vagrantup.com/phR0ze/boxes/cyberlinux-k8snode) as the base of Virtual Machines
backing your K8s cluster.
<a href="doc/images/vagrantup-k8snode.jpg"><img src="doc/images/vagrantup-k8snode.jpg"></a>

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

2. Add node IPs to no_proxy  
  ```bash
  export no_proxy=$no_proxy,192.168.56.10,192.168.56.11,192.168.56.12
  ```

3. Deploy K8s on vagrant nodes  
  This step ***clears your ~/.kube*** cache
  ```bash
  ./kubinator deploy --cluster
  ```
  Note: i'd recommend taking another snapshot of your vms at this point
  Note: if this step seems to hang at the "waiting for the control plane
  to become ready" stage (i.e. more than 10min) ensure that your
  ***no_proxy*** includes your nodes as configured in the previous step.

4. Access k8s cluster  
  The deployment process will configure a ***kubernetes-admin@kubernetes*** context
  ```bash
  kubectl config use-context kubernetes-admin@kubernetes
  # Example: kubectl get po --all-namespaces -o wide
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

<!-- 
vim: ts=2:sw=2:sts=2
-->
