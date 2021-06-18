# coding: utf-8

class Pat
  def initialize(bw,red,line_spacing,baseline,bbox,c)
    @bw,@red,@line_spacing,@bbox,@baseline,@c = bw,red,line_spacing,bbox,baseline,c
    # bw and red are ChunkyPNG objects
    # The bbox is typically the one from the original seed font, and is maintained along with the rest of the data, but
    # it's not of much use compared to real_bbox(), unless real_bbox() is wrong because of flyspecks.
    # The most important part of real_bbox is that it's used to define ref_x.
    # The character itself, c, is only used as a convenience feature for storing in the metadata when writing to a file,
    # and is also used in the actual OCR'ing process.
    @real_bbox = nil # mark it as not ready to calculate, will be wrong if calculated before fix_red() is executed
    garbage,@pink,@bw=Pat.fix_red(bw,red,baseline,line_spacing,c,@bbox)
    @real_bbox = [] # mark it as ready to calculate and memoize
    @threshold = 0.5 # once this has been set, don't change it without deleting all memoized data by calling set_threshold on everything that has a Fat mixin
    # Mix in Fat methods for all objects, memoizing for speed:
    Fat.bless(@bw,@threshold)
    Fat.bless(@red,@threshold)
    Fat.bless(@pink,@threshold)
    @stats = ink_stats_pat(image_to_ink_array(@bw),image_to_ink_array(@pink)) # use pink for this, because that's what we're actually using in correlations
  end

  def ref_x
    # The left side of real_bbox. Can be unreliable if real_bbox is wrong because of flyspecks.
    # this differs from what is normally called the origin of a character in a font; the difference is called the left bearing.
    return real_bbox.left
  end

  def ref_y
    return real_baseline
  end

  def real_baseline
    # The @baseline variable is based on how this character was registered relative to the seed font, and can be off by a couple of pixels.
    # For characters that don't have a descender, we can give a more precise estimate using the real bbox. For a character that doesn't have
    # a descender, this allows us to estimate the bottom of the snowman accurately, rather than mistaking the bottom of the character for
    # something that is a descender.
    if self.has_descender then return @baseline else return self.real_bbox.bottom end
  end

  def has_descender
    est_x_ht = self.height*0.4 # all we need for our present purposes is a quick and dirty estimate that is independent of script
    return self.real_bbox.bottom>@baseline+0.5*est_x_ht
  end

  def real_bbox
    # Returns a Box object. This is based on the actual black ink in self.bw, not the bbox on the seed font. If there are flyspecks
    # that don't get cleaned up by fix_red, then this will be wrong.
    # As with all my box objects, this has integer coords and includes edges.
    if @real_bbox.nil? then die("real_bbox called before fix_ref") end
    if @real_bbox.class==Box then return @real_bbox end
    @real_bbox = real_ink_bbox(self.bw) # will use Fat mixin for speed
    return @real_bbox
  end

  def bbox_width
    return self.real_bbox.width
  end

  def ascii_art
    return array_ascii_art(self.bw.bool_array,fn:lambda { |x| if x==true then '*' else if x.nil? then 'n' else ' ' end end} )
  end

  attr_reader :bw,:red,:line_spacing,:baseline,:bbox,:c
  attr_accessor :pink,:stats

  def width()
    return bw.width
  end

  def height()
    return bw.height
  end

  def transplant_from_file(filename)
    # Checks that the dimensions are the same, and deletes any memoized data.
    my new_pat = Pat.from_file(filename)
    self.transplant(new_pat.bw)
  end

  def transplant(new_bw)
    # Checks that the dimensions are the same, and deletes any memoized data.
    if new_bw.width!=self.width or new_bw.height!=self.height then die("error transplanting swatch into pattern, not the same dimensions") end
    write_bw(new_bw)
  end

  def write_bw(bw)
    @bw = bw
    Fat.bless(@bw,@threshold) # eliminates any old memoized data
  end

  def Pat.char_to_filename(dir,c)
    # Generate the conventional filename we would expect for this unicode character.
    name = char_to_short_name(c)
    return dir_and_file_to_path(dir,name+".pat")
  end

  def white()
    # A pattern where the part we conceptualize as white is set to black, and the red, pink, and white parts set to white.
    # That is, this is a boolean mask that says where the conceptual white is.
    w = ChunkyPNG::Image.new(self.width,self.height,bg_color = ChunkyPNG::Color::BLACK)
    white_color = ChunkyPNG::Color::WHITE
    0.upto(w.width-1) { |i|
      0.upto(w.height-1) { |j|
        if has_ink(@pink[i,j]) then w[i,j]=white_color end # Turn all the red to white.
        if has_ink(@bw[i,j]) then w[i,j]=white_color end # Turn all the black to white
      }
    }
    return w
  end

  def visual(black_color:ChunkyPNG::Color::rgb(0,0,0),red_color:ChunkyPNG::Color::rgb(255,0,0))
    # Either color can be nil.
    # Unlike most of our routines that return PNG images, this one returns a color image.
    v = ChunkyPNG::Image.new(@red.width,@red.height) # default is to initialize it as transparent, which is what we want
    pink_color = ChunkyPNG::Color::rgb(255,160,160)
    0.upto(v.width-1) { |i|
      0.upto(v.height-1) { |j|
        if (not red_color.nil?) then
          if has_ink(@pink[i,j]) then v[i,j]=pink_color end
          if has_ink(@red[i,j]) then v[i,j]=red_color end
        end
        if (not black_color.nil?) and has_ink(@bw[i,j]) then v[i,j]=black_color end
      }
    }
    return v
  end

  def save(filename)
    # My convention is that the filename has extension .pat.
    data = {'baseline'=>self.baseline,'bbox'=>self.bbox,'character'=>self.c,'unicode_name'=>char_to_name(self.c),'line_spacing'=>self.line_spacing}
    # ...the call to char_to_name() is currently pretty slow
    temp_files = []
    write_as_name = ["bw.png","red.png","data.json"]
    n_pieces = write_as_name.length
    0.upto(n_pieces-1) { |i|
      temp_files.push(temp_file_name())
    }
    0.upto(n_pieces-1) { |i|
      n = temp_files[i]
      if i==0 then self.bw.save(n) end
      if i==1 then self.red.save(n) end
      if i==2 then create_text_file(n,JSON.pretty_generate(data)) end
    }
    # rubyzip, https://github.com/rubyzip
    FileUtils.rm_f(filename)
    Zip::File.open(filename, Zip::File::CREATE) do |zipfile|
      0.upto(n_pieces-1) { |i|
        zipfile.add(write_as_name[i],temp_files[i])
      }
    end
    delete_files(temp_files)
  end

  def Pat.from_file(filename,if_fix_red:true)
    temp_files = []
    read_as_name = ["bw.png","red.png","data.json"]
    name_to_index = {}
    n_pieces = read_as_name.length
    0.upto(n_pieces-1) { |i|
      temp_files.push(temp_file_name())
      name_to_index[read_as_name[i]] = i
    }
    bw,red,data = nil,nil,nil
    # https://github.com/rubyzip/rubyzip
    Zip::File.open(filename) do |zipfile|
      zipfile.each do |entry|
        # Their sample code has sanity check on entry.size here.
        # Extract to file or directory based on name in the archive
        name_in_archive = entry.name
        if not (name_to_index.has_key?(name_in_archive)) then die("illegal filename in archive, #{name_in_archive}") end
        i = name_to_index[name_in_archive]
        temp = temp_files[i]
        entry.extract(temp) # read into temp file
        if i==0 or i==1 then
          content = image_from_file_to_grayscale(temp)
        else
          content = JSON.parse(entry.get_input_stream.read)
        end
        if i==0 then bw=content end
        if i==1 then red=content end
        if i==2 then data=content end
      end
    end
    delete_files(temp_files)
    if bw.nil? or red.nil? or data.nil? then die("error reading #{filename}, didn't find all required parts") end
    if data.has_key?('line_spacing') then 
      line_spacing=data['line_spacing']
    else
      line_spacing=72; warn("using default line spacing for pink")
    end
    return Pat.new(bw,red,line_spacing,data['baseline'],data['bbox'],data['character'])
  end

  def real_x_height(set)
    # Gives a precise geometrical estimate of the x height, but can be wrong if there are flyspecks.
    # A pat object doesn't know what set it's part of, so for this purpose we need that as an argument.
    script = Script.new(self.c)
    return set.real_x_height(script:script)
  end

  def snowman(set)
    # Generate some kind of approximate kerning information. This consists of [vert,horiz], containing 16 numbers, where
    # vert is an array like [top,xheight,baseline,bottom], and horiz is an array indexed as [side][color][slab].
    # Breaks the character up into three layers (slab=0, 1, 2) on each side (0=left, 1=right).
    # For color=0, gives the skinny snowman consisting of the width of the black template.
    # For color=1, gives the fatter one that is the white (i.e., not pink).
    # All x coordinates are relative to the left side of the template image.
    # A pat object doesn't know what set it's part of, so for this purpose we need that as an argument.
    # The computations take about 1 second for 100 characters, and are memoized.
    w,h = self.bw.width,self.bw.height
    bl = self.real_baseline
    xh = self.real_x_height(set)
    vert = [xh/6,bl-xh,bl,h] # top is not 0 because often we have a strip of white at the top
    if !(@snowman.nil?) then return @snowman end # memoized
    black = image_to_boolean_ink_array(self.bw) # true means black
    white = generate_array(w,h,lambda {|i,j| !has_ink(self.pink[i,j])}) # true means not pink
    outermost = [nil,nil]
    0.upto(1) { |side| # 0=left, 1=right
      stuff = [nil,nil]
      0.upto(1) { |color| # 0=black, 1=white
        stuff[color] = []
        0.upto(h-1) { |j|
          if color==0 then
            x = 0.upto(w-1).select { |i| black[i][j] }
          else
            x = 0.upto(w-1).select { |i| white[i][j] }
          end
          if side==0 then stuff[color].push(x.min) else stuff[color].push(x.max) end
        }
      }
      outermost[side] = clown(stuff)
    }
    horiz = [nil,nil]
    0.upto(1) { |side| # 0=left, 1=right
      horiz[side] = [nil,nil]
      0.upto(1) { |color| # 0=black, 1=white
        horiz[side][color] = [nil,nil,nil]
        0.upto(2) { |slab| # 0=top, 1=waist, 2=descender
          vslop = (0.03*h).round # try to make it not too sensitive to the exact vertical coords
          top = vert[slab]+vslop
          bottom = vert[slab+1]-vslop
          outer_limits = top.upto(bottom).map { |j| outermost[side][color][j] }.select { |x| !(x.nil?)}
          if outer_limits.length==0 then
            x = (self.bbox[0]+self.bbox[1])/2 # happens a lot with black above x height, black snowman is at center, zero width
          else
            if side==0 then extreme_outer_limits=outer_limits.min else extreme_outer_limits=outer_limits.max end
            x = extreme_outer_limits
          end
          horiz[side][color][slab] = x
        }
      }
    }
    @snowman = [vert,horiz]
    return @snowman
  end

  def Pat.fix_red(bw,red,baseline,line_spacing,c,bbox)
    # On the fly, fiddle with three things related to the red mask:
    # (1) It's hard to get an accurate red mask below the baseline using guard-rail characters. E.g., in my initial attempts,
    # I neglected to use ρ as a right-side guard character, so strings like ερ were causing problems, tail of ρ hanging
    # down into ε's whitespace. This operation is idempotent, so although could be done for once and for all, it's OK to do it every time.
    # (2) Fill in concavities in the shape of the red mask, and let it diffuse outward by a few pixels (variable pink_radius below).
    # This is something we want to do on the fly, because the amount of smearing is something we might want to adjust.
    # (3) Remove any black pixels that are both (a) outside the nominal bbox from the seed font and (b)
    # either inside pink or at the edges. These are always glitches. (Criterion a can't be based on snowman, because part of the reason
    # for removing these glitches is so we can make an accurate snowman.)
    # The argument c is used only for debugging. The bbox argument is the nominal bbox from the seed font.
    # Note that if there are flyspecks in bw, it will have an effect on this.
    # Returns chunkypng objects [red,pink].
    r = image_to_boolean_ink_array(red)
    #print array_ascii_art(r,fn:lambda {|x| {true=>'t',false=>' '}[x]}) 
    w,h = ink_array_dimensions(r)

    red_below_baseline = []
    0.upto(w-1) { |i|
      # Find the fraction of pixels above baseline that are red.
      n = 0
      nr = 0
      0.upto(baseline) { |j|
        n += 1
        if r[i][j] then nr +=1 end
      }
      red_below_baseline.push(n>0 && nr/n.to_f>0.25)
    }
    smear = (w*0.07).round
    smeared_red_below_baseline = clown(red_below_baseline)
    0.upto(w-1) { |i|
      (i-smear).upto(i+smear) { |ii|
        if ii>=0 and ii<=w-1 and red_below_baseline[ii] then smeared_red_below_baseline[i]=true end
      }
    }
    red_below_baseline = smeared_red_below_baseline
    0.upto(w-1) { |i|
      if red_below_baseline[i] then
        baseline.upto(h-1) { |j|
          r[i][j] = true
        }
      end
    }
    r_with_baseline_fix = clown(r)
    #if c=='ε' then print array_ascii_art(r,fn:lambda {|x| {true=>'t',false=>' '}[x]}) end

    bw_boolean = image_to_boolean_ink_array(bw)
    pink_radius = (0.042*line_spacing).round  # the magic constant gives 3 pixels for Giles, which worked well
    r = pinkify(bw_boolean,r,pink_radius,c)
    #if c=='ε' then print array_ascii_art(r,fn:lambda {|x| {true=>'t',false=>' '}[x]}) end

    # Remove any black pixels that are outside the nominal bbox and inside pink or at the edges. (See comments at top of method for why
    # these criteria are used.)
    white_color = ChunkyPNG::Color::WHITE
    box = Box.from_a(bbox)
    0.upto(h-1) { |j|
      deglitch_helper(box,bw_boolean,0,j)
      deglitch_helper(box,bw_boolean,w-1,j)
    }
    0.upto(w-1) { |i|
      deglitch_helper(box,bw_boolean,i,0)
      deglitch_helper(box,bw_boolean,i,h-1)
    }
    0.upto(w-1) { |i|
      0.upto(h-1) { |j|
        if r[i][j] then deglitch_helper(box,bw_boolean,i,j) end
      }
    }
    return [boolean_ink_array_to_image(r_with_baseline_fix),boolean_ink_array_to_image(r),boolean_ink_array_to_image(bw_boolean)]
  end

