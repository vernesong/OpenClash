#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LGBM_SCRIPT="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_lgbm.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

run_flow_case() (
  local scenario="$1"
  local case_tmp runtime_script target_model
  local download_status script_status index content

  case_tmp="$(mktemp -d)"
  runtime_script="$case_tmp/openclash_lgbm.sh"
  target_model="$case_tmp/etc/openclash/Model.bin"
  trap 'rm -rf -- "$case_tmp"' EXIT
  mkdir -p "$case_tmp/etc/openclash" "$case_tmp/tmp/etc/openclash" "$case_tmp/lock"

  sed \
    -e '/^\. \/lib\/functions\.sh$/d' \
    -e '/^\. \/usr\/share\/openclash\//d' \
    -e "s|/tmp/etc/openclash|$case_tmp/tmp/etc/openclash|g" \
    -e "s|/etc/openclash|$case_tmp/etc/openclash|g" \
    -e "s|/tmp/Model.bin|$case_tmp/Model.bin|g" \
    -e "s|/tmp/lock/openclash_lgbm.lock|$case_tmp/lock/openclash_lgbm.lock|g" \
    "$LGBM_SCRIPT" > "$runtime_script"

  ROUTER_SELF_PROXY=1
  MIXED_PORT=7893
  CORE_RUNNING=1
  DOWNLOAD_CALLS=0
  RESTART_FLAG=unset
  LOG_MESSAGES=()

  case "$scenario" in
    same)
      DOWNLOAD_RESULTS=(0)
      DOWNLOAD_CONTENTS=("old-model")
      EXPECTED_MODEL="old-model"
      EXPECTED_RESTART=0
      EXPECTED_CALLS=1
      ;;
    not-modified)
      DOWNLOAD_RESULTS=(2)
      DOWNLOAD_CONTENTS=("")
      EXPECTED_MODEL="old-model"
      EXPECTED_RESTART=0
      EXPECTED_CALLS=1
      ;;
    proxy-update)
      DOWNLOAD_RESULTS=(1 0)
      DOWNLOAD_CONTENTS=("" "new-model")
      EXPECTED_MODEL="new-model"
      EXPECTED_RESTART=1
      EXPECTED_CALLS=2
      ;;
    failure)
      DOWNLOAD_RESULTS=(1 1)
      DOWNLOAD_CONTENTS=("" "")
      EXPECTED_MODEL="old-model"
      EXPECTED_RESTART=0
      EXPECTED_CALLS=2
      ;;
    *)
      fail "unknown scenario: $scenario"
      ;;
  esac

  printf 'old-model' > "$target_model"

  uci_get_config() {
    case "$1" in
      small_flash_memory) printf '0' ;;
      lgbm_custom_url) return 0 ;;
      router_self_proxy) printf '%s' "$ROUTER_SELF_PROXY" ;;
      mixed_port) printf '%s' "$MIXED_PORT" ;;
      *) return 1 ;;
    esac
  }

  config_load() {
    [[ "$1" == "openclash" ]]
  }

  config_foreach() {
    return 0
  }

  pidof() {
    [[ "$1" == "clash" && "$CORE_RUNNING" == "1" ]]
  }

  DOWNLOAD_FILE_CURL() {
    index="$DOWNLOAD_CALLS"
    download_status="${DOWNLOAD_RESULTS[$index]:-1}"
    content="${DOWNLOAD_CONTENTS[$index]:-}"
    DOWNLOAD_CALLS=$((DOWNLOAD_CALLS + 1))
    if [[ "$download_status" == "0" ]]; then
      printf '%s' "$content" > "$2"
    fi
    return "$download_status"
  }

  LOG_OUT() {
    LOG_MESSAGES+=("$*")
  }

  SLOG_CLEAN() {
    return 0
  }

  inc_job_counter() {
    return 0
  }

  dec_job_counter_and_restart() {
    RESTART_FLAG="$1"
  }

  flock() {
    return 0
  }

  OPENCLASH_TEST_ONLY=0
  set +e
  source "$runtime_script"
  script_status=$?
  set -e

  [[ "$script_status" == "0" ]] || fail "$scenario flow returned $script_status"
  [[ "$(cat "$target_model")" == "$EXPECTED_MODEL" ]] || fail "$scenario changed the model incorrectly"
  [[ "$RESTART_FLAG" == "$EXPECTED_RESTART" ]] || fail "$scenario produced restart flag $RESTART_FLAG"
  [[ "$DOWNLOAD_CALLS" == "$EXPECTED_CALLS" ]] || fail "$scenario used $DOWNLOAD_CALLS downloads"
  [[ ! -e "$case_tmp/Model.bin" ]] || fail "$scenario left the staged model behind"
)

run_flow_case same
run_flow_case not-modified
run_flow_case proxy-update
run_flow_case failure

printf 'openclash_lgbm flow tests passed\n'
