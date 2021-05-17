default: chpl/correl
	./dorcas.rb

chpl/correl: chpl/correl.chpl
	chpl --fast -o chpl/correl chpl/correl.chpl
