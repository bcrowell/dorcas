def correl_convenience(text_ink,pat,stats,box,line_spacing,threshold,max_hits,verbosity:1,give_details:false)
  # Returns a list of hits in the format [... [c,i,j,jb] ...], sorted in descending order by correlation score c.
  # (i,j) is the upper left corner where the swatch would be placed, while jb is the coordinate of the baseline.
  i_lo,i_hi,j_lo,j_hi = box.to_a
  bw_ink = image_to_ink_array(pat.bw)
  red_ink = image_to_ink_array(pat.red)
  pat_stats = ink_stats_pat(bw_ink,red_ink) # calculates mean and sd
  sdt = stats['sd_in_text']
  sdp = pat_stats['sd']
  norm = sdt*sdp # normalization factor for correlations
  text_line_spacing = stats['line_spacing']  
  scale = text_line_spacing/pat.line_spacing
  results = correl_many(text_ink,bw_ink,red_ink,stats['background'],i_lo,i_hi,j_lo,j_hi,text_line_spacing.to_i,norm)
  hits = filter_hits(results,pat.bboxo,box,threshold,max_hits,verbosity:verbosity)
  db = pat.baseline-pat.bbox[2]
  hits = hits.map {|x| [x[0],x[1],x[2],x[2]+db]}
  details = {}
  if give_details then details['heat']=results end
  return [hits,details]
end

def correl_many(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi,line_spacing,norm)
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

def correl_many_pure_ruby(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi)
  # returns results in [j][i] index order
  c = []
  dy_lo.upto(dy_hi) { |dy|
    print (dy*100.0/dy_hi).round," "
    if dy%30==0 then print "\n" end
    row = []
    dx_lo.upto(dx_hi) { |dx|
      row.push(correl(text,pat,red,background,dx,dy))
    }
    c.push(row)
  }
  return c
end

def correl(text,pat,red,background,dx,dy,norm)
  # dx,dy are offsets of pat within text
  wp,hp = ink_array_dimensions(pat)
  wt,ht = ink_array_dimensions(text)

  norm = 0
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
      norm += 1
      sum_p += p
      sum_t += t
      sum_pt += p*t
    }
  }
  p_mean = sum_p/norm
  t_mean = sum_t/norm
  return (sum_pt/norm-p_mean*t_mean)/norm
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
