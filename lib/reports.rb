def stats_to_string(stats)
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
  a[6] = a[6] + "\n "
  return "  "+a.join(" ")+"\n"
end
