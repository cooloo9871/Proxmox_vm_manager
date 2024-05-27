#!/bin/bash

#set -x

source ./setenvVar

RED='\033[1;31m' # alarm
GRN='\033[1;32m' # notice
YEL='\033[1;33m' # warning
NC='\033[0m' # No Color
ipstart=$(echo $VM_ip | cut -d '~' -f 1)
ipend=$(echo $VM_ip | cut -d '~' -f 2)
idstart=$(echo $VM_id | cut -d '~' -f 1)
idend=$(echo $VM_id | cut -d '~' -f 2)

printf "${GRN}[Stage: Download images from images.txt to VM]${NC}\n"
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

sudo podman save -m $(cat ./images.txt | grep -v '#' | tr '\n' ' ') | gzip --stdout > images.tar.gz

for ((a=$idstart,b=$ipstart;a<=$idend,b<=$ipend;a++,b++))
do
  sshpass -p "$PASSWORD" scp -o "StrictHostKeyChecking no" -o ConnectTimeout=5 ./images.tar.gz "$USER"@"$VM_netid.$b":/home/"$USER"/images.tar.gz &>/dev/null
  if [[ "$?" == '0' ]]; then
    printf "${GRN}=====scp images.tar.gz on $a success=====${NC}\n"
  else
    printf "${RED}=====scp images.tar.gz on $a fail=====${NC}\n"
  fi
done

printf "${GRN}[Stage: Delete images]${NC}\n"

sudo rm images.tar.gz
sudo podman image prune -a -f &>> /tmp/pve_vm_manager.log
[[ "$?" == "0" ]] && printf "${GRN}=====delete images success=====${NC}\n"
