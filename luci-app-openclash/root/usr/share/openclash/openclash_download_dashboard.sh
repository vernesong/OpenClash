#!/bin/bash
. /usr/share/openclash/log.sh
. /lib/functions.sh
. /usr/share/openclash/openclash_curl.sh
. /usr/share/openclash/uci.sh

   set_lock() {
      exec 871>"/tmp/lock/openclash_dashboard.lock" 2>/dev/null
      flock -x 871 2>/dev/null
   }

   del_lock() {
      flock -u 871 2>/dev/null
      rm -rf "/tmp/lock/openclash_dashboard.lock" 2>/dev/null
   }

   validate_dashboard_dir() {
      local dashboard_dir="$1"
      local index_file="${dashboard_dir%/}/index.html"
      local ref=""
      local asset=""
      local script_found=0

      [ -s "$index_file" ] || return 1

      while IFS= read -r ref; do
         [ -n "$ref" ] || continue
         ref="${ref%%#*}"
         ref="${ref%%\?*}"
         ref="${ref#./}"

         case "$ref" in
            ""|http://*|https://*|//*|/*|data:*|mailto:*) continue ;;
         esac

         case "$ref" in
            *.js|*.css)
               asset="${dashboard_dir%/}/$ref"
               [ -s "$asset" ] || return 1
               [ "${ref##*.}" = "js" ] && script_found=1
            ;;
         esac
      done <<-EOF
