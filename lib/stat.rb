def sum_of_array(a)
  return a.inject(0){|sum,x| sum + x } # https://stackoverflow.com/questions/1538789/how-to-sum-array-of-numbers-in-ruby
end

def find_median(x) # https://stackoverflow.com/a/14859546
  return nil if x.empty?
  sorted = x.sort
  len = sorted.length
  return (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
end

def find_percentile(x,f)
  return nil if x.empty?
  sorted = x.sort
  len = sorted.length
  i = ((len-1)*f).to_i # this could be improved as in find_median()
  return sorted[i]
end

def greatest(a)
  g = -2*(a[0].abs)
  ii = nil
  0.upto(a.length) { |i|
    if not a[i].nil? and a[i]>g then ii=i; g=a[i] end
  }
  return [ii,g]
end
