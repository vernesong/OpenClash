module YAML
  class << self
    alias_method :load, :unsafe_load if YAML.respond_to? :unsafe_load
    alias_method :original_dump, :dump
  end

  def self.LOG(info)
    puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + " #{info}"
  end

  def self.dump(obj, io = nil, **options)
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
  end

  private

  SHORT_ID_REGEX = /^(\s*short-id:\s*)([^\s"'\n][^\s,}\n]*)$/m.freeze
  QUOTED_VALUE_REGEX = /^["'].*["']$/.freeze

  def self.fix_short_id_quotes(yaml_content)
    return yaml_content unless yaml_content.include?('short-id:')

    yaml_content.lines.map do |line|
      if line =~ SHORT_ID_REGEX
        field_name = $1
        value = $2
        if value !~ QUOTED_VALUE_REGEX
          "#{field_name}\"#{value}\"\n"
        else
          "#{field_name}#{value}\n"
        end
      else
        line
      end
    end.join
  end
end