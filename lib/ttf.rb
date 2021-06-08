=begin
Low-level interface to truetype fonts.
Opentype is a superset of truetype.
Currently I'm doing this with Perl's GD library, but because that seems to be
buggy and no longer actively maintained, I've tried to isolate that interface
here so that it will be easy to switch to somethig else later if I need to.
The story with Perl GD is that it seems to have been popular and widely used
at one point, but I found flaky, buggy code in it, and as of 2021 there are
bug reports and regressions on the github issues page that have not been responded
to in years. Its advantage is that it's available as a debian package and
doesn't require me to use a C interface.
Quirks: if a character is missing from the font, it just silently doesn't output 
it, and instead outputs a little bit of whitespace
=end

def ttf_render_string(s,out_file,ttf_file_path,dpi,point_size,font_height,descender,margin,em)
  # Renders the text to a file.
  # Returns baseline and bounding box in the format [baseline,left,right,top,bottom].
  # Rendered text is aligned vertically in such a way that the descenders, if any, are at the bottom of the image,
  # and ascenders are at the top, except that a margin is added at the top and bottom as well.
  # The purpose of the margin is that if the renderer puts gray pixels outside the nominal bounding box, we get those.
  # When calling GD, the vertical coordinate means the baseline.
  image_height = font_height+2*margin
  baseline = font_height-margin-descender
  verbosity = 2
  max_width = 3*em # making this too big incurs a big performance hit
  sq = escape_double_quotes(s)
  if point_size<=0 or point_size>200 then die("point size #{point_size} fails sanity check") end
  code = <<-"PERL"
    use strict;
    use GD;
    my @bounds;
    my ($black,$white);
    my $ttf_path = "#{escape_double_quotes(ttf_file_path)}";
    my $ptsize = #{point_size};
    my $dummy_image = new GD::Image(1,1);
    $black = $dummy_image->colorAllocate(0,0,0);
    $white = $dummy_image->colorAllocate(255,255,255);
    my %options = {'resolution'=>"#{dpi},#{dpi}"}; # has little or no effect by itself, is just hinting
    my @bounds = GD::Image->stringFT($black,$ttf_path,$ptsize,0,10,#{baseline},"#{sq}",\%options); # trial run for size; is supposed to be cheap
    my $w = $bounds[2];
    my $h = #{image_height};
    my $image = new GD::Image($w,$h);
    $black = $image->colorAllocate(0,0,0);
    $white = $image->colorAllocate(255,255,255);
    $image->filledRectangle(0,0,$w-1,$h-1,$white);
    my @bounds = $image->stringFT($black,$ttf_path,$ptsize,0,10,#{baseline},"#{sq}",\%options);
    open(F, '>', "#{escape_double_quotes(out_file)}") or die $!;
    binmode F;
    print F $image->png;
    close F;
    print "__output__",$bounds[0],",",$bounds[2],",",$bounds[5],",",$bounds[1],"\\n" # left, right, top, bottom -- https://metacpan.org/pod/GD
  PERL
  if verbosity>=4 then print code; print "escaped s=#{escape_double_quotes(s)}\n" end
  output = run_perl_code(code)
  left,right,top,bottom = output.split(/,/).map {|x| x.to_i}
  if verbosity>=3 then print "lrtb=#{[left,right,top,bottom]}\n" end
  return [baseline,left,right,top,bottom]
end

def ttf_get_font_metrics(ttf_file_path,point_size,script,x_height_str,full_height_str,m_width_str)
  # Returns a hash with keys xheight, ascent, descent, hpheight, leading, line_spacing, em.
  # Ascent is defined the normal, standard way in typography, from the baseline to the top of the tallest letter; the Perl GD docs
  # define it a nonstandard way, but this code does it the standard way.
  code = <<-"PERL"
    use GD::Simple;
    use strict;
    # Based on code from GD::Simple, which had bugs. I reported the bugs and offered a patch:
    #   https://github.com/lstein/Perl-GD/issues/37
    # Their code is dual licensed, GPL/Artistic.

    my $image = GD::Simple->new(1,1); # dummy height and width
    my $black = $image->colorAllocate(0,0,0);
    my $size = #{point_size};
    my $font = $image->font('#{ttf_file_path}',$size);

    my $m = '#{x_height_str}';     # such as 'm' for Latin script
    my $hp = '#{full_height_str}'; # such as 'hp' for Latin script
    my $mm = "$m\n$m";
    my $em_str = "#{m_width_str}";

    my @mbounds   = GD::Image->stringFT($black,$font,$size,0,0,0,$m);
    my @hpbounds  = GD::Image->stringFT($black,$font,$size,0,0,0,$hp);
    my @mmbounds  = GD::Image->stringFT($black,$font,$size,0,0,0,$mm);
    my @embounds  = GD::Image->stringFT($black,$font,$size,0,0,0,$em_str);
    my $baseline    = $mbounds[3];
    my $xheight     = $baseline-$mbounds[5];
    my $ascent      = $baseline-$hpbounds[5]; # standard definition in typography, not Perl GD's definition
    my $descent     = $hpbounds[3]-$baseline;
    my $mm_height   = $mmbounds[3]-$mmbounds[5];
    my $hpheight    = $hpbounds[3]-$hpbounds[5];
    my $em          = $embounds[2]-$embounds[0];
    my $leading     = $mm_height - $xheight - $ascent - $descent; # using standard definition of ascent

    print "__output__{\\"xheight\\":$xheight,\\"ascent\\":$ascent,\\"descent\\":$descent,\\"hpheight\\":$hpheight,\\"leading\\":$leading,\\"em\\":$em}";
  PERL
  result = JSON.parse(run_perl_code(code))
  result['line_spacing'] = result['hpheight']+result['leading']
  return result
end
