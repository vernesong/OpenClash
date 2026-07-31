#!/bin/sh

write_ruby_part()
{
  local part="$1" sid="${OPENCLASH_OVERWRITE_SID:-unknown}"
  if [ -z "$part" ]; then
    return
  fi
  if [ "$OVERWRITE_PARENT" = "yaml_overwrite" ]; then
    mkdir -p /tmp/yaml_openclash_ruby_parts 2>/dev/null
    echo "threads << Thread.new do begin $part; rescue Exception => e; YAML.LOG_ERROR('Set Custom Overwrite Script Failed,【%s】' % [e.message]); end; end" >> "/tmp/yaml_openclash_ruby_parts/$sid"
  else
    echo "threads << Thread.new do begin $part; rescue Exception => e; YAML.LOG_ERROR('Set Custom Overwrite Script Failed,【%s】' % [e.message]); end; end" >> /tmp/yaml_openclash_ruby_parse
  fi
}

run_ruby_part()
{
  local part="$1" show_error="${2:-true}"
  if [ -z "$part" ]; then
    return
  fi
  
  if [ "$show_error" = "false" ] || [ "$show_error" = "0" ]; then
    ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "begin $part; end" 2>/dev/null
  else
    ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e "begin $part; rescue Exception => e; YAML.LOG_ERROR('Set Custom Overwrite Script Failed,【%s】' % [e.message]); end" 2>/dev/null
  fi
}

openclash_custom_overwrite() {
  local pid=$$
  while [ "$pid" != "1" ]; do
    pname=$(tr -d '\0' < /proc/"$pid"/cmdline 2>/dev/null)
    case "$pname" in
      *openclash_custom_overwrite.sh*)
        OVERWRITE_PARENT="custom"
        return 0
        ;;
      *yaml_overwrite.sh*|*/tmp/yaml_overwrite.sh*)
        OVERWRITE_PARENT="yaml_overwrite"
        return 0
        ;;
    esac
    pid=$(awk '/^PPid:/ {print $2}' /proc/"$pid"/status 2>/dev/null)
  done
  return 1
}

ruby_read()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ]; then
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if Value$2 then puts Value$2 end"
if [ -n "$(echo "$2" |grep '.to_yaml' 2>/dev/null)" ]; then
   run_ruby_part "$RUBY_YAML_PARSE" "false" |sed '1d' 2>/dev/null
else
   run_ruby_part "$RUBY_YAML_PARSE" "false"
fi
}

ruby_read_hash()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ]; then
  return
fi
RUBY_YAML_PARSE="Value = $1; if Value$2 then puts Value$2 end"
run_ruby_part "$RUBY_YAML_PARSE" "false"
}

ruby_read_hash_arr()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ]; then
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if Value$2 then Value$2.each do |i| if i$3 then puts i$3 end; end; end"
run_ruby_part "$RUBY_YAML_PARSE" "false"
}

ruby_edit()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; Value$2=$3"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); Value$2=$3; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_cover()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if File::exist?('$3') then Value_1 = YAML.load_file('$3'); if not '$4'.empty? then Value$2=Value_1['$4']; else Value$2=Value_1 end else if not '$4'.empty? then Value.delete('$4'); end; end"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if File::exist?('$3') then Value_1 = YAML.load_file('$3'); if not '$4'.empty? then Value$2=Value_1['$4']; else Value$2=Value_1 end else if not '$4'.empty? then Value.delete('$4'); end; end; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_merge()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; Value_1 = YAML.load_file('$3'); if not Value$2 then Value$2 = {}; end; if Value_1$4 && Value_1$4.is_a?(Hash) then Value$2.merge!(Value_1$4) end"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if File::exist?('$3') then Value_1 = YAML.load_file('$3'); if not Value$2 then Value$2 = {}; end; if Value_1$4 && Value_1$4.is_a?(Hash) then Value$2.merge!(Value_1$4) end end; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_uniq()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if Value$2 then Value$2=Value$2.uniq; end"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if Value$2 then Value$2=Value$2.uniq; end; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_merge_hash()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if not Value$2 then Value$2 = {}; end; Value$2.merge!({$3})"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if not Value$2 then Value$2 = {}; end; Value$2.merge!({$3}); YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_arr_add_file()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if File::exist?('$4') then Value_1 = YAML.load_file('$4'); if not Value$2 or Value$2.nil? then Value$2 = []; end; if Value_1$5 && Value_1$5.is_a?(Array) then idx = [$3.to_i, 0].max; idx = [idx, Value$2.length].min; Value_1$5.reverse.each{|x| Value$2.insert(idx,x); idx += 1}; Value$2=Value$2.uniq end end"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if File::exist?('$4') then Value_1 = YAML.load_file('$4'); if not Value$2 or Value$2.nil? then Value$2 = []; end; if Value_1$5 && Value_1$5.is_a?(Array) then idx = [$3.to_i, 0].max; idx = [idx, Value$2.length].min; Value_1$5.reverse.each{|x| Value$2.insert(idx,x); idx += 1}; Value$2=Value$2.uniq end end; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_arr_head_add_file()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if File::exist?('$3') then Value_1 = YAML.load_file('$3'); if not Value$2 or Value$2.nil? then Value$2 = []; end; if Value_1$4 && Value_1$4.is_a?(Array) then Value$2=(Value_1$4+Value$2).uniq else Value$2=Value$2.uniq end end"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if File::exist?('$3') then Value_1 = YAML.load_file('$3'); if not Value$2 or Value$2.nil? then Value$2 = []; end; if Value_1$4 && Value_1$4.is_a?(Array) then Value$2=(Value_1$4+Value$2).uniq else Value$2=Value$2.uniq end end; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_arr_insert()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if not Value$2 or Value$2.nil? then Value$2 = []; end; idx = [$3.to_i, 0].max; idx = [idx, Value$2.length].min; Value$2=Value$2.insert(idx,'$4').uniq"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if not Value$2 or Value$2.nil? then Value$2 = []; end; idx = [$3.to_i, 0].max; idx = [idx, Value$2.length].min; Value$2=Value$2.insert(idx,'$4').uniq; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_arr_insert_hash()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if not Value$2 or Value$2.nil? then Value$2 = []; end; idx = [$3.to_i, 0].max; idx = [idx, Value$2.length].min; Value$2=Value$2.insert(idx,$4).uniq"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if not Value$2 or Value$2.nil? then Value$2 = []; end; idx = [$3.to_i, 0].max; idx = [idx, Value$2.length].min; Value$2=Value$2.insert(idx,$4).uniq; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_arr_insert_arr()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if not Value$2 or Value$2.nil? then Value$2 = []; end; if $4.is_a?(Array) then idx = [$3.to_i, 0].max; idx = [idx, Value$2.length].min; $4.reverse.each{|x| Value$2=Value$2.insert(idx,x); idx += 1}; Value$2=Value$2.uniq end"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if not Value$2 or Value$2.nil? then Value$2 = []; end; if $4.is_a?(Array) then idx = [$3.to_i, 0].max; idx = [idx, Value$2.length].min; $4.reverse.each{|x| Value$2=Value$2.insert(idx,x); idx += 1}; Value$2=Value$2.uniq end; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_delete()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$3" ]; then
  return