end

def deglitch_helper(box,array,i,j)
  if !box.contains?(i,j) then array[i][j] = false end
end

def pinkify(b,r,x,c)
  # Return a new version of the red in which additional pixels are deemed honorary red pixels. See pinkify_right_side() for details.
  # b and r are boolean ink arrays; returns a modified version of r
  # c is used only for debugging
  m = pinkify_right_side(b,r,x,c)
  return flip_array(pinkify_right_side(flip_array(b),flip_array(m),x,''))
end

def pinkify_right_side(b,r,x,c)
  # c is used only for debugging
  w,h = ink_array_dimensions(r)
  center = w/2 # possibly inaccurate
  m = clown(r)
  center.upto(w-1) { |i|
    0.upto(h-1) { |j|
      # Decide whether (i,j) deserves honorary red status according to criterion #1, which
      # is to remove concavities <=x in depth and <=2x in height.
      next if b[i][j] # Never actually make the read spread on top of a black pixel.
      if nearest_right(r,i,j)<=x and nearest_above(r,i,j)+nearest_below(r,i,j)<2*x then m[i][j]=true end
    }
  }
  m2 = clown(m)
  center.upto(w-1) { |i|
    0.upto(h-1) { |j|
      # Now, cumulatively, apply criterion #2, which is to pinkify points whose horizontal distance from 
      # previously established red/pink is <=x and whose horizontal distance from black is >x.
      if nearest_right(m,i,j)<=x and nearest_left(b,i,j)>x then m2[i][j]=true end
    }
  }
  return m2
