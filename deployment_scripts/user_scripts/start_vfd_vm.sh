#!/usr/bin/env bash
# Copyright 2017 Mellanox Technologies, Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source /sbin/common

net_vlan_id=`neutron net-show admin_internal_net -F provider:segmentation_id -f value`

VST='{"ATT_VF_VLAN_FILTER":['${net_vlan_id}'],"ATT_INSERT_STAG":true,"ATT_VF_BROADCAST_ALLOW":true,"ATT_VF_UNKNOWN_MULTICAST_ALLOW":true,"ATT_VF_UNKNOWN_UNICAST_ALLOW":true,"ATT_VF_LINK_STATUS":"auto","ATT_VF_VLAN_STRIP":true}'
VGT='{"ATT_VF_VLAN_FILTER":[1,2,3],"ATT_INSERT_STAG":false,"ATT_VF_BROADCAST_ALLOW":true,"ATT_VF_UNKNOWN_MULTICAST_ALLOW":true,"ATT_VF_UNKNOWN_UNICAST_ALLOW":true,"ATT_VF_LINK_STATUS":"auto","ATT_VF_VLAN_STRIP":false}'
MAC_SPOOF_FALSE='{"ATT_VF_VLAN_FILTER":['${net_vlan_id}'],"ATT_INSERT_STAG":true,"ATT_VF_BROADCAST_ALLOW":true,"ATT_VF_UNKNOWN_MULTICAST_ALLOW":true,"ATT_VF_UNKNOWN_UNICAST_ALLOW":true,"ATT_VF_LINK_STATUS":"auto","ATT_VF_VLAN_STRIP":false,"ATT_VF_MAC_ANTI_SPOOF_CHECK"=false}'

usage() {
  echo "Usage: `basename $0` [-f vm_flavor | -h | -m <vgt|vst|mac_spoof_false>]"
  echo "    This script is used to start a VM with a flavor using SR-IOV image."
  echo "    before starting the VM, make sure the SRIOV image is uploaded,"
  echo "    please use upload_sriov_image script."

  echo "
  Options:
  -h           Display the help message.
  -f <flavor>  Create <flavor> SR-IOV VM with direct port.
  -m <mode>    Choose mode for vfd parameters
  "
}

while getopts ":f:m:h" opt; do
  case $opt in
    h)
      usage
      exit 0
      ;;
    f)
      flavor="${OPTARG}"
      logger_print info "SRIOV image flavor $flavor"
      ;;
    m)
      mode="${OPTARG}"
      logger_print info "VFD mode is $mode"
      if [[ "$mode" == "vgt" ]];then
          VFDParams=$VGT;
      elif [[ "$mode" == "vst" ]];then
          VFDParams=$VST;
      elif [[ "$mode" == "mac_spoof_false" ]];then
          VFDParams=$MAC_SPOOF_FALSE;
      else
          usage
          exit 1

      fi
      ;;
    [?])
      usage
      exit 1
      ;;
  esac
done

if [ -z $flavor ]
then
    echo "ERROR: -f or -h must be included when a calling this script" >&2
    usage
    exit 1
fi

. /root/openrc
glance_line=`glance image-list | grep mellanox`
if [[ $glance_line == *mellanox* ]]; then
  SRIOV_IMAGE=`echo $glance_line | head -n 1 | awk '{print $2}'`
  port_id=`neutron port-create admin_internal_net --name vfd_port --vnic-type direct --binding-profile $VFDParams| grep " id " | awk '{print $4}'`
  nova boot --flavor ${flavor} --image $SRIOV_IMAGE --nic port-id=$port_id "vfd_vm-$port_id"
  if [ $? -ne 0 ]; then
    logger_print error "Starting VFD VM failed."
    exit 1
  else
    logger_print info "VFD VM was successfully started."
    exit 0
  fi
else
  echo "No Mellanox SR-IOV image was found. Please use 'upload_sriov_image' script"
  exit 1
fi
