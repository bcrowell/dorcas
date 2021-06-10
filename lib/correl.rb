def correl(text,pat,red,background,dx,dy,norm)
  # Simple correlation. Somewhat useful because it's efficient and has a meaningful absolute normalization.
  # We also use this as a measure of similarity when clustering results in pattern learning mode.
  # All input images are ink arrays.
  # Seems to work well if norm is the product of the sd of this particular pattern multiplied by sd_in_text from ink stats.
  # dx,dy are offsets of pat within text
  wp,hp = ink_array_dimensions(pat)
  wt,ht = ink_array_dimensions(text)

  n = 0
  sum_p = 0.0
  sum_t = 0.0
  sum_pt = 0.0
  0.upto(wp-1) { |i|
    it = i+dx
    0.upto(hp-1) { |j|
      jt = j+dy
      if red[i][j]>0.0 then next end
      p = pat[i][j]
      if it<0 or it>wt-1 or jt<0 or jt>ht-1 then
        t = background
      else
        t = text[it][jt]
      end
      n += 1
      sum_p += p
      sum_t += t
      sum_pt += p*t
    }
  }
  p_mean = sum_p/n
  t_mean = sum_t/n
  return (sum_pt/n-p_mean*t_mean)/norm
end

def mean_product_simple_list_of_floats(a,b)
  if a.length!=b.length then die("unequal lengths") end
  norm = a.length.to_f
  sum = 0.0
  0.upto(a.length-1) { |i|
    sum += a[i]*b[i]
  }
  return sum/norm
end

def squirrel(text_raw,pat_raw,red_raw,dx,dy,stats,max_scooch:1,smear:2,debug:nil,k:3.0)
  # returns [score,data,scooch_x,scooch_y]
  # The registration adjustment is important. It has a big effect on scores, and the caller also needs to know the corrected position.
  # I'm not clear on why, but the max on the fft seems to be systematically off by about half a pixel up and to the left.
  # In cases where the error is 1 pixel horizontally on a character like l, this causes a huge effect on scores.
  scores = []
  other = []
  (-max_scooch).upto(max_scooch) { |scooch_x|
    (-max_scooch).upto(max_scooch) { |scooch_y|
      s,data = squirrel_no_registration_adjustment(text_raw,pat_raw,red_raw,dx+scooch_x,dy+scooch_y,stats,smear,k,debug)
      scores.push(s)
      other.push([data,scooch_x,scooch_y])
    }
  }
  i,s = greatest(scores)
  x = [scores[i]]
  x.concat(other[i])
  return x
end

def squirrel_no_registration_adjustment(text_raw,pat_raw,red_raw,dx,dy,stats,smear,k,debug)
  # An experimental version of correl, meant to be slower but smarter, for giving a secondary, more careful evaluation of a hit found by correl.
  # text_raw, pat_raw, and red_raw are ink arrays
  # dx,dy are offsets of pat within text
  # k = multiplier to the penalty when image!=template
  # stats should include the keys background, dark, and threshold, which refer to text
  # If debug is not nil, it should be a Pat object.
  w,h = ink_array_dimensions(pat_raw)

  background,threshold,dark = stats['background'],stats['threshold'],stats['dark']
  if background.nil? or threshold.nil? or dark.nil? then die("nil provided in stats as one of background,threshold,dark={[background,threshold,dark]}") end

  text_gray = extract_subarray_with_padding(text_raw,Box.new(dx,dx+w-1,dy,dy+h-1),background)
  # Make convenient arrays text, pat, and red that are full of the values 0 and 1 and are all the same size.
  text = array_elements_threshold(text_gray,threshold)
  pat = array_elements_threshold(pat_raw,0.5)
  red = array_elements_threshold(red_raw,0.5)

  do_debug = ! (debug.nil?)
  if do_debug then
    pat_obj = debug
    filename = sprintf("squirrel%04d_%04d.png",dx,dy)
    v = pat_obj.visual(black_color:ChunkyPNG::Color::rgba(0,0,255,130),red_color:ChunkyPNG::Color::rgba(255,0,0,130))
    #v.save("sqv_"+filename)
    ii = ink_array_to_image(text_gray)
    ii = compose_safe(ii,v,0,0)
    ii.save(filename)
  end

  norm = 0.0
  total = 0.0
  if debug then terms=generate_array(w,h,lambda {|i,j| 0.0}) end
  0.upto(h-1) { |j|
    0.upto(w-1) { |i|
      if red[i][j]==1 then next end
      p = pat[i][j]
      t = text[i][j]
      wt = 1
      pp,tt = (p==1),(t==1) # boolean versions
      pn = squirrel_helper_has_neighbor(pat,w,h,i,j,smear)
      tn = squirrel_helper_has_neighbor(text,w,h,i,j,smear)
      # We don't care if they're both whitespace. Default to doing nothing unless something more special happens.
      wt=0.0
      score=0.0
      mismatch = ((!tn) && pp) || ((!pn) && tt)
      if mismatch then wt=1.0; score= -k end      # we care a lot if one has ink and the other doesn't
      if pp and tt then wt=1.0; score= 1.0 end      # they both have ink in the same place
      if debug then terms[i][j]=wt*score end
      norm += wt
      total += wt*score
    }
  }
  if debug then print array_ascii_art(terms,fn:lambda {|x| {0=>' ',1=>'+',-3=>'-'}[x.round]}) end
  return [total/norm,{"image"=>filename}]
end

def squirrel_helper_has_neighbor(x,w,h,i,j,radius)
  (-radius).upto(radius) { |di|
    (-radius).upto(radius) { |dj|
      ii = i+di
      jj = j+dj
      if ii<0 or ii>w-1 or jj<0 or jj>h-1 then next end
      if x[ii][jj]==1 then return true end
    }
  }
  return false
end