end

def nearest_left(a,i,j)
  w,h = ink_array_dimensions(a)
  i.downto(0) { |ii|
    if a[ii][j] then return i-ii end
  }
  return i
end

def nearest_right(a,i,j)
  w,h = ink_array_dimensions(a)
  i.upto(w-1) { |ii|
    if a[ii][j] then return ii-i end
  }
  return w-1-i
end

def nearest_below(a,i,j)
  w,h = ink_array_dimensions(a)
  j.upto(h-1) { |jj|
    if a[i][jj] then return jj-j end
  }
  return h-1-j
end

def nearest_above(a,i,j)
  w,h = ink_array_dimensions(a)
  j.downto(0) { |jj|
    if a[i][jj] then return j-jj end
  }
  return j
end

#---------- end of class Pat

def char_to_pat(c,output_dir,seed_font,dpi,script)
  if dpi<=0 or dpi>2000 then die("dpi=#{dpi} fails sanity check") end
  # Seed_font is a Font object.
  bw,red,line_spacing,baseline,bbox = char_to_pat_without_cropping(c,output_dir,seed_font,dpi.to_i,script)
  bw,red,line_spacing,bbox = crop_pat(bw,red,line_spacing,bbox)
  return Pat.new(bw,red,line_spacing,baseline,bbox,c)
