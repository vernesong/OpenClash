#!/bin/sh

# One-line JSON summary of a config file for the subscription result view.
# Rule lines are read without their trailing options (no-resolve/no-resolve6/src).
# Age encrypted files are decrypted by YAML.rb; a missing key degrades to need_key=1.
# The device ruby ships without the json gem, so the JSON is serialized by hand.

CONFIG_FILE="$1"

if [ -z "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
    echo '{"status":"error","message":"config file missing"}'
    exit 0
fi

ruby -ryaml -rYAML -I "/usr/share/openclash" -E UTF-8 - "$CONFIG_FILE" 2>/dev/null <<'RUBY'
def jstr(str)
  str.to_s.gsub("\\") { "\\\\" }.gsub("\"") { "\\\"" }.gsub("\n") { "\\n" }.gsub("\r") { "" }.gsub("\t") { "\\t" }
end

def jdump(obj)
  case obj
  when Hash
    "{" + obj.map { |k, v| "\"" + jstr(k) + "\":" + jdump(v) }.join(",") + "}"
  when Array
    "[" + obj.map { |v| jdump(v) }.join(",") + "]"
  when Integer, Float
    obj.to_s
  when TrueClass, FalseClass
    obj ? "true" : "false"
  when NilClass
    "null"
  else
    "\"" + jstr(obj) + "\""
  end
end

path = ARGV[0]
res = { "status" => "success" }
begin
  res["mtime"] = File.mtime(path).strftime("%Y-%m-%d %H:%M:%S")
  header = File.binread(path, 512).to_s
  res["age"] = header.include?("BEGIN AGE ENCRYPTED FILE")
  cfg = YAML.load_file(path)
  cfg = {} unless cfg.is_a?(Hash)
  proxies = cfg["proxies"].is_a?(Array) ? cfg["proxies"] : []
  pprov = cfg["proxy-providers"].is_a?(Hash) ? cfg["proxy-providers"] : {}
  groups = cfg["proxy-groups"].is_a?(Array) ? cfg["proxy-groups"] : []
  rules = cfg["rules"].is_a?(Array) ? cfg["rules"] : []
  rprov = cfg["rule-providers"].is_a?(Hash) ? cfg["rule-providers"] : {}
  types = {}
  proxies.each do |proxy|
    t = (proxy.is_a?(Hash) ? proxy["type"] : nil).to_s
    t = "unknown" if t.empty?
    types[t] = types[t].to_i + 1
  end
  prov_items = []
  prov_nodes = {}
  prov_nodes_total = 0
  pprov.each do |pname, pconf|
    count = nil
    ptypes = {}
    if pconf.is_a?(Hash)
      candidates = []
      ppath = pconf["path"].to_s
      candidates << ppath if ppath.start_with?("/")
      candidates << "/etc/openclash/proxy_provider/#{pname}.yaml"
      candidates.each do |cand|
        next if cand.empty? || !File.exist?(cand)
        begin
          pf = YAML.load_file(cand)
        rescue StandardError
          next
        end
        next unless pf.is_a?(Hash) && pf["proxies"].is_a?(Array)
        count = pf["proxies"].size
        pf["proxies"].each do |px|
          t = (px.is_a?(Hash) ? px["type"] : nil).to_s
          t = "unknown" if t.empty?
          ptypes[t] = ptypes[t].to_i + 1
        end
        break
      end
    end
    prov_nodes[pname.to_s] = count if count
    prov_nodes_total += count if count
    prov_items << { "name" => pname.to_s, "nodes" => count, "types" => ptypes }
  end
  group_names = {}
  groups.each do |group|
    next unless group.is_a?(Hash)
    group_names[group["name"].to_s] = true
  end
  ref_counts = {}
  groups.each do |group|
    next unless group.is_a?(Hash)
    seen = {}
    mlist = group["proxies"].is_a?(Array) ? group["proxies"] : []
    mlist.each do |m|
      m = m.to_s
      next if m == group["name"].to_s || !group_names[m] || seen[m]
      seen[m] = true
      ref_counts[m] = ref_counts[m].to_i + 1
    end
  end
  items = []
  groups.each do |group|
    next unless group.is_a?(Hash)
    t = group["type"].to_s
    next if items.size >= 80
    grefs = ref_counts[group["name"].to_s].to_i
    node_count = 0
    members = []
    member_names = group["proxies"].is_a?(Array) ? group["proxies"] : []
    member_names.each do |m|
      m = m.to_s
      if m == "DIRECT"
        members << { "k" => "direct", "v" => "DIRECT" }
      elsif m.start_with?("REJECT") || m == "PASS"
        members << { "k" => "reject", "v" => m }
      elsif group_names[m]
        members << { "k" => "ref", "v" => m }
      else
        node_count += 1
      end
    end
    if group["use"].is_a?(Array)
      group["use"].each do |u|
        u = u.to_s
        members << { "k" => "provider", "v" => u }
        node_count += prov_nodes[u] if prov_nodes[u]
      end
    end
    members << { "k" => "all", "v" => ".*" } if group["include-all-proxies"] == true
    members << { "k" => "nodes", "v" => node_count } if node_count > 0
    items << { "n" => group["name"].to_s, "t" => t, "refs" => grefs, "members" => members }
  end
  refs = 0
  rtypes = {}
  targets = {}
  target_order = []
  # options at the end of a rule line must not be mistaken for the target
  rule_opts = { "no-resolve" => true, "no-resolve6" => true, "src" => true }
  rules.each do |rule|
    s = rule.to_s.strip
    next if s.empty?
    parts = s.split(",").map { |p| p.to_s.strip }
    parts.pop while parts.size >= 3 && rule_opts[parts.last.downcase]
    next if parts.size < 2
    rtype = parts[0].upcase
    rtypes[rtype] = rtypes[rtype].to_i + 1
    refs += 1 if rtype == "RULE-SET"
    target = parts.last.to_s
    next if target.empty?
    unless targets[target]
      targets[target] = { "t" => target, "c" => 0, "sets" => [], "rules" => [] }
      target_order << target
    end
    entry = targets[target]
    entry["c"] += 1
    label = parts[0...-1].join(",")
    if rtype == "RULE-SET"
      entry["sets"] << parts[1].to_s if parts.size >= 3 && entry["sets"].size < 48
    else
      entry["rules"] << label if !label.empty? && entry["rules"].size < 48
    end
  end
  mode = "empty"
  mode = "provider" if proxies.empty? && !pprov.empty?
  mode = "proxies" unless proxies.empty?
  res["mode"] = mode
  res["nodes"] = { "total" => proxies.size, "types" => types }
  res["providers"] = { "proxy" => pprov.size, "rule" => rprov.size, "nodes_total" => prov_nodes_total, "items" => prov_items }
  res["groups"] = { "total" => groups.size, "items" => items }
  res["rules"] = { "total" => rules.size, "refs" => refs, "types" => rtypes, "targets" => target_order.map { |name| targets[name] } }
rescue StandardError => err
  msg = err.message.to_s
  if msg.include?("Encrypted file") || msg.include?("age decrypt")
    res["age"] = true
    res["need_key"] = true
  else
    res["status"] = "error"
    res["message"] = msg
  end
end
puts jdump(res)
RUBY
