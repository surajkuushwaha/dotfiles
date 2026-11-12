# Inputs. Real values live in terraform.tfvars (gitignored).

variable "project_id" {
  description = "GCP project ID that holds the workspace."
  type        = string
}

variable "region" {
  description = "GCP region for the workspace."
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP zone for the workspace VM."
  type        = string
  default     = "asia-south1-a"
}

variable "name" {
  description = "Base name for the VM and its network resources."
  type        = string
  default     = "workspace"
}

variable "machine_type" {
  description = "VM size. e2-standard-2 = 2 vCPU/8 GB, e2-standard-4 = 4 vCPU/16 GB."
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB. Billed even while the VM is stopped."
  type        = number
  default     = 50
}

variable "ssh_user" {
  description = "Linux username created on the VM."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key allowed to log in. The private key lives in the SSH agent (e.g. Bitwarden)."
  type        = string
}

variable "ssh_identity_agent" {
  description = "Optional SSH agent socket for the generated ssh_config (e.g. Bitwarden's). Empty = default agent."
  type        = string
  default     = ""
}
