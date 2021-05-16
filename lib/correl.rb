def correl(text,pat,red,bbox,dx,dy)
  # dx,dy are offsets of pat within text
  wp,hp = ink_array_dimensions(pat)
  wt,ht = ink_array_dimensions(text)

  # for speed: ignore columns in pat that have any red in them, not just red pixels
  red_in_col = []
  0.upto(wp-1) { |i|
    has_red = false
    0.upto(hp-1) { |j|
      if red[i][j]>0.0 then has_red=true; break end
    }
    red_in_col.push(has_red)
  }  

  norm = 0
  sum_p = 0.0
  sum_t = 0.0
  sum_pt = 0.0
  0.upto(wp-1) { |i|
    if red_in_col[i] then next end
    it = i+dx
    if it<0 or it>wt-1 then next end
    0.upto(hp-1) { |j|
      jt = j+dy
      if jt<0 or jt>ht-1 then next end
      if red[i][j]>0.0 then next end
      in_bbox = (i>=bbox[0] and i<=bbox[1] and j>=bbox[2] and j<=bbox[3])
      if in_bbox then w=1.0 else w=3.0 end # heuristic: if text has ink in white and outside bbox, penalize that a lot
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
