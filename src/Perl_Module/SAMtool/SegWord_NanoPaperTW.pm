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
3-dimensional : 2
3d : 1
ac : 2
activation : 2
afm : 1
ag : 2
al : 3
alkanethiol : 2
alloy : 2
amorphou : 2
amorphous-alloys : 1
angle : 2
anhydride : 1
anisotropic : 2
anisotropy : 1
anneal : 2
anodic : 2
anodization : 1
atom : 1
atomic : 3 2
atomic-force : 1
atomic-layer : 2 1
atomic-scale : 1
atomistic : 1
au : 2
auger : 3
band : 2
barrier : 2
beta-ga2o3 : 2
biexciton : 1
bind : 2
binuclear : 2
biocompatibility : 1
biosensor : 1
bipolar : 1
birefringence : 1
block : 2
block-copolymers : 1
blood-brain : 2
blue : 2
blueshift : 1
bn : 2
boron-nitride : 2
c-60 : 2
c-axis : 1
cantilever : 1
capillary : 2
carbon : 2
carrier : 2
catalytic : 2
cationic : 2 1
cdse : 2
cell : 1
center : 2
charge : 2
chemic : 3
chemical-vapor-deposition : 1
chromosome : 1
clay : 2
cnt : 1
coercive : 2
coherence : 1
colloidal : 2
composite : 2
copolymer : 1
copper : 2
core : 4
coulomb : 2
coulomb-blockade : 1
coupl : 2
covalently : 1
cryogenic : 1
crystal : 1
crystal-structure : 1
crystallinity : 1
crystallization : 1
cuo : 2
curie : 2
curie-temperature : 1
dark : 2
dehydrogenation : 1
dendritic : 2 1
deposition : 2
desorption : 1
diamond : 2
diamond-like : 2
diblock : 2
dielectric : 3 2
dielectric-properties : 1
differential : 3
dna : 2 1
domain : 2
domain-wall : 2
dot : 3
double : 2
double-stranded : 2
droplet : 1
drug : 1
e-beam : 2
elastic : 2
electric : 2
electric-field : 1
electrical-properties : 1
electrochemic : 2
electrochemical : 1
electrochemistry : 1
electrodeposition : 1
electroluminescence : 1
electromagnetic : 1
electromigration : 1
electron : 3 2
electron-beam : 1
electron-electron : 1
electron-hole : 1
electron-microscopy : 1
electron-transfer : 2 1
electronic : 2
electronic-properties : 1
electroreflectance : 1
electrostatic : 1
encapsulate : 3 1
energy : 2
energy-gap : 1
entanglement : 1
entropy : 1
enzyme : 1
epilayer : 1
epitaxial : 2
epitaxial-growth : 1
epitaxially : 1
epitaxy : 1
evaporation : 1
excimer : 2
far-field : 1
fe3o4 : 2
femtosecond : 1
fept : 2
fermi : 1
ferrite : 2
ferromagnet : 1
ferromagnetic : 1
ferromagnetism : 1
field : 3 2
field-effect : 2 1
field-emission : 1
film : 2
fluorescence : 2
focu : 3
force : 2
fuel : 2
function : 2
fundamental-band : 2
gaa : 2
gallium : 3 2
gan : 2
ge : 3 2
giant : 2
glass-transition : 1
gold : 2
grain : 2
granular : 2
green : 4
ground : 2
heteroepitaxial : 1
heterogeneou : 2
heterojunction : 1
heterostructure : 1
hexagonal : 3
high-aspect-ratio : 1
high-entropy : 1
high-resolution : 4
hole : 2
homogeneou : 2 1
hydrogen : 2
hydrogen-bonding : 1
hydrophilicity : 1
hydrophobic : 1
iii-v : 2
immersion : 1
impedance : 1
implantation : 1
imprint : 2
in-vivo : 1
ina : 3
induc : 2
infrar : 2
ingaa : 3
inhomogeneity : 1
inhomogeneou : 1
interfacial : 2
interferometer : 1
intergranular : 1
intermetallic : 1
ion : 2 1
ion-beam : 3 1
ion-exchange : 1
ionization : 1
iro2 : 2
isotope : 1
laser : 2
laser-ablation : 1
laser-scanning : 2 1
light : 3
light-emitting : 2 1
light-emitting-diodes : 1
line : 2
liquid : 2
liquid-crystal : 3 1
lithography : 2 1
localize : 3 2
luminescence : 2
magnetic : 3 2
magnetic-anisotropy : 1
magnetic-properties : 1
magnetism : 1
magnetization : 2 1
magneto-optical : 1
magnetoresistance : 2 1
magnetoresistive : 1
magnetotransport : 2
magnetron : 2
mas : 5
mechanic : 2
membrane : 1
mesoporou : 2
metal : 2
metal-insulator : 1
metal-oxide-semiconductor : 1
metallic : 2
metastable : 1
micro-photoluminescence : 1
microcavity : 1
microchip : 1
microfluidic : 1
micromagnetic : 1
microphase : 1
microporou : 2
microscope : 1
microscopy : 1
microsphere : 1
microstructur : 1
microstructural : 1
microstructure : 1
mitochondrial : 2
molecular : 3 2 1
molecular-beam : 2 1
molecular-dynamics : 2 1
molecular-sieves : 1
molecularly : 1
molecule : 1
monolayer : 1
monomer : 1
monte : 2
morphology : 1
multiple-quantum : 1
multiquantum : 1
multiwall : 3
nano-adsorbent : 1
nano-rings : 1
nanobelt : 1
nanocatalyst : 1
nanocavity : 1
nanochannel : 1
nanocluster : 1
nanocomposite : 1
nanocrystal : 1
nanocrystalline : 3 2 1
nanodevice : 1
nanodot : 1
nanofabrication : 1
nanofiber : 1
nanoindentation : 1
nanomechanical : 1
nanoparticle : 1
nanopore : 1
nanorode : 1
nanoscale : 1
nanosize : 1
nanosphere : 1
nanotip : 2 1
nanotube : 2 1
nanowire : 2 1
near-field : 3 2 1
near-infrared : 1
neutron-scattering : 1
nonequilibrium : 1
nonlinear : 2
nuclear : 3 1
nucleation : 1
nuclei : 1
nucleic-acids : 1
one-dimensional : 2 1
optic : 2
optoelectronic : 2 1
order-disorder : 1
organic : 3
organoclay : 2
oxide : 2
particle : 2
phase : 2
phonon : 1
phosphor : 1
photo-optical : 1
photocatalyst : 1
photodetector : 1
photoelectron : 2 1
photoelectron-spectroscopy : 1
photoemission : 2 1
photoexcitation : 1
photoinduc : 2
photolithography : 1
photoluminescence : 1
photon : 1
photonic : 3 2
photophysic : 2
photoreflectance : 1
photoresist : 1
photosensitive : 1
photovoltaic : 2 1
physic : 2
piezoelectric : 2
planar : 2
plasma : 2 1
plasma-assisted : 1
plasma-enhanced : 1
polariton : 1
polarity : 1
polarizability : 1
polarization : 1
polarize : 2
polyimide : 2
polymerization : 1
pore : 2
porou : 2
protein : 2 1
proton : 1
pseudomorphic : 1
pt : 2
pulsed-laser : 2
pump-probe : 1
quantum : 4 2
quantum-confined : 1
quantum-well : 1
raman : 2
rapid : 3
ray : 2
reactive : 2
redox : 1
resonant-tunneling : 2
rhodium-catalyzed : 1
ruo2 : 2
sample : 2
saturation : 2
scan : 3 2
scanning-tunneling-microscopy : 1
self-aligned : 1
self-assemblable : 1
self-assembled : 3 2 1
self-assembly : 1
self-catalyzed : 1
self-consistent : 1
self-organization : 1
self-organized : 1
semiconductor : 2 1
sidewall : 1
silica : 2
silicon : 2
siloxane : 2
silver : 2
single : 2
single-atom : 2
single-crystal : 2 1
single-crystalline : 1
single-crystals : 1
single-electron : 2 1
single-layer : 1
single-walled : 3 1
small-angle : 3
sol-gel : 1
spectroscopic : 2
spectroscopy : 1
spheric : 2
spin : 2
spin-coating : 1
spin-dependent : 2
spin-orbit : 2
spin-valve : 2
spontaneou : 2
stoke : 1
strain : 2
strain-induced : 1
subband : 1
sublattice : 1
sublayer : 1
submicrometer : 1
submicron : 1
super-resolution : 3
supercapacitor : 1
superconductor : 1
supercool : 3
superlattice : 1
superparamagnetic : 1
support : 3
supramolecular : 1
supramolecule : 1
surface : 3 2
surface-emitting : 1
surface-enhanced : 1
temperature : 2
temperature-dependent : 1
thermal : 2 1
thermal-stability : 1
thermodynamically : 2 1
thin : 2
thin-film : 2
thin-films : 1
threshold : 2
time-resolved : 2
tio2 : 2
titanium : 2
titanium-dioxide : 1
transconductance : 1
transformation : 1
transition : 2
transmission : 3 2
transport : 2
transport-properties : 1
tridentate : 1
tumor : 1
tunnel : 2
two-dimensional : 1
ultrafine : 2 1
ultrathin : 2 1
unlike : 3
vacancy : 1
vacuum : 1
vapor : 2
vapor-deposition : 1
vapor-liquid-solid : 1
vapour : 1
vertical-cavity : 2
vibration : 1
viscosity : 1
wavelength : 1
whisker : 1
work : 2
x : 2
x-ray : 6 1
x-ray-scattering : 1
__END_OF_WLen__
2-dimensional	3-dimensional monolayer	3d	ac impedance	activation energy	afm	ag nanowire	al / gaa	
alkanethiol monolayer	alloy catalyst	amorphou carbon	amorphou state	amorphous-alloys	angle neutron-scattering	anhydride	anisotropic magnetoresistance	
anisotropy	anneal temperature	anodic deposition	anodization	atom	atomic force	atomic force microscope	atomic-force	
atomic-layer	atomic-layer deposition	atomic-scale	atomistic	au nanoparticle	auger electron spectroscopy	band gap	barrier layer	
beta-ga2o3 nanowire	biexciton	bind energy	binuclear complexe	biocompatibility	biosensor	bipolar	birefringence	
block copolymer	block-copolymers	blood-brain barrier	blue shift	blueshift	bn nanotube	boron-nitride nanotube	c-60 molecule	
c-axis	cantilever	capillary electrophoresi	carbon film	carbon nanofiber	carbon nanotube	carrier localization	catalytic activity	
catalytic growth	cationic	cationic surfactant	cdse nanocrystal	cell	center dot	charge transport	chemic vapor deposition	
chemical-vapor-deposition	chromosome	clay nanocomposite	cnt	coercive force	coherence	colloidal crystal	colloidal particle	
composite film	copolymer	copper ion	copper nanoparticle	core / shell nanocrystal	coulomb interaction	coulomb-blockade	coupl reaction	
covalently	cryogenic	crystal	crystal-structure	crystallinity	crystallization	cuo nanoparticle	curie temperature	
curie-temperature	dark current	dehydrogenation	dendritic	dendritic macromolecule	deposition technique	desorption	diamond film	
diamond-like carbon	diblock copolymer	dielectric constant	dielectric function	dielectric property	dielectric tunnel capacitance	dielectric-properties	differential scan calorimetry	
dna	dna molecule	domain inversion	domain structure	domain wall	domain-wall motion	dot infrar photodetector	double perovskite	
double-stranded dna	droplet	drug	e-beam lithography	elastic property	electric characteristic	electric conductivity	electric field	
electric property	electric resistivity	electric-field	electrical-properties	electrochemic property	electrochemical	electrochemistry	electrodeposition	
electroluminescence	electromagnetic	electromigration	electron beam	electron diffraction	electron diffraction pattern	electron emission	electron field-emission	
electron microscopy	electron mobility	electron trap	electron-beam	electron-electron	electron-hole	electron-microscopy	electron-transfer	
electron-transfer reaction	electronic property	electronic state	electronic-properties	electroreflectance	electrostatic	encapsulate	encapsulate gold nanoparticle	
energy level	energy-gap	entanglement	entropy	enzyme	epilayer	epitaxial film	epitaxial growth	
epitaxial-growth	epitaxially	epitaxy	evaporation	excimer laser	far-field	fe3o4 nanoparticle	femtosecond	
fept thin-films	fermi	ferrite nanoparticle	ferromagnet	ferromagnetic	ferromagnetism	field emission	field emission property	
field-effect	field-effect transistor	field-emission	film deposit	film thickne	fluorescence microscopy	fluorescence quench	focu ion beam	
force microscope	fuel cell	function theory	fundamental-band gap	gaa quantum	gaa substrate	gallium nitride	gallium nitride nanorode	
gallium nitride nanowire	gan film	gan nanowire	gan quantum-well	gan thin-films	ge dot	ge qds	ge quantum dot	
giant magnetoresistance	glass-transition	gold catalyst	gold nanoparticle	gold nanorode	gold surface	grain size	granular film	
green ' s function	ground state	heteroepitaxial	heterogeneou catalysi	heterojunction	heterostructure	hexagonal mesoporou silica	hexagonal pore array	
high-aspect-ratio	high-entropy	high-resolution transmission electron microscope	hole mobility	homogeneou	homogeneou catalysi	hydrogen adsorption	hydrogen bond	
hydrogen-bonding	hydrophilicity	hydrophobic	iii-v semiconductor	immersion	impedance	implantation	imprint lithography	
in-vivo	ina quantum dot	induc nanohelixe	infrar photodetector	ingaa quantum dot	inhomogeneity	inhomogeneou	interfacial layer	
interfacial reaction	interferometer	intergranular	intermetallic	ion	ion bombardment	ion implantation	ion-beam	
ion-beam deposition technique	ion-exchange	ionization	iro2 nanorod	isotope	laser ablation	laser lift-off	laser-ablation	
laser-scanning	laser-scanning microscopy	light emit diode	light-emitting	light-emitting device	light-emitting diode	light-emitting-diodes	line shape	
liquid crystal	liquid-crystal	liquid-crystal thin film	lithography	lithography technique	localize electrochemic deposition	localize exciton	localize surface plasmon	
luminescence property	magnetic anisotropy	magnetic domain	magnetic force microscopy	magnetic nanoparticle	magnetic particle	magnetic property	magnetic susceptibility	
magnetic tunnel junction	magnetic-anisotropy	magnetic-properties	magnetism	magnetization	magnetization reversal	magneto-optical	magnetoresistance	
magnetoresistance ratio	magnetoresistive	magnetotransport property	magnetron sputter	mas ( ma ) spectrometry	mechanic property	membrane	mesoporou aluminosilicate	
mesoporou material	mesoporou silica	metal nanoparticle	metal-insulator	metal-oxide-semiconductor	metallic nanoparticle	metastable	micro-photoluminescence	
microcavity	microchip	microfluidic	micromagnetic	microphase	microporou material	microscope	microscopy	
microsphere	microstructur	microstructural	microstructure	mitochondrial dna	molecular	molecular aggregation	molecular architecture	
molecular beam epitaxy	molecular dynamic	molecular dynamic simulation	molecular recognition	molecular rectangle	molecular tilt	molecular weight	molecular wire	
molecular-beam	molecular-beam epitaxy	molecular-dynamics	molecular-dynamics simulation	molecular-sieves	molecularly	molecule	monolayer	
monomer	monte carlo	morphology	multiple-quantum	multiquantum	multiwall carbon nanotube	nano-adsorbent	nano-rings	
nanobelt	nanocatalyst	nanocavity	nanochannel	nanocluster	nanocomposite	nanocrystal	nanocrystalline	
nanocrystalline diamond	nanocrystalline diamond film	nanodevice	nanodot	nanofabrication	nanofiber	nanoindentation	nanomechanical	
nanoparticle	nanopore	nanorode	nanoscale	nanosize	nanosphere	nanotip	nanotip array	
nanotube	nanotube tip	nanowire	nanowire array	near-field	near-field optic	near-field optic disk	near-field optic probe	
near-field scan optic	near-field structure	near-infrared	neutron-scattering	nonequilibrium	nonlinear optic	nuclear	nuclear magnetic resonance	
nucleation	nuclei	nucleic-acids	one-dimensional	one-dimensional nanostructure	optic absorption	optic property	optoelectronic	
optoelectronic application	order-disorder	organic electroluminescent device	organoclay nanocomposite	oxide fuel-cells	particle size	phase separation	phase transformation	
phase transition	phonon	phosphor	photo-optical	photocatalyst	photodetector	photoelectron	photoelectron spectroscopy	
photoelectron-spectroscopy	photoemission	photoemission electron	photoexcitation	photoinduc electron-transfer	photolithography	photoluminescence	photon	
photonic bandgap material	photonic crystal	photophysic property	photoreflectance	photoresist	photosensitive	photovoltaic	photovoltaic cell	
physic evaporation	piezoelectric field	planar wave-guides	plasma	plasma cvd	plasma-assisted	plasma-enhanced	polariton	
polarity	polarizability	polarization	polarize light	polyimide film	polyimide nanocomposite	polymerization	pore size	
porou alumina	porou organosilicate	protein	protein adsorption	protein interaction	proton	pseudomorphic	pt particle	
pulsed-laser deposition	pump-probe	quantum confinement	quantum dot	quantum dot infrar photodetector	quantum efficiency	quantum ring	quantum yield	
quantum-confined	quantum-well	raman scatter	raman spectra	raman spectroscopy	rapid thermal anneal	ray photoelectron-spectroscopy	reactive sputter	
redox	resonant-tunneling diode	rhodium-catalyzed	ruo2 nanorod	sample surface	saturation magnetization	scan electron microscopy	scan optic microscopy	
scan probe	scan probe lithography	scan probe microscope	scan probe microscopy	scan tunnel microscope	scan tunnel microscopy	scanning-tunneling-microscopy	self-aligned	
self-assemblable	self-assembled	self-assembled monolayer	self-assembled quantum dot	self-assembly	self-catalyzed	self-consistent	self-organization	
self-organized	semiconductor	semiconductor nanocrystal	semiconductor nanowire	sidewall	silica nanoparticle	silicon nanowire	silicon nitride	
siloxane copolymer	silver nanoparticle	silver surface	single crystal	single layer	single-atom tip	single-crystal	single-crystal nanor	
single-crystal surface	single-crystalline	single-crystals	single-electron	single-electron transistor	single-layer	single-walled	single-walled carbon nanotube	
small-angle x-ray scatter	sol-gel	spectroscopic ellipsometry	spectroscopy	spheric aberration	spin accumulation	spin polarization	spin transistor	
spin-coating	spin-dependent tunnel	spin-orbit interaction	spin-valve transistor	spontaneou emission	stoke	strain relaxation	strain-induced	
subband	sublattice	sublayer	submicrometer	submicron	super-resolution near-field structure	supercapacitor	superconductor	
supercool liquid region	superlattice	superparamagnetic	support gold catalyst	support palladium catalyst	supramolecular	supramolecule	surface acoustic wave	
surface energy	surface modification	surface morphology	surface plasmon	surface plasmon resonance	surface property	surface roughne	surface structure	
surface tension	surface-emitting	surface-enhanced	temperature dependence	temperature-dependent	thermal	thermal anneal	thermal behavior	
thermal evaporation	thermal stability	thermal-stability	thermodynamically	thermodynamically stable	thin film	thin-film transistor	thin-films	
threshold voltage	time-resolved photoluminescence	tio2 nanotube	titanium oxide	titanium-dioxide	transconductance	transformation	transition temperature	
transmission electron	transmission electron microscopy	transport property	transport-properties	tridentate	tumor	tunnel current	tunnel diode	
tunnel junction	tunnel magnetoresistance	tunnel microscope	two-dimensional	ultrafine	ultrafine particle	ultrathin	ultrathin film	
unlike carbon nanotube	vacancy	vacuum	vapor deposition	vapor-deposition	vapor-liquid-solid	vapour	vertical-cavity surface-emitting	
vibration	viscosity	wavelength	whisker	work function	x ray	x-ray	x-ray photoelectron spectroscopy ( xps )	
x-ray-scattering	
