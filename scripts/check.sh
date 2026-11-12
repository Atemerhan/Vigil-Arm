#!/usr/bin/env bash
# Re-export every model with OpenSCAD's CGAL backend, then run the mesh checks.
# Usage, from anywhere: ./scripts/check.sh
# Requires OpenSCAD (2026.11.10 snapshot in CI) and checks/requirements.txt.

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

openscad_bin=${OPENSCAD:-openscad}
if [[ "$openscad_bin" == */* ]]; then
  if [[ ! -x "$openscad_bin" ]]; then
    echo "OPENSCAD is not an executable file: $openscad_bin" >&2
    exit 1
  fi
elif ! command -v "$openscad_bin" >/dev/null 2>&1; then
  echo "OpenSCAD was not found. Install it, or set OPENSCAD to the binary." >&2
  echo "CI downloads the 2026.11.10 snapshot and exports with --backend CGAL." >&2
  exit 1
fi

if ! "$openscad_bin" --help 2>&1 | grep -q -- '--backend'; then
  echo "This OpenSCAD build has no --backend flag. Exports must use --backend CGAL so they match the committed STLs." >&2
  exit 1
fi

if ! python3 -c "import numpy, trimesh" >/dev/null 2>&1; then
  echo "Install the check dependencies first:" >&2
  echo "  python3 -m pip install -r checks/requirements.txt" >&2
  exit 1
fi

out=$(mktemp -d)
cleanup() { rm -rf "$out"; }
trap cleanup EXIT

echo "OpenSCAD:"
"$openscad_bin" --version

declare -a pids=()
declare -a labels=()
declare -a logs=()

start_export() {
  local scad=$1
  local stl=$2
  local log=$3
  mkdir -p "$(dirname "$stl")"
  "$openscad_bin" --backend CGAL --hardwarnings --export-format binstl \
    -o "$stl" "$scad" >"$log" 2>&1 &
  pids+=("$!")
  labels+=("$scad")
  logs+=("$log")
}

start_export vigil.scad "$out/vigil.stl" "$out/vigil.log"
for folder in 03 04 05 06 07 08 09; do
  start_export "$folder/vigil.scad" "$out/$folder/vigil.stl" "$out/$folder.log"
done

failed=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    echo "OpenSCAD failed while exporting ${labels[$i]}" >&2
    cat "${logs[$i]}" >&2
    failed=1
  fi
done
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

export PYTHONDONTWRITEBYTECODE=1
python3 checks/check_geometry.py --repo "$root" --exported-dir "$out"
