#
# Makefile for rbycp
#
# ycp compiler in Ruby
#

all: rbycp.rb Makefile

rbycp.rb: rbycp.y ycpscanner.rb
	racc -g -v -o $@ $<

clean:
	$(RM) rbycp.rb
	$(RM) core
	
distclean: clean
	$(RM) *~
	$(RM) *.output
	