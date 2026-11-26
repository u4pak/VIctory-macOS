#!/bin/sh
# Builds VIctory for Windows and runs it on macOS under CrossOver Wine with
# Apple's D3DMetal. Arguments go to victory.exe, for example:
#   tools/macos/victory.sh config
#   tools/macos/victory.sh run --execute <path to the game's executable>
# WINE defaults to the Wine that tools/macos/build-crossover-wine.sh builds.
# VICTORY_DIAGNOSTICS=1 builds with the diagnostics feature (debug logs,
# black-frame reports, frame capture and the other debugging switches).
set -e
cd "$(dirname "$0")/../.."
ROOT="$PWD"
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
WINE="${WINE:-$HOME/Library/Caches/victory-macos/target/wine-cx/bin/wine}"
[ -x "$WINE" ] || { echo "no Wine at $WINE: run tools/macos/build-crossover-wine.sh first" >&2; exit 1; }
[ -d "$(dirname "$WINE")/../lib/external/D3DMetal.framework" ] || {
    echo "D3DMetal is missing: copy the redist/lib folder of Apple's evaluation environment over $(dirname "$WINE")/../lib" >&2
    exit 1
}
if [ "${VICTORY_DIAGNOSTICS:-0}" = 1 ]; then
    cargo build --quiet --release -p victory --features diagnostics --target x86_64-pc-windows-gnullvm
else
    cargo build --quiet --release -p victory --target x86_64-pc-windows-gnullvm
fi
export WINEPREFIX="${WINEPREFIX:-$ROOT/target/wineprefix-play}"
export WINEDEBUG="${WINEDEBUG:--all}"
# Wine is built without SDL, and winebus reads gamepads straight from IOHID
# only when SDL and its input bus are both off. Otherwise XInput sees no pad.
if ! grep -qs '"Enable SDL"=dword:00000000' "$WINEPREFIX/system.reg"; then
    "$WINE" reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v 'Enable SDL' /t REG_DWORD /d 0 /f > /dev/null
    "$WINE" reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v DisableInput /t REG_DWORD /d 1 /f > /dev/null
fi
export WINEDLLOVERRIDES="mscoree,mshtml=;winedbg.exe=d;d3d12,d3d12core,dxgi=b${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
# Rosetta tells the game about AVX and AVX2, which it may check for.
export ROSETTA_ADVERTISE_AVX=1
exec "$WINE" "$ROOT/target/x86_64-pc-windows-gnullvm/release/victory.exe" "$@"
