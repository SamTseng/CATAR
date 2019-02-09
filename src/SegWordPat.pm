#!/usr/bin/perl -s
package SegWordPat;
    use SAMtool::SegWord;
    @ISA = qw(SegWord); # inherit from class SegWord
    use SAMtool::Stem;
    use vars;  use strict;

# Next is a comment segment in POD format. Comment ends until '=cut'
=head1 NAME

SegWordPat -- A class for parsing and segmenting phrases for a patent.
	This class is derived from the class SegWord.

=head1 SYNOPSIS

    use SegWordPat;
    $seg = SegWordPat->new({'WordDir'=>'SAM/word', 'MaxRT'=>0, 'UseDic'=>0});
    Others are the same as "use SAMtool::SegWord;". 
    
=head1 DESCRIPTION

    To generate the comments surrounded by =head and =cut, run
	pod2html SegWordPat.pm > SegWordPat.html
    under MS-DOS.
    To know more about the methods provided, see SegWord.html for details.
        
Author:
    Yuen-Hsien Tseng.  All rights reserved.
Date:
    2003/05/17

=cut


=head2 SegWordPat->new( {'WordDir'=>'SAM/word', 'MaxRT'=>0, 'UseDic'=>0} );

  The constructor inherits SegWord.pm.

=cut
sub new {
    my($class, $rpara) = @_;
    $class = ref($class) || $class;
#print "in SegWordPat, new(), class=$class, class->SUPER=$class->SUPER\n";
    my $this = $class->SUPER::new($rpara);
    &ReadStopWord('StopPatWord-eng.txt'); # call $SegWord::Stop->AddESW()
    return $this;
}

# Use the module Stopword (used in SegWord.pm)
sub ReadStopWord {
    my($file) = @_;    local $/ = "\n";  my(@SList, $w, $t);
    @SList = keys %Stopword::ESW;
    foreach $w (@SList) { Stopword->AddESW(&Stem::stem(lc $w)); }
#print "Content-type: text/html\n\nSList=@SList<br>\n";
    open(F, "$file") or die("cannot open file:'$file' in &ReadStopWord()");
    while (<F>) { 
    	next if /^#/;   chomp;  
    	@SList = split ' ', $_;
    	foreach $w (@SList) {
    	    $t=lc $w;
	    Stopword->AddESW($t); 
	    Stopword->AddESW(&Stem::stem($t));
    	}
#print "stem(include)=", &Stem::stem('include'), ", SList=@SList<br>\n";
    }
    close(F);
#print "Stopword::ESW{include}=$Stopword::ESW{include}<br>\n";
}

=head2 $seg->PrepareLists();
 
  Given a segmented text, accumulate the word count, prepare the WordList for
  keyword extraction, prepare the sentence list for related term analysis and
  abstract extraction.

