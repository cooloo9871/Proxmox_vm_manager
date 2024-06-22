#!/bin/bash

RED='\033[1;31m' # alarm
GRN='\033[1;32m' # notice
YEL='\033[1;33m' # warning
NC='\033[0m' # No Color

# function
# debug mode
Debug() {
  ### output log
  [[ -f ~/.ssh/known_hosts ]] && rm ~/.ssh/known_hosts
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
    ssh -q -o BatchMode=yes -o "StrictHostKeyChecking no" root@"$n" '/bin/true' &> /dev/null
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
    ssh -q -o BatchMode=yes -o "StrictHostKeyChecking no" root@"$i" '/bin/true' &> /dev/null
    [[ "$?" != "0" ]] && printf "${RED}Must be configured to use hostname to ssh login to the Proxmox $i.${NC}\n" && exit 1
  done

  ### check vm id
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((f=$idstart;f<=$idend;f++))
  do
    for c in ${NODE_HOSTNAME[@]}
    do
      ssh -q root@"$c" qm list | awk '{print $1}' | grep -v VMID | grep "$f" &>/dev/null
      if [[ "$?" == "0" ]]; then
        printf "${RED}=====$f VM ID Already used=====${NC}\n" && exit 1
      fi
    done
  done

  ### check vm ip
  ipstart=$(echo $VM_ip | cut -d '~' -f 1)
  ipend=$(echo $VM_ip | cut -d '~' -f 2)
  for ((g=$ipstart;g<=$ipend;g++))
  do
    ping -c 1 -W 1 $VM_netid.$g &>/dev/null
    if [[ "$?" == "0" ]]; then
      printf "${RED}=====$VM_netid.$g VM IP Already used=====${NC}\n" && exit 1
    fi
  done

  ### check ip & id the quantities
  id_range=$((idend - idstart + 1))
  ip_range=$((ipend - ipstart + 1))
  [[ "$id_range" != "$ip_range" ]] && printf "${RED}=====vm id & vm ip discrepancy in quantity=====${NC}\n" && exit 1

  ### check command
  ssh -q root@"$EXECUTE_NODE" which virt-customize >/dev/null
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
    if [[ ! -f /var/vmimg/nocloud_alpine.qcow2 ]]; then
      wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2 -O /var/vmimg/nocloud_alpine.qcow2
      if [[ "$?" != '0' ]]; then
        printf "${RED}=====download cloud init image fail=====${NC}\n" && exit 1
      fi
      virt-customize --install qemu-guest-agent,bash,sudo -a /var/vmimg/nocloud_alpine.qcow2
    fi
EOF

  for ((z=$idstart;z<=$idend;z++))
  do
    ssh root@"$EXECUTE_NODE" "qm create $z --name alp-$z --memory $MEM --sockets $CPU_socket --cores $CPU_core --cpu $CPU_type --net0 virtio,bridge=$Network_device" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm importdisk $z /var/vmimg/nocloud_alpine.qcow2 ${STORAGE}" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-$z-disk-0" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm resize $z scsi0 ${DISK}G" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --ide2 ${STORAGE}:cloudinit" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --boot c --bootdisk scsi0" &>> /tmp/pve_vm_manager.log
    ssh root@"$EXECUTE_NODE" "qm set $z --serial0 socket --vga serial0" &>> /tmp/pve_vm_manager.log
  done

  scp ./user.yml root@"$EXECUTE_NODE":"/var/lib/vz/snippets/user.yml" &>> /tmp/pve_vm_manager.log
  ssh root@"$EXECUTE_NODE" sed -i "s/NS/$NAMESERVER/g" "/var/lib/vz/snippets/user.yml" &>> /tmp/pve_vm_manager.log
  ssh root@"$EXECUTE_NODE" sed -i "s/AC/$USER/g" "/var/lib/vz/snippets/user.yml" &>> /tmp/pve_vm_manager.log
  ssh root@"$EXECUTE_NODE" sed -i "s/PW/$PASSWORD/g" "/var/lib/vz/snippets/user.yml" &>> /tmp/pve_vm_manager.log

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
    ssh root@"$EXECUTE_NODE" qm set "$c" --cicustom "user=local:snippets/user.yml,network=local:snippets/network$c.yml" &>> /tmp/pve_vm_manager.log
    printf "${GRN}=====create vm $c success=====${NC}\n"
  done
}

