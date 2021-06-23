def write_svg_reports(job,dir,pats:nil)
  # Dir is the directory in which to write the svg files, i.e., normally the reports directory.

  output_dir = job.output # used in order to read back all the patterns

  # Write a single svg file summarizing all the patterns in the list defined by pats (which can be
  # either a string of characters or a list of patterns):
  if !(pats.nil?) && pats.length>0 then
    write_svg_reports_helper(dir,output_dir,"swatches.svg","Writing a summary of new swatches to %s\n",pats,job)
  end

  all_chars_in_set = Fset.from_file_or_directory(job.output).all_char_names().map { |n| short_name_to_char(n) }.join('')
  # ... list of all short names in the set

  # loop over each script/case combination
  job.characters.each { |x|
    script_name,the_case,chars_done = x
    file_base = "#{script_name}_#{the_case}.svg"
    chars = Script.new(script_name).alphabet(c:the_case) # do all characters, not just the ones worked on in this job
    chars = chars+all_chars_in_set # in case there are accented characters not listed there
    chars = chars+chars_done # in case we have characters we tried and failed to match, so they're not in the output
    chars = chars.chars.uniq.sort.select { |c| char_to_code_block(c)==script_name && matches_case(c,the_case) }.join('')
    write_svg_reports_helper(dir,output_dir,file_base,"Writing a summary of #{script_name} #{the_case} to %s\n",chars,job)
  }
end

def write_svg_reports_helper(dir,output_dir,file_base,info,data,job)
  # Data can be either a string of characters or a list of patterns. For the characters defined by this list, write
  # a single report.
  if data.class==String then
    pats = []
    data.chars.each { |c|
      filename = Pat.char_to_filename(output_dir,c)
      if File.exists?(filename) then
        pats.push([true,Pat.from_file_or_directory(filename)])
      else
        pats.push([false,c])
      end
    }
  else
    pats = data
  end
  scale = 1.0
  err,message,filename = patset_as_svg(dir,file_base,pats,scale,job.set)
  print sprintf(info,filename)
  if err!=0 then warn(message) end
end

def patset_as_svg(dir,basic_svg_filename,unsorted_pats,scale,set)
  if unsorted_pats.length==0 then return [1,"no patterns to write to #{basic_svg_filename}, file not written",nil] end
  if not File.exists?(dir) then Dir.mkdir(dir) end
  svg_filename = dir_and_file_to_path(dir,basic_svg_filename)
  pats = {}
  unsorted_pats.each { |x|
    matched,match = x
    if matched then
      pat = match
      pats[char_to_short_name(pat.c)] = [pat.c,matched,pat]
    else
      c = match
      pats[char_to_short_name(c)] = [c,matched,nil]
    end
  }
  heights = []
  pats.each { |name,x|
    if x[1] then heights.push(x[2].bw.height) end
  }
  if heights.length==0 then return [2,"no matched patterns to write to #{basic_svg_filename}, file not written",nil] end
  max_height = scale*greatest(heights)[1]
  row_height = max_height*1.3
  col_width = max_height*1.5
  images = []
  labels = []
  bw_filename = {}
  snowmen = []
  bboxen = []
  count = 0
  ref_dots = []
  pats.keys.sort {|a,b| pats[a][0] <=> pats[b][0]}.each { |name|
    c,matched,pat = pats[name]
    x = 0
    y = count*row_height
    if matched then
      basic_png_filename = "patterns_"+name+"_bw.png" # the prefix is because we share a directory with other svg files and their images
      bw_filename[name] = basic_png_filename
      pat.visual.save(dir_and_file_to_path(dir,basic_png_filename))
      images.push([basic_png_filename,x,y,pat.bw.width,pat.bw.height,1.0])
      snowmen.push(pat.snowman(set))
      bboxen.push(pat.real_bbox)
    end
    rough_font_size = max_height*0.27
    labels.push([c,   x+col_width,  y,rough_font_size])
    labels.push([name,x+col_width*2,y,rough_font_size]) if name!=c
    radius = 0.8 # mm
    ref_dots.push([x,y,pat.ref_x,pat.ref_y,radius])
    count += 1
  }
  svg = svg_code_patset(images,labels,snowmen,bboxen,ref_dots,300.0,scale)
  File.open(svg_filename,'w') { |f| f.print svg }
  return [0,nil,svg_filename]
end

