#!/bin/bash
set -e

OWNER_REPO="${REPO_URL#https://github.com/}"

get_fresh_removal_token() {
  curl -sf -X POST \
    -H "Authorization: Bearer ${GH_PAT}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER_REPO}/actions/runners/registration-token" \
    | jq -r .token
}

cleanup() {
  local token="${RUNNER_TOKEN}"
  if [ -n "${GH_PAT}" ]; then
    fresh="$(get_fresh_removal_token)" || fresh=""
    [ -n "${fresh}" ] && [ "${fresh}" != "null" ] && token="${fresh}"
  fi
  ./config.sh remove --token "${token}" || true
}
trap cleanup EXIT

./config.sh --url "${REPO_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME:-docker-runner}" \
  --work "_work" \
  --unattended \
  --replace

./run.sh
