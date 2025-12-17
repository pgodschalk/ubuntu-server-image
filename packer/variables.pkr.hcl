variable "arch" {
  type        = string
  default     = "arm64"
  description = "Target architecture: arm64 or amd64"

  validation {
    condition     = contains(["arm64", "amd64"], var.arch)
    error_message = "Architecture must be 'arm64' or 'amd64'."
  }
}

variable "accelerator" {
  type        = string
  default     = "kvm"
  description = "QEMU accelerator: kvm (Linux), hvf (macOS), or tcg (emulation)"

  validation {
    condition     = contains(["kvm", "hvf", "tcg"], var.accelerator)
    error_message = "Accelerator must be 'kvm', 'hvf', or 'tcg'."
  }
}

variable "cpu_model" {
  type        = string
  default     = "host"
  description = "QEMU CPU model: 'host' for native, or specific model for emulation"
}

variable "efi_firmware_code" {
  type = object({
    arm64 = string
    amd64 = string
  })
  default = {
    # Ubuntu 24.04 uses 4M variants
    arm64 = "/usr/share/AAVMF/AAVMF_CODE.fd"
    amd64 = "/usr/share/OVMF/OVMF_CODE_4M.fd"
  }
  description = "Path to EFI firmware code by architecture"
}

variable "efi_firmware_vars" {
  type = object({
    arm64 = string
    amd64 = string
  })
  default = {
    # Ubuntu 24.04 uses 4M variants
    arm64 = "/usr/share/AAVMF/AAVMF_VARS.fd"
    amd64 = "/usr/share/OVMF/OVMF_VARS_4M.fd"
  }
  description = "Path to EFI firmware vars by architecture"
}
