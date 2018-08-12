# Kubinator
Deployment automation for Kubernetes  
Note: this is for ***development only*** and not production

[![Build Status](https://travis-ci.org/phR0ze/kubinator.svg)](https://travis-ci.org/phR0ze/kubinator)

### Disclaimer
***kubinator*** comes with absolutely no guarantees or support of any kind. It is to be used at
your own risk.  Any damages, issues, losses or problems caused by the use of ***kubinator*** are
strictly the responsiblity of the user and not the developer/creator of ***kubinator***.

### Table of Contents
* [Deploy Kubinator](#deploy-kubinator)
  * [Deploy on cyberlinux](#deploy-on-cyberlinux)
  * [Deploy on Arch Linux](#deploy-on-arch-linux)
  * [Deploy on Ubuntu](#deploy-on-ubuntu)
* [Deploy Kubernetes](#deploy-kubernetes)
  * [Vagrant Node Access](#vagrant-node-access)
 
## Deploy Kubinator <a name="deploy-kubinator"/></a>
There is no Linux distribution requirements here other than something that supports
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
  ./kubinator deploy --nodes=10,11,12
  ```
  Note: it's recommended to take a snapshot after your vms deploy

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

### Vagrant Node Access
You can access the nodes using *vagrant* for your username and password  
Example shell into a node:
```bash
ssh vagrant@192.168.56.10
```

Example scp out a file:
```bash
scp vagrant@192.168.56.10:/etc/kubernetes/kubelet.conf .
```

<!-- 
vim: ts=2:sw=2:sts=2
-->
