class Job
  def initialize(data)
    @keys = []
    init_helper(data,'image',nil)
    init_helper(data,'prev',nil)
    init_helper(data,'output',"output")
    init_helper(data,'seed_fonts',[["Times"]])
    init_helper(data,'spacing_multiple',1.0)
    init_helper(data,'threshold',0.62)
    init_helper(data,'cluster_threshold',0.85)
    init_helper(data,'adjust_size',1.0)
    if @image.nil? then die("no image specified") end
    if (not @prev.nil?) and @prev==@output then die("prev and output must not be the same") end
  end

  attr_accessor :image,:seed_fonts,:spacing_multiple,:threshold,:cluster_threshold,:adjust_size,:keys,:prev,:output

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
    recognized = false
    if key=='image' then @image = value; recognized=true end
    if key=='prev' then @prev = value; recognized=true end
    if key=='output' then @output = value; recognized=true end
    if key=='seed_fonts' then @seed_fonts = value; recognized=true end
    if key=='spacing_multiple' then @spacing_multiple = value.to_f; recognized=true end
    if key=='threshold' then @threshold = value.to_f; recognized=true end
    if key=='cluster_threshold' then @cluster_threshold = value.to_f; recognized=true end
    if key=='adjust_size' then @adjust_size = value.to_f; recognized=true end
    if !recognized then die("illegal key #{key}") end
  end

  def Job.from_file(filename)
    return Job.new(JSON.parse(slurp_file(filename)))
  end

  def Job.font_string_is_full_path(s)
    return (s=~/\.ttf$/) # This is the behavior that the docs guarantee.
  end

  def Job.font_string_to_path(s)
    if Job.font_string_is_full_path(s) then 
      return s
    else
      return Font.name_to_path(s)
    end
  end

  def all_font_files
    hash = {}
    @seed_fonts.each { |x|
      s = x[0] # may be a font name or a ttf filename
      hash[Job.font_string_to_path(s)] = 1
    }
    return hash.keys
  end

end
