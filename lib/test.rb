# This is meant to run various small, quick tests for functions that lend themselves
# well to this sort of thing.
# To run these, do "dorcas test".

def verb_test()
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
  assert_equal(boost_for_no_large_prime_factors(65536*7+1),460800) # 2^11 x 3^2 x 5^2 = 65536*7+2*2048
  print "Passed all tests.\n"
end

def assert_equal(x,y)
  assert(x==y,data:[x,y])
end

def assert(x,data:nil)
  if x then print "passed, data=#{data}\n"; return end
  die("failed test, see stack trace to find which test was failed, data=#{data}")
end