fi
if openclash_custom_overwrite; then
  if [ -z "$2" ]; then
    RUBY_YAML_PARSE="yaml_file_path='$1'; Value.delete('$3')"
  else
    RUBY_YAML_PARSE="yaml_file_path='$1'; if Value$2 then if Value$2.is_a?(Hash) then Value$2.delete('$3') elsif Value$2.is_a?(Array) then Value$2.delete('$3') end end"
  fi
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
if [ -z "$2" ]; then
  RUBY_YAML_PARSE="Value = YAML.load_file('$1'); Value.delete('$3'); YAML.dump(Value, '$1')"
else
  RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if Value$2 then if Value$2.is_a?(Hash) then Value$2.delete('$3') elsif Value$2.is_a?(Array) then Value$2.delete('$3') end end; YAML.dump(Value, '$1')"
fi
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_map_edit()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if Value$2 && Value$2.is_a?(Hash) then if Value$2['$3'] && Value$2['$3'].is_a?(Hash) then Value$2['$3']$4 = '$5' end end"
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if Value$2 && Value$2.is_a?(Hash) then if Value$2['$3'] && Value$2['$3'].is_a?(Hash) then Value$2['$3']$4 = '$5' end end; YAML.dump(Value, '$1')"
run_ruby_part "$RUBY_YAML_PARSE"
}

ruby_arr_edit()
{
local RUBY_YAML_PARSE
if [ -z "$1" ] || [ -z "$2" ]; then
  return
fi
if openclash_custom_overwrite; then
  RUBY_YAML_PARSE="yaml_file_path='$1'; if Value$2 && Value$2.is_a?(Array) then"
  if [ -n "$3" ] && [ -n "$4" ] && [ -n "$5" ] && [ -n "$6" ]; then
    RUBY_YAML_PARSE="$RUBY_YAML_PARSE Value$2.each{|x| if x.is_a?(Hash) && x$3 == '$4' then x$5='$6' end} end"
  elif [ -z "$3" ] && [ -n "$4" ] && [ -z "$5" ] && [ -n "$6" ]; then
    RUBY_YAML_PARSE="$RUBY_YAML_PARSE Value$2.map!{|x| if x == '$4' then '$6' else x end}; Value$2.uniq! end"
  else
    return
  fi
  write_ruby_part "$RUBY_YAML_PARSE"
  return
fi
if [ -n "$3" ] && [ -n "$4" ] && [ -n "$5" ] && [ -n "$6" ]; then
  RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if Value$2 && Value$2.is_a?(Array) then Value$2.map!{|x| if x.is_a?(Hash) && x$3 == '$4' then x$5='$6' end; x}; Value$2.uniq! end; YAML.dump(Value, '$1')"
elif [ -z "$3" ] && [ -n "$4" ] && [ -z "$5" ] && [ -n "$6" ]; then
  RUBY_YAML_PARSE="Value = YAML.load_file('$1'); if Value$2 && Value$2.is_a?(Array) then Value$2.map!{|x| if x == '$4' then '$6' else x end}; Value$2.uniq! end; YAML.dump(Value, '$1')"
else
  return
fi
run_ruby_part "$RUBY_YAML_PARSE"
}