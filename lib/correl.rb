def correl_convenience(text_ink,pat,stats,box,line_spacing,threshold,max_hits,verbosity:1,give_details:false,implementation:'chapel',heat:false)
  # Returns a list of hits in the format [... [c,i,j,jb] ...], sorted in descending order by correlation score c.
  # (i,j) is the upper left corner where the swatch would be placed, while jb is the coordinate of the baseline.
  # If heat is true, return a heat map as part of the details.
  i_lo,i_hi,j_lo,j_hi = box.to_a
  bw_ink = image_to_ink_array(pat.bw)
  red_ink = image_to_ink_array(pat.red)
  pat_stats = ink_stats_pat(bw_ink,red_ink) # calculates mean and sd
  sdt = stats['sd_in_text']
  sdp = pat_stats['sd']
  norm = sdt*sdp # normalization factor for correlations
  text_line_spacing = stats['line_spacing']  
  scale = text_line_spacing/pat.line_spacing
  results = correl_many(text_ink,bw_ink,red_ink,stats['background'],i_lo,i_hi,j_lo,j_hi,text_line_spacing.to_i,norm,implementation:implementation)
  hits = filter_hits(results,pat.bboxo,box,threshold,max_hits,verbosity:verbosity)
  threshold2 = 0.7
  warn("using hardcoded value of threshold2=#{threshold2}")
  hits = improve_hits_using_squirrel(hits,text_ink,bw_ink,red_ink,stats,threshold2)
  baseline = pat.baseline
  db = baseline-pat.bbox[2]
  hits = hits.map {|x| [x[0],x[1],x[2],x[2]+db]}
  details = {}
  if give_details then
    if !(heat.nil?) then
      # We may not actually have font metrics, but supplying estimates of them helps to get a reasonable alignment of map with image.
      dx = pat.bbox[1]-pat.bbox[0]
      dy = baseline*0.8
      details['heat']=scoot_array(results,dy,dx,-1.0) # order is dy,dx because this will get transposed later
    end
  end
  return [hits,details]
end

def correl_many(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi,line_spacing,norm,implementation:'chapel')
  if implementation=='chapel' then return correl_many_chapel(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi,line_spacing,norm) end
  if implementation=='ruby' then return correl_many_pure_ruby(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi,line_spacing,norm) end
  die ("unrecognized value of implementation: #{implementation}")
end

def correl_many_chapel(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi,line_spacing,norm)
  # A whole page is typically too much for correl_many_one_pass() to do at once.
  verbosity=2
  start = Time.now
  extra_margin = (line_spacing*0.5).round
  max_rows_per_slice = constants()['correl_max_h']-2*extra_margin
  if max_rows_per_slice<200 then die("misconfiguration or resolution is too high, max_rows_per_slice=#{max_rows_per_slice} is very small") end
  n_rows = dy_hi-dy_lo+1
  n_cols = dx_hi-dx_lo+1
  n_slices=n_rows/max_rows_per_slice
  if n_slices*max_rows_per_slice<n_rows then n_slices+=1 end
  rows_per_slice=n_rows/n_slices
  if n_slices*rows_per_slice<n_rows then rows_per_slice+=1 end
  results = [] # list of arrays
  0.upto(n_slices) { |slice|
    this_dy_lo = dy_lo+slice*rows_per_slice
    this_dy_hi = this_dy_lo+rows_per_slice-1
    if this_dy_hi>dy_hi then this_dy_hi=dy_hi end
    if this_dy_hi>=this_dy_lo then
      result = correl_many_one_pass(text,pat,red,background,dx_lo,dx_hi,this_dy_lo,this_dy_hi,extra_margin,norm)
      # returns a list of rows
      results.concat(result)
    end
  }
  finish = Time.now
  if verbosity>=2 then print "  time for correl = #{finish-start} seconds\n" end
  return results
end

def correl_many_one_pass(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi,extra_margin,norm)
  verbosity=1
  # Set up jobs to be done by all CPUs at once.
  start = Time.now
  results = correl_many_chapel(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi,extra_margin,norm)
  finish = Time.now
  if verbosity>=2 then print "    time for this pass of correl = #{finish-start} seconds\n" end
  return results
end

