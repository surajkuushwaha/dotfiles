# Printed after `tofu apply`. Re-print any time with `tofu output`.

output "instance_name" {
  value = google_compute_instance.workspace.name
}

locals {
  # compact() drops the empty IdentityAgent line when no agent socket is set.
  ssh_config_lines = compact([
    "Host ${var.name}",
    "  HostName ${google_compute_instance.workspace.name}",
    "  User ${var.ssh_user}",
    "  IdentityFile ${var.ssh_public_key_path}",
    "  IdentitiesOnly yes",
    var.ssh_identity_agent != "" ? "  IdentityAgent ${var.ssh_identity_agent}" : "",
    "  ProxyCommand gcloud compute start-iap-tunnel %h 22 --listen-on-stdin --project=${var.project_id} --zone=${var.zone}",
  ])
}

output "ssh_config" {
  description = "Paste into ~/.ssh/config, then `ssh <name>`. Tunnels SSH through IAP."
  value       = "${join("\n", local.ssh_config_lines)}\n"
}
