default:
	echo "There is no default"

chapel: chpl/correl chpl/shotgun lib/constants.rb
	echo "..."

lib/constants.rb: lib/constants_pre_cpp.rb constants.h
	cpp -P lib/constants_pre_cpp.rb -o lib/constants.rb

chpl/correl: chpl/correl.chpl constants.h
	cpp -P chpl/correl.chpl -o chpl/correl_post_cpp.chpl
	chpl --fast -o chpl/correl chpl/correl_post_cpp.chpl

chpl/shotgun: chpl/shotgun.chpl constants.h
	cpp -P chpl/shotgun.chpl -o chpl/shotgun_post_cpp.chpl
	chpl --fast -o chpl/shotgun chpl/shotgun_post_cpp.chpl
