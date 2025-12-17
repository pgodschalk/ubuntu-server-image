# @pgodschalk/ubuntu-server-image

[Report a Bug](https://github.com/pgodschalk/ubuntu-server-image/issues/new?assignees=&labels=bug&template=bug_report.md&title=bug%3A+)
·
[Request a Feature](https://github.com/pgodschalk/ubuntu-server-image/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=feat%3A+)

Ready-to-go hardened Ubuntu Server image

[![Project license](https://img.shields.io/github/license/pgodschalk/ubuntu-server-image.svg?style=flat-square)](LICENSE)

[![Pull Requests welcome](https://img.shields.io/badge/PRs-welcome-ff69b4.svg?style=flat-square)](https://github.com/pgodschalk/ubuntu-server-image/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
[![code with love by pgodschalk](https://img.shields.io/badge/%3C%2F%3E%20with%20%E2%99%A5%20by-pgodschalk-ff1414.svg?style=flat-square)](https://github.com/pgodschalk)

## Table of contents

- [About](#about)
  - [Built with](#built-with)
- [Getting started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
- [Roadmap](#roadmap)
- [Support](#support)
- [Project assistance](#project-assistance)
- [Contributing](#contributing)
- [Authors & contributors](#authors--contributors)
- [Security](#security)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## About

A pre-built, security-hardened Ubuntu Server image for bare-metal and virtual
machine deployments. The image is built using Packer and Ansible, following CIS
Benchmark guidelines for security hardening. It supports both amd64 and arm64
architectures and is designed for LUKS-encrypted installations with LVM.

### Built with

- [Ansible](https://www.ansible.com/)
- [GitHub Actions](https://github.com/features/actions)
- [Packer](https://www.packer.io/)
- [QEMU](https://www.qemu.org/)
- [Ubuntu](https://ubuntu.com/)
- [uv](https://docs.astral.sh/uv/)
- [Vagrant](https://developer.hashicorp.com/vagrant)

## Getting started

### Prerequisites

- A bootable medium

### Installation

#### 1. Boot a live environment

Boot from Ubuntu Live USB or similar rescue system.

#### 2. Partition the disk

```bash
# Identify your disk:
lsblk

# Partition (assuming /dev/sda, adjust as needed)
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart "" 512MiB 100%
```

#### 3. Set up LUKS

```bash
cryptsetup luksFormat /dev/sda2
cryptsetup open /dev/sda2 sda2_crypt
```

#### 4. Set up LVM

```bash
pvcreate /dev/mapper/sda2_crypt
vgcreate ubuntu-vg /dev/mapper/sda2_crypt
lvcreate -l 100%FREE -n ubuntu-lv ubuntu-vg
```

#### 5. Format partitions

```bash
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/ubuntu-vg/ubuntu-lv
```

#### 6. Write the image to the root LV

For amd64:

<!-- markdownlint-disable MD013 -->

```bash
curl --location --remote-name-all \
  https://github.com/pgodschalk/ubuntu-server-image/releases/latest/download/ubuntu-server-image_amd64.qcow2 \
  https://github.com/pgodschalk/ubuntu-server-image/releases/latest/download/ubuntu-server-image_amd64_SHA256SUMS.sha256 \
  https://github.com/pgodschalk/ubuntu-server-image/releases/latest/download/ubuntu-server-image_amd64_SHA256SUMS.sha256.sig

# Verify GPG signature
gpg --verify ubuntu-server-image_amd64_SHA256SUMS.sha256.sig \
  ubuntu-server-image_amd64_SHA256SUMS.sha256

# Verify checksum
sha256sum --check ubuntu-server-image_amd64_SHA256SUMS.sha256

qemu-img convert --target-format raw \
  ubuntu-server-image_amd64.qcow2 /dev/ubuntu-vg/ubuntu-lv
```

<!-- markdownlint-enable MD013 -->

For arm64:

<!-- markdownlint-disable MD013 -->

```bash
curl --location --remote-name-all \
  https://github.com/pgodschalk/ubuntu-server-image/releases/latest/download/ubuntu-server-image_arm64.qcow2 \
  https://github.com/pgodschalk/ubuntu-server-image/releases/latest/download/ubuntu-server-image_arm64_SHA256SUMS.sha256 \
  https://github.com/pgodschalk/ubuntu-server-image/releases/latest/download/ubuntu-server-image_arm64_SHA256SUMS.sha256.sig

# Verify GPG signature
gpg --verify ubuntu-server-image_arm64_SHA256SUMS.sha256.sig \
  ubuntu-server-image_arm64_SHA256SUMS.sha256

# Verify checksum
sha256sum --check ubuntu-server-image_arm64_SHA256SUMS.sha256

qemu-img convert --target-format raw \
  ubuntu-server-image_arm64.qcow2 /dev/ubuntu-vg/ubuntu-lv
```

<!-- markdownlint-enable MD013 -->

Then resize the filesystem:

```bash
e2fsck -f /dev/ubuntu-vg/ubuntu-lv
resize2fs /dev/ubuntu-vg/ubuntu-lv
```

#### 7. Mount and configure

```bash
mount /dev/ubuntu-vg/ubuntu-lv /mnt
mount /dev/sda1 /mnt/boot/efi
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /run /mnt/run
mount --bind /sys /mnt/sys

chroot /mnt
```

#### 8. Install and configure bootloader

```bash
# Install required packages
apt update
apt install cryptsetup-initramfs lvm2

# Configure crypttab
echo "sda2_crypt UUID=$(blkid -s UUID -o value /dev/sda2) none luks" \
  >> /etc/crypttab

# Update fstab
cat > /etc/fstab <<EOF
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/ubuntu-vg/ubuntu-lv /      ext4    defaults        0       1
UUID=$(blkid -s UUID -o value /dev/sda1) /boot/efi vfat umask=0077 0 1
EOF

# Rebuild initramfs
update-initramfs -u -k all

# Install GRUB

# For amd64:
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu

# For arm64:
grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu

update-grub
```

#### 9. Configure GRUB for LUKS

Edit /etc/default/grub:

<!-- markdownlint-disable MD013 -->

```bash
GRUB_CMDLINE_LINUX="cryptdevice=UUID=$(blkid -s UUID -o value /dev/sda2):sda2_crypt root=/dev/ubuntu-vg/ubuntu-lv"
```

<!-- markdownlint-enable MD013 -->

Then:

```bash
update-grub
```

#### 10. Configure initial user with cloud-init

The image has no default user. You must configure one via cloud-init.

Create a cloud-init configuration to set up the initial user:

```bash
mkdir -p /mnt/var/lib/cloud/seed/nocloud

cat > /mnt/var/lib/cloud/seed/nocloud/meta-data << EOF
instance-id: iid-$(uuidgen)
local-hostname: $(head -c 4 /dev/urandom | xxd -p)
EOF

cat > /mnt/var/lib/cloud/seed/nocloud/user-data << 'EOF'
#cloud-config
users:
  - name: myuser
    groups: [sudo]
    lock_passwd: true
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAA... your-key-here
EOF
```

Replace `myuser` with your username, and add your SSH public key.

### 11. Exit and reboot

```bash
exit
umount -R /mnt
reboot
```

## Usage

After reboot, log in via SSH with your configured user and key.

## Roadmap

See the [open issues](https://github.com/pgodschalk/ubuntu-server-image/issues)
for a list of proposed features (and known issues).

- [Top Feature Requests](https://github.com/pgodschalk/ubuntu-server-image/issues?q=label%3Aenhancement+is%3Aopen+sort%3Areactions-%2B1-desc)
  (Add your votes using the 👍 reaction)
- [Top Bugs](https://github.com/pgodschalk/ubuntu-server-image/issues?q=is%3Aissue+is%3Aopen+label%3Abug+sort%3Areactions-%2B1-desc)
  (Add your votes using the 👍 reaction)
- [Newest Bugs](https://github.com/pgodschalk/ubuntu-server-image/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Support

Reach out to the maintainer at one of the following places:

- [GitHub issues](https://github.com/pgodschalk/ubuntu-server-image/issues/new?assignees=&labels=question&template=04_SUPPORT_QUESTION.md&title=support%3A+)
- Contact options listed on [this GitHub profile](https://github.com/pgodschalk)

## Project assistance

If you want to say **thank you** or/and support active development of
ubuntu-server-image:

- Add a [GitHub Star](https://github.com/pgodschalk/ubuntu-server-image) to the
  project.
- Write interesting articles about the project on [Dev.to](https://dev.to/),
  [Medium](https://medium.com/) or your personal blog.

Together, we can make ubuntu-server-image **better**!

## Contributing

First off, thanks for taking the time to contribute! Contributions are what make
the open-source community such an amazing place to learn, inspire, and create.
Any contributions you make will benefit everybody else and are **greatly
appreciated**.

Please read [our contribution guidelines](CONTRIBUTING.md), and thank you for
being involved!

## Authors & contributors

The original setup of this repository is by
[Patrick Godschalk](https://github.com/pgodschalk).

For a full list of all authors and contributors, see
[the contributors page](https://github.com/pgodschalk/ubuntu-server-image/contributors).

## Security

ubuntu-server-image follows good practices of security, but 100% security cannot
be assured. ubuntu-server-image is provided **"as is"** without any
**warranty**. Use at your own risk.

_For more information and to report security issues, please refer to our
[security documentation](SECURITY.md)._

## License

This project is licensed under the MIT license.

See [LICENSE](LICENSE.txt) for more information.

## Acknowledgements

- Hardening based off the
  [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
