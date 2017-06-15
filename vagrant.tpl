nodes = [
  #{:host=>"k8snode10", :ip=>"192.168.56.10/24", :box=>"k8snode-1.0.60.box", :cpus=>2, :ram=>2048, :vram=>8, :v3d=>"off", :ipv6=>false},
]
no_proxy = nodes.map{|x| x[:ip][0..x[:ip].index('/')-1]} * ','
auth_keys = File.read(File.expand_path('~/.ssh/authorized_keys'))

Vagrant.configure("2") do |config|
  config.vm.synced_folder(".", "/vagrant", disabled:true)

  # Configure each node
  #-----------------------------------------------------------------------------
  nodes.each do |node|
    config.vm.define node[:host] do |conf|
      conf.vm.box = node[:box]
      conf.vm.hostname = node[:host]

      # Custom VirtualBox settings
      #-------------------------------------------------------------------------
      conf.vm.provider :virtualbox do |vbox|
        vbox.name = node[:host]
        vbox.cpus = node[:cpus]
        vbox.memory = node[:ram]
        vbox.customize(["modifyvm", :id, "--vram", node[:vram]])
        vbox.customize(["modifyvm", :id, "--accelerate3d", node[:v3d]])

        # Configure Networking
        vbox.customize(["modifyvm", :id, "--nic1", "nat"])
        vbox.customize(["modifyvm", :id, "--nic2", "hostonly"])
        vbox.customize(["modifyvm", :id, "--hostonlyadapter2", "vboxnet0"])
      end

      # Custom VM provisioning
      #-------------------------------------------------------------------------
      conf.vm.provision :shell do |script|
        script.args = [node[:ip], no_proxy]
        script.inline = <<-SHELL
          # Configure host-only static ip address
          echo -e "[Match]\\nName=enp0s8\\n" >> /etc/systemd/network/10-static.network
          echo -e "[Network]\\nAddress=${1}\\nIPForward=kernel" >> /etc/systemd/network/10-static.network

          # Add local private ip to no_proxy
          sed -i -e "s/\\(.*no_proxy=localhost.*\\)/\\1,${2}/" /usr/bin/setproxy

          # Inject local authorization keys for convenience
          echo -e "#{auth_keys}" >> /home/vagrant/.ssh/authorized_keys
          SHELL
      end

    end
  end
end

# vim: ft=ruby:ts=2:sw=2:sts=2
