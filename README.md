# Proxmox_vm_manager
## This project is used to automate the implement of alpine linux vm in proxmox.
## Script usage
### Download script
```
git clone https://github.com/cooloo9871/Proxmox_vm_manager.git;cd Proxmox_vm_manager
```

### Setting the parameters
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

# Set VM Hardware Env
export CPU_socket="2"
export CPU_core="2"
export MEM="4096"
export Network_device="vmbr0"
export DISK="50"
export STORAGE="local-lvm"
```

### View the script options
```
$ bash pve_vm_manager.sh help
Usage: pve_vm_manager.sh [OPTIONS]

Available options:

create    create the vm based on the setenvVar parameter.
start     start all vm.
reboot    reboot all vm.
stop      stop all vm.
delete    delete all vm.
help      display this help and exit.
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
=====reboot vm completed=====
=====reboot vm completed=====
=====reboot vm  ompleted=====
=====reboot vm completed=====
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
=====delete nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 completed=====
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

![image](https://github.com/cooloo9871/Proxmox_vm_manager/assets/62133915/953ed351-036c-4636-9917-8ce9a0d6c76a)
