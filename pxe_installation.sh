#!/bin/bash
ip_address=$(ip -o -4 addr show dev ens33 | awk '{split($4,a,"/"); print a[1]}')
dns=$(cat /etc/resolv.conf | grep "nameserver" | awk '{print $2}')
wangduan=$(ip -o -4 addr show dev ens33 | awk '{split($4,a,"/"); print a[1]}' |awk -F . '{printf $1"."$2"."$3"."}')

dhcp () {
yes |cp -a /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example /etc/dhcp/dhcpd.conf &> /dev/null
cd /etc/dhcp
sed -i '/^subnet/,/^}$/c\\' dhcpd.conf
sed -i '/^option/,/^$/c\\' dhcpd.conf
cat << EOF >> dhcpd.conf
log-facility local7;
subnet $(printf $wangduan)0 netmask 255.255.255.0 {
  range $(printf $wangduan)200 $(printf $wangduan)249;
  option domain-name-servers $(printf $dns);
  option routers $(printf $wangduan)2;
  default-lease-time 600;
  max-lease-time 7200;
  next-server $(printf $ip_address);    
  filename "pxelinux.0";                
}
EOF

systemctl restart dhcpd
ss -tlunp|grep dhcpd > /root/.ceshi.txt
if [ $(wc -l /root/.ceshi.txt | awk '{print $1}') -ne 0 ] 
then 
	echo "dhcp开启成功" 
else 
	echo "dhcp开启失败，需要手动启动"
fi
systemctl enable dhcpd &> /dev/null
}

apache () {
#挂载镜像到httpd目录下，并开启共享。
mkdir /var/www/html/centos7
echo "/dev/sr0 /var/www/html/centos7 iso9660 defaults 0 0" >> /etc/fstab
mount -a &> /dev/null
systemctl restart httpd
ss -tlunp|grep :80 > /root/.ceshi.txt
if [ $(wc -l /root/.ceshi.txt | awk '{print $1}') -ne 0 ] 
then 
	echo "apache开启成功" 
else 
	echo "apache开启失败，需要手动启动"
fi
systemctl enable httpd &> /dev/null
}

tftp () {
#配置tftp并开启tftp.socket
sed -i '/disable/cdisable=no' /etc/xinetd.d/tftp
systemctl start tftp.socket
systemctl status tftp.socket > /root/.ceshi.txt
grep active /root/.ceshi.txt > /root/.ceshi1.txt
if [ $(wc -l /root/.ceshi1.txt | awk '{print $1}') -ne 0 ]
then 
	echo "tftp开启成功" 
else 
	echo "tftp开启失败，需要手动启动"
fi
systemctl enable tftp.socket &> /dev/null
}

pxe () {
cp -a /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot/
#引导文件
cp -a /var/www/html/centos7/isolinux/{vesamenu.c32,boot.msg,splash.png}   /var/lib/tftpboot/
#用来辅助完成菜单的显示
cp -a /var/www/html/centos7/images/pxeboot/{vmlinuz,initrd.img}   /var/lib/tftpboot/
#用来预加载的内核和驱动文件，然后使用预加载内核进行系统安装
mkdir /var/lib/tftpboot/pxelinux.cfg/
cp -a /var/www/html/centos7/isolinux/isolinux.cfg /var/lib/tftpboot/pxelinux.cfg/default

cat << EOF > /var/lib/tftpboot/pxelinux.cfg/default
default vesamenu.c32
timeout 50

display boot.msg
menu background splash.png

label linux
  menu label install CentOS 7 by Kickstart
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.repo=http://$(printf $ip_address)/centos7 inst.ks=http://$(printf $ip_address)/ks_config/centos7.cfg
menu end
EOF
}


kscfg () {
mkdir /var/www/html/ks_config
#cp -a /root/systemtools.sh /var/www/html/
cat << EOF >/var/www/html/ks_config/centos7.cfg
#version=DEVEL
auth --enableshadow --passalgo=sha512
url --url=http://$(printf $ip_address)/centos7
graphical
firstboot --enable
ignoredisk --only-use=sda
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
network --bootproto=dhcp --device=ens33 --onboot=on --ipv6=auto --no-activate
network --hostname=localhost.localdomain
rootpw --iscrypted $(printf '$6$JL2nR/Hla79hGmeN$.cy3zGANbdkzQU/GRec1pxyNIlC8CnDMfUq85aWZEcuL0wGrtfxw2N/1S5cd17g0.WBX4oUiOCuvg3nX5DonU0')
firewall --disabled
selinux --disabled
services --disabled="chronyd"
timezone Asia/Shanghai --isUtc --nontp
bootloader --append=" crashkernel=auto " --location=mbr --boot-drive=sda
clearpart --none --initlabel
part /boot --fstype="xfs" --ondisk=sda --size=1024
part swap --fstype="swap" --ondisk=sda --size=2048
part / --fstype="xfs" --ondisk=sda --grow --size=1
%packages
@^web-server-environment
@base
@core
@web-server
lrzsz
mariadb-server
mariadb
%end
%post --log=/root/ks-post.log
#Restart network service
#systemctl restart network
#Download systemtools.sh script
#curl -o /root/systemtools.sh http://$(printf $ip_address)/systemtools.sh
# Make systemtools.sh executable
#chmod +x /root/systemtools.sh
# Run systemtools.sh script
#/root/systemtools.sh
%end
reboot
EOF
}

yum -y install httpd dhcp tftp-server syslinux system-config-kickstart > /dev/null

dhcp;
apache;
tftp;
pxe;
kscfg;


