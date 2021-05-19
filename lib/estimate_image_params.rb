def ink_stats(image)
  sample = random_sample(image,1000) # nothing bad happens if the image has less than 1000 pixels, we just get a smaller sample
  median = find_median(sample)
  min = sample.min
  max = sample.max
  submedian = find_submedian(sample,median)
  return {'median'=>median,'min'=>min,'max'=>max,'submedian'=>submedian}
end