start_vm() {
  printf "${GRN}[Stage: Start VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((d=$idstart;d<=$idend;d++))
  do
    if ! ssh -q -o "StrictHostKeyChecking no" root@"$EXECUTE_NODE" qm list | grep "$d" &>/dev/null; then
      printf "${RED}=====vm $d not found=====${NC}\n"
    elif
      ssh -q -o "StrictHostKeyChecking no" root@"$EXECUTE_NODE" qm list | grep "$d" | grep 'running' &>/dev/null; then
      printf "${YEL}=====vm $d already running=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm start "$d" &>> /tmp/pve_vm_manager.log
      sleep 10
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
    if ! ssh -q -o "StrictHostKeyChecking no" root@"$EXECUTE_NODE" qm list | grep "$e" &>/dev/null; then
      printf "${RED}=====vm $e not found=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm stop "$e" &>> /tmp/pve_vm_manager.log
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
    if ! ssh -q -o "StrictHostKeyChecking no" root@"$EXECUTE_NODE" qm list | grep "$h" &>/dev/null; then
      printf "${RED}=====vm $h not found=====${NC}\n"
    elif ssh root@"$EXECUTE_NODE" qm list | grep "$h" | grep running &>/dev/null; then
      printf "${RED}=====stop vm $h first=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm destroy "$h" &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====delete vm $h completed=====${NC}\n"
    fi
  done
  [[ -f /tmp/pve_execute_command.log ]] && rm /tmp/pve_execute_command.log && printf "${GRN}=====delete /tmp/pve_execute_command.log completed=====${NC}\n"
  [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log && printf "${GRN}=====delete /tmp/pve_vm_manager.log completed=====${NC}\n"
  ssh root@"$EXECUTE_NODE" rm /var/vmimg/nocloud_alpine.qcow2 &>/dev/null && printf "${GRN}=====delete nocloud_alpine.qcow2 completed=====${NC}\n"
  ssh root@"$EXECUTE_NODE" rm '/var/lib/vz/snippets/*' &>/dev/null && printf "${GRN}=====delete cloud init yml completed=====${NC}\n"
}

reboot_vm() {
  printf "${GRN}[Stage: Reboot VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((j=$idstart;j<=$idend;j++))
  do
    if ! ssh -q -o "StrictHostKeyChecking no" root@"$EXECUTE_NODE" qm list | grep "$j" &>/dev/null; then
      printf "${RED}=====vm $j not found=====${NC}\n"
    elif ! ssh root@"$EXECUTE_NODE" qm list | grep "$j" | grep running &>/dev/null; then
      printf "${RED}=====vm $j not running=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm reboot "$j" &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====reboot vm $j completed=====${NC}\n"
    fi
  done
}

log_vm() {
  if [[ ! -f '/tmp/pve_vm_manager.log' ]]; then
    printf "${RED}=====log not found=====${NC}\n"
    exit 1
  else
    cat /tmp/pve_vm_manager.log
  fi
}

debug_vm() {
  if [[ ! -f '/tmp/pve_execute_command.log' ]]; then
    printf "${RED}=====log not found=====${NC}\n"
    exit 1
  else
    cat /tmp/pve_execute_command.log
  fi
}


dep_kind() {
  printf "${GRN}[Stage: Deploy kind k8s environment to the VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  ipstart=$(echo $VM_ip | cut -d '~' -f 1)
  ipend=$(echo $VM_ip | cut -d '~' -f 2)

  ### check command
  if ! which sshpass &>/dev/null; then
    printf "${RED}=====sshpass command not found,please install on localhost=====${NC}\n"
  exit 1
  fi

  ### check alp-kind-env.sh file
  if [[ ! -f ./alp-kind-env.sh ]]; then
    printf "${RED}=====alp-kind-env.sh file not found=====${NC}\n"
    exit 1
  fi

  for ((l=$idstart,m=$ipstart;l<=$idend,m<=$ipend;l++,m++))
  do
    if ! ssh -q -o "StrictHostKeyChecking no" root@"$EXECUTE_NODE" qm list | grep "$l" &>/dev/null; then
      printf "${RED}=====vm $l not found=====${NC}\n"
    elif ! ssh root@"$EXECUTE_NODE" qm list | grep "$l" | grep running &>/dev/null; then
      printf "${RED}=====vm $l not running=====${NC}\n"
    else
      sshpass -p "$PASSWORD" scp -o "StrictHostKeyChecking no" -o ConnectTimeout=5 ./alp-kind-env.sh "$USER"@"$VM_netid.$m":/home/"$USER"/alp-kind-env.sh &>> /tmp/pve_vm_manager.log && \
      sshpass -p "$PASSWORD" ssh "$USER"@"$VM_netid.$m" bash /home/"$USER"/alp-kind-env.sh &>> /tmp/pve_vm_manager.log && \
      sshpass -p "$PASSWORD" ssh "$USER"@"$VM_netid.$m" rm /home/"$USER"/alp-kind-env.sh
      if [[ "$?" == "0" ]]; then
        printf "${GRN}=====deploy kind k8s environment to the vm $l completed=====${NC}\n"
        printf "${GRN}=====vm $l is rebooting=====${NC}\n"
      else
        printf "${RED}=====deploy kind k8s environment to the vm $l fail=====${NC}\n"
      fi
    fi
  done

  sleep 40

  printf "${GRN}[Stage: Snapshot the VM]${NC}\n"
  for ((l=$idstart;l<=$idend;l++))
  do
    if ! ssh root@"$EXECUTE_NODE" qm list | grep "$l" &>/dev/null; then
      printf "${RED}=====vm $l not found=====${NC}\n"
    elif ! ssh root@"$EXECUTE_NODE" qm list | grep "$l" | grep running &>/dev/null; then
      printf "${RED}=====vm $l not running=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm snapshot "$l" kindenv-first-snapshot &>> /tmp/pve_vm_manager.log
      if [[ "$?" == "0" ]]; then
        printf "${GRN}=====snapshot vm $l completed=====${NC}\n"
      else
        printf "${RED}=====snapshot vm $l fail=====${NC}\n"
      fi
    fi
  done
}

snapshot_vm() {
  printf "${GRN}[Stage: Snapshot VM]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  for ((n=$idstart;n<=$idend;n++))
  do
    if ! ssh -q -o "StrictHostKeyChecking no" root@"$EXECUTE_NODE" qm list | grep "$n" &>/dev/null; then
      printf "${RED}=====vm $n not found=====${NC}\n"
    else
      ssh root@"$EXECUTE_NODE" qm snapshot "$n" snapshot-"$(date +"%Y-%m-%d_%H-%M-%S")" &>> /tmp/pve_vm_manager.log
      printf "${GRN}=====snapshot vm $n completed=====${NC}\n"
    fi
  done
}

status_vm() {
  printf "${GRN}[Stage: Show VM status]${NC}\n"
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)
  ssh -q -o "StrictHostKeyChecking no" root@"$EXECUTE_NODE" qm list | head -n 1
  for ((o=$idstart;o<=$idend;o++))
  do
    if ! ssh -q -o "StrictHostKeyChecking no" root@"$EXECUTE_NODE" qm list | grep "$o"; then
      printf "${RED}       $o not found${NC}\n"
    fi
  done
}

