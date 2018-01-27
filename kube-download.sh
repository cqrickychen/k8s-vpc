#!/usr/bin/env bash

#set -x
#如果任何语句的执行结果不是true则应该退出,set -o errexit和set -e作用相同
set -e

#id -u显示用户ID,root用户的ID为0
root=$(id -u)
#脚本需要使用root用户执行
if [ "$root" -ne 0 ] ;then
    echo "must run as root"
    exit 1
fi

#
#kubelet kubeadm kubectl kubernetes-cni安装包
#
kube_rpm()
{
    if [ ! -n "$KUBE_VERSION" ]; then
        export KUBE_VERSION="1.9.1"
    fi
    if [ ! -n "$KUBE_CNI_VERSION" ]; then
        export KUBE_CNI_VERSION="0.6.0"
    fi
    if [ ! -n "$SOCAT_VERSION" ]; then
        export SOCAT_VERSION="1.7.3.2"
    fi
    export OSS_URL="http://centos-k8s.oss-cn-hangzhou.aliyuncs.com/rpm/"${KUBE_VERSION}"/"
    export RPM_KUBEADM="kubeadm-"${KUBE_VERSION}"-0.x86_64.rpm"
    export RPM_KUBECTL="kubectl-"${KUBE_VERSION}"-0.x86_64.rpm"
    export RPM_KUBELET="kubelet-"${KUBE_VERSION}"-0.x86_64.rpm"
    export RPM_KUBECNI="kubernetes-cni-"${KUBE_CNI_VERSION}"-0.x86_64.rpm"
    export RPM_SOCAT="socat-"${SOCAT_VERSION}"-2.el7.x86_64.rpm"

    export RPM_KUBEADM_URL=${OSS_URL}${RPM_KUBEADM}
    export RPM_KUBECTL_URL=${OSS_URL}${RPM_KUBECTL}
    export RPM_KUBELET_URL=${OSS_URL}${RPM_KUBELET}
    export RPM_KUBECNI_URL=${OSS_URL}${RPM_KUBECNI}
    export RPM_SOCAT_URL=${OSS_URL}${RPM_SOCAT}
}


#
#安装kubernetes的rpm包
#
kube_download()
{
    # Kubernetes 1.8开始要求关闭系统的Swap，如果不关闭，默认配置下kubelet将无法启动。可以通过kubelet的启动参数–fail-swap-on=false更改这个限制。
    # 修改 /etc/fstab 文件，注释掉 SWAP 的自动挂载，使用free -m确认swap已经关闭。
    swapoff -a
    echo "Swap off success!"

    # IPv4 iptables 链设置 CNI插件需要
    # net.bridge.bridge-nf-call-ip6tables = 1
    # net.bridge.bridge-nf-call-iptables = 1
    # 设置swappiness参数为0，linux swap空间为0
    cat >> /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness=0
EOF
    modprobe br_netfilter
    # 生效配置
    sysctl -p /etc/sysctl.d/k8s.conf
    echo "Network configuration success!"
    #kubelet kubeadm kubectl kubernetes-cni安装包
    kube_rpm

    #kube_repository

    #下载安装包
    if [ ! -f $PWD"/"$RPM_KUBEADM ]; then
        wget $RPM_KUBEADM_URL
    fi
    if [ ! -f $PWD"/"$RPM_KUBECTL ]; then
        wget $RPM_KUBECTL_URL
    fi
    if [ ! -f $PWD"/"$RPM_KUBELET ]; then
        wget $RPM_KUBELET_URL
    fi
    if [ ! -f $PWD"/"$RPM_KUBECNI ]; then
        wget $RPM_KUBECNI_URL
    fi
    if [ ! -f $PWD"/"$RPM_SOCAT ]; then
        wget $RPM_SOCAT_URL
    fi
    
	#rpm -ivh $PWD"/"$RPM_KUBECNI $PWD"/"$RPM_SOCAT $PWD"/"$RPM_KUBEADM $PWD"/"$RPM_KUBECTL $PWD"/"$RPM_KUBELET
    
	echo "kubelet kubeadm kubectl kubernetes-cni downloaded successfully!"

    #systemctl daemon-reload
    #systemctl enable kubelet
    #systemctl start kubelet
    echo "Kubelet downloaded successfully!"
}

#
# 重置集群
#
kube_reset()
{
    kubeadm reset

    rm -rf /var/lib/cni /etc/cni/ /run/flannel/subnet.env /etc/kubernetes/kubeadm.conf

    # 删除rpm安装包
    yum remove -y kubectl kubeadm kubelet kubernetes-cni socat

    #ifconfig cni0 down
    ip link delete cni0
    #ifconfig flannel.1 down
    ip link delete flannel.1
}

kube_help()
{
    echo "usage: $0 --node-type master --master-address 127.0.0.1 --token xxxx"
    echo "       $0 --node-type node --master-address 127.0.0.1 --token xxxx"
    echo "       $0 reset     reset the kubernetes cluster,include all data!"
    echo "       unkown command $0 $@"
}


main()
{
    kube_download
}

main $@

