#!/bin/bash

set -e

[ -n "$_MONGO_SH_LOADED" ] && return 0
_MONGO_SH_LOADED=1

SCRIPT_DIR_MONGO_COMPAT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_MONGO_COMPAT/mongo_store.sh"
source "$SCRIPT_DIR_MONGO_COMPAT/mongo_secrets.sh"
source "$SCRIPT_DIR_MONGO_COMPAT/mongo_repos.sh"
