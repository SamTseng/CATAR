#!/usr/bin/perl -s
package Stem;
# Next is a comment segment in POD format. Comment ends until '=cut'

=head1 NAME

Stem -- A package (and/or a class) for making stems of English words. 

=head1 SYNOPSIS

    use Stem;
    print Stem::stem('computers'), ', ', Stem::stem('computing'), "\n";
    print Stem::stem_lc('CompuTERs'), ', ', Stem::stem('cOMpUTING'), "\n";
    foreach (@ARGV) { push @A, Stem::stem($_); } print (join ', ', @A), "\n";
    
From 2005/06/19, stem() now only perform light stemming. That is, only
    common plural (passive) forms are reduced to their original forms.
Deep stemming (the previous version) needs an addtional flag, like these:
    use Stem;
    print Stem::stem('computers', 1), ', ', Stem::stem('computing', 1), "\n";
    print Stem::stem_lc('CompuTERs', 1), ', ', Stem::stem('cOMpUTING', 1), "\n";
    foreach (@ARGV) { push @A, Stem::stem($_,1); } print (join ', ', @A), "\n";
The 2nd argument indicates to perform deep stemming.


=head1 DESCRIPTION

    Stemmed words are often used as indexed terms in a search system.

    The stem code here is a conversion from a C program described in  
    "Information Retrieval : Algorithm and Data Structures, 1992", 
    which is actually Porter's stem algorithm.
    The Porter's stem algorithm performs deep stemming.
    On 2005/06/19, it was revised to perform light stemming by default.
    Original deep stemming requires an additional argument to do so.
  
Author:
    Yuen-Hsien Tseng. 
Date:
    1998/04/28, updated on: 2003/06/02, last updated on 2005/06/19.

