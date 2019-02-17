#!/usr/bin/perl -s
package SegWord;

=head1 NAME

  SegWord - Segment a given text, produce some good terms.

=head1 SYNOPSIS

    use SAMtool::SegWord;
    $seg = SegWord->new( {'WantRT'=>1, 'UseDic'=>0} );

    $seg->Value('WantRT', 0); # set WantRT to 0
    $True_or_False = $seg->Value('WantRT'); # get WantRT

    $rSegText = $seg->segment( $text ); # return a list of segment words

    $ref_to_tokenized_text = $seg->Tokenize( $text ); # return a ref to a list
    $rSegText = $seg->segment( $ref_to_tokenized_text );

    ($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
     $rLinkValue, $rSenList) = $seg->ExtractKeyPhrase( $text_or_ref_to_text );

    $rSentenceRank = $seg->RankSenList($rWL, $rFL, $rSN, $rSenList);
    print "The first rank sentence is $rSenList->[ $rSentenceRank->[0] ]\n";    

    $rNewLinkValue = $seg->TrimLink($rLinkValue, $rFL);


    Next are for creaing some auxiliary files for segmenting Chinese words.
    
    use SAMtool::SegWord;
    &SegWord::InsertSpace('stopword-chi.txt', 'new-stopword-chi.txt');
    &SegWord::CreateTPS($TermPosFile, $TPSDBfile);
    &SegWord::CreateDicDBM('word/wordlist.txt', 'WL.db', 'WLWL.db');

=head1 DESCRIPTION

    This module is to segment a string a text and return key terms, 
    indexed terms, identified names, analyzed related terms, 
    segmented sentences, and ranked sentences. 
    
Author:
    Yuen-Hsien Tseng.  All rights reserved.
    
Date:
    1998/06/13

=cut

  use SAMtool::Stopword;
  use strict;  use vars;
# Next are class (not object) variables, used for segmenting Chinese words.
  my %DIC = ();
  my %WLen = ();
  my %CASCII = ();
  my %CForeign = ();
  my %CSurname = ();
  my %CSurname2 = ();
  my %CNumbers = ();
  my %UnCommonSurname = ();
  my %CNotName = ();


# ------------------- Begin of functions for initialization -----------

=head1 Methods

=head2 new() : the construtor

  $obj = segWord->new( {'Attribute_Name'=>'Attribute_Value',...} );

  Attributes in an object in Perl is often saved in a referece to a hash.
  A reference to a no-name hash is donated as '{ }', as shown in 
    SegWord->new( { 'Attribute_Name'=>'Attribute_Value' }  );

  The attributes in the object can be directly given in the constructor's 
  argumnets in a key=>value format. 
  The attribute names and values are:
    WordDir(path in a file system),
    UseDic(1 or 0), WantRT(1 or 0), MaxRT(positive int), MaxKeyWordLen(int),
    MinKWlevel(positive int), MinKW(postive int), SenMaxLength(positive int),
    MIthreshold(float), NorMIthreshold(float).

  Omitted attribute pairs will be given default values.
  
  Two files are required before this class can be used: 
    1. WL.db
    2. WLWL.db
  The 2 files are created from 'wordlist.txt' using the tools provided
  in this class. 
  In the earlier version (in SAM), all these data files should be saved 
  in a directory specified in the attribute: 'WordDir'. (Normally set 'WordDir' 
  to 'SAM/word' and  put these data files in 'SAM/word' under the current 
  directory or under one of the directories in @INC.)
  But in this version (SAMtool), the 'WordDir' attribute is no longer necessary
  since the only 2 data file WL.db and WLWL.db are placed under the same 
  directory where SAMtool is installed.

=cut

sub new {
    my($class, $rpara) = @_; 
    $class = ref($class) || $class; # ref() return a package name
    my $this = bless( {}, $class ); # same as  $this={}; bless $this, $class;
#print "in &new(): ref(\$rpara)='", ref($rpara), "'\n";
    $this->Init($rpara) ; # if ref($rpara); # 2003/11/09
    &Stopword::new();
    return $this;
}


=head2 Init() : initialization function

  $seg->Init(); or $seg->Init( { 'WordDir'=>'word', 'WantRT'=>1 } );

  Initialize some variables in this package by reading some files 
  given in new().

  If the variables are set in &new(), you don't need to call this method.

  If in &new(), you set no variables, you should call this method
  to set the variables.

  Or even if in &new() you have already set some variables, you can still 
  redefine these variables by calling this method with arguments, like this:
    $seg->Init( {
                'DicDBfile'  => 'WL.db'
                'DicWLfile'  => 'WLWL.db'
    } );

=cut

sub Init {
    my($this, $rpara) = @_; my($k, $v, $dir);
#print "in &Init(): ref(\$rpara)='", ref($rpara), "'\n";
    if (ref($rpara)) {
	while (($k, $v) = each %$rpara) { $this->{$k} = $v; }
    }

    $this->{'UseDic'} = 1 if not defined $this->{'UseDic'};
    $this->{'WantRT'} = 1 if not defined $this->{'WantRT'};
    # 'WantRT' must be 1 if abstract is needed.
    $this->{'MaxRT'} = 12 if not defined $this->{'MaxRT'};
    $this->{'MinKWlevel'} = 2 if not defined $this->{'MinKWlevel'};
    $this->{'MinKW'} = 5 if not defined $this->{'MinKW'};
    $this->{'MIthreshold'} = 0.4 if not defined $this->{'MIthreshold'};
    $this->{'NorMIthreshold'} = 0.01 if not defined $this->{'NorMIthreshold'};
    $this->{'SenMaxLength'} = 100 if not defined $this->{'SenMaxLength'};
    $this->{'MaxKeyWordLen'} = 9 if not defined $this->{'MaxKeyWordLen'};
#    $this->{'Eng_Seg_Phrase'} = 0 if not defined $this->{'Eng_Seg_Phrase'};

=Comment : this block is no more used
    if ($this->{'DicDBfile'} eq '') {
	foreach $dir (@INC, map{"$_/SAMtool"}@INC) { 
	    if (-e "$dir/WL.db") {
		$this->{'DicDBfile'} = "$dir/WL.db";
		$this->{'DicWLfile'} = "$dir/WLWL.db";
		last;
	    } 
	}
    }
#print "INC=@INC, DBfile='$this->{'DicDBfile'}'\n";
    use Fcntl;  use DB_File;
    tie(%DIC, 'DB_File',"$this->{'DicDBfile'}", O_RDONLY, 0, $DB_BTREE)
	||(print "Cannot read DBM:'$this->{DicDBfile}', " and die $!);
    tie(%WLen, 'DB_File',"$this->{'DicWLfile'}", O_RDONLY, 0, $DB_BTREE)
	||(print "Cannot read DBM:'$this->{DicWLfile}', " and die $!);
    if (not $this->{'UseDic'}) { untie %DIC; untie %WLen; }
# 'untie' should be used, not 'undef' nor %DIC=(). The later do'nt work.
#print "UseDic='", $this->{'UseDic'}, "', \$DIC{'¬ü °ê'}=$DIC{'¬ü °ê'}<br>\n";
=cut

    &SetWLHash(\%DIC, \%WLen) if $this->{'UseDic'};
# Next is reserved for future segmentation by POS
#    $this->{'TPSDBfile'} = 'TPS.db' if not defined $this->{'TPSDBfile'};
#    tie(%TermPos,'DB_File',"$TPSDBfile", O_RDONLY, 0, $DB_BTREE)
#	||(print "Err:$!" and die $!);
    $this->SetHashes();
    $this->{DIC} = \%DIC; # 2006/06/21
}


=head2 Value() : A generic Set and Get method for all scalar attributes.

  This method is a generic Set and Get. 
  Examples: 
      $seg->Value('WantRT', 0);
      $True_or_False = $seg->Value('WantRT'); # get WantRT
  All scalar attributes should work. Consult new() for all possible attributes.

=cut

sub Value {
    my($this, $attribute, $value) = @_;
    if ($value ne '') {
        my $old = $this->{$attribute};
        $this->{$attribute} = $value;
        return $old;
    } else {
        return $this->{$attribute};
    }
}



# --- Begin of functions for extracting key phrases and related terms ---

=head2 ExtractKeyPhrase() : the main method for keywords/terms/abstaction

  ($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, $rLinkValue, 
  $rSenList) = $seg->ExtractKeyPhrase( $text or $ref_to_segmented_text );

  Given a text or a ref to a segmented text array, return key terms, 
    indexed terms, identified names, analyzed related terms, 
    segmented sentences, and ranked sentences.

=cut

