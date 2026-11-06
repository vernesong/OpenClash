#!/bin/sh
# Quick start baseline, sole owner of /tmp/openclash.change: every tracked file is
# stored by md5, inputs (raw, custom/*, overwrite/*) are stamped before the run reads
# them and the self files (uci, runtime config) when it ends.

QUICK_STATE_FILE="/tmp/openclash.change"
QUICK_INPUT_STAMP=""

quick_state_runtime()
{
   local raw

   raw=$(uci -q get openclash.config.config_path)
   [ -n "$raw" ] && echo "/etc/openclash/$(basename "$raw" 2>/dev/null)"
}

quick_state_entry()
{
   [ -f "$1" ] || return 0
   echo "$1 #md5# $(md5sum < "$1" 2>/dev/null)"
}

quick_state_inputs()
{
   local raw

   raw=$(uci -q get openclash.config.config_path)
   {
      [ -n "$raw" ] && echo "$raw"
      ls -d /etc/openclash/custom/* /etc/openclash/overwrite/* 2>/dev/null
   } | while IFS= read -r file; do
      quick_state_entry "$file"
   done
}

# restart() checks before stop_service rewrites uci, start_service checks again
quick_state_check()
{
   local raw runtime line path stamp now

   [ "$QUICK_STATE_CHECKED" = "1" ] && return
   QUICK_STATE_CHECKED=1

   raw=$(uci -q get openclash.config.config_path)
   runtime=$(quick_state_runtime)
   QUICK_INPUT_STAMP=$(quick_state_inputs)

   if [ -z "$raw" ] || [ ! -f "$raw" ] || [ -z "$runtime" ] || [ ! -f "$runtime" ] ||
      [ ! -f "$QUICK_STATE_FILE" ]; then
      QUICK_START=false
      rm -f "$QUICK_STATE_FILE"
      return
   fi

   # a truncated or foreign baseline is not trusted
   if ! grep -qF "/etc/config/openclash #md5# " "$QUICK_STATE_FILE" ||
      ! grep -qF "$runtime #md5# " "$QUICK_STATE_FILE" ||
      ! grep -qF "$raw #md5# " "$QUICK_STATE_FILE"; then
      QUICK_START=false
      rm -f "$QUICK_STATE_FILE"
      return
   fi

   while IFS= read -r line; do
      [ -n "$line" ] || continue
      path=${line%% #md5# *}
      stamp=${line#* #md5# }
      now=""
      if [ "$path" != "$line" ] && [ -f "$path" ]; then
         now=$(md5sum < "$path" 2>/dev/null)
      fi
      if [ -z "$now" ] || [ "$now" != "$stamp" ]; then
         LOG_TIP "Because of the file【 $path 】modificated, Pause quick start..."
         QUICK_START=false
         rm -f "$QUICK_STATE_FILE"
         return
      fi
   done < "$QUICK_STATE_FILE"

   # an input added while running is not part of the runtime config yet
   path=$(printf '%s\n' "$QUICK_INPUT_STAMP" | while IFS= read -r line; do
      [ -n "$line" ] || continue
      grep -qxF "$line" "$QUICK_STATE_FILE" || echo "${line%% #md5# *}"
   done | head -n 1)
   if [ -n "$path" ]; then
      LOG_TIP "Because of the new file【 $path 】, Pause quick start..."
      QUICK_START=false
      rm -f "$QUICK_STATE_FILE"
   fi
}

quick_state_commit()
{
   local runtime

   runtime=$(quick_state_runtime)
   [ -n "$QUICK_INPUT_STAMP" ] || QUICK_INPUT_STAMP=$(quick_state_inputs)

   {
      quick_state_entry "/etc/config/openclash"
      [ -n "$runtime" ] && quick_state_entry "$runtime"
      [ -n "$QUICK_INPUT_STAMP" ] && printf '%s\n' "$QUICK_INPUT_STAMP"
      # inputs created during the run are only known now
      ls -d /etc/openclash/custom/* /etc/openclash/overwrite/* 2>/dev/null | while IFS= read -r file; do
         printf '%s' "$QUICK_INPUT_STAMP" | grep -qF "$file #md5# " || quick_state_entry "$file"
      done
   } > "$QUICK_STATE_FILE"
}
