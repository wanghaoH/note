#!/bin/bash
#批量通过backfile创建虚拟机
#2015/8/9 v1.0 by tianyun
images_dir=/var/lib/libvirt/images
xml_dir=/etc/libvirt/qemu

for i in {1..100}
do
	kvm_name=tianyun${i}
	kvm_uuid=`uuidgen`
	kvm_mac="52:54:$(dd if=/dev/urandom count=1 2>/dev/null | md5sum | sed -r 's/^(..)(..)(..)(..).*$/\1:\2:\3:\4/')"
	kvm_xml=${xml_dir}/${kvm_name}.xml
	kvm_image=${images_dir}/${kvm_name}.img

	qemu-img create -f qcow2 -b /base_images/tianyun0.img ${kvm_name}.img
	cp -rf ${xml_dir}/tianyun0.xml ${xml_dir}/${kvm_name}.xml
	sed -ri 's/name/${kvm_name}/' ${xml_dir}/${kvm_name}.xml
	sed -ri 's/uuid/${kvm_uuid}/' ${xml_dir}/${kvm_name}.xml
	sed -ri 's/disk/${kvm_name}/' ${xml_dir}/${kvm_name}.xml
	sed -ri 's/mac/${kvm_mac}/' ${xml_dir}/${kvm_name}.xml
	virsh define /etc/libvirt/qemu/${kvm_name}.xml
	virsh start ${kvm_name}
done
