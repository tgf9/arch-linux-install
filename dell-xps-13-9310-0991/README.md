# Install

This guide is for installing Linux on a Dell XPS 13 9310. See
[lshw.txt](lshw.txt) for more hardware info.

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

Use `lsblk` to list the currently detected block devices.

```
$ lsblk
NAME          MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
nvme0n1       259:0    0 238.5G  0 disk
├─nvme0n1p1   259:1    0   512M  0 part  /boot
└─nvme0n1p2   259:2    0   238G  0 part
  └─cryptroot 254:0    0   238G  0 crypt /
```

Unmount the USB, but don't eject it.

```
$ umount
```

Use `cat` to copy the ISO to the USB drive.

```
$ sudo -s
# cat archlinux-2022.11.01-x86_64.iso > /dev/sda
# exit
```

Eject the USB drive.

```
$ eject /dev/sda
```

