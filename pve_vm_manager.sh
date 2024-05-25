#!/bin/bash

RED='\033[1;31m' # alarm
GRN='\033[1;32m' # notice
YEL='\033[1;33m' # warning
NC='\033[0m' # No Color

# function#!/bin/bash

RED='\033[1;31m' # alarm
GRN='\033[1;32m' # notice
YEL='\033[1;33m' # warning
NC='\033[0m' # No Color

# function
# debug mode
Debug() {
  ### output log
  [[ -f /tmp/pve_execute_command.log ]] && rm /tmp/pve_execute_command.log
  exec {BASH_XTRACEFD}>> /tmp/pve_execute_command.log
  set -x
  #set -o pipefail
}

# check environment
check_env() {
  printf "${GRN}[Stage: Check Environment]${NC}\n"
  [[ ! -f ./setenvVar ]] && printf "${RED}setenvVar file not found${NC}\n" && exit 1
  var_names=$(cat setenvVar | grep -v '#' | cut -d " " -f 2 | cut -d "=" -f 1 | tr -s "\n" " " | sed 's/[ \t]*$//g')
  for var_name in ${var_names[@]}
  do
    [ -z "${!var_name}" ] && printf "${RED}$var_name is unset.${NC}\n" && exit 1
  done

  ### check ssh login to Proxmox node without password
  for n in ${NODE_IP[@]}
  do
    ssh -o BatchMode=yes -o "StrictHostKeyChecking no" root@"$n" '/bin/true' &> /dev/null
    if [[ "$?" != "0" ]]; then
      printf "${RED}Must be configured to use ssh to login to the Proxmox node1 without a password.${NC}\n"
      printf "${YEL}=====Run this command: ssh-keygen -t rsa -P ''=====${NC}\n"
      printf "${YEL}=====Run this command: ssh-copy-id root@"$n"=====${NC}\n"
      exit 1
    fi
  done

  ### check ssh login to Proxmox node use hostname
  for i in ${NODE_HOSTNAME[@]}
  do
    ssh -o BatchMode=yes -o "StrictHostKeyChecking no" root@"$i" '/bin/true' &> /dev/null
    [[ "$?" != "0" ]] && printf "${RED}Must be configured to use hostname to ssh login to the Proxmox $i.${NC}\n" && exit 1
  done

  ### check vm id
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  used=$(ssh root@"$EXECUTE_NODE" qm list | awk '{print $1}' | grep -v VMID)
  for ((f=$idstart;f<=$idend;f++))
  do
    echo "$used" | grep "$f" &>/dev/null
    if [[ "$?" == "0" ]]; then
      printf "${RED}=====$f VM ID Already used=====${NC}\n" && exit 1
    fi
  done

  ### check vm ip
  ipstart=$(echo $VM_ip | cut -d '~' -f 1)
  ipend=$(echo $VM_ip | cut -d '~' -f 2)
  for ((g=$ipstart;g<=$ipend;g++))
  do
    ping -c 1 $VM_netid.$g &>/dev/null
    if [[ "$?" == "0" ]]; then
      printf "${RED}=====$VM_netid.$g VM IP Already used=====${NC}\n" && exit 1
    fi
  done

  ### check command
  ssh root@"$EXECUTE_NODE" which virt-customize >/dev/null
  if [[ ! "$?" == "0" ]]; then
    printf "${RED}=====Please install virt-customize on $EXECUTE_NODE=====${NC}\n"
    printf "${YEL}=====Run this command on $EXECUTE_NODE: sudo apt install -y libguestfs-tools=====${NC}\n"
    exit 1
  else
    printf "${GRN}=====Check Environment Success=====${NC}\n"
  fi
}


