#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/luci-app-openclash/root/usr/share/openclash/openclash_download_dashboard.sh"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/openclash-dashboard-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/usr/share/openclash" "$WORKDIR/lib" "$WORKDIR/bin" "$WORKDIR/tmp/lock"

cat >"$WORKDIR/usr/share/openclash/log.sh" <<'STUB'
LOG_OUT() {
  printf '%s\n' "$*" >>"${TEST_LOG:?}"
}
SLOG_CLEAN() {
  :
}
STUB

cat >"$WORKDIR/usr/share/openclash/uci.sh" <<'STUB'
uci_get_config() {
  return 1
}
STUB

cat >"$WORKDIR/lib/functions.sh" <<'STUB'
:
STUB

cat >"$WORKDIR/usr/share/openclash/openclash_curl.sh" <<'STUB'
DOWNLOAD_FILE_CURL() {
  case "${TEST_DOWNLOAD_RESULT:?}" in
    0)
      cp "${TEST_ZIP:?}" "$2"
      return 0
      ;;
    2)
      return 2
      ;;
    *)
      return 1
      ;;
  esac
}
STUB

cat >"$WORKDIR/bin/flock" <<'STUB'
#!/usr/bin/env sh
exit 0
STUB
chmod +x "$WORKDIR/bin/flock"

cp "$SCRIPT_UNDER_TEST" "$WORKDIR/openclash_download_dashboard.sh"
perl -0pi -e "s#/usr/share/openclash/#$WORKDIR/usr/share/openclash/#g; s#/lib/functions\\.sh#$WORKDIR/lib/functions.sh#g; s#/tmp/dash\\.zip#$WORKDIR/tmp/dash.zip#g; s#/tmp/dash/#$WORKDIR/tmp/dash/#g; s#/tmp/lock/#$WORKDIR/tmp/lock/#g" "$WORKDIR/openclash_download_dashboard.sh"
chmod +x "$WORKDIR/openclash_download_dashboard.sh"

make_dashboard_zip() {
  local zip_path="$1"
  local top_dir="$2"
  local include_index="$3"
  local include_assets="${4:-yes}"
  local quote_style="${5:-double}"
  local build_dir="$WORKDIR/build-$(basename "$zip_path" .zip)"

  rm -rf "$build_dir"
  mkdir -p "$build_dir/$top_dir/assets"
  if [ "$include_index" = "yes" ]; then
    if [ "$quote_style" = "single" ]; then
      printf "<script type='module' src = './assets/app.js'></script>\n" >"$build_dir/$top_dir/index.html"
    else
      printf '<script type="module" src="./assets/app.js"></script>\n' >"$build_dir/$top_dir/index.html"
    fi
    if [ "$include_assets" = "yes" ]; then
      printf 'console.log("dashboard");\n' >"$build_dir/$top_dir/assets/app.js"
    fi
  else
    printf 'console.log("orphan");\n' >"$build_dir/$top_dir/assets/orphan.js"
  fi
  (cd "$build_dir" && zip -qr "$zip_path" "$top_dir")
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  if ! LC_ALL=C grep -q "$expected" "$file"; then
    echo "expected $file to contain: $expected" >&2
    echo "actual:" >&2
    sed -n '1,120p' "$file" >&2 || true
    exit 1
  fi
}

assert_file_exists() {
  local file="$1"
  if [ ! -s "$file" ]; then
    echo "expected non-empty file: $file" >&2
    exit 1
  fi
}

test_304_requires_existing_dashboard_entrypoint() {
  local ui_dir="$WORKDIR/usr/share/openclash/ui/zashboard"
  rm -rf "$WORKDIR/usr/share/openclash/ui"
  mkdir -p "$ui_dir"
  TEST_LOG="$WORKDIR/304.log"
  : >"$TEST_LOG"

  set +e
  TEST_LOG="$TEST_LOG" TEST_DOWNLOAD_RESULT=2 PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/openclash_download_dashboard.sh" Zashboard Official
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "expected stale 304 with missing index.html to fail" >&2
    exit 1
  fi
  assert_file_contains "$TEST_LOG" "Unzip Error"
}

test_bad_zip_preserves_existing_dashboard() {
  local ui_dir="$WORKDIR/usr/share/openclash/ui/zashboard"
  local bad_zip="$WORKDIR/bad-zashboard.zip"
  rm -rf "$WORKDIR/usr/share/openclash/ui"
  mkdir -p "$ui_dir/assets"
  printf 'old-good\n' >"$ui_dir/index.html"
  printf 'old-js\n' >"$ui_dir/assets/app.js"
  make_dashboard_zip "$bad_zip" "zashboard-gh-pages-cdn-fonts" "no"
  TEST_LOG="$WORKDIR/bad-zip.log"
  : >"$TEST_LOG"

  set +e
  TEST_LOG="$TEST_LOG" TEST_DOWNLOAD_RESULT=0 TEST_ZIP="$bad_zip" PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/openclash_download_dashboard.sh" Zashboard Official
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "expected dashboard zip without index.html to fail" >&2
    exit 1
  fi
  assert_file_exists "$ui_dir/index.html"
  assert_file_contains "$ui_dir/index.html" "old-good"
  assert_file_contains "$TEST_LOG" "Unzip Error"
}

