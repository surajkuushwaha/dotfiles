# GCP workspace VM

Personal dev VM on GCP, reached over SSH through Identity-Aware Proxy (IAP). No SSH port is open to the internet.
Values in `<angle brackets>` are placeholders: real ones live only in `terraform.tfvars` (gitignored) and the local gcloud config.

## What it creates

| Resource | Purpose |
|----------|---------|
| `google_project_service` (compute, iap) | APIs the VM and IAP tunnel need |
| `<name>-vpc`, `<name>-subnet` | Own network, so the project's `default` network (SSH open to `0.0.0.0/0`) is never used |
| `<name>-allow-iap-ssh` | Port 22 open only to Google's IAP range `35.235.240.0/20` |
| VM `<name>` | Ubuntu 24.04, `e2-standard-4`, 50 GB `pd-balanced`, Shielded VM, no service account, ephemeral public IP for outbound only |

First boot runs `infra/shared/cloud-init.yaml.tftpl`: creates the user with your SSH public key, installs git, curl and Tailscale, clones the dotfiles over HTTPS, switches `origin` to SSH, and runs `install-linux.sh`.
cloud-init runs only once per VM. Changing it later does not touch an existing VM.

## One-time setup (Mac)

```bash
brew install opentofu gcloud-cli

# Separate gcloud profile, so other accounts/projects never mix in
gcloud config configurations create workspace
gcloud auth login

# Dedicated project linked to the billing account
gcloud projects create <project-id> --name="Dev Workspace"
gcloud billing accounts list
gcloud billing projects link <project-id> --billing-account=<billing-account-id>

gcloud config set project <project-id>
gcloud config set compute/zone asia-south1-a

# Credentials OpenTofu uses (no service-account key files)
gcloud auth application-default login
gcloud auth application-default set-quota-project <project-id>
```

### SSH key (Bitwarden)

The private key stays in Bitwarden. Only the public key is on disk.

1. Bitwarden desktop app → Settings → **Enable SSH agent**. Keep the app open and the vault unlocked when connecting.
2. Check the agent offers the key: `SSH_AUTH_SOCK=~/.bitwarden-ssh-agent.sock ssh-add -L`
   (Mac App Store build: `~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock`)
3. Copy the key item's **Public key**, then:
   ```bash
   pbpaste > ~/.ssh/id_ed25519_workspace.pub
   chmod 600 ~/.ssh/id_ed25519_workspace.pub
   ```

### Variables

```bash
cp terraform.tfvars.example terraform.tfvars   # fill real values; never commit
```

## Create, update, destroy

```bash
cd ~/Personal/dotfiles/infra/gcp/workspace
tofu init                          # once, or after changing providers
tofu fmt && tofu validate
tofu plan -out=workspace.tfplan    # read it: + create, ~ change, -/+ replace (wipes the VM)
tofu apply workspace.tfplan
```

`tofu destroy` deletes the VM and its disk, along with everything on it. Push your work first.

## Connect

Add the generated SSH config once (it tunnels through IAP and uses the Bitwarden agent):

```bash
tofu output -raw ssh_config >> ~/.ssh/config
ssh workspace
```

First connection asks to trust the host key. Verify it against the VM's boot log before typing `yes`:

```bash
gcloud --configuration=workspace compute instances get-serial-port-output workspace \
  | grep -A6 "BEGIN SSH HOST KEY FINGERPRINTS"
```

On the VM, wait for first-boot setup to finish:

```bash
cloud-init status --wait    # status: done
```

## `ws` command (zsh)

Defined in `zsh/.zshrc`. Reads project and zone from the `workspace` gcloud configuration, so no IDs are in the repo.

| Command | Does |
|---------|------|
| `ws start` | Start the VM |
| `ws stop` | Stop the VM (only the disk is billed while stopped) |
| `ws status` | `RUNNING` / `TERMINATED` |
| `ws ssh` | `ssh workspace` |

Starting and stopping is runtime state, not config: do it with `ws`, not Tofu. `tofu plan` stays clean after either.

## On the VM

### Dotfiles (only for a VM created before cloud-init ran `install-linux.sh`)

```bash
git clone https://github.com/<github-user>/dotfiles.git ~/Personal/dotfiles
git -C ~/Personal/dotfiles remote set-url origin git@github.com:<github-user>/dotfiles.git
~/Personal/dotfiles/install-linux.sh    # safe to re-run
exit                                    # reconnect to load zsh + p10k
```

### GitHub (one account, HTTPS through gh)

No private key on the VM. The token is in `~/.config/gh/hosts.yml`, which is gitignored in the dotfiles repo.
Revoke it any time at github.com → Settings → Applications.

```bash
gh auth login    # GitHub.com → HTTPS → authenticate Git: Yes → web browser
git config --global url."https://github.com/".insteadOf "git@github.com:"   # SSH-style remotes go over HTTPS
git config --global user.name "<name>"
git config --global user.email "<github-noreply-email>"
gh auth status
gh extension install dlvhdr/gh-dash
```

SSH agent forwarding is not used: the forwarded agent dies when SSH disconnects, so git inside a reattached tmux session would fail.

### Tailscale (optional)

```bash
sudo tailscale up --ssh    # open the printed URL and log in
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `4003: 'failed to connect to backend'` | VM stopped or still booting | `ws status`; `ws start`, wait ~60 s |
| `Permissions 0644 ... id_ed25519_workspace.pub are too open` + `Permission denied (publickey)` | Bitwarden agent did not offer the key (app closed or vault locked); ssh fell back to the `.pub` file | Open and unlock Bitwarden, check `ssh-add -L` (above), retry |
| `Host key verification failed` | Host key prompt not answered `yes` | Verify fingerprint (see Connect), type `yes` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` after recreating the VM | New VM, new host key | `ssh-keygen -R workspace`, then verify the new fingerprint |
| NumPy warning on connect | Slower IAP tunnel, harmless | `$(gcloud info --format="value(basic.python_location)") -m pip install numpy` and `export CLOUDSDK_PYTHON_SITEPACKAGES=1` |
| Setup failed on first boot | `install-linux.sh` error | On the VM: `sudo tail -100 /var/log/cloud-init-output.log`, fix, re-run the script |

## Cost

- Trial credit expires 90 days after signup, used or not.
- `e2-standard-4` running 24/7 is roughly ₹9–10k/month. Stop it when idle.
- The 50 GB disk is billed even while the VM is stopped.
- Set a budget alert in the console: Billing → Budgets & alerts.

## Security

- Never commit `terraform.tfvars`, `*.tfstate*`, `*.tfplan`, `.terraform/`. `infra/.gitignore` blocks them.
- `tofu plan` output shows your project ID and public key. Don't paste it anywhere public.
- Run `gitleaks dir infra` before committing changes here.
- Don't put work (CultureX) code or credentials on this VM without approval.
