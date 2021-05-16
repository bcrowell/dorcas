def correl(text,pat,red,bbox,dx,dy,background)
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
      in_bbox = (i>=bbox[0] and i<=bbox[1] and j>=bbox[2] and j<=bbox[3])
      if in_bbox then w=1.0 else w=1.0 end # heuristic: if text has ink in white and outside bbox, penalize that a lot
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
