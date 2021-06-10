def sum_of_array(a)
  return a.inject(0){|sum,x| sum + x } # https://stackoverflow.com/questions/1538789/how-to-sum-array-of-numbers-in-ruby
end

def find_mean_sd(x)
  sum = 0.0
  sum_sq = 0.0
  x.each { |a|
    sum += a
    sum_sq += a*a
  }
  n = x.length
  mean = sum/n
  mean_sq = sum_sq/n
  sd = Math::sqrt(mean_sq-mean*mean)
  return [mean,sd]
end

def find_sup_sub_median(x,x0)
  # Submedian is just my made-up term for the median of all data that lie below some value x0 (typically the mean).
  sub = find_median(x.select{ |a| a<=x0})
  sup = find_median(x.select{ |a| a>=x0})
  if sub.nil? then sub=x0 end
  if sup.nil? then sup=x0 end
  return [sub,sup]
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
  # returns [i,a[i]]
  return greatest_in_range(a,0,a.length-1)
end

def least(a)
  # returns [i,a[i]]
  return greatest_in_range(a,0,a.length-1,flip:-1)
end

def greatest_in_range(a,i_lo,i_hi,filter:lambda {|x| x},flip:1)
  # with flip=-1, returns the lowest
  g = nil
  ii = nil
  i_lo.upto(i_hi) { |i|
    if i<0 or i>a.length-1 then next end
    aa = filter.call(a[i])*flip
    if g.nil? or aa>g then ii=i; g=aa end
  }
  if g.nil? then return [nil,nil] end
  return [ii,g*flip]
end

def fraction_over_trigger_level(a,threshold)
  n = 0
  a.each { |x|
    if x>threshold then n += 1 end
  }
  return n.to_f/(a.length.to_f)
end