end

def crop_pat(bw,red,line_spacing,bbox)
  # for each column in red, count number of red pixels
  w,h = red.width,red.height
  nred = []
  0.upto(w-1) { |i|
    count = 0
    0.upto(h-1) { |j|
      if has_ink(red[i,j]) then count += 1 end
    }
    nred.push(count)
  }
  # find region near center where number of red pixels is not max
  left = nil
  0.upto(w-1) { |i|
    if nred[i]<nred[0] then left=i; break end
  }  
  right = nil
  0.upto(w-1) { |i|
    ii = w-i-1
    if nred[ii]<nred[w-1] then right=ii; break end
  }
  if left.nil? or right.nil? then
    bw.save("debug1.png")
    red.save("debug2.png")
    die("left or right is nil, left=#{left}, right=#{right}; bw written to debug1.png, red written to debug2.png")
  end
  if bbox[0]-left<0 then left=bbox[0] end
  # ... Happens with Nimbus Sans, j. Make sure that after subtracting, left will still be >=0.
  #     Since bbox[1]>bbox[0], this should automatically keep bbox[1] from being negative either.
  bw2  = bw.crop(left,0,right-left+1,h)
  red2 = red.crop(left,0,right-left+1,h)
  bbox[0] -= left
  bbox[1] -= left
  if bbox[0]<0 then die("bbox=#{bbox} contains negative values") end
  return [bw2,red2,line_spacing,bbox]
