#!/usr/bin/env bash
# Sourced by bootstrap.sh and update.sh. Saves your Apple team ID to Config/Local.xcconfig so
# regenerating the Xcode project keeps signing. Order: explicit argument, the team already set in
# Blob.xcodeproj, then the OU of your "Apple Development" certificate.
save_team() {
  local root="$1" team="${2:-}"
  local file="$root/Config/Local.xcconfig"
  if [ -z "$team" ]; then
    team="$(grep -m1 -oE 'DEVELOPMENT_TEAM = [A-Z0-9]{10}' "$root/Blob.xcodeproj/project.pbxproj" 2>/dev/null | awk '{print $3}')"
  fi
  if [ -z "$team" ]; then
    team="$(security find-certificate -c "Apple Development" -p 2>/dev/null \
      | openssl x509 -noout -subject 2>/dev/null \
      | sed -nE 's/.*OU ?= ?([A-Z0-9]{10}).*/\1/p' | head -n1)"
  fi
  if [ -n "$team" ]; then
    mkdir -p "$root/Config"
    printf '// Your Apple team for signing. Not committed.\nDEVELOPMENT_TEAM = %s\n' "$team" > "$file"
    echo "Signing team: $team"
  fi
}
