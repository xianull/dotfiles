#!/bin/bash
# Install / refresh agent skills declared in packages.txt
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES_FILE="${DIR}/packages.txt"
AGENTS_FILE="${DIR}/agents.txt"

if ! command -v npx >/dev/null 2>&1; then
  echo "❌ 需要 Node.js / npx"
  exit 1
fi

AGENTS=()
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    ''|\#*) continue ;;
  esac
  AGENTS+=("$line")
done < "$AGENTS_FILE"

AGENT_ARGS=()
for a in "${AGENTS[@]}"; do
  AGENT_ARGS+=(-a "$a")
done

echo "📦 Installing skill packages → agents: ${AGENTS[*]}"

while IFS= read -r pkg || [ -n "$pkg" ]; do
  case "$pkg" in
    ''|\#*) continue ;;
  esac
  echo "→ npx skills add $pkg -g --skill '*' ${AGENT_ARGS[*]} -y"
  npx --yes skills add "$pkg" -g --skill '*' "${AGENT_ARGS[@]}" -y
done < "$PACKAGES_FILE"

echo "✅ Skills install finished"
echo "   Canonical: ~/.agents/skills"
echo "   Lockfile:  ~/.agents/.skill-lock.json"
echo "   List:      npx skills ls -g"
