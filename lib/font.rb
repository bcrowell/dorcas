class Font
  def initialize(font_name:nil,file_path:nil,serif:true,italic:false,bold:false,size:12)
    # The most reliable way to specify a font us by using file_path and size.
    # If using font_name, then it needs to be a font name that is recognized by fc-match. For example,
    # on my system 'fc-match BosporosU' verifies that such a font is installed, as opposed to giving some fallback font.
    # Use of serif, italic, and bold args is not implemented. This is difficult to do well because most fonts do not contain multiple styles.
    # If, e.g., you need italics, it's best to explicitly name a .ttf file that is a purely italic font.
    @serif,@italic,@bold,@size = serif,italic,bold,size
    # font_name is, e.g., "BosporosU" if the font is in BosporosU.ttf in one of the standard locations
    if (not font_name.nil?) and file_path.nil? then
      file_path = `fc-match -f "%{file}" #{font_name}`
    end
    if not file_path.nil? then
      font_name = `fc-query -f "%{family}" #{file_path}`
    end
    @font_name,@file_path = font_name,file_path
  end

  def to_s()
    if false then # not implemented
      styling = "bold: #{self.bold} italic: #{self.italic} serif: #{self.serif} "
    else
      styling = ''
    end
    result = "Font:\n  name: #{self.font_name}\n  file: #{self.file_path}\n #{styling} size: #{self.size}\n"
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

  def line_height_pixels(dir,dpi,script)
    image = string_to_image_pango_view(script.full_height_string(),dir,self,"test_line_height.png",0,dpi)
    print "******** line_height_pixels = #{image.height}\n"
    ht1 = image.height
    ht2 = self.metrics(dpi,script)['line_spacing']
    print "********* ht2 = #{ht2}\n"
    return ht1
  end

  def metrics(dpi,script)
    # Returns a hash with keys xheight, ascent, descent, hpheight, leading, line_spacing.
    return get_font_metrics_from_perl_gd(self,font_size_and_dpi_to_size_for_gd(self.size,dpi),script)
  end

  attr_reader :serif,:italic,:bold,:size,:font_name,:file_path
end

def get_font_metrics_from_perl_gd(font,size,script)
  # Input size in points.
  # Returns a hash with keys xheight, ascent, descent, hpheight, leading, line_spacing.
  code = <<-"PERL"
    use GD::Simple;
    use strict;
    # Based on code from GD::Simple, which had bugs. I reported the bugs and offered a patch:
    #   https://github.com/lstein/Perl-GD/issues/37
    # Their code is dual licensed, GPL/Artistic.

    my $image = GD::Simple->new(1,1); # dummy height and width
    my $black = $image->colorAllocate(0,0,0);
    my $size = #{size};
    my $font = $image->font('#{font.file_path}',$size);

    my $m = '#{script.x_height_string()}';     # such as 'm' for Latin script
    my $hp = '#{script.full_height_string()}'; # such as 'hp' for Latin script
    my $mm = "$m\n$m";

    my @mbounds   = GD::Image->stringFT($black,$font,$size,0,0,0,$m);
    my @hpbounds  = GD::Image->stringFT($black,$font,$size,0,0,0,$hp);
    my @mmbounds  = GD::Image->stringFT($black,$font,$size,0,0,0,$mm);
    my $xheight     = $mbounds[3]-$mbounds[5];
    my $ascent      = $mbounds[5]-$hpbounds[5];
    my $descent     = $hpbounds[3]-$mbounds[3];
    my $mm_height   = $mmbounds[3]-$mmbounds[5];
    my $hpheight    = $hpbounds[3]-$hpbounds[5];
    my $leading     = $mm_height - 2*$xheight - $ascent - $descent;

    print "__output__{\\"xheight\\":$xheight,\\"ascent\\":$ascent,\\"descent\\":$descent,\\"hpheight\\":$hpheight,\\"leading\\":$leading}";
  PERL
  result = JSON.parse(run_perl_code(code))
  result['line_spacing'] = result['hpheight']+result['leading']
  return result
end

def font_size_and_dpi_to_size_for_gd(size,dpi)
  return ((dpi/72.0)*size).round # haven't seen clear documentation as to how GD actually does this or whether 72 is the correct magic number
end
