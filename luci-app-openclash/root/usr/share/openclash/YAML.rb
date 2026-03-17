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

  # Keep `short-id` as string before YAML parsing so leading zeros are preserved.
  # This is required for REALITY short-id values like `00000000`.
  def self.load_file(filename, *args, **kwargs)
    yaml_content = File.read(filename)
    processed_content = fix_short_id_quotes(yaml_content)

    if kwargs.empty?
      load(processed_content, *args)
    else
      load(processed_content, *args, **kwargs)
    end
  end

  def self.dump(obj, io = nil, **options)
    begin
      if io.nil?
        yaml_content = original_dump(obj, **options)
        fix_short_id_quotes(yaml_content)
      elsif io.respond_to?(:write)
        require 'stringio'
        temp_io = StringIO.new
        original_dump(obj, temp_io, **options)
        yaml_content = temp_io.string
        processed_content = fix_short_id_quotes(yaml_content)
        io.write(processed_content)
        io
      else
        yaml_content = original_dump(obj, io, **options)
        fix_short_id_quotes(yaml_content)
      end
    rescue => e
      LOG_ERROR("Write file failed:【%s】" % [e.message])
      nil
    end
  end

  private

  SHORT_ID_REGEX = /^(\s*)short-id:\s*(.*)$/
  LIST_ITEM_REGEX = /^(\s*)-\s*(.*)$/
  KEY_REGEX = /^(\s*)([a-zA-Z0-9_-]+):\s*(.*)$/
  QUOTED_VALUE_REGEX = /^["'].*["']$/

  # Inline map support, e.g. reality-opts: { ..., short-id: 00000000 }
  INLINE_SHORT_ID_REGEX = /(short-id:\s*)(?!["'\[])([^\s,"'{}\[\]\n\r]+)(?=\s*(?:[,}\]\n\r]|$))/m.freeze

  def self.fix_short_id_quotes(yaml_content)
    return yaml_content unless yaml_content.include?('short-id:')

    begin
      # First, normalize inline-map style unquoted short-id.
      processed = yaml_content.gsub(INLINE_SHORT_ID_REGEX) do
        "#{$1}\"#{$2}\""
      end

      lines = processed.lines
      short_id_indices = lines.each_index.select { |i| lines[i] =~ SHORT_ID_REGEX }
      short_id_indices.each do |short_id_index|
        line = lines[short_id_index]
        if line =~ SHORT_ID_REGEX
          indent = $1
          value = $2.strip
          if value.empty?
            (short_id_index + 1...lines.size).each do |i|
              line = lines[i]
              next if line.strip.empty?
              if line[/^\s*/].length <= short_id_indent_len
                break
              end
              if line =~ LIST_ITEM_REGEX
                indent = $1
                value = $2.strip
                if value =~ KEY_REGEX
                  break
                end
                if value !~ QUOTED_VALUE_REGEX
                  lines[i] = "#{indent}- \"#{value}\"\n"
                end
              elsif line =~ KEY_REGEX
                break
              end
            end
          else
            if value !~ QUOTED_VALUE_REGEX
              lines[short_id_index] = "#{indent}short-id: \"#{value}\"\n"
            end
          end
        end
      end
      lines.join
    rescue => e
      LOG_ERROR("Fix short-id values type failed:【%s】" % [e.message])
      yaml_content
    end
  end
end
