# This is meant to run various small, quick tests for functions that lend themselves
# well to this sort of thing.
# To run these, do "dorcas test".

def special_test
  #-----------------------------
  print "Running test code in special_test() rather than the actual tests. To run this, do a make test or dorcas test.\n"
  #-----------------------------
  max,ink,outfile = convolution_convenience_function("test.png","bw.png",0.2,norm:2.0,options:{'preserve_file'=>true})
  `mv #{outfile} a.png`
  print "outfile= a.png , max=#{max}\n"
  #-----------------------------
  print "Done running test code in special_test().\n"
  #-----------------------------
  exit(0)
end

def verb_test()
  # special_test()
  #----------------------------------------------------------------------------------------------
  print "Testing real_ink_bbox():\n"
  a = [[false,false,false,false],[true,false,false,false],[false,true,true,false],[false,false,false,false]] # [col1, col2, ...]
  b = real_ink_bbox(a)
  assert_equal(b.to_a,[1,2,0,2])
  #----------------------------------------------------------------------------------------------
  print "Testing split_by_scripts():\n"
  assert(compatible_scripts("a","a"))
  assert(!compatible_scripts("w","ξ"))
  assert(likely_cross_script_confusion("ξ","latin").nil?)
  assert(likely_cross_script_confusion("ν","latin")[0][0]=='v')
  assert(likely_cross_script_confusion("γ","latin")[0][0]=='y')
  assert(likely_cross_script_confusion("γ","latin",threshold:10).nil?)
  assert_equal(split_by_scripts(["the"]),["the"])
  assert_equal(split_by_scripts(["the","dog"]),["the","dog"])
  assert_equal(split_by_scripts(["the","κύον"]),["the","κύον"])
  assert_equal(split_by_scripts(["theκύον"]),["the","κύον"])
  assert_equal(split_by_scripts(["ηρχεbeganμυθων,"]),["ηρχε","began","μυθων,"])
  assert_equal(split_by_scripts(["a"]),["a"]) # single character
  assert_equal(split_by_scripts(["ξξξξξ"]),["ξξξξξ"]) # nothing needs to be fixed
  assert_equal(split_by_scripts(["flaξen"]),["fla","ξ","en"]) # no alternatives available
  assert_equal(split_by_scripts(["flγing"]),["flying"]) # y misread as gamma
  assert_equal(split_by_scripts(["γou"]),["you"])
  assert_equal(split_by_scripts(["boγ"]),["boy"])
  assert_equal(split_by_scripts(["άγyελος"]),["άγγελος"]) # latin to greek
  #----------------------------------------------------------------------------------------------
  print "Testing longest-path algorithm:\n"
  # ----
  # A trivial railroad, forced through two edges.
  e = [[0],[1],[2]]
  wt = [1,1]
  success,path,score,if_error,error_message = longest_path(e,wt)
  assert(success)
  assert_equal(path,[0,1])
  assert_equal(score,2.0)
  # ----
  # A graph that doesn't allow us to get all the way to the end. This is the railroad with one edge removed.
  e = [[0],[],[2]]
  wt = [3,1]
  success,path,score,if_error,error_message = longest_path(e,wt)
  assert(!success)
  assert_equal(path,[0])
  assert_equal(score,3.0)
  # ----
  # A diamond-shaped graph, choice between scores of 1+1 and 2+1.
  e = [[0,1],[2],[3],[4],[4]]
  wt = [2,1,1,1]
  success,path,score,if_error,error_message = longest_path(e,wt)
  assert(success)
  assert_equal(path,[0,2])
  assert_equal(score,3.0)
  # ----
  # The diamond with one edge removed, forming a dead end.
  e = [[0,1],[2],[3],[],[4]]
  wt = [2,1,1,1]
  success,path,score,if_error,error_message = longest_path(e,wt)
  assert(success)
  assert_equal(path,[1,3])
  assert_equal(score,2.0)
  # ----
  # A more complicated graph. The paths are [01], [234], and a dead-ending [25]. The dead end has a big weight, but we shouldn't pick it.
  e = [[0,2],[1],[6],[3,5],[4],[6],[]]
  wt = [3,5,-1,-1,11,100]
  success,path,score,if_error,error_message = longest_path(e,wt)
  assert(success)
  assert_equal(path,[2,3,4])
  assert_equal(score,9.0)
  # ----
  # An example that came up in practice (simpler version below).
  e=[[0], [1], [2, 3], [4], [], [5], [6], [], [8], [9]]
  wt=[0.42156862745098034, 0.47136038186157514, 0.5, 0.484, 0.5, 0.46371882086167804, 0.44160583941605835, 0.4672131147540983, 0.5]
  success,path,score,if_error,error_message = longest_path(e,wt)
  assert_equal(path,[0,1,2,4,5,6])
  assert(!success)
  # ----
  # Simplified version of the preceding one.
  e=[[0,1],[2],[],[],[4]]
  wt=[1,1,1,1]
  success,path,score,if_error,error_message = longest_path(e,wt)
  assert_equal(path,[0,2])
  assert(!success)
  #----------------------------------------------------------------------------------------------
  print "Testing canonicalization of json:\n"
  json1 = <<-'JSON'
  {
    "numbers": [333333333.33333329, 1E30, 4.50,
              2e-3, 0.000000000000000000000000001],
    "string": "\u20ac$\u000F\u000aA'\u0042\u0022\u005c\\\"\/",
    "literals": [null, true, false]
  }
  JSON
  json2 = <<-'JSON'
  {"literals":[null,true,false],"numbers":[333333333.3333333,1e+30,4.5,0.002,1e-27],"string":"€$\u000f\nA'B\"\\\\\"/"}
  JSON
  assert_equal(JSON.parse(json1).to_json_c14n,json2.gsub(/\s/,''))
  #----------------------------------------------------------------------------------------------
  print "Testing arithmetic for fft:\n"
  2.upto(10) { |n|
    #print "n=#{n}, result=#{boost_for_no_large_prime_factors(n)}\n"
    assert_equal(boost_for_no_large_prime_factors(n),n)
  }
  assert_equal(boost_for_no_large_prime_factors(11),12)
  assert_equal(boost_for_no_large_prime_factors(1024),1024)
  assert_equal(boost_for_no_large_prime_factors(1029),1029) # 1029=3 x 7^3
  assert(has_no_large_prime_factors(1050))
  assert_equal(boost_for_no_large_prime_factors(1050),1050) # 1050=2 x 3 x 5 x 5 x 7
  assert_equal(boost_for_no_large_prime_factors(1031),1050) # 1031 is prime
  assert_equal(boost_for_no_large_prime_factors(65536*7+1),460800)
  #     ... 2^11 x 3^2 x 5^2 = 65536*7+2*2048; this asserts the current behavior, not the theoretical optimum behavior
  #----------------------------------------------------------------------------------------------
  assert_equal(test_convolve("i 2,i 2,b +,o"),4)
  assert_equal(test_convolve("i 5,i 2,b -,o"),3)
  assert_equal(test_convolve("i 5,i 2,b *,o"),10)
  assert_equal(test_convolve("i 69343957,i 37,b /,o"),1874161) # 36^5/37
  assert_equal(test_convolve("f 2,f 2,b +,o"),4.0)
  assert_equal(test_convolve("f 2,f 2,b -,o"),0.0)
  assert_equal(test_convolve("f 2,f 3,b *,o"),6.0)
  assert_equal(test_convolve("f 1,f 2,b /,o",to_int:false).to_f,0.5) # 1/2 has an exact binary representation
  assert_equal(test_convolve("c hello,o",to_int:false),"hello\n")
  assert_equal(test_convolve("i 137,d fine,r fine,o"),137)
  assert_equal(test_convolve("i 5,d x,r x,r x,r x,b *,b *,o"),125)
  assert_equal(test_convolve("c test/sample_tiny.png,read,i 0,o"),0)
  assert_equal(test_convolve("c test/sample_tiny.png,read,u max,o"),218) # find max value of input file; checked in gimp
  assert_equal(test_convolve("c test/sample_tiny.png,read_rot,u max,o"),218) # read with 180-degree rotation, max should be the same
  assert_equal(test_convolve("c test/sample_tiny.png,read,u sum_sq,o",to_int:false).to_f,1.2e9,tol:0.1e9)
  #                  ... Find total energy in input file. This result is reasonable, since (w)(h)(256^2) is about 2e9.
  assert_equal(test_convolve("c test/sample_tiny.png,read,d orig,r orig,u fft,u ifft,r orig,a -,u max,o",to_int:false).to_f,0,tol:10.0)
  #                                               ... test that we can do an fft and inverse fft and get back the original image

  # A workout with a convolution. To inspect the output b.png visually, comment out the line saying "exit".
  # The output being tested is the color of a pixel in the result that is a peak of the convolution function.
  # I checked visually that the image made sense.
  code = <<-"CODE"
    c test/sample_tiny.png,read,     # signal...
    f -1,s *,f 205.0,s +,            #   pixel -> 205-pixel, i.e., invert grayscale (background is 205)
    u fft,                           #   fft
    i 1,i 1,high_pass,               #   filter out low-frequency background
    d f1,                            #   save
    c test/epsilon.png,read_rot,     # template...(read with rotation because that's how the convolution theorem works)
    i 224,i 148,f 255.0,bloat,       #   bloat with a white background color
    f -1,s *,f 255,s +,              #   pixel -> 255-pixel
    u fft,                           #   fft
    r f1,                            # bring back signal's spectrum
    a *,                             # multiply the signal and template in frequency domain
    u ifft,f 1.0e-8,s *,             # do an inverse fourier transform and renormalize
    noneg,
    f 3.4e3,s *,
    i 134,i 62,index,o,              # extract one pixel for testing purposes and write to output
    #exit,
    c b.png,write
  CODE
  assert_equal(test_convolve(code,to_int:false).to_f,201.0,tol:1.0)
  # Fiddle with gaussian cross peak detection.
  code = <<-"CODE"
    i 500,d w,                       # semi-arbitrary dimensiona to bloat everything to
    i 300,d h,                       #   ...
    c test/sample_tiny.png,read,     # signal...
    f -1,s *,f 205.0,s +,            #   pixel -> 205-pixel, i.e., invert grayscale (background is 205)
    r w,r h,f 0,bloat,               #   bloat
    u fft,                           #   fft
    i 1,i 1,high_pass,               #   filter out low-frequency background
    d f1,                            #   save
    c test/epsilon.png,read_rot,     # template...(read with rotation because that's how the convolution theorem works)
    f -1,s *,f 255,s +,              #   pixel -> 255-pixel
    r w,r h,f 0,bloat,               #   bloat with a white background color
    u fft,                           #   fft
    r f1,                            # bring back signal's spectrum
    a *,                             # multiply the signal and template in frequency domain
    r w,r h,i 10,f 3,f 0.0,gaussian_cross_kernel,  # generate a peak-detection kernel with the given a and sigma
    u fft,                           #    fft
    a *,                             #    convolve with that too
    u ifft,                          # do an inverse fourier transform
    noneg,
    dup,u max,s /,f 255,s *,         # renormalize
    #exit,
    c c.png,write
  CODE
  test_convolve(code)
  #----------------------------------------------------------------------------------------------
  print "Passed all tests.\n"
end

def assert_equal(x,y,tol:nil)
  if tol.nil? then
    assert(x==y,data:[x,y])
  else
    assert((x-y).abs<tol,data:[x,y,tol])
  end
end

def assert(x,data:nil)
  if x then print "  passed, data=#{data}\n"; return end
  die("failed test, see stack trace to find which test was failed, data=#{data}")
end

