#!/bin/bash

set -x

RED='\033[1;31m' # alarm
GRN='\033[1;32m' # notice
YEL='\033[1;33m' # warning
NC='\033[0m' # No Color

download_img() {
  printf "${GRN}[Stage: Download images from images.txt to VM]${NC}\n"
  [[ ! -f ./images.txt ]] && printf "${RED}=====images.txt not found=====${NC}\n" && exit 1
  ipstart=$(echo $VM_ip | cut -d '~' -f 1)
  ipend=$(echo $VM_ip | cut -d '~' -f 2)
  if ! which podman &>/dev/null; then
    printf "${RED}=====podman command not found,please install on localhost=====${NC}\n"
    exit 1
  fi

  while read img
  do
    sudo podman pull $img &>> /tmp/pve_vm_manager.log
  done < <(cat ./images.txt | grep -v '#')

  sudo podman save -m $(cat ./images.txt | grep -v '#' | tr '\n' ' ') | gzip --stdout > images.tar.gz

  for ((k=$ipstart;k<=$ipend;k++))
  do
    sshpass -p bigred scp -o "StrictHostKeyChecking no" ./images.tar.gz bigred@"$VM_netid.$k":/home/bigred/images.tar.gz
    if [[ "$?" == '0' ]]; then
      printf "${GRN}=====scp images.tar.gz on $k success=====${NC}\n"
    else
      printf "${RED}=====scp images.tar.gz on $k fail=====${NC}\n"
    fi
  done

  printf "${GRN}[Stage: Delete images]${NC}\n"
  sudo rm images.tar.gz
  sudo podman image prune -a -f &>> /tmp/pve_vm_manager.log
  [[ "$?" == "0" ]] && printf "${GRN}=====delete images success=====${NC}\n"

}

source ./setenvVar

download_img
