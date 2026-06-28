#!/bin/bash

set -e

[ -n "$_DEPS_SH_LOADED" ] && return 0
_DEPS_SH_LOADED=1

SCRIPT_DIR_DEPS_COMPAT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_DEPS_COMPAT/setup_project_env.sh"
source "$SCRIPT_DIR_DEPS_COMPAT/screen_manager.sh"
source "$SCRIPT_DIR_DEPS_COMPAT/install_deps.sh"
