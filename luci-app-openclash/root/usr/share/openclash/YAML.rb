module YAML
	class << self
		alias_method :load, :unsafe_load if YAML.respond_to? :unsafe_load
		alias_method :original_dump, :dump
		alias_method :original_load_file, :load_file
	end

	def self.LOG(info)
		puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + " [Info] " + "#{info}"
	end

	def self.LOG_ERROR(info)
		puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + " [Error] " + "#{info}"
	end

	def self.LOG_WARN(info)
		puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + " [Warning] " + "#{info}"
	end

	def self.LOG_TIP(info)
		puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + " [Tip] " + "#{info}"
	end

	def self.load_file(filename, *args, **kwargs)
		secret = nil
		if kwargs.key?(:secret)
			secret = kwargs.delete(:secret)
		end

		header = File.binread(filename, 512).to_s

		if header.include?("BEGIN AGE ENCRYPTED FILE")
			yaml_content = File.read(filename, mode: "r:bom|utf-8")
			if secret && secret.to_s.strip != ""
				decrypted = decrypt_content_with_secret(secret.to_s, yaml_content)
				if decrypted && !decrypted.empty? && !decrypted.include?("BEGIN AGE ENCRYPTED FILE")
					return fix_and_load(decrypted, *args, **kwargs)
				else
					raise "Decrypted content empty or still encrypted: [#{filename}]"
				end
			end

			keys = find_age_keys_for_filename(filename)
			last_error = nil
			(keys[:secrets] || []).each do |sec|
				begin
					decrypted = decrypt_content_with_secret(sec, yaml_content)
					if decrypted && !decrypted.empty? && !decrypted.include?("BEGIN AGE ENCRYPTED FILE")
						return fix_and_load(decrypted, *args, **kwargs)
					end
				rescue => e
					last_error = e.message
				end
			end

			detail = last_error ? "#{last_error}" : ""
			raise "Encrypted file: decryption failed for [#{filename}]: [#{detail}]"
		end

		base64, short_id, protocol_param = File.open(filename, "r:bom|utf-8") do |io|
			scan_for_fixes(io)
		end

		if base64 || protocol_param
			fix_and_load(File.read(filename, mode: "r:bom|utf-8"), *args, **kwargs)
		elsif short_id
			fixed = File.open(filename, "r:bom|utf-8") { |io| fix_short_id_text(io) }
			begin
				load(fixed, *args, **kwargs)
			rescue => e
				raise "fix short-id values type failed: #{e.message}"
			end
		else
			result = File.open(filename, "r:bom|utf-8") do |io|
				load(io, *args, **kwargs)
			end
			if result.nil? || result == false
				result = fix_and_load(File.read(filename, mode: "r:bom|utf-8"), *args, **kwargs)
			end
			result
		end
	end

	# The pipeline loads the same large file repeatedly, cache it by mtime/size.
	def self.load_file_cached(filename, cache_file, *args, **kwargs)
		if File.exist?(cache_file)
			begin
				entry = Marshal.load(File.binread(cache_file))
				if entry.is_a?(Array) && entry.length == 3 &&
						entry[0] == File.mtime(filename).to_i && entry[1] == File.size(filename)
					return entry[2]
				end
			rescue ::Exception
				# ignore broken cache, parse the file again
			end
		end

		value = load_file(filename, *args, **kwargs)
		cache_write(filename, value, cache_file)
		value
	end

	def self.cache_write(filename, value, cache_file)
		begin
			File.open(cache_file, 'wb') do |file|
				Marshal.dump([File.mtime(filename).to_i, File.size(filename), value], file)
			end
		rescue ::Exception
			File.delete(cache_file) rescue nil
		end
	end

	def self.dump(obj, io = nil, **options)
		if obj.nil? || obj == false
			target = ""
			if io.is_a?(String)
				target = " [#{io}]"
			elsif io && io.respond_to?(:path)
				target = " [#{io.path}]"
			elsif options.key?(:filename)
				target = " [#{options[:filename]}]"
			end
			raise "YAML.dump: refusing to write nil/false config content#{target} (previous load may have failed)"
		end

		if io.is_a?(String)
			dump_to_path(obj, io, **options)
		else
			dump_to_io(obj, io, **options)
		end
	end

	def self.dump_to_io(obj, io = nil, **options)
		public_key = nil
		fname = nil
		if options.key?(:public)
			public_key = options.delete(:public)
		end

		if (!public_key || public_key.to_s.strip == "")
			if options.key?(:filename)
				fname = options.delete(:filename)
			elsif io && io.respond_to?(:path)
				fname = io.path
			elsif io && io.respond_to?(:to_path)
				fname = io.to_path
			end

			if fname && fname.to_s.strip != ""
				keys = find_age_keys_for_filename(fname)
				public_key = keys[:publics].first if keys[:publics] && !keys[:publics].empty?
			end
		end

		needs_fix = contains_short_id?(obj)

		if public_key && public_key.to_s.strip != ""
			yaml_content = original_dump(obj, **options)
			processed = needs_fix ? fix_short_id_quotes(yaml_content) : yaml_content
			begin
				encrypted = encrypt_content_with_public(public_key.to_s, processed)
				if encrypted && !encrypted.empty?
					if io.nil?
						return encrypted
					elsif io.respond_to?(:write)
						io.write(encrypted)
						return io
					else
						return encrypted
					end
				end
			rescue => e
				if io.respond_to?(:write)
					io.write(processed)
				end
				raise
			end
		end

		stream = options.empty? && StreamDump.supported?(obj)

		if io.respond_to?(:write)
			if stream
				StreamDump.new(io).dump(obj, short_id: needs_fix)
			elsif needs_fix
				fix_short_id_text(original_dump(obj, **options), io)
			else
				original_dump(obj, io, **options)
			end
			io
		elsif stream
			stream_dump_to_string(obj, needs_fix)
		else
			dump_string(obj, options, needs_fix)
		end
	end

	def self.stream_dump_to_string(obj, needs_fix)
		sink = StringSink.new
		StreamDump.new(sink).dump(obj, short_id: needs_fix)
		sink.string
	end

	def self.dump_string(obj, options, needs_fix)
		yaml_content = original_dump(obj, **options)
		needs_fix ? fix_short_id_quotes(yaml_content) : yaml_content
	end

	def self.dump_to_path(obj, path, **options)
		real = File.symlink?(path) ? File.realpath(path) : path
		dir = File.dirname(real)
		tmp = File.join(dir, ".#{File.basename(real)}.tmp#{Process.pid}.#{rand(1000)}")
		mode = File.exist?(real) ? File.stat(real).mode & 07777 : nil
		begin
			File.open(tmp, 'w') { |f| dump_to_io(obj, f, **options.merge(filename: real)) }
			File.chmod(mode, tmp) if mode
			File.rename(tmp, real)
		rescue ::Exception
			begin
				File.unlink(tmp) if File.exist?(tmp)
			rescue
			end
			raise
		end
		path
	end

	def self.popen_stream(cmd, input, chunk_size: 64 * 1024)
		output = String.new
		IO.popen(cmd, 'r+', err: [:child, :out]) do |io|
			io.binmode
			writer_error = nil
			writer = Thread.new do
				begin
					input.bytesize.times do |i|
						chunk = input.byteslice(i * chunk_size, chunk_size)
						break if chunk.nil?
						io.write(chunk)
					end
					io.close_write
				rescue Errno::EPIPE
					# child exited before reading all input, not an error
				rescue => e
					writer_error = e
				end
			end

			while chunk = io.read(chunk_size)
				output << chunk
			end
			writer.join
			raise writer_error if writer_error
		end
		[output, $?]
	end

	def self.decode64(input)
		first_line = input.each_line.find { |l| !l.strip.empty? } || ""
		return input if !first_line.strip.match?(/\A[A-Za-z0-9+\/=]+\z/)
		out, status = popen_stream(["base64", "-d"], input)
		status.success? ? out : input
	rescue Errno::ENOENT
		input
	end

	AGE_KEYS_UCI_CONFIG = "/etc/config/openclash"
	AGE_KEYS_SECTION = "config_age_secret".freeze

	# The file itself says whether a lookup is needed: the common case has no age key and must
	# not pay for a fork and a uci parse.
	def self.age_keys_enabled?
		File.read(AGE_KEYS_UCI_CONFIG).include?(AGE_KEYS_SECTION)
	rescue StandardError
		true
	end

	# One "uci show" dump resolves every name and both key types
	def self.age_keys
		@age_keys ||= begin
			keys = {}
			if age_keys_enabled?
				cmd = ["/bin/sh", "-c", ". /usr/share/openclash/uci.sh; uci_age_keys_dump"]
				IO.popen(cmd, "r") do |io|
					io.each_line do |line|
						tag, name, value = line.strip.split("\t", 3)
						next if name.nil? || value.nil? || value.strip == ""
						keys[name] ||= { publics: [], secrets: [] }
						(tag == "P" ? keys[name][:publics] : keys[name][:secrets]) << value.strip
					end
				end
			end
			keys
		rescue Errno::ENOENT
			{}
		end
	end

	def self.find_age_keys_for_filename(filename)
		keys = age_keys
		publics = []
		secrets = []

		[File.basename(filename), File.basename(filename, File.extname(filename))].uniq.each do |n|
			entry = keys[n]
			next if entry.nil?

			publics.concat(entry[:publics])
			secrets.concat(entry[:secrets])
		end
		{ publics: publics, secrets: secrets }
	end

	def self.decrypt_content_with_secret(secret, content)
		# Clear injection-detection env vars to prevent OIX GuardStartup from
		# killing the child process (e.g. LD_PRELOAD set by opkg upgrade)
		cmd = ['/etc/openclash/core/clash_meta', 'age', 'decrypt', secret, '-', '-']
		old_ld_preload = ENV.delete('LD_PRELOAD')
		old_ld_audit = ENV.delete('LD_AUDIT')
		old_dyld = ENV.delete('DYLD_INSERT_LIBRARIES')
		begin
			out, status = popen_stream(cmd, content)
			status.success? ? out : raise("age decrypt failed: #{out.to_s.strip}")
		rescue => e
			raise "age decrypt failed: #{e.message.strip}"
		ensure
			ENV['LD_PRELOAD'] = old_ld_preload if old_ld_preload
			ENV['LD_AUDIT'] = old_ld_audit if old_ld_audit
			ENV['DYLD_INSERT_LIBRARIES'] = old_dyld if old_dyld
		end
	end

	def self.encrypt_content_with_public(public, content)
		cmd = ['/etc/openclash/core/clash_meta', 'age', 'encrypt', public, '-', '-']
		old_ld_preload = ENV.delete('LD_PRELOAD')
		old_ld_audit = ENV.delete('LD_AUDIT')
		old_dyld = ENV.delete('DYLD_INSERT_LIBRARIES')
		begin
			out, status = popen_stream(cmd, content)
			status.success? ? out : raise("age encrypt failed: #{out.to_s.strip}")
		rescue => e
			raise "age encrypt failed: #{e.message.strip}"
		ensure
			ENV['LD_PRELOAD'] = old_ld_preload if old_ld_preload
			ENV['LD_AUDIT'] = old_ld_audit if old_ld_audit
			ENV['DYLD_INSERT_LIBRARIES'] = old_dyld if old_dyld
		end
	end

	private

	# fix_short_id_quotes:
	# Purpose: ensure YAML `short-id` values are emitted with the intended
	# representation when dumping or re-writing YAML files.
	# Behavior:
	# - Non-null, non-empty scalar `short-id` values (and items inside
	#   `short-id` sequences) are written as double-quoted strings.
	# - Empty strings are preserved as empty quoted strings ("" remains "").
	# - Null values are preserved and may be emitted explicitly (e.g. `! "").
	# Lastly, use gsub to clean up any `! ""` tags
	# Examples:
	#   Input:  short-id: 00000000    -> Output: short-id: "00000000"
	#   Input:  short-id: ""          -> Output: short-id: ""
	#   Input:  short-id: "abc123"    -> Output: short-id: "abc123"
	#   Input:  short-id: "1600e237"  -> Output: short-id: "1600e237"
	#   Input:  short-id: null        -> Output: short-id: ""

	def self.fix_and_load(yaml_content, *args, **kwargs)
		yaml_content = decode64(yaml_content)
		# Fix bare protocol-param values that break YAML parsing (e.g. "1.2.3.4:8080#test")
		yaml_content.gsub!(/^(\s*protocol-param:\s+)([^\s"'][^"\n\r]*[#:][^"\n\r]*)$/, '\1"\2"')
		return load(yaml_content, *args, **kwargs) unless yaml_content.include?('short-id:')

		begin
			load(fix_short_id_text(yaml_content), *args, **kwargs)
		rescue => e
			raise "fix short-id values type failed: #{e.message}"
		end
	end

	def self.quote_short_id_scalar(value)
		v = value.strip
		return value if v.empty?
		return '""' if v =~ /\A(?:~|null|NULL|Null)\z/
		if v.start_with?("'")
			if (m = v.match(/\A'((?:[^']|'')*)'(\s+#.*)?\z/))
				inner = m[1].gsub("''", "'")
				return "\"#{inner.gsub(/["\\]/) { |c| "\\#{c}" }}\"#{m[2]}"
			end
			return value
		end
		return value if v.start_with?('"')
		return value if v =~ /[:{}\[\],|>]/
		if (m = v.match(/\A(\S+)(\s+#.*)?\z/))
			"\"#{m[1].gsub('"', '\\"')}\"#{m[2]}"
		else
			"\"#{v.gsub('"', '\\"')}\""
		end
	end

	def self.fix_short_id_text(yaml_content, output = nil)
		out = output || String.new
		in_seq = false
		seq_indent = -1
		in_block = false
		block_indent = -1
		pending = nil

		yaml_content.each_line do |line|
			if in_block
				if line.strip.empty? || (line =~ /^(\s*)/ && Regexp.last_match(1).length > block_indent)
					out << line
					next
				else
					in_block = false
				end
			end

			if pending
				if (m = line.match(/^(\s*)-(\s*)(.*?)(\r?\n)?\z/)) && m[1].length >= seq_indent
					out << pending
					in_seq = true
				else
					out << pending.sub(/^(\s*)short-id:.*?(\r?\n)?\z/, '\1short-id: ""\2')
					in_seq = false
				end
				pending = nil
			end

			if (m = line.match(/^(\s*)short-id:(\s*)(.*?)(\r?\n)?\z/))
				indent = m[1]
				rest = m[3].to_s.strip
				if rest.empty? || rest.start_with?('#')
					in_seq = true
					seq_indent = indent.length
					pending = line
				else
					in_seq = false
					out << indent + "short-id:" + m[2] + quote_short_id_scalar(rest) + m[4].to_s
				end
			elsif (m = line.match(/^(\s*)[^:\s][^:]*:\s*[|>](\s*.*)?$/))
				in_block = true
				in_seq = false
				block_indent = m[1].length
				out << line
			elsif line.strip.empty?
				out << line
			elsif in_seq && (m = line.match(/^(\s*)-(\s*)(.*?)(\r?\n)?\z/)) && m[1].length >= seq_indent
				out << m[1] + "-" + m[2] + quote_short_id_scalar(m[3]) + m[4].to_s
			else
				in_seq = false
				out << line
			end
		end

		if pending
			out << pending.sub(/^(\s*)short-id:.*?(\r?\n)?\z/, '\1short-id: ""\2')
		end

		out
	end

	def self.fix_short_id_quotes(yaml_content)
		begin
			fix_short_id_text(yaml_content)
		rescue => e
			raise "fix short-id values type failed: #{e.message}"
		end
	end

	def self.scan_for_fixes(io)
		base64 = false
		short_id = false
		protocol_param = false
		first_nonempty_seen = false
		buffer = String.new
		chunk_size = 64 * 1024

		while (chunk = io.read(chunk_size))
			buffer << chunk

			unless first_nonempty_seen
				if (idx = buffer.index("\n"))
					stripped = buffer[0...idx].strip
					if !stripped.empty?
						first_nonempty_seen = true
						base64 = stripped.match?(/\A[A-Za-z0-9+\/=]+\z/)
					end
				end
			end

			short_id ||= buffer.include?('short-id:')
			protocol_param ||= buffer.include?('protocol-param:')

			if first_nonempty_seen && buffer.bytesize > chunk_size + 4096
				buffer = buffer[-4096, 4096]
			end

			break if base64 || short_id || protocol_param
		end

		unless first_nonempty_seen
			stripped = buffer.strip
			base64 = !stripped.empty? && stripped.match?(/\A[A-Za-z0-9+\/=]+\z/)
		end

		[base64, short_id, protocol_param]
	end

	def self.contains_short_id?(obj, depth = 0)
		return false if depth > 64
		case obj
		when Hash
			return true if obj.key?('short-id') || obj.key?(:"short-id")
			obj.each_value { |v| return true if contains_short_id?(v, depth + 1) }
			false
		when Array
			obj.any? { |v| contains_short_id?(v, depth + 1) }
		else
			false
		end
	end

	# StreamDump writes the data tree directly into libyaml, Psych.dump builds a full AST first
	# and nearly doubles the peak memory. supported? skips trees with anchors or tags,
	# and the scalar style rules below reproduce Psych::Visitors::YAMLTree#visit_String.
	class StringSink
		attr_reader :string

		def initialize
			@string = String.new
		end

		def write(data)
			@string << data
			data.to_s.bytesize
		end
	end

	class StreamDump
		ANY = Psych::Nodes::Scalar::ANY
		PLAIN = Psych::Nodes::Scalar::PLAIN
		SINGLE_QUOTED = Psych::Nodes::Scalar::SINGLE_QUOTED
		DOUBLE_QUOTED = Psych::Nodes::Scalar::DOUBLE_QUOTED
		LITERAL = Psych::Nodes::Scalar::LITERAL
		MAP_BLOCK = Psych::Nodes::Mapping::BLOCK
		SEQ_BLOCK = Psych::Nodes::Sequence::BLOCK
		NULL_TAG = 'tag:yaml.org,2002:null'
		STR_TAG = 'tag:yaml.org,2002:str'

		def self.available?
			defined?(Psych::Emitter) && defined?(Psych::ScalarScanner) && defined?(Psych::ClassLoader)
		end

		def self.supported?(obj)
			return false unless available?

			seen = {}.compare_by_identity
			stack = [obj]
			until stack.empty?
				item = stack.pop
				case item
				when Hash
					return false unless item.class == ::Hash
					return false if seen.key?(item)
					seen[item] = true
					item.each do |key, value|
						stack << key
						stack << value
					end
				when Array
					return false unless item.class == ::Array
					return false if seen.key?(item)
					seen[item] = true
					stack.concat(item)
				when String
					return false unless item.class == ::String
					return false if item.instance_variables.any?
					return false if item.encoding == Encoding::ASCII_8BIT && !item.ascii_only?
				when Integer, Float, TrueClass, FalseClass, NilClass
					# dumped through to_s, exactly like Psych does
				else
					return false
				end
			end
			true
		end

		def initialize(io)
			@io = io
			@scanner = Psych::ScalarScanner.new(Psych::ClassLoader.new)
			@short_id = false
		end

		def dump(obj, short_id: false)
			@short_id = short_id
			emitter = Psych::Emitter.new(@io)
			@emitter = emitter
			emitter.start_stream(Psych::Parser::UTF8)
			emitter.start_document([], [], false)
			emit(obj)
			emitter.end_document(true)
			emitter.end_stream
			@emitter = nil
			@io
		end

		private

		def emit(obj)
			case obj
			when Hash
				@emitter.start_mapping(nil, nil, true, MAP_BLOCK)
				obj.each do |key, value|
					emit(key)
					emit_value(value, key)
				end
				@emitter.end_mapping
			when Array
				@emitter.start_sequence(nil, nil, true, SEQ_BLOCK)
				obj.each { |value| emit(value) }
				@emitter.end_sequence
			when String
				emit_string(obj)
			when Integer, TrueClass, FalseClass
				@emitter.scalar(obj.to_s, nil, nil, true, false, ANY)
			when Float
				emit_float(obj)
			when NilClass
				@emitter.scalar('', nil, NULL_TAG, true, false, ANY)
			end
		end

		def emit_value(value, key)
			if @short_id && (key == 'short-id' || key == :'short-id')
				emit_short_id(value)
			else
				emit(value)
			end
		end

		def emit_float(value)
			if value.nan?
				@emitter.scalar('.nan', nil, nil, true, false, ANY)
			elsif value.infinite?
				@emitter.scalar(value.infinite? > 0 ? '.inf' : '-.inf', nil, nil, true, false, ANY)
			else
				@emitter.scalar(value.to_s, nil, nil, true, false, ANY)
			end
		end

		# short-id values are always double quoted: same result as
		# fix_short_id_text, without building the intermediate document string
		def emit_short_id(value)
			if value.is_a?(Array)
				@emitter.start_sequence(nil, nil, true, SEQ_BLOCK)
				value.each { |item| emit_quoted(item) }
				@emitter.end_sequence
			else
				emit_quoted(value)
			end
		end

		def emit_quoted(value)
			case value
			when String, Integer, Float
				@emitter.scalar(value.to_s, nil, nil, false, true, DOUBLE_QUOTED)
			when nil
				@emitter.scalar('', nil, nil, false, true, DOUBLE_QUOTED)
			else
				emit(value)
			end
		end

		def emit_string(value)
			plain = true
			quote = true
			style = PLAIN
			tag = nil

			if value.match?(/\n(?!\Z)/)
				style = LITERAL
			elsif value == '<<'
				style = SINGLE_QUOTED
				tag = STR_TAG
				plain = false
				quote = false
			elsif value == 'y' || value == 'Y' || value == 'n' || value == 'N'
				style = DOUBLE_QUOTED
			elsif value.match?(/^[^[:word:]][^"]*$/)
				style = DOUBLE_QUOTED
			elsif !(String === @scanner.tokenize(value)) || /\A0[0-7]*[89]/.match?(value)
				style = SINGLE_QUOTED
			end

			@emitter.scalar(value, nil, tag, plain, quote, style)
		end
	end

	# Inline replaces the "one Thread per field" pattern: a finished Thread keeps its stack
	# until it is joined, which costs hundreds of MB for thousands of entries.
	class Inline
		def initialize(*args, &block)
			@error = nil
			begin
				block.call(*args)
			rescue ::Exception => e
				@error = e
			end
		end

		def join
			raise @error if @error
			self
		end

		def value
			raise @error if @error
			self
		end

		def alive?
			false
		end

		def status
			@error ? nil : false
		end

		def kill
			self
		end
		alias_method :terminate, :kill
	end

	def self.overwrite(base, override)
		return override if base.nil?
		return base if override.nil?

		current_key = nil
		current_operation = nil

		begin
			case override
			when Hash
				result = base.is_a?(Hash) ? base.dup : {}

				override.each do |key, value|
					current_key = key
					processed_key, operation = parse_key(key)
					current_operation = operation

					applied = apply_operation(result[processed_key], value, operation)
					if applied.equal?(DELETED_SENTINEL)
						result.delete(processed_key)
					else
						result[processed_key] = applied
					end
				end

				result
			else
				override
			end
		rescue => e
			raise "key: [#{current_key}] - operation: [#{current_operation}], error: [#{e.message}]"
		end
	end

	private

	def self.parse_key(key)
		key_str = key.to_s

		# +<key>
		if key_str.start_with?('+<') && key_str.include?('>')
			close_idx = key_str.index('>')
			inner_key = key_str[2...close_idx]
			return inner_key, :prepend_array
		end

		# <key>suffix
		if key_str.start_with?('<') && key_str.include?('>')
			close_idx = key_str.index('>')
			inner_key = key_str[1...close_idx]
			suffix = key_str[(close_idx + 1)..-1]
			return inner_key, determine_operation(suffix)
		end

		# 前缀 +key
		if key_str.start_with?('+')
			return key_str[1..-1], :prepend_array
		end

		# 尾部（支持 +, !, *, -）
		if key_str =~ /^(.*?)([+!*\-])$/
			return Regexp.last_match(1), determine_operation(Regexp.last_match(2))
		end

		[key_str, :merge]
	end

	def self.determine_operation(suffix)
		case suffix
		when '+'
			:append_array
		when '-'
			:delete
		when '!'
			:force_overwrite
		when '*'
			:batch_update
		else
			:merge
		end
	end

	def self.match_value(target, condition)
		return false if target.nil? || condition.nil?

		begin
			if condition.is_a?(String) && condition.start_with?('/') && condition.end_with?('/')
				pattern = condition[1...-1]
				regexp = Regexp.new(pattern)
				if target.is_a?(Array)
					target.any? { |item| item.to_s =~ regexp }
				else
					target.to_s =~ regexp
				end
			elsif condition.is_a?(Array) && target.is_a?(Array)
				condition.all? { |c| target.include?(c) }
			else
				target == condition
			end
		rescue => e
			raise "[match value] target: [#{target}] - condition: [#{condition}], error: [#{e.message}]"
		end
	end

	def self.deep_dup(obj)
		case obj
		when Array
			obj.map { |x| deep_dup(x) }
		when Hash
			obj.transform_values { |v| deep_dup(v) }
		else
			obj.dup rescue obj
		end
	end

	def self.merge_hash(base, value, prepend: false)
		if prepend
			result = {}

			value.each do |k, v|
				if base.key?(k)
					result[k] = apply_operation(base[k], v, :merge)
				else
					result[k] = deep_dup(v)
				end
			end

			base.each do |k, v|
				result[k] = deep_dup(v) unless result.key?(k)
			end

			result
		else
			result = deep_dup(base)

			value.each do |k, v|
				if result.key?(k)
					result[k] = apply_operation(result[k], v, :merge)
				else
					result[k] = deep_dup(v)
				end
			end

			result
		end
	end

	def self.delete_from_hash(base, value)
		result = deep_dup(base)

		case value
		when Array
			value.each { |k| result.delete(k) }
		when Hash
			value.each do |k, v|
				if v.nil? || v == true
					result.delete(k)
				elsif result[k].is_a?(Hash) && v.is_a?(Hash)
					nested = apply_operation(result[k], v, :delete)
					if nested.equal?(DELETED_SENTINEL)
						result.delete(k)
					else
						result[k] = nested
					end
				else
					result.delete(k)
				end
			end
		else
			result.delete(value)
		end

		result
	end

	DELETED_SENTINEL = Object.new.freeze

	def self.apply_operation(base, value, operation)
		case operation
		when :delete
			if base.is_a?(Array) && value.is_a?(Array)
				base - value
			elsif base.is_a?(Array) && !value.nil?
				base - [value]
			elsif base.is_a?(Hash)
				delete_from_hash(base, value)
			else
				DELETED_SENTINEL
			end
		when :force_overwrite
			deep_dup(value)
		when :prepend_array
			if base.is_a?(Array) && value.is_a?(Array)
				(deep_dup(value) + base).uniq
			elsif base.is_a?(Hash) && value.is_a?(Hash)
				merge_hash(base, value, prepend: true)
			else
				deep_dup(value)
			end
		when :append_array
			if base.is_a?(Array) && value.is_a?(Array)
				base_dup = base.dup
				deep_dup(value).each { |v| base_dup.delete(v) }
				base_dup + deep_dup(value)
			elsif base.is_a?(Hash) && value.is_a?(Hash)
				merge_hash(base, value, prepend: false)
			else
				deep_dup(value)
			end
		when :batch_update
			batch_update_items(base, value)
		when :merge
			if base.is_a?(Hash) && value.is_a?(Hash)
				overwrite(base, value)
			elsif value.nil?
				base
			else
				deep_dup(value)
			end
		else
			deep_dup(value)
		end
	end

	def self.apply_set_fields(item, set_values)
		keys_to_delete = []

		set_values.each do |k, v|
			processed_key, operation = parse_key(k)
			result = apply_operation(item[processed_key], v, operation)
			if result.equal?(DELETED_SENTINEL)
				keys_to_delete << processed_key
			else
				item[processed_key] = result
			end
		end

		keys_to_delete.each { |k| item.delete(k) }
	end

	def self.match_item(item, where_conditions, key = nil)
		where_conditions.all? do |k, v|
			if k == 'key' && !key.nil?
				match_value(key, v)
			elsif item.is_a?(Hash)
				match_value(item[k] || item[k.to_s], v)
			elsif item.is_a?(String) && k == 'value'
				match_value(item, v)
			else
				false
			end
		end
	end

	def self.batch_update_items(collection, update_spec)
		return collection unless update_spec.is_a?(Hash)

		begin
			where_conditions = update_spec['where'] || {}
			set_values = update_spec['set'] || {}

			if collection.is_a?(Array)
				result = collection.dup
				delete_indices = []

				result.each_with_index do |item, index|
					match = match_item(item, where_conditions)

					if match
						if item.is_a?(Hash)
							apply_set_fields(item, set_values)
						elsif item.is_a?(String) && set_values.key?('value')
							new_value = set_values['value']
							if new_value.nil?
								delete_indices << index
							else
								result[index] = deep_dup(new_value)
							end
						end
					end
				end

				delete_indices.reverse_each { |i| result.delete_at(i) }
				result
			elsif collection.is_a?(Hash)
				if where_conditions.any? { |k, _| k != 'key' } &&
					match_item(collection, where_conditions)
					result = collection.dup
					apply_set_fields(result, set_values)
					result
				else
					result = collection.dup
					keys_to_delete = []

					result.each do |key, value|
						next unless value.is_a?(Hash)
						match = match_item(value, where_conditions, key)

						if match
							if set_values.key?('key-') || (set_values.key?('key') && set_values['key'].nil?)
								keys_to_delete << key
							else
								apply_set_fields(value, set_values)
							end
						end
					end

					keys_to_delete.each { |k| result.delete(k) }
					result
				end
			elsif collection.nil?
				nil
			else
				collection
			end
		rescue => e
			raise "[batch update] update_spec: [#{update_spec}], error: [#{e.message}]"
		end
	end

	# The [Overwrite] modules and the custom overwrite script are both executed by this section,
	# they record their helper calls and let one process own one Value and one dump; the argument
	# counts below must stay in sync with ruby_record() in ruby.sh

	OVERWRITE_HELPERS = {
		'ruby_arr_add_file' => 5,
		'ruby_arr_edit' => 6,
		'ruby_arr_head_add_file' => 4,
		'ruby_arr_insert' => 4,
		'ruby_arr_insert_arr' => 4,
		'ruby_arr_insert_hash' => 4,
		'ruby_cover' => 4,
		'ruby_delete' => 3,
		'ruby_edit' => 3,
		'ruby_map_edit' => 5,
		'ruby_merge' => 4,
		'ruby_merge_hash' => 3,
		'ruby_uniq' => 2
	}.freeze

	OVERWRITE_REQUIRED = {
		'ruby_arr_add_file' => [1, 2, 3, 4, 5],
		'ruby_arr_edit' => [1, 2],
		'ruby_arr_head_add_file' => [1, 2, 3, 4],
		'ruby_arr_insert' => [1, 2, 3, 4],
		'ruby_arr_insert_arr' => [1, 2, 3, 4],
		'ruby_arr_insert_hash' => [1, 2, 3, 4],
		'ruby_cover' => [1, 2],
		'ruby_delete' => [1, 3],
		'ruby_edit' => [1, 2],
		'ruby_map_edit' => [1, 2, 3, 4],
		'ruby_merge' => [1, 2, 3],
		'ruby_merge_hash' => [1, 2, 3],
		'ruby_uniq' => [1, 2]
	}.freeze

	# The code arguments are checked against these lists before eval: node types give the allowed
	# syntax, the method, operator and constant lists the allowed callable surface, everything
	# not listed is rejected; the inspected arguments never take part in the check
	OVERWRITE_NODES = %i[
		AND ARGS ATTRASGN BEGIN BLOCK BLOCK_PASS BREAK CALL CASE CASE3 CONST DASGN DOT2 DOT3
		DREGX DSTR DVAR EVSTR FALSE FCALL HASH IF IN ITER LAMBDA LASGN LIST LIT LVAR MASGN
		NEXT NIL NOT OP_ASGN1 OP_ASGN2 OP_ASGN_AND OP_ASGN_OR OPCALL OR RESBODY RESCUE SCOPE
		STR SYM TRUE UNLESS WHEN ZLIST
	].freeze

	OVERWRITE_METHODS = %w(
		[] []= LOG LOG_ERROR LOG_TIP LOG_WARN abs all? any? call capitalize ceil chars chomp
		chomp! chop clone compact compact! concat count delete delete_at delete_if detect dig
		downcase drop drop_while dup each each_char each_key each_line each_pair each_slice
		each_value each_with_index empty? end_with? fetch filter filter! find find_index first
		flat_map flatten flatten! floor frozen? group_by gsub gsub! has_key? has_value?
		include? index insert inspect instance_of? is_a? itself join keep_if key? keys kind_of?
		lambda last length lstrip map map! match match? max max_by member? merge merge! min
		min_by nil? none? partition pop proc push reject reject! replace reverse reverse!
		rindex round rstrip select select! shift size slice slice! sort sort! sort_by sort_by!
		split start_with? store strip sub sub! sum swapcase take take_while tally tap then to_a
		to_f to_h to_i to_s to_sym transform_keys transform_keys! transform_values
		transform_values! uniq uniq! unshift upcase update values values_at yield_self
	).freeze

	OVERWRITE_OPERATORS = %w[! != !~ % & * ** + - / < << <= <=> == =~ > >= >> ^ | ~].freeze

	OVERWRITE_CONSTANTS = %w[Array FalseClass Float Hash Integer NilClass Numeric String Symbol TrueClass Value YAML].freeze

	# Derived lookups keep the node walk cheap, the tables above stay readable
	OVERWRITE_NODE_LOOKUP = OVERWRITE_NODES.to_h { |type| [type, true] }.freeze
	OVERWRITE_CALL_LOOKUP = (OVERWRITE_METHODS + OVERWRITE_OPERATORS).to_h { |name| [name.to_sym, true] }.freeze
	OVERWRITE_CONST_LOOKUP = OVERWRITE_CONSTANTS.to_h { |name| [name.to_sym, true] }.freeze

	# Argument numbers follow the helper call order of ruby.sh, 1 is the config file; the check
	# only covers the arguments interpolated as ruby source
	OVERWRITE_CODE = {
		'ruby_arr_add_file' => [2, 3, 5],
		'ruby_arr_edit' => [2, 3, 5],
		'ruby_arr_head_add_file' => [2, 4],
		'ruby_arr_insert' => [2, 3],
		'ruby_arr_insert_arr' => [2, 3, 4],
		'ruby_arr_insert_hash' => [2, 3, 4],
		'ruby_cover' => [2],
		'ruby_delete' => [2],
		'ruby_edit' => [2, 3],
		'ruby_map_edit' => [2, 4],
		'ruby_merge' => [2, 4],
		'ruby_merge_hash' => [2, 3],
		'ruby_uniq' => [2]
	}.freeze

	# Manifest records: 'M <module>' opens a module block, 'Y <file>' is its [YAML] override block
	# and every 'L <line>' is one [Overwrite] line of it
	def self.overwrite_run(config_file, manifest_file)
		return if config_file.nil? || config_file.empty? || !File.exist?(manifest_file)

		# module lines expand $CONFIG_FILE from the environment, keep the legacy contract
		ENV['CONFIG_FILE'] = config_file

		value = load_file(config_file)
		blocks = []
		File.foreach(manifest_file) do |raw|
			line = raw.chomp
			if line.start_with?('M ')
				blocks << [line[2..-1], nil, []]
			elsif blocks.any?
				if line.start_with?('Y ')
					blocks.last[1] = line[2..-1]
				elsif line.start_with?('L ')
					blocks.last[2] << line[2..-1]
				end
			end
		end

		blocks.each do |name, yaml_file, lines|
			value = overwrite_apply_yaml(value, yaml_file) if yaml_file
			lines.each { |line| overwrite_apply_line(value, name, line) }
		end

		dump(value, config_file)
	rescue ::Exception => e
		LOG_ERROR("Set Custom Overwrite Script Failed,【#{e.message}】")
	end

	# Calls recorded by ruby_record() in ruby.sh: NUL separated fields and a fixed argument count
	# per helper, the records may target several config files
	def self.overwrite_run_custom(calls_file)
		return if calls_file.nil? || calls_file.empty? || !File.exist?(calls_file)

		fields = File.read(calls_file).split("\0", -1)
		values = {}
		position = 0
		while position < fields.length
			fn = fields[position]
			arity = OVERWRITE_HELPERS[fn]
			if fn.nil? || fn.empty?
				position += 1
				next
			elsif arity.nil?
				LOG_WARN("skip unsafe Overwrite command【Ruby Script => #{fn}】")
				position += 1
				next
			end

			args = fields[position + 1, arity] || []
			args += [''] * (arity - args.length)
			position += arity + 1

			if overwrite_unsafe?(fn, args)
				LOG_WARN("skip unsafe Overwrite command【Ruby Script => #{fn}(#{args.map(&:inspect).join(', ')})】")
				next
			end

			file = args[0]
			next if file.nil? || file.empty? || !File.exist?(file)

			values[file] = load_file(file) unless values.key?(file)
			begin
				overwrite_apply(values[file], fn, args)
			rescue ::Exception => e
				LOG_ERROR("Set Custom Overwrite Script Failed,【#{e.message}】")
			end
		end

		values.each { |file, value| dump(value, file) }
	rescue ::Exception => e
		LOG_ERROR("Set Custom Overwrite Script Failed,【#{e.message}】")
	end

	def self.overwrite_apply_yaml(value, yaml_file)
		return value if yaml_file.nil? || yaml_file.empty? || !File.exist?(yaml_file)

		begin
			yaml_data = load(File.read(yaml_file))
			if yaml_data.is_a?(Hash)
				value = overwrite(value, yaml_data)
			else
				LOG_WARN('Invalid YAML Override format, skipped...')
			end
		rescue ::Exception => e
			LOG_ERROR("Parse YAML Override failed:【#{e.message}】")
		end
		value
	end

	def self.overwrite_apply_line(value, name, line)
		parsed = overwrite_parse_line(line)
		if parsed.nil?
			LOG_WARN("skip invalid Overwrite command【Ruby Script => #{name}: #{line}】")
			return
		end

		fn, args = parsed
		if overwrite_unsafe?(fn, args)
			LOG_WARN("skip invalid Overwrite command【Ruby Script => #{name}: #{line}】")
			return
		end

		LOG_TIP("Load Overwrite Script【Ruby Script => #{line}】")
		overwrite_apply(value, fn, args)
	rescue ::Exception => e
		LOG_ERROR("Set Custom Overwrite Script Failed,【#{e.message}】")
	end

	def self.overwrite_unsafe?(fn, args)
		OVERWRITE_CODE[fn].any? do |index|
			text = args[index - 1]
			!text.nil? && !text.empty? && overwrite_code_unsafe?(text)
		end
	end

	# The hash body of ruby_merge_hash is only valid inside braces, so a => fragment needs the
	# braced source checked too, an unparsable argument is unsafe
	def self.overwrite_code_unsafe?(text)
		tree = overwrite_parse_source(text)
		if tree.nil?
			tree = overwrite_parse_source("{#{text}}")
			return true if tree.nil?
		elsif text.include?('=>')
			braced = overwrite_parse_source("{#{text}}")
			return true if braced && overwrite_ast_unsafe?(braced)
		end
		overwrite_ast_unsafe?(tree)
	end

	def self.overwrite_parse_source(source)
		RubyVM::AbstractSyntaxTree.parse(source)
	rescue ::Exception
		nil
	end

	# An explicit stack keeps the walk free of per-node recursion and block calls
	def self.overwrite_ast_unsafe?(node)
		stack = [node]
		until stack.empty?
			current = stack.pop
			next unless current.is_a?(RubyVM::AbstractSyntaxTree::Node)
			return true unless OVERWRITE_NODE_LOOKUP.key?(current.type)

			case current.type
			when :CALL, :FCALL, :VCALL, :ATTRASGN
				return true unless overwrite_method_allowed?(overwrite_call_name(current))
			when :OPCALL
				return true unless overwrite_method_allowed?(current.children[1])
			when :CONST
				names = overwrite_leaf_names(current)
				return true unless names.length == 1 && OVERWRITE_CONST_LOOKUP.key?(names[0].to_sym)
			when :BLOCK_PASS
				names = overwrite_leaf_names(current)
				return true if names.empty? || names.any? { |name| !overwrite_method_allowed?(name) }
			end

			stack.concat(current.children)
		end
		false
	end

	def self.overwrite_method_allowed?(name)
		return OVERWRITE_CALL_LOOKUP.key?(name) if name.is_a?(Symbol)

		OVERWRITE_CALL_LOOKUP.key?(name.to_s.to_sym)
	end

	def self.overwrite_call_name(node)
		(node.type == :CALL || node.type == :ATTRASGN) ? node.children[1] : node.children[0]
	end

	# Symbols and strings of a node subtree, the called name of &:<name> block passes and the
	# name of constants are carried this way
	def self.overwrite_leaf_names(node, names = [])
		node.children.each do |child|
			if child.is_a?(Symbol) || child.is_a?(String)
				names << child
			elsif child.is_a?(RubyVM::AbstractSyntaxTree::Node)
				overwrite_leaf_names(child, names)
			end
		end
		names
	end

	# Only a single call to an allowed helper with quoted arguments is accepted; in double quoted
	# arguments $NAME and ${NAME} expand from the environment and every other character stays
	# literal, in single quoted arguments nothing is expanded
	def self.overwrite_parse_line(line)
		length = line.length
		position = 0
		position += 1 while position < length && (line[position] == ' ' || line[position] == "\t")

		head = position
		position += 1 while position < length && line[position] != ' ' && line[position] != "\t"
		fn = line[head...position]
		return nil unless OVERWRITE_HELPERS.key?(fn)

		args = []
		while position < length
			position += 1 while position < length && (line[position] == ' ' || line[position] == "\t")
			break if position >= length

			quote = line[position]
			return nil unless quote == '"' || quote == "'"

			position += 1
			closing = line.index(quote, position)
			return nil if closing.nil?

			arg = line[position...closing]
			args << (quote == '"' && arg.include?('$') ? overwrite_expand_env(arg) : arg)
			position = closing + 1
		end
		return nil if args.empty?

		[fn, args]
	end

	def self.overwrite_expand_env(text)
		text.gsub(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)/) do
			ENV[Regexp.last_match(1) || Regexp.last_match(2)].to_s
		end
	end

	def self.overwrite_apply(value, fn, args)
		arity = OVERWRITE_HELPERS[fn]
		args = args[0, arity] || []
		args += [''] * (arity - args.length)
		return if OVERWRITE_REQUIRED[fn].any? { |index| args[index - 1].empty? }

		statement = overwrite_statement(fn, args)
		return if statement.nil?

		overwrite_eval(value, statement)
	end

	def self.overwrite_statement(fn, args)
		path = args[1]
		a3 = args[2]
		a4 = args[3]
		a5 = args[4]
		a6 = args[5]
		case fn
		when 'ruby_edit'
			"Value#{path} = #{a3}"
		when 'ruby_cover'
			"if File.exist?(#{a3.inspect}) then value_1 = YAML.load_file(#{a3.inspect}); if not #{a4.inspect}.empty? then Value#{path} = value_1[#{a4.inspect}] else Value#{path} = value_1 end else if not #{a4.inspect}.empty? then Value.delete(#{a4.inspect}); end; end"
		when 'ruby_merge'
			"if File.exist?(#{a3.inspect}) then value_1 = YAML.load_file(#{a3.inspect}); if not Value#{path} then Value#{path} = {}; end; if value_1#{a4} && value_1#{a4}.is_a?(Hash) then Value#{path}.merge!(value_1#{a4}) end end"
		when 'ruby_uniq'
			"if Value#{path} then Value#{path} = Value#{path}.uniq; end"
		when 'ruby_merge_hash'
			"if not Value#{path} then Value#{path} = {}; end; Value#{path}.merge!({#{a3}})"
		when 'ruby_arr_add_file'
			"if File.exist?(#{a4.inspect}) then value_1 = YAML.load_file(#{a4.inspect}); if not Value#{path} or Value#{path}.nil? then Value#{path} = []; end; if value_1#{a5} && value_1#{a5}.is_a?(Array) then idx = [#{a3}.to_i, 0].max; idx = [idx, Value#{path}.length].min; value_1#{a5}.reverse.each{|x| Value#{path}.insert(idx,x); idx += 1}; Value#{path} = Value#{path}.uniq end end"
		when 'ruby_arr_head_add_file'
			"if File.exist?(#{a3.inspect}) then value_1 = YAML.load_file(#{a3.inspect}); if not Value#{path} or Value#{path}.nil? then Value#{path} = []; end; if value_1#{a4} && value_1#{a4}.is_a?(Array) then Value#{path} = (value_1#{a4} + Value#{path}).uniq else Value#{path} = Value#{path}.uniq end end"
		when 'ruby_arr_insert'
			"if not Value#{path} or Value#{path}.nil? then Value#{path} = []; end; idx = [#{a3}.to_i, 0].max; idx = [idx, Value#{path}.length].min; Value#{path} = Value#{path}.insert(idx, #{a4.inspect}).uniq"
		when 'ruby_arr_insert_hash'
			"if not Value#{path} or Value#{path}.nil? then Value#{path} = []; end; idx = [#{a3}.to_i, 0].max; idx = [idx, Value#{path}.length].min; Value#{path} = Value#{path}.insert(idx, #{a4}).uniq"
		when 'ruby_arr_insert_arr'
			"if not Value#{path} or Value#{path}.nil? then Value#{path} = []; end; if (#{a4}).is_a?(Array) then idx = [#{a3}.to_i, 0].max; idx = [idx, Value#{path}.length].min; (#{a4}).reverse.each{|x| Value#{path} = Value#{path}.insert(idx,x); idx += 1}; Value#{path} = Value#{path}.uniq end"
		when 'ruby_delete'
			if path.empty?
				"Value.delete(#{a3.inspect})"
			else
				"if Value#{path} then if Value#{path}.is_a?(Hash) then Value#{path}.delete(#{a3.inspect}) elsif Value#{path}.is_a?(Array) then Value#{path}.delete(#{a3.inspect}) end end"
			end
		when 'ruby_map_edit'
			"if Value#{path} && Value#{path}.is_a?(Hash) then if Value#{path}[#{a3.inspect}] && Value#{path}[#{a3.inspect}].is_a?(Hash) then Value#{path}[#{a3.inspect}]#{a4} = #{a5.inspect} end end"
		when 'ruby_arr_edit'
			if !a3.empty? && !a4.empty? && !a5.empty? && !a6.empty?
				"if Value#{path} && Value#{path}.is_a?(Array) then Value#{path}.map!{|x| if x.is_a?(Hash) && x#{a3} == #{a4.inspect} then x#{a5} = #{a6.inspect} end; x}; Value#{path}.uniq! end"
			elsif a3.empty? && !a4.empty? && a5.empty? && !a6.empty?
				"if Value#{path} && Value#{path}.is_a?(Array) then Value#{path}.map!{|x| if x == #{a4.inspect} then #{a6.inspect} else x end}; Value#{path}.uniq! end"
			end
		end
	end

	def self.overwrite_eval(value, statement)
		remove_const(:Value) if const_defined?(:Value, false)
		const_set(:Value, value)
		eval(statement, binding, '(overwrite)', 1)
	end

	# Value readers for scripts, the path keeps the ruby source form the old helpers accepted,
	# e.g. "['dns']['fake-ip-range']" or ".select { |k, _| k != 'proxies' }.to_yaml"
	def self.overwrite_read(file, path)
		value = load_file(file)
		result = overwrite_eval(value, "Value#{path}")
		puts result if result
	rescue
		nil
	end

	def self.overwrite_read_hash(code, path)
		overwrite_eval(nil, "v = #{code}; if v#{path} then puts v#{path} end")
	rescue
		nil
	end

	def self.overwrite_read_hash_arr(file, path, item_path)
		overwrite_eval(nil, "v = YAML.load_file(#{file.inspect}); if v#{path} then v#{path}.each do |i| if i#{item_path} then puts i#{item_path} end; end; end")
	rescue
		nil
	end
end