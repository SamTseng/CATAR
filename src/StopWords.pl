# If you are processing Chinese texts, you may want to delete some un-wanted terms.
# Just add these un-wanted terms after __DATA__, one term in one line.
# The term must be in Big5 code, not UTF-8, and a white space be in-btwn two characters. 
sub SetStopWords { # Written on 2011/02/20 by Sam Tseng
	my($rDC, $seg) = @_; my($i) = (0);
	while (<DATA>) { chomp; $seg->AddCSW($_); $i++; } # read terms from __DATA__ section
	return $i; # return number of terms added to the stop word list
}

=comment until next =cut. # This is the same function, but less flexible and awkward
sub SetStopWords { my($rDC, $seg) = @_; $seg->AddCSW('�p �e'); $seg->AddCSW('�� �p �e'); 
$seg->AddCSW('�� �p �e'); $seg->AddCSW('�� �p �e ��'); $seg->AddCSW('�� ��'); 
$seg->AddCSW('�� �s');$seg->AddCSW('�� ��');$seg->AddCSW('�� ��'); $seg->AddCSW('�e ��');
}
=cut

1;

__DATA__
�p �e
�� �p �e
�� �p �e
�� �p �e ��
�� ��
�� ��
�� �s
�� ��
�e ��
