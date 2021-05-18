default: chpl/correl lib/constants.rb
	./dorcas.rb

lib/constants.rb: lib/constants_pre_cpp.rb constants.h
	cpp -P lib/constants_pre_cpp.rb -o lib/constants.rb

chpl/correl: chpl/correl.chpl constants.h
	cpp -P chpl/correl.chpl -o chpl/correl_post_cpp.chpl
	chpl --fast -o chpl/correl chpl/correl_post_cpp.chpl
