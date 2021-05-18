require 'fileutils'
require 'json'

def correl_many(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi)
  start = Time.now
  result = correl_many_chapel(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi)
  finish = Time.now
  print "\ntime for correl = #{finish-start} seconds\n"
  return result
end

def correl_many_chapel(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi)
  exe = 'chpl/correl'
  n_rows = dy_hi-dy_lo+1
  n_cpus = guess_n_cores() # making this equal to the number of physical cores (not counting hypertrheading) gives the best performance
  rows_per_cpu = n_rows/n_cpus
  if rows_per_cpu*n_cpus<n_rows then rows_per_cpu += 1 end
  max_rows = constants()['correl_max_h']
  print "rows_per_cpu=#{rows_per_cpu} max_rows=#{max_rows}\n" # qwe
  if rows_per_cpu>max_rows then die("rows_per_cpu=#{rows_per_cpu} is greater than CORREL_MAX_H") end

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
    remember_slicing.push([this_dy_lo,this_dy_hi])
    file_base = temp_file_base+"-#{cpu}"
    in_file = file_base+".in"
    out_file = file_base+".out"
    files_to_remove.push(in_file)
    files_to_remove.push(out_file)
    out_files.push(out_file)
    prep_chapel_input(in_file,text,pat,red,background,dx_lo,dx_hi,this_dy_lo,this_dy_hi)
  }

  cmd = "ls #{temp_file_base}*.in | taskset --cpu-list 0-#{n_cpus-1} parallel --verbose #{exe} \"<\"{} \">\"{.}.out"
  print cmd,"\n"
  system(cmd)

  cpu = 0
  result = []
  out_files.each { |filename|
    this_dy_lo,this_dy_hi = remember_slicing[cpu]
    cpu +=1
    this_result = retrieve_chapel_output(filename,dx_lo,dx_hi,this_dy_lo,this_dy_hi)
    this_result.each { |row|
      result.push(row)
    }
  }

  files_to_remove.each { |filename|
    FileUtils.rm(filename)
  }

  return result
end

def prep_chapel_input(filename,text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi)
  wp,hp = ink_array_dimensions(pat)
  wt,ht = ink_array_dimensions(text)
  File.open(filename,'w') { |f| 
    f.print "#{wt}\n#{ht}\n#{wp}\n#{hp}\n"
    f.print "#{dx_lo}\n#{dx_hi}\n#{dy_lo}\n#{dy_hi}\n"
    f.print "#{ink_to_int(background)}\n"
    0.upto(ht-1) { |j|
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
end

def retrieve_chapel_output(out_file,dx_lo,dx_hi,dy_lo,dy_hi)
  c = []
  File.open(out_file,'r') { |f|
    err = f.gets;
    message = f.gets;
    if err!=0 then die(message) end
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

def correl(text,pat,red,background,dx,dy)
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
  return sum_pt/norm-p_mean*t_mean
end