# create VM
create_vm() {
  printf "${GRN}[Stage: Create VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  ipstart=$(echo $VM_ip | cut -d '~' -f 1)
  ipend=$(echo $VM_ip | cut -d '~' -f 2)

  ssh root@"$EXECUTE_NODE" /bin/bash << EOF &>> /tmp/pve_vm_manager.log
    if [[ ! -d /var/vmimg/ ]]; then
      mkdir /var/vmimg/
    fi
    if [[ ! -d /var/lib/vz/snippets/ ]]; then
      mkdir -p /var/lib/vz/snippets/
    fi
    if [[ ! -f /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 ]]; then
      wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 -O /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2
      virt-customize --install qemu-guest-agent -a /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2
      virt-customize --install bash -a /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2
      virt-customize --install sudo -a /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2
    fi
EOF

  for ((z=$idstart;z<=$idend;z++))
  do
    ssh root@"$EXECUTE_NODE" "qm create $z --name alp-$z --memory $MEM --sockets $CPU_socket --cores $CPU_core --net0 virtio,bridge=$Network_device" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm importdisk $z /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 ${STORAGE}" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-$z-disk-0" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm resize $z scsi0 ${DISK}G" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --ide2 ${STORAGE}:cloudinit" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --boot c --bootdisk scsi0" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --serial0 socket --vga serial0" &>> /tmp/pve_vm_manager.log
  done

  scp ./user.yml root@"$EXECUTE_NODE":"/var/lib/vz/snippets/user.yml" &>> /tmp/pve_vm_manager.log
  ssh root@"$EXECUTE_NODE" sed -i "s/ns/$NAMESERVER/g" "/var/lib/vz/snippets/user.yml" &>> /tmp/pve_vm_manager.log
  for ((a=$idstart,b=$ipstart;a<=$idend,b<=$ipend;a++,b++))
  do
    scp ./network.yml root@"$EXECUTE_NODE":"/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" sed -i "s/netid/$VM_netid/g" "/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" sed -i "s/ip/$b/g" "/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" sed -i "s/nk/$NETMASK/g" "/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" sed -i "s/gw/$GATEWAY/g" "/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
  done

  for ((c=$idstart;c<=$idend;c++))
  do
    ssh root@"$EXECUTE_NODE" qm set $c --cicustom "user=local:snippets/user.yml,network=local:snippets/network$c.yml" &>> /tmp/pve_vm_manager.log
    printf "${GRN}=====create vm $c success=====${NC}\n"
  done
}

start_vm() {
  printf "${GRN}[Stage: Start VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((d=$idstart;d<=$idend;d++))
  do
    if ! ssh root@"$EXECUTE_NODE" qm list | grep "$d" &>/dev/null; then
      printf "${RED}=====vm $d not found=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm start $d &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====start vm $d=====${NC}\n"
    fi
  done
}

stop_vm() {
  printf "${GRN}[Stage: Stop VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((e=$idstart;e<=$idend;e++))
  do
    if ! ssh root@"$EXECUTE_NODE" qm list | grep "$e" &>/dev/null; then
      printf "${RED}=====vm $e not found=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm stop $e &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====stop vm $e completed=====${NC}\n"
    fi
  done
}

delete_vm() {
  printf "${GRN}[Stage: Delete VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((h=$idstart;h<=$idend;h++))
  do
    if ! ssh root@"$EXECUTE_NODE" qm list | grep "$h" &>/dev/null; then
      printf "${RED}=====vm $h not found=====${NC}\n"
    elif ssh root@"$EXECUTE_NODE" qm list | grep "$h" | grep running &>/dev/null; then
      printf "${RED}=====stop vm $h first=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm destroy $h &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====delete vm $h completed=====${NC}\n"
    fi
  done
  [[ -f /tmp/pve_execute_command.log ]] && rm /tmp/pve_execute_command.log && printf "${GRN}=====delete /tmp/pve_execute_command.log completed=====${NC}\n"
  [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log && printf "${GRN}=====delete /tmp/pve_vm_manager.log completed=====${NC}\n"
  ssh root@"$EXECUTE_NODE" rm /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 &>> /tmp/pve_vm_manager.log && printf "${GRN}=====delete nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 completed=====${NC}\n"
}

reboot_vm() {
  printf "${GRN}[Stage: Reboot VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((j=$idstart;j<=$idend;j++))
  do
    if ! ssh root@"$EXECUTE_NODE" qm list | grep "$j" &>/dev/null; then
      printf "${RED}=====vm $j not found=====${NC}\n"
    elif ! ssh root@"$EXECUTE_NODE" qm list | grep "$j" | grep running &>/dev/null; then
      printf "${RED}=====vm $j not running=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm reboot $j &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====reboot vm $j completed=====${NC}\n"
    fi
  done
}

log_vm() {
  if [[ ! -f '/tmp/pve_execute_command.log' ]]; then
    printf "${RED}=====log not found=====${NC}\n"
    exit 1
  else
    cat /tmp/pve_execute_command.log
  fi
}

help() {
  cat <<EOF
Usage: pve_vm_manager.sh [OPTIONS]

Available options:

create    create the vm based on the setenvVar parameter.
start     start all vm.
reboot    reboot all vm.
stop      stop all vm.
delete    delete all vm.
logs      show last execute command log.
help      display this help and exit.
EOF
  exit
}


if [[ "$#" < 1 ]]; then
  help
else
  case $1 in
    create)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      check_env
      create_vm
    ;;
    start)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      start_vm
    ;;
    stop)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      stop_vm
    ;;
    delete)
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      delete_vm
    ;;
    reboot)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      reboot_vm
    ;;
    logs)
      log_vm
    ;;
    *)
      help
    ;;
  esac
