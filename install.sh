#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Yozakura · cava theme installer
#  Usage:  bash install.sh [--theme <flavor>]
#          bash install.sh           (interactive menu)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_SRC="$SCRIPT_DIR/themes"
CAVA_CFG_DIR="$HOME/.config/cava"
CAVA_THEMES_DIR="$CAVA_CFG_DIR/themes"
CAVA_CONFIG="$CAVA_CFG_DIR/config"

# ── Palette (terminal output only) ───────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_DIM='\033[2m'
  C_PINK='\033[38;2;230;150;175m'
  C_IRIS='\033[38;2;155;135;210m'
  C_TEAL='\033[38;2;100;195;180m'
  C_WARN='\033[38;2;240;180;80m'
  C_ERR='\033[38;2;210;80;100m'
  C_OK='\033[38;2;130;200;150m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_PINK='' C_IRIS=''
  C_TEAL='' C_WARN='' C_ERR='' C_OK=''
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
info() { echo -e "  ${C_TEAL}→${C_RESET} $*"; }
ok()   { echo -e "  ${C_OK}✓${C_RESET} $*"; }
warn() { echo -e "  ${C_WARN}!${C_RESET} $*"; }
err()  { echo -e "  ${C_ERR}✗${C_RESET} $*" >&2; }
die()  { err "$*"; exit 1; }

banner() {
  echo -e ""
  echo -e "  ${C_PINK}${C_BOLD}夜桜 · Yozakura${C_RESET}${C_DIM} — cava theme installer${C_RESET}"
  echo -e "  ${C_DIM}──────────────────────────────────────${C_RESET}"
  echo -e ""
}

# ── Discover flavors: files named  yozakura-<flavor>  inside ./themes/ ────────
list_flavors() {
  local found=()
  while IFS= read -r -d '' f; do
    local base
    base="$(basename "$f")"
    found+=("${base#yozakura-}")
  done < <(find "$THEMES_SRC" -maxdepth 1 -type f -name 'yozakura-*' -print0 | sort -z)
  printf '%s\n' "${found[@]}"
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: bash install.sh [--theme <flavor>]"
  echo ""
  echo "Options:"
  echo "  --theme <flavor>   Install the named flavor directly (non-interactive)"
  echo "  --help, -h         Show this help"
  echo ""
  echo "Available flavors:"
  while IFS= read -r f; do
    echo "    $f"
  done < <(list_flavors 2>/dev/null || true)
  echo ""
  echo "Run without arguments for an interactive menu."
}

# ── Argument parsing ──────────────────────────────────────────────────────────
FLAVOR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)
      [[ -n "${2-}" ]] || die "--theme requires a flavor argument"
      FLAVOR="$2"
      shift 2
      ;;
    -h|--help)
      banner; usage; exit 0
      ;;
    *)
      die "Unknown option: $1  (try --help)"
      ;;
  esac
done

# ── Validate themes source directory ─────────────────────────────────────────
[[ -d "$THEMES_SRC" ]] \
  || die "themes/ directory not found at: $THEMES_SRC\nRun this script from the repo root."

