import math,numpy

# Convolutions have good peaks that look like spikes.
# Bad matches tend to be more like horizontal or vertical streaks.
# Fit these features with a function of the form
#   C0 exp[-(x^2+y^2)/2sigma^2] + C1 exp[-(x^2)/2sigma^2] + C2 exp[-(y^2)/2sigma^2] + C3
# in a square window centered on the origin with diameter 2a.
# I call this a "gaussian cross."
# Here C0 is the height of the peak we want.
# Since this depends on the coefficients in a linear way, we can fit C0
# to the data by convoluting with a kernel of the form
#   K(x,y) = k0 f0 + k1 f1 + k2 f2 + k3 f3
# where f0, ... f3 are the functions defined above that look like exp[...].
# There is some basic testing in gaussian_cross_test().
# Seems to work well in practice when the template is accurate. When the template
# is a poor match, the real peaks can be smeared out horizontally or vertically,
# which then makes the kernel reject them completely. To deal with this, I added
# the parameter laxness, which, if nonzero, lets through some fraction of the
# "ridges" as well as the peak.

def gaussian_cross_kernel(w,h,a,sigma,laxness):
  # a should be an integer
  # Returns a numpy array of the given size.
  # The kernel is positioned at the origin, which with wrap-around makes it appear
  # at the four corners of the resulting array. This choice makes it so that the
  # convolution in frequency domain doesn't displace features.
  small = gaussian_cross_kernel_small(a,sigma,laxness)
  ker = numpy.zeros((h,w))
  # ... gets transposed on conversion between numpy and PIL, see INTERNALS
  n = 2*a+1
  for i in range(n):
    for j in range(n):
      ii = (i-a)%w
      jj = (j-a)%h
      ker[jj,ii] = small[i,j]
  return ker

def gaussian_cross_kernel_small(a,sigma,laxness):
  # a should be an integer
  # Returns a numpy array with dimensions 2a+1 x 2a+1.
  k = gaussian_cross_kernel_coefficients(a,sigma,laxness)
  n = 2*a+1
  ker = numpy.zeros((n,n))
  for i in range(n):
    for j in range(n):
      for m in range(4):
        x = i-a
        y = j-a
        ker[i,j] = ker[i,j]+k[m]*gaussian_cross_kernel_f(m,sigma,x,y)
  return ker

def gaussian_cross_kernel_f(m,sigma,x,y):
  # Compute the function f_m(x,y) defined above.
  p,q = gaussian_feature_overlap_helper3(m)
  f = gaussian_cross_kernel_f_helper(p,x,sigma)
  g = gaussian_cross_kernel_f_helper(q,y,sigma)
  return f*g

def gaussian_cross_kernel_f_helper(p,x,sigma):
  if p==0:
    return 1.0
  else:
    return math.exp(-(x/sigma)**2/2.0)

def gaussian_cross_kernel_coefficients(a,sigma,laxness):
  # Compute the coefficients k0,...k3 defined above.
  a = gaussian_feature_overlap(a,sigma)
  m = numpy.linalg.inv(a).real # A is real and symmetric, so m is also real and symmetric, but make sure there 
                               # aren't imaginary parts due to rounding errors.
  return [m[0,0]+laxness*(m[0,1]+m[0,2]),m[1,0]+laxness*(m[1,1]+m[1,2]),m[2,0]+laxness*(m[2,1]+m[2,2]),m[3,0]+laxness*(m[3,1]+m[3,2])]

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
  
def gaussian_cross_test():
  # This can be run directly from a main() function.
  # Put in each of the four fitting components and test that I get back the right answer.
  # This is approximate because of discretization, but basically when I put in f0 I should
  # get C0=1, and when I put in fm for m!=0, I should get C0=0.
  a = 20
  sigma = 3.0
  ker = gaussian_cross_kernel_small(a,sigma)
  print(ker)
  n = 2*a+1
  for m in range(4):
    conv = 0.0
    for i in range(n):
      for j in range(n):
        x = i-a
        y = j-a
        conv = conv +ker[i,j]*gaussian_cross_kernel_f(m,sigma,x,y)
    print(f"f{m} convoluted with kernel gives C{m}={conv}")
