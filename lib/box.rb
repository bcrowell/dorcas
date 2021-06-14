class Box
  def initialize(left,right,top,bottom,force_ints:true)
    if force_ints then
      @left,@right,@top,@bottom = left.round,right.round,top.round,bottom.round
    else
      @left,@right,@top,@bottom = left,right,top,bottom
    end
  end

  attr_accessor :left,:right,:top,:bottom

  def to_a
    return [@left,@right,@top,@bottom]
  end

  def to_s
    return "LRTB = #{[@left,@right,@top,@bottom]}"
  end

  def width
    return @right-@left+1
  end

  def height
    return @bottom-@top+1
  end

  def Box.from_image(image)
    return Box.new(0,image.width-1,0,image.height-1)
  end

  def Box.from_a(a)
    return Box.new(a[0],a[1],a[2],a[3])
  end

  def intersection(q)
    horiz = intersection_of_intervals([@left,@right],[q.left,q.right])
    vert  = intersection_of_intervals([@top,@bottom],[q.top,q.bottom])
    return Box.new(horiz[0],horiz[1],vert[0],vert[1])
  end

  def empty?
    return self.left>self.right || self.top>self.bottom
  end

  def contains?(x,y)
    return (x>=self.left and x<=self.right and y>=self.top and y<=self.bottom)
  end

  def fatten(h)
    # returns a new object
    x = clown(self)
    x.left -= h
    x.right += h
    x.top -=h
    x.bottom +=h
    return x
  end
end

def intersection_of_intervals(a,b)
  return [    [a[0],b[0]].max , [a[1],b[1]].min     ]
end
