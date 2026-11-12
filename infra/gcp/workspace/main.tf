# Provider: credentials come from `gcloud auth application-default login`.
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# --- APIs -------------------------------------------------------------------
# Enabling an already-enabled API is a no-op.

resource "google_project_service" "compute" {
  service = "compute.googleapis.com"

  # Keep the API on after `tofu destroy`; deleting the project is the full cleanup.
  disable_on_destroy = false
}

# Needed for SSH through Identity-Aware Proxy (no SSH port open to the internet).
resource "google_project_service" "iap" {
  service            = "iap.googleapis.com"
  disable_on_destroy = false
}

# --- Network ----------------------------------------------------------------
# Own VPC instead of the project's "default" network, whose default-allow-ssh
# rule accepts SSH from 0.0.0.0/0.

resource "google_compute_network" "workspace" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "workspace" {
  name          = "${var.name}-subnet"
  network       = google_compute_network.workspace.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/24"
}

# Only Google's IAP range may reach port 22. Nothing else gets in.
resource "google_compute_firewall" "iap_ssh" {
  name      = "${var.name}-allow-iap-ssh"
  network   = google_compute_network.workspace.id
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# --- VM ---------------------------------------------------------------------

resource "google_compute_instance" "workspace" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [var.name]

  # Lets `tofu apply` stop the VM to change machine_type instead of failing.
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64" # image family: latest 24.04
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.workspace.id

    # Ephemeral public IP for outbound internet (apt, git, Tailscale).
    # Inbound is still blocked by the firewall above.
    access_config {}
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    # Only the key from cloud-init may log in; ignore project-wide keys.
    block-project-ssh-keys = "TRUE"

    user-data = templatefile("${path.module}/../../shared/cloud-init.yaml.tftpl", {
      username       = var.ssh_user
      ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
    })
  }

  # No service_account block: the VM gets no Google Cloud credentials.

  lifecycle {
    # A new Ubuntu image in the family must not recreate (wipe) the VM.
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }

  depends_on = [google_project_service.iap]
}
