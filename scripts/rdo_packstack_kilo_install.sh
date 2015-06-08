#!/bin/sh

setenforce 0
getenforce
systemctl list-unit-files | grep NetworkManager
systemctl disable NetworkManager
yum clean all
yum update
yum -y upgrade
yum install net-tools
yum install gcc
yum install python-devel
rpm -iUvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
yum install python-pip
pip install oslo.concurrency
pip install netifaces
yum install -y http://rdoproject.org/repos/openstack-kilo/rdo-release-kilo.rpm
yum -y install openstack-packstack
echo "run packstack --allinone"
