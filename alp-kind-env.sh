#!/bin/bash

sudo apk update;sudo apk upgrade

sudo apk add tree unzip open-vm-tools curl wget zip grep bash procps util-linux-misc dialog go udev jq sudo iproute2 net-tools aardvark-dns util-linux openrc alpine-base alpine-conf alpine-keys alsa-lib apk-tools argon2 autologin binutils bridge bridge-utils brotli c-ares capstone catatonit conmon containers-common crun cryptsetup lvm2 elinks encodings ethtool file findutils font-dejavu fontconfig fping freetype fstrm fts fuse gcc gcompat gdbm giflib glib gmp gnutls gpgme gnupg gpm hwids isl26 jansson java-cacerts java-common java-jffi json-c k9s keyutils krb5-conf krb5 kubernetes lcms2 lddtree acl libaio libassuan attr libbpf libbsd bzip2 libc-dev libcap-ng e2fsprogs openssl libeconf libedit elfutils expat libffi libfontenc libgcrypt libgpg-error libidn2 gettext libjpeg-turbo libksba openldap lksctp-tools libmd libmnl ncurses libnftnl libpng procps-ng cyrus-sasl libseccomp libslirp libtasn1 libucontext libunistring liburing libutempter libuv libverto libx11 libxau libxcb libxcomposite libxdmcp libxext libxi libxml2 libxrender iptables libxtst linux-pam linux-lts lz4 lzo mdev-conf mkfontscale mkinitfs mpc1 mpdecimal mpfr4 mtools musl-obstack musl mariadb nano netavark nettle nghttp2 npth nspr nss numactl oniguruma openblas pcre2 pcsc-lite perl perl-error git pinentry pixman pkgconf protobuf-c readline pax-utils screen skalibs slirp4netns snappy sqlite sshpass busybox syslinux utmps vde2 xz yajl zlib zstd agetty podman

sudo rc-update add local

sudo rc-update add cgroups

sudo rc-service cgroups start

sudo ln -s /usr/share/zoneinfo/Asia/Taipei /etc/localtime

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64 && \
chmod +x ./kind && \
sudo mv ./kind /usr/local/bin/kind && \
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
sudo rm -r kubectl

sudo curl https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/bin/mc
sudo chmod +x /usr/bin/mc

mkdir ~/cni/ && \
curl -sL "$(curl -sL https://api.github.com/repos/containernetworking/plugins/releases/latest | jq -r '.assets[].browser_download_url' | grep 'linux-amd64.*.tgz$')" -o ~/cni/cni-plugins.tgz && \
tar xf ~/cni/cni-plugins.tgz -C ~/cni; rm ~/cni/cni-plugins.tgz

mkdir -p ~/wulin/yaml

wget http://www.oc99.org/zip/kind2024v1.0.zip -O ~/kind2024v1.0.zip
unzip kind2024v1.0.zip
sudo rm -r kind2024v1.0.zip

wget https://raw.githubusercontent.com/braveantony/bash-script/main/kind/kindctl -O ~/bin/kindctl && chmod +x ~/bin/kindctl

cat <<EOF | sudo tee /etc/profile
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PAGER=less
export PS1='\h:\w\\$ '
umask 022

