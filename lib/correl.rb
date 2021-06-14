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

def squirrel(text_raw,pat,dx,dy,stats,max_scooch:1,smear:2,debug:false,k:3.0)
  # returns [score,data,scooch_x,scooch_y]
  # The registration adjustment is important. It has a big effect on scores, and the caller also needs to know the corrected position.
  # I'm not clear on why, but the max on the fft seems to be systematically off by about half a pixel up and to the left.
  # In cases where the error is 1 pixel horizontally on a character like l, this causes a huge effect on scores.
  # If debug is not nil, then it should be of the form [true,pat] or [false,...]. The place to set debug is in match.rb.
  # Text_raw should be a chunkypng object that has had the Fat mixin applied.
  if debug then 
    print array_ascii_art(pat.bw.bool_array,fn:lambda { |x| if x==true then '*' else if x.nil? then 'n' else ' ' end end} )
  end
  scores = []
  other = []
  (-max_scooch).upto(max_scooch) { |scooch_x|
    (-max_scooch).upto(max_scooch) { |scooch_y|
      s,data = squirrel_no_registration_adjustment(text_raw,pat,dx+scooch_x,dy+scooch_y,stats,smear,k,false)
      scores.push(s)
      other.push([data,scooch_x,scooch_y]) # data is [score,{"image"=>filename}], where filename is just for debugging
    }
  }
  i,s = greatest(scores)
  x = [scores[i]]
  x.concat(other[i])
  if debug then 
    # Rerun it once, with the optimum registration, just to get debugging output as requested.
    squirrel_no_registration_adjustment(text_raw,pat,dx+other[i][1],dy+other[i][2],stats,smear,k,false)
  end
  return x
end

def squirrel_no_registration_adjustment(text,pat,dx,dy,stats,smear,k,do_debug)
  # A modified version of correl, meant to be slower but smarter, for giving a secondary, more careful evaluation of a hit found by correl.
  # text is a chunkypng image that has had the Fat mixin applied.
  # Pat is a Pat object.
  # dx,dy are offsets of pat within text
  # k = multiplier to the penalty when image!=template
  # stats should include the keys background, dark, and threshold, which refer to text
  w,h = pat.width,pat.height
  tw,th = text.width,text.height

  background,threshold,dark = stats['background'],stats['threshold'],stats['dark']
  if background.nil? or threshold.nil? or dark.nil? then die("nil provided in stats as one of background,threshold,dark={[background,threshold,dark]}") end

  norm = 0.0
  total = 0.0
  if do_debug then terms=generate_array(w,h,lambda {|i,j| 0.0}) end
  0.upto(h-1) { |j|
    0.upto(w-1) { |i|
      next if pat.pink.ink?(i,j)
      ii,jj = i+dx,j+dy
      next if ii<0 || ii>tw-1 || jj<0 || jj>th-1
      pp = pat.bw.ink?(i,j)
      tt = text.ink?(ii,jj)
      wt = 1
      pn = pat.bw.ink?(i,j,radius:smear)
      tn = text.ink?(ii,jj,radius:smear)
      if do_debug && i==31 && j==h-1 then print "i=#{i} j=#{j} pp=#{pp} tt=#{tt} pn=#{pn} tn=#{tn}, smear=#{smear}\n" end
      # We don't care if they're both whitespace. Default to doing nothing unless something more special happens.
      wt=0.0
      score=0.0
      mismatch = ((!tn) && pp) || ((!pn) && tt)
      if mismatch then wt=1.0; score= -k end      # we care a lot if one has ink and the other doesn't
      if pp and tt then wt=1.0; score= 1.0 end      # they both have ink in the same place
      if do_debug then terms[i][j]=wt*score end
      norm += wt
      total += wt*score
    }
  }
  if do_debug then print array_ascii_art(terms,fn:lambda { |x| squirrel_ascii_art_helper(x) }) end

  return [total/norm,{}]
end

def squirrel_ascii_art_helper(x)
  r = x.round
  if r==0 then return ' ' end
  if r>0 then return '+' end
  if r<0 then return '-' end
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
