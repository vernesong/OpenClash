# UCI writes the sections of a package with one `uci import` call, the callers generate the
# text of the sections they own (the sections of the other configuration files, matched on
# the "config" option, stay untouched).
module UCI
  QUOTE = 39.chr
  BACKSLASH = 92.chr
  SAVEDIR = '/tmp/.uci'

  # The callers collect their uci text from several threads; a section must be emitted in one
  # piece, because uci import reads the sections in the order they are written.
  CMDS_LOCK = Mutex.new

  # section type => [package, config directory]
  # New LuCI resolves the types through ubus, which has no directory argument, so a custom
  # directory would be invisible.
  MAIN_TARGETS = {
    'proxies' => ['openclash', '/etc/config'],
    'proxy_groups' => ['openclash', '/etc/config'],
    'proxy_providers' => ['openclash', '/etc/config']
  }.freeze

  # Dynamic sections read back by the configuration pipeline
  STORAGE = '/etc/config'
  STORAGE_PACKAGE = 'openclash'
  GROUP_KEYWORDS = ['DIRECT', 'REJECT', 'REJECT-DROP', 'PASS', 'GLOBAL'].freeze
  LOG_FILES = ['/tmp/openclash.log', '/tmp/openclash_start.log'].freeze
  DECODE = { 'n' => "\n", 't' => "\t", 'r' => "\r", 'e' => 27.chr }.freeze
  ECHO = {
    'n' => "\n", 't' => "\t", 'r' => "\r", 'v' => 11.chr, 'b' => 8.chr,
    'a' => 7.chr, 'e' => 27.chr, 'f' => 12.chr, '\\' => '\\'
  }.freeze

  # Compiled node/provider group patterns, shared by every group of one run
  PATTERN_CACHE = {}

  # Values that config_get_bool reads as false
  DISABLED = ['0', 'off', 'false', 'no', 'disabled'].freeze

  module_function

  # Splits uci text into [{ :type => 'servers', :lines => [...] }, ...]
  def sections(text)
    list = []
    current = nil
    lines_of(text).each do |line|
      if line =~ /^config\s+(\S+)/
        current = { :type => $1, :lines => [line] }
        list << current
      elsif current
        current[:lines] << line
      else
        list << { :type => nil, :lines => [line] }
      end
    end
    list
  end

  # Free form values (other_parameters) keep their line breaks in the storage file, so a
  # quoted value has to be collected from every line it spans.
  def lines_of(text)
    result = []
    pending = nil
    text.to_s.each_line do |line|
      if pending
        pending << line
        next if open_quote?(pending)
        result << pending
        pending = nil
      elsif open_quote?(line)
        pending = line
      else
        result << line
      end
    end
    result << pending if pending
    result
  end

  # Returns the quote character of an unterminated quoted value, otherwise nil
  def open_quote?(text)
    return nil unless text.include?(QUOTE) || text.include?('"')
    quote = nil
    index = 0
    while index < text.length
      char = text[index, 1]
      if char == BACKSLASH
        index += 2
      else
        if quote.nil?
          quote = char if char == QUOTE || char == '"'
        elsif char == quote
          quote = nil
        end
        index += 1
      end
    end
    quote
  end

  # Quotes the value of an option/list line, because uci import rejects bare values
  # ("invalid character in name field").
  def normalize(text)
    text.to_s.gsub(/^(\s*)(option|list)\s+([^=\s]+)\s*=?\s*([^\n]*)/) do
      "#{$1}#{$2} #{$3} #{quote($4)}\n"
    end
  end

  def quote(value)
    raw = unescape(value.to_s.sub(/\s+$/, ''))
    escaped = raw.gsub(BACKSLASH, BACKSLASH + BACKSLASH)
    QUOTE + escaped.gsub(QUOTE) { QUOTE + BACKSLASH + QUOTE + QUOTE } + QUOTE
  end

  # Removes the surrounding quotes of a value written by the yml_*_get.sh scripts
  def unescape(value)
    return value if value.length < 2
    first = value[0, 1]
    last = value[-1, 1]
    return value unless first == last && (first == QUOTE || first == '"')
    inner = value[1..-2]
    if first == '"'
      inner.gsub(BACKSLASH + '"', '"')
    else
      inner.gsub(QUOTE + BACKSLASH + QUOTE + QUOTE, QUOTE)
    end
  end

  # Returns the value of "option config" of a section, or nil when unset
  def section_config(section)
    section[:lines].each do |line|
      return unquote($1) if line =~ /^\s*option\s+config\s+(.+?)\s*$/
    end
    nil
  end

  def unquote(value)
    return nil if value.nil? || value.empty?
    quote = value[0, 1]
    return value unless quote == QUOTE || quote == '"'
    inner = value.length > 2 ? value[1..-2] : ''
    if quote == QUOTE
      inner.gsub(QUOTE + BACKSLASH + QUOTE + QUOTE, QUOTE)
    else
      inner.gsub(BACKSLASH + '"', '"')
    end
  end

  # Splits uci text by section type: { 'proxies' => 'config proxies ...', ... }
  def split_by_type(text)
    result = {}
    sections(text).each do |section|
      next if section[:type].nil?
      result[section[:type]] ||= []
      result[section[:type]].concat(section[:lines])
    end
    result
  end

  # Replaces the sections of `type` owned by `config_name` with `new_text`, nil on success
  # otherwise the uci error message. The package is read through package_text, so a pending
  # change in the save directory is carried over instead of being dropped.
  def replace(dir, pkg, type, config_name, new_text, sort = true)
    old = package_text(dir, pkg)
    keep = sections(old).reject do |section|
      section[:type] == type && section_config(section) == config_name
    end
    body = keep.map { |section| section[:lines] }.join
    body << (sort ? canonical(new_text) : new_text)
    body << "\n" unless body.empty? || body.end_with?("\n")
    import(dir, pkg, body, false)
  end

  # Raw text of any package in `dir`
  def read_package(dir, pkg)
    path = File.join(dir, pkg)
    File.exist?(path) ? File.read(path) : ''
  end

  # Replaces the sections contained in `stream` (grouped by section type), targets maps a
  # section type to [package, directory]. `types` names the types the caller owns, they are
  # replaced even when the stream holds none of them. Returns { type => error message }.
  def replace_stream(config_name, stream, targets = MAIN_TARGETS, sort = true, types = [])
    failures = {}
    grouped = split_by_type(stream)
    types.each { |type| grouped[type] ||= [] }
    grouped.each do |type, lines|
      target = targets[type]
      next if target.nil?
      error = replace(target[1], target[0], type, config_name, lines.join, sort)
      failures[type] = error if error
    end
    failures
  end

  # Sorts the lines of every section (name first, then the option names) and keeps the order
  # of a list, so the same configuration is written the same way on every run. A text without
  # a trailing line break is closed here, section lines are joined without a separator.
  def canonical(text)
    body = text.empty? || text.end_with?("\n") ? text : text + "\n"
    sections(body).map do |section|
      section[:type].nil? ? section[:lines].join : canonical_section(section[:lines])
    end.join
  end

  def canonical_section(lines)
    head = terminated(lines.first.to_s)
    body = (lines[1..-1] || []).map { |line| terminated(line) }.each_with_index.sort_by do |line, index|
      option = line =~ /^\s*(?:option|list)\s+(\S+)/ ? $1 : ''
      [option == 'name' ? '' : option, index]
    end
    head + body.map { |line, _| line }.join
  end

  def terminated(line)
    line.empty? || line.end_with?("\n") ? line : line + "\n"
  end

  # The get scripts collect `option name="value"` lines (the syntax of the uci command line),
  # while a package file rejects them with "invalid character in name field". The conversion
  # runs line by line on purpose, a pattern that spans lines would backtrack over the whole
  # file once per line.
  def file_format(text)
    text.each_line.map do |line|
      parts = file_format_parts(line)
      next line if parts.nil?
      indent, kind, name, value = parts
      ending = line[/\r?\n\z/].to_s
      quoted =
        if !value.include?("'")
          "'#{value}'"
        elsif !value.include?('"')
          "\"#{value}\""
        else
          "'#{value.gsub(/['\\]/) { |char| '\\' + char }}'"
        end
      "#{indent}#{kind} #{name} #{quoted}#{ending}"
    end.join
  end

  # [indent, kind, name, value] of a `option name=value` line, nil when the line is not
  # written in the command line syntax
  def file_format_parts(line)
    return nil unless line =~ /\A([ \t]*)(option|list)[ \t]+([^=\s"']+)=(.*?)[ \t]*\r?\n?\z/
    value = $4
    value = value[1..-2] if value.length > 1 && value.start_with?('"') && value.end_with?('"')
    [$1, $2, $3, value]
  end

  # Writes `text` as the whole content of package `pkg` with one `uci import` call, nil on
  # success otherwise the uci error message. `order` re-sorts the option lines of freshly
  # generated text, the stored sections are written back verbatim.
  def import(dir, pkg, text, order = true)
    path = File.join(dir, pkg)
    tmp = "/tmp/oc_uci_#{pkg}.new"
    err = "/tmp/oc_uci_#{pkg}.err"
    backup = "#{path}.bak"
    # uci reports "I/O error" instead of creating the package when the directory is missing
    system('mkdir', '-p', dir) unless File.directory?(dir)
    body = file_format(text)
    body = canonical(body) if order
    File.open(tmp, 'w') { |file| file.write(body) }
    # flush pending changes first, otherwise a stale delta would be applied over the new file
    system('uci', '-c', dir, 'commit', pkg, :err => File::NULL, :out => File::NULL)
    File.rename(path, backup) if File.exist?(path)
    ok = system('uci', '-c', dir, '-f', tmp, 'import', pkg, :err => [err, 'w'], :out => File::NULL)
    if ok
      File.delete(backup) if File.exist?(backup)
      File.delete(File.join(SAVEDIR, pkg)) if File.exist?(File.join(SAVEDIR, pkg))
      File.delete(tmp) if File.exist?(tmp)
      File.delete(err) if File.exist?(err)
      nil
    else
      message = File.exist?(err) ? File.read(err).strip : ''
      message = "uci import failed for #{pkg}" if message.empty?
      # keep the rejected text and the error file for troubleshooting
      File.rename(backup, path) if File.exist?(backup)
      message
    end
  end

  # Reads the sections of one type out of the storage package as a list of option hashes, in
  # file order: the generated configuration, the servers page and the chained proxy
  # definitions rely on it.
  # Note: the name must not be Kernel#load, which shadows module functions on some rubies.
  def read_sections(dir, type)
    sections(package_text(dir)).select { |section| section[:type] == type }.map { |section| options(section) }
  end

  # Text of a package. `uci export` is preferred over reading the file because it includes
  # the changes a caller wrote but did not commit yet, which is what config_load used to see.
  # The leading `package` line is dropped, uci does not store it in the file.
  def package_text(dir, pkg = STORAGE_PACKAGE)
    text = nil
    begin
      text = IO.popen(['uci', '-c', dir, '-q', 'export', pkg], :err => File::NULL, &:read)
    rescue ::Exception
      text = nil
    end
    unless text.nil? || text.empty?
      return text.sub(/\Apackage\s+\S+[ \t]*\n\n?/, '')
    end
    read_package(dir, pkg)
  end

  def options(section)
    result = {}
    section[:lines].each do |line|
      next unless line =~ /\A\s*(option|list)\s+(\S+)[ \t]*(.*)\z/m
      value = value_of($3)
      if $1 == 'list'
        (result[$2] ||= []) << value
      else
        result[$2] = value
      end
    end
    result
  end

  # Decodes the value of an option line as written by uci
  def value_of(raw)
    text = raw.to_s.sub(/\s+\z/, '')
    return '' if text.empty?
    quote = text[0, 1]
    if text.length > 1 && (quote == QUOTE || quote == '"') && text[-1, 1] == quote
      decode(text[1..-2])
    else
      decode(text.sub(/\s+#.*\z/m, ''))
    end
  end

  def decode(text)
    text.gsub(/\\(.)/) { DECODE[$1] || $1 }
  end

  # Rebuilds the whole `proxy-groups:` block from the dynamic storage.
  def write_groups(path, config_name, dir = STORAGE)
    groups = read_sections(dir, 'proxy_groups')
    nodes = read_sections(dir, 'proxies')
    providers = read_sections(dir, 'proxy_providers')
    File.open(path, 'w') do |file|
      file.write("proxy-groups:\n")
      groups.each do |group|
        begin
          text = group_text(group, groups, nodes, providers, config_name)
          file.write(text) unless text.nil?
        rescue ::Exception => error
          YAML.LOG_ERROR('Resolve Group Failed,【' + group['name'].to_s + ' - ' + error.message + '】')
        end
      end
    end
  end

  def group_text(group, groups, nodes, providers, config_name)
    name = group['name'].to_s
    type = group['type'].to_s
    return nil if name.empty? || type.empty?
    return nil if !enabled?(group) || !own_section?(group, config_name)
    log_line("Start Writing【#{config_name} - #{type} - #{name}】Group To Config File...")
    members = member_lines(group, groups, nodes, name, config_name)
    uses = use_lines(name, providers, config_name)
    lines = []
    lines << "  - name: #{name}"
    lines << "    type: #{type}"
    if members.empty? && uses.empty?
      lines << '    proxies:'
      lines << '      - DIRECT'
    else
      unless members.empty?
        lines << '    proxies:'
        lines.concat(members)
      end
      unless uses.empty?
        lines << '    use:'
        lines.concat(uses)
      end
    end
    lines.concat(option_lines(group, type))
    lines.join("\n") + "\n"
  end

  def member_lines(group, groups, nodes, name, config_name)
    members = []
    (group['other_group'] || []).each do |pattern|
      builtin = GROUP_KEYWORDS.find { |word| plain_pattern(pattern) == word }
      if builtin
        members << "      - #{builtin}"
        next
      end
      groups.each do |other|
        other_name = other['name'].to_s
        next if other_name.empty? || other_name == name
        next if !enabled?(other) || !own_section?(other, config_name)
        members << "      - #{other_name}" if matched?(pattern, other_name)
      end
    end
    nodes.each do |node|
      next if !enabled?(node) || !own_section?(node, config_name)
      next unless (node['groups'] || []).any? { |pattern| matched?(pattern, name) }
      members << "      - \"#{node['name']}\""
    end
    members
  end

  def use_lines(name, providers, config_name)
    uses = []
    providers.each do |provider|
      provider_name = provider['name'].to_s
      next if provider_name.empty?
      next if !enabled?(provider) || !own_section?(provider, config_name)
      next unless (provider['groups'] || []).any? { |pattern| matched?(pattern, name) }
      uses << "      - #{provider_name}"
    end
    uses
  end

  def option_lines(group, type)
    lines = []
    lines << "    strategy: #{group['strategy']}" if type == 'load-balance' && group['strategy'].to_s != ''
    lines << "    disable-udp: #{group['disable_udp']}" if group['disable_udp'].to_s != ''
    lines << "    url: #{group['test_url']}" if group['test_url'].to_s != ''
    lines << "    interval: \"#{group['test_interval']}\"" if group['test_interval'].to_s != ''
    lines << "    tolerance: \"#{group['tolerance']}\"" if group['tolerance'].to_s != ''
    lines << "    filter: \"#{group['policy_filter']}\"" if group['policy_filter'].to_s != ''
    lines << "    interface-name: \"#{group['interface_name']}\"" if group['interface_name'].to_s != ''
    lines << "    routing-mark: \"#{group['routing_mark']}\"" if group['routing_mark'].to_s != ''
    if type == 'smart'
      lines << "    uselightgbm: #{group['uselightgbm']}" if group['uselightgbm'].to_s != ''
      lines << "    collectdata: #{group['collectdata']}" if group['collectdata'].to_s != ''
      lines << "    policy-priority: \"#{group['policy_priority']}\"" if group['policy_priority'].to_s != ''
    end
    lines << "    icon: #{group['icon']}" if group['icon'].to_s != ''
    lines << echo_e(group['other_parameters']) if group['other_parameters'].to_s != ''
    lines
  end

  # `echo -e` of the shell implementation, other_parameters is free form text
  def echo_e(value)
    value.to_s.gsub(/\\(.)/) { ECHO[$1] || BACKSLASH + $1 }
  end

  def own_section?(section, config_name)
    config = section['config'].to_s
    config.empty? || config == config_name || config == 'all'
  end

  # config_get_bool of the shell implementation, with the "enabled" default of 1
  def enabled?(section)
    !DISABLED.include?(section['enabled'].to_s)
  end

  def matched?(pattern, text)
    return false if pattern.nil? || pattern.empty?
    return true if pattern == 'all'
    expression = pattern_regexp(pattern)
    expression ? expression.match?(text) : false
  end

  # `^NAME$` as stored by the yml_*_get.sh scripts
  def plain_pattern(pattern)
    pattern.to_s.sub(/\A\^/, '').sub(/\$\z/, '')
  end

  def pattern_regexp(pattern)
    return PATTERN_CACHE[pattern] if PATTERN_CACHE.key?(pattern)
    PATTERN_CACHE[pattern] = (Regexp.new(pattern) rescue nil)
  end

  def log_line(info)
    line = Time.new.strftime('%Y-%m-%d %H:%M:%S') + ' [Info] ' + info.to_s + "\n"
    LOG_FILES.each { |path| File.open(path, 'a') { |file| file.write(line) } }
  end

  # Node and proxy provider fragments (yml_proxys_set.sh). The text is generated here instead
  # of one `cat >> file <<EOF` plus one uci lookup per option line, the fragment files and
  # the merge below are the ones the shell driver used, the file stays the same.

  SERVERS_FILE = '/tmp/yaml_servers.yaml'
  PROVIDERS_FILE = '/tmp/yaml_provider.yaml'
  GROUPS_FILE = '/tmp/yaml_groups.yaml'

  PROXY_FILE_KEYS = [
    ['proxies', SERVERS_FILE],
    ['proxy-providers', PROVIDERS_FILE],
    ['proxy-groups', GROUPS_FILE]
  ].freeze

  # The duplicate guards of the shell implementation: names are collected first and a section
  # is dropped when its name already exists or repeats. Plain names go through a hash, non
  # plain ones keep the grep semantics.
  class Guard
    META = /[.\[\]*+?(){}|\\^$]/
    WORD = /[A-Za-z0-9_]/

    def initialize(names, pattern)
      @list = names.dup
      @pattern = pattern
      @emitted = []
      @plain_list = @list.all? { |name| Guard.plain?(name) }
      @counts = Hash.new(0)
      @list.each { |name| @counts[name] += 1 } if @plain_list
      @count = Hash.new(0)
    end

    def self.plain?(value)
      !META.match?(value)
    end

    def self.regexp(text)
      Regexp.new(text)
    rescue ::Exception
      nil
    end

    # grep -w <pattern> on one line
    def self.word_match?(line, expression)
      index = 0
      while index <= line.length && (match = expression.match(line, index))
        start = match.begin(0)
        stop = match.end(0)
        head = start.zero? ? ' ' : line[start - 1, 1]
        tail = stop >= line.length ? ' ' : line[stop, 1]
        return true if !WORD.match?(head) && !WORD.match?(tail)
        index = start + 1
      end
      false
    end

    # grep -w "^$value$" <name list> | wc -l
    def times_in_list(value)
      return @counts[value] if @plain_list && Guard.plain?(value)
      expression = Guard.regexp('^' + value + '$')
      return 0 if expression.nil?
      @list.count { |text| Guard.word_match?(text, expression) }
    end

    # sed -i "1,/^$value$/{//d}" <name list>, i.e. drop the first match
    def drop_first(value)
      if @plain_list && Guard.plain?(value)
        index = @list.index(value)
      else
        expression = Guard.regexp('^' + value + '$')
        index = expression && @list.index { |text| Guard.word_match?(text, expression) }
      end
      return nil if index.nil?
      dropped = @list.delete_at(index)
      @counts[dropped] -= 1 if @plain_list
      dropped
    end

    # grep -w "name: \"$value\"" <fragment>
    def written?(value)
      return @count[value].positive? if Guard.plain?(value)
      expression = Guard.regexp(@pattern.call(value))
      !expression.nil? && @emitted.any? { |line| Guard.word_match?(line, expression) }
    end

    def mark(value, line)
      @count[value] += 1 if Guard.plain?(value)
      @emitted << line
    end
  end

  # config_get: the value of an option, the items of a list joined by LIST_SEP (" ")
  def opt(section, key, fallback = '')
    value = section[key]
    value = value.is_a?(Array) ? value.join(' ') : value.to_s
    value = fallback if value.empty?
    value
  end

  # config_list_foreach: a `list` option yields its items. A value stored as a single option
  # (a hand edited or an imported file) is used as one item instead of being dropped.
  def each_item(section, key)
    value = section[key]
    return value.reject { |item| item.to_s.empty? } if value.is_a?(Array)
    value.to_s.empty? ? [] : [value.to_s]
  end

  # config_load reads an other uci directory when UCI_CONFIG_DIR is set
  def storage_dir
    dir = ENV['UCI_CONFIG_DIR'].to_s
    dir.empty? ? STORAGE : dir
  end

  # Keys of a node that do not come from the field table: the ones the section carries itself
  # and the blocks the set direction builds from several options (the ss plugin from `obfs`,
  # the vmess http block with a fixed method, the mieru transport with defaults).
  NODE_OWN_KEYS = %w[name type config enabled manual groups].freeze
  NODE_BUILT_KEYS = {
    '*' => %w[smux],
    'ss' => %w[plugin plugin-opts],
    'vmess' => %w[http-opts],
    'http' => %w[headers],
    'mieru' => %w[transport multiplexing]
  }.freeze

  # A nested block is written when the node really uses the transport the block belongs to:
  # the sub keys of `ws-opts` belong to `network: ws`, and a block whose parent network is
  # no longer selected is left out instead of being written with a stale value.
  # A block without an entry here is written when at least one of its sub keys has a value.
  SET_BLOCK_GUARDS = {
    'ws-opts' => {'vmess' => 'obfs_vmess=websocket', 'vless' => 'obfs_vless=ws', 'trojan' => 'obfs_trojan=ws'},
    'h2-opts' => {'vmess' => 'obfs_vmess=h2'},
    'grpc-opts' => {'vmess' => 'obfs_vmess=grpc', 'vless' => 'obfs_vless=grpc', 'trojan' => 'obfs_trojan=grpc'},
    'xhttp-opts' => {'vless' => 'obfs_vless=xhttp'},
    'obfs-opts' => {'snell' => 'obfs_snell!=none'},
    'reality-opts' => {'vless' => 'obfs_vless!=none'},
    'smux' => {'*' => ['multiplex', 'multiplex!=false']}
  }.freeze

  # A row that maps a uci value to a yaml value (`:mapped` reads the other direction):
  # a value the map does not name is kept, so a plain key can be written unchanged.
  def mapped_yaml_value(map, value)
    return value if map.key?(value)
    found = nil
    map.each { |yaml, uci| found = yaml if uci == value }
    found
  end

  # The yaml text of the node keys the plugin cannot write itself: the form keeps them in
  # `other_parameters`, so a hand written key survives the import of its section.
  #
  # Only whole keys are moved: the text is appended below the node, so a key has to carry its
  # parent with it. A key the table knows is only moved when it is a block with a sub key
  # without a row (tlsmirror-opts), then the block is kept as text and its name is written to
  # `other_blocks`, which keeps the rows of that block out of the file.
  def other_parameters_lines(node)
    type = node['type'].to_s
    known, blocks = node_row_paths(type)
    built = NODE_BUILT_KEYS.fetch(type, [])
    text = {}
    blocked = []
    node.each do |raw_key, value|
      key = raw_key.to_s
      next if NODE_OWN_KEYS.include?(key) || NODE_BUILT_KEYS['*'].include?(key) || built.include?(key)
      if !known.include?(key)
        text[key] = value
      elsif value.is_a?(Hash) && uncovered_paths(value, blocks[key]).any?
        text[key] = value
        blocked << key
      end
    end

    lines = []
    unless text.empty?
      body = Psych.dump(text).sub(/\A---\s*\n/, '').split("\n").reject(&:empty?)
      lines << "\toption other_parameters '#{body.map { |line| "    #{line}" }.join("\n")}'"
    end
    lines << "\toption other_blocks '#{blocked.join(' ')}'" unless blocked.empty?
    lines
  end

  # Keys of a type the rows can write: the plain keys of the node and, per block, the sub
  # keys below it. `blocks` is empty for a type whose rows are all plain keys.
  def node_row_paths(type)
    keys = []
    blocks = {}
    GET_NODE_FIELDS.each do |_option, path, _kind, _guard, types, _fixed|
      next if path.nil? || path.empty?
      next if types && !types.include?(type)
      head, rest = path.split('.', 2)
      keys << head
      (blocks[head] ||= []) << rest if rest
    end
    [keys, blocks]
  end

  # Sub keys of a block value the rows of that block cannot write, as their dotted path.
  # A row covers the key it names and everything below it (a `:headers` row writes the
  # whole map). A list of maps is always uncovered: the `list` rendering writes plain items.
  def uncovered_paths(value, sub_paths, prefix = '')
    sub_paths ||= []
    if value.is_a?(Hash)
      value.flat_map { |key, item| uncovered_paths(item, sub_paths, prefix.empty? ? key.to_s : "#{prefix}.#{key}") }
    elsif value.is_a?(Array) && value.any? { |item| item.is_a?(Hash) }
      [prefix]
    elsif sub_paths.any? { |sub| prefix == sub || prefix.start_with?("#{sub}.") }
      []
    else
      [prefix]
    end
  end

  # Writes the `proxies:` and `proxy-providers:` blocks of the configuration file, `dir` is
  # the uci directory config_load would have read (UCI_CONFIG_DIR).
  def write_proxies(config_file, config_name, dir = storage_dir)
    package = read_package_rows(dir)
    log_line("Start Writing【#{config_name}】Proxy-providers Setting...")
    providers = provider_fragment(config_name, dir, package['proxy_providers'])
    log_line("Start Writing【#{config_name}】Proxies Setting...")
    servers = node_fragment(config_name, dir, package['proxies'])
    # the parsed package and the section lists are dead weight from here on, the fragments
    # are on disk before the merge reads the whole configuration file back
    package = nil
    store_fragment(PROVIDERS_FILE, providers)
    store_fragment(SERVERS_FILE, servers)
    providers = nil
    servers = nil
    log_line("Proxies, Proxy-providers, Groups Edited Successful, Updating Config File【#{config_name}】...")
    GC.start
    merge_fragments(config_file)
    log_line("Config File【#{config_name}】Write Successful!")
  end

  # Option hashes of every section of the storage package, grouped by section type, read in
  # one pass so that the node and the provider pass do not parse the package twice.
  def read_package_rows(dir)
    result = {}
    sections(package_text(dir)).each do |section|
      type = section[:type]
      next if type.nil?
      (result[type] ||= []) << options(section)
    end
    result
  end

  def store_fragment(path, text)
    if text.nil?
      File.delete(path) if File.exist?(path)
    else
      File.write(path, text)
    end
  end

  # The fragments replace the matching keys of the target file, a key without fragment is
  # dropped. `failed` picks the fallback of the caller, so an unparsable fragment ends up
  # here instead of aborting the run.
  def merge_fragments(config_file)
    failed = false
    begin
      value = YAML.load_file(config_file)
      PROXY_FILE_KEYS.each do |key, path|
        begin
          if File.exist?(path)
            value[key] = YAML.load_file(path)[key]
          else
            value.delete(key)
          end
        rescue ::Exception => error
          failed = true
          YAML.LOG_ERROR('Merge Failed,【' + key + ' - ' + error.message + '】')
        end
      end
      YAML.dump(value, config_file)
    rescue ::Exception => error
      failed = true
      YAML.LOG_ERROR('Update Config File Failed,【' + error.message + '】')
    end
    concatenate_fragments(config_file) if failed
  ensure
    PROXY_FILE_KEYS.each { |_, path| File.delete(path) if File.exist?(path) }
  end

  # `cat $SERVER_FILE $PROXY_PROVIDER_FILE /tmp/yaml_groups.yaml > $CONFIG_FILE`
  def concatenate_fragments(config_file)
    return unless File.exist?(config_file)
    body = PROXY_FILE_KEYS.map { |_, path| File.exist?(path) ? File.read(path) : '' }.join
    File.write(config_file, body) unless body.empty?
  rescue ::Exception
    nil
  end

  def provider_fragment(config_name, dir = storage_dir, rows = nil)
    rows ||= read_sections(dir, 'proxy_providers')
    guard = Guard.new(rows.map { |row| opt(row, 'name') }.reject(&:empty?), ->(value) { 'path: ' + value })
    out = "proxy-providers:\n"
    rows.each do |section|
      enabled = enabled?(section)
      type = opt(section, 'type')
      name = opt(section, 'name')
      path = opt(section, 'path')
      health_check = opt(section, 'health_check')
      config = opt(section, 'config')
      next unless enabled
      next if type.empty? || name.empty?
      if path != "./proxy_provider/#{name}.yaml" && type == 'http'
        path = "./proxy_provider/#{name}.yaml"
      elsif path.empty?
        next
      end
      next if health_check.empty?
      next if !config.empty? && config != config_name && config != 'all'
      if config == config_name || config == 'all'
        next if guard.times_in_list(name) >= 2 && guard.written?(path)
        next if guard.written?(path)
        if guard.times_in_list(name) >= 2 && !guard.written?(path)
          guard.drop_first(name)
          next
        end
      end
      log_line("Start Writing【#{config_name} - #{type} - #{name}】Proxy-provider To Config File...")
      provider_filter = opt(section, 'provider_filter')
      provider_url = opt(section, 'provider_url')
      other_parameters = opt(section, 'other_parameters')
      out << "  #{name}:\n"
      out << "    type: #{type}\n"
      out << "    path: \"#{path}\"\n"
      out << "    filter: \"#{provider_filter}\"\n" unless provider_filter.empty?
      unless provider_url.empty?
        out << "    url: \"#{provider_url}\"\n"
        out << "    interval: #{opt(section, 'provider_interval')}\n"
      end
      out << "    health-check:\n"
      out << "      enable: #{health_check}\n"
      out << "      url: \"#{opt(section, 'health_check_url')}\"\n"
      out << "      interval: #{opt(section, 'health_check_interval')}\n"
      out << echo_e(other_parameters) + "\n" unless other_parameters.empty?
      guard.mark(path, "    path: \"#{path}\"")
    end
    out == "proxy-providers:\n" ? nil : out
  end

  def node_fragment(config_name, dir = storage_dir, rows = nil)
    rows ||= read_sections(dir, 'proxies')
    guard = Guard.new(rows.map { |row| opt(row, 'name') }.reject(&:empty?), ->(value) { 'name: "' + value + '"' })
    out = "proxies:\n"
    rows.each do |section|
      text = node_text(section, config_name, guard)
      out << text if text
    end
    out == "proxies:\n" ? nil : out
  end

  # One `- name: ...` block of the proxies list, nil when the section is skipped
  def node_text(section, config_name, guard)
    type = opt(section, 'type')
    name = opt(section, 'name')
    server = opt(section, 'server')
    port = opt(section, 'port')
    config = opt(section, 'config')
    return nil unless enabled?(section)
    return nil if type.empty? || name.empty?
    return nil if server.empty? && !%w[direct dns tailscale zerotier].include?(type)
    return nil if port.empty? && !%w[direct dns tailscale zerotier].include?(type)
    return nil if (type == 'ss' || type == 'trojan' || type == 'ssr') && opt(section, 'password').empty?
    return nil if !config.empty? && config != config_name && config != 'all'
    if config == config_name || config == 'all'
      return nil if guard.times_in_list(name) >= 2 && guard.written?(name)
      return nil if guard.written?(name)
      if guard.times_in_list(name) >= 2 && !guard.written?(name)
        guard.drop_first(name)
        return nil
      end
    end
    log_line("Start Writing【#{config_name} - #{type} - #{name}】Proxy To Config File...")

    skip_cert_verify = opt(section, 'skip_cert_verify')
    tls = opt(section, 'tls')
    fingerprint = opt(section, 'fingerprint')
    other_parameters = opt(section, 'other_parameters')

    out = []
    head = "  - name: \"#{name}\"\n    type: #{type}\n"
    tail = ''

    # every node starts with the rows of the shared table, the case below adds the two blocks
    # whose content the table cannot express: the ss plugin and the vmess http block
    out << head
    out.concat(set_lines(section, type))

    case type
    when 'ss'
      obfs = opt(section, 'obfs')
      host = opt(section, 'host')
      mux = opt(section, 'mux')
      custom = opt(section, 'custom')
      path = opt(section, 'path')
      if !obfs.empty? && obfs != 'none'
        plugin = if obfs == 'websocket'
                   'plugin: v2ray-plugin'
                 elsif obfs == 'shadow-tls'
                   'plugin: shadow-tls'
                 elsif obfs == 'restls'
                   'plugin: restls'
                 else
                   'plugin: obfs'
                 end
      else
        plugin = ''
      end
      path = "path: \"#{path}\"" unless path.empty?
      unless plugin.empty?
        plugin_opts = []
        plugin_opts << "      mode: #{obfs}\n" if obfs != 'shadow-tls' && obfs != 'restls'
        plugin_opts << "      host: \"#{host}\"\n" unless host.empty?
        if plugin == 'plugin: shadow-tls'
          obfs_password = opt(section, 'obfs_password')
          plugin_opts << "      password: \"#{obfs_password}\"\n" unless obfs_password.empty?
          plugin_opts << "      fingerprint: \"#{fingerprint}\"\n" unless fingerprint.empty?
        end
        if plugin == 'plugin: restls'
          obfs_password = opt(section, 'obfs_password')
          obfs_version_hint = opt(section, 'obfs_version_hint')
          obfs_restls_script = opt(section, 'obfs_restls_script')
          plugin_opts << "      password: \"#{obfs_password}\"\n" unless obfs_password.empty?
          plugin_opts << "      version-hint: \"#{obfs_version_hint}\"\n" unless obfs_version_hint.empty?
          plugin_opts << "      restls-script: \"#{obfs_restls_script}\"\n" unless obfs_restls_script.empty?
        end
        if plugin == 'plugin: v2ray-plugin'
          plugin_opts << "      tls: #{tls}\n" unless tls.empty?
          plugin_opts << "      skip-cert-verify: #{skip_cert_verify}\n" unless skip_cert_verify.empty?
          plugin_opts << "      #{path}\n" unless path.empty?
          plugin_opts << "      mux: #{mux}\n" unless mux.empty?
          plugin_opts << "      headers:\n        custom: #{custom}\n" unless custom.empty?
          plugin_opts << "      fingerprint: \"#{fingerprint}\"\n" unless fingerprint.empty?
        end
        out << "    #{plugin}\n"
        unless plugin_opts.empty?
          out << "    plugin-opts:\n"
          out.concat(plugin_opts)
        end
      end
    when 'ssr'
    when 'vmess'
      # The vmess http block is the one block the table cannot write: mihomo expects the method
      # and the keep-alive marker, both are constants of the plugin.
      obfs = opt(section, 'obfs_vmess')
      http_path = opt(section, 'http_path')
      keep_alive = opt(section, 'keep_alive')
      if obfs == 'http' && (!http_path.empty? || keep_alive == 'true')
        out << "    http-opts:\n      method: \"GET\"\n"
        unless http_path.empty?
          out << "      path:\n"
          each_item(section, 'http_path').each { |item| out << "        - '#{item}'\n" }
        end
        out << "      headers:\n        Connection:\n          - keep-alive\n" if keep_alive == 'true'
      end
    when 'anytls'
    when 'mieru'
      transport = opt(section, 'transport', 'TCP')
      multiplexing = opt(section, 'multiplexing', 'MULTIPLEXING_LOW')
      out << "    transport: \"#{transport}\"\n" unless transport.empty?
      out << "    multiplexing: \"#{multiplexing}\"\n" unless multiplexing.empty?
    when 'tuic'
    when 'wireguard'
    when 'hysteria'
    when 'hysteria2'
    when 'dns'
    when 'direct'
    when 'ssh'
    when 'socks5'
    when 'http'
      http_headers = opt(section, 'http_headers')
      unless http_headers.empty?
        out << "    headers:\n"
        each_item(section, 'http_headers').each { |item| out << "        #{item}\n" }
      end
    when 'sudoku'
    when 'masque'
    when 'trusttunnel'
    end

    tail << echo_e(other_parameters) + "\n" unless other_parameters.empty?
    guard.mark(name, "  - name: \"#{name}\"")
    (out << tail).join
  end

  # hysteria / hysteria2: a single alpn value keeps its own line layout
  # ---------------------------------------------------------------------------
  # Get direction: one row per uci option, field_lines writes the lines of the rows that
  # apply: [option, yaml path, kind, presence guard, node types, fixed value].
  #   option uci option name, it has to exist in the lua form of the pages
  #   path   key path inside the configuration ("smux.enabled" for a nested key)
  #   kind   :string quotes, :bare writes unchanged, :list writes one `list` line per item,
  #          :headers writes one `key: value` item per key of a map, :fixed the row value,
  #          :mapped the mapped value, :bool_string an off/on string read as a boolean
  #   guard  key path that has to be present, nil when unconditional
  #   types  node types the row belongs to, nil for every type
  #   fixed  value of a :fixed row, the value map of a :mapped row
  # A new option needs one row here and one field in the lua form, nothing else.
  # ---------------------------------------------------------------------------
  GET_PROVIDER_FIELDS = [
    ['type', 'type', :string, 'type', nil, nil],
    ['path', 'path', :string, 'path', nil, nil],
    ['provider_url', 'url', :string, 'url', nil, nil],
    ['provider_interval', 'interval', :string, 'interval', nil, nil],
    ['provider_filter', 'filter', :string, 'filter', nil, nil],
    ['health_check', 'health-check.enable', :string, 'health-check', nil, nil],
    ['health_check_url', 'health-check.url', :string, 'health-check', nil, nil],
    ['health_check_interval', 'health-check.interval', :string, 'health-check', nil, nil],
  ].freeze

  # A group is written from the uci sections by the set direction, so these rows are read by
  # the get direction only (the shell built them with 13 YAML::Inline workers per group).
  # `strategy` is the load-balance mode, `strategy_smart` the one of a smart group; a smart
  # group reads the same key, both rows are told apart by the type.
  GET_GROUP_FIELDS = [
    ['strategy', 'strategy', :string, 'strategy', %w[load-balance], nil],
    ['strategy_smart', 'strategy', :string, 'strategy', %w[smart], nil],
    ['uselightgbm', 'uselightgbm', :string, 'uselightgbm', %w[smart], nil],
    ['collectdata', 'collectdata', :string, 'collectdata', %w[smart], nil],
    ['policy_priority', 'policy-priority', :string, 'policy-priority', %w[smart], nil],
    ['disable_udp', 'disable-udp', :string, 'disable-udp', nil, nil],
    ['test_url', 'url', :string, 'url', %w[url-test fallback load-balance smart], nil],
    ['test_interval', 'interval', :string, 'interval', %w[url-test fallback load-balance smart], nil],
    ['tolerance', 'tolerance', :string, 'tolerance', %w[url-test], nil],
    ['policy_filter', 'filter', :string, 'filter', nil, nil],
    ['interface_name', 'interface-name', :string, 'interface-name', nil, nil],
    ['routing_mark', 'routing-mark', :string, 'routing-mark', nil, nil],
    ['icon', 'icon', :string, 'icon', nil, nil],
  ].freeze

  # Members that are groups themselves are stored as `other_group` patterns, the set
  # direction resolves them back to group names. COMPATIBLE is only read here.
  GROUP_GET_KEYWORDS = (GROUP_KEYWORDS + ['COMPATIBLE']).uniq.freeze

  GET_NODE_FIELDS = [
    ['type', 'type', :string, 'type', nil, nil, :none],
    ['server', 'server', :string, 'server', nil, nil],
    ['port', 'port', :string, 'port', nil, nil, :bare],
    ['udp', 'udp', :string, 'udp', nil, nil, :bare],
    ['interface_name', 'interface-name', :string, 'interface-name', nil, nil],
    ['routing_mark', 'routing-mark', :string, 'routing-mark', nil, nil],
    ['ip_version', 'ip-version', :string, 'ip-version', nil, nil],
    ['tfo', 'tfo', :string, 'tfo', nil, nil, :bare],
    ['dialer_proxy', 'dialer-proxy', :string, 'dialer-proxy', nil, nil],
    ['cipher', 'cipher', :string, 'cipher', %w[ss ssr vmess openvpn], nil, :bare],
    ['udp_over_tcp', 'udp-over-tcp', :string, 'udp-over-tcp', nil, nil, :bare],
    ['multiplex', 'smux.enabled', :string, 'smux', nil, nil, :bare],
    ['multiplex_protocol', 'smux.protocol', :string, 'smux', nil, nil, :bare],
    ['multiplex_max_connections', 'smux.max-connections', :string, 'smux', nil, nil, :bare],
    ['multiplex_min_streams', 'smux.min-streams', :string, 'smux', nil, nil, :bare],
    ['multiplex_max_streams', 'smux.max-streams', :string, 'smux', nil, nil, :bare],
    ['multiplex_padding', 'smux.padding', :string, 'smux', nil, nil, :bare],
    ['multiplex_statistic', 'smux.statistic', :string, 'smux', nil, nil, :bare],
    ['multiplex_only_tcp', 'smux.only-tcp', :string, 'smux', nil, nil, :bare],
    # the ss plugin block is picked from `obfs` and written by node_text, so its sub keys
    # are read here and rendered there (:none)
    ['obfs', 'plugin-opts.mode', :string, 'plugin-opts', nil, nil, :none],
    ['host', 'plugin-opts.host', :string, 'plugin-opts', nil, nil, :none],
    ['fingerprint', 'plugin-opts.fingerprint', :string, 'plugin-opts', nil, nil, :none],
    ['path', 'plugin-opts.path', :string, 'plugin=v2ray-plugin', nil, nil, :none],
    ['mux', 'plugin-opts.mux', :string, 'plugin=v2ray-plugin', nil, nil, :none],
    ['custom', 'plugin-opts.headers.custom', :string, 'plugin=v2ray-plugin', nil, nil, :none],
    ['tls', 'plugin-opts.tls', :string, 'plugin-opts', nil, nil, :none],
    ['skip_cert_verify', 'plugin-opts.skip-cert-verify', :string, 'plugin-opts', nil, nil, :none],
    ['obfs', 'plugin', :mapped, 'plugin', %w[ss], {'shadow-tls' => 'shadow-tls', 'restls' => 'restls'}, :none],
    ['obfs_password', 'plugin-opts.password', :string, 'plugin-opts', nil, nil, :none],
    ['obfs_version_hint', 'plugin-opts.version-hint', :string, 'plugin=restls', nil, nil, :none],
    ['obfs_restls_script', 'plugin-opts.restls-script', :string, 'plugin=restls', nil, nil, :none],
    ['obfs_ssr', 'obfs', :string, 'obfs', %w[ssr], nil],
    ['protocol', 'protocol', :string, 'protocol', %w[ssr], nil],
    ['obfs_param', 'obfs-param', :string, 'obfs-param', nil, nil],
    ['protocol_param', 'protocol-param', :string, 'protocol-param', nil, nil],
    ['uuid', 'uuid', :string, 'uuid', %w[vmess vless], nil, :bare],
    ['uuid', 'uuid', :string, 'uuid', %w[tuic], nil],
    ['alterId', 'alterId', :string, 'alterId', nil, nil, :bare],
    ['xudp', 'xudp', :string, 'xudp', nil, nil, :bare],
    ['packet_encoding', 'packet-encoding', :string, 'packet-encoding', nil, nil],
    ['global_padding', 'global-padding', :string, 'global-padding', nil, nil, :bare],
    ['authenticated_length', 'authenticated-length', :string, 'authenticated-length', nil, nil, :bare],
    ['tls', 'tls', :string, 'tls', %w[vmess vless socks5 http gost-relay], nil, :bare],
    ['skip_cert_verify', 'skip-cert-verify', :string, 'skip-cert-verify', %w[vmess vless trojan socks5 http hysteria hysteria2 anytls tuic trusttunnel masque gost-relay], nil, :bare],
    ['servername', 'servername', :string, 'servername', %w[vmess], nil, nil, 'tls=true'],
    ['servername', 'servername', :string, 'servername', %w[vless], nil],
    ['fingerprint', 'fingerprint', :string, 'fingerprint', %w[anytls gost-relay http hysteria hysteria2 socks5 trojan trusttunnel tuic vless vmess], nil],
    ['client_fingerprint', 'client-fingerprint', :string, 'client-fingerprint', nil, nil, nil, 'client_fingerprint!=none'],
    ['obfs_vmess', 'network', :mapped, 'network', %w[vmess], {'ws' => 'websocket', 'http' => 'http', 'h2' => 'h2', 'grpc' => 'grpc', 'mkcp' => 'mkcp', 'mekya' => 'mekya'}, nil],
    ['ws_path', 'ws-opts.path', :string, 'ws-opts.path', nil, nil],
    ['ws_headers', 'ws-opts.headers', :headers, 'ws-opts.headers', nil, nil],
    ['max_early_data', 'ws-opts.max-early-data', :string, 'network=ws', nil, nil, :bare],
    ['early_data_header_name', 'ws-opts.early-data-header-name', :string, 'network=ws', nil, nil],
    # the vmess http block carries a fixed method and the keep-alive marker, node_text writes it
    ['http_path', 'http-opts.path', :list, 'http-opts.path', %w[vmess], nil, :none],
    ['keep_alive', nil, :fixed, 'http-opts', nil, 'true'],
    ['h2_host', 'h2-opts.host', :list, 'h2-opts.host', %w[vmess], nil],
    ['h2_path', 'h2-opts.path', :string, 'h2-opts.path', %w[vmess], nil],
    ['grpc_service_name', 'grpc-opts.grpc-service-name', :string, 'grpc-opts', nil, nil],
    ['mkcp_mtu', 'mkcp-opts.mtu', :string, 'mkcp-opts.mtu', %w[vmess], nil, :bare],
    ['mkcp_tti', 'mkcp-opts.tti', :string, 'mkcp-opts.tti', %w[vmess], nil, :bare],
    ['mkcp_uplink_capacity', 'mkcp-opts.uplink-capacity', :string, 'mkcp-opts.uplink-capacity', %w[vmess], nil, :bare],
    ['mkcp_downlink_capacity', 'mkcp-opts.downlink-capacity', :string, 'mkcp-opts.downlink-capacity', %w[vmess], nil, :bare],
    ['mkcp_congestion', 'mkcp-opts.congestion', :string, 'mkcp-opts.congestion', %w[vmess], nil, :bare],
    ['mkcp_write_buffer', 'mkcp-opts.write-buffer', :string, 'mkcp-opts.write-buffer', %w[vmess], nil, :bare],
    ['mkcp_read_buffer', 'mkcp-opts.read-buffer', :string, 'mkcp-opts.read-buffer', %w[vmess], nil, :bare],
    ['mkcp_seed', 'mkcp-opts.seed', :string, 'mkcp-opts.seed', %w[vmess], nil],
    ['mkcp_header', 'mkcp-opts.header', :string, 'mkcp-opts.header', %w[vmess], nil],
    # the kcp block of mekya-opts is a nested structure of its own, it stays in the free form field
    ['mekya_url', 'mekya-opts.url', :string, 'mekya-opts.url', %w[vmess], nil],
    ['mekya_h2_pool_size', 'mekya-opts.h2-pool-size', :string, 'mekya-opts.h2-pool-size', %w[vmess], nil, :bare],
    ['mekya_max_write_delay', 'mekya-opts.max-write-delay', :string, 'mekya-opts.max-write-delay', %w[vmess], nil, :bare],
    ['mekya_max_request_size', 'mekya-opts.max-request-size', :string, 'mekya-opts.max-request-size', %w[vmess], nil, :bare],
    ['mekya_polling_interval_initial', 'mekya-opts.polling-interval-initial', :string, 'mekya-opts.polling-interval-initial', %w[vmess], nil, :bare],
    ['mekya_max_write_size', 'mekya-opts.max-write-size', :string, 'mekya-opts.max-write-size', %w[vmess], nil, :bare],
    ['mekya_max_write_duration_ms', 'mekya-opts.max-write-duration-ms', :string, 'mekya-opts.max-write-duration-ms', %w[vmess], nil, :bare],
    ['mekya_max_simultaneous_write_connection', 'mekya-opts.max-simultaneous-write-connection', :string, 'mekya-opts.max-simultaneous-write-connection', %w[vmess], nil, :bare],
    ['mekya_packet_writing_buffer', 'mekya-opts.packet-writing-buffer', :string, 'mekya-opts.packet-writing-buffer', %w[vmess], nil, :bare],
    ['mekya_kcp_mtu', 'mekya-opts.kcp.mtu', :string, 'mekya-opts.kcp.mtu', %w[vmess], nil, :bare],
    ['mekya_kcp_tti', 'mekya-opts.kcp.tti', :string, 'mekya-opts.kcp.tti', %w[vmess], nil, :bare],
    ['mekya_kcp_uplink_capacity', 'mekya-opts.kcp.uplink-capacity', :string, 'mekya-opts.kcp.uplink-capacity', %w[vmess], nil, :bare],
    ['mekya_kcp_downlink_capacity', 'mekya-opts.kcp.downlink-capacity', :string, 'mekya-opts.kcp.downlink-capacity', %w[vmess], nil, :bare],
    ['mekya_kcp_congestion', 'mekya-opts.kcp.congestion', :string, 'mekya-opts.kcp.congestion', %w[vmess], nil, :bare],
    ['mekya_kcp_write_buffer', 'mekya-opts.kcp.write-buffer', :string, 'mekya-opts.kcp.write-buffer', %w[vmess], nil, :bare],
    ['mekya_kcp_read_buffer', 'mekya-opts.kcp.read-buffer', :string, 'mekya-opts.kcp.read-buffer', %w[vmess], nil, :bare],
    ['mekya_kcp_seed', 'mekya-opts.kcp.seed', :string, 'mekya-opts.kcp.seed', %w[vmess], nil],
    ['mekya_kcp_header', 'mekya-opts.kcp.header', :string, 'mekya-opts.kcp.header', %w[vmess], nil],
    # tlsmirror keeps its time, padding and enrolment structures in the free form field
    ['tlsmirror_primary_key', 'tlsmirror-opts.primary-key', :string, 'tlsmirror-opts.primary-key', %w[vmess], nil],
    ['tlsmirror_sequence_watermarking', 'tlsmirror-opts.sequence-watermarking-enabled', :string, 'tlsmirror-opts.sequence-watermarking-enabled', %w[vmess], nil, :bare],
    ['tlsmirror_explicit_nonce_ciphersuites', 'tlsmirror-opts.explicit-nonce-ciphersuites', :list, 'tlsmirror-opts.explicit-nonce-ciphersuites', %w[vmess], nil],
    ['port_range', 'port-range', :string, 'port-range', %w[mieru], nil],
    ['username', 'username', :string, 'username', nil, nil],
    ['transport', 'transport', :string, 'transport', %w[mieru], nil, :none],
    ['multiplexing', 'multiplexing', :string, 'multiplexing', %w[mieru], nil, :none],
    ['password', 'password', :string, 'password', nil, nil],
    ['idle_session_check_interval', 'idle-session-check-interval', :string, 'idle-session-check-interval', nil, nil, :bare],
    ['idle_session_timeout', 'idle-session-timeout', :string, 'idle-session-timeout', nil, nil, :bare],
    ['min_idle_session', 'min-idle-session', :string, 'min-idle-session', nil, nil, :bare],
    ['alpn', 'alpn', :list, 'alpn', nil, nil],
    ['sni', 'sni', :string, 'sni', %w[anytls gost-relay http hysteria hysteria2 masque shadowquic trojan trusttunnel tuic], nil],
    ['token', 'token', :string, 'token', %w[tuic], nil],
    ['heartbeat_interval', 'heartbeat-interval', :string, 'heartbeat-interval', nil, nil, :bare],
    ['disable_sni', 'disable-sni', :string, 'disable-sni', nil, nil, :bare],
    ['reduce_rtt', 'reduce-rtt', :string, 'reduce-rtt', nil, nil, :bare],
    ['fast_open', 'fast-open', :string, 'fast-open', nil, nil, :bare],
    ['request_timeout', 'request-timeout', :string, 'request-timeout', nil, nil, :bare],
    ['udp_relay_mode', 'udp-relay-mode', :string, 'udp-relay-mode', nil, nil],
    ['congestion_controller', 'congestion-controller', :string, 'congestion-controller', nil, nil],
    ['max_udp_relay_packet_size', 'max-udp-relay-packet-size', :string, 'max-udp-relay-packet-size', nil, nil, :bare],
    ['max_open_streams', 'max-open-streams', :string, 'max-open-streams', nil, nil, :bare],
    ['ip', 'ip', :string, 'ip', %w[tuic wireguard masque], nil],
    ['ipv6', 'ipv6', :string, 'ipv6', %w[wireguard masque], nil],
    ['private_key', 'private-key', :string, 'private-key', %w[wireguard masque ssh gost-relay anytls http hysteria hysteria2 socks5 trojan trusttunnel tuic vless vmess], nil],
    ['public_key', 'public-key', :string, 'public-key', %w[wireguard masque], nil],
    ['preshared_key', 'preshared-key', :string, 'preshared-key', nil, nil],
    ['mtu', 'mtu', :string, 'mtu', %w[wireguard], nil, :bare],
    ['mtu', 'mtu', :string, 'mtu', %w[masque], nil, :bare],
    ['mtu', 'mtu', :string, 'mtu', %w[zerotier openvpn], nil, :bare],
    ['dns', 'dns', :list, 'dns', %w[wireguard masque zerotier openvpn], nil],
    ['hysteria_protocol', 'protocol', :string, 'protocol', %w[hysteria], nil, :bare],
    ['hysteria_up', 'up', :string, 'up', %w[hysteria hysteria2 shadowquic], nil],
    ['hysteria_down', 'down', :string, 'down', %w[hysteria hysteria2 shadowquic], nil],
    ['recv_window_conn', 'recv-window-conn', :string, 'recv-window-conn', nil, nil],
    ['recv_window', 'recv-window', :string, 'recv-window', nil, nil],
    ['initial_stream_receive_window', 'initial-stream-receive-window', :string, 'initial-stream-receive-window', nil, nil],
    ['max_stream_receive_window', 'max-stream-receive-window', :string, 'max-stream-receive-window', nil, nil],
    ['initial_connection_receive_window', 'initial-connection-receive-window', :string, 'initial-connection-receive-window', nil, nil],
    ['max_connection_receive_window', 'max-connection-receive-window', :string, 'max-connection-receive-window', nil, nil],
    ['hysteria_obfs', 'obfs', :string, 'obfs', %w[hysteria hysteria2], nil],
    ['obfs_password', 'obfs-password', :string, 'obfs-password', %w[hysteria2], nil],
    ['hysteria_auth', 'auth', :string, 'auth', %w[hysteria], nil],
    ['hysteria_auth_str', 'auth-str', :string, 'auth-str', %w[hysteria], nil],
    ['disable_mtu_discovery', 'disable-mtu-discovery', :string, 'disable-mtu-discovery', nil, nil, :bare],
    ['ports', 'ports', :string, 'ports', nil, nil, :bare],
    ['hop_interval', 'hop-interval', :string, 'hop-interval', nil, nil, :bare],
    ['vless_flow', 'flow', :string, 'flow', %w[vless], nil, nil, 'obfs_vless=tcp'],
    ['obfs_vless', 'network', :mapped, 'network', %w[vless], {'ws' => 'ws', 'grpc' => 'grpc', 'tcp' => 'tcp', 'xhttp' => 'xhttp', 'http' => 'http', 'h2' => 'h2'}, nil],
    ['reality_public_key', 'reality-opts.public-key', :string, 'reality-opts', nil, nil],
    ['reality_short_id', 'reality-opts.short-id', :string, 'reality-opts', nil, nil],
    ['vless_encryption', 'encryption', :string, 'encryption', %w[vless], nil, nil, 'obfs_vless=tcp'],
    ['xhttp_opts_path', 'xhttp-opts.path', :string, 'xhttp-opts', nil, nil],
    ['xhttp_opts_host', 'xhttp-opts.host', :string, 'xhttp-opts', nil, nil],
    ['vless_http_method', 'http-opts.method', :string, 'http-opts.method', %w[vless], nil],
    ['vless_http_path', 'http-opts.path', :list, 'http-opts.path', %w[vless], nil],
    ['vless_http_headers', 'http-opts.headers', :header_lists, 'http-opts.headers', %w[vless], nil],
    ['vless_h2_host', 'h2-opts.host', :list, 'h2-opts.host', %w[vless], nil],
    ['vless_h2_path', 'h2-opts.path', :string, 'h2-opts.path', %w[vless], nil],
    ['packet_addr', 'packet-addr', :string, 'packet-addr', %w[vmess vless], nil, :bare],
    ['obfs_snell', 'obfs-opts.mode', :string, 'obfs-opts', %w[snell], nil],
    ['host', 'obfs-opts.host', :string, 'obfs-opts', %w[snell], nil],
    ['psk', 'psk', :string, 'psk', nil, nil, :bare],
    ['snell_version', 'version', :string, 'version', %w[snell], nil, :bare],
    ['private_key_passphrase', 'private-key-passphrase', :string, 'private-key-passphrase', nil, nil],
    ['host_key_algorithms', 'host-key-algorithms', :list, 'host-key-algorithms', nil, nil],
    ['host_key', 'host-key', :list, 'host-key', nil, nil],
    ['http_headers', 'headers', :headers, 'headers', %w[http], nil, :none],
    ['obfs_trojan', 'grpc-opts', :fixed, 'grpc-opts', %w[trojan], 'grpc'],
    ['obfs_trojan', 'ws-opts', :fixed, 'ws-opts', %w[trojan], 'ws'],
    ['obfs_trojan', 'network', :mapped, 'network', %w[trojan], {'tcp' => 'tcp', 'ws' => 'ws', 'grpc' => 'grpc'}, nil],
    ['trojan_ss_enabled', 'ss-opts.enabled', :string, 'ss-opts.enabled', %w[trojan], nil, :bare],
    ['trojan_ss_method', 'ss-opts.method', :string, 'ss-opts.method', %w[trojan], nil],
    ['trojan_ss_password', 'ss-opts.password', :string, 'ss-opts.password', %w[trojan], nil],
    ['sudoku_key', 'key', :string, 'key', %w[sudoku], nil],
    ['aead_method', 'aead-method', :string, 'aead-method', nil, nil, :bare],
    ['padding_min', 'padding-min', :string, 'padding-min', nil, nil, :bare],
    ['padding_max', 'padding-max', :string, 'padding-max', nil, nil, :bare],
    ['table_type', 'table-type', :string, 'table-type', nil, nil, :bare],
    ['http_mask', 'http-mask', :string, 'http-mask', nil, nil, :bare],
    ['sudoku_enable_pure_downlink', 'enable-pure-downlink', :string, 'enable-pure-downlink', %w[sudoku], nil, :bare],
    ['sudoku_http_mask_mode', 'http-mask-mode', :string, 'http-mask-mode', %w[sudoku], nil],
    ['sudoku_http_mask_tls', 'http-mask-tls', :string, 'http-mask-tls', %w[sudoku], nil, :bare],
    ['sudoku_http_mask_host', 'http-mask-host', :string, 'http-mask-host', %w[sudoku], nil],
    ['sudoku_multiplex', 'multiplex', :bool_string, 'multiplex', %w[sudoku], nil],
    ['sudoku_http_mask_multiplex', 'http-mask-multiplex', :bool_string, 'http-mask-multiplex', %w[sudoku], nil],
    ['sudoku_path_root', 'path-root', :string, 'path-root', %w[sudoku], nil],
    ['sudoku_custom_table', 'custom-table', :string, 'custom-table', %w[sudoku], nil],
    ['sudoku_custom_tables', 'custom-tables', :list, 'custom-tables', %w[sudoku], nil],
    ['masque_network', 'network', :string, 'network', %w[masque], nil],
    ['remote_dns_resolve', 'remote-dns-resolve', :string, 'remote-dns-resolve', %w[masque zerotier openvpn wireguard], nil, :bare],
    ['trusttunnel_health_check', 'health-check', :string, 'health-check', %w[trusttunnel], nil, :bare],
    ['trusttunnel_quic', 'quic', :string, 'quic', %w[trusttunnel], nil, :bare],
    ['trusttunnel_congestion_controller', 'congestion-controller', :string, 'congestion-controller', %w[trusttunnel], nil],
    ['bbr_profile', 'bbr-profile', :string, 'bbr-profile', nil, nil],
    ['anytls_client_metadata', 'client-metadata', :string, 'client-metadata', nil, nil],
    ['handshake_timeout', 'handshake-timeout', :string, 'handshake-timeout', nil, nil, :bare],
    ['ip_stack', 'ip-stack', :string, 'ip-stack', %w[wireguard masque zerotier openvpn], nil],
    ['name_cert_verify', 'name-cert-verify', :string, 'name-cert-verify', nil, nil],
    ['hysteria_obfs_max_packet_size', 'obfs-max-packet-size', :string, 'obfs-max-packet-size', nil, nil, :bare],
    ['refresh_server_ip_interval', 'refresh-server-ip-interval', :string, 'refresh-server-ip-interval', %w[wireguard], nil, :bare],
    ['snell_reuse', 'reuse', :string, 'reuse', nil, nil, :bare],
    ['mieru_traffic_pattern', 'traffic-pattern', :string, 'traffic-pattern', nil, nil],
    ['udp_over_stream_version', 'udp-over-stream-version', :string, 'udp-over-stream-version', nil, nil, :bare],
    ['udp_over_tcp_version', 'udp-over-tcp-version', :string, 'udp-over-tcp-version', nil, nil, :bare],
    ['anytls_disable_reuse', 'disable-reuse', :string, 'disable-reuse', %w[anytls], nil, :bare],
    ['hysteria_up_speed', 'up-speed', :string, 'up-speed', %w[hysteria], nil, :bare],
    ['hysteria_down_speed', 'down-speed', :string, 'down-speed', %w[hysteria], nil, :bare],
    ['hysteria_obfs_protocol', 'obfs-protocol', :string, 'obfs-protocol', %w[hysteria], nil],
    ['hysteria_obfs_min_packet_size', 'obfs-min-packet-size', :string, 'obfs-min-packet-size', %w[hysteria2], nil, :bare],
    ['mieru_handshake_mode', 'handshake-mode', :string, 'handshake-mode', %w[mieru], nil],
    ['persistent_keepalive', 'persistent-keepalive', :string, 'persistent-keepalive', %w[wireguard], nil, :bare],
    ['workers', 'workers', :string, 'workers', %w[wireguard], nil, :bare],
    # the amnezia option of wireguard is a flat block of numbers, the peer list of a node
    # (a list of maps) stays in the free form field of the page
    ['amnezia_version', 'amnezia-wg-option.version', :string, 'amnezia-wg-option.version', %w[wireguard], nil, :bare],
    ['amnezia_jc', 'amnezia-wg-option.jc', :string, 'amnezia-wg-option.jc', %w[wireguard], nil, :bare],
    ['amnezia_jmin', 'amnezia-wg-option.jmin', :string, 'amnezia-wg-option.jmin', %w[wireguard], nil, :bare],
    ['amnezia_jmax', 'amnezia-wg-option.jmax', :string, 'amnezia-wg-option.jmax', %w[wireguard], nil, :bare],
    ['amnezia_s1', 'amnezia-wg-option.s1', :string, 'amnezia-wg-option.s1', %w[wireguard], nil, :bare],
    ['amnezia_s2', 'amnezia-wg-option.s2', :string, 'amnezia-wg-option.s2', %w[wireguard], nil, :bare],
    ['amnezia_s3', 'amnezia-wg-option.s3', :string, 'amnezia-wg-option.s3', %w[wireguard], nil, :bare],
    ['amnezia_s4', 'amnezia-wg-option.s4', :string, 'amnezia-wg-option.s4', %w[wireguard], nil, :bare],
    ['amnezia_h1', 'amnezia-wg-option.h1', :string, 'amnezia-wg-option.h1', %w[wireguard], nil, :bare],
    ['amnezia_h2', 'amnezia-wg-option.h2', :string, 'amnezia-wg-option.h2', %w[wireguard], nil, :bare],
    ['amnezia_h3', 'amnezia-wg-option.h3', :string, 'amnezia-wg-option.h3', %w[wireguard], nil, :bare],
    ['amnezia_h4', 'amnezia-wg-option.h4', :string, 'amnezia-wg-option.h4', %w[wireguard], nil, :bare],
    ['udp_mtu', 'udp-mtu', :string, 'udp-mtu', %w[hysteria2], nil, :bare],
    ['cwnd', 'cwnd', :string, 'cwnd', %w[hysteria2 masque trusttunnel tuic shadowquic], nil, :bare],
    ['max_datagram_frame_size', 'max-datagram-frame-size', :string, 'max-datagram-frame-size', %w[tuic shadowquic], nil, :bare],
    ['udp_over_stream', 'udp-over-stream', :string, 'udp-over-stream', %w[tuic shadowquic], nil, :bare],
    ['uri', 'uri', :string, 'uri', %w[masque], nil],
    ['reality_support_x25519mlkem768', 'reality-opts.support-x25519mlkem768', :string, 'reality-opts', %w[vless], nil],
    ['ws_opts_v2ray_http_upgrade', 'ws-opts.v2ray-http-upgrade', :string, 'ws-opts', nil, nil, :bare],
    ['ws_opts_v2ray_http_upgrade_fast_open', 'ws-opts.v2ray-http-upgrade-fast-open', :string, 'ws-opts', nil, nil, :bare],
    # The option struct tags of the outbound types the shell version did not support.
    ['hostname', 'hostname', :string, 'hostname', %w[tailscale], nil],
    ['auth_key', 'auth-key', :string, 'auth-key', %w[tailscale], nil],
    ['control_url', 'control-url', :string, 'control-url', %w[tailscale], nil],
    ['state_dir', 'state-dir', :string, 'state-dir', %w[tailscale zerotier], nil],
    ['ephemeral', 'ephemeral', :string, 'ephemeral', %w[tailscale], nil, :bare],
    ['accept_routes', 'accept-routes', :string, 'accept-routes', %w[tailscale], nil, :bare],
    ['exit_node', 'exit-node', :string, 'exit-node', %w[tailscale], nil],
    ['exit_node_allow_lan_access', 'exit-node-allow-lan-access', :string, 'exit-node-allow-lan-access', %w[tailscale], nil, :bare],
    ['network', 'network', :string, 'network', %w[zerotier], nil],
    ['planet', 'planet', :string, 'planet', %w[zerotier], nil],
    ['physical_mtu', 'physical-mtu', :string, 'physical-mtu', %w[zerotier], nil, :bare],
    ['low_bandwidth', 'low-bandwidth', :string, 'low-bandwidth', %w[zerotier], nil, :bare],
    ['encrypted_hello', 'encrypted-hello', :string, 'encrypted-hello', %w[zerotier], nil, :bare],
    ['primary_port', 'primary-port', :string, 'primary-port', %w[zerotier], nil, :bare],
    ['secondary_port', 'secondary-port', :string, 'secondary-port', %w[zerotier], nil, :bare],
    ['tcp_fallback_mode', 'tcp-fallback-mode', :string, 'tcp-fallback-mode', %w[zerotier], nil],
    ['tcp_fallback_relay', 'tcp-fallback-relay', :string, 'tcp-fallback-relay', %w[zerotier], nil],
    ['remote_trace_target', 'remote-trace-target', :string, 'remote-trace-target', %w[zerotier], nil],
    ['remote_trace_level', 'remote-trace-level', :string, 'remote-trace-level', %w[zerotier], nil, :bare],
    ['proto', 'proto', :string, 'proto', %w[openvpn], nil],
    ['dev', 'dev', :string, 'dev', %w[openvpn], nil],
    ['data_ciphers', 'data-ciphers', :list, 'data-ciphers', %w[openvpn], nil],
    ['data_ciphers_fallback', 'data-ciphers-fallback', :string, 'data-ciphers-fallback', %w[openvpn], nil],
    ['auth', 'auth', :string, 'auth', %w[openvpn], nil],
    ['comp_lzo', 'comp-lzo', :string, 'comp-lzo', %w[openvpn], nil],
    ['ca', 'ca', :string, 'ca', %w[openvpn], nil],
    ['cert', 'cert', :string, 'cert', %w[openvpn], nil],
    ['key', 'key', :string, 'key', %w[openvpn], nil],
    ['tls_auth', 'tls-auth', :string, 'tls-auth', %w[openvpn], nil],
    ['key_direction', 'key-direction', :string, 'key-direction', %w[openvpn], nil],
    ['tls_crypt', 'tls-crypt', :string, 'tls-crypt', %w[openvpn], nil],
    ['tls_crypt_v2', 'tls-crypt-v2', :string, 'tls-crypt-v2', %w[openvpn], nil],
    ['peer_info', 'peer-info', :headers, 'peer-info', %w[openvpn], nil],
    ['ping', 'ping', :string, 'ping', %w[openvpn], nil, :bare],
    ['ping_restart', 'ping-restart', :string, 'ping-restart', %w[openvpn], nil, :bare],
    ['tran_window', 'tran-window', :string, 'tran-window', %w[openvpn], nil, :bare],
    ['quic_versions', 'quic-versions', :list, 'quic-versions', %w[shadowquic], nil],
    ['zero_rtt', 'zero-rtt', :string, 'zero-rtt', %w[shadowquic], nil, :bare],
    ['keep_alive_interval', 'keep-alive-interval', :string, 'keep-alive-interval', %w[shadowquic], nil, :bare],
    ['forward', 'forward', :string, 'forward', %w[gost-relay], nil, :bare],
    ['mux', 'mux', :string, 'mux', %w[gost-relay], nil, :bare],
    ['reserved', 'reserved', :list, 'reserved', %w[wireguard], nil],
    ['trusttunnel_max_connections', 'max-connections', :string, 'max-connections', %w[trusttunnel], nil, :bare],
    ['trusttunnel_min_streams', 'min-streams', :string, 'min-streams', %w[trusttunnel], nil, :bare],
    ['trusttunnel_max_streams', 'max-streams', :string, 'max-streams', %w[trusttunnel], nil, :bare],
    ['certificate', 'certificate', :string, 'certificate', %w[gost-relay anytls http hysteria hysteria2 socks5 trojan trusttunnel tuic vless vmess], nil],
  ].freeze

  # Value behind a key path, nil as soon as a part of the path is missing
  def path_value(source, path)
    path.to_s.split('.').each do |key|
      return nil unless source.is_a?(Hash) && source.key?(key)
      source = source[key]
    end
    source
  end

  def path_present?(source, path)
    !path_value(source, path).nil?
  end

  # uci lines of every row that applies to `source`
  def field_lines(source, fields)
    lines = []
    fields.each do |option, path, kind, guard, types, fixed|
      next if types && !types.include?(source['type'].to_s)
      # a guard is either the path that has to be present or "key=value"
      if guard
        key, wanted = guard.split('=', 2)
        value_of_key = path_value(source, key)
        next if wanted.nil? ? value_of_key.nil? : value_of_key.to_s != wanted
      end
      value = path_value(source, path)
      # a key that the configuration does not have is not written at all, the shell version
      # only emitted a line inside `if x.key?('key')`
      next if value.nil? && kind != :fixed
      case kind
      when :fixed
        lines << "\toption #{option} '#{fixed}'"
      when :mapped
        mapped = fixed[value.to_s]
        lines << "\toption #{option} '#{mapped}'" if mapped
      when :bool_string
        lines << "\toption #{option} '#{value == true ? 'on' : (value == false ? 'off' : value)}'"
      when :bare
        lines << "\toption #{option} #{value}"
      when :list
        (value.is_a?(Array) ? value : [value]).each { |item| lines << "\tlist #{option} '#{item}'" }
      when :header_lists
        (value.is_a?(Hash) ? value : {}).each do |key, items|
          Array(items).each { |item| lines << "\tlist #{option} '#{key}: #{item}'" }
        end
      when :headers
        value.each { |key, item| lines << "\tlist #{option} '#{key}: #{item}'" }
      else
        lines << "\toption #{option} '#{value}'"
      end
    end
    lines
  end

  # `    key: value` lines of one node, written from the same table the get direction reads.
  # A row belongs to the set direction when it is no :fixed row, no :none row (the block is
  # built by node_text or the group writer) and no :mapped row without a mapping for its
  # value. set_kind overrides kind, set_guard is a `key=value`, `key!=value` or `key` guard.
  def set_lines(section, type)
    lines = []
    blocks = {}
    GET_NODE_FIELDS.each do |option, path, kind, guard, types, fixed, set_kind, set_guard|
      next if kind == :fixed || set_kind == :none
      next if path.nil? || path.empty?
      next if types && !types.include?(type)
      next unless set_guard_match?(section, set_guard)
      value = opt(section, option)
      if kind == :mapped
        value = mapped_yaml_value(fixed, value).to_s
      end
      next if value.empty?

      if path.include?('.')
        parent, sub = path.split('.', 2)
        (blocks[parent] ||= []) << [sub, set_kind || kind, value, option]
        next
      end

      case set_kind || kind
      when :bare
        lines << "    #{path}: #{value}\n"
      when :list
        lines << "    #{path}:\n"
        each_item(section, option).each { |item| lines << "      - '#{item}'\n" }
      when :headers
        lines << "    #{path}:\n"
        each_item(section, option).each do |item|
          key, item_value = item.split(':', 2)
          lines << "      #{key.strip}: \"#{escape_yaml(item_value.to_s.strip)}\"\n"
        end
      else
        lines << "    #{path}: \"#{escape_yaml(value)}\"\n"
      end
    end
    lines.concat(nested_block_lines(section, type, blocks))
    lines
  end

  # `    parent:\n      sub: value` lines of the blocks the rows above belong to. A block is
  # left out when the node does not use its transport (SET_BLOCK_GUARDS), so an option of
  # another transport cannot revive it. Sub keys share the tree of their parent.
  def nested_block_lines(section, type, blocks)
    lines = []
    blocks.each do |parent, entries|
      next unless block_allowed?(section, type, parent)
      body = []
      render_nested(section, body, nested_tree(entries), 6)
      next if body.empty?
      lines << "    #{parent}:\n"
      lines.concat(body)
    end
    lines
  end

  # `entries` is [[sub key, kind, value, option], ...], the tree groups the keys that share
  # a parent: {"kcp" => {"mtu" => [:leaf, :bare, "1350", "mekya_kcp_mtu"]}}
  def nested_tree(entries)
    tree = {}
    entries.each do |sub, kind, value, option|
      cursor = tree
      parts = sub.split('.')
      leaf = parts.pop
      parts.each { |part| cursor = (cursor[part] ||= {}) }
      cursor[leaf] = [:leaf, kind, value, option]
    end
    tree
  end

  def render_nested(section, body, tree, indent)
    pad = ' ' * indent
    tree.each do |key, node|
      if node.is_a?(Hash)
        body << "#{pad}#{key}:\n"
        render_nested(section, body, node, indent + 2)
      else
        render_nested_key(section, body, key, node[1], node[2], indent, node[3])
      end
    end
  end

  def render_nested_key(section, body, key, kind, value, indent, option)
    pad = ' ' * indent
    case kind
    when :list
      body << "#{pad}#{key}:\n"
      each_item(section, option).each { |item| body << (' ' * (indent + 2)) + "- '#{item}'\n" }
    when :headers
      body << "#{pad}#{key}:\n"
      each_item(section, option).each do |item|
        item_key, item_value = item.split(':', 2)
        body << (' ' * (indent + 2)) + "#{item_key.strip}: \"#{escape_yaml(item_value.to_s.strip)}\"\n"
      end
    when :header_lists
      grouped = {}
      each_item(section, option).each do |item|
        item_key, item_value = item.split(':', 2)
        next if item_key.nil? || item_value.nil?
        (grouped[item_key.strip] ||= []) << item_value.strip
      end
      body << "#{pad}#{key}:\n"
      grouped.each do |item_key, items|
        body << (' ' * (indent + 2)) + "#{item_key}:\n"
        items.each { |item| body << (' ' * (indent + 4)) + "- #{item}\n" }
      end
    when :bare
      body << "#{pad}#{key}: #{value}\n"
    else
      body << "#{pad}#{key}: \"#{escape_yaml(value)}\"\n"
    end
  end

  def block_allowed?(section, type, parent)
    # a block kept in `other_parameters` is not written from the rows, the text carries it as
    # a whole. A cleared text field lets the rows write the block again.
    if opt(section, 'other_blocks').split.include?(parent) &&
       opt(section, 'other_parameters').include?("#{parent}:")
      return false
    end
    guard = SET_BLOCK_GUARDS[parent]
    return true if guard.nil?
    wanted = guard[type] || guard['*']
    return true if wanted.nil?
    [wanted].flatten.all? { |item| set_guard_match?(section, item) }
  end

  # Body of a double quoted yaml scalar. uci keeps a backslash and the line breaks of a free
  # form value (a certificate) literally, yaml has to escape both.
  def escape_yaml(value)
    value.to_s.gsub(BACKSLASH, BACKSLASH + BACKSLASH).gsub('"', BACKSLASH + '"').gsub("\n", BACKSLASH + 'n')
  end

  def set_guard_match?(section, guard)
    return true if guard.nil?
    key, operator, wanted = guard.partition(/!=|=/)
    current = opt(section, key)
    case operator
    when '!=' then current != wanted
    when '=' then current == wanted
    else !current.empty?
    end
  end

  # A node or a provider is a member of every group that names it, the membership is
  # written on the member itself as one `list groups '^name$'` line
  def membership_lines(name, groups, key)
    lines = []
    groups.each do |group|
      next unless group.is_a?(Hash) && group['name'] && group[key].is_a?(Array)
      lines << "\tlist groups '^#{group['name']}$'" if group[key].include?(name)
    end
    lines
  end

  def provider_lines(name, provider, config_name, groups)
    type = provider['type'].to_s
    YAML.LOG("Start Getting【#{config_name} - #{type} - #{name}】Proxy-provider Setting...")
    lines = ["config proxy_providers", "\toption enabled '1'", "\toption manual '0'",
             "\toption config '#{config_name}'", "\toption name '#{name}'", "\toption type '#{type}'"]
    lines.concat(field_lines(provider, GET_PROVIDER_FIELDS))
    # an http provider keeps its file below the provider directory of the plugin
    lines << "\toption path '#{type == 'http' ? "./proxy_provider/#{name}.yaml" : provider['path']}'" if path_present?(provider, 'path')
    lines.concat(membership_lines(name, groups, 'use'))
    lines
  end

  def node_lines(node, config_name, groups)
    name = node['name']
    YAML.LOG("Start Getting【#{config_name} - #{node['type']} - #{name}】Proxy Setting...")
    lines = ["config proxies", "\toption enabled '1'", "\toption manual '0'",
             "\toption config '#{config_name}'", "\toption name '#{name}'"]
    lines.concat(field_lines(node, GET_NODE_FIELDS))
    lines.concat(other_parameters_lines(node))
    lines.concat(membership_lines(name, groups, 'proxies'))
    lines
  end

  def group_lines(group, config_name, names)
    name = group['name'].to_s
    type = group['type'].to_s
    YAML.LOG("Start Getting【#{config_name} - #{type} - #{name}】Group Setting...")
    lines = ["config proxy_groups", "\toption name '#{name}'", "\toption type '#{type}'",
             "\toption enabled '1'", "\toption config '#{config_name}'", "\toption old_name '#{name}'"]
    lines.concat(field_lines(group, GET_GROUP_FIELDS))
    members = group['proxies'].is_a?(Array) ? group['proxies'] : []
    members.each do |member|
      lines << "\tlist other_group '^#{member}$'" if names.include?(member)
    end
    lines
  end

  # Imports the proxy-groups block of `config_file` (yml_groups_get.sh)
  def import_groups(config_file, config_name)
    value = YAML.load_file(config_file)
    return { 'config' => 'Load Config File Failed' } unless value.is_a?(Hash)
    groups = value['proxy-groups'].is_a?(Array) ? value['proxy-groups'] : []
    names = (GROUP_GET_KEYWORDS + groups.map { |group| group['name'].to_s }).reject(&:empty?).uniq
    lines = []
    groups.each do |group|
      next unless group.is_a?(Hash) && group['name'] && group['type']
      lines.concat(group_lines(group, config_name, names))
    end
    replace_stream(config_name, lines.join("\n"), MAIN_TARGETS, true, ['proxy_groups'])
  end

  # Imports the proxies and proxy-providers blocks of `config_file` into the uci package.
  # Returns the failures of replace_stream, an empty hash on success.
  def import_config(config_file, config_name)
    value = YAML.load_file(config_file)
    return { 'config' => 'Load Config File Failed' } unless value.is_a?(Hash)
    providers = value['proxy-providers'].is_a?(Hash) ? value['proxy-providers'] : {}
    nodes = value['proxies'].is_a?(Array) ? value['proxies'] : []
    groups = value['proxy-groups'].is_a?(Array) ? value['proxy-groups'] : []
    lines = []
    providers.each do |name, provider|
      lines.concat(provider_lines(name.to_s, provider, config_name, groups)) if provider.is_a?(Hash) && provider['type']
    end
    nodes.each do |node|
      lines.concat(node_lines(node, config_name, groups)) if node.is_a?(Hash) && node['name'] && node['type']
    end
    replace_stream(config_name, lines.join("\n"), MAIN_TARGETS, false, ['proxies', 'proxy_providers'])
  end
end
