#!/usr/bin/env bash
set -eEuo pipefail

_on_error() {
  trap '' ERR
  line_path=$(caller)
  line=${line_path% *}
  path=${line_path#* }

  echo ""
  echo "ERR $path:$line $BASH_COMMAND exited with $1"
  _shutdown 1
}
trap '_on_error $?' ERR

_shutdown() {
  trap '' TERM INT
  echo "shutdown: $1"

  kill 0
  wait
  exit "$1"
}
trap '_shutdown 0' TERM INT

delay=${1:-5}

echo "starting with delay: $delay"

until kubectl get nodes ; do
  echo "failed to get nodes, retrying in $delay"
  sleep "$delay"
done

nodes_last_unreachable=""
while true; do
  nodes_now_unreachable=$(
    kubectl get nodes -o go-template='{{range .items}}{{ $name := .metadata.name }}{{ $tainted := false }}{{range .spec.taints}}{{if eq .key "node.kubernetes.io/unreachable"}}{{ $tainted = true }}{{end}}{{end}}{{if $tainted}}{{$name}}{{"\n"}}{{end}}{{end}}' || true
  )

  for node_now_unreachable in $nodes_now_unreachable; do
    for node_last_unreachable in $nodes_last_unreachable; do
      if [ "$node_now_unreachable" == "$node_last_unreachable" ]; then
        echo "$(date) still unreachable $node_now_unreachable, deleting"
        kubectl delete node "$node_now_unreachable" || echo "failed to delete"
      fi
    done
  done

  sleep "$delay"

  nodes_now_unreachable=$(
    kubectl get nodes -o go-template='{{range .items}}{{ $name := .metadata.name }}{{ $tainted := false }}{{range .spec.taints}}{{if eq .key "node.kubernetes.io/unreachable"}}{{ $tainted = true }}{{end}}{{end}}{{if $tainted}}{{$name}}{{"\n"}}{{end}}{{end}}' || true
  )

  for node_now_unreachable in $nodes_now_unreachable; do
    nodes_last_unreachable="$nodes_last_unreachable $node_now_unreachable"
    echo "$(date) marked as unreachable $node_now_unreachable"
  done

  sleep "$delay"
done
