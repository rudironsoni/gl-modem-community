#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Run a Lua 5.1 script locally, or in the analysis container.
# Callers must set repo_dir. Optional RUN_LUA_BIND mounts a temp tree
# at the same host path so fixture paths stay valid.

ANALYSIS_IMAGE=${ANALYSIS_IMAGE:-mt3000-modem-analysis:2026-07-19}

lua_interpreter() {
	if command -v lua5.1 >/dev/null 2>&1; then
		printf '%s\n' lua5.1
		return 0
	fi
	if command -v lua >/dev/null 2>&1; then
		printf '%s\n' lua
		return 0
	fi
	return 1
}

run_lua() {
	interp=
	if interp=$(lua_interpreter); then
		"$interp" "$@"
		return
	fi
	if ! command -v docker >/dev/null 2>&1; then
		echo 'lua5.1 or the analysis container is required' >&2
		return 1
	fi
	if [ -z "${repo_dir:-}" ]; then
		echo 'run_lua: repo_dir is unset' >&2
		return 2
	fi
	set -- \
		--rm \
		--mount "type=bind,src=$repo_dir,dst=$repo_dir,readonly" \
		-e FM350_DRIVER \
		-e FM350_FIXTURE_DIR \
		-e USB_DEVICES_ROOT \
		-e FM350_EXPECT \
		-e FM350_GTCCINFO \
		-e FM350_COPS \
		-e TETHERING_STOCK \
		-e FM350_PORT_BIN \
		-w "$repo_dir" \
		"$ANALYSIS_IMAGE" \
		lua5.1 "$@"
	if [ -n "${RUN_LUA_BIND:-}" ]; then
		set -- --mount "type=bind,src=$RUN_LUA_BIND,dst=$RUN_LUA_BIND" "$@"
	fi
	docker run "$@"
}
