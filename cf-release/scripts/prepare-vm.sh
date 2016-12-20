#!/bin/bash

set -ef -o pipefail
set -u

# This  commands should be executed on CF VM
# for now it is not a complete script but just a log of commands, that should be executed manually by copying them

# 1/ Delete current system domain

monit stop all
# wain for all jobs to be stopped
rsync -a /var/vcap/data/ /var/vcap/data_copy/
rm /var/vcap/store/* -rf
rm /var/vcap/data_copy/sys/log/* -rf
rm /var/vcap/data_copy/sys/run/* -rf
rm /etc/service/agent

# remove 10.0.0.2 from /etc/reolv.conf
# modify /etc/network/interfaces:dns-nameservers remove 10.0.0.2
#modify /etc/dhcp/dhclient.conf remove 10.0.0.2

# remove the following from /etc/init/rsyslog.conf
# pre-start script
#        until mountpoint -q /var/log; do
#          sleep .1
#        done
# end script

config_files=$(find /var/vcap/data_copy/jobs/*/ /var/vcap/monit/job -type f)
ip='private_ip_placeholder'
old_ip=$(ip route get 1 | awk '{print $NF;exit}')
perl -p -i -e "s/\\Q$old_ip\\E/$ip/g" $config_files

domain='domain_placeholder'
old_domain='s-matyukevich.cf-training.net'
perl -p -i -e "s/\\Q$old_domain\\E/$domain/g" $config_files

export EDITOR=vim
visudo
# add the following to the end of file
vcap ALL=(ALL) NOPASSWD:ALL

# add the following command to /etc/rc.local
curl http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key > /home/vcap/.ssh/authorized_keys

#Copy start.sh to /usr/local/bin/start-cf
chmod +x /usr/local/bin/start-cf