def correl_many_chapel(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi,extra_margin,norm)
  verbosity=1
  exe = 'chpl/correl'
  n_rows = dy_hi-dy_lo+1
  n_cpus = guess_n_cores() # making this equal to the number of physical cores (not counting hypertrheading) gives the best performance
  rows_per_cpu = n_rows/n_cpus
  if rows_per_cpu*n_cpus<n_rows then rows_per_cpu += 1 end
  max_rows = constants()['correl_max_h']
  wt,ht = ink_array_dimensions(text)
  rows_per_cpu_fat = rows_per_cpu+2*extra_margin
  print "    n_cpus=#{n_cpus} rows_per_cpu=#{rows_per_cpu_fat} max_rows=#{max_rows} doing rows #{dy_lo}-#{dy_hi} out of 0-#{ht-1}\n"
  if rows_per_cpu_fat>max_rows then die("rows_per_cpu=#{rows_per_cpu_fat} is greater than CORREL_MAX_H=#{max_rows}") end
  if dy_hi<dy_lo then die("fails sanity check, dy_hi<dy_lo") end

  temp_file_base = temp_file_name()
  files_to_remove = []
  out_files = []
  remember_slicing = []
  0.upto(n_cpus-1) { |cpu|
    offset = cpu*rows_per_cpu
    this_dy_lo = dy_lo+offset
    this_dy_hi = this_dy_lo+rows_per_cpu-1
    if this_dy_lo>dy_hi then break end # can happen if number of rows to do is less than n_cpus
    if this_dy_hi>dy_hi then this_dy_hi=dy_hi end
    file_base = temp_file_base+"-#{cpu}"
    in_file = file_base+".in"
    out_file = file_base+".out"
    files_to_remove.push(in_file)
    files_to_remove.push(out_file)
    out_files.push(out_file)
    offset = prep_chapel_input(in_file,text,pat,red,background,dx_lo,dx_hi,this_dy_lo,this_dy_hi,extra_margin)
    if not File.exists?(in_file) then die("in_file not created?") end
    remember_slicing.push([this_dy_lo,this_dy_hi,offset])
    #print "cpu #{cpu} will do dy=#{this_dy_lo}-#{this_dy_hi}\n"
  }

  if verbosity>=2 then v="--verbose" else v="" end
  cmd = "ls #{temp_file_base}*.in | taskset --cpu-list 0-#{n_cpus-1} parallel #{v} #{exe} \"<\"{} \">\"{.}.out"
  if verbosity>=3 then print cmd,"\n" end
  system(cmd)
  if $?!=0 then die("error executing shell command `cmd`") end
  if verbosity>=3 then print "got back from taskset command, temp_file_base=#{temp_file_base}\n" end
  #print "Done with processing correlations.\n"

  # Initialize the array of results with zeroes:
  result = []
  dy_lo.upto(dy_hi) { |j|
    row = []
    dx_lo.upto(dx_hi) { |i| row.push(0.0) }
    result.push(row)
  }

  # Read chapel results into the array.
  cpu = 0
  out_files.each { |filename|
    this_dy_lo,this_dy_hi,offset = remember_slicing[cpu]
    this_result = retrieve_chapel_output(filename,dx_lo,dx_hi,this_dy_lo,this_dy_hi)
    this_dy_lo.upto(this_dy_hi) { |j|
      dx_lo.upto(dx_hi) { |i|
        jj = j-this_dy_lo
        if jj<0 || jj>this_result.length-1 then die("jj=#{jj} is out of range, #{result.length}, cpu=#{cpu}, j=#{j}, offset=#{offset}, this_dy=#{this_dy_lo},#{this_dy_hi}, dy_lo=#{dy_lo}, this_result.length=#{this_result.length}") end
        ii = i-dx_lo
        if ii<0 || ii>this_result[jj].length-1 then die("i out of range, ii=#{i}, len=#{this_result[jj].length}") end
        result[j-dy_lo][i-dx_lo] = this_result[jj][ii]/norm
      }
    }
    cpu +=1
  }
  #print "Retrieved chapel output.\n"

  files_to_remove.each { |filename|
    FileUtils.rm_f(filename)
  }

  return result
end

def prep_chapel_input(filename,text,pat,red,background,dx_lo,dx_hi,dy_lo_raw,dy_hi_raw,extra_margin)
  wp,hp = ink_array_dimensions(pat)
  wt,ht_raw = ink_array_dimensions(text)
  # Redefine array indices for the chapel code so it only knows about the rows we're providing.
  # The dy values can hang outside the actual physical bounds of the array a little, and that's ok.
  # Figure out the min and max row numbers that we're actually going to provide in the data passed to the chapel code.
  min_y = dy_lo_raw-extra_margin
  if min_y<0 then min_y = 0 end
  max_y = dy_hi_raw+extra_margin
  if max_y>ht_raw-1 then max_y=ht_raw-1  end
  ht = max_y-min_y+1
  offset = min_y
  dy_lo = dy_lo_raw-offset
  dy_hi = dy_hi_raw-offset
  # write to a file:
  File.open(filename,'w') { |f| 
    f.print "#{wt}\n#{ht}\n#{wp}\n#{hp}\n"
    f.print "#{dx_lo}\n#{dx_hi}\n#{dy_lo}\n#{dy_hi}\n"
    f.print "#{ink_to_int(background)}\n"
    min_y.upto(max_y) { |j|
      0.upto(wt-1) { |i|
        f.print "#{ink_to_int(text[i][j])}\n"
      }
    }
    0.upto(hp-1) { |j|
      0.upto(wp-1) { |i|
        f.print "#{ink_to_int(pat[i][j])}\n"
        f.print "#{ink_to_int(red[i][j])}\n"
      }
    }
  }
  #print "exiting prep_chapel_input, offset=#{offset}\n"
  return offset
end

