#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
readonly SCRIPT_DIR

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v]

Build a UTM vagrant box from Ubuntu cloud image.

Available options:

-h, --help          Print this help and exit
-v, --verbose       Print script debug info
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
  else
    NOFORMAT=''
    RED=''
    GREEN=''
    BLUE=''
  fi
  readonly NOFORMAT RED GREEN BLUE
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1}
  msg "${RED}${msg}${NOFORMAT}"
  exit "$code"
}

parse_params() {
  while :; do
    case "${1-}" in
      -h | --help) usage ;;
      -v | --verbose) set -x ;;
      --no-color) NO_COLOR=1 ;;
      -?*) die "Unknown option: $1" ;;
      *) break ;;
    esac
    shift
  done

  return 0
}

parse_params "$@"
setup_colors

# Check required tools
for cmd in curl qemu-img hdiutil uuidgen tar; do
  command -v "${cmd}" >/dev/null || die "Required tool not found: ${cmd}"
done

# Detect architecture
ARCH=$(uname -m)
case "${ARCH}" in
  arm64 | aarch64)
    UBUNTU_ARCH="arm64"
    QEMU_ARCH="aarch64"
    ;;
  x86_64 | amd64)
    UBUNTU_ARCH="amd64"
    QEMU_ARCH="x86_64"
    ;;
  *)
    die "Unsupported architecture: ${ARCH}"
    ;;
esac

# Configuration
readonly BOX_NAME="ubuntu-server-image"
readonly CLOUD_INIT_DIR="${SCRIPT_DIR}/cloud-init"
readonly WORK_DIR="${SCRIPT_DIR}/.box-build"
readonly UBUNTU_VERSION="24.04"
readonly UBUNTU_IMAGE="ubuntu-${UBUNTU_VERSION}-server-cloudimg-${UBUNTU_ARCH}.img"
readonly UBUNTU_URL="https://cloud-images.ubuntu.com/releases/${UBUNTU_VERSION}/release/${UBUNTU_IMAGE}"
readonly UBUNTU_SHA256SUMS_URL="https://cloud-images.ubuntu.com/releases/${UBUNTU_VERSION}/release/SHA256SUMS"

# UUIDs for the VM
CIDATA_UUID=$(uuidgen)
readonly CIDATA_UUID
DISK_UUID=$(uuidgen)
readonly DISK_UUID
VM_UUID=$(uuidgen)
readonly VM_UUID

msg "${GREEN}Building UTM vagrant box for ${UBUNTU_ARCH}...${NOFORMAT}"
msg "VM UUID: ${VM_UUID}"
msg "Disk UUID: ${DISK_UUID}"

# Clean up previous build
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}/box.utm/Data"

# Download Ubuntu cloud image
msg "${BLUE}Downloading Ubuntu ${UBUNTU_VERSION} cloud image...${NOFORMAT}"
if [[ -f "${SCRIPT_DIR}/${UBUNTU_IMAGE}" ]]; then
  msg "Using cached image: ${UBUNTU_IMAGE}"
  cp "${SCRIPT_DIR}/${UBUNTU_IMAGE}" \
    "${WORK_DIR}/box.utm/Data/${DISK_UUID}.qcow2"
else
  curl --location --output "${WORK_DIR}/box.utm/Data/${DISK_UUID}.qcow2" \
    "${UBUNTU_URL}"
fi

# Verify checksum
msg "${BLUE}Verifying image checksum...${NOFORMAT}"
curl --silent --location --output "${WORK_DIR}/SHA256SUMS" \
  "${UBUNTU_SHA256SUMS_URL}"
EXPECTED_CHECKSUM=$(grep "${UBUNTU_IMAGE}" "${WORK_DIR}/SHA256SUMS" \
  | awk '{print $1}')
ACTUAL_CHECKSUM=$(shasum -a 256 "${WORK_DIR}/box.utm/Data/${DISK_UUID}.qcow2" \
  | awk '{print $1}')
if [[ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]]; then
  die "Checksum verification failed for ${UBUNTU_IMAGE}"
fi
msg "${GREEN}Checksum verified${NOFORMAT}"

# Resize disk image
msg "${BLUE}Resizing disk image to 20GB...${NOFORMAT}"
qemu-img resize "${WORK_DIR}/box.utm/Data/${DISK_UUID}.qcow2" 20G

# Create EFI vars file
msg "${BLUE}Creating EFI variables file...${NOFORMAT}"
if [[ "${QEMU_ARCH}" == "aarch64" ]]; then
  # Create empty 64MB EFI vars file for ARM
  dd if=/dev/zero \
    of="${WORK_DIR}/box.utm/efi_vars.fd" bs=1m count=64 2>/dev/null
else
  # Create empty 128KB EFI vars file for x86_64
  dd if=/dev/zero \
    of="${WORK_DIR}/box.utm/efi_vars.fd" bs=1k count=128 2>/dev/null
fi

# Create cloud-init ISO
msg "${BLUE}Creating cloud-init ISO...${NOFORMAT}"
[[ -f "${CLOUD_INIT_DIR}/user-data" ]] \
  || die "Missing ${CLOUD_INIT_DIR}/user-data"
cat >"${CLOUD_INIT_DIR}/meta-data" <<EOF
---
instance-id: iid-vagrant-$(uuidgen | cut -d- -f1)
local-hostname: ubuntu-server-image
...
EOF

# Create cloud-init ISO using hdiutil (macOS native)
hdiutil makehybrid -iso -joliet -o \
  "${WORK_DIR}/box.utm/Data/${CIDATA_UUID}.iso" \
  "${CLOUD_INIT_DIR}" \
  -default-volume-name cidata
