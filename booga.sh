#!/usr/bin/env bash

set -e

sudo apt-get install -y cloud-image-utils qemu

# This is already in qcow2 format.
base_img=ubuntu-20.04-server-cloudimg-amd64.img
if [ ! -f "$base_img" ]; then
  wget "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
fi

# Always delete existing VM image
img=openwhisk-vm.qcow2
if [ -f "$img" ]; then
  echo "Deleting existing VM image: $img"
  rm "$img"
fi

# Create a new image with the base image as backing file
echo "Creating new VM image: $img"
qemu-img create -f qcow2 -b "$base_img" -F qcow2 "$img" 256G

# Always delete existing user data image
user_data=user-data.img
if [ -f "$user_data" ]; then
  echo "Deleting existing user data image: $user_data"
  rm "$user_data"
fi

# Create a new user data image
echo "Creating new user data image from cloud-init-config.yaml"
cloud-localds "$user_data" cloud-init-config.yaml

# Start the VM
qemu-system-x86_64 -drive "file=openwhisk-vm.qcow2,format=qcow2"   \
    -drive "file=user-data.img,format=raw"   \
    -device virtio-net-pci,netdev=net0   \
    -enable-kvm   \
    -m 100G   \
    -netdev user,id=net0,hostfwd=tcp::2222-:22   \
    -nographic   \
    -smp 48 \
    -cpu host