fi
# debug mode
Debug() {
  ### output log
  [[ -f /tmp/pve_execute_command.log ]] && rm /tmp/pve_execute_command.log
  exec {BASH_XTRACEFD}>> /tmp/pve_execute_command.log
  set -x
  #set -o pipefail
}

# check environment
check_env() {
  printf "${GRN}[Stage: Check Environment]${NC}\n"
  [[ ! -f ./setenvVar ]] && printf "${RED}setenvVar file not found${NC}\n" && exit 1
  var_names=$(cat setenvVar | grep -v '#' | cut -d " " -f 2 | cut -d "=" -f 1 | tr -s "\n" " " | sed 's/[ \t]*$//g')
  for var_name in ${var_names[@]}
  do
    [ -z "${!var_name}" ] && printf "${RED}$var_name is unset.${NC}\n" && exit 1
  done

  ### check ssh login to Proxmox node without password
  for n in ${NODE_IP[@]}
  do
    ssh -o BatchMode=yes -o "StrictHostKeyChecking no" root@"$n" '/bin/true' &> /dev/null
    if [[ "$?" != "0" ]]; then
      printf "${RED}Must be configured to use ssh to login to the Proxmox node1 without a password.${NC}\n"
      printf "${YEL}=====Run this command: ssh-keygen -t rsa -P ''=====${NC}\n"
      printf "${YEL}=====Run this command: ssh-copy-id root@"$n"=====${NC}\n"
      exit 1
    fi
  done

  ### check ssh login to Proxmox node use hostname
  for i in ${NODE_HOSTNAME[@]}
  do
    ssh -o BatchMode=yes -o "StrictHostKeyChecking no" root@"$i" '/bin/true' &> /dev/null
    [[ "$?" != "0" ]] && printf "${RED}Must be configured to use hostname to ssh login to the Proxmox $i.${NC}\n" && exit 1
  done

  ### check vm id
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  used=$(ssh root@"$EXECUTE_NODE" qm list | awk '{print $1}' | grep -v VMID)
  for ((f=$idstart;f<=$idend;f++))
  do
    echo "$used" | grep "$f" &>/dev/null
    if [[ "$?" == "0" ]]; then
      printf "${RED}=====$f VM ID Already used=====${NC}\n" && exit 1
    fi
  done

  ### check vm ip
  ipstart=$(echo $VM_ip | cut -d '~' -f 1)
  ipend=$(echo $VM_ip | cut -d '~' -f 2)
  for ((g=$ipstart;g<=$ipend;g++))
  do
    ping -c 1 $VM_netid.$g &>/dev/null
    if [[ "$?" == "0" ]]; then
      printf "${RED}=====$VM_netid.$g VM IP Already used=====${NC}\n" && exit 1
    fi
  done

  ### check command
  ssh root@"$EXECUTE_NODE" which virt-customize >/dev/null
  if [[ ! "$?" == "0" ]]; then
    printf "${RED}=====Please install virt-customize on $EXECUTE_NODE=====${NC}\n"
    printf "${YEL}=====Run this command on $EXECUTE_NODE: sudo apt install -y libguestfs-tools=====${NC}\n"
    exit 1
  else
    printf "${GRN}=====Check Environment Success=====${NC}\n"
  fi
}


