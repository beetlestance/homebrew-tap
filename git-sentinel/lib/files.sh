#!/usr/bin/env bash
# files.sh — file generation (README, LICENSE, GIT_REFERENCE, PR template)
# Requires: log.sh, config.sh (sourced before this)
# Expects: SCRIPT_DIR set by caller

# Resolve templates directory — support local dev and Homebrew install
if [[ -d "${SCRIPT_DIR}/../share/git-sentinel/templates" ]]; then
  TMPL_DIR="${SCRIPT_DIR}/../share/git-sentinel/templates"
elif [[ -d "${SCRIPT_DIR}/../templates" ]]; then
  TMPL_DIR="${SCRIPT_DIR}/../templates"
else
  TMPL_DIR=""
fi

generate_readme() {
  if [[ -n "$README_PATH" ]]; then
    cp "$README_PATH" README.md
    log_ok "README.md (from $README_PATH)"
  else
    cat > README.md <<EOF
# $REPO_NAME

$DESCRIPTION

---

- [License](LICENSE)
- [Git Reference](GIT_REFERENCE.md)
- [PR Template](.github/PULL_REQUEST_TEMPLATE.md)
EOF
    log_ok "README.md (default)"
  fi
}

generate_license() {
  if [[ -z "$LICENSE" ]]; then
    log_skip "LICENSE (not configured)"
    return
  fi

  local body
  body=$(gh_api "/licenses/$LICENSE" --jq '.body' 2>/dev/null) || {
    log_fail "license not found on GitHub: $LICENSE"
    exit "$EXIT_GITHUB_ERROR"
  }

  echo "$body" > LICENSE
  log_ok "LICENSE ($LICENSE)"
}

generate_git_reference() {
  local template="$TMPL_DIR/GIT_REFERENCE.md"

  if [[ ! -f "$template" ]]; then
    log_fail "template not found: $template"
    exit "$EXIT_FS_ERROR"
  fi

  sed "s/\[from config\]/$REQUIRED_REVIEWS/" "$template" > GIT_REFERENCE.md
  log_ok "GIT_REFERENCE.md"
}

generate_pr_template() {
  local template="$TMPL_DIR/PR_TEMPLATE.md"

  if [[ ! -f "$template" ]]; then
    log_fail "template not found: $template"
    exit "$EXIT_FS_ERROR"
  fi

  mkdir -p .github
  cp "$template" .github/PULL_REQUEST_TEMPLATE.md
  log_ok ".github/PULL_REQUEST_TEMPLATE.md"
}

generate_gitattributes() {
  cat > .gitattributes <<'EOF'
# Auto-detect text files and normalize line endings
* text=auto eol=lf

# Force these as text
*.sh text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.md text eol=lf
*.json text eol=lf
*.txt text eol=lf

# Force these as binary
*.png binary
*.jpg binary
*.ico binary
*.gif binary
*.woff binary
*.woff2 binary
*.ttf binary
EOF
  log_ok ".gitattributes"
}

generate_gitignore() {
  cat > .gitignore <<'EOF'
# OS
.DS_Store
Thumbs.db

# Editor
.idea/
.vscode/
*.swp
*.swo
*~

# Environment
.env
.env.local
.env.*.local

# Dependencies
node_modules/
.venv/
__pycache__/

# Build
dist/
build/
*.egg-info/

# Logs
*.log
EOF
  log_ok ".gitignore"
}

generate_files() {
  generate_gitattributes
  generate_gitignore
  generate_readme
  generate_license
  generate_git_reference
  generate_pr_template
}
