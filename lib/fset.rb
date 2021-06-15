class Fset
  # Encapsulates a set of character-matching patterns. Is similar to a font, but contains
  # different info such as the red mask, and is used for pattern-matching, not drawing.

  def initialize(pats,data)
    @pats = pats # ... an array of Pat objects
    @max_w = @pats.map {|p| p.width}.max
    @max_h = @pats.map {|p| p.height}.max
    @data = data
    @index = Hash[  @pats.map { |p| [p.c,p]}  ]
    @index2 = Hash[  @pats.map { |p| [char_to_short_name(p.c),p]}  ]
  end

  attr_reader :pats,:max_w,:max_h

  def pat(char_or_name)
    # Char_or_name can be either the unicode character or its short name.
    # Returns nil if the pat doesn't exist.
    if @index.has_key?(char_or_name) then return @index[char_or_name] end
    return @index2[char_or_name] # assume it's a short name
  end

  def has_pat?(char_or_name)
    return ! (self.pat(char_or_name).nil?)
  end

  def all_char_names
    # returns a list of short names
    return @index2.keys
  end

  def dpi
    return @data['dpi'] # resolution in dots per inch
  end

  def size
    return @data['size'] # font's size in points
  end

  def estimate_em
    if self.has_pat?('m') then return self.pat('m').bbox_width end
    if self.has_pat?('Ω') then return self.pat('Ω').bbox_width end
    if self.has_pat?('א') then return self.pat('א').bbox_width end
    return (self.dpi*self.size/72.0)*0.7
  end

  def Fset.from_file_or_directory(file_or_dir)
    # The files containing characters have names that end in .pat. In addition there should
    # be a file called _data.json that looks like this:
    #   {"size":12,"dpi":300}
    # The product of these two numbers, divided by 72, is the nominal line spacing.
    # Other files are harmless but ignored.
    if File.directory?(file_or_dir) then
      return Fset.from_directory_helper(file_or_dir)
    else
      return Fset.from_file_helper(file_or_dir)
    end
  end

  def Fset.from_directory_helper(dir)
    # Don't call this directly, call Fset.from_file_or_directory, so the user always has a choice of dir or zip.
    l = []
    Dir[dir_and_file_to_path(dir,"*.pat")].each { |filename|
      l.push(Pat.from_file(filename))
    }
    data_file = dir_and_file_to_path(dir,"_data.json")
    if File.exists?(data_file) then
      data=JSON.parse(slurp_file(data_file))
    else
      warn("No _data.json file found in #{dir}, supplying default values.")
      data = {"size"=>12,"dpi"=>300}
    end
    return Fset.new(l,data)
  end

  def Fset.from_file_helper(filename)
    # Don't call this directly, call Fset.from_file_or_directory, so the user always has a choice of dir or zip.
    # Input file is a zip archive, not containing a directory but just files. 
    # To create a set file:
    #   zip -j giles46.set pass46/* -i \*.pat \*_data.json
    temp = temp_file_name()
    l = []
    # https://github.com/rubyzip/rubyzip
    data = nil
    Zip::File.open(filename) do |zipfile|
      zipfile.each do |entry|
        # Their sample code has sanity check on entry.size here.
        # Extract to file or directory based on name in the archive
        name_in_archive = entry.name
        type = nil
        if name_in_archive=~/\.pat$/ then type='pat' end
        if name_in_archive=~/_data.json/ then type='data' end
        next if type.nil?
        entry.extract(temp)
        if type=='pat' then l.push(Pat.from_file(temp)) end
        if type=='data' then data=JSON.parse(entry.get_input_stream.read) end
        FileUtils.rm_f(temp)
      end
    end
    if data.nil? then die("Zip file #{filename} does not contain a file _data.json") end
    return Fset.new(l,data)
  end

  def Fset.grow_from_seed(job,page,verbosity:2)
    # Construct a set from scratch using a seed font.
    # Mutates both job and page.
    all_fonts,script_and_case_to_font_name = load_fonts(job)
    if verbosity>=1 then print "Growing pattern set from seed.\n" end
    job.characters.each { |x|
      # x looks like ["greek","lowercase","αβγδε"]. The string of characters at the end has already been filled in by initializer, if necessary.
      script_name,c,chars = x
      font_name = script_and_case_to_font_name["#{script_name}***#{c}"]
      seed_font = all_fonts[font_name]
      script = Script.new(script_name)
      page.dpi = match_seed_font_scale(seed_font,page.stats,script,job.adjust_size)
      if verbosity>=2 then
        print "  #{script_name} #{c} #{chars} #{font_name} #{page.dpi} dpi\n"
        print "  metrics: #{seed_font.metrics(page.dpi,script)}\n"
      end
      pats = []
      chars.chars.each { |char|
        pats.push(char_to_pat(char,job.output,seed_font,page.dpi,script))
      }
      job.set = Fset.new(pats,{}) # fixme -- will it be a problem that data is empty?
    }
  end

end
