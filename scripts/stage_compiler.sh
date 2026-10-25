#!/usr/bin/env bash
# Prepare the pinned jac compiler source in the jaseci submodule. jac.toml's
# `[dev] jaclang_source = "jaseci/jac"` routes every jac command run in this
# project to that source, but the launcher refuses a tree without the typeshed
# stdlib stubs (it prints "ignoring the dev compiler source" and falls back to
# its bundled compiler), so this checks the submodule out at the recorded pin
# and fetches the stubs the compiler pins (jac's own `zig build fetch-typeshed`).
# Run it after cloning and after every pin move. Without a native compiler
# kernel the compiler runs on its slower bytecode floor; build the kernel once
# per pin with `jac native build llvm-shim` and then `jac native build kernel`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$REPO_ROOT/jaseci/jac"
TYPESHED="$SOURCE/jaclang/vendor/typeshed"

git -C "$REPO_ROOT" submodule update --init jaseci >&2
commit="$(tr -d '[:space:]' < "$TYPESHED/PIN")"
expected="$(tr -d '[:space:]' < "$TYPESHED/TARBALL_SHA256")"
if [[ "$(cat "$TYPESHED/stdlib/.typeshed-sha" 2>/dev/null)" != "$commit" ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  # The pin is the checksum of the uncompressed tar.
  curl -fsSL "https://codeload.github.com/python/typeshed/tar.gz/$commit" | gunzip > "$tmp/typeshed.tar"
  if command -v sha256sum >/dev/null; then
    actual="$(sha256sum "$tmp/typeshed.tar" | cut -d ' ' -f 1)"
  else
    actual="$(shasum -a 256 "$tmp/typeshed.tar" | cut -d ' ' -f 1)"
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "typeshed checksum mismatch" >&2; exit 1
  fi
  tar -xf "$tmp/typeshed.tar" -C "$tmp"
  rm -rf "$TYPESHED/stdlib"
  mv "$tmp/typeshed-$commit/stdlib" "$TYPESHED/stdlib"
  printf '%s\n' "$commit" > "$TYPESHED/stdlib/.typeshed-sha"
fi

echo "jaseci/jac is ready: jac commands in this project use it (look for \"jac dev mode\")." >&2
