qemu-system-x86_64 -drive "file=openwhisk-vm.qcow2,format=qcow2"   \
    -drive "file=user-data.img,format=raw"   \
    -device virtio-net-pci,netdev=net0   \
    -enable-kvm   \
    -m 100G   \
    -netdev user,id=net0,hostfwd=tcp::2222-:22   \
    -nographic   \
    -smp 48 \
    -cpu host