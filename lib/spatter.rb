class Spatter
  # Encapsulates a list of hits, with their spatial locations and scores, along with basic spatial
  # information such as estimated line spacing, maximum kerning, and interword spacing.
  # Putting this in a class is meant to make it easier to add functionality such as efficient searching.

  def initialize(hits,widths,spatial)
    @hits = clown(hits)
    @hits.each { |c,h|
      h = h.sort {|p, q| q[0] <=> p[0]} # sort in descending order by score; are probably sorted in decreasing order already, or approximately so
    }
    @spatial = spatial
    @widths = widths
  end

  def Spatter.from_hits_page_and_set(hits,page,set)
    # Hits should be a hash whose keys are characters and whose values are lists of hits in the format [score,x,y].
    # On input to the initializer, the x-y coordinates are the top-left corners of the templates, but after the object
    # is created we change those to the coordinates of the point where the baseline intersects the left side of the bounding box.
    # The page and set inputs are used only for extracting geometrical information.
    # Bracket a reasonable range for interword spacing. Convention is 1/3 em to 1/2 em, but will obviously vary in justified text.
    em = set.estimate_em
    min_interword = (0.3*em).round
    # ...based on general typographic practice
    max_interword = (0.53*em).round
    max_kern = (em*0.15).round # https://en.wikipedia.org/wiki/Kerning
    hits = clown(hits)
    hits.each { |c,h|
      h = h.map { |a| a[2]+=set.pat(c).baseline; a } # reference each hit to the baseline, not the upper left corner
      h = h.map { |a| a[1]+=set.pat(c).bbox[0]; a } # ... and to the left side of the bounding box
    }
    spatial = {'line_spacing'=>page.stats['line_spacing'],'max_w'=>set.max_w,'max_h'=>set.max_h,
                              'em'=>em,'min_interword'=>min_interword,'max_interword'=>max_interword,'max_kern'=>max_kern}
    widths = {}
    hits.keys.each { |c|
      pat = set.pat(c)
      widths[c] = pat.bbox_width
    }
    return Spatter.new(hits,widths,spatial)
  end

  attr_reader :hits,:spatial,:widths

  def line_spacing() self.spatial['line_spacing'] end
  def max_w() self.spatial['max_w'] end
  def max_h() self.spatial['max_h'] end
  def em() self.spatial['em'] end
  def min_interword() self.spatial['min_interword'] end
  def max_interword() self.spatial['max_interword'] end
  def max_kern() self.spatial['max_kern'] end

  def report
    return [stats_to_string({'line_spacing'=>self.line_spacing,'max_w'=>self.max_w,'max_h'=>self.max_h,'em'=>self.em,
                 'min_interword'=>self.min_interword,'max_interword'=>self.max_interword,'max_kern'=>self.max_kern}),
            stats_to_string({'top'=>self.top,'spread'=>self.spread,'total_hits'=>self.total_hits})
           ].join("\n  ")
  end

  def total_hits
    return self.hits.keys.map { |c| self.hits[c].length }.sum
  end

  def top
    if @top.nil? then @top=self.hits.keys.map { |c| maxmin_helper(self.hits[c],2,-1) }.min.round end
    return @top
  end

  def bottom
    if @bottom.nil? then @bottom=self.hits.keys.map { |c| maxmin_helper(self.hits[c],2,1) }.max.round end
    return @bottom
  end

  def spread
    # For a happy and well adjusted single line of text, this should be just a few pixels.
    return self.bottom-self.top
  end

  def plow
    # Return a list of new Spatter objects, each of which is estimated to be a line of text.
    # This is meant to be the dumbest algorithm that has any hope of working. Won't cope well if the text is rotated or lines are curved at all.
    if self.total_hits==0 then return [] end
    if self.spread<0.5*self.line_spacing then return [self] end
    # Make a histogram running along the vertical axis.
    f = 0.25 # each bin is this fraction of line spacing
    bin_width = (self.line_spacing*f).round
    if bin_width<1 then bin_width=1 end
    n_bins = (self.spread/bin_width.to_f).round
    if n_bins*bin_width<self.spread then n_bins+= 1 end
    histogram = array_of_zero_floats(n_bins)
    self.hits.each { |c,h|
      h.each { |hh|
        score,x,y = hh
        next if score<0.0
        if score>1.0 then wt=1.0 else wt=Math.exp(4.5*(score-1.0)) end # score of 0 has a weight of about exp(-4.5), ~1 % compared to score of 1
        bin = (y-self.top)/bin_width
        if bin<0 then bin=0 end
        if bin>histogram.length-1 then bin=histogram.length-1 end
        histogram[bin] += wt
      }
    }
    # Find the bin with the most weight, with a preference for the middle of the page.
    histogram2 = clown(histogram)
    0.upto(n_bins-1) { |i|
      histogram2[i] *= ([i,n_bins-1-i].min+n_bins/4)
    }
    bin,garbage = greatest(histogram2)
    if bin<n_bins/2 then direction=1 else direction = -1 end # if 1 then look for a break at y>y0, else y<y0
    ἐρημία = []
    0.upto((1.0/f).round-1) { |d|
      b = bin+direction*d
      next if b<0 || b>histogram.length-1
      ἐρημία[d] = histogram[b]
    }
    d,garbage = least(ἐρημία)
    b = bin+direction*d
    y_split = self.top+(b+0.5)*bin_width # approximate pixel coord of middle of bin
    s1 = self.select(lambda { |a| a[2]<=y_split})
    s2 = self.select(lambda { |a| a[2]>y_split})
    return s1.plow().concat(s2.plow())
  end

  def select(fn)
    new_hits = {}
    self.hits.each { |c,h|
      new_hits[c] = h.select {|a| fn.call([a[0],a[1],a[2],c])} # filter function sees [score,x,y,c]
    }
    return self.transplant_hits(new_hits)
  end

  def you_have_to_have_standards(threshold)
    return self.select(lambda { |a| a[0]>=threshold })
  end

  def transplant_hits(h)
    return Spatter.new(h,self.widths,self.spatial)
  end

end

def maxmin_helper(list,item_num,direction)
  if list.length==0 then return -direction*1.0e9 end
  if direction == -1 then
    return list.map { |e| e[item_num]}.min
  else
    return list.map { |e| e[item_num]}.max
  end
end
