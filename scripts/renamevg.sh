#!/bin/bash

# Renames the default volume group from 'ubuntu-vg' to something
# sane

FIRST=$(vgdisplay -C | awk 'NR==2 { print $1 }')

if [ ! "$FIRST" ]; then
	echo "Can't find the first vg, wat"
	exit
fi

read -e -i "$FIRST" -p "Volume group to rename: " p
read -e -i avavg -p "New name of volume group: " n

if [ ! "$n" ]; then
	echo "I need a new name"
	exit
fi

alt=$(echo $p | sed 's/-/--/g')
echo "Renaming vg '$p' (aka $alt) to '$n' in:"
echo "  /boot/grub/grub.cfg"
sed --in-place=.bak "s!/dev/mapper/$p!/dev/mapper/$n!g" /boot/grub/grub.cfg
sed --in-place=.bak "s!/dev/mapper/$alt!/dev/mapper/$n!g" /boot/grub/grub.cfg
echo "  /etc/fstab"
sed --in-place=.bak "s!/dev/mapper/$p!/dev/mapper/$n!g" /etc/fstab
sed --in-place=.bak "s!/dev/mapper/$alt!/dev/mapper/$n!g" /etc/fstab

for x in /etc/udev/rules.d/$p-* /etc/udev/rules.d/$alt-*; do
        if [ ! -e "$x" ]; then
                continue
        fi
        uf=$(echo $x | sed -e "s/$p/$n/" -e "s/$alt/$n/")
        echo Renaming "$x" to "$uf"
        mv $x $uf
        sed -i -e "s/$p-/$n-/g" -e "s/$alt-/$n-/g" $uf
done

echo "Renaming VG"
vgrename $p $n

echo "Updating initramfs (ignore crypt error)"
update-initramfs -c -k $(uname -r)

echo "When ready, run /sbin/reboot -f to reboot"
echo "The machine will not shut down due to the missing volumes, which is why you need -f"




