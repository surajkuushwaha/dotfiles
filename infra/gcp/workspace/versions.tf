# Pins the OpenTofu CLI and provider versions this root works with.
terraform {
  required_version = ">= 1.8"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.11" # any 8.x from 8.11 up, never 9.0
    }
  }
}
