#!/usr/bin/env ruby
require 'fileutils'             # advanced file utils: FileUtils
require 'mkmf'                  # system utils: find_executable
require 'optparse'              # cmd line options: OptionParser
require 'open3'                 # Better system commands
require 'rubygems/package'      # tar
require 'yaml'                  # YAML

# Gems that need to be installed
begin
  require 'colorize'            # color output: colorize
  require 'net/ssh'             # ssh integration: Net::SSH
  require 'net/scp'             # scp integration: Net::SCP
rescue Exception => e
  mod = e.message.split(' ').last.sub('/', '-')
  !puts("Error: install missing module with 'sudo gem install #{mod} --no-user-install'") and exit
end

class Kubinator

  # Initialize
  # ==== Attributes
  # * +k8sver+ - version of kubernetes we are working with
  # * +nodever+ - version of vagrant box we are working with
  def initialize(k8sver, nodever)
    @k8sver = k8sver
    @nodever = nodever

    # Minimum versions
    @helmver = '2.3.1'
    @vagrantver = '1.8.1'
    @virtualboxver = '5.0.32'

    @user = 'vagrant'
    @pass = 'vagrant'
    @host = 'k8snode'
    @netname = 'vboxnet0'
    @netip = '192.168.56.1'
    @netmask = '255.255.255.0'

    # Set proxy vars
    @proxyenv = {
      'ftp_proxy' => ENV['ftp_proxy'],
      'http_proxy' => ENV['http_proxy'],
      'https_proxy' => ENV['https_proxy'],
      'no_proxy' => ENV['no_proxy']
    }
    @proxy = ENV['http_proxy']
    @proxy_export = @proxy ? (@proxyenv.map{|k,v| "export #{k}=#{v}"} * ';') + ";" : nil
  end

  # Deploy vagrant node/s
  # ==== Attributes
  # * +nodes+ - list of node ids to deploy
  # * +box+ - vagrant box to deploy
  # * +cpu+ - number of cpus to give a VM
  # * +ram+ - amount of ram in mb to give a VM
  def deploy_nodes(nodes, box, cpu:nil, ram:nil)
    puts("#{'-' * 80}\nDeploying layer '#{box}'\n#{'-' * 80}".colorize(:yellow))

    # Set defaults if not given
    cpu = cpu || 2
    ram = ram || 2048

    # Validate vagrant environment
    #---------------------------------------------------------------------------
    puts("Validating the environment for the correct vagrant tooling".colorize(:cyan))

    # Check that the given box is compatible
    !puts("Please use compatible vagrant box version #{@nodever}".colorize(:red)) and
      exit unless box.include?(@nodever)
    puts("Box: #{box}".colorize(:green))

    # Check that vagrant is installed and the correct version
    !puts("Ensure 'vagrant' is installed and on the $PATH".colorize(:red)) and
      exit unless find_executable('vagrant')
    vagrantver = `vagrant --version`[/\d+\.\d+\.\d+/]
    !puts("Vagrant needs to be version #{@vagrantver} or higher".colorize(:red)) and
      exit unless Gem::Version.new(vagrantver) >= Gem::Version.new(@vagrantver)
    puts("Vagrant: #{vagrantver}".colorize(:green))

    # Check that vagrant/virtualbox are on the path and clean previously deployed VMs
    !puts("Ensure 'virtualbox' is installed and on the $PATH".colorize(:red)) and
      exit unless find_executable('vboxmanage')
    virtualboxver = `vboxmanage --version`[/\d+\.\d+\.\d+/]
    !puts("Virtualbox needs to be version #{@virtualboxver} or higher".colorize(:red)) and
      exit unless Gem::Version.new(virtualboxver) >= Gem::Version.new(@virtualboxver)
    puts("Virtualbox: #{virtualboxver}".colorize(:green))

    # Update vagrant registry and ensure host-only network exists
    #---------------------------------------------------------------------------
    puts("Updating vagrant registry for '#{box}'".colorize(:cyan))
    sys("vagrant box add #{@host} #{box} --force")

    config_network = "vboxmanage hostonlyif ipconfig #{@netname} -ip #{@netip} -netmask #{@netmask}"
    if not sys(config_network, die:false)
      sys("vboxmanage hostonlyif create")
      sys(config_network)
    end

    # Generate vagrant node parameters
    #---------------------------------------------------------------------------
    specs = []
    nodes.each do |node|
      spec = {
        host: "#{@host}#{node}",
        ip: "#{@netip[0..-2]}#{node}/24",
        box: box,
        cpus: cpu,
        ram: ram,
        vram: 8,
        v3d: 'off',
        ipv6: false
      }
      specs << spec
      puts("Generating node: #{spec.to_s}".colorize(:cyan))
    end

    # Read in the template file and write out with ips
    lines = nil
    File.open('vagrant.tpl', 'r+') do |f|
      lines = f.readlines
      cut = lines.find_index{|x| x =~ /no_proxy.*/}
      lines = ['nodes = ['] + specs.map{|x| "  #{x.to_s},"} + [']'] + lines[cut..-1]
    end
    File.open('Vagrantfile', 'w'){|f| f.puts(lines)}

    # Initialize vagrant box
    #-----------------------------------------------------------------------
    puts("Initializing vagrant box/s '#{box}'".colorize(:cyan))
    sys("vagrant up")
    sys("vagrant reload")
  end

  # Create Kubernetes cluster from given nodes
  # ==== Attributes
  # * +ips+ - list of node ips to cluster
  # * +init+ - initialize the main node
  # * +join+ - join all the slaves to the cluster
  # * +dashboard+ - install the dashboard
  # * +registry+ - private registry to authorize
  # * +helm+ - install helm
  def deploy_cluster(ips, init:nil, join:nil, dashboard:nil, helm:nil, registry:nil)
    puts("Deploying Kubernetes Cluster".colorize(:yellow))
    puts("Nodes: #{ips * ', '}".colorize(:yellow))
    puts("#{'-' * 80}".colorize(:cyan))
    all = ![init, join].any?

    token = 'c74b2e.897db207c8e26de2'

    # Validate the environment
    #---------------------------------------------------------------------------
    puts("Validating the environment for the correct k8s tooling".colorize(:cyan))
    !puts("Please unset uppercase proxy vars, it is just confusing and they are not used ever".colorize(:red)) and
      exit unless not [ENV['HTTP_PROXY'], ENV['HTTPS_PROXY'], ENV['NO_PROXY']].any?

    !puts("Please unset KUBECONFIG. We will be using 'contexts' instead".colorize(:red)) and
      exit unless not ENV['KUBECONFIG']

    # Check environment variables
    !puts("Ensure 'no_proxy' includes your node ips #{ips * ','}".colorize(:red)) and
      exit unless not @proxy or ips.each{|x| ENV['no_proxy'].include?(x)}
    puts("$no_proxy configured correctly".colorize(:green)) if @proxy

    # Validate that kubectl is installed on the path and a supported version
    !puts("Ensure 'kubectl' is installed and on the path".colorize(:red)) and
      exit unless find_executable('kubectl')
    stdout, stderr, status = Open3.capture3("kubectl version")
    kubectlver = stdout[/GitVersion:\"v\d+\.\d+\.\d+/].split('v').last
    !puts("Kubectl needs to be version #{@k8sver} or higher".colorize(:red)) and
      exit unless Gem::Version.new(kubectlver) >= Gem::Version.new(@k8sver)
    puts("Kubectl: #{kubectlver}".colorize(:green))

    # Validate that helm is installed on the path and a supported version
    !puts("Ensure 'helm' is installed and on the path".colorize(:red)) and
      exit unless find_executable('helm')
    helmver = `helm version --client`[/\d+\.\d+\.\d+/]
    !puts("Helm needs to be version #{@helmver} or higher".colorize(:red)) and
      exit unless Gem::Version.new(helmver) >= Gem::Version.new(@helmver)
    puts("Helm: #{helmver}".colorize(:green))

    # (Idempotent) Configure nodes for clustering
    #---------------------------------------------------------------------------
    threads = []
    ips.each{|ip| threads << Thread.new{
      Net::SSH.start(ip, @user, password:@pass, paranoid:false) do |ssh|

        # Configure journald for persistent storage
        journald_conf = '/etc/systemd/journald.conf'
        if not ssh.exec!("cat #{journald_conf}").include?('persistent')
          ssh.exec!("sudo sed -i -e 's/.*\\(Storage=\\).*/\\1persistent/' #{journald_conf}")
          ssh.exec!("sudo systemctl restart systemd-journald")
          puts("#{ip}: Configured node journald...done".colorize(:cyan))
        else
          puts("#{ip}: Configured node journald...skipped".colorize(:cyan))
        end

        # Configure kubelet
        kubeadm_conf = '/etc/systemd/system/kubelet.service.d/10-kubeadm.conf'
        if not ssh.exec!("cat #{kubeadm_conf}").include?(ip)
          extra_args = "Environment=\"KUBELET_EXTRA_ARGS=--hostname-override=#{ip} --node-ip=#{ip}\"\\n"
          ssh.exec!("sudo sed -i -e 's/\\(ExecStart=\\)$/#{extra_args}\\1/' #{kubeadm_conf}")
          ssh.exec!("sudo systemctl daemon-reload")
          ssh.exec!("sudo systemctl restart kubelet")
          puts("#{ip}: Configured Kubelet private network ip...done".colorize(:cyan))
        else
          puts("#{ip}: Configured Kubelet private network ip...skipped".colorize(:cyan))
        end

        # Configure kernel for Elasticsearch
        sysctl_conf = '/etc/sysctl.d/10-cyberlinux.conf'
        if not ssh.exec!("cat #{sysctl_conf}").include?('max_map_count')
          ssh.exec!("sudo bash -c 'echo \"vm.max_map_count = 262144\" >> #{sysctl_conf}'")
          ssh.exec!("sudo sysctl -w vm.max_map_count=262144")
        else
          puts("#{ip}: Configured kernel params...skipped".colorize(:cyan))
        end

        # Optionally - configure private registry
        if registry
          docker_opts = [ "--registry-mirror=http://#{registry}", "--insecure-registry #{registry}" ]
          override_conf = '/etc/systemd/system/docker.service.d/override.conf'
          if not ssh.exec!("[ -e #{override_conf} ] && echo 'exists'").include?('exists')

            # Configure kubernetes for private registry
            docker_conf = "{\\\"auths\\\":{\\\"#{registry}\\\":{\\\"auth\\\":\\\"YW5vbnltb3VzOmFub255bW91cw==\\\"}}}"
            ssh.exec!("sudo bash -c 'mkdir -p /root/.docker'")
            ssh.exec!("sudo bash -c 'echo \"#{docker_conf}\" > /root/.docker/config.json'")

            # Configure docker for private registry
            ssh.exec!("sudo bash -c 'echo \"[Service]\" > #{override_conf}'")
            ssh.exec!("sudo bash -c 'echo \"ExecStart=\" >> #{override_conf}'")
            ssh.exec!("sudo bash -c 'echo \"ExecStart=/usr/bin/dockerd #{docker_opts * ' '} -H fd://\" >> #{override_conf}'")
            ssh.exec!("sudo systemctl daemon-reload")
            ssh.exec!("sudo systemctl restart docker")
            puts("#{ip}: Configured Docker overrides...done".colorize(:cyan))
          else
            puts("#{ip}: Configured Docker overrides...skipped".colorize(:cyan))
          end
        end
      end
    }}
    threads.each{|x| x.join}

    # (Idempotent) Initialize master node
    # https://kubernetes.io/docs/getting-started-guides/kubeadm
    #---------------------------------------------------------------------------
    if all or init
      Net::SSH.start(ips.first, @user, password:@pass, paranoid:false) do |ssh|
        if not ssh.exec!("docker ps").include?("google")

          # Initialize master - pod-network injects the --cluster-cidr into kube-proxy
          puts("#{ips.first}: Initialize Master node...".colorize(:cyan))
          cmd = "sudo kubeadm init --token=#{token} --kubernetes-version=v#{@k8sver} --apiserver-advertise-address=#{ips.first}"
          ssh.exec!(cmd){|c,s,o|puts(o)}
          (1..10).each{|i| puts("Waiting for k8s networking to quiesce..#{i}"); sleep(1)}
          ssh.exec!("mkdir -p ~/.kube")
          ssh.exec!("sudo mkdir -p /root/.kube")
          ssh.exec!("sudo cp /etc/kubernetes/admin.conf /root/.kube/config")
          ssh.exec!("sudo cp /etc/kubernetes/admin.conf ~/.kube/config")
          ssh.exec!("sudo chown $(id -u):$(id -g) ~/.kube/config")
          ssh.exec!("kubectl config use-context kubernetes-admin@kubernetes")
          ssh.exec!("sudo kubectl config use-context kubernetes-admin@kubernetes")

          # Disable RBAC for now (will wait until needed)
          # Bottom of https://kubernetes.io/docs/admin/authorization/rbac
          ssh.exec!("kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts"){|c,s,o|puts(o)}

          # Patch kube-proxy for dns resolution using --proxy-mode=iptables
          # https://github.com/kubernetes/kubernetes/issues/18934
          get_kube_proxy = "kubectl -n kube-system get ds kube-proxy -o json"
          mod_kube_proxy = " | jq '.spec.template.spec.containers[0].command |= .+ [\"--proxy-mode=iptables\"]'"
          mod_kube_proxy += " | jq '.spec.template.spec.containers[0].command |= .+ [\"--cluster-cidr=10.32.0.0/12\"]'"
          set_kube_proxy = " | kubectl apply -f -"
          ssh.exec!("#{get_kube_proxy} #{mod_kube_proxy} #{set_kube_proxy}"){|c,s,o|puts(o)}
          ssh.exec!("kubectl -n kube-system delete po -l 'k8s-app=kube-proxy'"){|c,s,o|puts(o)}

          # Taint master node to allow pods to be scheduled on it
          # Check current taints in Tains section: kubectl describe node
          # Note: this needs to be done before deploying flannel
          puts("Tainting the master node to allow pods to be scheduled on it".colorize(:cyan))
          ssh.exec!("kubectl taint nodes --all node-role.kubernetes.io/master-"){|c,s,o|puts(o)}

          # Install Pod networking
          # Note: kube-dns will be pending until the pod networking is installed
          puts("Installing weave networking".colorize(:cyan))
          ssh.exec!("#{@proxy_export}kubectl apply -f https://git.io/weave-kube-1.6"){|c,s,o|puts(o)}
        end
      end
    end

    # (Idempotent) Configure slaves to join cluster
    #---------------------------------------------------------------------------
    if all or join
      nodes_to_join = []
      Net::SSH.start(ips.first, @user, password:@pass, paranoid:false) do |ssh|
        output = getpods(ssh:ssh)
        nodes_to_join = ips.select{|x| !output.include?(x)}
      end
      nodes_to_join.each do |ip|
        Net::SSH.start(ip, @user, password:@pass, paranoid:false) do |ssh|
          puts("#{ip}: Joining cluster".colorize(:cyan))
          ssh.exec!("sudo kubeadm join --token=#{token} #{ips.first}:6443"){|c,s,o|puts(o)}
        end
      end
    end

    # (Idempotent) Install dashboard and helm
    #---------------------------------------------------------------------------
    Net::SSH.start(ips.first, @user, password:@pass, paranoid:false) do |ssh|

      # Install dashboard
      if all or dashboard
        if not getpods(pod:'dashboard', ssh:ssh)
          puts("#{ips.first}: Installing dashboard".colorize(:cyan))
          url = "https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml"
          puts(ssh.exec!("kubectl create -f #{url}"))
        else
          puts("#{ips.first}: Installing dashboard...skipped".colorize(:cyan))
        end
      end

      # Initialize/update helm
      if all or helm
        if not getpods(pod:'tiller', ssh:ssh)
          puts("#{ips.first}: Initializing helm".colorize(:cyan))
          ssh.exec!("#{@proxy_export}helm init"){|c,s,o|puts(o)}
          ssh.exec!("#{@proxy_export}helm repo update"){|c,s,o|puts(o)}
        else
          puts("#{ips.first}: Initializing/updating helm...skipped".colorize(:cyan))
        end
      end
    end

    # Configure local kubectl
    kube_conf = File.expand_path("~/.kube/config")
    FileUtils.rm_rf(kube_conf)
    FileUtils.mkdir_p(File.dirname(kube_conf))
    Net::SCP.download!(ips.first, @user, '.kube/config', kube_conf, ssh:{paranoid: false, password: @pass})
    sys("kubectl config use-context kubernetes-admin@kubernetes")
    puts("#{'-' * 80}".colorize(:cyan))
    sys("kubectl get po --all-namespaces -o wide")
    puts("#{'-' * 80}".colorize(:cyan))
    puts("Your cluster will need a few minutes to be fully operational".colorize(:cyan))
  end

  # Deploy logger test pods
  # ==== Attributes
  # * +deploy+ - number of logger pods to deploy
  # * +delete+ - number of logger pods to deploy
  def loggers(deploy:nil, delete:nil)
    !puts("Error: either the 'deploy' or the 'delete' flags need passed".colorize(:red)) and
      exit unless [deploy, delete].any?

    msg = "slfjslkdfjlsjfsjdlfsjdlfkjslkfjslkjflskjflskjdflskjdflskdflsjsldfkjsdlfkjsldjkfslkdjflskjdflkj"
    msg += "lfkjsdlkfjsldkjfsldjflskdjflskjdflsjdlfksjdlfjsdlkfjsldkjflssldfkjsdlfkjsldfjkslkjflskjdflkjs"
    msg += "dkjflskjdflskjflskjdllkjsdlkfjsldfkjsldkjflskdjflskjflskjdlsalkdjlksjdflksjflkjsdlfkjsdflkjsk"

    # Logger deployment
    if deploy
      i = 1
      pods = getpods()
      while true
        pod = "logger#{i.to_s.rjust(2, '0')}"
        pods.include?(pod) ? i += 1 : break
      end
      puts("Deploy loggers from: #{pod}")

      # Start deploying loggers
      (i..i+(deploy-1)).each{|x|
        pod = "logger#{x.to_s.rjust(2, '0')}"
        sys("kubectl run #{pod} --image=busybox --generator=run-pod/v1 -- sh -c 'while true; do echo #{msg}; sleep 0.0001; done'")
      }
    end

    # Logger destruction
    if delete
      pods = getpods().split("\n").map{|x| x.include?("logger") and !x.split(" ")[3].include?('Terminating') ? x.split(" ")[1]:nil}.compact.uniq
      start = pods.last.split("logger").last.to_i
      i = start
      pod = "logger#{start.to_s.rjust(2, '0')}"
      puts("Delete loggers from: #{pod}")
      while start - i < delete
        pod = "logger#{i.to_s.rjust(2, '0')}"
        sys("kubectl delete po #{pod}")
        i -= 1
      end
    end
  end

  # Wait for the given pod to be ready
  # Blocks until service is ready
  # ==== Attributes
  # * +pod+ - pod by name to wait for
  def podready!(pod)
    details = getpods(pod:pod)
    status = details ? details[3] : ""

    # Skip wait if pod already running
    if status.include?('Running')
      puts("Waiting for '#{pod}' to be ready - Running".colorize(:cyan))

    # Wait for pod to be ready
    else
      ready = 0
      until ready > 1
        !puts("Waiting for '#{pod}' to be ready - #{status}".colorize(:cyan)) and sleep(10)
        details = getpods(pod:pod)
        status = details ? details[3] : ""

        ready += 1 if status.include?('Running')
      end
    end
  end

  # Get pod details
  # ==== Attributes
  # * +pod+ - pod by name to pull details for
  # * +ssh+ - optionaly use ssh connection to use
  def getpods(pod:nil, ssh:nil)
    details = ssh ? ssh.exec!("kubectl get pod --all-namespaces -o wide") :
      `kubectl get pod --all-namespaces -o wide`
    if pod
      details = details.split("\n").find{|x| x.include?(pod)}
      details = details.split(' ').map{|x| x.strip} if details
      return details
    end
    return details
  end

  # Parse the node ips out of the Vagrantfile
  # ==== Attributes
  # * +returns+ - list of node ips
  def getnodeips()
    ips = []

    pattern = @netip.split('.')[0..-2] * '.'
    File.open('Vagrantfile', 'r') do |f|
      f.readlines.each{|x|
        if x =~ /#{pattern}.*/
          ips << x[/#{pattern}\.\d+/]
        end
      }
    end

    return ips
  end

  # Run a system command
  # ==== Attributes
  # * +cmd+ - cmd to execute
  # * +env+ - optional environment variables to set
  # * +die+ - fail if error
  # * +returns+ - true on success else false
  def sys(cmd, env:{}, die:true)
    result = false
    puts("sys: #{cmd.is_a?(String) ? cmd : cmd * ' '}")

    begin
      if cmd.is_a?(String)
        result = system(env, cmd, out: $stdout, err: :out)
      else
        result = system(env, *cmd, out: $stdout, err: :out)
      end
    rescue Exception => e
      result = false
      puts(e.message.colorize(:red))
      puts(e.backtrace.inspect.colorize(:red))
      exit if die
    end

    !puts("Error: failed to execute command properly".colorize(:red)) and
      exit unless !die or result

    return result
  end
end

#-------------------------------------------------------------------------------
# Main entry point
#-------------------------------------------------------------------------------
opts = {}
app = 'kubinator'
k8sver = '1.6.2'
nodever = '1.0.156'
title = "#{app}_v#{k8sver}"

# Configure command line options
#-------------------------------------------------------------------------------
help = <<HELP
Commands available for use:
    deploy                           Deploy Kubernetes
    cluster                          Kubernetes cluster control

see './#{app}.rb COMMAND --help' for specific command info
HELP

optparser = OptionParser.new do |parser|
  banner = "#{title}\n#{'-' * 80}\n".colorize(:yellow)
  examples = "Examples:\n".colorize(:green)
  examples += "Deploy nodes: ./#{app}.rb deploy --nodes=10,11,12 --box=~/Downloads/k8snode-#{nodever}.box\n".colorize(:green)
  examples += "Deploy large nodes: ./#{app}.rb deploy --nodes=10,11,12 --box=~/Downloads/k8snode-#{nodever}.box --cpu=4 --ram=12288\n".colorize(:green)
  examples += "Deploy cluster: ./#{app}.rb deploy --cluster\n".colorize(:green)
  examples += "Deploy cluster with private registry: ./#{app}.rb deploy --cluster --registry <reg>\n".colorize(:green)
  examples += "Deploy loggers: ./#{app}.rb deploy --loggers=3\n".colorize(:green)
  examples += "Delete loggers: ./#{app}.rb delete --loggers=3\n".colorize(:green)
  parser.banner = "#{banner}#{examples}\nUsage: ./#{app}.rb commands [options]"
  parser.on('-h', '--help', 'Print command/options help') {|x| !puts(parser) and exit }
  parser.separator(help)
end

optparser_cmds = {
  'deploy' => [OptionParser.new{|parser|
    parser.banner = "Usage: ./#{app}.rb deploy [options]"
    parser.on('--nodes x,y,z', Array, 'List of last octet IPs (e.g. 10,11,2) for nodes') {|x| opts[:nodes] = x}
    parser.on('--box BOX', 'Path to the vagrant box to use for the nodes') {|x| opts[:box] = x}
    parser.on('--cpu CPU', 'Number of cpus to assign a new VM') {|x| opts[:cpu] = x}
    parser.on('--ram RAM', 'Amount of ram to assign a new VM') {|x| opts[:ram] = x}
    parser.on('--cluster', 'Deploy a Kubernetes cluster on the nodes') {|x| opts[:cluster] = x}
    parser.on('--registry REGISTRY', 'Authorize the given private registry') {|x| opts[:registry] = x}
    parser.on('--loggers NUM', Float, 'Deploy a number of logger instances') {|x| opts[:loggers_deploy] = x}
  }],
  'delete' => [OptionParser.new{|parser|
    parser.banner = "Usage: ./#{app}.rb delete [options]"
    parser.on('--loggers NUM', Float, 'Delete a number of logger instances') {|x| opts[:loggers_delete] = x}
  }],
  'cluster' => [OptionParser.new{|parser|
    parser.banner = "Usage: ./#{app}.rb cluster [options]"
    parser.on('--init', 'Initialize the main k8s node') {|x| opts[:init] = x}
    parser.on('--join', 'Join all the slave nodes to the cluster') {|x| opts[:join] = x}
    parser.on('--dashboard', 'Install dashboard') {|x| opts[:dashboard] = x}
    parser.on('--helm', 'Install helm') {|x| opts[:helm] = x}
  }]
}

# Evaluate command line args
ARGV.clear and ARGV << '-h' if ARGV.empty? or not optparser_cmds[ARGV[0]]
optparser.order!
cmds = ARGV.select{|x| not x.include?('--')}
ARGV.reject!{|x| not x.include?('--')}
cmds.each{|x| !puts("Error: invalid command '#{x}'".colorize(:red)) and exit unless optparser_cmds[x]}
cmds.each do |cmd|
  begin
    opts[cmd.to_sym] = true
    optparser_cmds[cmd].first.order!
  rescue OptionParser::InvalidOption => e
    puts("Error: #{e}".colorize(:red))
    !puts(optparser_cmds[cmd].first.help) and exit
  end
end

# Check required options
if ARGV.any?
  !puts("Error: unhandled arguments #{ARGV}".colorize(:red)) and exit
elsif opts[:nodes] and not opts[:box]
  !puts("Error: '--box' is a required option".colorize(:red)) and exit
elsif opts[:box] and not opts[:nodes]
  !puts("Error: '--nodes' is a required option".colorize(:red)) and exit
elsif opts[:cluster] or opts[:loggers] and not File.exist?('Vagrantfile')
  !puts("Error: you must deploy the nodes first".colorize(:red)) and exit
end

#-------------------------------------------------------------------------------
# Execute application
#-------------------------------------------------------------------------------
kubinator = Kubinator.new(k8sver, nodever)
kubinator.deploy_nodes(opts[:nodes], opts[:box], cpu:opts[:cpu], ram:opts[:ram]) if opts[:nodes]
ips = kubinator.getnodeips() if opts[:cluster]
kubinator.deploy_cluster(ips, init: opts[:init], join: opts[:join], dashboard: opts[:dashboard], helm: opts[:helm]) if opts[:cluster]
kubinator.loggers(deploy: opts[:loggers_deploy], delete: opts[:loggers_delete]) if opts[:loggers_deploy] or opts[:loggers_delete]

# vim: ft=ruby:ts=2:sw=2:sts=2
