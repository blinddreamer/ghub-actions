# GitHub Actions Self-Hosted Runner (Docker)

A Dockerized GitHub Actions self-hosted runner with Docker-outside-of-Docker (DooD) support.

## How it works

The runner container installs only the Docker CLI and mounts the host's `/var/run/docker.sock`, so `docker build` / `docker run` steps in your workflows talk directly to the host daemon. Containers spun up by workflows are siblings on the host, not nested children.

## Prerequisites

- Docker installed on the Linux host
- A fine-grained PAT (`GH_PAT`) with **Administration: Read & write** on the target repo (recommended), or
- a one-off registration token (expires ~1 hour, single-use) from **repo → Settings → Actions → Runners → New self-hosted runner**

## Usage

### 1. Build the image

```bash
docker build -t gha-runner \
  --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3) .
```

The `DOCKER_GID` build arg matches the runner user's group to the host `docker` group so it can access the socket without `root`.

### 2. Run the container

```bash
docker run -d --name my-runner --restart unless-stopped \
  -e REPO_URL="https://github.com/<owner>/<repo>" \
  -e RUNNER_NAME="my-runner" \
  --env-file runner.env \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gha-runner
```

`runner.env` holds `GH_PAT=<pat>`. With `GH_PAT` set, the runner mints a fresh registration
token on every start, so it re-registers by itself after a restart, reboot or image update.
Without it, pass `-e RUNNER_TOKEN="<fresh-token>"` instead; that token is single-use and
expires after ~1 hour, so the container cannot come back after a restart.

### Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `REPO_URL` | yes | — | GitHub repository URL to register against |
| `GH_PAT` | yes, unless `RUNNER_TOKEN` | — | Fine-grained PAT with **Administration: Read & write** on the repo. Used to mint a fresh registration token at every start and a fresh removal token at shutdown, so the runner survives restarts. Falls back to `RUNNER_TOKEN` if the API call fails. |
| `RUNNER_TOKEN` | only without `GH_PAT` | — | One-off registration token from GitHub (single-use, ~1 hour) |
| `RUNNER_NAME` | no | `docker-runner` | Display name shown in GitHub UI |

### Stop and deregister

```bash
docker stop my-runner
```

The container's `EXIT` trap automatically calls `config.sh remove`, cleanly deregistering the runner from GitHub before it exits. If `GH_PAT` is set, the trap first fetches a fresh **removal** token from GitHub's `remove-token` API endpoint (distinct from the registration-token endpoint used at startup), so removal still works even if `RUNNER_TOKEN` has expired by the time the container stops.

## Build arguments

| Argument | Default | Description |
|---|---|---|
| `RUNNER_VERSION` | `2.338.2` | GitHub Actions runner version to install |
| `DOCKER_GID` | `999` | Host `docker` group GID for socket access |

## Notes

- **Tokens expire** — with `GH_PAT` set this is handled for you. With only `RUNNER_TOKEN`, grab a new one right before each `docker run`; do not reuse tokens from previous runs.
- **`--replace`** is set in `entrypoint.sh`, so restarting the container with the same `RUNNER_NAME` won't error with "runner already exists".
- **DooD caveat** — if a workflow step does `-v $(pwd):/app`, the path resolves to the runner container's filesystem path, not the host path. Use absolute host paths or named volumes when mounting inside workflow steps.
- **No `svc.sh`** — `run.sh` runs in the foreground as PID 1, which is the correct Docker pattern (no systemd inside the container).
- **`GH_PAT` scope** — only needs `Administration: Read & write` on the target repo (that's what the registration-token endpoint requires). Pass it in via a secrets manager or `--env-file`, not baked into the image.
