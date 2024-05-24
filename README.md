# Proxmox_vm_manager


```
git clone https://github.com/cooloo9871/Proxmox_vm_manager.git;cd Proxmox_vm_manager
```

```
$ nano setenvVar
# Set Proxmox Cluster Env
export NODE_1_IP="192.168.21.2"
export NODE_2_IP="192.168.21.3"
export NODE_3_IP="192.168.21.4"

# Specify which node of the proxmox you want to implement the vm on.
export EXECUTE_NODE="pve2"

# Set VM Env
# Please make sure that the vm id and vm ip is not conflicting.
export VM_id="601~603"
export VM_netid="192.168.11"
export VM_ip="150~152"
export NETMASK="255.255.255.0"
export GATEWAY="192.168.11.254"
export NAMESERVER="8.8.8.8"
```

```
$ bash pve_vm_manager.sh create
```

