#!/bin/bash

DATA=$(date '+%Y-%m-%d-%H-%M-%S') #returning date

declare -A VM_VERSION #association table
VM_VERSION=( [ubuntu22]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img" [centos7]="https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2" )

declare -A OPTION #association table for os type version
OPTION=( [ubuntu22]="ubuntu22.04" [centos7]="rhel7.0" )

# Functions

function downloadCloudImage() {
  if [ ! -e "/var/lib/libvirt/images/${1}.img" ]; then
    wget -O /var/lib/libvirt/images/${1}.img ${VM_VERSION[$1]}
  fi

  qemu-img convert -O qcow2 /var/lib/libvirt/images/${1}.img /var/lib/libvirt/images/${1}.qcow2
  qemu-img resize /var/lib/libvirt/images/${1}.qcow2 +20G
}
# creating cloud config and image, deleting cloud-init, authentication for ssh
function createCloudImage() {
  local PACMAN=$2
  qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/${1}.qcow2 /var/lib/libvirt/images/${1}-${SUDO_USER}-${DATA}.img
  virt-customize -a /var/lib/libvirt/images/${1}-${SUDO_USER}-${DATA}.img --root-password password:1234
  virt-customize -a /var/lib/libvirt/images/${1}-${SUDO_USER}-${DATA}.img --uninstall cloud-init

cat > /var/lib/libvirt/images/${1}-${SUDO_USER}-${DATA}-config<<EOF
chpasswd: { expire: False }
ssh_pwauth: True
EOF

  cloud-localds /var/lib/libvirt/images/${1}-${SUDO_USER}-${DATA}-config.img /var/lib/libvirt/images/${1}-${SUDO_USER}-${DATA}-config
}

function runVirtualMachine () {
  virt-install --import --connect=qemu:///system --name ${1}-${SUDO_USER}-${DATA} --ram=2048 --vcpus=2 --os-variant=${OPTION[$1]} --disk "/var/lib/libvirt/images/${1}-${SUDO_USER}-${DATA}.img",device=disk,bus=virtio --disk "/var/lib/libvirt/images/${1}-${SUDO_USER}-${DATA}-config.img",device=cdrom --graphic none --network bridge=virbr0,model=virtio --noautoconsole
}

function main () {
  downloadCloudImage $1
  createCloudImage $1 $2
  runVirtualMachine $1
}

#main
main $1 $2