=cut
    
    use Exporter;
    @ISA = qw(Exporter); # inherit class Exporter for exporting methods
    @EXPORT = qw(stem stem_lc); # export the methods in this package

    my(@Rules, @RulesDeep, @RuleLight);
    my(@Step, @StepDeep, @StepLight);

    @Rules = (
	101,	'sses',	'ss',	3,	1,	-1,	"",
#	102,	'ies',	'i',	2,	0,	-1,	"",
	102,	'ies',	'y',	2,	0,	-1,	"", # 2005/08/06
#	103,	'ss',	'ss',	1,	1,	-1,	"",
	103,	's',	'',	0,	-1,	-1,	"",
	0,	"",	"",	0,	0,	0,	"",

	104,	'eed',	'ee',	2,	1,	0,	"",
	105,	'ied',	'y',	2,	0,	-1,	'', # 2005/08/06
	106,	'ed',	'',	1,	-1,	-1,	'hasV',
	107,	'ing',	'',	2,	-1,	-1,	'hasV',
	0,	"",	"",	0,	0,	0,	"",

	108,	'at',	'ate',	1,	2,	-1,	"",
	109,	'bl',	'ble',	1,	2,	-1,	"",
	110,	'iz',	'ize',	1,	2,	-1,	"",
	111,	'bb',	'b',	1,	0,	-1,	"",
	112,	'dd',	'd',	1,	0,	-1,	"",
	113,	'ff',	'f',	1,	0,	-1,	"",
	114,	'gg',	'g',	1,	0,	-1,	"",
	115,	'mm',	'm',	1,	0,	-1,	"",
	116,	'nn',	'n',	1,	0,	-1,	"",
	117,	'pp',	'p',	1,	0,	-1,	"",
	118,	'rr',	'r',	1,	0,	-1,	"",
	119,	'tt',	't',	1,	0,	-1,	"",
	120,	'ww',	'w',	1,	0,	-1,	"",
	121,	'xx',	'x',	1,	0,	-1,	"",
	122,	'',	'e',	1,	0,	-1,	'AanE',
	0,	"",	"",	0,	0,	0,	"",

#	123,	'y',	'i',	0,	0,	-1,	'hasV',  # 05/08/06
	0,	"",	"",	0,	0,	0,	"",

	203,	'ational',	'ate',	6,	2,	0,	"",
	204,	'tional',	'tion',	5,	3,	0,	"",
	205,	'enci',		'ence',	3,	3,	0,	"",
	206,	'anci',		'ance',	3,	3,	0,	"",
	207,	'izer',		'ize',	3,	2,	0,	"",
	208,	'abli',		'able',	3,	3,	0,	"",
	209,	'alli',		'al',	3,	1,	0,	"",
	210,	'entli',	'ent',	4,	2,	0,	"",
	211,	'eli',		'e',	2,	0,	0,	"",
	213,	'ousli',	'ous',	4,	2,	0,	"",
#	214,	'ization',	'ize',	6,	2,	0,	"", # 05/08/06
#	215,	'ation',	'ate',	4,	2,	0,	"", # 05/08/06
	222,	'iviti',	'ive',	4,	2,	0,	"",
	223,	'biliti',	'ble',	5,	2,	0,	"",
	0,	"",		"",	0,	0,	0,	"",
	
	304,	'iciti',	'ic',	4,	1,	0,	"",
	305,	'ical',		'ic',	3,	1,	0,	"",
	0,	"",		"",	0,	0,	0,	"",
	
    );
    @Step = (0, 4, 9, 25, 26, 39);

    @RulesLight = (
	101,	'sses',	'ss',	3,	1,	-1,	"",
#	102,	'ies',	'i',	2,	0,	-1,	"",
	102,	'ies',	'y',	2,	0,	-1,	"", # 2005/08/06
#	103,	'ss',	'ss',	1,	1,	-1,	"",
	103,	's',	'',	0,	-1,	-1,	"",
	0,	"",	"",	0,	0,	0,	"",

	104,	'eed',	'ee',	2,	1,	0,	"",
	105,	'ied',	'y',	2,	0,	-1,	'', # 2005/08/06
	106,	'ed',	'',	1,	-1,	-1,	'hasV',
	107,	'ing',	'',	2,	-1,	-1,	'hasV',
	0,	"",	"",	0,	0,	0,	"",

	108,	'at',	'ate',	1,	2,	-1,	"",
	109,	'bl',	'ble',	1,	2,	-1,	"",
	110,	'iz',	'ize',	1,	2,	-1,	"",
	111,	'bb',	'b',	1,	0,	-1,	"",
	112,	'dd',	'd',	1,	0,	-1,	"",
	113,	'ff',	'f',	1,	0,	-1,	"",
	114,	'gg',	'g',	1,	0,	-1,	"",
	115,	'mm',	'm',	1,	0,	-1,	"",
	116,	'nn',	'n',	1,	0,	-1,	"",
	117,	'pp',	'p',	1,	0,	-1,	"",
	118,	'rr',	'r',	1,	0,	-1,	"",
	119,	'tt',	't',	1,	0,	-1,	"",
	120,	'ww',	'w',	1,	0,	-1,	"",
	121,	'xx',	'x',	1,	0,	-1,	"",
	122,	'',	'e',	1,	0,	-1,	'AanE',
	0,	"",	"",	0,	0,	0,	"",	
    );
    @StepLight = (0, 4, 9);
