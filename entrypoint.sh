#!/bin/bash
set -e

OWNER_REPO="${REPO_URL#https://github.com/}"
OWNER_REPO="${OWNER_REPO%.git}"
OWNER_REPO="${OWNER_REPO%/}"

get_fresh_removal_token() {
  curl -sf --max-time 5 -X POST \
    -H "Authorization: Bearer ${GH_PAT}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER_REPO}/actions/runners/remove-token" \
    | jq -r .token
}

cleanup() {
  local token="${RUNNER_TOKEN}"
  local fresh
  if [ -n "${GH_PAT}" ]; then
    fresh="$(get_fresh_removal_token)" || fresh=""
    if [ -n "${fresh}" ] && [ "${fresh}" != "null" ]; then
      token="${fresh}"
    else
      echo "entrypoint: could not get a fresh removal token from GitHub, falling back to RUNNER_TOKEN" >&2
    fi
  fi
  if ! ./config.sh remove --token "${token}"; then
    echo "entrypoint: failed to deregister runner from GitHub; it may remain listed as offline" >&2
  fi
}
trap cleanup EXIT

./config.sh --url "${REPO_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME:-docker-runner}" \
  --work "_work" \
  --unattended \
  --replace

./run.sh
