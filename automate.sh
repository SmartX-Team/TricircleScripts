#!/bin/bash

REGEX_PARAM_KEY_TRIM_CHAR_PATTERN='[ ]'
TMP_STDOUT_FILE='/tmp/tmp-stdout.txt'

ere_quote() {
    sed 's/[]/\.|$(){}?+*^]/\\&/g' <<< "$*"
}

normalize_key() {
	REGEX_KEY=`ere_quote "$1"`
    echo `cat $TMP_STDOUT_FILE | grep "$REGEX_KEY" | tail -n 1 | cut -d '|' -f $2 | sed "s/^$REGEX_PARAM_KEY_TRIM_CHAR_PATTERN*//g" | sed "s/$REGEX_PARAM_KEY_TRIM_CHAR_PATTERN*$//g"`
}

get_ip_addr() {
    echo `cat $TMP_STDOUT_FILE | grep -Pom 1 "$1"'[0-9.]{1,3}'`
}

run_and_get_stdout() {
	# $1 = The stdout to filter.
	echo "EXECUTING: $1"
	$1 > $TMP_STDOUT_FILE 2>&1
	cat $TMP_STDOUT_FILE
}

hold_and_wait() {
	echo "HOLDING FOR $1 SECONDS..."
	sleep $1
}

source openrc admin demo
unset OS_REGION_NAME

run_and_get_stdout "openstack --os-region-name=RegionOne endpoint list"

run_and_get_stdout "openstack multiregion networking pod create --region-name CentralRegion"
run_and_get_stdout "openstack multiregion networking pod create --region-name RegionOne --availability-zone az1"
run_and_get_stdout "openstack multiregion networking pod create --region-name RegionTwo --availability-zone az2"

run_and_get_stdout "neutron --os-region-name=CentralRegion net-create --availability-zone-hint RegionOne net1"
export NET1_ID=`normalize_key " id " 3`
run_and_get_stdout "neutron --os-region-name=CentralRegion subnet-create --name=subnet1 --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 net1 10.0.1.0/24"
export SUBNET1_ID=`normalize_key " id " 3`
run_and_get_stdout "neutron --os-region-name=CentralRegion net-create --availability-zone-hint RegionTwo net2"
export NET2_ID=`normalize_key " id " 3`
run_and_get_stdout "neutron --os-region-name=CentralRegion subnet-create --name=subnet2 --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 net2 10.0.2.0/24"
export SUBNET2_ID=`normalize_key " id " 3`

run_and_get_stdout "neutron --os-region-name=CentralRegion net-create --provider:network_type vxlan --availability-zone-hint az1 --availability-zone-hint az2 net3"
export NET3_ID=`normalize_key " id " 3`
run_and_get_stdout "neutron --os-region-name=CentralRegion subnet-create --name=subnet3 --no-gateway net3 10.0.3.0/24"
export SUBNET3_ID=`normalize_key " id " 3`

run_and_get_stdout "neutron --os-region-name=CentralRegion net-create --router:external --provider:network_type flat --provider:physical_network extern --availability-zone-hint RegionOne ext-net1"
export EXTNET1_ID=`normalize_key " id " 3`
run_and_get_stdout "neutron --os-region-name=CentralRegion subnet-create --name ext-subnet1 --disable-dhcp --allocation-pool start=192.168.101.100,end=192.168.101.254 ext-net1 192.168.101.0/24"
export EXTSUBNET1_ID=`normalize_key " id " 3`
run_and_get_stdout "neutron --os-region-name=CentralRegion net-create --router:external --provider:network_type flat --provider:physical_network extern --availability-zone-hint RegionTwo ext-net2"
export EXTNET2_ID=`normalize_key " id " 3`
run_and_get_stdout "neutron --os-region-name=CentralRegion subnet-create --name ext-subnet2 --disable-dhcp --allocation-pool start=192.168.102.100,end=192.168.102.254 ext-net2 192.168.102.0/24"
export EXTSUBNET2_ID=`normalize_key " id " 3`

