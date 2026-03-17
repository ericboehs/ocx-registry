#!/usr/bin/env bash
# Detect languages, linter configs, and available linter binaries in a project.
# Outputs JSON describing what was found.
# Usage: detect-project.sh [project-dir]

set -euo pipefail
shopt -s globstar 2>/dev/null || true

# Require jq for JSON output
if ! command -v jq >/dev/null 2>&1; then
  echo '{"error": "jq is required but not found in PATH"}' >&2
  exit 1
fi

PROJECT_DIR="${1:-$(pwd)}"
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "{\"error\": \"directory not found: $PROJECT_DIR\"}" >&2
  exit 1
fi
cd "$PROJECT_DIR"

# Helper: check if a command exists
cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Detect languages present in the project
detect_languages() {
  local languages=()

  # Ruby
  if [[ -f Gemfile ]] || [[ -f Rakefile ]] || compgen -G "*.rb" >/dev/null 2>&1 || compgen -G "**/*.rb" >/dev/null 2>&1; then
    languages+=("ruby")
  fi

  # JavaScript/TypeScript
  if [[ -f package.json ]] || compgen -G "*.js" >/dev/null 2>&1 || compgen -G "*.ts" >/dev/null 2>&1; then
    languages+=("javascript")
  fi

  # Python
  if [[ -f requirements.txt ]] || [[ -f pyproject.toml ]] || [[ -f setup.py ]] || [[ -f Pipfile ]] || compgen -G "*.py" >/dev/null 2>&1; then
    languages+=("python")
  fi

  # Go
  if [[ -f go.mod ]] || compgen -G "*.go" >/dev/null 2>&1; then
    languages+=("go")
  fi

  # Rust
  if [[ -f Cargo.toml ]] || compgen -G "*.rs" >/dev/null 2>&1; then
    languages+=("rust")
  fi

  # Markdown
  if compgen -G "*.md" >/dev/null 2>&1 || compgen -G "**/*.md" >/dev/null 2>&1; then
    languages+=("markdown")
  fi

  # HTML/CSS
  if compgen -G "*.html" >/dev/null 2>&1 || compgen -G "**/*.html" >/dev/null 2>&1 || compgen -G "*.css" >/dev/null 2>&1 || compgen -G "**/*.css" >/dev/null 2>&1; then
    languages+=("html")
  fi

  # Shell
  if compgen -G "*.sh" >/dev/null 2>&1 || compgen -G "*.bash" >/dev/null 2>&1 || compgen -G "*.zsh" >/dev/null 2>&1; then
    languages+=("shell")
  fi

  if [[ ${#languages[@]} -gt 0 ]]; then
    printf '%s\n' "${languages[@]}"
  fi
}

# Detect linter configs and availability for a language
detect_linters() {
  local lang="$1"

  case "$lang" in
    ruby)
      echo "{"
      # rubocop
      local rubocop_available=false rubocop_config=""
      if cmd_exists rubocop || ([[ -f Gemfile ]] && grep -q rubocop Gemfile 2>/dev/null); then
        rubocop_available=true
      fi
      [[ -f .rubocop.yml ]] && rubocop_config=".rubocop.yml"
      echo "  \"rubocop\": {\"available\": $rubocop_available, \"config\": \"$rubocop_config\", \"command\": \"bundle exec rubocop\", \"autofix_command\": \"bundle exec rubocop -A --fail-level=error\"},"

      # reek
      local reek_available=false reek_config=""
      if cmd_exists reek || ([[ -f Gemfile ]] && grep -q reek Gemfile 2>/dev/null); then
        reek_available=true
      fi
      [[ -f .reek.yml ]] && reek_config=".reek.yml"
      echo "  \"reek\": {\"available\": $reek_available, \"config\": \"$reek_config\", \"command\": \"bundle exec reek\"},"

      # brakeman
      local brakeman_available=false
      if cmd_exists brakeman || ([[ -f Gemfile ]] && grep -q brakeman Gemfile 2>/dev/null); then
        brakeman_available=true
      fi
      echo "  \"brakeman\": {\"available\": $brakeman_available, \"whole_project_only\": true, \"command\": \"bundle exec brakeman -q\"}"
      echo "}"
      ;;

    javascript)
      echo "{"
      # eslint
      local eslint_available=false eslint_config=""
      if cmd_exists eslint || ([[ -f package.json ]] && jq -e '.devDependencies.eslint // .dependencies.eslint' package.json >/dev/null 2>&1); then
        eslint_available=true
      fi
      for f in .eslintrc .eslintrc.js .eslintrc.json .eslintrc.yml eslint.config.js eslint.config.mjs eslint.config.ts; do
        [[ -f "$f" ]] && eslint_config="$f" && break
      done
      echo "  \"eslint\": {\"available\": $eslint_available, \"config\": \"$eslint_config\", \"command\": \"npx eslint\", \"autofix_command\": \"npx eslint --fix\"},"

      # biome
      local biome_available=false biome_config=""
      if cmd_exists biome || ([[ -f package.json ]] && jq -e '.devDependencies["@biomejs/biome"] // .dependencies["@biomejs/biome"]' package.json >/dev/null 2>&1); then
        biome_available=true
      fi
      [[ -f biome.json ]] && biome_config="biome.json"
      [[ -f biome.jsonc ]] && biome_config="biome.jsonc"
      echo "  \"biome\": {\"available\": $biome_available, \"config\": \"$biome_config\", \"command\": \"npx biome check\", \"autofix_command\": \"npx biome check --write\"}"
      echo "}"
      ;;

    python)
      echo "{"
      # ruff
      local ruff_available=false ruff_config=""
      if cmd_exists ruff; then
        ruff_available=true
      fi
      [[ -f ruff.toml ]] && ruff_config="ruff.toml"
      [[ -f .ruff.toml ]] && ruff_config=".ruff.toml"
      if [[ -f pyproject.toml ]] && grep -q '\[tool.ruff\]' pyproject.toml 2>/dev/null; then
        ruff_config="pyproject.toml"
      fi
      echo "  \"ruff\": {\"available\": $ruff_available, \"config\": \"$ruff_config\", \"command\": \"ruff check\", \"autofix_command\": \"ruff check --fix\"},"

      # mypy
      local mypy_available=false mypy_config=""
      if cmd_exists mypy; then
        mypy_available=true
      fi
      [[ -f mypy.ini ]] && mypy_config="mypy.ini"
      [[ -f .mypy.ini ]] && mypy_config=".mypy.ini"
      if [[ -f pyproject.toml ]] && grep -q '\[tool.mypy\]' pyproject.toml 2>/dev/null; then
        mypy_config="pyproject.toml"
      fi
      echo "  \"mypy\": {\"available\": $mypy_available, \"config\": \"$mypy_config\", \"command\": \"mypy\"},"

      # flake8
      local flake8_available=false flake8_config=""
      if cmd_exists flake8; then
        flake8_available=true
      fi
      [[ -f .flake8 ]] && flake8_config=".flake8"
      [[ -f setup.cfg ]] && grep -q '\[flake8\]' setup.cfg 2>/dev/null && flake8_config="setup.cfg"
      echo "  \"flake8\": {\"available\": $flake8_available, \"config\": \"$flake8_config\", \"command\": \"flake8\"}"
      echo "}"
      ;;

    go)
      echo "{"
      local golangci_available=false golangci_config=""
      if cmd_exists golangci-lint; then
        golangci_available=true
      fi
      [[ -f .golangci.yml ]] && golangci_config=".golangci.yml"
      [[ -f .golangci.yaml ]] && golangci_config=".golangci.yaml"
      [[ -f .golangci.toml ]] && golangci_config=".golangci.toml"
      echo "  \"golangci-lint\": {\"available\": $golangci_available, \"config\": \"$golangci_config\", \"command\": \"golangci-lint run\"}"
      echo "}"
      ;;

    rust)
      echo "{"
      local clippy_available=false
      if cmd_exists cargo; then
        clippy_available=true
      fi
      echo "  \"clippy\": {\"available\": $clippy_available, \"whole_project_only\": true, \"command\": \"cargo clippy -- -D warnings\"}"
      echo "}"
      ;;

    markdown)
      echo "{"
      local mdlint_available=false mdlint_config=""
      if cmd_exists markdownlint || cmd_exists markdownlint-cli2; then
        mdlint_available=true
      fi
      [[ -f .markdownlint.json ]] && mdlint_config=".markdownlint.json"
      [[ -f .markdownlint.yaml ]] && mdlint_config=".markdownlint.yaml"
      [[ -f .markdownlint-cli2.jsonc ]] && mdlint_config=".markdownlint-cli2.jsonc"
      echo "  \"markdownlint\": {\"available\": $mdlint_available, \"config\": \"$mdlint_config\", \"command\": \"npx markdownlint-cli\", \"autofix_command\": \"npx markdownlint-cli --fix\"}"
      echo "}"
      ;;

    html)
      echo "{"
      # htmlhint
      local htmlhint_available=false htmlhint_config=""
      if cmd_exists htmlhint || ([[ -f package.json ]] && jq -e '.devDependencies.htmlhint // .dependencies.htmlhint' package.json >/dev/null 2>&1); then
        htmlhint_available=true
      fi
      [[ -f .htmlhintrc ]] && htmlhint_config=".htmlhintrc"
      echo "  \"htmlhint\": {\"available\": $htmlhint_available, \"config\": \"$htmlhint_config\", \"command\": \"npx htmlhint\"},"

      # prettier
      local prettier_available=false prettier_config=""
      if cmd_exists prettier || ([[ -f package.json ]] && jq -e '.devDependencies.prettier // .dependencies.prettier' package.json >/dev/null 2>&1); then
        prettier_available=true
      fi
      for f in .prettierrc .prettierrc.json .prettierrc.yml .prettierrc.js prettier.config.js prettier.config.mjs; do
        [[ -f "$f" ]] && prettier_config="$f" && break
      done
      echo "  \"prettier\": {\"available\": $prettier_available, \"config\": \"$prettier_config\", \"command\": \"npx prettier --check\", \"autofix_command\": \"npx prettier --write\"}"
      echo "}"
      ;;

    shell)
      echo "{"
      local shellcheck_available=false
      if cmd_exists shellcheck; then
        shellcheck_available=true
      fi
      echo "  \"shellcheck\": {\"available\": $shellcheck_available, \"command\": \"shellcheck\"}"
      echo "}"
      ;;
  esac
}

# Main output — build JSON with jq to ensure validity
mapfile -t LANGUAGES < <(detect_languages)

# Start with base object
RESULT=$(jq -n --arg dir "$PROJECT_DIR" '{"project_dir": $dir, "languages": {}}')

for LANG_NAME in "${LANGUAGES[@]}"; do
  # Skip empty entries (can happen if detect_languages outputs blank lines)
  [[ -z "$LANG_NAME" ]] && continue
  LINTER_JSON=$(detect_linters "$LANG_NAME")
  RESULT=$(echo "$RESULT" | jq --arg lang "$LANG_NAME" --argjson linters "$LINTER_JSON" '.languages[$lang] = $linters')
done

echo "$RESULT" | jq .
