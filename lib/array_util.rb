def extract_subarray(a,i_lo,i_hi,j_lo,j_hi)
  w,h = [i_hi-i_lo+1,j_hi-j_lo+1]
  return generate_array(w,h,lambda {|i,j| a[i][j]})
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