for script in /etc/profile.d/*.sh ; do
        if [ -r \$script ] ; then
                . \$script
        fi
done

# Alpine 的啟動系統是 openrc, 登入前會執行 /etc/local.d/rc.local.start, 登入後會執行 /etc/profile
gw=\$(route -n | grep -e "^0.0.0.0 ")
export GWIF=\${gw##* }
ips=\$(ifconfig \$GWIF | grep 'inet ')
export IP=\$(echo \$ips | cut -d' ' -f2 | cut -d':' -f2)
export NETID=\${IP%.*}
export GW=\$(route -n | grep -e '^0.0.0.0' | tr -s \ - | cut -d ' ' -f2)
export PATH="/home/bigred/bin:/home/bigred/kind/bin:\$PATH"
# source /home/bigred/bin/myk3s
clear && sleep 2
echo "Welcome to Alpine Linux : `cat /etc/alpine-release`"
[ "\$IP" != "" ] && echo "IP : \$IP"
echo ""

export PS1="[\\${STY#*.}]\u@\h:\w\$ "
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
alias vms='sudo /usr/bin/vmware-toolbox-cmd disk shrink /'

# /etc/local.d/rc.local.start (相當於 rc.local) create /tmp/sinfo
if [ -z "\$SSH_TTY" ]; then
   [ -f /tmp/sinfo ] && dialog --title " Cloud Native Trainer " --textbox /tmp/sinfo 24 85; clear
fi

export KIND_EXPERIMENTAL_PROVIDER='podman kind create cluster'
EOF

cat <<EOF | sudo tee /etc/local.d/rc.local.start
#!/bin/bash
gw=\$(route -n | grep -e "^0.0.0.0 ")
export GWIF=\${gw##* }
ips=\$(ifconfig \$GWIF | grep 'inet ')
export IP=\$(echo \$ips | cut -d' ' -f2 | cut -d':' -f2)
export NETID=\${IP%.*}
export GW=\$(route -n | grep -e '^0.0.0.0' | tr -s \ - | cut -d ' ' -f2)

echo "[System]" > /tmp/sinfo
echo "Hostname : `hostname`" >> /tmp/sinfo

m=\$(free -mh | grep Mem: | tr -s ' ' | cut -d' ' -f2)
echo "Memory : \${m}M" >> /tmp/sinfo

cname=\$(cat /proc/cpuinfo | grep 'model name' | head -n 1 | cut -d ':' -f2)
cnumber=\$(cat /proc/cpuinfo | grep 'model name' | wc -l)
echo "CPU : \$cname (core: \$cnumber)" >> /tmp/sinfo

m=\$(df -h | grep /dev/sda)
ds=\$(echo \$m | cut -d ' ' -f2)
echo "Disk : \$ds" >> /tmp/sinfo

kubectl get no &>/dev/null
if [ "\$?" == "0" ]; then
   #v=\$(kubectl version --short | head -n 1 | cut -d ":" -f2 | tr -d ' ')
   echo "Kubernetes: enabled" >> /tmp/sinfo
fi

echo "" >> /tmp/sinfo

echo "[Network]" >> /tmp/sinfo
echo "IP : \$IP" >> /tmp/sinfo
echo "Gateway : \$GW" >> /tmp/sinfo
cat /etc/resolv.conf | grep 'nameserver' | head -n 1 >> /tmp/sinfo

/bin/ping -c 1 www.hinet.net
[ "\$?" == "0" ] && echo "Internet OK" >> /tmp/sinfo

modprobe tun
modprobe fuse
mount --make-rshared /
modprobe br_netfilter
modprobe ip_tables
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
EOF

sudo chmod +x /etc/local.d/rc.local.start

mkdir ~/bin

cat <<EOF | tee ~/bin/dknet
#!/bin/bash
[ "\$#" != 2 ] && echo "dknet ctn net" && exit 1

ifconfig \$2 &>/dev/null
[ "\$?" != "0" ] && echo "\$2 not exist" && exit 1

x=\$(docker inspect -f '{{.State.Pid}}' \$1 2>/dev/null)
[ "\$x" == "" ] && echo "\$1 not exist" && exit 1

[ ! -d /var/run/netns ] && sudo mkdir -p /var/run/netns

if [ ! -f /var/run/netns/\$x ]; then
   sudo ln -s /proc/\$x/ns/net /var/run/netns/\$x
   sudo ip link set \$2 netns \$x
fi

exit 0
EOF

chmod +x ~/bin/dknet

cat <<EOF | tee ~/bin/dktag
#!/bin/bash
# Returns the tags for a given docker image.
# Based on http://stackoverflow.com/a/32622147/

print_help_and_exit() {
        name=`basename "\$0"`
        echo "Usage:"
        echo "  \${name} alpine"
        echo "  \${name} phusion/baseimage"
        exit
}

repo="\$1"

[ "\$#" != 1  ] && print_help_and_exit
[ "\$" = "-h" ] && print_help_and_exit
[ "\$" = "-help" ] && print_help_and_exit
[ "\$" = "--help" ] && print_help_and_exit

if [[ "\${repo}" != */* ]]; then
        repo="library/\${repo}"
fi

# v2 API does not list all tags at once, it seems to use some kind of pagination.
#url="https://registry.hub.docker.com/v2/repositories/\${repo}/tags/"
##echo "\${url}"
#curl -s -S "\${url}" | jq '."results"[]["name"]' | sort

# v1 API lists everything in a single request.
url="https://registry.hub.docker.com/v1/repositories/\${repo}/tags"
#echo "\${url}"
curl -s -S "\${url}" | jq '.[]["name"]' | sed 's/^"\(.*\)"\$/\1/' | sort
EOF

chmod +x ~/bin/dktag

cat <<EOF | tee ~/bin/k3smaster
#!/bin/bash

which kubectl &>/dev/null
if [ "\$?" != "0" ]; then
   echo -n "K3S Master creating"
   curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--cluster-cidr=10.20.0.0/16 --service-cidr=172.20.0.0/24 --no-deploy servicelb --no-deploy traefik --cluster-domain=dt.io" K3S_KUBECONFIG_MODE="644" sh -
   sudo reboot
fi
EOF

chmod +x ~/bin/k3smaster

cat <<EOF | tee ~/bin/pingnid
#!/bin/bash

[ "\$1" == "" ] && echo "need a network id" && exit
netid=\$1

# 安裝 fping 命令
fping -v &>/dev/null
if [ "\$?" != "0" ];then
   sudo apk add fping &>/dev/null
   [ "\$?" != "0" ] && echo "fping not found" && exit 1
   echo "fping ok"
fi

fping -c 1 -g -q \$netid &> "/tmp/netid.chk"
nip=\$(grep "min/avg/max" "/tmp/netid.chk" | cut -d' ' -f1 | tr -s ' ')

for ip in \$nip
do
  echo -n "\$ip "

  nc -w 2 \$ip 22 &>/dev/null
  [ "\$?" == "0" ] && echo -n "ssh "

  nc -w 2 \$ip 80 &>/dev/null
  [ "\$?" == "0" ] && echo -n "www "

  nc -w 2 \$ip 445 &>/dev/null
  [ "\$?" == "0" ] && echo -n "smb"

  echo ""
done
EOF

chmod +x ~/bin/pingnid

cat <<EOF | sudo tee /etc/inittab
# /etc/inittab

::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

# Set up a couple of getty's
tty1::respawn:/sbin/agetty --autologin $USER --noclear 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

# Put a getty on the serial port
#ttyS0::respawn:/sbin/getty -L ttyS0 115200 vt100

# Stuff to do for the 3-finger salute
::ctrlaltdel:/sbin/reboot

# Stuff to do before rebooting
::shutdown:/sbin/openrc shutdown

ttyS0::respawn:/bin/login -f $USER
EOF



sudo reboot