=cut
sub PrepareLists {
    my($this, $rSA) = @_;
    my($w, $Sen, $SenLength, $BreakPos, $BreakPosPrev);
    my(@WordList, %Words, $CWC, $EWC, %SN, @SenList);  
    my($para, $i, @Parenthesis); # 2004/08/21
    $Sen = 0; 
    $para = -1; $i = -1; # 2003/05/08, for counting paragraph number
    $SenLength = 0;
    $BreakPos = -1; 
    $BreakPosPrev = 0;
#print "<hr>PrepareList: ", (join ' ', @$rSA), "\n<hr>";
#    foreach $w (@$rSA) {
    for($i=0, $para=-1; $i<@$rSA; $i++) {
    	$w = $rSA->[$i];
    	$BreakPos++;
    	push @Parenthesis, $w if $w eq '('; # 2004/08/21
    	pop @Parenthesis if $w eq ')';
    	if ($w eq '<' and $rSA->[$i+1] eq 'pa' and $rSA->[$i+2] eq '>') {
    	    $para++; $i+=2;   $BreakPos += 2; $BreakPosPrev += 3;
    	    next; # 2003/05/08
    	}
    	if ($Stopword::Cmark{$w} or $Stopword::Emark{$w}) {
    	  if ($w eq '.' # and $rSA->[$i-1]=~/^[A-Z]$/ 
    	   and @Parenthesis > 0 # in a parenthesis
#    	   and $rSA->[$i+1]=~/^[A-Z]/ and not $Stopword::ESW{lc $rSA->[$i+1]}
    	  ) { # 2004/08/21
	    # may be the abbreviation of a name, do nothing
#print "P=@Parenthesis, rSA=", join(' ', @$rSA[($i-2)..($i+2)]), "<br>\n";
    	  } else {
	    push @WordList, "\n";
    	    if ($this->{'WantRT'} and ($w =~ /[\.\?\!]/ or
		$SenLength > $this->{'SenMaxLength'} or
		$w =~ /。|？|！/ # only valid for Big5 code
		)) {
		$SenLength = 0;
		$Sen++;
#		push @SenList,join' ',@$rSA[$BreakPosPrev..($BreakPos-1)];
		push @SenList,"<pa=$para>".join' ',@$rSA[$BreakPosPrev..$BreakPos];#2003/05
		$BreakPosPrev = $BreakPos + 1;
	    }
	    next;
	  }  
	}
# a valid term
	push @WordList, $w;
	$Words{$w}++;
	$SenLength++; 
	if ($w =~ /^\w/) { $EWC++; } else { $CWC++; }
    }
    if ($BreakPosPrev <= $BreakPos) {
   	push @SenList, "<pa=$para>".join ' ',@$rSA[$BreakPosPrev..$BreakPos];
    }
    if ($this->{'WantRT'}) { 
    	$this->{'MIthreshold'} = (1/log(2+@SenList));
#print"<p>MI thr=",$this->{MIthreshold}=(1/(0.1+log(2.7+@SenList))),"<br>\n"; 
    }
#print "<HR>SenList:<br>", (join "<p>\n", @SenList), "<br>\n";# if index($SenList[0], '五 金')>-1;
    return (\@WordList, \%Words, \@SenList, $CWC, $EWC);
} # End of &PrepareLists();


=head2 ($rWL, $rFL) = $seg->ClearPhrase( $rFL );

  Given a referece to a hash of extracted phrases, delete unreasonable terms

=cut
sub ClearPhrase {
    my($this, $rFL) = @_;
    my(@CWL, %CFL); # returned ref variables
    my($w, $f, $wAt, $len, $t1, $t2, $lcw); # temporary variables
#print "\n<p>ClearPhrase: <br>", (join ', ', sort keys %$rFL), "<hr>\n";
#print "\n<p>ClearPhrase: <br>", (join ', ', sort keys %Stop::StopHead), "<hr>\n";
#print "\n<p>ClearPhrase: <br>", (join ', ', sort keys %Stop::StopTail), "<hr>\n";
    while(($w, $f) = each %$rFL) {
# delete unreasonable terms
	next if length($w) > 512; # term to long
	next if $w =~ /^\W.$/; # if a single Chinese character
	next if $w =~ /^\W. [\w\-]+/o; # if 1st token is Chinese and 2nd is English

	$wAt = index($w, "\t");
#print "\n<p>Before : $w : $f, wAt=$wAt\n" if $w eq "之\t不 同" or $w eq '之 不 同' or $w eq "之\t不\t同" or $w eq "之 不\t同";
	next if $wAt>-1 and $Stopword::StopHead{substr($w,0,$wAt)};
#print "\n<p>After  : $w : $f, wAt=$wAt\n" if $w eq "之\t不 同" or $w eq '之 不 同' or $w eq "之\t不\t同" or $w eq "之 不\t同";
	$wAt = rindex($w, "\t");
	next if $wAt>-1 and $Stopword::StopTail{substr($w,$wAt+1,2)};

	$len = length($w);
	if ($len >= 5) {
#print "$w:Stop:$Stop::StopHead{substr($w,0,2)}<br>"if substr($w,0,2)eq'他';
	    next if $Stopword::StopHead{substr($w,0,2)} 
	     and defined($rFL->{substr($w, 3, $len-3)});
	    next if $Stopword::StopTail{substr($w,-2,2)}
	     and defined($rFL->{substr($w, 0, $len-3)});
	}

    	$w =~ tr/\t/ /; # convert tab into space
#print "\n<p>After2 : $w : $f, wAt=$wAt\n" if $w eq '之 不 同';
    	if ($w =~ /^\w/) {
    	    next if /ed$/; 
    	    $lcw = &Stem::stem(lc $w);
#    	    $lcw = (lc $w);
	    next if $Stopword::ESW{$lcw};
	    $wAt = index($w, ' ');
	    next if $wAt>-1 and $Stopword::ESW{substr($lcw, 0, $wAt)};
	    $wAt = rindex($w, ' ');
	    next if $wAt>-1 and
		$Stopword::ESW{substr($lcw, $wAt+1, length($w)-$wAt-1)};
	    next if $w =~ /^\d|^\w$/; # start with a digit or single letter
	    next if ($w =~ /^\d+$/o); # if single digits
    	    next if $w=~ /\.sub$|\.sub\s/; # 2003/05/08
    	} else { # Chinese
	    next if $Stopword::Cmark{$w};
	    next if $Stopword::CSW{$w};
	    next if $Stopword::CSW{substr($w,0,5)}; 
	    next if $Stopword::CSW{substr($w,-5,5)};
	    next if $Stopword::CSW{substr($w,0,8)}; 
	    next if $Stopword::CSW{substr($w,-8,8)};
	}
	next if ($w =~ / \d+$/o); # if end with digits
	next if ($w =~ tr/ / /) >= $this->{'MaxKeyWordLen'} ;
	$CFL{$w} = $f;
    }
    @CWL = sort {$CFL{$b} <=> $CFL{$a}} keys %CFL;
#print "WL=<br>ClearPhrase", (join ', ',map{"$_:$CFL{$_}"}sort@CWL),"<hr>\n";
    return (\@CWL, \%CFL); # %CFL contains the same number of words as @WL
} # End of &ClearPhrase()


