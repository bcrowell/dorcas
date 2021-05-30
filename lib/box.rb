class Box
  def initialize(left,right,top,bottom)
    @left,@right,@top,@bottom = left,right,top,bottom
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
end
