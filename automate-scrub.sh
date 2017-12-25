#!/bin/bash

source openrc admin demo
unset OS_REGION_NAME

openstack --os-region-name=RegionTwo server delete vm2
openstack --os-region-name=RegionOne server delete vm1
neutron --os-region-name=CentralRegion router-interface-delete R2 subnet2
neutron --os-region-name=CentralRegion router-gateway-clear R2 ext-net2
neutron --os-region-name=CentralRegion router-delete R2
neutron --os-region-name=CentralRegion router-interface-delete R1 subnet1
neutron --os-region-name=CentralRegion router-gateway-clear R1 ext-net1
neutron --os-region-name=CentralRegion router-delete R1
neutron --os-region-name=CentralRegion subnet-delete ext-subnet2
neutron --os-region-name=CentralRegion net-delete ext-net2
neutron --os-region-name=CentralRegion subnet-delete ext-subnet1
neutron --os-region-name=CentralRegion net-delete ext-net1
neutron --os-region-name=CentralRegion subnet-delete subnet3
neutron --os-region-name=CentralRegion net-delete net3
neutron --os-region-name=CentralRegion subnet-delete subnet2
neutron --os-region-name=CentralRegion net-delete net2
neutron --os-region-name=CentralRegion subnet-delete subnet1
neutron --os-region-name=CentralRegion net-delete net1