end

def char_to_pat_without_cropping(c,dir,font,dpi,script)
  image = []
  bboxes = []
  red = []
  my_baseline = nil
  0.upto(1) { |side|
    baseline,bbox,im = string_to_image(c,dir,font,side,dpi,script)
    my_baseline = baseline # should be the same both times through the loop
    image.push(im)
    bboxes.push(bbox)
    red.push(red_one_side(c,dir,font,side,image[side],dpi,script))
  }
  w = red[0].width+red[1].width-image[0].width # (RL+I)+(RR+I)-I
  h = image[0].height
  image_final = pad_image_right(pad_image_left(image[0],red[0].width,h),w,h)
  red_left_full_width = pad_image_right(red[1],w,h)
  red_right_full_width = pad_image_left(red[0],w,h)
  red_final = image_or(red_left_full_width,red_right_full_width)
  final_bbox = clown(bboxes[0])
  scoot = red[1].width-image[0].width
  final_bbox[0] += scoot  
  final_bbox[1] += scoot  
  pat_line_spacing = image_final.height # this may be wrong, but it seems like pango sets the height of the image to the line height
  return [image_final,red_final,pat_line_spacing,my_baseline,final_bbox]
end

def red_one_side(c,dir,font,side,image_orig,dpi,script)
  script = Script.new(c)
  # To find out how much white "personal space" the character has around it, we render various other "guard-rail" characters
  # to the right and left of it. The logical "or" of these is space that we know can be occupied by other characters. I visualize
  # this as red.
  # side=0 means guard-rail chars will be on the right of our character, 1 means left
  # As we go through the loop, the images can grow, but we don't mutate image_orig.
  red = image_empty_copy(image_orig)
  image = clown(image_orig)
  other = script.guard_rail_chars(side)
  other.chars.each { |c2|
    if side==0 then s=c+c2 else s=c2+c end
    trash1,trash2,image2 = string_to_image(s,dir,font,side,dpi,script)
    image,image2,red = reconcile_widths([image,image2,red],side)
    red = image_or(red,image_minus(image2,image))
  }
  bbox = bounding_box(image)

  # When side=1, it seems like the main character is not aligned in precisely the same spot every time, varies by ~1 pixel. 
  # I'm not sure if this is a +-1 bug in GD or in my code. Kerning shouldn't actually cause this to happen, since by definition,
  # right-alignment should be right-alignment. The effect is in fact quite small compared to a big kerning correction, seems to
  # be only 1 pixel. But it does happen, and this causes the red pattern to contain glitches at the left and right edges of
  # the main character. Remove these glitches.
  if side==1 then
    bigger_bbox = clown(bbox)
    max_kern = font.metrics(dpi,script)['max_kern'] # efficient because memoized
    bigger_bbox[0] -= 1
    bigger_bbox[1] += 1
    erase_inside_box(red,bigger_bbox) 
  end

  # If a pixel is red, fill in everything farther away to the side with red as well.
  w,h = image.width,image.height
  0.upto(h-1) { |j|
    started = false
    0.upto(w-1) { |ii|
      if side==1 then i=w-1-ii else i=ii end
      if has_ink(red[i,j]) then started=true end
      if started then red[i,j]=ChunkyPNG::Color::BLACK end
    }
  }
  return red