def svg_code_patset(image_info,label_info,snowmen,bboxen,ref_dots_info,dpi,scale2)
  x_offset = 10 # in mm
  y_offset = 10
  images = []
  scale = 25.4/dpi # to convert from pixels to mm
  count = 0
  snowmen_list_svg = []
  bbox_list_svg = []
  image_info.each { |i|
    filename,x,y,w,h,opacity = i
    x0,y0 = [x*scale+x_offset,y*scale+y_offset]
    images.push(svg_image(filename,x0,y0,w*scale*scale2,h*scale*scale2,opacity))
    b = clown(bboxen[count])
    b.right +=1; b.bottom +=1 # my Box objects always include edges, so when drawing an outline, need to include the right and bottom pixels
    bbox_list_svg.push(svg_box(b.scale(scale*scale2).translate(x0,y0),color:"#00b949"))
    vert,horiz = snowmen[count]
    0.upto(1) { |side| # 0=left, 1=right
      0.upto(1) { |color| # 0=black, 1=white
        0.upto(2) { |slab| # 0=top, 1=waist, 2=descender
          x = x0 + horiz[side][color][slab]*scale*scale2
          y1 = y0 + vert[slab]  *scale*scale2
          y2 = y0 + vert[slab+1]*scale*scale2
          snowmen_list_svg.push(svg_vertical_line(x,y1,y2))
        }
      }
    }    
    count += 1
  }
  images_svg = images.join("\n")
  snowmen_svg = snowmen_list_svg.join("\n")
  bbox_svg = bbox_list_svg.join("\n")
  labels = []
  label_info.each { |i|
    text,x,y,h = i
    fudge_y_pos = 2.8 # why is this necessary?
    labels.push(svg_text(text,x*scale+x_offset,(y+fudge_y_pos*h)*scale+y_offset,h*scale))
  }
  labels_svg = labels.join("\n")
  ref_dots = []
  ref_dots_info.each { |dot|
    x,y,dx,dy,radius = dot
    ref_dots.push(svg_blue_dot(x*scale+x_offset+dx*scale*scale2,y*scale+y_offset+dy*scale*scale2,radius))
  }
  ref_dots_svg = ref_dots.join("\n")

  svg = "#{svg_header()}  #{images_svg} #{snowmen_svg} #{bbox_svg} #{labels_svg} #{ref_dots_svg} </svg>"
  return svg
end

def svg_text(text,x,y,size_mm)
  # size_mm is the font's point size, expressed in mm; fonts' sizes are normally the em width
svg = 
<<-"SVG"
  <text x="#{x}" y="#{y}" style="font-size:#{mm_to_pt(size_mm)}"><tspan>#{text}</tspan></text>
SVG
end

def summarize_composites_as_svg(report_dir,svg_filename,char_name,composites)
  dpi = 300.0 # fixme
  scale = 25.4/dpi # to convert from pixels to mm
  labels = []
  count = 0
  images = []
  composites.each { |image|
    x = 0
    y = count*100
    filename = dir_and_file_to_path(report_dir,"composite_#{char_name}_#{count}.png")
    image.save(filename)
    images.push(svg_image(filename,x*scale,y*scale,image.width*scale,image.height*scale,1.0))
    count += 1
  }
  images_svg = images.join("\n")
  svg = "#{svg_header()}  #{images_svg} </svg>"
  print "  Writing summary of composites and clusters to #{svg_filename}\n"
  File.open(svg_filename,'w') { |f| f.print svg }
end

def matches_as_svg(dir,svg_filename,char_name,text_file,text,pat,hits,composites)
  print "Writing svg file #{svg_filename}\n"
  images = []
  filename = dir_and_file_to_path(dir,"matches_#{char_name}.png")
  pat.visual.save(filename)
  images.push([text_file,0,0,text.width,text.height,0.4])
  dpi = 300.0 # fixme
  scale = 25.4/dpi # to convert from pixels to mm
  labels = []
  x_offset,y_offset = 0,9.7 # mm
  h = 0.7 # mm
  hits.each { |hit|
    c,x,y = hit
    images.push([filename,x,y,pat.bw.width,pat.bw.height,0.8])
    score_string = (c*100).round.to_s
    labels.push(svg_text(score_string,x*scale+x_offset,y*scale+y_offset,h))
  }
  labels_svg = labels.join("\n")
  svg = svg_code_matches(char_name,dir,images,dpi,composites,labels_svg)
  File.open(svg_filename,'w') { |f| f.print svg }
