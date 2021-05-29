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

  def pat(char)
    # char can be either the unicode character or its short name
    if @index.has_key?(char) then return @index[char] end
    return @index2[char] # assume it's a short name
  end

  def dpi
    return @data['dpi'] # resolution in dots per inch
  end

  def size
    return @data['size'] # font's size in points
  end

  def Fset.from_file(filename)
    # Input file is a zip archive, not containing a directory but just files. The files containing characters
    # have names that end in .pat. In addition there should be a file called _data.json that looks like this:
    #   {"size":12,"dpi":300}
    # Other files are harmless but ignored.
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
    if data.nil? then die("Zip file #{filenam} does not contain a file _data.json") end
    return Fset.new(l,data)
  end



end
