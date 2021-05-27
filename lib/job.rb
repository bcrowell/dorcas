class Job
  def initialize(data)
    # When calling this on data derived from user input, make sure to canonicalize all unicode characters first.
    @keys = []
    init_helper(data,'image',nil)
    init_helper(data,'prev',nil)
    init_helper(data,'output',"output")
    init_helper(data,'characters',[['latin','lowercase']])
    init_helper(data,'seed_fonts',[["Times"]])
    init_helper(data,'spacing_multiple',1.0)
    init_helper(data,'threshold',0.62)
    init_helper(data,'cluster_threshold',0.85)
    init_helper(data,'adjust_size',1.0)
    init_helper(data,'guess_dpi',300)
    init_helper(data,'guess_font_size',12)
    init_helper(data,'prefer_cluster',nil)
    if @image.nil? then die("no image specified") end
    if (not @prev.nil?) and @prev==@output then die("prev and output must not be the same") end
    characters_helper()
    bogus_keys = data.keys-@keys
    if bogus_keys.length>0 then die("bogus keys: #{bogus_keys}") end
  end

  attr_accessor :image,:seed_fonts,:spacing_multiple,:threshold,:cluster_threshold,:adjust_size,:keys,:prev,:output,:characters,
          :guess_dpi,:guess_font_size,:prefer_cluster

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
    if key=='characters' then @characters = value; recognized=true end
    if key=='guess_dpi' then @guess_dpi = value.to_i; recognized=true end
    if key=='guess_font_size' then @guess_font_size = value.to_f; recognized=true end
    if key=='prefer_cluster' then @prefer_cluster = prefer_cluster_helper(value); recognized=true end
    if !recognized then die("illegal key #{key}") end # We normally don't even call this helper except on known keys. Bogus keys are checked elsewhere.
  end

  def characters_helper()
    # Flesh out the input list of characters so that if they only specified an alphabet, we put in the whole alphabet.
    processed_chars = []
    @characters.each { |x|
      script,c,string = x # if x has 2 elements then string is nil
      if string.nil? then string=Script.new(script).alphabet(c:c) end
      processed_chars.push([script,c,string])
    }
    @characters = processed_chars
  end

  def prefer_cluster_helper(list)
    # Convert the list of lists to a hash. Convert numbers to 0-based.
    if list.nil? then return nil end
    result = {}
    list.each { |pair|
      char,num = pair
      result[char] = num.to_i-1
    }
    return result
  end

  def Job.from_file(filename)
    return Job.new(JSON.parse(slurp_file(filename))) # slurp_file automatically does unicode_normalize(:nfc)
  end

  def Job.font_string_is_full_path(s)
    return (s=~/\.ttf$/) # This is the behavior that the docs guarantee.
  end

  def Job.font_string_to_path(s)
    if Job.font_string_is_full_path(s) then 
      return s
    else
      return Fontconfig.name_to_path(s)
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