#    @StepLight = (0);


    @RulesDeep = (
	101,	'sses',	'ss',	3,	1,	-1,	"",
	102,	'ies',	'i',	2,	0,	-1,	"",
	103,	'ss',	'ss',	1,	1,	-1,	"",
	104,	's',	'',	0,	-1,	-1,	"",
	0,	"",	"",	0,	0,	0,	"",

	105,	'eed',	'ee',	2,	1,	0,	"",
	106,	'ed',	'',	1,	-1,	-1,	'hasV',
	107,	'ing',	'',	2,	-1,	-1,	'hasV',
	0,	"",	"",	0,	0,	0,	"",

	108,	'at',	'ate',	1,	2,	-1,	"",
	109,	'bl',	'ble',	1,	2,	-1,	"",
	110,	'iz',	'ize',	1,	2,	-1,	"",
	111,	'bb',	'b',	1,	0,	-1,	"",
	112,	'dd',	'd',	1,	0,	-1,	"",
	113,	'ff',	'f',	1,	0,	-1,	"",
	114,	'gg',	'g',	1,	0,	-1,	"",
	115,	'mm',	'm',	1,	0,	-1,	"",
	116,	'nn',	'n',	1,	0,	-1,	"",
	117,	'pp',	'p',	1,	0,	-1,	"",
	118,	'rr',	'r',	1,	0,	-1,	"",
	119,	'tt',	't',	1,	0,	-1,	"",
	120,	'ww',	'w',	1,	0,	-1,	"",
	121,	'xx',	'x',	1,	0,	-1,	"",
	122,	'',	'e',	1,	0,	-1,	'AanE',
	0,	"",	"",	0,	0,	0,	"",

	123,	'y',	'i',	0,	0,	-1,	'hasV',
	0,	"",	"",	0,	0,	0,	"",

	203,	'ational',	'ate',	6,	2,	0,	"",
	204,	'tional',	'tion',	5,	3,	0,	"",
	205,	'enci',		'ence',	3,	3,	0,	"",
	206,	'anci',		'ance',	3,	3,	0,	"",
	207,	'izer',		'ize',	3,	2,	0,	"",
	208,	'abli',		'able',	3,	3,	0,	"",
	209,	'alli',		'al',	3,	1,	0,	"",
	210,	'entli',	'ent',	4,	2,	0,	"",
	211,	'eli',		'e',	2,	0,	0,	"",
	213,	'ousli',	'ous',	4,	2,	0,	"",
	214,	'ization',	'ize',	6,	2,	0,	"",
	215,	'ation',	'ate',	4,	2,	0,	"",
	216,	'ator',		'ate',	3,	2,	0,	"",
	217,	'alism',	'al',	4,	1,	0,	"",
	218,	'iveness',	'ive',	6,	2,	0,	"",
	219,	'fulnes',	'ful',	5,	2,	0,	"",
	220,	'ousness',	'ous',	6,	2,	0,	"",
	221,	'aliti',	'al',	4,	1,	0,	"",
	222,	'iviti',	'ive',	4,	2,	0,	"",
	223,	'biliti',	'ble',	5,	2,	0,	"",
	0,	"",		"",	0,	0,	0,	"",
	
	301,	'icate',	'ic',	4,	1,	0,	"",
	302,	'ative',	'',	4,	-1,	0,	"",
	303,	'alize',	'al',	4,	1,	0,	"",
	304,	'iciti',	'ic',	4,	1,	0,	"",
	305,	'ical',		'ic',	3,	1,	0,	"",
	308,	'ful',		'',	2,	-1,	0,	"",
	309,	'ness',		'',	3,	-1,	0,	"",
	0,	"",		"",	0,	0,	0,	"",

	401,	'al',	'',	1,	-1,	1,	"",
	402,	'ance',	'',	3,	-1,	1,	"",
	403,	'ence',	'',	3,	-1,	1,	"",
	405,	'er',	'',	1,	-1,	1,	"",
	406,	'ic',	'',	1,	-1,	1,	"",
	407,	'able',	'',	3,	-1,	1,	"",
	408,	'ible',	'',	3,	-1,	1,	"",
	409,	'ant',	'',	2,	-1,	1,	"",
	410,	'ement','',	4,	-1,	1,	"",
	411,	'ment',	'',	3,	-1,	1,	"",
	412,	'ent',	'',	2,	-1,	1,	"",
	423,	'sion',	's',	3,	0,	1,	"",
	424,	'tion',	't',	3,	0,	1,	"",
	415,	'ou',	'',	1,	-1,	1,	"",
	416,	'ism',	'',	2,	-1,	1,	"",
	417,	'ate',	'',	2,	-1,	1,	"",
	418,	'iti',	'',	2,	-1,	1,	"",
	419,	'ous',	'',	2,	-1,	1,	"",
	420,	'ive',	'',	2,	-1,	1,	"",
	421,	'ize',	'',	2,	-1,	1,	"",
	0,	"",	"",	0,	0,	0,	"",

	501,	'e',	'',	0,	-1,	1,	"",
	502,	'e',	'',	0,	-1,	-1,	'RanE',
	0,	"",	"",	0,	0,	0,	"",

	503,	'll',	'l',	1,	0,	1,	"",
	0,	"",	"",	0,	0,	0,	""
    );
    @StepDeep = (0, 5, 9, 25, 27, 48, 56, 77, 80);

