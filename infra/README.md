# infra

Cloud dev workspaces as code, managed with [OpenTofu](https://opentofu.org/) (open source Terraform fork, same HCL, `tofu` CLI). Not stowed.

## Layout

```
infra/
  shared/            cloud-agnostic pieces (cloud-init bootstrap used by every cloud)
  gcp/workspace/     GCP dev VM
  azure/workspace/   Azure dev VM (later)
```

Each `<cloud>/workspace/` is a standalone root: its own provider, variables, and state. All of them take the same inputs (name, size, SSH key) and expose the same outputs (IP, SSH command), so switching clouds means changing directory, not workflow.

## Workflow

```bash
cd infra/gcp/workspace
cp terraform.tfvars.example terraform.tfvars   # fill real values, never committed
tofu init      # download providers
tofu plan      # preview changes
tofu apply     # create/update
tofu destroy   # delete everything this root created
```
