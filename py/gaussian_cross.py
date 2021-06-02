import math,numpy

# Convolutions have good peaks that look like spikes.
# Bad matches tend to be more like horizontal or vertical streaks.
# Fit these features with a function of the form
#   C0 exp[-(x^2+y^2)/2sigma^2] + C1 exp[-(x^2)/2sigma^2] + C2 exp[-(y^2)/2sigma^2] + C3
# in a square window centered on the origin with diameter 2a.
# Here C0 is the height of the peak we want.
# Since this depends on the coefficients in a linear way, we can fit C0
# to the data by convoluting with a kernel of the form
#   K(x,y) = k0 f0 + k1 f1 + k2 f2 + k3 f3
# where f0, ... f3 are the functions defined above that look like exp[...].
# This is not yet integrated into the rest of the code, is just a stand-alone
# demo program for now.

def main():
  k = gaussian_cross_kernel_coefficients(5.0,3.0)
  print(k)

def gaussian_cross_kernel_coefficients(a,sigma):
  # Compute the coefficients k0,...k3 defined above.
  a = gaussian_feature_overlap(a,sigma)
  m = numpy.linalg.inv(a) # A is real and symmetric, so m is also real and symmetric
  return [m[0,0],m[1,0],m[2,0],m[3,0]]

def gaussian_feature_overlap(a,sigma):
  # Let e_pq = exp[-(px^2+qy^2)/2sigma^2], where p and q are 0 or 1.
  # Return a 4x4 matrix consisting of the overlap integrals of these four functions with each other over the square [-a,a]x[-a,a].  
  ov = numpy.zeros((4,4))
  for i in range(4):
    for j in range(4):
      p,q = gaussian_feature_overlap_helper3(i)
      r,s = gaussian_feature_overlap_helper3(j)
      ov[i,j] = gaussian_feature_overlap_helper(p,q,r,s,a,sigma)
  return ov

def gaussian_feature_overlap_helper(p,q,r,s,a,sigma):
  # Let e_pq = exp[-(px^2+qy^2)/2sigma^2], where p and q are 0 or 1.
  # Calculate Int_a^a Int_a^a e_pq e_rs dx dy.
  return gaussian_feature_overlap_helper2(p,r,a,sigma)*gaussian_feature_overlap_helper2(q,s,a,sigma)

def gaussian_feature_overlap_helper2(p,q,a,sigma):
  # Calculate Int_a^a exp[-(p+q) x^2/2sigma^2] dx, where p and q are 0 or 1.
  zeta = p+q
  if zeta==0:
    return 2*a
  else:
    return sigma*math.sqrt(2.0*math.pi/zeta)*math.erf((a/sigma)*math.sqrt(zeta/2.0))

def gaussian_feature_overlap_helper3(i):
  # Convert to indices p and q, which are 0 or 1, from a single, more convenient index.
  return {0:(1,1),1:(1,0),2:(0,1),3:(0,0)}[i]
  
  

main()
