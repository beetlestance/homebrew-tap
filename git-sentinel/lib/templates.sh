#!/usr/bin/env bash
# templates.sh — template injection (user-provided files and folders)
# Requires: log.sh, config.sh (sourced before this)

inject_templates() {
  if [[ "${#TEMPLATES[@]}" -eq 0 ]]; then return 0; fi

  for tmpl in "${TEMPLATES[@]}"; do
    if [[ -d "$tmpl" ]]; then
      cp -r "$tmpl"/. .
      log_ok "template injected: $tmpl/ (folder)"
    elif [[ -f "$tmpl" ]]; then
      cp "$tmpl" .
      log_ok "template injected: $tmpl"
    else
      log_fail "template path not found: $tmpl"
      exit "$EXIT_FS_ERROR"
    fi
  done
}
