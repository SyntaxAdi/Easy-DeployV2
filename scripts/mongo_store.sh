#!/bin/bash

set -e

[ -n "$_MONGO_STORE_SH_LOADED" ] && return 0
_MONGO_STORE_SH_LOADED=1

SCRIPT_DIR_MONGO_STORE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_MONGO_STORE/config.sh"

escape_mongo_str() {
    echo "$1" | sed "s/'/\\\\'/g"
}
