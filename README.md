# Proxmox_vm_manager
## This project automates and manages the deployment of hundreds of Alpine Linux virtual machines on Proxmox.
## How to use
### Download script
```
git clone https://github.com/cooloo9871/Proxmox_vm_manager.git;cd Proxmox_vm_manager
```

### Setting the parameters
- `VM_id` is the number of the vm, be careful not to duplicate it.
- `VM_netid` is the network id used by the configured vm.
- `VM_ip` is the ip address used by the configuration vm.
  - The vm ip addresses in the following example range from 192.168.61.110 to 192.168.61.113.
```
$ nano setenvVar
# Set Proxmox Cluster Env
export NODE_IP=('192.168.1.3' '192.168.1.4' '192.168.1.5')
export NODE_HOSTNAME=('p1' 'p2' 'p3')
# The EXECUTE_NODE parameter specifies the proxmox node on which to manage the vm.
export EXECUTE_NODE="p2"

# Set VM Network Env
# Please make sure that the vm id and vm ip is not conflicting.
export VM_id="600~603"
export VM_netid="192.168.61"
export VM_ip="110~113"
export NETMASK="255.255.255.0"
export GATEWAY="192.168.61.2"
export NAMESERVER="8.8.8.8"

#export EXECUTE_NODE="p3"

# Set VM Network Env
# Please make sure that the vm id and vm ip is not conflicting.
#export VM_id="604~606"
#export VM_netid="192.168.61"
#export VM_ip="114~116"
#export NETMASK="255.255.255.0"
#export GATEWAY="192.168.61.2"
#export NAMESERVER="8.8.8.8"

# Set VM Hardware Env
export CPU_socket="2"
export CPU_core="2"
export CPU_type="x86-64-v2"
export MEM="4096"
export Network_device="vmbr0"
export DISK="50"
export STORAGE="local-lvm"

# Set alpine default user
export USER="bigred"
export PASSWORD="bigred"
```
### Notice
1. Before you start, please set up `/etc/hosts` in your localhost to be able to resolve to the Proxmox node by hostname.
2. Must be configured to use ssh to login to the Proxmox node without a password.
### View the script options
```
$ bash pve_vm_manager.sh help
Usage: pve_vm_manager.sh [OPTIONS]

Available options:

create        create the vm based on the setenvVar parameter.
start         start all vm.
reboot        reboot all vm.
stop          stop all vm.
delete        delete all vm.
logs          show the complete execution process log.
deploy        deploy kind k8s environment to the vm.
snapshot      snapshot all vm.
status        show all vm status.
dimg          download the image to all the vm,image tar named images.tar.
debug         show execute command log.
help          display this help and exit.
```

### Create vm
```
$ bash pve_vm_manager.sh create
[Stage: Check Environment]
=====Check Environment Success=====
[Stage: Create VM]
=====create vm 600 success=====
=====create vm 601 success=====
=====create vm 602 success=====
=====create vm 603 success=====
```
### Start vm
```
$ bash pve_vm_manager.sh start
[Stage: Start VM]
=====start vm 600=====
=====start vm 601=====
=====start vm 602=====
=====start vm 603=====
```
### Reboot vm
```
$ bash pve_vm_manager.sh reboot
[Stage: Reboot VM]
=====reboot vm 600 completed=====
=====reboot vm 601 completed=====
=====reboot vm 602 completed=====
=====reboot vm 603 completed=====
```
### Stop vm
```
$ bash pve_vm_manager.sh stop
[Stage: Stop VM]
=====stop vm 600 completed=====
=====stop vm 601 completed=====
=====stop vm 602 completed=====
=====stop vm 603 completed=====
```
### Delete vm
```
$ bash pve_vm_manager.sh delete
[Stage: Delete VM]
=====delete vm 600 completed=====
=====delete vm 601 completed=====
=====delete vm 602 completed=====
=====delete vm 603 completed=====
=====delete /tmp/pve_execute_command.log completed=====
=====delete /tmp/pve_vm_manager.log completed=====
=====delete nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 completed=====
```
### Show status
```
$ bash pve_vm_manager.sh status
[Stage: Show VM status]
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID
       600 alp-600              stopped    4096              50.00 0
       601 alp-601              stopped    4096              50.00 0
       602 alp-602              stopped    4096              50.00 0
       603 alp-603              stopped    4096              50.00 0
```
### Deploy kind k8s environment to the vm
```
$ bash pve_vm_manager.sh deploy
[Stage: Deploy kind environment to the VM]
=====deploy kind k8s environment to the vm 600 completed=====
=====vm 600 is rebooting=====
=====deploy kind k8s environment to the vm 601 completed=====
=====vm 601 is rebooting=====
=====deploy kind k8s environment to the vm 602 completed=====
=====vm 602 is rebooting=====
=====deploy kind k8s environment to the vm 603 completed=====
=====vm 603 is rebooting=====
[Stage: Snapshot the VM]
=====snapshot vm 600 completed=====
=====snapshot vm 601 completed=====
=====snapshot vm 602 completed=====
=====snapshot vm 603 completed=====
```
### Snapshot vm
```
$ bash pve_vm_manager.sh snapshot
[Stage: Snapshot VM]
=====snapshot vm 600 completed=====
=====snapshot vm 601 completed=====
=====snapshot vm 602 completed=====
=====snapshot vm 603 completed=====
```
### Download image to all the vm
```
$ bash pve_vm_manager.sh dimg
[Stage: Download images from images.txt to VM]
=====scp images.tar on 600 success=====
=====scp images.tar on 601 success=====
=====scp images.tar on 602 success=====
=====scp images.tar on 603 success=====
[Stage: Delete images]
=====delete images success=====
```
### Show logs
```
$ bash pve_vm_manager.sh logs
......
```
### Login vm
#### account/password: bigred/bigred
![image](https://github.com/cooloo9871/Proxmox_vm_manager/assets/62133915/2da5eef1-0431-47eb-876d-82226997be0f)
```
$ ssh bigred@192.168.61.110
bigred@192.168.61.110's password:
Welcome to Alpine!

The Alpine Wiki contains a large amount of how-to guides and general
information about administrating Alpine systems.
See <https://wiki.alpinelinux.org>.

Alpine release notes:
* <https://alpinelinux.org/posts/Alpine-3.19.1-released.html>

NOTE: 'sudo' is not installed by default, please use 'doas' instead.

You may change this message by editing /etc/motd.
```

## VM spec
- CPU: 4C
- Memory: 4G
- Disk: 50G
- Network: vmbr0
- Storage: local-lvm

![image](https://github.com/cooloo9871/Proxmox_vm_manager/assets/62133915/953ed351-036c-4636-9917-8ce9a0d6c76a)
