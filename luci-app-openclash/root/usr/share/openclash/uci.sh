#!/bin/sh
. /lib/functions.sh

# The stock loader evaluates the whole export in the shell, seconds once the dynamic sections
# hold hundreds of nodes, and they are never read through config_get; the stages that need
# them call config_load_full.
uci_load() {
  local PACKAGE="$1"
  local DATA
  local RET
  local VAR

  _C=0
  if [ -z "$CONFIG_APPEND" ]; then
    for VAR in $CONFIG_LIST_STATE; do
      export ${NO_EXPORT:+-n} CONFIG_${VAR}=
      export ${NO_EXPORT:+-n} CONFIG_${VAR}_LENGTH=
    done
    export ${NO_EXPORT:+-n} CONFIG_LIST_STATE=
    export ${NO_EXPORT:+-n} CONFIG_SECTIONS=
    export ${NO_EXPORT:+-n} CONFIG_NUM_SECTIONS=0
    export ${NO_EXPORT:+-n} CONFIG_SECTION=
  fi

  DATA="$(/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} ${LOAD_STATE:+-P /var/state} -S -n export "$PACKAGE" 2>/dev/null)"
  RET="$?"
  if [ "$RET" = 0 ] && [ -n "$DATA" ]; then
    DATA="$(printf '%s\n' "$DATA" | awk -v keep=1 '/^config /{ keep = ($2 != "proxies" && $2 != "proxy_groups" && $2 != "proxy_providers") } keep')"
  fi
  [ "$RET" != 0 -o -z "$DATA" ] || eval "$DATA"
  unset DATA

  ${CONFIG_SECTION:+config_cb}
  return "$RET"
}

# Unfiltered loader, for the pipeline stages that build the YAML from the dynamic sections
uci_load_full() {
  local PACKAGE="$1"
  local DATA
  local RET
  local VAR

  _C=0
  if [ -z "$CONFIG_APPEND" ]; then
    for VAR in $CONFIG_LIST_STATE; do
      export ${NO_EXPORT:+-n} CONFIG_${VAR}=
      export ${NO_EXPORT:+-n} CONFIG_${VAR}_LENGTH=
    done
    export ${NO_EXPORT:+-n} CONFIG_LIST_STATE=
    export ${NO_EXPORT:+-n} CONFIG_SECTIONS=
    export ${NO_EXPORT:+-n} CONFIG_NUM_SECTIONS=0
    export ${NO_EXPORT:+-n} CONFIG_SECTION=
  fi

  DATA="$(/sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} ${LOAD_STATE:+-P /var/state} -S -n export "$PACKAGE" 2>/dev/null)"
  RET="$?"
  [ "$RET" != 0 -o -z "$DATA" ] || eval "$DATA"
  unset DATA

  ${CONFIG_SECTION:+config_cb}
  return "$RET"
}

config_load_full() {
  [ -n "$IPKG_INSTROOT" ] && return 0
  uci_load_full "$@"
}

uci_get_config() {
    local key="$1"
    uci -q get openclash.@overwrite[0]."$key" || uci -q get openclash.config."$key"
}

# Prints one "<tag>\t<name>\t<value>" line per age key, tag P = public / S = secret, from a
# single "uci show" dump; a tag or a name restricts the output.
uci_age_keys_dump() {
  [ -f /etc/config/openclash ] || return 0
  grep -q config_age_secret /etc/config/openclash 2>/dev/null || return 0

  uci -q show openclash 2>/dev/null | awk -v only_tag="$1" -v only_name="$2" '
    BEGIN {
      sq = sprintf("%c", 39)
      escaped = sq sprintf("%c", 92) sq sq
      tab = sprintf("%c", 9)
    }
    {
      eq = index($0, "=")
      if (eq == 0) next
      key = substr($0, 1, eq - 1)
      val = substr($0, eq + 1)
      if (length(val) >= 2 && substr(val, 1, 1) == sq && substr(val, length(val), 1) == sq) {
        val = substr(val, 2, length(val) - 2)
        while ((p = index(val, escaped)) > 0) val = substr(val, 1, p - 1) sq substr(val, p + 4)
      }
      if (index(key, "openclash.") != 1) next
      rest = substr(key, 11)
      dot = 0
      for (i = 1; i <= length(rest); i++) if (substr(rest, i, 1) == ".") dot = i
      if (dot == 0) { type[rest] = val; next }
      id = substr(rest, 1, dot - 1)
      opt = substr(rest, dot + 1)
      if (opt == "name") names[id] = val
      else if (opt == "public") pubs[id] = (pubs[id] == "" ? val : pubs[id] "\n" val)
      else if (opt == "secret") secs[id] = (secs[id] == "" ? val : secs[id] "\n" val)
    }
    END {
      for (id in names) {
        if (type[id] != "config_age_secret" || names[id] == "") continue
        if (only_name != "" && names[id] != only_name) continue
        if (only_tag != "S" && pubs[id] != "") {
          c = split(pubs[id], v, "\n")
          for (i = 1; i <= c; i++) print "P" tab names[id] tab v[i]
        }
        if (only_tag != "P" && secs[id] != "") {
          c = split(secs[id], v, "\n")
          for (i = 1; i <= c; i++) print "S" tab names[id] tab v[i]
        }
      }
    }
  '
}

uci_age_key_lookup() {
  local field="$1" name="$2" tag
  [ -n "$name" ] || return 0

  case "$field" in
    public) tag="P" ;;
    secret) tag="S" ;;
    *) return 0 ;;
  esac

  uci_age_keys_dump "$tag" "$name" | cut -f 3-
}

uci_get_age_secret_keys() {
  uci_age_key_lookup "secret" "$1"
}

uci_set_age_keys_by_name() {
  local name="$1"
  local secret="$2"
  local public="$3"
  local target_section=""

  [ -n "$name" ] || return 1

  _find_age_section() {
    local section="$1"
    local cfg_name
    config_get cfg_name "$section" name
    [ "$cfg_name" = "$name" ] && target_section="$section"
  }

  config_load openclash
  config_foreach _find_age_section config_age_secret

  if [ -z "$target_section" ]; then
    target_section=$(uci -q add openclash config_age_secret)
  fi

  [ -n "$target_section" ] || return 1

  uci -q set openclash."$target_section".name="$name"
  [ -n "$secret" ] && uci -q set openclash."$target_section".secret="$secret"
  [ -n "$public" ] && uci -q set openclash."$target_section".public="$public"
  uci -q commit openclash

  return 0
}