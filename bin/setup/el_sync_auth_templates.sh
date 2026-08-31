#!/bin/bash
set -euo pipefail

# Synchronize the templates that define the authentication UI and mutation
# safeguards.  This intentionally overwrites stale copies while preserving a
# numbered backup whenever an installed file differs.  With --all, domain
# directories are derived only from absolute, initialized *_WEB DocumentRoots
# in Apache's sites-available directory.

if [ "$#" -ne 1 ] || { [ "$1" != "--all" ] && { [ -z "$1" ] || [ "${1#/}" = "$1" ]; }; }; then
  echo "Usage: $0 --all | /absolute/domain/directory" >&2
  exit 2
fi

if [ "$EUID" -ne 0 ]; then
  echo "Run this template synchronization as root." >&2
  exit 1
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SOURCE_DIR=""
for source_candidate in "$SCRIPTPATH/_TEMPLATES" "$SCRIPTPATH/../_TEMPLATES"; do
  if [ -d "$source_candidate" ] && [ ! -L "$source_candidate" ] \
     && [ -f "$source_candidate/EL_LOGON.oml" ]; then
    SOURCE_DIR="$source_candidate"
    break
  fi
done
if [ -z "$SOURCE_DIR" ]; then
  echo "Complete authentication template source not found beside: $SCRIPTPATH" >&2
  exit 1
fi
SITES_DIR="${EL_APACHE_SITES_DIR:-/etc/apache2/sites-available}"
TEMPLATE_OWNER=www-data
TEMPLATE_GROUP=www-data
if ! getent passwd "$TEMPLATE_OWNER" >/dev/null || ! getent group "$TEMPLATE_GROUP" >/dev/null; then
  if [ -f /etc/fedora-release ] \
     && getent passwd apache >/dev/null && getent group apache >/dev/null; then
    TEMPLATE_OWNER=apache
    TEMPLATE_GROUP=apache
  else
    echo "No supported Apache content account is available (www-data or apache)." >&2
    exit 1
  fi
fi

AUTH_TEMPLATES=(
  EL_LOGON.oml
  EL_SIGNUP.oml
  EL_CHANGE_PASSPHRASE.oml
  EL_PROFILE.oml
  EL_SETTINGS.oml
  EL_ADMIN.oml
  PERSONS/EL_NEW_PERSON.oml
  PERSONS/EL_SHOW_PERSON.oml
  EL_HEADER.oml
  EL_NAV_BUTTONS.oml
  EL_NAV_MENUS.oml
  EL_NAV_SHOW_MORE.oml
  EL_TOKENS_SEARCH.oml
  EL_FN_DATA_MAX_STEP.oml
  DEFAULT.oml
  EL_FORM_DATA.oml
  EL_FORM_DATA_ADD.oml
  EL_BUTTON_NEW.oml
  EL_BUTTON_ADD.oml
  EL_TOKENS.oml
  EL_INPUT_BUTTONS.oml
  EL_FN_GET_BUTTON_PREV.oml
  EL_INPUT_STANDARD_HIDDEN.oml
  EL_INPUT_DATA_COLOR.oml
  LANGS/ENG/EL_SHOW_WORD.oml
)

for template in "${AUTH_TEMPLATES[@]}"; do
  source_file="$SOURCE_DIR/$template"
  if [ ! -f "$source_file" ] || [ -L "$source_file" ]; then
    echo "Required authentication template is missing: $source_file" >&2
    exit 1
  fi
done