mapfile -t FLAVORS < <(list_flavors)
(( ${#FLAVORS[@]} > 0 )) \
  || die "No yozakura-* theme files found in: $THEMES_SRC"

# ── Interactive menu (when --theme is not provided) ───────────────────────────
if [[ -z "$FLAVOR" ]]; then
  banner
  echo -e "  ${C_BOLD}Choose a flavor:${C_RESET}"
  echo ""
  for i in "${!FLAVORS[@]}"; do
    printf "  ${C_IRIS}%2d)${C_RESET}  %s\n" "$((i+1))" "${FLAVORS[$i]}"
  done
  echo ""
  while true; do
    read -rp "  Enter number [1-${#FLAVORS[@]}]: " sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#FLAVORS[@]} )); then
      FLAVOR="${FLAVORS[$((sel-1))]}"
      break
    fi
    warn "Please enter a number between 1 and ${#FLAVORS[@]}"
  done
  echo ""
fi

# ── Validate the chosen flavor ────────────────────────────────────────────────
THEME_FILE="$THEMES_SRC/yozakura-$FLAVOR"
[[ -f "$THEME_FILE" ]] \
  || die "Theme file not found: $THEME_FILE\nAvailable flavors: ${FLAVORS[*]}"

THEME_NAME="yozakura-$FLAVOR"

# ── Print header (only when using --theme directly, banner already shown above) ─
[[ -z "${_BANNER_SHOWN:-}" ]] && { banner; _BANNER_SHOWN=1; }
echo -e "  ${C_BOLD}Installing${C_RESET} ${C_PINK}${THEME_NAME}${C_RESET}\n"

# ── Copy all theme files to cava themes directory ─────────────────────────────
mkdir -p "$CAVA_THEMES_DIR"
cp "$THEMES_SRC"/yozakura-* "$CAVA_THEMES_DIR/"
ok "Theme files copied  →  $CAVA_THEMES_DIR"

# ── Patch cava config ─────────────────────────────────────────────────────────
if [[ ! -f "$CAVA_CONFIG" ]]; then
  warn "No cava config found at: $CAVA_CONFIG — creating a minimal one"
  mkdir -p "$CAVA_CFG_DIR"
  printf '[color]\ntheme = '"'"'%s'"'"'\n' "$THEME_NAME" > "$CAVA_CONFIG"
  ok "Created            →  $CAVA_CONFIG"
  echo ""
  echo -e "  ${C_OK}${C_BOLD}Done!${C_RESET}  Restart cava to apply ${C_PINK}${THEME_NAME}${C_RESET}."
  echo ""
  exit 0
fi

# Back up the existing config
cp "$CAVA_CONFIG" "${CAVA_CONFIG}.bak"
ok "Config backed up    →  ${CAVA_CONFIG}.bak"

# ─────────────────────────────────────────────────────────────────────────────
#  awk — single-pass config patcher
#
#  Rules inside the [color] block:
#    1.  Print the [color] header, then immediately inject:
#            theme = '<THEME_NAME>'
#    2.  Every subsequent ACTIVE line (not blank, not already ; or #-commented)
#        is commented out with a leading "; "
#    3.  Already-commented and blank lines are left untouched.
#    4.  The block ends when the next [section] header is seen.
#
#  Edge case: if no [color] block exists at all, one is appended at EOF.
# ─────────────────────────────────────────────────────────────────────────────
awk \
  -v theme="$THEME_NAME" \
  '
  BEGIN {
    in_color    = 0
    found_block = 0
  }

  # ── entering [color] ──────────────────────────────────────────────────────
  /^\[color\]/ {
    in_color    = 1
    found_block = 1
    print                                        # keep [color] header
    printf "theme = \047%s\047\n", theme         # inject active theme line
    next
  }

  # ── entering any other section → leave [color] mode ──────────────────────
  /^\[[a-zA-Z]/ {
    in_color = 0
  }

  # ── lines inside the [color] block ───────────────────────────────────────
  in_color {
    if (/^[[:space:]]*$/)        { print; next }  # blank      → keep
    if (/^[[:space:]]*[;#]/)     { print; next }  # commented  → keep
    printf "; %s\n", $0                           # active     → comment out
    next
  }

  # ── everything else passes through unchanged ──────────────────────────────
  { print }

  # ── append [color] block if one was never found ───────────────────────────
  END {
    if (!found_block) {
      printf "\n[color]\ntheme = \047%s\047\n", theme
    }
  }
  ' "${CAVA_CONFIG}.bak" > "$CAVA_CONFIG"

ok "Config patched      →  $CAVA_CONFIG"
echo ""
echo -e "  ${C_OK}${C_BOLD}Done!${C_RESET}  Restart cava to apply ${C_PINK}${THEME_NAME}${C_RESET}."
echo ""