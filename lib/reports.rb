def stats_to_string(stats)
  # used for both text stats and pat stats
  a = []
  stats.keys.sort.each { |k|
    x = stats[k]
    if x>0.01 and x<1.0 then 
      s = sprintf("%.3f",x)
    else
      if x>1.0 and x<1000 then
        s = sprintf("%.1f",x)
      else
        s = x.to_s
      end
    end
    a.push("#{k}:#{s}")
  }
  if a.length>=8 then
    a[6] = a[6] + "\n " 
    return "  "+a.join(" ")+"\n"
  else
    return a.join(" ")
  end
end

def ascii_scatterplot(data,save_to_file:nil)
  bins = 40
  s = generate_array(bins,bins,lambda { |i,j| 0})
  data.each { |p|
    x,y = p
    y = (y+2)*0.333
    x=(x*bins).round
    y=(y*bins).round
    y = bins-1-y
    if x<0 then x=0 end
    if x>bins-1 then x=bins-1 end
    if y<0 then y=0 end
    if y>bins-1 then y=bins-1 end
    s[x][y] += 1
  }
  result = array_ascii_art(s,fn:lambda {|x| if x==0 then ' ' else 'x' end})
  if !(save_to_file.nil?) then create_text_file(save_to_file,result) end
  return result
end