sync_template_file() {
  local template_dir="$1"
  local template="$2"
  local install_missing="$3"
  local source_file="$SOURCE_DIR/$template"
  local target_file="$template_dir/$template"
  local target_parent relative_parent component link_count current_parent old_ifs
  local changed=0

  if [ "$install_missing" -eq 0 ] && [ ! -e "$target_file" ] && [ ! -L "$target_file" ]; then
    return 0
  fi
  if [ ! -d "$template_dir" ] || [ -L "$template_dir" ]; then
    echo "Refusing unsafe template directory: $template_dir" >&2
    return 1
  fi
  if [ -L "$target_file" ]; then
    echo "Refusing symbolic-link authentication template: $target_file" >&2
    return 1
  fi
  if [ -f "$target_file" ]; then
    link_count="$(stat -c '%h' -- "$target_file")" || {
      echo "Unable to inspect authentication template: $target_file" >&2
      return 1
    }
    if [ "$link_count" -ne 1 ]; then
      echo "Refusing multiply-linked authentication template: $target_file" >&2
      return 1
    fi
  elif [ -e "$target_file" ]; then
    echo "Refusing non-regular authentication template: $target_file" >&2
    return 1
  fi

  relative_parent="$template"
  if [ "${relative_parent%/*}" = "$relative_parent" ]; then
    relative_parent=""
  else
    relative_parent="${relative_parent%/*}"
  fi
  current_parent="$template_dir"
  if [ -n "$relative_parent" ]; then
    old_ifs="$IFS"
    IFS='/'
    for component in $relative_parent; do
      current_parent="$current_parent/$component"
      if [ -L "$current_parent" ]; then
        IFS="$old_ifs"
        echo "Refusing symbolic-link template subdirectory: $current_parent" >&2
        return 1
      fi
    done
    IFS="$old_ifs"
  fi

  target_parent="$(dirname "$target_file")"
  install -d -o "$TEMPLATE_OWNER" -g "$TEMPLATE_GROUP" -m 0775 "$target_parent" || {
    echo "Unable to create template subdirectory for: $target_file" >&2
    return 1
  }
  if [ ! -f "$target_file" ] || ! cmp -s "$source_file" "$target_file"; then
    cp -p --backup=numbered "$source_file" "$target_file" || {
      echo "Unable to update authentication template: $target_file" >&2
      return 1
    }
    changed=1
  fi
  chown "$TEMPLATE_OWNER:$TEMPLATE_GROUP" "$target_file" || {
    echo "Unable to set template ownership: $target_file" >&2
    return 1
  }
  chmod 0664 "$target_file" || {
    echo "Unable to set template permissions: $target_file" >&2
    return 1
  }
  if [ "$changed" -eq 1 ]; then
    echo "Updated $target_file"
  fi
  return 0
}

sync_domain() {
  local domain_dir="${1%/}"
  local canonical_domain target_dir template discovered_dir canonical_template_dir scan_file

  if [ ! -d "$domain_dir" ] || [ -L "$domain_dir" ] || [ ! -d "$domain_dir/_WEB" ] \
     || [ -L "$domain_dir/_WEB" ] || [ ! -d "$domain_dir/_ROOT" ] \
     || [ -L "$domain_dir/_ROOT" ]; then
    echo "Domain root is not safely initialized: $domain_dir" >&2
    return 1
  fi

  canonical_domain="$(readlink -f -- "$domain_dir")" || {
    echo "Unable to resolve domain root: $domain_dir" >&2
    return 1
  }
  [ -n "$canonical_domain" ] || {
    echo "Unable to resolve domain root: $domain_dir" >&2
    return 1
  }
  target_dir="$canonical_domain/_ROOT/_TEMPLATES"
  if [ -L "$target_dir" ]; then
    echo "Refusing symbolic-link template directory: $target_dir" >&2
    return 1
  fi

  install -d -o "$TEMPLATE_OWNER" -g "$TEMPLATE_GROUP" -m 0775 "$target_dir" || {
    echo "Unable to create template directory: $target_dir" >&2
    return 1
  }

  for template in "${AUTH_TEMPLATES[@]}"; do
    sync_template_file "$target_dir" "$template" 1 || return 1
  done

  # A root-specific _TEMPLATES directory precedes the canonical _ROOT copy in
  # Orbit's lookup order.  Do not populate every root, but force-sync any exact
  # security-sensitive files that already exist there so a stale shadow cannot
  # bypass the deployed policy.
  scan_file="$(mktemp)" || {
    echo "Unable to create a temporary template scan file" >&2
    return 1
  }
  trap 'rm -f -- "$scan_file"' RETURN
  find "$canonical_domain" -xdev \
    -path "$canonical_domain/_ORBIT/_AUTH" -prune -o \
    \( -type d -o -type l \) -name _TEMPLATES -print0 >"$scan_file" || {
      echo "Unable to enumerate template directories below $canonical_domain" >&2
      return 1
    }
  while IFS= read -r -d '' discovered_dir; do
    if [ -L "$discovered_dir" ]; then
      echo "Refusing symbolic-link shadow template directory: $discovered_dir" >&2
      return 1
    fi
    canonical_template_dir="$(readlink -f -- "$discovered_dir")" || {
      echo "Unable to resolve shadow template directory: $discovered_dir" >&2
      return 1
    }
    case "$canonical_template_dir/" in
      "$canonical_domain/"*) ;;
      *)
        echo "Refusing template directory outside domain: $discovered_dir" >&2
        return 1
        ;;
    esac
    [ "$canonical_template_dir" = "$target_dir" ] && continue
    for template in "${AUTH_TEMPLATES[@]}"; do
      sync_template_file "$canonical_template_dir" "$template" 0 || return 1
    done
  done <"$scan_file"
  rm -f -- "$scan_file"
  scan_file=''
  trap - RETURN
  return 0
}

