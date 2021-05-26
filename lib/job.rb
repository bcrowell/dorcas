class Job
  def initialize(data)
    self.keys = []
    init_helper(data,'image',nil)
    init_helper(data,'seed_fonts',[["Times"]])
    init_helper(data,'spacing_multiple',1.0)
    init_helper(data,'threshold',0.62)
    init_helper(data,'cluster_threshold',0.85)
    init_helper(data,'adjust_size',1.0)
  end

  attr_accessor :image,:seed_fonts,:spacing_multiple,:threshold,:cluster_threshold,:adjust_size,:keys

  def to_s
    return self.to_hash.to_s
  end

  def to_hash
    result = {}
    self.keys.each { |key|
      result[key] = self.send(key)
    }
    return result
  end

  def init_helper(data,key,default)
    if data.has_key?(key) then 
      value=data[key]
    else
      value = default
    end
    @keys = @keys.push(key)
    if key=='image' then @image = value end
    if key=='seed_fonts' then @seed_fonts = value end
    if key=='spacing_multiple' then @spacing_multiple = value.to_f end
    if key=='threshold' then @threshold = value.to_f end
    if key=='cluster_threshold' then @cluster_threshold = value.to_f end
    if key=='adjust_size' then @adjust_size = value.to_f end
  end

  def Job.from_file(filename)
    return Job.new(JSON.parse(slurp_file(filename)))
  end

  def font_string_to_path(s)
    if s=~/\.ttf$/ then # This is the behavior that the docs guarantee.
      return s
    else
      return Font.name_to_path(s)
    end
  end

  def all_font_files
    hash = {}
    @seed_fonts.each { |x|
      s = x[0] # may be a font name or a ttf filename
      hash[font_string_to_path(s)] = 1
    }
    return hash.keys
  end

end