# create VM
create_vm() {
  printf "${GRN}[Stage: Create VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  ipstart=$(echo $VM_ip | cut -d '~' -f 1)
  ipend=$(echo $VM_ip | cut -d '~' -f 2)

  ssh root@"$EXECUTE_NODE" /bin/bash << EOF &>> /tmp/pve_vm_manager.log
    if [[ ! -d /var/vmimg/ ]]; then
      mkdir /var/vmimg/
    fi
    if [[ ! -d /var/lib/vz/snippets/ ]]; then
      mkdir -p /var/lib/vz/snippets/
    fi
    if [[ ! -f /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 ]]; then
      wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 -O /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2
      virt-customize --install qemu-guest-agent -a /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2
      virt-customize --install bash -a /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2
      virt-customize --install sudo -a /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2
    fi
EOF

  for ((z=$idstart;z<=$idend;z++))
  do
    ssh root@"$EXECUTE_NODE" "qm create $z --name alp-$z --memory $MEM --sockets $CPU_socket --cores $CPU_core --net0 virtio,bridge=$Network_device" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm importdisk $z /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 ${STORAGE}" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-$z-disk-0" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm resize $z scsi0 ${DISK}G" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --ide2 ${STORAGE}:cloudinit" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --boot c --bootdisk scsi0" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --serial0 socket --vga serial0" &>> /tmp/pve_vm_manager.log
  done

  scp ./user.yml root@"$EXECUTE_NODE":"/var/lib/vz/snippets/user.yml" &>> /tmp/pve_vm_manager.log
  ssh root@"$EXECUTE_NODE" sed -i "s/ns/$NAMESERVER/g" "/var/lib/vz/snippets/user.yml" &>> /tmp/pve_vm_manager.log
  for ((a=$idstart,b=$ipstart;a<=$idend,b<=$ipend;a++,b++))
  do
    scp ./network.yml root@"$EXECUTE_NODE":"/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" sed -i "s/netid/$VM_netid/g" "/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" sed -i "s/ip/$b/g" "/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" sed -i "s/nk/$NETMASK/g" "/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" sed -i "s/gw/$GATEWAY/g" "/var/lib/vz/snippets/network$a.yml" &>> /tmp/pve_vm_manager.log
  done

  for ((c=$idstart;c<=$idend;c++))
  do
    ssh root@"$EXECUTE_NODE" qm set $c --cicustom "user=local:snippets/user.yml,network=local:snippets/network$c.yml" &>> /tmp/pve_vm_manager.log
    printf "${GRN}=====create vm $c success=====${NC}\n"
  done
}

start_vm() {
  printf "${GRN}[Stage: Start VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((d=$idstart;d<=$idend;d++))
  do
    if ! ssh root@"$EXECUTE_NODE" qm list | grep "$d" &>/dev/null; then
      printf "${RED}=====vm $d not found=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm start $d &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====start vm $d=====${NC}\n"
    fi
  done
}

stop_vm() {
  printf "${GRN}[Stage: Stop VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((e=$idstart;e<=$idend;e++))
  do
    if ! ssh root@"$EXECUTE_NODE" qm list | grep "$e" &>/dev/null; then
      printf "${RED}=====vm $e not found=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm stop $e &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====stop vm $e completed=====${NC}\n"
    fi
  done
}

delete_vm() {
  printf "${GRN}[Stage: Delete VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((h=$idstart;h<=$idend;h++))
  do
    if ! ssh root@"$EXECUTE_NODE" qm list | grep "$h" &>/dev/null; then
      printf "${RED}=====vm $h not found=====${NC}\n"
    elif ssh root@"$EXECUTE_NODE" qm list | grep "$h" | grep running &>/dev/null; then
      printf "${RED}=====stop vm $h first=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm destroy $h &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====delete vm $h completed=====${NC}\n"
    fi
  done
  ssh root@"$EXECUTE_NODE" rm /var/vmimg/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 &>> /tmp/pve_vm_manager.log && printf "${GRN}=====delete nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 completed=====${NC}\n"
}

reboot_vm() {
  printf "${GRN}[Stage: Reboot VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((j=$idstart;j<=$idend;j++))
  do
    if ! ssh root@"$EXECUTE_NODE" qm list | grep "$j" &>/dev/null; then
      printf "${RED}=====vm $j not found=====${NC}\n"
    elif ! ssh root@"$EXECUTE_NODE" qm list | grep "$j" | grep running &>/dev/null; then
      printf "${RED}=====vm $j not running=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm reboot $j &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====reboot vm $j completed=====${NC}\n"
    fi
  done
}

log_vm() {
  if [[ ! -f '/tmp/pve_execute_command.log' ]]; then
    printf "${RED}=====log not found=====${NC}\n"
    exit 1
  else
    cat /tmp/pve_execute_command.log
  fi
}

help() {
  cat <<EOF
Usage: pve_vm_manager.sh [OPTIONS]

Available options:

create    create the vm based on the setenvVar parameter.
start     start all vm.
reboot    reboot all vm.
stop      stop all vm.
delete    delete all vm.
logs      show last execute command log.
help      display this help and exit.
EOF
  exit
}


if [[ "$#" < 1 ]]; then
  help
else
  case $1 in
    create)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      check_env
      create_vm
    ;;
    start)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      start_vm
    ;;
    stop)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      stop_vm
    ;;
    delete)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      delete_vm
    ;;
    reboot)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      reboot_vm
    ;;
    logs)
      log_vm
    ;;
    *)
      help
    ;;
  esac
fi