run_and_get_stdout "neutron --os-region-name=CentralRegion router-create --availability-zone-hint RegionOne R1"
run_and_get_stdout "neutron --os-region-name=CentralRegion router-gateway-set R1 ext-net1"
run_and_get_stdout "neutron --os-region-name=CentralRegion router-interface-add R1 subnet1"
run_and_get_stdout "neutron --os-region-name=CentralRegion router-show R1"

run_and_get_stdout "neutron --os-region-name=CentralRegion router-create --availability-zone-hint RegionTwo R2"
run_and_get_stdout "neutron --os-region-name=CentralRegion router-gateway-set R2 ext-net2"
run_and_get_stdout "neutron --os-region-name=CentralRegion router-interface-add R2 subnet2"
run_and_get_stdout "neutron --os-region-name=CentralRegion router-show R2"

run_and_get_stdout "glance --os-region-name=RegionOne image-list"
export IMAGE1_ID=`normalize_key " cirros" 2`
run_and_get_stdout "nova --os-region-name=RegionOne flavor-list"
run_and_get_stdout "glance --os-region-name=RegionTwo image-list"
export IMAGE2_ID=`normalize_key " cirros" 2`
run_and_get_stdout "nova --os-region-name=RegionTwo flavor-list"

run_and_get_stdout "openstack --os-region-name=RegionOne server create --flavor 1 --image $IMAGE1_ID --nic net-id=$NET1_ID --nic net-id=$NET3_ID vm1"
run_and_get_stdout "openstack --os-region-name=RegionTwo server create --flavor 1 --image $IMAGE2_ID --nic net-id=$NET2_ID --nic net-id=$NET3_ID vm2"
hold_and_wait 60

run_and_get_stdout "nova --os-region-name=RegionOne list"
export VM1_NET1_IP_ADDR=`get_ip_addr "10\.0\.1\."`
export VM1_NET3_IP_ADDR=`get_ip_addr "10\.0\.3\."`
run_and_get_stdout "nova --os-region-name=RegionTwo list"
export VM2_NET2_IP_ADDR=`get_ip_addr "10\.0\.2\."`
export VM2_NET3_IP_ADDR=`get_ip_addr "10\.0\.3\."`
run_and_get_stdout "neutron --os-region-name=CentralRegion port-list"
export VM1_NET3_PORT_ID=`normalize_key "$VM1_NET3_IP_ADDR" 2`
export VM2_NET3_PORT_ID=`normalize_key "$VM2_NET3_IP_ADDR" 2`
run_and_get_stdout "neutron --os-region-name=RegionOne port-list"
export VM1_NET1_PORT_ID=`normalize_key "$VM1_NET1_IP_ADDR" 2`
run_and_get_stdout "neutron --os-region-name=RegionTwo port-list"
export VM2_NET2_PORT_ID=`normalize_key "$VM2_NET2_IP_ADDR" 2`

run_and_get_stdout "neutron --os-region-name=CentralRegion floatingip-create ext-net1"
export EXTNET1_FLOATIP_ID=`normalize_key " id " 3`
export EXTNET1_FLOATIP_ADDR=`normalize_key " floating_ip_address " 3`
run_and_get_stdout "neutron --os-region-name=CentralRegion floatingip-create ext-net2"
export EXTNET2_FLOATIP_ID=`normalize_key " id " 3`
export EXTNET2_FLOATIP_ADDR=`normalize_key " floating_ip_address " 3`
run_and_get_stdout "neutron --os-region-name=CentralRegion floatingip-associate $EXTNET1_FLOATIP_ID $VM1_NET1_PORT_ID"
run_and_get_stdout "neutron --os-region-name=CentralRegion floatingip-associate $EXTNET2_FLOATIP_ID $VM2_NET2_PORT_ID"
run_and_get_stdout "neutron --os-region-name=CentralRegion floatingip-list"

run_and_get_stdout "neutron --os-region-name=RegionOne floatingip-list"
run_and_get_stdout "neutron --os-region-name=RegionOne router-list"
run_and_get_stdout "neutron --os-region-name=RegionTwo floatingip-list"
run_and_get_stdout "neutron --os-region-name=RegionTwo router-list"

