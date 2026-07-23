#!/bin/sh
set -eu

store=${UCI_TEST_STORE:?}
log=${UCI_TEST_LOG:?}

[ "${1:-}" != -q ] || shift
command=${1:?}
shift

case "$command" in
	get)
		key=${1:?}
		[ -f "$store/$key" ] || exit 1
		cat "$store/$key"
		;;
	set)
		assignment=${1:?}
		key=${assignment%%=*}
		value=${assignment#*=}
		printf '%s\n' "$value" >"$store/$key"
		printf 'set %s\n' "$assignment" >>"$log"
		;;
	delete)
		key=${1:?}
		rm -f "$store/$key" "$store/$key".*
		printf 'delete %s\n' "$key" >>"$log"
		;;
	commit)
		printf 'commit %s\n' "${1:?}" >>"$log"
		;;
	show)
		prefix=${1:-}
		for file in "$store"/*; do
			[ -f "$file" ] || continue
			key=${file##*/}
			case "$key" in
				"$prefix"|"$prefix".*) ;;
				*) [ -n "$prefix" ] && continue ;;
			esac
			printf "%s='%s'\n" "$key" "$(cat "$file")"
		done
		;;
	*)
		echo "unsupported mock uci command: $command" >&2
		exit 2
		;;
esac
