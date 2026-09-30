#!/bin/sh

#The custom overwrite script never edits the config itself, its helper calls are recorded here
#and executed by YAML.overwrite_run_custom() once it finished; the argument counts must stay in
#sync with OVERWRITE_HELPERS in YAML.rb
ruby_record()
{
  local op="$1" arity=0 count=0 arg
  shift

  case "$op" in
    ruby_arr_add_file|ruby_map_edit) arity=5;;
    ruby_arr_edit) arity=6;;
    ruby_arr_head_add_file|ruby_arr_insert|ruby_arr_insert_arr|ruby_arr_insert_hash|ruby_cover|ruby_merge) arity=4;;
    ruby_delete|ruby_edit|ruby_merge_hash) arity=3;;
    ruby_uniq) arity=2;;
    *) return;;
  esac

  printf '%s' "$op" >> /tmp/yaml_openclash_custom_calls
  for arg in "$@"; do
    printf '\000%s' "$arg" >> /tmp/yaml_openclash_custom_calls
    count=$((count + 1))
  done
  while [ "$count" -lt "$arity" ]; do
    printf '\000' >> /tmp/yaml_openclash_custom_calls
    count=$((count + 1))
  done
  printf '\000' >> /tmp/yaml_openclash_custom_calls
}

ruby_edit()
{
  ruby_record ruby_edit "$1" "$2" "$3"
}

ruby_cover()
{
  ruby_record ruby_cover "$1" "$2" "$3" "$4"
}

ruby_merge()
{
  ruby_record ruby_merge "$1" "$2" "$3" "$4"
}

ruby_uniq()
{
  ruby_record ruby_uniq "$1" "$2"
}

ruby_merge_hash()
{
  ruby_record ruby_merge_hash "$1" "$2" "$3"
}

ruby_arr_add_file()
{
  ruby_record ruby_arr_add_file "$1" "$2" "$3" "$4" "$5"
}

ruby_arr_head_add_file()
{
  ruby_record ruby_arr_head_add_file "$1" "$2" "$3" "$4"
}

ruby_arr_insert()
{
  ruby_record ruby_arr_insert "$1" "$2" "$3" "$4"
}

ruby_arr_insert_hash()
{
  ruby_record ruby_arr_insert_hash "$1" "$2" "$3" "$4"
}

ruby_arr_insert_arr()
{
  ruby_record ruby_arr_insert_arr "$1" "$2" "$3" "$4"
}

ruby_delete()
{
  ruby_record ruby_delete "$1" "$2" "$3"
}

ruby_map_edit()
{
  ruby_record ruby_map_edit "$1" "$2" "$3" "$4" "$5"
}

ruby_arr_edit()
{
  ruby_record ruby_arr_edit "$1" "$2" "$3" "$4" "$5" "$6"
}

ruby_read()
{
  [ -z "$1" ] || [ -z "$2" ] && return
  if [ -n "$(echo "$2" |grep '.to_yaml' 2>/dev/null)" ]; then
    ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e 'YAML.overwrite_read(ARGV[0], ARGV[1])' "$1" "$2" 2>/dev/null |sed '1d'
  else
    ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e 'YAML.overwrite_read(ARGV[0], ARGV[1])' "$1" "$2" 2>/dev/null
  fi
}

ruby_read_hash()
{
  [ -z "$1" ] || [ -z "$2" ] && return
  ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e 'YAML.overwrite_read_hash(ARGV[0], ARGV[1])' "$1" "$2" 2>/dev/null
}

ruby_read_hash_arr()
{
  [ -z "$1" ] || [ -z "$2" ] && return
  ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 -e 'YAML.overwrite_read_hash_arr(ARGV[0], ARGV[1], ARGV[2])' "$1" "$2" "$3" 2>/dev/null
}