=head2 ($rSWL, $rSFL) = $seg->ClearWord( $rSWL );

  Given a text or a reference to a segmented text, return
  reasonable segmented terms

=cut
sub ClearWord {
    my($this, $rSWL) = @_;      my(@SWL, %SFL, $w, $wAt, $lcw);
    $rSWL = &segment($rSWL) if not ref($rSWL);
    foreach $w (@$rSWL) { # delete unreasonable terms
	next if length($w) > 512; # term to long
	next if $Stopword::Emark{$w};
        if ($w =~ /^\w/) {
#	    next if $w =~ /^\d/;
	    $lcw = lc $w;
	    next if $Stopword::ESW{$lcw};
	    $wAt = index($w, ' ');
	    next if $wAt>-1 and $Stopword::ESW{substr($lcw, 0, $wAt)};
	    $wAt = rindex($w, ' ');
	    next if $wAt>-1 and
		$Stopword::ESW{substr($lcw, $wAt+1, length($w)-$wAt-1)};
	    next if $w=~ /\.sub$|\.sub\s/; # 2003/05/08
	} else { # Chinese
	    next if $Stopword::StopHead{substr($w,0,2)};
	    next if $Stopword::StopTail{substr($w,-2,2)};
#	    next if ($w =~ /^\W. \w+$/o); #if 1st token is Chi and 2nd is Eng
	    next if $Stopword::Cmark{$w};
	    next if $Stopword::CSW{$w};
#	    next if $Stopword::CSW{substr($w,0,8)};
#	    next if $Stopword::CSW{substr($w,0,5)};
#	    next if $Stopword::CSW{substr($w,-8,8)};
#	    next if $Stopword::CSW{substr($w,-5,5)};
	}
#	next if ($w =~ /\d+$/o); # if end with digits
#	next if ($w =~ tr/ / /) > 9;

# if exists POS and not Noun, Ver, or FW
#print "w='$w', pos=$TermPos{$w}<br>\n";
#	next if exists $TermPos{$w} and $TermPos{$w} !~ /^[NV]|^FW/o;

	$SFL{$w}++;
    }
    @SWL = sort { $SFL{$b} <=> $SFL{$a} } keys %SFL;
#print "ClearWord: ", join ',', @WL, "<br>\n";
#print "WL=<br>ClearWord : ", (join ', ',map{"$_:$FL{$_}"}sort@WL),"<hr>\n";
    return (\@SWL, \%SFL);
} # End of &ClearWord();



