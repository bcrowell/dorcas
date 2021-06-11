class Job
  def initialize(data)
    # When calling this on data derived from user input, make sure to canonicalize all unicode characters first.
    @keys = []
    init_helper(data,'verb',nil)
    init_helper(data,'image',nil)
    init_helper(data,'output',"output")
    init_helper(data,'characters',nil)
    init_helper(data,'seed_fonts',[["Times"]])
    init_helper(data,'spacing_multiple',1.0)
    init_helper(data,'threshold',0.5)
    init_helper(data,'cluster_threshold',0.85)
    init_helper(data,'adjust_size',1.0)
    init_helper(data,'guess_dpi',300)
    init_helper(data,'guess_font_size',12)
    init_helper(data,'prefer_cluster',nil)
    init_helper(data,'force_location',nil)
    init_helper(data,'no_matching',false)
    init_helper(data,'set',nil)
    if @verb.nil? then die("no verb specified") end
    if !(@verb=='ocr' || @verb=='learn' || @verb=='seed') then die("unrecognized verb: #{verb}") end
    if @image.nil? then die("no image specified") end
    if (not set_filename.nil?) and set_filename==@output then die("set and output must not be the same") end
    if not @characters.nil? then characters_helper() end
    bogus_keys = data.keys-@keys
    if bogus_keys.length>0 then die("bogus keys: #{bogus_keys}") end
  end

  attr_accessor :verb,:image,:seed_fonts,:spacing_multiple,:threshold,:cluster_threshold,:adjust_size,:keys,:output,:characters,
          :guess_dpi,:guess_font_size,:prefer_cluster,:force_location,:no_matching,:set
  attr_accessor :set_filename

  def to_s
    x = self.to_hash
    x['set'] = self.set_filename
    return x.to_s
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
    if key=='verb' then @verb = value; recognized=true end
    if key=='image' then @image = value; recognized=true end
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
    if key=='force_location' then @force_location = force_location_helper(value); recognized=true end
    if key=='no_matching' then @no_matching = value.to_s.downcase=="true"; recognized=true end
    if key=='set' then
      set_filename=value
      if !(value.nil?) then @set = Fset.from_file_or_directory(value) end
      recognized=true
    end
    if !recognized then die("illegal key #{key}") end # We normally don't even call this helper except on known keys. Bogus keys are checked elsewhere.
  end

  def characters_helper()
    # Flesh out the input list of characters so that if they only specified an alphabet, we put in the whole alphabet.
    processed_chars = []
    @characters.each { |x|
      if x.length!=2 and x.length!=3 then die("illegal value in characters, #{x}, should have 2 or 3 elements") end
      script,c,string = x # if x has 2 elements then string is nil
      if string.nil? then string=Script.new(script).alphabet(c:c) end
      processed_chars.push([script,c,string])
    }
    @characters = processed_chars
  end

  def all_characters()
    # Note that this has already been made explicit by the initializer (in characters_helper()) if the user gave a blank for the whole alphabet.
    # Returns nil if the user hasn't explicitly given a characters[] data structure.
    result = ''
    @characters.each { |x|
      if x.length!=3 then die("illegal value in characters, #{x}, should have 3 elements at this point") end
      script,c,string = x
      result = result + string
    }
    if result=='' then return nil end
    return result
  end

  def prefer_cluster_helper(list)
    # Convert the list of lists to a hash. Convert numbers to 0-based.
    if list.nil? then return nil end
    result = {}
    list.each { |pair|
      char,num = pair
      if num.nil? then die("prefer_cluster should consist of a list of pairs") end
      result[char] = num.to_i-1
    }
    return result
  end

  def force_location_helper(list)
    # Convert the list of lists to a hash whose values are 2-element arrays (x,y).
    if list.nil? then return nil end
    result = {}
    list.each { |a|
      if a.length!=3 then die("illegal value in force_location, #{list}, should have 3 elements") end
      char,x,y = a
      result[char] = [x.to_i,y.to_i]
    }
    return result
  end

  def Job.from_file(filename)
    return Job.new(json_from_file_or_stdin_or_die(filename)) # automatically does unicode_normalize(:nfc)
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
