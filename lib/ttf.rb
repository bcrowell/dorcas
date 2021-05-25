def ttf_render_string(s,out_file,ttf_file_path,dpi,line_spacing,point_size)
  # quirks: if a character is missing from the font, it just silently doesn't output it, and instead outputs a little bit of whitespace
  # advantage: unlike pango-view, lets you really force a particular font
  # Returns bounding box.
  verbosity = 2
  code = <<-"PERL"
    use strict;
    use GD;
    my $w = 1000;
    my $h = #{line_spacing};
    my $image = new GD::Image($w,$h);
    my $black = $image->colorAllocate(0,0,0);
    my $white = $image->colorAllocate(255,255,255);
    $image->filledRectangle(0,0,$w-1,$h-1,$white);
    my $ttf_path = "#{escape_double_quotes(ttf_file_path)}";
    my $ptsize = #{point_size};
    my %options = {'resolution'=>"#{dpi},#{dpi}"}; # has little or no effect by itself, is just hinting
    my @bounds = $image->stringFT($black,$ttf_path,$ptsize,0,10,$h*0.75,"#{escape_double_quotes(s)}",\%options);
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
  return [left,right,top,bottom]
end
