#!/bin/bash
set -e

cleanup() {
  ./config.sh remove --unattended --token "${RUNNER_TOKEN}"
}
trap cleanup EXIT

./config.sh --url "${REPO_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME:-docker-runner}" \
  --work "_work" \
  --unattended \
  --replace

./run.sh
