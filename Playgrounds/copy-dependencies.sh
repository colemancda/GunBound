#!/bin/bash
#
# Vendors the local library sources (and, if available, the game assets) into
# the GunBoundSpriteKit App Playground so it is fully self-contained and can be
# opened and run in Swift Playgrounds on an iPad — where the `.package(path:
# "../..")` local dependency the desktop package would otherwise use isn't
# reachable.
#
# What it copies INTO Playgrounds/GunBoundSpriteKit.swiftpm/:
#   - Sources/GunBoundProtocol  -> GunBoundProtocol/   (local Swift target)
#   - Sources/GunBoundFile      -> GunBoundFile/
#   - Sources/GunBound          -> GunBound/
#   - Sources/GunBoundClient    -> GunBoundClient/
#   - ~/Developer/GunBound-Decomp/orig/*  -> AppModule/Resources/  (assets)
#
# The Playground's own Package.swift references these as local targets and pulls
# the third-party packages (Socket, CryptoSwift, swift-binary-parsing,
# swift-argument-parser) by URL, which Swift Playgrounds resolves over the
# network. The vendored folders and the assets are gitignored — re-run this
# script after cloning (and before syncing the .swiftpm to an iPad).
#
# Usage: Playgrounds/copy-dependencies.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAYGROUND="$REPO_ROOT/Playgrounds/GunBoundSpriteKit.swiftpm"
ASSETS_SRC="${GUNBOUND_ASSETS:-$HOME/Developer/GunBound-Decomp/orig}"

VENDORED_TARGETS=(GunBoundProtocol GunBoundFile GunBound GunBoundClient)
ASSET_FILES=(graphics.xfs sound.xfs avatar.xfs characterdata.dat itemdata.dat specialdata.dat stage.dat)

echo "Vendoring library sources into $PLAYGROUND"
for target in "${VENDORED_TARGETS[@]}"; do
    src="$REPO_ROOT/Sources/$target"
    dst="$PLAYGROUND/$target"
    if [[ ! -d "$src" ]]; then
        echo "  ! missing source target: $src" >&2
        exit 1
    fi
    rm -rf "$dst"
    cp -R "$src" "$dst"
    echo "  copied $target ($(find "$dst" -name '*.swift' | wc -l | tr -d ' ') files)"
done

echo "Copying game assets from $ASSETS_SRC"
if [[ -d "$ASSETS_SRC" ]]; then
    dst="$PLAYGROUND/AppModule/Resources/"
    mkdir -p "$dst"
    for file in "${ASSET_FILES[@]}"; do
        if [[ -f "$ASSETS_SRC/$file" ]]; then
            cp -p "$ASSETS_SRC/$file" "$dst/$file"
            echo "  copied $file"
        else
            echo "  ! missing asset (skipped): $file" >&2
        fi
    done
else
    echo "  ! assets directory not found — set GUNBOUND_ASSETS or place them at $ASSETS_SRC" >&2
    echo "  ! the Playground will build but fail to load assets at runtime" >&2
fi

echo
echo "Done. GunBoundSpriteKit.swiftpm is now self-contained."
echo "Open it in Swift Playgrounds (or Xcode), or AirDrop/sync the .swiftpm to your iPad."
