#!/bin/bash

set -e

if [[ -z $1 ]]; then
    domain=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4).nip.io
else
    domain=$1
fi

>&2 echo "Use $domain for domain"

rm /var/vcap/data -rf
mv /var/vcap/data_copy /var/vcap/data

# Replace the old system domain / IP with the new system domain / IP

config_files=$(find /var/vcap/jobs/*/ /var/vcap/monit/job -type f)

ip=$(ip route get 1 | awk '{print $NF;exit}')
old_ip='private_ip_placeholder'
perl -p -i -e "s/\\Q$old_ip\\E/$ip/g" $config_files
echo "Setting private ip to $ip"

old_domain='domain_placeholder'
perl -p -i -e "s/\\Q$old_domain\\E/$domain/g" $config_files
echo "Setting system domain to $domain"

monit="/var/vcap/bosh/bin/monit"
monit_summary() { while output=$($monit summary 2>&1) && [[ $output = *"error connecting to the monit daemon"* ]]; do sleep 1; done; echo "$output"; }
total_services() { monit_summary | grep -E '^(Process|File|System)' | wc -l; }
started_service_count() { started_services | wc -l; }
started_services() { monit_summary | grep -E '(running|accessible|Timestamp changed|PID changed)' | awk '{print $2}' | tr -d "'"; }
stopped_services() { monit_summary | grep 'not monitored' | grep -v 'pending' | awk '{print $2}' | tr -d "'"; }
wait_for_monit_to_start() { while [[ $(total_services) = 0 ]]; do sleep 1; done; }
wait_for_sv_to_load_monit() { while sv status monit | grep fail ; do sleep 1; done; }
cc_status_code() { curl -s -I -o /dev/null -w %{http_code} -H "Host: api.$1" http://localhost/v2/info; }


ln -s /etc/sv/monit /etc/service
wait_for_sv_to_load_monit
sv start monit
wait_for_monit_to_start

start_services() {
  for service in $@; do
    $monit start $service
  done

  for service in $@; do
    while ! monit_summary | grep $service | grep -q running; do sleep 1; done;
  done
}


start_remaining() { 
  for service in $(stopped_services); do
    $monit start $service
  done
}

echo "Executing pre-start scripts..."

for script in /var/vcap/jobs/*/bin/pre-start; do
  $script
done

echo "Starting mysql..."

start_services mariadb_ctrl galera-healthcheck

while ! nc -z 127.0.0.1 3306; do
  sleep 1
done

echo "Starting consul garden etcd uaa..."
start_services consul_agent garden etcd uaa

while [[ ! /var/vcap/jobs/uaa/bin/dns_health_check ]]; do
  sleep 1
done

echo "Starting bbs..."
start_services bbs

echo "Starting reminig services..."
start_remaining
total=$(total_services)

while started=$(started_service_count) && [[ $started -lt $total ]]; do
  counter=$(($counter + 1))
  [[ $(($counter % 60)) = 0 ]] && echo "$started out of $total running"
  sleep 1
done

echo "$total out of $total running"

#install buildpacks
/var/vcap/jobs/cloud_controller_ng/bin/post-start

while [[ $(cc_status_code "$domain") != 200 ]]; do
  sleep 1
done