# private methed
sub WS {
    my($w) = @_;    my($s,$i,$n,$r);
    $n = length($w);	
    $s = $r = 0;
    for ($i=0; $i<$n; $i++) {
	if ($s==0) { 
	    $s = substr($w,$i,1) =~ /[aeiou]/o ? 1: 2;
	} elsif ($s==1) {
	    $s = substr($w,$i,1) =~ /[aeiou]/o ? 1: 2;
	    $r++ if ($s==2);
	} else {
	    $s = substr($w,$i,1) =~ /[aeiouy]/o ? 1: 2;
	}
    }
    return $r;
}

=head1 Methods

=head2 stem_lc() : convert to low-case and make stem for an English word

  $english_word_stem = stem_lc( $English_Word [, 1]);

  Convert an English word into a lower-case word and then convert the 
  lower-case word into a word stem.
  
  The 2nd argument indicates to perform deep stemming 
  (i.e., the original Porter's algorithm).
  If it is not provided, only light stemming is perform.

=cut
    sub stem_lc { return stem( lc shift , shift ); }


=head2 stem() : the main method to stem an English word

   $english_word_stem = stem( $english_word [, 1] );

   Convert an English word into a word stem. The input word should be 
   in lower case for correct stemming.
  
   The 2nd argument indicates to perform deep stemming 
   (i.e., the original Porter's algorithm).
   If it is not provided, only light stemming is perform.

=cut
sub stem {
    my($w, $StemLevel) = @_;  my($r, $s, $sn, $c, $f, $ws, $len, $at);
# Check to ensure the word is all alphabetic
    return $w if $w !~ /^[a-z]+$/o;
    return $w if length($w) <= 3; # 2005/08/06
    if ($StemLevel == 1)   { @Step = @StepDeep; @Rules = @RulesDeep; }
    elsif ($StemLevel == 0){ @Step = @StepLight; @Rules = @RulesLight; }
    $r = 0;
    for ($s=0; $s<@Step; $s++) {
	$s++ if ($s==2 && ($Rules[$r]!=106 && $Rules[$r]!=107));
	$r = $Step[$s] * 7;
	while ($Rules[$r] != 0) {
	    # next line is added on 2005/08/06
	    if ($w =~ /[aeious]s$/ and $Rules[$r] == 104) { $r += 7; next; }
	    $len = $Rules[$r+3] + 1; 
	    $at = length($w) - $len;
#	    if ($w =~ /$Rules[$r+1]$/) {
	    if (substr($w, $at, $len) eq $Rules[$r+1]) {
#		$c = $w;  $c =~ s/$Rules[ $r+1]$//;
		$c = substr($w, 0, $at); 
		$ws = &WS($c);
		if ($Rules[$r+5] < $ws) {
		    $sn = $Rules[$r+6]; # $sn : sub name
		    if ($sn eq 'hasV') { 
			$f = $c=~/^[aeiou]|\w+[aeiouy]/o && length($c)>2; 
		    } elsif ($sn eq 'AanE') { 
			$f = (1 == $ws) && ($c =~ /[^aeiouwxy][aeiouy][^aeiou]$/o);
		    } elsif ($sn eq 'RanE') { 
			$f = (1 == $ws) && ($c !~ /[^aeiouwxy][aeiouy][^aeiou]$/o);
		    }
		    if ($sn eq "" || $f) {
			$w = $c . $Rules[$r+2];
			last;
		    }
		}
	    }
	    $r += 7;
	} # End of while
    } # End of for
    return $w;
} # End of sub stem

1;
