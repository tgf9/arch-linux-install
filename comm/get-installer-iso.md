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