downloadimg_vm() {
  ipstart=$(echo $VM_ip | cut -d '~' -f 1)
  ipend=$(echo $VM_ip | cut -d '~' -f 2)
  idstart=$(echo $VM_id | cut -d '~' -f 1)
  idend=$(echo $VM_id | cut -d '~' -f 2)

  printf "${GRN}[Stage: Download images from images.txt to VM]${NC}\n"
  [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
  [[ ! -f ./images.txt ]] && printf "${RED}=====images.txt not found=====${NC}\n" && exit 1

  if ! which podman &>/dev/null; then
    printf "${RED}=====podman command not found,please install on localhost=====${NC}\n"
    exit 1
  fi

  if ! which sshpass &>/dev/null; then
    printf "${RED}=====sshpass command not found,please install on localhost=====${NC}\n"
    exit 1
  fi

  while read img
  do
    sudo podman pull $img &>> /tmp/pve_vm_manager.log
  done < <(cat ./images.txt | grep -v '#')

  sudo podman save -m $(cat ./images.txt | grep -v '#' | tr '\n' ' ') > images.tar

  for ((a=$idstart,b=$ipstart;a<=$idend,b<=$ipend;a++,b++))
  do
    sshpass -p "$PASSWORD" scp -q -o "StrictHostKeyChecking no" -o ConnectTimeout=5 ./images.tar "$USER"@"$VM_netid.$b":/home/"$USER"/images.tar &>/dev/null
    if [[ "$?" == '0' ]]; then
      printf "${GRN}=====scp images.tar on $a success=====${NC}\n"
    else
      printf "${RED}=====scp images.tar on $a fail=====${NC}\n"
    fi
  done

  printf "${GRN}[Stage: Delete images]${NC}\n"

  sudo rm images.tar && \
  sudo podman image prune -a -f &>> /tmp/pve_vm_manager.log
  [[ "$?" == "0" ]] && printf "${GRN}=====delete images success=====${NC}\n" || printf "${RED}=====delete images fail=====${NC}\n"
}

help() {
  cat <<EOF
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
    deploy)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      dep_kind
    ;;
    snapshot)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      snapshot_vm
    ;;
    status)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      status_vm
    ;;
    dimg)
      Debug
      source ./setenvVar
      [[ -f /tmp/pve_vm_manager.log ]] && rm /tmp/pve_vm_manager.log
      downloadimg_vm
    ;;
    logs)
      log_vm
    ;;
    debug)
      debug_vm
    ;;
    *)
      help
    ;;
  esac
fi
