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

		if io.nil?
			yaml_content = original_dump(obj, **options)
			needs_fix ? fix_short_id_quotes(yaml_content) : yaml_content
		elsif io.respond_to?(:write)
			if needs_fix
				fix_short_id_text(original_dump(obj, **options), io)
			else
				original_dump(obj, io, **options)
			end
			io
		else
			yaml_content = original_dump(obj, **options)
			needs_fix ? fix_short_id_quotes(yaml_content) : yaml_content
		end
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
		rescue Exception
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

	def self.find_age_keys_for_filename(filename)
		basename = File.basename(filename)
		basename_no_ext = File.basename(filename, File.extname(filename))
		publics = []
		secrets = []

		[basename, basename_no_ext].uniq.each do |n|
			cmd_public = ["/bin/sh", "-c", ". /usr/share/openclash/uci.sh; uci_get_age_public_keys \"$1\"", "sh", n]
			IO.popen(cmd_public, "r") do |io|
				io.each_line { |l| publics << l.strip unless l.nil? || l.strip == "" }
			end

			cmd_secret = ["/bin/sh", "-c", ". /usr/share/openclash/uci.sh; uci_get_age_secret_keys \"$1\"", "sh", n]
			IO.popen(cmd_secret, "r") do |io|
				io.each_line { |l| secrets << l.strip unless l.nil? || l.strip == "" }
			end
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
end