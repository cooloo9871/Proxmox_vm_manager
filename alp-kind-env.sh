#!/bin/bash

sudo apk update;sudo apk upgrade

sudo apk add tree unzip curl wget zip grep bash procps util-linux-misc dialog go udev jq sudo iproute2 net-tools aardvark-dns util-linux openrc alpine-base alpine-conf alpine-keys alsa-lib apk-tools argon2 autologin binutils bridge bridge-utils brotli c-ares capstone catatonit conmon containers-common crun cryptsetup lvm2 elinks encodings ethtool file findutils font-dejavu fontconfig fping freetype fstrm fts fuse gcc gcompat gdbm giflib glib gmp gnutls gpgme gnupg gpm hwids isl26 jansson java-cacerts java-common java-jffi json-c k9s keyutils krb5-conf krb5 kubernetes lcms2 lddtree acl libaio libassuan attr libbpf libbsd bzip2 libc-dev libcap-ng e2fsprogs openssl libeconf libedit elfutils expat libffi libfontenc libgcrypt libgpg-error libidn2 gettext libjpeg-turbo libksba openldap lksctp-tools libmd libmnl ncurses libnftnl libpng procps-ng cyrus-sasl libseccomp libslirp libtasn1 libucontext libunistring liburing libutempter libuv libverto libx11 libxau libxcb libxcomposite libxdmcp libxext libxi libxml2 libxrender iptables libxtst linux-pam linux-lts lz4 lzo mdev-conf mkfontscale mkinitfs mpc1 mpdecimal mpfr4 mtools musl-obstack musl mariadb nano netavark nettle nghttp2 npth nspr nss numactl oniguruma openblas pcre2 pcsc-lite perl perl-error git pinentry pixman pkgconf protobuf-c readline pax-utils screen skalibs slirp4netns snappy sqlite sshpass busybox syslinux utmps vde2 xz yajl zlib zstd podman

sudo rc-update add local

sudo rc-update add cgroups

sudo rc-service cgroups start

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64 && \
chmod +x ./kind && \
sudo mv ./kind /usr/local/bin/kind && \
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
sudo rm -r kubectl

mkdir ~/cni/ && \
curl -sL "$(curl -sL https://api.github.com/repos/containernetworking/plugins/releases/latest | jq -r '.assets[].browser_download_url' | grep 'linux-amd64.*.tgz$')" -o ~/cni/cni-plugins.tgz && \
tar xf ~/cni/cni-plugins.tgz -C ~/cni; rm ~/cni/cni-plugins.tgz


cat <<EOF | sudo tee /etc/profile
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PAGER=less
export PS1='\h:\w\$ '
umask 022

