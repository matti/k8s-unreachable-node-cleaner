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

delay=${K8S_UNREACHABLE_NODE_CLEANER_DELAY:-10}

echo "starting with delay: $delay"

until kubectl get nodes ; do
  echo "$(date) failed to get nodes, retrying in $delay"
  sleep "$delay"
done

echo "$(date) got node listing, starting watching"

nodes_last_unreachable=""
while true; do
  while true; do
    nodes_now_unreachable=$(
      kubectl get nodes -o go-template='{{range .items}}{{ $name := .metadata.name }}{{ $tainted := false }}{{range .spec.taints}}{{if eq .key "node.kubernetes.io/unreachable"}}{{ $tainted = true }}{{end}}{{end}}{{if $tainted}}{{$name}}{{"\n"}}{{end}}{{end}}' || true
    )

    [[ -n "$nodes_now_unreachable" ]] && break

    nodes_last_unreachable=""
    sleep "$delay"
  done

  nodes_still_unreachable=""
  for node_now_unreachable in $nodes_now_unreachable; do
    case "$nodes_last_unreachable" in
      *"$node_now_unreachable"*)
        echo "$(date) node $node_now_unreachable is unreachable after delay, deleting"
        kubectl delete node "$node_now_unreachable" || echo "failed to delete node $node_now_unreachable"
        kubectl delete pods --all-namespaces --field-selector spec.nodeName="$node_now_unreachable" || echo "failed to delete pods from node $node_now_unreachable"
      ;;
      *)
        echo "$(date) node $node_now_unreachable added to still unreachable"
        nodes_still_unreachable="$nodes_still_unreachable $node_now_unreachable"
      ;;
    esac

    nodes_last_unreachable=""
  done

  for node_now_unreachable in $nodes_still_unreachable; do
    nodes_last_unreachable="$nodes_last_unreachable $node_now_unreachable"
    echo "$(date) node $node_now_unreachable marked as last unreachable"
  done

  sleep "$delay"
done
