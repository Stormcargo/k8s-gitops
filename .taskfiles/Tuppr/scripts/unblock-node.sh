#!/usr/bin/env bash
# Pre-stage a node so tuppr's drain can succeed.
#
# tuppr gives up on the first PodDisruptionBudget refusal instead of retrying
# until its timeout. Longhorn only deletes a node's instance-manager PDB once no
# engine is running there — i.e. once every Longhorn-backed pod has left — and
# a workload pinned to the node by a single-replica volume (CNPG on
# longhorn-cnpg, strict-local) can't schedule anywhere else, so its volume
# detaches only after the pod is evicted and left Pending. That takes Longhorn
# ~30-60s, tuppr gives it ~0s, and the drain loops forever.
#
# `kubectl drain` retries PDB-refused evictions every 5s until its timeout,
# which is exactly the behaviour tuppr lacks, so: stop tuppr (so it stops
# cordon/uncordon cycling and undoing Longhorn's progress), let kubectl drain
# the node completely, then hand it back to tuppr with nothing left to evict.
#
# Pods are only ever evicted; PVCs are untouched. Evicting a CNPG primary makes
# CNPG switch over to a replica first (it does this itself on seeing the node
# cordoned) — a few seconds of write unavailability.
set -euo pipefail

NODE="${1:?node name required}"
TUPPR_NS="${TUPPR_NS:-system-upgrade}"
TUPPR_DEPLOY="${TUPPR_DEPLOY:-tuppr}"
LONGHORN_NS="${LONGHORN_NS:-storage}"
DRAIN_TIMEOUT="${DRAIN_TIMEOUT:-10m}"

log() { printf '[%s] %s\n' "$(date +%T)" "$*"; }

# Same reasoning as rollout.sh: the descheduler treats this cordoned, drained
# node as an underutilized target and will shuffle pods between the two nodes
# still carrying load. PARKED_HERE (not DESCHEDULER_PARKED) gates the unpark so
# that when rollout.sh has already parked it, this script leaves it parked for
# the rest of the run instead of releasing it early.
DESCHEDULER_NS="${DESCHEDULER_NS:-kube-system}"
PARKED_HERE=0

park_descheduler() {
  [[ "${DESCHEDULER_PARKED:-0}" == "1" ]] && return 0
  kubectl -n "${DESCHEDULER_NS}" get deploy descheduler >/dev/null 2>&1 || return 0
  flux -n "${DESCHEDULER_NS}" suspend hr descheduler >/dev/null 2>&1 || true
  kubectl -n "${DESCHEDULER_NS}" scale deploy descheduler --replicas=0 >/dev/null
  PARKED_HERE=1
  export DESCHEDULER_PARKED=1
  log "descheduler parked (hr suspended, deployment scaled to 0)"
}

unpark_descheduler() {
  [[ "${PARKED_HERE}" == "1" ]] || return 0
  kubectl -n "${DESCHEDULER_NS}" scale deploy descheduler --replicas=1 >/dev/null 2>&1 \
    || log "WARNING: could not scale descheduler back up — run: kubectl -n ${DESCHEDULER_NS} scale deploy descheduler --replicas=1"
  flux -n "${DESCHEDULER_NS}" resume hr descheduler >/dev/null 2>&1 \
    || log "WARNING: descheduler HelmRelease still suspended — run: flux -n ${DESCHEDULER_NS} resume hr descheduler"
  log "descheduler resumed"
}

park_descheduler
trap unpark_descheduler EXIT

# Single-replica Longhorn volumes attached to NODE — the ones that make tuppr's
# own drain loop. Without any, tuppr can drain the node unaided.
pinned_volumes() {
  kubectl -n "${LONGHORN_NS}" get volumes.longhorn.io -o json | jq -r --arg n "${NODE}" '
    .items[]
    | select(.spec.numberOfReplicas == 1 and .status.state == "attached" and .status.currentNodeID == $n)
    | "\(.metadata.name) (\(.status.kubernetesStatus.namespace)/\(.status.kubernetesStatus.pvcName))"'
}

# Longhorn names each instance-manager PDB after the instance-manager pod and
# deletes it (rather than raising the budget) once the node is safe to drain.
blocking_pdbs() {
  local im
  for im in $(kubectl -n "${LONGHORN_NS}" get pods -l longhorn.io/component=instance-manager \
      --field-selector "spec.nodeName=${NODE}" -o jsonpath='{.items[*].metadata.name}'); do
    kubectl -n "${LONGHORN_NS}" get pdb "${im}" >/dev/null 2>&1 && echo "${im}"
  done
  return 0
}

kubectl get node "${NODE}" >/dev/null

mapfile -t VOLUMES < <(pinned_volumes)
if [[ ${#VOLUMES[@]} -eq 0 ]]; then
  log "${NODE}: no single-replica Longhorn volume is attached here — tuppr can drain it unaided, nothing to do"
  exit 0
fi
log "${NODE}: pinned by ${VOLUMES[*]}"

log "Stopping ${TUPPR_NS}/${TUPPR_DEPLOY} so it stops cordon/uncordon cycling the node"
kubectl -n "${TUPPR_NS}" scale "deploy/${TUPPR_DEPLOY}" --replicas=0
# Not `wait --for=delete`: a stale Completed pod from a previous node's reboot
# can linger under the same label and never be deleted.
until [[ -z "$(kubectl -n "${TUPPR_NS}" get pods -l "app.kubernetes.io/name=${TUPPR_DEPLOY}" \
    --field-selector status.phase=Running -o name)" ]]; do sleep 2; done

log "Draining ${NODE} with kubectl (retries PDB-refused evictions until ${DRAIN_TIMEOUT}; 'Cannot evict' lines are expected while Longhorn detaches volumes)"
kubectl drain "${NODE}" --ignore-daemonsets --delete-emptydir-data --timeout="${DRAIN_TIMEOUT}"

mapfile -t BLOCKING < <(blocking_pdbs)
if [[ ${#BLOCKING[@]} -gt 0 ]]; then
  log "Drain returned but instance-manager PDBs remain: ${BLOCKING[*]} — leaving ${TUPPR_NS}/${TUPPR_DEPLOY} stopped"
  log "Check: kubectl -n ${LONGHORN_NS} get volumes.longhorn.io -o wide | grep ${NODE}"
  exit 1
fi
log "${NODE}: drained, instance-manager PDBs gone"

log "Restarting ${TUPPR_NS}/${TUPPR_DEPLOY}; its drain now has nothing left to evict"
kubectl -n "${TUPPR_NS}" scale "deploy/${TUPPR_DEPLOY}" --replicas=1