test_good_zip_installs_dashboard() {
  local ui_dir="$WORKDIR/usr/share/openclash/ui/zashboard"
  local good_zip="$WORKDIR/good-zashboard.zip"
  rm -rf "$WORKDIR/usr/share/openclash/ui"
  make_dashboard_zip "$good_zip" "zashboard-gh-pages-cdn-fonts" "yes"
  TEST_LOG="$WORKDIR/good-zip.log"
  : >"$TEST_LOG"

  TEST_LOG="$TEST_LOG" TEST_DOWNLOAD_RESULT=0 TEST_ZIP="$good_zip" PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/openclash_download_dashboard.sh" Zashboard Official

  assert_file_exists "$ui_dir/index.html"
  assert_file_exists "$ui_dir/assets/app.js"
  assert_file_contains "$TEST_LOG" "Download Successful"
}

test_good_zip_installs_metacubexd() {
  local ui_dir="$WORKDIR/usr/share/openclash/ui/metacubexd"
  local good_zip="$WORKDIR/good-metacubexd.zip"
  rm -rf "$WORKDIR/usr/share/openclash/ui"
  make_dashboard_zip "$good_zip" "metacubexd-gh-pages" "yes"
  TEST_LOG="$WORKDIR/good-metacubexd.log"
  : >"$TEST_LOG"

  TEST_LOG="$TEST_LOG" TEST_DOWNLOAD_RESULT=0 TEST_ZIP="$good_zip" PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/openclash_download_dashboard.sh" Metacubexd Official

  assert_file_exists "$ui_dir/index.html"
  assert_file_exists "$ui_dir/assets/app.js"
  assert_file_contains "$TEST_LOG" "Download Successful"
}

test_missing_referenced_asset_preserves_existing_dashboard() {
  local ui_dir="$WORKDIR/usr/share/openclash/ui/zashboard"
  local bad_zip="$WORKDIR/missing-asset-zashboard.zip"
  rm -rf "$WORKDIR/usr/share/openclash/ui"
  mkdir -p "$ui_dir/assets"
  printf 'old-good\n' >"$ui_dir/index.html"
  printf 'old-js\n' >"$ui_dir/assets/app.js"
  make_dashboard_zip "$bad_zip" "zashboard-gh-pages-cdn-fonts" "yes" "no"
  TEST_LOG="$WORKDIR/missing-asset.log"
  : >"$TEST_LOG"

  set +e
  TEST_LOG="$TEST_LOG" TEST_DOWNLOAD_RESULT=0 TEST_ZIP="$bad_zip" PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/openclash_download_dashboard.sh" Zashboard Official
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "expected dashboard zip with missing referenced asset to fail" >&2
    exit 1
  fi
  assert_file_exists "$ui_dir/index.html"
  assert_file_contains "$ui_dir/index.html" "old-good"
  assert_file_contains "$TEST_LOG" "Unzip Error"
}

test_single_quoted_missing_asset_preserves_existing_dashboard() {
  local ui_dir="$WORKDIR/usr/share/openclash/ui/zashboard"
  local bad_zip="$WORKDIR/single-quoted-missing-asset-zashboard.zip"
  rm -rf "$WORKDIR/usr/share/openclash/ui"
  mkdir -p "$ui_dir/assets"
  printf 'old-good\n' >"$ui_dir/index.html"
  printf 'old-js\n' >"$ui_dir/assets/app.js"
  make_dashboard_zip "$bad_zip" "zashboard-gh-pages-cdn-fonts" "yes" "no" "single"
  TEST_LOG="$WORKDIR/single-quoted-missing-asset.log"
  : >"$TEST_LOG"

  set +e
  TEST_LOG="$TEST_LOG" TEST_DOWNLOAD_RESULT=0 TEST_ZIP="$bad_zip" PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/openclash_download_dashboard.sh" Zashboard Official
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "expected dashboard zip with single-quoted missing referenced asset to fail" >&2
    exit 1
  fi
  assert_file_exists "$ui_dir/index.html"
  assert_file_contains "$ui_dir/index.html" "old-good"
  assert_file_contains "$TEST_LOG" "Unzip Error"
}