for script in /etc/profile.d/*.sh ; do
        if [ -r $script ] ; then
                . $script
        fi
done

# Alpine 的啟動系統是 openrc, 登入前會執行 /etc/local.d/rc.local.start, 登入後會執行 /etc/profile
gw=\$(route -n | grep -e "^0.0.0.0 ")
export GWIF=\${gw##* }
ips=\$(ifconfig $GWIF | grep 'inet ')
export IP=\$(echo $ips | cut -d' ' -f2 | cut -d':' -f2)
export NETID=\${IP%.*}
export GW=\$(route -n | grep -e '^0.0.0.0' | tr -s \ - | cut -d ' ' -f2)
export PATH="/home/bigred/bin:/home/bigred/vmalpdt/bin:$PATH"
# source /home/bigred/bin/myk3s
clear && sleep 2
echo "Welcome to Alpine Linux : `cat /etc/alpine-release`"
[ "$IP" != "" ] && echo "IP : $IP"
echo ""

#if [ "$USER" == "bigred" ]; then
  # change hostname & set IP
  # sudo /home/bigred/bin/chnameip

  # create join k3s command
  #which kubectl &>/dev/null
  #if [ "$?" == "0" ]; then
  #   if [ -z "$SSH_TTY" ]; then
  #      echo "K3S Starting, pls wait 30 sec" && sleep 30
  #      kubectl get nodes 2>/dev/null | grep master | grep `hostname` &>/dev/null
  #      if [ "$?" == "0" ]; then
  #         echo "sudo curl -sfL https://get.k3s.io | K3S_URL=https://$IP:6443 K3S_TOKEN=`sudo cat /var/lib/rancher/k3s/server/node-token` K3S_KUBECONFIG_MODE='644' sh - && sudo reboot" > /home/bigred/bin/joink3s
  #         chmod +x /home/bigred/bin/joink3s
  #      fi
  #   fi
  #fi
#fi

export PS1="[\${STY#*.}]\u@\h:\w$ "
alias ping='ping -c 4 '
alias pingdup='sudo arping -D -I eth0 -c 2 '
alias dir='ls -alh '
alias poweroff='sudo poweroff; sleep 5'
alias reboot='sudo reboot; sleep 5'
alias kg='kubectl get'
alias ka='kubectl apply'
alias kd='kubectl delete'
alias kc='kubectl create'
alias ks='kubectl get pods -n kube-system'
alias docker='sudo podman'
alias pc='sudo podman system prune -a -f'

[ -f /home/bigred/dt/alpine.bash ] && source /home/bigred/dt/alpine.bash

# /etc/local.d/rc.local.start (相當於 rc.local) create /tmp/sinfo
if [ -z "$SSH_TTY" ]; then
   [ -f /tmp/sinfo ] && dialog --title " Cloud Native Trainer " --textbox /tmp/sinfo 24 85; clear
fi

docker ps -a | grep -e "Up.*c27" &>/dev/null
[ "$?" == "0" ] && export c27="true" && echo "c27 Up"

docker ps -a | grep -e "Up.*c24" &>/dev/null
[ "$?" == "0" ] && export c24="true" && echo "c24 Up"

docker ps -a | grep -e "Up.*c28" &>/dev/null
[ "$?" == "0" ] && export c28="true" && echo "c28 Up"

docker ps -a | grep -e "Up.*c29" &>/dev/null
[ "$?" == "0" ] && export c29="true" && echo "c29 Up"

export KIND_EXPERIMENTAL_PROVIDER='podman kind create cluster'
export C24=\$(docker ps -a | grep -o -e "c24-[a-z]*[-]*[a-z]*" | tr '\n' ' ')
export C27=\$(docker ps -a | grep -o -e "c27-[a-z]*[-]*[a-z]*[1-9]*" | tr '\n' ' ')
export C28=\$(docker ps -a | grep -o -e "c28-[a-z]*[-]*[a-z]*" | tr '\n' ' ')
export C29=\$(docker ps -a | grep -o -e "c29-[a-z]*[-]*[a-z]*[1-9]*" | tr '\n' ' ')

alias c24gm='([ "\$c24" != "true" ] && [ "\$c27" != "true" ]) && docker start \$C24 && c24="true"'
alias c24gn='[ "\$c24" == "true" ] && docker stop \$C24 && c24=""'
alias c27gm='([ "\$c24" != "true" ] && [ "\$c27" != "true" ]) && docker start \$C27 && c27="true"'
alias c27gn='[ "\$c27" == "true" ] && docker stop \$C27 && c27=""'
alias c27adm='[ "\$c27" == "true" ] && docker exec -it c27-control-plane bash'
alias c24adm='[ "\$c24" == "true" ] && docker exec -it c24-control-plane bash'

alias c28gm='([ "\$c28" != "true" ] && [ "\$c29" != "true" ]) && docker start \$C28 && c28="true"'
alias c28gn='[ "\$c28" == "true" ] && docker stop \$C28 && c28=""'
alias c29gm='([ "\$c28" != "true" ] && [ "\$c29" != "true" ]) && docker start \$C29 && c29="true"'
alias c29gn='[ "\$c29" == "true" ] && docker stop \$C29 && c29=""'
alias c29adm='[ "\$c29" == "true" ] && docker exec -it c29-control-plane bash'
alias c28adm='[ "\$c28" == "true" ] && docker exec -it c28-control-plane bash'

alias kup='([ "\$c28" == "true" ] && echo "c28 Up") || ([ "\$c29" == "true" ] && echo "c29 Up")'

alias vms='sudo /usr/bin/vmware-toolbox-cmd disk shrink /'
EOF

cat <<EOF | sudo tee /etc/local.d/rc.local.start
#!/bin/bash
gw=\$(route -n | grep -e "^0.0.0.0 ")
export GWIF=\${gw##* }
ips=\$(ifconfig $GWIF | grep 'inet ')
export IP=$\(echo $ips | cut -d' ' -f2 | cut -d':' -f2)
export NETID=\${IP%.*}
export GW=\$(route -n | grep -e '^0.0.0.0' | tr -s \ - | cut -d ' ' -f2)

echo "[System]" > /tmp/sinfo
echo "Hostname : `hostname`" >> /tmp/sinfo

m=$(free -mh | grep Mem: | tr -s ' ' | cut -d' ' -f2)
echo "Memory : \${m}M" >> /tmp/sinfo

cname=\$(cat /proc/cpuinfo | grep 'model name' | head -n 1 | cut -d ':' -f2)
cnumber=\$(cat /proc/cpuinfo | grep 'model name' | wc -l)
echo "CPU : \$cname (core: \$cnumber)" >> /tmp/sinfo

m=\$(df -h | grep /dev/sda)
ds=\$(echo \$m | cut -d ' ' -f2)
echo "Disk : \$ds" >> /tmp/sinfo

which kubectl &>/dev/null
if [ "$?" == "0" ]; then
   #v=\$(kubectl version --short | head -n 1 | cut -d ":" -f2 | tr -d ' ')
   echo "Kubernetes: enabled" >> /tmp/sinfo
fi

echo "" >> /tmp/sinfo

echo "[Network]" >> /tmp/sinfo
echo "IP : \$IP" >> /tmp/sinfo
echo "Gateway : \$GW" >> /tmp/sinfo
cat /etc/resolv.conf | grep 'nameserver' | head -n 1 >> /tmp/sinfo

/bin/ping -c 1 www.hinet.net
[ "$?" == "0" ] && echo "Internet OK" >> /tmp/sinfo

modprobe tun
modprobe fuse
mount --make-rshared /
modprobe br_netfilter
modprobe ip_tables
EOF

sudo chmod +x /etc/local.d/rc.local.start

sudo reboot
