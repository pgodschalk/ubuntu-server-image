packer {
  required_version = ">= 1.14.3"

  required_plugins {
    qemu = {
      version = ">= 1.1.4"
      source  = "github.com/hashicorp/qemu"
    }

    ansible = {
      version = ">= 1.1.4"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

locals {
  # SSH key paths - generate with: ssh-keygen -t ed25519 -f packer/build_key -N ""
  # Workaround for https://github.com/hashicorp/packer-plugin-qemu/issues/182
  ssh_private_key = "${path.root}/build_key"
  ssh_public_key  = file("${path.root}/build_key.pub")

  arch_config = {
    arm64 = {
      machine_type    = "virt"
      image_url       = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img"
      qemu_binary     = "qemu-system-aarch64"
      cdrom_interface = "virtio"
    }
    amd64 = {
      machine_type    = "q35"
      image_url       = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
      qemu_binary     = "qemu-system-x86_64"
      cdrom_interface = "ide"
    }
  }

  config         = local.arch_config[var.arch]
  image_checksum = "file:https://cloud-images.ubuntu.com/releases/24.04/release/SHA256SUMS"
}

source "qemu" "ubuntu" {
  accelerator      = var.accelerator
  disk_interface   = "virtio-scsi"
  disk_discard     = "unmap"
  disk_compression = true
  headless         = true
  disk_image       = true
  machine_type     = local.config.machine_type
  qemu_binary      = local.config.qemu_binary
  cdrom_interface  = local.config.cdrom_interface
  cpu_model        = var.cpu_model
  iso_checksum     = local.image_checksum
  iso_url          = local.config.image_url
  cd_content = {
    "meta-data" = ""
    "user-data" = <<-EOF
      #cloud-config
      hostname: ubuntu-server
      users:
        - name: ubuntu
          groups: [sudo]
          sudo: ALL=(ALL) NOPASSWD:ALL
          lock_passwd: true
          shell: /bin/bash
          ssh_authorized_keys:
            - ${trimspace(local.ssh_public_key)}
      EOF
  }
  cd_label         = "cidata"
  shutdown_command = "sudo sh -c \"sed -i '/^ubuntu:/d' /etc/passwd /etc/shadow /etc/group /etc/gshadow && rm -rf /home/ubuntu && shutdown -P now\""
  ssh_username     = "ubuntu"
  ssh_ciphers = [
    "chacha20-poly1305@openssh.com",
    "aes128-gcm@openssh.com",
    "aes256-ctr",
    "aes192-ctr",
    "aes128-ctr"
  ]
  ssh_key_exchange_algorithms = [
    "curve25519-sha256@libssh.org",
    "ecdh-sha2-nistp521",
    "ecdh-sha2-nistp384",
    "ecdh-sha2-nistp256"
  ]
  ssh_private_key_file = local.ssh_private_key
  efi_boot             = true
  efi_firmware_code    = var.efi_firmware_code[var.arch]
  efi_firmware_vars    = var.efi_firmware_vars[var.arch]
  cpus                 = 2
}

build {
  name    = "ubuntu-server"
  sources = ["source.qemu.ubuntu"]

  provisioner "ansible" {
    playbook_file = "../ansible/site.yml"
    extra_arguments = [
      "-e", "ansible_remote_tmp=/var/tmp/.ansible"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs --machine-id --seed --configs network --configs datasource",
    ]
    remote_folder = "/var/tmp"
  }

  # All post-processors in a single sequence so checksum only runs once at the end
  post-processors {
    # Run virt-sysprep on the image after shutdown to clean up any files
    # created during shutdown and perform additional cleanup.
    # Requires libguestfs-tools (Linux only).
    post-processor "shell-local" {
      inline = [
        "if command -v virt-sysprep >/dev/null 2>&1; then sudo virt-sysprep -a output-ubuntu/packer-ubuntu --operations defaults; fi",
        "if command -v virt-sparsify >/dev/null 2>&1; then sudo virt-sparsify --in-place output-ubuntu/packer-ubuntu; fi"
      ]
    }

    post-processor "checksum" {
      checksum_types = ["sha256"]
      output         = "packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
    }

    post-processor "manifest" {}
  }
}
