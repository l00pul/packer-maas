url ${KS_OS_REPOS} ${KS_PROXY}
firewall --enabled --service=ssh
firstboot --disable
ignoredisk --only-use=vda
lang en_US.UTF-8
keyboard us
network --device eth0 --bootproto=dhcp
firewall --enabled --service=ssh
selinux --enforcing
timezone UTC --isUtc
bootloader --location=mbr --driveorder="vda" --timeout=1
rootpw --plaintext password

repo --name="Updates" ${KS_UPDATES_REPOS} ${KS_PROXY}
repo --name="Extras" ${KS_EXTRAS_REPOS} ${KS_PROXY}

zerombr
clearpart --all --initlabel
part / --size=1 --grow --asprimary --fstype=ext4

%{ if communicator == "none" }
poweroff
%{ else }
# Add a provisioner user
user --name='${SSH_USERNAME}' --groups=wheel --password='${SSH_PASSWORD}' --plaintext

# Reboot the system for provisioning
reboot
%{ endif }

%post --erroronfail
# workaround anaconda requirements and clear root password
passwd -d root
passwd -l root

%{ if communicator == "none" }
# Clean up install config not applicable to deployed environments.
for f in resolv.conf fstab; do
    rm -f /etc/$f
    touch /etc/$f
    chown root:root /etc/$f
    chmod 644 /etc/$f
done
rm -f /etc/sysconfig/network-scripts/ifcfg-[^lo]*
%{ else }
# Passwordless sudo for provisioner user
echo "${SSH_USERNAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${SSH_PASSWORD}
chmod 440 /etc/sudoers.d/${SSH_USERNAME}

%{ endif }

# Kickstart copies install boot options. Serial is turned on for logging with
# Packer which disables console output. Disable it so console output is shown
# during deployments
sed -i 's/^GRUB_TERMINAL=.*/GRUB_TERMINAL_OUTPUT="console"/g' /etc/default/grub
sed -i '/GRUB_SERIAL_COMMAND="serial"/d' /etc/default/grub
sed -ri 's/(GRUB_CMDLINE_LINUX=".*)\s+console=ttyS0(.*")/\1\2/' /etc/default/grub
sed -i 's/GRUB_ENABLE_BLSCFG=.*/GRUB_ENABLE_BLSCFG=false/g' /etc/default/grub

yum clean all
%end

%packages
@core
bash-completion
cloud-init
# cloud-init only requires python-oauthlib with MAAS. As such upstream
# has removed python-oauthlib from cloud-init's deps.
python2-oauthlib
cloud-utils-growpart
rsync
tar
yum-utils
# bridge-utils is required by cloud-init to configure networking. Without it
# installed cloud-init will try to install it itself which will not work in
# isolated environments.
bridge-utils
# Tools needed to allow custom storage to be deployed without acessing the
# Internet.
grub2-efi-x64
shim-x64
# Older versions of Curtin do not support secure boot and setup grub by
# generating grubx64.efi with grub2-efi-x64-modules.
grub2-efi-x64-modules
efibootmgr
dosfstools
lvm2
mdadm
device-mapper-multipath
iscsi-initiator-utils
-plymouth
# Remove ALSA firmware
-a*-firmware
# Remove Intel wireless firmware
-i*-firmware
%end
