def array_of_zero_floats(n)
  return Array.new(n) { |i| 0.0 }
end

def array_subset?(a,b)
  # is a a subset of b?
  return a.to_set.subset?(b.to_set)
end

def extract_subarray(a,i_lo,i_hi,j_lo,j_hi)
  # crops, then pads with nil if necessary
  w,h = [i_hi-i_lo+1,j_hi-j_lo+1]
  return generate_array(w,h,lambda {|i,j| a[i][j]})
end

def extract_subarray_with_padding(a,box,pad_value)
  # pads with nil if necessary
  dx = box.left
  dy = box.top
  return generate_array(box.width,box.height,lambda {|i,j| array_sub(a,i+dx,j+dy,pad_value) })
end

def array_max(a)
  # very fast
  result = a[0][0]
  a.each { |col|
    m = col.max
    if m>result then result=m end
  }
  return result
end

def array_min(a)
  # very fast
  result = a[0][0]
  a.each { |col|
    m = col.min
    if m<result then result=m end
  }
  return result
end

def array_sub(a,i,j,default)
  # won't croak if i or j is out of bounds, will return default instead
  col = a[i]
  if col.nil? then return default end
  z = col[j]
  if z.nil? then return default end
  return z
end

def array_elements_threshold(a,threshold)
  # returns an array filled with the values 0 and 1
  w,h = array_dimensions(a)
  return generate_array(w,h,lambda {|i,j| if a[i][j]>threshold then 1 else 0 end})
end

def transform_array_elements_linearly!(x,a,b,min,max)
  0.upto(x.length-1) { |i|
    0.upto(x[i].length-1) { |j|
      z = x[i][j]
      z = a*z+b
      if z<min then z=min end
      if z>max then z=max end
      x[i][j] = z
    }
  }
end

def array_dimensions(b)
  # returns [width,height]
  return [b.length,b[0].length]
end

def scoot_array(b,dx,dy,value_for_padding)
  w,h = array_dimensions(b)
  a = generate_array(w,h,lambda {|i,j| value_for_padding})
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      ii = i+dx
      jj = j+dy
      if ii>=0 and ii<=w-1 and jj>=0 and jj<=h-1 then a[ii][jj]=b[i][j] end
    }
  }
  return a
end

def generate_array(w,h,fn,symm:false)
  a = []
  if symm and w!=h then die("symm is true, but w and h are unequal, w=#{w}, h=#{h}") end
  0.upto(w-1) { |i|
    col = []
    if symm then max_j=i else max_j=h-1 end
    0.upto(max_j) { |j|
      col.push(fn.call(i,j))
    }
    if symm then # Fill out the matrix with temporary dummy values so it's square.
      (max_j+1).upto(h-1) { |j|
        col.push(nil)
      }
    end
    a.push(col)
  }
  if symm then
    0.upto(w-1) { |i|
      (i+1).upto(h-1) { |j|
        a[i][j] = a[j][i]
      }
    }
  end
  return a
end

def array_to_string(a,indentation,format,fn:lambda {|x| x})
  lines = []
  0.upto(a.length-1) { |i|
    print "  ",(a[i].map {|x| if x.nil? then return "nil" else return  sprintf(format,fn.call(x)) end }).join(" "),"\n"
  }  
  return lines.join("\n")
end

def array_ascii_art(a,fn:lambda { |c| c})
  result = ''
  w,h = array_dimensions(a)
  0.upto(h-1) { |j|
    0.upto(w-1) { |i|
      #print "going in, display.class=#{display.class}\n"
      display = fn.call(a[i][j])
      #if i==19 && (j-31).abs<=3 then display='*' end
      #print "display.class=#{display.class}\n"
      if not display.kind_of?(String) then die("string not returned from user function") end
      result = result + display
    }
    result = result + "\n"
  }
  return result
end

def flip_array(a)
  w,h = array_dimensions(a)
  b = clown(a)
  0.upto(w-1) { |i|
    ii = w-1-i
    if i==ii then next end
    b[i] = a[ii]
    b[ii] = a[i]
  }
  return b
end

def four_point_2d_interp(a,x,y,method)
  # X and y are floating point values to be treated as if they were indices into the array a.
  # They should be in the ranges [0,w-1) and [0,h-1).
  # Return an interpolated value.
  # Method="nested" if a should be indexed as a[i][j], "comma" if it should be a[i,j].
  i = x.to_i
  j = y.to_i
  if method=='nested' then
    a1 = a[i][j]; a2 = a[i+1][j]; a3 = a[i][j+1]; a4 = a[i+1][j+1]
  else
    a1 = a[i,j]; a2 = a[i+1,j]; a3 = a[i,j+1]; a4 = a[i+1,j+1]
  end
  return four_point_2d_interp_helper(a1,a2,a3,a4,x,y)
end

def four_point_2d_interp_helper(a1,a2,a3,a4,x,y)
  # Let a1, ... a4 be four samples of a function on a square (top-left to bottom-right, 0,0 to 1,1).
  # Return an interpolated value at x,y.
  eps = 0.001
  wl = 1.0/(x.abs+eps)
  wr = 1.0/((1.0-x).abs+eps)
  wt = 1.0/(y.abs+eps)
  wb = 1.0/((1.0-y).abs+eps)
  return (a1*wl*wt+a2*wr*wt+a3*wl*wb+a4*wr*wb)/(wl*wt+wr*wt+wl*wb+wr*wb)
end