run_and_get_stdout "openstack --os-region-name=CentralRegion security group list"
export SECURITY_GROUP_ID=`normalize_key " default " 2`
# Question: CentralRegion only or all regions? (CentralRegion is essential.)
# run_and_get_stdout "openstack --os-region-name=CentralRegion security group rule create --proto icmp $SECURITY_GROUP_ID"
# run_and_get_stdout "openstack --os-region-name=CentralRegion security group rule create --proto tcp $SECURITY_GROUP_ID"
# run_and_get_stdout "openstack --os-region-name=CentralRegion security group rule create --proto udp $SECURITY_GROUP_ID"
run_and_get_stdout "openstack --os-region-name=RegionOne security group rule create --proto icmp $SECURITY_GROUP_ID"
run_and_get_stdout "openstack --os-region-name=RegionOne security group rule create --proto tcp $SECURITY_GROUP_ID"
run_and_get_stdout "openstack --os-region-name=RegionOne security group rule create --proto udp $SECURITY_GROUP_ID"
run_and_get_stdout "openstack --os-region-name=RegionTwo security group rule create --proto icmp $SECURITY_GROUP_ID"
run_and_get_stdout "openstack --os-region-name=RegionTwo security group rule create --proto tcp $SECURITY_GROUP_ID"
run_and_get_stdout "openstack --os-region-name=RegionTwo security group rule create --proto udp $SECURITY_GROUP_ID"

run_and_get_stdout "neutron --os-region-name=CentralRegion port-update --allowed-address-pair ip_address=0.0.0.0/0 $VM1_NET3_PORT_ID"
run_and_get_stdout "neutron --os-region-name=CentralRegion port-update --allowed-address-pair ip_address=0.0.0.0/0 $VM2_NET3_PORT_ID"


echo "Clearing ~/.ssh/known_hosts..."
rm ~/.ssh/known_hosts 2> /dev/null

echo "Updating VM1 for networking..."
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET1_FLOATIP_ADDR 'sudo sh -c "echo auto eth1 >> /etc/network/interfaces"'
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET1_FLOATIP_ADDR 'sudo sh -c "echo iface eth1 inet dhcp >> /etc/network/interfaces"'
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET1_FLOATIP_ADDR 'sudo /sbin/cirros-dhcpc up eth1'
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET1_FLOATIP_ADDR "sudo ip route add 10.0.2.0/24 via $VM2_NET3_IP_ADDR"
echo "VM1: EXECUTING: ip addr show"
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET1_FLOATIP_ADDR "sudo ip addr show"
echo "VM1: EXECUTING: ip route show"
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET1_FLOATIP_ADDR "sudo ip route show"

echo "Updating VM2 for networking..."
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET2_FLOATIP_ADDR 'sudo sh -c "echo auto eth1 >> /etc/network/interfaces"'
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET2_FLOATIP_ADDR 'sudo sh -c "echo iface eth1 inet dhcp >> /etc/network/interfaces"'
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET2_FLOATIP_ADDR 'sudo /sbin/cirros-dhcpc up eth1'
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET2_FLOATIP_ADDR "sudo ip route add 10.0.1.0/24 via $VM1_NET3_IP_ADDR"
echo "VM2: EXECUTING: ip addr show"
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET2_FLOATIP_ADDR "sudo ip addr show"
echo "VM2: EXECUTING: ip route show"
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET2_FLOATIP_ADDR "sudo ip route show"

hold_and_wait 10
echo "Pinging VM2 from VM1 via inter-site tunnel..."
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET1_FLOATIP_ADDR "ping -c 4 $VM2_NET2_IP_ADDR"
echo "Pinging VM1 from VM2 via inter-site tunnel..."
sshpass -p 'cubswin:)' ssh -o StrictHostKeyChecking=no cirros@$EXTNET2_FLOATIP_ADDR "ping -c 4 $VM1_NET1_IP_ADDR"

echo "Passed all configurations and tests, demo run finished."