end


def string_to_image(s,dir,font,side,dpi,script)
  verbosity = 2
  temp_file = temp_file_name()
  line_spacing = font.line_spacing_pixels(dpi,script)
  point_size = font_size_and_dpi_to_size_for_gd(font.size,dpi)
  ttf_file_path = font.file_path

  if point_size<=0 or point_size>200 then die("point size #{point_size} fails sanity check") end

  # The following is not inefficient, because font.metrics() is memoized.
  metrics = font.metrics(dpi,script)
  hpheight = metrics['hpheight']
  descent = metrics['descent']
  em = metrics['em']
  margin = 1
  
  baseline,left,right,top,bottom = ttf_render_string(s,temp_file,ttf_file_path,dpi,point_size,hpheight,descent,margin,em)
  if verbosity>=3 then print "lrtb=#{[left,right,top,bottom]}\n" end
  image = ChunkyPNG::Image.from_file(temp_file)
  FileUtils.rm_f(temp_file)

  if side==1 then # right-aligned
    # Because GD doesn't support drawing right-aligned text, we have to scooch it over.
    # In the following, I'm afraid to use methods like crop! and replace! because in the past those have crashed.
    offset = image.width-right
    if offset<0 then die("negative offset; this can happen if the renderer overflows the size allocated for the image") end
    image4 = image.crop(0,0,image.width-offset,image.height) # make it narrower, otherwise the replace method complains
    image2 = ChunkyPNG::Image.new(image.width,image.height,ChunkyPNG::Color::WHITE)
    image3 = image2.replace(image4,offset_x=offset)
    image = image3
    left += offset
    right += offset
  end
  
  bbox = [left,right,top,bottom]

  return [baseline,bbox,image]
end



