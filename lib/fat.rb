module Fat
  # Provides mixins that are meant to improve performance by memoizing certain types of
  # data about an image. These can be mixed in to a ChunkyPNG object, or to any object
  # that provides methods #[](x, y), #height, and #width. If the memoizing is going to work, then the image
  # should be treated as immutable.

  attr_reader :threshold

  def Fat.bless(x,threshold)
    # Extend the object x with the Fat module's mixins, and set its threshold. The
    # threshold is a floating point ink value, 0=background, 1=dark ink.
    x.extend(Fat)
    x.set_threshold(threshold)
  end

  def set_threshold(threshold)
    @threshold = threshold
    @memoized = {}
  end
end
