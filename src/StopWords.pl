# If you are processing Chinese texts, you may want to delete some un-wanted terms.
# Just add these un-wanted terms after __DATA__, one term in one line.
# The term must be in Big5 code, not UTF-8, and a white space be in-btwn two characters. 
sub SetStopWords { # Written on 2011/02/20 by Sam Tseng
	my($rDC, $seg) = @_; my($i) = (0);
	while (<DATA>) { chomp; $seg->AddCSW($_); $i++; } # read terms from __DATA__ section
	return $i; # return number of terms added to the stop word list
}

=comment until next =cut. # This is the same function, but less flexible and awkward
sub SetStopWords { my($rDC, $seg) = @_; $seg->AddCSW('計 畫'); $seg->AddCSW('本 計 畫'); 
$seg->AddCSW('原 計 畫'); $seg->AddCSW('本 計 畫 執'); $seg->AddCSW('執 行'); 
$seg->AddCSW('研 究');$seg->AddCSW('目 標');$seg->AddCSW('文 中'); $seg->AddCSW('委 員');
}
=cut

1;

__DATA__
計 畫
本 計 畫
原 計 畫
本 計 畫 執
目 標
執 行
研 究
文 中
委 員
