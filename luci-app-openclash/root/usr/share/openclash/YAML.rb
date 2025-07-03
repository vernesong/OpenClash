module YAML
  class << self
    alias_method :load, :unsafe_load if YAML.respond_to? :unsafe_load
    alias_method :original_dump, :dump
  end

  def self.LOG(info)
    puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + " #{info}"
  end

  def self.dump(obj, io = nil, **options)
    if io
      require 'stringio'
      temp_io = StringIO.new
      original_dump(obj, temp_io, **options)
      yaml_content = temp_io.string
      processed_content = fix_short_id_quotes(yaml_content)
      io.write(processed_content)
      processed_content
    else
      yaml_content = original_dump(obj, **options)
      fix_short_id_quotes(yaml_content)
    end
  end

  private

  SHORT_ID_REGEX = /(\s+short-id:\s*)([^"\s\n]+)/.freeze
  QUOTED_VALUE_REGEX = /^["'].*["']$/.freeze

  def self.fix_short_id_quotes(yaml_content)
    return yaml_content unless yaml_content.include?('short-id:')
    
    yaml_content.gsub(SHORT_ID_REGEX) do
      prefix = $1
      value = $2.strip
      if value !~ QUOTED_VALUE_REGEX
        "#{prefix}\"#{value}\""
      else
        $&
      end
    end
  end
end