$(grep -oE "(src|href)[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]" "$index_file" 2>/dev/null | sed "s/^[^=]*=[[:space:]]*['\"]//;s/['\"]$//")
EOF

      [ "$script_found" -eq 1 ]
   }

   cleanup_dashboard_tmp() {
      rm -rf "$DASH_FILE_DIR" "$DASH_FILE_TMP" "$NEW_FILE_DIR" "$OLD_FILE_DIR" >/dev/null 2>&1
   }

   restore_old_dashboard() {
      rm -rf "$TARGET_FILE_DIR" >/dev/null 2>&1
      [ -d "$OLD_FILE_DIR" ] && mv "$OLD_FILE_DIR" "$TARGET_FILE_DIR" >/dev/null 2>&1
   }

   log_unzip_error() {
      LOG_OUT "Control Panel【$DASH_NAME - $DASH_TYPE】Unzip Error!" && SLOG_CLEAN
      cleanup_dashboard_tmp
      del_lock
      exit 2
   }

   set_lock

   DASH_NAME="$1"
   DASH_TYPE="$2"
   DASH_FILE_DIR="/tmp/dash.zip"
   DASH_FILE_TMP="/tmp/dash/"
   github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
   if [ "$DASH_NAME" == "Dashboard" ]; then
      UNPACK_FILE_DIR="/usr/share/openclash/ui/dashboard/"
		if [ "$DASH_TYPE" == "Official" ]; then
			DOWNLOAD_PATH="https://codeload.github.com/ayanamist/clash-dashboard/zip/refs/heads/gh-pages"
         FILE_PATH_INCLUDE="clash-dashboard-gh-pages"
      else
			DOWNLOAD_PATH="https://codeload.github.com/MetaCubeX/Razord-meta/zip/refs/heads/gh-pages"
         FILE_PATH_INCLUDE="Razord-meta-gh-pages"
      fi
	elif [ "$DASH_NAME" == "Yacd" ]; then
      UNPACK_FILE_DIR="/usr/share/openclash/ui/yacd/"
		if [ "$DASH_TYPE" == "Official" ]; then
			DOWNLOAD_PATH="https://codeload.github.com/haishanh/yacd/zip/refs/heads/gh-pages"
         FILE_PATH_INCLUDE="yacd-gh-pages"
      else
			DOWNLOAD_PATH="https://codeload.github.com/MetaCubeX/Yacd-meta/zip/refs/heads/gh-pages"
         FILE_PATH_INCLUDE="Yacd-meta-gh-pages"
      fi
  elif [ "$DASH_NAME" == "Zashboard" ]; then
      UNPACK_FILE_DIR="/usr/share/openclash/ui/zashboard/"
      DOWNLOAD_PATH="https://codeload.github.com/Zephyruso/zashboard/zip/refs/heads/gh-pages-cdn-fonts"
      FILE_PATH_INCLUDE="zashboard-gh-pages-cdn-fonts"
   else
      UNPACK_FILE_DIR="/usr/share/openclash/ui/metacubexd/"
		DOWNLOAD_PATH="https://codeload.github.com/MetaCubeX/metacubexd/zip/refs/heads/gh-pages"
      FILE_PATH_INCLUDE="metacubexd-gh-pages"
	fi
   TARGET_FILE_DIR="${UNPACK_FILE_DIR%/}"
   TARGET_PARENT_DIR="$(dirname "$TARGET_FILE_DIR")"
   NEW_FILE_DIR="${TARGET_PARENT_DIR}/.openclash_dashboard_new.$$"
   OLD_FILE_DIR="${TARGET_PARENT_DIR}/.openclash_dashboard_old.$$"

   DOWNLOAD_FILE_CURL "$DOWNLOAD_PATH" "$DASH_FILE_DIR" "$UNPACK_FILE_DIR"
   DOWNLOAD_RESULT=$?

   if [ "$DOWNLOAD_RESULT" -eq 0 ] && [ -s "$DASH_FILE_DIR" ]; then
      unzip -qt "$DASH_FILE_DIR" >/dev/null 2>&1
      if [ "$?" -eq "0" ]; then
         rm -rf "$DASH_FILE_TMP" "$NEW_FILE_DIR" "$OLD_FILE_DIR" >/dev/null 2>&1
         unzip -q "$DASH_FILE_DIR" -d "$DASH_FILE_TMP" >/dev/null 2>&1
         if [ "$?" -eq "0" ] && [ -d "$DASH_FILE_TMP$FILE_PATH_INCLUDE" ]; then
            mkdir -p "$NEW_FILE_DIR" >/dev/null 2>&1 || log_unzip_error
            cp -rf "$DASH_FILE_TMP$FILE_PATH_INCLUDE"/. "$NEW_FILE_DIR" >/dev/null 2>&1 || log_unzip_error
            validate_dashboard_dir "$NEW_FILE_DIR" || log_unzip_error

            mkdir -p "$TARGET_PARENT_DIR" >/dev/null 2>&1 || log_unzip_error
            if [ -d "$TARGET_FILE_DIR" ]; then
               mv "$TARGET_FILE_DIR" "$OLD_FILE_DIR" >/dev/null 2>&1 || log_unzip_error
            fi
            if mv "$NEW_FILE_DIR" "$TARGET_FILE_DIR" >/dev/null 2>&1 && validate_dashboard_dir "$TARGET_FILE_DIR"; then
               cleanup_dashboard_tmp
               LOG_OUT "Control Panel【$DASH_NAME - $DASH_TYPE】Download Successful!" && SLOG_CLEAN
               del_lock
               exit 0
            else
               restore_old_dashboard
               log_unzip_error
            fi
         else
            log_unzip_error
         fi
      else
         log_unzip_error
      fi
   elif [ "$DOWNLOAD_RESULT" -eq 2 ]; then
      if validate_dashboard_dir "$UNPACK_FILE_DIR"; then
         cleanup_dashboard_tmp
         LOG_OUT "Control Panel【$DASH_NAME - $DASH_TYPE】Download Successful!" && SLOG_CLEAN
         del_lock
         exit 0
      else
         log_unzip_error
      fi
   else
      cleanup_dashboard_tmp
      LOG_OUT "Control Panel【$DASH_NAME - $DASH_TYPE】Download Error!" && SLOG_CLEAN
      del_lock
      exit 1
   fi

   del_lock
