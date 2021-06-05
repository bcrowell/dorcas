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
    return @index2.keys
  end

  def dpi
    return @data['dpi'] # resolution in dots per inch
  end

  def size
    return @data['size'] # font's size in points
  end

  def Fset.from_file_or_directory(file_or_dir)
    # The files containing characters have names that end in .pat. In addition there should
    # be a file called _data.json that looks like this:
    #   {"size":12,"dpi":300}
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

end
