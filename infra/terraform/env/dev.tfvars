# Hackathon lab project. No secrets in this file.
project_id = "qwiklabs-gcp-00-cc29ec8bfdd9"
region     = "europe-west1"

# Placeholder; infra/scripts/deploy.sh passes -var image_tag=<git sha>-<timestamp>.
image_tag = "latest"

# Teammates' services stay off until they have images.
deploy_agent = false
deploy_api   = false

# Add teammates' Google accounts here to give them run/firestore/registry/log access.
team_members = []

allow_public = true
