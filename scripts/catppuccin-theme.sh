#!/usr/bin/env bash

catppuccin_palette_file() {
  printf '%s\n' "${CATPPUCCIN_PALETTE_FILE:-${scripts_root}/theme/catppuccin-mocha.json}"
}

catppuccin_theme_enabled() {
  [ -z "${APOLLO_RELEASES_FILE:-}" ] || \
    [ "$APOLLO_RELEASES_FILE" = "${scripts_root}/apollo-releases.tsv" ]
}

catppuccin_hash_inputs() {
  local file
  catppuccin_theme_enabled || return 0
  for file in \
    "${scripts_root}/catppuccin-theme.sh" \
    "$(catppuccin_palette_file)" \
    "${scripts_root}/theme/catppuccin-mocha.toml" \
    "${scripts_root}/theme/catppuccin-mocha-rmux.conf" \
    "${scripts_root}/theme/catppuccin-mocha-eza.yml"; do
    apollo_sha256 "$file"
  done
}

catppuccin_expected_bundle_sha() {
  local id="$1"
  local lock="$2"
  local source
  if ! catppuccin_theme_enabled; then
    apollo_lock_sha "$id" "$lock"
    return
  fi
  case "$id" in
    palette) source="$(catppuccin_palette_file)" ;;
    sonicterm) source="${scripts_root}/theme/catppuccin-mocha.toml" ;;
    rmux) source="${scripts_root}/theme/catppuccin-mocha-rmux.conf" ;;
    eza) source="${scripts_root}/theme/catppuccin-mocha-eza.yml" ;;
    *) return 1 ;;
  esac
  apollo_sha256 "$source"
}

catppuccin_apply_palette() {
  local bundle="$1"
  catppuccin_theme_enabled || return 0
  local palette="${bundle}/palette/apollo.json"
  local sonicterm="${bundle}/sonicterm/apollo.toml"
  local rmux="${bundle}/rmux/apollo-rmux.conf"
  local eza="${bundle}/eza/theme.yml"
  cp "$(catppuccin_palette_file)" "$palette"
  cp "${scripts_root}/theme/catppuccin-mocha.toml" "$sonicterm"
  cp "${scripts_root}/theme/catppuccin-mocha-rmux.conf" "$rmux"
  cp "${scripts_root}/theme/catppuccin-mocha-eza.yml" "$eza"
  apollo_validate_palette "$palette" || {
    printf 'Error: fork Catppuccin palette has an unsupported schema.\n' >&2
    return 1
  }

  chmod 644 "$palette" "$sonicterm" "$rmux" "$eza"
}
