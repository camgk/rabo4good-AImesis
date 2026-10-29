# infra

Terraform and scripts that put the AImesis demo on Cloud Run in the hackathon
project `qwiklabs-gcp-00-cc29ec8bfdd9` (region `europe-west1`).

> Prototype. Demo data only, no real patient data.

## What gets created

| Resource | Name | Notes |
|---|---|---|
| Project services | run, artifactregistry, firestore, cloudbuild, compute, iam, iamcredentials, logging, aiplatform, storage | `disable_on_destroy = false` |
| Artifact Registry (Docker) | `aimesis` | `europe-west1-docker.pkg.dev/<project>/aimesis/<image>:<tag>` |
| Firestore (native) | `(default)` | The team database from PR #3 (patients, passports, episodes), adopted with an import block. Kept on destroy (`deletion_policy = ABANDON`). Demo records are tagged `demo`. |
| Service account | `aimesis-mock-api` | `roles/datastore.user`, `roles/logging.logWriter`, `roles/aiplatform.user` (Gemini cycle summary) |
| Service account | `aimesis-web` | No roles (static nginx) |
| IAM for builds | compute default SA (+ legacy `<number>@cloudbuild` SA) | `cloudbuild.builds.builder`, `artifactregistry.writer`, `logging.logWriter`, `storage.objectViewer`, so `gcloud builds submit` works in a fresh project |
| IAM for teammates | `var.team_members` | `run.developer`, `datastore.user`, `artifactregistry.writer`, `logging.viewer` |
| Cloud Run | `mock-api` | `backend/mock_api` (FastAPI + Firestore + UZA v2 rules engine `backend/rules` + Gemini on Vertex AI). Min 1 instance, 1 vCPU / 1 Gi; env `GOOGLE_CLOUD_LOCATION=global`, `AIMESIS_GEMINI_MODEL=gemini-2.5-flash` |
| Cloud Run | `web` | Care-team Flutter web app on nginx. Min 1, 512 Mi. `API_URL` = mock-api URL |
| Cloud Run | `family-web` | Family app (`frontend/ios`) built as Flutter web, phone-width fallback. Min 1 |
| Cloud Run | `api`, `agent` | Teammates' real services. **Off by default** (`deploy_api`, `deploy_agent`) |
| Public access | `roles/run.invoker` → `allUsers` | Per deployed service when `allow_public = true` |
| `random_password` | `token_secret` | JWT signing key for mock-api, also the `X-Demo-Reset` value |

Outside Terraform, `bootstrap.sh` creates two buckets: `gs://<project>-tfstate`
(Terraform state, versioned) and `gs://<project>-build-src` (Cloud Build source
uploads, in the EU).

## Prerequisites

- `gcloud`, logged in with an account that is Owner on the project: `gcloud auth login`
- Terraform 1.6 or later
- Flutter (stable). The scripts look for `$FLUTTER`, then `flutter` on `PATH`,
  then `~/development/flutter/bin/flutter`, then `/opt/flutter/bin/flutter`.
- No Docker needed: images are built remotely with Cloud Build.

The scripts run on macOS (`/bin/bash` 3.2) and Linux. Terraform uses gcloud's
access token, so you do **not** need `gcloud auth application-default login`
(set `USE_ADC=1` if you prefer ADC).

## Deploy (one command)

```bash
gcloud auth login
infra/scripts/deploy.sh
```

What it does:

1. `bootstrap.sh`: enables the base APIs, creates the state and build buckets,
   runs `terraform init` against `gs://<project>-tfstate`.
2. Terraform phase 1 (`-target`): APIs, registry, Firestore, service accounts, IAM.
3. Builds and pushes images with Cloud Build, tagged `<git sha>-<UTC timestamp>`:
   - `mock-api` from `backend/mock_api` + `backend/rules` (temp build context)
   - `web`: `flutter build web --release` in `frontend/web`, then the nginx image from `frontend/web/Dockerfile`
   - `family-web`: `flutter build web --release` in `frontend/ios`, packed with the same nginx Dockerfile
4. Terraform phase 2: all Cloud Run services and public access.
5. Prints the URLs and smoke-tests `mock-api /healthz` and `config.json` on both frontends.

Faster variants:

```bash
infra/scripts/deploy.sh --only web          # rebuild one image: api | web | family
infra/scripts/deploy.sh --skip-build        # re-apply Terraform with the current images
TAG=abc1234-20261029-140000 infra/scripts/deploy.sh --skip-build   # roll back to a tag
```

Only Terraform:

```bash
cd infra/terraform
terraform init -backend-config="bucket=qwiklabs-gcp-00-cc29ec8bfdd9-tfstate"
terraform apply -var-file=env/dev.tfvars -var image_tag=<tag>
```

## Outputs

