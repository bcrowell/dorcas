default: chpl/correl
	./dorcas.rb

chpl/correl: chpl/correl.chpl
	chpl -o chpl/correl chpl/correl.chpl