end

def svg_code_matches(char_name,dir,image_info,dpi,composites,labels_svg)
  images = []
  labels = []
  scale = 25.4/dpi # to convert from pixels to mm
  y_bottom_list = []
  image_info.each { |i|
    filename,x,y,w,h,opacity = i
    y_bottom_list.push(y+h)
    images.push(svg_image(filename,x*scale,y*scale,w*scale,h*scale,opacity))
  }
  highest_y = greatest(y_bottom_list)[1]
  count = 0
  composites.each { |image|
    x0 = 0
    y0 = highest_y+75*count # shouldn't be hardcoded
    filename = dir_and_file_to_path(dir,"matches_#{char_name}_composite_#{count}.png")
    image.save(filename)
    count += 1
    y = y0
    images.push(svg_image(filename,0,y*scale,image.width*scale,image.height*scale,1.0))
    font_size = 16 # mm
    text = "cluster #{count}"
    x = image.width*2
    labels.push(svg_text(text,x*scale,(y+image.height*0.7)*scale,font_size*scale))
  }
  images_svg = images.join("\n")
  text_svg = labels.join("\n")
  svg = "#{svg_header()}  #{images_svg} #{text_svg} #{labels_svg} </svg>"
  return svg
end

def svg_vertical_line(x,y_top,y_bottom)
svg = 
<<-"SVG"
    <path
       style="opacity:1;vector-effect:none;fill:none;fill-opacity:1;stroke:#000000;stroke-width:0.17638889;stroke-linecap:butt;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1"
       d="M #{x},#{y_top} V #{y_bottom}"
       inkscape:connector-curvature="0" />
SVG
  return svg
end

def svg_blue_dot(cx,cy,radius)
svg = 
<<-"SVG"
    <circle
       style="opacity:1;vector-effect:none;fill:#422cff;fill-opacity:0.59174314;fill-rule:evenodd;stroke:#0500fa;stroke-width:0.24694444;stroke-linecap:but\
t;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1"
       id="path5099"
       cx="#{cx}"
       cy="#{cy}"
       r="#{radius}" />
SVG
  return svg
end


def svg_box(box,color:"#000000")
  # box is a Box object
  # color is, e.g., "#00b949" for green
  ds = ["M #{box.left},#{box.top} V #{box.bottom}",
       "M #{box.right},#{box.top} V #{box.bottom}",
       "M #{box.left},#{box.top} H #{box.right}",
       "M #{box.left},#{box.bottom} H #{box.right}"]
  svg = ''
  ds.each { |d|
    svg += 
      <<-"SVG"
      <path
       style="opacity:1;vector-effect:none;fill:none;fill-opacity:1;stroke:#{color};stroke-width:0.17638889;stroke-linecap:butt;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1"
       d="#{d}"
       inkscape:connector-curvature="0" />
      SVG
  }
  return svg
end

def svg_image(filename,x,y,w,h,opacity)
svg = 
<<-"SVG"
    <image
       xlink:href="#{filename}"
       x="#{x}"
       y="#{y}"
       preserveAspectRatio="none"
       height="#{h}"
       width="#{w}"
       style="opacity:#{opacity}" />
SVG
  return svg
end

def svg_header()
svg = 
<<-"SVG"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>

<svg
   xmlns:xlink="http://www.w3.org/1999/xlink"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   width="210mm"
   height="297mm"
   viewBox="0 0 210 297" >
  <defs
     id="defs2" />
  <metadata
     id="metadata5">
  </metadata>
  SVG
  return svg
end

def mm_to_pt(mm)
  return mm/(25.4/72.0) # https://en.wikipedia.org/wiki/Point_(typography)
end

def png_report(monitor_file,text,hits,chars,set,verbosity:2)
  # hits is a hash whose keys are characters and whose values are lists of [score,x,y]
  if monitor_file.nil? then die("no filename set for monitor file") end
  monitor_image = clown(text).grayscale
  overlays = {}
  v = {}
  chars.chars.each { |c|
    short_name = char_to_short_name(c)
    v[short_name] = set.pat(c).visual(black_color:ChunkyPNG::Color::rgba(255,0,0,130),red_color:nil) # semitransparent red
    hits[c].each { |x|
      score,i,j = x
      if verbosity>=3 then print "    ",x,"\n" end
      monitor_image = compose_safe(monitor_image,v[short_name],i,j)
    }
  }
  monitor_image.save(monitor_file)
end