def retrieve_chapel_output(out_file,dx_lo,dx_hi,dy_lo,dy_hi)
  c = []
  File.open(out_file,'r') { |f|
    err = f.gets.to_i;
    message = f.gets;
    if err!=0 then die("error from chapel: #{err}: #{message}") end
    dy_lo.upto(dy_hi) { |dy|
      row = []
      dx_lo.upto(dx_hi) { |dx|
        row.push(f.gets.to_f/(256.0*256.0)) # if changing this, also change the conversion factor inside ink_to_int
      }
      c.push(row)
    }
  }
  return c
end

def ink_to_int(ink)
  return (ink*256).to_i # if changing this, also change the conversion factor inside retrieve_chapel_output
end

def correl_many_pure_ruby(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi,line_spacing,norm)
  # returns results in [j][i] index order
  c = []
  dy_lo.upto(dy_hi) { |dy|
    print (dy*100.0/dy_hi).round," "
    if dy%30==0 then print "\n" end
    row = []
    dx_lo.upto(dx_hi) { |dx|
      row.push(correl(text,pat,red,background,dx,dy,norm))
    }
    c.push(row)
  }
  return c
end

def correl(text,pat,red,background,dx,dy,norm)
  # dx,dy are offsets of pat within text
  wp,hp = ink_array_dimensions(pat)
  wt,ht = ink_array_dimensions(text)

  n = 0
  sum_p = 0.0
  sum_t = 0.0
  sum_pt = 0.0
  0.upto(wp-1) { |i|
    it = i+dx
    0.upto(hp-1) { |j|
      jt = j+dy
      if red[i][j]>0.0 then next end
      p = pat[i][j]
      if it<0 or it>wt-1 or jt<0 or jt>ht-1 then
        t = background
      else
        t = text[it][jt]
      end
      n += 1
      sum_p += p
      sum_t += t
      sum_pt += p*t
    }
  }
  p_mean = sum_p/n
  t_mean = sum_t/n
  return (sum_pt/n-p_mean*t_mean)/norm
end

def mean_product_simple_list_of_floats(a,b)
  if a.length!=b.length then die("unequal lengths") end
  norm = a.length.to_f
  sum = 0.0
  0.upto(a.length-1) { |i|
    sum += a[i]*b[i]
  }
  return sum/norm
end

def improve_hits_using_squirrel(hits,text_ink,bw_ink,red_ink,stats,threshold)
  controls = []
  w,h = ink_array_dimensions(text_ink)
  wp,hp = ink_array_dimensions(bw_ink)  
  1.upto(100) { |i|
    i = wp+rand(w-2*wp)
    j = hp+rand(h-2*hp)
    s,info = squirrel(text_ink,bw_ink,red_ink,i,j,stats)
    #print sprintf("    squirrel: i,j=%4d,%4d       s=%5.2f    control\n",i,j,s)
    controls.push(s)
  }
  mean,sd = find_mean_sd(controls)

  cooked = []
  hits.each { |x|
    c,i,j = x
    s,info = squirrel(text_ink,bw_ink,red_ink,i,j,stats)
    s = 1.23*(s-mean)/(1.0-mean) # The 1.23 is to make good matches stay about the same as with the basic correlation algorithm.
    next if s<threshold
    print sprintf("    squirrel: i,j=%4d,%4d  c=%5.2f   s=%5.2f    %s\n",i,j,c,s,info['image'])
    cooked.push([s,i,j])
  }

  return cooked
end

def squirrel(text_raw,pat_raw,red_raw,dx,dy,stats)
  # An experimental version of correl, meant to be slower but smarter, for giving a secondary, more careful evaluation of a hit found by correl.
  # text_raw, pat_raw, and red_raw are ink arrays
  # dx,dy are offsets of pat within text
  # stats should include the keys background, dark, and threshold, which refer to text
  w,h = ink_array_dimensions(pat_raw)

  background,threshold,dark = stats['background'],stats['threshold'],stats['dark']
  if background.nil? or threshold.nil? or dark.nil? then die("nil provided in stats as one of background,threshold,dark={[background,threshold,dark]}") end

  text_gray = extract_subarray_with_padding(text_raw,Box.new(dx,dx+w-1,dy,dy+h-1),background)
  # Make convenient arrays text, pat, and red that are full of the values 0 and 1 and are all the same size.
  text = array_elements_threshold(text_gray,threshold)
  pat = array_elements_threshold(pat_raw,0.5)
  red = array_elements_threshold(red_raw,0.5)

  filename = sprintf("squirrel%04d_%04d.png",dx,dy)
  #ink_array_to_image(text_gray).save(filename)

  norm = 0.0
  total = 0.0
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      if red[i][j]==1 then next end
      p = pat[i][j]
      t = text[i][j]
      wt = 1
      pp,tt = (p==1),(t==1) # boolean versions
      if (!pp) and (!tt) then wt=0.0; score=0.0 end # we don't care if they're both whitespace
      if (pp!=tt) then wt=1.0; score= -3.0 end      # we care a lot if one has ink and the other doesn't
      if pp and tt then wt=1.0; score= 1.0 end      # they both have ink in the same place
      norm += wt
      total += wt*score
    }
  }
  return [total/norm,{"image"=>filename}]
end