# ---------------- Begin of functions for Abstracting -----------
=head2 $seg->FilterTerms( $rTerm, $rTF );

  
=cut
sub FilterTerms {
    my($this, $rTerm, $rTF) = @_;  my($w, @A, %T, @Term, $sw, $ws, $n);
NextLoop: foreach $w (@$rTerm) {
    	@A = map {($_=~/^\w/)?&Stem::stem(lc $_):$_} split ' ', $w;
#    	@A = map {($_=~/^\w/)?(lc $_):$_} split ' ', $w;
    	next if $Stopword::ESW{$A[0]} or $Stopword::ESW{$A[-1]};
    	next if $Stopword::Emark{$A[-1]}; # 2004/08/21, ends with a punctuation
    	$n = 0;
    	foreach (@A) { 
	    if ($Stopword::ESW{$_}) { $n++; next NextLoop if $n>=2; }
    	    next NextLoop if /^\d+/;
    	}
    	next if $w =~ /ed$/; # escape if past tense
    	next if $w =~ /'s$/; # escape if ends up with 'someone's'
    	$T{join ' ', @A} .= "$w\t";
    }
    while (($sw, $ws) = each %T) {
    	@A = sort {$rTF->{$b} <=> $rTF->{$a}} split /\t/, $ws;
    	push @Term , $A[0]; # leave only those terms having largest TF
    }
    return \@Term;
}

# ------------------- Begin of functions for segmenting words -----------
=head2  $rTokenList = $seg->Tokenize( $text );

  Given a text string, parse it into all 1-character (1-word) token array.

=cut
sub Tokenize {
    my($this, $t) = @_;  my($i, $j, $k, $c, $len, @terms1);
    @terms1 = (); # returned ref variable
    $len = length($t);
#print "t=$t ===>\n\n";
	for ($j=0; $j<$len; $j++) {
	    if (ord(substr($t, $j, 1))>=128) {  # test for Chinese start byte
# split out Chinese word that has no space with English word
		for ($k=$j; $k<$len; $k+=2) {
		    last if (ord(substr($t, $k, 1))<128);
		    push @terms1, substr($t, $k, 2);
		}
	        $j = $k - 1;
	        next ;
	    }

# split out English word that has no space with Chinese word
	    $c = substr($t, $j, 1);
	    if ($c =~ /\W/o) {
#		push @terms1, '.' if $c eq '.';
		push @terms1, $c if $c ne ' '; #$c =~ /\(\),/; # 2003/05/08
		next; # push '.' for sentence delimiter
	    }
# Now it begins with an English letter
	    for ($k=$j+1; $k<$len; $k++) {
		next if substr($t, $k, 1) eq '-';
# The next 2 lines are added on Feb. 18, 2000 to allow terms like '0.18微米'
# They should be best controlled by options (users' decision)
		if (substr($t, $k, 3) =~ /\'s\W/o) { $k++; next ; }#2003/01/24
		if (substr($t, $k, 2) =~ /[.]\d/ ) { $k++; next ; }
#		if (substr($t, $k, 2) =~ /[.]\S/ ) { $k++; next ; }#2003/05/08
		if (substr($t, $k, 2) =~ /[.]\w/ ) { $k++; next ; }#2004/08/21
#		if (substr($t, $k, 2) =~ /[,.]\d/ ) { $k++; next; }
## Next line is changed into next next 2 lines for this package in old version
		last if (substr($t, $k, 1) =~ /\W/o);
#		last if (substr($t, $k, 1) =~ /\s/o);
#		last if (ord(substr($t, $k, 1)) > 127);
	    }
# Next line is changed into next next line for this package
#	    push @terms1, &STEMER::stem(lc substr($t, $j, $k-$j));
	    push @terms1, substr($t, $j, $k-$j) if $k-$j < 100;
		# $k-$j<100 is to assure a term so as not too long
	    $j = $k - 1;
	} # end of for($j=0;
# @terms1 has all 1-token in input order
#print "terms1=@terms1 ";
    return \@terms1;
} # End of &Tokenize()


1;
