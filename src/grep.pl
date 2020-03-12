#!/usr/bin/env perl -s
# C:\CATAR_src\Source_Data\SC_LIS>perl -s ..\..\src\grep.pl "Upham" data/*/*.txt
	($pat, $files) = @ARGV;
	@ARGV = glob($files);
	print "pat=$pat, ARGV=@ARGV\n\n";
	print "file:line Num: matched line\n";
	while (<>) { print "$ARGV:$.: $_" if /$pat/; }
	
# To convert an English string into capitalized string, try this command:
# perl -e "print join ' ', map{ucfirst lc} split ' ','JOURNAL OF THE AMERICAN SOCIETY FOR INFORMATION SCIENCE AND TECHNOLOGY'"
# Journal Of The American Society For Information Science And Technology