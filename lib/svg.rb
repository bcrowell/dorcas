def patset_as_svg(dir,basic_svg_filename,unsorted_pats)
  if not File.exists?(dir) then Dir.mkdir(dir) end
  svg_filename = dir_and_file_to_path(dir,basic_svg_filename)
  pats = {}
  unsorted_pats.each { |pat|
    pats[char_to_short_name(pat.c)] = pat
  }
  heights = []
  pats.each { |name,pat|
    heights.push(pat.bw.height)
  }
  max_height = greatest(heights)[1]
  images = []
  labels = []
  bw_filename = {}
  count = 0
  pats.each { |name,pat|
    c = pat.c
    print "character: #{name}\n"
    basic_png_filename = name+"_bw.png"
    bw_filename[name] = basic_png_filename
    pat.bw.save(dir_and_file_to_path(dir,basic_png_filename))
    y = count*max_height
    images.push([basic_png_filename,0,y,pat.bw.width,pat.bw.height,1.0])
    labels.push([c,name,pat.bw.width*2,y,max_height*0.25])
    count += 1
  }
  svg = svg_code_patset(images,labels,300.0)
  File.open(svg_filename,'w') { |f| f.print svg }
end

def svg_code_patset(image_info,label_info,dpi)
  images = []
  scale = 25.4/dpi # to convert from pixels to mm
  image_info.each { |i|
    filename,x,y,w,h,opacity = i
    images.push(svg_image(filename,x*scale,y*scale,w*scale,h*scale,opacity))
  }
  images_svg = images.join("\n")
  labels = []
  label_info.each { |i|
    c,name,x,y,h = i
    labels.push(svg_text(c,x*scale,(y+h)*scale,h*scale))
  }
  labels_svg = labels.join("\n")
  svg = "#{svg_header()}  #{images_svg} #{labels_svg} </svg>"
  return svg
end

def svg_text(text,x,y,size_mm)
  # size_mm is the font's point size, expressed in mm; fonts' sizes are normally the em width
svg = 
<<-"SVG"
  <text x="#{x}" y="#{y}" style="font-size:#{mm_to_pt(size_mm)}"><tspan>#{text}</tspan></text>
SVG
end

def matches_as_svg(svg_filename,text_file,text,pat,hits)
  print "Writing svg file #{svg_filename}\n"
  images = []
  hits.each { |hit|
    c,i,j = hit
    images.push(["bw.png",i,j,pat.bw.width,pat.bw.height,1.0])
  }
  images.push([text_file,0,0,text.width,text.height,0.25])
  svg = svg_code_matches(images,300.0)
  File.open(svg_filename,'w') { |f| f.print svg }
end

def svg_code_matches(image_info,dpi)
  images = []
  scale = 25.4/dpi # to convert from pixels to mm
  image_info.each { |i|
    filename,x,y,w,h,opacity = i
    images.push(svg_image(filename,x*scale,y*scale,w*scale,h*scale,opacity))
  }
  images_svg = images.join("\n")
  svg = "#{svg_header()}  #{images_svg} </svg>"
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