sub ExtractKeyPhrase {
    my($this, $rSA) = @_;
    my(@IWL, %IFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
       $rLinkValue, $rSenList); # returned variables
    my($w, $ws, $f, @RWL, $rRWL); # temparay variables

    $rSA = $this->segment($rSA) if not ref($rSA); # get segmented text
    $rName = $this->{'Name'}; # set in &ProcessUnKnown() of &segment()
    ($rSWL, $rSFL) = $this->ClearWord($rSA); # delete unreasonable terms
    ($rFL, $rSenList) = $this->keyphrase($rSA); 
    # get key-phrases from segmented text
    ($rWL, $rFL) = $this->ClearPhrase($rFL); # delete unreasonable key-phrases

# Below merge terms from &ClearWord() and &ClearPhrase()
    %IFL = %$rFL; # First, copy terms in %$rWL to %$rIFL
    foreach $w (@$rSWL) { # Second, copy terms in @$rSWL to %$rIFL.
    	next if $rFL->{$w}; # escape if already in key phrases
	$IFL{$w} = $rSFL->{$w}; # copy dictionary term to the index hash
    }
# Now we have indexed terms in @IWL and %IFL after the above steps.
    @IWL = sort {$IFL{$b} <=> $IFL{$a}} keys %IFL;
# Process related terms and abstract
    if ($this->{'WantRT'}) {
	@RWL = @$rWL[0..((@$rWL>$this->{'MaxRT'})?$this->{'MaxRT'}:@$rWL-1)];
	$rRWL = \@RWL;
	$rSN = $this->SetSN($rRWL, $rSenList);
	$rLinkValue = $this->SetTermLink($rRWL, $rSN, $rSenList); 
    }
    
# If there are only a few keywords, take keywords from Index words
# This will let short documents to still have keywords for suggestion.
    if (@$rWL < $this->{'MinKWlevel'}) { 
    	@$rWL = @IWL[0..(@IWL>$this->{'MinKW'}?$this->{'MinKW'}:$#IWL)]; 
    	undef $rFL;
    	foreach $w (@$rWL) { $rFL->{$w} = $IFL{$w}; }
    }

#    return (\@IWL, \%IFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
#             $rLinkValue, $rSenList);
    return (\@IWL, \%IFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
             $rLinkValue, $rSenList, $this->{CoSenIdx});
} # End of &ExtractKeyPhrase



# ------------- Begin of functions for extracing key phrases -----------

=head2 keyphrase() : extract keyword/keyphrase from a given text

  ($rTerm, $rSenList) = $seg->keyphrase( $text or $ref_to_segmented_text );

  Given a text or a ref to a text, return extracted key-phrases, sentences in a
  list, and inverted sentence list (word=>"Sentence_no1 Sentence_no2 ...")

=cut

sub keyphrase {
    my($this, $rSA) = @_;
    $rSA = $this->segment($rSA) if not ref($rSA);
    my($rWordList, $rWords, $rSenList, $CWC, $EWC) = $this->PrepareLists($rSA);
    my $rFL = $this->ConcateTerm($rWordList, $rWords, $CWC, $EWC);
    return ($rFL, $rSenList);
} # End of &keyphrase();


=head2 PrepareLists() : prepare for keyword/term/abstraction extraction

  ($rWordList, $rWords, $rSenList, $CWC, $EWC) = $seg->PrepareLists( $text );

  Given a segmented text, accumulate the word count, prepare the WordList for
  keyword extraction, prepare the sentence list for related term analysis and
  abstract extraction.

=cut

sub PrepareLists {
    my($this, $rSA) = @_;
    my($w, $Sen, $SenLength, $BreakPos, $BreakPosPrev);
    my(@WordList, %Words, $CWC, $EWC, %SN, @SenList);
    $Sen = 0;
    $SenLength = 0;
    $BreakPos = -1; 
    $BreakPosPrev = 0;
#print "<hr>PrepareList: ", (join ', ', @$rSA), "\n";
    foreach $w (@$rSA) {
    	$BreakPos++;
    	if ($Stopword::Cmark{$w} or $Stopword::Emark{$w}) {
	    push @WordList, "\n";
#    	    if ($this->{'WantRT'} and ($w =~ /[\.\?\!]/ or
    	    if (($w =~ /[\.\?\!]/ or # 2004/01/26
		$SenLength > $this->{'SenMaxLength'} or
		$w =~ /¡C|¡H|¡I/ # only valid for Big5 code
		)) {
		next if $BreakPos-$BreakPosPrev < 10; # if too short
		$SenLength = 0;
		$Sen++;
		push @SenList, join ' ', @$rSA[$BreakPosPrev..$BreakPos];
		$BreakPosPrev = $BreakPos + 1;
	    }
	    next;
	}
	push @WordList, $w; # a valid term
	$Words{$w}++;
	$SenLength++;
	if ($w =~ /^\w/) { $EWC++; } else { $CWC++; }
    }
    if ($BreakPosPrev <= $BreakPos) {
   	push @SenList, join ' ', @$rSA[$BreakPosPrev..$BreakPos];
    }
    if ($this->{'WantRT'}) { 
    	$this->{'MIthreshold'} = (1/log(2+@SenList));
#print"<p>MI thr=",$this->{MIthreshold}=(1/(0.1+log(2.7+@SenList))),"<br>\n"; 
    }
#print "<HR>SenList:<br>", (join "<p>\n", @SenList), "<br>\n";# if index($SenList[0], '¤­ ª÷')>-1;
    return (\@WordList, \%Words, \@SenList, $CWC, $EWC);
} # End of &PrepareLists();


=head2 ConcateTerm() : merge longer terms back with the patented algorithm

  $rFL = $seg->ConcateTerm($rWordList, $rWords, $CWC, $EWC);

  Given a prepare word list and word count, merge token back to get 
  (multi-token) key-phrases, using the patented algorithm developed 
  by Yuen-Hsien Tseng (Sam).

=cut

sub ConcateTerm {
    my($this, $rWordList, $rWords, $CWC, $EWC) = @_;
    my($CminWF, $EminWF, $lp, $NoW1, $NoW2, $x, $xf, %FL);
#    if ($Cauto) { $CminWF = int(log($CWC)/log(10) - 0.5) if $CWC > 10; }
#    if ($Eauto) { $EminWF = int(log($EWC)/log(10) - 0.5)-1 if $EWC > 10; }
    $CminWF = 1 if ($CminWF<1);  $EminWF = 1 if ($EminWF<1);
# Merge tokens until no more is left
    $lp = 0; %FL= (); # used ref var, outside this package
    $rWords->{"\n"} = 0; # 2006/05/15
    do {
    	$lp++;
#print "<hr>", join ', ', map {$_.':'.$rWords->{$_}} @$rWordList,"<br>\n";
	&Concate(\%FL, $rWordList, $rWords, $CminWF, $EminWF);
 # Delete unnecessary keywords in %$rWords to save memory space
	foreach $x (keys %$rWords) { # delete items that are no longer used
	    $xf = $x =~ tr/\t/\t/;
	    if ($xf < $lp) { 
		delete($rWords->{$x});
	    }
	}
#print"<p>Final:<br>",(join"<br>",map{"$_:$FL{$_}"}sort keys%FL),"<p>\n";
    } until (@$rWordList < 2) or $lp >= 10;
    return \%FL;
} # End of &ConcateTerm()


# Use: $EminWF, $CminWF, @WordList, %Words. Set: %FL
# %TmpWord is introduced (not the the patented algorithm) to prevent from
# missing some key-phrases. The use of %TmpWord is based on a hunch by Sam.
sub Concate { # private
    my($rFL, $rWordList, $rWords, $CminWF, $EminWF) = @_;
    my($i, $x, $y, $c, $xn, $yn, $xf, $yf, $xAt, $yAt);
    my($minf, $minWF, @MergeList, %TmpWord);
    $yn = 1; # Record if last $y has merged or not, 0 for yes, 1 for not yet
    push(@$rWordList, "\n"); # as a sentinel in the next (merging) step
    $x = "\n";
    foreach $y (@$rWordList) {
#	if (substr($x, -1, 1) eq "\n") {  $yn = 1;  $x = $y; next;  }
	if (substr($x, -1, 1) eq "\n") {  # 2006/05/15
	    $xn = $yn; $x = $y; $yn = 1;  
	    push(@MergeList, "\n") if $MergeList[$#MergeList] ne "\n";
	    next;  
	}
	if ($x =~ /\w$/o && $y =~ /^\w/o) { $minWF = $EminWF;
	} else { $minWF = $CminWF; }
	$xf = $rWords->{$x}; $yf = $rWords->{$y};
	$xn = $yn; $yn = 1;
	$minf = ($xf<$yf)?$xf:$yf;
	if ($minf > $minWF) { # They can be merged
# Next line is replaced by next next 2 lines
#	    $yAt=rindex($y, ' '); $c = $x . substr($y, $yAt, length($y)-$yAt);
	    $yAt=rindex($y, "\t")+1; # a tab
	    $c = $x . "\t" . substr($y, $yAt, length($y)-$yAt);
	    $rWords->{$c} += 1;  
	    $TmpWord{$c}++;
	    push(@MergeList, $c);
	    $yn = 0;
	} else {
	    if ($xn  &&  $xf > $minWF) { # accept it
		$rFL->{$x} = $rWords->{$x} unless(defined($rFL->{$x}));
	    }
            push(@MergeList, "\n") if $MergeList[$#MergeList] ne "\n";
        }
        $x = $y; # shift $y to $x for next loop
    } # End of for each pair of @WordList
    @$rWordList = (); @$rWordList = @MergeList;
    while (($c, $xf) = each %TmpWord) {
    	if ($xf == 1) { # restore the legal substrings
    	    $xAt = rindex($c, "\t");
    	    $x = substr($c, 0, $xAt);
    	    $rFL->{$x} = $rWords->{$x};
#    	    $yAt = index($c, "\t")+1;
#    	    $y = substr($c, $yAt, length($c)-$yAt);
#    	    $rFL->{$y} = $rWords->{$y};
    	}
    }
} # End of &Concate()


=head2 ClearPhrase() : clear extracted phrases

  ($rWL, $rFL) = $seg->ClearPhrase( $rFL );

  Given a referece to a hash of extracted phrases, delete unreasonable terms

=cut

sub ClearPhrase {
    my($this, $rFL) = @_;
    my(@CWL, %CFL); # returned ref variables
    my($w, $f, $wAt, $len, $t1, $t2, $lcw); # temporary variables
#print "\n<p>ClearPhrase: <br>", (join ', ', sort keys %$rFL), "<hr>\n";
#print "\n<p>ClearPhrase: <br>", (join ', ', sort keys %Stopword::StopHead), "<hr>\n";
#print "\n<p>ClearPhrase: <br>", (join ', ', sort keys %Stopword::StopTail), "<hr>\n";
    while(($w, $f) = each %$rFL) {
# delete unreasonable terms
	next if $w =~ /^\s+$/; # delete empty word
	next if length($w) > 512; # term to long
	next if $w =~ /^\W.$/; # if a single Chinese character
	next if $w =~ /^\W. [\w\-]+/o; # if 1st token is Chinese and 2nd is English

	$wAt = index($w, "\t");
#print "\n<p>Before : $w : $f, wAt=$wAt\n" if $w eq "¦¹ ®×" or $w eq '¤§ ¤£ ¦P' or $w eq "¤§\t¤£\t¦P" or $w eq "¤§ ¤£\t¦P";
	next if $wAt>-1 and $Stopword::StopHead{substr($w,0,$wAt)};
#print "\n<p>After  : $w : $f, wAt=$wAt\n" if $w eq "¦¹ ®×" or $w eq '¤§ ¤£ ¦P' or $w eq "¤§\t¤£\t¦P" or $w eq "¤§ ¤£\t¦P";
	$wAt = rindex($w, "\t");
	next if $wAt>-1 and $Stopword::StopTail{substr($w,$wAt+1,2)};

	$len = length($w);
	if ($len >= 5) {
#print "$w:$Stopword::StopHead{substr($w,0,2)}<br>"if substr($w,0,2)eq'¥L';
	    next if $Stopword::StopHead{substr($w,0,2)} 
	     and defined($rFL->{substr($w, 3, $len-3)});
	    next if $Stopword::StopTail{substr($w,-2,2)}
	     and defined($rFL->{substr($w, 0, $len-3)});
	}

    	$w =~ tr/\t/ /; # convert tab into space
#print "\n<p>After2 : $w : $f, wAt=$wAt\n" if $w eq '¤§ ¤£ ¦P';
    	if ($w =~ /^\w/) {
    	    $lcw = lc $w;
	    next if $Stopword::ESW{$lcw};
	    $wAt = index($w, ' ');
	    next if $wAt>-1 and $Stopword::ESW{substr($lcw, 0, $wAt)};
	    $wAt = rindex($w, ' ');
	    next if $wAt>-1 and
		$Stopword::ESW{substr($lcw, $wAt+1, length($w)-$wAt-1)};
	    next if $w =~ /^\d|^\w$/; # start with a digit or single letter
    	} else { # Chinese
	    next if $Stopword::Cmark{$w};
	    next if $Stopword::CSW{$w};
	    next if $Stopword::CSW{substr($w,0,5)};
	    next if $Stopword::CSW{substr($w,-5,5)};
	    next if $Stopword::CSW{substr($w,0,8)};
	    next if $Stopword::CSW{substr($w,-8,8)};
	}
	next if ($w =~ / \d+$/o); # if end with digits
	next if ($w =~ tr/ / /) >= $this->{'MaxKeyWordLen'}; # if key too long
	$CFL{$w} = $f;
    }
    @CWL = sort {$CFL{$b} <=> $CFL{$a}} keys %CFL;
#print "WL=<br>ClearPhrase", (join ', ',map{"$_:$CFL{$_}"}sort@CWL),"<hr>\n";
    return (\@CWL, \%CFL); # %CFL contains the same number of words as @WL
} # End of &ClearPhrase()


=head2 ClearWord() : clear extracted index terms

 ($rSWL, $rSFL) = $seg->ClearWord( $rSWL );

  Given a text or a reference to a segmented text, return
  reasonable segmented terms

=cut
sub ClearWord {
    my($this, $rSWL) = @_;      my(@SWL, %SFL, $w, $wAt, $lcw);
    $rSWL = &segment($rSWL) if not ref($rSWL);
    foreach $w (@$rSWL) { # delete unreasonable terms
	next if $w =~ /^\s+$/;
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


=head1 methods for extracting related terms

=head2 SetSN() : created inverted structure for terms and sentence numbers

  $rSN = $seg->SetSN($rRWL, $rSenList);

  Given a (candidate) related word list and a sentence list, create a inverted
  hast structure of "word=>sentence_no1 sentence_no2 ..." for later fast
  analysis of related terms.

=cut
sub SetSN {
    my($this, $rRWL, $rSenList) = @_;
    my($w, $i, $sen, %SN); %SN = (); # returned ref var
# Using next line would (over)emphasize Single English Word, good for some cases
#    foreach $w (@WL, keys %Stem) { # Note : Keys in %Stem are so far all stems
    foreach $w (@$rRWL) {
	$i = -1;
	foreach $sen (@$rSenList) {
	    $i++;
# The \Q in next line ask Perl to disable special pattern char.
    	     while ($sen =~ /\Q$w/g) { $SN{$w} .= "$i "; }
#    	     if ($sen =~ /\Q$w/g) { $SN{$w} .= "$i "; }
#print "$w : i=$i : $SN{$w} : $sen<br>\n"if $w eq 'CHINA';
    	}
    }
    return (\%SN);
}


=head2 SetTermLink() : Set mutual information of two terms

  $rLinkValue = $seg->SetTermLink($rWL, $rSN, $rSenList);

  Set mutual information of two terms, whose mi > threshold

=cut
sub SetTermLink {
    my($this, $rWL, $rSN, $rSenList) = @_;
    my($x, $y, $i, $j, $mi, $NumSen, %LinkValue);
    %LinkValue = (); # returned ref var, may be used outside this package
    $NumSen = @$rSenList;
    for ($i=0; $i<@$rWL; $i++) {
    	$x = $rWL->[$i];
	for ($j=$i+1; $j<@$rWL; $j++) {
    	    $y = $rWL->[$j];
# Next line should be remarked if we want RT, but do not want keyword suggestion
#    	    next if index($y, $x)>-1 or index($x, $y)>-1;
#	    $mi = &CoMI($x, $y, $rSN);
	    $mi = &CoMI($this, $x, $y, $rSN);
#	    $mi = &Covariance($x, $y, $NumSen, $rSN);

	    $mi /= $this->{'MIthreshold'}; 
	    if ($mi > 1.0) { # added on June 8
#	    if ($mi > $MIthreshold) {
# To standardize the sequence of the two phrases, sort them
#		$LinkValue{join "-?", sort($x, $y)} = $mi;
		$LinkValue{join "-?", $x, $y} = $mi;
	    }
    	}
    }
#    $this->NormalizeLinkValue(\%LinkValue);
#$x=join"<br>\n",map{"$_:$LinkValue{$_}"}sort{$LinkValue{$b}<=>$LinkValue{$a}}
# keys%LinkValue;
#$x=join"<br>\n",map{"$_:$LinkValue{$_}"}sort keys%LinkValue;
#print"\n<hr>",$x,"<hr>\n";
    return \%LinkValue;
} # End of &SetTermLink();


# Set CoSenIdx : Co-occurred Sentence Index
#   To know at which sentence indices the two terms co-occurred
#   With the sentence indices, we can get the sentences via $rSenList
sub CoMI { # private
#    my($x, $y, $rSN) = @_;
    my($me, $x, $y, $rSN) = @_;
    my($xi, $yi, $co, @X, @Y, $rt);
# Here we assume @X,@Y has been sorted (and this is true so far)
    @X = split ' ', $rSN->{$x};
    return  0 if (@X == 0);
    @Y = split ' ', $rSN->{$y};
    while ($xi<@X && $yi<@Y) {
    	if ($X[$xi] == $Y[$yi]) {
    	    $rt = join("-?", $x, $y);
	    $me->{CoSenIdx}{$rt} .= "$X[$xi] " if not $me->{CoSenIdx}{$rt}=~/\b$X[$xi] $/;
	    $co++;  $xi++; $yi++;
    	} elsif ($X[$xi] < $Y[$yi]) {	$xi++;
	} else {			$yi++;
	}
    }
#print "$x:@X, $y:@Y, co=$co, mi=", (@X+@Y>0?(2*$co/(@X+@Y)):0),"<br>\n";
    return 2*$co/(@X+@Y);
} # End of &CoMi()


sub Covariance { # not yet tested
    my($x, $y, $n, $rSN) = @_;
    my($xi, $yi, @X, @Y, $xpyp, $xpym, $xmyp, $xmym);
# Here we assume @X,@Y has been sorted (and this is true so far)
    @X = split ' ', $rSN->{$x};
    @Y = split ' ', $rSN->{$y};
    while ($xi<@X && $yi<@Y) {
    	if ($X[$xi] == $Y[$yi]) { 	$xpyp++;  $xi++; $yi++;
    	} elsif ($X[$xi] < $Y[$yi]) {	$xpym++;  $xi++;
	} else {			$xmyp++;  $yi++;
	}
    }
    if ($xi<@X) { $xpym += @X - $xi; }
    if ($yi<@Y) { $xmyp += @Y - $yi; }
    $xmym = $n - ($xpyp + $xpym + $xmyp);
    $xpyp = 1 + log(1+$xpyp);#/log(10);
    $xpym = 1 + log(1+$xpym);#/log(10);
    $xmyp = 1 + log(1+$xmyp);#/log(10);
    $xmym = 1 + log(1+$xmym);#/log(10);
    $a = ($xpyp * $xmym - $xpym * $xmyp);
    return 0 if $a < 0;
#    $a *= sqrt($n);
    $a *= sqrt(1+log($n) );#/log(10));
    $b = ($xpyp + $xpym)*($xpyp + $xmyp)*($xmym + $xpym)*($xmym + $xmyp);
    if ($b == 0) { $b = 1; } else { $b = sqrt $b; }
#print "$x:@X, $y=@Y, xpyp=$xpyp, xpym=$xpym, xmyp=$xmyp, xmym=$xmym, a/b=$a/$b, <br>\n";
    return $a/$b;
} # End of &Covariance()


# Short documents may have larger LinkValues, so we should normalize
# the values so as to provide fair comparison among documents
# Use and Set %LinkValue
sub NormalizeLinkValue {  # not yet tested
    my($this, $rLinkValue) = @_;    my($tl, $ww, $lv);
    while (($ww, $lv) = each %$rLinkValue) {
	$tl += $lv;
    }
    $tl = 1 if $tl < 1;
    foreach $ww (keys %$rLinkValue) {
    	$lv = $rLinkValue->{$ww}/$tl;
    	if ($lv < $this->{'NorMIthreshold'}) {
    	    delete($rLinkValue->{$ww});
    	} else {
	    $rLinkValue->{$ww} = $lv;
	}
    }
    return $rLinkValue;
} # &NormalizeLinkValue()


=head2 TrimLink() : delete excessive term links for graphical display

  $rNewLinkValue = $seg->TrimLink($rLinkValue, $rFL);

  Trim links of related terms for concise display.

=cut
sub TrimLink { # public and private
    my($this, $rLinkValue, $rFL) = @_; # for keyphrase's term frequency
    my(%LV); %LV = (); # returned ref var, maybe used outside this package
    my($ww, $lv, $x, $y, %WW, @W2, %Edge);
    while (($ww, $lv) = each %$rLinkValue) {
    	($x, $y) = split /\-\?/, $ww; # '-?' is used in Java applet
    	push @{$WW{$x}}, $ww;
    }
    foreach $x (sort {$rFL->{$b} <=> $rFL->{$a}} keys %WW) {
	@W2 = sort {$rLinkValue->{$b} <=> $rLinkValue->{$a}} @{$WW{$x}}; 
	@W2 = @W2[0..2] if @W2>3;
	foreach $ww (@W2) { 
	    ($x, $y) = split /\-\?/, $ww;
	    next if $Edge{$x} > 2 or $Edge{$y} > 2;
	    $LV{$ww} = $rLinkValue->{$ww};
	    $Edge{$x}++; $Edge{$y}++;
	}
    }
    return \%LV;
} # End of &TrimLink();


=head1 methods for extracting abstracts

=head2 RankSenList() : rank sentences in terms of keyword frequency

  $rSentenceRank = $seg->RankSenList($rWL, $rFL, $rSN, $rSenList);

  Given keyword list in @$rWL, %$rFL,
  the sentence number for which a term occurs, represented in %$rSN, 
  compute which sentence contains most keywords listed in @$rWL.
  Rank the sentences according to accumulated frequencies of the keywords
  occur in the sentences.
  Return a reference to an array (a list) of ranked sentence numbers.

=cut
sub RankSenList {
    my($this, $rWL, $rFL, $rSN, $rSenList) = @_;  
    my($w, $s, %RankSen, @SenRank);
    for($s=0; $s<(@$rSenList); $s++) { $RankSen{$s} = 0; } 
# so that every sentence is guaranteed to be sorted, 2003/09/05
    foreach $w (@$rWL) {
	foreach $s (split ' ', $rSN->{$w}) {#see &SetSN() to know the format
#	    $RankSen{$s} += 1;
	    $RankSen{$s} += $rFL->{$w}; # may miss those sentences not in %SN
	}
    }
    @SenRank = sort { $RankSen{$b} <=> $RankSen{$a} } keys %RankSen;
    return \@SenRank;
}


=head1 segmenting methods

  Next methods are for segmenting Chinese words. These methods are those
  that needs to be re-implemented if you have another way of segmenting
  Chinese words.

=head2  Tokenize() : tokenize the given text for processing

  $rTokenList = $seg->Tokenize( $text );

  Given a text string, parse it into all 1-character (1-word) token array.

=cut
sub Tokenize {
    my($this, $t) = @_;  my($i, $j, $k, $c, $len, @terms1);
    @terms1 = (); # returned ref variable
    $len = length($t);
#print "t=$t ===>";
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
#	    push @terms1, $c if $c =~ /[\.\?\!]/;
#	    push @terms1, $c;  # replace above on 2003/10/07
#	    push @terms1, $c if $c ne ' '; # 2004/01/26
	    push @terms1, $c if $c !~ /\s/; # 2004/01/26
	    next; # push '.', '?', or '!' for sentence delimiter
	}
# Now it begins with an English letter
	    for ($k=$j+1; $k<$len; $k++) { # look for the next characters
		next if substr($t, $k, 1) eq '-'; # allow terms like 'Yu-Lung'
# The next 2 lines are added on Feb. 18, 2000 to allow terms like '0.18·L¦Ì'
# They should be best controlled by options (users' decision)
#		if (substr($t, $k, 3) =~ /\'s\W/o) { $k++; next ; }#2003/01/24
		if (substr($t, $k, 2) =~ /[.]\d/ ) { $k++; next ; }
#		if (substr($t, $k, 2) =~ /[,.]\d/ ) { $k++; next; }
# To allow '40%' as a term
		if (substr($t, $k-1, 2)=~/\d\%/) { $k++; last; }
# To allow E. F. Codd. # 2006/05/15
		if (substr($t, $j, 2)=~/\w\./) { $k++; last; }
## Next line is changed into next next 2 lines for this package in old version
		last if (substr($t, $k, 1) =~ /\W/o);
#		last if (substr($t, $k, 1) =~ /\s/o);
#		last if (ord(substr($t, $k, 1)) > 127);
	    }
# Next line is changed into next next line for this package
#	    push @terms1, &STEMER::stem(lc substr($t, $j, $k-$j));
#	    push @terms1, substr($t, $j, $k-$j) if $k-$j < 100; # 2006/05/15
	    push @terms1, lc substr($t, $j, $k-$j) if $k-$j < 30;
#	    push @terms1, Stem::stem(lc substr($t, $j, $k-$j), 0) if $k-$j < 30;
		# $k-$j<100 is to assure a term so as not too long
	    $j = $k - 1;
	} # end of for($j=0;
# @terms1 has all 1-token in input order
#print "terms1=@terms1 ";
    return \@terms1;
} # End of &Tokenize()


=head2 segment() : segment the give text by longest match with a dictionary

  $rSegText = $seg->segment($text)|$seg->segment($ref_to_tokenized_text);

  Given a text or a reference to a tokenized text array,
  return a reference to an array where the text is segmented in that array.
  
  This method is the main method called for segmenting Chinese words.
  It use %Dic, and %WLen for longest-first dictionary word matching.
  It then use some other hashes for unknown word processing.

=cut
sub segment {
    my($this, $rTTA) = @_;
    $rTTA = $this->Tokenize($rTTA) if not ref($rTTA);
    my ($i, @SegText, @UnKnown, $c, @WrdLen, $wl, $w, $NoMatch);
    @SegText = (); # return ref variable, may be used outside this package
    for ($i=0; $i<@$rTTA; $i++) { # do not use 'foreach $c (@$rTTA)' here
    	$c = $rTTA->[$i];
#	if (ord(substr($c, 0, 1)) < 128) { # $c is an English word
	if (not $this->{Eng_Seg_Phrase} and ord(substr($c, 0, 1)) < 128) {
	    $this->ProcessUnKnown(\@UnKnown, \@SegText) if @UnKnown > 0;
	    push @SegText, $c; # remember always do this after the above line
	} else { # $c is a 2-byte Chinese character
	    $NoMatch = 1;
	    @WrdLen = split ' ', $WLen{$c};
#warn "i=$i, c=$c, WdLen=@WrdLen\n";
	    foreach $wl (@WrdLen) { # longest-first match
	        next if $i+$wl-1 > @$rTTA;
		$w = join ' ', @$rTTA[$i..($i+$wl-1)];
		if (defined $DIC{$w}) {
		    $this->ProcessUnKnown(\@UnKnown, \@SegText) if @UnKnown>0;
		    push @SegText, $w;
		    $i = $i + $wl - 1; # change content of index $i
		    $NoMatch = 0;
		    last;
		}
	    } # foreach $wl
	    push @UnKnown, $c if $NoMatch;# leave it there for later processing
	} # if (ord(substr($c, 0, 1)) < 128) {
    } # for (my $i = 0; $i < @$rTTA; $i++) {
    $this->ProcessUnKnown(\@UnKnown, \@SegText) if @UnKnown > 0;
#print "\n<HR>SegWord:", join ', ', @SegText, "<br>\n";
    return \@SegText;
} # End of &segment()


=head2 ProcessUnKnown() : process terms unknown to a lexicon

  $seg->ProcessUnKnown($rUnKnown, $rSegText);

  Given @UnKnown and @SegText, process unknown words and put the result
  back to @SegText and then empty @Unknown if the unknown becomes known.
  
  use class hashes : %CNumbers, %CASCII, %CForeign, %CSurname, %CSurname2,
		     %UnCommonSurname, %CNotName
  Set object variable : $seg->{'Name'};

=cut
sub ProcessUnKnown {
    my($this, $rUnKnown, $rSegText) = @_;  my($len, @W, $name);
    while (@$rUnKnown > 0) {
    	@W = ();
    	while (exists($CNumbers{$rUnKnown->[0]})) {
    	    push @W, shift @$rUnKnown;
    	}
	if (@W > 0) { push @$rSegText, join ' ', @W;  next; } # a number

    	while (exists($CASCII{$rUnKnown->[0]})) {
    	    push @W, shift @$rUnKnown;
    	}
	if (@W > 0) { push @$rSegText, join ' ', @W;  next; }#an ASCII string

#print "\$CForeign{$rUnKnown->[0]}:$CForeign{$rUnKnown->[0]}<br>\n";
    	while (exists($CForeign{$rUnKnown->[0]})) {
    	    push @W, shift @$rUnKnown;
    	}
	if (@W > 0) {
	    if (@W == 1) { unshift @$rUnKnown, @W; } # resotre the @$rUnKnown
	    else {  # Foreign name
		$name = join ' ', @W;
		$this->{'Name'}{$name}++;
	    	push @$rSegText, $name;
	    	next;
	    }
	}

	if ($len = &IsChineseName($rUnKnown) and $len <= @$rUnKnown) {
	    $name = join ' ', @$rUnKnown[0..($len-1)];
	    $this->{'Name'}{$name}++;  # a Chinese name
	    push @$rSegText, $name;
	    foreach (1..$len) { shift @$rUnKnown; }
	    next;
	}
#	if ($len = &isForeignName($rUnKnown)) {
#	    push @$rSegText, join ' ', @$rUnKnown[0..($len-1)];
#	    foreach (1..$len) { shift @$rUnKnown; }
#	    next;
#	}
	push @$rSegText, shift @$rUnKnown; # still an unknown char
    }
} # End of &ProcessUnKnown()


=head2 SetHashes() : Set hashes for Chinese text segmentation

  $seg->SetHashes();

  Set class global : %CNumbers, %CASCII, %CForeign, %CSurname, %CSurname2,
		     %UnCommonSurname, %CNotName
  These hashes are used by &ProcessUnKnown().

=cut
sub SetHashes {
    my($this) = @_;
  my($n, $numbers, $wascii, $foreign, $surname, $UnCommonSurname, $NotName);
# Numbers
  $numbers  = '¹s¡³¤@¤G¤T¥|¤­¤»¤C¤K¤E¤Q¦Ê¤d¸U»õ¢¯¢°¢±¢²¢³¢´¢µ¢¶¢·¢¸¡DÂI²Ä';
  $numbers .= '¦h¥b¼Æ´X­Ç¤Ê¨â³ü¶L¤T¸v¥î³°¬m®Ã¨h¬B§B¥a';
  for ($n = 0; $n < length($numbers); $n+=2) {
    $CNumbers{substr($numbers, $n, 2)} = 1;
  }

# Wide ASCII words
  $wascii =  '¢é¢ê¢ë¢ì¢í¢î¢ï¢ð¢ñ¢ò¢ó¢ô¢õ¢ö¢÷¢ø¢ù¢ú¢û¢ü¢ý¢þ£@£A£B£C¡D';
  $wascii .= '¢Ï¢Ð¢Ñ¢Ò¢Ó¢Ô¢Õ¢Ö¢×¢Ø¢Ù¢Ú¢Û¢Ü¢Ý¢Þ¢ß¢à¢á¢â¢ã¢ä¢å¢æ¢ç¢è¡Ð';
  $wascii .= '';
  for ($n = 0; $n < length($wascii); $n+=2) {
    $CASCII{substr($wascii, $n, 2)} = 1;
  }

# Foreign name transliteration characters
  $foreign =  'ªü§J©Ô¥[¤º¨È´µ¨©¤Úº¸©i·RÄõ¤×§Q¦è¸â³ì¥ì¶O³ÇÃ¹¯Ç¥¬¥i¤ÒºÖ»®°Ç¬_¯S';
  $foreign .= '³Ò­Û©Z¥vªâ¥§®Úµn³£§BªL¥î®õ­E¾¤«X¬ì¯Á¨Uª÷´Ë¶øÀN¥Ë¯ý´¶¸¦¶ëºû¤j§Q';
  $foreign .= '®æµÜ¼w©£ÂÄ¹p¾¥­ô¥±®w¿D°¨«¢¦h¯÷¤à¯Q©_¤Á¿ÕÀ¹¸Ì½Ñ¶ë¦N°ò©µ¬ì¹F¶ð³Õ';
  $foreign .= '¥d¶®¨Ó²öªi¦ã«¢ÁÚ½´¦w¿c¤°¤ñ¼¯°Ò¤D¥ð¦X¿à¦Ì¨º­}³ÍµÜ·Å©¬®á¨Ø»X³Õ¦«';
  $foreign .= 'ÁÂ®æ¿A¬¥¤Î§Æ¤R¾|¤Ç»ô¯÷¦L¥j®J§V¯P²Öªk¸ë¹Ï³Ø¤g¿pµÌ°ò¥T¥ð»\­C¨F';
  $foreign .= '»¹»«³ÁµØ¸UªF´ö';
  for ($n = 0; $n < length($foreign); $n+=2) {
    $CForeign{substr($foreign, $n, 2)} = 1;
  }

#Chinese surnames
  $surname  = '¦ã¦w±Î¥Õ¯Z¥]Ä_«OÀj¨©²¦Ãä¤Ë¬f¤R½²±ä§Â®ã©÷±`³¯¦¨µ{¿ð¦À»u·¡';
  $surname .= 'Àx²E±ZÀ¹¤M¾H¨f¤N¤B¸³Äu§ùºÝ¬q¼Ô­S¤è©Ð´´¶OÂ×«Ê¶¾»ñ¥ñºÖ³Å»\¥Ì';
  $surname .= '°ª¤à¯ÕÅÇ®c¤Ä­e¶d¨¦¥jÅU©xÃöºÞ®Û³¢ÁúªC°q¥Ý¦ó¶P»®¿Å¬x«J­Jªá';
  $surname .= 'µØ¶ÀÀN½]®V¦N¬ö©u¸ëÂ²æù«¸¦¿½±µJ®Êª÷àÚ¯ð©~±d¬_ªÅ¤Õ¦JñKªp¿àÂÅ';
  $surname .= '­¦®Ô³Ò¼Ö¹p§N¾¤§õ²z¼F§QÀy³s·G½m¨}±ç¹ùªL­â¼B¬h¶©Às¼Ó°ú¿c§f¾|';
#  $surname .= '³°¸ô­ÛÃ¹¬¥Àd³Â°¨³Áº¡­T¤ò±ö©s¦Ì­]Á[¶{©ú²ö¦È¿p­ÙÂ¿¤û¶s¹A¼ïÃe';
  $surname .= '³°    Ã¹  Àd  °¨³Á  ­T¤ò±ö©s  ­]      ²ö¦È¿p­ÙÂ¿¤û    ¼ïÃe';
  $surname .= '»p´^¥Ö¾ë¥­»Z·Á®ú±­ªÂ»ô¿ú±j³ì¯³¥Cªô¤³¸Ê©}Â£Åv¥TÄÇ¥ôºa®e¨¿';
  $surname .= '·çÍºÂÄÁÉ¨F³æ°ÓªòÊe¥Ó¨H²±¥Û¥v¹ØµÎ´µ§ºÄ¬®]Í×ÃÓ½Í´ö­ð³³¼ð';
  $surname .= '¥ÐÊcÉi±O¶î¸U¨L¤ý¦M­³ÃQ½Ã½«·Å»D¯Î§Åà©¥îªZ§d®O²ß®LÂAËÎ';
#  $surname .= '¶µ¿½¸ÑÁÂ¨¯¨·©¯ºµ®}³\«ÅÁ§¯ûÃCÀF¨¥ÄY«Û®Ë¿P·¨¶§«À¸­ÃÆ©ö®ï»È¤¨';
  $surname .= '¶µ¿½  ÁÂ¨¯¨·  ºµ®}³\  Á§¯ûÃCÀF  ÄY  ®Ë¿P·¨¶§«À¸­  ©ö®ï  ¤¨';
# $surname .= 'À³­^´å¤×©ó³½¸·«\§E¬ê³ë­§±L¤¸°K©¨¶³»N´¿¬d»C¸â´ï±i³¹©Û»¯ºÂ';
  $surname .= '  ­^´å¤×  ³½¸·«\§E    ­§±L¤¸°K©¨¶³»N´¿¬d»C¸â´ï±i³¹  »¯ºÂ';
  $surname .= '¾GÄÁÁé©P½Ñ¦¶ªÇ¯¬²ø¨ô©v¹Q¯ª¥ª';
  for ($n = 0; $n < length($surname); $n+=2) {
    $CSurname{substr($surname, $n, 2)} = 1;
  }

# Add in 2 character surnames; also add to lexicon
# so they'll be segmented as one unit
  $CSurname2{'ªF ³¢'} = 1; # $DIC{'ªF ³¢'} = 1;
  $CSurname2{'¤½ ®]'} = 1; # $DIC{'¤½ ®]'} = 1;
  $CSurname2{'¬Ó ¨j'} = 1; # $DIC{'¬Ó ¨j'} = 1;
  $CSurname2{'¼} ®e'} = 1; # $DIC{'¼} ®e'} = 1;
  $CSurname2{'¼Ú ¶§'} = 1; # $DIC{'¼Ú ¶§'} = 1;
  $CSurname2{'³æ ¤_'} = 1; # $DIC{'³æ ¤_'} = 1;
  $CSurname2{'¥q ªÅ'} = 1; # $DIC{'¥q ªÅ'} = 1;
  $CSurname2{'¥q °¨'} = 1; # $DIC{'¥q °¨'} = 1;
  $CSurname2{'¥q ®{'} = 1; # $DIC{'¥q ®{'} = 1;
  $CSurname2{'¿F ¥x'} = 1; # $DIC{'¿F ¥x'} = 1;
  $CSurname2{'½Ñ ¸¯'} = 1; # $DIC{'½Ñ ¸¯'} = 1;

  $UnCommonSurname = '¨®©M¥þ®É¤ô¦P¤å®u©ó';
  for ($n = 0; $n < length($UnCommonSurname); $n+=2) {
    $UnCommonSurname{substr($UnCommonSurname, $n, 2)} = 1;
  }

#Not in name
  $NotName  = 'ªº»¡¹ï¦b©M¬O³Q³Ì©Ò¨º³o¦³±N·|»P©ó¥L¬°¤]';
  $NotName .= '¡B¡G¡A¡C¡¹¡i¡j¡]¡^¡ó¡ã¡i¡j¡X¡O¡H¡I¡u¡v¡@';
  for ($n = 0; $n < length($NotName); $n+=2) {
    $CNotName{substr($NotName, $n, 2)} = 1;
  }
} # End of &SetHashes()


sub IsName { # private
    my($c) = @_;
    return 0 if (exists $CNotName{$c} or $Stopword::Cmark{$c});
    return 1;
}

sub IsChineseName { # private
    my($rUnKnown) = @_;
    if ( $CSurname2{join ' ', @$rUnKnown[0..1]} ) { # if 2-char Surname
    	if (&IsName($rUnKnown->[2])) {
    	    if (&IsName($rUnKnown->[3])) { return 4; }
	    else {  return 3; }
	}
    }
    if ($CSurname{$rUnKnown->[0]}) { # if 1-char Surname;
    	if (&IsName($rUnKnown->[1])) {
    	    if (&IsName($rUnKnown->[2]) ) { return 3; }
	    else {  return 2; }
	}
    }
    return 0;
}




=head1 --- Tools ---

  Next methods are tools for creating auxiliary (DBM) files.
  These methods are not used when segmenting words, but the files they
  created are used when segmenting and cleaning words.

=head2 CreateDicDBM() : Create DBM files from a lexicon in text

  use SegWord; &SegWord::CreateDicDBM( $WordList, $DicDBfile, $DicWLfile );

  Given a Chinese word list (e.g., wordlist.txt), create a dictionary DBM file
  (WL.db) and a word length DBM file (WLWL.db) for later fast segmentation.

=cut
sub CreateDicDBM { # public tool
    my($WordListFile, $DicDBfile, $DicWLfile) = @_;  
    my(%DIC, %WLen, $rW, $w, $wlen, %WLenTMP, %W);
    use Fcntl;    use DB_File;
    die "Word File is '$WordListFile' and DicWLfile is empty" if $DicWLfile eq '';
    die "Word File is '$WordListFile' and DicDBfile is empty" if $DicDBfile eq '';
    unlink "$DicDBfile";    unlink "$DicWLfile";
    tie(%DIC, 'DB_File',"$DicDBfile",
	O_RDWR | O_CREAT, 0644, $DB_File::DB_BTREE)
	||(print "Err:$!" and die $!);
    tie(%WLen, 'DB_File',"$DicWLfile",
	O_RDWR | O_CREAT, 0644, $DB_File::DB_BTREE)
	||(print "Err:$!" and die $!);
    open(WRDS, $WordListFile) or die "Can't open $WordListFile\n";
    my $MaxWordLen = 0;
    while (<WRDS>) { chomp;
#print "$_ ===> ";
	$rW = &Tokenize('SegWord', $_);
	$w = join ' ', @$rW;
	$DIC{$w} = 1;
	$wlen = scalar @$rW;
	$MaxWordLen = $wlen if $MaxWordLen < $wlen;
	$WLenTMP{$rW->[0]} .= "$wlen "; # record match length of the 1st char
#print "w=$w, 1st c $rW->[0]=$WLen{$rW->[0]}, wlen=$wlen \n" if $w eq'¤f ÀY';
    }
    close(WRDS);
    while (($w, $wlen) = each %WLenTMP) {
	%W = ();
	foreach $rW (split ' ', $wlen) {  $W{$rW} = 1;  }
	$WLen{$w} = join ' ', sort { $b <=> $a } keys %W;
    }
#print '¤f¡G', $WLen{'¤f'}, '=>', $DIC{'¤f ÀY'}, "\n";
    untie %DIC; untie %WLen;
} # End of &CreateDicDBM();


=head2 CreateTPS() : create a term-part-of-speech file

  use SegWord; &SegWord::CreateTPS($TermPosFile, $TPSDBfile);

  Given a Term-Part-of-speech file, create a DBM file
  perl -s segword.pm -TPS TermPos.txt => will create a TPS.db file

=cut
sub CreateTPS { # public tool
    my($TermPosFile, $TPSDBfile) = @_;
    my(%TermPos, $w, $pos);
    use Fcntl;  use DB_File;
    unlink "$TPSDBfile";
    tie(%TermPos, 'DB_File', "$TPSDBfile",
	O_RDWR | O_CREAT, 0644, $DB_File::DB_BTREE)
	|| (print "Error:" and die $!);
    open F, $TermPosFile or die "Cannot open file:'$TermPosFile', $!";
    while (<F>) {
    	($w, $pos) = split / :/, $_;
    	$w = join ' ', @{ &Tokenize('SegWord', $w) };
#print "w='$w', pos=$pos\n";
    	$TermPos{$w} = $pos;
    }
    close(F);
    untie(%TermPos);
}


=head2 InsertSpace() : insert a space between each character in a text


  use SegWord; &SegWord::InsertSpace($InFile, $OutFile);

  Given a stop word file ($InFile, say stopword-chi.txt), insert a space 
  between each character of the stop word and delete duplicate terms and then
  print out the results to $OutFile

=cut
sub InsertSpace {
    my($InFile, $OutFile) = @_;    my($w, %W);
    open F, $InFile || die "Cannot read file:'$InFile'";
    while (<F>) {
    	chomp; next if $_ eq '';
    	$W{join ' ', @{&Tokenize('SegWord', $_)}} = 1; # delete duplicate words
    } close(F);
    open FF, ">$OutFile" || die "Cannot write to file:'$OutFile'";
    foreach $w (sort keys %W) { print FF "$w\n"; }
    close(FF);
}

#--------------------------------------------------
#  Below is copied from the results generated by SegWord_gen.pl
#--------------------------------------------------



# Load %WL and %WLen
sub SetWLHash {
    my($rWL, $rWLen) = @_;  my($w, $wlen, @W);  
    local $/; $/ = "\n";
    while (<DATA>) { # load %WLen first
    	chomp;  	last if /^__END_OF_WLen__$/;
    	($w, $wlen) = split / : /, $_;
    	$rWLen->{$w} = $wlen;
    }
    while (<DATA>) { # load %WL
    	chomp; 	@W = split /\t/, $_;
    	foreach $w (@W) { $rWL->{$w} = 1; }
    }
    return 1;
}
1;
__DATA__
2-dimensional : 1
3d : 1
absorption : 2
absorption-spectroscopy : 1
acid-base : 1
acoustical : 1
acrosome : 1
activation : 2
adamantanoid : 3 1
adsorption : 2
aerodynamic : 2 1
aethalometer : 1
afm : 1
ag : 2
agricultural : 1
air : 2
air-pollution : 1
airborne : 1
aircraft : 1
albumin : 1
alkali-metal : 2 1
alkanethiol : 2
alkanethiolate : 2
alkylation : 1
all-optical : 1
allotrope : 1
alloy : 2
allylamine : 1
alternation : 1
aluminophosphate : 1
aluminum-alloys : 1
alveolar : 2 1
ambipolar : 1
amidoamine : 1
amino-acid : 1
amorphou : 3 2
amorphous-alloys : 1
amperometric : 2
amphiphile : 1
amphiphilic : 2
amphotericin-b : 1
amplicon : 1
analogou : 1
angele : 1
angiogenic : 1
angle : 2
anhydride : 1
anion-exchange : 2 1
anisotropy : 1
anodic : 2
anodization : 1
antibiotic : 1
antibody-coated : 1
antibunch : 1
anticro : 1
antigen-antibody : 1
antimicrobial : 1
antitubercular : 1
antiviral : 1
aortic : 1
apatite : 1
apolipoprotein : 1
aquatic : 1
arabidopsis-thaliana : 1
architectural : 1
arg-gly-asp : 1
argon : 2
aromatic-hydrocarbons : 1
array : 2
artificial : 2
atom : 1
atomic : 3 2
atomic-force : 1
atomic-layer : 2 1
atomic-level : 1
atomic-resolution : 1
atomic-scale : 1
atomic-structure : 1
atomistic : 2 1
au : 2
aureu : 1
automata : 1
autosomal : 1
axon : 1
axonal : 1
azo : 2
bacilli : 1
bacterioplankton : 1
bacterium : 1
balb : 1
band : 2
base-pair : 1
bend : 2
beta-cyclodextrin : 1
beta-ga2o3 : 2
bienzyme : 1
biexciton : 1
bimetallic : 2
binuclear : 2
bioactive : 1
biocatalytic : 1
biochemically : 1
biocompatibility : 1
bioconjugate : 1
bioconjugation : 1
biodegradable : 3 2 1
biodegradation : 1
bioengineer : 1
biofilm : 1
bioinformatic : 1
bioinorganic : 1
biological : 2 1
biologist : 1
biomedical : 2 1
biomimicry : 1
biomolecular : 2 1
biophysical : 1
biopolymer : 1
biorecognition : 1
biosen : 1
biosensor : 1
biotin-functionalized : 1
biotinylate : 1
biphenyl : 1
bipolar : 1
birefringence : 1
block : 2
block-copolymer : 1
block-copolymers : 1
blood-brain : 2
bloom : 1
blue : 2
blueshift : 1
bn : 2
bond-dissociation : 2
bone : 2
bone-formation : 1
borohydride : 1
boron-nitride : 2
bottom-up : 1
boundary : 3
braid : 1
brillouin : 1
bronchoalveolar : 1
butyric : 1
c-60 : 2
c-axis : 1
c-terminus : 1
cadmium : 3
calcification : 1
calcite : 1
cancer-therapy : 1
cantilever : 1
capillary : 2
capsid : 1
carbon : 4 3 2
carbon-monoxide : 2
carbon-nanotube : 2 1
carbonate : 2
carbosilane : 1
cardiovascular : 2 1
cartilage : 1
casein : 1
catalyst : 2
catalytic : 2
catenane : 1
cation-ether : 2 1
cationic : 2 1
cdse : 3 2
cdte : 2
cell : 2 1
cell-matrix : 1
cell-specific : 1
cell-wall : 1
cellular : 2
cement : 1
centrifugation : 1
ceo2 : 2
cerevisiae : 1
cervical : 1
chain-transfer : 1
chalcogenide : 1
charg : 2
charge : 2
chelator : 1
chemical : 3 2
chemical-analysis : 2
chemical-synthesis : 1
chemical-vapor-deposition : 1
chemotaxi : 1
chimeric : 1
chitosan : 2
chitosan-dna : 1
chlorinate : 1
chlorophyll : 1
chloroplast : 1
cholesterol : 1
chromatin : 1
chromosome : 1
ciliate : 1
circumferential : 1
circumvent : 1
citation : 1
clay : 2
clinical : 1
cnt : 1
cntfet : 1
coagulation : 1
coarse-grained : 1
cochlea : 1
coherence : 1
collagen : 2
colloidal : 2
coloration : 1
composite : 2
composite-materials : 1
concentration : 4
conduct : 2
conductance : 2
configur : 1
conformational : 2
conical : 1
contaminant : 1
contaminate : 2
contemporary : 1
continuum : 2
controll : 2
controlled-release : 1
convective : 1
copolymer : 1
coral : 1
core : 4
core-shell : 2
coreceptor : 1
corona : 1
cortical : 1
coulomb : 2
coulomb-blockade : 1
coupl : 2
covalently : 1
crossbar : 1
crown-ethers : 1
cryogenic : 1
cryomill : 1
crystal : 1
crystal-growth : 1
crystal-structure : 1
crystallinity : 1
crystallization : 2 1
crystallize : 1
current-driven : 1
cvd : 1
cystic : 1
dark-field : 1
dealt : 1
decoherence : 1
deformation-mechanism : 1
dehydrate : 1
dehydration : 1
dehydrogenase-based : 1
dehydrogenation : 1
deleteriou : 1
delivery-system : 1
dendrimer-based : 1
dendrimer-encapsulated : 1
dendrite : 1
dendritic : 2 1
dendron : 1
density : 3
dental : 1
dentin : 1
deplet : 1
der-waals : 2 1
desorption : 1
deterministically : 1
detoxification : 1
detrital : 1
deviate : 1
dialysi : 1
diamond-like : 2
diatom : 1
diazonium : 1
diblock : 2
dicarboxylate : 1
dielectric : 2
diesel : 1
differential : 3
diffusional : 1
digestion : 1
dip-coating : 1
dip-pen : 2 1
direct : 2
discrete-dipole : 2 1
discriminatory : 1
distal : 1
distinctly : 1
dl-lactide-co-glycolide : 1
dmfc : 1
dna : 2 1
dna-based : 1
dna-damage : 1
dominance : 1
dopamine : 1
dope : 1
double : 3
double-gate : 1
double-strand : 1
double-stranded : 2
double-wall : 1
down-regulation : 1
downwind : 1
doxorubicin : 1
doxorubicin-loaded : 2 1
droplet : 1
drug : 3 2 1
duplex : 1
dust : 1
dye-sensitized : 3 1
dynamic : 3
e-beam : 1
ecological : 1
ecosystem : 1
elastic : 2
elasticity : 1
elastomeric : 3 1
electric : 2
electric-field : 1
electrical : 2
electrical-properties : 1
electrical-transport : 1
electroanalytical : 1
electrochemical : 2 1
electrochemistry : 1
electrodeposition : 1
electroluminescence : 1
electrolyte : 2
electromagnetic : 2 1
electromechanical : 1
electromigration : 1
electron : 2
electron-beam : 2 1
electron-deficient : 1
electron-electron : 1
electron-hole : 1
electron-microscopy : 1
electron-spin : 1
electron-transfer : 2 1
electronic : 2
electronic-properties : 1
electrooxidation : 1
electrospin : 1
electrospray-ionization : 1
electrospun : 1
electrostatically : 1
ellipsometry : 1
elongate : 1
embryonal : 1
embryonic : 2
empirical : 1
emulsification : 1
emulsion : 2
enamel : 1
encapsulate : 1
energy : 2
energy-transport : 1
enlargement : 1
entanglement : 1
enterotoxin : 1
entrance : 1
entrapment : 1
entropy : 1
environmental : 2
enzyme : 2 1
enzyme-immunoassay : 1
epiblast : 1
epilayer : 1
episode : 1
epitaxial : 2
epitaxial-growth : 1
epitaxially : 1
epitaxy : 1
epithelia : 1
epithelium : 1
epitope : 1
epoxidation : 1
epoxy : 2
error-correcting : 2
error-correction : 1
ethic : 1
ethical : 1
eukaryote : 1
eukaryotic : 1
european : 1
evaporation : 1
evaporation-induced : 1
exciton-phonon : 1
extracellular : 2
extrapolation : 1
extruder : 1
far-field : 1
fatty : 2
fault-tolerant : 1
favorably : 1
favour : 1
fcc : 2
fe-sem : 1
fe3o4 : 2
femtosecond : 1
fermi : 1
ferritin : 1
ferromagnet : 1
ferromagnetic : 1
ferromagnetism : 1
ferumoxide : 1
few-electron : 1
fibril : 1
field : 2
field-effect : 2 1
field-emission : 1
filamentou : 2
fine : 2
fine-grained : 2 1
fixation : 1
flagellate : 1
flip-flop : 1
flow-injection : 1
fluorescence : 3 2
fluorescence-based : 1
fluorescent : 2
fluorescently : 1
fluxe : 1
focu : 3
foodborne : 1
force : 2
fossil : 1
four-wave : 1
free : 2
free-radical : 2
fresh-water : 1
freshwater : 1
frictional : 1
frontline : 1
fry : 1
fsp : 1
fuel : 2
fullerene-like : 1
functionalize : 3
fungal : 1
fungi : 1
fur : 1
gallium : 3 2
gan : 2
gas : 3 2
gene-therapy : 1
gene-transfer : 2 1
genome-wide : 1
geological : 1
geometrical : 1
germ-cells : 1
giant : 2
glass-transition : 1
glioma : 1
globular : 1
glucose : 2
glucose-oxidase : 1
goethite : 1
gold : 2
gpi-anchored : 2 1
grain : 2
grain-boundaries : 1
grain-size : 1
gram : 1
gram-negative : 1
granular : 2
graphite : 2
gravitational : 1
gravity : 1
grazing-incidence : 1
green : 4
greens-function : 1
ground : 2
groundwater : 1
growth-mechanism : 1
guinea : 1
h-bond : 1
hairpin : 1
half-life : 1
half-lives : 1
hall-petch : 1
halpin-tsai : 1
handheld : 1
harne : 1
heavy-duty : 1
helical : 1
helice : 1
hematite : 1
hemicellulose : 1
hemoglobin : 1
hepatiti : 1
hepatitis-b-virus : 1
heteroepitaxial : 1
heterogeneou : 2
heterojunction : 1
heterostructur : 1
heterostructure : 1
heterotrophic : 2 1
hexagon : 1
hexagonal : 3
hexagonally : 1
high-aspect-ratio : 1
high-spin : 2
highly : 3 2
hipco : 1
histological : 1
hiv : 1
hole : 2
hollow : 2
homogeneou : 1
horseradish : 1
host-guest : 2
hove : 1
hrem : 1
hrtem : 1
human : 2
humidity : 2
hydraulic : 1
hydrodynamic : 2
hydrogen : 2
hydrogen-bond : 1
hydrogen-bonding : 1
hydrophilicity : 1
hydrophobic : 1
hydrophobicity : 1
hyperbranch : 2
hyperfine : 1
hypersensitivity : 1
hypervariable : 1
hypothese : 1
hysteretic : 1
iii-v : 2
immersion : 1
immune : 2
immunization : 1
immunodeficiency : 1
immunogenicity : 1
immunoglobulin : 1
immunohistochemical : 1
immunological : 1
immunomagnetic : 2 1
immunosensor : 1
immunotherapy : 1
impedance : 1
implantation : 1
imprint : 2
in-vivo : 1
ina : 3
incubate : 1
indistinguishable : 1
indium-phosphide : 2 1
indium-tin : 1
individual : 3 2
indocyanine : 1
infiltration : 1
influenza : 1
influx : 1
infrared-active : 1
inhalation : 1
inhomogeneity : 1
inhomogeneou : 1
injector : 1
inorganic : 2
instillation : 1
integrin-targeted : 1
interfacial : 2
interferometer : 1
intergranular : 1
interlock : 1
intermetallic : 1
interstitium : 1
intestinal : 1
intestine : 1
intracranial : 1
intranasal : 1
intraoperative : 1
intratracheal : 2
intravenou : 1
intravenously : 1
invitro : 1
ion : 2 1
ion-beam : 1
ion-exchange : 1
ionization : 1
ipce : 1
iron-oxide : 2
isotope : 1
isotopic : 1
josephson-junction : 1
kaolinite : 1
keratinocyte : 1
kernel : 1
kinesin : 1
kinetically : 1
lactic : 1
lactic-co-glycolic : 1
lactide-co-glycolide : 1
lamellae : 1
landauer : 1
langmuir-blodgett : 2 1
larval : 1
laser : 2
laser-ablation : 1
lateral : 2
lattice : 2
lavage : 1
layer : 3
layered-silicate : 2
leach : 1
leishmania : 1
length-scale : 1
lennard-jones : 1
lethal : 1
leukemia : 3
light : 2
light-emitting : 2 1
light-emitting-diodes : 1
light-induced : 2
light-scattering : 1
lignin : 1
limb : 1
line : 2
lineage : 1
lipid : 2
lipoprotein : 1
liposomal : 1
liposome : 1
liquid : 2
liquid-crystal : 1
liquid-crystalline : 2
liquid-phase : 2
liquid-solid : 2
listeria-monocytogenes : 1
lithography : 1
liv : 2
localize : 4
locomotion : 1
long-circulating : 1
low-temperature : 2
lspr : 1
lubrication : 1
lucent : 1
luminescence : 2
lymphatic : 1
lysozyme : 1
macrocyclic : 3
macromolecular : 1
macroscale : 1
macroscopic : 3
magnetic : 3 2
magnetic-anisotropy : 1
magnetic-properties : 1
magnetism : 1
magnetization : 2 1
magnetophotoluminescence : 1
magnetoresistance : 1
magnetoresistive : 1
magnetron : 2
maltose : 1
mat : 1
mater : 1
materialia : 1
matrix : 2
maturation : 1
mbe : 1
mechanical : 2
mechanical-behavior : 1
medicale : 1
medication : 1
mediterranean : 1
melanoma : 1
melt-intercalation : 1
mem : 2
membrane : 2 1
mems-based : 1
mesenchymal : 2
mesoporou : 3 2
mesoscale : 1
mesoscopic : 2 1
mesostructur : 4 2
messenger-rna : 1
metabolite : 1
metal : 2
metal-insulator : 1
metal-insulator-transition : 1
metal-molecule : 1
metal-organic : 2
metal-oxide-semiconductor : 1
metal-to-ligand : 1
metallic : 2
metallurgica : 1
metastable : 1
methanol : 2
microarray : 1
microbe : 1
microbeam : 1
microbial : 3 1
microcapsule : 1
microcavity : 1
microchannel : 1
microchip : 1
microcrystallite : 1
microelectrode : 1
microelectromechanical : 2 1
microencapsulation : 1
microfabricate : 2 1
microfibril : 1
microfluidic : 1
microhardne : 1
micromagnetic : 1
micromechanic : 1
micromechanical : 1
microorganism : 1
microphase : 1
micropore : 1
microporou : 2
microscope : 1
microscopy : 1
microsphere : 1
microstructural : 1
microstructure : 1
microsystem : 1
microvalve : 1
millimeter : 1
mineralization : 1
minimization : 1
mismatche : 1
mitochondrial : 2
mmt : 1
molecular : 3 2 1
molecular-beam : 2 1
molecular-dynamics : 2 1
molecular-oxygen : 1
molecular-scale : 1
molecular-sieves : 1
molecular-switch : 1
molecularly : 1
molecule : 1
mono-dispersed : 1
monoclonal-antibody : 1
monocrystalline : 1
monolayer : 1
monomer : 1
mori-tanaka : 1
morphogenetic : 1
morphological : 1
morphologically : 1
morphology : 1
mqw : 1
mram : 1
mucosa : 1
multi-wall : 3
multi-walled : 3
multidrug-resistance : 1
multimetallic : 1
multiquantum : 1
multiwall : 3
mutate : 1
mwnt : 1
mycobacterium : 1
myoglobin : 1
myosin : 1
n-isopropylacrylamide : 1
n-zno : 1
nano : 1
nano-adsorbent : 1
nano-composites : 1
nano-crystal : 1
nano-electronic : 1
nano-indentation : 1
nano-optoelectronics : 1
nano-pores : 1
nano-size : 1
nano-technology : 1
nanoassembly : 1
nanobacteria : 1
nanobacterial : 1
nanobarcode : 1
nanobelt : 1
nanobiotechnology : 1
nanocable : 1
nanocage : 1
nanocantilever : 1
nanocapsule : 1
nanocatalyst : 1
nanocavity : 1
nanochannel : 1
nanochemistry : 1
nanochip : 1
nanoclay : 1
nanocluster : 1
nanocolloid : 1
nanocomb : 1
nanocomposite : 2 1
nanocrystal : 1
nanocrystalline : 2 1
nanocube : 1
nanocylinder : 1
nanodevice : 1
nanodisk : 1
nanodot : 1
nanoelectrode : 2 1
nanoelectromechanical : 1
nanoelectrospray : 1
nanofabrication : 1
nanofiber : 1
nanofibre : 1
nanofibrou : 1
nanofiltration : 2 1
nanoflagellate : 1
nanoflare : 1
nanofluidic : 1
nanogold : 1
nanoindentation : 1
nanoindenter : 1
nanoleakage : 1
nanomechanical : 1
nanomedicine : 1
nanomembrane : 1
nanometer : 2
nanometre-scale : 1
nanomorphology : 1
nanoparticle : 2 1
nanoparticle-based : 2
nanophase : 2
nanophotonic : 1
nanoplankton : 1
nanoplate : 1
nanopore : 1
nanoprism : 1
nanoprobe : 1
nanoreactor : 1
nanoresonator : 1
nanoscale : 3 1
nanoscience : 1
nanosize : 2 1
nanosphere : 2 1
nanostructur : 2
nanosystem : 1
nanotechnological : 1
nanotechnology : 1
nanotip : 1
nanotriangle : 1
nanotube : 4 1
nanotube-based : 1
nanotube-polymer : 2 1
nanotube-reinforced : 1
nanowire : 2 1
nanowire-based : 1
near-field : 2 1
near-infrared : 1
neointimal : 1
neonatal : 1
neovasculature : 1
neutron-capture : 2 1
neutron-scattering : 1
nitrite : 1
nitrogen : 2
non-viral : 1
non-volatile : 1
non-woven : 1
nonequilibrium : 1
nontoxic : 1
northeast : 1
northern : 1
nose : 1
novo : 1
nsom : 1
nuclear : 2 1
nucleation : 1
nuclei : 1
nucleic : 2 1
nucleic-acid : 1
nucleic-acids : 1
nutrient : 1
ocular : 1
oil-in-water : 1
olive : 1
one-dimensional : 2 1
one-qubit : 1
optical : 2
optical-absorption : 1
optoelectronic : 2 1
order : 2
organ : 1
organic : 2
organic-surfaces : 1
organisation : 1
orthopaedic : 1
osmosi : 1
osteogenic : 1
outer : 3
oxide : 3 2
oxide-based : 1
oxidi : 1
oxidic : 1
oxygen : 2
oxygen-reduction : 2
oxygen-terminated : 1
ozone : 1
p-terphenyl : 1
palladium : 2
pancreatic : 1
para-terphenyl : 2 1
paracrystalline : 1
parasite : 1
particle : 3 2
particle-mediated : 1
particle-specific : 1
particulate : 2
paste : 2 1
pathogen : 1
pathogenic : 1
pathological : 1
pave : 1
payload : 1
pcr : 2
peak-to-valley : 1
pegylation : 1
pentagon : 1
periodic : 3
persistent-current : 2 1
persulphate : 1
perylene : 1
pesticide : 1
phage : 1
phagokinetic : 2 1
pharmaceutical : 1
pharmacological : 1
phase : 2
phenotypic : 1
phonon : 2 1
phosphatidylcholine : 1
phospholipid : 1
phosphonium : 1
phosphoprotein : 1
phosphorylate : 1
photo-induced : 1
photo-optical : 1
photoactivity : 1
photobleach : 1
photocatalyst : 1
photocatalytic : 2 1
photochemical : 1
photodegradation : 1
photodetector : 1
photoelectrochemical : 2 1
photoelectron : 1
photoelectron-spectroscopy : 1
photoemission : 1
photoexcitation : 1
photogeneration : 1
photoinduc : 2
photolithography : 1
photoluminescence : 2 1
photon : 1
photonic : 2
photooxidation : 1
photophysical : 2 1
photoreduction : 1
photoresist : 1
photosynthesi : 1
photosynthetic : 2 1
photovoltage : 1
photovoltaic : 2 1
phylogenetic : 1
physical : 2
physicist : 1
physicochemical : 1
physiological : 1
physiologically : 1
phytoplankton : 1
piezoelectric : 2
plasma : 3 2 1
plasma-assisted : 1
plasma-enhanced : 1
plasmid : 2
plastic : 2
platinum : 2
platinum-electrodes : 1
pluripotent : 1
pluronic : 1
pmol : 1
pna : 1
polariton : 1
polarity : 1
polarizability : 1
polarization : 1
polyacrylonitrile : 1
polyamidoamine : 2 1
polyaniline : 2
polyanion : 1
polycation : 1
polyclonal : 1
polycyclic : 2
polycystic : 1
polyelectrolyte : 1
polyethylene-glycol : 1
polygonal : 1
polyisohexylcyanoacrylate : 2 1
polymer : 3 2
polymer-controlled : 2
polymer-matrix : 1
polymer-mediated : 1
polymer-nanotube : 1
polymerase-chain-reaction : 1
polymerization : 1
polynomial : 1
polynucleotide : 2
polypeptide : 1
polystyrene-clay : 2
pore : 2
pore-size : 2
porou : 2
postsynthesi : 1
potassium : 2
potentiometric : 1
powder : 2
predator : 1
predictable : 1
preexist : 1
preimplantation : 1
prevalent : 1
prey : 1
primordial : 1
programme : 1
propulsion : 1
protein : 2 1
proteoglycan : 1
proton : 1
protozoa : 1
protrusion : 1
prussian : 1
psa : 1
pseudomona : 1
pt : 2
pul : 2
pulmonary : 2
pump-probe : 1
pyrazinamide : 1
pyrolytic-graphite : 1
quantum : 4 2
quantum-confined : 1
quantum-information : 1
quantum-size : 1
quantum-well : 1
quartz-crystal : 2 1
quartz-crystal-microbalance : 1
qubit : 1
quencher : 1
raman : 2
range : 3
rapid : 2
ray : 2
ray-absorption : 2 1
rbm : 1
receptor-mediated : 2
reconstitut : 1
recoverable : 2
recruitment : 1
rectification : 1
recycle : 1
redox : 1
reductive : 2
reminiscent : 1
replacement : 2
resolution : 2
resonance : 2
resonant : 2
retardancy : 1
reticular : 1
reverse-osmosis : 2 1
reversed-phase : 1
rheological : 1
rifampicin : 1
rifampin : 1
rinse : 1
ripen : 1
robot : 1
robotic : 1
robustne : 1
rose : 1
rotational : 1
rotaxane : 1
rough : 2
rta : 1
s-layer : 1
saccharomyce : 1
salen : 1
salmonella-typhimurium : 1
saturation : 2
scan : 3 2
scanning-tunneling-microscopy : 1
scatter : 3
sclerosi : 1
screen-printed : 1
selenium : 1
self-assembled : 2 1
self-assembly : 1
self-catalyzed : 1
self-consistent : 1
self-organization : 1
self-organize : 1
self-organized : 1
self-renewal : 1
sem : 1
semi-conducting : 1
semi-crystalline : 1
semiconductor : 3 2 1
semiempirical : 1
sen : 2
sensitization : 1
sensitizer : 1
sensory : 1
sequence-specific : 1
sequester : 1
shape-controlled : 2
shape-dependent : 1
shape-memory : 1
sheath : 1
short-channel : 1
si : 5
sidewall : 2 1
silica : 2
silicate : 2
silicon : 2
silicon-carbide : 1
siloxane : 2
silver : 2
simpler : 1
single : 4 3 2
single-cell : 1
single-crystal : 2 1
single-crystalline : 1
single-crystals : 1
single-electron : 2 1
single-layer : 1
single-molecule : 2 1
single-nucleotide : 2 1
single-qubit : 1
single-wall : 2
single-walled : 3 2 1
skeletal : 1
skeletal-muscle : 1
skeleton : 1
small : 3
small-angle : 2
small-molecule : 1
smectite : 1
soft : 2
sol-gel : 1
solar : 2 1
solar-cell : 1
solid : 3
sonication : 1
sonochemical : 1
spacecraft : 1
sparse : 1
spatio-temporal : 1
spectral : 2
spectrophotometric : 1
spectroscopy : 1
spermatozoa : 1
spherical : 3
spheroidal : 1
spin : 2
spin-assisted : 1
spin-based : 1
spin-coating : 1
spin-orbit : 2
spin-transfer : 1
spm : 1
spontaneou : 2
spr : 2
squid : 1
ssdna : 1
stabilize : 3
stabilizer : 1
stack : 2
stacking-fault : 2 1
staphylococcal : 1
staphylococcal-enterotoxin-b : 1
staphylococcu : 1
starburst : 2
stealth : 1
steer : 1
stem-cells : 1
stoke : 1
stone : 2
strain-rate : 2
strained-layer : 2 1
strik : 1
structure : 2
structure-based : 1
structure-function : 1
structure-property : 1
subband : 1
subcutaneou : 1
submicrometer : 1
submicron : 1
submicroscopic : 1
sulfonic : 1
sun : 3
supercapacitor : 1
superconductor : 1
supercool : 3
supercritical : 2
superhard : 2
superlattice : 1
superparamagnetic : 3 2 1
superplastic : 1
support : 3
supramolecular : 2 1
supramolecule : 1
surface : 3 2
surface-area : 1
surface-confined : 1
surface-emitting : 1
surface-enhanced : 1
surface-immobilized : 1
surface-layer : 1
surface-related : 1
surface-to-volume : 1
surfactant-assisted : 1
surfactant-templated : 1
surgical : 1
swnt-based : 1
synapse : 1
t : 2
t-cells : 1
target : 3 2
teeth : 1
temperature : 2
temperature-dependent : 1
template-directed : 1
term : 1
tetrapod : 1
tetrathiafulvalene : 2 1
thermal : 2 1
thermal-conductivity : 1
thermal-stability : 1
thermodynamically : 1
thermomechanical : 1
thermoset : 1
thin : 2
thin-film : 2
thin-films : 1
three-dimensional : 3
three-qubit : 1
threshold : 2
time-resolved : 2
tin : 2
tio2 : 2
tissue : 2
tissue-engineering : 1
titanium : 3 2
titanium-dioxide : 2 1
tobacco-mosaic-virus : 1
tooth : 1
top-down : 1
topographical : 1
topological : 1
torque : 1
toughen : 1
toughne : 1
toxic : 1
toxicology : 1
trabecular : 1
transconductance : 1
transcriptase-polymerase : 1
transcription : 2
transcriptional : 1
transfection : 2
transfer : 3
transform : 2
transformation : 1
transient : 2
transition : 2
transmission : 3 2
transparent : 3
transplantation : 1
transport : 2
transport-properties : 1
transporter : 1
tribological : 1
trichloroethylene : 1
tridentate : 1
trititanate : 2 1
trophic : 1
tumor : 1
tunnel : 2
two-body : 1
two-dimensional : 1
two-electron : 1
two-qubit : 1
two-terminal : 1
ultra-fine : 1
ultrafiltration : 1
ultrafine : 2 1
ultrafine-grained : 1
ultrahard : 1
ultrahigh-density : 1
ultralong : 1
ultrasonic : 2
ultrathin : 2 1
uniaxially : 3 1
unidirectional : 1
uniform : 3
unimolecular : 2
unle : 1
uv : 2
vacancy : 1
vaccination : 1
vacuole : 1
vacuum : 1
valley : 1
vapor : 2
vapor-deposition : 1
vapor-liquid-solid : 1
vapour : 1
vapour-liquid-solid : 1
vascular-permeability : 1
vehicle : 2
vertically : 4
vesicular : 1
vibration : 1
vibrational : 2
viral : 1
viruse : 1
viscoelasticity : 1
viscosity : 1
vitreou : 1
volatile : 3
water : 2
water-in-oil : 1
water-solubilization : 1
water-soluble : 2
wavelength : 1
waxd : 1
wet : 3 2
whisker : 1
whole-blood : 1
work : 2
ws2 : 2
x-ray : 1
x-ray-scattering : 1
xenograft : 1
yeast : 1
zno : 2
__END_OF_WLen__
2-dimensional	3d	absorption fine-structure	absorption property	absorption-spectroscopy	acid-base	
acoustical	acrosome	activation energy	activation volume	adamantanoid	adamantanoid chelate complexe	adsorption property	aerodynamic	
aerodynamic lense	aethalometer	afm	ag nanocrystal	ag nanoparticle	agricultural	air pollution	air-pollution	
airborne	aircraft	albumin	alkali-metal	alkali-metal ion	alkanethiol monolayer	alkanethiolate monolayer	alkylation	
all-optical	allotrope	alloy catalyst	allylamine	alternation	aluminophosphate	aluminum-alloys	alveolar	
alveolar macrophage	ambipolar	amidoamine	amino-acid	amorphou carbon	amorphou intergranular film	amorphous-alloys	amperometric biosensor	
amphiphile	amphiphilic block-copolymers	amphotericin-b	amplicon	analogou	angele	angiogenic	angle neutron-scattering	
anhydride	anion-exchange	anion-exchange property	anisotropy	anodic deposition	anodization	antibiotic	antibody-coated	
antibunch	anticro	antigen-antibody	antimicrobial	antitubercular	antiviral	aortic	apatite	
apolipoprotein	aquatic	arabidopsis-thaliana	architectural	arg-gly-asp	argon adsorption	aromatic-hydrocarbons	array biosensor	
artificial muscle	artificial photosynthesi	atom	atomic force	atomic force microscope	atomic-force	atomic-layer	atomic-layer deposition	
atomic-level	atomic-resolution	atomic-scale	atomic-structure	atomistic	atomistic simulation	au nanoparticle	aureu	
automata	autosomal	axon	axonal	azo dye	bacilli	bacterioplankton	bacterium	
balb	band gap	base-pair	bend instability	beta-cyclodextrin	beta-ga2o3 nanowire	bienzyme	biexciton	
bimetallic nanoparticle	binuclear complexe	bioactive	biocatalytic	biochemically	biocompatibility	bioconjugate	bioconjugation	
biodegradable	biodegradable polymer	biodegradable polymer scaffold	biodegradation	bioengineer	biofilm	bioinformatic	bioinorganic	
biological	biological application	biologist	biomedical	biomedical application	biomimicry	biomolecular	biomolecular interaction	
biophysical	biopolymer	biorecognition	biosen	biosensor	biotin-functionalized	biotinylate	biphenyl	
bipolar	birefringence	block copolymer	block-copolymer	block-copolymers	blood-brain barrier	bloom	blue shift	
blueshift	bn nanotube	bond-dissociation energy	bone formation	bone-formation	borohydride	boron-nitride nanotube	bottom-up	
boundary diffusion creep	braid	brillouin	bronchoalveolar	butyric	c-60 molecule	c-axis	c-terminus	
cadmium selenide nanocrystal	calcification	calcite	cancer-therapy	cantilever	capillary condensation	capillary electrophoresi	capsid	
carbon black	carbon cage	carbon cluster	carbon film	carbon nanofiber	carbon nanotube	carbon nanotube composite	carbon nanotube field-effect transistor	
carbon nanotube transistor	carbon-monoxide oxidation	carbon-nanotube	carbon-nanotube transistor	carbonate apatite	carbosilane	cardiovascular	cardiovascular disease	
cartilage	casein	catalyst concentration	catalytic activity	catalytic growth	catenane	cation-ether	cation-ether complexe	
cationic	cationic lipid	cationic surfactant	cdse nanocrystal	cdse quantum dot	cdte nanocrystal	cell	cell adhesion	
cell proliferation	cell wall	cell-matrix	cell-specific	cell-wall	cellular automata	cement	centrifugation	
ceo2 single-crystals	cerevisiae	cervical	chain-transfer	chalcogenide	charg exciton	charge recombination	chelator	
chemical sensor	chemical vapor deposition	chemical-analysis system	chemical-synthesis	chemical-vapor-deposition	chemotaxi	chimeric	chitosan nanoparticle	
chitosan-dna	chlorinate	chlorophyll	chloroplast	cholesterol	chromatin	chromosome	ciliate	
circumferential	circumvent	citation	clay nanocomposite	clinical	cnt	cntfet	coagulation	
coarse-grained	cochlea	coherence	collagen nanofiber	colloidal crystal	colloidal gold	colloidal particle	coloration	
composite film	composite material	composite-materials	concentration and size distribution	conduct polyaniline	conductance quantization	configur	conformational dynamic	
conical	contaminant	contaminate groundwater	contemporary	continuum model	controll drug-delivery	controll release	controlled-release	
convective	copolymer	coral	core / shell nanocrystal	core-shell nanoparticle	coreceptor	corona	cortical	
coulomb blockade	coulomb interaction	coulomb-blockade	coupl reaction	covalently	crossbar	crown-ethers	cryogenic	
cryomill	crystal	crystal-growth	crystal-structure	crystallinity	crystallization	crystallization behavior	crystallize	
current-driven	cvd	cystic	dark-field	dealt	decoherence	deformation-mechanism	dehydrate	
dehydration	dehydrogenase-based	dehydrogenation	deleteriou	delivery-system	dendrimer-based	dendrimer-encapsulated	dendrite	
dendritic	dendritic macromolecule	dendritic polymer	dendron	density oligonucleotide array	dental	dentin	deplet	
der-waals	der-waals force	desorption	deterministically	detoxification	detrital	deviate	dialysi	
diamond-like carbon	diatom	diazonium	diblock copolymer	dicarboxylate	dielectric constant	dielectric function	diesel	
differential scan calorimetry	diffusional	digestion	dip-coating	dip-pen	dip-pen nanolithography	direct electrochemistry	direct electron-transfer	
discrete-dipole	discrete-dipole approximation	discriminatory	distal	distinctly	dl-lactide-co-glycolide	dmfc	dna	
dna biosensor	dna molecule	dna sensor	dna-based	dna-damage	dominance	dopamine	dope	
double quantum dot	double-gate	double-strand	double-stranded dna	double-wall	down-regulation	downwind	doxorubicin	
doxorubicin-loaded	doxorubicin-loaded nanoparticle	droplet	drug	drug delivery	drug delivery system	duplex	dust	
dye-sensitized	dye-sensitized solar cell	dynamic kinetic resolution	e-beam	ecological	ecosystem	elastic property	elasticity	
elastomeric	elastomeric phase mask	electric field	electric property	electric-field	electrical conductivity	electrical property	electrical-properties	
electrical-transport	electroanalytical	electrochemical	electrochemical biosensor	electrochemical detection	electrochemical energy-storage	electrochemical oxidation	electrochemical property	
electrochemical reduction	electrochemical sensor	electrochemistry	electrodeposition	electroluminescence	electrolyte composition	electromagnetic	electromagnetic energy-transport	
electromechanical	electromigration	electron beam	electron diffraction	electron emission	electron injection	electron microscopy	electron transfer	
electron-beam	electron-beam lithography	electron-deficient	electron-electron	electron-hole	electron-microscopy	electron-spin	electron-transfer	
electron-transfer reaction	electronic nose	electronic property	electronic state	electronic-properties	electrooxidation	electrospin	electrospray-ionization	
electrospun	electrostatically	ellipsometry	elongate	embryonal	embryonic stem-cells	empirical	emulsification	
emulsion polymerization	enamel	encapsulate	energy level	energy-transport	enlargement	entanglement	enterotoxin	
entrance	entrapment	entropy	environmental photochemistry	enzyme	enzyme electrode	enzyme-immunoassay	epiblast	
epilayer	episode	epitaxial growth	epitaxial thin-films	epitaxial-growth	epitaxially	epitaxy	epithelia	
epithelium	epitope	epoxidation	epoxy nanocomposite	error-correcting code	error-correction	ethic	ethical	
eukaryote	eukaryotic	european	evaporation	evaporation-induced	exciton-phonon	extracellular matrix	extrapolation	
extruder	far-field	fatty acid	fault-tolerant	favorably	favour	fcc metal	fe-sem	
fe3o4 nanoparticle	femtosecond	fermi	ferritin	ferromagnet	ferromagnetic	ferromagnetism	ferumoxide	
few-electron	fibril	field emission	field-effect	field-effect transistor	field-emission	filamentou carbon	fine particle	
fine-grained	fine-grained material	fixation	flagellate	flip-flop	flow-injection	fluorescence correlation spectroscopy	fluorescence microscopy	
fluorescence photobleach recovery	fluorescence-based	fluorescent nanocrystal	fluorescently	fluxe	focu ion beam	foodborne	force microscope	
fossil	four-wave	free radical	free-radical polymerization	fresh-water	freshwater	frictional	frontline	
fry	fsp	fuel cell	fullerene-like	functionalize gold nanoparticle	fungal	fungi	fur	
gallium nitride	gallium nitride nanowire	gan film	gan nanowire	gas phase	gas shift reaction	gene-therapy	gene-transfer	
gene-transfer agent	genome-wide	geological	geometrical	germ-cells	giant magnetoresistance	glass-transition	glioma	
globular	glucose oxidase	glucose-oxidase	goethite	gold catalyst	gold electrode	gold nanoparticle	gold surface	
gpi-anchored	gpi-anchored protein	grain aluminum-alloys	grain boundary	grain size	grain-boundaries	grain-size	gram	
gram-negative	granular film	graphite surface	gravitational	gravity	grazing-incidence	green ' s function	greens-function	
ground state	groundwater	growth-mechanism	guinea	h-bond	hairpin	half-life	half-lives	
hall-petch	halpin-tsai	handheld	harne	heavy-duty	helical	helice	hematite	
hemicellulose	hemoglobin	hepatiti	hepatitis-b-virus	heteroepitaxial	heterogeneou catalyst	heterogeneou photocatalysi	heterojunction	
heterostructur	heterostructure	heterotrophic	heterotrophic bacteria	heterotrophic nanoflagellate	hexagon	hexagonal pore array	hexagonally	
high-aspect-ratio	high-spin molecule	highly crystalline	highly fluorescent analog	hipco	histological	hiv	hole mobility	
hollow interior	hollow sphere	homogeneou	horseradish	host-guest chemistry	hove	hrem	hrtem	
human sperm	humidity sensor	hydraulic	hydrodynamic interaction	hydrogen adsorption	hydrogen bond	hydrogen peroxide	hydrogen-bond	
hydrogen-bonding	hydrophilicity	hydrophobic	hydrophobicity	hyperbranch polymer	hyperfine	hypersensitivity	hypervariable	
hypothese	hysteretic	iii-v semiconductor	immersion	immune response	immunization	immunodeficiency	immunogenicity	
immunoglobulin	immunohistochemical	immunological	immunomagnetic	immunomagnetic separation	immunosensor	immunotherapy	impedance	
implantation	imprint lithography	in-vivo	ina quantum dot	incubate	indistinguishable	indium-phosphide	indium-phosphide nanowire	
indium-tin	individual carbon nanotube	individual molecule	indocyanine	infiltration	influenza	influx	infrared-active	
inhalation	inhomogeneity	inhomogeneou	injector	inorganic material	inorganic nanotube	instillation	integrin-targeted	
interfacial electron-transfer	interferometer	intergranular	interlock	intermetallic	interstitium	intestinal	intestine	
intracranial	intranasal	intraoperative	intratracheal instillation	intravenou	intravenously	invitro	ion	
ion implantation	ion-beam	ion-exchange	ionization	ipce	iron-oxide nanoparticle	isotope	isotopic	
josephson-junction	kaolinite	keratinocyte	kernel	kinesin	kinetically	lactic	lactic-co-glycolic	
lactide-co-glycolide	lamellae	landauer	langmuir-blodgett	langmuir-blodgett monolayer	larval	laser ablation	laser-ablation	
lateral diffusion	lattice relaxation	lavage	layer silicate nanocomposite	layered-silicate nanocomposite	leach	leishmania	length-scale	
lennard-jones	lethal	leukemia inhibitory factor	light intensity	light-emitting	light-emitting device	light-emitting diode	light-emitting-diodes	
light-induced degradation	light-scattering	lignin	limb	line shape	lineage	lipid raft	lipoprotein	
liposomal	liposome	liquid crystal	liquid jet	liquid-crystal	liquid-crystalline phase	liquid-phase oxidation	liquid-solid growth	
listeria-monocytogenes	lithography	liv cell	localize surface plasmon resonance	locomotion	long-circulating	low-temperature synthesi	lspr	
lubrication	lucent	luminescence property	lymphatic	lysozyme	macrocyclic tetranuclear complexe	macromolecular	macroscale	
macroscopic quantum state	magnetic anisotropy	magnetic force microscopy	magnetic multilayer	magnetic nanoparticle	magnetic particle	magnetic property	magnetic-anisotropy	
magnetic-properties	magnetism	magnetization	magnetization reversal	magnetophotoluminescence	magnetoresistance	magnetoresistive	magnetron sputter	
maltose	mat	mater	materialia	matrix metalloproteinase	maturation	mbe	mechanical property	
mechanical-behavior	medicale	medication	mediterranean	melanoma	melt-intercalation	mem device	membrane	
membrane reactor	mems-based	mesenchymal stem-cells	mesoporou film	mesoporou molecular sieve	mesoporou titania	mesoscale	mesoscopic	
mesoscopic superstructure	mesostructur and mesoporou material	mesostructur material	messenger-rna	metabolite	metal nanoparticle	metal nanostructure	metal nanowire	
metal-insulator	metal-insulator-transition	metal-molecule	metal-organic framework	metal-oxide-semiconductor	metal-to-ligand	metallic gla	metallic nanoparticle	
metallurgica	metastable	methanol fuel-cells	microarray	microbe	microbeam	microbial	microbial food web	
microcapsule	microcavity	microchannel	microchip	microcrystallite	microelectrode	microelectromechanical	microelectromechanical system	
microencapsulation	microfabricate	microfabricate device	microfibril	microfluidic	microhardne	micromagnetic	micromechanic	
micromechanical	microorganism	microphase	micropore	microporou material	microscope	microscopy	microsphere	
microstructural	microstructure	microsystem	microvalve	millimeter	mineralization	minimization	mismatche	
mitochondrial dna	mmt	molecular	molecular architecture	molecular beacon	molecular beam epitaxy	molecular device	molecular dynamic	
molecular dynamic simulation	molecular imag	molecular junction	molecular model	molecular motor	molecular recognition	molecular switch	molecular weight	
molecular wire	molecular-beam	molecular-beam epitaxy	molecular-dynamics	molecular-dynamics simulation	molecular-oxygen	molecular-scale	molecular-sieves	
molecular-switch	molecularly	molecule	mono-dispersed	monoclonal-antibody	monocrystalline	monolayer	monomer	
mori-tanaka	morphogenetic	morphological	morphologically	morphology	mqw	mram	mucosa	
multi-wall carbon nanotube	multi-walled carbon nanotube	multidrug-resistance	multimetallic	multiquantum	multiwall carbon nanotube	mutate	mwnt	
mycobacterium	myoglobin	myosin	n-isopropylacrylamide	n-zno	nano	nano-adsorbent	nano-composites	
nano-crystal	nano-electronic	nano-indentation	nano-optoelectronics	nano-pores	nano-size	nano-technology	nanoassembly	
nanobacteria	nanobacterial	nanobarcode	nanobelt	nanobiotechnology	nanocable	nanocage	nanocantilever	
nanocapsule	nanocatalyst	nanocavity	nanochannel	nanochemistry	nanochip	nanoclay	nanocluster	
nanocolloid	nanocomb	nanocomposite	nanocomposite coate	nanocrystal	nanocrystalline	nanocrystalline copper	nanocrystalline diamond	
nanocrystalline metal	nanocrystalline microstructure	nanocube	nanocylinder	nanodevice	nanodisk	nanodot	nanoelectrode	
nanoelectrode array	nanoelectromechanical	nanoelectrospray	nanofabrication	nanofiber	nanofibre	nanofibrou	nanofiltration	
nanofiltration membrane	nanoflagellate	nanoflare	nanofluidic	nanogold	nanoindentation	nanoindenter	nanoleakage	
nanomechanical	nanomedicine	nanomembrane	nanometer scale	nanometre-scale	nanomorphology	nanoparticle	nanoparticle array	
nanoparticle-based detection	nanophase material	nanophotonic	nanoplankton	nanoplate	nanopore	nanoprism	nanoprobe	
nanoreactor	nanoresonator	nanoscale	nanoscale graphitic tubule	nanoscience	nanosize	nanosize particle	nanosphere	
nanosphere lithography	nanostructur material	nanostructur metal	nanosystem	nanotechnological	nanotechnology	nanotip	nanotriangle	
nanotube	nanotube / polymer composite	nanotube-based	nanotube-polymer	nanotube-polymer composite	nanotube-reinforced	nanowire	nanowire array	
nanowire growth	nanowire-based	near-field	near-field structure	near-infrared	neointimal	neonatal	neovasculature	
neutron-capture	neutron-capture therapy	neutron-scattering	nitrite	nitrogen adsorption	non-viral	non-volatile	non-woven	
nonequilibrium	nontoxic	northeast	northern	nose	novo	nsom	nuclear	
nuclear spin	nucleation	nuclei	nucleic	nucleic acid	nucleic-acid	nucleic-acids	nutrient	
ocular	oil-in-water	olive	one-dimensional	one-dimensional nanostructure	one-qubit	optical biosensor	optical fiber	
optical imag	optical property	optical spectroscopy	optical-absorption	optoelectronic	optoelectronic application	order mesoporou	organ	
organic group	organic matrix	organic-surfaces	organisation	orthopaedic	osmosi	osteogenic	outer hair cell	
oxide composite catalyst	oxide fuel-cells	oxide nanoparticle	oxide nanotube	oxide-based	oxidi	oxidic	oxygen reduction	
oxygen-reduction catalyst	oxygen-terminated	ozone	p-terphenyl	palladium nanoparticle	pancreatic	para-terphenyl	para-terphenyl crystal	
paracrystalline	parasite	particle number concentration	particle size	particle track	particle-mediated	particle-specific	particulate air-pollution	
particulate matter	paste	paste electrode	pathogen	pathogenic	pathological	pave	payload	
pcr amplification	peak-to-valley	pegylation	pentagon	periodic mesoporou organosilica	persistent-current	persistent-current qubit	persulphate	
perylene	pesticide	phage	phagokinetic	phagokinetic track	pharmaceutical	pharmacological	phase epitaxial-growth	
phase separation	phase transformation	phase transition	phenotypic	phonon	phonon interaction	phosphatidylcholine	phospholipid	
phosphonium	phosphoprotein	phosphorylate	photo-induced	photo-optical	photoactivity	photobleach	photocatalyst	
photocatalytic	photocatalytic degradation	photocatalytic oxidation	photochemical	photodegradation	photodetector	photoelectrochemical	photoelectrochemical property	
photoelectron	photoelectron-spectroscopy	photoemission	photoexcitation	photogeneration	photoinduc electron-transfer	photolithography	photoluminescence	
photoluminescence property	photon	photonic crystal	photooxidation	photophysical	photophysical property	photoreduction	photoresist	
photosynthesi	photosynthetic	photosynthetic reaction-center	photovoltage	photovoltaic	photovoltaic cell	photovoltaic device	phylogenetic	
physical evaporation	physicist	physicochemical	physiological	physiologically	phytoplankton	piezoelectric biosensor	piezoelectric field	
plasma	plasma membrane	plasma membrane compartment	plasma-assisted	plasma-enhanced	plasmid dna	plastic deformation	platinum nanoparticle	
platinum-electrodes	pluripotent	pluronic	pmol	pna	polariton	polarity	polarizability	
polarization	polyacrylonitrile	polyamidoamine	polyamidoamine dendrimer	polyaniline nanofiber	polyanion	polycation	polyclonal	
polycyclic aromatic-hydrocarbons	polycystic	polyelectrolyte	polyethylene-glycol	polygonal	polyisohexylcyanoacrylate	polyisohexylcyanoacrylate nanoparticle	polymer matrix	
polymer melt intercalation	polymer nanofiber	polymer-controlled crystallization	polymer-matrix	polymer-mediated	polymer-nanotube	polymerase-chain-reaction	polymerization	
polynomial	polynucleotide molecule	polypeptide	polystyrene-clay nanocomposite	pore size	pore-size distribution	porou alumina	postsynthesi	
potassium channel	potentiometric	powder microelectrode	predator	predictable	preexist	preimplantation	prevalent	
prey	primordial	programme	propulsion	protein	protein adsorption	protein crystallization	protein electrochemistry	
protein identification	proteoglycan	proton	protozoa	protrusion	prussian	psa	pseudomona	
pt particle	pul electrodeposition	pulmonary toxicity	pump-probe	pyrazinamide	pyrolytic-graphite	quantum computation	quantum computer	
quantum confinement	quantum dot	quantum dot infrar photodetector	quantum effect	quantum efficiency	quantum transport	quantum wire	quantum yield	
quantum-confined	quantum-information	quantum-size	quantum-well	quartz-crystal	quartz-crystal microbalance	quartz-crystal-microbalance	qubit	
quencher	raman scatter	raman spectroscopy	range distance dependence	rapid detection	ray photoelectron-spectroscopy	ray-absorption	ray-absorption spectroscopy	
rbm	receptor-mediated endocytosi	reconstitut	recoverable catalyst	recruitment	rectification	recycle	redox	
reductive dechlorination	reminiscent	replacement reaction	resolution electron-microscopy	resonance energy-transfer	resonant tunnel	retardancy	reticular	
reverse-osmosis	reverse-osmosis membrane	reversed-phase	rheological	rifampicin	rifampin	rinse	ripen	
robot	robotic	robustne	rose	rotational	rotaxane	rough surface	rta	
s-layer	saccharomyce	salen	salmonella-typhimurium	saturation magnetization	scan electron microscopy	scan electron-microscopy	scan force microscopy	
scan optical microscopy	scan probe	scan probe lithography	scan probe microscopy	scan tunnel microscope	scan tunnel microscopy	scanning-tunneling-microscopy	scatter submicroscopic particle	
sclerosi	screen-printed	selenium	self-assembled	self-assembled monolayer	self-assembly	self-catalyzed	self-consistent	
self-organization	self-organize	self-organized	self-renewal	sem	semi-conducting	semi-crystalline	semiconductor	
semiconductor cluster	semiconductor device	semiconductor device model	semiconductor nanocrystal	semiconductor nanostructure	semiconductor nanowire	semiempirical	sen property	
sensitization	sensitizer	sensory	sequence-specific	sequester	shape-controlled synthesi	shape-dependent	shape-memory	
sheath	short-channel	si / sige superlattice nanowire	sidewall	sidewall functionalization	silica film	silica nanoparticle	silica thin-films	
silicate layer	silicon nanowire	silicon nitride	silicon-carbide	siloxane copolymer	silver nanoparticle	silver nanosphere	silver nanowire	
silver nitrate	simpler	single crystal	single photon source	single wall	single wall carbon	single wall carbon nanotube	single-cell	
single-crystal	single-crystal nanor	single-crystalline	single-crystals	single-electron	single-electron transistor	single-layer	single-molecule	
single-molecule magnet	single-molecule spectroscopy	single-nucleotide	single-nucleotide polymorphism	single-qubit	single-wall carbon	single-walled	single-walled carbon	
single-walled carbon nanotube	single-walled nanotube	skeletal	skeletal-muscle	skeleton	small reorganization energy	small-angle scatter	small-molecule	
smectite	soft lithography	sol-gel	solar	solar cell	solar light	solar-cell	solid lipid nanoparticle	
sonication	sonochemical	spacecraft	sparse	spatio-temporal	spectral diffusion	spectrophotometric	spectroscopy	
spermatozoa	spherical supramolecular dendrimer	spheroidal	spin decoherence	spin relaxation	spin-assisted	spin-based	spin-coating	
spin-orbit interaction	spin-transfer	spm	spontaneou emission	spontaneou polarization	spr biosensor	squid	ssdna	
stabilize gold nanoparticle	stabilizer	stack fault	stacking-fault	stacking-fault energy	staphylococcal	staphylococcal-enterotoxin-b	staphylococcu	
starburst dendrimer	stealth	steer	stem-cells	stoke	stone formation	strain-rate sensitivity	strained-layer	
strained-layer superlattice	strik	structure prediction	structure sensitivity	structure-based	structure-function	structure-property	subband	
subcutaneou	submicrometer	submicron	submicroscopic	sulfonic	sun : corona	supercapacitor	superconductor	
supercool liquid region	supercritical carbon-dioxide	superhard material	superlattice	superparamagnetic	superparamagnetic iron oxide	superparamagnetic iron-oxide	superparamagnetic nanoparticle	
superplastic	support gold catalyst	supramolecular	supramolecular organization	supramolecule	surface charge	surface energy	surface modification	
surface morphology	surface plasmon	surface plasmon resonance	surface property	surface structure	surface tension	surface-area	surface-confined	
surface-emitting	surface-enhanced	surface-immobilized	surface-layer	surface-related	surface-to-volume	surfactant-assisted	surfactant-templated	
surgical	swnt-based	synapse	t cell	t-cells	target drug-delivery	target paramagnetic nanoparticle	teeth	
temperature dependence	temperature-dependent	template-directed	term	tetrapod	tetrathiafulvalene	tetrathiafulvalene unit	thermal	
thermal anneal	thermal evaporation	thermal stability	thermal transport	thermal-conductivity	thermal-stability	thermodynamically	thermomechanical	
thermoset	thin film	thin-film deposition	thin-film transistor	thin-films	three-dimensional nanostructure fabrication	three-qubit	threshold voltage	
time-resolved photoluminescence	tin oxide	tio2 catalyst	tio2 electrode	tio2 nanotube	tio2 photocatalyst	tio2 powder	tio2 thin-films	
tissue distribution	tissue engineer	tissue-engineering	titanium dioxide	titanium oxide	titanium oxide nanotube	titanium oxide photocatalyst	titanium-dioxide	
titanium-dioxide film	tobacco-mosaic-virus	tooth	top-down	topographical	topological	torque	toughen	
toughne	toxic	toxicology	trabecular	transconductance	transcriptase-polymerase	transcription factor	transcriptional	
transfection efficiency	transfer radical polymerization	transform infrared-spectroscopy	transformation	transient absorption	transition temperature	transmission electron	transmission electron microscopy	
transparent conduct oxide	transplantation	transport property	transport-properties	transporter	tribological	trichloroethylene	tridentate	
trititanate	trititanate nanotube	trophic	tumor	tunnel diode	tunnel microscope	two-body	two-dimensional	
two-electron	two-qubit	two-terminal	ultra-fine	ultrafiltration	ultrafine	ultrafine particle	ultrafine-grained	
ultrahard	ultrahigh-density	ultralong	ultrasonic irradiation	ultrathin	ultrathin film	uniaxially	uniaxially align array	
unidirectional	uniform inorganic particle	unimolecular micelle	unle	uv irradiation	vacancy	vaccination	vacuole	
vacuum	valley	vapor deposition	vapor-deposition	vapor-liquid-solid	vapour	vapour-liquid-solid	vascular-permeability	
vehicle emission	vertically align carbon nanofiber	vesicular	vibration	vibrational property	viral	viruse	viscoelasticity	
viscosity	vitreou	volatile organic compound	water purification	water-in-oil	water-solubilization	water-soluble fullerene	wavelength	
waxd	wet chemical synthesi	wet chemical-synthesis	whisker	whole-blood	work function	ws2 nanotube	x-ray	
x-ray-scattering	xenograft	yeast	zno nanobelt	zno nanostructure	