```bash
terraform -chdir=infra/terraform output
terraform -chdir=infra/terraform output -raw token_secret   # sensitive
```

`mock_api_url`, `web_url`, `family_web_url`, `api_url` / `agent_url` (null unless
switched on), `firestore_database`, `artifact_registry`, `token_secret`, plus the
image references currently deployed.

## Demo data

The API starts with an empty database. Demo patients (Casus 1–4), their passports,
the six demo accounts and the Belgian reference resources are loaded by script.
Everything demo carries the tag `demo`, so it can be removed without touching real records.

```bash
infra/scripts/demo-data.sh load            # idempotent upsert
infra/scripts/demo-data.sh load --reset    # clear demo data first, then load (fresh demo)
infra/scripts/demo-data.sh clear           # dry run: shows what would be deleted
infra/scripts/demo-data.sh clear --yes     # delete demo-tagged records and their episodes/passports
```

## Switching on the teammates' agent and api

Build and push the image yourself, then apply with the flags:

```bash
REG=europe-west1-docker.pkg.dev/qwiklabs-gcp-00-cc29ec8bfdd9/aimesis
gcloud builds submit backend/agent --tag $REG/agent:v1     # build context per the agent's Dockerfile

cd infra/terraform
terraform apply -var-file=env/dev.tfvars \
  -var image_tag="$(terraform output -raw image_tag)" \
  -var deploy_agent=true -var agent_image=$REG/agent:v1
```

Same for the api: `-var deploy_api=true -var api_image=$REG/api:v1`.

- `agent` runs as `aimesis-agent` with `roles/aiplatform.user`, env
  `GOOGLE_CLOUD_LOCATION=global` and `GOOGLE_GENAI_USE_VERTEXAI=TRUE`, 300 s timeout for SSE.
- `api` runs as `aimesis-api` with `roles/datastore.user` and env `FIRESTORE_DATABASE=(default)`.

To keep them on, set `deploy_agent = true` and `agent_image = "..."` in
`env/dev.tfvars`. Otherwise the next `deploy.sh` run removes them again.

## Adding team members

Add their Google accounts to `env/dev.tfvars` and redeploy (or run `terraform apply`):

```hcl
team_members = ["teammate1@gmail.com", "teammate2@gmail.com"]
```

A bare email becomes `user:<email>`. Pass `group:...` or `serviceAccount:...` for anything else.

## If an org policy gets in the way

- **`allUsers` blocked** (domain-restricted sharing): the scripts notice the
  error and retry with `public_via_invoker_iam_disabled = true`, which turns off
  the Cloud Run invoker check instead of granting `allUsers`. The fallback is saved
  in `infra/terraform/local.auto.tfvars` (git-ignored). If that is blocked too,
  open the services through an authenticated proxy:
  `gcloud run services proxy web --region europe-west1 --port 8081`. This only
  works for the frontends; the browser calls to mock-api still need a public URL.
- **Legacy Cloud Build SA does not exist**: the scripts retry with
  `grant_legacy_cloudbuild_sa = false`.
- **Cloud Build permission errors right after phase 1**: IAM can take a minute
  to propagate. The scripts retry each build up to three times.

## Costs

For a single demo day this costs a few euros at most. `min_instance_count = 1`
on `mock-api`, `web` and `family-web` keeps three small instances warm (no cold
starts during the demo), which is the main cost. Set the minimum to 0 or run
`destroy.sh` after the showcase. Firestore, Artifact Registry and Cloud Build stay
within or near the free tier at demo volumes.

## Security notes (demo shortcuts)

- `TOKEN_SECRET` is a plain Cloud Run env var generated by Terraform and kept in
  the state bucket. **Next step: Secret Manager** (`secret_key_ref`) .
- All services are public and CORS is open. Fine for mock data, not for anything real.

## Cleanup

```bash
infra/scripts/destroy.sh            # asks you to type the project id
```

This deletes the Cloud Run services (the Firestore database and its data are kept) and all its
data, the registry with all images, the service accounts and the IAM grants. The
state and build buckets stay; the script prints the command to remove them.

## Files

| Path | What |
|---|---|
| `terraform/providers.tf`, `backend.tf` | Provider pins, GCS backend (bucket passed at init) |
| `terraform/variables.tf`, `env/dev.tfvars` | Inputs; no secrets in tfvars |
| `terraform/apis.tf`, `artifact_registry.tf`, `firestore.tf`, `iam.tf` | Foundations |
| `terraform/cloud_run_*.tf` | `mock-api`, `web`, `family-web`, and the switchable `api` / `agent` |
| `terraform/outputs.tf` | URLs, image refs, token secret |
| `scripts/bootstrap.sh`, `deploy.sh`, `destroy.sh`, `_common.sh` | Workflow scripts |
