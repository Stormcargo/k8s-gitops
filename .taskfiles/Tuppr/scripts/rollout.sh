#!/usr/bin/env bash
# Babysit a tuppr TalosUpgrade run end to end: whenever tuppr is Draining a node
# whose instance-manager PDB is blocking, run unblock-node.sh for it; once a
# node is back on the target version, make sure it is uncordoned. Exits when the
# TalosUpgrade reaches a terminal phase.
set -euo pipefail

TALOSUPGRADE="${TALOSUPGRADE:-talos}"
LONGHORN_NS="${LONGHORN_NS:-storage}"
POLL="${POLL:-15}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '[%s] %s\n' "$(date +%T)" "$*"; }

tu() { kubectl get talosupgrade "${TALOSUPGRADE}" -o jsonpath="{$1}"; }

# The descheduler's hourly LowNodeUtilization pass classifies a cordoned,
# drained node as an underutilized *target*: descheduler's ReadyNodes only
# checks the Ready condition, never .spec.unschedulable. Mid-rollout it
# therefore sees the two remaining nodes as overloaded sources with somewhere
# to put pods, and shuffles pods between them while the drain is still running.
#
# Suspending the HelmRelease alone does not stop it — that only stops Flux
# reconciling the object, the running pod keeps evicting on its interval — so
# scale the Deployment to 0 as well, with the suspend there purely to stop Flux
# putting it straight back.
DESCHEDULER_NS="${DESCHEDULER_NS:-kube-system}"

park_descheduler() {
  [[ "${DESCHEDULER_PARKED:-0}" == "1" ]] && return 0
  kubectl -n "${DESCHEDULER_NS}" get deploy descheduler >/dev/null 2>&1 || return 0
  flux -n "${DESCHEDULER_NS}" suspend hr descheduler >/dev/null 2>&1 || true
  kubectl -n "${DESCHEDULER_NS}" scale deploy descheduler --replicas=0 >/dev/null
  export DESCHEDULER_PARKED=1
  log "descheduler parked for the rollout (hr suspended, deployment scaled to 0)"
}

unpark_descheduler() {
  [[ "${DESCHEDULER_PARKED:-0}" == "1" ]] || return 0
  kubectl -n "${DESCHEDULER_NS}" scale deploy descheduler --replicas=1 >/dev/null 2>&1 \
    || log "WARNING: could not scale descheduler back up — run: kubectl -n ${DESCHEDULER_NS} scale deploy descheduler --replicas=1"
  flux -n "${DESCHEDULER_NS}" resume hr descheduler >/dev/null 2>&1 \
    || log "WARNING: descheduler HelmRelease still suspended — run: flux -n ${DESCHEDULER_NS} resume hr descheduler"
  log "descheduler resumed"
}

park_descheduler
trap unpark_descheduler EXIT

TARGET="$(tu .spec.talos.version)"
log "TalosUpgrade/${TALOSUPGRADE}: target ${TARGET}"

# A node is going to deadlock tuppr's drain iff a single-replica Longhorn volume
# is attached to it (see unblock-node.sh). The PDB itself is not the signal: at
# rest every node's instance-manager PDB shows disruptionsAllowed=0.
node_pinned() {
  [[ -n "$(kubectl -n "${LONGHORN_NS}" get volumes.longhorn.io -o json | jq -r --arg n "$1" '
    .items[]
    | select(.spec.numberOfReplicas == 1 and .status.state == "attached" and .status.currentNodeID == $n)
    | .metadata.name' | head -n1)" ]]
}

# tuppr only ever cordons the node it is currently working on, so any other
# Ready node that is cordoned is a leftover: either finished (tuppr rebooted it
# and moved on) or abandoned mid-rollback when tuppr was stopped. Either way,
# give it back — leaving two nodes cordoned starves anti-affinity workloads
# (CNPG) down to a single instance.
uncordon_leftovers() {
  kubectl get nodes -o json | jq -r '
    .items[]
    | select(.spec.unschedulable == true)
    | select(any(.status.conditions[]; .type == "Ready" and .status == "True"))
    | .metadata.name' | while read -r n; do
      [[ "${n}" == "${CURRENT:-}" ]] && continue
      log "${n} is cordoned but tuppr is not working on it — uncordoning"
      kubectl uncordon "${n}"
    done
}

LAST=""
while :; do
  PHASE="$(tu .status.phase)"
  CURRENT="$(tu .status.currentNode)"
  MSG="$(tu .status.message)"
  STATE="${PHASE}/${CURRENT:-none}: ${MSG}"
  [[ "${STATE}" != "${LAST}" ]] && log "${STATE}"
  LAST="${STATE}"

  case "${PHASE}" in
    Completed|Failed|"")
      break ;;
    Draining)
      if [[ -n "${CURRENT}" ]] && node_pinned "${CURRENT}"; then
        log "${CURRENT}: a single-replica Longhorn volume pins this node; tuppr's drain will loop — pre-staging"
        bash "${SCRIPT_DIR}/unblock-node.sh" "${CURRENT}"
      fi ;;
  esac

  uncordon_leftovers
  sleep "${POLL}"
done

uncordon_leftovers
log "Final state: ${PHASE}"
kubectl get nodes -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,CORDONED:.spec.unschedulable,TALOS:.status.nodeInfo.osImage'
[[ "${PHASE}" == "Completed" ]]
