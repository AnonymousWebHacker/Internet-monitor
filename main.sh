#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

alltray --icon "$SCRIPT_DIR/assets/icon.png" \
 --large_icons --show xterm "$SCRIPT_DIR/inetmon.sh"