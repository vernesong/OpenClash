require 'yaml'
require 'tmpdir'

source = File.expand_path('../luci-app-openclash/root/usr/share/openclash', __dir__)
require File.join(source, 'YAML')
require File.join(source, 'uci')

def assert(value, message)
  raise message unless value
end

# Keep the real parser, group writer and merge; replace only device UCI/file locations.
module UCI
  def self.package_text(dir, pkg = STORAGE_PACKAGE)
    path = File.join(dir, pkg)
    File.exist?(path) ? File.read(path) : ''
  end

  def self.import(dir, pkg, text, order = true)
    body = file_format(text)
    File.write(File.join(dir, pkg), order ? canonical(body) : body)
    nil
  end
end

module YAML
  def self.age_keys
    {}
  end
end

Dir.mktmpdir('openclash-group-rules-') do |dir|
  paths = {
    STORAGE: dir,
    LOG_FILES: [File.join(dir, 'log')],
    SERVERS_FILE: File.join(dir, 'proxies.yaml'),
    PROVIDERS_FILE: File.join(dir, 'providers.yaml'),
    GROUPS_FILE: File.join(dir, 'groups.yaml'),
    MAIN_TARGETS: %w[proxies proxy_groups proxy_providers].to_h { |type| [type, ['openclash', dir]] }
  }
  paths.each do |name, value|
    UCI.send(:remove_const, name)
    UCI.const_set(name, value)
  end
  UCI.send(:remove_const, :PROXY_FILE_KEYS)
  UCI.const_set(:PROXY_FILE_KEYS, [
    ['proxies', UCI::SERVERS_FILE], ['proxy-providers', UCI::PROVIDERS_FILE],
    ['proxy-groups', UCI::GROUPS_FILE]
  ])

  group = {'name' => 'AdBlock', 'type' => 'select', 'config' => 'smart.yaml'}
  ['REJECT', ['REJECT'], nil, '', []].each do |members|
    value = YAML.load("proxy-groups:\n" + UCI.group_text(group.merge('other_group' => members), [group], [], [], 'smart.yaml'))
    expected = members.nil? || members.empty? ? ['DIRECT'] : ['REJECT']
    assert(value['proxy-groups'][0]['proxies'] == expected, "other_group #{members.inspect}")
  end
  ['^AdBlock$', ['^AdBlock$'], nil, '', []].each do |members|
    node = {'name' => 'TestNode', 'groups' => members}
    provider = {'name' => 'TestProvider', 'groups' => members}
    value = YAML.load("proxy-groups:\n" + UCI.group_text(group, [group], [node], [provider], 'smart.yaml'))['proxy-groups'][0]
    if members.nil? || members.empty?
      assert(value['proxies'] == ['DIRECT'] && !value.key?('use'), "empty memberships #{members.inspect}")
    else
      assert(value['proxies'] == ['TestNode'] && value['use'] == ['TestProvider'], "memberships #{members.inspect}")
    end
  end

  expected = {
    'RULE-SET,AdBlock,AdBlock' => 'RULE-SET,AdBlock,Filtering',
    'MATCH,AdBlock' => 'MATCH,Filtering',
    'IP-CIDR,192.0.2.0/24,AdBlock,no-resolve' => 'IP-CIDR,192.0.2.0/24,Filtering,no-resolve',
    'DOMAIN-REGEX,^a,b[0-9]+$,AdBlock' => 'DOMAIN-REGEX,^a,b[0-9]+$,Filtering',
    'AND,((DOMAIN,example.invalid),(NETWORK,TCP)),AdBlock' => 'AND,((DOMAIN,example.invalid),(NETWORK,TCP)),Filtering',
    'SUB-RULE,(DOMAIN,example.invalid),AdBlock' => 'SUB-RULE,(DOMAIN,example.invalid),AdBlock',
    'RULE-SET,AdBlock,DIRECT' => 'RULE-SET,AdBlock,DIRECT',
    'DOMAIN,AdBlock,DIRECT' => 'DOMAIN,AdBlock,DIRECT'
  }
  renames = [
    {'config' => 'smart.yaml', 'old_name' => 'AdBlock', 'new_name' => 'Ads'},
    {'config' => 'smart.yaml', 'old_name' => 'Ads', 'new_name' => 'Filtering'}
  ]
  config = {
    'proxy-groups' => [{'name' => 'AdBlock', 'type' => 'select', 'proxies' => ['REJECT']}],
    'rules' => expected.keys,
    'sub-rules' => {'AdBlock' => ['MATCH,AdBlock', 'SUB-RULE,(NETWORK,TCP),AdBlock']},
    'rule-providers' => {'AdBlock' => {'type' => 'inline', 'behavior' => 'domain', 'payload' => ['AdBlock']}}
  }
  renamed = Marshal.load(Marshal.dump(config))
  UCI.rename_rule_targets(renamed, renames)
  assert(renamed['rules'] == expected.values, 'rule targets, suffixes, comma payloads and SUB-RULE')
  assert(renamed['sub-rules'] == {'AdBlock' => ['MATCH,Filtering', 'SUB-RULE,(NETWORK,TCP),AdBlock']}, 'sub-rule targets and names')
  assert(renamed['rule-providers'] == config['rule-providers'], 'provider names and payloads stay unchanged')

  package = File.join(dir, 'openclash')
  queue = renames + [{'config' => 'other.yaml', 'old_name' => 'AdBlock', 'new_name' => 'Other'}]
  queue_text = queue.map do |event|
    "config group_rename\n" + event.map { |key, value| " option #{key} '#{value}'\n" }.join
  end.join
  File.write(package, "config proxy_groups\n option config 'smart.yaml'\n option name 'Filtering'\n option type 'select'\n option other_group 'REJECT'\n" + queue_text)
  file = File.join(dir, 'smart.yaml')
  YAML.dump(config, file)
  before = File.binread(file)
  UCI.write_groups(UCI::GROUPS_FILE, 'smart.yaml', dir)
  assert(File.binread(file) == before, 'group edits must leave YAML unchanged before Apply')
  UCI.write_proxies(file, 'smart.yaml', dir)
  applied = YAML.load_file(file)
  assert(applied['proxy-groups'].map { |item| item['name'] } == ['Filtering'], 'Apply saves the renamed group')
  assert(applied['rules'] == expected.values && applied['sub-rules'] == renamed['sub-rules'], 'Apply saves group and rule targets together')
  assert(applied['rule-providers'] == config['rule-providers'], 'Apply preserves same-name rule provider')
  remaining = UCI.read_sections(dir, 'group_rename')
  assert(remaining == [queue.last], 'Apply consumes only this configuration rename queue')

  File.write(package, File.read(package) + "config group_rename\n option config 'smart.yaml'\n option old_name 'Filtering'\n option new_name 'Obsolete'\n")
  assert(UCI.import_groups(file, 'smart.yaml').empty?, 'Read Config succeeds')
  assert(UCI.read_sections(dir, 'group_rename') == [queue.last], 'Read Config clears only its stale rename events')
end

puts 'group rules regression checks passed'