if [ "$1" != "--all" ]; then
  sync_domain "$1"
  exit 0
fi

if [ ! -d "$SITES_DIR" ]; then
  echo "Apache sites directory does not exist: $SITES_DIR" >&2
  exit 1
fi

declare -A SEEN_DOMAINS=()
eligible=0

while IFS= read -r -d '' config_file; do
  while IFS= read -r document_root; do
    [ -n "$document_root" ] || continue
    document_root="${document_root%/}"

    # Default and unrelated vhosts are expected here.  They are not Orbit
    # domains, so report and skip them without treating them as attempted syncs.
    if [ "${document_root#/}" = "$document_root" ] || [ "${document_root%/_WEB}" = "$document_root" ]; then
      echo "Skipping non-Orbit DocumentRoot in $config_file: $document_root" >&2
      continue
    fi

    domain_dir="${document_root%/_WEB}"
    if [ ! -d "$document_root" ] || [ -L "$document_root" ] \
       || [ ! -d "$domain_dir" ] || [ -L "$domain_dir" ] \
       || [ ! -d "$domain_dir/_ROOT" ] || [ -L "$domain_dir/_ROOT" ]; then
      echo "Refusing configured but uninitialized/unsafe Orbit DocumentRoot in $config_file: $document_root" >&2
      exit 1
    fi

    canonical_domain="$(readlink -f -- "$domain_dir")" || {
      echo "Refusing unresolvable Orbit DocumentRoot in $config_file: $document_root" >&2
      exit 1
    }
    canonical_web="$(readlink -f -- "$document_root")" || {
      echo "Refusing unresolvable Orbit DocumentRoot in $config_file: $document_root" >&2
      exit 1
    }
    if [ "$canonical_web" != "$canonical_domain/_WEB" ]; then
      echo "Refusing mismatched Orbit DocumentRoot in $config_file: $document_root" >&2
      exit 1
    fi
    if [ -n "${SEEN_DOMAINS[$canonical_domain]+present}" ]; then
      continue
    fi
    SEEN_DOMAINS[$canonical_domain]=1
    eligible=$((eligible + 1))
    echo "Synchronizing authentication templates for $canonical_domain"
    sync_domain "$canonical_domain" || {
      echo "Authentication template synchronization failed for $canonical_domain" >&2
      exit 1
    }
  done < <(
    awk '
      {
        line = $0
        sub(/#.*/, "", line)
        if (line !~ /^[[:space:]]*DocumentRoot[[:space:]]+/) next
        sub(/^[[:space:]]*DocumentRoot[[:space:]]+/, "", line)
        sub(/[[:space:]]+$/, "", line)
        if (line ~ /^"[^"]*"$/) {
          sub(/^"/, "", line)
          sub(/"$/, "", line)
        }
        print line
      }
    ' "$config_file"
  )
done < <(find "$SITES_DIR" -maxdepth 1 -type f -name '*.conf' -print0 | sort -z)

if [ "$eligible" -eq 0 ]; then
  echo "No initialized Orbit vhost domains found under $SITES_DIR"
fi