test_one_line_missing_stylesheet_preserves_existing_dashboard() {
  local ui_dir="$WORKDIR/usr/share/openclash/ui/metacubexd"
  local bad_zip="$WORKDIR/one-line-missing-css-metacubexd.zip"
  local build_dir="$WORKDIR/build-one-line-missing-css"
  rm -rf "$WORKDIR/usr/share/openclash/ui" "$build_dir"
  mkdir -p "$ui_dir/assets" "$build_dir/metacubexd-gh-pages/assets"
  printf 'old-good\n' >"$ui_dir/index.html"
  printf 'old-js\n' >"$ui_dir/assets/app.js"
  printf '<script src="./assets/app.js"></script><link rel="stylesheet" href="./assets/app.css">\n' >"$build_dir/metacubexd-gh-pages/index.html"
  printf 'console.log("dashboard");\n' >"$build_dir/metacubexd-gh-pages/assets/app.js"
  (cd "$build_dir" && zip -qr "$bad_zip" "metacubexd-gh-pages")
  TEST_LOG="$WORKDIR/one-line-missing-css.log"
  : >"$TEST_LOG"

  set +e
  TEST_LOG="$TEST_LOG" TEST_DOWNLOAD_RESULT=0 TEST_ZIP="$bad_zip" PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/openclash_download_dashboard.sh" Metacubexd Official
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "expected one-line dashboard index with missing stylesheet to fail" >&2
    exit 1
  fi
  assert_file_exists "$ui_dir/index.html"
  assert_file_contains "$ui_dir/index.html" "old-good"
  assert_file_contains "$TEST_LOG" "Unzip Error"
}

test_index_without_local_script_preserves_existing_dashboard() {
  local ui_dir="$WORKDIR/usr/share/openclash/ui/zashboard"
  local bad_zip="$WORKDIR/no-local-script-zashboard.zip"
  local build_dir="$WORKDIR/build-no-local-script"
  rm -rf "$WORKDIR/usr/share/openclash/ui" "$build_dir"
  mkdir -p "$ui_dir/assets" "$build_dir/zashboard-gh-pages-cdn-fonts"
  printf 'old-good\n' >"$ui_dir/index.html"
  printf 'old-js\n' >"$ui_dir/assets/app.js"
  printf '<!doctype html><title>empty shell</title><div id="app"></div>\n' >"$build_dir/zashboard-gh-pages-cdn-fonts/index.html"
  (cd "$build_dir" && zip -qr "$bad_zip" "zashboard-gh-pages-cdn-fonts")
  TEST_LOG="$WORKDIR/no-local-script.log"
  : >"$TEST_LOG"

  set +e
  TEST_LOG="$TEST_LOG" TEST_DOWNLOAD_RESULT=0 TEST_ZIP="$bad_zip" PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/openclash_download_dashboard.sh" Zashboard Official
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "expected dashboard index without local script to fail" >&2
    exit 1
  fi
  assert_file_exists "$ui_dir/index.html"
  assert_file_contains "$ui_dir/index.html" "old-good"
  assert_file_contains "$TEST_LOG" "Unzip Error"
}

test_staging_dirs_are_under_target_parent() {
  local ui_dir="$WORKDIR/usr/share/openclash/ui/zashboard"
  local good_zip="$WORKDIR/staging-zashboard.zip"
  local before_tmp=""
  local after_tmp=""
  rm -rf "$WORKDIR/usr/share/openclash/ui"
  before_tmp="$(find "${TMPDIR:-/tmp}" -maxdepth 1 \( -name 'openclash_dashboard_new.*' -o -name 'openclash_dashboard_old.*' \) -print 2>/dev/null | sort)"
  make_dashboard_zip "$good_zip" "zashboard-gh-pages-cdn-fonts" "yes"
  TEST_LOG="$WORKDIR/staging.log"
  : >"$TEST_LOG"

  TEST_LOG="$TEST_LOG" TEST_DOWNLOAD_RESULT=0 TEST_ZIP="$good_zip" PATH="$WORKDIR/bin:$PATH" \
    "$WORKDIR/openclash_download_dashboard.sh" Zashboard Official

  assert_file_exists "$ui_dir/index.html"
  after_tmp="$(find "${TMPDIR:-/tmp}" -maxdepth 1 \( -name 'openclash_dashboard_new.*' -o -name 'openclash_dashboard_old.*' \) -print 2>/dev/null | sort)"
  if [ "$before_tmp" != "$after_tmp" ]; then
    echo "expected staging directories not to be created in /tmp" >&2
    exit 1
  fi
  if find "$WORKDIR/usr/share/openclash/ui" -maxdepth 1 -name '.openclash_dashboard_*' | grep -q .; then
    echo "expected staging directories to be cleaned from target parent" >&2
    exit 1
  fi
}

test_304_requires_existing_dashboard_entrypoint
test_bad_zip_preserves_existing_dashboard
test_good_zip_installs_dashboard
test_good_zip_installs_metacubexd
test_missing_referenced_asset_preserves_existing_dashboard
test_single_quoted_missing_asset_preserves_existing_dashboard
test_one_line_missing_stylesheet_preserves_existing_dashboard
test_index_without_local_script_preserves_existing_dashboard
test_staging_dirs_are_under_target_parent

echo "openclash_download_dashboard tests passed"
