module YAML
  class << self
    alias_method :load, :unsafe_load if YAML.respond_to? :unsafe_load
  end

  def dump(obj, io = nil, **options)
      default_options = {
        :line_width => -1,
        :canonical => false
      }
      
      merged_options = default_options.merge(options)
      
      original_dump(obj, io, **merged_options)
    end
  end

  def self.LOG(info)
    puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + " #{info}"
  end
end