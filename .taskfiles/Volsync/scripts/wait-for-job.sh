#!/usr/bin/env bash
set -euo pipefail

JOB="${1:-}"
NAMESPACE="${2:-default}"

[[ -z "${JOB}" ]] && echo "Job name not specified" && exit 1

while true; do
  # Get phases for pods created by this job (empty if none exist yet)
  STATUS="$(kubectl -n "${NAMESPACE}" get pod -l "job-name=${JOB}" -o jsonpath='{.items[*].status.phase}' 2>/dev/null || true)"
  if [[ -n "${STATUS}" ]]; then
    break
  fi
  sleep 1
done
