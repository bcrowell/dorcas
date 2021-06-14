module Fat
  # Provides mixins that are meant to improve performance by memoizing certain types of
  # data about an image. These can be mixed in to a ChunkyPNG object, or to any object
  # that provides methods #[](x, y), #height, and #width. 
  # If the memoizing is going to work, then the image should be treated as immutable.

  attr_reader :threshold

  def Fat.bless(x,threshold)
    # Extend the object x with the Fat module's mixins, and set its threshold. The
    # threshold is a floating point ink value, 0.0=background, 1.0=dark ink.
    # In later use, we assume that the image itself has a #[](x,y) method that returns
    # values that can be used as inputs to color_to_ink(), whose output is then what we
    # compare to threshold.
    x.extend(Fat)
    x.set_threshold(threshold)
  end

  def set_threshold(threshold)
    @threshold = threshold
    @memoized = [] # @memoized[0] is the boolean version of the original, @memoized[1] is for radius=1, etc.
  end

  def ink?(i,j,radius:0)
    # Returns a boolean. If radius is 0, tells us whether the original image has ink at (i,j).
    # If radius is 1, tells us if it or any of its neighbors have ink.
    if radius<@memoized.length then return @memoized[radius][i][j] end
    # print "memoization failed, radius=#{radius}\n"
    if radius==0 then
      r0 = generate_array(self.width,self.height,lambda {|i,j| color_to_ink(self[i,j])>@threshold })
      @memoized = [r0]
      return r0[i][j]
    end
    # Recurse:
    rn = @memoized[0].clone # just make another boolean array with the same shape
    w,h = self.width,self.height
    0.upto(w-1) { |x|
      0.upto(h-1) { |y|
        has_neighbor = false
        (-1).upto(1) { |di|
          ii = x+di
          next if ii<0 || ii>w-1
          (-1).upto(1) { |dj|
            jj = y+dj
            next if jj<0 || jj>h-1
            if self.ink?(ii,jj,radius:radius-1) then has_neighbor=true; next end
          }
          next if has_neighbor
        }
        rn[x][y] = has_neighbor
      }
    }
    @memoized.push(rn)
    return rn[i][j]
  end
end
