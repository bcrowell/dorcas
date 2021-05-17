require 'fileutils'

def correl_many(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi)
  correl_many_chapel(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi)
end

def correl_many_chapel(text,pat,red,background,dx_lo,dx_hi,dy_lo,dy_hi)
  in_file = temp_file_name()
  out_file = temp_file_name()
  exe = 'chpl/correl'

  wp,hp = ink_array_dimensions(pat)
  wt,ht = ink_array_dimensions(text)
  File.open(in_file,'w') { |f| 
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

  system("#{exe} <#{in_file} >#{out_file}")

  c = []
  File.open(out_file,'r') { |f|
    dy_lo.upto(dy_hi) { |dy|
      row = []
      dx_lo.upto(dx_hi) { |dx|
        row.push(f.gets.to_f/(256.0*256.0))
      }
      c.push(row)
    }
  }

  FileUtils.rm(in_file)
  FileUtils.rm(out_file)

  return c

end

def ink_to_int(ink)
  return (ink*256).to_i # if changing this, also change the conversion factor applied to c when we read it back from the chapel code
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
