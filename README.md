# GitHub Actions Self-Hosted Runner (Docker)

A Dockerized GitHub Actions self-hosted runner with Docker-outside-of-Docker (DooD) support.

## How it works

The runner container installs only the Docker CLI and mounts the host's `/var/run/docker.sock`, so `docker build` / `docker run` steps in your workflows talk directly to the host daemon. Containers spun up by workflows are siblings on the host, not nested children.

## Prerequisites

- Docker installed on the Linux host
- A fresh GitHub Actions registration token (expires ~1 hour, single-use)

Get a token at: **repo → Settings → Actions → Runners → New self-hosted runner**

## Usage

### 1. Build the image

```bash
docker build -t gha-runner \
  --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3) .
```

The `DOCKER_GID` build arg matches the runner user's group to the host `docker` group so it can access the socket without `root`.

### 2. Run the container

```bash
docker run -d --name my-runner \
  -e REPO_URL="https://github.com/<owner>/<repo>" \
  -e RUNNER_TOKEN="<fresh-token>" \
  -e RUNNER_NAME="my-runner" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gha-runner
```

### Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `REPO_URL` | yes | — | GitHub repository URL to register against |
| `RUNNER_TOKEN` | yes | — | Registration token from GitHub |
| `RUNNER_NAME` | no | `docker-runner` | Display name shown in GitHub UI |
| `GH_PAT` | no | — | Fine-grained PAT with **Administration: Read & write** on the repo. Used to mint a fresh removal token at shutdown so deregistration doesn't fail if `RUNNER_TOKEN` has expired (registration tokens last ~1 hour). Without it, removal falls back to `RUNNER_TOKEN` and may silently no-op if that token is already stale. |

### Stop and deregister

```bash
docker stop my-runner
```

The container's `EXIT` trap automatically calls `config.sh remove`, cleanly deregistering the runner from GitHub before it exits. If `GH_PAT` is set, the trap fetches a fresh registration token from the GitHub API first, so removal still works even if `RUNNER_TOKEN` has expired by the time the container stops.

## Build arguments

| Argument | Default | Description |
|---|---|---|
| `RUNNER_VERSION` | `2.329.0` | GitHub Actions runner version to install |
| `DOCKER_GID` | `999` | Host `docker` group GID for socket access |

## Notes

- **Tokens expire** — grab a new one right before each `docker run`. Do not reuse tokens from previous runs.
- **`--replace`** is set in `entrypoint.sh`, so restarting the container with the same `RUNNER_NAME` won't error with "runner already exists".
- **DooD caveat** — if a workflow step does `-v $(pwd):/app`, the path resolves to the runner container's filesystem path, not the host path. Use absolute host paths or named volumes when mounting inside workflow steps.
- **No `svc.sh`** — `run.sh` runs in the foreground as PID 1, which is the correct Docker pattern (no systemd inside the container).
- **`GH_PAT` scope** — only needs `Administration: Read & write` on the target repo (that's what the registration-token endpoint requires). Pass it in via a secrets manager or `--env-file`, not baked into the image.
