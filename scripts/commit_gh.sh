#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.1.1"

QUIET=0
GENERATE_TREE=0
BUMP_TYPE=""

# -----------------------
# Argument parsing
# -----------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      cat <<EOF
Usage: commit_gh [--quiet] [--tree true|false] [--bump patch|minor|major]

Automates common Git commit and push operations:

  - Detects in progress rebase/merge and exits safely
  - Stashes local changes before rebasing
  - Adds/commits/pushes only when needed
  - Optional folder tree regeneration
  - Optional semantic version bump and tag

Options:
  --quiet, -q         Reduce output
  --tree [true|false] Generate folder tree (default: false, true if flag without value)
  --bump [type]       Tag release: patch (default), minor, major
  --version           Show script version
  --help, -h          Show this help

Examples:
  ./commit_gh.sh
  ./commit_gh.sh --quiet
  ./commit_gh.sh --tree
  ./commit_gh.sh --bump minor
EOF
      exit 0
      ;;
    --version)
      echo "commit_gh version $VERSION"
      exit 0
      ;;
    --quiet|-q)
      QUIET=1
      ;;
    --bump)
      case "${2:-patch}" in
        patch|minor|major)
          BUMP_TYPE="$2"
          shift
          ;;
        *)
          echo "❌ Invalid value for --bump. Use: patch | minor | major" >&2
          exit 1
          ;;
      esac
      ;;
    --tree)
      if [[ "${2:-}" =~ ^(true|false)$ ]]; then
        [[ "$2" == "true" ]] && GENERATE_TREE=1
        shift
      else
        GENERATE_TREE=1
      fi
      ;;
    *)
      echo "Ignoring unknown argument: $1" >&2
      ;;
  esac
  shift
done

msg()       { [[ $QUIET -eq 0 ]] && echo "$*"; }
always_msg(){ echo "$*"; }

# -----------------------
# Repo and safety checks
# -----------------------
cd "$(git rev-parse --show-toplevel)" || exit 1

if [[ -d .git/rebase-merge || -d .git/rebase-apply ]]; then
  echo "❌ Git rebase is in progress. Resolve it before running commit_gh." >&2
  exit 1
fi

if [[ -f .git/MERGE_HEAD ]]; then
  echo "❌ Git merge is in progress. Resolve it before running commit_gh." >&2
  exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"

# Not hard failing on non main, but warn
if [[ "$current_branch" != "main" ]]; then
  msg "⚠️ Running on branch '$current_branch' (expected main). Continuing anyway."
fi

# -----------------------
# Commit message and ssh-agent
# -----------------------
DD=$(date +'%d')
MM=$(date +'%m')
YYYY=$(date +'%Y')
COMMIT_MESSAGE="$DD/$MM/$YYYY - Updated configuration and fixed bugs"

if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add -A >/dev/null 2>&1 || true
fi

# -----------------------
# FOLDER_TREE.md cleanup
# -----------------------
if git ls-files --error-unmatch FOLDER_TREE.md >/dev/null 2>&1; then
  if grep -qF "FOLDER_TREE.md" .gitignore 2>/dev/null; then
    msg "🧹 Removing FOLDER_TREE.md from Git tracking..."
    git rm --cached FOLDER_TREE.md >/dev/null
  fi
fi

# -----------------------
# First commit round (staged only)
# -----------------------
git add . >/dev/null

DID_COMMIT=0
if ! git diff --cached --quiet; then
  msg "📦 Committing staged changes before pull/rebase..."
  git commit -m "$COMMIT_MESSAGE" >/dev/null
  DID_COMMIT=1
fi

# -----------------------
# Stash, rebase, unstash
# -----------------------
if ! git diff --quiet; then
  msg "💾 Stashing unstaged changes before rebase..."
  git stash -u >/dev/null
  if ! git pull --rebase origin main >/dev/null 2>&1; then
    echo "❌ Pull/rebase failed. Please resolve manually." >&2
    exit 1
  fi
  git stash pop >/dev/null 2>&1 || true
else
  git pull --rebase origin main >/dev/null 2>&1
fi

# -----------------------
# Second commit round (after rebase)
# -----------------------
git add . >/dev/null
if ! git diff --cached --quiet; then
  msg "📦 Committing new staged changes after rebase..."
  git commit -m "$COMMIT_MESSAGE" >/dev/null
  DID_COMMIT=1
fi

# -----------------------
# Smart push with retry
# -----------------------
DID_PUSH=0

try_push() {
  local max_attempts=2
  local attempt=1

  while [[ $attempt -le $max_attempts ]]; do
    if [[ $(git log origin/main..HEAD --oneline | wc -l | tr -d ' ') -gt 0 ]]; then
      if git push origin "$current_branch" >/dev/null 2>&1; then
        DID_PUSH=1
        msg "🚀 Successfully pushed to origin/$current_branch."
        return 0
      fi

      msg "⚠️ Push failed. Retrying after pull --rebase..."
      if ! git pull --rebase origin "$current_branch" >/dev/null 2>&1; then
        echo "❌ Pull/rebase failed during push retry. Please resolve manually." >&2
        exit 1
      fi

      ((attempt++))
    else
      return 0
    fi
  done

  echo "❌ Push failed after retries. Please resolve manually." >&2
  exit 1
}

try_push

# -----------------------
# Status summary
# -----------------------
if [[ $DID_COMMIT -eq 0 && $DID_PUSH -eq 0 ]]; then
  always_msg "✅ Branch $current_branch is up to date."
  always_msg "🟢 No changes to commit."
fi

if [[ -f .github/dependabot.yml ]]; then
  msg "🔐 Dependabot is enabled in this repository."
fi

# -----------------------
# Optional folder tree
# -----------------------
if [[ $GENERATE_TREE -eq 1 ]]; then
  if command -v folder_tree >/dev/null 2>&1; then
    msg "🌳 Generating updated folder tree..."
    folder_tree --preset terraform,github --output markdown >/dev/null || true
  else
    msg "⚠️ 'folder_tree' not found. Skipping tree generation."
  fi
fi

# -----------------------
# Optional semantic version bump
# -----------------------
if [[ -n "$BUMP_TYPE" ]]; then
  latest_tag=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || echo "v0.0.0")
  IFS='.' read -r major minor patch <<<"${latest_tag#v}"

  msg "🔍 Latest tag: $latest_tag"
  msg "🔼 Requested bump: $BUMP_TYPE"

  case "$BUMP_TYPE" in
    patch)
      ((patch++))
      ;;
    minor)
      ((minor++))
      patch=0
      ;;
    major)
      ((major++))
      minor=0
      patch=0
      ;;
  esac

  new_tag="v$major.$minor.$patch"

  if git rev-parse "$new_tag" >/dev/null 2>&1; then
    msg "⚠️ Tag $new_tag already exists. Aborting to avoid overwrite."
    exit 1
  fi

  msg "🏷️ Creating new tag: $new_tag"
  git tag -a "$new_tag" -m "Release $new_tag" >/dev/null
  git push origin "$new_tag" >/dev/null
  echo "$new_tag" > .version
  msg "✅ Pushed tag $new_tag and updated .version"
fi