mv "${WORK_DIR}/box.utm/Data/${CIDATA_UUID}.iso.iso" \
  "${WORK_DIR}/box.utm/Data/${CIDATA_UUID}.iso" 2>/dev/null || true

# Generate random MAC address for network interface
MAC_ADDR_EMULATED=$(printf 'AE:%02X:%02X:%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))

# Create config.plist with UTM 4.x format
msg "${BLUE}Creating config.plist...${NOFORMAT}"
cat >"${WORK_DIR}/box.utm/config.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Backend</key>
	<string>QEMU</string>
	<key>ConfigurationVersion</key>
	<integer>4</integer>
	<key>Display</key>
	<array>
		<dict>
			<key>DownscalingFilter</key>
			<string>Linear</string>
			<key>DynamicResolution</key>
			<true/>
			<key>Hardware</key>
			<string>virtio-gpu-pci</string>
			<key>NativeResolution</key>
			<false/>
			<key>UpscalingFilter</key>
			<string>Nearest</string>
		</dict>
	</array>
	<key>Drive</key>
	<array>
		<dict>
			<key>Identifier</key>
			<string>${CIDATA_UUID}</string>
			<key>ImageName</key>
			<string>${CIDATA_UUID}.iso</string>
			<key>ImageType</key>
			<string>CD</string>
			<key>Interface</key>
			<string>VirtIO</string>
			<key>InterfaceVersion</key>
			<integer>1</integer>
			<key>ReadOnly</key>
			<true/>
		</dict>
		<dict>
			<key>Identifier</key>
			<string>${DISK_UUID}</string>
			<key>ImageName</key>
			<string>${DISK_UUID}.qcow2</string>
			<key>ImageType</key>
			<string>Disk</string>
			<key>Interface</key>
			<string>VirtIO</string>
			<key>InterfaceVersion</key>
			<integer>1</integer>
			<key>ReadOnly</key>
			<false/>
		</dict>
	</array>
	<key>Information</key>
	<dict>
		<key>Icon</key>
		<string>linux</string>
		<key>IconCustom</key>
		<false/>
		<key>Name</key>
		<string>Ubuntu Server</string>
		<key>UUID</key>
		<string>${VM_UUID}</string>
	</dict>
	<key>Input</key>
	<dict>
		<key>MaximumUsbShare</key>
		<integer>3</integer>
		<key>UsbBusSupport</key>
		<string>3.0</string>
		<key>UsbSharing</key>
		<false/>
	</dict>
	<key>Network</key>
	<array>
		<dict>
			<key>Hardware</key>
			<string>virtio-net-pci</string>
			<key>IsolateFromHost</key>
			<false/>
			<key>MacAddress</key>
			<string>${MAC_ADDR_EMULATED}</string>
			<key>Mode</key>
			<string>Emulated</string>
			<key>PortForward</key>
			<array/>
		</dict>
	</array>
	<key>QEMU</key>
	<dict>
		<key>AdditionalArguments</key>
		<array/>
		<key>BalloonDevice</key>
		<false/>
		<key>DebugLog</key>
		<false/>
		<key>GuestAgent</key>
		<true/>
		<key>Hypervisor</key>
		<true/>
		<key>PS2Controller</key>
		<false/>
		<key>RNGDevice</key>
		<true/>
		<key>RTCLocalTime</key>
		<false/>
		<key>TPMDevice</key>
		<false/>
		<key>TSO</key>
		<false/>
		<key>UEFIBoot</key>
		<true/>
	</dict>
	<key>Serial</key>
	<array/>
	<key>Sharing</key>
	<dict>
		<key>ClipboardSharing</key>
		<true/>
		<key>DirectoryShareMode</key>
		<string>VirtFS</string>
		<key>DirectoryShareReadOnly</key>
		<false/>
	</dict>
	<key>Sound</key>
	<array/>
	<key>System</key>
	<dict>
		<key>Architecture</key>
		<string>${QEMU_ARCH}</string>
		<key>CPU</key>
		<string>default</string>
		<key>CPUCount</key>
		<integer>0</integer>
		<key>CPUFlagsAdd</key>
		<array/>
		<key>CPUFlagsRemove</key>
		<array/>
		<key>ForceMulticore</key>
		<false/>
		<key>JITCacheSize</key>
		<integer>0</integer>
		<key>MemorySize</key>
		<integer>2048</integer>
		<key>Target</key>
		<string>virt</string>
	</dict>
</dict>
</plist>
EOF

# Create metadata.json
msg "${BLUE}Creating metadata.json...${NOFORMAT}"
cat >"${WORK_DIR}/metadata.json" <<EOF
{
	"provider": "utm"
}
EOF

# Create box Vagrantfile
msg "${BLUE}Creating box Vagrantfile...${NOFORMAT}"
cat >"${WORK_DIR}/Vagrantfile" <<'VAGRANTFILE_EOF'
# frozen_string_literal: true

# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.provider :utm do |utm|
    utm.cpus = 2
    utm.memory = 2048
  end
end
VAGRANTFILE_EOF

# Package the box
msg "${BLUE}Packaging box...${NOFORMAT}"
cd "${WORK_DIR}"
tar cvf "${SCRIPT_DIR}/${BOX_NAME}.box" metadata.json Vagrantfile box.utm

msg ""
msg "${GREEN}Box created: ${SCRIPT_DIR}/${BOX_NAME}.box${NOFORMAT}"
msg ""
msg "To add the box:"
msg "  vagrant box add --name ubuntu-server-image ${SCRIPT_DIR}/${BOX_NAME}.box"
