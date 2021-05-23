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
