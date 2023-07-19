
#!/bin/bash

echo "****************************************"
echo "该脚本是一个服务器安装后的初始化配置脚本"
echo "*****1. 关闭Linux的防火墙和SELinux******"
echo "***********2. 手动配置网络参数**********"
echo "***********3. 配置本地yum源************"
echo "***********4. 配置网络yum源************"
echo "****************************************"

echo -n "请根据需求选择对应的数字："
read -t 5 num

# 如果没有用户输入，则自动执行 case 1、case 4
if [ -z "$num" ]; then
    num="14"
    echo "没有输入，执行 case 1，case 4"
fi

firewall() {
    systemctl stop firewalld
    systemctl disable firewalld && return 0
}

selinux() {
    setenforce 0
    sed -i '7s/enforcing/disabled/' /etc/selinux/config
}

configure_network() {
echo "请输入IP地址："
read ip_address

echo "请输入子网掩码："
read subnet_mask

echo "请输入网关地址："
read gateway

echo "请输入DNS服务器地址："
read dns

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-ens33
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=ens33
DEVICE=ens33
ONBOOT=yes
IPADDR=$ip_address
NETMASK=$subnet_mask
GATEWAY=$gateway
DNS1=$dns
EOF


systemctl restart network


}

configure_local_yum() {

if ls /etc/yum.repos.d/backup 1> /dev/null 2>&1; then
    rm -rf /etc/yum.repos.d/*.repo
else
    mkdir /etc/yum.repos.d/backup
	mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup
fi

 #   echo "请输入本地光盘镜像挂载路径："
 #   read mount_path


cat <<EOF > /etc/yum.repos.d/local.repo


[local]
name=Local Repository
#baseurl=file://$mount_path
baseurl=file:///media
enabled=1
gpgcheck=0
EOF

yum clean all &> /dev/null
yum makecache &> /dev/null

echo "本地yum源配置完成。"


}


configure_network_yum() {
if ls /etc/yum.repos.d/backup 1> /dev/null 2>&1; then
    rm -rf /etc/yum.repos.d/*.repo
else
    mkdir /etc/yum.repos.d/backup
	mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup
fi

    cat <<EOF > /etc/yum.repos.d/network.repo
[base]
name=base
baseurl=http://mirror.centos.org/centos/7/os/\$basearch/
gpgcheck=0
enabled=1
EOF

yum clean all &> /dev/null
yum makecache &> /dev/null

echo "网络yum源配置完成。"


}

case $num in
    1)
        status=$(systemctl status firewalld | awk -F "; " 'NR==2{printf $2"\n"}')
        systemctl status firewalld &> /dev/null
        if [ "$?" -eq 0 -o "$status" == "enabled" ]; then
            firewall
            if [ "$?" -eq 0 ]; then
                echo "firewalld停止成功了."
            else
                echo "firewalld停止失败，请自行查看失败原因."
            fi
        else
            echo "firewalld已经关闭了."
        fi


    selinux
    if [ "$?" -eq 0 ]; then
        echo "SELinux禁用成功了."
    else
        echo "SELinux禁用失败，请自行查看失败原因."
    fi
    ;;
	2)
		configure_network
    ;;
	3)
		configure_local_yum
    ;;
	4)
		configure_network_yum
    ;;

	14)
		status=$(systemctl status firewalld | awk -F "; " 'NR==2{printf $2"\n"}')
		systemctl status firewalld &> /dev/null
		if [ "$?" -eq 0 -o "$status" == "enabled" ]; then
			firewall
			if [ "$?" -eq 0 ]; then
				echo "firewalld停止成功了."
			else
				echo "firewalld停止失败，请自行查看失败原因."
			fi
		else
			echo "firewalld已经关闭了."
		fi

		selinux
			if [ "$?" -eq 0 ]; then
				echo "SELinux禁用成功了."
			else
				echo "SELinux禁用失败，请自行查看失败原因."
			fi

		configure_network_yum
    ;;
*)
    echo "Usage: $0 {1|2|3|4|5}"
    ;;


esac
