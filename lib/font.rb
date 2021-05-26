class Font
  def initialize(font_name:nil,file_path:nil,serif:true,italic:false,bold:false,size:12)
    # The most reliable way to specify a font us by using file_path and size.
    # If using font_name, then it needs to be a font name that is recognized by fc-match. For example,
    # on my system 'fc-match BosporosU' verifies that such a font is installed, as opposed to giving some fallback font.
    # Use of serif, italic, and bold args is not implemented. This is difficult to do well because most fonts do not contain multiple styles.
    # If, e.g., you need italics, it's best to explicitly name a .ttf file that is a purely italic font.
    @serif,@italic,@bold,@size = serif,italic,bold,size
    # font_name is, e.g., "BosporosU" if the font is in BosporosU.ttf in one of the standard locations
    # The following assumes we're on a Unix system and can invoke fontconfig's command-line interface, but
    # should still work if that fails, provided an absolute path is suppled. See README under Portability.
    if (not font_name.nil?) and file_path.nil? then
      file_path = Font.name_to_path(font_name)
    end
    if not file_path.nil? then
      font_name = `fc-query -f "%{family}" #{file_path}`
    end
    @font_name,@file_path = font_name,file_path
    @memoized_metrics = {}
  end

  attr_reader :serif,:italic,:bold,:size,:font_name,:file_path

  def Font.name_to_path(font_name)
    return `fc-match -f "%{file}" #{font_name}`
  end

  def to_s()
    if false then # not implemented
      styling = "bold: #{self.bold} italic: #{self.italic} serif: #{self.serif} "
    else
      styling = ''
    end
    result = "font:\n  name: #{self.font_name}\n  file: #{self.file_path}\n #{styling} size: #{self.size}\n"
  end

  def pango_string()
    # Ignores file_path because pango doesn't seem to allow explicit naming of font files.
    a = []
    if not @font_name.nil? then 
      a.push(@font_name)
    else
      if !@serif then a.push("sans") end
      # E.g., doing "BosporosU sans" causes it to fall back on some other sans serif font rather than Bosporos.
      # There is no recognized keyword 'serif', only a keyword 'sans'.
    end
    if @italic then a.push("italic") end
    if @bold then a.push("bold") end
    a.push(size.to_s)
    return a.join(' ')
  end

  def line_spacing_pixels(dpi,script)
    # Gives baseline-to-baseline spacing.
    return self.metrics(dpi,script)['line_spacing']
  end

  def metrics(dpi,script)
    # Returns a hash with keys xheight, ascent, descent, hpheight, leading, line_spacing, em, max_kern.
    # dpi must be an integer, so that memoization works
    if dpi.class != Integer then die("dpi must be of Integer type, so that memoization will work") end
    key = "#{dpi},#{script}"
    if @memoized_metrics.has_key?(key) then return @memoized_metrics[key] end
    result = font_metrics_helper(self,dpi,script)
    result['max_kern'] = (result['em']*0.15).round # https://en.wikipedia.org/wiki/Kerning
    @memoized_metrics[key] = result
    return result
  end

end

def font_size_and_dpi_to_size_for_gd(size,dpi)
  return ((dpi/72.0)*size).round # haven't seen clear documentation as to how GD actually does this or whether 72 is the correct magic number
end

def font_metrics_helper(font,dpi,script)
  # glue code for the low-level interface
  # Returns a hash with keys xheight, ascent, descent, hpheight, leading, line_spacing, em.
  ttf_file_path = font.file_path
  x_height_str = script.x_height_string()
  full_height_str = script.full_height_string()
  m_width_str = script.m_width_string()
  point_size = font_size_and_dpi_to_size_for_gd(self.size,dpi)
  return ttf_get_font_metrics(ttf_file_path,point_size,script,x_height_str,full_height_str,m_width_str)
end
