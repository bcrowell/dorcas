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
  assert_equal(convolve2("i 2,i 2,b +,o"),4)
  assert_equal(convolve2("i 5,i 2,b -,o"),3)
  assert_equal(convolve2("i 5,i 2,b *,o"),10)
  assert_equal(convolve2("i 69343957,i 37,b /,o"),1874161) # 36^5/37
  assert_equal(convolve2("f 2,f 2,b +,o"),4.0)
  assert_equal(convolve2("f 2,f 2,b -,o"),0.0)
  assert_equal(convolve2("f 2,f 3,b *,o"),6.0)
  assert_equal(convolve2("f 1,f 2,b /,o",to_int:false).to_f,0.5) # 1/2 has an exact binary representation
  assert_equal(convolve2("c hello,o",to_int:false),"hello\n")
  assert_equal(convolve2("i 137,d fine,r fine,o"),137)
  assert_equal(convolve2("i 5,d x,r x,r x,r x,b *,b *,o"),125)
  assert_equal(convolve2("c test/sample_tiny.png,read,i 0,o"),0)
  assert_equal(convolve2("c test/sample_tiny.png,read,u max,o"),218) # find max value of input file; checked in gimp
  assert_equal(convolve2("c test/sample_tiny.png,read_rot,u max,o"),218) # read with 180-degree rotation, max should be the same
  assert_equal(convolve2("c test/sample_tiny.png,read,u sum_sq,o"),3.8e6,tol:0.1e6) # find total energy in input file
  assert_equal(convolve2("c test/sample_tiny.png,read,d orig,r orig,u fft,u ifft,r orig,a -,u max,o"),0,tol:10.0)
  # ... test that we can do an fft and inverse fft and get back the original array
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

