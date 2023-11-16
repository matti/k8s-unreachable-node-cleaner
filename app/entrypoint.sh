#!/usr/bin/env bash
set -eEuo pipefail

echo "starting"

delay=${1:-5}

nodes_last_unreachable=""
while true; do
  nodes_now_unreachable=$(
    kubectl get nodes -o go-template='{{range .items}}{{ $name := .metadata.name }}{{ $tainted := false }}{{range .spec.taints}}{{if eq .key "node.kubernetes.io/unreachable"}}{{ $tainted = true }}{{end}}{{end}}{{if $tainted}}{{$name}}{{"\n"}}{{end}}{{end}}' || true
  )

  for node_now_unreachable in $nodes_now_unreachable; do
    for node_last_unreachable in $nodes_last_unreachable; do
      if [ "$node_now_unreachable" == "$node_last_unreachable" ]; then
        echo "$(date) still unreachable $node_now_unreachable, deleting"
        kubectl delete node "$node_now_unreachable"
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
