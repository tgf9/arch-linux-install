# Install

This guide is for installing Linux on a Dell XPS 13 9310. See
[lshw.txt](lshw.txt) for more detailed hardware info.

See also [Dell XPS 13 (9310)](https://wiki.archlinux.org/title/Dell_XPS_13_(9310)).


## Get installer ISO

- Go to the [Arch Linux Downloads](https://archlinux.org/download) page.
- Find a mirror in your country, click their link.
- Download a file that looks like `archlinux-2022.11.01-x86_64.iso`.

Get the file's SHA256 checksum.
```
$ shasum -a 256 archlinux-2022.11.01-x86_64.iso
df6749df55b02cec98e5a9177c7957acfb96fe14d04553b6e4714100a4824f68  archlinux-2022.11.01-x86_64.iso
```

Verify it matches the checksum on the
[Arch Linux Downloads](https://archlinux.org/download) page.



## Create installer live USB

Plug in a USB drive where you want to copy the installer. The installer image
will take over the entire USB drive.

Use `lsblk` to list the currently detected block devices. In my case, the USB I
plugged in is at `/dev/sda`.

```
$ lsblk
NAME          MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
sda             8:0    1  14.3G  0 disk  /run/media/tgf9/myusb
nvme0n1       259:0    0 447.1G  0 disk
├─nvme0n1p1   259:1    0   512M  0 part  /boot
└─nvme0n1p2   259:2    0 446.6G  0 part
  └─cryptroot 254:0    0 446.6G  0 crypt /
```

Unmount the USB, but don't eject it.

```
$ umount /run/media/tgf9/myusb
```

Use `cat` to copy the ISO to the USB drive.

```
$ sudo -s
# cat archlinux-2022.11.01-x86_64.iso > /dev/sda
# exit
```

Eject the USB drive.

```
$ sudo eject /dev/sda
```


## Change firmware settings before boot

- Boot the laptop
- Press F2 to access the firmware settings

- Boot Configuration > Enable Secure Boot = OFF
- Storage > SATA/NVMe Operation = AHCI/NVMe


## Boot installer

- Plug in live USB.
- Power on the laptop.
- Press F12 to access the boot menu when you see the boot logo.
- Select "Arch Linux install medium" from GRUB menu



## Connect to WiFi

Use `iwctl` to connect to WiFi.

```
$ iwctl station wlan0 scan
$ iwctl station wlan0 get-networks
```

If you need to change the keyboard layout to type accents in your SSID, use
`loadkeys`.

```
# Switch to us-acentos layout.
$ loadkeys us-acentos

# Switch to us layout.
$ loadkeys us
```

```
$ iwctl station wlan0 connect my-network
```

Verify the internet connection is working.

```
$ ping -c 3 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=115 time=10.6 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=115 time=16.0 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=115 time=13.1 ms

--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 10.610/13.264/16.039/2.218 ms
```



## Create partition table

Create a GPT partition table on main drive.

- `echo g` create a GPT partition table
- `echo w` write changes to disk

```
(echo g; echo w;) | fdisk /dev/nvme0n1
```

## Create EFI partition

Create a new partition.

- `echo n` add new partition
- `echo 1` set parition number
- `echo` accept default first sector
- `echo "+512M"` set the last sector
- `echo w` write changes to disk

```
(echo n; echo 1; echo; echo "+512M"; echo w;) | fdisk /dev/nvme0n1
```

Set partition type to EFI.

- `echo t` change partition type
- `echo w` write changes to disk

```
(echo t; echo "EFI System"; echo w;) | fdisk /dev/nvme0n1
```

## Create primary partition

The primary partition is where all the user data will be stored.

Create a new partition.

- `echo n` add new partition
- `echo 2` set parition number
- `echo` accept default first sector
- `echo` accept default last sector (end of disk)
- `echo w` write changes to disk

```
(echo n; echo 2; echo; echo; echo w;) | fdisk /dev/nvme0n1
```

No need to change partition type, default is "Linux filesystem".

## Verify disk

```
# fdisk -l /dev/nvme0n1
Disk /dev/nvme0n1: 447.13 GiB, 480103981056 bytes, 937703088 sectors
Disk model: PC SN530 NVMe WDC
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: DB00E3FF-2C56-47A8-63D1-DB2191CB608A

Device           Start       End   Sectors   Size Type
/dev/nvme0n1p1    2048   1050623   1048576   512M EFI System
/dev/nvme0n1p2 1050624 937701375 936650752 446.6G Linux filesystem
```


## Install FAT32 on EFI partition

```
# mkfs.fat -F32 /dev/nvme0n1p1
```

## Encrypt primary partition

Encrypt partition. See [TRIM support](https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)).

```
cryptsetup --verify-passphrase --verbose --allow-discards luksFormat /dev/nvme0n1p2
```

Create decrypted device, so we can use it.

```
cryptsetup open /dev/nvme0n1p2 cryptroot
```

## Install ext4 on primary partition

Install filesystem on decrypted primary partition.

```
mkfs.ext4 -F /dev/mapper/cryptroot
```

## Mount filesystems

```
mount /dev/mapper/cryptroot /mnt
mkdir /mnt/boot

mount /dev/nvme0n1p1 /mnt/boot
```



## Install bootstrap packages

Refresh mirror list used by `pacstrap`, as well as `pacman` in the new system.

```
reflector --verbose --latest 10 --sort rate --protocol https \
	--save /etc/pacman.d/mirrorlist
```

## Install bootstrap packages

```
pacstrap -K /mnt base linux linux-firmware sudo vim
```

## Generate fstab

```
genfstab -U /mnt >> /mnt/etc/fstab
```

## Enter the new system

```
arch-chroot /mnt
```



## Install Intel microcode

See [Microcode](https://wiki.archlinux.org/title/microcode).

```
pacman -S intel-ucode
```


## Install fwupd

[fwupd](https://wiki.archlinux.org/title/fwupd) updates firmware found on
different devices.

```
pacman -S fwupd
```


## Install sound open firmware

Install [Sound Open Firmware](https://www.sofproject.org/) for audio firmware.

```
pacman -S sof-firmware
```



## Enable Intel GPU features

Next add this to `/etc/modprobe.d/i915.conf`.
See [Enable GuC / HuC firmware loading](https://wiki.archlinux.org/title/intel_graphics#Enable_GuC_/_HuC_firmware_loading).

```
options i915 enable_guc=3
options i915 enable_fbc=1
options i915 fastboot=1
```

## Configure hardware acceleration

See [Hardware video acceleration](https://wiki.archlinux.org/title/Hardware_video_acceleration#Intel).
```
pacman -S intel-media-driver intel-gpu-tools libva-utils
```

Verify there are no errors.

```
$ vainfo | grep "Driver"
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 22.4.4
```



## Enable TRIM

See [SSD NVMe](https://wiki.archlinux.org/title/Solid_state_drive/NVMe).

Enable periodic trim.

```
systemctl enable fstrim.timer
```



## Create initial ramdisk

First, edit `/etc/mkinitcpio.conf`. Order is important.


Add `i915` for Intel graphics for [early KMS](https://wiki.archlinux.org/title/Kernel_mode_setting#Early_KMS_start).

```diff
MODULES=(i915)
```


Add the `encrypt` hook so we can unlock the LUKS partition.

```diff
-HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)
+HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)
```
Build the image.

```
mkinitcpio -p linux
```


## Configure EFISTUB

Install `efibootmgr`.

```
pacman -S efibootmgr
```

The firmware will be in charge of booting Linux.

Delete old boot entries before creating additional entries.

```
efibootmgr -b 0001 -B
```

Create new boot entry.

Kernel parameters.
- `cryptdevice` the location of an encrypted partition, plus the decrypted name
- `initrd` the location of the initial ramdisk
- `root` the root filesystem
- `rw` mount the root device as read-write

Helpful for initial setup only.
- `debug` enable kernel debugging
- `ignore_loglevel` print all kernel messages

```
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label 'Arch Linux' \
	--loader /vmlinuz-linux \
	--unicode "initrd=/intel-ucode.img initrd=/initramfs-linux.img cryptdevice=/dev/nvme0n1p2:cryptroot root=/dev/mapper/cryptroot rw debug ignore_loglevel"
```



## Configure time

```
# ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
# hwclock --systohc

# systemctl enable systemd-timesyncd.service
```


## Configure locale

Uncomment desired locales from `/etc/locale.gen`.

Generate locales.

```
locale-gen
```

Configure `LANG`.

```
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```


## Set hostname

```
echo "myhost" > /etc/hostname
```

## Set regulatory domain

```
pacman -S crda
iw reg set US
```

## Install NetworkManager

Install the package.

```
pacman -S networkmanager
```

Enable the service.

```
systemctl enable NetworkManager.service
```


## Enable sudo privileges for wheel group

```
visudo
```

Scroll down and then uncomment this line.

```diff
-# %wheel ALL=(ALL) ALL
+%wheel ALL=(ALL) ALL
```

## Add a new user

```
useradd --create-home tgf9
passwd tgf9

# Append to wheel group.
usermod --append --groups wheel tgf9
```

## Disable root login

```
passwd --lock root
```



## Install GNOME

```
# Fonts
pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra

# Audio management
pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
pacman -S pipewire-v4l2 gst-plugin-pipewire

# Screen sharing
pacman -S xdg-desktop-portal xdg-desktop-portal-gnome

# GNOME
pacman -S gdm gnome xdg-utils wl-clipboard
systemctl enable gdm.service

# Power management
pacman -S power-profiles-daemon
```



## Reboot

Exit chroot.

```
exit
```

Unmount new system.

```
umount /mnt/boot
umount /mnt
```

Restart computer.

```
reboot
```

Unplug live USB.



## Configure GNOME keyboard

Configure the keyboard for Spanish accents and map caps to control.

```
# Change
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+altgr-intl')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['ctrl:nocaps']"

# Verify
gsettings get org.gnome.desktop.input-sources sources
gsettings get org.gnome.desktop.input-sources xkb-options
```



## Install manpages

```
sudo pacman -S man-db man-pages-es
```


## Install bash completions

```
sudo pacman -S bash-completion
```

## Configure bash history

- `ignoreboth` ignore consecutive commands and commands that start with space.

```
export HISTCONTROL="ignoreboth"
```


## Setup bluetooth

See [Bluetooth](https://wiki.archlinux.org/title/bluetooth) and
[PipeWire Bluetooth](https://wiki.archlinux.org/title/PipeWire#Bluetooth_devices).

```
sudo pacman -S bluez bluez-utils

# This should already be installed by gnome meta package.
# sudo pacman -S gnome-bluetooth-3.0 
```

Enable service.

```
sudo systemctl enable --now bluetooth.service
```


## Install gstreamer

```
sudo pacman -S gstreamer gst-libav gst-plugins-good gst-plugins-ugly gstreamer-vaapi
```


## Install CUPS

See [CUPS](https://wiki.archlinux.org/title/CUPS).

Install packages.

```
sudo pacman -S cups cups-pdf cups-filters

# Drivers
sudo pacman -S foomatic-db-engine foomatic-db-ppds foomatic-db-nonfree-ppds gutenprint foomatic-db-gutenprint-ppds
sudo pacman -S system-config-printer
sudo pacman -S hplip
```

Enable service

```
sudo systemctl enable --now cups.service
```



## Install Firefox

```
pacman -S firefox
```


## Configure Firefox
Enable Wayland. Add this to `~/.bash_profile`.

```
if [ "$XDG_SESSION_TYPE" == "wayland" ]; then
    export MOZ_ENABLE_WAYLAND=1
fi
```

Enable hardware acceleration.

Open Firefox and navigate to `about:config`.

```
gfx.webrender.all true
media.ffmpeg.vaapi.enabled true
```


