# Install

This guide is for installing Linux on a Dell XPS 13 9310. See
[lshw.txt](lshw.txt) for more detailed hardware info.


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

- Disable Secure Boot
- Storage > NVMe Operation > Select AHCI/NVMe

## Boot installer

- Plug in live USB.
- Power on the laptop.
- Press F12 to access the boot menu when you see the boot logo.
- Select the installer live USB from boot menu (likely the first entry in the
  menu)


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
# (echo g; echo w;) | fdisk /dev/nvme0n1
```

## Create EFI partition

Create a new partition.

- `echo n` add new partition
- `echo 1` set parition number
- `echo` accept default first sector
- `echo "+512M"` set the last sector
- `echo w` write changes to disk

```
# (echo n; echo 1; echo; echo "+512M"; echo w;) | fdisk /dev/nvme0n1
```

Set partition type to EFI.

- `echo t` change partition type
- `echo w` write changes to disk

```
# (echo t; echo "EFI System"; echo w;) | fdisk /dev/nvme0n1
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
# (echo n; echo 2; echo; echo; echo w;) | fdisk /dev/nvme0n1
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

Encrypt partition.

```
cryptsetup --verify-passphrase --verbose luksFormat /dev/nvme0n1p2
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
# reflector --verbose --latest 10 --sort rate --protocol https \
	--save /etc/pacman.d/mirrorlist
```

## Install bootstrap packages

```
# pacstrap -K /mnt base linux linux-firmware sudo vim crda iw
```

## Generate fstab

```
# genfstab -U /mnt >> /mnt/etc/fstab
```

## Enter the new system

```
# arch-chroot /mnt
```



## Create initial ramdisk

First, edit `/etc/mkinitcpio.conf`. Order is important.

Add `i915` for Intel graphics.

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

```
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label 'Arch Linux' \
	--loader /vmlinuz-linux \
	--unicode "cryptdevice=UUID=$(blkid -s UUID -o value /dev/nvme0n1p2):cryptroot root=/dev/mapper/cryptroot rootfstype=ext4 rw initrd=/intel-ucode.img initrd=/initramfs-linux.img i915.enable_guc=2"
```


## Configure time

```
# ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
# hwclock --systohc

# systemctl enable systemd-timesyncd.service #? Maybe?
```


## Configure locale

Uncomment desired locales from `/etc/locale.gen`.

Generate locales.

```
# locale-gen
```

Configure `LANG`.

```
# echo "LANG=en_US.UTF-8" > /etc/locale.conf
```


## Set hostname

```
# echo "myhost" > /etc/hostname
```

## Set regulatory domain

```
# iw reg set US
```

## Install NetworkManager

Install the package.

```
# pacman -S networkmanager
```

Enable the service.

```
# systemctl enable NetworkManager.service
```


## Enable sudo privileges for wheel group

```
visudo
```

Scroll down and then uncomment this line.

```
# %wheel ALL=(ALL) ALL
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

