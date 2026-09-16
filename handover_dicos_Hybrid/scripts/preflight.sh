#!/usr/bin/env bash
# Read-only input checks. This script never launches NAMD.
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PACKAGE_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SYSTEM_DIR=${1:-"$PACKAGE_DIR/551"}
REQUIRE_PBC=${2:-""}
if [[ ! -d "$SYSTEM_DIR" ]]; then
    echo "ERROR: System directory does not exist: $SYSTEM_DIR" >&2
    exit 1
fi
SYSTEM_DIR=$(cd -- "$SYSTEM_DIR" && pwd)
TOPPAR_DIR=$(cd -- "$SYSTEM_DIR/.." && pwd)/toppar
errors=0
check_file() {
    if [[ ! -s "$1" ]]; then
        echo "ERROR: Missing or empty file: $1" >&2
        errors=$((errors + 1))
    fi
}
for name in G4_TO_nvt.conf G4_TO_npt.conf G4_md.conf step3_input.psf step3_input.pdb prot_posres.ref; do
    check_file "$SYSTEM_DIR/$name"
done
conf_paths=()
for conf in G4_TO_nvt.conf G4_TO_npt.conf G4_md.conf; do
    [[ ! -s "$SYSTEM_DIR/$conf" ]] || conf_paths+=("$SYSTEM_DIR/$conf")
done
if (( ${#conf_paths[@]} > 0 )); then
    while IFS= read -r parameter; do
        check_file "$TOPPAR_DIR/$parameter"
    done < <(awk '$1=="parameters" {p=$2; sub(/^\$TOPPAR\//,"",p); print p}' "${conf_paths[@]}" | sort -u)
fi
if [[ -s "$SYSTEM_DIR/step3_input.psf" && -s "$SYSTEM_DIR/step3_input.pdb" && -s "$SYSTEM_DIR/prot_posres.ref" ]]; then
    psf_atoms=$(awk '/!NATOM/ {print $1; exit}' "$SYSTEM_DIR/step3_input.psf")
    pdb_atoms=$(awk '/^(ATOM  |HETATM)/ {n++} END {print n+0}' "$SYSTEM_DIR/step3_input.pdb")
    ref_atoms=$(awk '/^(ATOM  |HETATM)/ {n++} END {print n+0}' "$SYSTEM_DIR/prot_posres.ref")
    echo "Atoms: PSF=$psf_atoms PDB=$pdb_atoms restraint=$ref_atoms"
    if [[ "$psf_atoms" != "$pdb_atoms" || "$psf_atoms" != "$ref_atoms" ]]; then
        echo "ERROR: Atom counts differ. Do not start MD." >&2
        errors=$((errors + 1))
    fi
fi
review="$SYSTEM_DIR/PBC_REVIEW.txt"
status=""
[[ ! -f "$review" ]] || status=$(awk -F= '$1=="STATUS" {gsub(/\r/,"",$2); print $2; exit}' "$review")
if [[ "$status" != "CONFIRMED" ]]; then
    echo "WARNING: PBC review is pending (GUI waterbox 82 A; initial NVT PBC 102 A)."
    if [[ "$REQUIRE_PBC" == "--require-reviewed-pbc" ]]; then
        echo "ERROR: Review the cell/coordinates and record evidence in PBC_REVIEW.txt before submission." >&2
        errors=$((errors + 1))
    fi
fi
if (( errors > 0 )); then
    echo "Preflight failed: $errors checks require attention." >&2
    exit 1
fi
echo "File checks passed. This does NOT validate atom order, ligand parameters or ion placement."
