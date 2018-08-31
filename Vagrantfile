# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  n_cpus = ENV["VM_N_CPUS"] || 2
  n_cpus = Integer(n_cpus) if n_cpus
  memory = ENV["VM_MEMORY"] || 1024
  memory = Integer(memory) if memory
  synced_folder = ENV["VM_SYNCED_FOLDER"]
  synced_folder = synced_folder.split(":") if synced_folder

  box = "bento/ubuntu-18.04"
  [
    ["3.4.6", "postgresql"],
  ].each do |redmine_version, rdb|
    config.vm.define("#{redmine_version}-#{rdb}") do |node|
      node.vm.box = box
      node.vm.synced_folder(*synced_folder) if synced_folder
      node.vm.provider("virtualbox") do |virtual_box|
        virtual_box.cpus = n_cpus
        virtual_box.memory = memory
      end
      node.vm.provision("shell",
                        path: "setup.sh",
                        args: [redmine_version, rdb])
    end
  end

  config.vm.network("public_network")
end
