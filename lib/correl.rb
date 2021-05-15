def correl(text,pat,red,dx,dy)
  # dx,dy are offsets of pat within text
  wp,hp = ink_array_dimensions(pat)
  wt,ht = ink_array_dimensions(text)
  norm = 0
  sum_p = 0.0
  sum_t = 0.0
  sum_pt = 0.0

  # for speed: ignore columns that have any red in them
  red_in_col = []
  0.upto(wp-1) { |i|
    has_red = false
    0.upto(hp-1) { |j|
      if red[i][j]>0.0 then has_red=true; break end
    }
    red_in_col.push(has_red)
  }  

  0.upto(wp-1) { |i|
    if red_in_col[i] then next end
    it = i+dx
    if it<0 or it>wt-1 then next end
    0.upto(hp-1) { |j|
      jt = j+dy
      if jt<0 or jt>ht-1 then next end
      if red[i][j]>0.0 then next end
      p = pat[i][j]
      t = text[it][jt]
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
