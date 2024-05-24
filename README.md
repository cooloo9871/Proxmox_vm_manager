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
export NODE_1_IP="192.168.1.3"
export NODE_2_IP="192.168.1.4"
export NODE_3_IP="192.168.1.5"
export NODE_hostname1="p1"
export NODE_hostname2="p2"
export NODE_hostname3="p3"
# The EXECUTE_NODE parameter specifies the proxmox node on which to manage the vm.
export EXECUTE_NODE="p2"

# Set VM Env
# Please make sure that the vm id and vm ip is not conflicting.
export VM_id="600~603"
export VM_netid="192.168.61"
export VM_ip="110~113"
export NETMASK="255.255.255.0"
export GATEWAY="192.168.61.2"
export NAMESERVER="8.8.8.8"
```

### View the script options
```
$ bash pve_vm_manager.sh help
Usage: pve_vm_manager.sh [OPTIONS]

Available options:

create    create the vm based on the setenvVar parameter.
start     start all vm.
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
```
### Login vm
#### account/password: bigred/bigred
![image](https://github.com/cooloo9871/Proxmox_vm_manager/assets/62133915/00a91b90-5ebf-4a60-a45a-b5572c359ef6)
