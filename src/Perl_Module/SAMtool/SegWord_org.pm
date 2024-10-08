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
#print "UseDic='", $this->{'UseDic'}, "', \$DIC{'美 國'}=$DIC{'美 國'}<br>\n";
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
		$w =~ /。|？|！/ # only valid for Big5 code
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
#print "<HR>SenList:<br>", (join "<p>\n", @SenList), "<br>\n";# if index($SenList[0], '五 金')>-1;
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
#print "\n<p>Before : $w : $f, wAt=$wAt\n" if $w eq "此 案" or $w eq '之 不 同' or $w eq "之\t不\t同" or $w eq "之 不\t同";
	next if $wAt>-1 and $Stopword::StopHead{substr($w,0,$wAt)};
#print "\n<p>After  : $w : $f, wAt=$wAt\n" if $w eq "此 案" or $w eq '之 不 同' or $w eq "之\t不\t同" or $w eq "之 不\t同";
	$wAt = rindex($w, "\t");
	next if $wAt>-1 and $Stopword::StopTail{substr($w,$wAt+1,2)};

	$len = length($w);
	if ($len >= 5) {
#print "$w:$Stopword::StopHead{substr($w,0,2)}<br>"if substr($w,0,2)eq'他';
	    next if $Stopword::StopHead{substr($w,0,2)} 
	     and defined($rFL->{substr($w, 3, $len-3)});
	    next if $Stopword::StopTail{substr($w,-2,2)}
	     and defined($rFL->{substr($w, 0, $len-3)});
	}

    	$w =~ tr/\t/ /; # convert tab into space
#print "\n<p>After2 : $w : $f, wAt=$wAt\n" if $w eq '之 不 同';
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
# The next 2 lines are added on Feb. 18, 2000 to allow terms like '0.18微米'
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
  $numbers  = '零○一二三四五六七八九十百千萬億０１２３４５６７８９．點第';
  $numbers .= '多半數幾倆卅兩壹貳三肆伍陸柒捌玖拾伯仟';
  for ($n = 0; $n < length($numbers); $n+=2) {
    $CNumbers{substr($numbers, $n, 2)} = 1;
  }

# Wide ASCII words
  $wascii =  'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ．';
  $wascii .= 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ－';
  $wascii .= '';
  for ($n = 0; $n < length($wascii); $n+=2) {
    $CASCII{substr($wascii, $n, 2)} = 1;
  }

# Foreign name transliteration characters
  $foreign =  '阿克拉加內亞斯貝巴爾姆愛蘭尤利西詹喬伊費傑羅納布可夫福赫勒柯特';
  $foreign .= '勞倫坦史芬尼根登都伯林伍泰胥黎俄科索沃金森奧霍瓦茨普蒂塞維大利';
  $foreign .= '格萊德岡薩雷墨哥弗庫澳馬哈多茲戈烏奇切諾戴裡諸塞吉基延科達塔博';
  $foreign .= '卡雅來莫波艾哈邁蓬安盧什比摩曼乃休合賴米那迪凱萊溫帕桑佩蒙博托';
  $foreign .= '謝格澤洛及希卜魯匹齊茲印古埃努烈累法賈圖喀土穆腓基冉休蓋耶沙';
  $foreign .= '遜賓麥華萬東湯';
  for ($n = 0; $n < length($foreign); $n+=2) {
    $CForeign{substr($foreign, $n, 2)} = 1;
  }

#Chinese surnames
  $surname  = '艾安敖白班包寶保鮑貝畢邊卞柏卜蔡曹岑柴昌常陳成程遲池褚楚';
  $surname .= '儲淳崔戴刀鄧狄刁丁董竇杜端段樊范方房斐費豐封馮鳳伏福傅蓋甘';
  $surname .= '高戈耿龔宮勾苟辜谷古顧官關管桂郭韓杭郝禾何賀赫衡洪侯胡花';
  $surname .= '華黃霍稽姬吉紀季賈簡翦姜江蔣焦晉金靳荊居康柯空孔匡鄺況賴藍';
  $surname .= '郎朗勞樂雷冷黎李理厲利勵連廉練良梁廖林凌劉柳隆龍樓婁盧呂魯';
#  $surname .= '陸路倫羅洛駱麻馬麥滿茅毛梅孟米苗繆閔明莫牟穆倪聶牛鈕農潘龐';
  $surname .= '陸    羅  駱  馬麥  茅毛梅孟  苗      莫牟穆倪聶牛    潘龐';
  $surname .= '裴彭皮樸平蒲溥浦戚祁齊錢強喬秦丘邱仇裘屈瞿權冉饒任榮容阮';
  $surname .= '瑞芮薩賽沙單商邵佘申沈盛石史壽舒斯宋蘇孫邰譚談湯唐陶滕';
  $surname .= '田佟仝屠塗萬汪王危韋魏衛蔚溫聞翁巫鄔伍武吳奚習夏鮮冼';
#  $surname .= '項蕭解謝辛邢幸熊徐許宣薛荀顏閻言嚴彥晏燕楊陽姚葉蟻易殷銀尹';
  $surname .= '項蕭  謝辛邢  熊徐許  薛荀顏閻  嚴  晏燕楊陽姚葉  易殷  尹';
# $surname .= '應英游尤於魚虞俞余禹喻郁尉元袁岳雲臧曾查翟詹湛張章招趙甄';
  $surname .= '  英游尤  魚虞俞余    郁尉元袁岳雲臧曾查翟詹湛張章  趙甄';
  $surname .= '鄭鐘鍾周諸朱竺祝莊卓宗鄒祖左';
  for ($n = 0; $n < length($surname); $n+=2) {
    $CSurname{substr($surname, $n, 2)} = 1;
  }

# Add in 2 character surnames; also add to lexicon
# so they'll be segmented as one unit
  $CSurname2{'東 郭'} = 1; # $DIC{'東 郭'} = 1;
  $CSurname2{'公 孫'} = 1; # $DIC{'公 孫'} = 1;
  $CSurname2{'皇 甫'} = 1; # $DIC{'皇 甫'} = 1;
  $CSurname2{'慕 容'} = 1; # $DIC{'慕 容'} = 1;
  $CSurname2{'歐 陽'} = 1; # $DIC{'歐 陽'} = 1;
  $CSurname2{'單 于'} = 1; # $DIC{'單 于'} = 1;
  $CSurname2{'司 空'} = 1; # $DIC{'司 空'} = 1;
  $CSurname2{'司 馬'} = 1; # $DIC{'司 馬'} = 1;
  $CSurname2{'司 徒'} = 1; # $DIC{'司 徒'} = 1;
  $CSurname2{'澹 台'} = 1; # $DIC{'澹 台'} = 1;
  $CSurname2{'諸 葛'} = 1; # $DIC{'諸 葛'} = 1;

  $UnCommonSurname = '車和全時水同文席於';
  for ($n = 0; $n < length($UnCommonSurname); $n+=2) {
    $UnCommonSurname{substr($UnCommonSurname, $n, 2)} = 1;
  }

#Not in name
  $NotName  = '的說對在和是被最所那這有將會與於他為也';
  $NotName .= '、：，。★【】（）☉∼【】—﹒？！「」　';
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
#print "w=$w, 1st c $rW->[0]=$WLen{$rW->[0]}, wlen=$wlen \n" if $w eq'口 頭';
    }
    close(WRDS);
    while (($w, $wlen) = each %WLenTMP) {
	%W = ();
	foreach $rW (split ' ', $wlen) {  $W{$rW} = 1;  }
	$WLen{$w} = join ' ', sort { $b <=> $a } keys %W;
    }
#print '口：', $WLen{'口'}, '=>', $DIC{'口 頭'}, "\n";
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
３ : 4
Ａ : 4 3
Ｂ : 4 3 2
Ｃ : 3
Ｄ : 5 4 3 2
Ｅ : 2
Ｇ : 3 2
Ｈ : 4
Ｉ : 3 2
Ｌ : 3
Ｎ : 4 3
Ｐ : 3
Ｓ : 4 3 2
Ｔ : 3 2
Ｕ : 3
Ｗ : 3
Ｘ : 2
Ｙ : 3
一 : 8 7 6 5 4 3 2
乙 : 4 3 2
丁 : 6 5 4 3 2
七 : 5 4 3 2
乃 : 4 2
九 : 6 5 4 3 2
了 : 4 3 2
二 : 8 7 6 5 4 3 2
人 : 8 7 6 5 4 3 2
入 : 6 4 3 2
八 : 6 5 4 3 2
刀 : 4 2
刁 : 4 2
力 : 4 3 2
匕 : 4 2
十 : 8 7 5 4 3 2
卜 : 4 3 2
又 : 4 3 2
三 : 8 7 6 5 4 3 2
下 : 6 5 4 3 2
丈 : 4 3 2
上 : 8 7 6 5 4 3 2
丫 : 2
丸 : 3 2
凡 : 4 3 2
久 : 5 4 2
么 : 4 2
也 : 4 3 2
乞 : 4 3 2
于 : 4 3 2
亡 : 5 4 3 2
兀 : 2
刃 : 2
勺 : 2
千 : 8 7 6 5 4 3 2
叉 : 2
口 : 6 4 3 2
土 : 5 4 3 2
士 : 6 4 3 2
夕 : 4 2
大 : 8 7 6 5 4 3 2
女 : 7 5 4 3 2
子 : 7 5 4 3 2
孑 : 4 2
寸 : 7 4 2
小 : 8 7 5 4 3 2
尸 : 4
山 : 8 7 4 3 2
川 : 5 4 2
工 : 7 5 4 3 2
己 : 8 4 2
已 : 4 3 2
巳 : 2
巾 : 8 6 4 2
干 : 4 3 2
弋 : 4 2
弓 : 3 2
才 : 4 3 2
丑 : 4 2
不 : 8 7 6 5 4 3 2
中 : 8 7 6 5 4 3 2
丰 : 4 2
丹 : 4 3 2
之 : 4 3 2
尹 : 2
予 : 4 2
云 : 4 2
井 : 6 4 3 2
互 : 6 4 3 2
五 : 7 6 5 4 3 2
亢 : 4 3 2
仁 : 4 3 2
什 : 4 3 2
仇 : 2
仍 : 3 2
今 : 4 3 2
介 : 4 3 2
仄 : 2
元 : 4 3 2
允 : 4 2
內 : 6 4 3 2
六 : 7 5 4 3 2
兮 : 2
公 : 9 8 7 5 4 3 2
冗 : 4 2
分 : 5 4 3 2
切 : 4 3 2
勻 : 6 2
勾 : 4 2
勿 : 6 4 3 2
化 : 6 5 4 3 2
匹 : 8 4 3 2
午 : 2
升 : 4 3 2
厄 : 4 2
友 : 5 4 3 2
及 : 4 3 2
反 : 6 5 4 3 2
壬 : 2
天 : 7 6 5 4 3 2
夫 : 4 3 2
太 : 8 6 5 4 3 2
夭 : 4 2
孔 : 4 3 2
少 : 6 5 4 3 2
尤 : 4 3 2
尺 : 4 2
屯 : 4 2
巴 : 7 5 4 3 2
幻 : 4 3 2
弔 : 4 2
引 : 4 3 2
心 : 7 4 3 2
戈 : 5 3 2
戶 : 4 3 2
手 : 6 5 4 3 2
扎 : 4 3 2
支 : 4 3 2
文 : 7 6 5 4 3 2
斗 : 4 3 2
斤 : 4 2
方 : 4 3 2
日 : 8 6 5 4 3 2
月 : 8 4 3 2
木 : 4 3 2
欠 : 4 3 2
止 : 6 4 3 2
歹 : 2
毋 : 4 2
比 : 8 7 5 4 3 2
毛 : 5 4 3 2
氏 : 2
水 : 8 5 4 3 2
火 : 5 4 3 2
爪 : 4 3 2
父 : 8 6 4 3 2
片 : 4 3 2
牙 : 4 3 2
牛 : 6 4 3 2 1
犬 : 4 3 2
王 : 8 4 3 2
丙 : 3 2
世 : 6 5 4 3 2
且 : 2
丘 : 3 2
主 : 6 5 4 3 2
乍 : 4 3 2
乏 : 2
乎 : 2
以 : 8 7 6 5 4 3 2
付 : 4 3 2
仔 : 4 2
仕 : 2
他 : 5 4 3 2
仗 : 4 2
代 : 4 3 2
令 : 6 4 2
仙 : 5 4 3 2
充 : 4 3 2
兄 : 4 3 2
冉 : 4 2
冊 : 2
冬 : 5 4 3 2
凹 : 4 3 2
出 : 8 6 5 4 3 2
凸 : 4 3 2
刊 : 3 2
加 : 5 4 3 2
功 : 5 4 3 2
包 : 4 3 2
匆 : 4 2
北 : 8 6 5 4 3 2
匝 : 4 2
半 : 7 5 4 3 2
卡 : 5 4 3 2
占 : 5 4 3 2
卯 : 2
去 : 4 3 2
可 : 6 5 4 3 2
古 : 5 4 3 2
右 : 4 3 2
召 : 4 3 2
叮 : 4 3 2
叩 : 3 2
叨 : 2
叼 : 2
司 : 5 4 3 2
叵 : 2
叫 : 4 3 2
另 : 4 3 2
只 : 8 7 6 5 4 3 2
史 : 4 3 2
叱 : 4 2
台 : 8 7 6 5 4 3 2
句 : 2
叭 : 2
四 : 8 7 6 5 4 3 2
囚 : 4 2
外 : 6 5 4 3 2
央 : 2
失 : 8 7 4 3 2
奴 : 4 3 2
奶 : 3 2
孕 : 3 2
它 : 4 3 2
尼 : 6 4 3 2
巨 : 4 3 2
巧 : 8 6 4 3 2
左 : 6 4 3 2
市 : 6 4 3 2
布 : 5 4 3 2
平 : 6 5 4 3 2
幼 : 5 4 3 2
弘 : 4 2
弗 : 4 2
必 : 5 4 3 2
戊 : 4 2
打 : 7 6 5 4 3 2
扔 : 2
扒 : 2
斥 : 3 2
旦 : 4 2
本 : 4 3 2
未 : 6 5 4 3 2
末 : 5 4 3 2
札 : 4 2
正 : 5 4 3 2
母 : 4 3 2
民 : 6 5 4 3 2
永 : 4 3 2
汁 : 2
汀 : 2
氾 : 4 2
犯 : 7 4 3 2
玄 : 4 3 2
玉 : 5 4 3 2
瓜 : 5 4 3 2
瓦 : 7 4 3 2
甘 : 6 4 3 2
生 : 8 6 5 4 3 2
用 : 6 4 3 2
甩 : 2
田 : 4 3 2
由 : 6 4 3 2
甲 : 8 6 5 4 3 2
申 : 4 3 2
白 : 5 4 3 2
皮 : 8 7 5 4 3 2
目 : 5 4 3 2
矛 : 4 3 2
矢 : 4 2
石 : 7 5 4 3 2
示 : 4 3 2
禾 : 3 2
穴 : 4 3 2
立 : 6 4 3 2
丞 : 2
丟 : 4 3 2
乒 : 3 2
乓 : 2
亙 : 4 2
交 : 4 3 2
亦 : 4 2
亥 : 4 2
仿 : 3 2
伉 : 2
伙 : 2
伊 : 4 3 2
伍 : 4 2
伐 : 4 3 2
休 : 7 4 3 2
伏 : 4 3 2
仲 : 5 4 3 2
件 : 2
任 : 5 4 3 2
仰 : 4 3 2
份 : 4 2
企 : 6 5 4 3 2
光 : 5 4 3 2
兇 : 4 3 2
兆 : 4 3 2
先 : 6 5 4 3 2
全 : 10 8 7 6 5 4 3 2
共 : 5 4 3 2
再 : 4 3 2
冰 : 5 4 3 2
列 : 5 4 3 2
刑 : 6 5 4 3 2
划 : 3 2
刎 : 4 2
劣 : 4 3 2
匈 : 4 3 2
匡 : 4 2
匠 : 4 2
印 : 5 4 3 2
危 : 4 3 2
吉 : 6 4 3 2
吏 : 2
同 : 5 4 3 2
吊 : 4 3 2
吐 : 4 3 2
吁 : 2
各 : 7 6 5 4 3 2
向 : 5 4 3 2
名 : 6 5 4 3 2
合 : 5 4 3 2
吃 : 6 5 4 3 2
后 : 3 2
吆 : 4 2
因 : 6 5 4 3 2
回 : 4 3 2
地 : 7 6 5 4 3 2
在 : 8 7 6 5 4 3 2
圭 : 3
圩 : 2
夙 : 4 2
多 : 8 7 6 5 4 3 2
夷 : 4 2
夸 : 2
妄 : 4 3 2
奸 : 4 2
妃 : 2
好 : 4 3 2
她 : 3 2
如 : 8 6 4 3 2
字 : 4 3 2
存 : 6 4 3 2
宇 : 4 3 2
守 : 4 3 2
宅 : 4 3 2
安 : 8 7 6 4 3 2
寺 : 3 2
尖 : 5 4 3 2
屹 : 2
州 : 4 3 2
帆 : 2
并 : 4
年 : 6 5 4 3 2
式 : 2
弛 : 3 2
忙 : 6 4 3 2
忖 : 2
戎 : 4 2
戌 : 2
戍 : 2
成 : 8 6 5 4 3 2
扣 : 4 3 2
扛 : 4 2
托 : 4 3 2
收 : 4 3 2
早 : 8 6 5 4 3 2
旨 : 4 2
旬 : 2
旭 : 4 2
曲 : 4 3 2
曳 : 4 3 2
有 : 8 7 6 5 4 3 2
朽 : 4 2
朴 : 3
朱 : 5 4 3 2
朵 : 4 2
次 : 4 3 2
此 : 8 7 6 4 3 2
死 : 8 7 6 5 4 3 2
氖 : 2
汝 : 4 2
汗 : 4 3 2
江 : 8 6 4 3 2
池 : 4 3 2
汐 : 3 2
汕 : 2
污 : 4 3 2
汛 : 2
灰 : 4 3 2
牟 : 4 2
牝 : 4 2
百 : 8 7 6 5 4 3 2
竹 : 4 3 2
米 : 5 4 3 2
羊 : 7 4 3 2 1
羽 : 5 4 3 2
老 : 7 6 5 4 3 2
考 : 4 3 2
而 : 4 3 2
耒 : 4
耳 : 6 4 3 2
肉 : 6 4 3 2
肋 : 4 3 2
肌 : 4 2
臣 : 2
自 : 6 5 4 3 2
至 : 4 3 2
臼 : 2
舌 : 4 3 2
舟 : 4 2
色 : 4 3 2
艾 : 6 5 4 3 2
血 : 4 3 2
行 : 8 6 5 4 3 2
衣 : 4 3 2
西 : 5 4 3 2
阡 : 2
串 : 4 3 2
亨 : 6 2
位 : 4 3 2
住 : 4 3 2
佇 : 2
伴 : 4 3 2
佛 : 4 3 2
何 : 5 4 3 2
估 : 4 3 2
佐 : 4 3 2
佑 : 2
伽 : 3 2
伺 : 4 3 2
伸 : 4 3 2
佃 : 2
佔 : 6 5 4 3 2
似 : 4 3 2
但 : 4 2
佣 : 2
作 : 4 3 2
你 : 4 3 2
伯 : 4 3 2
低 : 6 4 3 2
伶 : 4 2
余 : 4 3 2
佝 : 3 2
佈 : 3 2
佚 : 2
兌 : 3 2
克 : 6 5 4 3 2
免 : 4 3 2
兵 : 8 5 4 3 2
冶 : 5 4 3 2
冷 : 4 3 2
別 : 7 4 3 2
判 : 4 3 2
利 : 4 3 2
刪 : 4 3 2
刨 : 5 2
劫 : 4 3 2
助 : 5 4 3 2
努 : 4 3 2
匣 : 4 2
即 : 6 4 3 2
卵 : 4 3 2
吝 : 3 2
吭 : 2
吞 : 4 3 2
吾 : 4 2
否 : 5 4 3 2
吧 : 2
呆 : 4 3 2
呃 : 2
吳 : 4 3 2
呈 : 5 2
呂 : 4 3 2
君 : 8 7 4 3 2
吩 : 2
告 : 4 3 2
吹 : 6 5 4 3 2
吻 : 2
吸 : 4 3 2
吮 : 4 2
吵 : 4 3 2
吶 : 2
吠 : 4 2
吼 : 2
呀 : 2
吱 : 3 2
含 : 4 3 2
吟 : 4 3 2
困 : 4 3 2
囤 : 4 3 2
囫 : 4 2
坑 : 4 2
坍 : 4 2
均 : 4 3 2
坎 : 4 3 2
坐 : 5 4 3 2
壯 : 4 3 2
夾 : 5 4 3 2
妒 : 4 2
妨 : 5 4 3 2
妞 : 2
妙 : 4 3 2
妖 : 4 2
妍 : 4
妓 : 2
妊 : 3 2
妥 : 4 3 2
孝 : 4 2
孜 : 4 2
完 : 4 3 2
宋 : 4 3 2
宏 : 5 4 3 2
局 : 4 3 2
屁 : 4 2
尿 : 4 3 2
尾 : 4 3 2
岐 : 2
岔 : 3 2
岌 : 4 2
巫 : 4 3 2
希 : 4 3 2
序 : 2
庇 : 3 2
床 : 4 3 2 1
廷 : 4 2
弄 : 4 3 2
弟 : 3 2
彤 : 2
形 : 4 3 2
彷 : 2
役 : 3 2
忘 : 4 3 2
忌 : 2
志 : 4 3 2
忍 : 4 3 2
快 : 5 4 3 2
忸 : 4 2
戒 : 4 3 2
我 : 4 3 2
抄 : 4 3 2
抗 : 5 4 3 2
抖 : 2
技 : 5 4 3 2
扶 : 4 3 2
抉 : 4 2
扭 : 4 3 2
把 : 4 3 2
扼 : 4 3 2
找 : 4 3 2
批 : 7 4 3 2
扳 : 3 2
抒 : 3 2
扯 : 4 3 2
折 : 4 3 2
扮 : 3 2
投 : 4 3 2
抓 : 4 3 2
抑 : 4 3 2
改 : 4 3 2
攻 : 4 3 2
攸 : 2
旱 : 4 3 2
更 : 5 4 3 2
束 : 4 3 2
李 : 9 5 4 3 2
杏 : 4 2
材 : 4 3 2
村 : 4 3 2
杜 : 4 3 2
杖 : 2
杞 : 4 3 2
杉 : 3 2
步 : 5 4 3 2
每 : 5 4 3 2
求 : 8 6 4 3 2
汞 : 3 2
沙 : 6 5 4 3 2
沁 : 4 2
沈 : 4 3 2
沉 : 4 3 2
沅 : 2
沛 : 4 2
汪 : 4 3 2
決 : 4 3 2
沐 : 4 3 2
汰 : 4
汨 : 2
沖 : 4 3 2
沒 : 4 3 2
汽 : 8 6 4 3 2
沃 : 4 2
汲 : 4 3 2
汾 : 2
沆 : 4 2
汶 : 2
沂 : 4 2
灶 : 4 2
灼 : 4 2
災 : 4 3 2
牢 : 4 2
牡 : 3 2
狄 : 6 3 2
狂 : 4 3 2
甬 : 2
男 : 6 4 3 2
甸 : 2
皂 : 4 3 2
盯 : 3 2
私 : 5 4 3 2
秀 : 4 3 2
禿 : 3 2
究 : 4 2
系 : 5 4 3 2
罕 : 4 2
肖 : 3 2
肝 : 4 3 2
肘 : 4 3 2
肛 : 2
肚 : 3 2
育 : 3 2
良 : 4 3 2
芒 : 4 2
芋 : 2
芍 : 2
見 : 8 5 4 3 2
角 : 4 3 2
言 : 8 6 4 3 2
谷 : 4 3 2
豆 : 4 3 2
豕 : 4
貝 : 4 3 2
赤 : 5 4 3 2
走 : 8 4 3 2
足 : 4 3 2
身 : 8 7 5 4 3 2
車 : 5 4 3 2
辛 : 4 3 2
辰 : 2
迂 : 4 2
迅 : 6 4 2
迄 : 4 3 2
巡 : 4 3 2
邑 : 4
邢 : 2
邪 : 4 2
邦 : 5 2
那 : 4 3 2
酉 : 2
里 : 4 3 2
防 : 8 6 5 4 3 2
阮 : 4 3
阪 : 4
並 : 7 4 3 2
乖 : 3 2
乳 : 4 3 2
事 : 8 6 5 4 3 2
些 : 2
亞 : 7 6 5 4 3 2
享 : 4 2
京 : 4 3 2
佯 : 4 3 2
依 : 5 4 3 2
侍 : 3 2
佳 : 4 3 2
使 : 6 4 3 2
佬 : 2
供 : 5 4 3 2
例 : 5 4 2
來 : 4 3 2
侃 : 4 2
併 : 3 2
侈 : 2
佩 : 4 2
侏 : 4 3 2
兔 : 4 3 2
兒 : 6 5 4 3 2
兩 : 5 4 3 2
具 : 4 3 2
其 : 4 3 2
典 : 4 3 2
函 : 4 3 2
刻 : 4 3 2
券 : 4 2
刷 : 4 3 2
刺 : 4 3 2
到 : 5 4 3 2
刮 : 4 3 2
制 : 4 3 2
剁 : 2
卒 : 2
協 : 5 4 3 2
卓 : 4 3 2
卑 : 6 4 3 2
卦 : 2
卷 : 4 3 2
卸 : 4 3 2
取 : 8 4 3 2
叔 : 2
受 : 4 3 2
味 : 4 3 2
呵 : 4 3 2
咖 : 3 2
呸 : 2
咕 : 2
咀 : 2
呻 : 3 2
呷 : 2
咄 : 4 2
咒 : 2
咆 : 4 3 2
呼 : 8 5 4 3 2
呱 : 3 2
呶 : 4 2
和 : 6 4 3 2
咚 : 2
呢 : 4 3 2
周 : 4 3 2
咋 : 3 2
命 : 4 3 2
咎 : 4 2
固 : 6 4 3 2
垃 : 5 4 3 2
坷 : 2
坪 : 3 2
坩 : 2
坡 : 2
坦 : 4 2
夜 : 4 3 2
奉 : 4 3 2
奇 : 4 3 2
奈 : 6 4 3 2
奄 : 4 2
奔 : 4 2
妾 : 2
妻 : 4 2
委 : 4 3 2
妹 : 2
姑 : 4 3 2
姆 : 2
姐 : 3 2
姍 : 4 2
始 : 4 3 2
姓 : 3 2
姊 : 2
妯 : 2
孟 : 4 3 2
孤 : 5 4 3 2
季 : 4 3 2
宗 : 4 3 2
定 : 5 4 3 2
官 : 6 4 3 2
宜 : 5 4 2
宙 : 2
宛 : 4 2
尚 : 7 4 3 2
屈 : 4 3 2
居 : 7 6 5 4 3 2
屆 : 2
岷 : 2
岡 : 3 2
岸 : 4 2
岳 : 3 2
帖 : 2
帕 : 3
帛 : 2
幸 : 4 3 2
庚 : 4 2
店 : 4 3 2
府 : 2
底 : 6 3 2
庖 : 4 2
延 : 4 3 2
弦 : 4 3 2
弧 : 3 2
弩 : 2
往 : 4 3 2
征 : 4 3 2
彼 : 6 4 3 2
忠 : 6 4 3 2
忽 : 4 3 2
念 : 4 2
忿 : 4 2
怏 : 4 2
怔 : 2
怯 : 4 3 2
怵 : 4
怪 : 5 4 3 2
怕 : 4 3 2
怡 : 4 2
性 : 8 5 4 3 2
怛 : 4
或 : 4 3 2
戕 : 4 2
房 : 4 3 2
所 : 5 4 3 2
承 : 7 5 4 3 2
拉 : 6 5 4 3 2
拌 : 2
拄 : 2
抿 : 2
拂 : 4 2
抹 : 4 3 2
拒 : 6 4 3 2
招 : 4 3 2
披 : 4 2
拓 : 4 3 2
拔 : 4 3 2
拋 : 4 3 2
拈 : 4 2
抨 : 2
抽 : 4 3 2
押 : 2
拐 : 4 3 2
拙 : 4 2
拇 : 3 2
拍 : 4 3 2
抵 : 4 3 2
拚 : 4 3 2
抱 : 4 3 2
拘 : 4 3 2
拖 : 4 3 2
拗 : 4 3 2
拆 : 4 3 2
抬 : 5 4 3 2
放 : 8 7 6 5 4 3 2
斧 : 2
於 : 4 3 2
旺 : 4 2
昔 : 4 2
易 : 4 3 2
昌 : 4 2
昆 : 4 3 2
昂 : 4 2
明 : 8 7 6 5 4 3 2
昏 : 4 3 2
昊 : 4
昇 : 2
服 : 5 4 3 2
朋 : 5 4 3 2
杭 : 3 2
枋 : 2
枕 : 4 3 2
東 : 7 6 5 4 3 2
果 : 6 4 3 2
杳 : 4 2
枇 : 4 2
枝 : 4 2
林 : 4 3 2
杯 : 4 3 2
板 : 4 3 2
枉 : 4 2
松 : 5 4 3 2
析 : 4 2
枚 : 2
杼 : 4
欣 : 4 3 2
武 : 5 4 3 2
歧 : 4 2
歿 : 4
氛 : 2
泣 : 4 2
注 : 4 3 2
泳 : 2
泌 : 2
泥 : 5 4 3 2
河 : 5 4 3 2
沽 : 4 2
沾 : 4 2
沼 : 5 3 2
波 : 5 4 3 2
沫 : 2
法 : 8 5 4 3 2
沸 : 4 3 2
油 : 4 3 2
況 : 2
沮 : 2
泗 : 2
泅 : 2
泱 : 4 2
沿 : 6 4 2
治 : 4 3 2
泡 : 4 3 2
泛 : 4 3 2
泊 : 2
泯 : 2
炕 : 2
炎 : 4 2
炒 : 4 3 2
炊 : 4 3 2
炙 : 4 2
爬 : 4 3 2
爭 : 8 4 3 2
爸 : 2
版 : 5 4 2
牧 : 4 3 2
物 : 5 4 3 2
狀 : 2
狎 : 2
狙 : 3 2
狗 : 8 5 4 3 2 1
狐 : 4 3 2
玩 : 4 3 2
玫 : 3 2
疝 : 3 2
疙 : 4 2
疚 : 4
的 : 3 2
盂 : 4
盲 : 5 4 3 2
直 : 5 4 3 2
知 : 8 7 6 5 4 3 2
矽 : 4 3 2
社 : 5 4 3 2
祀 : 3 2
祁 : 4 2
秉 : 4 2
空 : 6 5 4 3 2
穹 : 2
糾 : 4 3 2
罔 : 4
羌 : 4 2
者 : 4
肺 : 4 3 2
肥 : 4 3 2
肢 : 9 2
肱 : 2
股 : 6 5 4 3 2
肩 : 5 4 3 2
肯 : 4 3 2
臥 : 4 3 2
舍 : 2
芳 : 4 3 2
芝 : 5 4 3 2
芙 : 4 2
芭 : 3 2
芽 : 2
芟 : 4
芹 : 2
花 : 5 4 3 2
芬 : 4 3 2
芥 : 3 2
芯 : 3 2
芸 : 4 2
虎 : 5 4 3 2
虱 : 2
初 : 7 4 3 2
表 : 5 4 3 2
軋 : 3 2
迎 : 4 3 2
返 : 4 3 2
近 : 8 7 4 3 2
邸 : 2
邱 : 3
采 : 4 3 2
金 : 8 6 4 3 2
長 : 5 4 3 2
門 : 5 4 3 2
阜 : 2
陀 : 2
阿 : 8 7 6 5 4 3 2
阻 : 3 2
附 : 4 3 2
雨 : 4 3 2
青 : 7 5 4 3 2
非 : 8 5 4 3 2
亟 : 2
亭 : 4 2
亮 : 3 2
信 : 6 5 4 3 2
侵 : 4 3 2
侯 : 3 2
便 : 5 4 3 2
俠 : 2
俏 : 3 2
保 : 4 3 2
促 : 8 4 3 2
俘 : 4 2
俟 : 4
俊 : 2
俗 : 4 3 2
侮 : 3 2
俐 : 4
俄 : 4 3 2
俚 : 2
侷 : 4 2
冒 : 7 4 3 2
冠 : 4 3 2
剎 : 3 2
剃 : 3 2
削 : 4 3 2
前 : 8 6 5 4 3 2
剌 : 2
剋 : 2
則 : 2
勇 : 4 3 2
勉 : 4 3 2
勃 : 4 2
勁 : 4 2
匍 : 4 2
南 : 6 4 3 2
卻 : 4 2
厚 : 4 3 2
叛 : 3 2
咬 : 4 3 2
哀 : 6 4 2
咨 : 5 4 2
哎 : 2
咸 : 2
咳 : 4 3 2
哇 : 3 2
咽 : 3 2
咪 : 2
品 : 4 3 2
哄 : 4 2
哈 : 4 3 2
咯 : 3 2
咫 : 4 2
咱 : 2
咻 : 2
咩 : 2
咧 : 2
咿 : 2
囿 : 4 2
垂 : 5 4 3 2
型 : 2
垢 : 2
城 : 8 4 3 2
垮 : 2
奕 : 2
契 : 4 3 2
奏 : 3 2
奎 : 2
姜 : 5 2
姘 : 2
姿 : 2
姣 : 4 2
姨 : 3 2
娃 : 3 2
姥 : 2
姚 : 4 3
姦 : 2
威 : 5 4 3 2
姻 : 2
孩 : 3 2
宣 : 4 3 2
宦 : 2
室 : 4 3 2
客 : 6 4 3 2
封 : 4 3 2
屎 : 2
屏 : 4 2
屍 : 4 2
屋 : 4 3 2
峙 : 2
巷 : 4 2
帝 : 5 4 3 2
帥 : 3 2
幽 : 4 3 2
度 : 4 3 2
建 : 4 3 2
弭 : 2
彥 : 4
很 : 4 3 2
待 : 4 3 2
律 : 5 4 2
徇 : 4 2
後 : 5 4 3 2
怒 : 4 3 2
思 : 4 3 2
怠 : 2
急 : 5 4 3 2
怎 : 5 4 3 2
怨 : 4 3 2
恍 : 4 2
恰 : 5 4 2
恨 : 5 4 3 2
恢 : 4 3 2
恆 : 4 3 2
恃 : 4 2
恬 : 4 2
恫 : 4 2
恪 : 4 2
恤 : 4 2
扁 : 4 3 2
拜 : 4 3 2
挖 : 4 3 2
按 : 7 5 4 3 2
拼 : 4 3 2
拭 : 4 2
持 : 7 6 5 4 3 2
拮 : 2
拽 : 4 2
指 : 6 5 4 3 2
拱 : 4 3 2
拷 : 3 2
拯 : 4 2
括 : 4 3 2
拾 : 4 3 2
拴 : 2
挑 : 4 3 2
政 : 6 5 4 3 2
故 : 5 4 3 2
斫 : 4
施 : 4 3 2
既 : 8 6 4 3 2
春 : 7 4 3 2
昭 : 4 2
映 : 4 3 2
昧 : 4 2
是 : 4 3 2
星 : 8 4 3 2
昨 : 4 3 2
昱 : 4
柿 : 2
染 : 4 3 2
柱 : 3 2
柔 : 4 3 2
某 : 4 3 2
柬 : 3 2
架 : 4 3 2
枯 : 4 3 2
柵 : 2
柩 : 2
柯 : 3 2
柄 : 2
柑 : 3 2
柚 : 2
查 : 4 3 2
枸 : 3 2
柏 : 5 4 3 2
柞 : 3 2
柳 : 7 4 3 2
歪 : 4 2
殃 : 4 2
殆 : 4 2
段 : 2
毒 : 8 5 4 3 2
毗 : 2
氟 : 5 3 2
泉 : 4 2
洋 : 4 3 2
洲 : 4 2
洪 : 4 3 2
流 : 5 4 3 2
津 : 4 2
洞 : 5 4 3 2
洗 : 4 3 2
活 : 6 4 3 2
洽 : 4 3 2
派 : 4 3 2
洶 : 4 2
洛 : 4 3 2
泵 : 2
洩 : 4 3 2
炫 : 4 2
為 : 8 6 5 4 3 2
炳 : 4
炬 : 2
炯 : 4 2
炭 : 3 2
炸 : 3 2
炮 : 4 3 2
牲 : 2
牯 : 2
狩 : 2
狠 : 4 3 2
狡 : 6 4 2
玷 : 2
珊 : 5 4 3 2
玻 : 5 4 3 2
玲 : 4 2
珍 : 6 4 3 2
珀 : 2
玳 : 2
甚 : 4 3 2
甭 : 2
畏 : 4 2
界 : 3 2
畎 : 4
疫 : 4 2
疤 : 2
疥 : 4 2
疣 : 2
癸 : 2
皆 : 4 2
皇 : 8 4 3 2
皈 : 3 2
盈 : 4 2
盆 : 4 2
省 : 4 3 2
盹 : 2
相 : 4 3 2
眉 : 8 4 2
看 : 8 4 3 2
盾 : 2
盼 : 2
矜 : 4 2
砂 : 3 2
研 : 4 3 2
砌 : 2
砍 : 4 3 2
祉 : 3
祈 : 4 3 2
禹 : 4
科 : 6 4 3 2
秒 : 2
秋 : 5 4 3 2
穿 : 4 3 2
突 : 4 3 2
竿 : 4 2
籽 : 2
紅 : 5 4 3 2
紀 : 4 3 2
紇 : 4
約 : 4 3 2
紆 : 4 2
缸 : 2
美 : 7 6 5 4 3 2
耄 : 2
耐 : 5 4 3 2
耍 : 4 3 2
耶 : 3 2
胖 : 3 2
胚 : 4 3 2
胃 : 3 2
背 : 4 3 2
胡 : 4 3 2
胎 : 3 2
胞 : 2
致 : 4 3 2
舢 : 2
苧 : 2
范 : 5 4 3
茅 : 5 4 3 2
苛 : 5 4 3 2
苦 : 4 3 2
茄 : 3 2
若 : 4 3 2
茂 : 4 3 2
茉 : 4 3 2
苗 : 4 3 2
英 : 7 6 4 3 2
茁 : 4 3 2
苜 : 2
苔 : 2
苑 : 2
苞 : 4 2
苓 : 3
苟 : 4 2
苯 : 6 3 2 1
虐 : 4 3 2
虹 : 4 3 2
衍 : 3 2
要 : 4 3 2
觔 : 2
計 : 6 5 4 3 2
訂 : 4 3 2
訃 : 2
貞 : 4 2
負 : 4 3 2
赴 : 4 2
赳 : 4 2
趴 : 2
軍 : 5 4 3 2
軌 : 3 2
述 : 2
迢 : 4 2
迪 : 3 2
迥 : 4 2
迭 : 4 2
迫 : 4 3 2
迤 : 4 2
郊 : 4 2
郎 : 4 2
郁 : 2
酋 : 3 2
重 : 8 6 5 4 3 2
閂 : 2
限 : 4 3 2
陋 : 4 2
陌 : 4 3 2
降 : 4 3 2
面 : 5 4 3 2
革 : 4 3 2
韋 : 4 2
韭 : 2
音 : 4 3 2
頁 : 3 2
風 : 8 6 4 3 2
飛 : 4 3 2
食 : 8 4 3 2
首 : 4 3 2
香 : 8 4 3 2
乘 : 4 3 2
亳 : 2
倍 : 4 3 2
倣 : 2
俯 : 4 3 2
倦 : 2
倥 : 2
俸 : 2
倩 : 2
倖 : 4 3 2
倆 : 2
值 : 4 3 2
借 : 6 4 3 2
倚 : 4 2
倒 : 4 3 2
俺 : 2
倔 : 4 2
倨 : 2
俱 : 4 3 2
倡 : 4 3 2
個 : 5 4 3 2
候 : 4 3 2
倘 : 4 2
修 : 4 3 2
倭 : 2
俾 : 4
倫 : 4 3 2
倉 : 4 2
兼 : 4 3 2
冤 : 8 6 4 2
冥 : 4 3 2
凍 : 4 2
凌 : 4 2
准 : 3 2
凋 : 2
剖 : 4 3 2
剜 : 4
剔 : 4 2
剛 : 5 4 3 2
剝 : 8 4 3 2
匪 : 4 2
卿 : 4 3 2
原 : 6 5 4 3 2
厝 : 4
哨 : 2
唐 : 4 3 2
唁 : 2
哼 : 3 2
哥 : 5 4 3 2
哲 : 4 3 2
唆 : 2
哺 : 4 3 2
哭 : 4 3 2
員 : 3 2
唉 : 4 2
哮 : 2
哪 : 4 3 2
哦 : 2
唧 : 3 2
唇 : 4 3 2
哽 : 2
唏 : 2
埔 : 3 2
埋 : 4 3 2
埃 : 5 3 2
夏 : 6 5 4 3 2
套 : 3 2
奚 : 2
娘 : 3 2
娟 : 2
娛 : 4 3 2
娓 : 4 2
孫 : 4 3 2
宰 : 2
害 : 4 3 2
家 : 8 6 5 4 3 2
宴 : 4 3 2
宮 : 4 3 2
宵 : 4 2
容 : 4 3 2
射 : 4 3 2
屑 : 2
展 : 4 3 2
屐 : 4
峭 : 2
峽 : 2
峻 : 4 2
峪 : 2
峨 : 4 3 2
峰 : 4 2
島 : 4 3 2
崁 : 3 2
差 : 8 4 3 2
席 : 6 4 3 2
師 : 4 2
庫 : 4 3 2
庭 : 4 3 2
座 : 4 3 2
弱 : 4 3 2
徒 : 4 2
徑 : 4 2
徐 : 4 3 2
恣 : 4 2
恥 : 4 2
恐 : 4 3 2
恕 : 4 2
恭 : 6 4 3 2
恩 : 4 3 2
息 : 4 2
悄 : 3 2
悟 : 2
悚 : 2
悍 : 4 2
悔 : 4 3 2
悅 : 4 2
悖 : 4 2
扇 : 4 3 2
拳 : 4 3 2
挈 : 4
拿 : 8 5 4 3 2
捎 : 4 2
挾 : 7 4 2
振 : 4 3 2
捕 : 4 3 2
捂 : 4 3 2
捆 : 3 2
捏 : 4 3 2
捉 : 8 5 4 3 2
挺 : 4 2
捐 : 4 3 2
挽 : 6 4 3 2
挪 : 4 3 2
挫 : 4 2
挨 : 4 3 2
捍 : 2
效 : 5 4 3 2
料 : 4 3 2
旁 : 4 3 2
旅 : 4 3 2
時 : 8 5 4 3 2
晉 : 4 3 2
晏 : 4 2
晃 : 4 2
晌 : 2
晁 : 2
書 : 4 3 2
朔 : 2
朗 : 3 2
校 : 4 3 2
核 : 5 4 3 2
案 : 4 2
框 : 2
根 : 4 3 2
桂 : 4 3 2
桔 : 2
栩 : 4 2
梳 : 3 2
栗 : 3 2
桌 : 5 4 3 2
桑 : 4 3 2
栽 : 4 3 2
柴 : 5 4 3 2
桐 : 2
桀 : 4 2
格 : 4 3 2
桃 : 8 6 5 4 3 2
株 : 4 2
桅 : 2
栓 : 3 2
桁 : 2
殊 : 4 3 2
殉 : 4 3 2
殷 : 4 2
氣 : 4 3 2
氧 : 4 3 2
氨 : 4 3 2
氦 : 2
泰 : 6 4 3 2
浪 : 4 3 2
涕 : 4 2
消 : 7 6 5 4 3 2
涇 : 4 2
浦 : 3 2
浸 : 4 3 2
海 : 6 5 4 3 2
浙 : 3 2
涓 : 4 2
涉 : 4 3 2
浮 : 4 3 2
浴 : 4 3 2
浩 : 4 2
浹 : 4
涅 : 4
涔 : 2
烘 : 4 3 2
烤 : 3 2
烙 : 3 2
烈 : 6 5 4 3 2
烏 : 6 5 4 3 2
爹 : 2
特 : 6 5 4 3 2
狼 : 4 3 2
狹 : 4 3 2
狸 : 2
班 : 5 4 3 2
琉 : 4 3 2
珠 : 5 4 3 2
畝 : 3 2
畜 : 3 2
畚 : 2
留 : 4 3 2
疾 : 6 5 4 2
病 : 5 4 3 2
症 : 3 2
疲 : 4 3 2
疳 : 2
疽 : 2
疼 : 4 2
疹 : 2
疸 : 2
皋 : 2
益 : 4 2
盎 : 4 3 2
眩 : 4 2
真 : 6 4 3 2
眠 : 4 2
眨 : 3 2
矩 : 4 2
砰 : 4 3 2
砧 : 2
砸 : 4 2
砝 : 2
破 : 4 3 2
砷 : 3
砥 : 4 2
祠 : 2
祟 : 2
祖 : 8 4 3 2
神 : 8 7 6 5 4 3 2
祝 : 4 3 2
秤 : 2
秣 : 4 2
秧 : 2
租 : 4 3 2
秦 : 4 3 2
秩 : 4 2
秘 : 4 3 2
窄 : 4 2
窈 : 4 2
站 : 4 3 2
笆 : 2
笑 : 4 3 2
粉 : 4 3 2
紡 : 5 3 2
紗 : 2
紋 : 4 3 2
紊 : 2
素 : 4 3 2
索 : 4 3 2
純 : 4 3 2
紐 : 6 5 4 3 2
紕 : 2
級 : 4 2
紜 : 2
納 : 4 3 2
紙 : 6 4 3 2
紛 : 4 2
缺 : 4 3 2
羔 : 3 2
翅 : 2
翁 : 3 2
耆 : 4
耕 : 4 3 2
耙 : 2
耗 : 4 3 2
耽 : 4 2
耿 : 4 2
脂 : 3 2
胰 : 4 3 2
脅 : 4 2
胭 : 3 2
胴 : 2
脆 : 4 2
胸 : 4 3 2
胳 : 2
脈 : 4 3 2
能 : 4 3 2
脊 : 4 3 2
胼 : 4
胯 : 2
臭 : 4 3 2
舀 : 2
舐 : 2
航 : 5 4 3 2
般 : 2
芻 : 2
茫 : 4 3 2
荒 : 4 3 2
荔 : 2
荊 : 4 3 2
茸 : 2
草 : 4 3 2
茴 : 2
荏 : 2
茲 : 4 2
茹 : 4 2
茶 : 4 3 2
茗 : 2
荀 : 2
茱 : 8 6 2
荃 : 2
虔 : 3 2
蚊 : 4 2
蚤 : 2
蚩 : 4
蚌 : 2
蚜 : 2
衰 : 3 2
衷 : 4 2
袁 : 3
記 : 5 4 3 2
討 : 4 3 2
訕 : 2
訊 : 4 3 2
訓 : 4 3 2
訖 : 2
豈 : 6 4 3 2
豺 : 4 2
豹 : 4 2
財 : 4 3 2
貢 : 4 3 2
起 : 6 5 4 3 2
躬 : 4 2
軒 : 4 3 2
辱 : 4 3 2
送 : 4 3 2
逆 : 4 3 2
迷 : 4 3 2
退 : 10 4 3 2
迴 : 5 4 3 2
逃 : 4 3 2
追 : 6 4 3 2
迸 : 3 2
郡 : 2
郝 : 3 2
郢 : 4
酒 : 4 3 2
配 : 4 3 2
酌 : 4 2
釘 : 3 2
針 : 4 3 2
釜 : 4 2
閃 : 4 3 2
院 : 4 2
陣 : 4 3 2
陡 : 2
陛 : 2
陝 : 5 3 2
除 : 4 3 2
陞 : 4 2
隻 : 4 2
馬 : 7 6 5 4 3 2
骨 : 5 4 3 2
高 : 6 5 4 3 2
鬥 : 4 3 2
鬼 : 4 3 2
乾 : 4 3 2
偽 : 5 4 3 2
停 : 4 3 2
假 : 4 3 2
偃 : 4 2
偌 : 2
做 : 4 3 2
偉 : 4 2
健 : 5 4 3 2
偶 : 4 3 2
偎 : 4 2
偕 : 2
偵 : 4 3 2
側 : 4 3 2
偷 : 7 4 3 2
偏 : 4 3 2
倏 : 4 2
兜 : 3 2
冕 : 2
剪 : 4 3 2
副 : 5 4 3 2
勒 : 4 3 2
務 : 4 2
勘 : 3 2
動 : 7 4 3 2
匐 : 2
匏 : 4
匙 : 2
匿 : 4 3 2
區 : 6 5 4 3 2
匾 : 2
參 : 4 3 2
曼 : 4 3 2
商 : 5 4 3 2
啪 : 2
啦 : 3 2
啄 : 3 2
啞 : 5 4 3 2
啃 : 2
啊 : 2
唱 : 4 3 2
問 : 4 3 2
唯 : 5 4 3 2
啤 : 3 2
唸 : 4 2
售 : 4 3 2
啜 : 4 2
唬 : 4 2
啁 : 3 2
圈 : 2
國 : 7 6 5 4 3 2
域 : 2
堅 : 8 4 3 2
堊 : 2
堆 : 4 3 2
埠 : 2
埤 : 3
基 : 4 3 2
堂 : 4 2
堵 : 2
執 : 5 4 3 2
培 : 4 3 2
夠 : 3 2
奢 : 4 3 2
娶 : 2
婁 : 2
婉 : 4 2
婦 : 7 5 4 3 2
婀 : 2
娼 : 2
婢 : 4 2
婚 : 5 4 3 2
婆 : 4 2
婊 : 2
孰 : 2
寅 : 4
寄 : 4 3 2
寂 : 4 2
宿 : 4 3 2
密 : 6 4 3 2
尉 : 2
專 : 5 4 3 2
將 : 4 3 2
屠 : 4 3 2
崇 : 4 3 2
崎 : 4 2
崛 : 2
崖 : 2
崢 : 4 2
崑 : 2
崩 : 2
崔 : 2
崙 : 3
崧 : 4
崗 : 2
巢 : 4 2
常 : 5 4 3 2
帶 : 4 3 2
帳 : 2
帷 : 4 2
康 : 4 3 2
庸 : 5 4 3 2
庶 : 2
庵 : 2
庾 : 3
張 : 7 4 3 2
強 : 7 6 5 4 3 2
彗 : 4 2
彬 : 4 2
彩 : 5 4 3 2
彫 : 4 2
得 : 8 7 4 3 2
徙 : 2
從 : 8 7 6 5 4 3 2
徘 : 2
御 : 4 3 2
徜 : 2
患 : 4 2
悉 : 4 2
悠 : 4 3 2
您 : 2
惋 : 2
惦 : 2
情 : 7 4 3 2
悻 : 2
悵 : 4 2
惜 : 4 2
悼 : 4 2
惘 : 4 2
惕 : 4
惆 : 2
惟 : 6 5 4 2
悸 : 2
戚 : 2
戛 : 4 2
掠 : 4 3 2
控 : 4 3 2
捲 : 4 3 2
探 : 4 3 2
接 : 4 3 2
捷 : 8 7 4 3 2
捧 : 4 2
掘 : 4 3 2
措 : 4 3 2
捱 : 4 2
掩 : 4 3 2
掉 : 4 3 2
掃 : 4 3 2
掛 : 6 4 3 2
捫 : 4 2
推 : 4 3 2
掄 : 4 2
授 : 4 3 2
掙 : 2
採 : 8 6 5 4 3 2
掬 : 2
排 : 4 3 2
掏 : 4 3 2
掀 : 4 3 2
捻 : 4 3 2
捨 : 4 3 2
捺 : 2
敝 : 4 2
敖 : 4 3
救 : 5 4 3 2
教 : 5 4 3 2
敗 : 4 3 2
啟 : 4 3 2
敏 : 3 2
敘 : 4 3 2
敕 : 2
斜 : 4 3 2
斬 : 4 2
族 : 2
旋 : 4 3 2
旌 : 4 2
晝 : 4 2
晚 : 6 4 2
晤 : 2
晨 : 4 2
晦 : 4 2
曹 : 4 3 2
望 : 4 3 2
梁 : 3 2
梯 : 4 3 2
梢 : 2
梓 : 3
梵 : 3 2
桿 : 4 2
桶 : 4 2
梧 : 4 2
梗 : 2
械 : 2
棄 : 4 3 2
梭 : 2
梆 : 2
梅 : 5 4 3 2
梔 : 2
條 : 4 3 2
梨 : 4 2
梟 : 2
欲 : 8 5 4 3 2
殺 : 8 6 5 4 3 2
毫 : 4 3 2
氫 : 4 3 2
涎 : 4
涼 : 4 3 2
淳 : 2
淙 : 2
液 : 5 3 2
淡 : 4 3 2
淌 : 3 2
淤 : 3 2
添 : 4 3 2
淺 : 4 3 2
清 : 7 5 4 3 2
淇 : 2
淋 : 4 3 2
涯 : 2
淑 : 4 2
涮 : 2
淞 : 2
淹 : 4 2
涸 : 4
混 : 4 3 2
淵 : 2
淅 : 2
淒 : 4 2
涵 : 2
淚 : 4 3 2
淫 : 4 2
淘 : 3 2
淪 : 4 3 2
深 : 4 3 2
淮 : 4 2
淨 : 4 3 2
淄 : 2
涪 : 2
淬 : 3 2
涿 : 2
烹 : 4 3 2
焉 : 2
焊 : 3 2
烽 : 4 2
烯 : 2
爽 : 4 3 2
牽 : 7 4 3 2
犁 : 4 2
猜 : 4 3 2
猛 : 4 3 2
猖 : 2
猙 : 4 2
率 : 4 2
琅 : 4 2
球 : 4 3 2
理 : 6 5 4 3 2
現 : 4 3 2
瓶 : 4 2
瓷 : 2
甜 : 4 3 2
產 : 4 3 2
略 : 4 3 2
畦 : 2
畢 : 6 4 3 2
異 : 4 3 2
疏 : 4 2
痔 : 2
痕 : 2
疵 : 2
痊 : 2
皎 : 2
盔 : 3 2
盒 : 2
盛 : 8 4 3 2
眷 : 4 2
眾 : 7 4 3 2
眼 : 8 6 5 4 3 2
眸 : 2
眺 : 2
硫 : 4 3 2
硃 : 2
祥 : 4 2
票 : 5 4 3 2
祭 : 5 3 2
移 : 4 3 2
窒 : 2
笠 : 2
笨 : 4 2
笛 : 3 2
第 : 8 7 6 5 4 3 2
符 : 3 2
笙 : 4 2
笞 : 2
粒 : 4 3 2
粗 : 5 4 3 2
絆 : 3 2
統 : 6 4 3 2
紮 : 2
紹 : 3 2
細 : 4 3 2
紳 : 3 2
組 : 5 4 3 2
累 : 4 3 2
終 : 4 3 2
缽 : 2
羞 : 4 3 2
羚 : 4 2
翌 : 2
翎 : 2
習 : 5 4 3 2
聊 : 4 3 2
聆 : 3 2
脖 : 2
脫 : 4 3 2
舵 : 3 2
舷 : 3 2
舶 : 3 2
船 : 7 4 3 2
莎 : 5 4
莞 : 2
莘 : 2
荸 : 2
莢 : 2
莖 : 2
莽 : 2
莫 : 7 4 3 2
莒 : 3
莊 : 4 3 2
莉 : 2
莠 : 2
荷 : 4 3 2
荼 : 4 2
莆 : 2
莧 : 2
處 : 6 4 3 2
彪 : 4 2
蛇 : 4 3 2
蛀 : 3 2
蛋 : 3 2
蚱 : 2
蚯 : 2
術 : 3 2
袞 : 4
袈 : 2
被 : 6 5 4 3 2
袒 : 4 2
袖 : 4 3 2
袍 : 4 2
袋 : 2
覓 : 4 2
規 : 4 3 2
訪 : 4 3 2
訣 : 2
許 : 4 3 2
設 : 4 3 2
訟 : 2
訛 : 4 2
豚 : 2
販 : 4 3 2
責 : 4 3 2
貫 : 4 2
貨 : 5 4 3 2
貪 : 7 5 4 3 2
貧 : 5 4 3 2
赧 : 4 2
赦 : 4 2
趾 : 4 3 2
趺 : 2
軟 : 4 3 2
這 : 7 6 5 4 3 2
逍 : 4 3 2
通 : 5 4 3 2
逗 : 3 2
連 : 6 5 4 3 2
速 : 4 3 2
逝 : 4 2
逐 : 4 3 2
逕 : 2
逞 : 4 2
造 : 8 4 3 2
透 : 4 3 2
逢 : 4 2
逛 : 2
途 : 2
部 : 4 3 2
郭 : 3
都 : 4 3 2
酗 : 2
野 : 4 3 2
釣 : 4 3 2
釩 : 3
閉 : 4 3 2
陪 : 4 3 2
陵 : 4 2
陳 : 6 4 3 2
陸 : 5 4 3 2
陰 : 5 4 3 2
陶 : 4 3 2
陷 : 4 2
雀 : 4 2
雪 : 5 4 3 2
章 : 4 3 2
竟 : 3 2
頂 : 4 3 2
頃 : 4 2
魚 : 4 3 2
鳥 : 4 3 2
鹵 : 4 3 2
鹿 : 7 5 4 3 2
麥 : 6 5 4 3 2
麻 : 6 4 3 2
傢 : 3 2
傍 : 4 2
傅 : 4
備 : 4 3 2
傑 : 4 3 2
傀 : 3 2
傘 : 3 2
傚 : 2
最 : 7 6 5 4 3 2
凱 : 7 4 3 2
割 : 6 4 3 2
創 : 7 4 3 2
剩 : 4 2
勞 : 5 4 3 2
勝 : 7 6 4 3 2
博 : 6 4 3 2
喀 : 4 3 2
喧 : 4 3 2
啼 : 4 3 2
喊 : 4 3 2
喝 : 4 3 2
喘 : 4 3 2
喂 : 2
喜 : 5 4 3 2
喪 : 4 3 2
喔 : 2
喇 : 3 2
喋 : 4 2
喃 : 4 2
喳 : 2
單 : 5 4 3 2
喟 : 2
唾 : 4 3 2
喚 : 3 2
喻 : 2
喬 : 5 4 3 2
啾 : 2
喉 : 3 2
喫 : 2
喙 : 4
圍 : 5 4 3 2
堯 : 4 2
堪 : 4 3 2
場 : 2
堤 : 4 3 2
堰 : 3 2
報 : 5 4 3 2
堡 : 3 2
壹 : 2
壺 : 4 2
奠 : 4 3 2
婷 : 2
媚 : 2
媒 : 3 2
孳 : 2
孱 : 2
寒 : 4 3 2
富 : 5 4 3 2
寓 : 3 2
寐 : 2
尊 : 6 4 2
尋 : 4 3 2
就 : 4 3 2
嵌 : 4 3 2
幅 : 4 3 2
帽 : 2
幀 : 2
幾 : 6 5 4 3 2
廊 : 2
廁 : 2
廂 : 2
廄 : 2
彭 : 3
復 : 4 3 2
循 : 4 3 2
徨 : 2
惑 : 4 2
惡 : 5 4 3 2
悲 : 4 3 2
悶 : 4 3 2
惠 : 5 4 3 2
愜 : 2
愣 : 2
惺 : 5 4 2
愕 : 2
惰 : 4 2
惻 : 4 2
惴 : 4 2
慨 : 4 2
惱 : 4 2
惶 : 6 4 2
愉 : 2
戟 : 4
扉 : 2
掣 : 4 2
掌 : 5 4 3 2
描 : 4 3 2
揀 : 4 3 2
揩 : 2
揉 : 4 3 2
插 : 4 3 2
揣 : 4 2
提 : 6 5 4 3 2
握 : 4 2
揖 : 2
揭 : 4 3 2
揮 : 4 3 2
捶 : 4 2
援 : 4 3 2
揪 : 4 3 2
換 : 5 4 3 2
摒 : 2
揚 : 4 3 2
敞 : 4 3 2
敦 : 4 3 2
敢 : 6 5 4 3 2
散 : 4 3 2
斑 : 4 3 2
斐 : 4 3 2
斯 : 5 4 3 2
普 : 5 4 3 2
晴 : 4 3 2
晶 : 5 4 3 2
景 : 6 4 3 2
暑 : 4 2
智 : 8 5 4 3 2
晾 : 2
曾 : 4 3 2
替 : 5 4 3 2
期 : 5 4 3 2
朝 : 8 7 4 3 2
棺 : 2
棕 : 3 2
棠 : 2
棘 : 2
棗 : 2
椅 : 2
棟 : 4 2
棵 : 2
森 : 4 3 2
棧 : 4 2
棒 : 4 3 2
棲 : 3 2
棋 : 4 3 2
棍 : 2
植 : 4 3 2
椒 : 2
椎 : 4 2
棉 : 4 3 2
棚 : 3 2
款 : 4 2
欺 : 4 3 2
欽 : 4 2
殘 : 8 6 4 3 2
殖 : 4 3 2
殼 : 2
毯 : 2
氮 : 3 2
氯 : 4 3 2
港 : 5 4 3 2
游 : 4 3 2
渡 : 4 3 2
渲 : 2
湧 : 2
湊 : 3 2
渠 : 2
渥 : 3
渣 : 4 3 2
減 : 4 3 2
湛 : 2
湘 : 2
渤 : 3 2
湖 : 4 3 2
湮 : 2
渭 : 4 2
渦 : 3 2
湯 : 5 4 3 2
渴 : 4 3 2
湍 : 2
渺 : 4 2
測 : 3 2
渾 : 4 2
滋 : 4 3 2
渙 : 2
湎 : 2
湄 : 3
湟 : 2
焙 : 2
焚 : 4 3 2
焦 : 4 3 2
焰 : 2
無 : 8 7 6 5 4 3 2
然 : 4 2
煮 : 4 2
牌 : 3 2
犄 : 4 2
犀 : 4 2
猶 : 6 4 3 2
猥 : 4 2
猴 : 4 2
猩 : 3 2
琺 : 2
琪 : 4
琳 : 4 2
琢 : 4 2
琥 : 3 2
琵 : 4 2
琴 : 4 3 2
琨 : 4 2
甥 : 2
甦 : 3 2
畫 : 7 4 3 2
番 : 4 3 2
痢 : 3 2
痛 : 4 3 2
痙 : 2
痘 : 2
痞 : 2
登 : 4 3 2
發 : 5 4 3 2
皖 : 4 2
皓 : 4 2
皴 : 2
盜 : 4 3 2
睏 : 2
短 : 4 3 2
硝 : 4 3 2
硬 : 4 3 2
硯 : 2
稍 : 4 3 2
稈 : 2
程 : 5 4 3 2
稅 : 4 3 2
稀 : 4 3 2
窘 : 4 2
窗 : 4 3 2
窖 : 2
童 : 5 4 3 2
竣 : 2
等 : 5 4 3 2
策 : 4 3 2
筆 : 5 4 3 2
筐 : 4 2
筒 : 3 2
答 : 4 3 2
筍 : 2
筋 : 4 2
筏 : 2
粟 : 4 2
粥 : 4 2
絞 : 4 3 2
結 : 4 3 2
絨 : 3 2
絕 : 6 5 4 3 2
紫 : 4 3 2
絮 : 4 2
絲 : 4 3 2
絡 : 4 3 2
給 : 4 3 2
絢 : 4 2
善 : 5 4 3 2
翔 : 2
翕 : 2
聒 : 2
肅 : 4 2
腕 : 3 2
腔 : 2
腋 : 2
腑 : 2
腎 : 3 2
脹 : 2
腆 : 2
脾 : 4 3 2
舒 : 4 2
舜 : 4
菩 : 4 3 2
萃 : 2
菸 : 2
萍 : 4 2
菠 : 2
萋 : 4 2
菁 : 2
華 : 5 4 3 2
菱 : 4 3 2
著 : 4 3 2
萊 : 3 2
萌 : 3 2
菌 : 3 2
菽 : 4
菲 : 7 4 3 2
菊 : 4 2
萎 : 4 3 2
菜 : 3 2
萇 : 4
虛 : 4 3 2
蛟 : 4 2
蛙 : 2
蛔 : 2
蛛 : 7 4 3 2
蛤 : 3 2
街 : 5 4 3 2
裁 : 4 3 2
裂 : 4 3 2
視 : 8 5 4 3 2
註 : 2
詠 : 4 3 2
評 : 5 4 3 2
詞 : 4 3 2
詔 : 2
詛 : 2
詐 : 4 3 2
詆 : 2
訴 : 4 3 2
診 : 4 3 2
訶 : 2
象 : 4 3 2
貂 : 6 4 2
貯 : 3 2
貼 : 4 3 2
貽 : 4 2
賁 : 2
費 : 4 3 2
賀 : 3 2
貴 : 4 3 2
買 : 4 3 2
貶 : 3 2
貿 : 4 3 2
貸 : 3 2
越 : 6 5 4 3 2
超 : 5 4 3 2
趁 : 4 2
距 : 3 2
跋 : 4 2
跑 : 4 3 2
跌 : 4 2
跛 : 4 3 2
跆 : 6 3 2
軸 : 4 3 2
軼 : 4 2
辜 : 4 3 2
逮 : 4 3 2
週 : 4 3 2
逸 : 4 2
進 : 5 4 3 2
逶 : 2
鄂 : 2
郵 : 4 3 2
鄉 : 5 4 3 2
酣 : 4 2
酥 : 2
量 : 4 3 2
鈔 : 2
鈕 : 3 2
鈣 : 4 2
鈉 : 2
鈞 : 2
鈍 : 3 2
閏 : 2
開 : 5 4 3 2
間 : 4 3 2
閒 : 4 3 2
閎 : 4
隊 : 4 2
階 : 4 3 2
隋 : 2
陽 : 4 3 2
隅 : 2
隆 : 4 3 2
雁 : 4 3 2
雅 : 4 3 2
雄 : 4 3 2
集 : 5 4 3 2
雇 : 2
雲 : 5 4 3 2
韌 : 2
項 : 8 4 3 2
順 : 8 4 3 2
須 : 3 2
飯 : 4 3 2
飲 : 4 3 2
飭 : 2
馮 : 2
黃 : 5 4 3 2
黍 : 4 2
黑 : 7 5 4 3 2
亂 : 4 3 2
傭 : 2
債 : 4 3 2
傲 : 5 4 2
傳 : 5 4 3 2
僅 : 4 3 2
傾 : 4 3 2
催 : 4 3 2
傷 : 4 3 2
傻 : 4 3 2
剿 : 2
剷 : 2
剽 : 3 2
募 : 3 2
勤 : 4 3 2
勢 : 4 3 2
匯 : 4 3 2
嗟 : 4
嗓 : 3 2
嗦 : 2
嗎 : 3 2
嗜 : 4 2
嗑 : 2
嗣 : 2
嗤 : 4 2
嗯 : 2
嗚 : 4 2
嗡 : 3 2
嗅 : 3 2
嗆 : 2
嗥 : 2
嗉 : 2
園 : 3 2
圓 : 6 4 3 2
塞 : 4 3 2
塑 : 4 3 2
塘 : 4 2
塗 : 4 3 2
塚 : 4
塔 : 5 4 3 2
填 : 6 4 3 2
塌 : 3 2
塊 : 3 2
奧 : 7 4 3 2
嫁 : 4 3 2
嫉 : 4 3 2
嫌 : 4 3 2
媾 : 2
媽 : 2
媳 : 3 2
嫂 : 3 2
媲 : 2
嵩 : 2
幌 : 2
幹 : 5 4 3 2
廉 : 4 3 2
廈 : 3 2
弒 : 3 2
彙 : 4 3 2
微 : 5 4 3 2
愚 : 8 4 3 2
意 : 6 4 3 2
慈 : 5 4 3 2
感 : 4 3 2
想 : 5 4 3 2
愛 : 8 6 5 4 3 2 1
惹 : 4 3 2
愁 : 4 2
愈 : 4 3 2
慎 : 4 2
慌 : 4 3 2
慄 : 4
慍 : 2
愴 : 4 2
愧 : 2
愷 : 4 2
戡 : 2
戢 : 4
搓 : 4 2
搾 : 3 2
搞 : 4 3 2
搪 : 3 2
搭 : 3 2
搽 : 4 2
搬 : 4 3 2
搏 : 4 2
搜 : 4 3 2
搔 : 4 3 2
損 : 5 4 3 2
搶 : 4 3 2
搖 : 4 3 2
搗 : 4 3 2
敬 : 6 4 3 2
斟 : 2
新 : 8 7 6 5 4 3 2
暗 : 5 4 3 2
暉 : 2
暇 : 2
暈 : 4 3 2
暖 : 4 3 2
暄 : 2
會 : 4 3 2
榔 : 2
業 : 5 4 3 2
楚 : 4 2
楷 : 2
楠 : 4 3 2
楔 : 2
極 : 4 3 2
椰 : 3 2
概 : 4 3 2
楊 : 5 4 3 2
楞 : 2
楓 : 2
楹 : 2
榆 : 4 2
楣 : 2
歇 : 4 3 2
歲 : 4 3 2
毀 : 5 4 3 2
殿 : 2
毓 : 4
毽 : 2
溢 : 4 3 2
溯 : 4 2
溶 : 3 2
滂 : 2
源 : 4 3 2
溝 : 4 2
滇 : 2
滅 : 4 3 2
溥 : 4
溘 : 2
溺 : 3 2
溫 : 5 4 3 2
滑 : 4 3 2
準 : 4 3 2
溜 : 4 3 2
滄 : 4 2
滔 : 4 2
溪 : 4 3 2
溧 : 2
溴 : 3 2
煎 : 4 3 2
煙 : 4 3 2
煩 : 4 2
煤 : 4 3 2 1
煉 : 3 2
照 : 5 4 3 2
煦 : 2
煌 : 4 2
煥 : 4 2
煞 : 4 2
煨 : 4
爺 : 4 2
獅 : 8 6 4 3 2
猿 : 4 2
瑚 : 4
瑕 : 4 2
瑟 : 4 2
瑞 : 4 3 2
瑙 : 2
瑜 : 4 2
當 : 6 4 3 2
畸 : 4 3 2
瘀 : 2
痰 : 4 2
痱 : 2
盞 : 2
盟 : 4 3 2
睫 : 3 2
睦 : 2
督 : 4 3 2
睹 : 4
睪 : 3 2
睜 : 8 4 2
睥 : 4
矮 : 4 3 2
碎 : 4 3 2
碰 : 5 3 2
碗 : 3 2
碘 : 3 2
碌 : 4 2
碉 : 2
硼 : 3 2
碑 : 2
祿 : 8
禁 : 4 3 2
萬 : 8 6 5 4 3 2
禽 : 4 2
稜 : 2
稚 : 2
稠 : 4 2
稔 : 4
稟 : 2
稞 : 2
窟 : 2
窠 : 2
筷 : 2
節 : 5 4 3 2
粳 : 2
粵 : 4 2
經 : 7 6 5 4 3 2
絹 : 2
綁 : 2
綏 : 2
絛 : 2
置 : 8 7 6 4 3 2
罩 : 3 2
罪 : 4 2
署 : 2
義 : 4 3 2
羨 : 2
群 : 8 5 4 3 2
聖 : 5 4 3 2
聘 : 3 2
肆 : 4 2
肄 : 2
腱 : 2
腰 : 4 3 2
腸 : 4 3 2
腥 : 4 2
腮 : 3 2
腳 : 5 4 3 2
腫 : 2
腹 : 4 3 2
腺 : 2
腦 : 6 5 4 3 2
舅 : 2
艇 : 2
蒂 : 2
葷 : 2
落 : 8 4 3 2
萱 : 4
葵 : 3 2
葦 : 2
葫 : 3 2
葉 : 5 4 3 2
葬 : 4 3 2
葛 : 6 4 3 2
萼 : 2
萵 : 2
葡 : 4 3 2
董 : 4 3 2
葭 : 4
虞 : 2
虜 : 2
號 : 4 3 2
蛹 : 3 2
蜈 : 2
蜀 : 4 2
蛾 : 4 2
蛻 : 4 2
蜂 : 4 3 2
蜃 : 4
衙 : 4 2
裔 : 2
裙 : 4 3 2
補 : 5 4 3 2
裘 : 4 2
裝 : 4 3 2
裡 : 5 4 3 2
裊 : 4 2
裕 : 4 2
裒 : 4
解 : 7 5 4 3 2
詫 : 2
該 : 4 3 2
詳 : 4 2
試 : 4 3 2
詩 : 4 3 2 1
詰 : 4 2
誇 : 4 3 2
詼 : 3 2
誠 : 4 2
話 : 5 4 3 2
誅 : 4 2
詭 : 4 3 2
詢 : 4 3 2
詮 : 2
詬 : 2
詹 : 3
豢 : 2
賊 : 4 2
資 : 6 4 3 2
賈 : 3
賄 : 4 3 2
跡 : 2
跟 : 3 2
跨 : 4 3 2
路 : 8 5 4 3 2
跳 : 4 3 2
跺 : 2
跪 : 4 3 2
躲 : 8 4 3 2
較 : 4 3 2
載 : 4 3 2
辟 : 4 2
農 : 7 6 5 4 3 2
運 : 8 4 3 2
遊 : 4 3 2
道 : 8 7 6 5 4 3 2
遂 : 2
達 : 8 4 3 2
逼 : 5 4 3 2
違 : 5 4 3 2
遐 : 4 2
遇 : 4 3 2
遏 : 4 2
過 : 6 4 3 2
遍 : 4 2
逾 : 4 3 2
遁 : 4 3 2
鄒 : 4
酬 : 3 2
酪 : 2
酩 : 4 2
釉 : 2
鈷 : 2
鉗 : 4 2
鉀 : 2
鈾 : 2
鉛 : 4 3 2
鉤 : 4 3 2
鈴 : 4 3 2
鉅 : 4 2
鉚 : 2
閘 : 2
隘 : 2
隔 : 4 3 2
隕 : 3 2
雍 : 4 2
雋 : 2
雉 : 2
雷 : 5 4 3 2
電 : 7 5 4 3 2
雹 : 2
零 : 4 3 2
靖 : 2
靴 : 2
靶 : 2
預 : 5 4 3 2
頑 : 4 3 2
頓 : 4 3 2
頒 : 4 2
頌 : 4 3 2
飼 : 3 2
飴 : 2
飽 : 8 5 4 3 2
飾 : 4 3 2
馳 : 4 2
馱 : 2
馴 : 3 2
鳩 : 4
麂 : 2
鼎 : 4 2
鼓 : 4 3 2
鼠 : 4 3 2
僧 : 4 2
僥 : 2
僚 : 2
僕 : 4 2
像 : 5 3 2
僑 : 5 4 3 2
僱 : 3 2
兢 : 4 2
凳 : 2
劃 : 4 3 2
匱 : 2
厭 : 4 3 2
嗾 : 2
嘀 : 4 3 2
嘗 : 4 3 2
嗽 : 3 2
嘔 : 4 3 2
嘉 : 4 3 2
嘍 : 2
嘎 : 3 2
嗷 : 4 2
嘖 : 4 2
嘟 : 4 2
嘈 : 4 3 2
嗶 : 2
團 : 4 3 2
圖 : 5 4 3 2
塵 : 4 2
境 : 3 2
墓 : 3 2
墊 : 3 2
塹 : 2
壽 : 4 3 2
夥 : 3 2
夢 : 4 3 2
夤 : 4
奪 : 4 2
嫡 : 2
嫦 : 2
嫩 : 2
嫖 : 2
嫘 : 3
嫣 : 4 2
孵 : 3 2
寞 : 2
寧 : 8 7 5 4 3 2
寡 : 4 3 2
寥 : 4 2
實 : 5 4 3 2
寨 : 2
寢 : 4 3 2
察 : 4 3 2
對 : 7 6 5 4 3 2
屢 : 4 2
嶄 : 4 2
幣 : 4 2
幕 : 4 2
廖 : 3
弊 : 4 2
彆 : 2
彰 : 4 2
徹 : 4 2
態 : 4 2
慷 : 5 4 2
慢 : 5 4 3 2
慣 : 4 3 2
慟 : 2
慚 : 2
慘 : 4 3 2
慵 : 2
截 : 4 3 2
撇 : 2
摘 : 4 3 2
摔 : 3 2
撤 : 4 2
摸 : 5 4 3 2
摟 : 2
摺 : 2
摧 : 4 2
搴 : 4
摭 : 4
摻 : 3 2
敲 : 4 3 2
斡 : 2
旗 : 4 3 2
旖 : 4 2
暢 : 4 3 2
榜 : 4 2
榨 : 3
榕 : 2
槁 : 4
榮 : 4 3 2
槓 : 4 2
構 : 4 3 2
榛 : 2
榻 : 3 2
榫 : 2
榴 : 3 2
槐 : 2
槍 : 4 3 2
槌 : 5 4 2
歉 : 2
歌 : 4 3 2
漳 : 2
演 : 4 3 2
滾 : 4 3 2
漓 : 2
滴 : 4 3 2
漩 : 2
漾 : 2
漠 : 4 2
漏 : 5 4 3 2
漂 : 4 3 2
漢 : 6 5 4 3 2
滿 : 6 4 3 2
滯 : 3 2
漆 : 4 3 2
漱 : 4 3 2
漸 : 4 3 2
漲 : 3 2
漣 : 2
漕 : 2
漫 : 4 3 2
澈 : 2
滬 : 2
漁 : 4 3 2
滲 : 3 2
滌 : 4 3 2
滷 : 2
熔 : 3 2
熙 : 4 3 2
煽 : 4 3 2
熊 : 4 3 2
熄 : 3 2
熒 : 3 2
爾 : 4 2
犒 : 2
獄 : 2
獐 : 4
瑤 : 4 2
瑣 : 4 2
瑪 : 3 2
瑰 : 4 2
甄 : 4 2
疑 : 8 5 4 3 2
瘧 : 3 2
瘋 : 4 3 2
盡 : 5 4 3 2
監 : 4 3 2
瞄 : 3 2
睽 : 4 2
睿 : 2
睡 : 4 3 2
磁 : 3 2
碟 : 3 2
碧 : 4 3 2
碳 : 5 4 3 2
碩 : 5 4 3 2
福 : 8 5 4 3 2
禍 : 4 2
種 : 8 6 4 3 2
稱 : 4 3 2
窪 : 2
窩 : 4 3 2
竭 : 4 2
端 : 4 3 2
管 : 4 3 2
箕 : 4
箋 : 2
筵 : 2
算 : 4 3 2
箝 : 4 2
箔 : 2
箸 : 4
粽 : 2
精 : 8 5 4 3 2
綻 : 2
綰 : 2
綜 : 4 3 2
綽 : 4 2
綾 : 2
綠 : 6 4 3 2
緊 : 4 3 2
綴 : 4 2
網 : 5 4 3 2
綱 : 5 4 3 2
綺 : 4 2
綢 : 2
綿 : 4 3 2
綵 : 2
維 : 6 4 3 2
緒 : 2
綬 : 2
罰 : 4 3 2
翠 : 4 3 2
翡 : 2
聞 : 6 4 2
聚 : 5 4 3 2
肇 : 3 2
腐 : 4 3 2
膀 : 4 3 2
膏 : 4 3 2
膈 : 2
腿 : 3 2
膂 : 2
臧 : 4
臺 : 4 2
與 : 5 4 3 2
舔 : 4 2
舞 : 4 3 2
蓉 : 2
蒿 : 4
蓄 : 4 3 2
蒙 : 4 3 2
蒞 : 2
蒲 : 4 3 2
蒜 : 2
蓋 : 4 3 2
蒸 : 4 3 2
蓓 : 2
蒐 : 2
蒼 : 4 3 2
蓑 : 2
蜿 : 4 2
蜜 : 6 4 3 2
蜻 : 4 2
蜥 : 3 2
蜘 : 3 2
蝕 : 3 2
蜷 : 2
蜩 : 4
褂 : 2
裴 : 2
裹 : 4 2
裸 : 4 3 2
製 : 3 2
裨 : 2
誦 : 2
語 : 5 4 3 2
誣 : 4 2
認 : 4 3 2
誡 : 2
誓 : 4 2
誤 : 4 3 2
說 : 8 6 5 4 3 2
誨 : 8 4 2
誘 : 4 3 2
誑 : 2
豪 : 4 3 2
貌 : 4 2
賓 : 4 2
賑 : 4 2
賒 : 2
赫 : 4 2
趙 : 3 2
趕 : 6 5 4 3 2
輔 : 4 3 2
輕 : 4 3 2
輓 : 2
辣 : 3 2
遠 : 8 7 6 4 3 2
遜 : 4 2
遣 : 4 2
遙 : 4 3 2
遞 : 4 3 2
遛 : 3 2
鄙 : 4 2
酵 : 4 3 2
酸 : 4 3 2
酷 : 5 3 2
鉸 : 2
銀 : 4 3 2
銅 : 8 4 3 2
銘 : 4 2
銖 : 4 2
鉻 : 2
銓 : 3 2
銜 : 4 2
銨 : 2
銑 : 2
閨 : 2
閩 : 2
閣 : 2
閥 : 2
隙 : 4 2
障 : 3 2
際 : 4 2
雌 : 4 3 2
需 : 3 2
韶 : 4 2
頗 : 4 2
領 : 5 4 3 2
颯 : 4 3 2
颱 : 2
餃 : 2
餅 : 2
餌 : 2
餉 : 2
駁 : 4 3 2
骯 : 2
骰 : 3 2
魁 : 3 2
魂 : 4 2
鳴 : 4 3 2
鳶 : 4
鳳 : 4 3 2
麼 : 2
鼻 : 4 3 2
齊 : 4 3 2
億 : 4 2
儀 : 4 3 2
僻 : 2
僵 : 4 2
價 : 4 3 2
儉 : 2
凜 : 2
劇 : 3 2
劈 : 4 3 2
劉 : 3 2
劍 : 4 3 2
劊 : 3
厲 : 4 2
嘮 : 4 2
嘻 : 4 2
嘹 : 3 2
嘲 : 4 3 2
嘿 : 2
嘴 : 3 2
嘩 : 4 2
噓 : 4 2
噎 : 2
噗 : 2
噴 : 5 4 3 2
嘶 : 3 2
嘯 : 3 2
嘰 : 4 3 2
增 : 4 3 2
墳 : 2
墜 : 4 2
墮 : 4 3 2
墩 : 2
嬉 : 4 3 2
嫻 : 2
嬋 : 2
嫵 : 2
嬌 : 4 3 2
寮 : 2
寬 : 4 3 2
審 : 5 4 3 2
寫 : 4 3 2
層 : 4 3 2
履 : 6 4 3 2
幢 : 2
幡 : 4 2
廢 : 6 4 3 2
廚 : 2
廟 : 2
廝 : 4 2
廣 : 7 5 4 3 2
廠 : 5 4 2
彈 : 4 3 2
影 : 4 3 2
德 : 5 4 3 2
徵 : 4 3 2
慶 : 8 4 3 2
慧 : 4 2
慮 : 2
慕 : 4 3 2
憂 : 4 3 2
慰 : 4 3 2
慫 : 2
慾 : 4 2
憧 : 2
憐 : 4 2
憫 : 2
憎 : 2
憤 : 4 2
憔 : 2
戮 : 4 2
摩 : 5 4 3 2
摯 : 2
摹 : 3 2
撞 : 4 3 2
撲 : 4 3 2
撈 : 3 2
撐 : 4 3 2
撰 : 3 2
撥 : 4 3 2
撓 : 4 2
撕 : 4 3 2
撩 : 4 2
撒 : 4 3 2
撮 : 4 2
播 : 4 3 2
撫 : 4 3 2
撬 : 2
撳 : 2
敵 : 4 3 2
敷 : 4 2
數 : 5 4 3 2
暮 : 4 2
暫 : 4 3 2
暴 : 4 3 2
暱 : 2
樣 : 4 3 2
樟 : 3 2
樁 : 2
樞 : 3 2
標 : 5 4 3 2
槽 : 2
模 : 4 3 2
樓 : 4 3 2
樊 : 3 2
槳 : 2
樂 : 5 4 3 2
樅 : 2
樑 : 4 2
歐 : 8 7 5 4 3 2
歎 : 5 4 2
毅 : 4 2
毆 : 4 2
漿 : 4 2
潼 : 2
澄 : 4 3 2
潑 : 4 3 2
潦 : 4 2
潔 : 4 2
澆 : 4 2
潭 : 3 2
潛 : 4 3 2
潸 : 2
潮 : 4 3 2
澎 : 3 2
潺 : 3 2
潰 : 4 3 2
潤 : 4 3 2
澗 : 2
潘 : 4 3
滕 : 2
熟 : 4 3 2
熬 : 2
熱 : 6 5 4 3 2
熨 : 3 2
牖 : 4
獎 : 4 3 2
瑩 : 4 2
璀 : 2
畿 : 2
瘠 : 4 2
瘟 : 2
瘤 : 2
瘦 : 4 2
瘡 : 4 2
瘢 : 2
皚 : 2
皺 : 4 3 2
盤 : 4 3 2
瞎 : 4 3 2
瞇 : 2
瞌 : 2
瞑 : 2
磋 : 3 2
磅 : 2
確 : 4 3 2
磊 : 4 2
碾 : 2
磕 : 4 2
碼 : 2
磐 : 4 2
稿 : 2
稼 : 4
穀 : 2
稽 : 4 2
稻 : 3 2
窯 : 2
窮 : 4 3 2
箭 : 4 2
箱 : 2
範 : 4 3 2
箴 : 3 2
篆 : 3 2
篇 : 2
糊 : 4 3 2
締 : 3 2
練 : 4 3 2
緯 : 4 2
緻 : 2
緘 : 4 2
緬 : 3 2
緝 : 2
編 : 5 4 3 2
緣 : 4 2
線 : 4 3 2
緞 : 2
緩 : 4 3 2
罵 : 4 3 2
罷 : 4 3 2
羯 : 4
翩 : 4 2
耦 : 3 2
膛 : 2
膜 : 2
膝 : 4 3 2
膠 : 4 3 2
膚 : 4 2
膘 : 4 2
蔗 : 2
蔽 : 4 2
蔚 : 4 2
蓮 : 5 2
蔬 : 3 2
蔭 : 4 2
蔓 : 3 2
蔑 : 2
蔣 : 3 2
蔡 : 3 2
蓬 : 4 2
蔥 : 4 2
蝴 : 3 2
蝶 : 4 2
蝦 : 4 2
蝸 : 4 2
蝙 : 3 2
蝗 : 2
蝌 : 2
衛 : 5 4 3 2
衝 : 4 3 2
褐 : 3 2
複 : 4 3 2
褒 : 4 3 2
褓 : 2
諒 : 2
談 : 4 3 2
諄 : 4 2
誕 : 4 3 2
請 : 6 5 4 3 2
諸 : 4 3 2
課 : 4 3 2
諉 : 2
諂 : 4 3 2
調 : 6 5 4 3 2
誰 : 6 4 3 2
論 : 4 3 2
諍 : 2
誶 : 2
誹 : 4 3 2
諛 : 2
豌 : 3 2
豎 : 6 4 3 2
豬 : 5 4 3 2 1
賠 : 7 4 3 2
賞 : 4 2
賦 : 4 2
賤 : 4 3 2
賬 : 3 2
賭 : 3 2
賢 : 4 3 2
賣 : 5 4 3 2
賜 : 2
質 : 4 3 2
赭 : 4 2
趟 : 2
趣 : 4 3 2
踐 : 2
踝 : 3 2
踢 : 4 3 2
踏 : 7 4 3 2
踩 : 3 2
踟 : 2
躺 : 2
輝 : 4 2
輛 : 2
輟 : 4 2
輩 : 2
輦 : 4
輪 : 4 3 2
輜 : 2
輥 : 2
適 : 4 3 2
遮 : 4 3 2
遨 : 2
遭 : 3 2
遷 : 4 3 2
鄰 : 4 2
鄭 : 4 3 2
鄧 : 3 2
鄱 : 2
醇 : 4 2
醉 : 7 4 3 2
醋 : 4 3 2
醃 : 3 2
鋅 : 3 2
銻 : 3
銷 : 4 3 2
銬 : 3 2
鋤 : 4 2
鋁 : 4 3 2
銳 : 4 2
鋒 : 4 2
鋇 : 2
閭 : 4
閱 : 4 3 2
霄 : 4 2
震 : 4 3 2
霉 : 3 2
靠 : 4 3 2
鞍 : 4 2
鞋 : 3 2
鞏 : 2
頜 : 2
颳 : 4 2
養 : 8 4 3 2
餓 : 8 4 3 2
餘 : 4 2
駝 : 3 2
駐 : 5 4 3 2
駟 : 4
駛 : 2
駑 : 4
駕 : 4 3 2
駒 : 4
駙 : 2
骷 : 2
髮 : 3 2
鬧 : 4 3 2
魅 : 3 2
魄 : 4 2
魷 : 2
魯 : 4 3 2
鴉 : 4 3 2
麩 : 3 2
麾 : 2
黎 : 4 3 2
墨 : 4 3 2
齒 : 4 3 2
儒 : 4 2
儘 : 4 2
冀 : 2
冪 : 2
凝 : 3 2
劑 : 4 3 2
勳 : 2
噹 : 2
噩 : 2
噤 : 4
噸 : 3 2
噪 : 2
器 : 4 3 2
噱 : 2
噬 : 4 3 2
壁 : 4 3 2
墾 : 2
壇 : 4 2
奮 : 4 3 2
學 : 5 4 3 2
寰 : 2
導 : 4 3 2
憲 : 4 3 2
憑 : 4 3 2
憩 : 2
憶 : 4 2
憾 : 2
懊 : 2
懈 : 2
戰 : 4 3 2
擅 : 4 2
擁 : 6 4 3 2
擋 : 3 2
撻 : 2
撼 : 4 2
據 : 7 6 5 4 3 2
擄 : 4 2
擇 : 4 2
擂 : 4 3 2
操 : 4 3 2
撿 : 3 2
擒 : 5 4 2
擔 : 4 3 2
整 : 6 4 3 2
曆 : 2
曉 : 4 2
曇 : 4 2
樸 : 6 4 2
樺 : 2
橙 : 3 2
橫 : 7 6 4 3 2
橘 : 3 2
樹 : 8 7 5 4 3 2
橄 : 3 2
橢 : 3 2
橡 : 4 3 2
橋 : 3 2
橇 : 2
樵 : 2
機 : 8 7 6 5 4 3 2
歙 : 4 2
歷 : 6 5 4 3 2
氅 : 2
澱 : 3 2
澡 : 4 3 2
濃 : 4 3 2
澤 : 4 2
濁 : 4 2
澳 : 5 4 3 2
激 : 5 4 3 2
澹 : 4
熾 : 2
燉 : 2
燒 : 4 3 2
燈 : 5 4 3 2
燕 : 4 3 2
燎 : 4 2
燙 : 3 2
燜 : 2
燃 : 5 4 3 2
獨 : 8 5 4 3 2
璞 : 4
瓢 : 4 3 2
瘴 : 2
瘸 : 2
盧 : 4 3 2
盥 : 4 3 2
瞠 : 4 2
瞞 : 5 4 2
瞟 : 3 2
瞥 : 2
磨 : 4 3 2
磚 : 3 2
禦 : 2
積 : 8 4 3 2
穎 : 4 2
穆 : 4 3 2
窺 : 4 3 2
築 : 4 3 2
篤 : 4 2
篡 : 3 2
篩 : 2
篦 : 2
糕 : 2
糖 : 4 3 2
縊 : 2
縈 : 2
縛 : 2
縣 : 4 3 2
縝 : 2
縉 : 2
縐 : 2
罹 : 2
羲 : 4
翰 : 2
翱 : 2
膳 : 3 2
膩 : 2
膨 : 3 2
臻 : 4
興 : 4 3 2
艙 : 2
蕊 : 2
蕙 : 4
蕩 : 4 3 2
蕃 : 3 2
蕉 : 2
蕭 : 4 3 2
蕪 : 2
螃 : 2
螟 : 2
螞 : 5 2
螢 : 4 3 2
融 : 4 3 2
衡 : 4 3 2
褪 : 4 2
褲 : 3 2
褥 : 2
褫 : 2
褡 : 2
親 : 4 3 2
諦 : 2
諺 : 2
諫 : 4 2
諱 : 4 2
謀 : 4 3 2
諜 : 3 2
諧 : 3 2
諮 : 4 2
諾 : 5 4 3 2
謁 : 2
謂 : 2
諷 : 4 3 2
諭 : 2
諳 : 2
豫 : 2
貓 : 4 3 2 1
賴 : 5 4 3 2
蹄 : 4 3 2
踱 : 2
踴 : 4 2
蹂 : 2
踵 : 4
輻 : 4 3 2
輯 : 2
輸 : 4 3 2
辨 : 4 3 2
辦 : 5 4 3 2
遵 : 4 3 2
遴 : 2
選 : 4 3 2
遲 : 4 3 2
遼 : 4 3 2
遺 : 4 3 2
醒 : 3 2
錠 : 3 2
錶 : 2
鋸 : 4 3 2
錳 : 2
錯 : 4 3 2
錢 : 4 3 2
鋼 : 5 4 3 2
錫 : 3 2
錄 : 4 3 2
錚 : 4 2
錐 : 4 3 2
錦 : 5 4 3 2
錙 : 4
閻 : 3 2
隧 : 2
隨 : 4 3 2
險 : 4 2
雕 : 4 3 2
霎 : 3 2
霍 : 3 2
霓 : 3 2
霏 : 2
靛 : 2
靜 : 8 4 3 2
靦 : 2
鞘 : 2
頰 : 2
頸 : 3 2
頻 : 4 3 2
頷 : 2
頭 : 8 4 3 2
頹 : 3 2
頤 : 4 3 2
餐 : 4 3 2
館 : 4 2
餞 : 4 2
餛 : 2
餡 : 3 2
駭 : 4 2
駢 : 4 2
駱 : 4 3 2
骸 : 2
骼 : 2
鮑 : 2
鴕 : 3 2
鴨 : 4 3 2 1
鴛 : 4 2
默 : 4 3 2
黔 : 4 3 2
龍 : 4 3 2
龜 : 4 3 2
優 : 4 3 2
償 : 2
儲 : 4 3 2
勵 : 4 2
嚎 : 2
嚇 : 3 2
嚏 : 2
壕 : 2
壓 : 4 3 2
嬰 : 3 2
嬪 : 2
嬤 : 2
孺 : 4 3 2
尷 : 2
屨 : 4
嶺 : 2
幫 : 4 3 2
彌 : 4 2
徽 : 2
應 : 5 4 3 2
懂 : 2
懇 : 3 2
懦 : 2
戲 : 3 2
戴 : 4 3 2
擎 : 4 2
擊 : 4 2
擘 : 4
擠 : 4 3 2
擰 : 5 3 2
擦 : 4 3 2
擬 : 4 3 2
擱 : 2
擢 : 4
斂 : 2
斃 : 4 2
曙 : 4 2
曖 : 2
檀 : 4 3 2
檔 : 4 3 2
檄 : 2
檢 : 4 3 2
櫛 : 4
檣 : 2
檠 : 4
氈 : 2
濱 : 3 2
濟 : 4 3 2
濠 : 2
濛 : 4 3 2
濤 : 2
濫 : 4 2
濯 : 4
澀 : 2
濡 : 4 2
濕 : 4 3 2
濮 : 4
濰 : 2
燧 : 3 2
營 : 7 4 3 2
燮 : 4
燦 : 4 2
燥 : 2
燭 : 4 2
爵 : 4 3 2
牆 : 7 6 5 4 3 2
獰 : 3 2
獲 : 4 3 2
環 : 9 5 4 3 2
璨 : 2
癆 : 2
療 : 4 3 2
癌 : 3 2
盪 : 2
瞳 : 2
瞪 : 4 3 2
瞰 : 2
瞬 : 4 3 2
瞧 : 3 2
瞭 : 4 3 2
矯 : 4 3 2
磷 : 3 2
磺 : 3 2
磯 : 2
礁 : 2
禪 : 2
穗 : 2
簇 : 4 2
簍 : 2
篾 : 2
篷 : 4 3 2
簌 : 2
糠 : 2
糜 : 2
糞 : 3 2
糟 : 7 4 2
糙 : 2
縮 : 4 3 2
績 : 4 2
繆 : 4 2
縷 : 3 2
繃 : 3 2
縫 : 4 3 2
總 : 4 3 2
縱 : 4 3 2
繅 : 2
繁 : 4 3 2
縴 : 2
縹 : 2
罄 : 4
翼 : 4 3 2
聲 : 4 3 2
聰 : 4 3 2
聯 : 5 4 3 2
聳 : 4 2
臆 : 3 2
臃 : 2
膺 : 2
臂 : 2
臀 : 2
膿 : 3 2
膽 : 4 3 2
臉 : 5 3 2
膾 : 4
臨 : 5 4 3 2
舉 : 4 3 2
艱 : 4 3 2
薪 : 4 3 2
薄 : 4 3 2
蕾 : 2
薑 : 2
薔 : 3 2
薯 : 2
薊 : 2
虧 : 4 3 2
蟑 : 2
螳 : 8 4 2
蟒 : 2
螫 : 2
螻 : 2
螺 : 5 3 2
蟈 : 2
蟋 : 2
褻 : 3 2
褶 : 2
襄 : 2
覬 : 4 2
謎 : 3 2
謙 : 6 4 2
講 : 4 3 2
謊 : 2
謠 : 2
謝 : 4 3 2
謄 : 2
豁 : 4 3 2
賺 : 3 2
賽 : 5 4 3 2
購 : 4 3 2
賸 : 5 4 3 2
趨 : 4 3 2
蹉 : 4 2
蹈 : 4 2
蹊 : 4 2
轄 : 2
輾 : 4 3 2
轂 : 4 2
轅 : 2
輿 : 4 3 2
避 : 8 6 4 3 2
遽 : 2
還 : 6 4 3 2
邁 : 4 3 2
邂 : 4 2
邀 : 4 3 2
醞 : 2
醜 : 4 3 2
鍍 : 3 2
鎂 : 3 2
錨 : 3 2
鍵 : 2
鍊 : 4 3 2
鍥 : 4
鍋 : 3 2
錘 : 2
鍾 : 3 2
鍛 : 4 3 2
闊 : 4 3 2
闌 : 3 2
隱 : 4 3 2
隸 : 3 2
雖 : 4 3 2
霜 : 4 2
霞 : 2
鞠 : 8 4 2
韓 : 4 3 2
顆 : 3 2
颶 : 2
餵 : 2
騁 : 2
駿 : 2
鮮 : 4 3 2
鮭 : 2
鴻 : 4 2
鴿 : 2
麋 : 4 2
黏 : 3 2
點 : 4 3 2
黜 : 4 2
黝 : 2
黛 : 2
鼾 : 2
齋 : 4 2
叢 : 3 2
嚕 : 2
嚮 : 2
壘 : 2
嬸 : 2
彝 : 2
戳 : 2
擴 : 5 4 3 2
擲 : 6 4 3 2
擾 : 3 2
攆 : 2
擺 : 6 4 3 2
擷 : 2
斷 : 4 3 2
朦 : 2
檳 : 3 2
檬 : 2
櫃 : 6 4 2
檻 : 4
檸 : 3 2
檯 : 2
歸 : 4 3 2
殯 : 3 2
瀉 : 2
瀋 : 4 3 2
濾 : 3 2
瀆 : 3 2
濺 : 3 2
瀑 : 2
瀏 : 3 2
燻 : 3 2
獷 : 2
獵 : 3 2
璧 : 4
甕 : 4
癖 : 2
癒 : 2
瞽 : 4
瞻 : 4 2
禮 : 6 5 4 3 2
穢 : 2
竄 : 2
竅 : 2
簫 : 4
簧 : 2
簪 : 4
簞 : 4
簡 : 5 4 3 2
糧 : 4 3 2
織 : 4 3 2
繕 : 4
繞 : 4 3 2
繚 : 2
繡 : 4 2
罈 : 2
翹 : 4 3 2
翻 : 7 4 3 2
職 : 6 4 3 2
聶 : 2
臍 : 2
舊 : 7 5 4 3 2
藏 : 4 3 2
薩 : 7 5 4 3 2
藍 : 4 3 2
藐 : 2
藉 : 4 2
薰 : 2
薦 : 2
蟯 : 2
蟬 : 3 2
蟲 : 4 2
蟠 : 2
覆 : 5 4 3 2
謹 : 4 2
謬 : 4 2
謫 : 2
豐 : 4 3 2
贅 : 3 2
蹙 : 4 2
蹣 : 4 2
蹦 : 4 2
蹤 : 4 2
軀 : 2
轉 : 5 4 3 2
轍 : 4 2
邈 : 4
醫 : 5 4 3 2
醬 : 2
釐 : 2
鎖 : 2
鎢 : 3 2
鎳 : 4 3 2
鎮 : 4 3 2
鎬 : 2
闖 : 3 2
闕 : 2
離 : 6 5 4 3 2
雜 : 4 3 2
雙 : 8 4 3 2
雛 : 4 3 2
雞 : 4 3 2 1
鞣 : 3 2
鞦 : 2
鞭 : 4 3 2
額 : 4 3 2
顏 : 4 3 2
題 : 3 2
顎 : 2
餿 : 2
餮 : 2
馥 : 2
騎 : 4 3 2
鬃 : 2
鬆 : 4 3 2
魏 : 4 3 2
魍 : 2
鯊 : 3 2
鯉 : 2
鯽 : 2
鵝 : 4 3 2
鵠 : 4
鼬 : 2
嚥 : 2
壞 : 5 4 3 2
壟 : 4 3 2
寵 : 4 3 2
龐 : 4 2
廬 : 5 4 2
懲 : 4 3 2
懷 : 4 3 2
懶 : 4 3 2
懵 : 2
攀 : 4 3 2
攏 : 2
曠 : 4 2
曝 : 4 2
櫥 : 2
櫚 : 2
瀛 : 2
瀟 : 4 2
瀨 : 2
瀚 : 2
瀝 : 4 2
瀕 : 4 2
瀘 : 2
爆 : 5 4 3 2
爍 : 4 2
犢 : 2
獸 : 4 3 2
獺 : 2
瓊 : 4 3 2
瓣 : 2
疇 : 4 2
疆 : 2
癟 : 2
癡 : 7 4 3 2
矇 : 4 2
礙 : 4 2
禱 : 2
穩 : 5 4 3 2
簾 : 3 2
簿 : 3 2
簸 : 2
簽 : 3 2
簷 : 2
繫 : 4 2
繭 : 4 2
繹 : 4 2
繩 : 4 2
繪 : 4 3 2
羅 : 5 4 3 2
繳 : 4 2
羹 : 2
臘 : 3 2
藩 : 2
藝 : 4 3 2
藕 : 4 2
藤 : 4 2
藥 : 4 3 2
蟻 : 4 3 2
蠅 : 4 2
蠍 : 2
蟹 : 4 2
蟾 : 4 3 2
襟 : 4 2
襞 : 2
譁 : 4
譜 : 2
識 : 7 4 3 2
證 : 9 7 5 4 3 2
譚 : 4
譎 : 4
譏 : 3 2
贈 : 3 2
贊 : 4 3 2
蹼 : 2
蹲 : 2
躇 : 2
蹬 : 2
蹺 : 4 3 2
蹴 : 2
轎 : 4 2
辭 : 4 3 2
邊 : 4 3 2
邋 : 2
鏡 : 4 2
鏟 : 2
鏈 : 2
鏜 : 2
鏖 : 2
鏢 : 2
鏘 : 2
鏤 : 4 2
鏗 : 3 2
鏨 : 2
關 : 6 5 4 3 2
隴 : 4 2
難 : 5 4 3 2
霧 : 4 3 2
靡 : 8 4 2
韜 : 4 2
韻 : 3 2
類 : 5 4 3 2
願 : 4 3 2
顛 : 4 3 2
颼 : 3 2
饅 : 2
騙 : 4 2
鬍 : 7 2
鯨 : 4 2
鯧 : 2
鶉 : 4
鵲 : 4 2
鵪 : 2
鵬 : 4 2
麒 : 2
麗 : 4 3 2
勸 : 4 3 2
嚷 : 2
嚶 : 4 2
嚴 : 4 3 2
嚼 : 4 2
壤 : 2
孀 : 2
孽 : 2
寶 : 4 3 2
懸 : 6 4 3 2
懺 : 3 2
攘 : 4 2
攔 : 4 3 2
攙 : 4 3 2
朧 : 2
瀾 : 3 2
瀰 : 2
爐 : 4 2
獻 : 4 3 2
癢 : 3 2
癥 : 2
礦 : 4 3 2
礪 : 4
礬 : 2
礫 : 2
竇 : 2
競 : 4 3 2
籌 : 4 3 2
籃 : 3 2
籍 : 4 2
糯 : 2
糰 : 2
辮 : 2
繽 : 2
繼 : 4 3 2
纂 : 2
罌 : 3 2
耀 : 4 2
艦 : 4 2
藻 : 3 2
藹 : 2
蘑 : 2
蘆 : 3 2
蘋 : 4 3 2
蘇 : 7 4 3 2
蘊 : 4 3 2
蠕 : 3 2
襤 : 2
覺 : 2
觸 : 4 3 2
議 : 4 3 2
譬 : 2
警 : 5 4 3 2
譯 : 3 2
贏 : 2
贍 : 3 2
躉 : 6 2
躁 : 3 2
醴 : 2
釋 : 4 3 2
鐘 : 4 3 2
闡 : 2
飄 : 4 3 2
饒 : 4 3 2
饑 : 4 3 2
馨 : 4 2
騰 : 4 2
騷 : 4 3 2
鰓 : 4
鹹 : 3 2
麵 : 3 2
黨 : 5 4 3 2
鼯 : 2
齟 : 4 2
囁 : 2
囂 : 4 2
夔 : 4
屬 : 4 3 2
巍 : 4 2
懼 : 2
懾 : 2
攝 : 5 4 3 2
攜 : 4 3 2
櫻 : 5 4 3 2
欄 : 2
殲 : 4 3 2
灌 : 4 3 2
爛 : 4 3 2
犧 : 3 2
癩 : 8 3 2
籐 : 2
纏 : 4 3 2
續 : 3 2
蘭 : 4 3 2
蠣 : 2
蠢 : 4 2
蠟 : 4 3 2
襪 : 2
覽 : 2
譴 : 2
護 : 4 3 2
譽 : 4 2
贓 : 4 2
躊 : 4 2
躍 : 4 2
躋 : 3 2
轟 : 4 3 2
辯 : 6 5 4 3 2
醺 : 2
鐮 : 2
鐳 : 3 2
鐵 : 5 4 3 2
鐺 : 2
鐲 : 2
鐫 : 4 2
闢 : 4 2
霸 : 4 2
霹 : 5 4 2
露 : 4 3 2
響 : 4 3 2
顧 : 6 5 4 3 2
饗 : 2
驅 : 4 3 2
驃 : 2
驀 : 2
騾 : 2
魔 : 3 2
魑 : 4 2
鰭 : 3 2
鰥 : 4 2
鶯 : 4 3 2
鶴 : 4 2
麝 : 2
黯 : 4 2
齜 : 4 2
儼 : 2
儻 : 4
囈 : 2
囊 : 4 2
囉 : 4 2
孿 : 4 2
巔 : 2
彎 : 4 3 2
攤 : 3 2
權 : 4 3 2
歡 : 5 4 3 2
灑 : 3 2
灘 : 3 2
疊 : 4 3 2
癮 : 3
癬 : 4 2
禳 : 2
籠 : 4 2
聾 : 3 2
聽 : 8 7 4 3 2
臟 : 2
襲 : 4 3 2
襯 : 2
讀 : 4 3 2
贖 : 2
贗 : 2
躑 : 2
酈 : 4
鑄 : 4 3 2
鑑 : 2
鑒 : 5 4 3 2
霽 : 4
韃 : 3 2
韁 : 2
顫 : 4 3 2
饕 : 4 3 2
驕 : 4 2
驍 : 2
髒 : 3 2
鬚 : 4 2
鱉 : 2
鰱 : 2
鰻 : 2
鷓 : 2
鷗 : 2
鼴 : 2
龔 : 4
巖 : 4 3 2
戀 : 4 2
攣 : 2
攫 : 4 2
攪 : 4 3 2
曬 : 3 2
竊 : 4 3 2
籤 : 2
纓 : 2
纖 : 4 3 2
蘸 : 2
蘿 : 4 3 2
蠱 : 4 2
變 : 6 5 4 3 2
邏 : 4 3 2
鑠 : 4
顯 : 4 3 2
驚 : 4 3 2
驛 : 2
驗 : 4 3 2
髓 : 2
體 : 5 4 3 2
鱔 : 2
鱗 : 4 3 2
鱖 : 2
麟 : 4 3
黴 : 3 2
囑 : 2
壩 : 2
攬 : 4 2
癱 : 2
癲 : 2
矗 : 2
罐 : 4 3 2
羈 : 2
蠶 : 4 3 2
蠹 : 4
衢 : 2
讓 : 8 5 4 3 2
讒 : 4 2
讖 : 2
艷 : 4 2
贛 : 2
釀 : 4 3 2
靂 : 2
靈 : 4 3 2
顰 : 2
驟 : 4 2
鬢 : 4 2
鷹 : 4 3 2
鷺 : 2
鹼 : 4 3 2
鹽 : 3 2
齷 : 2
齲 : 2
廳 : 3 2
灣 : 2
籬 : 5 4 2
籮 : 2
蠻 : 4 2
觀 : 4 3 2
躡 : 4 2
釁 : 4
鑲 : 3 2
鑰 : 3 2
顱 : 2
饞 : 4 2
髖 : 2
矚 : 2
讚 : 4 3 2
鑷 : 2
驢 : 6 4 2
驥 : 4
纜 : 3 2
讜 : 4
鑽 : 4 3 2
鑼 : 4 2
鱷 : 4 3 2
鱸 : 2
黷 : 4 2
鑿 : 4 3 2
鸚 : 4 3 2
鬱 : 4 3 2
鸞 : 4 2
籲 : 2
�B : 4
�� : 2
�� : 2
囗 : 2
夯 : 4 2
尻 : 4
伎 : 2
伢 : 2
囡 : 2
奼 : 4
扦 : 2
旮 : 2
氘 : 2
汜 : 2
佤 : 2
坌 : 4
夆 : 4
忐 : 4 2
忡 : 2
忤 : 4
忻 : 4
旰 : 4
沏 : 2
汩 : 2
疔 : 2
芎 : 3
芊 : 2
佼 : 2
佶 : 4 2
侄 : 3 2
侗 : 2
侔 : 4
冼 : 2
咂 : 4 2
呤 : 2
囹 : 2
坯 : 2
孢 : 3 2
怦 : 2
怙 : 4
昃 : 4
枘 : 4
沓 : 2
泫 : 2
泔 : 2
炔 : 2
狒 : 2
矸 : 2
邯 : 4 2
邰 : 3
剉 : 2
厘 : 3 2
哆 : 4 2
呲 : 2
垛 : 2
峇 : 3
恂 : 4
挎 : 2
昶 : 4
枷 : 2
枵 : 4
洄 : 2
炷 : 2
砒 : 2
紈 : 4
耷 : 2
苫 : 4 2
倜 : 4 2
悒 : 4
捅 : 4 3 2
挹 : 4
捋 : 4 2
桉 : 2
桎 : 2
浣 : 2
珥 : 4
祛 : 4 2
秭 : 2
笊 : 2
茭 : 2
茜 : 2
茯 : 2
茬 : 2
蚍 : 5 4 2
蚝 : 2
衾 : 4
豇 : 2
陟 : 4
啐 : 2
啥 : 2
埴 : 2
庹 : 3
悱 : 2
掂 : 4 2
掎 : 4
掇 : 4 2
掐 : 4 2
捭 : 4 2
桴 : 4
烷 : 2
烴 : 2
猝 : 2
猞 : 2
硌 : 2
硅 : 3 2
秸 : 2
笤 : 2
笸 : 2
粘 : 4 3 2
羝 : 4
脛 : 2
舳 : 4
趿 : 2
逋 : 4
郴 : 2
酚 : 4 2
釬 : 2
傣 : 2
喑 : 4
婺 : 2
崽 : 2
掰 : 2
揎 : 4
揠 : 4
揶 : 2
氰 : 3 2
猢 : 2
痧 : 2
痤 : 2
硭 : 2
菏 : 2
莿 : 3 2
菖 : 2
詘 : 4
詒 : 4
鈦 : 3
僂 : 2
嗝 : 2
嗔 : 2
嗄 : 2
嗩 : 2
嗒 : 2
嗖 : 2
嵊 : 2
嵬 : 4
徭 : 2
搠 : 4
搦 : 4
摁 : 2
摀 : 2
椿 : 4 2
椽 : 2
椴 : 2
歃 : 4
滁 : 2
煢 : 4
煸 : 2
痼 : 2
睚 : 4
稗 : 4 2
筱 : 2
粲 : 4
綆 : 4
羥 : 2
羧 : 2
艄 : 2
葑 : 4
觥 : 4
誆 : 4 2
趑 : 4
趔 : 2
跬 : 4
跣 : 4
跫 : 4
遒 : 4 2
酯 : 2
鈺 : 4
鉬 : 2
鳧 : 4 2
僳 : 2
嘧 : 2
嘁 : 4
嫠 : 4
慪 : 2
摶 : 4
摳 : 4 2
撂 : 3 2
槙 : 4
殞 : 4 2
漉 : 2
漚 : 2
漭 : 2
熏 : 4 3 2
瘊 : 2
皸 : 2
瞅 : 2
碲 : 3
碴 : 2
碭 : 2
箍 : 2
箅 : 2
粼 : 2
緋 : 4 2
蒺 : 2
蒹 : 4
蓖 : 2
蜚 : 4 2
裱 : 3 2
裾 : 4
踉 : 4 2
銥 : 3 2
儆 : 2
噁 : 2
噘 : 2
嶗 : 2
憋 : 2
撅 : 2
撣 : 2
樗 : 4
澇 : 2
潢 : 4
熠 : 2
熵 : 2
獠 : 2
瘞 : 4
瘙 : 2
糌 : 2
羰 : 2
舖 : 4 3 2
蔻 : 2
蓽 : 4
踮 : 3 2
踔 : 4
鋃 : 4 2
鋌 : 4
靚 : 2
餑 : 2
鴇 : 2
噠 : 2
憨 : 4 2
擗 : 4
殫 : 4
燁 : 4
燔 : 4
篝 : 4 2
蕁 : 3 2
蕎 : 3 2
螓 : 4
諠 : 2
諢 : 2
謔 : 2
諤 : 4
踽 : 4 2
蹁 : 2
醍 : 4
鍺 : 2
錸 : 4
錩 : 4
閾 : 2
閹 : 3 2
鴟 : 4
幪 : 2
懨 : 2
擯 : 2
檁 : 2
殭 : 2
璐 : 2
甑 : 4
癉 : 4
篳 : 4
膻 : 2
薏 : 4 2
薈 : 2
蟄 : 2
蟊 : 2
襁 : 2
觳 : 4
謇 : 4
蹇 : 4
醚 : 3 2
醛 : 2
鍘 : 2
闇 : 2
黿 : 4
嚙 : 4 2
攄 : 4
燿 : 4
癤 : 2
簦 : 2
蟣 : 2
謳 : 2
謾 : 5 4 3 2
蹩 : 2
轆 : 2
鎧 : 2
隳 : 4
騏 : 4
騍 : 2
髀 : 4
鬈 : 2
嚦 : 2
韞 : 4
饃 : 2
鯪 : 2
鯤 : 2
鯰 : 2
獼 : 5 3 2
矍 : 2
蘄 : 2
蠑 : 2
蠖 : 4
鐐 : 2
饌 : 4
饋 : 2
齠 : 4
齙 : 2
巋 : 4 2
攛 : 4 2
纈 : 2
纍 : 2
飆 : 4 2
鰣 : 2
孌 : 4
攢 : 4 2
饔 : 4
鬻 : 4
鰲 : 4 2
龕 : 2
攥 : 2
鱒 : 2
鷸 : 4
讕 : 2
囔 : 2
躥 : 4
顴 : 2
鸝 : 2
�� : 2
__END_OF_WLen__
３ Ｄ 動 畫	Ａ Ｂ Ｓ	Ａ Ｃ 米 蘭	Ａ Ｄ Ｂ	Ａ Ｄ Ｒ	Ｂ ２ Ｂ	Ｂ ２ Ｃ	Ｂ Ｏ Ｔ	
Ｂ 肝	Ｂ 型 肝 炎	Ｃ Ｐ Ｉ	Ｃ Ｐ Ｕ	Ｃ Ｔ ２	Ｄ Ｄ Ｒ	Ｄ Ｈ Ｌ	Ｄ Ｊ	
Ｄ Ｎ Ａ	Ｄ Ｎ Ａ 比 對	Ｄ Ｒ Ａ Ｍ	Ｅ Ｃ	Ｇ Ｄ Ｒ	Ｇ 八	Ｈ Ｄ Ｐ Ｅ	Ｉ Ｂ Ｍ	
Ｉ Ｃ	Ｉ Ｅ Ａ	Ｉ Ｍ Ｆ	Ｉ Ｓ Ｐ	Ｌ Ｃ Ｄ	Ｌ Ｅ Ｄ	Ｎ Ｂ Ａ	Ｎ Ｃ Ａ Ａ	
Ｎ Ｆ Ｌ	Ｐ Ｃ Ｂ	Ｐ Ｄ Ａ	Ｓ Ｅ Ｇ Ａ	Ｓ Ｋ Ⅱ	Ｓ Ｍ	Ｓ Ｏ Ｓ	Ｔ Ｌ Ｃ	
Ｔ Ｍ Ｄ	Ｔ 恤	Ｕ Ｐ Ｓ	Ｗ Ｔ Ｏ	Ｘ 光	Ｙ ２ Ｋ	一 一	一 丁 不 視	
一 九	一 九 九 Ｏ	一 九 九 一	一 九 九 七	一 九 九 二	一 九 九 六	一 九 八 七	一 九 八 八	
一 了 千 明	一 了 百 了	一 了 百 當	一 二	一 二 十 年	一 人	一 人 之 下	一 人 之 交	
一 人 做 事 一 人 當	一 人 得 道 雞 犬 升 天	一 人 傳 虛 萬 人 傳 實	一 刀	一 刀 切	一 刀 兩 段	一 刀 兩 斷	一 力 承 當	
一 下	一 下 子	一 千	一 千 年	一 千 個	一 千 萬	一 口	一 口 吸 盡 西 江 水	
一 口 兩 匙	一 口 咬 定	一 口 氣	一 大	一 大 二 公	一 大 半	一 大 早	一 大 批	
一 大 步	一 大 陣	一 大 堆	一 大 群	一 大 幫	一 女	一 女 中	一 寸	
一 寸 丹 心	一 寸 光 陰 一 寸 金	一 寸 赤 心	一 小 口	一 小 時	一 小 群	一 小 撮	一 己	
一 己 之 私	一 己 之 見	一 干	一 干 一 方	一 不 做 二 不 休	一 中 全 會	一 之 已 甚	一 之 為 甚	
一 之 謂 甚	一 五 一 十	一 仍 舊 貫	一 介	一 介 不 取	一 元	一 元 化	一 元 方 程	
一 元 論	一 分	一 分 子	一 分 為 二	一 分 錢	一 分 鐘	一 切	一 切 向 錢 看	
一 切 事	一 切 從 嚴	一 切 眾 生	一 匹	一 反	一 反 常 態	一 天	一 天 到 晚	
一 天 星 斗	一 夫	一 夫 一 妻 制	一 夫 制	一 夫 當 關 萬 夫 莫 開	一 孔	一 孔 之 見	一 尺	
一 巴 掌	一 心	一 心 一 計	一 心 一 意	一 心 一 德	一 心 掛 兩 頭	一 心 無 二	一 戶	
一 手	一 手 一 足	一 手 包 辦	一 手 包 攬	一 手 寬	一 手 遮 天	一 支	一 文	
一 文 不 名	一 文 不 值	一 文 如 命	一 文 錢 難 倒 英 雄 漢	一 斗	一 斤	一 方	一 方 有 難 八 方 支 援	
一 方 面	一 日	一 日 三 秋	一 日 三 餐	一 日 千 里	一 日 不 見 如 隔 三 秋	一 日 之 長	一 日 之 雅	
一 日 萬 機	一 月	一 月 份	一 木 難 支	一 木 難 扶	一 比	一 毛 不 拔	一 毛 錢	
一 片	一 片 丹 心	一 片 冰 心	一 片 至 誠	一 片 汪 洋	一 片 赤 心	一 片 宮 商	一 片 散 沙	
一 牛 吼 地	一 世	一 世 之 雄	一 世 紀	一 丘 一 壑	一 丘 之 貉	一 以 貫 之	一 以 當 十	
一 代	一 代 人	一 代 宗 臣	一 代 風 流	一 代 新 人	一 代 楷 模	一 代 鼎 臣	一 冊	
一 出	一 包	一 半	一 半 兒	一 去	一 去 不 復 返	一 古 腦 兒	一 叫	
一 台	一 句	一 句 話	一 失 足 成 千 古 恨	一 市	一 平 二 調	一 打	一 扔	
一 旦	一 本	一 本 正 經	一 本 萬 利	一 民 同 俗	一 犯 再 犯	一 生	一 生 中	
一 目 十 行	一 目 瞭 然	一 石 二 鳥	一 件	一 件 式	一 任	一 份	一 兆	
一 共	一 再	一 再 強 調	一 再 說 明	一 列	一 匡 天 下	一 同	一 吐	
一 吐 為 快	一 向	一 名	一 回	一 回 事	一 地	一 地 方	一 在	
一 如	一 如 既 往	一 字	一 字 一 板	一 字 一 珠	一 字 一 淚	一 字 千 金	一 字 不 苟	
一 字 不 識	一 字 之 師	一 字 長 蛇 陣	一 字 值 千 金	一 字 褒 貶	一 帆 風 順	一 年	一 年 一 次	
一 年 一 度	一 年 之 計 在 於 春	一 年 比 一 年	一 年 半 載	一 年 四 季	一 年 多 來	一 年 兩 次	一 年 到 尾	
一 年 到 頭	一 年 被 蛇 咬	一 式	一 成	一 成 一 旅	一 成 不 變	一 早	一 曲	
一 曲 陽 關	一 朵	一 次	一 次 又 一 次	一 次 方 程	一 次 性	一 死 一 生	一 死 百 了	
一 百	一 百 二 十 行	一 百 年	一 百 萬	一 而 再	一 而 再 再 而 三	一 而 再 地	一 至 於 此	
一 色	一 行	一 行 人	一 行 作 吏	一 行 詩	一 衣 帶 水	一 串	一 位	
一 佛 出 世 二 佛 升 天	一 兵	一 冷	一 吹	一 吸	一 局	一 床 兩 好	一 床 錦 被 遮 蓋	
一 忍 再 忍	一 抖	一 技 之 長	一 把	一 把 手	一 把 汗	一 把 抓	一 批	
一 折	一 改 故 轍	一 束	一 步	一 步 一 個 腳 印	一 步 一 鬼	一 步 一 趨	一 步 到 位	
一 步 登 天	一 決 勝 負	一 決 雌 雄	一 沐 三 捉 發	一 系 列	一 肚 子 氣	一 見	一 見 如 故	
一 見 傾 心	一 見 鍾 情	一 角	一 言	一 言 一 行	一 言 一 動	一 言 九 鼎	一 言 千 金	
一 言 不 發	一 言 中 的	一 言 以 蔽	一 言 以 蔽 之	一 言 半 句	一 言 半 字	一 言 半 語	一 言 而 定	
一 言 抄 百 總	一 言 兩 語	一 言 定 交	一 言 既 出 駟 馬 難 追	一 言 為 定	一 言 訂 交	一 言 堂	一 言 喪 邦	
一 言 蔽 之	一 言 興 邦	一 言 難 盡	一 言 難 罄	一 走	一 身	一 身 二 任	一 身 作 事 一 人 當	
一 身 兩 役	一 身 是 膽	一 車	一 事	一 事 無 成	一 些	一 些 人	一 些 單 位	
一 依 舊 式	一 例	一 來	一 來 一 往	一 來 二 去	一 併	一 併 處 理	一 兩 句 話	
一 刻	一 刻 千 金	一 刻 鐘	一 到	一 卷	一 卷 布	一 味	一 呼 百 諾	
一 呼 百 應	一 命 嗚 呼	一 夜	一 夜 之 間	一 夜 夫 妻 百 日 恩	一 夜 夫 妻 百 夜 恩	一 夜 被 蛇 咬	一 妻	
一 妻 制	一 季	一 季 度	一 定	一 定 不 易	一 定 不 移	一 定 之 規	一 定 程 度	
一 定 量	一 官 半 職	一 屆	一 往	一 往 情 深	一 往 無 前	一 忽	一 忽 兒	
一 念	一 念 之 差	一 念 之 錯	一 怔	一 拉	一 抹	一 招	一 拐	
一 拍	一 拍 即 合	一 拍 兩 散	一 拖	一 服	一 枕 黃 粱	一 杯	一 杯 奶	
一 杯 湯	一 板 一 眼	一 板 三 眼	一 板 正 經	一 枚	一 波 三 折	一 波 未 平 一 波 又 起	一 物	
一 物 一 主	一 物 一 制	一 物 不 知	一 物 降 一 物	一 狐 之 腋	一 直	一 知 半 解	一 空	
一 者	一 股	一 花 獨 放	一 虎 難 敵 眾 犬	一 表 人 才	一 表 人 材	一 表 人 物	一 表 非 凡	
一 表 非 俗	一 長 一 短	一 長 半 短	一 長 制	一 門	一 門 心 思	一 亮	一 便	
一 剎 那	一 前 一 後	一 則	一 則 以 喜 一 則 以 懼	一 勇 之 夫	一 哄 而 上	一 哄 而 起	一 哄 而 散	
一 客 不 犯 二 主	一 封	一 封 信	一 屋	一 度	一 律	一 怒 之 下	一 按	
一 拽	一 指	一 是	一 星 半 點	一 星 期	一 柱 擎 天	一 架	一 段	
一 段 時 間	一 流	一 派	一 炮	一 炮 打 響	一 盅	一 相 情 願	一 看	
一 砍 二 主	一 砍 二 家	一 秒	一 胎	一 致	一 致 百 慮	一 致 性	一 致 通 過	
一 致 意 見	一 致 認 為	一 軌 同 風	一 迭 連 聲	一 面	一 面 之 交	一 面 之 詞	一 面 之 雅	
一 面 之 緣	一 面 之 識	一 面 之 辭	一 面 如 舊	一 音	一 音 節	一 頁	一 風 吹	
一 飛 沖 天	一 首	一 倍	一 倡 三 歎	一 倡 百 和	一 個	一 個 又 一 個	一 個 中 心	
一 個 勁 兒	一 個 國 家 兩 種 制 度	一 個 樣	一 准	一 員	一 套	一 家	一 家 一 計	
一 家 人	一 家 之 言	一 家 之 說	一 家 之 論	一 家 老 小	一 家 眷 屬	一 展	一 島	
一 差 二 誤	一 差 二 錯	一 席 之 地	一 席 話	一 席 談	一 座	一 座 皆 驚	一 息 奄 奄	
一 息 尚 存	一 拳	一 捆	一 旁	一 時	一 時 一 事	一 時 一 刻	一 時 之 秀	
一 時 之 選	一 時 半 刻	一 時 間	一 晃	一 書	一 桌	一 格	一 株	
一 氣	一 氣 之 下	一 氣 呵 成	一 氧	一 氧 化 碳	一 浪	一 班	一 病 不 起	
一 眨	一 眨 眼	一 眨 眼 間	一 砸	一 神	一 神 教	一 神 論	一 笑	
一 笑 千 金	一 笑 置 之	一 索 成 男	一 索 得 男	一 級	一 級 企 業	一 紙 空 文	一 脈 相 承	
一 脈 相 通	一 脈 相 傳	一 般	一 般 人	一 般 化	一 般 比	一 般 以	一 般 用	
一 般 地 說	一 般 地 講	一 般 而 言	一 般 見 識	一 般 來 說	一 般 性	一 般 的 說	一 般 指	
一 般 疾 病	一 般 無 二	一 般 等 價 物	一 般 說 來	一 般 應	一 般 竊 盜	一 草 一 木	一 起	
一 起 上	一 起 抓	一 退 六 二 五	一 針	一 針 見 血	一 閃	一 閃 而 過	一 院	
一 陣	一 陣 子	一 陣 風	一 陣 煙	一 隻	一 隻 眼	一 馬	一 馬 一 鞍	
一 馬 平 川	一 馬 當 先	一 骨 碌	一 乾 二 淨	一 停	一 側	一 偏 之 見	一 副	
一 動	一 動 不 如 一 靜	一 動 不 動	一 區	一 唱 一 和	一 問	一 圈	一 國 三 公	
一 國 兩 制	一 堆	一 堆 沙	一 堂	一 堵	一 專 多 能	一 將 功 成 萬 骨 枯	一 帶	
一 張	一 張 一 弛	一 張 一 馳	一 得	一 得 之 功	一 得 之 見	一 得 之 愚	一 探	
一 掃	一 掃 而 空	一 推	一 排	一 排 排	一 敗 如 水	一 敗 塗 地	一 族	
一 晝 夜	一 望	一 望 而 知	一 望 無 際	一 桶	一 桶 水	一 條	一 條 心	
一 條 街	一 條 龍	一 毫	一 清 二 白	一 清 二 楚	一 清 如 水	一 清 早	一 瓶	
一 盒	一 眼	一 眼 見 得	一 粒	一 粒 砂	一 統	一 組	一 組 人	
一 處	一 袋	一 貫	一 貫 方 針	一 貫 性	一 貫 道	一 貧 如 洗	一 通 百 通	
一 連	一 連 串	一 部	一 部 分	一 章	一 頂	一 傅 眾 咻	一 勞 久 逸	
一 勞 永 逸	一 場	一 場 空	一 場 春 夢	一 場 虛 驚	一 壺	一 壺 千 金	一 寒 如 此	
一 尊	一 幅	一 帽 子	一 廂 情 願	一 悲 一 喜	一 愣	一 提	一 揮 而 成	
一 揮 而 就	一 斑	一 景	一 期	一 朝	一 朝 一 夕	一 朝 被 蛇 咬	一 朝 權 在 手	
一 棒 一 條 痕	一 棲 兩 雄	一 棍 打 一 船	一 無	一 無 可 取	一 無 忌 憚	一 無 所 好	一 無 所 成	
一 無 所 有	一 無 所 求	一 無 所 知	一 無 所 能	一 無 所 得	一 無 所 獲	一 無 長 物	一 無 是 處	
一 琴 一 鶴	一 番	一 番 話	一 發	一 發 千 鈞	一 程	一 等	一 等 功	
一 等 品	一 等 獎	一 筆	一 筆 不 苟	一 筆 勾 銷	一 筆 抹 倒	一 筆 抹 殺	一 筆 抹 煞	
一 絕	一 絲	一 絲 一 毫	一 絲 不 苟	一 絲 不 掛	一 絲 不 線 單 木 不 林	一 腔 熱 血	一 著	
一 著 不 慎 滿 盤 皆 輸	一 視 同 仁	一 詠 一 觴	一 週	一 進	一 間	一 隊	一 階 半 級	
一 階 半 職	一 隅	一 隅 三 反	一 隅 之 地	一 集	一 項	一 順 兒	一 飯 千 金	
一 飲	一 傳 十	一 塌 刮 子	一 塌 糊 塗	一 塊	一 塊 兒	一 塊 糖	一 塊 錢	
一 廉 如 水	一 意	一 意 孤 行	一 想	一 搭 一 檔	一 搏	一 新	一 會	
一 會 兒	一 概	一 概 而 言	一 概 而 論	一 歲	一 歲 九 遷	一 歲 三 遷	一 滑	
一 溜 煙	一 溜 煙 兒	一 盞	一 睹 為 快	一 碰	一 碗	一 萬	一 節	
一 節 課	一 經	一 群	一 群 人	一 群 牛	一 群 羊	一 腳	一 落 千 丈	
一 葉	一 葉 知 秋	一 葉 落 知 天 下 秋	一 葉 障 目 不 見 泰 山	一 葉 蔽 目	一 葉 蔽 目 不 見 泰 山	一 號	一 詮 精 密	
一 路	一 路 上	一 路 平 安	一 路 發	一 路 順 風	一 路 福 星	一 路 領 先	一 跳	
一 道	一 道 菜	一 遍	一 酬 一 酢	一 頓	一 頓 飯	一 鼓 而 下	一 鼓 作 氣	
一 劃	一 團	一 團 和 氣	一 團 漆 黑	一 團 糟	一 團 糟 攤 子	一 塵 不 染	一 夥	
一 夥 人	一 夥 兒	一 奪	一 對	一 對 一	一 對 多	一 幕	一 撇	
一 摔	一 榻 糊 塗	一 槍	一 滴	一 滴 水	一 滿 匙	一 滿 碗	一 碟	
一 種	一 窩	一 窩 蜂	一 端	一 算	一 網 打 盡	一 聚 枯 骨	一 語	
一 語 中 人	一 語 破 的	一 語 道 破	一 語 雙 關	一 誤 再 誤	一 說	一 貌 堂 堂	一 貌 傾 城	
一 鳴 驚 人	一 鼻 子 灰	一 鼻 孔 出 氣	一 齊	一 齊 二 整	一 齊 天 下	一 億	一 價	
一 噴 一 醒	一 墩	一 審	一 層	一 幢	一 彈 指 傾	一 德 一 心	一 撮	
一 暴 十 寒	一 樣	一 模 一 樣	一 樓	一 漿 十 餅	一 潭 死 水	一 盤	一 盤 散 沙	
一 盤 棋	一 瞑 不 視	一 碼 事	一 稿	一 窮 二 白	一 箭 之 地	一 箭 雙 鵰	一 箱	
一 篇	一 線	一 線 希 望	一 課	一 輛	一 輩	一 輩 子	一 輪	
一 醉	一 麾 出 守	一 劑	一 噸	一 戰	一 擁 而 入	一 擁 而 上	一 擔	
一 整 套	一 樹 百 獲	一 瘸	一 瞥	一 諾 千 金	一 選	一 錯 再 錯	一 錢 不 值	
一 錢 不 落 虛 空 地	一 錢 如 命	一 霎	一 頭	一 餐	一 龍 一 蛇	一 龍 一 豬	一 龍 九 種	
一 幫	一 幫 人	一 應	一 應 俱 全	一 擊	一 環	一 環 扣 一 環	一 環 緊 扣 一 環	
一 瞬	一 瞬 間	一 簇	一 簇 簇	一 縷	一 縷 煙	一 總	一 聲	
一 聲 不 吭	一 聲 不 響	一 聲 令 下	一 聯	一 臂 之 力	一 臉	一 舉	一 舉 一 動	
一 舉 千 里	一 舉 手 之 勞	一 舉 多 得	一 舉 成 名	一 舉 兩 便	一 舉 兩 得	一 謙 四 益	一 鍵	
一 鍋	一 錘	一 錘 定 音	一 鍬	一 顆	一 點	一 點 一 滴	一 點 也 不	
一 點 兒	一 點 點	一 點 靈 犀	一 叢	一 擲	一 擲 千 金	一 擲 百 萬	一 瀉 千 里	
一 竅 不 通	一 簧 兩 舌	一 簞 一 瓢	一 翻	一 觴 一 詠	一 轉	一 雙	一 雙 兩 好	
一 雙 鞋	一 蟹 不 如 一 蟹	一 蹶 不 振	一 蹴 而 得	一 蹴 而 就	一 邊	一 邊 倒	一 類	
一 爐	一 籌 莫 展	一 籃	一 覺	一 觸 即 發	一 觸 即 潰	一 黨	一 夔 已 足	
一 欄	一 覽	一 覽 表	一 覽 無 餘	一 躍	一 顧 傾 人	一 顧 傾 城	一 聽	
一 讀	一 驚	一 體	一 體 化	一 鱗 一 爪	一 鱗 片 甲	一 鱗 半 爪	一 鱗 半 甲	
一 攬 子	一 罐	一 顰 一 笑	一 厘 一 毫	一 捅 就 破	一 摞	一 饋 十 起	乙 二 醇	
乙 丑	乙 方	乙 地	乙 肝	乙 型	乙 型 腦 炎	乙 苯	乙 級	
乙 烯	乙 烯 基	乙 等	乙 腦	乙 酸	乙 醇	乙 類	乙 ��	
乙 炔	乙 胺	乙 烷	乙 醚	乙 醛	丁 □ 橡 膠	丁 一 卯 二	丁 一 確 二	
丁 二 烯	丁 人	丁 小 芹	丁 字	丁 字 尺	丁 字 街	丁 字 路	丁 是 丁 卯 是 卯	
丁 苯	丁 苯 橡 膠	丁 香	丁 香 花	丁 基	丁 基 橡 膠	丁 烯	丁 烯 二 酸	
丁 當	丁 零	丁 寧	丁 種 維 生 素	丁 聚 醣	丁 酸	丁 醇	丁 烷	
七 一	七 七	七 七 八 八	七 人	七 十	七 十 一	七 十 七	七 十 九	
七 十 二	七 十 人	七 十 八	七 十 三	七 十 五	七 十 六	七 十 四	七 十 年	
七 十 年 代	七 十 個	七 十 歲	七 上 八 下	七 上 八 落	七 千	七 千 萬	七 大	
七 大 工 業 國	七 寸	七 中 全 會	七 五	七 五 計 劃	七 五 期 間	七 六 人	七 六 人 隊	
七 分 之 一	七 天	七 孔 生 煙	七 手 八 腳	七 日	七 月	七 月 份	七 台	
七 巧 板	七 件	七 年	七 死 八 活	七 百	七 百 萬	七 老 八 十	七 色	
七 行	七 折 八 扣	七 步 之 才	七 步 成 章	七 步 格	七 角	七 角 形	七 屆	
七 弦 琴	七 拉 八 扯	七 長 八 短	七 青 八 黃	七 度	七 律	七 拼 八 湊	七 挑 八 選	
七 星	七 段	七 美	七 重 奏	七 面 體	七 音	七 倍	七 個	
七 時	七 狼 八 狽	七 病 八 痛	七 隻	七 高 八 低	七 區	七 國	七 堵 區	
七 彩	七 情 六 慾	七 條	七 絕	七 萬	七 號	七 路	七 零	
七 零 八 落	七 嘴 八 舌	七 嘴 八 張	七 樓	七 擒 七 縱	七 擒 八 縱	七 橫 八 豎	七 頭	
七 縱 七 擒	七 點	七 竅	七 竅 生 煙	七 顛 八 倒	七 彎 八 曲	乃 心 王 室	乃 文 乃 武	
乃 至	乃 見	乃 武 乃 文	乃 是	乃 論	九 一 八 事 變	九 七	九 九	
九 九 歸 一	九 人	九 十	九 十 一	九 十 七	九 十 九	九 十 二	九 十 八	
九 十 三	九 十 五	九 十 六	九 十 四	九 十 年	九 十 年 代	九 十 萬	九 三	
九 三 學 社	九 千	九 千 萬	九 大	九 中 全 會	九 五	九 五 之 位	九 五 之 尊	
九 六	九 分	九 分 之 一	九 天	九 孔	九 日	九 月	九 月 份	
九 牛 一 毛	九 牛 二 虎	九 牛 二 虎 之 力	九 世 之 仇	九 台	九 四	九 本	九 合 一 匡	
九 如 鄉	九 州	九 州 島	九 年	九 成	九 曲 迴 腸	九 曲 堂	九 次	
九 死 一 生	九 死 不 悔	九 江	九 百	九 百 萬	九 步	九 屆	九 股	
九 品	九 品 中 正	九 段	九 泉	九 泉 之 下	九 洲	九 流 三 教	九 流 百 家	
九 省	九 重 奏	九 倍	九 個	九 卿	九 原 可 作	九 時	九 書 不 如 無 書	
九 格	九 烈 三 貞	九 族	九 條	九 連 環	九 章	九 進 法	九 歲	
九 萬	九 號	九 路	九 鼎	九 鼎 大 呂	九 寨 溝	九 億	九 層	
九 德	九 德 電 子	九 樓	九 霄	九 霄 雲 外	九 龍	九 點	九 穩	
九 邊	九 邊 形	了 了 草 草	了 不 起	了 不 得	了 此	了 吧	了 局	
了 身 達 命	了 事	了 卻	了 案	了 帳	了 得	了 望	了 清	
了 然	了 結	了 債	了 斷	了 願	二 一	二 一 添 作 五	二 七	
二 九	二 二	二 人	二 人 同 心 其 利 斷 金	二 人 劃	二 八 開	二 十	二 十 一	
二 十 一 日	二 十 一 世 紀	二 十 七	二 十 七 日	二 十 九	二 十 九 日	二 十 二	二 十 二 日	
二 十 人	二 十 八	二 十 八 日	二 十 三	二 十 三 日	二 十 五	二 十 五 日	二 十 六	
二 十 六 日	二 十 日	二 十 世 紀	二 十 四	二 十 四 日	二 十 年	二 十 個	二 三	
二 三 其 意	二 三 其 德	二 千	二 寸	二 不	二 中	二 中 全 會	二 中 選 一	
二 五	二 元	二 元 性	二 元 酸	二 元 論	二 元 論 者	二 元 醇	二 六	
二 分	二 分 明 月	二 分 音 符	二 天	二 尺	二 心	二 心 兩 意	二 手	
二 手 車	二 手 貨	二 日	二 月	二 月 份	二 比 一	二 毛	二 水 鄉	
二 世	二 世 紀	二 四	二 用	二 甲 苯	二 伏	二 份	二 列	
二 名	二 名 制	二 回	二 地 區	二 字	二 尖 瓣	二 年	二 年 生	
二 年 級	二 年 級 情	二 次	二 次 大 戰	二 次 方	二 次 方 程	二 次 革 命	二 次 開 發	
二 次 冪	二 百	二 百 五	二 百 年	二 百 萬	二 缶 鐘 惑	二 老	二 色	
二 位	二 把	二 把 手	二 步	二 足	二 來	二 妹	二 姐	
二 姓 之 好	二 季 度	二 屆	二 弦	二 性	二 房	二 林	二 者	
二 者 之 一	二 者 之 間	二 者 必 居 其 一	二 則	二 度	二 指	二 段	二 流	
二 流 子	二 流 貨	二 炮	二 胡	二 胎	二 郎 腿	二 重	二 重 性	
二 重 奏	二 重 唱	二 面 角	二 音 節	二 倍	二 倍 體	二 個	二 哥	
二 哥 大	二 時	二 桃 殺 三 士	二 氧	二 氧 化 物	二 氧 化 硫	二 氧 化 氮	二 氧 化 碳	
二 氧 化 錳	二 氧 化 硅	二 氧 化 鈦	二 級	二 級 品	二 院	二 副	二 崙 鄉	
二 條	二 硫 化 物	二 硫 化 碳	二 硫 化 鉬	二 部	二 幾	二 期	二 期 工 程	
二 氯 乙 烷	二 等	二 等 分	二 等 功	二 等 獎	二 等 邊	二 進 位	二 進 位 制	
二 進 制	二 進 法	二 進 宮	二 量 體	二 開	二 項	二 項 分 佈	二 項 式	
二 傳	二 傳 手	二 傻	二 意	二 意 三 心	二 極	二 極 管	二 極 體	
二 歲	二 萬	二 萬 五 千 里 長 征	二 義 性	二 腳	二 號	二 話	二 話 不 說	
二 話 沒 說	二 路	二 道 販 子	二 滿 三 平	二 種	二 維	二 輕	二 輕 局	
二 億	二 價	二 審	二 層	二 層 樓	二 樓	二 線	二 輪	
二 輪 車	二 頭	二 頭 肌	二 環	二 點	二 簧	二 雙	二 類	
二 類 股	二 疊 紀	人 一 已 百	人 丁	人 丁 興 旺	人 人	人 人 平 等	人 人 有 責	
人 人 自 危	人 人 皆 知	人 力	人 力 仲 介 公 司	人 力 車	人 力 資 源	人 上	人 也	
人 亡 物 在	人 亡 政 息	人 亡 家 破	人 千 人 萬	人 口	人 口 分 佈	人 口 分 析	人 口 出 生 率	
人 口 危 機	人 口 地 理	人 口 地 理 學	人 口 老 化	人 口 社 會 學	人 口 政 策	人 口 統 計	人 口 規 劃	
人 口 普 查	人 口 經 濟 學	人 口 資 料	人 口 過 剩	人 口 預 測	人 口 增 長	人 口 數	人 口 遷 移	
人 口 戰 略	人 口 斷 層	人 士	人 大	人 大 代 表	人 大 常 委 會	人 子	人 小	
人 山 人 海	人 工	人 工 干 預	人 工 化	人 工 合 成	人 工 技 術	人 工 品	人 工 授 精	
人 工 智 能	人 才	人 才 出 眾	人 才 流 動	人 才 培 養	人 才 輩 出	人 才 學	人 才 濟 濟	
人 才 難 得	人 不 可 貌 相	人 不 犯 我 我 不 犯 人	人 不 自 安	人 不 知 鬼 不 覺	人 不 聊 生	人 中	人 中 之 龍	
人 中 獅 子	人 中 龍 虎	人 中 騏 驥	人 之	人 之 長 情	人 之 常 情	人 云	人 云 亦 云	
人 少	人 心	人 心 大 快	人 心 不 古	人 心 叵 測	人 心 向 背	人 心 如 面	人 心 所 向	
人 心 所 歸	人 心 皇 皇	人 心 惟 危	人 心 莫 測	人 心 惶 恐	人 心 惶 惶	人 心 渙 散	人 心 渙 漓	
人 心 隔 肚 皮	人 心 難 測	人 手	人 手 一 冊	人 手 不 足	人 文	人 文 主 義	人 文 地 理	
人 文 科 學	人 文 學	人 日	人 月	人 氏	人 世	人 世 間	人 主	
人 代 會	人 去 樓 空	人 奶	人 本 主 義	人 本 基 金 會	人 本 教 育	人 民	人 民 大 會 堂	
人 民 內 部 矛 盾	人 民 公 社	人 民 日 報	人 民 代 表 大 會	人 民 出 版 社	人 民 民 主 專 政	人 民 共 和 國	人 民 法 庭	
人 民 法 院	人 民 政 府	人 民 起 義	人 民 群 眾	人 民 解 放 軍	人 民 團 體	人 民 幣	人 民 檢 查 院	
人 犯	人 生	人 生 地 不 熟	人 生 在 世	人 生 面 不 熟	人 生 哲 學	人 生 價 值	人 生 觀	
人 用	人 仰 馬 翻	人 同 此 心	人 各 有 志	人 名	人 多	人 多 口 雜	人 多 手 雜	
人 多 地 少	人 多 勢 眾	人 多 嘴 雜	人 好	人 字 架	人 存 政 舉	人 年	人 有	
人 次	人 死 留 名	人 百 其 身	人 老 珠 黃	人 而 無 信 不 知 其 可	人 肉	人 臣	人 自 為 戰	
人 血	人 行	人 行 道	人 行 橋	人 住	人 似	人 君	人 困 馬 乏	
人 均	人 均 收 入	人 均 產 值	人 妖	人 形	人 形 靶	人 我 是 非	人 材	
人 言	人 言 可 畏	人 言 嘖 嘖	人 言 籍 籍	人 言 鑿 鑿	人 走 燈 滅	人 身	人 身 事 故	
人 身 權	人 防	人 乳	人 事	人 事 心 理 學	人 事 代 謝	人 事 行 政 局	人 事 局	
人 事 制 度	人 事 科	人 事 異 動	人 事 處	人 事 部	人 事 部 門	人 事 費	人 事 監 察	
人 事 管 理	人 事 管 理 學	人 事 變 動	人 事 廳	人 來 人 往	人 來 客 去	人 來 客 往	人 兒	
人 和	人 命	人 命 危 淺	人 命 關 天	人 定	人 定 勝 天	人 性	人 性 化	
人 性 論	人 或 物	人 所 不 為	人 所 不 齒	人 所 共 知	人 武	人 武 部	人 治	
人 爭	人 物	人 物 專 訪	人 物 描 寫	人 物 誌	人 知	人 社	人 者	
人 非	人 非 土 木	人 非 草 木	人 前	人 品	人 品 好	人 急 計 生	人 急 智 生	
人 怨 神 怒	人 流	人 流 行	人 為	人 皆 有 之	人 皆 盡 知	人 相	人 相 學	
人 約 黃 昏	人 面 桃 花	人 面 獸 心	人 首	人 們	人 倫	人 員	人 員 測 評	
人 員 構 成	人 家	人 師	人 時	人 格	人 格 化	人 格 心 理 學	人 格 違 常	
人 格 操 守	人 氣	人 海	人 海 戰 術	人 浮 於 事	人 畜	人 神 共 憤	人 神 同 憤	
人 脈 關 係	人 般	人 財 兩 失	人 財 兩 旺	人 財 兩 空	人 馬	人 馬 座	人 高	
人 做	人 參	人 堆	人 強 馬 壯	人 情	人 情 之 常	人 情 世 故	人 情 冷 暖	
人 情 味	人 情 洶 洶	人 情 債	人 望	人 棄 我 取	人 欲	人 眾 勝 天	人 莫 予 毒	
人 莫 於 毒	人 販 子	人 貪 智 短	人 造	人 造 毛	人 造 皮	人 造 石 油	人 造 冰	
人 造 地 球 衛 星	人 造 革	人 造 棉	人 造 絲	人 造 衛 星	人 造 橡 膠	人 造 纖 維	人 逢 喜 事 精 神 爽	
人 都	人 傑	人 傑 地 靈	人 喊 馬 嘶	人 掌	人 散	人 智 說	人 渣	
人 無 遠 慮 必 有 近 憂	人 琴 俱 亡	人 給 家 足	人 街	人 貴 有 自 知 之 明	人 間	人 間 天 上	人 間 地 獄	
人 傳 記	人 勢	人 微 言 輕	人 微 權 輕	人 意	人 愛	人 煙	人 煙 浩 穰	
人 煙 湊 集	人 煙 稀 少	人 煙 稠 密	人 煙 輻 輳	人 猿	人 瑞	人 稠 物 穰	人 罪	
人 群	人 腦	人 話	人 跡	人 跡 罕 至	人 跡 罕 到	人 跡 稀 少	人 道	
人 道 主 義	人 像	人 像 圖	人 壽	人 壽 年 豐	人 壽 保 險	人 對 人	人 滿 為 患	
人 盡 其 才	人 禍	人 種	人 種 上	人 種 間	人 稱	人 網	人 與	
人 與 人 之 間	人 語	人 語 馬 嘶	人 際	人 際 服 務	人 際 藝 術	人 際 關 係	人 影	
人 慾 橫 流	人 數	人 數 眾 多	人 樣	人 潮	人 窮 志 短	人 窮 智 短	人 緣	
人 質	人 學	人 寰	人 機	人 機 交 互	人 機 界 面	人 謀	人 選	
人 靜	人 頭	人 頭 皮	人 頭 畜 鳴	人 頭 馬	人 頭 稅	人 龍	人 糞 尿	
人 聲	人 聲 鼎 沸	人 講	人 叢	人 證	人 證 物 證 俱 在	人 類	人 類 工 程 學	
人 類 化	人 類 文 化 學	人 類 社 會	人 類 學	人 贓	人 權	人 權 協 會	人 歡 馬 叫	
人 髒 俱 獲	人 體	人 體 科 學	人 體 學	入 口	入 口 處	入 土	入 不 支 出	
入 不 敷 出	入 內	入 手	入 支	入 木 三 分	入 水	入 世	入 主	
入 主 出 奴	入 冊	入 冬	入 出 境	入 出 境 管 理 局	入 市	入 伙	入 伍	
入 伏	入 列	入 地	入 托	入 耳	入 住	入 住 率	入 吾 彀 中	
入 村	入 味	入 夜	入 定	入 店	入 於	入 社	入 股	
入 門	入 門 書	入 侵	入 侵 者	入 城	入 室 升 堂	入 室 操 戈	入 春	
入 流	入 洞	入 夏	入 射	入 射 角	入 射 線	入 席	入 庫	
入 座	入 時	入 海	入 眠	入 神	入 站	入 貢	入 迷	
入 院	入 骨	入 國 問 俗	入 帳	入 情 入 理	入 教	入 眼	入 圍	
入 圍 者	入 場	入 場 券	入 場 權	入 棧	入 款	入 港	入 港 稅	
入 畫	入 窖	入 超	入 鄉 隨 俗	入 隊	入 微	入 會	入 會 者	
入 會 談 判	入 稟	入 聖 超 凡	入 道	入 團	入 境	入 境 問 俗	入 境 問 禁	
入 境 隨 俗	入 夢	入 寢	入 幕 之 賓	入 獄	入 睡	入 網	入 閣	
入 賬	入 學	入 學 率	入 選	入 選 者	入 檔	入 殮	入 營	
入 聲	入 闈	入 贅	入 藥	入 鏡	入 關	入 籍	入 黨	
入 魔	八 一	八 一 建 軍 節	八 一 隊	八 七	八 九 不 離 十	八 人	八 八	
八 十	八 十 一	八 十 七	八 十 九	八 十 二	八 十 人	八 十 八	八 十 三	
八 十 五	八 十 六	八 十 四	八 十 年	八 十 年 代	八 十 個	八 十 歲	八 十 萬	
八 千	八 千 萬	八 大 處	八 小 時	八 小 時 工 作 制	八 中 全 會	八 五	八 五 規 劃	
八 五 期 間	八 分	八 分 之 一	八 分 音 符	八 斗 之 才	八 方	八 方 支 援	八 方 呼 應	
八 日	八 月	八 月 份	八 仙	八 仙 桌	八 仙 過 海	八 字	八 字 打 開	
八 字 形	八 字 沒 一 撇	八 字 憲 法	八 字 鬍	八 年	八 成	八 次	八 百	
八 百 萬	八 戒	八 折	八 村	八 角	八 角 形	八 邦 立 國	八 里 鄉	
八 兩	八 兩 半 斤	八 卦	八 卦 陣	八 屆	八 弦 琴	八 怪	八 的	
八 股	八 股 文	八 門 五 花	八 度	八 拜 之 交	八 段	八 重 奏	八 面	
八 面 見 光	八 面 威 風	八 面 威 風 睜	八 面 玲 瓏	八 面 圓 通	八 面 體	八 音	八 音 節	
八 倍	八 個	八 哥	八 時	八 國	八 國 聯 軍	八 條	八 進 制	
八 開 紙	八 塊	八 萬	八 號	八 路	八 路 軍	八 道	八 達 嶺	
八 旗	八 旗 子 弟	八 億	八 層	八 德 市	八 德 鄉	八 樓	八 點	
八 點 半	八 邊	八 邊 形	八 類	八 寶	八 寶 山	刀 刃	刀 叉	
刀 口	刀 子	刀 山	刀 山 火 海	刀 山 劍 樹	刀 片	刀 光	刀 光 劍 影	
刀 匠	刀 尖	刀 把	刀 豆	刀 身	刀 具	刀 法	刀 架	
刀 柄	刀 背	刀 面	刀 差	刀 耕 火 種	刀 耕 火 耨	刀 桿	刀 械	
刀 痕	刀 魚	刀 割	刀 筆	刀 傷	刀 閘	刀 槍	刀 槍 入 庫	
刀 劍	刀 鋒	刀 鞘	刁 民	刁 悍	刁 婦	刁 圓	刁 滑	
刁 頑	刁 難	刁 鑽	刁 鑽 古 怪	力 士	力 大 無 比	力 大 無 窮	力 山 工 業	
力 不 同 科	力 不 自 勝	力 不 副 心	力 不 從 心	力 不 從 願	力 分 勢 弱	力 及	力 主	
力 行	力 作	力 克	力 困 筋 乏	力 均 勢 敵	力 戒	力 求	力 系	
力 屈 計 窮	力 屈 勢 窮	力 屈 道 窮	力 所 能 及	力 爭	力 爭 上 游	力 信 興 業	力 促	
力 度	力 持	力 派	力 倍 功 半	力 差	力 弱	力 挽 狂 瀾	力 挫	
力 挫 群 雄	力 氣	力 泰 建 設	力 矩	力 衰	力 做	力 偶	力 強	
力 捷 電 腦	力 捧	力 排	力 排 眾 議	力 透 紙 背	力 陳	力 創	力 場	
力 晶 半 導	力 華 票 券	力 量	力 量 大	力 量 對 比	力 微	力 微 任 重	力 感	
力 解	力 圖	力 盡	力 盡 筋 疲	力 竭	力 竭 聲 嘶	力 敵 勢 均	力 敵 萬 夫	
力 學	力 學 篤 行	力 戰	力 謀	力 濟 九 區	力 臂	力 薄 才 疏	力 薦	
力 蹙 勢 窮	力 鵬 企 業	力 麒 建 設	力 麗 企 業	力 勸	力 瑋 實 業	力 殫 財 竭	匕 首	
匕 鬯 不 驚	十 一	十 一 人	十 一 大	十 一 月	十 一 月 份	十 一 屆 三 中 全 會	十 一 倍	
十 一 個	十 一 時	十 七	十 七 人	十 七 世 紀	十 七 個	十 九	十 九 人	
十 九 世 紀	十 九 個	十 九 時	十 二	十 二 人	十 二 大	十 二 分	十 二 月	
十 二 月 份	十 二 用	十 二 金 牌	十 二 指 腸	十 二 音	十 二 倍	十 二 個	十 二 個 月	
十 二 時	十 二 開	十 人	十 八	十 八 人	十 八 世 紀	十 八 個	十 八 時	
十 八 般 武 藝	十 八 開	十 八 歲	十 八 羅 漢	十 十 五 五	十 三	十 三 人	十 三 大	
十 三 個	十 三 時	十 三 陵	十 三 經	十 三 點	十 大	十 中 全 會	十 之 八 九	
十 五	十 五 人	十 五 日	十 五 世 紀	十 五 年	十 五 個	十 五 個 吊 桶 打 水	十 元	
十 元 整	十 六	十 六 人	十 六 分 音 符	十 六 世 紀	十 六 字 訣	十 六 個	十 六 時	
十 六 進 位	十 六 進 制	十 六 開 本	十 六 歲	十 分	十 分 干	十 分 之	十 分 之 一	
十 分 必 要	十 分 多 謝	十 分 困 難	十 分 迅 速	十 分 明 確	十 分 注 意	十 分 相 似	十 分 重 要	
十 分 重 視	十 分 高 興	十 分 滿 意	十 分 複 雜	十 分 艱 巨	十 分 關 心	十 分 寶 貴	十 天	
十 尺	十 戶	十 方	十 日	十 日 一 水 五 日 一 石	十 日 怕 麻 繩	十 日 談	十 月	
十 月 份	十 月 革 命	十 冬 臘 月	十 四	十 四 人	十 四 大	十 四 個	十 四 時	
十 本	十 生 九 死	十 目 所 視 十 手 所 指	十 件	十 全	十 全 十 美	十 字	十 字 形	
十 字 花 科	十 字 架	十 字 軍	十 字 街 頭	十 字 路	十 字 路 口	十 字 路 頭	十 字 標	
十 字 頭	十 字 繡	十 字 鏡	十 年	十 年 九 不 遇	十 年 內 亂	十 年 如 一 日	十 年 怕 井 索	
十 年 動 亂	十 年 規 劃	十 年 寒 窗	十 年 期	十 年 間	十 年 樹 木	十 年 樹 木 百 年 樹 人	十 成	
十 有 八 九	十 死 一 生	十 死 九 生	十 米	十 羊 九 牧	十 行 俱 下	十 位	十 克	
十 步 芳 草	十 角 形	十 足	十 足 類	十 里	十 里 洋 場	十 佳	十 味	
十 屆	十 便 士	十 室 九 空	十 指 有 長 短	十 指 連 心	十 段	十 美 企 業	十 面	
十 面 體	十 音 節	十 風 五 雨	十 倍	十 個	十 家	十 拿 九 穩	十 拿 十 穩	
十 捉 九 著	十 時	十 病 九 痛	十 級	十 張	十 條	十 通	十 圍 五 攻	
十 堰	十 幾	十 幾 年 來	十 幾 歲	十 惡 不 赦	十 期	十 進 小 數	十 進 位	
十 進 位 制	十 進 制	十 進 管	十 開	十 項	十 項 全 能	十 歲	十 萬	
十 萬 八 千 里	十 萬 火 急	十 萬 火 速	十 號	十 路	十 鼠 同 穴	十 鼠 爭 穴	十 滴 水	
十 億	十 樓	十 噸	十 蕩 十 決	十 親 九 故	十 點	十 邊 形	十 類	
卜 占	卜 占 官	卜 卦	卜 夜 卜 晝	卜 晝 卜 夜	卜 術	卜 蜂 企 業	卜 算	
卜 辭	又 一	又 一 次	又 一 個	又 上	又 大	又 不	又 不 能	
又 及	又 比	又 以	又 可	又 叫	又 打	又 名	又 名 為	
又 因	又 在	又 多	又 好	又 如	又 有	又 吹	又 把	
又 沒	又 來	又 到	又 和	又 拉	又 放	又 非	又 是	
又 為	又 紅 又 專	又 要	又 哭 又 鬧	又 弱 一 個	又 能	又 訊	又 起	
又 帶	又 從	又 被	又 都	又 給	又 搞	又 會	又 經	
又 像	又 對	又 稱	又 端	又 與	又 說	又 熱	又 瘦	
又 靠	三 七	三 七 二 十 一	三 七 開	三 九	三 九 天	三 人	三 人 成 虎	
三 人 行 必 有 我 師	三 人 間	三 八	三 八 紅 旗 手	三 八 國 際 婦 女 節	三 八 婦 女 節	三 八 節	三 十	
三 十 一	三 十 一 日	三 十 七	三 十 九	三 十 二	三 十 人	三 十 八	三 十 三	
三 十 五	三 十 六	三 十 六 招 走 為 上 招	三 十 六 計	三 十 六 策 走 為 上 策	三 十 日	三 十 四	三 十 年	
三 十 年 代	三 十 而 立	三 十 個	三 十 萬	三 三 五 五	三 三 兩 兩	三 下 五 除 二	三 丈	
三 千	三 千 珠 履	三 叉	三 叉 戟	三 叉 路 口	三 口	三 大	三 大 作 風	
三 大 法 寶	三 寸	三 寸 不 爛 之 舌	三 寸 之 舌	三 中 全 會	三 五 成 群	三 元	三 元 裡	
三 六 九 等	三 分	三 分 之 一	三 分 之 二	三 分 法	三 分 鼎 立	三 分 鼎 足	三 分 像 人 七 分 像 鬼	
三 天	三 天 兩 頭	三 孔	三 尺	三 心 二 意	三 心 兩 意	三 戶 亡 秦	三 方 面	
三 日	三 日 打 魚 兩 日 曬 網	三 月	三 月 份	三 毛	三 水	三 世	三 代	
三 令 五 申	三 包	三 北	三 台	三 句	三 句 話 不 離 本 行	三 平 二 滿	三 民 主 義	
三 瓦 四 捨	三 瓦 兩 捨	三 生 有 幸	三 伏	三 伏 天	三 件	三 份	三 光	
三 名	三 合 一	三 合 板	三 地	三 好	三 好 生	三 好 兩 歉	三 好 學 生	
三 字 經	三 年	三 年 不 窺 園	三 年 之 艾	三 年 五 載	三 年 怕 井 繩	三 成	三 旬 九 食	
三 次	三 百	三 百 六 十 行	三 百 年	三 百 萬	三 老 四 嚴	三 色	三 色 版	
三 行	三 位	三 位 一 體	三 位 數	三 局	三 局 兩 勝	三 把 火	三 折 之 肱	
三 折 肱 為 良 醫	三 更	三 更 半 夜	三 束	三 步	三 求 四 懇	三 沐 三 熏	三 災 八 難	
三 男 四 女	三 角	三 角 巾	三 角 尺	三 角 方 程	三 角 形	三 角 函 數	三 角 板	
三 角 法	三 角 架	三 角 洲	三 角 釘	三 角 旗	三 角 學	三 角 鐵	三 言 二 拍	
三 言 五 語	三 言 兩 句	三 言 兩 語	三 豕 涉 河	三 豕 渡 河	三 足 鼎 立	三 和 弦	三 和 音	
三 夜	三 姑	三 姑 六 婆	三 季 度	三 屆	三 弦	三 弦 琴	三 明	
三 明 治	三 朋 四 友	三 河	三 者 間	三 芳 化 工	三 芝	三 芝 鄉	三 采 建 設	
三 長 兩 短	三 門 峽	三 信 商 銀	三 便 士	三 度	三 思	三 思 而 行	三 思 而 後 行	
三 是	三 星	三 星 五 金	三 星 堆	三 星 鄉	三 星 電 子	三 段	三 段 式	
三 段 論	三 洋	三 洋 紡 織	三 洋 電 機	三 流	三 流 九 等	三 相	三 秋	
三 竿 日 上	三 胞 胎	三 貞 九 烈	三 軍	三 重	三 重 奏	三 面	三 面 體	
三 音 步	三 音 節	三 倍	三 倍 性	三 個	三 個 月	三 個 字	三 個 臭 皮 匠	
三 原 色	三 夏	三 家	三 峽	三 差 五 錯	三 座 大 山	三 振	三 時	
三 晃	三 氧	三 班 六 房	三 班 制	三 班 倒	三 級	三 級 跳 遠	三 級 管	
三 紙 無 驢	三 茶 六 飯	三 隻	三 副	三 商 人 壽	三 商 行	三 商 電 腦	三 商 銀	
三 國	三 國 時 代	三 國 演 義	三 國 誌	三 張	三 強	三 從 四 德	三 接 頭	
三 推 六 問	三 教 九 流	三 斜	三 條	三 通	三 通 一 平	三 通 閥	三 連 冠	
三 連 音	三 部	三 部 曲	三 頂	三 富 汽 車	三 幅	三 復 斯 言	三 期	
三 朝 元 老	三 番 五 次	三 番 四 復	三 番 兩 次	三 等	三 等 分	三 等 功	三 等 獎	
三 結 合	三 絕 韋 編	三 菱	三 開	三 陽 工 業	三 集	三 項	三 項 式	
三 極 管	三 歲	三 溫 暖	三 萬	三 稜	三 稜 鏡	三 窟 狡 兔	三 節	
三 義 鄉	三 腳	三 腳 架	三 葉 形	三 號	三 資	三 路	三 跪 九 叩	
三 道	三 態	三 槐 九 棘	三 種	三 粹	三 綱 五 常	三 維	三 維 空 間	
三 聚	三 億	三 價	三 層	三 廢	三 樓	三 箱	三 緘 其 口	
三 線	三 輪	三 輪 車	三 親 六 故	三 親 六 眷	三 親 四 眷	三 頭	三 頭 六 臂	
三 頭 肌	三 頭 兩 緒	三 頭 對 證	三 餐	三 環	三 翼	三 聯	三 點	
三 豐 建 設	三 邊	三 邊 形	三 類	三 顧 其 門 而 不 入	三 顧 茅 廬	三 權 分 立	三 灣	
三 釁 三 沐	三 熏 三 沐	下 一	下 一 代	下 一 位	下 一 步	下 一 個	下 一 階 段	
下 了	下 人	下 下	下 凡	下 勺	下 口	下 土	下 士	
下 大 力 氣	下 大 工 夫	下 大 本 錢	下 女	下 子	下 山	下 工	下 工 夫	
下 不 來	下 不 為 例	下 中 農	下 井 投 石	下 午	下 孔	下 巴	下 引	
下 手	下 文	下 方	下 月	下 毛	下 水	下 水 道	下 片	
下 世	下 世 紀 初	下 仔	下 令	下 冊	下 半	下 半 生	下 半 年	
下 半 夜	下 半 時	下 半 場	下 半 旗	下 去	下 台	下 生	下 用	
下 田	下 列	下 同	下 回	下 地	下 年	下 旬	下 有	
下 次	下 江	下 行	下 位	下 作	下 判 斷	下 床	下 步	
下 沉	下 決 心	下 牢	下 角	下 身	下 車	下 車 之 始	下 車 伊 始	
下 車 泣 罪	下 例	下 來	下 周	下 命 令	下 坡	下 坡 路	下 季	
下 定	下 定 義	下 官	下 屆	下 帖	下 店	下 延	下 弦	
下 房	下 拉	下 拉 菜 單	下 放	下 於	下 板 走 丸	下 注	下 河	
下 法	下 油	下 炕	下 肢	下 表	下 門	下 附	下 雨	
下 雨 天	下 品	下 垂	下 垂 症	下 奏	下 拜	下 星 期	下 星 期 一	
下 星 期 二	下 星 期 三	下 星 期 五	下 星 期 日	下 星 期 四	下 柬	下 毒	下 毒 手	
下 毒 者	下 流	下 流 人	下 流 話	下 洩	下 界	下 相	下 看	
下 穿	下 述	下 限	下 降	下 面	下 頁	下 風	下 飛 機	
下 乘	下 個	下 個 月	下 個 世 紀	下 個 星 期	下 凍	下 唇	下 挫	
下 書	下 氣	下 海	下 浮	下 班	下 站	下 級	下 級 服 從 上 級	
下 級 單 位	下 起	下 酒	下 院	下 陣 雨	下 馬	下 馬 威	下 馬 看 花	
下 側	下 問	下 基 層	下 堂	下 崗	下 得	下 情	下 情 上 達	
下 探	下 接	下 推	下 略	下 移	下 船	下 莊	下 處	
下 蛋	下 設	下 逐 客 令	下 部	下 野	下 釣	下 陷	下 雪	
下 雪 雨	下 雪 量	下 單	下 場	下 期	下 棋	下 款	下 游	
下 無 立 錐 之 地	下 發	下 等	下 策	下 筆	下 筆 千 言	下 筆 如 有 神	下 筆 如 神	
下 筆 成 章	下 筆 成 篇	下 筆 有 神	下 著 雨	下 詔	下 象 棋	下 跌	下 鄉	
下 階 層	下 集	下 飯	下 傳	下 傾	下 塌	下 嫁	下 愚 不 移	
下 意 識	下 溢	下 滑	下 碗	下 腳	下 腳 料	下 腹	下 腹 部	
下 落	下 落 不 明	下 葬	下 裝	下 裡 巴 人	下 跪	下 載	下 道	
下 達	下 僚	下 劃	下 劃 線	下 榻	下 獄	下 種	下 端	
下 網	下 墜	下 墜 球	下 寫	下 層	下 廚	下 廠	下 撥	
下 標	下 樓	下 樓 梯	下 潛	下 盤	下 篇	下 課	下 調	
下 賤	下 賭	下 輩	下 輩 子	下 頜	下 操	下 樹	下 艙	
下 錯	下 頭	下 壓	下 檔	下 營	下 營 鄉	下 聯	下 臂	
下 轄	下 錨	下 鍵	下 鍋	下 霜	下 點	下 擺	下 瀉	
下 額	下 顎	下 懷	下 藥	下 邊	下 關	下 霧	下 議 院	
下 屬	下 鐵 道	下 體	下 鑽	下 崽	下 舖	丈 二	丈 二 金 剛	
丈 人	丈 夫	丈 夫 似	丈 母	丈 量	丈 義	上 一	上 一 次	
上 一 個	上 一 階 段	上 一 勸 百	上 了	上 下	上 下 一 心	上 下 一 致	上 下 午	
上 下 文	上 下 交 困	上 下 同 心	上 下 其 手	上 下 相 安	上 下 班	上 下 級	上 下 級 之 間	
上 下 結 合	上 上	上 上 下 下	上 千	上 叉	上 口	上 山	上 山 下 鄉	
上 工	上 弓	上 中 農	上 午	上 升	上 升 幅 度	上 天	上 天 入 地	
上 天 無 路 入 地 無 門	上 心	上 手	上 手 銬	上 文	上 方	上 月	上 月 份	
上 水	上 火	上 片	上 世	上 世 紀	上 以	上 代	上 加	
上 半 年	上 半 身	上 半 夜	上 半 時	上 半 部	上 半 場	上 去	上 司	
上 台	上 句	上 市	上 市 公 司	上 市 申 請	上 用	上 皮	上 交	
上 任	上 光	上 列	上 刑	上 吊	上 吐	上 回	上 在	
上 好	上 年	上 年 紀	上 托	上 旬	上 有	上 有 老 下 有 小	上 次	
上 百	上 自	上 至	上 色	上 行	上 行 下 效	上 衣	上 位	
上 作	上 告	上 坐	上 床	上 扯	上 求 下 告	上 角	上 身	
上 車	上 京	上 供	上 例	上 來	上 到	上 卸	上 周	
上 坡	上 夜	上 季	上 官	上 屈	上 屆	上 岸	上 弦	
上 房	上 拋	上 拍	上 林	上 油	上 爬	上 知 天 文 下 知 地 理	上 空	
上 肢	上 表	上 門	上 門 服 務	上 前	上 前 線	上 品	上 奏	
上 帝	上 映	上 星 期	上 星 期 一	上 星 期 二	上 星 期 三	上 星 期 五	上 星 期 六	
上 星 期 日	上 星 期 四	上 段	上 流	上 流 社 會	上 流 階 級	上 為	上 界	
上 相	上 看	上 背 部	上 述	上 限	上 面	上 頁	上 風	
上 首	上 香	上 乘	上 個	上 個 月	上 個 世 紀	上 個 星 期	上 凍	
上 哪	上 唇	上 套	上 家	上 射 式	上 席	上 座	上 座 率	
上 書	上 校	上 栓	上 氣 不 接 下 氣	上 海	上 海 市	上 海 交 大	上 海 商 銀	
上 浮	上 班	上 班 族	上 站	上 級	上 級 指 示	上 級 領 導	上 院	
上 陣	上 馬	上 側	上 匾	上 堂	上 尉	上 將	上 崗	
上 帳	上 情 下 達	上 斜	上 梁	上 條	上 眼 皮	上 移	上 船	
上 訪	上 貨	上 部	上 場	上 報	上 揚	上 期	上 朝	
上 款	上 游	上 無 片 瓦	上 畫	上 稅	上 等	上 等 品	上 策	
上 著	上 菜	上 街	上 訴	上 訴 人	上 進	上 進 心	上 間	
上 集	上 項	上 傳	上 傳 下 達	上 溢	上 溯	上 當	上 當 受 騙	
上 萬	上 節	上 腰	上 裙	上 裝	上 路	上 載	上 達	
上 鉤	上 圖	上 榜	上 演	上 漏 下 濕	上 漆	上 漲	上 漲 幅 度	
上 端	上 算	上 緊	上 網	上 臺 階	上 蒼	上 賓	上 墳	
上 層	上 層 建 築	上 標	上 標 題	上 樓	上 樓 去 梯	上 樑 不 正 下 樑 歪	上 漿	
上 篇	上 膛	上 膘	上 課	上 調	上 頜	上 學	上 操	
上 樹	上 樹 拔 梯	上 機	上 機 操 作	上 燈	上 諭	上 頷 骨	上 頭	
上 戴	上 檔	上 環	上 繃 帶	上 聲	上 聯	上 臂	上 舉	
上 曜 塑 膠	上 櫃	上 櫃 公 司	上 竄 下 跳	上 翻	上 鎖	上 額	上 顎	
上 簷	上 繳	上 藥	上 邊	上 邊 緣	上 類	上 議 院	上 饒	
上 屬 音	上 蠟	上 彎 形	上 癮	上 變	上 體	上 舖	丫 頭	
丫 環	丫 鬟	丸 子	丸 藥	丸 藥 盒	凡 人	凡 士 林	凡 夫	
凡 夫 俗 子	凡 心	凡 以	凡 可	凡 未	凡 用	凡 立 丁	凡 在	
凡 有	凡 此	凡 此 種 種	凡 事	凡 例	凡 是	凡 為	凡 胎 俗 骨	
凡 胎 濁 骨	凡 能	凡 將	凡 庸	凡 經	凡 爾	凡 與	凡 需	
凡 賽 斯	凡 屬	凡 響	久 了	久 久	久 已	久 之	久 仰	
久 仰 大 名	久 地	久 存	久 安 長 治	久 而 久 之	久 別	久 坐	久 旱	
久 旱 逢 甘 雨	久 性	久 拖	久 拖 不 辦	久 治	久 長	久 前	久 品	
久 津 實 業	久 負 盛 名	久 候	久 留	久 病	久 假 不 歸	久 等	久 經	
久 經 考 驗	久 經 沙 場	久 經 鍛 煉	久 話	久 違	久 隔	久 夢 初 醒	久 稱	
久 遠	久 撥	久 辯	么 喝	么 麼 小 丑	也 不 例 外	也 比	也 占	
也 可	也 可 能	也 回	也 好	也 即	也 門	也 門 人	也 非	
也 指	也 是	也 為	也 挺	也 許	也 喊	也 就	也 須	
也 須 用	也 會	也 像	也 罷	也 還	乞 丐	乞 求	乞 求 者	
乞 兒	乞 哀	乞 哀 告 憐	乞 降	乞 食	乞 納	乞 討	乞 援	
乞 憐	乞 憐 搖 尾	乞 漿 得 酒	于 思 于 思	于 飛 之 樂	于 莉	于 魁 智	亡 人	
亡 立 錐 之 地	亡 羊 補 牢	亡 命	亡 命 之 徒	亡 命 徒	亡 者	亡 故	亡 國	
亡 國 之 音	亡 國 奴	亡 戟 得 矛	亡 魂	亡 魂 失 魄	亡 魂 喪 膽	亡 靈	兀 立	
兀 自	兀 鷹	刃 人	刃 口	刃 角	刃 具	勺 子	千 了 百 當	
千 人	千 人 所 指	千 刀 萬 剁	千 刀 萬 剮	千 丈	千 千 萬 萬	千 山	千 山 萬 水	
千 山 萬 壑	千 仇 萬 恨	千 元	千 公 斤	千 分	千 分 之	千 分 之 一	千 分 尺	
千 分 位	千 分 表	千 分 率	千 升	千 夫 所 指	千 孔 百 瘡	千 尺	千 戶	
千 斤	千 斤 頂	千 方 百 計	千 方 萬 計	千 日	千 代 大 海	千 卡	千 古	
千 古 獨 步	千 叮 萬 囑	千 瓦	千 伏	千 伏 特	千 兆	千 回	千 回 百 轉	
千 字	千 字 節	千 年	千 年 萬 載	千 百	千 百 年 來	千 百 萬	千 米	
千 位	千 伶 百 俐	千 克	千 克 米	千 兵 萬 馬	千 妥 萬 妥	千 妥 萬 當	千 村 萬 落	
千 言 萬 語	千 足 蟲	千 辛 百 苦	千 辛 萬 苦	千 里	千 里 一 曲	千 里 之 行	千 里 之 堤	
千 里 之 堤 潰 於 蟻 穴	千 里 命 駕	千 里 姻 緣 一 線 牽	千 里 迢 迢	千 里 迢 遙	千 里 純 羹	千 里 送 鵝 毛	千 里 馬	
千 里 眼	千 里 猶 面	千 里 達	千 里 鵝 毛	千 依 百 順	千 依 萬 順	千 呼 萬 喚	千 周	
千 周 率	千 奇 百 怪	千 居 裡	千 狀 萬 態	千 狀 萬 端	千 金	千 金 一 刻	千 金 一 笑	
千 金 一 諾	千 金 一 擲	千 金 小 姐	千 金 之 子	千 金 之 家	千 金 市 骨	千 金 買 笑	千 金 弊 帚	
千 門 萬 戶	千 姿 百 態	千 度	千 思 萬 想	千 秋	千 秋 大 業	千 秋 萬 世	千 秋 萬 代	
千 秋 萬 古	千 秋 萬 歲	千 紅 萬 紫	千 軍	千 軍 易 得 一 將 難 求	千 軍 萬 馬	千 頁	千 乘 萬 騎	
千 倍	千 倉 萬 箱	千 家 萬 戶	千 島	千 差 萬 別	千 恩 萬 謝	千 畝	千 真 萬 真	
千 真 萬 確	千 張	千 推 萬 阻	千 條 萬 端	千 部 一 腔 千 人 一 面	千 喚 萬 喚	千 絲 萬 縷	千 鈞	
千 鈞 一 髮	千 鈞 重 負	千 陽	千 歲	千 歲 一 時	千 盞 菊	千 萬	千 萬 個	
千 萬 買 鄰	千 葉	千 葉 市	千 載 一 合	千 載 一 時	千 載 一 逢	千 載 一 會	千 載 一 遇	
千 載 獨 步	千 載 難 逢	千 態 萬 狀	千 端 萬 緒	千 緒 萬 端	千 聞 不 如 一 見	千 赫	千 億	
千 嬌 百 媚	千 嬌 百 態	千 層	千 慮	千 慮 一 失	千 慮 一 得	千 瘡 百 孔	千 篇 一 律	
千 編 一 律	千 餘	千 噸	千 興	千 頭 萬 緒	千 禧 蟲	千 禧 蟲 問 題	千 錘	
千 錘 百 煉	千 鎰 之 裘	千 難 萬 險	千 難 萬 難	千 歡 萬 喜	千 巖 萬 谷	千 巖 萬 壑	千 纖	
千 變 萬 化	叉 上	叉 口	叉 子	叉 手	叉 形	叉 車	叉 狀	
叉 架	叉 起	叉 配	叉 掉	叉 著	叉 開	叉 腰	叉 路	
叉 腿	叉 燒	口 口	口 口 相 傳	口 口 聲 聲	口 子	口 才	口 不 二 價	
口 不 應 心	口 中	口 中 蚤 虱	口 中 雌 黃	口 內	口 水	口 水 戰	口 令	
口 出	口 出 狂 言	口 外	口 交	口 吐 珠 璣	口 吃	口 吃 人	口 吃 者	
口 如 懸 河	口 耳 之 學	口 舌	口 血 未 干	口 似 懸 河	口 吻	口 吻 生 花	口 含 天 憲	
口 形	口 快	口 快 心 直	口 技	口 角	口 角 春 風	口 供	口 供 人	
口 兒	口 味	口 尚 乳 臭	口 岸	口 拙	口 服	口 服 心 服	口 服 液	
口 沸 目 赤	口 狀	口 信	口 是 心 非	口 紅	口 若	口 若 懸 河	口 述	
口 述 者	口 音	口 風	口 香 片	口 香 糖	口 哨	口 徑	口 氣	
口 臭	口 乾	口 乾 舌 燥	口 側	口 密 腹 劍	口 授	口 條	口 涎	
口 術	口 袋	口 訣	口 部	口 惠 而 實 不 至	口 湖 鄉	口 渴	口 無 擇 言	
口 琴	口 腔	口 腔 炎	口 腔 衛 生	口 腔 癌	口 傳	口 碑	口 碑 載 道	
口 罩	口 腹 蜜 劍	口 號	口 試	口 誅	口 誅 筆 伐	口 實	口 福	
口 稱	口 算	口 緊	口 蓋	口 蜜 腹 劍	口 誦 心 惟	口 語	口 說 無 憑	
口 鼻	口 鼻 部	口 德	口 瘡	口 齒	口 齒 伶 俐	口 器	口 壁	
口 蹄 疫	口 頭	口 頭 上	口 頭 語	口 頭 禪	口 燥 唇 乾	口 糧	口 譯	
土 人	土 山	土 中	土 方	土 木	土 木 工 程	土 木 形 骸	土 木 建 築	
土 木 香	土 牛 木 馬	土 丘	土 包 子	土 司	土 布	土 生	土 生 土 長	
土 石	土 石 方	土 石 流	土 地	土 地 改 革	土 地 法	土 地 測 量 局	土 地 稅	
土 地 開 發	土 地 資 源	土 地 增 值 稅	土 地 廟	土 地 標 售	土 地 證	土 灰 色	土 耳 其	
土 耳 其 人	土 耳 其 語	土 色	土 坑	土 坎	土 改	土 牢	土 豆	
土 味	土 坡	土 性	土 法	土 法 上 馬	土 炕	土 城	土 城 市	
土 建	土 政 策	土 星	土 洋 結 合	土 皇 帝	土 風 舞	土 匪	土 家	
土 庫 曼	土 庫 鎮	土 氣	土 特	土 特 品	土 特 產	土 紙	土 堆	
土 專 家	土 崩 瓦 解	土 崩 魚 爛	土 崗	土 族	土 產	土 貨	土 陶	
土 窖	土 腔	土 著	土 著 居 民	土 階 茅 屋	土 階 茅 茨	土 黃	土 黃 色	
土 塊	土 腥	土 葬	土 裡 土 氣	土 話	土 管	土 製	土 語	
土 豪	土 豪 劣 紳	土 銀	土 墩	土 層	土 質	土 辦 法	土 頭 土 腦	
土 龍 芻 狗	土 牆	土 糞	土 雞 瓦 犬	土 藥	土 壤	土 壤 型	土 壤 細 流	
土 壤 學	土 礦	土 霸	土 鱉	土 黴 素	土 坯	士 人	士 大 夫	
士 女	士 可 殺 不 可 辱	士 民	士 死 知 己	士 兵	士 卒	士 官	士 林 紙 業	
士 林 區	士 林 電 機	士 氣	士 紳	士 飽 馬 騰	夕 拾	夕 惕 若 厲	夕 陽	
夕 陽 工 業	夕 煙	夕 照	夕 幕	大 一	大 一 些	大 丁 草	大 二	
大 人	大 人 先 生	大 人 物	大 人 虎 變	大 人 國	大 刀	大 刀 闊 斧	大 力	
大 力 士	大 力 支 持	大 力 加 強	大 力 神	大 力 推 廣	大 力 提 高	大 力 發 展	大 力 開 展	
大 三	大 三 元	大 丈 夫	大 丸 藥	大 凡	大 千	大 千 世 界	大 口	
大 口 瓶	大 大	大 大 小 小	大 大 方 方	大 大 咧 咧	大 大 建 設	大 大 高 於	大 小	
大 小 不 一	大 小 不 等	大 小 相 當	大 山	大 山 小 山	大 山 洞	大 山 電 線	大 川	
大 已	大 干	大 干 物 議	大 弓	大 才 小 用	大 不	大 不 一 樣	大 不 了	
大 不 列 顛	大 不 如 前	大 不 相 同	大 中 企 業	大 中 型	大 中 型 項 目	大 中 城 市	大 中 學 校	
大 中 鋼 鐵	大 五 碼	大 仁 大 義	大 元 帥	大 內	大 公	大 公 報	大 公 無 私	
大 分 子	大 化	大 天 使	大 天 幕	大 夫	大 少 爺	大 巴	大 戶	
大 手	大 手 大 腳	大 方	大 方 之 家	大 方 向	大 日 建 設	大 月	大 木 片	
大 比	大 毛	大 水	大 火	大 火 災	大 父	大 片	大 牙	
大 王	大 主 教	大 仙	大 出	大 出 風 頭	大 加	大 功	大 功 告 成	
大 功 率	大 功 畢 成	大 包	大 包 大 攬	大 包 干	大 半	大 半 截	大 半 輩 子	
大 卡	大 可 不 必	大 司 馬	大 叫	大 台 北	大 四	大 失	大 失 人 望	
大 失 所 望	大 失 敗	大 巧 若 拙	大 打 出 手	大 本	大 本 大 宗	大 本 營	大 札	
大 民 主	大 民 族 主 義	大 用	大 田 作 物	大 田 精 密	大 甲 鎮	大 白	大 白 於 天 下	
大 白 菜	大 白 鼠	大 石 塊	大 伙	大 全	大 刑	大 匠 不 斫	大 印	
大 吉	大 吉 大 利	大 同	大 同 小 異	大 同 公 司	大 同 地 區	大 同 思 想	大 同 鄉	
大 名	大 名 鼎 鼎	大 合 唱	大 吃	大 吃 一 驚	大 吃 大 喝	大 地	大 地 回 春	
大 地 測 量	大 多	大 多 功 能	大 多 數	大 多 數 人	大 多 數 情 況 下	大 奸 似 忠	大 好	
大 好 形 勢	大 好 事	大 好 時 光	大 字	大 字 報	大 宇 宙	大 宇 紡 織	大 宅 邸	
大 安 銀 行	大 帆 船	大 年	大 年 夜	大 年 初 一	大 忙	大 忙 人	大 成	
大 成 功	大 成 報	大 曲	大 有	大 有 人 在	大 有 文 章	大 有 可 為	大 有 可 觀	
大 有 好 轉	大 有 作 為	大 有 希 望	大 有 益 處	大 有 逕 庭	大 有 裨 益	大 汗	大 江	
大 百 科 全 書	大 米	大 老	大 老 粗	大 老 闆	大 考	大 而	大 而 化 之	
大 而 言 之	大 而 無 當	大 耳	大 臣	大 自 然	大 衣	大 衣 箱	大 西 北	
大 西 洋	大 西 洋 地 區	大 西 洋 聯 盟	大 亨	大 佛	大 佐	大 作	大 伯	
大 兵	大 兵 團	大 冶	大 別 山	大 君 主	大 吹	大 吹 大 擂	大 吹 法 螺	
大 吵 大 鬧	大 含 細 入	大 局	大 弟	大 形	大 忌	大 志	大 志 若 愚	
大 快 人 心	大 把	大 批	大 批 量	大 抓	大 旱	大 旱 望 雲 霓	大 旱 雲 霓	
大 材 小 用	大 村 鄉	大 杖 則 走 小 杖 則 受	大 步	大 步 流 星	大 沙 漠	大 災	大 災 之 年	
大 災 難	大 牢	大 男 大 女	大 男 子 主 義	大 男 小 女	大 系 統	大 肚	大 肚 子	
大 言 不 慚	大 言 相 駭	大 豆	大 足 石 窟	大 車	大 車 以 載	大 里 市	大 阪	
大 事	大 事 不 糊 塗	大 事 去 矣	大 事 年 表	大 事 紀	大 事 記	大 亞 電 纜	大 使	
大 使 館	大 侃	大 典	大 協 作	大 叔	大 受	大 受 歡 迎	大 呼 小 叫	
大 和	大 姑 娘	大 姐	大 姓	大 宗	大 官	大 店	大 房	
大 拇 指	大 抵	大 放 光 明	大 放 異 彩	大 放 厥 詞	大 放 悲 聲	大 斧	大 於	
大 東 紡 織	大 林 鎮	大 杯	大 武	大 河	大 法	大 法 小 廉	大 法 官	
大 油	大 沿	大 沿 帽	大 治	大 玩	大 直 若 屈	大 社	大 花 瓶	
大 門	大 門 口	大 門 柱	大 雨	大 雨 如 注	大 雨 特 報	大 雨 傾 盆	大 信 證 券	
大 便	大 俠	大 前 提	大 前 題	大 勇	大 勇 若 怯	大 型	大 型 企 業	
大 型 項 目	大 型 機	大 城 市	大 姨	大 威 廉 絲	大 客 車	大 屏 幕	大 帥	
大 度	大 度 汪 洋	大 度 豁 達	大 建	大 後 方	大 怒	大 指	大 括 弧	
大 政	大 政 方 針	大 春	大 昭 寺	大 是 大 非	大 段	大 洋	大 洋 彼 岸	
大 洋 洲	大 洋 洲 人	大 洋 間	大 洋 塑 膠	大 洲	大 洪 水	大 流 星	大 洞	
大 洞 穴	大 為	大 為 不 滿	大 為 吃 驚	大 為 改 觀	大 為 激 動	大 為 驚 異	大 炮	
大 牲 畜	大 盆	大 相 逕 庭	大 砍 刀	大 秋	大 秋 作 物	大 紅	大 紅 大 紫	
大 約	大 胡	大 胡 蜂	大 致	大 致 說 來	大 要	大 計	大 軍	
大 限	大 面	大 面 紗	大 面 積	大 革 命	大 音 階	大 風	大 風 大 浪	
大 風 暴	大 飛 躍	大 乘	大 個	大 個 子	大 修	大 哥	大 哥 大	
大 哭	大 員	大 埔	大 套	大 娘	大 家	大 家 風 範	大 家 庭	
大 宴 會	大 展	大 展 宏 圖	大 島	大 師	大 師 傅	大 庭 廣 眾	大 恭 化 學	
大 恩	大 恩 大 德	大 悟	大 悅	大 捆	大 挫 折	大 料	大 書	
大 書 特 書	大 校	大 案	大 案 要 案	大 桅 帆	大 氣	大 氣 光	大 氣 污 染	
大 氣 科 學	大 氣 候	大 氣 圈	大 氣 層	大 氣 磅 礡	大 氣 學	大 氣 壓	大 浪	
大 海	大 海 撈 針	大 海 龜	大 班	大 病	大 破	大 破 迷 關	大 破 壞	
大 笑	大 笑 話	大 笑 聲	大 荒	大 草 原	大 財 主	大 起 大 落	大 辱	
大 逆	大 逆 不 道	大 逆 無 道	大 酒 杯	大 酒 宴	大 酒 瓶	大 院	大 馬	
大 馬 士 革	大 馬 金 刀	大 骨 節 病	大 做	大 做 文 章	大 剪 刀	大 副	大 動	
大 動 干 戈	大 動 肝 火	大 動 脈	大 區	大 問 題	大 國	大 國 沙 文 主 義	大 堆	
大 堆 棧	大 埤 鄉	大 堂	大 尉	大 專	大 專 生	大 專 院 校	大 將	
大 將 軍	大 屠 殺	大 帳 幕	大 帳 篷	大 庸	大 張 旗 鼓	大 張 撻 伐	大 張 聲 勢	
大 得	大 得 以	大 患	大 捷	大 掃 除	大 排 檔	大 教 堂	大 敗	
大 族	大 旋 渦	大 梁	大 桶	大 殺 風 景	大 混 亂	大 烹 五 鼎	大 理	
大 理 石	大 理 高 中	大 理 國 中	大 略	大 眾	大 眾 化	大 眾 文 學	大 眾 媒 介	
大 眾 傳 播	大 眾 電 腦	大 眾 銀 行	大 眼	大 眼 睛	大 粒	大 統	大 統 益	
大 脖 子 病	大 船	大 莊 園	大 處	大 處 著 眼	大 處 落 墨	大 袋	大 規 模	
大 規 模 集 成 電 路	大 貨 車	大 赦	大 通	大 連	大 逛	大 部	大 部 分	
大 部 分 地 區	大 部 份	大 部 地 區	大 部 頭	大 都	大 都 市	大 都 市 建	大 都 有	
大 都 會	大 陸	大 陸 工 程	大 陸 同 胞	大 陸 地 區	大 陸 性	大 陸 性 氣 候	大 陸 股 市	
大 陸 架	大 陸 間	大 陸 職 籃	大 雪	大 魚	大 鳥	大 麥	大 麻	
大 麻 子	大 傢 伙 兒	大 勝	大 喊	大 喊 大 叫	大 喝	大 喝 一 聲	大 喜	
大 喜 過 望	大 堤	大 壺	大 媒	大 寒	大 富 翁	大 富 豪	大 幅	
大 幅 度	大 循 環	大 惑	大 惑 不 解	大 悲	大 提	大 提 倡	大 提 琴	
大 提 琴 手	大 提 琴 家	大 暑	大 智	大 智 若 愚	大 棗	大 棒	大 款	
大 港	大 渡 河	大 湖	大 湖 鄉	大 無 畏	大 牌	大 猩 猩	大 發	
大 發 宏 論	大 發 慈 悲	大 發 雷 霆	大 等 高 線	大 筆	大 筆 一 揮	大 筆 如 椽	大 筆 錢	
大 華 金 屬	大 華 建 設	大 華 證 券	大 菜	大 街	大 街 小 巷	大 象	大 買 家	
大 跌	大 軸	大 進 化	大 量	大 量 生 產	大 鈔	大 開 方 便 之 門	大 開 眼 界	
大 開 綠 燈	大 隊	大 雁	大 雅	大 雅 君 子	大 項	大 順	大 黃	
大 黃 魚	大 黃 蜂	大 傷 腦 筋	大 傻 瓜	大 勢	大 勢 已 去	大 勢 所 趨	大 園	
大 塊	大 塊 文 章	大 塊 頭	大 媽	大 嫂	大 廈	大 廈 將 傾	大 廈 棟 樑	
大 愚 不 靈	大 意	大 慈 大 悲	大 搞	大 搞 特 搞	大 搖 大 擺	大 新	大 會	
大 會 堂	大 業	大 楷	大 概	大 概 是	大 殿	大 溪	大 溪 地	
大 溪 鎮	大 煙	大 煙 囪	大 煞 風 景	大 爺	大 碗	大 節	大 義	
大 義 滅 親	大 義 凜 然	大 群	大 聖	大 肆	大 肆 鼓 噪	大 腸	大 腸 炎	
大 腸 桿 菌	大 腸 菌	大 腳	大 腹 便 便	大 腦	大 腦 皮 層	大 舅	大 葉 桉	
大 號	大 解	大 話	大 路	大 路 貨	大 農 場	大 農 園	大 運 河	
大 道	大 道 理	大 過	大 閘 蟹	大 雷 雨	大 飽 眼 福	大 鼓	大 團 結	
大 團 圓	大 夥	大 夥 兒	大 夢 初 醒	大 寨	大 徹 大 悟	大 旗	大 榮 貨 運	
大 槍	大 槌	大 演 說	大 漩 渦	大 漠	大 漢	大 漢 建 設	大 滿 貫	
大 滿 貫 賽	大 澈 大 悟	大 熊 貓	大 獄	大 福 不 再	大 禍	大 禍 臨 頭	大 端	
大 管	大 綱	大 聚 會	大 腿	大 腿 骨	大 蒜	大 蒜 似	大 褂	
大 餅	大 鳴 大 放	大 鼻 子	大 億	大 嘴	大 增	大 寮	大 寮 鄉	
大 寫	大 寫 字 母	大 廚	大 廠	大 德	大 慶	大 敵	大 敵 當 前	
大 數	大 樣	大 模 大 樣	大 模 型	大 樓	大 毅 科 技	大 潮	大 潤 發	
大 獎	大 獎 章	大 獎 牌	大 獎 賽	大 瘟 熱	大 盤 子	大 盤 分 析	大 箱	
大 篆	大 罵	大 罷 工	大 蔥	大 蝦	大 衛	大 衛 鮑 伊	大 談	
大 課	大 調	大 調 動	大 論	大 賢	大 賢 虎 變	大 踏 步	大 醇 小 疵	
大 醉	大 震 盪	大 霉	大 駕	大 鬧	大 魯 閣	大 儒	大 噪	
大 器	大 器 晚 成	大 學	大 學 士	大 學 生	大 學 間	大 戰	大 戰 略	
大 操 大 辦	大 樹	大 樹 將 軍	大 樹 鄉	大 橋	大 氅	大 澤 隆 夫	大 穎 企 業	
大 興	大 興 土 木	大 興 安 嶺	大 辦	大 選	大 錯	大 錯 特 錯	大 錯 誤	
大 錢	大 頭	大 頭 釘	大 頭 針	大 頭 菜	大 餐	大 壑	大 戲	
大 檢 查	大 獲	大 獲 全 勝	大 糞	大 總 統	大 聲	大 聲 一 點	大 聲 叫	
大 聲 疾 呼	大 聲 笑	大 聲 說	大 聲 點	大 聲 嚷	大 聯 盟	大 膽	大 膽 妄 為	
大 舉	大 講	大 謊	大 賺	大 賽	大 趨 勢	大 鍵 琴	大 鍋	
大 鍋 菜	大 鍋 飯	大 隱 朝 市	大 叢 林	大 嬸	大 擺	大 瀑 布	大 禮	
大 禮 堂	大 藏	大 蟲	大 謬	大 謬 不 然	大 轉 變	大 雜 院	大 雜 燴	
大 額	大 題 小 作	大 顎	大 襟	大 難	大 難 不 死	大 難 臨 頭	大 類	
大 嚷	大 嚼	大 懸	大 蘇 打	大 鐘	大 饑	大 騰	大 騰 電 子	
大 騷 亂	大 齡	大 齡 青 年	大 躍 進	大 轟	大 轟 大 嗡	大 辯 不 言	大 辯 若 訥	
大 霸 電 子	大 權	大 權 在 握	大 權 旁 落	大 權 獨 攬	大 變	大 變 革	大 變 動	
大 顯 身 手	大 顯 威 風	大 顯 神 通	大 驚	大 驚 小 怪	大 驚 失 色	大 體	大 體 上	
大 體 而 言	大 體 相 當	大 體 說 來	大 壩	大 廳	大 觀	大 觀 園	大 狒 狒	
大 輅 椎 輪	大 纛 高 牙	女 人	女 人 家	女 人 氣	女 士	女 士 們	女 大 十 八 變	
女 大 不 中 留	女 大 使	女 大 須 嫁	女 大 難 留	女 子	女 子 高 球 公 開 賽	女 子 單 打	女 工	
女 工 頭	女 中	女 中 丈 夫	女 中 堯 舜	女 中 豪 傑	女 友	女 方	女 王	
女 王 般	女 王 國	女 主	女 主 人	女 主 角	女 主 席	女 司 機	女 外 套	
女 奴	女 奴 隸	女 巨 人	女 市 長	女 生	女 生 外 向	女 用	女 兇 手	
女 同 志	女 名	女 色	女 伴	女 伯 爵	女 低 音	女 兵	女 妖	
女 妖 魔	女 巫	女 扮 男 裝	女 沙 皇	女 足 隊	女 車	女 侍	女 兒	
女 官	女 店 員	女 怪	女 性	女 性 化	女 性 名	女 性 荷 爾 蒙	女 性 間	
女 房 東	女 招 待	女 服	女 服 務 員	女 朋 友	女 牧 師	女 的	女 者	
女 長 鬚 嫁	女 門 房	女 門 徒	女 青 年	女 侯 爵	女 便 袍	女 城 主	女 娃	
女 孩	女 孩 子	女 孩 子 家	女 孩 兒	女 帝	女 待	女 星	女 流	
女 皇	女 看 守	女 英 雄	女 英 雌	女 衫	女 貞	女 郎	女 家	
女 家 長	女 師	女 座	女 徒	女 捕 手	女 校	女 校 長	女 海 神	
女 真	女 祖 先	女 神	女 院	女 高 音	女 售	女 將	女 庵	
女 探	女 排	女 捨	女 教 師	女 眷	女 袍	女 單	女 婿	
女 帽	女 帽 類	女 廁	女 廁 所	女 畫 家	女 發	女 超 人	女 隊	
女 黑 人	女 傭	女 傭 人	女 幹 部	女 業 主	女 經 理	女 裙	女 裙 釵	
女 裝	女 詩 人	女 運	女 僕	女 像 柱	女 歌	女 歌 手	女 歌 唱 家	
女 演 員	女 監 工	女 管 家	女 誘	女 貌	女 貌 郎 才	女 領	女 樣	
女 編 輯	女 調	女 鞋	女 儐 相	女 學 生	女 學 者	女 導 演	女 褲	
女 親 屬	女 雕	女 嬰	女 總 督	女 聲	女 嚮 導	女 獵 人	女 獵 師	
女 織 男 耕	女 醫 生	女 騎 手	女 騎 師	女 騙 徒	女 籃	女 議 長	女 警	
女 警 們	女 警 察	女 魔	女 權	女 襯 衣	女 襯 衫	子 女	子 女 玉 帛	
子 女 教 育	子 子 孫 孫	子 丑 寅 卯	子 不 語 怪	子 公 司	子 午	子 午 卯 酉	子 午 圈	
子 午 線	子 曰 詩 雲	子 代	子 句	子 民	子 目	子 目 錄	子 多	
子 串	子 弟	子 弟 兵	子 系 統	子 兒	子 函 數	子 夜	子 夜 歌	
子 房	子 為 父 隱	子 孫	子 孫 後 代	子 宮	子 宮 內	子 宮 內 膜 異 位 症	子 宮 外	
子 宮 炎	子 宮 病	子 宮 學	子 宮 頸	子 宮 擴 刮 術	子 時	子 書	子 畜	
子 粒	子 設 備	子 棉	子 程 序	子 虛 烏 有	子 集	子 集 合	子 項	
子 嗣	子 群	子 葉	子 蜂	子 實	子 層	子 彈	子 彈 夾	
子 彈 帶	子 爵	子 雞	子 類	子 囊	孑 孓	孑 然	孑 然 一 身	
孑 然 無 依	寸 口	寸 土	寸 土 不 讓	寸 土 尺 地	寸 土 必 爭	寸 心	寸 木 岑 樓	
寸 地 尺 天	寸 有 所 長	寸 兵 尺 鐵	寸 步	寸 步 不 離	寸 步 不 讓	寸 步 難 行	寸 步 難 移	
寸 男 尺 女	寸 函	寸 金 難 買 寸 光 陰	寸 長 尺 短	寸 草	寸 草 不 生	寸 草 不 留	寸 草 春 暉	
寸 揩	寸 絲 不 掛	寸 善 片 長	寸 陽 尺 璧	寸 陽 若 歲	寸 楷	寸 積 銖 累	寸 頭	
寸 鐵	小 九 九	小 了	小 人	小 人 物	小 人 國	小 人 得 志	小 刀	
小 丸	小 丸 藥	小 勺	小 口	小 女	小 女 子	小 女 孩	小 子	
小 小	小 小 說	小 山	小 山 丘	小 山 羊	小 川	小 工	小 工 廠	
小 干	小 丑	小 丑 跳 梁	小 不 忍 則 亂 大 謀	小 不 點 兒	小 五 金	小 分 枝	小 分 隊	
小 反 對	小 天 平	小 天 地	小 天 使	小 天 鵝	小 孔	小 巴	小 心	
小 心 眼 兒	小 心 翼 翼	小 心 點	小 心 謹 慎	小 戶	小 手	小 手 小 腳	小 手 工 業 者	
小 手 鼓	小 斗 篷	小 日 子	小 月	小 木 材	小 木 槌	小 毛 病	小 水	
小 火	小 火 花	小 片	小 牛	小 王 子	小 丘	小 兄 弟	小 冊	
小 冊 子	小 包	小 半	小 可	小 叮 噹	小 叫	小 巧	小 巧 玲 瓏	
小 市 民	小 布	小 布 袋	小 平 房	小 打 小 鬧	小 本	小 本 生 意	小 本 經 營	
小 母 雞	小 民	小 生	小 生 產	小 生 產 者	小 生 意	小 白 兔	小 白 菜	
小 白 臉	小 皮 包	小 石	小 石 子	小 穴	小 伙	小 伙 子	小 份	
小 名	小 合 唱	小 吃	小 如	小 字	小 字 輩	小 宇 宙	小 尖 塔	
小 年	小 成	小 曲	小 有	小 池	小 百 貨	小 米	小 羊	
小 羊 皮	小 羊 肉	小 羊 兒	小 老 婆	小 考	小 而	小 而 全	小 舟	
小 住	小 住 所	小 佃 農	小 兵	小 別	小 坑	小 妞	小 妖	
小 妖 精	小 巫 見 大 巫	小 床	小 弟	小 弟 弟	小 我	小 把	小 批	
小 束	小 束 狀	小 村	小 杖 則 受 大 杖 則 走	小 步	小 步 舞 曲	小 沙 丘	小 沙 彌	
小 汽 車	小 灶	小 災 難	小 男	小 男 孩	小 肚 雞 腸	小 豆	小 豆 子	
小 車	小 車 站	小 乖	小 事	小 事 一 樁	小 事 件	小 些	小 兔	
小 兒	小 兒 科	小 兒 麻 痺 症	小 兒 語	小 兩	小 到	小 卒	小 叔	
小 受 大 走	小 和 尚	小 夜 曲	小 妹	小 姑	小 姑 娘	小 姐	小 宗	
小 官	小 官 僚	小 屈 大 伸	小 店	小 往 大 來	小 忠 小 信	小 房	小 房 子	
小 房 屋	小 房 間	小 於	小 明 星	小 朋 友	小 東 西	小 枝	小 杯	
小 枉 大 直	小 河	小 波 動	小 炒	小 爭 吵	小 爭 執	小 爭 論	小 物 件	
小 物 體	小 狗	小 玩	小 玩 意	小 的	小 者	小 臥 室	小 舍	
小 花	小 花 飾	小 金	小 門	小 雨	小 青 年	小 亭	小 便	
小 便 宜	小 便 所	小 保 姆	小 前 提	小 則	小 咬	小 品	小 品 文	
小 型	小 型 化	小 型 報	小 型 機	小 城	小 城 市	小 奏	小 姨	
小 威 廉 絲	小 孩	小 孩 子	小 孩 似	小 孩 兒	小 客 店	小 屋	小 屋 子	
小 巷	小 扁 豆	小 指	小 春	小 春 作 物	小 柱	小 洋 蔥	小 流 氓	
小 洞	小 盆	小 看	小 茅 屋	小 計	小 風 琴	小 首 飾	小 香 袋	
小 倆 口	小 個	小 修	小 哥	小 套 房	小 娘	小 家 庭	小 家 碧 玉	
小 容 器	小 峽 谷	小 島	小 差	小 徑	小 恩	小 捆	小 旅 館	
小 時	小 時 了 了	小 時 候	小 書	小 桌	小 氣	小 氣 候	小 氣 鬼	
小 浪	小 海 雀	小 海 灣	小 班	小 珠	小 病	小 真 豫	小 神 仙	
小 站	小 粉	小 草	小 茴 香	小 茶 杯	小 酒	小 酒 館	小 馬	
小 鬼	小 偷	小 偷 小 摸	小 偷 兒	小 動 作	小 區	小 區 域	小 商 人	
小 商 小 販	小 商 品	小 商 販	小 圈	小 圈 子	小 圈 環	小 國	小 國 王	
小 國 寡 民	小 堅 果	小 堆	小 將	小 帳	小 康	小 康 水 平	小 康 生 活	
小 張	小 彬 彬	小 桶	小 淵 惠 三	小 淘 氣	小 球	小 球 性	小 球 體	
小 瓶	小 甜 點	小 產	小 盒	小 盒 子	小 眼 薄 皮	小 票	小 粒	
小 細 胞	小 組	小 組 長	小 組 第 一	小 組 會	小 船	小 船 室	小 處 著 手	
小 蛇	小 袋	小 袋 鼠	小 規 模	小 販	小 趾	小 部 分	小 都 市	
小 雪	小 魚	小 鳥	小 鹿	小 麥	小 傢 伙	小 喜	小 喜 劇	
小 喇 叭	小 場	小 報	小 堡 壘	小 寒	小 循 環	小 惠	小 提	
小 提 琴	小 提 琴 手	小 提 琴 家	小 提 箱	小 暑	小 湖	小 發 明	小 稅	
小 窗	小 童	小 筆	小 結	小 菜	小 街	小 街 突	小 費	
小 跑	小 跑 步	小 量	小 鈔	小 隊	小 隊 長	小 集 團	小 項	
小 項 目	小 飯 店	小 飯 館	小 飲	小 黃 瓜	小 傳	小 嗓	小 塊	
小 塊 土	小 廉 大 法	小 廉 曲 謹	小 意 思	小 業 主	小 楷	小 溝	小 溪	
小 溪 流	小 照	小 獅 子	小 節	小 群	小 腸	小 腳	小 腹	
小 腦	小 腦 萎 縮 症	小 舅	小 艇	小 葉	小 葛	小 葛 瑞 菲	小 董	
小 號	小 補	小 解	小 試	小 試 鋒 芒	小 話	小 資 產 階 級	小 路	
小 農	小 農 場	小 農 經 濟	小 道	小 道 具	小 道 消 息	小 過	小 鉤	
小 鉤 子	小 鈴 當	小 隔 間	小 鼓	小 團	小 夥 子	小 寨	小 寢 室	
小 旗	小 槍 眼	小 歌 劇	小 滴	小 滿	小 熊	小 熊 隊	小 睡	
小 碟	小 種	小 窩	小 算 盤	小 腿	小 腿 側	小 褂	小 說	
小 說 家	小 隙 沉 舟	小 餅 乾	小 嘴	小 寫	小 寫 字	小 寫 體	小 廚 房	
小 廝	小 廠	小 彈 丸	小 撮	小 數	小 數 點	小 樣	小 標 題	
小 樓	小 獎 章	小 盤	小 箱	小 篆	小 膜	小 蔥	小 蝦	
小 衝 突	小 調	小 豬	小 賬	小 賣 部	小 輩	小 鞋	小 駐	
小 齒 輪	小 器	小 器 易 盈	小 學	小 學 生	小 學 校	小 學 教 師	小 憩	
小 樹	小 樹 枝	小 橋	小 機 槍	小 磚	小 貓	小 貓 似	小 錯	
小 錢	小 雕 像	小 靜 脈	小 頭	小 鴨	小 龍	小 環	小 瞧	
小 聲	小 聰 明	小 聯 盟	小 臉	小 虧	小 謊	小 鍵 盤	小 鍋	
小 顆	小 點	小 點 心	小 擺 設	小 瀑 布	小 禮	小 禮 帽	小 蟲	
小 鎮	小 雞	小 額	小 題 大 作	小 題 大 做	小 黠 大 癡	小 壞 蛋	小 懲 大 誡	
小 繩 索	小 臘 燭	小 轎 車	小 寶	小 辮	小 辮 子	小 辮 兒	小 艦 隊	
小 艦 艇	小 蘇 打	小 觸 角	小 麵 包	小 灌 木	小 攤	小 變	小 鷹	
小 覷	尸 位 素 餐	山 人	山 下	山 上	山 上 鄉	山 口	山 山 水 水	
山 川	山 中	山 木	山 水	山 水 畫	山 火	山 丘	山 凹	
山 包	山 民	山 田	山 石	山 地	山 地 人	山 地 同 胞	山 竹	
山 羊	山 羊 皮	山 羊 似	山 羊 座	山 羊 絨	山 色	山 西	山 西 省	
山 形	山 形 牆	山 村	山 芋	山 谷	山 那 邊	山 呼 海 嘯	山 坡	
山 夜	山 姆	山 居	山 岡	山 明 水 秀	山 東	山 東 省	山 果	
山 林	山 河	山 河 易 改 本 性 難 移	山 花	山 長 水 遠	山 門	山 雨 欲 來 風 滿 樓	山 前	
山 南	山 南 海 北	山 城	山 後	山 泉	山 洪	山 洪 暴 發	山 洞	
山 炮	山 珍	山 珍 海 味	山 珍 海 錯	山 胡 桃	山 風	山 峰	山 徑	
山 根	山 桃	山 海 經	山 海 關	山 神	山 脈	山 脈 間	山 脊	
山 草	山 茶	山 高	山 高 水 低	山 高 水 長	山 側	山 區	山 崖	
山 崩	山 崩 地 坼	山 崩 地 陷	山 崩 地 裂	山 崩 鐘 應	山 崗	山 帶	山 梁	
山 清 水 秀	山 莊	山 貨	山 野	山 陵	山 陰	山 雀	山 雀 類	
山 頂	山 鳥 類	山 普 拉 斯	山 棲 谷 飲	山 鄉	山 間	山 隆 通 運	山 勢	
山 塔 那	山 搖 地 動	山 楊	山 溝	山 盟 海 誓	山 群	山 腰	山 腳	
山 腹	山 葡 萄	山 裡	山 裡 紅	山 賊	山 路	山 道	山 鼠 類	
山 寨	山 歌	山 窪	山 窩	山 窩 窩	山 遙 水 遠	山 澗	山 窮 水 盡	
山 豬	山 貓	山 險	山 雕	山 頭	山 頹 木 壞	山 餚 野 蔌	山 壑	
山 嶺	山 嶽	山 牆	山 鎮	山 雞	山 雞 舞 鏡	山 藥	山 顛	
山 麓	山 巔	山 巒	山 巖	山 坳	山 楂	川 江	川 沙	
川 貝	川 流	川 流 不 息	川 軍	川 飛 工 業	川 島 茉 樹 代	川 菜	川 畸	
川 芎	工 人	工 人 文 化 宮	工 人 日 報	工 人 們	工 人 階 級	工 人 運 動	工 人 黨	
工 力 悉 敵	工 工 整 整	工 分	工 友	工 夫	工 夫 不 負 有 心 人	工 日	工 巧	
工 布 江 達	工 本	工 本 費	工 交	工 休	工 休 日	工 件	工 匠	
工 地	工 字 鋼	工 作	工 作 人 員	工 作 上	工 作 中	工 作 日	工 作 台	
工 作 件	工 作 地	工 作 狂	工 作 周	工 作 房	工 作 服	工 作 者	工 作 室	
工 作 面	工 作 站	工 作 區	工 作 組	工 作 袋	工 作 場	工 作 等	工 作 量	
工 作 隊	工 作 鞋	工 作 學	工 作 簿	工 作 證	工 余	工 兵	工 序	
工 役	工 車	工 事	工 具	工 具 包	工 具 架	工 具 書	工 具 箱	
工 具 機	工 具 鋼	工 具 欄	工 制	工 委	工 房	工 所	工 於 心 計	
工 況	工 長	工 信 工 程	工 宣 隊	工 段	工 活	工 研 院	工 科	
工 值	工 套	工 效	工 料	工 時	工 務 局	工 區	工 商	
工 商 人 員	工 商 戶	工 商 企 業	工 商 行 政	工 商 行 政 管 理 局	工 商 局	工 商 協 進 會	工 商 界	
工 商 界 人 士	工 商 會	工 商 業	工 商 管 理	工 商 綜 合 區	工 商 銀 行	工 商 聯	工 欲 善 其 事	
工 部	工 場	工 場 間	工 期	工 棚	工 程	工 程 兵	工 程 招 標	
工 程 建 設	工 程 師	工 程 處	工 程 設 計	工 程 部	工 程 圍 標	工 程 會	工 程 弊 案	
工 程 學	工 筆	工 筆 畫	工 貿	工 貿 結 合	工 間	工 間 操	工 隊	
工 傷	工 傷 事 故	工 會	工 會 工 作	工 會 組 織	工 會 幹 部	工 業	工 業 化	
工 業 生 產	工 業 用	工 業 用 地	工 業 局	工 業 品	工 業 界	工 業 革 命	工 業 區	
工 業 區 廠 辦	工 業 國	工 業 部	工 業 廳	工 號	工 蜂	工 裝	工 賊	
工 資	工 資 級 別	工 資 高	工 資 單	工 農	工 農 兵	工 農 差 別	工 農 業	
工 農 業 □	工 農 群 眾	工 農 聯 盟	工 運	工 團	工 種	工 價	工 廠	
工 廠 主	工 數	工 潮	工 質	工 學	工 學 院	工 整	工 錢	
工 頭	工 總	工 聯	工 薪	工 繳	工 藝	工 藝 品	工 藝 流 程	
工 藝 美 術	工 藝 學	工 礦	工 礦 企 業	工 黨	工 齡	工 讀	工 讀 生	
工 讀 學 校	己 人	己 內 醯 胺	己 方	己 任	己 有	己 見	己 身	
己 所 不 欲 勿 施 於 人	己 物	己 欲 毋 人	己 欲 毋 施	己 癖	己 饑 己 溺	已 久	已 不	
已 化 膿	已 支 付	已 付	已 去	已 用	已 由	已 交	已 向	
已 在	已 成	已 扣	已 收	已 有	已 死	已 死 者	已 而	
已 佔	已 作	已 冷	已 完	已 完 成	已 更 新	已 決	已 見	
已 見 分 曉	已 到	已 取 得	已 定	已 往	已 征	已 於	已 知	
已 知 數	已 按	已 故	已 是	已 為	已 倒 閉	已 納	已 能	
已 退	已 售	已 婚	已 將	已 得	已 從	已 晚	已 深	
已 被	已 報	已 提	已 無	已 然	已 發	已 發 棄	已 結 婚	
已 開 發	已 亂	已 損 壞	已 極	已 滅	已 經	已 補	已 達	
已 過	已 過 盛	已 預	已 對	已 滿	已 盡	已 與	已 製 成	
已 認 罪	已 認 識	已 領	已 廢	已 撥	已 確 定	已 銷	已 辦	
已 償 付	已 獲	已 縮 水	已 轉	已 繳	已 讀	巳 時	巾 在 江 湖 心 存 魏 闕	
巾 狀	巾 幗	巾 幗 不 讓 鬚 眉	巾 幗 英 雄	干 了	干 下	干 戈	干 戈 載 戢	
干 支	干 兄 弟	干 打 壘	干 休	干 休 所	干 名 采 譽	干 好	干 死	
干 冷	干 吧	干 豆	干 貝	干 制	干 的	干 股	干 係	
干 流	干 卿 何 事	干 料	干 時	干 校	干 涉	干 涉 內 政	干 涉 者	
干 涉 計	干 涉 現 象	干 粉	干 將	干 球	干 球 溫 度	干 啼 濕 哭	干 渠	
干 等	干 結	干 貯	干 雲 蔽 日	干 飯	干 群	干 群 關 係	干 路	
干 酪	干 酪 素	干 預	干 酵 母	干 親	干 鮮 果	干 擾	干 擾 者	
干 擾 素	干 擾 機	干 擾 聲	干 餾	干 臘 腸	干 警	干 躁	干 蠢 事	
干 曬	弋 不 射 宿	弋 者 何 慕	弋 者 何 篡	弋 陽	弓 匠	弓 形	弓 弦	
弓 背	弓 射 手	弓 起	弓 腰	弓 箭	才 人	才 大 難 用	才 女	
才 子	才 子 佳 人	才 不	才 分	才 可	才 有	才 行	才 秀 人 微	
才 使	才 來	才 具	才 怪	才 知 自	才 者	才 俊	才 思	
才 是	才 兼 文 武	才 氣	才 氣 無 雙	才 能	才 高 八 斗	才 高 行 厚	才 高 行 潔	
才 高 意 廣	才 將	才 望	才 略	才 疏 志 大	才 疏 計 拙	才 疏 意 廣	才 疏 德 薄	
才 疏 學 淺	才 被	才 貫 二 酉	才 智	才 短 氣 粗	才 華	才 華 出 眾	才 華 奔 放	
才 華 橫 溢	才 幹	才 會	才 過 屈 宋	才 對	才 盡	才 盡 其 用	才 算	
才 貌	才 貌 雙 全	才 輕 德 厚	才 廣 妨 身	才 德	才 德 兼 備	才 蔽 識 淺	才 學	
才 學 兼 優	才 藝	才 藝 競 賽	才 識	丑 不	丑 角	丑 相	丑 時	
丑 鬼	丑 劇	丑 聲 遠 播	丑 雜	丑 類	丑 類 惡 物	不 一	不 一 而 足	
不 一 定	不 一 律	不 一 致	不 一 般	不 一 會 兒	不 一 樣	不 了	不 了 了 之	
不 二	不 二 法 門	不 二 價	不 人 道	不 入	不 入 虎 穴	不 入 虎 穴 不 得 虎 子	不 入 虎 穴 焉 得 虎 子	
不 入 時 宜	不 入 獸 穴 安 得 獸 子	不 力	不 三 不 四	不 下	不 上	不 上 不 下	不 凡	
不 久	不 久 以 前	不 久 前	不 大	不 大 方	不 大 可 能	不 大 於	不 小	
不 小 心	不 小 於	不 已	不 干	不 干 涉	不 干 膠	不 才	不 不	
不 中	不 中 用	不 中 意	不 丹	不 丹 人	不 丹 亞	不 丹 語	不 予	
不 予 考 慮	不 予 承 認	不 予 重 視	不 予 置 評	不 亢	不 亢 不 卑	不 仁	不 仁 慈	
不 今 不 古	不 介	不 介 意	不 允 許	不 公	不 公 平	不 公 正	不 分	
不 分 大 小	不 分 皂 白	不 分 彼 此	不 分 青 紅 皂 白	不 分 勝 負	不 分 開	不 分 離	不 分 畛 域	
不 切 實 際	不 化	不 匹 配	不 友 好	不 友 善	不 及	不 及 格	不 反 射	
不 太	不 少	不 少 國 家	不 支	不 支 持	不 文	不 文 不 武	不 文 明	
不 文 雅	不 方	不 方 便	不 日	不 日 不 月	不 止	不 止 一 次	不 比	
不 毛	不 毛 之 地	不 主 故 常	不 乏	不 乏 其 人	不 乏 其 例	不 以	不 以 為 恥 反 以 為 榮	
不 以 為 然	不 以 為 意	不 付	不 充 分	不 充 足	不 出	不 出 所 料	不 刊 之 典	
不 刊 之 論	不 加	不 加 分 析	不 加 水	不 加 思 索	不 加 區 別	不 加 渲 染	不 加 虛 飾	
不 加 評 論	不 加 疑 問	不 加 選 擇	不 包 分 配	不 包 括	不 去	不 可	不 可 一 世	
不 可 不	不 可 分	不 可 以	不 可 企 及	不 可 同 日 而 語	不 可 同 年 而 語	不 可 向 邇	不 可 名 狀	
不 可 多 得	不 可 收 拾	不 可 行	不 可 估 量	不 可 否 認	不 可 告 人	不 可 忍 受	不 可 抗 拒	
不 可 改 變	不 可 言 狀	不 可 言 宣	不 可 言 喻	不 可 言 傳	不 可 取	不 可 忽 視	不 可 枚 舉	
不 可 爭 議	不 可 知	不 可 知 論	不 可 阻 擋	不 可 信	不 可 信 任	不 可 侵 犯	不 可 思 議	
不 可 限 量	不 可 原 諒	不 可 容 忍	不 可 捉 摸	不 可 缺	不 可 缺 少	不 可 能	不 可 能 性	
不 可 逆 轉	不 可 偏 廢	不 可 動 搖	不 可 接 受	不 可 救 藥	不 可 教	不 可 理 喻	不 可 終 日	
不 可 勝 言	不 可 勝 計	不 可 勝 數	不 可 測	不 可 開 交	不 可 想 像	不 可 愛	不 可 解	
不 可 遏 止	不 可 逾 越	不 可 預 見	不 可 預 測	不 可 數	不 可 靠	不 可 戰 勝	不 可 磨 滅	
不 可 避 免	不 可 變	不 只	不 外	不 外 人 訓	不 外 人 道	不 外 人 據	不 外 乎	
不 失	不 失 為	不 失 敗	不 失 眾 望	不 孕	不 孕 症	不 巧	不 平	
不 平 凡	不 平 而 鳴	不 平 坦	不 平 則 鳴	不 平 常	不 平 等	不 平 衡	不 平 靜	
不 必	不 必 要	不 打	不 打 不 成 相 識	不 打 不 與 相 識	不 打 自 招	不 正	不 正 之 風	
不 正 式	不 正 直	不 正 派	不 正 常	不 正 當	不 正 確	不 正 確 性	不 民 主	
不 犯	不 甘	不 甘 心	不 甘 示 弱	不 甘 後 人	不 甘 寂 寞	不 甘 落 後	不 甘 雌 伏	
不 甘 願	不 生	不 生 不 死	不 生 育	不 生 產	不 生 ��	不 用	不 用 說	
不 由	不 由 分 說	不 由 自 主	不 由 得	不 白	不 白 之 冤	不 示	不 交	
不 交 叉	不 亦 樂 乎	不 休	不 休 息	不 伏 燒 埋	不 任 職	不 光	不 光 彩	
不 光 滑	不 全	不 共 戴 天	不 再	不 列 頓 人	不 列 顛	不 劣 方 頭	不 吉	
不 吉 利	不 吉 祥	不 同	不 同 凡 響	不 同 於	不 同 情	不 同 意	不 同 意 者	
不 同 種 類	不 同 點	不 向	不 名 一 文	不 名 一 錢	不 名 譽	不 合	不 合 文 法	
不 合 作	不 合 作 者	不 合 作 態 度	不 合 身	不 合 味 口	不 合 宜	不 合 法	不 合 時	
不 合 時 令	不 合 時 宜	不 合 時 機	不 合 格	不 合 情 理	不 合 理	不 合 理 化	不 合 理 制 度	
不 合 規 格	不 合 群	不 合 道 理	不 合 實 際	不 合 算	不 合 語 法	不 合 調	不 合 適	
不 合 諧	不 合 權 宜	不 合 邏 輯	不 吃	不 吃 煙 火 食	不 因	不 因 人 熱	不 因 不 由	
不 回	不 在	不 在 少 數	不 在 乎	不 在 此 列	不 在 其 位 不 謀 其 政	不 在 空	不 在 意	
不 在 話 下	不 多	不 多 見	不 夷 不 惠	不 好	不 好 不 壞	不 好 吃	不 好 看	
不 好 意 思	不 好 戰	不 如	不 如 歸 去	不 存 不 濟	不 存 幻 想	不 存 在	不 守	
不 守 約	不 守 誓	不 安	不 安 份	不 安 全	不 安 其 室	不 安 定	不 安 定 因 素	
不 安 於 位	不 安 寧	不 安 靜	不 尖	不 忙	不 成	不 成 文	不 成 文 法	
不 成 比 例	不 成 功	不 成 形	不 成 角	不 成 型	不 成 話	不 成 樣 子	不 成 熟	
不 成 器	不 成 體 系	不 成 體 統	不 扣	不 收	不 早	不 早 不 晚	不 曲	
不 曲 折	不 有	不 朽	不 死	不 死 不 活	不 死 心	不 灰 心	不 老	
不 老 實	不 老 練	不 考 慮	不 自	不 自 主	不 自 在	不 自 私	不 自 然	
不 自 量	不 自 量 力	不 至	不 至 於	不 血	不 行	不 行 了	不 住	
不 似	不 但	不 但 如 此	不 作	不 低 於	不 免	不 免 一 死	不 冷	
不 冷 不 熱	不 利	不 利 因 素	不 利 作 用	不 利 於	不 刪	不 努 力	不 即 不 離	
不 吝	不 吝 指 教	不 吝 珠 玉	不 吝 惜	不 吭	不 告 而 辭	不 吸 收	不 含	
不 含 糊	不 含 鐵	不 均	不 均 勻	不 均 衡	不 妨	不 妨 一 試	不 妙	
不 妥	不 妥 協	不 孝	不 完	不 完 全	不 完 全 統 計	不 完 備	不 完 善	
不 忘	不 忘 溝 壑	不 忍	不 快	不 快 樂	不 抗 不 卑	不 把	不 批	
不 折 不 扣	不 折 不 撓	不 投	不 改	不 攻	不 攻 自 破	不 求	不 求 上 進	
不 求 甚 解	不 求 聞 達	不 沉	不 決	不 牢	不 肖	不 肖 子 孫	不 育	
不 良	不 良 少 年	不 良 放 款	不 見	不 見 天 日	不 見 圭 角	不 見 得	不 見 棺 材 不 落 淚	
不 見 經 傳	不 言	不 言 下 自 成 行	不 言 不 語	不 言 而 喻	不 言 自 明	不 走	不 走 過 場	
不 足	不 足 之 處	不 足 之 數	不 足 介 意	不 足 以 平 民 憤	不 足 取	不 足 為 奇	不 足 為 慮	
不 足 為 憑	不 足 夠	不 足 掛 齒	不 足 提	不 足 道	不 足 輕 重	不 足 齒 數	不 迂	
不 那 麼	不 防	不 亞 於	不 依	不 佳	不 使	不 使 用 武 力	不 來	
不 來 往	不 具	不 具 名	不 具 備	不 典 型	不 到	不 到 長 城 非 好 漢	不 到 時 候	
不 到 烏 江 不 肯 休	不 到 烏 江 不 盡 頭	不 到 烏 江 心 不 死	不 到 黃 河 不 死 心	不 到 黃 河 心 不 死	不 協	不 協 同	不 協 調	
不 卑 不 亢	不 受	不 受 干 擾	不 受 束 縛	不 受 注 意	不 受 約 束	不 受 重 視	不 受 傷 害	
不 受 影 響	不 受 勸 告	不 受 歡 迎	不 受 歡 迎 的 人	不 和	不 和 悅	不 和 諧	不 和 藹	
不 周	不 咎 既 往	不 坦 白	不 定	不 定 方 程	不 定 式	不 定 形	不 定 根	
不 定 期	不 定 詞	不 宜	不 屈	不 屈 不 撓	不 屈 曲 性	不 屈 服	不 幸	
不 幸 人	不 幸 福	不 忠	不 忠 誠	不 忠 實	不 念	不 念 舊 惡	不 忿	
不 怕	不 怕 官 只 怕 管	不 怕 虎	不 承 認	不 拒	不 抽	不 抵 抗	不 抱	
不 拘	不 拘 一 格	不 拘 小 節	不 拘 形 式	不 拘 束	不 拘 泥	不 拘 細 行	不 拘 儀 式	
不 拘 禮 節	不 放	不 易	不 易 之 論	不 易 對 付	不 易 懂	不 明	不 明 了	
不 明 不 白	不 明 飛 行 物	不 明 朗	不 明 真 相	不 明 淨	不 明 智	不 明 說	不 明 確	
不 明 顯	不 服	不 服 水 土	不 服 氣	不 服 從	不 服 輸	不 果 斷	不 武 裝	
不 注 意	不 沾	不 法	不 法 之 徒	不 法 分 子	不 法 行 為	不 治	不 治 之 症	
不 的 話	不 知	不 知 凡 幾	不 知 不 覺	不 知 去 向	不 知 甘 苦	不 知 名	不 知 好 歹	
不 知 死 活	不 知 足	不 知 所 云	不 知 所 以	不 知 所 指	不 知 所 為	不 知 所 措	不 知 所 終	
不 知 怎 麼	不 知 為 不 知	不 知 為 什 麼	不 知 恥	不 知 悔 改	不 知 高 低	不 知 情	不 知 深 淺	
不 知 進 退	不 知 道	不 知 輕 重	不 知 禮	不 知 舊 裡	不 肥 沃	不 肯	不 表	
不 返	不 近	不 近 人 情	不 長	不 附 著	不 信	不 信 任	不 信 仰	
不 信 神	不 信 神 者	不 便	不 保	不 俗	不 冒 昧	不 前	不 勉 強	
不 厚	不 奏 效	不 威 嚴	不 宣	不 宣 而 戰	不 客 氣	不 很	不 待	
不 徇 私 情	不 思 考	不 急	不 急 之 務	不 急 於	不 恰 當	不 恤	不 拜	
不 按	不 持 久	不 指 人	不 是	不 是 味 兒	不 是 故 意	不 歪	不 流	
不 流 行	不 流 動	不 活	不 活 化 疫 苗	不 活 動	不 活 潑	不 洩 氣	不 為	
不 為 人 知	不 為 己 甚	不 為 已 甚	不 為 五 斗 米 折 腰	不 為 牛 後	不 為 瓦 全	不 為 所 動	不 狡 猾	
不 甚	不 甚 了 了	不 甚 重 要	不 畏	不 畏 強 暴	不 畏 強 禦	不 畏 艱 險	不 畏 懼	
不 省	不 省 人 事	不 相	不 相 上 下	不 相 干	不 相 似	不 相 宜	不 相 信	
不 相 為 謀	不 相 容	不 相 配	不 相 等	不 相 稱	不 相 適 應	不 相 關	不 看	
不 看 僧 面 看 佛 面	不 矜 不 伐	不 矜 細 行	不 祉	不 科 學	不 約	不 約 而 同	不 約 而 合	
不 美	不 美 栗	不 美 觀	不 耐 心	不 耐 煩	不 致	不 致 命	不 致 於	
不 苟	不 苟 言 笑	不 要	不 要 胡 說	不 要 哭	不 要 緊	不 要 臉	不 計	
不 計 其 數	不 計 後 果	不 計 報 酬	不 貞	不 貞 潔	不 負	不 負 眾 望	不 負 責 任	
不 軌	不 迭	不 迫	不 郎 不 秀	不 重	不 重 要	不 重 讀	不 限	
不 限 於 一	不 食 之 地	不 倦	不 值	不 值 一 文	不 值 一 哂	不 值 一 提	不 值 一 錢	
不 值 得	不 值 得 一 提	不 借	不 倒	不 倒 翁	不 俱	不 修	不 修 不 節	
不 修 邊 幅	不 倫	不 倫 不 類	不 兼 容	不 兼 容 性	不 凍	不 准	不 凋 花	
不 哼 不 哈	不 哭	不 害 羞	不 容	不 容 分 說	不 容 分 辨	不 容 忽 視	不 容 易	
不 容 耽 擱	不 容 許	不 容 置 喙	不 容 置 疑	不 容 輕 視	不 屑	不 屑 一 顧	不 屑 做	
不 差	不 差 毫 髮	不 差 毫 釐	不 差 累 黍	不 弱	不 恥	不 恥 下 問	不 恐 懼	
不 恭	不 恭 敬	不 息	不 悟	不 悔 改	不 悅	不 悅 耳	不 拿	
不 拿 薪 水	不 振	不 料	不 時	不 時 之 須	不 時 之 需	不 殷 勤	不 消	
不 消 化	不 留	不 留 心	不 留 神	不 疾 不 徐	不 疲 倦	不 疲 勞	不 真 誠	
不 真 實	不 真 確	不 眠	不 眠 之 夜	不 破	不 破 不 立	不 神 聖	不 笑	
不 純	不 純 潔	不 納	不 能	不 能 不	不 能 分	不 能 同 日 而 語	不 能 自 已	
不 能 自 拔	不 能 按	不 能 挽 回	不 能 夠	不 茶 不 飯	不 虔 誠	不 衰	不 記 名	
不 討	不 起	不 起 作 用	不 起 勁	不 起 眼	不 送	不 配	不 配 合	
不 高	不 高 興	不 乾 不 淨	不 乾 淨	不 停	不 停 止	不 停 頓	不 假	
不 假 思 索	不 做	不 做 作	不 做 事	不 健 全	不 健 康	不 偏	不 偏 不 倚	
不 偏 不 袒	不 務 正 業	不 動	不 動 情	不 動 產	不 動 搖	不 動 聲 色	不 參 加	
不 問	不 問 青 紅 皂 白	不 堅 固	不 堅 定	不 夠	不 夠 格	不 專	不 常	
不 常 見	不 常 常	不 帶	不 帶 偏 見	不 強	不 強 烈	不 強 調	不 得	
不 得 了	不 得 人 心	不 得 已	不 得 不	不 得 而 知	不 得 其 死	不 得 要 領	不 得 當	
不 得 體	不 情 之 情	不 情 之 請	不 情 願	不 惜	不 惜 工 本	不 惟	不 捲 入	
不 接	不 接 受	不 接 近	不 掉	不 捨	不 捨 晝 夜	不 救	不 教	
不 教 而 殺	不 教 而 誅	不 敗	不 敗 之 地	不 旋	不 棄	不 欲	不 清	
不 清 爽	不 清 楚	不 清 潔	不 混 亂	不 深	不 淨	不 爽	不 爽 快	
不 理	不 理 睬	不 理 解	不 現 實	不 甜	不 產	不 祥	不 祥 之 力	
不 祥 之 兆	不 祥 之 物	不 祥 預 兆	不 移	不 第	不 符	不 符 合	不 統 一	
不 細 緻	不 累	不 習 見	不 習 慣	不 脫 線	不 脫 離	不 莊 重	不 被	
不 規 則	不 規 律	不 規 矩	不 許	不 許 可	不 設	不 設 防	不 通	
不 通 人 情	不 通 水 火	不 通 風	不 通 氣	不 通 融	不 連 接	不 連 貫	不 連 續	
不 速 之 客	不 逞 之 徒	不 透	不 透 水	不 透 光	不 透 明	不 透 明 化	不 透 明 性	
不 透 氣	不 透 熱	不 陰 不 陽	不 備	不 勞	不 勞 而 獲	不 勝	不 勝 任	
不 勝 其 煩	不 勝 枚 舉	不 勝 舉	不 啻	不 喝	不 喜	不 喜 愛	不 喜 歡	
不 單	不 堪	不 堪 一 擊	不 堪 入 目	不 堪 入 耳	不 堪 用	不 堪 回 首	不 堪 忍 受	
不 堪 重 負	不 堪 設 想	不 堪 造 就	不 報	不 寒 而 慄	不 富	不 尊 敬	不 尋 常	
不 幾 天	不 復	不 復 存 在	不 惑	不 惑 之 年	不 愉 快	不 揣 冒 昧	不 提	
不 換	不 揚	不 敢	不 敢 告 勞	不 敢 後 人	不 敢 越 雷 池 一 步	不 敢 當	不 散	
不 景 氣	不 智	不 智 之 舉	不 曾	不 期	不 期 而 然	不 期 而 會	不 期 而 遇	
不 欺 暗 室	不 湊 巧	不 減	不 減 弱	不 減 當 年	不 測	不 測 之 禍	不 測 風 雲	
不 渝	不 無	不 無 小 補	不 無 道 理	不 無 關 係	不 然	不 猶 豫	不 痛	
不 痛 不 癢	不 登 大 雅 之 堂	不 發	不 發 火	不 發 亮	不 發 音	不 發 達	不 發 達 地 區	
不 發 達 國 家	不 短	不 等	不 等 式	不 等 於	不 等 號	不 等 價 交 換	不 等 壓	
不 等 邊	不 答 應	不 答 覆	不 結	不 結 果	不 結 塊	不 結 盟	不 結 盟 政 策	
不 結 盟 國 家	不 結 盟 會 議	不 結 實	不 絕	不 絕 如 線	不 絕 如 縷	不 絕 於 耳	不 給	
不 給 予	不 善	不 善 交 際	不 舒	不 舒 服	不 舒 適	不 著	不 著 火	
不 著 邊 際	不 虛 偽	不 費	不 費 力	不 費 吹 灰 之 力	不 貴	不 買	不 超 過	
不 進	不 開	不 間 不 界	不 間 斷	不 雅	不 雅 緻	不 雅 觀	不 順	
不 順 利	不 順 服	不 順 從	不 順 遂	不 須	不 飲 盜 泉	不 亂	不 傲 慢	
不 傳 導	不 僅	不 僅 如 此	不 僅 僅	不 僅 僅 在 於	不 僅 僅 如 此	不 僅 僅 是	不 傻	
不 圓	不 圓 滑	不 塞 不 流 不 止 不 行	不 嫉 妒	不 嫌	不 意	不 慈 悲	不 感	
不 感 興 趣	不 感 謝	不 想	不 愛	不 愛 交 際	不 愛 國	不 愛 說 話	不 惹 人	
不 愁	不 慎	不 慎 重	不 慌 不 忙	不 慌 張	不 愧	不 愧 不 怍	不 愧 屋 漏	
不 搭 調	不 敬	不 敬 神	不 新 奇	不 新 鮮	不 暇	不 會	不 會 有	
不 會 老	不 會 吧	不 會 弄 錯	不 會 飛	不 會 錯	不 溶	不 溶 解	不 滅	
不 溫 不 火	不 溫 暖	不 滑	不 滑 稽	不 準 時	不 準 確	不 煩 惱	不 當	
不 當 人 子	不 當 之 處	不 當 行 為	不 當 真	不 睬	不 禁	不 節 制	不 節 儉	
不 經	不 經 一 事	不 經 之 談	不 經 常	不 經 意	不 經 濟	不 置 可 否	不 署 名	
不 義	不 義 之 財	不 落	不 落 巢 臼	不 落 窠 臼	不 虞	不 虞 之 譽	不 補	
不 裝 訂	不 裡	不 解	不 解 之 緣	不 解 之 謎	不 解 其 意	不 該	不 該 得	
不 詳	不 詳 盡	不 誠 實	不 誠 懇	不 跟	不 道 德	不 遂	不 達 時 務	
不 違 農 時	不 過	不 過 如 此	不 過 如 此 而 已	不 過 爾 爾	不 過 關	不 遑	不 遑 寧 處	
不 飽 和	不 馴	不 馴 服	不 像	不 像 是 真	不 像 話	不 像 樣	不 劃 線	
不 厭	不 厭 求 祥	不 厭 其 祥	不 厭 其 煩	不 厭 其 詳	不 嘛	不 圖	不 奪 農 時	
不 寧	不 實	不 實 之 處	不 實 之 詞	不 實 用	不 實 際	不 對	不 對 的	
不 對 稱	不 對 頭	不 徹 底	不 慣	不 暢	不 榮 譽	不 漏	不 漏 水	
不 漂 白	不 漂 亮	不 滿	不 滿 足	不 滿 者	不 滿 現 狀	不 滿 意	不 滿 意 者	
不 滲	不 疑	不 盡	不 盡 人 意	不 盡 相 同	不 盡 然	不 睡	不 睡 眠	
不 稱	不 稱 職	不 端	不 端 莊	不 管	不 管 □	不 管 三 七 二 十 一	不 管 不 顧	
不 管 什 麼	不 管 如 何	不 管 怎 麼 說	不 管 怎 樣	不 管 是 誰	不 算	不 精	不 精 密	
不 精 通	不 精 確	不 精 確 性	不 緊	不 緊 不 慢	不 緊 要	不 罰	不 聞 不 問	
不 腐 敗	不 舞 之 鶴	不 語	不 認	不 認 真	不 認 輸	不 認 識	不 說	
不 說 謊	不 輕	不 輕 信	不 遠	不 遠 千 里	不 遠 萬 里	不 遜	不 需	
不 需 要	不 領 情	不 鳴 則 已	不 齊	不 寬	不 寬 容	不 寬 恕	不 寬 敞	
不 審 慎	不 履 行	不 履 行 者	不 廣	不 憚 強 禦	不 憤	不 撓	不 敵	
不 敷	不 敷 使 用	不 標 準	不 樂	不 潦 潦 之	不 潔	不 潔 淨	不 潮 濕	
不 熟	不 熟 悉	不 熟 練	不 熱	不 熱 心	不 熱 情	不 皺	不 確 切	
不 確 定	不 確 定 性	不 確 實	不 稼 不 穡	不 蔓 不 枝	不 衛 生	不 複 雜	不 談	
不 請	不 調	不 調 和	不 論	不 論 什 麼	不 論 何 時	不 論 何 種	不 論 是 誰	
不 論 甚 麼	不 論 誰	不 賠	不 賣	不 質 疑	不 輟	不 適	不 適 中	
不 適 用	不 適 任	不 適 合	不 適 宜	不 適 航	不 適 當	不 適 應	不 靠	
不 餓	不 齒	不 凝 固	不 學	不 學 無 術	不 懊 悔	不 懈	不 懈 努 力	
不 戰 不 和	不 戰 自 敗	不 擇 手 段	不 整	不 整 飾	不 整 齊	不 整 潔	不 機 敏	
不 燃	不 燃 性	不 燃 物	不 燃 燒	不 獨	不 瞞 你 說	不 瞞 您 說	不 磨 損	
不 積 極	不 興	不 融 合	不 褪 色	不 親	不 親 切	不 親 熱	不 諱	
不 謀 而 同	不 謀 而 合	不 謀 私 利	不 諧 和	不 諧 和 音	不 謂	不 賴	不 輸	
不 辨	不 辨 菽 麥	不 遵 守	不 遲	不 遺	不 遺 餘 力	不 醒	不 錯	
不 隨	不 隨 意	不 優 美	不 優 雅	不 儲 存	不 幫	不 應	不 應 得	
不 應 該	不 懂	不 懂 裝 懂	不 戴	不 戴 帽	不 檢	不 檢 查	不 檢 點	
不 櫛 進 士	不 濟	不 瞭 解	不 縮	不 縮 不 皺	不 翼 而 飛	不 臉 紅	不 謙 虛	
不 講	不 講 方 法	不 講 出	不 講 條 件	不 謝	不 賺	不 購 買	不 輿	
不 避	不 避 強 禦	不 避 艱 險	不 還	不 還 債	不 鮮 明	不 擺	不 斷	
不 斷 要 求	不 斷 發 展	不 斷 電 系 統	不 斷 增 加	不 斷 增 長	不 禮 貌	不 簡 單	不 織 布	
不 舊	不 謹 慎	不 豐 不 殺	不 離	不 鬆 懈	不 壞	不 懷	不 懷 好 意	
不 懷 疑	不 礙	不 穩	不 穩 固	不 穩 定	不 藥	不 藥 而 愈	不 識	
不 識 大 體	不 識 好 歹	不 識 抬 舉	不 識 時 務	不 證 自 明	不 贊 同	不 贊 成	不 辭	
不 辭 而 別	不 辭 辛 苦	不 辭 辛 勞	不 辭 勞 苦	不 關	不 關 心	不 關 連	不 關 痛 癢	
不 難	不 難 看	不 難 看 出	不 難 想 像	不 類	不 願	不 願 給	不 願 意	
不 願 聽	不 嚴	不 嚴 重	不 嚴 峻	不 嚴 密	不 嚴 謹	不 覺	不 覺 察	
不 贏	不 屬	不 屬 於	不 懼	不 爛	不 爛 之 舌	不 蠢	不 露	
不 露 圭 角	不 露 面	不 露 痕 跡	不 露 聲 色	不 響 應	不 顧	不 顧 一 切	不 顧 危 險	
不 顧 死 活	不 顧 前 後	不 顧 後 果	不 彎	不 彎 曲	不 歡	不 歡 而 散	不 聽	
不 聽 話	不 讀 音	不 驕	不 驕 不 躁	不 變	不 變 □	不 變 化	不 變 性	
不 變 量	不 變 資 本	不 變 價 格	不 顯	不 顯 眼	不 顯 著	不 驚	不 體 面	
不 體 諒	不 羈	不 讓	不 靈	不 靈 巧	不 靈 敏	不 讚 一 詞	不 忮 不 得	
不 祧 之 祖	不 脛 而 走	不 稂 不 莠	不 瞅 不 睬	不 韙	不 ��	不 �� 鋼	中 了	
中 人	中 下	中 下 旬	中 下 游	中 上	中 上 游	中 上 等	中 上 層	
中 士	中 子	中 子 星	中 小	中 小 企 業	中 小 型	中 小 城 市	中 小 學	
中 小 學 生	中 小 學 校	中 山	中 山 大 學	中 山 女 高	中 山 科 學 研 究 院	中 山 美 穗	中 山 裝	
中 干	中 介	中 介 人	中 元	中 切	中 午	中 友 百 貨	中 天	
中 巴	中 巴 關 係	中 心	中 心 內 容	中 心 任 務	中 心 店	中 心 思 想	中 心 區	
中 心 詞	中 心 對 稱	中 心 環 節	中 心 點	中 心 體	中 文	中 文 之 星	中 文 版	
中 文 信 息	中 文 窗	中 文 電 腦	中 方	中 日	中 日 國 際	中 日 關 係	中 止	
中 世 紀	中 刊	中 去	中 古	中 古 車	中 古 屋	中 台	中 台 禪 寺	
中 外	中 外 合 資	中 外 合 資 企 業	中 外 合 資 經 營 企 業	中 外 記 者	中 外 觀 眾	中 央	中 央 人 民 廣 播 電 台	
中 央 文 件	中 央 全 會	中 央 再 保	中 央 印 製 廠	中 央 各 部 委	中 央 存 保	中 央 存 款 保 險 公 司	中 央 委 員	
中 央 委 員 會	中 央 社	中 央 青 工 會	中 央 信 託 局	中 央 保	中 央 政 治 局	中 央 政 治 局 委 員	中 央 政 治 局 常 委	
中 央 研 究 院	中 央 軍 委	中 央 書 記 處	中 央 氣 象 局	中 央 部	中 央 電 視 台	中 央 銀 行	中 央 辦 公 廳	
中 央 選 舉 委 員 會	中 正	中 正 紀 念 堂	中 正 機 場	中 用	中 立	中 立 不 倚	中 立 化	
中 立 政 策	中 立 國	中 立 國 家	中 伏	中 共	中 共 中 央	中 共 中 央 總 書 記	中 共 黨 員	
中 再 保	中 名	中 宇 環 保	中 年	中 年 人	中 式	中 成 藥	中 旬	
中 老 年	中 老 年 人	中 耳	中 耳 炎	中 西	中 西 文	中 西 合 璧	中 西 部	
中 西 醫	中 住	中 低 產 田	中 低 檔	中 含 有	中 局	中 技	中 灶	
中 亞	中 亞 地 區	中 亞 國 家	中 亞 細 亞	中 和	中 和 力	中 和 市	中 和 羊 毛	
中 和 作 用	中 性	中 性 鹽	中 東	中 東 社	中 東 問 題	中 東 戰 爭	中 果 皮	
中 板	中 波	中 法	中 油	中 的	中 直	中 直 機 關	中 空	
中 肯	中 表	中 長	中 長 期	中 雨	中 青 年	中 非	中 信	
中 信 局	中 信 投 信	中 信 商 銀	中 信 證 券	中 南	中 南 海	中 南 部	中 垂 線	
中 型	中 型 機	中 宣 部	中 度	中 拮	中 指	中 段	中 毒	
中 流	中 流 砥 柱	中 流 擊 楫	中 為	中 看	中 研 院	中 科 院	中 秋	
中 秋 節	中 紀	中 紀 委	中 美	中 美 洲	中 美 關 係	中 英	中 計	
中 軍	中 音	中 頁	中 風	中 原	中 原 地 區	中 原 板 蕩	中 原 逐 鹿	
中 埔	中 師	中 時 晚 報	中 時 電 子 報	中 校	中 氣	中 海	中 班	
中 級	中 級 法 院	中 級 品	中 耕	中 脈	中 草 藥	中 院	中 高 音	
中 高 級	中 高 檔	中 區	中 國	中 國 人	中 國 人 民	中 國 人 民 解 放 軍	中 國 人 民 銀 行	
中 國 人 壽	中 國 人 權 協 會	中 國 人 纖	中 國 力 霸	中 國 大 陸	中 國 工 商 銀 行	中 國 之 最	中 國 化	
中 國 化 學	中 國 少 年 先 鋒 隊	中 國 文 化	中 國 文 學	中 國 日 報	中 國 史	中 國 民 主 促 進 會	中 國 民 航	
中 國 石 化	中 國 共 產 黨	中 國 式	中 國 作 協	中 國 作 家 協 會	中 國 社 會 科 學 院	中 國 青 年	中 國 政 府	
中 國 科 協	中 國 科 學 院	中 國 紅 十 字 會	中 國 致 公 黨	中 國 軍 隊	中 國 革 命	中 國 時 報	中 國 書 店	
中 國 特 色	中 國 特 色 的	中 國 商 銀	中 國 國 民 黨	中 國 婦 女	中 國 專 利 局	中 國 產 物	中 國 貨 櫃	
中 國 通	中 國 畫	中 國 菜	中 國 隊	中 國 話	中 國 電 視	中 國 電 器	中 國 製 釉	
中 國 銀 行	中 國 熱	中 國 學	中 國 戰 區	中 國 橡 膠	中 國 歷 史	中 國 輸 出 入 銀 行	中 國 鋼 鐵	
中 國 醫 學	中 國 邊 界	中 堅	中 堅 力 量	中 堂	中 尉	中 專	中 將	
中 常	中 庸	中 庸 之 道	中 強 光 電	中 強 電 子	中 彩	中 產	中 產 階 級	
中 統	中 組 部	中 船	中 連 汽 車	中 途	中 途 而 廢	中 部	中 場	
中 就	中 提 琴	中 提 琴 手	中 景	中 暑	中 期	中 森 明 菜	中 游	
中 焦	中 短 波	中 程	中 程 導 彈	中 等	中 等 水 平	中 等 城 市	中 等 專 業 教 育	
中 等 教 育	中 策	中 華	中 華 人 民 共 和 國	中 華 工 程	中 華 化 學	中 華 民 國	中 華 民 族	
中 華 汽 車	中 華 兒 女	中 華 映 管	中 華 書 局	中 華 紙 漿	中 華 航 空	中 華 票 券	中 華 開 發	
中 華 奧 會	中 華 經 濟 研 究 院	中 華 電 信	中 華 電 纜	中 華 銀 行	中 華 徵 信 所	中 華 職 棒	中 華 職 籃	
中 菲 電 腦	中 視	中 越	中 距 離	中 軸	中 進	中 量 級	中 間	
中 間 人	中 間 色	中 間 物	中 間 派	中 間 級	中 間 商	中 間 圈	中 間 語	
中 間 層	中 間 線	中 間 環 節	中 隊	中 階 層	中 項	中 飯	中 傷	
中 傷 者	中 微 子	中 意	中 會	中 概 股	中 殿	中 經	中 經 院	
中 腹 部	中 腦	中 落	中 葉	中 裝	中 路	中 農	中 道	
中 道 而 廢	中 飽	中 飽 私 囊	中 鼎 工 程	中 福 紡 織	中 綴	中 網	中 寮 鄉	
中 寫	中 層	中 層 樓	中 廣	中 廣 戰 神	中 彈	中 德	中 樞	
中 樞 神 經	中 標	中 歐	中 獎	中 盤	中 磊 電 子	中 稻	中 篇	
中 篇 小 說	中 緯 度	中 線	中 衛	中 輟	中 輟 生	中 輟 學 生	中 鋒	
中 學	中 學 生	中 學 教 師	中 導	中 縣	中 興	中 興 人 壽	中 興 百 貨	
中 興 保 全	中 興 紡 織	中 興 票 券	中 興 電	中 興 銀 行	中 選	中 選 會	中 醒	
中 鋼	中 鋼 結 構	中 鋼 碳 素	中 頻	中 頭	中 餐	中 戲	中 檔	
中 環	中 環 公 司	中 聯 信 託	中 聯 部	中 聯 爐 石	中 點	中 斷	中 斷 器	
中 轉	中 醫	中 醫 師	中 醫 院	中 醫 診 所	中 醫 學	中 醫 藥	中 壢	
中 壢 市	中 藥	中 藥 材	中 關 村	中 繼	中 繼 站	中 繼 線	中 蘇	
中 蘇 關 係	中 欄	中 顧 委	中 聽	中 籤	中 廳	中 摳	中 饋 乏 人	
丰 采	丰 姿	丰 姿 冶 麗	丰 姿 綽 約	丰 容 靚 飾	丰 標 不 凡	丰 韻	丹 心	
丹 心 碧 血	丹 田	丹 江	丹 佛 市	丹 東	丹 青	丹 徒	丹 書 鐵 券	
丹 書 鐵 契	丹 桂	丹 參	丹 麥	丹 麥 人	丹 麥 語	丹 陽	丹 楹 刻 桷	
丹 鳳	丹 霞	之 一	之 二	之 人	之 八 九	之 十	之 又	
之 三	之 下	之 上	之 久	之 口	之 士	之 大	之 女	
之 子	之 小	之 才	之 不	之 中	之 五	之 內	之 六	
之 分	之 友	之 夫	之 心	之 日	之 日 起	之 比	之 水	
之 火	之 父	之 犬	之 王	之 主	之 乎 者 也	之 以	之 功	
之 北	之 半	之 四	之 外	之 本	之 母	之 用	之 由	
之 交	之 份	之 光	之 兆	之 先	之 列	之 名	之 地	
之 在	之 多	之 字 形	之 年	之 死	之 死 靡 它	之 百	之 而	
之 肉	之 色	之 行	之 位	之 作	之 兵	之 別	之 志	
之 災	之 見	之 角	之 言	之 事	之 和	之 夜	之 妻	
之 所	之 所 以	之 明	之 河	之 爭	之 物	之 初	之 長	
之 門	之 便	之 冠	之 前	之 客	之 度	之 後	之 後 不 久	
之 故	之 流	之 為	之 秋	之 美	之 計	之 音	之 首	
之 值	之 冤	之 家	之 差	之 差 是	之 徒	之 恩	之 旁	
之 旅	之 時	之 氣	之 泰	之 神	之 能 事	之 財	之 馬	
之 側	之 國	之 患	之 情	之 欲	之 理	之 眾	之 處	
之 術	之 都	之 鳥	之 尊	之 殼	之 痛	之 短	之 詞	
之 量	之 間	之 亂	之 勢	之 意	之 極	之 源	之 祿	
之 罪	之 義	之 貉	之 路	之 道	之 過	之 隔	之 境	
之 墓	之 夢	之 實	之 態 度	之 歌	之 福	之 語	之 際	
之 價	之 價 值	之 數	之 誼	之 談	之 論	之 輩	之 餘	
之 戰	之 險	之 聲	之 舉	之 職	之 辭	之 難	之 類	
之 寶	之 鐘	之 歡	之 戀	之 啥	尹 馨	予 以	予 以 安 排	
予 以 考 慮	予 取 予 求	云 云	云 辰 電 子	井 下	井 口	井 中 求 火	井 中 視 星	
井 井	井 井 有 條	井 井 有 禮	井 水	井 水 不 犯 河 水	井 台	井 田	井 田 制	
井 字	井 臼 親 操	井 岡	井 岡 山	井 底	井 底 之 蛙	井 底 銀 瓶	井 巷	
井 架	井 泵	井 陘	井 探	井 場	井 然	井 然 有 序	井 筒	
井 蛙 之 見	井 蛙 醯 雞	井 隊	井 蓋	井 噴	井 壁	井 機	井 繩	
井 邊	井 欄	井 灌	井 鹽	互 不	互 不 干 涉	互 不 服 氣	互 不 侵 犯	
互 不 侵 犯 條 約	互 不 相 讓	互 斥	互 生	互 用	互 用 性	互 有	互 利	
互 利 互 惠	互 利 共 生	互 助	互 助 友 愛	互 助 組	互 見	互 使	互 卷	
互 定	互 抵	互 爭	互 爭 高 下	互 信	互 勉	互 查	互 派	
互 派 大 使	互 為	互 為 知 己	互 為 表 裡	互 相	互 相 協 作	互 相 愛 護	互 相 幫 助	
互 涉	互 祝	互 動	互 推	互 現	互 盛 公 司	互 訪	互 設	
互 通	互 通 有 無	互 連	互 連 性	互 惠	互 惠 待 遇	互 惠 關 稅	互 換	
互 換 性	互 替	互 結	互 給	互 訴 衷 情	互 感	互 愛	互 敬 互 愛	
互 會	互 補	互 毆	互 諒	互 諒 互 讓	互 調	互 踢	互 選	
互 濟	互 鎖	互 贈	互 關	互 變	互 讓	五 一	五 一 國 際 勞 動 節	
五 一 節	五 七	五 七 干 校	五 人	五 十	五 十 一	五 十 七	五 十 九	
五 十 二	五 十 人	五 十 八	五 十 三	五 十 五	五 十 六	五 十 四	五 十 步 笑 百 步	
五 十 個	五 十 歲	五 十 萬	五 千	五 千 萬	五 大	五 大 三 粗	五 大 洲	
五 中	五 中 全 會	五 元	五 內	五 內 如 焚	五 分	五 分 之 一	五 分 制	
五 斗	五 斗 櫃	五 方	五 方 雜 厝	五 方 雜 處	五 日	五 日 熱	五 月	
五 月 天	五 月 份	五 月 花	五 世	五 代	五 代 十 國	五 台	五 台 山	
五 四	五 四 青 年 節	五 四 運 動	五 件	五 份	五 光	五 光 十 色	五 名	
五 如 京 兆	五 年	五 年 前	五 年 計 劃	五 旬 節	五 次	五 百	五 百 萬	
五 色	五 色 無 主	五 色 繽 紛	五 行	五 行 八 作	五 行 並 下	五 行 俱 下	五 位	
五 忘 形 交	五 更	五 角	五 角 大 樓	五 角 形	五 角 星	五 角 錢	五 言 長 城	
五 言 詩	五 里	五 里 霧 中	五 卷	五 味	五 味 子	五 味 瓶	五 官	
五 屆	五 弦 琴	五 服	五 股	五 股 鄉	五 花	五 花 八 門	五 花 大 綁	
五 金	五 保	五 保 戶	五 帝	五 度	五 律	五 指	五 指 山	
五 星	五 星 紅 旗	五 段	五 毒	五 洲	五 洲 四 海	五 洲 製 革	五 胞 胎	
五 重 奏	五 面	五 面 體	五 音	五 音 節	五 風 十 雨	五 香	五 倍	
五 倍 子	五 個	五 原	五 家	五 峰	五 時	五 級	五 馬 分 屍	
五 常	五 彩	五 彩 紛 呈	五 彩 繽 紛	五 條	五 部	五 陵 年 少	五 陵 豪 氣	
五 雀 六 燕	五 湖	五 湖 四 海	五 筆	五 筆 字 型	五 結	五 絕	五 項	
五 項 原 則	五 黃 六 月	五 萬	五 禽 戲	五 號	五 路	五 載	五 道	
五 鼎 生 物	五 福	五 種	五 億	五 層	五 樓	五 穀	五 穀 不 分	
五 穀 豐 登	五 穀 豐 稔	五 穀 豐 熟	五 穀 雜 糧	五 線 譜	五 蓮	五 頭	五 嶽	
五 環	五 癆 七 傷	五 講	五 講 四 美	五 點	五 顏 六 色	五 邊	五 邊 形	
五 類 分 子	五 權	五 臟	五 臟 六 腑	五 體 投 地	亢 進	亢 進 性	亢 極 之 悔	
亢 奮	亢 龍 有 悔	仁 人	仁 人 君 子	仁 人 志 士	仁 化	仁 心	仁 心 仁 術	
仁 兄	仁 民 愛 物	仁 至	仁 至 義 盡	仁 弟	仁 言 利 博	仁 武 鄉	仁 者	
仁 者 見 仁	仁 厚	仁 政	仁 堂	仁 翔 建 設	仁 慈	仁 愛	仁 愛 鄉	
仁 義	仁 義 之 師	仁 義 道 德	仁 德	仁 德 鄉	仁 學	仁 醫	仁 題	
仁 寶 電 腦	什 一 之 利	什 午	什 件	什 物	什 葉 派	什 麼	什 麼 地 方	
什 麼 事	什 麼 的	什 麼 時 候	什 麼 樣	什 錦	什 錦 菜	什 襲 而 藏	仇 人	
仇 心	仇 外	仇 快	仇 念	仇 者	仇 怨	仇 恨	仇 家	
仇 殺	仇 報	仇 視	仇 隙	仇 敵	仇 懼	仍 不	仍 以	
仍 可	仍 未	仍 用	仍 由	仍 在	仍 有	仍 系	仍 按	
仍 是	仍 能	仍 停 留	仍 將	仍 然	仍 然 是	仍 須	仍 會	
仍 照	仍 需	仍 舊	今 人	今 不 如 昔	今 井 美 樹	今 天	今 文	
今 日	今 月 古 月	今 世	今 以	今 冬	今 冬 明 春	今 古 奇 聞	今 古 傳 奇	
今 生	今 生 今 世	今 年	今 年 以 來	今 年 年 初	今 年 底	今 次	今 來 古 往	
今 兒	今 夜	今 昔	今 昔 之 感	今 昔 對 比	今 明 兩 天	今 明 兩 年	今 非 昔 比	
今 後	今 後 任 務	今 春	今 是	今 是 昨 非	今 為	今 秋	今 夏	
今 起	今 晚	今 晨	今 期	今 朝	今 番	今 愁 古 恨	今 歲	
今 譯	介 入	介 子	介 休	介 在	介 於	介 係 詞	介 面	
介 面 卡	介 音	介 紹	介 紹 人	介 紹 性	介 紹 信	介 殼	介 殼 蟲	
介 詞	介 意	介 電 常 數	介 質	介 體	仄 聲	元 大	元 大 證 券	
元 子	元 元 本 本	元 化	元 方 季 方	元 日	元 月	元 月 份	元 氏	
元 代	元 古 紀	元 旦	元 件	元 兇	元 年	元 曲	元 老	
元 老 院	元 長	元 長 鄉	元 帥	元 音	元 食 贅 行	元 首	元 宵	
元 宵 節	元 桌	元 氣	元 祖	元 素	元 素 符 號	元 配	元 釘	
元 針	元 麥	元 富 投 信	元 富 鋁 業	元 富 證 券	元 惡 大 奸	元 惡 大 憝	元 智 大 學	
元 朝	元 雅	元 禎 企 業	元 語 言	元 勳	元 器 件	元 謀	元 龍 高 臥	
元 豐 電 子	元 寶	允 文 允 武	允 可	允 准	允 執 其 中	允 執 厥 中	允 強 實 業	
允 許	允 當	允 諾	內 人	內 力	內 子	內 中	內 公 切 線	
內 分	內 分 泌	內 分 泌 腺	內 切	內 切 圓	內 心	內 心 世 界	內 心 深 處	
內 心 裡	內 主	內 凹	內 出	內 出 血	內 功	內 包	內 史	
內 外	內 外 勾 結	內 外 交 困	內 外 有 別	內 外 夾 攻	內 生	內 皮	內 向	
內 向 性	內 向 者	內 向 型	內 因	內 地	內 地 人	內 在	內 在 化	
內 在 性	內 在 聯 繫	內 奸	內 存	內 宅	內 收	內 有	內 江	
內 耳	內 行	內 衣	內 衣 褲	內 串	內 克	內 助	內 含	
內 廷	內 弟	內 攻	內 秀	內 角	內 侍	內 制	內 卷	
內 定	內 府	內 底	內 弧 面	內 拉	內 放	內 服	內 服 藥	
內 果	內 果 皮	內 河	內 河 運 輸	內 沿	內 爭	內 物	內 疚	
內 空	內 門	內 阻	內 則	內 城	內 室	內 建	內 急	
內 政	內 政 部	內 柔 外 剛	內 查 外 調	內 毒	內 省	內 省 性	內 科	
內 胚	內 胎	內 面	內 埔 鄉	內 容	內 容 提 要	內 座 層	內 徑	
內 核	內 海	內 破 裂	內 耗	內 能	內 訌	內 院	內 骨	
內 骨 骼	內 側	內 務	內 務 條 令	內 務 部	內 動	內 參	內 圈	
內 堂	內 寄 生	內 患	內 情	內 接	內 涵	內 痔	內 盛	
內 眷	內 袖	內 設	內 部	內 部 人	內 部 刊 物	內 部 矛 盾	內 部 事 務	
內 陸	內 陷	內 場	內 嵌	內 插	內 景	內 港	內 湖	
內 焰	內 華 達	內 華 達 州	內 視 反 聽	內 診 鏡	內 項	內 黃	內 亂	
內 亂 罪	內 債	內 傾	內 傷	內 勤	內 匯	內 愛	內 殿	
內 經	內 置	內 聖 外 王	內 腫	內 腺	內 裙	內 裝	內 裡	
內 詳	內 資	內 電 阻	內 幕	內 管	內 緊 外 松	內 聚 力	內 聚 性	
內 蒙	內 蒙 古	內 蒙 古 自 治 區	內 閣	內 閣 改 組	內 層	內 憂	內 憂 外 患	
內 戮	內 摩 擦	內 熱	內 碼	內 線	內 線 交 易	內 膜	內 膝	
內 踝	內 銷	內 駐	內 壁	內 戰	內 燃	內 燃 機	內 燃 機 車	
內 褲	內 親	內 錯	內 錯 角	內 壕	內 應	內 應 力	內 牆	
內 聯	內 聯 外 引	內 翻	內 轉	內 爆	內 羅 畢	內 難	內 蘊	
內 顧	內 顧 之 憂	內 彎	內 彎 足	內 臟	內 變	內 �� 胺	內 侄	
內 澇	六 一	六 一 兒 童 節	六 一 國 際 兒 童 節	六 人	六 十	六 十 一	六 十 七	
六 十 九	六 十 二	六 十 人	六 十 八	六 十 三	六 十 五	六 十 六	六 十 四	
六 十 年	六 十 年 代	六 十 倍	六 十 個	六 十 歲	六 十 萬	六 千	六 大	
六 中 全 會	六 六	六 六 六	六 分	六 分 之 一	六 分 儀	六 尺 之 孤	六 尺 長	
六 日	六 月	六 月 份	六 月 飛 霜	六 出 奇 計	六 甲	六 合	六 合 彩	
六 安	六 年	六 次	六 百	六 百 萬	六 色	六 行	六 位	
六 折	六 步 格	六 角	六 角 形	六 屆	六 弦 琴	六 所	六 便 士	
六 指	六 段	六 重 奏	六 重 唱	六 面	六 面 體	六 音	六 倍	
六 個	六 個 月	六 個 裝	六 時	六 書	六 根	六 根 清 淨	六 畜	
六 畜 不 安	六 畜 興 旺	六 神	六 神 不 安	六 神 無 主	六 馬 仰 秣	六 問 三 推	六 條	
六 通 四 辟	六 通 四 達	六 朝	六 朝 金 粉	六 腑	六 街 三 市	六 開 本	六 陽 會 首	
六 萬	六 節 詩	六 腳 鄉	六 號	六 路	六 道	六 道 輪 迴	六 零	
六 零 六	六 福 開 發	六 億	六 價	六 盤 水	六 線 形	六 輪	六 親	
六 親 不 認	六 親 無 靠	六 龜 鄉	六 點	六 邊	六 邊 形	六 韜 三 略	兮 兮	
公 人	公 子	公 子 王 孫	公 子 哥 兒	公 寸	公 才 公 望	公 元	公 元 前	
公 允	公 公	公 公 正 正	公 分	公 切 線	公 升	公 尺	公 心	
公 文	公 文 包	公 文 旅 行	公 文 書	公 文 袋	公 斤	公 方	公 比	
公 牛	公 牛 隊	公 主	公 主 裝	公 主 嶺	公 出	公 司	公 司 倒 閉	
公 司 債	公 平	公 平 交 易 委 員 會	公 平 合 理	公 平 會	公 平 競 爭	公 正	公 正 人	
公 民	公 民 自 由	公 民 投 票	公 民 權	公 民 權 利	公 用	公 用 事 業	公 用 設 施	
公 用 電 話	公 立	公 交	公 交 車	公 交 部 門	公 休	公 休 假 日	公 共	
公 共 工 程 委 員 會	公 共 危 險 罪	公 共 汽 車	公 共 場 所	公 因 式	公 因 數	公 安	公 安 人 員	
公 安 工 作	公 安 干 警	公 安 局	公 安 事 件	公 安 事 故	公 安 部	公 安 部 長	公 安 部 隊	
公 安 戰 士	公 安 機 關	公 安 廳	公 式	公 式 化	公 式 集	公 弛	公 有	
公 有 化	公 有 制	公 羊	公 而 忘 私	公 余	公 佈	公 佈 於	公 佈 於 世	
公 克	公 判	公 告	公 決	公 私	公 私 不 分	公 私 分 明	公 私 合 營	
公 私 兩 便	公 私 兩 濟	公 私 兼 顧	公 車	公 里	公 事	公 事 公 辦	公 事 包	
公 使	公 使 館	公 例	公 兩	公 函	公 制	公 房	公 河	
公 法	公 物	公 社	公 秉	公 股	公 門	公 保	公 映	
公 約	公 倍	公 倍 數	公 候	公 孫	公 害	公 家	公 差	
公 案	公 海	公 畝	公 畜	公 益	公 益 事 業	公 益 金	公 益 組 織	
公 假	公 務	公 務 人 員 懲 戒 委 員 會	公 務 上	公 務 制 度	公 務 員	公 務 員 懲 戒 委 員 會	公 堂	
公 娼	公 婆	公 推	公 教	公 教 住 宅	公 族	公 理	公 現	
公 產	公 眾	公 祭	公 處	公 設	公 章	公 頃	公 鹿	
公 報	公 報 私 仇	公 寓	公 廁	公 款	公 然	公 程 會	公 訴	
公 訴 人	公 費	公 費 生	公 費 旅 遊	公 費 醫 療	公 開	公 開 化	公 開 批 評	
公 開 性	公 開 信	公 開 場 合	公 開 審 判	公 開 賽	公 債	公 傾	公 傷	
公 園	公 園 管 理 局	公 幹	公 幹 粉	公 意	公 會	公 署	公 路	
公 路 交 通	公 路 局	公 路 運 輸	公 道	公 電	公 僕	公 墓	公 演	
公 稱	公 認	公 誡	公 需	公 審	公 德	公 憤	公 敵	
公 諸	公 諸 同 好	公 諸 於 世	公 諸 於 眾	公 論	公 豬	公 賣	公 賣 局	
公 噸	公 擔	公 歷	公 積 金	公 辦	公 錢	公 館	公 館 鄉	
公 鴨	公 檢	公 檢 法	公 營	公 營 事 業	公 爵	公 舉	公 斷	
公 斷 人	公 糧	公 職	公 職 人 員	公 轉	公 雞	公 懲 會	公 證	
公 證 人	公 證 書	公 證 處	公 證 機 關	公 關	公 關 小 姐	公 議	公 權	
公 聽 並 觀	公 厘	冗 位	冗 余	冗 言	冗 長	冗 員	冗 筆	
冗 詞	冗 詞 贅 句	冗 語	冗 贅	冗 雜	分 力	分 叉	分 叉 處	
分 子	分 子 力	分 子 式	分 子 狀	分 子 結 構	分 子 量	分 子 電 流	分 子 論	
分 子 篩	分 寸	分 工	分 不 清	分 不 開	分 之	分 之 一	分 內	
分 公 司	分 分	分 分 秒 秒	分 化	分 化 瓦 解	分 心	分 戶	分 手	
分 支	分 文	分 文 不 取	分 斤 較 兩	分 斤 掰 兩	分 月	分 比	分 水 線	
分 水 嶺	分 片	分 片 包 干	分 付	分 冊	分 出	分 包	分 句	
分 外	分 母	分 甘 共 苦	分 生 孢 子	分 立	分 光	分 光 計	分 光 儀	
分 光 譜	分 光 鏡	分 列	分 列 式	分 各 部	分 合	分 地	分 在	
分 多	分 字 法	分 式	分 式 方 程	分 成	分 旬	分 米	分 米 波	
分 而 治 之	分 色	分 行	分 作	分 佈	分 佈 式	分 佈 區	分 佈 電 容	
分 佈 廣	分 佈 學	分 克	分 兵 把 口	分 兵 把 守	分 別	分 別 為	分 局	
分 岔	分 我 杯 羹	分 批	分 灶	分 貝	分 身	分 身 術	分 享	
分 到	分 取	分 居	分 店	分 所	分 明	分 析	分 析 化 學	
分 析 法	分 析 者	分 析 員	分 析 家	分 析 師	分 析 器	分 析 學	分 歧	
分 泌	分 泌 汗	分 泌 物	分 泌 素	分 泌 液	分 法	分 社	分 表	
分 門	分 門 別 戶	分 門 別 類	分 則	分 封	分 屏	分 屍	分 度 規	
分 度 器	分 指 數	分 星 擘 兩	分 段	分 段 落	分 洪	分 流	分 派	
分 為	分 界	分 界 符	分 界 線	分 省	分 科	分 秒	分 秒 必 爭	
分 紅	分 茅 列 土	分 茅 胙 土	分 赴	分 軌	分 述	分 音	分 頁	
分 香 賣 履	分 值	分 娩	分 家	分 庫	分 庭 伉 禮	分 庭 抗 禮	分 時	
分 校	分 班	分 神	分 租	分 站	分 級	分 級 分 類	分 送	
分 配	分 配 人	分 配 者	分 配 律	分 配 閥	分 配 器	分 配 權	分 針	
分 院	分 做	分 區	分 區 制	分 寄	分 崩	分 崩 離 析	分 帶	
分 帳	分 得	分 得 清	分 得 開	分 掉	分 毫	分 毫 不 爽	分 淺 緣 薄	
分 淺 緣 慳	分 清	分 清 是 非	分 清 敵 我	分 理	分 理 處	分 粒 器	分 組	
分 組 循 環	分 組 循 環 賽	分 組 會	分 組 賽	分 設	分 途	分 部	分 釵 斷 帶	
分 割	分 場	分 揀	分 散	分 散 介 質	分 散 主 義	分 散 度	分 散 染 料	
分 散 相	分 散 劑	分 散 器	分 期	分 期 分 批	分 期 付 款	分 發	分 發 者	
分 稅	分 稅 制	分 等	分 等 級	分 給	分 裂	分 裂 主 義	分 裂 生 殖	
分 詞	分 進 合 擊	分 開	分 開 了	分 隊	分 階	分 階 段	分 塊	
分 會	分 業	分 節 音	分 群	分 號	分 裝	分 解	分 解 力	
分 解 者	分 路	分 路 揚 鑣	分 道	分 道 揚 鑣	分 隔	分 隔 符	分 隔 欄	
分 劃	分 管	分 算	分 說	分 遣	分 遣 隊	分 際	分 層	
分 廠	分 憂	分 憂 解 愁	分 撥	分 數	分 線	分 論	分 銷	
分 擔	分 擔 者	分 曉	分 機	分 辨	分 辨 不 清	分 辨 出	分 辨 率	
分 辦	分 選	分 錢	分 錄	分 頭	分 壓	分 壓 器	分 擱	
分 檔	分 獲	分 薄 緣 慳	分 薛	分 薛 期	分 點	分 離	分 離 主 義	
分 離 出	分 離 性	分 離 器	分 餾	分 餾 法	分 餾 塔	分 類	分 類 上	
分 類 法	分 類 者	分 類 帳	分 類 匯 總	分 類 賬	分 類 器	分 類 學	分 鐘	
分 屬	分 欄	分 譴	分 贓	分 辯	分 辯 率	分 攤	分 權	
分 體	分 厘 卡	切 入	切 力	切 下	切 口	切 不	切 不 可	
切 中	切 中 要 害	切 中 時 弊	切 分	切 分 法	切 分 音	切 切	切 切 私 語	
切 切 實 實	切 勿	切 片	切 片 機	切 去	切 石 術	切 合	切 合 實 際	
切 成	切 肉	切 肉 刀	切 忌	切 角	切 角 面	切 身	切 身 利 益	
切 近	切 削	切 削 面	切 盼	切 要	切 屑	切 紙	切 脈	
切 草	切 記	切 起	切 送	切 除	切 除 術	切 骨 之 仇	切 掉	
切 望	切 細	切 莫	切 割	切 割 物	切 割 機	切 換	切 菜	
切 菜 刀	切 診	切 距	切 開	切 圓	切 塊	切 碎	切 碎 器	
切 腹	切 實	切 實 可 行	切 磋	切 磋 琢 磨	切 線	切 膚	切 膚 之 痛	
切 齒	切 齒 咬 牙	切 齒 痛 恨	切 齒 腐 心	切 齒 拊 心	切 點	切 斷	切 斷 者	
切 題	切 麵	切 變	勻 淨	勻 速	勻 速 直 線 運 動	勻 速 圓 周 運 動	勻 溜	
勻 實	勻 稱	勻 整	勾 勾	勾 勾 搭 搭	勾 引	勾 心	勾 心 鬥 角	
勾 出	勾 去	勾 住	勾 兌	勾 取	勾 股	勾 股 定 理	勾 消	
勾 起	勾 針	勾 除	勾 勒	勾 掉	勾 通	勾 畫	勾 結	
勾 搭	勾 當	勾 號	勾 劃	勾 魂	勾 踐	勾 銷	勾 臉	
勾 欄	勾 籐	勾 芡	勿 失	勿 失 良 機	勿 有	勿 似	勿 忘 草	
勿 玩	勿 動	勿 帶	勿 庸 置 疑	勿 寧 說	勿 謂 言 之 不 預	勿 藥 有 喜	化 上	
化 子	化 工	化 工 局	化 工 股	化 工 部	化 工 廠	化 干 戈 為 玉 帛	化 公 為 私	
化 日 光 天	化 石	化 名	化 合	化 合 物	化 合 價	化 州	化 成	
化 作	化 作 灰 燼	化 妝	化 妝 水	化 妝 台	化 妝 品	化 妝 師	化 身	
化 武	化 油 器	化 肥	化 為	化 為 己 有	化 為 灰 燼	化 為 泡 影	化 為 烏 有	
化 革	化 凍	化 除	化 掉	化 氮	化 費	化 募	化 痰	
化 裝	化 裝 服	化 解	化 過	化 零 為 整	化 境	化 敵	化 緣	
化 劑	化 學	化 學 工 業 部	化 學 元 素	化 學 分 析	化 學 反 應	化 學 反 應 式	化 學 方 程 式	
化 學 平 衡	化 學 合 成	化 學 式	化 學 防 護	化 學 性 質	化 學 武 器	化 學 治 療	化 學 物	
化 學 品	化 學 家	化 學 能	化 學 符 號	化 學 戰	化 學 鍵	化 學 藥 劑	化 學 纖 維	
化 學 變 化	化 整	化 整 為 零	化 險	化 險 為 夷	化 療	化 糞	化 膿	
化 齋	化 簡	化 鐵 爐	化 纖	化 纖 工 業	化 驗	化 驗 室	化 驗 員	
匹 夫	匹 夫 之 勇	匹 夫 匹 婦	匹 夫 有 責	匹 夫 無 罪 懷 璧 其 罪	匹 亞	匹 茲 堡	匹 配	
匹 馬 單 槍	匹 敵	午 市	午 休	午 安	午 曲	午 夜	午 門	
午 前	午 後	午 宴	午 時	午 場	午 間	午 飯	午 獅	
午 睡	午 課	午 膳	午 餐	午 覺	升 了	升 力	升 上	
升 天	升 天 節	升 斗	升 水	升 平	升 任	升 至	升 序	
升 到	升 於	升 空	升 為	升 限	升 降	升 降 索	升 降 機	
升 值	升 格	升 班	升 級	升 級 版	升 起	升 高	升 高 自 下	
升 堂	升 堂 入 室	升 堂 拜 母	升 幅	升 勢	升 溫	升 旗	升 漲	
升 調	升 遷	升 學	升 學 率	升 壓	升 壓 機	升 檔	升 職	
升 騰	厄 瓜 多 爾	厄 運	厄 爾 尼 諾	厄 難	友 人	友 力 工 業	友 立 資 訊	
友 好	友 好 人 士	友 好 月	友 好 代 表 團	友 好 合 作	友 好 使 者	友 好 周	友 好 往 來	
友 好 城 市	友 好 相 處	友 好 國 家	友 好 條 約	友 好 訪 問	友 好 襄 助	友 好 關 係	友 伴	
友 邦	友 協	友 尚 公 司	友 派	友 軍	友 風 子 雨	友 訊 科 技	友 情	
友 通 資 訊	友 善	友 愛	友 誼	友 誼 比 賽	友 誼 賽	友 鄰	友 聯 產 物	
友 聯 產 險	及 之	及 早	及 至	及 到	及 物	及 時	及 時 行 樂	
及 時 雨	及 格	及 第	及 膝	及 鋒 一 試	及 鋒 而 試	反 力	反 三 角 函 數	
反 口	反 干 擾	反 中	反 之	反 之 亦 然	反 互 換	反 切	反 及	
反 心	反 戈	反 戈 一 擊	反 手	反 手 拍	反 比	反 比 例	反 水 不 收	
反 火 力	反 去	反 左	反 打	反 本 還 原	反 正	反 用	反 用 法	
反 白	反 目	反 目 成 仇	反 目 為 仇	反 光	反 光 鏡	反 共	反 向	
反 合 圍	反 地 道	反 托	反 托 拉 斯	反 而	反 而 是	反 色	反 西 方	
反 串	反 作 用	反 作 用 力	反 告	反 坐	反 序	反 抗	反 抗 者	
反 折	反 折 射	反 攻	反 攻 日	反 攻 倒 算	反 攻 戰 役	反 步 兵	反 求 諸 己	
反 角	反 言	反 例	反 其	反 其 道 而 行 之	反 函 數	反 到	反 坦 克	
反 坦 克 炮	反 季	反 武 裝	反 法 西 斯	反 物 質	反 社 會	反 空 降	反 空 襲	
反 侵 略	反 叛	反 咬	反 咬 一 口	反 客 為 主	反 封 鎖	反 帝	反 帝 反 封 建	
反 建 議	反 思	反 政 府	反 政 變	反 映	反 映 情 況	反 映 論	反 毒 品	
反 派	反 省	反 相	反 突 破	反 突 擊	反 美	反 胃	反 英	
反 計	反 重 合	反 面	反 面 教 員	反 面 無 情	反 革 命	反 革 命 分 子	反 倒	
反 修	反 哺	反 唇 相 稽	反 唇 相 譏	反 射	反 射 比	反 射 角	反 射 弧	
反 射 性	反 射 波	反 射 率	反 射 層	反 射 線	反 射 器	反 射 鏡	反 射 爐	
反 射 體	反 差	反 差 強	反 恐 怖	反 悔	反 氣 旋	反 特	反 芻	
反 芻 動 物	反 芻 類	反 躬 自 省	反 躬 自 問	反 躬 自 責	反 逆	反 偵 察	反 側	
反 動	反 動 分 子	反 動 派	反 問	反 常	反 情 報	反 控	反 捲	
反 接	反 掃 蕩	反 推	反 推 力	反 敗 為 勝	反 眼 不 識	反 粒 子	反 貪 污	
反 殖	反 殖 民	反 訴	反 間	反 間 諜	反 黃	反 傾 銷	反 傾 銷 稅	
反 意	反 意 字	反 感	反 搞	反 照	反 照 率	反 經 合 義	反 經 行 權	
反 義	反 義 字	反 義 詞	反 腳	反 裘 負 芻	反 裘 負 薪	反 裝 甲	反 話	
反 跳	反 過 來	反 過 來 說	反 電 動 勢	反 對	反 對 物	反 對 者	反 對 派	
反 對 票	反 對 極	反 對 稱	反 對 黨	反 對 黨 人	反 演	反 磁 性	反 腐 敗	
反 語	反 誣	反 駁	反 駁 者	反 駁 道	反 彈	反 彈 道	反 影 鏡	
反 撲	反 潛	反 潛 艇	反 潮	反 潮 流	反 碼	反 衛 星	反 衝	
反 衝 擊	反 調 幅	反 調 製	反 論	反 質 子	反 遭	反 噬	反 導	
反 導 彈	反 戰	反 戰 運 動	反 機 動	反 激 因	反 諷	反 醒	反 壓 力	
反 應	反 應 方 程	反 應 式	反 應 物	反 應 者	反 應 堆	反 應 熱	反 應 器	
反 應 遲 鈍	反 應 爐	反 擊	反 講	反 覆	反 覆 不 常	反 覆 性	反 覆 研 究	
反 覆 強 調	反 覆 無 常	反 覆 說	反 覆 證 明	反 轉	反 轉 片	反 轉 來	反 藝 術	
反 證	反 證 法	反 黨	反 黨 集 團	反 躍	反 霸	反 霸 鬥 爭	反 響	
反 聽 內 視	反 襯	反 驕 破 滿	反 顯	反 蠶 食	反 觀	反 饋	壬 午	
壬 申	壬 戌	壬 辰	天 人 之 際	天 人 合 一	天 人 路 隔	天 人 關 係	天 下	
天 下 一 家	天 下 大 事	天 下 大 亂	天 下 太 平	天 下 文 宗	天 下 本 無 事	天 下 事	天 下 洶 洶	
天 下 為 一	天 下 為 公	天 下 為 家	天 下 烏 鴉 一 般 黑	天 下 第 一	天 下 無 敵	天 下 無 難 事	天 下 鼎 沸	
天 下 歸 心	天 上	天 上 人 間	天 上 石 麟	天 上 麒 麟	天 大	天 大 地 大	天 女 散 花	
天 子	天 子 門 生	天 子 無 戲 言	天 山	天 工	天 干	天 弓	天 才	
天 不 作 美	天 不 怕 地 不 怕	天 不 絕 人	天 之 驕 子	天 井	天 仁 茶 葉	天 公	天 公 不 作 美	
天 公 地 道	天 公 作 美	天 分	天 天	天 天 向 上	天 文	天 文 科 學 教 育 館	天 文 單 位	
天 文 臺	天 文 數 字	天 文 學	天 文 學 家	天 方	天 方 夜 譚	天 日	天 水	
天 火	天 牛	天 王	天 王 星	天 主	天 主 教	天 主 教 堂	天 付 良 緣	
天 仙	天 外	天 平	天 打	天 末 涼 風	天 生	天 生 天 殺	天 生 尤 物	
天 份	天 光	天 各 一 方	天 地	天 地 會	天 字 第 一 號	天 宇	天 安	
天 安 門	天 安 門 城 樓	天 安 門 廣 場	天 年	天 年 不 遂	天 有 不 測 風 雲	天 池	天 色	
天 衣	天 衣 無 縫	天 作 之 合	天 兵	天 冷	天 呀	天 快	天 旱	
天 災	天 災 人 禍	天 災 地 孽	天 災 地 變	天 災 物 怪	天 良	天 車	天 京	
天 使	天 使 般	天 使 學	天 和	天 周	天 命	天 命 有 歸	天 官	
天 府	天 府 之 國	天 底	天 性	天 明	天 昏	天 昏 地 黑	天 昏 地 暗	
天 昏 地 慘	天 河	天 狗	天 知 地 知	天 空	天 穹	天 竺	天 花	
天 花 板	天 花 亂 墜	天 芥 菜	天 長	天 長 日 久	天 長 地 久	天 長 地 老	天 長 地 遠	
天 門	天 青 石	天 青 色	天 亮	天 保 九 如	天 冠 地 屨	天 南 地 北	天 南 海 北	
天 卻	天 姿	天 姿 國 色	天 帝	天 後	天 怒	天 怒 人 怨	天 柱	
天 津	天 津 市	天 皇	天 相 吉 人	天 郎 氣 清	天 降	天 香 國 色	天 候	
天 倫	天 倫 之 樂	天 剛 資 訊	天 哪	天 宮	天 宮 圖	天 差 地 遠	天 師	
天 庭	天 恩	天 時	天 時 地 利	天 時 地 利 人 和	天 書	天 氣	天 氣 形 勢	
天 氣 狀 況	天 氣 真 好	天 氣 情 況	天 氣 現 象	天 氣 預 報	天 氣 圖	天 泰 銲 材	天 狼 星	
天 狼 座	天 真	天 真 活 潑	天 真 無 邪	天 真 爛 漫	天 神	天 祝	天 秤	
天 秤 座	天 荒	天 荒 地 老	天 馬 行 空	天 高	天 高 日 遠	天 高 地 卑	天 高 地 厚	
天 高 地 迥	天 高 地 遠	天 高 皇 帝 遠	天 高 氣 清	天 高 氣 爽	天 假 因 緣	天 假 良 緣	天 動	
天 啊	天 國	天 堂	天 崩 地 坼	天 崩 地 裂	天 從 人 願	天 授	天 授 地 設	
天 旋	天 旋 地 轉	天 梯	天 條	天 清 氣 朗	天 涯	天 涯 比 鄰	天 涯 地 角	
天 涯 咫 尺	天 涯 若 比 鄰	天 涯 海 角	天 淵	天 淵 之 別	天 球	天 理	天 理 不 容	
天 理 良 心	天 理 昭 昭	天 理 昭 然	天 理 昭 彰	天 理 難 容	天 造 地 設	天 陰	天 頂	
天 麻	天 寒	天 寒 地 凍	天 揚 精 密	天 晴	天 朝	天 棚	天 無 二 日	
天 無 絕 人 之 路	天 然	天 然 災 害	天 然 林	天 然 氣	天 然 氣 井	天 然 港	天 然 絲	
天 然 橡 膠	天 琴 座	天 窗	天 象	天 雲	天 黑	天 塔	天 塌 地 陷	
天 意	天 愁 地 慘	天 暗	天 溝	天 爺	天 經 地 義	天 葬	天 誅	
天 誅 地 滅	天 資	天 道	天 道 人 事	天 道 好 還	天 道 恢 恢	天 道 無 私	天 道 無 親	
天 道 盟	天 塹	天 奪 之 魄	天 奪 其 魄	天 幕	天 摧 地 塌	天 網 恢 恢	天 與 人 歸	
天 蓋	天 說	天 誘 其 衷	天 際	天 憫	天 敵	天 數	天 樓	
天 箭 座	天 緣 奇 遇	天 緣 湊 合	天 線	天 賦	天 賜	天 賜 良 機	天 趣	
天 壇	天 曉 得	天 橋	天 機	天 機 雲 錦	天 隨 人 願	天 險	天 龍	
天 篷	天 翻	天 翻 地 覆	天 職	天 藍	天 藍 色	天 覆 地 載	天 鵝	
天 鵝 座	天 鵝 絨	天 羅	天 羅 地 網	天 邊	天 壤	天 壤 之 別	天 壤 之 判	
天 壤 王 郎	天 懸 地 隔	天 蘭	天 譴	天 籟	天 驕	天 驚	天 驚 石 破	
天 體	天 體 圖	天 體 儀	天 體 學	天 靈 蓋 兒	天 潢 貴 冑	夫 人	夫 人 裙 帶	
夫 子	夫 子 自 道	夫 子 廟	夫 君	夫 妻	夫 妻 店	夫 座	夫 唱 婦 隨	
夫 婦	夫 婦 間	夫 琅 和 費	夫 喃	夫 喃 西 林	夫 婿	夫 貴 妻 榮	夫 榮 妻 貴	
夫 榮 妻 顯	夫 權	太 上	太 上 忘 情	太 上 皇	太 久	太 大	太 子	
太 子 建 設	太 小	太 不 自 量	太 不 像 話	太 公	太 公 釣 魚 願 者 上 鉤	太 太	太 太 們	
太 少	太 丘 道 廣	太 充 足	太 古	太 史	太 平	太 平 天 國	太 平 市	
太 平 門	太 平 洋	太 平 洋 百 貨	太 平 盛 世	太 平 無 象	太 平 間	太 白	太 兇 了	
太 后	太 多	太 妃	太 守	太 忙	太 早	太 死	太 行	
太 低	太 冷	太 君	太 快	太 奇	太 欣 半 導	太 的	太 空	
太 空 人	太 空 人 隊	太 空 飛 行	太 空 站	太 空 梭	太 空 船	太 空 學	太 空 戰 略	
太 空 艙	太 近	太 長	太 阿 之 柄	太 阿 在 握	太 阿 倒 持	太 保	太 保 市	
太 俗	太 甚	太 重	太 倉 一 粟	太 原	太 原 市	太 差	太 師	
太 師 椅	太 弱	太 祖	太 高	太 婆	太 尉	太 強	太 晚	
太 深	太 猛	太 粗	太 設	太 軟	太 陰	太 麻 里	太 傅	
太 棒	太 湖	太 短	太 虛	太 貴	太 陽	太 陽 日	太 陽 穴	
太 陽 光	太 陽 年	太 陽 系	太 陽 神	太 陽 能	太 陽 能 發 電	太 陽 能 電 池	太 陽 帽	
太 陽 隊	太 陽 儀	太 陽 燈	太 陽 鏡	太 陽 鐘	太 極	太 極 拳	太 極 張 三 豐	
太 極 劍	太 歲	太 歲 頭 上 動 土	太 爺	太 過	太 電	太 慢	太 監	
太 緊	太 輕	太 遠	太 寬	太 廟	太 熟	太 熱	太 窮	
太 簡	太 醫	太 壞	太 難	夭 亡	夭 夭	夭 折	夭 桃 濃 李	
孔 口	孔 子	孔 丘	孔 穴	孔 孟	孔 孟 之 道	孔 府	孔 明	
孔 武 有 力	孔 門	孔 型	孔 洞	孔 席 墨 突	孔 徑	孔 教	孔 眼	
孔 雀	孔 雀 石	孔 雀 草	孔 雀 開 屏	孔 道	孔 隙	孔 廟	孔 數	
孔 線	孔 學	孔 戲	孔 類	少 一 半	少 女	少 女 似	少 女 嫩 婦	
少 小	少 不	少 不 了	少 不 更 事	少 不 得	少 不 經 事	少 之	少 少	
少 付	少 奶 奶	少 生 優 生	少 用	少 白 頭	少 交	少 先 隊	少 先 隊 員	
少 列	少 印	少 吃	少 地	少 安 勿 躁	少 安 毋 躁	少 安 無 躁	少 年	
少 年 人	少 年 之 家	少 年 犯	少 年 先 鋒 隊	少 年 老 成	少 年 兒 童	少 年 宮	少 年 期	
少 年 觀 護 所	少 成	少 成 若 性	少 扣	少 收	少 有	少 而 精	少 佐	
少 壯	少 壯 不 努 力	少 壯 派	少 找	少 男	少 男 少 女	少 私 寡 慾	少 見	
少 見 多 怪	少 走 彎 路	少 兒	少 刻	少 征	少 於	少 東	少 林	
少 林 寺	少 的	少 花 錢 多 辦 事	少 則	少 待	少 計	少 時	少 校	
少 納	少 記	少 退	少 配	少 婦	少 尉	少 將	少 得	
少 條 失 教	少 產	少 許	少 陪	少 頃	少 報	少 提	少 棒	
少 發	少 等	少 給	少 貼	少 量	少 開	少 搞	少 爺	
少 裝	少 解	少 運	少 管	少 算	少 說	少 說 多 做	少 數	
少 數 人	少 數 民 族	少 數 民 族 地 區	少 數 服 從 多 數	少 數 派	少 數 黨	少 銷	少 錢	
少 講	少 講 空 話	少 禮	少 轉	少 額	尤 以	尤 加	尤 有	
尤 有 甚 者	尤 佳	尤 其	尤 其 是	尤 其 要	尤 物	尤 指	尤 為	
尤 甚	尤 恩	尤 須	尺 二 秀 才	尺 二 冤 家	尺 子	尺 寸	尺 寸 千 里	
尺 寸 之 功	尺 山 寸 水	尺 中	尺 布 斗 粟	尺 布 繩 趨	尺 有 所 短	尺 板 斗 食	尺 波 電 謝	
尺 度	尺 規	尺 幅 千 里	尺 短 寸 長	尺 數	尺 碼	屯 子	屯 田	
屯 兵	屯 門	屯 留	屯 紮	屯 街 塞 巷	屯 落	屯 墾	屯 積	
屯 糧	屯 糧 積 草	巴 人	巴 人 下 裡	巴 三 覽 四	巴 士	巴 士 公 司	巴 士 站	
巴 山	巴 不 得	巴 巴	巴 巴 劫 劫	巴 巴 結 結	巴 比	巴 比 倫	巴 布 亞 紐 幾 內 亞	
巴 布 亞 新 幾 內 亞	巴 伐 利 亞	巴 西	巴 西 人	巴 西 利 亞	巴 豆	巴 貝 多	巴 拉 圭	
巴 林	巴 金 森 氏 症	巴 青	巴 哈 馬	巴 拿 馬	巴 拿 馬 城	巴 格 達	巴 高 望 上	
巴 勒 斯 坦	巴 基 斯 坦	巴 望	巴 喬	巴 掌	巴 斯 卡 爾	巴 結	巴 塞 隆 那	
巴 塞 羅 那	巴 解 組 織	巴 爾 干	巴 爾 扎 克	巴 爾 的 摩	巴 赫	巴 黎	巴 黎 人	
幻 化	幻 日	幻 片	幻 形	幻 忽 然 間	幻 念	幻 景	幻 畫	
幻 視	幻 象	幻 想	幻 想 力	幻 想 曲	幻 想 家	幻 滅	幻 滅 感	
幻 像	幻 境	幻 影	幻 影 似	幻 燈	幻 燈 片	幻 燈 機	幻 覺	
幻 聽	弔 古 尋 幽	弔 民 伐 罪	弔 唁	弔 喪	弔 慰	引 人	引 人 入 勝	
引 人 注 目	引 人 注 意	引 人 矚 目	引 入	引 入 口	引 力	引 子	引 介	
引 文	引 水	引 水 入 牆	引 水 上 山	引 水 員	引 火	引 火 物	引 火 線	
引 火 燒 身	引 以	引 以 為 戒	引 以 為 恥	引 以 為 榮	引 以 為 憾	引 出	引 玉	
引 玉 之 磚	引 用	引 用 文	引 申	引 申 語	引 示	引 向	引 向 器	
引 而 不 發	引 自	引 行	引 伸	引 吭 高 歌	引 見	引 言	引 足 救 經	
引 車	引 使	引 來	引 兒	引 咎	引 咎 自 責	引 咎 責 躬	引 咎 辭 職	
引 河	引 物	引 狗 入 寨	引 虎 自 衛	引 信	引 流	引 為	引 炸	
引 致	引 述	引 風 吹 火	引 座 員	引 柴	引 狼 入 室	引 航	引 起	
引 起 爭 議	引 起 轟 動	引 退	引 鬼 上 門	引 動	引 商 刻 羽	引 得	引 得 出	
引 接	引 理	引 產	引 逗	引 喻	引 港	引 渡	引 發	
引 著	引 進	引 進 人 才	引 進 外 資	引 進 技 術	引 進 設 備	引 開	引 經 據 古	
引 經 據 典	引 號	引 路	引 道	引 種	引 語	引 誘	引 誘 物	
引 領	引 領 企 踵	引 線	引 線 穿 針	引 導	引 導 員	引 據	引 橋	
引 燃	引 錐 刺 骨	引 頸 受 戮	引 擎	引 薦	引 爆	引 爆 器	引 繩 批 根	
引 繩 排 根	引 證	引 證 者	引 類 呼 朋	引 體	心 力	心 力 交 瘁	心 上	
心 口	心 口 不 一	心 口 如 一	心 不	心 不 在 焉	心 不 應 口	心 中	心 中 有 數	
心 中 無 數	心 內	心 內 膜	心 切	心 心	心 心 相 印	心 心 唸 唸	心 手 相 應	
心 火	心 包	心 包 炎	心 外 膜	心 平 氣 和	心 平 氣 定	心 正	心 甘	
心 甘 情 願	心 田	心 目	心 目 中	心 同	心 向	心 回 意 轉	心 地	
心 地 善 良	心 在 魏 闕	心 如 刀 割	心 如 刀 鋸	心 如 刀 攪	心 如 刀 剉	心 如 木 石	心 如 止 水	
心 如 古 井	心 如 死 灰	心 如 金 石	心 如 堅 石	心 如 寒 灰	心 如 鐵 石	心 安	心 安 神 泰	
心 安 理 得	心 尖	心 忙 意 急	心 曲	心 有	心 有 餘 而 力 不 足	心 有 餘 悸	心 有 靈 犀 一 點 通	
心 灰	心 灰 意 冷	心 灰 意 敗	心 灰 意 懶	心 肌	心 肌 炎	心 肌 梗 塞	心 血	
心 血 來 潮	心 血 管	心 似	心 低	心 坎	心 形	心 形 線	心 志	
心 折 首 肯	心 肝	心 身	心 事	心 些	心 來	心 兒	心 到	
心 和 氣 平	心 底	心 弦	心 往 神 馳	心 怡 神 曠	心 性	心 房	心 拙 口 夯	
心 明 眼 亮	心 服	心 服 口 服	心 服 情 願	心 直	心 直 口 快	心 直 嘴 快	心 知	
心 花	心 花 怒 放	心 花 怒 發	心 花 怒 開	心 長 髮 短	心 室	心 律	心 思	
心 急	心 急 火 燎	心 急 如 火	心 急 如 焚	心 毒	心 活	心 狠	心 狠 手 辣	
心 若 死 灰	心 計	心 重	心 面	心 音	心 悅 神 怡	心 悅 誠 服	心 書	
心 氣	心 浮	心 病	心 疼	心 神	心 神 不 安	心 神 不 定	心 神 不 寧	
心 神 恍 惚	心 胸	心 胸 狹 窄	心 胸 開 闊	心 虔 志 誠	心 高 氣 硬	心 高 氣 傲	心 動	
心 動 神 馳	心 堅 石 穿	心 得	心 得 體 會	心 情	心 情 愉 快	心 情 舒 暢	心 情 壞	
心 悸	心 掏	心 旌 搖 曳	心 涼	心 焉 如 割	心 率	心 理	心 理 上	
心 理 重 建	心 理 劇	心 理 學	心 理 戰	心 眼	心 眼 多	心 眼 兒	心 眼 壞	
心 粗 氣 浮	心 粗 膽 大	心 粗 膽 壯	心 細	心 細 如 髮	心 術	心 術 不 正	心 貫 白 日	
心 軟	心 連 心	心 途	心 都	心 勞 日 拙	心 勞 意 攘	心 勞 意 穰	心 喜	
心 寒	心 寒 膽 碎	心 寒 膽 落	心 寒 膽 戰	心 扉	心 智	心 焦	心 焦 如 火	
心 焦 如 焚	心 無 二 用	心 無 二 想	心 痛	心 窗	心 絞 痛	心 虛	心 裁	
心 貼 心	心 鄉 往 之	心 開 目 明	心 間	心 閒 手 敏	心 黑	心 亂	心 亂 如 麻	
心 傳	心 意	心 慈	心 慈 手 軟	心 慈 面 軟	心 想	心 愛	心 慌	
心 慌 意 亂	心 搏	心 煩	心 煩 意 冗	心 煩 意 亂	心 煩 慮 亂	心 照 不 宣	心 照 神 交	
心 猿 意 馬	心 碎	心 腸	心 腸 好	心 腸 軟	心 腸 硬	心 腸 黑	心 腹	
心 腹 大 患	心 腹 之 交	心 腹 之 疾	心 腹 之 患	心 腹 之 憂	心 腹 重 患	心 腹 話	心 裡	
心 裡 話	心 誠	心 話	心 跡	心 路	心 跳	心 電 圖	心 馳 神 往	
心 馳 魏 闕	心 境	心 實	心 態	心 慵 意 懶	心 滿	心 滿 意 足	心 滿 願 足	
心 窩	心 算	心 緒	心 緒 如 麻	心 緒 恍 惚	心 膂 爪 牙	心 膂 股 肱	心 酸	
心 領	心 領 神 悟	心 領 神 會	心 寬	心 寬 體 肥	心 寬 體 胖	心 廣 體 胖	心 慕 手 追	
心 慕 筆 追	心 數	心 潮	心 潮 起 伏	心 潮 澎 湃	心 醉	心 餘 力 絀	心 魄	
心 學	心 戰	心 機	心 蕩 神 怡	心 蕩 神 迷	心 蕩 神 搖	心 融 神 會	心 靜	
心 頭	心 頭 病	心 聲	心 膽 俱 裂	心 膽 俱 碎	心 謗 腹 非	心 瞻 魏 闕	心 竅	
心 懷	心 懷 不 軌	心 懷 叵 測	心 懷 鬼 胎	心 曠 神 怡	心 曠 神 愉	心 願	心 癢	
心 癢 難 揉	心 癢 難 撓	心 臟	心 臟 形	心 臟 病	心 臟 學	心 驚	心 驚 肉 跳	
心 驚 肉 戰	心 驚 膽 怕	心 驚 膽 寒	心 驚 膽 落	心 驚 膽 跳	心 驚 膽 戰	心 驚 膽 懾	心 驚 膽 顫	
心 靈	心 靈 上	心 靈 手 巧	心 靈 重 建	心 靈 深 處	心 殞 膽 破	心 殞 膽 落	戈 比	
戈 矛	戈 林	戈 爾 巴 喬 夫	戈 壁	戈 壁 灘	戶 下	戶 口	戶 口 簿	
戶 內	戶 戶	戶 主	戶 外	戶 外 活 動	戶 列 簪 纓	戶 名	戶 別	
戶 告 人 曉	戶 長	戶 政 司	戶 政 機 關	戶 限	戶 家	戶 部	戶 牌	
戶 給 人 足	戶 對 門 當	戶 數	戶 樞	戶 樞 不 蠢	戶 樞 不 蠹	戶 縣	戶 頭	
戶 藉	戶 籍	手 力	手 下	手 下 留 情	手 上	手 刃	手 工	
手 工 匠	手 工 制	手 工 勞 動	手 工 業	手 工 業 者	手 工 業 品	手 工 課	手 工 操 作	
手 工 藝	手 工 藝 品	手 巾	手 不 停 揮	手 不 輟 卷	手 不 釋 卷	手 中	手 中 有 權	
手 中 無 權	手 心	手 爪	手 仗	手 令	手 冊	手 巧	手 本	
手 札	手 生	手 用	手 印	手 忙	手 忙 腳 亂	手 快	手 抄	
手 抄 本	手 扶	手 扶 拖 拉 機	手 把	手 把 手	手 杖	手 肘	手 足	
手 足 之 情	手 足 失 措	手 足 胼 胝	手 足 異 處	手 足 無 措	手 車	手 兒	手 到	
手 到 拿 來	手 到 病 除	手 到 擒 來	手 制	手 制 動	手 卷	手 帕	手 底 下	
手 拉 手	手 拔	手 法	手 長	手 勁	手 急 眼 快	手 持	手 指	
手 指 印	手 指 頭	手 拷	手 挑 選	手 柄	手 段	手 相	手 相 家	
手 相 術	手 背	手 訂	手 重	手 面	手 風 琴	手 套	手 拿	
手 挽 手	手 旁	手 書	手 氣	手 疾 眼 快	手 紋	手 紙	手 胼 足 胝	
手 記	手 起 刀 落	手 動	手 推	手 推 車	手 推 磨	手 淫	手 牽 手	
手 球	手 眼	手 術	手 術 台	手 術 前	手 術 後	手 袋	手 軟	
手 部	手 掌	手 掌 狀	手 提	手 提 包	手 提 式	手 提 箱	手 揮 目 送	
手 無 寸 鐵	手 無 縛 雞 之 力	手 畫 線	手 筆	手 腕	手 腕 子	手 間	手 勤	
手 勢	手 感	手 慌 腳 亂	手 搖	手 搖 車	手 搖 鈴	手 搖 鑽	手 滑 心 慈	
手 絹	手 腳	手 腳 無 措	手 裡	手 跡	手 閘	手 雷	手 電	
手 電 筒	手 飾	手 鼓	手 奪	手 榴 彈	手 緊	手 舞 足 蹈	手 語	
手 輕	手 寫	手 寫 體	手 稿	手 編	手 談	手 輪	手 銬	
手 機	手 諭	手 錶	手 錶 商	手 鋸	手 頭	手 頭 上	手 頭 不 便	
手 環	手 臂	手 戳	手 織	手 鎗	手 藝	手 藝 人	手 邊	
手 爐	手 癢	手 續	手 續 費	手 鐲	手 鑽	扎 入	扎 小 辮	
扎 手	扎 手 舞 腳	扎 扎 實 實	扎 以 爾	扎 布 機	扎 伊 爾	扎 伊 爾 人	扎 牢	
扎 花	扎 穿	扎 捆	扎 紙	扎 針	扎 堆	扎 眼	扎 痛	
扎 進	扎 傷	扎 幌 市	扎 鋼	扎 襄	扎 穩 打	扎 辮 子	支 支 吾 吾	
支 付	支 付 日	支 付 者	支 付 款	支 出	支 左	支 用	支 字	
支 行	支 住	支 助	支 吾	支 吾 其 詞	支 局	支 走	支 那	
支 使	支 取	支 委	支 委 會	支 店	支 承	支 前	支 前 工 作	
支 持	支 持 下	支 持 物	支 持 者	支 持 點	支 柱	支 架	支 流	
支 派	支 竿	支 庫	支 座	支 息	支 書	支 氣 管	支 索	
支 脈	支 配	支 配 人	支 配 力	支 配 下	支 配 者	支 配 權	支 桿	
支 票	支 票 簿	支 船 柱	支 部	支 部 書 記	支 單	支 援	支 援 者	
支 援 前 線	支 款	支 渠	支 給	支 著 兒	支 開	支 隊	支 稜	
支 葉 扶 疏	支 解	支 路	支 農	支 領	支 撐	支 撐 力	支 撐 物	
支 撐 點	支 撥	支 數	支 樞	支 線	支 應	支 薪	支 點	
支 離	支 離 破 碎	支 離 繁 碎	支 邊	支 護	文 人	文 人 相 輕	文 人 墨 客	
文 山	文 山 會 海	文 工 團	文 才	文 丑	文 不 加 點	文 不 對 題	文 不 盡 意	
文 中	文 內	文 化	文 化 人	文 化 上	文 化 大 革 命	文 化 工 作	文 化 中 心	
文 化 水 平	文 化 市 場	文 化 生 活	文 化 交 流	文 化 合 作	文 化 局	文 化 事 業	文 化 知 識	
文 化 表 演	文 化 建 設	文 化 建 設 委 員 會	文 化 活 動	文 化 界	文 化 科 學	文 化 娛 樂	文 化 娛 樂 活 動	
文 化 宮	文 化 站	文 化 素 質	文 化 教 育	文 化 理 論	文 化 部	文 化 程 度	文 化 傳 統	
文 化 節	文 化 網 址	文 化 層	文 化 衝 突	文 化 整 合	文 化 機 構	文 化 遺 址	文 化 遺 產	
文 化 館	文 化 藝 術	文 心 蘭	文 火	文 以 載 道	文 史	文 史 資 料	文 史 館	
文 句	文 旦	文 本	文 件	文 件 名	文 件 夾	文 件 尾	文 件 彙 編	
文 件 精 神	文 地	文 如 其 人	文 字	文 字 上	文 字 前	文 字 處 理	文 字 說 明	
文 式	文 江 學 海	文 竹	文 臣	文 行	文 君 司 馬	文 君 早 寡	文 君 新 寡	
文 告	文 抄 公	文 改	文 言	文 言 文	文 身	文 身 斷 髮	文 具	
文 具 店	文 具 商	文 具 盒	文 卷	文 官	文 性	文 房	文 房 四 士	
文 房 四 寶	文 昌 魚	文 明	文 明 人	文 明 化	文 明 社 會	文 明 病	文 明 單 位	
文 明 禮 貌	文 東 武 西	文 武	文 武 之 道	文 武 全 才	文 武 兼 備	文 武 兼 濟	文 武 雙 全	
文 法	文 法 上	文 法 家	文 法 素	文 治 武 功	文 物	文 物 古 跡	文 物 局	
文 物 館	文 盲	文 采	文 采 風 流	文 品	文 契	文 建 會	文 思	
文 恬 武 嬉	文 炳 雕 龍	文 科	文 英	文 苑	文 革	文 風	文 風 不 動	
文 修 武 偃	文 修 武 備	文 娛	文 娛 活 動	文 庫	文 弱	文 書	文 書 工 作	
文 氣	文 海	文 脈	文 脈 上	文 鬥	文 從 字 順	文 教	文 教 局	
文 教 基 金 會	文 教 衛 生	文 教 機 構	文 深 網 密	文 理	文 理 不 通	文 責	文 責 自 負	
文 章	文 章 巨 公	文 章 星 斗	文 章 蓋 世	文 章 魁 首	文 章 憎 命	文 場	文 無 加 點	
文 痞	文 筆	文 萊	文 蛤	文 詞	文 貴 天 成	文 雅	文 集	
文 匯	文 匯 報	文 經 武 略	文 經 武 緯	文 義	文 聖	文 號	文 過 遂 非	
文 過 飾 非	文 電	文 飾	文 摘	文 豪	文 齊 福 不 齊	文 儈	文 德 武 功	
文 稿	文 質	文 質 彬 彬	文 墨	文 壇	文 學	文 學 士	文 學 史	
文 學 作 品	文 學 知 識	文 學 思 想	文 學 思 潮	文 學 界	文 學 研 究	文 學 家	文 學 理 論	
文 學 創 作	文 學 評 論	文 學 遺 產	文 學 藝 術	文 憑	文 擅 雕 龍	文 曄 科 技	文 縐 縐	
文 翰	文 選	文 錢	文 靜	文 館	文 戲	文 檔	文 檔 資 料	
文 聯	文 職	文 職 人 員	文 牘 主 義	文 藝	文 藝 界	文 藝 家	文 藝 復 興	
文 藝 節 目	文 辭	文 韜 武 略	文 韜 武 韜	文 獻	文 獻 工 作	文 獻 分 類	文 獻 研 究 室	
文 獻 彙 編	文 獻 資 料	文 獻 標 引	文 獻 學	文 獻 檢 索	文 藻	文 體	文 體 活 動	
文 體 論	斗 人	斗 子	斗 六	斗 升 之 水	斗 升 之 祿	斗 方	斗 方 名 士	
斗 車	斗 門	斗 南 一 人	斗 南 鎮	斗 室	斗 拱	斗 重 山 齊	斗 倒	
斗 斛 之 祿	斗 眼	斗 笠	斗 渠	斗 絕 一 隅	斗 量 車 載	斗 箕	斗 蓬	
斗 膽	斗 轉 星 移	斗 轉 參 橫	斗 櫥	斗 筲 小 人	斗 筲 小 器	斗 筲 之 人	斗 筲 之 才	
斗 筲 之 材	斗 筲 之 徒	斗 筲 之 輩	斗 筲 之 器	斗 筲 穿 窬	斤 斗	斤 斤	斤 斤 計 較	
斤 兩	斤 頂	斤 數	方 丈	方 丈 盈 前	方 土 霖	方 士	方 子	
方 寸	方 寸 已 亂	方 寸 之 地	方 山	方 巾	方 才	方 今	方 尺	
方 文 琳	方 方	方 方 正 正	方 方 面 面	方 且	方 出	方 可	方 外	
方 外 之 人	方 正	方 正 不 阿	方 正 不 苟	方 石	方 示	方 交	方 向	
方 向 性	方 向 舵	方 向 感	方 向 盤	方 地	方 式	方 竹	方 米	
方 自	方 舟	方 位	方 位 判 定	方 位 角	方 岑	方 形	方 步	
方 言	方 言 區	方 言 學	方 些	方 使	方 來	方 始	方 季 韋	
方 底 圓 蓋	方 法	方 法 論	方 法 學	方 知	方 芳	方 便	方 便 之 門	
方 便 面	方 城	方 為	方 面	方 面 大 耳	方 面 軍	方 音	方 差	
方 時	方 案	方 框	方 框 圖	方 根	方 桌	方 格	方 桃 譬 李	
方 能	方 針	方 針 政 策	方 陣	方 略	方 術	方 許	方 趾 圓 顱	
方 勝	方 帽	方 斯 蔑 如	方 程	方 程 式	方 程 序	方 程 組	方 給	
方 圓	方 塊	方 塊 字	方 塊 舞	方 新 舟	方 解	方 解 石	方 鉛 礦	
方 靖	方 凳	方 對	方 語	方 語 言	方 說	方 領 矩 步	方 數	
方 盤	方 駕 齊 驅	方 劑	方 糖	方 興 未 艾	方 鋼	方 頭 不 劣	方 頭 不 律	
方 戲	方 鑿 圓 枘	方 枘 圓 鑿	日 人	日 下	日 下 無 雙	日 上 三 竿	日 久	
日 久 天 長	日 久 月 深	日 久 見 人 心	日 久 歲 深	日 子	日 工 資	日 不 移 晷	日 不 移 影	
日 不 暇 給	日 中	日 中 必 彗	日 中 則 昃	日 元	日 內	日 內 瓦	日 化	
日 引 月 長	日 文	日 方	日 日	日 日 夜 夜	日 曰	日 月	日 月 入 懷	
日 月 交 食	日 月 光	日 月 合 璧	日 月 如 流	日 月 如 梭	日 月 其 除	日 月 星 辰	日 月 重 光	
日 月 參 辰	日 月 經 天 江 河 行 地	日 月 逾 邁	日 月 潭	日 月 蹉 跎	日 月 麗 天	日 以 繼 夜	日 出	
日 出 三 竿	日 刊	日 加 工	日 半	日 本	日 本 人	日 本 化	日 本 式	
日 本 股 市	日 本 政 治	日 本 海	日 本 問 題	日 本 國	日 本 經 濟	日 本 語	日 本 學	
日 用	日 用 工 業 品	日 用 百 貨	日 用 品	日 用 消 費 品	日 立	日 立 製 作 所	日 光	
日 光 浴	日 光 燈	日 共	日 成	日 托	日 收	日 行 千 里	日 西	
日 均	日 坐 愁 城	日 見	日 角 珠 庭	日 角 偃 月	日 來	日 制	日 夜	
日 夜 兼 程	日 居 月 諸	日 往 月 來	日 昇 月 恆	日 服	日 炙 風 吹	日 炙 風 篩	日 表	
日 近 長 安 遠	日 俄	日 前	日 後	日 思 夜 想	日 持	日 甚 一 日	日 界	
日 界 線	日 省 月 試	日 省 月 課	日 盼	日 美	日 軍	日 食	日 食 萬 錢	
日 俱	日 射 病	日 差	日 書	日 班	日 益	日 益 月 滋	日 益 完 善	
日 益 頻 繁	日 神	日 記	日 記 簿	日 高 三 丈	日 冕	日 商	日 商 三 和 銀 行	
日 寇	日 常	日 常 工 作	日 常 生 活	日 理 萬 機	日 產	日 產 量	日 盛 證 券	
日 處 理 能 力	日 規	日 規 儀	日 創	日 勝 化 工	日 場	日 報	日 報 表	
日 就 月 將	日 復 一 日	日 斑	日 晷	日 晷 儀	日 期	日 滋 月 益	日 程	
日 程 表	日 間	日 圓	日 慎 一 日	日 新	日 新 月 異	日 暈	日 暖	
日 暖 風 和	日 照	日 落	日 落 西 山	日 裔	日 試 萬 言	日 資	日 馳 企 業	
日 幣	日 漸	日 漸 月 染	日 爾 曼	日 與 月	日 蝕	日 誦 五 車	日 誌	
日 誌 簿	日 語	日 增 月 益	日 影	日 數	日 暮	日 暮 途 遠	日 暮 途 窮	
日 銷	日 銷 月 鑠	日 壇	日 壇 公 園	日 曆	日 積 月 累	日 頭	日 濡 月 染	
日 環	日 環 食	日 薪	日 薄	日 薄 西 山	日 趨	日 鍛 月 煉	日 戳	
日 轉 千 街	日 轉 千 階	日 雜	日 麗 風 和	日 曬	日 旰 忘 食	日 昃 忘 食	月 了	
月 入	月 下	月 下 老 人	月 下 花 前	月 下 星 前	月 下 風 前	月 夕	月 夕 花 朝	
月 子	月 工 資	月 中	月 中 折 桂	月 內	月 日	月 月	月 牙	
月 出	月 刊	月 半	月 台	月 未	月 末	月 白	月 白 風 清	
月 石	月 份	月 光	月 光 如 水	月 光 計 劃	月 地 雲 階	月 收	月 收 入	
月 老	月 色	月 形	月 夜	月 夜 花 朝	月 季	月 底	月 明	
月 明 如 晝	月 明 星 稀	月 盲 症	月 芽	月 初	月 長 石	月 門	月 亮	
月 亮 似	月 前	月 度	月 後	月 盈	月 盈 則 食	月 相	月 眉 星 眼	
月 計	月 面	月 食	月 俸	月 值 年 災	月 娘	月 宮	月 息	
月 書 赤 繩	月 朗 風 清	月 桂	月 桂 冠	月 桂 樹	月 神	月 租	月 缺	
月 缺 花 殘	月 缺 難 圓	月 清	月 球	月 理	月 理 學	月 產	月 產 量	
月 異	月 票	月 終	月 報	月 琴	月 結	月 費	月 間	
月 黑 風 高	月 圓	月 暈	月 暈 而 風 礎 潤 而 雨	月 經	月 經 期	月 落	月 落 星 沉	
月 落 烏 啼	月 落 參 橫	月 過 中 秋	月 滿 花 香	月 滿 則 虧	月 蝕	月 貌 花 容	月 貌 花 龐	
月 餅	月 數	月 輪	月 壇	月 曆	月 艙	月 薪	月 虧	
月 鍛 季 煉	月 齡	木 乃 伊	木 人	木 人 石 心	木 工	木 工 師	木 工 術	
木 工 藝	木 已 成 舟	木 巳 成 舟	木 心 石 腹	木 片	木 牛	木 本	木 本 水 源	
木 本 植 物	木 瓜	木 石	木 石 為 徒	木 立	木 匠	木 朽 不 雕	木 灰	
木 耳	木 舟	木 色	木 行	木 床	木 形 灰 心	木 材	木 材 場	
木 村 拓 哉	木 刻	木 刻 家	木 刻 畫	木 底	木 房	木 林	木 板	
木 板 畫	木 板 路	木 版	木 版 畫	木 狀	木 門	木 型	木 屋	
木 拴	木 星	木 柱	木 架	木 柵	木 炭	木 炭 畫	木 香	
木 屑	木 屐	木 料	木 框	木 梳	木 柴	木 栓	木 粉	
木 紋	木 釘	木 馬	木 偶	木 偶 戲	木 排	木 梯	木 桿	
木 桶	木 條	木 條 箱	木 球	木 船	木 荷	木 訥	木 造	
木 造 品	木 魚	木 麻 黃	木 場	木 棺	木 椅	木 棒	木 棍	
木 棉	木 棉 花	木 棉 樹	木 棚	木 殼	木 焦 油	木 然	木 猴 而 冠	
木 琴	木 筆	木 筏	木 結	木 結 構	木 塞	木 塞 子	木 塊	
木 道	木 墊	木 槌	木 管	木 腿	木 製	木 製 品	木 劍	
木 履	木 樁	木 盤	木 箱	木 質	木 質 化	木 質 素	木 質 部	
木 鞋	木 器	木 橋	木 雕	木 雕 工	木 雕 泥 塑	木 頭	木 頭 人	
木 頭 木 腦	木 薯	木 錘	木 鍬	木 叢	木 壘	木 簡	木 雞	
木 雞 養 到	木 欄	木 蘭	木 蘭 花	木 籠	木 樨	欠 下	欠 戶	
欠 付	欠 交	欠 安	欠 收	欠 收 自 補	欠 考 慮	欠 伸	欠 妥	
欠 身	欠 佳	欠 明	欠 的	欠 思	欠 思 考	欠 思 慮	欠 席	
欠 時	欠 租	欠 缺	欠 帳	欠 條	欠 爽	欠 產	欠 款	
欠 稅	欠 著	欠 債	欠 債 還 錢	欠 慎 重	欠 當	欠 資	欠 撥	
欠 賬	欠 據	欠 錢	欠 薪	欠 繳	止 不 住	止 戈 為 武	止 戈 散 馬	
止 戈 興 仁	止 日	止 付	止 汗 劑	止 血	止 血 鉗	止 血 器	止 住	
止 扮 自 修	止 步	止 於	止 於 至 善	止 咳	止 怒	止 息	止 期	
止 渴	止 渴 思 梅	止 渴 飲 鴆	止 痛	止 痛 片	止 痛 法	止 痛 劑	止 痛 藥	
止 跌	止 境	止 暴 禁 非	止 謗 莫 若 自 修	止 瀉	止 瀉 劑	止 癢	歹 人	
歹 毒	歹 徒	歹 意	毋 忘	毋 到	毋 庸	毋 望 之 福	毋 望 之 禍	
毋 單	毋 須	毋 寧	毋 需	毋 翼 而 飛	毋 躁	比 了	比 下 有 餘	
比 上 不 足	比 上 不 足 比 下 有 餘	比 不 上	比 之	比 分	比 反	比 手 畫 腳	比 方	
比 比 皆 是	比 比 皆 然	比 比 劃 劃	比 以 往 任 何 時 候 都	比 他	比 去 年 同 期 下 降	比 目	比 目 連 枝	
比 目 魚	比 好	比 她	比 如	比 如 說	比 年 不 登	比 色	比 色 計	
比 作	比 利 時	比 利 時 人	比 快	比 我	比 例	比 例 中 項	比 例 尺	
比 例 失 調	比 例 規	比 例 關 係	比 來	比 武	比 物 此 志	比 物 連 類	比 的	
比 肩 而 立	比 肩 而 事	比 肩 皆 是	比 肩 隨 踵	比 肩 繼 踵	比 附	比 屋 可 封	比 屋 而 封	
比 拼	比 為	比 重	比 重 計	比 值	比 容	比 書	比 特	
比 索	比 起	比 配	比 高	比 做	比 基 尼	比 張 比 李	比 得	
比 得 上	比 率	比 喻	比 畫	比 著	比 評	比 量	比 歲 不 登	
比 照	比 號	比 試	比 較	比 較 級	比 較 慢	比 較 儀	比 較 器	
比 劃	比 爾	比 爾 蓋 茲	比 價	比 數	比 熱	比 諸	比 鄰	
比 學 趕 幫	比 學 趕 幫 超	比 歷 史 最 高 水 平	比 貓 畫 虎	比 擬	比 翼	比 翼 連 枝	比 翼 齊 飛	
比 翼 雙 飛	比 賽	比 賽 規 則	比 賽 項 目	比 薩	比 薩 餅	毛 一 般	毛 子	
毛 巾	毛 巾 被	毛 孔	毛 手	毛 手 毛 腳	毛 毛	毛 毛 雨	毛 片	
毛 主 席	毛 布	毛 白	毛 皮	毛 皮 商	毛 皮 袋	毛 地 黃	毛 多	
毛 尖	毛 竹	毛 衣	毛 估	毛 利	毛 利 人	毛 利 率	毛 利 語	
毛 豆	毛 刷	毛 刺	毛 制	毛 呢	毛 狀	毛 狀 體	毛 施 淑 姿	
毛 派	毛 玻 璃	毛 重	毛 值	毛 料	毛 桃	毛 病	毛 紡	
毛 紡 廠	毛 紡 織 廠	毛 茸	毛 茸 茸	毛 草	毛 茶	毛 骨 悚 然	毛 骨 聳 然	
毛 骨 竦 然	毛 條	毛 票	毛 細	毛 細 血 管	毛 細 現 象	毛 細 管	毛 帽	
毛 毯	毛 筆	毛 筍	毛 絨	毛 絮	毛 詞	毛 損	毛 瑟 槍	
毛 裝	毛 裡	毛 裡 求 斯	毛 裡 塔 尼 亞	毛 詩	毛 遂 自 薦	毛 團	毛 領	
毛 樣	毛 箭	毛 線	毛 髮	毛 髮 之 功	毛 髮 似	毛 髮 倒 豎	毛 髮 悚 然	
毛 髮 森 豎	毛 髮 學	毛 髮 聳 然	毛 澤 東	毛 澤 東 思 想	毛 褲	毛 錢	毛 頭	
毛 氈	毛 氈 苔	毛 糙	毛 舉 細 事	毛 舉 細 故	毛 舉 細 務	毛 舉 縷 析	毛 叢	
毛 叢 狀	毛 織	毛 織 物	毛 織 品	毛 蟲	毛 繩	毛 邊	毛 寶 公 司	
毛 躁	毛 襪	毛 驢	毛 坯	毛 撣	毛 撣 子	氏 族	水 力	
水 力 發 電	水 力 資 源	水 力 學	水 下	水 上	水 上 芭 蕾	水 上 活 動	水 上 飛 機	
水 上 鄉	水 上 運 動	水 上 摩 托 車	水 土	水 土 不 服	水 土 保 持	水 土 流 失	水 土 資 源	
水 大 魚 多	水 工	水 中	水 中 兵 器	水 中 捉 月	水 中 撈 月	水 井	水 分	
水 分 多	水 化	水 天 一 色	水 孔	水 手	水 手 長	水 手 隊	水 文	
水 文 地 質	水 文 科 學	水 文 氣 象	水 文 站	水 文 學	水 文 學 家	水 斗	水 月 鏡 花	
水 月 鏡 像	水 月 觀 音	水 木	水 火	水 火 不 相 容	水 火 不 辭	水 火 無 交	水 火 無 情	
水 牛	水 牛 城	水 仙	水 叮 噹	水 平	水 平 面	水 平 儀	水 平 線	
水 平 翼	水 母	水 母 目 蝦	水 汀	水 生	水 田	水 份	水 份 多	
水 光	水 光 山 色	水 光 接 天	水 印	水 合 物	水 地	水 成	水 曲 柳	
水 池	水 污	水 污 染	水 竹	水 米 無 交	水 色	水 色 山 光	水 位	
水 位 標	水 兵	水 冷	水 利	水 利 工 程	水 利 化	水 利 局	水 利 建 設	
水 利 部	水 利 資 源	水 利 樞 紐	水 利 學	水 利 廳	水 坑	水 旱	水 旱 災 害	
水 旱 輪 作	水 杉	水 沙	水 汪 汪	水 汽	水 災	水 牢	水 秀 山 明	
水 系	水 車	水 里 鄉	水 乳	水 乳 之 契	水 乳 交 融	水 供	水 來	
水 來 土 掩	水 來 伸 手 飯 來 張 口	水 具	水 到 渠 成	水 咀	水 底	水 底 摸 月	水 底 撈 明 月	
水 底 撈 針	水 怪	水 性	水 性 楊 花	水 性 隨 邪	水 果	水 果 汁	水 果 商	
水 果 渣	水 果 畫	水 果 糖	水 林	水 松	水 泥	水 泥 工 業	水 泥 匠	
水 泥 股	水 泥 廠	水 泥 漿	水 波	水 沫	水 泡	水 泡 疹	水 肥	
水 芹	水 花	水 表	水 門	水 前	水 垢	水 星	水 柱	
水 流	水 流 花 謝	水 洞	水 洗	水 泵	水 洩	水 洩 不 通	水 洩 不 漏	
水 玻 璃	水 界	水 盆	水 缸	水 軍	水 面	水 面 下	水 面 上	
水 害	水 師	水 庫	水 氣	水 浸	水 浴	水 珠	水 皰 疹	
水 紋	水 耕 法	水 脈	水 能	水 能 載 舟 亦 能 覆 舟	水 舀	水 荒	水 草	
水 蚤	水 送 山 迎	水 酒	水 鬼	水 動	水 域	水 宿 風 餐	水 密	
水 帶	水 彩	水 彩 畫	水 患	水 情	水 族	水 族 館	水 桶	
水 淺	水 清 無 魚	水 淹	水 深	水 深 火 熱	水 深 度	水 淨 鵝 飛	水 球	
水 理 學	水 瓶	水 瓶 座	水 產	水 產 局	水 產 品	水 產 業	水 產 養 殖	
水 缽	水 處 理	水 蛇	水 貨	水 通 燈 亮	水 部	水 陸	水 陸 交 通	
水 陸 空	水 陸 畢 陳	水 陸 聯 運	水 鳥	水 壺	水 壺 蓋	水 晶	水 晶 制	
水 晶 宮	水 棲	水 渠	水 渦	水 痘	水 筆	水 筒	水 蛭	
水 貂	水 費	水 鄉	水 量	水 勢	水 塘	水 塔	水 暖 工	
水 楊	水 溶	水 溶 性	水 溶 液	水 源	水 溝	水 溫	水 準	
水 準 儀	水 煙	水 煙 袋	水 煙 筒	水 煤 氣	水 禽	水 腫	水 腫 病	
水 落	水 落 石 出	水 落 管	水 落 歸 槽	水 葬	水 裡	水 解	水 資 源	
水 路	水 運	水 道	水 道 學	水 鉛	水 閘	水 閘 門	水 雷	
水 雷 區	水 電	水 電 站	水 電 部	水 電 費	水 靴	水 團	水 槍	
水 榭	水 滴	水 滴 石 穿	水 漬	水 漏	水 漲 船 高	水 盡	水 盡 山 窮	
水 盡 鵝 飛	水 碧 山 青	水 窪	水 管	水 管 車	水 綠	水 綠 山 青	水 網	
水 蒸 汽	水 蒸 氣	水 蜜 桃	水 蜥	水 遠 山 長	水 遠 山 搖	水 銀	水 銀 柱	
水 銀 劑	水 銀 燈	水 閣	水 餃	水 層	水 廠	水 槽	水 漿 不 入	
水 潔 冰 清	水 澆	水 澆 地	水 潭	水 稻	水 窮 山 盡	水 箱	水 線	
水 膠	水 蔥	水 質	水 輪	水 輪 機	水 墨 畫	水 劑	水 壁	
水 戰	水 瓢	水 磨	水 磨 功 夫	水 磨 石	水 蕩	水 選	水 頭	
水 龍	水 龍 頭	水 壓	水 濱	水 療	水 療 法	水 療 院	水 翼 船	
水 聲	水 錘	水 闊 山 高	水 斷 陸 絕	水 覆 難 收	水 獺	水 簾	水 邊	
水 霧	水 藻	水 體	水 壩	水 罐	水 靈	水 靈 靈	水 鹼	
水 湳 機 場	水 滸	水 澇	水 螅	水 ��	火 力	火 力 配 置	火 力 發 電	
火 力 發 電 廠	火 上	火 上 加 油	火 上 弄 冰	火 上 弄 冰 凌	火 上 添 油	火 口	火 大	
火 山	火 山 口	火 山 土	火 山 似	火 山 湯 海	火 山 學	火 山 爆 發	火 山 巖	
火 中	火 中 取 栗	火 化	火 夫	火 火	火 石	火 光	火 刑	
火 刑 柱	火 地	火 成 巖	火 舌	火 色	火 坑	火 把	火 攻	
火 災	火 車	火 車 站	火 車 票	火 車 意 外	火 車 頭	火 並	火 具	
火 性	火 拚	火 油	火 炕	火 狐	火 花	火 花 塞	火 門	
火 冒 三 丈	火 前	火 急	火 星	火 星 人	火 柱	火 炬	火 炬 計 劃	
火 炭	火 炮	火 盆	火 紅	火 紅 色	火 苗	火 候	火 柴	
火 柴 盒	火 氣	火 海	火 神	火 耕 水 種	火 耕 水 耨	火 耕 流 種	火 堆	
火 情	火 控	火 眼	火 眼 金 睛	火 蛇	火 速	火 傘 高 張	火 場	
火 焚	火 焰	火 焰 似	火 焰 噴 射 器	火 然 泉 達	火 勢	火 滅 煙 消	火 葬	
火 葬 者	火 葬 場	火 葬 爐	火 電	火 電 站	火 槍	火 漆	火 種	
火 網	火 腿	火 辣	火 辣 辣	火 暴	火 熱	火 熱 水 深	火 箭	
火 箭 炮	火 箭 筒	火 箭 學	火 箭 爆 破 器	火 線	火 器	火 樹	火 樹 琪 花	
火 樹 銀 花	火 熾	火 燒	火 燒 火 燎	火 燒 似	火 燒 眉 毛	火 耨 刀 耕	火 險	
火 頭	火 龍	火 燭	火 燭 小 心	火 牆	火 鍋	火 點	火 雞	
火 雞 肉	火 爆	火 繩	火 藥	火 藥 味	火 爐	火 警	火 鐮	
火 罐	火 鹼	爪 子	爪 牙	爪 牙 之 士	爪 牙 之 將	爪 甲	爪 印	
爪 兒	爪 哇	爪 哇 人	爪 哇 語	爪 痕	父 女	父 子	父 方	
父 王	父 兄	父 本	父 母	父 母 之 邦	父 母 之 命 媒 妁 之 言	父 母 在 不 遠 遊	父 母 官	
父 母 恩 勤	父 母 親	父 名	父 老	父 老 兄 弟	父 系	父 命	父 析 子 荷	
父 為 子 隱	父 執	父 慈 子 孝	父 愛	父 道	父 稱	父 輩	父 親	
父 嚴 子 孝	父 權	父 權 制	片 上	片 子	片 片	片 瓦	片 瓦 無 存	
片 甲	片 甲 不 回	片 甲 不 存	片 甲 不 留	片 甲 無 存	片 目	片 名	片 尾	
片 形	片 言	片 言 一 字	片 言 只 語	片 言 折 獄	片 言 隻 字	片 兒	片 刻	
片 刻 前	片 狀	片 長 末 技	片 長 薄 技	片 段	片 約	片 面	片 面 性	
片 面 強 調	片 時	片 紙	片 紙 隻 字	片 假 名	片 接 寸 附	片 善 小 才	片 集	
片 雲	片 雲 遮 頂	片 酬	片 語	片 語 只 辭	片 劑	片 頭	片 斷	
片 簿	片 欄	片 巖	片 鱗 半 爪	片 鱗 碎 甲	牙 牙	牙 牙 學 語	牙 外	
牙 白 口 清	牙 石	牙 印	牙 色	牙 行	牙 床	牙 刷	牙 周 炎	
牙 垢	牙 科	牙 音	牙 座	牙 根	牙 疳	牙 疼	牙 粉	
牙 祭	牙 椅	牙 痛	牙 買 加	牙 買 加 人	牙 飾	牙 膏	牙 線	
牙 質	牙 輪	牙 齒	牙 雕	牙 縫	牙 蟲	牙 醫	牙 關	
牙 齦	牙 籤	牙 籤 玉 軸	牙 籤 犀 軸	牙 籤 萬 軸	牙 籤 錦 軸	牙 髓 神 經	牙 磣	
牛	牛 刀	牛 刀 小 試	牛 刀 割 雞	牛 丸 米 粉	牛 之 一 毛	牛 毛	牛 毛 細 雨	
牛 仔	牛 仔 衫	牛 仔 帽	牛 仔 褲	牛 叫	牛 奶	牛 奶 酒	牛 奶 場	
牛 奶 等	牛 奶 糖	牛 市	牛 扒	牛 皮	牛 皮 紙	牛 年	牛 年 馬 月	
牛 羊	牛 耳	牛 耳 藝 術	牛 肉	牛 肉 汁	牛 肉 乾	牛 舌 草	牛 衣 對 泣	
牛 尾	牛 角	牛 角 尖	牛 角 掛 書	牛 車	牛 乳	牛 油	牛 肺	
牛 軋 糖	牛 勁	牛 娃	牛 屎	牛 流 行 熱	牛 津	牛 津 城	牛 郎	
牛 郎 織 女	牛 氣	牛 脂	牛 馬	牛 鬼	牛 鬼 蛇 神	牛 排	牛 捨	
牛 眼	牛 脖	牛 棚	牛 痘	牛 痘 苗	牛 筋	牛 脾 氣	牛 蛙	
牛 飲	牛 黃	牛 群	牛 頓	牛 鼎 烹 雞	牛 腿	牛 鳴 聲	牛 鼻	
牛 鼻 子	牛 膝 草	牛 蹄 中 魚	牛 頭	牛 頭 不 對 馬 面	牛 頭 不 對 馬 嘴	牛 頭 犬	牛 頭 馬 面	
牛 糞	牛 犢	牛 犢 子	牛 蠅	牛 欄	牛 驥 共 牢	牛 驥 同 皂	牛 溲 馬 勃	
牛 餼 退 敵	犬 不 夜 吠	犬 牙	犬 牙 交 錯	犬 牙 相 制	犬 牙 相 臨	犬 牙 差 互	犬 牙 盤 石	
犬 牙 鷹 爪	犬 吠	犬 吠 之 警	犬 兔 俱 斃	犬 馬	犬 馬 之 心	犬 馬 之 年	犬 馬 之 命	
犬 馬 之 計	犬 馬 之 疾	犬 馬 之 勞	犬 馬 之 報	犬 馬 之 誠	犬 馬 之 養	犬 馬 之 齒	犬 馬 之 戀	
犬 馬 齒 索	犬 馬 齒 勞	犬 馬 戀 主	犬 嗅 覺	犬 敲 門 磚	犬 齒	犬 儒	犬 儒 主 義	
犬 聲	王 八	王 八 蛋	王 力 宏	王 子	王 子 犯 法 庶 民 同 罪	王 小 棣	王 公	
王 公 大 人	王 公 貴 人	王 公 貴 戚	王 公 貴 族	王 水	王 母	王 永 慶	王 立 彬	
王 光 輝	王 后	王 妃	王 安 憶	王 羽	王 位	王 佐 之 才	王 廷 相	
王 志 剛	王 官	王 府	王 府 井	王 法	王 金 平	王 侯	王 冠	
王 室	王 建 民	王 思 婷	王 相	王 美 雪	王 貞 治	王 候 將 相	王 孫	
王 孫 公 子	王 孫 貴 戚	王 家	王 家 衛	王 宮	王 座	王 貢 彈 冠	王 偉 忠	
王 國	王 族	王 祥 臥 冰	王 雪 娥	王 傑	王 朝	王 牌	王 菲	
王 鈞	王 爺	王 道	王 蒙	王 銘 琬	王 漿	王 靜 瑩	王 儲	
王 爵	王 識 賢	王 耀 慶	王 馨 平	王 權	丙 丁	丙 午	丙 方	
丙 申	丙 戌	丙 辰	丙 級	丙 基	丙 烯	丙 烯 荃	丙 烯 酸	
丙 烯 醛	丙 等	丙 種	丙 綸	丙 醇	丙 類	丙 烷	丙 酮	
世 人	世 上	世 上 無 難 事	世 子	世 仇	世 世 代 代	世 世 生 生	世 代	
世 代 相 傳	世 代 書 香	世 兄	世 外	世 外 桃 源	世 平 興 業	世 交	世 臣	
世 行	世 局	世 系	世 事	世 居	世 昕 企 業	世 俗	世 俗 化	
世 故	世 界	世 界 人 民	世 界 上	世 界 大 國	世 界 大 戰	世 界 大 賽	世 界 之 最	
世 界 文 化	世 界 文 明	世 界 水 平	世 界 市 場	世 界 先 進	世 界 先 進 水 平	世 界 各 地	世 界 各 國	
世 界 地 理	世 界 形 勢	世 界 和 平	世 界 性	世 界 知 識	世 界 冠 軍	世 界 政 治	世 界 盃	
世 界 盃 賽	世 界 紀 錄	世 界 軍 事	世 界 展 望 會	世 界 級	世 界 第 一	世 界 博 覽	世 界 貿 易 組 織	
世 界 經 濟	世 界 語	世 界 銀 行	世 界 潮 流	世 界 範 圍	世 界 衛 生 組 織	世 界 歷 史	世 界 錦 標 賽	
世 界 觀	世 界 觀 光 組 織	世 紀	世 紀 末	世 紀 帝 國	世 面	世 風	世 風 日 下	
世 家	世 峰	世 情	世 族	世 華 銀 行	世 貿	世 貿 入 會 談 判	世 貿 組 織	
世 間	世 傳	世 祿	世 道	世 道 人 情	世 態	世 態 人 情	世 態 炎 涼	
世 襲	且 不	且 末	且 有	且 知	且 看	且 經	且 話	
且 過	且 慢	且 說	且 還	且 聽	且 讓	丘 八	丘 北	
丘 吉 爾	丘 阜	丘 疹	丘 陵	丘 腦	丘 壑	主 人	主 人 公	
主 人 翁	主 人 翁 精 神	主 力	主 力 軍	主 力 部 隊	主 子	主 心 骨	主 犯	
主 伐	主 件	主 任	主 任 委 員	主 任 醫 生	主 兇	主 列	主 刑	
主 名	主 旨	主 次	主 考	主 考 人	主 考 者	主 攻	主 攻 手	
主 見	主 角	主 事	主 使	主 供	主 制	主 和	主 和 派	
主 委	主 枝	主 治	主 治 醫 生	主 治 醫 師	主 牧 師	主 表	主 客	
主 客 觀	主 帥	主 持	主 持 人	主 持 正 義	主 持 會 議	主 政	主 流	
主 流 產 品	主 要	主 要 人 員	主 要 矛 盾	主 要 原 因	主 計 員	主 計 處	主 音	
主 頁	主 食	主 修	主 哪	主 宰	主 峰	主 席	主 席 令	
主 席 台	主 席 團	主 根	主 格	主 航 道	主 辱 臣 死	主 送	主 動	
主 動 性	主 動 脈	主 動 軸	主 動 精 神	主 動 輪	主 動 權	主 啊	主 唱	
主 唱 者	主 婦	主 婦 似	主 婦 們	主 婚	主 將	主 張	主 從	
主 控	主 控 台	主 教	主 教 練	主 族 元 素	主 旋 律	主 理	主 祭	
主 組	主 場	主 發 條	主 筆	主 菜	主 街	主 視 圖	主 詞	
主 詞 表	主 訴	主 軸	主 軸 承	主 隊	主 幹	主 意	主 敬 存 誠	
主 業	主 義	主 群	主 群 組	主 腦	主 試	主 路	主 道	
主 僕	主 幣	主 演	主 管	主 管 人	主 管 部 門	主 語	主 賓	
主 審	主 廚	主 憂 臣 辱	主 播	主 樓	主 稿	主 編	主 線	
主 課	主 調	主 調 音	主 導	主 導 地 位	主 導 作 用	主 導 者	主 戰	
主 戰 派	主 戰 論	主 機	主 機 板	主 謀	主 謂	主 辦	主 辦 人	
主 辦 者	主 辦 單 位	主 嶺	主 講	主 糧	主 題	主 題 法	主 題 思 想	
主 題 詞	主 題 歌	主 題 標 引	主 顧	主 權	主 權 國	主 顯	主 體	
主 觀	主 觀 化	主 觀 主 義	主 觀 性	主 觀 原 因	主 觀 能 動 性	主 觀 唯 心 主 義	主 觀 論	
乍 一 看	乍 冷 乍 熱	乍 見	乍 到	乍 看	乍 得	乍 現	乍 寒	
乍 富	乍 晴	乍 然	乍 暖	乍 暖 還 寒	乍 熱	乍 離 破 碎	乏 力	
乏 味	乏 時	乎 乎	以 一 奉 百	以 一 知 萬	以 一 持 萬	以 一 馭 萬	以 一 當 十	
以 一 擊 十	以 一 警 百	以 人 廢 言	以 力 服 人	以 下	以 上	以 上 幾 個 方 面	以 大	
以 大 局 為 重	以 子 之 矛 攻 子 之 盾	以 小 見 大	以 工 代 賑	以 工 補 農	以 己 度 人	以 之	以 什 麼	
以 內	以 升 量 石	以 及	以 太	以 太 網	以 少 勝 多	以 巴 協 議	以 巴 衝 突	
以 手 加 額	以 文 害 辭	以 文 會 友	以 日 為 年	以 日 為 歲	以 日 繼 夜	以 比	以 水	
以 水 救 水	以 水 濟 水	以 火 救 火	以 牙 還 牙	以 他	以 功 補 過	以 功 覆 過	以 功 贖 罪	
以 北	以 古 方 今	以 古 非 今	以 外	以 失 敗 而 告 終	以 用	以 白 為 黑	以 石 投 水	
以 石 投 卵	以 示	以 冰 致 蠅	以 在	以 多	以 夷 伐 夷	以 夷 制 夷	以 夷 治 夷	
以 次 充 好	以 此	以 此 為 根 據	以 此 為 基 礎	以 此 為 準	以 此 為 榮	以 此 類 推	以 耳 代 目	
以 耳 為 目	以 自	以 至	以 至 於	以 色 列	以 色 列 人	以 色 列 亞	以 血 洗 血	
以 血 償 血	以 血 還 血	以 西	以 住	以 作	以 免	以 利	以 利 再 戰	
以 利 於	以 卵 投 石	以 卵 擊 石	以 攻 為 守	以 求	以 求 一 逞	以 見 一 斑	以 言 取 人	
以 身 作 則	以 身 殉 國	以 身 殉 職	以 身 許 國	以 身 報 國	以 身 試 法	以 車	以 防	
以 防 不 測	以 防 萬 一	以 事 實 為 根 據	以 使	以 供	以 例	以 來	以 其	
以 其 人 之 道	以 夜 繼 日	以 屈 求 申	以 往	以 往 鑒 來	以 於	以 東	以 法 律 為 準 繩	
以 盲 辨 色	以 直 報 怨	以 近	以 便	以 前	以 南	以 咽 廢 飧	以 待	
以 後	以 怨 報 德	以 指	以 指 撓 佛	以 柔 克 剛	以 柔 制 剛	以 毒 攻 毒	以 為	
以 看	以 致	以 苦 為 榮	以 苦 為 樂	以 赴	以 容 取 人	以 弱 制 強	以 弱 勝 強	
以 狸 致 鼠	以 狸 餌 鼠	以 珠 彈 雀	以 蚓 投 魚	以 退 為 進	以 假 亂 真	以 做	以 偏 概 全	
以 售 其 奸	以 帶	以 強 凌 弱	以 情	以 殺 止 殺	以 殺 去 殺	以 理 服 人	以 眼 還 眼	
以 眼 還 眼 以 牙 還 牙	以 訛 傳 訛	以 備	以 勞 養 武	以 勝 利 而 告 終	以 報	以 湯 止 沸	以 湯 沃 沸	
以 湯 沃 雪	以 然	以 逸 待 勞	以 郵 戳 日 期 為 準	以 勢 壓 人	以 微 知 著	以 意 逆 志	以 當	
以 解	以 該	以 誠 相 待	以 資	以 資 抵 債	以 資 鼓 勵	以 對	以 管 窺 天	
以 貌 取 人	以 遠	以 德 抱 怨	以 德 服 人	以 德 報 怨	以 德 報 德	以 暴 易 暴	以 鄰 為 壑	
以 戰 去 戰	以 點 帶 面	以 禮 相 待	以 職 謀 私	以 舊 換 新	以 贏 利 為 目 的	以 蠡 測 海	以 饗 讀 者	
以 權 謀 私	以 聾 辨 聲	以 觀 後 效	以 莛 叩 鐘	以 莛 撞 鐘	以 筌 為 魚	以 儆 傚 尤	付 了	
付 之 一 哂	付 之 一 炬	付 之 一 笑	付 之 一 歎	付 之 東 流	付 予	付 方	付 出	
付 本	付 印	付 托	付 迄	付 金	付 品	付 息	付 訖	
付 帳	付 得	付 排	付 清	付 清 了	付 現	付 貨	付 款	
付 款 人	付 款 者	付 款 額	付 稅	付 給	付 費	付 酬	付 與	
付 諸	付 諸 東 流	付 諸 洪 喬	付 諸 實 施	付 諸 實 現	付 賬	付 錢	付 還	
仔 牛	仔 仔 細 細	仔 服	仔 畜	仔 細	仕 女	仕 宦	仕 途	
他 人	他 山 之 石	他 山 之 攻	他 之	他 方	他 日	他 本 人	他 州	
他 自 己	他 事	他 所	他 物	他 的	他 卻	他 倆	他 們	
他 們 的	他 家	他 國	他 殺	他 處	他 殘 酷	他 鄉	他 鄉 遇 故 知	
他 媽	他 媽 的	他 親 自	仗 恃	仗 馬 寒 蟬	仗 莫 如 信	仗 勢	仗 勢 欺 人	
仗 義	仗 義 執 言	仗 義 疏 財	代 人	代 人 捉 刀	代 入	代 之	代 之 而 起	
代 支	代 付	代 代 相 傳	代 市 長	代 用	代 用 者	代 用 品	代 交	
代 名	代 名 詞	代 回	代 扣	代 收	代 行	代 序	代 我	
代 步	代 言	代 言 人	代 征	代 拆 代 行	代 表	代 表 人	代 表 大 會	
代 表 作	代 表 性	代 表 處	代 表 隊	代 表 會	代 表 會 議	代 表 團	代 客	
代 派	代 為	代 為 說 項	代 省 長	代 訂	代 書	代 書 人	代 耕	
代 記	代 問 好	代 售	代 培	代 培 生	代 接	代 理	代 理 人	
代 理 者	代 理 商	代 理 權	代 部 長	代 勞	代 換	代 替	代 替 者	
代 筆	代 筆 人	代 詞	代 訴	代 訴 人	代 買	代 溝	代 罪	
代 號	代 電	代 墊	代 幣	代 爾	代 稱	代 管	代 說	
代 領	代 價	代 寫	代 數	代 數 方 程	代 數 式	代 數 和	代 數 學	
代 碼	代 編	代 課	代 賣	代 銷	代 銷 店	代 謀	代 辦	
代 辦 所	代 辦 處	代 營	代 總 理	代 總 統	代 謝	代 謝 物	代 購	
代 轄	代 職	代 簽	代 議 制	代 辯	代 辯 者	代 攤	令 人	
令 人 不 安	令 人 生 畏	令 人 作 嘔	令 人 注 目	令 人 信 服	令 人 氣 結	令 人 神 往	令 人 捧 腹	
令 人 深 思	令 人 費 解	令 人 感 動	令 人 鼓 舞	令 人 滿 意	令 人 噴 飯	令 人 髮 指	令 人 齒 冷	
令 人 難 以 置 信	令 人 難 忘	令 兄	令 出	令 出 如 山	令 出 惟 行	令 她	令 行 禁 止	
令 你	令 弟	令 其	令 叔	令 妹	令 狀	令 科	令 郎	
令 堂	令 您	令 尊	令 愛	令 箭	仙 人	仙 人 掌	仙 女	
仙 女 似	仙 子	仙 山	仙 山 瓊 閣	仙 丹	仙 台	仙 似	仙 妮 亞 唐 恩	
仙 姑	仙 居	仙 果	仙 花	仙 姿 玉 色	仙 後 座	仙 界	仙 風 道 骨	
仙 宮	仙 桃	仙 翁	仙 草	仙 國	仙 術	仙 逝	仙 都	
仙 景	仙 游	仙 童	仙 境	仙 樂	仙 蹤	仙 藥	仙 鏡	
仙 露 明 珠	仙 鶴	充 大	充 公	充 分	充 分 發 揮	充 水	充 以	
充 斥	充 任	充 份	充 好	充 耳	充 耳 不 聞	充 血	充 血 性	
充 作	充 沛	充 足	充 其 量	充 抵	充 盈	充 要 條 件	充 軍	
充 氣	充 氣 設 備	充 氧	充 做	充 頂	充 棟 汗 牛	充 塞	充 填	
充 填 物	充 溢	充 當	充 當 先 鋒	充 裕	充 電	充 電 站	充 電 器	
充 實	充 暢	充 滿	充 滿 生 機	充 滿 希 望	充 滿 信 心	充 滿 活 力	充 滿 著	
充 滿 敵 意	充 數	充 類 至 盡	充 饑	充 饑 畫 餅	兄 友 弟 恭	兄 台	兄 死 弟 及	
兄 弟	兄 弟 民 族	兄 弟 姐 妹	兄 弟 般	兄 弟 象	兄 弟 會	兄 弟 黨	兄 弟 鬩 牆	
兄 妹	兄 肥 弟 瘦	兄 長	兄 終 弟 及	兄 嫂	冉 冉	冉 冉 升 起	冊 子	
冊 卷	冊 書	冊 簿	冬 小 麥	冬 山	冬 山 鄉	冬 天	冬 日	
冬 日 可 愛	冬 令	冬 令 營	冬 冬 響	冬 瓜	冬 汛	冬 至	冬 衣	
冬 防	冬 季	冬 季 奧 運 會	冬 季 運 動	冬 季 運 動 會	冬 泳	冬 青	冬 青 樹	
冬 夏	冬 扇 夏 爐	冬 眠	冬 耕	冬 訓	冬 麥	冬 筍	冬 菜	
冬 閒	冬 奧 會	冬 溫	冬 溫 夏 清	冬 裝	冬 運 會	冬 學	冬 蟲 夏 草	
冬 灌	冬 響	冬 菇	凹 了	凹 入	凹 下	凹 口	凹 凸	
凹 凸 不 平	凹 凸 印 刷	凹 凸 透 鏡	凹 曲	凹 曲 面	凹 形	凹 角	凹 底	
凹 版	凹 狀	凹 的	凹 度	凹 面	凹 面 鏡	凹 痕	凹 處	
凹 透	凹 透 鏡	凹 陷	凹 進	凹 窪	凹 槽	凹 線	凹 鏡	
出 了	出 人	出 人 意 外	出 人 意 表	出 人 意 料	出 人 頭 地	出 入	出 入 口	
出 入 將 相	出 入 境	出 入 頭 地	出 入 證	出 力	出 力 不 討 好	出 口	出 口 入 耳	
出 口 成 章	出 口 品	出 口 政 策	出 口 商	出 口 商 品	出 口 國	出 口 接 單	出 口 產 品	
出 口 處	出 口 創 匯	出 口 創 匯 率	出 口 貿 易	出 口 量	出 口 轉 內 銷	出 口 額	出 土	
出 土 文 物	出 土 文 書	出 山	出 工	出 手	出 手 得 盧	出 毛 病	出 水	
出 水 芙 蓉	出 片	出 牙 期	出 世	出 主 意	出 乎	出 乎 意 外	出 乎 意 料	
出 出	出 包	出 去	出 去 走 走	出 台	出 外	出 外 謀 生	出 生	
出 生 入 死	出 生 日 期	出 生 地	出 生 年 月	出 生 於	出 生 前	出 生 後	出 生 率	
出 生 證	出 示	出 任	出 列	出 名	出 地	出 在	出 汗	
出 自	出 自 內 心	出 自 於	出 色	出 色 完 成	出 血	出 血 病	出 行	
出 位	出 兵	出 局	出 岔	出 岔 子	出 沒	出 沒 無 常	出 言	
出 言 不 遜	出 言 成 章	出 言 無 狀	出 谷 遷 喬	出 走	出 身	出 身 名 門	出 身 好	
出 身 微 賤	出 車	出 巡	出 乖 弄 丑	出 乖 露 丑	出 事	出 事 地 點	出 使	
出 來	出 來 了	出 具	出 其 不 意	出 典	出 奇	出 奇 制 勝	出 奔	
出 征	出 招	出 於	出 於 公 心	出 於 好 意	出 於 我 的 意 料 之 外	出 於 意 料 之 外	出 法	
出 油	出 版	出 版 工 作	出 版 自 由	出 版 事 業	出 版 物	出 版 社	出 版 者	
出 版 品	出 版 界	出 版 商	出 版 單 位	出 版 發 行	出 版 業	出 版 說 明	出 版 學	
出 空	出 芽	出 迎	出 門	出 品	出 城	出 洋	出 洋 相	
出 洞	出 活	出 界	出 苗	出 軌	出 面	出 面 交 涉	出 風 頭	
出 借	出 家	出 家 人	出 島	出 差	出 席	出 席 人	出 席 會 議	
出 師	出 庫	出 庭	出 恭	出 息	出 料	出 書	出 格	
出 氣	出 氣 筒	出 海	出 疹	出 破	出 神	出 神 入 化	出 租	
出 租 人	出 租 汽 車	出 租 車	出 租 者	出 租 國 宅	出 租 給	出 站	出 納	
出 納 員	出 納 業 務	出 缺	出 航	出 逃	出 院	出 陣	出 馬	
出 高 價	出 動	出 問 題	出 售	出 圈	出 國	出 國 考 察	出 國 深 造	
出 國 訪 問	出 國 熱	出 將 入 相	出 清	出 現	出 產	出 眾	出 脫	
出 船 塢	出 處	出 訪	出 貨	出 喪	出 場	出 期	出 港	
出 牌	出 發	出 發 點	出 診	出 買	出 超	出 亂 子	出 勤	
出 勤 率	出 塞	出 嫁	出 溜	出 群 拔 萃	出 落	出 資	出 路	
出 遊	出 道	出 境	出 榜	出 爾 反 爾	出 獄	出 端	出 閣	
出 齊	出 價	出 價 人	出 廠	出 廠 價 格	出 窯	出 線	出 線 權	
出 賣	出 賣 靈 魂	出 戰	出 據	出 操	出 艙	出 謀 劃 策	出 謀 獻 策	
出 錯	出 錢	出 險	出 頭	出 頭 露 面	出 戲	出 擊	出 聲	
出 賽	出 醜	出 殯	出 獵	出 題	出 鏡	出 關	出 類 拔 萃	
出 類 拔 群	出 類 超 群	出 爐	出 籠	出 讓	凸 凹	凸 出	凸 出 部	
凸 用	凸 多 邊 形	凸 版	凸 花	凸 面	凸 紋	凸 胸	凸 起	
凸 透	凸 透 鏡	凸 嵌 線	凸 輪	凸 輪 軸	凸 雕	凸 邊	凸 邊 角	
凸 鏡	刊 入	刊 出	刊 布	刊 本	刊 正	刊 印	刊 在	
刊 行	刊 刻	刊 物	刊 後 語	刊 授	刊 登	刊 發	刊 詞	
刊 號	刊 載	刊 誤	刊 頭	加 了	加 人 一 等	加 入	加 入 者	
加 力	加 下	加 下 標	加 上	加 大	加 工	加 工 絲	加 工 業	
加 工 廠	加 之	加 引 號	加 水	加 水 站	加 以	加 以 分 析	加 以 改 進	
加 以 解 決	加 付	加 加	加 外 框	加 刑	加 印	加 在	加 在 一 起	
加 多	加 州	加 成	加 成 反 應	加 收	加 有	加 色	加 刪	
加 尾 詞	加 快	加 足	加 些	加 來	加 侖	加 侖 量	加 到	
加 固	加 官	加 官 進 位	加 官 進 祿	加 官 進 爵	加 征	加 拉 加 斯	加 拉 卡 斯	
加 於	加 枝 添 葉	加 注	加 法	加 法 器	加 油	加 油 站	加 油 添 醋	
加 油 器	加 物	加 長	加 長 型	加 亮	加 前 綴	加 厚	加 封	
加 急	加 急 電 報	加 括 號	加 星 號	加 查	加 洗	加 派	加 重	
加 倍	加 倍 大	加 值	加 套	加 害	加 害 於	加 座	加 息	
加 拿 大	加 拿 大 人	加 料	加 框	加 氣 站	加 班	加 班 加 點	加 班 費	
加 納	加 納 人	加 記	加 酒	加 高	加 冕	加 勒 比 人	加 勒 比 海	
加 國	加 密	加 密 軟 體	加 強	加 強 團 結	加 強 管 理	加 氫	加 添	
加 深	加 粗	加 速	加 速 者	加 速 度	加 速 儀	加 速 劑	加 速 器	
加 速 檔	加 減	加 減 法	加 稅	加 答 兒	加 給	加 菜	加 進	
加 塞	加 意	加 溫	加 煤	加 盟	加 盟 共 和 國	加 盟 店	加 盟 者	
加 罪	加 號	加 號 碼	加 裝	加 裡 曼 丹	加 載	加 載 項	加 農 炮	
加 演	加 滿	加 緊	加 罰	加 聚 反 應	加 蓋	加 蓋 於	加 價	
加 劇	加 增	加 寬	加 數	加 標 記	加 標 籤	加 潤	加 熱	
加 熱 器	加 熱 爐	加 碼	加 練	加 膝 墜 淵	加 蓬	加 蓬 人	加 課	
加 醋	加 糖	加 餐	加 壓	加 總	加 薪	加 點	加 鎖	
加 鎖 鍊	加 鞭	加 藥 物	加 護	加 權	加 權 期 指	加 襯 墊	加 鹽	
功 力	功 力 深 湛	功 大 於 過	功 夫	功 用	功 同 賞 異	功 名	功 名 利 祿	
功 成 不 居	功 成 名 立	功 成 名 就	功 成 名 遂	功 成 行 滿	功 成 身 退	功 臣	功 利	
功 利 主 義	功 均 天 地	功 到 自 然 成	功 底	功 放	功 於	功 狗 功 人	功 效	
功 耗	功 能	功 能 上	功 能 鍵	功 高 不 賞	功 高 望 重	功 高 績 著	功 敗 垂 成	
功 率	功 率 因 數	功 勞	功 就 名 成	功 業	功 罪	功 遂 身 退	功 過	
功 墮 垂 成	功 德	功 德 無 量	功 德 圓 滿	功 德 會	功 課	功 勳	功 績	
功 虧 一 簣	功 虧 一 蕢	包 人	包 上	包 子	包 工	包 工 包 料	包 工 隊	
包 工 頭	包 干	包 干 到 戶	包 干 制	包 內	包 公	包 心 菜	包 片	
包 牙	包 以	包 包	包 布	包 皮	包 伙	包 件	包 在	
包 成	包 收	包 死	包 住	包 含	包 含 在 內	包 庇	包 抄	
包 谷	包 身	包 車	包 店	包 底	包 房	包 法 利	包 治 百 病	
包 金	包 括	包 括 了	包 修	包 容	包 疹	包 租	包 紙	
包 草	包 起	包 起 來	包 退	包 教	包 涵	包 產	包 產 到 戶	
包 票	包 紮	包 羞 忍 恥	包 羞 忍 辱	包 船	包 圍	包 圍 圈	包 圍 著	
包 場	包 廂	包 換	包 稅	包 給	包 著	包 袱	包 進	
包 飯	包 裝	包 裝 工 人	包 裝 材 料	包 裝 物	包 裝 紙	包 裝 費	包 裝 箱	
包 裡	包 管	包 緊	包 裹	包 銀	包 箱	包 賠	包 銷	
包 機	包 辦	包 辦 代 替	包 辦 婚 姻	包 鋼	包 頭	包 藏	包 藏 禍 心	
包 蟲	包 醫	包 羅	包 羅 萬 象	包 羅 廣 泛	包 纏	包 攬	包 攬 詞 訟	
匆 匆	匆 匆 一 看	匆 匆 忙 忙	匆 忙	匆 忙 而 行	匆 促	匆 穿	匆 猝	
北 上	北 大	北 大 西 洋	北 大 西 洋 公 約 組 織	北 大 荒	北 山	北 川	北 工 大	
北 斗	北 斗 星	北 方	北 方 人	北 方 工 業 公 司	北 方 地 區	北 方 話	北 方 領 土	
北 冬	北 半 球	北 市	北 平	北 瓜	北 伐	北 冰 洋	北 行	
北 宋	北 投 區	北 角	北 亞	北 京	北 京 人	北 京 工 業 大 學	北 京 日 報	
北 京 市	北 京 地 區	北 京 軍 區	北 京 時 間	北 京 站	北 京 晚 報	北 京 電 視 台	北 京 圖 書 館	
北 岸	北 往	北 房	北 的	北 門	北 門 鎖 鑰	北 非	北 非 洲	
北 段	北 洋	北 流	北 約	北 約 組 織	北 美	北 美 洲	北 美 產	
北 郊	北 面	北 面 稱 臣	北 風	北 叟 失 馬	北 埔 鄉	北 展	北 海	
北 海 道	北 航	北 迴 歸 線	北 側	北 區	北 國	北 國 風 光	北 票	
北 部	北 港	北 港 鎮	北 街	北 越	北 進	北 愛 爾 蘭	北 極	
北 極 光	北 極 星	北 極 圈	北 溫 帶	北 煤 南 運	北 路	北 道 主 人	北 端	
北 樓	北 歐	北 歐 人	北 緯	北 頭	北 戴 河	北 轅 適 楚	北 韓	
北 轍 南 轅	北 鎮	北 魏	北 瀕	北 疆	北 邊	北 關	北 麓	
北 體	匝 道 管 制	匝 數	半 大	半 子	半 小 時	半 山	半 山 坡	
半 山 腰	半 工 半 讀	半 干	半 分	半 天	半 文 盲	半 斤	半 斤 八 兩	
半 方	半 日	半 日 制	半 月	半 月 刊	半 月 形	半 世	半 句	
半 打	半 生	半 生 不 熟	半 份	半 吊 子	半 年	半 成 品	半 死	
半 死 不 活	半 死 半 活	半 百	半 老	半 老 徐 娘	半 自 動	半 自 動 化	半 吞 半 吐	
半 步	半 決 賽	半 決 賽 權	半 角	半 身	半 身 不 遂	半 身 像	半 車	
半 刻	半 夜	半 夜 三 更	半 夜 敲 門 不 吃 驚	半 夜 敲 門 心 不 驚	半 官 方	半 底	半 拉	
半 拍	半 明 半 暗	半 治 天 下	半 盲	半 空	半 空 中	半 青 半 黃	半 信 半 疑	
半 封 建	半 封 建 半 殖 民 地	半 苦 半 甜	半 英 寸	半 面	半 面 之 交	半 音	半 個	
半 個 月	半 個 世 紀	半 個 多 世 紀	半 島	半 徑	半 時	半 晌	半 神 半 人	
半 衰 期	半 高	半 推 半 就	半 球	半 瓶	半 票	半 脫 產	半 規 管	
半 透	半 透 明	半 透 膜	半 途	半 途 而 廢	半 部	半 部 論 語	半 勞 動 力	
半 場	半 場 球 賽	半 期	半 殖 民 地	半 發 達	半 開	半 間 不 界	半 圓	
半 圓 形	半 塗 而 廢	半 塗 而 罷	半 新	半 新 不 舊	半 新 半 舊	半 暗	半 路	
半 路 出 家	半 路 修 行	半 路 埋 伏	半 載	半 道	半 道 打 字	半 飽	半 截	
半 截 入 土	半 旗	半 裸	半 製 品	半 價	半 數	半 數 以 上	半 熟	
半 瞎	半 輩	半 輩 子	半 噸	半 壁	半 壁 江 山	半 學 年	半 導 體	
半 機 械 化	半 融	半 薪	半 點	半 職 業 性	半 邊	半 邊 天	半 籌 不 納	
半 籌 莫 展	卡 人	卡 上	卡 子	卡 介 苗	卡 尺	卡 巴	卡 片	
卡 片 盒	卡 加 利	卡 白	卡 在	卡 式	卡 西 歐	卡 位	卡 住	
卡 匣	卡 車	卡 具	卡 其	卡 其 布	卡 其 色	卡 拉	卡 拉 奇	
卡 油	卡 門	卡 特	卡 特 爾	卡 索	卡 紙	卡 圈	卡 帶	
卡 脖 子	卡 通	卡 斯 楚	卡 殼	卡 菲 尼 可 夫	卡 塞 爾	卡 塔 爾	卡 塔 爾 人	
卡 瑞 拉 斯	卡 路 裡	卡 達	卡 鉗	卡 緊	卡 賓 槍	卡 盤	卡 擦	
卡 嗒 聲	卡 嚓	占 卜	占 卜 者	占 公 家 便 宜	占 主 導 地 位	占 兆	占 卦	
占 板	占 星	占 星 家	占 星 術	占 星 學	占 為 己 有	占 著	占 夢	
占 線	占 壓	卯 時	去 了	去 上 學	去 天 尺 五	去 毛	去 火	
去 世	去 去	去 末 歸 本	去 皮	去 划 船	去 劣	去 危 就 安	去 向	
去 向 不 明	去 年	去 死	去 污	去 污 粉	去 污 劑	去 作	去 吧	
去 找	去 抓	去 角	去 邪	去 邪 歸 正	去 使	去 來	去 函	
去 取	去 官	去 法	去 的	去 垢	去 垢 劑	去 甚 去 泰	去 看	
去 看 戲	去 赴	去 拿	去 拿 來	去 核	去 氧	去 泰 去 甚	去 留	
去 病	去 能	去 除	去 偽 存 真	去 做	去 接	去 掉	去 殺 勝 殘	
去 硫	去 粗 取 精	去 處	去 野 餐	去 就	去 就 之 分	去 惡	去 暑	
去 殼	去 鄉 村	去 勢	去 歲	去 路	去 過	去 磁	去 磁 場	
去 請	去 調 節	去 縐	去 蕪 存 菁	去 辦	去 頭	去 濕	去 聲	
去 職	去 舊	去 鱗	可 人	可 上 演	可 口	可 口 可 樂	可 大	
可 子	可 不	可 不 可 以	可 不 可 能	可 不 是	可 予	可 互 換	可 分	
可 分 子	可 分 別	可 分 析	可 分 配	可 分 割	可 分 開	可 分 解	可 分 離	
可 分 類	可 切 除	可 升 級	可 及	可 反 對	可 反 轉	可 引	可 引 出	
可 引 用	可 引 渡	可 引 導	可 心	可 心 如 意	可 支 持	可 支 配	可 比	
可 比 較	可 比 價 格	可 主 張	可 以	可 以 分	可 以 休 矣	可 以 吃	可 以 忽 視	
可 以 喝	可 以 買	可 以 解	可 以 說	可 以 請	可 以 避 免	可 以 騎	可 付	
可 付 還	可 代 替	可 出 租	可 加	可 加 工	可 卡 因	可 占	可 可	
可 可 豆	可 召 喚	可 召 集	可 巧	可 汀	可 犯	可 生	可 生 產	
可 用	可 由	可 交 換	可 交 談	可 共 存	可 再	可 再 制	可 列 舉	
可 印 刷	可 同	可 同 化	可 向	可 合 併	可 吃	可 回	可 回 收	
可 回 復	可 回 憶	可 在	可 好	可 存 取	可 成 形	可 收	可 收 回	
可 收 到	可 收 買	可 收 集	可 有 可 無	可 汗	可 自	可 自 乘	可 行	
可 行 性	可 行 性 研 究	可 住	可 估 計	可 估 價	可 伸 出	可 伸 長	可 伸 縮	
可 作	可 兌 換	可 別	可 利 用	可 否	可 否 認	可 吸 收	可 吟 誦	
可 完	可 忍 受	可 忍 耐	可 把	可 折 式 衣 架	可 折 疊	可 抑 制	可 抑 壓	
可 改	可 改 正	可 改 良	可 改 革	可 改 善	可 改 編	可 改 變	可 攻 克	
可 更 改	可 更 新	可 求	可 決 定	可 沐 浴	可 沒	可 沒 收	可 汽 化	
可 見	可 見 一 斑	可 見 光	可 見 度	可 言	可 走	可 走 動	可 防	
可 防 止	可 防 守	可 防 衛	可 防 禦	可 享	可 享 樂	可 依	可 使	
可 使 用	可 供	可 佩	可 到	可 到 達	可 卑	可 取	可 取 代	
可 取 回	可 取 性	可 取 消	可 取 得	可 受	可 和	可 和 解	可 定 名	
可 定 址	可 定 義	可 居	可 居 住	可 延	可 延 長	可 延 期	可 延 續 性	
可 征 服	可 忽 略	可 怖	可 怕	可 承 認	可 拉 長	可 抹 掉	可 拒 絕	
可 抽 出	可 抽 吸	可 抽 稅	可 抵 抗	可 拆 卸	可 放	可 於	可 治	
可 治 療	可 治 癒	可 爭	可 爭 論	可 爭 議	可 爭 辯	可 直 接	可 知	
可 知 性	可 知 覺	可 糾 正	可 者	可 表 示	可 表 明	可 表 現	可 采	
可 非 難	可 信	可 信 用	可 信 任	可 信 性	可 信 賴	可 保 存	可 保 險	
可 保 證	可 保 釋	可 哀	可 品 嚐	可 待	可 恨	可 恢 復	可 挖 苦	
可 按	可 指	可 指 明	可 是	可 查	可 流 通	可 洞 察	可 洗	
可 洗 滌	可 為	可 畏	可 畏 懼	可 省 略	可 看 破	可 研	可 穿	
可 穿 透	可 穿 著	可 要	可 要 求	可 計 算	可 計 數	可 述 說	可 重 寫	
可 重 獲	可 限 制	可 降	可 降 低	可 食	可 食 用	可 乘	可 乘 之 隙	
可 乘 之 機	可 借	可 倒	可 修 正	可 修 好	可 修 訂	可 修 理	可 修 復	
可 修 繕	可 兼 容	可 凌 駕	可 剝 奪	可 原 諒	可 容	可 容 忍	可 容 納	
可 容 許	可 展 性	可 展 開	可 恥	可 恥 下 場	可 恕	可 振 動	可 捉 捕	
可 挽 回	可 核 准	可 根 除	可 氣	可 氣 化	可 氧 化	可 消 化	可 消 耗	
可 消 除	可 消 費	可 浸 透	可 破 壞	可 秤	可 笑	可 耕	可 耕 地	
可 能	可 能 有	可 能 性	可 能 發 生	可 航 行	可 記 述	可 記 得	可 起 訴	
可 逆	可 逆 性	可 退 回	可 追 求	可 追 蹤	可 除 盡	可 假 定	可 做	
可 動	可 動 性	可 動 搖	可 區 分	可 執 行	可 專 用	可 將	可 崇 敬	
可 帶 走	可 強 迫	可 得	可 得 到	可 從	可 惜	可 控	可 控 告	
可 控 硅	可 接	可 接 受	可 接 受 性	可 接 近	可 推 知	可 推 測	可 推 廣	
可 推 論	可 推 斷	可 推 薦	可 採 用	可 採 納	可 排	可 排 除	可 救	
可 救 出	可 救 助	可 教	可 教 化	可 教 育	可 教 性	可 望	可 望 而 不 可 及	
可 望 而 不 可 即	可 液 化	可 混	可 理 解	可 移	可 移 動	可 移 植 性	可 移 轉	
可 統 一	可 統 治	可 組 合	可 組 織	可 處 理	可 被	可 設	可 責	
可 責 備	可 責 難	可 這	可 通	可 通 行	可 通 航	可 通 過	可 通 融	
可 連 接	可 透 入	可 透 性	可 喜	可 圍 繞	可 報 導	可 尊 重	可 尊 敬	
可 就	可 復 甦	可 惡	可 悲	可 惱	可 提 議	可 揮 發	可 援 用	
可 替 換	可 欺	可 欽 佩	可 減 少	可 減 去	可 減 輕	可 測	可 測 性	
可 測 量	可 無	可 甦 醒	可 登 記	可 發	可 發 行	可 發 明	可 發 表	
可 發 音	可 發 覺	可 答 覆	可 答 辯	可 善	可 裁 決	可 視 性	可 視 電 話	
可 評 價	可 訴 訟	可 貼 現	可 賀	可 貴	可 買	可 買 賣	可 超 越	
可 進 入	可 進 口	可 郵 寄	可 量	可 開 動	可 飲 用	可 傳 性	可 傳 染	
可 傳 達	可 傳 遞	可 傳 播	可 傳 導	可 塑	可 塑 性	可 塑 造	可 塑 劑	
可 意	可 感 知	可 感 覺	可 想	可 想 而 知	可 想 到	可 想 像	可 愛	
可 搬 運	可 搶 救	可 敬	可 敬 畏	可 會 見	可 溶	可 溶 性	可 溶 解	
可 當	可 羨 慕	可 補 救	可 解	可 解 決	可 解 雇	可 解 說	可 解 釋	
可 解 讀	可 試 驗	可 資	可 達	可 達 到	可 過	可 預 付	可 預 言	
可 預 知	可 預 期	可 飽 和	可 馴 服	可 馴 養	可 像	可 僱 用	可 嘗	
可 嘉	可 實 行	可 實 施	可 實 現	可 察 覺	可 撤 回	可 撤 銷	可 歌 可 泣	
可 漂 浮	可 滿	可 滿 足	可 滲 入	可 滲 透	可 熔	可 熄 滅	可 疑	
可 疑 性	可 種 植	可 稱	可 算	可 維 持	可 維 護 性	可 聞	可 與	
可 認 識	可 說	可 說 明	可 說 服	可 誘 惑	可 輕 視	可 鄙	可 駁 斥	
可 駁 倒	可 增 加	可 寬 恕	可 廢 止	可 廢 除	可 徵 收	可 徵 稅	可 憐	
可 憐 人	可 憐 蟲	可 憎	可 撫 慰	可 數	可 模 仿	可 樂	可 歎	
可 磋 商	可 確 定	可 編	可 編 程	可 緩 和	可 課 稅	可 調	可 調 和	
可 調 停	可 調 整	可 論 證	可 賣	可 適 用	可 銷	可 銷 售	可 靠	
可 靠 人 士	可 靠 性	可 靠 性 理 論	可 靠 保 證	可 駕 駛	可 導	可 憑	可 戰 勝	
可 操 左 券	可 操 作	可 操 作 性	可 操 縱	可 樹	可 燃	可 燃 性	可 膨 脹	
可 親	可 親 可 敬	可 謂	可 輸 入	可 輸 出	可 辨 別	可 辨 認	可 遵 守	
可 選	可 選 項	可 選 擇	可 遺 傳	可 錄 音	可 償	可 償 還	可 儲 存	
可 壓	可 壓 搾	可 壓 縮	可 應 用	可 擊	可 擦 掉	可 濕 性	可 獲	
可 獲 利	可 獲 得	可 瞭 解	可 縮	可 聯	可 聯 想	可 講	可 避 免	
可 擴 展	可 擴 張	可 斷	可 斷 言	可 斷 定	可 歸	可 歸 因	可 歸 於	
可 歸 罪	可 歸 還	可 歸 屬	可 濾	可 簡 化	可 翻 譯	可 轉	可 轉 移	
可 轉 讓	可 醫	可 醫 好	可 醫 治	可 攀 登	可 證	可 證 明	可 證 實	
可 類 比	可 騙	可 勸	可 勸 告	可 懸 吊	可 懸 掛	可 繼 承	可 覺 察	
可 觸	可 觸 知	可 議 論	可 攜	可 攜 帶	可 灌 溉	可 犧 牲	可 蘭 經	
可 護	可 辯	可 辯 別	可 辯 解	可 辯 論	可 辯 護	可 聽	可 聽 見	
可 聽 度	可 讀	可 讀 性	可 贖	可 贖 回	可 變	可 變 化	可 變 形	
可 變 性	可 變 硬	可 變 資 本	可 變 電 容 器	可 驚 異	可 驗	可 驗 證	可 體	
可 讓	可 讓 與	可 觀	可 讚 歎	可 讚 賞	古 人	古 丈	古 已 有 之	
古 井 無 波	古 今	古 今 中 外	古 今 字	古 今 有 之	古 巴	古 巴 人	古 文	
古 文 化	古 文 字	古 文 明	古 文 書	古 文 體	古 文 觀 止	古 代	古 代 船	
古 代 辯 證 法	古 北 口	古 巨 基	古 生 代	古 生 物	古 用 法	古 田	古 交	
古 印	古 名	古 式	古 曲	古 老	古 色	古 色 古 香	古 坑	
古 妝	古 事	古 來	古 來 有 之	古 典	古 典 之 作	古 典 文 學	古 典 主 義	
古 典 交 響 曲	古 典 作 品	古 典 派	古 典 樂	古 往 今 來	古 怪	古 怪 人	古 拙	
古 板	古 版 書	古 物	古 玩	古 城	古 城 堡	古 建	古 為 今 用	
古 紀	古 風	古 哩 古 怪	古 時	古 時 人	古 時 候	古 晉	古 書	
古 浪	古 神	古 訓	古 國	古 都	古 堡	古 琴	古 稀	
古 稀 之 年	古 詞	古 雅	古 塔	古 奧	古 猿	古 經	古 腦	
古 董	古 裝	古 詩	古 話	古 跡	古 道	古 道 熱 腸	古 墓	
古 墓 奇 兵	古 幣	古 漢 語	古 語	古 貌 古 心	古 銅	古 銅 色	古 調 不 彈	
古 調 獨 彈	古 論	古 戰 場	古 樸	古 樹 名 木	古 諺	古 錢	古 龍 水	
古 舊	古 蹟	古 譜	古 籍	古 蘭 經	古 體	古 觀	右 下	
右 下 方	右 上	右 上 方	右 手	右 手 定 則	右 方	右 列	右 耳	
右 行	右 角	右 房	右 抱	右 派	右 派 分 子	右 面	右 頁	
右 側	右 旋	右 旋 性	右 眼	右 移	右 舷	右 傾	右 腳	
右 端	右 腿	右 翼	右 臂	右 鍵	右 邊	右 顧	右 彎	
召 之 即 來	召 父 杜 母	召 回	召 見	召 來	召 者	召 喚	召 喚 者	
召 開	召 集	召 集 人	召 集 者	召 募	召 請	叮 叮	叮 叮 噹 噹	
叮 咚	叮 玲	叮 玲 響	叮 傷	叮 鈴	叮 噹	叮 噹 聲	叮 噹 響	
叮 嚀	叮 響	叮 囑	叮 呤	叩 出	叩 打	叩 門	叩 拜	
叩 首	叩 問	叩 診	叩 頭	叩 擊 者	叩 謝	叨 叨	叨 念	
叨 嘮	叼 了	司 令	司 令 杖	司 令 官	司 令 員	司 令 部	司 局	
司 局 級	司 事	司 法	司 法 上	司 法 制 度	司 法 官	司 法 院	司 法 部	
司 法 部 門	司 法 機 關	司 法 權	司 空 見 慣	司 空 眼 慣	司 長	司 庫	司 徒	
司 書	司 馬	司 馬 青 衫	司 馬 昭 之 心	司 馬 遷	司 務	司 務 長	司 售	
司 售 人 員	司 晨	司 祭	司 儀	司 廚	司 線 員	司 機	司 職	
司 爐	叵 測	叫 人	叫 化	叫 出	叫 名	叫 吃	叫 好	
叫 住	叫 作	叫 我	叫 走	叫 來	叫 到	叫 屈	叫 板	
叫 花	叫 花 子	叫 門	叫 客	叫 春	叫 苦	叫 苦 不 迭	叫 苦 連 天	
叫 個	叫 座	叫 起	叫 陣	叫 做	叫 得	叫 喊	叫 喊 者	
叫 喊 聲	叫 喚	叫 牌	叫 絕	叫 著	叫 開	叫 號	叫 過	
叫 價	叫 罵	叫 賣	叫 賣 販	叫 賣 聲	叫 醒	叫 錯	叫 聲	
叫 嚷	叫 囂	叫 啥	另 一	另 一 方	另 一 方 面	另 一 面	另 一 個	
另 一 番	另 一 種	另 日	另 付	另 加	另 外	另 用	另 立	
另 件	另 存	另 收	另 有	另 行	另 行 安 排	另 行 規 定	另 行 通 知	
另 作	另 告	另 見	另 事	另 定	另 屈	另 征	另 版	
另 附	另 建	另 按	另 納	另 起	另 起 爐 灶	另 配	另 娶	
另 將	另 眼	另 眼 相 待	另 眼 相 看	另 眼 看 待	另 設	另 報	另 換	
另 給	另 開	另 開 生 面	另 當	另 置	另 辟 蹊 徑	另 請	另 請 高 明	
另 據	另 據 報 道	另 謀	另 謀 高 就	另 選	另 簽	另 繳	另 議	
只 一 次	只 不 過	只 不 過 是	只 手	只 手 空 拳	只 手 單 拳	只 手 擎 天	只 可	
只 可 意 會 不 可 言 傳	只 只	只 用	只 用 於	只 因	只 在	只 好	只 有	
只 此	只 此 一 家 別 無 分 店	只 佔	只 作	只 把	只 投	只 求	只 見	
只 見 樹 木 不 見 森 林	只 言	只 言 片 語	只 征	只 怕	只 於	只 爭	只 爭 旦 夕	
只 爭 朝 夕	只 玩	只 知 其 一 不 知 其 二	只 知 其 一 未 知 其 二	只 按	只 是	只 為	只 看	
只 要	只 要 功 夫 深	只 重 衣 衫 不 重 人	只 限	只 限 於	只 准	只 差	只 消	
只 留	只 缺	只 能	只 做	只 得	只 從	只 產	只 許	
只 許 州 官 放 火	只 剩	只 就	只 須	只 想	只 會	只 當	只 對	
只 管	只 說	只 需	只 影 孤 形	只 影 單 形	只 熱	只 輪 不 返	只 憑	
只 顧	只 讀	史 上	史 不 絕 書	史 丹 福	史 冊	史 瓦 濟 蘭	史 志	
史 官	史 前	史 前 史	史 家	史 料	史 料 選 編	史 書	史 記	
史 崔 克	史 略	史 無 前 例	史 評	史 傳 小 說	史 詩	史 話	史 跡	
史 載	史 實	史 實 性	史 稱	史 綱	史 語	史 劇	史 稿	
史 論	史 學	史 學 方 法	史 館	史 籍	叱 吒	叱 吒 風 雲	叱 責	
叱 喝	叱 嗟 風 雲	叱 罵	台 一 國 際	台 下	台 上	台 上 台 下	台 大	
台 山	台 中	台 中 商 銀	台 中 港	台 中 精 機	台 中 銀	台 北	台 北 市	
台 北 看 守 所	台 北 海 洋 館	台 北 商 港	台 北 商 銀	台 北 國 際 書 展	台 北 捷 運 公 司	台 北 港	台 北 銀 行	
台 北 縣	台 北 醫 學 院	台 布	台 企 銀	台 光	台 光 電	台 光 電 子	台 地	
台 安 電 機	台 式	台 西	台 位	台 步	台 汽	台 育 證 券	台 車	
台 東	台 東 企 銀	台 林 通 信	台 板	台 芳 開 發	台 金	台 前	台 南	
台 南 企 業	台 南 企 銀	台 南 科 學 園 區	台 南 紡 織	台 柱	台 柱 子	台 架	台 胞	
台 苯	台 面	台 哥 大	台 員	台 座	台 海	台 秤	台 商	
台 基	台 帳	台 啟	台 球	台 球 場	台 揚 科 技	台 港	台 港 澳	
台 硝	台 硝 公 司	台 視	台 詞	台 証 證 券	台 開 信 託	台 塑	台 塑 企 業	
台 新 銀 行	台 盟	台 經 院	台 資	台 達 化	台 達 化 工	台 達 電 子	台 電	
台 壽 保	台 幣	台 榮 產 業	台 稱	台 綜 院	台 維 斯 盃	台 銀	台 閣 生 風	
台 鳳	台 鳳 集 團	台 數	台 歷	台 燈	台 獨	台 積 電	台 糖	
台 聯	台 聯 貨 櫃	台 鏡	台 鐘	台 屬	台 鐵	台 鑒	台 鹽	
台 灣	台 灣 人	台 灣 人 壽	台 灣 大	台 灣 大 聯 盟	台 灣 工 業 銀 行	台 灣 工 銀	台 灣 工 礦	
台 灣 化 纖	台 灣 水 泥	台 灣 火 柴	台 灣 半 導	台 灣 民 主 自 治 同 盟	台 灣 企 銀	台 灣 光 罩	台 灣 同 胞	
台 灣 汽 電	台 灣 肥 料	台 灣 金 融 研 訓 院	台 灣 玻 璃	台 灣 省	台 灣 茂 矽	台 灣 島	台 灣 海 峽	
台 灣 航 業	台 灣 產 物	台 灣 產 險 公 司	台 灣 博 物 館	台 灣 富 綢	台 灣 開 億	台 灣 塑 膠	台 灣 當 局	
台 灣 經 濟 研 究 院	台 灣 電 路	台 灣 福 興	台 灣 綜 合 研 究 院	台 灣 聚 合	台 灣 橡 膠	台 灣 機 械	台 灣 櫻 花	
台 鑽	句 子	句 字	句 式	句 法	句 型	句 柄	句 段	
句 容	句 號	句 話	句 點	叭 叭	叭 達	叭 聲	叭 嗒	
四 人	四 人 幫	四 十	四 十 一	四 十 七	四 十 九	四 十 二	四 十 人	
四 十 八	四 十 三	四 十 五	四 十 六	四 十 四	四 十 倍	四 十 個	四 十 歲	
四 十 萬	四 下	四 下 裡	四 千	四 千 萬	四 大	四 大 政 府 基 金	四 大 皆 空	
四 大 基 金	四 川	四 川 省	四 不 拗 六	四 不 像	四 中	四 中 全 會	四 五	
四 元 數	四 分	四 分 之 一	四 分 之 二	四 分 之 三	四 分 五 裂	四 分 法	四 分 音 符	
四 分 儀	四 化	四 化 大 業	四 化 建 設	四 天	四 孔	四 手 類	四 方	
四 方 八 面	四 方 臉	四 日	四 月	四 月 份	四 世	四 代	四 外	
四 平	四 平 八 穩	四 伏	四 件	四 仰 八 叉	四 份	四 名	四 回	
四 好 運 動	四 年	四 成	四 旬	四 有	四 次	四 次 冪	四 百	
四 百 公 尺 接 力	四 百 公 尺 跨 欄	四 百 年	四 百 萬	四 行	四 行 詩	四 位	四 角	
四 角 形	四 角 帽	四 足	四 周	四 季	四 季 度	四 屆	四 肢	
四 亭 八 當	四 則	四 則 運 算	四 星	四 段	四 郊	四 郊 多 壘	四 重 奏	
四 重 唱	四 面	四 面 八 方	四 面 楚 歌	四 面 體	四 音	四 音 節	四 頁	
四 倍	四 個	四 個 人	四 個 堅 持	四 個 現 代 化	四 套	四 害	四 家	
四 射	四 庫 全 書	四 旁	四 時	四 時 八 節	四 時 氣 備	四 氧	四 海	
四 海 之 內 皆 兄 弟	四 海 生 平	四 海 承 風	四 海 為 家	四 海 鼎 沸	四 海 幫	四 級	四 起	
四 馬 攢 蹄	四 國	四 國 島	四 捨 五 入	四 條	四 清	四 清 六 活	四 組	
四 處	四 處 奔 波	四 處 活 動	四 通	四 通 八 達	四 通 五 達	四 部	四 部 曲	
四 野	四 圍	四 散	四 氯 化 碳	四 湖	四 湖 鄉	四 週 年	四 鄉	
四 開	四 隊	四 項	四 項 基 本 原 則	四 塊	四 極 管	四 萬	四 腳	
四 腳 朝 天	四 腳 獸	四 號	四 路	四 幕	四 種	四 維	四 億	
四 價	四 層	四 德 三 從	四 樓	四 輪	四 鄰	四 壁	四 戰 之 地	
四 戰 之 國	四 頭	四 頭 肌	四 環	四 環 素	四 環 黴 素	四 聲	四 聯	
四 點	四 舊	四 邊	四 邊 形	四 類 分 子	四 顧	四 體	四 體 不 勤	
四 體 不 勤 無 谷 不 分	囚 人	囚 犯	囚 衣	囚 牢	囚 車	囚 居	囚 房	
囚 室	囚 首 垢 面	囚 徒	囚 禁	囚 籠	外 人	外 力	外 子	
外 丹 功	外 公	外 公 切 線	外 引 內 聯	外 心	外 手	外 文	外 文 版	
外 方	外 欠	外 比	外 水	外 出	外 出 用	外 加	外 功	
外 包 裝	外 卡 爭 奪 戰	外 巧 內 嫉	外 市	外 生	外 用	外 皮	外 交	
外 交 上	外 交 史	外 交 官	外 交 政 策	外 交 活 動	外 交 界	外 交 家	外 交 訪 問	
外 交 部	外 交 部 長	外 交 機 構	外 交 謀 略	外 交 關 係	外 企	外 向	外 向 型	
外 向 型 經 濟	外 合 裡 應	外 因	外 地	外 地 人	外 在	外 存	外 弛	
外 耳	外 行	外 行 人	外 衣	外 伸	外 形	外 形 上	外 快	
外 角	外 事	外 事 知 識	外 事 活 動	外 來	外 來 干 涉	外 來 物	外 來 者	
外 來 貨	外 來 詞	外 來 語	外 協	外 姓	外 岸	外 延	外 弦	
外 征	外 果 皮	外 沿	外 空	外 表	外 表 上	外 長	外 侮	
外 型	外 城	外 室	外 屋	外 星 人	外 柔 內 剛	外 查	外 洋	
外 流	外 活	外 界	外 界 人 士	外 省	外 相	外 看	外 科	
外 科 學	外 胚 葉	外 胚 層	外 胎	外 軍	外 面	外 面 性	外 借	
外 剛 內 柔	外 埔	外 套	外 孫	外 孫 女	外 展	外 島	外 差	
外 差 式	外 校	外 框	外 氣 層	外 海	外 祖	外 祖 父	外 祖 母	
外 財	外 逃	外 側	外 務	外 務 省	外 務 員	外 區	外 商	
外 商 投 資 企 業	外 商 獨 資 企 業	外 圈	外 國	外 國 人	外 國 化	外 國 血 統	外 國 投 資	
外 國 商 人	外 國 專 家	外 國 產	外 國 貨	外 國 評 論	外 國 語	外 域	外 埠	
外 婆	外 寇	外 宿	外 帶	外 強 中 乾	外 患	外 戚	外 接	
外 接 圓	外 推	外 族	外 痔	外 袍	外 設	外 貨	外 部	
外 部 設 備	外 部 環 境	外 野 手	外 陰	外 陰 部	外 勞	外 單 位	外 圍	
外 場	外 廁	外 插 法	外 援	外 揚	外 景	外 殼	外 港	
外 焰	外 甥	外 貿	外 貿 出 口	外 貿 協 會	外 貿 逆 差	外 貿 部	外 貿 順 差	
外 貿 體 制	外 鄉	外 開	外 間	外 項	外 債	外 傳	外 傾	
外 傷	外 傷 學	外 勤	外 匯	外 匯 市 場	外 匯 交 易	外 匯 存 底	外 匯 存 款	
外 匯 券	外 匯 準 備	外 匯 資 金	外 匯 儲 備	外 圓 內 方	外 愚 內 智	外 感	外 溢	
外 經	外 經 部	外 罩	外 號	外 資	外 資 企 業	外 路	外 運	
外 道	外 遇	外 電	外 電 路	外 僑	外 奪	外 幣	外 幣 流 通	
外 滲	外 蒙	外 蓋	外 語	外 貌	外 賓	外 寬 內 忌	外 寬 內 深	
外 層	外 層 空 間	外 廠	外 敵	外 敷	外 碼	外 線	外 調	
外 輪	外 遷	外 銷	外 銷 訂 單	外 銷 接 單	外 銷 量	外 壁	外 縣	
外 親 內 疏	外 頭	外 牆	外 牆 磚	外 購	外 翻	外 轉	外 邊	
外 籍	外 籍 華 人	外 露	外 顯	外 觀	外 觀 上	央 托	央 行	
央 告	央 求	失 口	失 土	失 之	失 之 交 臂	失 之 東 隅	失 之 東 隅 收 之 桑 榆	
失 之 毫 釐	失 手	失 水	失 火	失 主	失 去	失 失 慌 慌	失 光 澤	
失 地	失 守	失 而 復 得	失 色	失 血	失 利	失 步	失 言	
失 足	失 足 青 年	失 身	失 事	失 和	失 所	失 於	失 明	
失 果	失 物	失 物 招 領	失 迎	失 信	失 卻	失 度	失 查	
失 為	失 約	失 計	失 重	失 音	失 修	失 效	失 時	
失 真	失 眠	失 眠 症	失 神	失 神 落 魄	失 笑	失 配	失 閃	
失 馬 亡 羊	失 密	失 常	失 張 失 志	失 張 失 智	失 控	失 措	失 掉	
失 敗	失 敗 乃 成 功 之 母	失 敗 者	失 敗 是 成 功 之 母	失 敗 為 成 功 之 母	失 望	失 速	失 陪	
失 陷	失 散	失 款	失 盜	失 策	失 傳	失 勢	失 意	
失 慎	失 敬	失 業	失 業 人 數	失 業 者	失 業 率	失 當	失 禁	
失 節	失 落	失 落 感	失 道 寡 助	失 實	失 察	失 態	失 算	
失 語 症	失 認	失 誤	失 魂 喪 魄	失 魂 落 魄	失 諸 交 臂	失 調	失 學	
失 機	失 衡	失 檢	失 聲	失 聲 症	失 聲 痛 哭	失 聰	失 禮	
失 職	失 蹤	失 蹤 兒	失 蹤 者	失 寵	失 讀 症	失 戀	失 竊	
失 驚 打 怪	失 體 面	失 靈	奴 女	奴 工	奴 才	奴 化	奴 役	
奴 性	奴 婢	奴 僕	奴 態	奴 隸	奴 隸 主	奴 隸 制	奴 隸 制 度	
奴 隸 性	奴 隸 社 會	奴 顏	奴 顏 婢 色	奴 顏 婢 睞	奴 顏 婢 膝	奴 顏 媚 骨	奶 子	
奶 毛	奶 水	奶 牙	奶 牛	奶 奶	奶 皮	奶 名	奶 羊	
奶 豆	奶 刷	奶 咀	奶 房	奶 杯	奶 油	奶 品	奶 品 店	
奶 孩	奶 凍	奶 娘	奶 粉	奶 茶	奶 酒	奶 液	奶 瓶	
奶 場	奶 媽	奶 罩	奶 酪	奶 製 品	奶 嘴	奶 廠	奶 糕	
奶 糖	奶 頭	奶 鍋	奶 類	孕 育	孕 育 處	孕 前	孕 婦	
孕 期	孕 穗	它 山 之 石	它 本 身	它 自 己	它 的	它 們	尼 日	
尼 日 利 亞	尼 日 爾	尼 木	尼 加 拉 瓜	尼 可 拉 斯 凱 吉	尼 古 丁	尼 克	尼 姑	
尼 泊 爾	尼 泊 爾 人	尼 泊 爾 語	尼 采	尼 峰	尼 庵	尼 赫	尼 龍	
尼 龍 粒	尼 龍 絲	尼 羅	尼 羅 河	巨 人	巨 人 般	巨 人 隊	巨 大	
巨 大 症	巨 大 機 械	巨 石	巨 穴	巨 匠	巨 奸	巨 宅	巨 妖	
巨 物	巨 型	巨 型 機	巨 星	巨 流	巨 峰	巨 案	巨 浪	
巨 商	巨 蛋	巨 鳥	巨 鹿	巨 富	巨 幅	巨 款	巨 無 霸	
巨 筆	巨 著	巨 量	巨 集	巨 債	巨 滑	巨 照	巨 碑	
巨 萬	巨 資	巨 賈	巨 像	巨 禍	巨 輪	巨 樹	巨 頭	
巨 龍	巨 擘	巨 蟒	巨 額	巨 獸	巨 響	巨 變	巧 干	
巧 不	巧 不 可 階	巧 手	巧 用	巧 立	巧 立 名 目	巧 匠	巧 合	
巧 舌	巧 克	巧 克 力	巧 妙	巧 言	巧 言 令 色	巧 言 如 簧	巧 言 利 口	
巧 事	巧 取	巧 取 豪 奪	巧 於	巧 勁	巧 思	巧 計	巧 偽 不 如 拙 誠	
巧 做	巧 偷 豪 奪	巧 婦	巧 婦 難 為 無 米 之 炊	巧 捷	巧 發 奇 中	巧 詐 不 如 拙 誠	巧 遇	
巧 奪	巧 奪 天 工	巧 語	巧 語 花 言	巧 辭	巧 辯	巧 驗	左 下	
左 上	左 上 方	左 手	左 支 右 絀	左 方	左 右	左 右 手	左 右 兩 難	
左 右 為 難	左 右 逢 原	左 右 逢 源	左 右 開 弓	左 列	左 向	左 耳	左 行	
左 角	左 卷	左 宜 右 有	左 拉	左 近	左 思 右 想	左 派	左 盼	
左 面	左 頁	左 挈 右 提	左 側	左 旋	左 眼	左 移	左 舷	
左 掌	左 提 右 挈	左 傾	左 傾 者	左 傾 機 會 主 義	左 腳	左 躲	左 道	
左 道 旁 門	左 圖 右 史	左 撇	左 撇 子	左 端	左 膀 右 臂	左 腿	左 腿 瘸	
左 輔 右 弼	左 輪	左 輪 槍	左 遷	左 鄰	左 鄰 右 舍	左 擁	左 縈 右 拂	
左 翼	左 聯	左 臂	左 鍵	左 歸 右 歸	左 轉	左 鎮	左 邊	
左 顧	左 顧 右 盼	左 顧 右 眄	市 下	市 上	市 不 二 價	市 中 心	市 井	
市 井 小 人	市 井 之 臣	市 井 之 徒	市 內	市 內 電 話	市 公 所	市 升	市 尺	
市 斤	市 代 表	市 外	市 民	市 民 權	市 立	市 名	市 西	
市 局	市 兩	市 制	市 委	市 委 書 記	市 府	市 房	市 況	
市 直	市 直 機 關	市 長	市 政	市 政 工 程	市 政 府	市 政 建 設	市 政 員	
市 郊	市 面	市 風	市 容	市 畝	市 級	市 區	市 區 觀 光	
市 售	市 情	市 紳	市 頃	市 場	市 場 分 析	市 場 化	市 場 供 應	
市 場 信 息	市 場 研 究	市 場 疲 軟	市 場 動 態	市 場 推 廣	市 場 規 模	市 場 部	市 場 萎 縮	
市 場 經 濟	市 場 預 測	市 場 管 理	市 場 需 求	市 場 需 求 分 析	市 場 價 格	市 場 調 查	市 場 調 節	
市 場 學	市 場 環 境	市 場 繁 榮	市 場 趨 勢	市 場 體 系	市 無 二 價	市 間	市 集	
市 裡	市 電	市 稱	市 管 縣	市 際	市 價	市 儈	市 數	
市 擔	市 縣	市 轄 區	市 鎮	市 議 員	市 議 會	市 警 局	市 屬	
布 丁	布 什	布 匹	布 片	布 包	布 市	布 吉 納 法 索	布 帆 無 恙	
布 托	布 衣	布 衣 之 交	布 衣 韋 帶	布 衣 料	布 衣 蔬 食	布 衣 黔 首	布 衣 �B 食	
布 床	布 谷	布 谷 鳥	布 帛	布 帛 菽 粟	布 店	布 拉	布 拉 格	
布 拖	布 法 羅	布 哈 拉	布 衫	布 面	布 料	布 料 商	布 朗	
布 朗 運 動	布 紋	布 商	布 帶	布 條	布 票	布 袋	布 袋 寅 泰	
布 袋 港	布 袋 戲	布 袋 鎮	布 傘	布 隆 迪	布 裙	布 裙 荊 釵	布 裝	
布 道	布 達 佩 斯	布 達 拉 宮	布 鼓 雷 門	布 墊	布 幕	布 熊	布 爾	
布 爾 什 維 克	布 熱 津 斯 基	布 線	布 鞋	布 魯 塞 爾	布 頭	布 篷	布 點	
布 簾	布 類	布 蘭 妮	布 蘭 德	布 襪 青 鞋	平 凡	平 口 鉗	平 川	
平 仄	平 允	平 分	平 分 秋 色	平 分 面	平 分 線	平 分 點	平 反	
平 尺	平 心	平 心 而 論	平 心 靜 氣	平 手	平 方	平 方 公 里	平 方 米	
平 方 根	平 方 厘 米	平 日	平 月	平 加	平 台	平 台 式	平 台 型	
平 布	平 平	平 平 安 安	平 平 常 常	平 平 淡 淡	平 平 靜 靜	平 平 穩 穩	平 正	
平 民	平 民 百 姓	平 生	平 白	平 白 無 故	平 伏	平 仰	平 光	
平 地	平 地 青 雲	平 地 風 波	平 安	平 安 無 事	平 江	平 米	平 行	
平 行 四 邊 形	平 行 作 業	平 行 線	平 伸	平 作	平 刨	平 均	平 均 工 資	
平 均 日 產 量	平 均 水 平	平 均 主 義	平 均 年 齡	平 均 收 入	平 均 每 年 下 降	平 均 每 年 增 長	平 均 指 標	
平 均 為	平 均 值	平 均 氣 溫	平 均 速 度	平 均 發 展 水 平	平 均 達	平 均 壽 命	平 均 價 格	
平 均 增 長 速 度	平 均 數	平 坐	平 局	平 抑	平 步 青 雲	平 角	平 谷	
平 足	平 身	平 車	平 和	平 坦	平 定	平 底	平 底 船	
平 底 鍋	平 房	平 房 式	平 放	平 易	平 易 近 人	平 易 近 民	平 板	
平 板 車	平 板 狀	平 板 儀	平 版	平 直	平 空	平 肩	平 臥	
平 信	平 叛	平 型 關	平 屋 頂	平 巷	平 度	平 架	平 流 層	
平 流 緩 進	平 看	平 降	平 面	平 面 化	平 面 角	平 面 幾 何	平 面 圖	
平 面 鏡	平 音	平 倉	平 原	平 原 十 日 飲	平 原 戰 場	平 展	平 息	
平 時	平 紋	平 素	平 級	平 胸	平 起	平 起 平 坐	平 假 名	
平 動	平 常	平 庸	平 庸 無 奇	平 涼	平 淡	平 淡 無 奇	平 添	
平 淺	平 產	平 移	平 頂	平 頂 山	平 魚	平 復	平 湖	
平 等	平 等 互 利	平 等 互 惠	平 等 利	平 等 待 人	平 等 競 爭	平 等 權 利	平 絨	
平 視	平 視 顯 示 器	平 順	平 亂	平 塘	平 滑	平 滑 流 暢	平 溪 鄉	
平 裝	平 裝 本	平 裝 書	平 話	平 路	平 路 機	平 道	平 實	
平 價	平 劇	平 槽	平 盤	平 緩	平 調	平 躺	平 輩	
平 戰 結 合	平 整	平 整 土 地	平 衡	平 衡 力	平 衡 木	平 衡 物	平 衡 者	
平 衡 環	平 靜	平 頭	平 頭 正 臉	平 頭 釘	平 聲	平 鍋	平 鍋 柄	
平 鎮	平 鎮 市	平 曝 一 聲 雷	平 疇	平 穩	平 壤	平 爐	平 攤	
平 壩	平 舖	平 舖 直 敘	幼 女	幼 子	幼 小	幼 少	幼 年	
幼 年 期	幼 托	幼 有 所 托	幼 君	幼 弟	幼 兒	幼 兒 用	幼 兒 教 育	
幼 兒 教 育 券	幼 兒 園	幼 林	幼 者	幼 芽	幼 苗	幼 師	幼 時	
幼 畜	幼 教	幼 童	幼 禽	幼 稚	幼 稚 症	幼 稚 期	幼 稚 園	
幼 態	幼 學 壯 行	幼 樹	幼 蟲	幼 雛	幼 獸	幼 齡	幼 體	
弘 法	弘 揚	弘 裕 企 業	弘 道	弘 圖	弘 論	弘 願	弗 吉 尼 亞	
弗 如	必 也 正 名	必 不	必 不 可 少	必 不 可 免	必 不 得 已	必 失	必 由	
必 由 之 路	必 先 利 其 器	必 有	必 死	必 行	必 改	必 究	必 到	
必 定	必 爭	必 爭 之 地	必 保	必 是	必 要	必 要 性	必 要 措 施	
必 要 條 件	必 要 勞 動	必 修	必 修 課	必 恭 必 敬	必 能	必 衰	必 將	
必 得	必 敗	必 被	必 備	必 勝	必 然	必 然 之 事	必 然 王 國	
必 然 伴 有	必 然 性	必 然 規 律	必 然 結 果	必 然 會	必 然 趨 勢	必 須	必 須 的	
必 會	必 經	必 經 之 地	必 經 階 段	必 罰	必 需	必 需 品	必 學	
必 應	戊 午	戊 申	戊 戌	戊 戌 變 法	戊 辰	戊 級	戊 等	
戊 烷	打 了	打 人	打 人 罵 狗	打 入	打 入 冷 宮	打 下	打 上	
打 工	打 不	打 不 垮	打 不 起 精 神	打 不 動	打 不 著	打 中	打 井	
打 天 下	打 孔	打 孔 器	打 孔 機	打 手	打 手 勢	打 水	打 火	
打 火 石	打 火 機	打 牙 犯 嘴	打 牙 撂 嘴	打 主 意	打 以	打 仗	打 出	
打 出 吊 入	打 包	打 包 機	打 卡	打 去	打 平	打 交	打 交 道	
打 光	打 先 鋒	打 印	打 印 台	打 印 紙	打 印 機	打 在	打 好	
打 字	打 字 本	打 字 員	打 字 機	打 成	打 成 一 片	打 死	打 死 打 傷	
打 死 老 虎	打 灰	打 耳 光	打 住	打 作	打 冷 顫	打 劫	打 坐	
打 屁	打 屁 股	打 岔	打 我	打 抖	打 折	打 折 扣	打 扮	
打 更	打 車	打 來	打 兔 子	打 到	打 制	打 呵 欠	打 呼	
打 定	打 定 主 意	打 官 司	打 官 腔	打 底	打 招	打 招 呼	打 拍	
打 抱 不 平	打 昏	打 法	打 油	打 油 詩	打 狗	打 的	打 門	
打 信 號	打 前 站	打 哈	打 哈 欠	打 哈 哈	打 垮	打 拼	打 架	
打 架 鬥 毆	打 歪	打 洞	打 炮	打 盹	打 盹 兒	打 秋 風	打 胎	
打 食	打 倒	打 個	打 個 照 面	打 埋 伏	打 家 劫 舍	打 家 劫 盜	打 家 截 道	
打 扇	打 拳	打 晃	打 校 樣	打 柴	打 氣	打 氣 筒	打 消	
打 消 心 意	打 烊	打 砸 搶	打 破	打 破 沙 鍋 問 到 底	打 破 紀 錄	打 破 記 錄	打 破 常 規	
打 草	打 草 驚 蛇	打 起	打 起 精 神	打 躬	打 躬 作 揖	打 退	打 退 堂 鼓	
打 針	打 馬 虎 眼	打 高	打 鬥	打 鬼	打 動	打 基 礎	打 得	
打 得 火 熱	打 從	打 情 罵 俏	打 探	打 掩 護	打 掉	打 掃	打 掃 工	
打 掃 衛 生	打 掃 戰 場	打 敗	打 旋 磨 兒	打 球	打 理	打 眼	打 眼 放 炮	
打 票	打 蛇 打 七 寸	打 蛋	打 通	打 造	打 頂	打 魚	打 傘	
打 勝	打 勝 仗	打 圍	打 場	打 富 濟 貧	打 散	打 棍	打 棍 子	
打 棉 機	打 游 擊	打 渾	打 牌	打 痛	打 發	打 短 工	打 結	
打 著	打 街 罵 巷	打 進	打 量	打 開	打 亂	打 傷	打 勤 獻 趣	
打 暈	打 滑	打 碎	打 群 架	打 腫	打 腫 臉 充 胖 子	打 落	打 落 水 狗	
打 過	打 雷	打 電 報	打 電 話	打 靶	打 鼓	打 旗 號	打 槍	
打 滾	打 滾 撒 潑	打 算	打 算 盤	打 緊	打 鳳 牢 龍	打 鳳 撈 龍	打 噎	
打 噴	打 噴 嚏	打 彈 子	打 撲	打 撈	打 撈 船	打 樣	打 樁	
打 漿	打 瞌 睡	打 磕 睡	打 稿	打 穀	打 穀 場	打 穀 機	打 罵	
打 衝 鋒	打 賭	打 趣	打 趣 話	打 鬧	打 戰	打 擂 台	打 整	
打 磨	打 錯	打 頭	打 頭 陣	打 擊	打 擊 報 復	打 聲	打 褶	
打 點	打 點 子	打 點 行 裝	打 鼾	打 鼾 者	打 擾	打 斷	打 獵	
打 翻	打 蟲 藥	打 轉	打 雜	打 壞	打 繩 節	打 贏	打 殲 滅 戰	
打 爛	打 蠟	打 鐵	打 響	打 聽	打 顫	打 攪	打 鑼	
打 夯	打 哆 嗦	打 嗝	打 嗝 兒	打 諢	打 諢 插 科	扔 了	扔 下	
扔 出	扔 向	扔 回	扔 在	扔 到	扔 掉	扔 棄	扔 球	
扔 給	扔 進	扒 手	扒 出	扒 地	扒 車	扒 拉	扒 起	
扒 尋	扒 開	扒 鴨	扒 雞	扒 竊	斥 力	斥 之	斥 退	
斥 責	斥 責 者	斥 喝	斥 資	斥 罵	斥 賣	旦 夕	旦 旦	
旦 旦 信 誓	旦 角	本 人	本 上	本 土	本 子	本 小 利 大	本 小 利 微	
本 分	本 心	本 支 百 世	本 文	本 日	本 月	本 片	本 世 紀	
本 世 紀 內	本 世 紀 末	本 世 紀 初	本 主	本 刊	本 司	本 台	本 台 記 者	
本 句	本 市	本 平 方 米	本 本	本 本 分 分	本 本 主 義	本 本 源 源	本 末	
本 末 倒 置	本 份	本 同 末 異	本 名	本 因 坊	本 地	本 地 人	本 地 區	
本 地 網 絡	本 州	本 州 島	本 年	本 年 度	本 式	本 旨	本 旬	
本 次	本 色	本 行	本 位	本 位 主 義	本 位 制	本 利	本 局	
本 我	本 批	本 村	本 系	本 系 統	本 身	本 事	本 例	
本 來	本 來 面 目	本 兒	本 卷	本 周	本 命	本 季	本 季 度	
本 屆	本 性	本 性 難 移	本 所	本 版	本 社	本 初	本 表	
本 金	本 品	本 室	本 省	本 相	本 科	本 科 生	本 紀	
本 頁	本 值	本 原	本 家	本 島	本 息	本 書	本 校	
本 案	本 班	本 站	本 級	本 能	本 能 衝 動	本 草	本 草 綱 目	
本 院	本 區	本 國	本 國 產	本 國 語	本 國 銀 行	本 埠	本 堂	
本 族	本 條	本 票	本 組	本 處	本 部	本 部 門	本 章	
本 單 位	本 場	本 報	本 報 記 者	本 報 訊	本 期	本 港	本 然	
本 著	本 鄉	本 鄉 本 土	本 隊	本 項	本 意	本 想	本 會	
本 源	本 溪	本 當	本 盟 紡 織	本 節	本 義	本 號	本 該	
本 該 如 此	本 團	本 幣	本 說	本 需	本 領	本 劇	本 廠	
本 質	本 質 上	本 質 性	本 輪	本 機	本 機 振 蕩	本 縣	本 錢	
本 應	本 戲	本 擬	本 營	本 職	本 職 工 作	本 題	本 類	
本 籍	本 體	本 體 論	未 了	未 了 公 案	未 卜	未 卜 先 知	未 上	
未 上 市 公 司	未 上 市 盤	未 上 弦	未 上 栓	未 久	未 亡	未 亡 人	未 干	
未 之	未 予	未 分	未 分 割	未 分 裂	未 分 開	未 分 選	未 分 離	
未 切 割	未 及	未 反 駁	未 付	未 出	未 出 聲	未 刊 行	未 加	
未 加 工	未 占	未 去 殼	未 可	未 可 同 日 而 語	未 可 厚 非	未 平	未 必	
未 必 有	未 必 然	未 打 破	未 生	未 生 效	未 用	未 用 過	未 用 盡	
未 交	未 列	未 列 出	未 向	未 在	未 好	未 安 排	未 成	
未 成 一 簣	未 成 功	未 成 年	未 成 年 人	未 成 形	未 成 長	未 成 熟	未 扣	
未 收	未 收 割	未 有	未 老 先 衰	未 艾 方 興	未 行	未 行 之 患	未 佔 用	
未 佔 領	未 作	未 兌	未 免	未 妥	未 完	未 完 成	未 完 待 續	
未 形 成	未 批 判	未 批 准	未 改	未 改 革	未 改 變	未 決	未 決 定	
未 決 意	未 見	未 見 分 曉	未 見 到	未 足 為 道	未 使	未 使 用	未 供 認	
未 來	未 來 技 術	未 來 派	未 來 研 究	未 來 學	未 到	未 卸 下	未 受	
未 受 阻	未 受 理	未 受 傷	未 受 損	未 和 解	未 奉 命	未 始	未 始 不 可	
未 定	未 定 之 天	未 定 角	未 定 義	未 征	未 放	未 明 求 衣	未 明 言	
未 武 裝	未 知	未 知 一 丁	未 知 所 措	未 知 量	未 知 萬 一	未 知 數	未 表 示	
未 長 成	未 附	未 附 屬	未 雨 綢 繆	未 便	未 剃 鬚	未 建 造	未 按	
未 指 定	未 流 通	未 洗	未 為	未 穿 過	未 穿 靴	未 約 定	未 范	
未 要	未 訂 婚	未 風 先 雨	未 修 正	未 修 改	未 准	未 時	未 格	
未 消 化	未 烘 透	未 純 化	未 納	未 能	未 能 如 願	未 能 免 俗	未 能 得 逞	
未 記	未 配 對	未 做	未 動	未 動 過	未 區	未 參 戰	未 娶	
未 婚	未 婚 夫	未 婚 妻	未 將	未 帶	未 得	未 掩 蔽	未 掃 清	
未 推 動	未 排 定	未 救 濟	未 清	未 清 算	未 烹 調	未 移 動	未 組 成	
未 組 織	未 處 理	未 被	未 規 定	未 設	未 設 防	未 陳 舊	未 竟	
未 竟 之 志	未 就	未 幾	未 提	未 提 到	未 揭 露	未 敢	未 曾	
未 減 輕	未 焚 徙 薪	未 然	未 煮 透	未 煮 過	未 煮 熟	未 琢 磨	未 登 記	
未 發	未 發 展	未 發 現	未 發 覺	未 稀 釋	未 答 覆	未 結 束	未 裂 開	
未 貼	未 開	未 開 化	未 開 拓	未 開 發	未 開 墾	未 意	未 感 染	
未 想	未 損 壞	未 搗 碎	未 毀	未 滅	未 準 備	未 碰 上	未 碰 過	
未 經	未 補	未 解	未 解 決	未 解 釋	未 詳	未 試 過	未 誇 張	
未 載 名	未 載 明	未 遂	未 遂 犯	未 遂 政 變	未 達	未 達 一 間	未 達 到	
未 過	未 預	未 馴 服	未 嘗	未 嘗 不 可	未 歌 頌	未 演 出	未 滿	
未 滿 月	未 滿 足	未 盡	未 盡 事 宜	未 精 煉	未 腐 敗	未 說	未 說 出	
未 說 明	未 審 理	未 標	未 標 明	未 標 號	未 熟	未 確 定	未 確 證	
未 編 號	未 編 輯	未 緩 和	未 誕 生	未 請	未 賣 出	未 醉	未 墾	
未 磨 光	未 錯	未 雕 琢	未 壓 縮	未 獲	未 獲 獎	未 聲 明	未 聯 合	
未 褻 瀆	未 點 燃	未 歸 類	未 翻 轉	未 離	未 關	未 覺	未 觸 動	
未 讀	未 變	未 粘 牢	未 舖 設	末 了	末 大 不 掉	末 大 必 折	末 子	
末 日	末 片	末 世	末 世 啟 世 錄	末 代	末 伏	末 名	末 如 之 何	
末 年	末 次	末 考	末 行	末 位	末 尾	末 車	末 枝	
末 狀	末 後	末 流	末 頁	末 班	末 班 車	末 梢	末 梢 部	
末 期	末 稍	末 節	末 節 細 行	末 葉	末 路	末 路 之 難	末 路 窮 途	
末 態	末 端	末 學 膚 受	札 手 舞 腳	札 記	札 幌	札 達	正 人 先 正 己	
正 人 君 子	正 三 角 形	正 下 方	正 上	正 大	正 大 光 明	正 大 堂 皇	正 己 守 道	
正 中	正 中 下 懷	正 中 己 懷	正 切	正 午	正 反	正 反 兩 方 面	正 反 面	
正 反 器	正 心 誠 意	正 手	正 文	正 方	正 方 形	正 方 體	正 月	
正 比	正 比 例	正 片	正 冊	正 北	正 史	正 句	正 巧	
正 旦	正 本	正 本 清 源	正 本 溯 源	正 本 澄 源	正 正 堂 堂	正 用	正 由	
正 交	正 交 基	正 兇	正 向	正 名	正 名 責 實	正 合 適	正 因 為 如 此	
正 因 為 這 樣	正 在	正 多 面 體	正 多 邊 形	正 好	正 好 是	正 如	正 字	
正 安	正 式	正 式 化	正 式 成 立	正 式 訪 問	正 式 開 始	正 成 大 錯	正 色	
正 色 危 言	正 色 取 言	正 色 直 言	正 西	正 位	正 告	正 扭	正 投 影	
正 步	正 沒	正 言	正 言 不 諱	正 言 直 諫	正 言 厲 色	正 言 厲 顏	正 身	
正 身 明 法	正 身 清 心	正 身 率 下	正 事	正 典	正 取	正 和	正 宗	
正 定	正 弦	正 弦 波	正 房	正 東	正 果	正 法	正 法 直 度	
正 法 眼 藏	正 版	正 直	正 直 無 私	正 直 無 邪	正 表	正 長 石	正 門	
正 冠 李 下	正 冠 納 履	正 前 方	正 南	正 品	正 型	正 室	正 屋	
正 待	正 急	正 是	正 派	正 相	正 相 反	正 紅	正 要	
正 負	正 軌	正 面	正 面 人 物	正 面 教 育	正 面 戰 場	正 音	正 音 法	
正 值	正 峰 工 業	正 差	正 座	正 時	正 氣	正 院	正 骨	
正 副	正 問	正 堂	正 常	正 常 人	正 常 化	正 常 生 活	正 常 生 產	
正 常 值	正 常 秩 序	正 常 情 況	正 常 現 象	正 常 渠 道	正 常 運 轉	正 常 關 係	正 從	
正 教	正 梁	正 理	正 盛	正 眼	正 統	正 統 性	正 統 思 想	
正 統 派	正 統 觀 念	正 處	正 處 於	正 被	正 規	正 規 化	正 規 軍	
正 逢	正 途	正 割	正 崴 精 密	正 菜	正 視	正 視 眼	正 視 圖	
正 視 繩 行	正 詞 法	正 陽	正 隆	正 隆 公 司	正 黑	正 傳	正 想	
正 新 橡 膠	正 業	正 楷	正 極	正 殿	正 當	正 當 化	正 當 手 段	
正 當 年	正 當 防 衛	正 當 理 由	正 當 權 利	正 當 權 益	正 經	正 經 八 百	正 義	
正 義 事 業	正 義 鬥 爭	正 義 感	正 號	正 該	正 話	正 路	正 道	
正 道 工 業	正 過	正 電	正 電 子	正 電 荷	正 像	正 對	正 對 著	
正 幣	正 態 分 佈	正 誤	正 數	正 確	正 確 引 導	正 確 方 向	正 確 地	
正 確 性	正 確 軌 道	正 確 理 解	正 確 處 理	正 確 路 線	正 確 對 待	正 確 認 識	正 確 領 導	
正 編	正 論	正 學	正 橋	正 餐	正 龜 成 鱉	正 壓	正 幫	
正 擊	正 濱 漁 港	正 磷 酸	正 聲 雅 音	正 聯	正 點	正 點 背 畫	正 職	
正 豐	正 離 子	正 顏 厲 色	正 題	正 襟	正 襟 危 坐	正 襟 安 坐	正 歡	
正 體	正 鹽	正 廳	正 鑲 白 旗	正 烷 屬 烴	母 女	母 子	母 方	
母 牛	母 以 子 貴	母 奶	母 本	母 后	母 羊	母 老 虎	母 系	
母 系 制	母 乳	母 性	母 板	母 狗	母 的	母 表	母 音	
母 音 間	母 料	母 校	母 株	母 畜	母 國	母 教	母 液	
母 鹿 皮	母 港	母 慈 子 孝	母 愛	母 獅 子	母 舅	母 蜂	母 道	
母 語	母 語 教 學	母 線	母 豬	母 質	母 樹	母 機	母 艙	
母 親	母 親 似	母 鴨	母 雞	母 獸	母 艦	母 鐘	母 體	
民 力	民 力 雕 弊	民 女	民 工	民 不 安 枕	民 不 畏 死	民 不 聊 生	民 不 堪 命	
民 反	民 夫	民 心	民 戶	民 主	民 主 人 士	民 主 化	民 主 主 義	
民 主 政 治	民 主 集 中 制	民 主 德 國	民 主 黨	民 主 黨 派	民 主 權	民 以 食 本	民 以 食 為 天	
民 生	民 生 科 技	民 生 凋 敝	民 生 國 計	民 生 塗 炭	民 生 雕 敝	民 用	民 用 工 業	
民 用 飛 機	民 用 航 空	民 用 產 品	民 田	民 宅	民 安	民 安 物 阜	民 安 國 泰	
民 兵	民 兵 工 作	民 兵 建 設	民 兵 英 雄	民 兵 隊	民 防	民 防 建 設	民 防 體 制	
民 事	民 事 法 庭	民 事 糾 紛	民 事 案 件	民 事 訴 訟	民 協	民 和 年 稔	民 和 年 豐	
民 委	民 官	民 房	民 法	民 初	民 俗	民 俗 學	民 俗 藝 術	
民 俗 藝 術 節	民 品	民 建	民 怨	民 怨 沸 騰	民 怨 盈 塗	民 政	民 政 工 作	
民 政 司	民 政 局	民 政 部	民 政 廳	民 柬	民 為 邦 本	民 約	民 胞 物 與	
民 革	民 革 中 央	民 風	民 食	民 校	民 殷 財 阜	民 殷 國 富	民 氣	
民 脂	民 脂 民 膏	民 航	民 航 局	民 國	民 康 物 阜	民 強	民 情	
民 情 物 理	民 惟 邦 本	民 族	民 族 化	民 族 主 義	民 族 自 治	民 族 自 治 地 區	民 族 性	
民 族 資 本	民 族 資 產 階 級	民 族 團	民 族 學	民 望	民 淳 俗 厚	民 眾	民 眾 日 報	
民 船	民 富 國 強	民 智	民 視	民 進	民 進 黨	民 間	民 間 文 學	
民 間 舞	民 間 藝 術	民 雄	民 勤	民 意	民 意 代 表	民 意 測 驗	民 意 調 查	
民 意 論 壇	民 盟	民 盟 中 央	民 賊	民 賊 獨 夫	民 運	民 團	民 歌	
民 熙 物 阜	民 粹	民 粹 派	民 膏	民 膏 民 脂	民 憤	民 樂	民 窮	
民 窮 財 匱	民 窮 財 盡	民 調	民 調 公 司	民 學	民 興 國 際	民 諺	民 辦	
民 辦 公 助	民 辦 教 師	民 選	民 營	民 謠	民 警	民 權	民 權 主 義	
民 變	永 久	永 久 性	永 久 磁 鐵	永 大 機 電	永 不	永 不 生 ��	永 不 再	
永 世	永 世 其 芳	永 世 無 窮	永 永 無 窮	永 生	永 生 永 世	永 生 鳥	永 光 化 學	
永 兆 精 密	永 存	永 存 不 朽	永 安 鄉	永 安 漁 港	永 別	永 享	永 和 市	
永 定	永 居	永 往	永 昌 證 券	永 信 建 設	永 信 藥 品	永 保	永 垂	
永 垂 不 朽	永 垂 青 史	永 恆	永 春	永 珍	永 眠	永 純 化 工	永 能	
永 記 造 漆	永 動 機	永 康	永 捷 高 分	永 訣	永 無	永 無 止 境	永 無 休 止	
永 傳 不 朽	永 葆 青 春	永 裕 塑 膠	永 靖	永 靖 鄉	永 嘉	永 彰 機 電	永 磁	
永 誌 不 忘	永 遠	永 駐	永 錫 不 匱	永 豐 餘	汁 水	汁 兒	汁 液	
汁 質	汀 江	氾 濫	氾 濫 成 災	犯 了	犯 了 罪	犯 人	犯 下	
犯 上	犯 上 作 亂	犯 大 錯	犯 不 上	犯 不 著	犯 天 下 之 大 不 韙	犯 有	犯 有 前 科	
犯 而 不 校	犯 而 務 校	犯 忌	犯 戒	犯 事	犯 法	犯 法 者	犯 者	
犯 案	犯 病	犯 做	犯 得 著	犯 殺	犯 規	犯 愁	犯 禁	
犯 罪	犯 罪 分 子	犯 罪 者	犯 罪 率	犯 罪 學	犯 過 者	犯 境	犯 疑	
犯 錯	犯 錯 誤	犯 顏 苦 諫	犯 顏 極 諫	犯 難	玄 之 又 玄	玄 乎	玄 妙	
玄 妙 入 神	玄 妙 莫 測	玄 妙 無 窮	玄 武	玄 圃 積 玉	玄 奘	玄 孫	玄 秘	
玄 教	玄 理	玄 虛	玄 黃 翻 覆	玄 奧	玄 想	玄 疑	玄 學	
玄 學 家	玄 機	玄 機 妙 算	玄 謀 廟 算	玄 關	玄 關 妙 理	玉 女	玉 山 神 學 院	
玉 山 將 崩	玉 山 票 券	玉 山 傾 倒	玉 山 傾 頹	玉 山 銀 行	玉 井 鄉	玉 友 金 昆	玉 尺 量 才	
玉 卮 無 當	玉 石	玉 石 不 分	玉 石 同 沉	玉 石 同 焚	玉 石 同 燼	玉 石 俱 焚	玉 石 俱 摧	
玉 石 俱 燼	玉 石 景 天	玉 立	玉 立 亭 亭	玉 宇	玉 宇 瓊 樓	玉 成	玉 成 其 事	
玉 成 其 美	玉 米	玉 米 片	玉 米 花	玉 米 面	玉 米 粥	玉 米 餅	玉 米 螟	
玉 色	玉 佛	玉 言	玉 里	玉 里 鎮	玉 兔	玉 制	玉 帛	
玉 昆 金 友	玉 枝 金 葉	玉 林	玉 門	玉 門 關	玉 屏	玉 帝	玉 律 金 科	
玉 皇	玉 皇 大 帝	玉 食 錦 衣	玉 振 金 聲	玉 珮	玉 般	玉 骨 冰 肌	玉 堂 金 門	
玉 堂 金 馬	玉 帶	玉 液 瓊 漿	玉 軟 花 柔	玉 軟 香 溫	玉 釵	玉 壺	玉 減 香 消	
玉 溪	玉 照	玉 碎	玉 碎 花 銷	玉 碎 香 消	玉 碎 香 殘	玉 碎 珠 沉	玉 葉	
玉 葉 金 枝	玉 葉 金 柯	玉 蜀	玉 蜀 黍	玉 滴 石	玉 腿	玉 貌 花 容	玉 樓 金 殿	
玉 樓 金 閣	玉 樓 金 闕	玉 漿	玉 潔 冰 清	玉 盤	玉 質 金 相	玉 齒	玉 器	
玉 樹	玉 雕	玉 環	玉 臂	玉 璽	玉 蘭	玉 蘭 片	玉 鐲	
玉 露	玉 體	瓜 子	瓜 子 臉	瓜 仁	瓜 分	瓜 分 豆 剖	瓜 片	
瓜 田	瓜 田 不 納 履	瓜 田 之 嫌	瓜 田 李 下	瓜 皮	瓜 地	瓜 地 馬 拉	瓜 字 初 分	
瓜 肉	瓜 李 之 嫌	瓜 果	瓜 剖 豆 分	瓜 秧	瓜 條	瓜 棚	瓜 葛	
瓜 農	瓜 熟	瓜 熟 蒂 落	瓜 蔓	瓜 類	瓜 瓤	瓦 千 時	瓦 工	
瓦 片	瓦 全	瓦 匠	瓦 合 之 卒	瓦 房	瓦 狀	瓦 屋	瓦 盆	
瓦 時	瓦 特	瓦 特 計	瓦 特 時	瓦 特 數	瓦 釜 之 鳴	瓦 釜 雷 鳴	瓦 圈	
瓦 斯	瓦 斯 外 洩	瓦 斯 費	瓦 棺 篆 鼎	瓦 塊	瓦 楞 紙	瓦 當	瓦 解	
瓦 解 土 崩	瓦 解 冰 消	瓦 解 冰 銷	瓦 解 冰 泮	瓦 解 星 飛	瓦 解 星 散	瓦 解 雲 散	瓦 影 龜 魚	
瓦 數	瓦 器 蚌 盤	瓦 類	瓦 礫	瓦 罐	瓦 罐 不 離 井 口 破	甘 之 如 飴	甘 之 如 薺	
甘 之 若 素	甘 之 若 飴	甘 井 先 竭	甘 分 隨 時	甘 心	甘 心 如 薺	甘 心 情 願	甘 心 瞑 目	
甘 比	甘 比 亞	甘 比 亞 共 和 國	甘 汁	甘 瓜 苦 蒂	甘 休	甘 地	甘 守	
甘 旨 肥 濃	甘 死 如 飴	甘 孜	甘 言 巧 辭	甘 言 好 辭	甘 言 厚 幣	甘 言 厚 禮	甘 言 美 語	
甘 谷	甘 受	甘 味	甘 居 中 游	甘 於	甘 松 香	甘 油	甘 油 酯	
甘 雨	甘 雨 隨 車	甘 冒	甘 冒 虎 口	甘 拜	甘 拜 下 風	甘 泉	甘 泉 必 竭	
甘 美	甘 美 多 汁	甘 苦	甘 草	甘 國 亮	甘 甜	甘 處 下 流	甘 貧 守 分	
甘 貧 守 志	甘 貧 守 節	甘 貧 樂 道	甘 棠 之 惠	甘 棠 之 愛	甘 棠 遺 愛	甘 結	甘 肅	
甘 肅 省	甘 菊	甘 當	甘 當 無 名 英 雄	甘 酸	甘 蔗	甘 蔗 渣	甘 霖	
甘 薯	甘 藍	甘 願	甘 馨 之 費	甘 露	甘 露 法 雨	甘 露 醇	生 了	
生 了 ��	生 人	生 人 塗 炭	生 力 軍	生 下	生 土	生 女	生 子	
生 小 牛	生 小 孩	生 不 逢 辰	生 不 逢 時	生 不 遇 時	生 公 說 法 頑 石 點 頭	生 分	生 化	
生 化 科 技 業	生 反 感	生 手	生 日	生 毛	生 水	生 水 果	生 水 泡	
生 火	生 父	生 仔	生 他	生 出	生 平	生 平 事 跡	生 母	
生 民	生 民 塗 炭	生 生 不 息	生 生 世 世	生 皮 鞋	生 石 灰	生 光	生 同 衾 死 同 穴	
生 合 成	生 吃	生 地	生 在	生 字	生 存	生 存 保 險	生 存 能 力	
生 存 率	生 存 遊 戲	生 存 權	生 年	生 成	生 成 物	生 有	生 死	
生 死 不 渝	生 死 之 交	生 死 予 奪	生 死 存 亡	生 死 有 命	生 死 肉 骨	生 死 別 離	生 死 攸 關	
生 死 線	生 死 輪 迴	生 死 關	生 死 關 頭	生 死 觀	生 米	生 米 做 成 熟 飯	生 米 煮 成 熟 飯	
生 羽 毛	生 老 病 死	生 而	生 而 知 之	生 肉	生 肉 芽	生 色	生 佛 萬 家	
生 冷	生 吞	生 吞 活 剝	生 妖 作 怪	生 我 劬 勞	生 技 股	生 材	生 男 育 女	
生 肖	生 育	生 育 保 健	生 角	生 身 父 母	生 辰	生 事	生 事 擾 民	
生 來	生 來 死 去	生 兒	生 兒 育 女	生 受	生 命	生 命 力	生 命 在 於 運 動	
生 命 攸 關	生 命 財 產	生 命 層	生 命 線	生 命 學	生 怕	生 性	生 拉 硬 拽	
生 於	生 於 憂 患 死 於 安 樂	生 法	生 油	生 物	生 物 工 程	生 物 化 學	生 物 技 術	
生 物 武 器	生 物 界	生 物 科 技	生 物 能	生 物 圈	生 物 量	生 物 資 源	生 物 電	
生 物 態	生 物 製 品	生 物 學	生 物 學 界	生 物 戰	生 物 鐘	生 物 體	生 物 鹼	
生 的	生 者	生 花 妙 筆	生 長	生 長 出	生 長 素	生 長 率	生 長 期	
生 長 髮 育	生 長 點	生 非 作 歹	生 俘	生 前	生 前 友 好	生 客	生 後	
生 染	生 活	生 活 上	生 活 方 式	生 活 水 平	生 活 者	生 活 消 費	生 活 區	
生 活 費	生 活 會	生 活 資 料	生 為	生 疥 癬	生 計	生 面	生 食	
生 香 油	生 恐	生 息	生 息 蕃 庶	生 效	生 料	生 時	生 根	
生 桑 之 夢	生 氣	生 氣 勃 勃	生 氣 蓬 勃	生 病	生 粉	生 荒	生 財	
生 財 之 道	生 財 有 道	生 動	生 動 活 潑	生 寄 死 歸	生 張 熟 魏	生 情 見 景	生 殺 之 權	
生 殺 予 奪	生 殺 與 奪	生 涯	生 猛	生 球 根	生 理	生 理 心 理 學	生 理 用 品	
生 理 特 點	生 理 衛 生	生 理 學	生 理 鹽 水	生 產	生 產 力	生 產 力 中 心	生 產 力 與 生 產 關 係	
生 產 上	生 產 大 隊	生 產 工 具	生 產 方 式	生 產 毛 額	生 產 水 平	生 產 自 救	生 產 性	
生 產 性 建 設	生 產 者	生 產 指 標	生 產 秩 序	生 產 國	生 產 條 件	生 產 率	生 產 責 任 制	
生 產 量	生 產 隊	生 產 資 料	生 產 過 剩	生 產 線	生 產 戰 線	生 產 操	生 產 總 值	
生 產 額	生 產 關 係	生 疏	生 疏 了	生 處	生 蛆	生 蛋	生 魚 片	
生 就	生 悲	生 棟 覆 屋	生 殖	生 殖 力	生 殖 者	生 殖 期	生 殖 腺	
生 殖 器	生 湊	生 煮	生 發	生 硬	生 絲	生 菌 劑	生 菜	
生 詞	生 意	生 意 人	生 意 經	生 意 興 隆	生 搬 硬 套	生 源	生 源 論	
生 義	生 路	生 達 製 藥	生 厭	生 境	生 奪 硬 抱	生 態	生 態 平 衡	
生 態 位	生 態 系 統	生 態 保 育	生 態 建 設	生 態 經 濟 學	生 態 學	生 態 環 境	生 態 藝 術	
生 榮 死 哀	生 滿	生 漆	生 疑	生 端	生 聚 教 訓	生 銅	生 餅	
生 齊	生 僻	生 潰 瘍	生 熱	生 豬	生 趣	生 輝	生 霉	
生 養	生 齒 日 繁	生 擒	生 擒 活 拿	生 擒 活 捉	生 樹 脂	生 機	生 機 勃 勃	
生 龍 活 虎	生 澀	生 膿 泡	生 薑	生 還	生 還 者	生 鮮 食 品	生 蟲	
生 離 死 別	生 離 死 絕	生 譜	生 關 死 劫	生 麵 團	生 懼	生 鐵	生 權	
生 變	生 靈	生 靈 塗 炭	生 坯	生 ��	用 一 句 話 來 說	用 一 當 十	用 了	
用 人	用 人 不 當	用 人 單 位	用 力	用 力 扯	用 力 拉	用 力 拖	用 上	
用 工	用 不	用 不 完	用 不 著	用 之	用 之 不 竭	用 之 於	用 什 麼	
用 分	用 反	用 天 因 地	用 心	用 心 良 苦	用 心 竭 力	用 戶	用 戶 至 上	
用 戶 意 見	用 手	用 文	用 水	用 以	用 他	用 出	用 功	
用 去	用 布	用 用	用 光	用 刑	用 印	用 地	用 在	
用 好	用 字	用 此	用 行 捨 藏	用 作	用 兵	用 兵 如 神	用 吧	
用 完	用 把	用 材	用 材 林	用 車	用 事	用 來	用 兩	
用 兩 耳	用 具	用 其 所 長	用 到	用 性	用 房	用 於	用 武	
用 武 之 地	用 法	用 的	用 者	用 非 其 人	用 非 所 學	用 勁	用 品	
用 度	用 後	用 指	用 為	用 計	用 計 舖 謀	用 唇	用 夏 變 夷	
用 家	用 料	用 氣	用 破	用 草 奇 花	用 財	用 帶	用 得 著	
用 掉	用 捨 行 藏	用 畢	用 處	用 處 小	用 途	用 場	用 智 舖 謀	
用 款	用 著	用 詞	用 詞 不 當	用 費	用 逸 代 勞	用 量	用 項	
用 匯	用 意	用 意 何 在	用 煤	用 腦	用 過	用 電	用 電 量	
用 圖	用 圖 表	用 槍	用 盡	用 盡 心 機	用 管 窺 天	用 語	用 嘴	
用 賢 任 能	用 膳	用 錯	用 錢	用 錢 如 水	用 頭	用 餐	用 聲 音	
用 糧	用 職	用 舊	用 舊 了	用 壞	用 藥	用 辭	甩 了	
甩 手	甩 車	甩 到	甩 動	甩 掉	甩 脫	甩 開	甩 落	
甩 賣	田 七	田 中	田 夫 野 老	田 父 之 獲	田 主	田 弘 茂	田 地	
田 宅	田 尾 鄉	田 東	田 契	田 埂	田 徑	田 徑 運 動	田 徑 賽	
田 畝	田 租	田 納 西	田 捨	田 產	田 莊	田 連 仟 陌	田 連 阡 陌	
田 野	田 間	田 間 試 驗	田 間 管 理	田 園	田 園 化	田 園 風 光	田 園 詩	
田 裡	田 鼠	田 寮 鄉	田 賦	田 頭	田 聯	田 螺	田 賽	
田 糧	田 雞	田 壟	田 疇	田 邊 地 頭	田 麗	田 鱉	田 塍	
由 人	由 下 向 上	由 下 而 上	由 上	由 上 向 下	由 上 而 下	由 大 到 小	由 不 得	
由 中 之 言	由 之	由 加	由 北 向 南	由 右 向 左	由 左 向 右	由 此	由 此 及 彼	
由 此 可 以 看 出	由 此 可 見	由 此 可 證	由 此 而 來	由 此 來 看	由 西 向 東	由 冷	由 來	
由 來 已 久	由 其	由 始 至 終	由 於	由 於 上 述 原 因	由 於 某 種 原 因	由 於 種 種 原 因	由 易 到 難	
由 東 向 西	由 表 及 裡	由 近	由 近 及 遠	由 南 向 北	由 省	由 衷	由 衷 之 言	
由 衷 感 謝	由 得	由 淺 入 深	由 盛 而 衰	由 博 返 約	由 該	由 遠	由 遠 而 近	
由 點 到 面	由 證	由 難 到 易	由 竇 尚 書	甲 乙	甲 乙 丙	甲 乙 雙 方	甲 士	
甲 子	甲 午	甲 天 下	甲 方	甲 仙 鄉	甲 申	甲 戌	甲 兵	
甲 肝	甲 板	甲 狀	甲 狀 腺	甲 狀 腺 炎	甲 狀 腺 結 節	甲 狀 腺 腫	甲 狀 腺 機 能 亢 進 症	
甲 型	甲 苯	甲 氨	甲 班	甲 級	甲 級 隊	甲 骨	甲 骨 文	
甲 基	甲 基 異 丁 基 酮	甲 第	甲 第 星 羅	甲 第 連 雲	甲 組 聯 賽	甲 魚	甲 殼	
甲 殼 類	甲 等	甲 種	甲 酸	甲 醇	甲 蟲	甲 蟲 類	甲 類	
甲 烷	甲 酚	甲 醚	甲 醛	申 斥	申 旦 達 夕	申 易	申 明	
申 述	申 冤	申 時	申 討	申 報	申 報 者	申 訴	申 訴 電 話	
申 誡	申 說	申 領	申 請	申 請 人	申 請 上 櫃	申 請 書	申 辨	
申 辦	申 辯	白 丁	白 丁 俗 客	白 人	白 刃	白 口 鐵	白 大 褂	
白 山 黑 水	白 干	白 內 障	白 化	白 化 病	白 天	白 天 黑 夜	白 手	
白 手 成 家	白 手 起 家	白 日	白 日 衣 繡	白 日 見 鬼	白 日 昇 天	白 日 做 夢	白 日 夢	
白 木	白 毛	白 水	白 片	白 令	白 布	白 打	白 扔	
白 玉	白 玉 無 瑕	白 玉 微 瑕	白 白	白 皮	白 皮 書	白 石	白 光	
白 冰 冰	白 吃	白 吃 白 喝	白 地	白 如	白 字	白 忙	白 死	
白 灰	白 米	白 肉	白 色	白 色 香 橙 花	白 色 恐 怖	白 血 病	白 血 球	
白 衣	白 衣 公 卿	白 衣 天 使	白 衣 秀 士	白 衣 卿 相	白 衣 宰 相	白 衣 蒼 狗	白 衣 戰 士	
白 坐	白 求 恩	白 芍	白 兔	白 卷	白 夜	白 居 易	白 底	
白 果	白 板 天 子	白 河	白 沫	白 狐	白 的	白 者	白 花	
白 花 花	白 花 齊 放	白 芷	白 虎	白 金	白 金 漢 宮	白 俄	白 俄 羅 斯	
白 城	白 屋 寒 門	白 柚	白 洋 澱	白 活	白 相	白 眉 赤 眼	白 虹 貫 日	
白 軍	白 面	白 面 書 生	白 頁	白 食	白 首	白 首 一 節	白 首 之 心	
白 首 北 面	白 首 同 歸	白 首 如 新	白 首 空 歸	白 首 相 知	白 首 無 成	白 首 窮 經	白 匪	
白 叟 黃 童	白 娘 子	白 宮	白 朗 寧	白 核	白 案	白 浪	白 海	
白 班	白 粉	白 紗	白 紙	白 紙 黑 字	白 茫 茫	白 送	白 酒	
白 馬	白 馬 非 馬	白 骨	白 骨 精	白 做	白 區	白 堊	白 專	
白 帶	白 族	白 晝	白 條	白 梨	白 毫 之 賜	白 淨	白 眼	
白 細	白 細 胞	白 脫 牛 奶	白 蛇	白 蛋 白	白 雪	白 雪 紛 飛	白 雪 陽 春	
白 魚 入 舟	白 喝	白 喉	白 堤	白 描	白 斑	白 湯	白 痢	
白 給	白 華 之 怨	白 菊	白 菜	白 費	白 費 力 氣	白 費 心 機	白 開 水	
白 雲	白 雲 山	白 雲 孤 飛	白 雲 蒼 狗	白 雲 親 捨	白 飯	白 黑	白 黑 分 明	
白 塔	白 搭	白 楊	白 葡 萄 酒	白 裙	白 裡 透 紅	白 話	白 話 文	
白 道	白 鼠	白 嘉 莉	白 嫩	白 旗	白 熊	白 種	白 種 人	
白 銀	白 銅	白 領	白 領 工 人	白 領 階 級	白 漿	白 熱	白 熱 化	
白 膚	白 蓮	白 豬	白 賠	白 醋	白 駒 空 谷	白 駒 過 隙	白 髮	
白 髮 朱 顏	白 髮 青 衫	白 髮 相 守	白 髮 紅 顏	白 髮 蒼 蒼	白 髮 蒼 顏	白 壁	白 學	
白 樺	白 熾	白 熾 燈	白 糖	白 鋼	白 頰	白 頭	白 頭 之 歎	
白 頭 如 新	白 頭 到 老	白 頭 相 守	白 頭 翁	白 頭 偕 老	白 頭 鳥	白 頭 髮	白 龍 魚 服	
白 龍 微 服	白 磷	白 臉	白 薯	白 賺	白 霜	白 點	白 璧 青 蠅	
白 璧 無 瑕	白 璧 微 瑕	白 蟲	白 鵝	白 癡	白 藥	白 蟻	白 鯨	
白 礬	白 籐	白 蘭	白 蘭 地	白 蘭 地 酒	白 蘭 花	白 蠟	白 蠟 明 經	
白 鐵	白 鐵 皮	白 鐵 礦	白 露	白 鶴	白 癲 風	白 鷺	白 鸛	
白 旄 黃 鉞	白 皙	皮 下	皮 下 組 織	皮 子	皮 之 不 存	皮 之 不 存 毛 將 焉 傅	皮 尺	
皮 毛	皮 包	皮 包 公 司	皮 包 骨	皮 卡 丘	皮 外	皮 件	皮 匠	
皮 肉	皮 衣	皮 夾	皮 夾 子	皮 制	皮 松 肉 緊	皮 炎	皮 的	
皮 厚	皮 相 之 士	皮 相 之 見	皮 相 之 談	皮 重	皮 面	皮 革	皮 革 商	
皮 革 藝 術	皮 套	皮 屑	皮 疹	皮 破	皮 笑	皮 笑 肉 不 笑	皮 脂	
皮 圈	皮 帶	皮 帶 輪	皮 桶	皮 條	皮 球	皮 蛋	皮 袋	
皮 貨	皮 軟	皮 部	皮 圍	皮 圍 巾	皮 帽	皮 棉	皮 殼	
皮 猴	皮 筋	皮 開 肉 破	皮 開 肉 綻	皮 開 肉 錠	皮 黃	皮 裡 春 秋	皮 裡 陽 秋	
皮 靴	皮 墊	皮 實	皮 爾 斯 布 洛 斯 南	皮 爾 絲	皮 層	皮 影	皮 影 戲	
皮 影 戲 團	皮 歐 林	皮 箱	皮 膠	皮 膚	皮 膚 上	皮 膚 之 見	皮 膚 炎	
皮 膚 病	皮 膚 病 變	皮 質	皮 輥	皮 鞋	皮 褲	皮 雕	皮 雕 師	
皮 癌	皮 鞭	皮 襖	皮 囊	目 人	目 力	目 下	目 下 十 行	
目 上	目 大 不 睹	目 不 交 睫	目 不 妄 視	目 不 忍 視	目 不 忍 睹	目 不 邪 視	目 不 知 書	
目 不 給 視	目 不 暇 接	目 不 窺 園	目 不 轉 晴	目 不 轉 視	目 不 轉 睛	目 不 識 丁	目 不 識 字	
目 中	目 中 無 人	目 牛 游 刃	目 牛 無 全	目 光	目 光 如 豆	目 光 如 炬	目 光 如 鼠	
目 光 呆 滯	目 光 短 淺	目 光 銳 利	目 成 心 許	目 次	目 即 成 誦	目 呆 口 咂	目 見	
目 見 耳 聞	目 使 頤 令	目 所 未 睹	目 披 手 抄	目 明	目 的	目 的 地	目 的 性	
目 的 意 義	目 的 論	目 空	目 空 一 切	目 空 一 世	目 空 四 海	目 前	目 指 氣 使	
目 挑 心 招	目 染 耳 濡	目 盼 心 思	目 若 懸 珠	目 疾	目 眩	目 眩 心 花	目 眩 神 迷	
目 眩 神 搖	目 眩 魂 搖	目 送	目 送 手 揮	目 迷 五 色	目 窕 心 與	目 測	目 無 下 塵	
目 無 全 牛	目 無 見 睫	目 無 法 紀	目 無 流 視	目 無 餘 子	目 視	目 睹	目 睹 耳 聞	
目 睜 口 呆	目 語	目 標	目 標 偽 裝	目 標 偵 察	目 標 責 任 制	目 標 管 理	目 瞠 口 哆	
目 錄	目 錄 學	目 錄 樹	目 擊	目 擊 耳 聞	目 擊 者	目 擊 道 存	目 濡 耳 染	
目 瞪	目 瞪 口 呆	目 瞪 舌 疆	目 瞪 神 呆	目 斷 飛 鴻	目 斷 魂 銷	目 斷 鱗 鴻	目 鏡	
矛 尖	矛 尖 狀	矛 刺	矛 和 盾	矛 柄	矛 盾	矛 盾 加 劇	矛 盾 律	
矛 盾 相 向	矛 盾 論	矛 盾 激 化	矛 盾 轉 化	矛 頭	矢 下 如 雨	矢 口	矢 口 否 認	
矢 口 抵 賴	矢 不 虛 發	矢 石 之 間	矢 石 之 難	矢 在	矢 在 弦 上	矢 如 雨 集	矢 死 不 二	
矢 志	矢 志 不 屈	矢 志 不 渝	矢 志 捐 軀	矢 言	矢 的	矢 無 虛 發	矢 量	
矢 槍	矢 盡 兵 窮	石 □	石 一 般	石 女	石 子	石 山	石 工	
石 井 丈 裕	石 化	石 心	石 心 木 腸	石 方	石 火 電 光	石 匠	石 印	
石 印 品	石 灰	石 灰 化	石 灰 水	石 灰 石	石 灰 乳	石 灰 窯	石 灰 質	
石 灰 巖	石 竹	石 臼	石 阡	石 坑	石 投 大 海	石 材	石 村	
石 沉 大 海	石 刻	石 岡	石 斧	石 林	石 板	石 板 瓦	石 板 樣	
石 油	石 油 工 業	石 油 化 工	石 油 市 場	石 油 地 理	石 油 氣	石 油 勘 探	石 油 商	
石 油 精	石 油 輸 出 國 組 織	石 版	石 版 家	石 版 畫	石 門	石 城	石 室 金 匱	
石 屏	石 拱	石 柱	石 枯 松 老	石 洞	石 炭	石 炭 酸	石 穿	
石 英	石 英 磚	石 英 鐘	石 英 巖	石 苔	石 原 慎 太 郎	石 家 莊	石 家 莊 市	
石 島	石 徑	石 料	石 破 天 驚	石 粉	石 級	石 舫	石 堆	
石 基	石 梯	石 硫 合 劑	石 場	石 斑 虹	石 斑 魚	石 景	石 景 山	
石 棺	石 棉	石 棉 瓦	石 渠	石 渣	石 筆	石 筍	石 階	
石 塔	石 塊	石 獅	石 碑	石 窟	石 腦 油	石 鼓	石 像	
石 凳	石 榴	石 碣	石 綿	石 膏	石 膏 板	石 膏 粉	石 膏 質	
石 製	石 酸	石 樓	石 窯	石 墨	石 器	石 壁	石 橋	
石 燕	石 蕊	石 雕	石 雕 家	石 頭	石 牆	石 縫	石 鎖	
石 臘	石 礫	石 鐘 乳	石 欄	石 爛	石 爛 海 枯	石 蠟	石 碇 鄉	
石 碴	石 舖	示 人	示 以	示 出	示 例	示 波 圖	示 波 管	
示 波 器	示 波 鏡	示 法	示 物	示 威	示 威 者	示 威 遊 行	示 弱	
示 眾	示 意	示 意 性	示 意 圖	示 愛	示 圖	示 數 器	示 範	
示 範 戶	示 範 作 用	示 範 表 演	示 範 動 作	示 範 區	示 警	禾 本 科	禾 伸 堂	
禾 谷	禾 苗	禾 場	穴 中	穴 位	穴 見 小 儒	穴 居	穴 居 人	
穴 居 野 處	穴 處 之 徒	穴 處 知 雨	穴 鳥	穴 道	穴 播	穴 頭	立 人	
立 人 達 人	立 下	立 大 農 畜	立 井	立 升	立 戶	立 方	立 方 米	
立 方 形	立 方 英 尺	立 方 根	立 方 體	立 方 厘 米	立 木	立 冬	立 功	
立 功 立 事	立 功 自 效	立 功 受 獎	立 功 喜 報	立 功 贖 罪	立 正	立 生	立 交	
立 交 橋	立 吃 地 陷	立 地	立 地 成 佛	立 地 金 剛	立 地 書 櫥	立 式	立 式 琴	
立 有	立 此	立 此 存 照	立 米	立 即	立 志	立 言	立 足	
立 足 之 地	立 足 於	立 足 處	立 足 點	立 身	立 身 行 己	立 身 行 道	立 身 處 世	
立 身 揚 名	立 刻	立 卷	立 命	立 命 安 身	立 委	立 定	立 定 腳 跟	
立 性	立 於	立 於 不 敗 之 地	立 法	立 法 委 員	立 法 者	立 法 院	立 法 機 關	
立 法 權	立 者	立 契	立 姿	立 春	立 柱	立 派	立 為	
立 盹 行 眠	立 眉 瞪 眼	立 秋	立 竿	立 竿 見 影	立 約	立 約 人	立 面	
立 候	立 夏	立 時	立 時 三 刻	立 案	立 益 紡 織	立 起	立 院 質 詢	
立 國	立 國 之 本	立 國 安 邦	立 掃 千 言	立 統	立 陶 宛	立 場	立 等	
立 著	立 軸	立 隆 電 子	立 項	立 傳	立 嗣	立 意	立 感	
立 新	立 業	立 業 安 邦	立 碑	立 腳	立 腳 點	立 達	立 榮 海 運	
立 誓	立 說	立 德	立 衛 科 技	立 談 之 間	立 論	立 賢 無 方	立 憲	
立 憲 派	立 戰 功	立 據	立 遺 囑	立 錐 之 土	立 錐 之 地	立 櫃	立 黨 為 公	
立 體	立 體 交 叉	立 體 性	立 體 派	立 體 音	立 體 幾 何	立 體 畫	立 體 感	
立 體 圖	立 體 聲	立 體 鏡	丞 相	丟 了	丟 人	丟 三 落 四	丟 下	
丟 出	丟 失	丟 光	丟 在	丟 字	丟 到	丟 卒	丟 卒 保 車	
丟 放	丟 面	丟 面 子	丟 掉	丟 棄	丟 盔 卸 甲	丟 盔 棄 甲	丟 開	
丟 損	丟 盡	丟 魂 落 魄	丟 臉	丟 醜	丟 擲	丟 雞 蛋	乒 乒	
乒 乓	乒 乓 球	乒 壇	乓 乓	亙 古	亙 古 未 有	亙 古 亙 今	交 了	
交 入	交 上	交 叉	交 叉 口	交 叉 表	交 叉 科 學	交 叉 著	交 叉 路	
交 叉 學 科	交 口	交 口 稱 譽	交 口 稱 讚	交 大	交 工	交 互	交 互 式	
交 公	交 友	交 幻	交 心	交 手	交 火	交 付	交 付 使 用	
交 代	交 出	交 加	交 用	交 由	交 合	交 回	交 好	
交 存	交 托	交 兵	交 困	交 尾	交 角	交 足	交 來	
交 到	交 卷	交 卸	交 官	交 底	交 往	交 易	交 易 所	
交 易 者	交 易 品	交 易 商	交 易 會	交 易 額	交 朋 友	交 保	交 城	
交 待	交 流	交 流 會	交 流 電	交 流 電 機	交 流 聲	交 界	交 界 處	
交 相	交 相 輝 映	交 迭	交 迫	交 差	交 庫	交 涉	交 班	
交 租	交 租 金	交 納	交 送	交 配	交 售	交 寄	交 帳	
交 情	交 接	交 接 班	交 接 儀 式	交 淺 言 深	交 清	交 貨	交 通	
交 通 工 具	交 通 史	交 通 局	交 通 政 策	交 通 員	交 通 崗	交 通 處	交 通 規 則	
交 通 規 費	交 通 部	交 通 量	交 通 違 規	交 通 圖	交 通 管 制	交 通 銀 行	交 通 線	
交 通 壅 塞	交 割	交 單	交 惡	交 換	交 換 台	交 換 意 見	交 換 價 值	
交 換 器	交 換 機	交 替	交 椅	交 款	交 稅	交 結	交 結 面	
交 給	交 費	交 鈔	交 集	交 匯	交 匯 點	交 媾	交 感	
交 感 性	交 感 神 經	交 會	交 遊	交 道	交 電	交 槍	交 與	
交 際	交 際 性	交 際 花	交 際 舞	交 齊	交 稿	交 耦	交 誼	
交 誼 舞	交 談	交 談 式	交 賬	交 輝	交 鋒	交 戰	交 戰 中	
交 戰 者	交 戰 國	交 融	交 辦	交 錯	交 錯 法	交 錯 觥 籌	交 錢	
交 頭 接 耳	交 臂	交 臂 失 之	交 還	交 點	交 歸	交 織	交 關	
交 響	交 響 曲	交 響 詩	交 響 樂	交 響 樂 隊	交 響 樂 團	交 權	交 歡	
交 疊	交 變	交 變 磁 場	交 驗	亦 工 亦 農	亦 不	亦 不 例 外	亦 云	
亦 以	亦 可	亦 同	亦 在	亦 有	亦 作	亦 即	亦 步 亦 趨	
亦 佳	亦 或	亦 非	亦 按	亦 是	亦 要	亦 喜 亦 憂	亦 曾	
亦 無	亦 然	亦 須	亦 會	亦 稱	亦 應	亦 應 如 此	亦 趨	
亦 還	亦 屬	亥 豕 魯 魚	亥 時	仿 人	仿 古	仿 生	仿 生 學	
仿 行	仿 宋	仿 宋 體	仿 性	仿 金	仿 冒	仿 冒 者	仿 射	
仿 真	仿 真 器	仿 造	仿 造 皮	仿 造 者	仿 麻	仿 單	仿 畫	
仿 照	仿 製	仿 製 品	伉 儷	伙 人	伙 子	伙 夫	伙 兒	
伙 房	伙 計	伙 食	伊 人	伊 于 湖 底	伊 利 諾 州	伊 甸	伊 甸 園	
伊 妹 兒	伊 始	伊 拉 克	伊 拉 克 人	伊 拉 克 語	伊 朗	伊 朗 人	伊 朗 幣	
伊 能 靜	伊 教	伊 犁	伊 斯 蘭	伊 斯 蘭 教	伊 斯 蘭 堡	伊 勢 丹	伊 爾	
伊 麗 莎 白	伍 元	伍 佰	伍 拾	伍 迪 艾 倫	伍 茲	伍 萬	伍 德	
伐 木	伐 木 人	伐 木 者	伐 木 業	伐 毛 洗 髓	伐 性 之 斧	伐 區	伐 異	
伐 異 黨 同	伐 樹	休 士 頓	休 工	休 止	休 止 符	休 牛 放 馬	休 牛 散 馬	
休 牛 歸 馬	休 刊	休 克	休 怪	休 要	休 息	休 息 日	休 息 室	
休 息 處	休 書	休 眠	休 眠 期	休 耕	休 耕 中	休 假	休 得	
休 戚	休 戚 相 關	休 戚 與 共	休 斯 敦	休 斯 頓	休 閒	休 閒 中 心	休 閒 形 態	
休 閒 車	休 閒 服	休 閒 活 動	休 閒 娛 樂	休 閒 裝	休 閒 運 動	休 閒 學	休 想	
休 會	休 業	休 寧	休 管 他 人 瓦 上 霜	休 養	休 養 生 息	休 養 所	休 學	
休 憩	休 戰	休 整	伏 下	伏 天	伏 牛	伏 地	伏 在	
伏 安	伏 安 表	伏 安 計	伏 汛	伏 低 做 小	伏 兵	伏 旱	伏 身	
伏 法	伏 臥	伏 虎	伏 虎 降 龍	伏 屍	伏 屍 流 血	伏 苓	伏 案	
伏 特	伏 特 加 酒	伏 特 計	伏 特 數	伏 處	伏 暑	伏 筆	伏 貼	
伏 罪	伏 誅	伏 爾 加 河	伏 維 尚 饗	伏 羲	伏 擊	伏 擊 戰	仲 介	
仲 介 人	仲 冬	仲 春	仲 秋	仲 夏	仲 琦 科 技	仲 裁	仲 裁 人	
仲 裁 者	仲 間 由 紀 惠	件 件	件 事	件 數	任 一	任 人	任 人 為 賢	
任 人 宰 割	任 人 唯 賢	任 人 唯 親	任 之	任 內	任 天 堂	任 心	任 他	
任 令	任 加	任 它	任 用	任 由	任 至	任 何	任 何 一 方	
任 何 人	任 何 時 候	任 免	任 使	任 其	任 其 自 流	任 其 自 然	任 其 發 展	
任 取	任 命	任 命 者	任 性	任 者	任 便	任 為	任 重	
任 重 而 道 遠	任 重 致 遠	任 重 道 遠	任 務	任 務 書	任 務 欄	任 情	任 教	
任 勞	任 勞 任 怨	任 期	任 意	任 滿	任 課	任 賢 杖 能	任 賢 使 能	
任 賢 齊	任 憑	任 選	任 職	仰 人 鼻 息	仰 不 愧 天	仰 天	仰 仗	
仰 光	仰 向	仰 求	仰 沖	仰 角	仰 事 俯 畜	仰 承	仰 泳	
仰 者	仰 臥	仰 屋 興 歎	仰 屋 竊 歎	仰 度	仰 後	仰 面	仰 首	
仰 首 伸 眉	仰 望	仰 脖	仰 給	仰 視	仰 慕	仰 慕 者	仰 賴	
仰 頭	仰 觀 俯 察	份 上	份 子	份 內	份 內 份 外	份 外	份 兒	
份 量	份 飯	份 數	份 額	企 及	企 仰	企 求	企 足 而 待	
企 足 矯 首	企 事 業	企 事 業 單 位	企 盼	企 望	企 業	企 業 化	企 業 文 化	
企 業 自 主 權	企 業 改 革	企 業 承 包	企 業 法	企 業 界	企 業 倫 理	企 業 家	企 業 集 團	
企 業 經 濟	企 業 經 營	企 業 管 理	企 業 管 理 制 度	企 業 虧 損	企 劃	企 劃 組 織	企 圖	
企 管	企 慕	企 鵝	光 下	光 大	光 子	光 化 性	光 化 度	
光 化 學	光 天	光 天 之 下	光 天 化 日	光 火	光 片	光 光	光 合	
光 合 作 用	光 州	光 年	光 束	光 材 料	光 禿	光 禿 禿	光 芒	
光 芒 萬 丈	光 兒	光 坦	光 宗 耀 祖	光 怪 陸 離	光 或 熱	光 所	光 明	
光 明 日 報	光 明 正 大	光 明 面	光 明 磊 落	光 板	光 波	光 采	光 亮	
光 亮 度	光 前 絕 後	光 前 裕 後	光 前 耀 後	光 度	光 度 計	光 拴	光 是	
光 柱	光 柵	光 面	光 風 霽 月	光 氣	光 能	光 閃 閃	光 圈	
光 帶	光 彩	光 彩 照 人	光 彩 奪 目	光 控	光 敏	光 敏 電 阻	光 桿	
光 桿 司 令	光 通 信	光 速	光 陰	光 陰 如 電	光 陰 如 箭	光 陰 似 箭	光 鹵 石	
光 復	光 復 鄉	光 復 舊 京	光 復 舊 物	光 斑	光 景	光 棍	光 棍 兒	
光 測	光 焰	光 焰 萬 丈	光 筆	光 華	光 華 投 信	光 著	光 軸	
光 陽	光 感	光 暈	光 源	光 滑	光 滑 面	光 溜	光 溜 溜	
光 照	光 罩	光 群 雷 射	光 腳	光 電	光 電 二 極 管	光 電 子	光 電 池	
光 電 流	光 電 效 應	光 電 管	光 飾	光 榮	光 榮 任 務	光 榮 傳 統	光 榮 義 務	
光 榮 榜	光 榮 稱 號	光 漆	光 磁	光 碟	光 碟 片	光 碟 機	光 緒	
光 彈	光 標	光 潔	光 潔 度	光 潤	光 熱	光 盤	光 磊	
光 磊 科 技	光 線	光 趟	光 輝	光 輝 燦 爛	光 學	光 學 玻 璃	光 學 家	
光 導	光 機	光 澤	光 輻 射	光 頭	光 壓	光 環	光 療	
光 聯 科 技	光 臨	光 臨 惠 顧	光 鮮	光 簾	光 譜	光 譜 分 析	光 譜 圖	
光 譜 儀	光 譜 線	光 譜 學	光 寶 電 子	光 耀	光 顧	光 驅	光 聽	
光 纖	光 纖 通 信	光 靈	光 纜	兇 化	兇 手	兇 犯	兇 光	
兇 兆	兇 多 吉 少	兇 宅	兇 年	兇 年 饑 歲	兇 災	兇 狂	兇 事	
兇 狠	兇 相	兇 相 畢 露	兇 徒	兇 悍	兇 氣	兇 神	兇 神 惡 煞	
兇 殺	兇 殺 案	兇 猛	兇 終 隙 末	兇 惡	兇 殘	兇 極	兇 歲	
兇 煞	兇 暴	兇 器	兇 橫	兇 險	兆 瓦	兆 伏	兆 兆	
兆 多	兆 位	兆 周	兆 赫	兆 赫 茲	兆 赫 電 子	兆 歐	兆 頭	
先 人	先 人 後 己	先 入	先 入 之 見	先 入 為 主	先 下 手 為 強	先 亡	先 不	
先 公 後 私	先 天	先 天 不 足	先 天 性	先 天 論	先 手	先 父	先 王	
先 世	先 主	先 以	先 付	先 令	先 出	先 加	先 占	
先 母	先 民	先 生	先 生 們	先 用	先 由	先 交	先 兆	
先 同	先 向	先 吃	先 在	先 死	先 自 隗 始	先 行	先 行 官	
先 行 者	先 行 後 聞	先 佔 滿	先 佔 領	先 佔 據	先 別	先 君	先 我 著 鞭	
先 把	先 抓	先 決	先 決 條 件	先 見	先 見 之 明	先 走	先 享 受 後 付 款	
先 享 後 付	先 使	先 例	先 來	先 來 後 到	先 到	先 取	先 征	
先 於	先 明	先 河	先 知	先 知 先 覺	先 花 後 果	先 前	先 帝	
先 後	先 按	先 是	先 查	先 為	先 看	先 要	先 述 權	
先 哲	先 師	先 烈	先 祖	先 秦	先 秦 時 代	先 納	先 務 之 急	
先 得	先 斬 後 奏	先 斬 後 聞	先 富 起 來	先 提	先 期	先 發 制 人	先 給	
先 買	先 買 權	先 進	先 進 事 跡	先 進 性	先 進 個 人	先 進 集 體	先 傳	
先 傾	先 意 承 志	先 搞	先 睹 為 快	先 試	先 過	先 嘗	先 端	
先 遣	先 遣 隊	先 寫	先 憂 後 樂	先 賢	先 輩	先 銷	先 鋒	
先 鋒 隊	先 鋒 團	先 導	先 機	先 頭	先 頭 部 隊	先 聲	先 聲 後 實	
先 聲 奪 人	先 禮	先 禮 後 兵	先 軀	先 軀 者	先 難 後 獲	先 覺	先 覺 先 知	
先 覺 者	先 驅	先 驅 者	先 驅 螻 蟻	先 驗	先 驗 性	先 驗 論	先 讓	
全 人	全 人 類	全 力	全 力 以 赴	全 大 運	全 工	全 干	全 才	
全 不	全 不 知	全 中 國	全 中 國 人 民	全 中 運	全 分	全 友 建 設	全 友 電 腦	
全 反 射	全 天	全 天 候	全 尺 寸	全 心	全 心 全 意	全 文	全 方	
全 方 向	全 方 位	全 日	全 日 制	全 月	全 片	全 世 界	全 世 界 人 民	
全 功 能	全 市	全 民	全 民 公 決	全 民 企 業	全 民 性	全 民 所 有 制	全 民 皆 兵	
全 民 教 育	全 民 族	全 由	全 交	全 份	全 光	全 名	全 好	
全 宇 宙	全 州	全 年	全 托	全 有	全 臣	全 自 動	全 色	
全 行	全 局	全 局 性	全 局 觀 念	全 形	全 村	全 角	全 身	
全 身 心	全 身 遠 害	全 坤 興 業	全 始 全 終	全 所	全 知	全 社 會	全 長	
全 長 度	全 信	全 南	全 城	全 室	全 屏	全 屏 幕	全 拼	
全 是	全 為	全 省	全 看	全 科	全 美 國	全 要	全 軍	
全 軍 覆 沒	全 軍 覆 滅	全 面	全 面 性	全 面 推 廣	全 面 質 量 管 理	全 音	全 音 域	
全 音 符	全 音 階	全 食	全 值	全 凍	全 員	全 員 承 包	全 員 勞 動 生 產 率	
全 員 勞 動 合 同 制	全 套	全 家	全 家 人	全 家 福	全 島	全 席	全 息	
全 息 術	全 息 圖	全 時 間	全 書	全 校	全 班	全 留	全 神	
全 神 貫 注	全 神 傾 注	全 脂	全 能	全 能 冠 軍	全 般	全 院	全 副	
全 副 武 裝	全 區	全 國	全 國 人 民 代 表 大 會	全 國 工 業 總 會	全 國 加 油	全 國 民 間 災 後 重 建 聯 盟	全 國 各 地	
全 國 性	全 國 商 業 總 會	全 國 電 子	全 國 總 工 會	全 帶	全 清	全 球	全 球 性	
全 異	全 盛	全 盛 期	全 票	全 規 模	全 速	全 部	全 都	
全 勝	全 場	全 幅	全 景	全 港	全 無	全 無 心 肝	全 無 忌 憚	
全 無 是 處	全 然	全 然 不 同	全 然 不 知	全 然 不 顧	全 程	全 等	全 買	
全 鄉	全 間	全 隊	全 集	全 勤	全 意	全 感	全 新	
全 會	全 盟	全 路	全 運 會	全 過 程	全 境	全 奪	全 對	
全 對 數	全 滿	全 稱	全 網	全 蝕	全 貌	全 銀 幕	全 價	
全 劇	全 廠	全 數	全 盤	全 盤 托 出	全 盤 西 化	全 瞎	全 碼	
全 稿	全 範 圍	全 篇	全 線	全 線 崩 潰	全 靠	全 縣	全 衡	
全 選	全 險	全 優	全 檢	全 總	全 壘 打	全 歸	全 鎮	
全 額	全 贏	全 黨	全 黨 全 軍 全 國	全 黨 全 軍 和 全 國	全 黨 全 國	全 殲	全 權	
全 權 大 使	全 權 代 表	全 讀	全 體	全 體 成 員	全 體 會 議	共 犯	共 生	
共 用	共 用 權	共 同	共 同 一 致	共 同 市 場	共 同 性	共 同 社	共 同 海 損	
共 同 語	共 同 點	共 同 體	共 在	共 存	共 收	共 有	共 有 化	
共 床 人	共 事	共 享	共 享 者	共 和	共 和 制	共 和 國	共 和 黨	
共 妻	共 居	共 性	共 析	共 知	共 青 組 織	共 青 團	共 青 團 員	
共 勉	共 度	共 建	共 建 文 明	共 為	共 為 唇 齒	共 約	共 計	
共 軍	共 面	共 匪	共 振	共 振 板	共 振 器	共 挽 鹿 東	共 祝	
共 商	共 商 國 是	共 基 極	共 婚	共 患 難	共 敘	共 產	共 產 主 義	
共 產 主 義 者	共 產 國 際	共 產 黨	共 產 黨 人	共 產 黨 員	共 處	共 設	共 軛	
共 軛 複 數	共 通	共 創	共 棲	共 發 射 極	共 賀	共 進	共 進 早 餐	
共 飲	共 路	共 運	共 達	共 圖 大 計	共 榮	共 管	共 聚	
共 聚 反 應	共 聚 物	共 需	共 鳴	共 鳴 器	共 價	共 價 鍵	共 慶	
共 憤	共 激	共 融	共 謀	共 謀 者	共 辦	共 餐	共 濟	
共 職	共 識	共 黨	再 一	再 一 次	再 入	再 三	再 三 再 四	
再 上	再 上 演	再 也	再 也 不	再 不	再 不 是	再 不 然	再 之	
再 予	再 分	再 分 析	再 且	再 主 張	再 充 填	再 出	再 出 口	
再 出 現	再 加	再 加 入	再 加 倍	再 去	再 打	再 犯	再 生	
再 生 父 母	再 生 草	再 生 產	再 生 資 源	再 生 器	再 用	再 由	再 立 新 功	
再 交	再 交 換	再 任 命	再 同	再 向	再 回	再 多	再 好	
再 好 不 過	再 好 沒 有	再 如	再 安 頓	再 有	再 次	再 考 慮	再 行	
再 作	再 作 馮 婦	再 佈 置	再 利 用	再 吸 收	再 把	再 找	再 折 扣	
再 投 資	再 改	再 見	再 走	再 防 雨	再 供	再 來	再 到	
再 制	再 制 用	再 取	再 取 得	再 定 購	再 往 前	再 拉	再 放	
再 放 映	再 放 射	再 武 裝	再 注 滿	再 版	再 直 接	再 者	再 肯 定	
再 表 明	再 保 險	再 保 證	再 則	再 度	再 建	再 拜	再 按	
再 指 名	再 洗 禮	再 為	再 看	再 穿 上	再 穿 著	再 致 詞	再 苦 再 累	
再 要	再 借	再 拿	再 振 作	再 捕 獲	再 租 賃	再 衰 三 竭	再 起	
再 假 定	再 做	再 區 分	再 參 加	再 唱	再 問	再 婚	再 將	
再 帶	再 接 再 厲	再 接 再 勵	再 接 合	再 掃 描	再 教 育	再 啟 動	再 混	
再 混 合	再 現	再 現 部	再 統 一	再 處 理	再 被	再 訪	再 通 過	
再 造	再 造 之 恩	再 陷	再 創	再 創 造	再 就 是	再 復 甦	再 循 環	
再 提	再 提 名	再 提 供	再 植	再 植 入	再 無	再 登	再 登 上	
再 發 生	再 發 行	再 發 作	再 發 佈	再 發 展	再 發 現	再 等	再 結 合	
再 給	再 萌 發	再 評 價	再 貼 現	再 買	再 進	再 進 入	再 開	
再 開 始	再 集 合	再 傳	再 塗 上	再 填 滿	再 嫁	再 嫁 娶	再 想	
再 會	再 經	再 經 歷	再 補	再 裝 入	再 裝 配	再 裝 填	再 裝 運	
再 裝 滿	再 試	再 試 驗	再 運 行	再 過	再 實 施	再 演	再 聚 集	
再 與	再 認	再 說	再 遠	再 障	再 審	再 寫	再 熱	
再 確 認	再 談	再 調 整	再 論	再 賦 予	再 踏 上	再 導 入	再 憑	
再 燃	再 燃 起	再 燃 燒	再 膨 脹	再 輸 入	再 輸 出	再 選	再 遲	
再 錄 音	再 檢 查	再 獲	再 臨	再 講	再 點 燃	再 擴 散	再 斷 言	
再 嚴	再 繼 續	再 議	再 聽	再 讀	再 讓	冰 刀	冰 上	
冰 上 運 動	冰 山	冰 川	冰 川 帶	冰 天	冰 天 雪 地	冰 天 雪 窖	冰 心	
冰 水	冰 火 不 容	冰 片	冰 皮	冰 肌 玉 骨	冰 似	冰 冷	冰 冷 如 石	
冰 車	冰 河	冰 河 學	冰 品	冰 室	冰 封	冰 封 雪 凍	冰 柱	
冰 洋	冰 炭 不 相 容	冰 炭 同 爐	冰 凍	冰 凍 三 尺	冰 凍 食 品	冰 凍 期	冰 凌	
冰 峰	冰 島	冰 島 人	冰 庫	冰 消 瓦 解	冰 消 凍 解	冰 消 凍 釋	冰 酒	
冰 堆	冰 堆 丘	冰 崩	冰 排	冰 涼	冰 清 玉 潔	冰 清 玉 潤	冰 淇 淋	
冰 球	冰 瓶	冰 船	冰 袋	冰 雪	冰 雪 消 融	冰 雪 聰 明	冰 場	
冰 壺	冰 壺 玉 尺	冰 壺 秋 月	冰 散 瓦 解	冰 晶	冰 晶 石	冰 期	冰 棒	
冰 棍	冰 棍 兒	冰 窖	冰 塔	冰 塊	冰 解 凍 釋	冰 雹	冰 魂 雪 魄	
冰 層	冰 箱	冰 醋 酸	冰 鋒	冰 鞋	冰 激 凌	冰 燈	冰 磚	
冰 糕	冰 糖	冰 雕	冰 霜	冰 點	冰 櫃	冰 鎮	冰 釋	
冰 碴	列 入	列 土 分 茅	列 土 封 疆	列 子	列 中	列 支	列 支 敦 斯 登	
列 出	列 示	列 列	列 印	列 名	列 式	列 成	列 成 表	
列 有	列 次	列 位	列 兵	列 車	列 車 長	列 車 員	列 宗	
列 於	列 明	列 法	列 表	列 前	列 拱	列 為	列 計	
列 島	列 席	列 席 代 表	列 席 會 議	列 祖	列 記	列 陣	列 國	
列 帳	列 強	列 報	列 隊	列 項	列 傳	列 塊	列 鼎 而 食	
列 寧	列 寧 主 義	列 寬	列 數	列 線	列 舉	列 櫃	列 櫥	
刑 令	刑 吏	刑 名	刑 事	刑 事 上	刑 事 犯	刑 事 犯 罪	刑 事 犯 罪 分 子	
刑 事 局	刑 事 法	刑 事 法 庭	刑 事 偵 察	刑 事 責 任	刑 事 訴 訟 法	刑 具	刑 典	
刑 法	刑 法 學	刑 律	刑 書	刑 訊	刑 偵	刑 措 不 用	刑 部	
刑 場	刑 期	刑 罰	刑 罰 學	刑 學	刑 警	刑 警 隊	划 不 來	
划 水	划 行	划 拳	划 動	划 船	划 船 賽	划 艇	划 算	
划 槳	划 漿	刎 頸	刎 頸 之 交	刎 頸 至 交	劣 行	劣 作	劣 汰	
劣 弧	劣 者	劣 品	劣 根 性	劣 酒	劣 紳	劣 貨	劣 畫	
劣 等	劣 等 紙	劣 勢	劣 詩	劣 跡	劣 跡 昭 著	劣 種	劣 質	
劣 質 品	劣 學 生	匈 牙 利	匈 牙 利 人	匈 牙 利 語	匈 奴	匈 奴 王	匡 心 如 水	
匡 正	匡 扶	匡 門 如 市	匡 俗 濟 時	匡 時 濟 俗	匡 算	匡 濟	匡 啷	
匠 人	匠 心	匠 心 獨 具	匠 心 獨 運	匠 石 運 斤	匠 遇 作 家	印 上	印 子	
印 中	印 之	印 支	印 片	印 出	印 加	印 台	印 尼	
印 尼 幣	印 本	印 件	印 地 安 人 隊	印 字	印 字 機	印 成	印 有	
印 江	印 色	印 行	印 妥	印 把 子	印 刷	印 刷 工	印 刷 店	
印 刷 所	印 刷 物	印 刷 品	印 刷 術	印 刷 業	印 刷 電 路	印 刷 電 路 板	印 刷 廠	
印 刷 學	印 刷 機	印 刷 體	印 於	印 泥	印 油	印 版	印 花	
印 花 布	印 花 稅	印 花 廠	印 表	印 表 機	印 信	印 度	印 度 人	
印 度 尼 西 亞	印 度 兵	印 度 洋	印 度 教	印 染	印 頁	印 書	印 紙	
印 記	印 堂	印 張	印 痕	印 盒	印 第 安	印 第 安 人	印 第 安 語	
印 累 綬 若	印 章	印 畫	印 發	印 象	印 象 派	印 跡	印 像	
印 像 派	印 製	印 數	印 錯	印 戳	印 證	印 鑒	危 亡	
危 及	危 地	危 地 馬 拉	危 在 旦 夕	危 如 累 卵	危 而 不 持	危 局	危 改	
危 言	危 言 正 色	危 言 危 行	危 言 聳 聽	危 言 讜 論	危 房	危 房 改 造	危 於 累 卵	
危 城	危 急	危 殆	危 若 朝 露	危 重	危 害	危 害 性	危 境	
危 語	危 樓	危 機	危 機 四 伏	危 機 感	危 險	危 險 性	危 險 物	
危 險 物 品	危 險 品	危 險 區	危 險 期	危 舊 房	危 舊 房 屋	危 辭 聳 聽	危 難	
危 巖	吉 人	吉 人 天 相	吉 人 自 有 天 相	吉 川 雛 乃	吉 文	吉 日	吉 日 良 辰	
吉 水	吉 他	吉 它	吉 尼 斯	吉 光 片 羽	吉 兇	吉 兆	吉 合	
吉 安	吉 利	吉 林	吉 林 省	吉 祥	吉 祥 止 止	吉 祥 如 意	吉 祥 物	
吉 通	吉 普	吉 普 車	吉 普 賽	吉 期	吉 隆 坡	吉 隆 波	吉 爾 吉 斯	
吉 慶	吏 治	吏 部	同 一	同 一 性	同 一 個	同 一 時 間	同 人	
同 上	同 大	同 工	同 工 不 同 酬	同 工 同 酬	同 工 異 曲	同 中 心	同 仁	
同 仁 醫 院	同 仇	同 仇 敵 愾	同 化	同 心	同 心 同 德	同 心 合 力	同 心 並 力	
同 心 協 力	同 心 鹿 力	同 心 圓	同 心 斷 金	同 日	同 日 而 言	同 日 而 語	同 月	
同 父	同 父 母	同 世	同 付	同 代 人	同 出 一 轍	同 功 一 體	同 去	
同 台	同 母	同 犯	同 甘 共 苦	同 甘 同 苦	同 生 共 死	同 用	同 名	
同 吃	同 回	同 地	同 地 方	同 在	同 好	同 年	同 年 代	
同 年 而 語	同 收	同 有	同 次	同 此	同 江	同 舟 共 濟	同 舟 而 濟	
同 色	同 血 族	同 行	同 行 業	同 位	同 位 角	同 位 格	同 位 素	
同 住	同 住 者	同 伴	同 作	同 告	同 床	同 床 共 枕	同 床 各 夢	
同 床 異 夢	同 形	同 志	同 志 合 道	同 志 們	同 村	同 步	同 步 化	
同 步 性	同 步 增 長	同 步 衛 星	同 步 機	同 系	同 事	同 享	同 協 電 子	
同 命 運	同 姓	同 宗	同 居	同 居 人	同 居 者	同 往	同 往 常 一 樣	
同 性	同 性 愛	同 性 質	同 性 戀	同 性 戀 者	同 房	同 房 間	同 於	
同 治	同 知	同 花 順	同 門 異 戶	同 前	同 型	同 城	同 室	
同 室 者	同 室 操 戈	同 屋	同 是	同 流 合 污	同 為	同 科	同 胞	
同 音	同 音 字	同 音 詞	同 原 語	同 席	同 座	同 旁 內 角	同 時	
同 時 代	同 時 並 舉	同 時 性	同 時 期	同 時 間	同 校	同 案	同 案 犯	
同 氣 相 求	同 氣 連 枝	同 班	同 病	同 病 相 憐	同 素	同 素 體	同 級	
同 翅 類	同 唱	同 國 人	同 堂	同 宿	同 宿 舍	同 情	同 情 心	
同 情 者	同 族	同 族 體	同 條	同 條 共 貫	同 理	同 異	同 組	
同 船	同 處	同 袍 同 澤	同 喜	同 惡 相 助	同 惡 相 求	同 惡 相 救	同 惡 相 濟	
同 期	同 減	同 窗	同 等	同 等 條 件	同 等 條 件 下	同 等 對 待	同 等 學 歷	
同 著	同 賀	同 軸	同 軸 電 纜	同 鄉	同 鄉 會	同 鄉 總 會	同 量	
同 意	同 感	同 業	同 業 工 會	同 業 公 會	同 歲	同 源	同 溫 層	
同 盟	同 盟 者	同 盟 軍	同 盟 國	同 盟 會	同 義	同 義 字	同 義 詞	
同 路	同 路 人	同 跳	同 道	同 酬	同 僚	同 夥	同 構	
同 獄	同 種	同 語	同 價	同 增	同 德 同 心	同 播	同 樣	
同 樣 地 　	同 樣 是	同 樂	同 線	同 調	同 質	同 質 性	同 輩	
同 學	同 學 們	同 機	同 謀	同 謀 者	同 餐	同 檔	同 濟	
同 聲	同 聲 之 應	同 聲 附 和	同 聲 相 應	同 點	同 歸	同 歸 於 盡	同 歸 殊 途	
同 歸 殊 塗	同 額	同 類	同 類 型	同 類 相 求	同 類 產 品	同 類 項	同 黨	
同 齡	同 齡 人	同 屬	同 歡	同 體	吊 引	吊 斗	吊 台	
吊 打	吊 刑	吊 在	吊 扣	吊 死	吊 死 問 疾	吊 住	吊 孝	
吊 床	吊 車	吊 兒 郎 當	吊 味 口	吊 門	吊 架	吊 胃 口	吊 扇	
吊 索	吊 起	吊 針	吊 帶	吊 掛	吊 梯	吊 桿	吊 桶	
吊 頂	吊 椅	吊 窗	吊 著	吊 嗓	吊 艇	吊 裝	吊 鉤	
吊 閘	吊 盤	吊 線	吊 銷	吊 橋	吊 燈	吊 艙	吊 褲	
吊 褲 帶	吊 環	吊 錨 索	吊 鍊	吊 櫃	吊 繩	吊 籃	吊 鐘	
吊 鐘 花	吊 蘭	吊 襪 帶	吊 譽 沽 名	吐 了	吐 口 水	吐 火	吐 出	
吐 出 物	吐 奶	吐 血	吐 沫	吐 泡	吐 故 納 新	吐 剛 茹 柔	吐 哺 握 發	
吐 氣	吐 氣 揚 眉	吐 納	吐 唾 沫	吐 絮	吐 絲	吐 絲 自 縛	吐 訴	
吐 痰	吐 魯 番	吐 蕃	吐 穗	吐 膽 傾 心	吐 瀉	吐 藩	吐 霧	
吐 露	吐 露 真 情	吁 吁	各 人	各 人 ︾	各 人 民 團 體	各 人 自 掃 門 前 雪	各 口	
各 大 軍 區	各 不 相 同	各 不 相 謀	各 不 相 讓	各 戶	各 方	各 方 面	各 月	
各 付	各 代	各 半	各 司 其 職	各 市	各 打	各 民 主 黨 派	各 民 族	
各 企 業	各 向	各 地	各 地 方	各 地 區	各 好	各 州	各 年	
各 式	各 式 各 樣	各 有	各 有 千 秋	各 有 不 同	各 有 所 好	各 有 所 長	各 有 所 得	
各 次	各 自	各 自 為 政	各 自 為 戰	各 色	各 行	各 行 各 業	各 行 其 志	
各 行 其 事	各 行 其 是	各 行 業	各 位	各 佔	各 別	各 局	各 形	
各 批	各 抒 己 見	各 村	各 具	各 具 特 色	各 取 所 需	各 奔 前 程	各 季	
各 所	各 表	各 長	各 門	各 持 己 見	各 派	各 界	各 界 人 士	
各 省	各 省 市	各 省 市 自 治 區	各 軍 兵 種	各 軍 區	各 頁	各 個	各 個 擊 破	
各 家	各 家 各 戶	各 島	各 校	各 級	各 級 領 導	各 級 黨 委	各 般	
各 院 校	各 區	各 國	各 國 人 民	各 執 一 詞	各 執 己 見	各 執 所 見	各 得 其 宜	
各 得 其 所	各 族	各 族 人 民	各 族 群 眾	各 條	各 條 戰 線	各 異	各 組	
各 處	各 部	各 部 委	各 部 門	各 單 位	各 就	各 期	各 款	
各 款 產 品	各 答	各 隊	各 項	各 業	各 路	各 達	各 盡 其 能	
各 盡 所 能	各 種	各 種 各 樣	各 說	各 層	各 廠	各 廠 礦	各 樣	
各 縣	各 聯	各 點	各 懷	各 類	各 欄	各 顧 各	各 攤	
各 顯 神 通	向 一 邊	向 人	向 人 民 負 責	向 下	向 下 坡	向 下 看	向 下 風	
向 上	向 上 扔	向 上 拋	向 上 爬	向 上 看	向 上 游	向 上 舉	向 內	
向 內 卷	向 太 空	向 心	向 心 力	向 日	向 日 性	向 日 葵	向 火 乞 兒	
向 北 方	向 右	向 右 轉	向 外	向 外 面	向 左	向 左 轉	向 平 之 願	
向 正	向 光	向 地 性	向 她	向 此	向 西 南	向 那	向 來	
向 到	向 岸 上	向 於	向 東 方	向 東 北	向 東 行	向 東 南	向 社 會 開 放	
向 前	向 前 看	向 前 進	向 前 衝	向 南 方	向 後	向 後 面	向 後 轉	
向 背	向 風	向 哪	向 海	向 海 外	向 海 岸	向 海 面	向 側 面	
向 側 邊	向 斜	向 舷 外	向 這	向 這 裡	向 這 邊	向 野 外	向 傍 側	
向 無 此 例	向 著	向 量	向 陽	向 隅	向 隅 而 泣	向 隅 獨 泣	向 裡	
向 裡 頭	向 摟 上	向 標	向 壁 虛 造	向 縱 深 發 展	名 人	名 下	名 下 無 虛	
名 士	名 士 風 流	名 子	名 山	名 山 大 川	名 山 事 業	名 不 見 經 傳	名 不 副 實	
名 不 符 實	名 不 虛 行	名 不 虛 傳	名 分	名 手	名 片	名 片 盒	名 冊	
名 古 屋	名 叫	名 史	名 句	名 正 言 順	名 目	名 目 繁 多	名 份	
名 列	名 列 前 茅	名 列 首 位	名 列 第 一	名 列 榜 首	名 匠	名 地	名 字	
名 存 實 亡	名 曲	名 次	名 位	名 作	名 利	名 利 場	名 利 雙 收	
名 址	名 角	名 言	名 言 集	名 佳 利	名 兒	名 制	名 物	
名 狀	名 門	名 門 世 族	名 垂	名 垂 史 冊	名 垂 青 史	名 城	名 後	
名 星	名 流	名 為	名 家	名 師	名 氣	名 特 產	名 茶	
名 酒	名 高 天 下	名 高 難 副	名 副 其 實	名 堂	名 將	名 從 主 人	名 望	
名 產	名 符 其 實	名 勝	名 勝 古 跡	名 單	名 喚	名 媒 正 配	名 揚 中 外	
名 揚 四 方	名 揚 四 海	名 牌	名 牌 產 品	名 牌 貨	名 畫	名 著	名 菜	
名 裂	名 詞	名 貴	名 貴 藥 材	名 煙	名 節	名 義	名 義 上	
名 落 孫 山	名 號	名 詩	名 過 其 實	名 實	名 實 不 符	名 實 相 副	名 實 相 符	
名 實 相 稱	名 演	名 演 員	名 滿 天 下	名 稱	名 聞	名 銜	名 廚	
名 數	名 標 青 史	名 論	名 震 中 外	名 儒	名 噪 一 時	名 學	名 錄	
名 優	名 優 特 新 產 品	名 優 產 品	名 優 新	名 優 新 產 品	名 聲	名 聲 大 振	名 聲 大 噪	
名 聲 在 外	名 聲 好	名 聲 狼 藉	名 醫	名 額	名 額 有 限	名 簿	名 譽	
名 譽 好	名 譽 壞	名 譽 權	名 韁 利 索	合 一	合 二 為 一	合 力	合 十	
合 口	合 子	合 川	合 干 者	合 不 來	合 不 攏 嘴	合 化	合 片	
合 乎	合 乎 邏 輯	合 刊	合 正 科 技	合 用	合 同	合 同 工	合 同 作 戰	
合 同 制	合 同 書	合 在	合 式	合 成	合 成 皮	合 成 物	合 成 者	
合 成 染 料	合 成 革	合 成 氨	合 成 器	合 成 樹 脂	合 成 橡 膠	合 成 機	合 成 纖 維	
合 江 省	合 而 為 一	合 住	合 作	合 作 化	合 作 制	合 作 社	合 作 社 經 濟	
合 作 商 店	合 作 項 目	合 作 經 濟	合 作 運 動	合 作 醫 療	合 作 關 係	合 身	合 併	
合 併 者	合 併 症	合 取	合 宜	合 拍	合 抱	合 於	合 法	
合 法 化	合 法 收 入	合 法 利 益	合 法 性	合 法 政 府	合 法 席 位	合 法 鬥 爭	合 法 權 利	
合 法 權 益	合 物	合 肥	合 肥 市	合 股	合 花	合 金	合 金 鋼	
合 則 兩 利	合 奏	合 度	合 建	合 流	合 為	合 約	合 計	
合 訂	合 訂 本	合 面	合 音	合 頁	合 家	合 家 歡	合 庫	
合 時	合 時 宜	合 格	合 格 者	合 格 品	合 格 率	合 格 證	合 格 證 書	
合 泰	合 浦 珠 還	合 浦 還 珠	合 租	合 唱	合 唱 曲	合 唱 會	合 唱 團	
合 婚	合 得 來	合 情	合 情 合 理	合 教	合 理	合 理 化	合 理 化 建 議	
合 理 性	合 理 流 動	合 理 負 擔	合 眾	合 眾 社	合 眾 國	合 眼	合 組	
合 處	合 圍	合 掌	合 發	合 發 興 業	合 著	合 著 者	合 進	
合 勤 科 技	合 塊	合 意	合 會	合 照	合 群	合 腳	合 葬	
合 解	合 資	合 資 企 業	合 資 經 營	合 閘	合 夥	合 夥 人	合 演	
合 稱	合 算	合 影	合 影 留 念	合 數	合 編	合 線	合 論	
合 適	合 劑	合 謀	合 辦	合 龍	合 營	合 營 企 業	合 縫	
合 縫 處	合 聲	合 璧	合 轍	合 騎	合 攏	合 議	合 議 制	
合 議 庭	合 屬	合 護	合 歡	吃 一 塹	吃 一 塹 長 一 智	吃 一 驚	吃 了 一 驚	
吃 人	吃 入	吃 力	吃 力 不 討 好	吃 下	吃 上	吃 口	吃 大 戶	
吃 大 鍋 飯	吃 不 了 兜 著 走	吃 不 上	吃 不 消	吃 不 開	吃 午 飯	吃 水	吃 去	
吃 奶	吃 光	吃 吃	吃 吃 地 笑	吃 吃 喝 喝	吃 早 飯	吃 早 餐	吃 老 本	
吃 吧	吃 完	吃 快 餐	吃 到	吃 官 司	吃 東 西	吃 法	吃 者	
吃 客	吃 穿	吃 苦	吃 苦 耐 勞	吃 苦 頭	吃 重	吃 食	吃 香	
吃 笑	吃 素	吃 草	吃 起 來	吃 得	吃 得 消	吃 得 開	吃 得 過 多	
吃 掉	吃 敗 仗	吃 通	吃 透	吃 魚	吃 喝	吃 喝 玩 樂	吃 喝 風	
吃 就	吃 著 不 盡	吃 進	吃 飯	吃 葷	吃 裡 爬 外	吃 過	吃 過 量	
吃 飽	吃 飽 穿 暖	吃 飽 喝 足	吃 盡 苦 頭	吃 緊	吃 窮	吃 請	吃 請 風	
吃 醋	吃 醋 拈 酸	吃 醋 爭 風	吃 膩	吃 虧	吃 點	吃 齋	吃 糧	
吃 羹	吃 藥 人	吃 驚	后 妃	后 里 鄉	吆 五 喝 六	吆 喝	因 人	
因 人 成 事	因 人 而 異	因 人 制 宜	因 子	因 子 型	因 小 失 大	因 小 而 失 大	因 小 見 大	
因 之	因 公	因 公 行 私	因 公 假 私	因 由	因 名 額 有 限	因 地 制 宜	因 在	
因 式	因 式 分 解	因 次	因 此	因 此 當	因 而	因 何	因 利 乘 便	
因 我	因 材 施 教	因 事	因 事 制 宜	因 使	因 其	因 受	因 所	
因 於	因 果	因 果 律	因 果 報 應	因 果 關 係	因 故	因 為	因 為 種 種 原 因	
因 陋 就 簡	因 風 吹 火	因 恐	因 時	因 時 制 宜	因 病	因 素	因 情 形	
因 條 件 限 制	因 被	因 循	因 循 守 舊	因 循 坐 誤	因 勢 利 導	因 禍 為 福	因 禍 得 福	
因 噎 廢 食	因 敵 取 資	因 數	因 緣	因 樹 為 屋	因 應	因 購 買	因 難 見 巧	
因 襲	因 變 量	回 了	回 山 倒 海	回 不 來	回 內 地	回 升	回 天	
回 天 之 力	回 天 乏 術	回 心 轉 意	回 手	回 文	回 文 織 錦	回 水	回 火	
回 主 頁	回 去	回 民	回 生	回 生 起 死	回 光	回 光 反 照	回 合	
回 回	回 扣	回 收	回 收 站	回 收 率	回 老 家	回 吼	回 形 針	
回 見	回 走	回 身	回 車	回 事	回 來	回 函	回 到	
回 味	回 味 無 窮	回 帖	回 波	回 返	回 采	回 青	回 信	
回 咬	回 城	回 拜	回 春	回 柱	回 流	回 紇	回 音	
回 風	回 飛	回 首	回 首 往 事	回 首 頁	回 修	回 原	回 家	
回 師	回 挪	回 送	回 退	回 馬 槍	回 動	回 國	回 執	
回 帳	回 掃	回 教	回 教 徒	回 族	回 條	回 球	回 眸	
回 訪	回 單	回 報	回 復	回 援	回 棋	回 游	回 程	
回 答	回 答 者	回 答 說	回 絕	回 絲	回 跑	回 跌	回 郵	
回 鄉	回 鄉 務 農	回 黃 轉 綠	回 填	回 想	回 暖	回 溯	回 稟	
回 落	回 話	回 路	回 跳	回 過	回 過 頭 來	回 電	回 駁	
回 嘴	回 彈	回 撥	回 潮	回 罵	回 請	回 憶	回 憶 起	
回 憶 錄	回 頭	回 頭 是 岸	回 頭 路	回 應	回 擊	回 擊 者	回 聲	
回 鍋	回 歸	回 歸 祖 國	回 歸 線	回 禮	回 覆	回 轉	回 轉 半 徑	
回 轉 軸	回 轉 窯	回 穩	回 爐	回 顧	回 顧 展	回 籠	回 贖	
回 嗔 作 喜	回 瞅	回 饋	回 饋 金	地 力	地 下	地 下 工 程 施 工	地 下 水	
地 下 室	地 下 修 文	地 下 鬥 爭	地 下 組 織	地 下 道	地 下 黨	地 上	地 久 天 長	
地 大 物 博	地 丑 德 齊	地 中	地 中 海	地 中 海 地 區	地 心	地 心 引 力	地 支	
地 文 學	地 方	地 方 人 物	地 方 化	地 方 自 治	地 方 志	地 方 性	地 方 法 院	
地 方 軍	地 方 首 長	地 方 病	地 方 部 隊	地 方 稅	地 方 機 關	地 方 戲	地 方 戲 曲	
地 方 黨 委	地 水	地 牛	地 主	地 主 之 誼	地 主 階 級	地 市	地 平	
地 平 天 成	地 平 線	地 平 線 上	地 瓜	地 皮	地 穴	地 光	地 名	
地 名 學	地 名 錄	地 地 道 道	地 安 門	地 老 天 荒	地 老 虎	地 衣	地 位	
地 利	地 利 人 和	地 址	地 形	地 形 圖	地 形 學	地 役 權	地 步	
地 牢	地 角	地 角 天 涯	地 走	地 委	地 委 書 記	地 帛	地 拉 那	
地 板	地 波	地 物	地 狀	地 表	地 保	地 契	地 政 司	
地 政 學	地 段	地 洞	地 界	地 界 標	地 面	地 面 水	地 面 站	
地 面 衛 星 接 收 站	地 核	地 畝	地 租	地 脈	地 能	地 做	地 側	
地 動	地 動 山 搖	地 動 儀	地 區	地 區 性	地 區 差 價	地 區 開 發	地 區 經 濟	
地 域	地 域 性	地 基	地 崩 山 摧	地 帶	地 淺	地 球	地 球 上	
地 球 工 業	地 球 化 學	地 球 外	地 球 物 理	地 球 儀	地 球 體	地 理	地 理 志	
地 理 師	地 理 書	地 理 學	地 產	地 處	地 陷	地 堡	地 富 反 壞	
地 富 反 壞 右	地 殼	地 毯	地 痞	地 痞 流 氓	地 稅	地 窖	地 軸	
地 間	地 黃	地 勤	地 勤 人 員	地 勢	地 塊	地 溫	地 窟	
地 腳	地 裡	地 話	地 道	地 道 戰	地 雷	地 雷 區	地 雷 場	
地 雷 戰	地 圖	地 圖 投 影	地 圖 集	地 圖 管 理	地 對 空	地 幔	地 榜	
地 滾 球	地 獄	地 獄 般	地 磁	地 磁 氣	地 磁 儀	地 精 似	地 網 天 羅	
地 綢	地 蓋	地 誌	地 說	地 貌	地 貌 學	地 貌 變 遷	地 價	
地 價 稅	地 層	地 層 學	地 廣 人 稀	地 槽	地 熱	地 熱 發 電	地 熱 資 源	
地 熱 學	地 瘩	地 盤	地 緣 政 治	地 線	地 膜	地 膜 覆 蓋	地 質	
地 質 力 學	地 質 年 代	地 質 作 用	地 質 局	地 質 勘 探	地 質 普 查	地 質 隊	地 質 圖	
地 質 學	地 質 學 家	地 質 礦 產 部	地 震	地 震 局	地 震 波	地 震 計	地 震 帶	
地 震 預 報	地 震 儀	地 震 學	地 壇	地 學	地 磚	地 頭	地 龍	
地 壓	地 檢 署	地 氈	地 點	地 覆 天 翻	地 癟	地 礦	地 礦 局	
地 礦 部	地 籍	地 籍 圖	地 蠟	地 鐵	地 響	地 攤	地 靈	
地 靈 人 傑	地 舖	在 一 般 情 況 下	在 一 起	在 一 邊	在 人 矮 簷 下	在 下	在 下 文	
在 下 方	在 下 列	在 下 面	在 下 邊	在 上	在 上 文	在 上 面	在 上 游	
在 大 多 數 情 況 下	在 山 麓	在 工 作 上	在 工 作 中	在 不 久 的 將 來	在 元 旦	在 內	在 內 部	
在 天 之 靈	在 心	在 戶 內	在 戶 外	在 手 邊	在 日 常 工 作 中	在 日 常 生 活 中	在 水 下	
在 水 上	在 世	在 世 界 上	在 世 界 範 圍 內	在 乎	在 他 處	在 冊	在 半 途	
在 可 能 範 圍 內	在 右	在 另 一 邊	在 左 舷	在 平 日	在 必	在 打	在 本 世 紀 內	
在 本 國	在 正 常 情 況 下	在 生 活 上	在 用	在 任	在 任 何 情 況 下	在 先	在 先 前	
在 全 國 範 圍 內	在 印 刷	在 同 等 條 件 下	在 各	在 各 方 面	在 地 下	在 地 上	在 次 頁	
在 此	在 此 中	在 此 之 前	在 此 之 後	在 此 存 照	在 此 基 礎 上	在 此 期 間	在 百 忙 之 中	
在 西 南	在 位	在 何 處	在 別 處	在 劫 難 逃	在 即	在 床	在 床 上	
在 我 心 中	在 我 看 來	在 技 術 上	在 改 革 中	在 沉	在 身 邊	在 車 上	在 那 時 候	
在 那 裡	在 那 邊	在 京	在 其 中	在 到	在 制	在 官 言 官	在 底 下	
在 彼 方	在 所 不 計	在 所 不 惜	在 所 不 辭	在 所 難 免	在 拉	在 押	在 押 犯	
在 於	在 東 方	在 的	在 空 中	在 初 期	在 近 旁	在 附 近	在 前	
在 前 方	在 前 於	在 前 面	在 前 部	在 前 頭	在 城 郊	在 室 內	在 屋 裡	
在 很 大 程 度 上	在 很 短 的 時 間 內	在 後	在 後 面	在 思 想 上	在 政 治 上	在 春 季	在 某 些 方 面	
在 某 些 特 殊 情 況 下	在 某 處	在 某 種 程 度 上	在 看	在 要	在 飛	在 哪	在 哪 裡	
在 家	在 家 出 家	在 宮 中	在 座	在 旁	在 旁 邊	在 旁 觀	在 時	
在 校	在 校 生	在 校 學 生	在 案	在 海 上	在 特 定 情 況 下	在 特 殊 情 況 下	在 逃	
在 逃 犯	在 高 處	在 做	在 國 內 外	在 國 外	在 國 際 上	在 將 來	在 崗	
在 教	在 望	在 深 夜	在 理	在 第 十	在 組 織 上	在 舷 側	在 船 上	
在 船 尾	在 被	在 這 之 前	在 這 之 後	在 這 個 基 礎 上	在 這 期 間	在 這 裡	在 這 點 上	
在 通 常 情 況 下	在 逗	在 野	在 野 外	在 野 黨	在 陳 之 厄	在 最	在 場	
在 握	在 朝	在 發 言 中	在 短 期 內	在 短 短 的 幾 年 之 內	在 窗	在 等	在 給	
在 開	在 隆 冬	在 傳	在 嗎	在 意	在 想	在 新 形 勢 下	在 新 的 一 年 裡	
在 暗 中	在 會 談 中	在 業	在 當	在 經 濟 上	在 群 眾 中	在 過	在 漲	
在 與	在 說	在 遠 方	在 遠 處	在 廠	在 編	在 編 人 員	在 線 造 詞	
在 談	在 調	在 戰 前	在 歷 史 上	在 擠	在 講 話 中	在 職	在 職 人 員	
在 職 者	在 職 訓 練	在 職 幹 部	在 欄 外	在 讀	圭 亞 那	圩 田	圩 地	
夙 心 往 志	夙 世 冤 家	夙 夜 不 懈	夙 夜 在 公	夙 夜 為 媒	夙 夜 匪 懈	夙 敵	夙 興 夜 寐	
夙 願	多 □	多 一 半	多 一 事 不 如 少 一 事	多 一 事 不 如 省 一 事	多 一 倍	多 了	多 人	
多 人 會 談 室	多 人 對 策	多 上	多 久	多 口	多 大	多 子	多 山	
多 才	多 才 多 藝	多 中 心	多 元	多 元 化	多 元 論	多 分	多 天	
多 孔	多 孔 性	多 少	多 少 年	多 少 年 如 一 日	多 少 年 來	多 心	多 文 為 富	
多 方	多 方 面	多 日	多 月	多 毛	多 水	多 水 分	多 以	
多 付	多 加	多 加 小 心	多 功	多 功 能	多 半	多 可	多 台	
多 巧	多 民 族	多 汁	多 汁 液	多 瓦	多 生	多 用	多 用 戶	
多 用 途	多 石	多 交	多 任 務	多 兇 少 吉	多 列	多 向	多 名	
多 吃 多 佔	多 多	多 多 少 少	多 多 保 重	多 多 益 善	多 多 益 辦	多 好	多 如 牛 毛	
多 年	多 年 生	多 年 來	多 收	多 次	多 此 一 舉	多 米	多 米 尼 克	
多 而	多 至	多 色	多 血 性	多 行 不 義 必 自 斃	多 位 數	多 佔	多 即	
多 含	多 址	多 形	多 形 式	多 快	多 快 好 省	多 材 多 藝	多 災 多 難	
多 見	多 見 於	多 角	多 角 形	多 言	多 言 或 中	多 言 數 窮	多 言 繁 稱	
多 足	多 足 類	多 事	多 事 之 秋	多 例	多 卷	多 受	多 妻	
多 於	多 明 尼 加	多 果 實	多 沼 地	多 沼 澤	多 波 段	多 的	多 者	
多 花	多 金 屬	多 長	多 雨	多 俊	多 則	多 咱	多 姿	
多 姿 多 彩	多 思	多 指	多 洞	多 派	多 為	多 相	多 看	
多 美	多 計	多 軌	多 重	多 面	多 面 手	多 面 體	多 音	
多 音 字	多 音 節	多 頁	多 風	多 食 症	多 倍 體	多 值	多 個	
多 倫	多 倫 多	多 哥	多 家	多 峰	多 拿	多 時	多 根	
多 留	多 病	多 神	多 級	多 脂	多 脂 肪	多 財 善 賈	多 退	
多 針 刺	多 高	多 做	多 做 實 事	多 動	多 啊	多 國	多 國 公 司	
多 國 籍	多 彩	多 得	多 得 多	多 情	多 旋 律	多 條	多 產	
多 產 性	多 粒	多 細	多 處	多 許 少 與	多 部	多 雪	多 勞	
多 勞 多 得	多 報	多 媒 體	多 晶 體	多 渠 道	多 發	多 發 病	多 給	
多 詞	多 費	多 量	多 雲	多 雲 轉 陰	多 項	多 項 式	多 塞	
多 塊	多 感	多 愁	多 愁 多 病	多 愁 善 感	多 會 兒	多 極	多 歲	
多 源	多 煩	多 瑙 河	多 萬	多 節	多 義	多 義 字	多 義 性	
多 義 詞	多 解	多 話	多 路	多 路 徑	多 道	多 達	多 鉤	
多 寡	多 對	多 對 一	多 幕 劇	多 疑	多 福	多 種	多 種 子	
多 種 多 樣	多 種 形 式	多 種 經 營	多 端	多 端 寡 要	多 管	多 管 閒 事	多 算	
多 維	多 聞 而 志 之	多 聞 強 記	多 聞 闕 疑	多 蒸 汽	多 蒸 氣	多 語	多 說	
多 遠	多 酸	多 領	多 麼	多 價	多 嘴	多 嘴 多 舌	多 嘴 饒 舌	
多 寬	多 層	多 層 次	多 層 面	多 廣	多 彈 頭	多 數	多 數 人	
多 數 黨	多 樣	多 樣 化	多 樣 性	多 篇	多 調 性	多 賤 寡 貴	多 趣	
多 銷	多 餘	多 齒	多 學 科	多 樹	多 歷 年 所	多 燈	多 糖	
多 糖 症	多 糖 類	多 謀 善 斷	多 辦	多 辦 一 些 實 事	多 辦 實 事	多 錢 善 賈	多 頻	
多 頭	多 檔	多 臂 機	多 虧	多 謝	多 謝 光 臨	多 賺	多 點	
多 禮	多 藏 厚 亡	多 蟲	多 藝	多 邊	多 邊 合 作	多 邊 形	多 邊 條 約	
多 邊 貿 易	多 難	多 難 興 邦	多 霧	多 類	多 黨	多 黨 合 作 制	多 黨 制	
多 顧 慮	多 聽	多 變	多 變 化	夷 人	夷 平	夷 為 平 地	夷 險 一 節	
夸 克	夸 脫	夸 誕	妄 人	妄 下 雌 黃	妄 加	妄 加 指 責	妄 加 評 論	
妄 生 穿 鑿	妄 用	妄 自	妄 自 尊 大	妄 自 菲 薄	妄 作	妄 求	妄 求 者	
妄 言	妄 言 妄 聽	妄 取	妄 念	妄 為	妄 動	妄 評	妄 想	
妄 羨	妄 圖	妄 稱	妄 語	妄 說	妄 談 禍 福	奸 人 之 雄	奸 夫	
奸 犯	奸 臣	奸 佞	奸 邪	奸 者	奸 計	奸 匪	奸 笑	
奸 商	奸 婦	奸 細	奸 惡	奸 惡 之 徒	奸 詐	奸 雄	奸 滑	
奸 猾	奸 賊	奸 謀	奸 險	奸 黨	奸 宄	妃 子	好 一 個	
好 了	好 人	好 人 好 事	好 久	好 大 喜 功	好 干	好 不	好 不 好	
好 不 容 易	好 中	好 丹 非 素	好 分 數	好 友	好 天	好 天 氣	好 心	
好 心 人	好 心 好 意	好 心 腸	好 手	好 斗	好 日 子	好 歹	好 比	
好 主 意	好 打	好 打 聽	好 本 事	好 生	好 生 之 德	好 生 惡 殺	好 用	
好 名 聲	好 吃	好 吃 懶 做	好 在	好 多	好 多 個	好 好	好 好 先 生	
好 字	好 收 成	好 死	好 自 為 之	好 自 矜 誇	好 色	好 色 之 徒	好 色 者	
好 行 小 慧	好 位	好 似	好 吧	好 吵 架	好 呀	好 弄	好 找	
好 批 評	好 言	好 言 好 語	好 走	好 事	好 事 之 徒	好 事 天 慳	好 事 多 磨	
好 事 者	好 些	好 使	好 來	好 來 塢	好 來 塢 式	好 受	好 命	
好 奇	好 奇 心	好 姑 娘	好 孤 立	好 抱 怨	好 朋 友	好 東 西	好 爭 吵	
好 爭 論	好 玩	好 的	好 的 多	好 冒 險	好 哇	好 孩 子	好 客	
好 施	好 施 小 惠	好 施 樂 善	好 為 人 師	好 看	好 要	好 香	好 哭	
好 容 易	好 時 機	好 書	好 消 息	好 笑	好 茶	好 起 來	好 酒	
好 馬	好 高 務 遠	好 高 騖 遠	好 高 鶩 遠	好 乾 燥	好 做	好 動	好 啦	
好 啊	好 問	好 問 則 裕	好 強	好 得 多	好 得 很	好 球	好 處	
好 處 費	好 貨	好 傢 伙	好 勝	好 勝 心	好 喝	好 報	好 寒 性	
好 尋	好 幾	好 幾 次	好 幾 里	好 幾 個	好 惡	好 散	好 景	
好 景 不 長	好 棒	好 植	好 痛	好 發	好 善 惡 惡	好 善 嫉 惡	好 脾 氣	
好 萊 塢	好 評	好 詞	好 逸 惡 勞	好 開	好 閒	好 黑	好 亂	
好 嗨	好 嗎	好 意	好 意 思	好 感	好 惹	好 搞	好 新 聞	
好 極	好 極 了	好 話	好 運	好 運 氣	好 過	好 像	好 嘛	
好 夢 想	好 夢 難 成	好 夢 難 圓	好 漢	好 端 端	好 管	好 緊	好 聞	
好 聚 好 散	好 語 似 珠	好 說	好 說 歹 說	好 說 謊	好 劍	好 寫	好 樣	
好 樣 兒 的	好 模 仿	好 樂 迪	好 諛 惡 直	好 躺	好 學	好 學 不 倦	好 學 生	
好 學 深 思	好 戰	好 整 以 暇	好 謀 而 成	好 謀 善 斷	好 諷 刺	好 賴	好 辦	
好 險	好 頭	好 幫 手	好 戲	好 戲 連 台	好 聲 好 氣	好 還	好 轉	
好 壞	好 壞 不 分	好 難 過	好 議 論	好 辯	好 聽	好 讓	好 噁 心	
她 自 己	她 的	她 倆	她 們	她 們 的	如 一	如 入	如 入 無 人 之 境	
如 下	如 上	如 上 所 述	如 弓	如 不	如 不 勝 衣	如 之	如 今	
如 切 如 磋	如 日 中 天	如 日 方 中	如 日 方 升	如 月	如 水	如 火	如 火 如 荼	
如 牛 負 重	如 丘 而 止	如 以	如 兄	如 兄 如 弟	如 冬	如 出	如 出 一 口	
如 出 一 轍	如 左 右 手	如 玉	如 用	如 冰	如 同	如 在	如 有	
如 有 所 失	如 次	如 此	如 此 之	如 此 而 已	如 此 來 說	如 此 這 般	如 此 等 等	
如 此 說 來	如 死	如 何	如 何 是 好	如 你	如 君 王	如 坐 針 氈	如 坐 雲 霧	
如 芒 在 背	如 芒 刺 背	如 來	如 來 佛	如 其	如 昔	如 東	如 果	
如 果 不	如 泣 如 訴	如 法	如 法 泡 製	如 法 炮 製	如 花	如 花 如 玉	如 花 似 月	
如 花 似 玉	如 花 似 錦	如 虎 生 翼	如 虎 得 翼	如 虎 添 翼	如 虎 傅 翼	如 初	如 表	
如 雨	如 前	如 後	如 按	如 持 左 券	如 指 諸 掌	如 拾 地 芥	如 故	
如 春	如 是	如 是 說	如 洗	如 約	如 若	如 面	如 風 過 耳	
如 飛	如 香 油	如 狼 似 虎	如 狼 牧 羊	如 皋	如 真 如 幻	如 神	如 能	
如 茵	如 針 刺	如 常	如 從	如 棄 敝 屣	如 烹 小 鮮	如 荼 如 火	如 被	
如 許	如 這 般	如 魚 似 水	如 魚 得 水	如 鳥 獸 散	如 麻	如 喪 考 妣	如 廁	
如 惡 魔	如 斯	如 期	如 湯 沃 雪	如 湯 潑 雪	如 湯 澆 雪	如 湯 灌 雪	如 渴	
如 焚	如 無	如 無 其 事	如 畫	如 訴 如 泣	如 象	如 雲	如 意	
如 意 算 盤	如 解 倒 懸	如 運 諸 掌	如 遇	如 雷	如 雷 貫 耳	如 雷 灌 耳	如 電	
如 圖	如 夢	如 夢 方 醒	如 夢 如 醉	如 夢 初 醒	如 夢 初 覺	如 實	如 對	
如 歌	如 聞 其 聲 如 見 其 人	如 與	如 說	如 需	如 墜 煙 海	如 墜 煙 霧	如 墮 五 里 霧 中	
如 履 平 地	如 履 如 臨	如 履 薄 冰	如 影 隨 形	如 數	如 數 家 珍	如 箭 在 弦	如 膠 如 漆	
如 膠 似 漆	如 膠 投 漆	如 醉 方 醒	如 醉 如 狂	如 醉 如 夢	如 醉 如 癡	如 醉 初 醒	如 興 製 衣	
如 獲 至 珍	如 獲 至 寶	如 臂 使 指	如 臨 大 敵	如 臨 淵 谷	如 臨 深 谷	如 臨 深 淵	如 蹈 水 火	
如 蹈 湯 火	如 歸	如 舊	如 癡 如 狂	如 癡 如 夢	如 癡 如 醉	如 癡 似 醉	如 蟻 附 膻	
如 蠅 附 膻	如 蠅 逐 臭	如 願	如 願 以 償	如 釋 重 負	如 饑	如 饑 似 渴	如 屬	
字 元	字 句	字 正 腔 圓	字 母	字 母 表	字 字	字 字 珠 玉	字 串	
字 尾	字 形	字 形 學	字 形 檔	字 兒	字 典	字 帖	字 狀	
字 表	字 長	字 前	字 型	字 後	字 段	字 面	字 面 上	
字 音	字 首	字 庫	字 書	字 框	字 根	字 區	字 條	
字 眼	字 符	字 符 串	字 處 理	字 畫	字 詞	字 貼	字 距	
字 間	字 集	字 彙	字 斟 句 酌	字 節	字 節 數	字 義	字 義 上	
字 腳	字 號	字 裡	字 裡 行 間	字 跡	字 幕	字 語	字 數	
字 樣	字 模	字 盤	字 碼	字 稿	字 據	字 頻	字 頭	
字 謎	字 譯	字 體	字 體 盒	存 入	存 十 一 於 一 百	存 下	存 亡	
存 亡 未 卜	存 亡 絕 續	存 亡 斷 絕	存 小 異	存 心	存 戶	存 立	存 在	
存 在 主 義	存 在 論	存 有	存 有 偏 見	存 而 不 論	存 完	存 折	存 身	
存 車	存 車 場	存 卷	存 取	存 取 時 間	存 底	存 放	存 放 處	
存 於	存 物	存 查	存 活	存 活 率	存 為	存 案	存 根	
存 留	存 記	存 託 憑 證	存 區	存 執	存 異	存 處	存 貨	
存 單	存 期	存 款	存 款 人	存 款 額	存 款 簿	存 詞	存 貯	
存 貯 器	存 貸	存 量	存 照	存 疑	存 管	存 樣	存 盤	
存 據	存 積	存 錢	存 儲	存 儲 容 量	存 儲 處	存 儲 棧	存 儲 器	
存 檔	存 糧	存 證	存 欄	存 欄 數	存 體	宇 宙	宇 宙 火 箭	
宇 宙 性	宇 宙 空 間	宇 宙 飛 船	宇 宙 射 線	宇 宙 線	宇 宙 論	宇 宙 學	宇 宙 學 家	
宇 宙 觀	宇 航	宇 航 員	宇 航 站	宇 航 學	守 口 如 瓶	守 己	守 方	
守 正 不 回	守 正 不 阿	守 正 不 移	守 正 不 撓	守 份	守 地	守 成	守 托 者	
守 死 善 道	守 住	守 住 陣	守 孝	守 身 如 玉	守 身 若 玉	守 車	守 夜	
守 夜 者	守 法	守 法 者	守 門	守 門 員	守 信	守 信 用	守 侯	
守 則	守 城	守 恆	守 紀	守 紀 律	守 約	守 約 施 博	守 貞	
守 軍	守 候	守 候 室	守 原 則	守 時	守 株 待 兔	守 缺	守 財 奴	
守 將	守 望	守 望 犬	守 望 相 助	守 球 門	守 規 矩	守 備	守 備 部 隊	
守 備 隊	守 喪	守 著	守 勢	守 業	守 歲	守 節	守 節 不 回	
守 節 不 移	守 經 達 權	守 道 安 貧	守 寡	守 誓	守 敵	守 衛	守 衛 者	
守 靜	守 齋	守 獵	守 舊	守 舊 者	守 舊 派	守 護	守 護 神	
守 靈	宅 子	宅 心 忠 厚	宅 地	宅 邸	宅 門	宅 急 便	宅 院	
宅 區	宅 基	宅 基 地	宅 第	安 下	安 下 心 來	安 上	安 土 重 遷	
安 土 樂 業	安 大 略	安 不 忘 危	安 之	安 之 若 命	安 之 若 素	安 仁	安 分	
安 分 守 己	安 心	安 心 工 作	安 丘	安 卡 拉	安 可	安 平	安 民	
安 民 告 示	安 生	安 立 奎	安 份	安 份 守 己	安 全	安 全 生 產	安 全 年	
安 全 別 針	安 全 局	安 全 系 數	安 全 性	安 全 保 密	安 全 科	安 全 員	安 全 島	
安 全 區	安 全 帶	安 全 措 施	安 全 第 一	安 全 部	安 全 帽	安 全 感	安 全 裝 置	
安 全 閥	安 全 檢 查	安 危	安 危 冷 暖	安 多	安 好	安 如 泰 山	安 如 磐 石	
安 宅 正 路	安 安 心 心	安 安 定 定	安 安 靜 靜	安 安 穩 穩	安 老 懷 少	安 坐	安 坐 待 斃	
安 妥	安 步	安 步 當 車	安 身	安 身 之 地	安 身 立 命	安 邦	安 邦 定 國	
安 邦 治 國	安 享	安 奈 班 寧	安 妮	安 定	安 定 團 結	安 居	安 居 樂 業	
安 放	安 於	安 於 一 隅	安 於 現 狀	安 枕	安 枕 而 臥	安 東 尼 歐 班 德 拉 斯	安 臥	
安 非 他 命	安 度	安 度 晚 年	安 若 泰 山	安 哥 拉	安 娜	安 家	安 家 立 業	
安 家 費	安 家 落 戶	安 家 樂 業	安 息	安 泰	安 泰 人 壽	安 泰 投 顧	安 泰 保 險	
安 泰 銀 行	安 眠	安 眠 藥	安 神	安 能	安 曼	安 國	安 堵 如 故	
安 堵 樂 業	安 培	安 培 計	安 常 處 順	安 常 履 順	安 康	安 排	安 排 時 間	
安 理 會	安 祥	安 設	安 貧 守 道	安 貧 樂 苦	安 貧 樂 道	安 貧 樂 賤	安 富 恤 貧	
安 富 恤 窮	安 富 尊 榮	安 插	安 然	安 然 無 事	安 然 無 恙	安 琪 兒	安 逸	
安 鄉	安 閒	安 閒 自 在	安 陽	安 塞	安 歇	安 置	安 葬	
安 裝	安 裝 工 程	安 詳	安 道 爾 共 和 國	安 達	安 達 信 顧 問 公 司	安 頓	安 圖	
安 寧	安 睡	安 遠	安 魂	安 德 烈	安 慶	安 慰	安 慰 性	
安 慰 賽	安 撫	安 樂	安 樂 窩	安 適	安 適 如 常	安 養	安 養 院	
安 澤	安 親 班	安 靜	安 龍	安 徽	安 徽 省	安 營	安 營 下 寨	
安 營 紮 寨	安 謐	安 穩	安 靈	安 瓿	寺 內	寺 院	寺 院 中	
寺 塔	寺 廟	尖 刀	尖 子	尖 山	尖 山 埤 水 庫	尖 扎	尖 牙	
尖 叫	尖 叫 聲	尖 石 鄉	尖 尖	尖 兵	尖 利	尖 形	尖 沙 咀	
尖 角	尖 刻	尖 刺	尖 拱	尖 美 建 設	尖 音	尖 峰	尖 釘	
尖 梢	尖 細	尖 頂	尖 頂 窗	尖 喊	尖 椒	尖 筆	尖 嗓	
尖 塔	尖 塔 狀	尖 端	尖 端 細	尖 酸	尖 酸 刻 薄	尖 鼻 子	尖 劈	
尖 嘴	尖 嘴 猴 腮	尖 嘴 薄 舌	尖 嘯	尖 樁	尖 銳	尖 銳 化	尖 銳 聲	
尖 齒	尖 頭	尖 聲	尖 瓣	屹 立	屹 然	州 內	州 市	
州 立	州 名	州 官	州 官 放 火	州 長	州 郡	州 裡	州 際	
州 縣	州 轄	州 議 會	帆 布	帆 船	并 日 而 食	年 力	年 下	
年 久 失 修	年 中	年 內	年 少	年 少 氣 盛	年 月	年 以 下	年 代	
年 代 初	年 代 學	年 兄	年 刊	年 史	年 市	年 平 均	年 平 均 增 長 率	
年 幼	年 幼 者	年 末	年 生	年 生 產 能 力	年 休	年 份	年 光	
年 年	年 年 如 此	年 年 有 餘	年 成	年 收 入	年 次	年 老	年 老 多 病	
年 老 體 弱	年 利	年 利 潤	年 均	年 尾	年 事	年 事 已 高	年 來	
年 夜	年 庚	年 底	年 初	年 表	年 近 半 百	年 近 古 稀	年 近 花 甲	
年 金	年 長	年 青	年 青 人	年 前	年 度	年 度 計 劃	年 度 報 告	
年 後	年 秋 天	年 紀	年 限	年 首	年 值	年 唔	年 宵	
年 息	年 根	年 神 獸 散	年 級	年 級 間	年 衰	年 高	年 高 德 邵	
年 高 德 劭	年 假	年 淺	年 深 日 久	年 深 月 久	年 率	年 產	年 產 值	
年 產 能 力	年 產 量	年 祭	年 終	年 終 分 配	年 終 評 比	年 終 獎	年 終 總 結	
年 貨	年 報	年 富 力 強	年 復 一 年	年 景	年 畫	年 稅	年 華	
年 間	年 飯	年 僅	年 會	年 歲	年 節	年 號	年 資	
年 過 半 百	年 過 古 稀	年 過 花 甲	年 逾	年 逾 古 稀	年 壽	年 滿	年 貌	
年 輕	年 輕 一 代	年 輕 人	年 輕 力 壯	年 輕 化	年 輕 有 為	年 輕 幹 部	年 增 長 率	
年 審	年 數	年 輩	年 輪	年 歷	年 糕	年 興 紡 織	年 頭	
年 頭 兒	年 總 產	年 薪	年 邁	年 邁 體 弱	年 禮	年 繳	年 譜	
年 關	年 齡	年 齡 特 徵	年 鑒	式 子	式 樣	弛 張	弛 張 性	
弛 禁	弛 緩	弛 懈	忙 人	忙 不 過 來	忙 中	忙 中 添 亂	忙 忙	
忙 忙 碌 碌	忙 於	忙 的	忙 者	忙 活	忙 個 不 停	忙 動	忙 問	
忙 將	忙 得	忙 得 不 可 開 交	忙 得 不 亦 樂 乎	忙 著	忙 亂	忙 碌	忙 碌 著	
忙 裡 偷 閒	忙 說	忖 量	戎 馬	戎 馬 一 生	戎 馬 生 郊	戎 馬 生 涯	戎 馬 倥 傯	
戎 裝	戌 時	戍 邊	成 一 家 言	成 了	成 人	成 人 不 自 在	成 人 之 美	
成 人 教 育	成 人 期	成 也 蕭 何 敗 也 蕭 何	成 千	成 千 上 萬	成 千 成 萬	成 千 累 萬	成 千 論 萬	
成 山	成 才	成 才 之 路	成 仁	成 仁 取 義	成 分	成 匹	成 反 比	
成 天	成 心	成 文	成 文 法	成 文 造 句	成 方	成 日	成 比 例	
成 仙	成 功	成 功 之 路	成 功 之 道	成 功 者	成 功 率	成 包	成 打	
成 本	成 本 上 升	成 本 計 算	成 本 核 算	成 正 比	成 立	成 交	成 交 量	
成 交 額	成 份	成 全	成 列	成 名	成 名 成 家	成 因	成 年	
成 年 人	成 年 組	成 年 累 月	成 百 上 千	成 竹 在 胸	成 舟	成 色	成 行	
成 衣	成 串	成 佛	成 妖 作 怪	成 形	成 批	成 批 生 產	成 材	
成 災	成 見	成 事	成 事 不 足	成 事 不 足 敗 事 有 餘	成 事 不 說	成 例	成 卷	
成 命	成 性	成 果	成 果 獎	成 果 鑒 定	成 林	成 武	成 表	
成 長	成 長 中	成 俗	成 則 為 王 敗 則 為 寇	成 則 為 王 敗 則 為 虜	成 則 為 王 敗 則 為 賊	成 品	成 品 率	
成 品 機	成 型	成 段	成 活	成 活 率	成 為	成 為 必 要	成 約	
成 風	成 倍	成 倍 增 長	成 員	成 員 國	成 套	成 套 設 備	成 家	
成 家 立 計	成 家 立 業	成 效	成 效 顯 著	成 氣 侯	成 氣 候	成 真	成 問 題	
成 堆	成 婚	成 排	成 敗	成 敗 在 此 一 舉	成 敗 利 鈍	成 敗 得 失	成 敗 論 人	
成 敗 興 廢	成 規	成 都	成 都 市	成 章	成 單	成 單 數	成 就	
成 就 感	成 棒	成 塊	成 群	成 群 作 隊	成 群 結 伙	成 群 結 隊	成 群 結 黨	
成 像	成 對	成 精 作 怪	成 語	成 說	成 鳳	成 數	成 熟	
成 熟 期	成 蔭	成 器	成 親	成 霖 企 業	成 龍	成 龍 配 套	成 穗 率	
成 績	成 績 冊	成 績 單	成 績 斐 然	成 癖	成 禮	成 蟲	成 雙	
成 雙 作 對	成 藥	成 礦	成 議	成 癮	成 體	扣 人	扣 人 心 弦	
扣 下	扣 上	扣 子	扣 心 泣 血	扣 手	扣 出	扣 去	扣 交	
扣 件	扣 在	扣 好	扣 扣	扣 住	扣 作	扣 牢	扣 兒	
扣 到	扣 押	扣 押 人	扣 押 者	扣 留	扣 針	扣 除	扣 除 額	
扣 動	扣 得	扣 掉	扣 殺	扣 球	扣 眼	扣 貨	扣 帽 子	
扣 款	扣 減	扣 發	扣 稅	扣 著	扣 緊	扣 緊 物	扣 鞋	
扣 頭	扣 壓	扣 環	扣 鍊	扣 鎖	扣 題	扣 繳	扣 籃	
扛 扛	扛 活	扛 著	扛 鼎 拔 山	托 人	托 付	托 出	托 幼	
托 瓦 茲	托 生	托 交	托 收	托 收 承 付	托 庇	托 足 無 門	托 兒	
托 兒 所	托 孤	托 孤 寄 命	托 拉 斯	托 板	托 物	托 物 寓 興	托 故	
托 架	托 派	托 洛 茨 基	托 病	托 情	托 梁	托 缽	托 缽 僧	
托 媒	托 期	托 給	托 著	托 詞	托 運	托 夢	托 槍	
托 爾 斯 泰	托 福	托 稱	托 管	托 說	托 熟	托 盤	托 銷	
托 鞋	托 辦	托 辭	收 入	收 入 水 平	收 力	收 下	收 口	
收 工	收 之 桑 榆	收 心	收 支	收 支 平 衡	收 文	收 方	收 付	
收 市	收 生	收 用	收 伏	收 件	收 件 人	收 件 箱	收 回	
收 回 成 命	收 好	收 存	收 存 入	收 成	收 兵	收 妥	收 完	
收 尾	收 束	收 走	收 足	收 迄	收 來	收 到	收 取	
收 受	收 受 者	收 受 賄 賂	收 押	收 放	收 治	收 信	收 信 人	
收 信 機	收 屍	收 拾	收 看	收 秋	收 約	收 音	收 音 機	
收 容	收 容 力	收 容 所	收 容 審 查	收 差	收 效	收 效 甚 微	收 留	
收 益	收 益 分 配	收 益 多	收 益 率	收 租	收 納	收 訖	收 起	
收 執	收 帳	收 悉	收 掉	收 條	收 清	收 票 人	收 貨	
收 貨 人	收 割	收 割 者	收 割 機	收 場	收 報 機	收 復	收 款	
收 款 人	收 款 員	收 款 機	收 發	收 發 室	收 發 器	收 稅	收 稅 人	
收 稅 官	收 稅 員	收 視	收 視 反 聽	收 視 率	收 視 機	收 費	收 費 站	
收 買	收 買 人	收 進	收 集	收 集 成	收 集 者	收 債	收 煞	
收 當 人	收 話	收 賄	收 監	收 緊	收 銀 員	收 銀 機	收 齊	
收 審	收 盤	收 編	收 賬	收 養	收 據	收 錢	收 錄	
收 錄 機	收 斂	收 斂 性	收 斂 劑	收 殮	收 縮	收 縮 了	收 縮 肌	
收 縮 性	收 購	收 購 站	收 購 量	收 購 價	收 購 價 格	收 購 額	收 歸 國 有	
收 禮	收 藏	收 藏 品	收 藏 家	收 轉	收 攏	收 穫	收 穫 物	
收 穫 期	收 羅	收 繳	收 贓 者	收 攤	收 權	收 聽	收 聽 者	
收 攬	早 一 點	早 了	早 上	早 上 睡	早 己	早 已	早 已 有 之	
早 中 晚	早 日	早 出 晚 歸	早 去 早 回	早 市	早 先	早 在	早 安	
早 安 少 女 組	早 年	早 成	早 早	早 有	早 死	早 育	早 車	
早 些	早 些 年	早 些 時 候	早 來	早 來 晚 走	早 到	早 於	早 版	
早 的	早 知	早 知 今 日 何 必 當 初	早 知 今 日 悔 不 當 初	早 春	早 洩	早 秋	早 班	
早 茶	早 衰	早 起	早 起 早 睡	早 退	早 婚	早 晚	早 晨	
早 產	早 產 兒	早 產 兒 基 金 會	早 逝	早 場	早 報	早 就	早 期	
早 期 教 育	早 間	早 飯	早 歲	早 該	早 睡	早 睡 早 起	早 熟	
早 稻	早 課	早 操	早 餐	早 餐 店	早 謝	早 霜	早 點	
早 點 火	早 點 名	早 戀	旨 在	旨 酒 嘉 餚	旨 意	旨 趣	旬 日	
旬 刊	旬 末	旬 報	旬 節	旭 日	旭 日 東 升	旭 日 初 升	旭 龍	
旭 龍 精 密	旭 麗 電 子	曲 子	曲 尺	曲 水	曲 水 流 觴	曲 交	曲 光	
曲 式	曲 曲 折 折	曲 曲 彎 彎	曲 折	曲 折 處	曲 角	曲 卷	曲 松	
曲 直	曲 阜	曲 品	曲 度	曲 柄	曲 柳	曲 突	曲 突 徙 薪	
曲 面	曲 風	曲 香	曲 徑	曲 徑 通 幽	曲 酒	曲 針	曲 高	
曲 高 和 寡	曲 張	曲 率	曲 笛	曲 終	曲 終 奏 雅	曲 棍	曲 棍 球	
曲 牌	曲 菌	曲 軸	曲 意	曲 意 逢 迎	曲 號	曲 裡 拐 彎	曲 解	
曲 靖	曲 盡	曲 盡 人 情	曲 盡 其 妙	曲 種	曲 線	曲 線 美	曲 線 球	
曲 線 圖	曲 膝	曲 膝 者	曲 調	曲 霉	曲 學 阿 世	曲 頸 瓶	曲 繞	
曲 藝	曲 譜	曳 引	曳 引 機	曳 用	曳 光	曳 光 彈	曳 尾 泥 塗	
曳 尾 塗 中	曳 步	曳 影	曳 裾 王 門	有 一 分 熱 發 一 分 光	有 一 天	有 一 個	有 一 套	
有 一 無 二	有 了	有 人	有 人 形	有 人 性	有 人 問	有 人 情	有 人 緣	
有 八 面	有 力	有 力 措 施	有 力 量	有 三 指	有 三 面	有 三 種	有 三 齒	
有 三 邊	有 口	有 口 皆 碑	有 口 無 心	有 口 無 行	有 口 難 分	有 口 難 言	有 口 難 辯	
有 女 懷 春	有 小	有 小 面	有 小 節	有 才	有 才 能	有 才 無 命	有 才 華	
有 才 幹	有 之	有 之 而 無 不 及	有 五 指	有 仇	有 分	有 反 應	有 天	
有 天 分	有 天 份	有 天 沒 日	有 天 無 日	有 天 賦	有 孔	有 孔 蟲	有 心	
有 心 人	有 心 無 力	有 手	有 手 段	有 文 化	有 方	有 方 法	有 木 柵	
有 木 紋	有 欠	有 毛	有 毛 病	有 水	有 火	有 主	有 代	
有 令 不 行	有 令 即 行	有 出 息	有 加 無 已	有 加 無 減	有 功	有 功 人 員	有 功 之 臣	
有 功 功 率	有 功 用	有 功 績	有 可	有 可 能	有 史 以 來	有 句	有 外 遇	
有 失	有 失 身 份	有 打	有 本 質 區 別	有 犯 無 隱	有 生	有 生 力 量	有 生 之 年	
有 生 以 來	有 生 命	有 生 氣	有 用	有 用 功	有 用 性	有 由	有 皮 層	
有 目 共 見	有 目 共 睹	有 目 共 賞	有 目 如 盲	有 目 的	有 份	有 份 量	有 企 圖	
有 光	有 光 澤	有 先	有 先 例	有 全 權	有 危 險	有 同	有 向	
有 名	有 名 氣	有 名 無 實	有 名 稱	有 地 位	有 多	有 多 層	有 好	
有 如	有 成	有 成 就	有 成 績	有 收 穫	有 此	有 死 無 二	有 污 點	
有 自	有 自 信	有 色	有 色 人 種	有 色 金 屬	有 血 有 肉	有 行	有 行 無 市	
有 何	有 何 特 長	有 你	有 別	有 別 於	有 利	有 利 可 圖	有 利 有 弊	
有 利 於	有 利 時 機	有 利 益	有 利 條 件	有 助	有 助 於	有 否	有 含 意	
有 含 蓄	有 希 望	有 序	有 形	有 形 資 本	有 形 資 產	有 志	有 志 不 在 年 高	
有 志 之 士	有 志 之 者 事 竟 成	有 志 於	有 志 於 此	有 志 者 事 竟 成	有 志 氣	有 志 竟 成	有 志 難 酬	
有 戒 心	有 技 能	有 把	有 把 握	有 折 痕	有 抑 揚	有 改	有 求	
有 求 必 應	有 求 於	有 求 於 人	有 求 斯 應	有 決 心	有 沒 有	有 系 統	有 良 心	
有 見 識	有 角	有 言	有 言 在 先	有 事	有 些	有 些 新	有 來	
有 來 歷	有 兩	有 兩 下 子	有 兩 手	有 兩 耳	有 兩 面	有 兩 頭	有 其	
有 其 名 而 無 其 實	有 典 有 則	有 刺	有 味	有 味 道	有 始 有 卒	有 始 有 終	有 始 無 終	
有 定 論	有 屈 無 伸	有 居 民	有 幸	有 底	有 往	有 征 無 戰	有 性	
有 房 間	有 所	有 所 不 同	有 所 改 善	有 所 前 進	有 所 突 破	有 所 致 力	有 所 區 別	
有 所 創 造	有 所 提 高	有 所 發 展	有 所 準 備	有 所 增 加	有 抵 抗	有 枝 有 葉	有 枝 添 葉	
有 板 有 眼	有 波 紋	有 法	有 法 不 依	有 法 可 依	有 法 必 依	有 治	有 爭 議	
有 物	有 的	有 的 放 矢	有 的 是	有 知	有 知 識	有 知 覺	有 空	
有 者	有 花 邊	有 門	有 附 文	有 雨	有 亭 子	有 信	有 信 心	
有 信 仰	有 保 留	有 前	有 前 途	有 則	有 則 改 之 無 則 加 勉	有 勇 有 謀	有 勇 氣	
有 勇 無 謀	有 勁	有 品 味	有 品 格	有 品 德	有 威 信	有 威 嚴	有 客	
有 度	有 待	有 待 於	有 後 跟	有 思	有 恃	有 恃 無 恐	有 指	
有 指 望	有 染	有 柄	有 柄 杯	有 毒	有 毒 性	有 洞	有 活	
有 活 力	有 為	有 界 限	有 界 線	有 突 起	有 紀 律	有 約	有 約 在 先	
有 耐 心	有 耐 性	有 苦	有 苦 味	有 苦 說 不 出	有 苦 難 言	有 若	有 計 劃	
有 負 於	有 負 債	有 負 載	有 軌	有 限	有 限 公 司	有 限 制	有 風	
有 風 味	有 風 趣	有 香 味	有 倦 容	有 俸	有 個	有 修 養	有 害	
有 害 於	有 害 物	有 害 物 質	有 害 無 利	有 家	有 家 難 奔	有 展 性	有 差	
有 差 錯	有 座	有 弱 點	有 效	有 效 力	有 效 功 率	有 效 地	有 效 性	
有 效 果	有 效 值	有 效 率	有 效 期	有 效 氯	有 效 數	有 效 數 字	有 效 驗	
有 時	有 時 侯	有 時 候	有 案	有 案 可 查	有 根 有 據	有 根 據	有 格 式	
有 氣	有 氣 孔	有 氣 沒 力	有 氣 味	有 氣 無 力	有 氧 運 動	有 消 息 說	有 浮 雕	
有 特 色	有 特 權	有 病	有 病 痛	有 病 變	有 益	有 益 於	有 益 無 害	
有 神	有 神 論	有 秩 序	有 笑	有 粉 刺	有 缺	有 缺 陷	有 缺 點	
有 翅 難 飛	有 脈 紋	有 能	有 能 力	有 記 號	有 財 產	有 貢 獻	有 起 色	
有 迴 響	有 酒 意	有 酒 窩	有 鬼	有 假	有 偶	有 偏 見	有 區 別	
有 問 題	有 國 難 投	有 帶	有 帶 扣	有 張 有 弛	有 得	有 接 縫	有 救	
有 教 益	有 教 無 類	有 教 養	有 啟 發	有 旋 律	有 望	有 條	有 條 不 紊	
有 條 件	有 條 有 理	有 條 紋	有 條 理	有 欲	有 淚	有 理	有 理 方 程	
有 理 由	有 理 式	有 理 有 據	有 理 性	有 理 無 情	有 理 想	有 理 解	有 理 數	
有 產 品	有 異	有 眼	有 眼 力	有 眼 不 識 泰 山	有 眼 如 盲	有 眼 無 珠	有 票	
有 粒	有 細 粒	有 組 織	有 被	有 袖 子	有 規 則	有 規 律	有 責	
有 責 任	有 野 心	有 陰 影	有 章 可 循	有 頂	有 頂 飾	有 備	有 備 無 患	
有 創 見	有 勞	有 勞 有 逸	有 喜	有 圍 牆	有 報 酬	有 復	有 惡 臭	
有 惡 意	有 斑 紋	有 斑 痕	有 斑 點	有 智 力	有 智 慧	有 智 慮	有 智 謀	
有 期	有 期 限	有 期 徒 刑	有 朝	有 朝 一 日	有 朝 氣	有 殼	有 渣 滓	
有 滋 有 味	有 滋 味	有 無	有 無 必 要	有 窗	有 等 級	有 策 略	有 筆	
有 結 節	有 絲 分 裂	有 腔	有 著	有 裂 痕	有 裂 縫	有 進 無 退	有 間	
有 陽 台	有 雄 心	有 雲	有 項	有 傷	有 傷 風 化	有 傻 勁	有 勢	
有 勢 力	有 塑 性	有 嫌 疑	有 微 風	有 意	有 意 思	有 意 無 意	有 意 義	
有 意 圖	有 意 識	有 感	有 感 而 發	有 感 於	有 愁 容	有 損	有 損 於	
有 損 無 益	有 極	有 準 備	有 睫 毛	有 禁 不 止	有 節 有 度	有 節 制	有 經 驗	
有 罪	有 罪 性	有 罪 者	有 罪 過 失	有 義 務	有 腳	有 腳 書 櫥	有 腳 陽 春	
有 解	有 詩	有 詩 才	有 詩 意	有 話	有 話 好 說	有 話 要 說	有 話 慢 慢 講	
有 資 格	有 道	有 道 具	有 道 是	有 道 理	有 道 德	有 過	有 過 失	
有 零	有 預 兆	有 實 質	有 弊 有 利	有 槍 眼	有 歉 意	有 漏 洞	有 疑 問	
有 疑 義	有 磁 力	有 福	有 福 同 享 有 禍 同 當	有 福 相	有 精 神	有 聞 必 錄	有 蓋	
有 說	有 說 有 笑	有 遠 而 近	有 遠 見	有 遠 慮	有 酸 味	有 隙 可 乘	有 價 值	
有 劇 毒	有 嘴 無 心	有 增 無 減	有 增 無 損	有 寫	有 彈 性	有 影	有 影 響	
有 敵 意	有 數	有 樣	有 標 號	有 獎	有 獎 徵 文	有 獎 銷 售	有 皺 紋	
有 緣	有 緣 無 份	有 線	有 線 電 視	有 線 廣 播	有 蔭 影	有 請	有 調	
有 趣	有 趣 味	有 輛	有 輪 子	有 銷 路	有 靠	有 餘	有 魅 力	
有 魄 力	有 齒 輪	有 噪 聲	有 學	有 學 位	有 學 問	有 憑 有 據	有 據	
有 機	有 機 化	有 機 化 學	有 機 可 乘	有 機 合 成	有 機 性	有 機 物	有 機 肥 料	
有 機 玻 璃	有 機 質	有 機 體	有 濃 味	有 興 趣	有 謂	有 賴	有 賴 於	
有 輻	有 選 擇	有 鋸 口	有 錯	有 錯 必 糾	有 錯 就 改	有 錯 誤	有 錢	
有 錢 人	有 錢 有 勢	有 錢 能 使 鬼 推 磨	有 頭 有 尾	有 頭 有 腦	有 頭 有 臉	有 頭 無 尾	有 頭 腦	
有 頭 蓋	有 頭 銜	有 償	有 償 使 用	有 償 服 務	有 償 轉 讓	有 幫 助	有 濕 氣	
有 營 養	有 療 效	有 縫	有 翼	有 聲	有 聲 有 色	有 聲 望	有 膽	
有 膽 有 識	有 薪 水	有 虧	有 黏 性	有 點	有 點 小	有 點 冷	有 點 兒	
有 點 甜	有 點 軟	有 點 舊	有 點 鹹	有 禮	有 禮 貌	有 織 紋	有 織 邊	
有 職 有 權	有 職 無 權	有 舊	有 雜 質	有 顏 色	有 鬃 毛	有 礙	有 藥 性	
有 藥 效	有 識	有 識 之 士	有 邊	有 邊 緣	有 關	有 關 方 面	有 關 係	
有 關 政 策	有 關 問 題	有 關 規 定	有 關 部 門	有 關 單 位	有 關 當 局	有 難 同 當	有 霧	
有 鬍 子	有 癥 狀	有 覺 悟	有 護	有 魔 力	有 魔 術	有 權	有 權 力	
有 權 有 勢	有 權 利	有 權 威	有 癮	有 癮 者	有 鑒	有 鑒 於 此	有 變 化	
有 靈	有 靈 魂	有 鹽 味	有 啥	有 粘 性	朽 木	朽 木 不 雕	朽 木 之 才	
朽 木 死 灰	朽 木 糞 土	朽 木 糞 牆	朽 株 枯 木	朽 棘 不 雕	朽 爛	朴 子 市	朴 贊 浩	
朱 口 皓 齒	朱 色	朱 衣 點 頭	朱 衣 點 額	朱 邦 造	朱 延 平	朱 弦 玉 磐	朱 弦 疏 越	
朱 門	朱 門 繡 戶	朱 紅	朱 紅 色	朱 唇 粉 面	朱 唇 皓 齒	朱 唇 榴 齒	朱 雀	
朱 惠 良	朱 紫 難 別	朱 順 一	朱 漆	朱 銘 美 術 館	朱 閣 青 樓	朱 衛 茵	朱 輪 華 轂	
朱 熹	朱 甍 碧 瓦	朱 鎔 基	朱 顏	朱 顏 粉 面	朱 顏 鶴 發	朱 麗 葉	朱 鷺	
朵 朵	朵 兒	朵 頤 大 嚼	次 下 標	次 大 陸	次 女	次 子	次 之	
次 元	次 內	次 方	次 日	次 月	次 布	次 生	次 生 林	
次 目 標	次 好	次 年	次 次	次 位	次 序	次 佳	次 性	
次 於	次 長	次 品	次 要	次 革	次 音 速	次 頁	次 料	
次 氧	次 級	次 級 品	次 級 線 圈	次 第	次 貨	次 氯 酸	次 等	
次 源 正 本	次 語	次 數	次 冪	次 聲 武 器	此 一 時 彼 一 時	此 人	此 中	
此 之 外	此 世	此 可 忍 孰 不 可 忍	此 可 忍 孰 不 可 容	此 外	此 正	此 生	此 由	
此 件	此 列	此 地	此 地 無 銀 三 百 兩	此 地 無 銀 存 而 不 論	此 次	此 而	此 行	
此 君	此 事	此 事 體 大	此 例	此 刻	此 岸	此 法	此 版	
此 表	此 前	此 後	此 派	此 為	此 致	此 時	此 時 此 刻	
此 書	此 案	此 起 彼 伏	此 起 彼 落	此 唱 彼 和	此 問 彼 難	此 情	此 情 此 景	
此 條	此 處	此 復	此 期 間	此 款	此 畫	此 番	此 發 彼 應	
此 稅	此 等	此 間	此 間 人 士	此 項	此 路	此 路 不 通	此 種	
此 際	此 輩	此 聯	此 舉	此 點	此 類	此 屬	此 欄	
死 一 般	死 了	死 人	死 人 般	死 力	死 也 瞑 目	死 乞 白 賴	死 亡	
死 亡 率	死 亡 無 日	死 亡 證	死 不	死 不 死 活 不 活	死 不 足 惜	死 不 旋 踵	死 不 閉 目	
死 不 瞑 目	死 中 求 生	死 心	死 心 眼	死 心 眼 兒	死 心 塌 地	死 心 搭 地	死 心 踏 地	
死 日 生 年	死 水	死 火	死 且 不 朽	死 去	死 去 活 來	死 囚	死 生 未 卜	
死 生 存 亡	死 生 有 命 富 貴 在 天	死 生 契 闊	死 生 活 氣	死 生 榮 辱	死 白 色	死 皮 賴 臉	死 光	
死 刑	死 刑 犯	死 因	死 地	死 地 求 生	死 守	死 扣	死 有 餘 責	
死 有 餘 辜	死 有 餘 罪	死 有 餘 戮	死 死	死 灰	死 灰 色	死 灰 復 燎	死 灰 復 燃	
死 灰 槁 木	死 而 不 朽	死 而 不 悔	死 而 後 己	死 而 後 已	死 而 後 止	死 而 復 生	死 而 復 甦	
死 而 無 怨	死 而 無 悔	死 別	死 別 生 離	死 告 活 央	死 抓	死 求 白 賴	死 角	
死 命	死 抱 著 不 放	死 於	死 於 非 命	死 板	死 物	死 的	死 者	
死 者 相 枕	死 信	死 前	死 契	死 屍	死 巷	死 後	死 活	
死 相	死 相 枕 藉	死 眉 瞪 眼	死 胡 同	死 胎	死 要	死 重	死 重 泰 山	
死 氣	死 氣 白 賴	死 氣 沉 沉	死 海	死 神	死 記	死 記 硬 背	死 訊	
死 馬 當 活 馬 醫	死 鬼	死 啃	死 寂	死 得	死 得 其 所	死 掉	死 規 矩	
死 魚	死 期	死 棋	死 無 葬 身 之 地	死 無 對 證	死 無 遺 憂	死 硬	死 硬 派	
死 等	死 結	死 絕	死 傷	死 傷 相 枕	死 傷 相 藉	死 滅	死 罪	
死 裡 求 生	死 裡 逃 生	死 路	死 路 一 條	死 對	死 對 頭	死 端	死 說 活 說	
死 輕 鴻 毛	死 僵	死 敵	死 樣	死 樣 活 氣	死 模 活 樣	死 緩	死 諸 葛 走 生 仲 達	
死 戰	死 樹	死 機	死 錢	死 頭 腦	死 聲 淘 氣	死 點	死 鎖	
死 難	死 難 者	死 黨	死 纏	死 摳	氖 氣	氖 燈	汝 州	
汝 南 月 旦	汝 等	汝 輩	汗 孔	汗 毛	汗 水	汗 牛 充 棟	汗 青	
汗 流	汗 流 浹 背	汗 流 滿 面	汗 洽 股 栗	汗 衫	汗 珠	汗 珠 子	汗 馬	
汗 馬 之 功	汗 馬 之 勞	汗 馬 之 績	汗 馬 功 勞	汗 馬 功 績	汗 馬 勳 勞	汗 液	汗 斑	
汗 腳	汗 腺	汗 跡	汗 漬	汗 褂	汗 濕	汗 顏	江 上	
江 口	江 山	江 山 不 老	江 山 之 恨	江 山 之 異	江 山 半 壁	江 山 好 改 本 性 難 移	江 山 好 改 秉 性 難 移	
江 山 如 故	江 山 如 畫	江 山 易 改 稟 性 難 移	江 山 易 幟	江 川	江 中	江 天	江 天 一 色	
江 心	江 心 補 漏	江 月	江 水	江 丙 坤	江 北	江 米	江 西	
江 西 省	江 宏 恩	江 沙	江 岸	江 東	江 東 父 老	江 東 獨 步	江 河	
江 河 日 下	江 河 行 地	江 河 湖 海	江 河 戰 鬥	江 油	江 青	江 南	江 南 海 北	
江 城	江 洋 大 盜	江 流	江 津	江 郎 才 掩	江 郎 才 盡	江 面	江 浦	
江 海 之 學	江 海 心 馳 魏 闕	江 海 同 歸	江 浙	江 畔	江 淮	江 都	江 陵	
江 陰	江 魚	江 湖	江 湖 義 氣	江 湖 騙 子	江 雲 渭 樹	江 達	江 漢	
江 潮	江 輪	江 澤 民	江 翻 海 沸	江 翻 海 倒	江 邊	江 蘇	江 蘇 省	
池 上 米	池 上 鄉	池 子	池 中 之 物	池 水	池 田 勇 人	池 州	池 座	
池 堂	池 魚 之 災	池 魚 之 殃	池 魚 林 木	池 魚 遭 殃	池 魚 籠 鳥	池 塘	池 邊	
池 鹽	汐 止	汐 止 市	汕 頭	污 七 八 糟	污 七 糟 八	污 水	污 水 池	
污 水 坑	污 水 處 理	污 吏	污 吏 黜 胥	污 名	污 言 穢 語	污 泥	污 泥 濁 水	
污 物	污 垢	污 染	污 染 物	污 染 空 氣	污 染 者	污 染 源	污 染 環 境	
污 辱	污 痕	污 斑	污 黑	污 損	污 跡	污 漬	污 蔑	
污 濁	污 點	污 穢	污 穢 物	污 粘	汛 情	汛 期	灰 土	
灰 分	灰 心	灰 心 喪 氣	灰 心 喪 意	灰 心 槁 形	灰 火	灰 白	灰 白 色	
灰 光	灰 灰	灰 色	灰 色 市 場	灰 衣 服	灰 身 粉 骨	灰 姑 娘	灰 忽	
灰 泥	灰 度	灰 飛 煙 滅	灰 狼	灰 頂	灰 渣	灰 黃	灰 黃 色	
灰 黑	灰 黑 花	灰 暗	灰 溜	灰 溜 溜	灰 鼠	灰 塵	灰 廓	
灰 綠 色	灰 蒙	灰 漿	灰 褐	灰 褐 色	灰 質	灰 頭 土 面	灰 頭 土 臉	
灰 頭 草 面	灰 濛 濛	灰 燼	灰 藍 色	灰 軀 靡 骨	灰 霧	灰 鐵	灰 鑄 鐵	
灰 巖	灰 碴	牟 利	牟 取	牟 取 暴 利	牝 牡 驪 黃	牝 馬	牝 雞 司 晨	
牝 雞 牡 鳴	牝 雞 晨 鳴	牝 雞 無 晨	百 二 山 河	百 二 關 山	百 丈	百 丈 竿 頭	百 口 莫 辯	
百 口 難 分	百 川 歸 海	百 不 一 失	百 不 一 爽	百 不 一 遇	百 不 失 一	百 不 當 一	百 中	
百 中 百 發	百 五	百 元	百 六	百 分	百 分 比	百 分 制	百 分 表	
百 分 率	百 分 數	百 分 點	百 升	百 孔	百 孔 千 創	百 孔 千 瘡	百 尺	
百 尺 竿 頭	百 日	百 日 咳	百 日 草	百 日 菊	百 世	百 世 不 易	百 世 不 磨	
百 世 之 利	百 世 之 師	百 世 流 芳	百 代 文 宗	百 代 過 客	百 出	百 卉 千 葩	百 卉 含 英	
百 巧 千 窮	百 巧 成 窮	百 份	百 份 之	百 份 之 一	百 份 之 百	百 合	百 合 花	
百 回	百 年	百 年 大 計	百 年 不 遇	百 年 之 好	百 年 之 後	百 年 之 柄	百 年 之 業	
百 年 到 老	百 年 偕 老	百 年 樹 人	百 年 諧 老	百 忙	百 忙 之 中	百 忙 當 中	百 成 行	
百 死 一 生	百 米	百 老 匯	百 舌 之 聲	百 舌 鳥	百 色	百 色 起 義	百 行	
百 伶 百 俐	百 克	百 兵 列 陣	百 折	百 折 不 回	百 折 不 撓	百 步	百 步 穿 楊	
百 步 無 輕 擔	百 足	百 足 不 僵	百 足 之 蟲 死 而 不 僵	百 足 之 蟲 至 死 不 僵	百 身 何 贖	百 身 莫 贖	百 里	
百 里 者 半 九 十	百 里 挑 一	百 里 香	百 事 大 吉	百 事 可 樂	百 事 通	百 事 無 成	百 依 百 順	
百 依 百 隨	百 兒 八 十	百 姓	百 官	百 念 皆 灰	百 念 俱 灰	百 怪	百 的	
百 花	百 花 爭 艷	百 花 盛 開	百 花 園	百 花 齊 放	百 花 獎	百 保 利	百 城 之 富	
百 度	百 思	百 思 不 得 其 解	百 思 不 解	百 思 而 不 得 其 解	百 思 莫 解	百 挑 不 厭	百 段 千 煉	
百 看 不 厭	百 科	百 科 全 書	百 科 知 識	百 科 詞 典	百 計	百 計 千 心	百 計 千 方	
百 計 千 謀	百 頁 窗	百 倍	百 個	百 家	百 家 姓	百 家 爭 嗚	百 家 爭 鳴	
百 家 諸 子	百 容 電 子	百 病	百 般	百 般 刁 難	百 般 挑 剔	百 草	百 動 不 如 一 靜	
百 商	百 問 不 煩	百 堵 皆 作	百 強	百 捨 重 繭	百 捨 重 趼	百 盒	百 貨	
百 貨 大 廈	百 貨 大 樓	百 貨 公 司	百 貨 店	百 貨 股	百 貨 商 店	百 貨 商 場	百 部	
百 勝	百 喙 莫 辯	百 媚 千 嬌	百 無 一 失	百 無 一 用	百 無 一 是	百 無 一 能	百 無 一 漏	
百 無 所 成	百 無 所 忌	百 無 聊 賴	百 無 禁 忌	百 發 百 中	百 紫 千 紅	百 順 百 依	百 感	
百 感 交 集	百 歲	百 歲 千 秋	百 歲 之 後	百 歲 老 人	百 煉	百 煉 千 錘	百 煉 之 鋼	
百 煉 成 鋼	百 萬	百 萬 倍	百 萬 個	百 萬 富 翁	百 萬 買 宅 千 萬 買 鄰	百 萬 雄 兵	百 萬 雄 獅	
百 萬 噸	百 萬 噸 級	百 葉	百 葉 窗	百 團 大 戰	百 弊	百 態	百 福 具 臻	
百 端 交 集	百 端 待 舉	百 聞 不 如 一 見	百 廢	百 廢 具 興	百 廢 待 興	百 廢 待 舉	百 廢 俱 興	
百 廢 俱 舉	百 廢 備 舉	百 慕	百 慕 大	百 磅	百 餘	百 噸	百 戰	
百 戰 不 殆	百 戰 百 勝	百 戰 奇 略	百 謀 千 計	百 龍 之 智	百 應	百 戲	百 縱 千 隨	
百 舉 百 全	百 獸 率 舞	百 羅 旅 遊 網	百 齡	百 齡 眉 壽	百 聽 不 厭	百 讀 不 厭	百 靈	
百 靈 百 驗	百 靈 鳥	竹 子	竹 山 鎮	竹 木	竹 片	竹 片 狀	竹 北	
竹 布	竹 田 鄉	竹 材	竹 東	竹 枝	竹 林	竹 林 之 遊	竹 板	
竹 南	竹 南 鎮	竹 科	竹 竿	竹 苞 松 茂	竹 紙	竹 馬 之 友	竹 馬 之 好	
竹 排	竹 條	竹 野 內 豐	竹 報 平 安	竹 椅	竹 筐	竹 筒	竹 筍	
竹 筏	竹 園	竹 塘	竹 筷	竹 節	竹 葉	竹 葉 青	竹 槓	
竹 管	竹 蓆	竹 製	竹 樓	竹 器	竹 頭 木 屑	竹 簍	竹 聯 幫	
竹 簡	竹 簾	竹 類	竹 籃	竹 籠	竹 籤	米 尺	米 老 鼠	
米 色	米 行	米 制	米 奇	米 店	米 突	米 面	米 倉	
米 格	米 珠 薪 桂	米 粉	米 脂	米 酒	米 高 福 克 斯	米 票	米 粒	
米 粒 之 珠	米 湯	米 粥	米 飯	米 黃	米 團	米 餅	米 價	
米 廠	米 糕	米 糠	米 糧	米 糧 川	米 蘇 裡 州	米 蘭	米 鹽 博 辯	
米 舖	羊	羊 毛	羊 毛 出 在 羊 身 上	羊 毛 皮	羊 毛 制	羊 毛 狀	羊 毛 衫	
羊 毛 脂	羊 毛 商	羊 毛 袋	羊 水	羊 叫 聲	羊 奶	羊 皮	羊 皮 衣	
羊 皮 紙	羊 皮 帽	羊 年	羊 肉	羊 肉 串	羊 角	羊 乳	羊 城	
羊 狠 狼 貪	羊 革	羊 倌	羊 真 孔 草	羊 羔	羊 脂	羊 圈	羊 毫	
羊 產	羊 場	羊 棗	羊 絨	羊 群	羊 腸	羊 腸 小 徑	羊 腸 小 道	
羊 腸 鳥 道	羊 落 虎 口	羊 裘 垂 釣	羊 道	羊 腿	羊 膜 穿 刺	羊 質 虎 皮	羊 踏 菜 園	
羊 齒	羊 齒 類	羊 頭	羊 頭 狗 肉	羊 觸 藩 籬	羊 欄	羊 續 懸 魚	羊 體 嵇 心	
羊 癲 風	羽 化	羽 化 飛 天	羽 化 登 仙	羽 毛	羽 毛 未 豐	羽 毛 狀	羽 毛 球	
羽 毛 球 運 動	羽 毛 被	羽 毛 豐 滿	羽 田	羽 田 機 械	羽 衣	羽 狀	羽 冠	
羽 扇	羽 扇 豆	羽 扇 綸 巾	羽 紗	羽 球	羽 絨	羽 絨 服	羽 絨 衫	
羽 量 級	羽 壇	羽 翮 已 就	羽 翮 飛 肉	羽 檄 交 馳	羽 檄 飛 馳	羽 翼	羽 翼 已 成	
羽 翼 豐 滿	羽 蹈 烈 火	老 一 代	老 一 套	老 一 輩	老 九	老 二	老 人	
老 人 安 養	老 人 年 金	老 人 家	老 人 福 利	老 人 學	老 八 路	老 三	老 丈	
老 么	老 大	老 大 自 居	老 大 哥	老 大 娘	老 大 徒 傷 悲	老 大 無 成	老 大 爺	
老 大 難	老 女 歸 宗	老 子	老 子 婆 娑	老 小	老 山	老 丑	老 不 曉 事	
老 中	老 中 青	老 中 青 三 結 合	老 井	老 五	老 六	老 公	老 化	
老 友	老 天	老 天 拔 地	老 天 爺	老 夫	老 夫 子	老 太	老 太 太	
老 太 婆	老 太 爺	老 少	老 少 咸 宜	老 少 皆 宜	老 少 邊 窮	老 手	老 毛 病	
老 水 手	老 父	老 牛	老 牛 破 車	老 牛 舐 犢	老 王	老 兄	老 去	
老 古 板	老 外	老 奴	老 奶 奶	老 幼	老 旦	老 本	老 母	
老 生	老 生 常 談	老 用 戶	老 光	老 先 生	老 同 志	老 奸 巨 滑	老 奸 巨 猾	
老 好 人	老 字 號	老 年	老 年 人	老 年 痴 呆 症	老 年 學	老 式	老 成	
老 成 之 見	老 成 見 到	老 成 持 重	老 成 練 達	老 早	老 有 所 為	老 有 所 終	老 有 所 樂	
老 朽	老 死	老 死 不 相 往 來	老 死 溝 壑	老 死 牖 下	老 百 姓	老 老	老 老 大 大	
老 老 少 少	老 老 實 實	老 而	老 而 不 死 是 為 賊	老 而 益 壯	老 西	老 伴	老 伴 兒	
老 伯	老 兵	老 君	老 妖	老 妖 似	老 弟	老 李	老 豆	
老 身	老 身 長 子	老 例	老 來	老 兒	老 到	老 叔	老 命	
老 姑 娘	老 姐	老 店	老 底	老 於 世 故	老 朋 友	老 河 口	老 爸	
老 的	老 者	老 花	老 花 眼	老 花 鏡	老 虎	老 虎 伍 茲	老 虎 鉗	
老 虎 頭 上 打 蒼 蠅	老 虎 頭 上 撲 蒼 蠅	老 表	老 金	老 長	老 前 輩	老 厚	老 城	
老 帥	老 是	老 是 往	老 派	老 皇 歷	老 相	老 相 識	老 紅 軍	
老 耄	老 倆 口	老 修	老 叟	老 哥	老 套	老 娘	老 家	
老 師	老 師 宿 儒	老 師 傅	老 弱	老 弱 病 殘	老 弱 殘 兵	老 拳	老 框 框	
老 根	老 根 據 地	老 氣	老 氣 橫 秋	老 爹	老 病	老 祖	老 祖 宗	
老 翁	老 蚌 生 珠	老 衰	老 衰 了	老 財	老 酒	老 院	老 馬	
老 馬 為 駒	老 馬 嘶 風	老 馬 識 途	老 高	老 區	老 婦	老 婆	老 婆 子	
老 婆 舌 頭	老 婆 兒	老 婆 婆	老 婆 當 軍	老 將	老 巢	老 帳	老 張	
老 掉 牙	老 捨	老 教 師	老 淚	老 淚 縱 橫	老 眼	老 眼 光	老 粗	
老 羞	老 羞 成 怒	老 羞 變 怒	老 莊	老 處 女	老 規 矩	老 魚 跳 波	老 幾	
老 景	老 殘	老 湯	老 牌	老 童	老 等	老 著	老 萊 娛 親	
老 街	老 鄉	老 黃	老 黃 牛	老 媽	老 媽 子	老 媼	老 幹 部	
老 搭 擋	老 爺	老 爺 子	老 爺 車	老 爺 爺	老 當	老 當 益 壯	老 話	
老 資 格	老 路	老 農	老 道	老 鼠	老 鼠 見 貓	老 鼠 過 街	老 僧	
老 僧 入 定	老 境	老 境 堪 憂	老 嫗	老 嫗 能 解	老 實	老 實 人	老 實 說	
老 態	老 態 龍 鍾	老 態 龍 鐘	老 槍	老 漢	老 熊 當 道	老 窩	老 說	
老 辣	老 遠	老 樣	老 糊 塗	老 練	老 練 兵	老 調	老 調 重 彈	
老 賬	老 輩	老 醋	老 鴉	老 戰 士	老 戰 友	老 撾	老 撾 人	
老 樹	老 親	老 謀	老 謀 深 算	老 頭	老 頭 子	老 頭 兒	老 龜	
老 營	老 總	老 聲	老 臉	老 薑	老 邁	老 邁 龍 鐘	老 闆	
老 闆 娘	老 舊	老 雞	老 壞 蛋	老 繭	老 齡	老 齡 化	老 鶴 成 軒	
老 聽	老 體	老 鷹	老 驥 伏 櫪	老 侄	老 衲	老 蔫	老 鴇	
老 鴰	老 羆 當 道	考 人	考 上	考 中	考 分	考 古	考 古 學	
考 生	考 名 則 實	考 完	考 究	考 其 原 因	考 到	考 卷	考 取	
考 官	考 查	考 訂	考 准	考 核	考 核 成 績	考 核 制 度	考 核 評 鑑	
考 級	考 區	考 問	考 得	考 場	考 評	考 量	考 勤	
考 勤 制 度	考 勤 簿	考 試	考 試 制 度	考 試 者	考 試 院	考 試 學	考 察	
考 察 報 告	考 察 隊	考 察 團	考 種	考 慮	考 慮 不 周	考 慮 到	考 慮 周 到	
考 慮 過	考 據	考 選 部	考 績	考 績 幽 明	考 績 黜 陟	考 題	考 證	
考 驗	而 又	而 下	而 上	而 不	而 今	而 今 而 後	而 止	
而 且	而 且 還	而 以	而 他	而 出	而 去	而 可	而 外	
而 未	而 生	而 用	而 由	而 立	而 立 之 年	而 在 於	而 她	
而 成	而 有	而 行	而 作	而 坐	而 每	而 言	而 足	
而 那	而 並	而 使	而 來	而 受	而 或	而 於	而 況	
而 近	而 非	而 後	而 是	而 為	而 要	而 飛	而 能	
而 起	而 將	而 得	而 從	而 異	而 處	而 無	而 然	
而 跑	而 解	而 達	而 遇	而 過	而 盡	而 蒙	而 談	
而 論	而 錄	而 獲	耒 耜 之 勤	耒 耨 之 利	耒 耨 之 教	耳 力	耳 下	
耳 上	耳 孔	耳 生	耳 目	耳 目 一 新	耳 石	耳 穴	耳 光	
耳 尖	耳 朵	耳 房	耳 炎	耳 狀 物	耳 門	耳 垂	耳 垢	
耳 屎	耳 挖	耳 染 目 濡	耳 科	耳 科 學	耳 紅 面 赤	耳 背	耳 食 之 言	
耳 食 之 談	耳 套	耳 旁 風	耳 根	耳 根 清 淨	耳 疾	耳 草 屬	耳 軟	
耳 軟 心 活	耳 部	耳 喻	耳 提 面 命	耳 提 面 訓	耳 殼	耳 視 目 食	耳 視 目 聽	
耳 順	耳 順 之 年	耳 塞	耳 溫 槍	耳 罩	耳 飾	耳 鼓	耳 滿 鼻 滿	
耳 聞	耳 聞 不 如 一 見	耳 聞 不 如 目 見	耳 聞 目 見	耳 聞 目 睹	耳 聞 目 擊	耳 語	耳 語 般	
耳 鳴	耳 鼻	耳 鼻 喉	耳 鼻 喉 科	耳 墜	耳 熟	耳 熟 能 詳	耳 膜	
耳 機	耳 濡 目 染	耳 環	耳 聲	耳 聰 目 明	耳 藥 水	耳 邊	耳 邊 風	
耳 鏡	耳 聾	耳 聾 眼 花	耳 聽	耳 聽 八 方	耳 聽 為 虛	耳 鬢 廝 磨	肉 丁	
肉 丸	肉 山 酒 海	肉 中 刺	肉 中 刺 眼 中 釘	肉 內	肉 片	肉 牛	肉 包	
肉 末	肉 汁	肉 汁 湯	肉 用	肉 皮	肉 刑	肉 色	肉 豆	
肉 身	肉 制	肉 卷	肉 店	肉 果	肉 林 酒 池	肉 狀	肉 芽	
肉 垂	肉 紅	肉 食	肉 食 性	肉 食 者 鄙	肉 食 品	肉 凍	肉 峰	
肉 桂	肉 畜	肉 骨	肉 乾	肉 排	肉 眼	肉 眼 凡 胎	肉 眼 愚 眉	
肉 眼 圖	肉 票	肉 脯	肉 蛋	肉 販	肉 麻	肉 棒	肉 湯	
肉 絲	肉 塊	肉 感	肉 搏	肉 搏 戰	肉 禽	肉 跳 心 驚	肉 團	
肉 粽	肉 綻	肉 綻 皮 開	肉 製 品	肉 餅	肉 價	肉 彈	肉 慾	
肉 瘤	肉 質	肉 館	肉 餡	肉 餡 餅	肉 糜	肉 醬	肉 醬 面	
肉 雞	肉 鬆	肉 類	肉 體	肉 體 上	肉 體 化	肉 體 性	肉 舖	
肋 肉	肋 狀	肋 肩 累 足	肋 骨	肋 骨 狀	肋 條	肋 間	肋 膜	
肋 膜 炎	肌 肉	肌 炎	肌 無 完 膚	肌 腱	肌 瘤	肌 膚	肌 體	
臣 子	臣 民	臣 臣	臣 妾	臣 服	臣 僚	臣 僕	自 力	
自 力 更 生	自 下	自 下 而 上	自 上	自 上 而 下	自 大	自 大 狂	自 大 者	
自 小	自 小 客 車	自 己	自 己 人	自 己 的	自 己 做	自 干	自 不	
自 不 待 言	自 不 量 力	自 今	自 分	自 主	自 主 經 營	自 主 權	自 以 為	
自 以 為 是	自 以 為 然	自 以 得 計	自 出	自 出 一 家	自 出 機 杼	自 古	自 古 以 來	
自 外	自 幼	自 打	自 本	自 民 黨	自 甘 落 後	自 甘 墮 落	自 生 自 滅	
自 用	自 由	自 由 女 神	自 由 化	自 由 王 國	自 由 主 義	自 由 市 場	自 由 民	
自 由 式	自 由 自 在	自 由 行 動	自 由 車	自 由 車 賽	自 由 泳	自 由 度	自 由 時 報	
自 由 基	自 由 散 漫	自 由 港	自 由 貿 易	自 由 電 子	自 由 選 擇	自 由 競 爭	自 由 權	
自 由 戀 愛	自 由 體 操	自 白	自 白 者	自 立	自 立 門 戶	自 交 系	自 刎	
自 同 寒 蟬	自 名	自 在	自 在 不 成 人	自 在 逍 遙	自 如	自 存	自 忖	
自 成	自 成 一 家	自 成 體 系	自 有	自 有 肺 腸	自 此	自 行	自 行 火 炮	
自 行 安 排	自 行 車	自 行 其 是	自 行 設 計	自 西	自 住	自 作	自 作 主 張	
自 作 多 情	自 作 自 受	自 作 聰 明	自 助	自 助 旅 行	自 助 旅 遊	自 助 餐	自 即 日 起	
自 告 奮 勇	自 吹 自 擂	自 序	自 戒	自 我	自 我 介 紹	自 我 作 故	自 我 批 評	
自 我 改 造	自 我 表 現	自 我 陶 醉	自 我 發 展	自 我 意 識	自 我 解 嘲	自 我 實 現	自 我 調 節	
自 我 犧 牲	自 找	自 投 羅 網	自 求 多 福	自 決	自 決 權	自 私	自 私 自 利	
自 言 自 語	自 走	自 足	自 身	自 身 利 益	自 身 建 設	自 身 難 保	自 供	
自 供 狀	自 來	自 來 水	自 來 水 公 司	自 來 水 事 業 處	自 來 水 筆	自 來 紅	自 卑	
自 卑 感	自 取	自 取 其 咎	自 取 其 辱	自 取 滅 亡	自 受	自 命	自 命 不 凡	
自 咎	自 奉	自 始 至 終	自 定	自 定 義	自 居	自 戕	自 招	
自 拔	自 拔 來 歸	自 明	自 東	自 治	自 治 州	自 治 區	自 治 縣	
自 治 體	自 的	自 知	自 知 之 明	自 花	自 信	自 信 心	自 便	
自 保	自 勉	自 封	自 建	自 律	自 律 性	自 怨 自 艾	自 恃	
自 恃 清 高	自 持	自 是	自 查	自 流	自 流 井	自 為	自 省	
自 相	自 相 水 火	自 相 矛 盾	自 相 魚 肉	自 相 殘 害	自 相 殘 殺	自 相 關	自 相 驚 擾	
自 矜	自 若	自 負	自 負 不 凡	自 負 盈 虧	自 述	自 述 文 件	自 重	
自 食 其 力	自 食 其 言	自 食 其 果	自 首	自 乘	自 個	自 個 兒	自 修	
自 哪	自 娛	自 家	自 差	自 書	自 核	自 留	自 留 地	
自 耕 農	自 討 沒 趣	自 討 苦 吃	自 辱	自 高 自 大	自 做	自 動	自 動 化	
自 動 步 槍	自 動 性	自 動 控 制	自 動 梯	自 動 傘	自 動 裝 置	自 動 電 話	自 動 播 放	
自 動 線	自 動 機	自 動 檢 索	自 動 檢 測	自 唱	自 問	自 崖 而 反	自 帶	
自 強	自 強 不 息	自 強 活 動	自 強 號	自 得	自 得 其 樂	自 從	自 惜 羽 毛	
自 控	自 掘	自 掘 墳 墓	自 掏	自 救	自 救 不 暇	自 敘	自 棄	
自 殺	自 殺 性	自 殺 者	自 殺 案	自 理	自 產	自 習	自 處	
自 處 理	自 許	自 設	自 責	自 造 詞	自 閉 症	自 備	自 創	
自 喜	自 喻	自 報	自 尊	自 尊 心	自 尋	自 尋 煩 惱	自 提	
自 欺	自 欺 欺 人	自 焚	自 然	自 然 人	自 然 力	自 然 生 態	自 然 地	
自 然 地 理	自 然 而 然	自 然 色	自 然 村	自 然 災 害	自 然 林	自 然 界	自 然 科 學	
自 然 科 學 史	自 然 美	自 然 風 光	自 然 哲 學	自 然 區	自 然 條 件	自 然 現 象	自 然 規 律	
自 然 經 濟	自 然 資 源	自 然 數	自 然 碼	自 然 學	自 然 環 境	自 然 辯 證 法	自 然 觀	
自 畫 像	自 發	自 發 性	自 發 勢 力	自 盜	自 硬 性	自 絕	自 給	
自 給 自 足	自 裁	自 視	自 訴	自 訴 人	自 貽 伊 戚	自 費	自 費 生	
自 費 留 學	自 量	自 雇	自 傲	自 傳	自 圓 其 說	自 填	自 感	
自 愛	自 愧 不 如	自 斟 自 酌	自 新	自 會	自 毀	自 溶	自 當	
自 經	自 誇	自 慚 形 穢	自 滿	自 盡	自 稱	自 稱 者	自 製	
自 語	自 認	自 說 自 話	自 誘 導	自 豪	自 豪 感	自 輕 自 賤	自 鳴	
自 鳴 得 意	自 鳴 清 高	自 嘲	自 慰	自 憐	自 暴 自 棄	自 歎	自 編	
自 編 自 演	自 衛	自 衛 戰 爭	自 衛 還 擊	自 衛 權	自 請	自 賣	自 賣 自 誇	
自 銷	自 養	自 餒	自 學	自 學 方 法	自 學 成 才	自 學 者	自 導	
自 導 引	自 擂	自 激	自 燃	自 縊	自 謀	自 謀 出 路	自 謀 職 業	
自 辦	自 選	自 選 市 場	自 選 商 場	自 勵	自 應	自 檢	自 營	
自 營 商	自 謙	自 購	自 擾	自 薦	自 轉	自 穩	自 願	
自 願 互 利	自 願 者	自 籌	自 籌 資 金	自 覺	自 覺 自 願	自 覺 行 穢	自 覺 性	
自 顧	自 顧 不 暇	自 戀	自 變 量	自 體	自 釀	自 詒 伊 戚	自 詡	
自 鄶 以 下	至 上	至 今	至 今 還	至 公 無 私	至 少	至 日	至 交	
至 交 契 友	至 再 至 三	至 多	至 好	至 此	至 死	至 死 不 屈	至 死 不 悟	
至 死 靡 他	至 尾	至 矣 盡 矣	至 於	至 為	至 高	至 高 至 上	至 高 無 上	
至 理	至 理 名 言	至 終	至 尊	至 尊 至 貴	至 善	至 善 至 美	至 意 誠 心	
至 極	至 當	至 聖	至 誠	至 誠 高 節	至 誠 無 昧	至 親	至 親 好 友	
至 親 骨 肉	至 遲	至 關	至 關 重 要	至 關 緊 要	至 寶	至 沓 來	臼 石	
臼 齒	舌 下	舌 干	舌 片	舌 尖	舌 炎	舌 狀 片	舌 狀 部	
舌 後	舌 苔	舌 面	舌 音	舌 音 字	舌 根	舌 敝 耳 聾	舌 敝 唇 焦	
舌 端	舌 劍 唇 槍	舌 鋒	舌 戰	舌 頭	舌 觸	舟 山	舟 中 敵 國	
舟 曲	舟 車	舟 楫	舟 橋	色 片	色 卡	色 布	色 光	
色 色 俱 全	色 味	色 性	色 拉	色 板	色 版	色 盲	色 度	
色 度 計	色 度 學	色 相	色 若 死 灰	色 飛 眉 舞	色 香 味	色 原 體	色 差	
色 弱	色 料	色 狼	色 素	色 素 體	色 衰	色 衰 愛 馳	色 衰 愛 寢	
色 酒	色 鬼	色 基	色 帶	色 彩	色 彩 斑 斕	色 彩 論	色 情	
色 情 交 易	色 情 狂	色 授 魂 與	色 條	色 淡	色 淺	色 散	色 斑	
色 筆	色 達	色 厲 內 荏	色 慾	色 樣	色 漿	色 調	色 澤	
色 燈	色 膽	色 膽 如 天	色 膽 迷 天	色 藝 兩 絕	色 藝 無 雙	色 藝 絕 輪	色 譜	
色 譜 儀	色 邊	色 覺	艾 艾	艾 佛 森	艾 倫	艾 莉 坎 貝 爾	艾 莉 絲	
艾 滋	艾 滋 病	艾 滋 病 毒	艾 爾 斯	艾 爾 頓 強	艾 瑪 湯 普 遜	艾 德 華 勃 恩 斯	艾 德 蒙 茲	
血 刃	血 口	血 口 噴 人	血 小 板	血 中	血 友	血 友 病	血 友 症	
血 水	血 本	血 汗	血 污	血 肉	血 肉 之 軀	血 肉 相 連	血 肉 相 聯	
血 肉 淋 漓	血 肉 模 糊	血 肉 橫 飛	血 色	血 色 好	血 色 素	血 行	血 衣	
血 吸 蟲	血 尿	血 尿 症	血 防	血 性	血 泊	血 花	血 雨 腥 風	
血 型	血 染	血 毒 症	血 流	血 流 如 注	血 流 成 川	血 流 成 河	血 流 成 渠	
血 流 漂 杵	血 洗	血 盆	血 盆 大 口	血 紅	血 紅 色	血 紅 素	血 紅 蛋 白	
血 庫	血 書	血 案	血 栓	血 栓 症	血 氣	血 氣 方 壯	血 氣 方 剛	
血 氣 方 盛	血 海	血 海 深 仇	血 粉	血 脂	血 脈	血 崩	血 液	
血 液 學	血 清	血 清 學	血 淋 淋	血 淚	血 淚 斑 斑	血 球	血 痕	
血 統	血 細 胞	血 絲	血 虛	血 債	血 塊	血 暈	血 腥	
血 跡	血 路	血 滴	血 漬	血 種	血 管	血 漿	血 緣	
血 凝	血 戰	血 濃 於 水	血 糖	血 親	血 壓	血 壓 計	血 癌	
血 虧	血 蟲	行 了	行 人	行 上	行 乞	行 己 有 恥	行 不	
行 不 及 言	行 不 由 徑	行 不 更 名 坐 不 改 姓	行 不 苟 合	行 不 苟 容	行 不 通	行 不 逾 方	行 不 顧 言	
行 中	行 之 有 年	行 之 有 效	行 化 如 神	行 天 宮	行 文	行 止	行 令	
行 只 影 單	行 市	行 必 果	行 伍	行 兇	行 兇 作 惡	行 兇 撒 潑	行 列	
行 列 式	行 刑	行 合 趨 同	行 在	行 好	行 成 于 思	行 成 功 滿	行 次	
行 色	行 色 匆 匆	行 行	行 行 出 狀 元	行 兵 佈 陣	行 劫	行 呀	行 吟 坐 詠	
行 尾	行 李	行 李 車	行 李 架	行 步 如 飛	行 走	行 走 如 飛	行 身	
行 車	行 車 道	行 事	行 事 歷	行 使	行 使 主 權	行 使 職 權	行 其	
行 刺	行 孤 影 只	行 孤 影 寡	行 性	行 房	行 所 無 事	行 於	行 於 言 色	
行 於 顏 色	行 於 辭 色	行 易 知 難	行 東	行 板	行 狀	行 的	行 者	
行 長	行 宣 福 禮	行 屍 走 肉	行 屍 走 骨	行 思 坐 想	行 思 坐 憶	行 政	行 政 上	
行 政 公 署	行 政 行 為	行 政 村	行 政 事 業 單 位	行 政 官	行 政 法	行 政 法 院	行 政 法 規	
行 政 法 學	行 政 院	行 政 院 主 計 處	行 政 區	行 政 區 域	行 政 區 劃	行 政 處 分	行 政 責 任	
行 政 訴 訟	行 政 訴 訟 法	行 政 監 督	行 政 監 察	行 政 管 理	行 政 學	行 政 機 關	行 星	
行 星 間	行 為	行 為 人	行 為 不 端	行 為 者	行 為 科 學	行 為 準 則	行 為 論	
行 省	行 若 狗 彘	行 若 無 事	行 軍	行 軍 動 眾	行 首	行 家	行 宮	
行 師 動 眾	行 徑	行 旁	行 旅	行 書	行 疾 如 飛	行 眠 立 盹	行 動	
行 動 上	行 動 者	行 動 計 劃	行 動 電 話	行 動 遲 緩	行 商	行 啦	行 將	
行 將 就 木	行 得 通	行 情	行 船	行 規	行 許	行 都	行 割 禮	
行 單 影 只	行 單 影 單	行 惡	行 期	行 棧	行 款	行 無 越 思	行 短 才 高	
行 短 才 喬	行 程	行 程 表	行 筆	行 善	行 腔	行 詐	行 距	
行 進	行 量	行 間	行 雲 流 水	行 嗎	行 會	行 業	行 業 不 正 之 風	
行 楷	行 當	行 經	行 署	行 號	行 號 巷 哭	行 裝	行 詩	
行 話	行 賄	行 賄 受 賄	行 賄 者	行 跡	行 路	行 道	行 過	
行 滿 功 成	行 滿 功 圓	行 語	行 遠 自 邇	行 數	行 樂	行 賞	行 輩	
行 銷	行 橫	行 濁 言 清	行 隨 事 遷	行 頻	行 頭	行 幫	行 檢	
行 營	行 虧 名 缺	行 轅	行 獵	行 禮	行 蹤	行 醫	行 騙	
行 囊	行 竊	衣 不 曳 地	衣 不 完 采	衣 不 重 采	衣 不 重 彩	衣 不 解 帶	衣 不 蓋 體	
衣 不 蔽 體	衣 勾	衣 包	衣 匠	衣 扣	衣 羊 公 鶴	衣 夾	衣 角	
衣 刷	衣 帛	衣 帛 食 肉	衣 服	衣 物	衣 阿 華	衣 冠	衣 冠 沐 猴	
衣 冠 甚 偉	衣 冠 梟 獍	衣 冠 雲 集	衣 冠 楚 楚	衣 冠 禽 獸	衣 冠 緒 餘	衣 冠 赫 奕	衣 冠 齊 楚	
衣 冠 輻 湊	衣 冠 優 孟	衣 冠 濟 楚	衣 冠 濟 濟	衣 冠 禮 樂	衣 冠 藍 縷	衣 架	衣 架 飯 囊	
衣 衫	衣 衫 藍 縷	衣 食	衣 食 之 謀	衣 食 父 母	衣 食 住 行	衣 香 鬢 影	衣 料	
衣 租 食 稅	衣 索 比 亞	衣 兜	衣 帶	衣 缽	衣 缽 相 傳	衣 被	衣 袖	
衣 袍	衣 袋	衣 帽	衣 帽 架	衣 帽 間	衣 紫 腰 金	衣 紫 腰 黃	衣 著	
衣 裙	衣 裝	衣 飾	衣 飾 邊	衣 裳	衣 裳 兒	衣 裳 楚 楚	衣 領	
衣 樣	衣 箱	衣 褲	衣 錦 之 榮	衣 錦 夜 行	衣 錦 夜 遊	衣 錦 故 鄉	衣 錦 食 肉	
衣 錦 晝 游	衣 錦 過 鄉	衣 錦 榮 歸	衣 錦 還 鄉	衣 櫃	衣 豐 食 足	衣 豐 食 飽	衣 櫥	
衣 襟	衣 類	衣 �� 夜 行	衣 �� 晝 行	西 人	西 下	西 口	西 山	
西 山 日 迫	西 山 日 薄	西 山 餓 夫	西 元	西 化	西 天	西 文	西 方	
西 方 人	西 方 化	西 方 國 家	西 方 淨 土	西 充	西 北	西 北 大 學	西 北 太 平 洋	
西 北 地 區	西 北 角	西 北 風	西 北 部	西 半 球	西 瓜	西 皮	西 向	
西 安	西 安 市	西 安 門	西 式	西 米	西 行	西 西	西 西 裡	
西 西 裡 人	西 西 裡 島	西 伯 利 亞	西 床 剪 燭	西 沙	西 沙 群 島	西 谷 米	西 走	
西 亞	西 京	西 典	西 周	西 岸	西 征	西 昌	西 服	
西 東	西 林	西 門	西 門 子	西 非	西 南	西 南 太 平 洋	西 南 地 區	
西 南 角	西 南 風	西 南 部	西 垂	西 城	西 城 男 孩	西 城 區	西 施	
西 歪 東 倒	西 段	西 洋	西 洋 人	西 洋 化	西 洋 式	西 洋 景	西 洋 棋	
西 洋 鏡	西 紅 柿	西 郊	西 面	西 風	西 夏	西 晉	西 班 牙	
西 班 牙 人	西 班 牙 語	西 貢	西 貢 市	西 閃	西 除 東 蕩	西 側	西 區	
西 域	西 望	西 部	西 陵	西 單	西 港	西 湖	西 湖 鄉	
西 窗	西 華	西 菜	西 街	西 距	西 雅 圖	西 照	西 盟	
西 經	西 葫 蘆	西 裝	西 裝 革 履	西 裝 料	西 路	西 境	西 寧	
西 寧 市	西 漢	西 端	西 餅	西 德	西 樓	西 樂	西 歐	
西 歐 各 國	西 歐 國 家	西 學	西 曆	西 褲	西 頭	西 餐	西 螺	
西 點	西 歸	西 藏	西 藏 自 治 區	西 醫	西 醫 結 合	西 闖	西 雙 版 納	
西 疇	西 疆	西 藥	西 藥 房	西 邊	西 關	西 曬	阡 陌	
串 用	串 列	串 在	串 成	串 行	串 串	串 並 聯	串 供	
串 花	串 門	串 門 子	串 流	串 音	串 氣	串 起	串 通	
串 通 一 氣	串 連	串 換	串 筒	串 話	串 演	串 線	串 謀	
串 戲	串 聯	串 講	串 擾	亨 丁 頓 舞 蹈 症	亨 利	亨 通	位 子	
位 元	位 元 組	位 及	位 次	位 似	位 似 變 換	位 低	位 址	
位 制	位 卑 言 高	位 居	位 於	位 於 下 面	位 於 在	位 於 高 處	位 差	
位 素	位 能	位 高	位 移	位 第	位 勢	位 極 人 臣	位 置	
位 置 格	位 圖	位 數	位 標	住 了	住 入	住 下	住 口	
住 戶	住 手	住 民	住 用	住 地	住 在	住 在 內	住 宅	
住 宅 區	住 宅 樓	住 血	住 行	住 址	住 足	住 店	住 房	
住 房 難	住 所	住 於	住 的	住 者	住 屋	住 持	住 員	
住 家	住 家 用	住 旅 館	住 校	住 氣	住 院	住 宿	住 處	
住 筆	住 著	住 進	住 勤	住 腳	住 慣	住 嘴	住 聯 工 業	
佇 立	佇 列	佇 足	佇 侯	佇 望	伴 人	伴 之	伴 手	
伴 以	伴 同	伴 有	伴 你	伴 兒	伴 性	伴 物	伴 者	
伴 侶	伴 奏	伴 奏 者	伴 奏 隊 員	伴 郎	伴 音	伴 食 中 書	伴 食 宰 相	
伴 娘	伴 唱	伴 著	伴 遊	伴 舞	伴 器	伴 隨	伴 隨 有	
伴 隨 物	伴 護	伴 讀	佛 口 蛇 心	佛 山	佛 手	佛 牙	佛 光 會	
佛 寺	佛 事	佛 典	佛 協	佛 坪	佛 法	佛 門	佛 陀	
佛 洛 伊 德	佛 家	佛 祖	佛 骨	佛 堂	佛 教	佛 教 史	佛 教 界	
佛 教 徒	佛 眼 相 看	佛 堤 樹	佛 塔	佛 殿	佛 爺	佛 經	佛 像	
佛 語	佛 學	佛 曉	佛 歷	佛 頭 著 糞	佛 羅 里 達	佛 羅 倫 斯	佛 羅 倫 薩	
佛 蘭	佛 囉 哩 達	佛 龕	何 人	何 干	何 不	何 方	何 月	
何 止	何 以	何 以 見 得	何 去	何 去 何 從	何 必	何 必 當 初	何 用	
何 地	何 在	何 如	何 年	何 年 何 月	何 至	何 妨	何 忍	
何 足 掛 齒	何 足 道 哉	何 事	何 其	何 況	何 者	何 故	何 為	
何 苦	何 時	何 時 何 地	何 時 是 了	何 患	何 處	何 許 人 也	何 堪	
何 曾	何 等	何 超 儀	何 須	何 廉	何 嘗	何 嘉 文	何 種	
何 樂	何 樂 不 為	何 樂 而 不 為	何 潤 東	何 謂	估 及	估 列	估 地	
估 衣 店	估 到	估 定	估 計	估 計 不 足	估 計 者	估 計 員	估 值	
估 產	估 測	估 稅	估 稅 員	估 量	估 過	估 摸	估 算	
估 價	估 價 人	估 錯	佐 人	佐 世	佐 治 亞	佐 料	佐 理	
佐 雍 得 嘗	佐 餐	佐 藥	佐 證	佑 知	伽 利 略	伽 馬	伽 瑪	
伺 服	伺 服 者	伺 服 閥	伺 服 器	伺 服 機 構	伺 候	伺 料	伺 料 槽	
伺 隙	伺 養	伺 養 者	伺 養 場	伺 機	伸 入	伸 化	伸 及	
伸 手	伸 手 派	伸 出	伸 向	伸 肌	伸 至	伸 角	伸 到	
伸 延	伸 直	伸 長	伸 長 性	伸 度	伸 眉 吐 氣	伸 冤	伸 展	
伸 展 到	伸 展 者	伸 域	伸 張	伸 張 正 義	伸 雪	伸 港 鄉	伸 進	
伸 開	伸 腰	伸 過	伸 鉤 索 鐵	伸 腿	伸 頸	伸 縮	伸 縮 性	
伸 縮 器	伸 臂	佃 戶	佃 契	佃 客	佃 租	佃 農	佔 了	
佔 人 口 總 數	佔 上 風	佔 去	佔 用	佔 先	佔 地	佔 地 位	佔 有	
佔 有 一 席 之 地	佔 有 人	佔 有 物	佔 有 者	佔 有 量	佔 位	佔 位 符	佔 位 置	
佔 住	佔 到	佔 便 宜	佔 著	佔 盡	佔 領	佔 領 市 場	佔 領 者	
佔 領 軍	佔 領 區	佔 據	佔 據 者	佔 優 勢	似 不	似 水 如 魚	似 火	
似 乎	似 乎 是	似 可	似 玉 如 花	似 合 理	似 地	似 有	似 於	
似 的	似 花	似 虎	似 非 而 是	似 是	似 是 而 非	似 為	似 玻 璃	
似 真	似 笑	似 能	似 馬	似 鬼	似 將	似 處 女	似 曾 相 識	
似 象	似 夢	似 漆 如 膠	似 蜜	似 模 似 樣	似 醉 如 癡	似 應	似 懂 非 懂	
似 屬	似 變	但 凡	但 不	但 仍 用 作	但 未	但 如	但 沒	
但 見	但 到	但 卻	但 是	但 能	但 僅	但 當	但 該	
但 願	佣 金	作 了	作 人	作 大	作 文	作 文 法	作 文 集	
作 木 工	作 主	作 出	作 出 了	作 出 努 力	作 出 決 定	作 出 規 定	作 出 評 價	
作 古	作 用	作 用 力	作 用 於	作 用 域	作 先 鋒	作 在	作 奸 犯 科	
作 好	作 如 是 觀	作 成	作 曲	作 曲 家	作 死 馬 醫	作 色	作 伴	
作 別	作 困 獸 鬥	作 坊	作 序	作 序 言	作 弄	作 弄 人	作 秀	
作 見 證	作 些	作 到	作 協	作 官	作 怪	作 拍	作 於	
作 東	作 法	作 法 自 斃	作 物	作 者	作 表	作 保	作 品	
作 品 發 表	作 威	作 威 作 福	作 宣 傳	作 客	作 指 示	作 為	作 美	
作 苦 工	作 風	作 風 修 養	作 家	作 息	作 息 制 度	作 息 時 間	作 料	
作 案	作 祟	作 記 號	作 鬼	作 偽	作 偽 證	作 假	作 帳	
作 得	作 捨 道 邊	作 梗	作 陪	作 鳥 獸 散	作 媒	作 惡 多 端	作 惡 者	
作 揖	作 畫	作 痛	作 答	作 裁 判	作 評 價	作 詞	作 亂	
作 勢	作 嫁	作 愁 相	作 業	作 業 室	作 準	作 準 備	作 詩	
作 詩 法	作 詩 者	作 賊 心 虛	作 過	作 嘔	作 圖	作 圖 解	作 夢	
作 夢 者	作 對	作 弊	作 態	作 福	作 福 作 威	作 價	作 廢	
作 數	作 樂	作 罷	作 賠	作 賤	作 踐	作 壁 上 觀	作 導	
作 戰	作 戰 方 案	作 操	作 興	作 戲	作 聲	作 壞 事	作 繭 自 縛	
作 證	作 難	作 孽	作 響	你 少	你 手	你 方	你 他	
你 去	你 本	你 先	你 先 走	你 多	你 好	你 好 壞	你 死 我 活	
你 自 己	你 別	你 吧	你 吹	你 呀	你 我	你 把	你 姐	
你 爭 我 奪	你 的	你 知 我 知	你 挑	你 是	你 們	你 們 的	你 個	
你 哥	你 家	你 家 人	你 能	你 追 我 趕	你 唱	你 將	你 帶	
你 得	你 猜	你 處	你 部	你 等	你 說	你 編	你 震 地 駭	
你 縣	你 錯 了	你 嚇	你 幫	你 瞧	你 讓	伯 公	伯 父	
伯 母	伯 仲	伯 仲 之 間	伯 伯	伯 克 利	伯 叔	伯 明 翰	伯 俞 泣 杖	
伯 恩	伯 格	伯 祖	伯 婆	伯 勞 飛 燕	伯 道 無 兒	伯 歌 季 舞	伯 樂	
伯 樂 一 顧	伯 爵	伯 爵 夫 人	伯 塤 仲 篪	低 了	低 人	低 人 一 等	低 三 下 四	
低 下	低 工 資	低 分	低 手	低 水 平	低 卡	低 叫	低 平	
低 劣	低 合 金 鋼	低 回	低 地	低 年 級	低 成 本	低 收 入	低 血 壓	
低 估	低 利	低 利 率	低 吟	低 沉	低 谷	低 周 波	低 於	
低 泣	低 空	低 垂	低 度	低 毒	低 限	低 降	低 音	
低 音 部	低 音 管	低 飛	低 首	低 首 下 心	低 倍	低 值	低 息	
低 息 貸 款	低 效	低 效 益	低 效 能	低 效 率	低 氣 壓	低 氧	低 消 耗	
低 級	低 級 階 段	低 級 趣 味	低 耗	低 脂	低 胸	低 能	低 能 兒	
低 能 者	低 迷	低 迷 狀 態	低 唱	低 密	低 密 度 聚 乙 烯	低 得	低 產	
低 產 田	低 處	低 速	低 喻	低 報	低 稅	低 等	低 著	
低 階	低 廉	低 微	低 溫	低 溫 泵	低 溫 計	低 溫 特 報	低 矮	
低 腰	低 落	低 槓	低 碳 鋼	低 窪	低 語	低 語 聲	低 價	
低 層	低 樓	低 潮	低 熱	低 緯 度	低 緩	低 調	低 賤	
低 質 量	低 銷	低 擋	低 燒	低 頸	低 頻	低 頭	低 頭 不 語	
低 頭 喪 氣	低 壓	低 檔	低 聲	低 聲 下 氣	低 聲 說	低 薪	低 點	
低 額	低 欄	低 壩	伶 仃	伶 仃 孤 苦	伶 牙	伶 牙 俐 嘴	伶 牙 俐 齒	
伶 俐	余 子 碌 碌	余 切	余 天	余 火	余 可	余 存	余 妙 繞 樑	
余 步	余 角	余 弦	余 性	余 杭	余 杯 冷 炙	余 物	余 者	
余 勇 可 賈	余 姚	余 政 憲	余 風	余 值	余 料	余 桃 啖 君	余 留	
余 缺	余 割	余 象	余 項	余 業 遺 烈	余 當	余 解	余 膏 剩 馥	
余 熱	余 霞	余 霞 成 綺	余 響 繞 樑	佝 僂	佝 僂 病	佈 告	佈 告 牌	
佈 告 欄	佈 局	佈 防	佈 施	佈 陣	佈 景	佈 置	佈 署	
佈 道 會	佈 雷	佈 雷 艦	佈 滿	佚 名	兌 付	兌 回	兌 成	
兌 取	兌 酒	兌 帳	兌 現	兌 換	兌 換 券	兌 換 率	兌 換 處	
兌 換 業	兌 款	兌 獎	克 人	克 己	克 己 奉 公	克 己 復 禮	克 什 米 爾	
克 分 子	克 分 子 濃 度	克 制	克 拉	克 拉 克	克 拉 查 克	克 拉 瑪 依	克 服	
克 服 困 難	克 服 缺 點	克 東	克 林 頓	克 原 子	克 朗	克 格 勃	克 紹 箕 裘	
克 莉 絲 汀	克 勞	克 勞 蒂 亞 雪 佛	克 萊 斯 勒	克 隆	克 勤 克 儉	克 愛 克 威	克 當 量	
克 裡	克 盡 厥 職	克 儉	克 儉 克 勤	克 敵	克 敵 制 勝	克 羅 地 亞	克 羅 埃 西 亞	
克 難	克 蘭 詩	免 不 了	免 予	免 付	免 去	免 交	免 刑	
免 收	免 局	免 役	免 役 稅	免 受	免 征	免 於	免 俗	
免 冠	免 持	免 為	免 疫	免 疫 力	免 疫 性	免 疫 針	免 疫 學	
免 料	免 租 金	免 納	免 除	免 得	免 掉	免 票	免 報	
免 復	免 提	免 稅	免 貼	免 費	免 費 者	免 進	免 郵 資	
免 開 尊 口	免 罪	免 試	免 罰	免 談	免 課	免 調	免 遭	
免 燙	免 還	免 禮	免 職	免 驗	兵 丁	兵 力	兵 士	
兵 工	兵 工 廠	兵 不 血 刃	兵 不 厭 詐	兵 不 厭 權	兵 戈 相 見	兵 出 無 名	兵 甲	
兵 多 將 廣	兵 戎 相 見	兵 坑	兵 役	兵 役 制 度	兵 役 法	兵 役 等	兵 志	
兵 災	兵 來 將 迎 水 來 土 堰	兵 來 將 敵 水 來 土 堰	兵 制	兵 卒	兵 法	兵 法 家	兵 員	
兵 家	兵 書	兵 站	兵 站 運 輸 線	兵 荒 馬 亂	兵 馬	兵 馬 俑	兵 強 馬 壯	
兵 捨	兵 略	兵 船	兵 連 禍 結	兵 部	兵 場	兵 無 血 刃	兵 痞	
兵 貴 神 速	兵 隊	兵 亂	兵 微 將 寡	兵 源	兵 經	兵 團	兵 禍	
兵 種	兵 種 戰 術	兵 精 糧 足	兵 餉	兵 器	兵 器 工 業	兵 器 工 業 部	兵 學	
兵 營	兵 臨 城 下	兵 籍	兵 艦	兵 權	兵 變	冶 性	冶 金	
冶 金 工 業 部	冶 金 家	冶 金 術	冶 金 部	冶 金 學	冶 金 學 家	冶 容 誨 淫	冶 煉	
冶 煉 廠	冶 葉 倡 條	冶 練	冶 鐵	冶 鑄	冷 下 來	冷 子 管	冷 不 防	
冷 天	冷 水	冷 加 工	冷 光	冷 冰	冷 冰 冰	冷 汗	冷 灰 爆 豆	
冷 色	冷 血	冷 作	冷 冷	冷 冷 清 清	冷 杉	冷 言	冷 言 冷 語	
冷 言 熱 語	冷 板 凳	冷 的	冷 空 氣	冷 軋	冷 門	冷 卻	冷 卻 劑	
冷 卻 器	冷 待	冷 流	冷 眉 冷 眼	冷 若 冰 霜	冷 面	冷 風	冷 食	
冷 凍	冷 凍 空 調	冷 凍 庫	冷 凍 劑	冷 宮	冷 峭	冷 庫	冷 氣	
冷 氣 機	冷 浸	冷 笑	冷 脆	冷 寂	冷 得	冷 淡	冷 清	
冷 清 清	冷 焊	冷 眼	冷 眼 相 看	冷 眼 旁 觀	冷 處 理	冷 透	冷 場	
冷 媒	冷 然	冷 飲	冷 塔	冷 感	冷 暖	冷 暖 自 知	冷 落	
冷 話	冷 遇	冷 槍	冷 漠	冷 語 冰 人	冷 酷	冷 僻	冷 嘲	
冷 嘲 熱 諷	冷 敷	冷 熱	冷 熱 病	冷 盤	冷 箭	冷 鋒	冷 凝	
冷 凝 物	冷 凝 器	冷 戰	冷 燙	冷 諷	冷 靜	冷 餐	冷 澀	
冷 濕	冷 療	冷 縮	冷 霜	冷 藏	冷 藏 間	冷 藏 器	冷 譏 熱 嘲	
冷 颼 颼	冷 鑄	冷 顫	別 了	別 人	別 子	別 心	別 出 心 裁	
別 出 機 杼	別 去	別 打 擾 我	別 犯 傻	別 用	別 再	別 名	別 地	
別 在	別 在 □	別 字	別 式	別 扣	別 有 天 地	別 有 用 心	別 有 肺 腸	
別 有 洞 天	別 有 風 味	別 住	別 克 高 球 邀 請 賽	別 吵	別 把	別 扯	別 走	
別 來 無 恙	別 具 一 格	別 具 只 眼	別 具 匠 心	別 具 特 色	別 具 爐 錘	別 法	別 的	
別 後	別 急	別 是	別 為	別 看	別 胡 說 了	別 胡 鬧	別 風 淮 雨	
別 個	別 哭	別 耽 擱	別 針	別 做	別 動	別 動 隊	別 國	
別 處	別 喊	別 提	別 無 二 致	別 無 他 法	別 無 出 路	別 無 所 求	別 無 長 物	
別 無 選 擇	別 詞	別 開	別 開 生 面	別 傳	別 傻 了	別 意	別 愁 離 恨	
別 號	別 墅	別 彆 扭 扭	別 稱	別 管	別 緊	別 緊 張	別 說	
別 樣	別 緻	別 罵	別 論	別 樹 一 幟	別 離	別 辭	別 類	
別 鶴 孤 鸞	別 鶴 離 鸞	別 戀	判 上	判 令	判 刑	判 別	判 別 式	
判 決	判 決 日	判 決 書	判 例	判 定	判 官	判 明	判 明 是 非	
判 若	判 若 天 淵	判 若 水 火	判 若 兩 人	判 若 雲 泥	判 若 黑 白	判 若 鴻 溝	判 案	
判 處	判 給	判 詞	判 罪	判 據	判 輸	判 優 器	判 斷	
判 斷 力	判 斷 句	判 斷 能 力	判 讀	利 人	利 刃	利 口 酒	利 口 捷 給	
利 川	利 己	利 己 主 義	利 己 癖	利 比 利 亞	利 比 亞	利 比 裡 亞	利 爪	
利 他	利 令 智 昏	利 市	利 市 三 倍	利 民	利 用	利 用 率	利 多	
利 多 消 息	利 多 弊 少	利 好	利 尿	利 尿 劑	利 改 稅	利 辛	利 奇 機 械	
利 於	利 析 秋 毫	利 物 浦	利 空	利 者	利 津	利 派	利 害	
利 差	利 息	利 時	利 益	利 益 輸 送	利 眠	利 索	利 馬	
利 國	利 國 利 民	利 率	利 眼	利 稅	利 稅 分 流	利 華 羊 毛	利 嗦	
利 落	利 弊	利 爾	利 語	利 誘	利 劍	利 嘴	利 慾	
利 慾 熏 心	利 潤	利 潤 留 成	利 潤 率	利 齒	利 齒 伶 牙	利 齒 能 牙	利 器	
利 錢	利 鎖 名 牽	利 鎖 名 韁	利 寶 銀 行	利 權	利 韁 名 鎖	刪 去	刪 改	
刪 削	刪 除	刪 剪	刪 掉	刪 略	刪 減	刪 節	刪 節 本	
刪 蕪 就 簡	刪 繁 就 簡	刨 刀	刨 子	刨 片	刨 平	刨 冰	刨 床	
刨 花	刨 根	刨 根 問 底 兒	刨 圓	劫 九 回 斷	劫 九 迴 腸	劫 出	劫 去	
劫 走	劫 車	劫 取	劫 者	劫 後	劫 後 重 逢	劫 後 餘 生	劫 持	
劫 持 犯	劫 持 者	劫 匪	劫 案	劫 掠	劫 船	劫 富	劫 富 濟 貧	
劫 盜	劫 奪	劫 寨	劫 獄	劫 數	劫 機	劫 機 事 件	劫 機 者	
劫 獲	劫 難	助 人	助 人 為 樂	助 力	助 工	助 手	助 帆	
助 成	助 作	助 我	助 我 張 目	助 攻	助 於	助 長	助 咳	
助 威	助 研	助 紂 為 虐	助 飛	助 飛 器	助 員	助 桀 為 虐	助 消 化	
助 航	助 記 符	助 陣	助 動 詞	助 您	助 推 器	助 教	助 理	
助 理 工 程 師	助 理 員	助 產	助 產 士	助 產 術	助 詞	助 跑	助 群 營 造	
助 編	助 劑	助 學	助 學 金	助 戰	助 燃	助 興	助 選	
助 餐	助 聽	助 聽 器	努 力	努 力 完 成	努 力 做 到	努 力 創 造	努 力 提 高	
努 力 奮 鬥	努 力 學 習	努 牙 突 嘴	努 努 嘴	匣 子	匣 裡 龍 吟	匣 劍 帷 燈	即 已	
即 化	即 日	即 止	即 以 其 人 之 道	即 付	即 令	即 可	即 扔	
即 用	即 由	即 丟	即 回	即 地	即 在	即 有	即 位	
即 告	即 把	即 那	即 使	即 使 是	即 刻	即 或	即 表 示	
即 便	即 按	即 指	即 是	即 為	即 若	即 要	即 席	
即 時	即 納	即 將	即 得	即 從	即 棄	即 被	即 逝	
即 鹿 無 虞	即 景	即 景 生 情	即 期	即 發	即 對	即 論	即 墨	
即 興	即 興 而 作	即 屬	卵 子	卵 生	卵 石	卵 形	卵 形 物	
卵 泡	卵 胎 生	卵 巢	卵 巢 炎	卵 細 胞	卵 殼	卵 裂	卵 黃	
卵 塊	卵 與 石 斗	卵 膜	卵 磷 脂	卵 翼	吝 於	吝 惜	吝 捨	
吝 嗇	吝 嗇 者	吝 嗇 鬼	吭 氣	吭 聲	吭 哧	吞 下	吞 吐	
吞 吐 能 力	吞 吐 量	吞 舟 之 魚	吞 吞 吐 吐	吞 沒	吞 併	吞 服	吞 物	
吞 金	吞 恨	吞 炭 漆 身	吞 食	吞 掉	吞 雲 吐 霧	吞 滅	吞 噬	
吞 噬 細 胞	吞 聲 忍 氣	吞 聲 飲 氣	吞 嚥	吾 人	吾 令	吾 兄	吾 地	
吾 家	吾 等	吾 道 東 矣	吾 爾	吾 輩	否 去 泰 來	否 決	否 決 者	
否 決 權	否 定	否 定 之 否 定	否 定 性	否 定 論	否 則	否 終 而 泰	否 終 則 泰	
否 極 生 泰	否 極 泰 至	否 極 泰 來	否 認	否 認 者	吧 女	吧 間	呆 子	
呆 瓜	呆 立	呆 在	呆 在 家	呆 住	呆 呆	呆 呆 地	呆 板	
呆 看	呆 若 木 雞	呆 帳	呆 得	呆 笨	呆 視	呆 傻	呆 想	
呆 話	呆 滯	呆 賬	呆 頭	呆 頭 呆 腦	呃 逆	吳 下 阿 蒙	吳 牛 喘 月	
吳 市 吹 簫	吳 宇 森	吳 作 棟	吳 伯 雄	吳 君 如	吳 宗 憲	吳 念 真	吳 建 恆	
吳 彥 祖	吳 哥	吳 祚 欽	吳 淡 如	吳 淞	吳 復 連	吳 越	吳 越 同 舟	
吳 頭 楚 尾	呈 上	呈 上 升 趨 勢	呈 文	呈 出	呈 交	呈 函	呈 准	
呈 脈	呈 貢	呈 送	呈 現	呈 祥	呈 報	呈 給	呈 項	
呈 遞	呈 請	呈 閱	呈 應	呈 獻	呈 驗	呂 氏 春 秋	呂 安 題 鳳	
呂 宋	呂 宋 島	呂 秀 蓮	呂 良 偉	呂 良 煥	呂 梁	君 子	君 子 一 言 快 馬 一 鞭	
君 子 之 交 淡 如 水	君 子 協 定	君 子 蘭	君 王	君 主	君 主 立 憲	君 主 制	君 主 國	
君 主 專 制	君 主 權	君 臣	君 臨	君 權	吩 咐	告 一 段 落	告 人	
告 白	告 示	告 成	告 老	告 老 還 鄉	告 別	告 別 宴 會	告 別 詞	
告 別 話	告 別 儀 式	告 別 辭	告 吹	告 戒	告 狀	告 知	告 者	
告 急	告 朔 餼 羊	告 病	告 退	告 假	告 密	告 密 者	告 捷	
告 終	告 牌	告 發	告 訴	告 罪	告 解	告 語	告 誡	
告 慰	告 罄	告 謝	告 辭	告 警	告 饒	告 欄	吹 入	
吹 口 哨	吹 大 法 螺	吹 大 氣	吹 毛 求 疵	吹 毛 求 瑕	吹 毛 索 疵	吹 火	吹 牛	
吹 牛 皮	吹 牛 老 爹	吹 牛 拍 馬	吹 牛 專 家	吹 出	吹 去	吹 打	吹 光	
吹 向	吹 成	吹 灰	吹 灰 之 力	吹 冷 風	吹 吹	吹 吹 打 打	吹 吹 拍 拍	
吹 走	吹 拂	吹 法	吹 泡	吹 奏	吹 風	吹 風 機	吹 倒	
吹 哨	吹 氣	吹 氣 勝 蘭	吹 消	吹 起	吹 動	吹 捧	吹 掉	
吹 掃	吹 笛	吹 笛 子	吹 笛 者	吹 進	吹 開	吹 滅	吹 煉	
吹 號	吹 遍	吹 鼓 手	吹 熄	吹 管	吹 噓	吹 影 鏤 塵	吹 皺 一 池 春 水	
吹 點	吹 簫	吹 霧	吹 鬍 子 瞪 眼	吹 響	吹 襲	吻 手	吻 合	
吻 別	吸 了	吸 入	吸 入 者	吸 入 量	吸 入 劑	吸 入 器	吸 力	
吸 上	吸 小	吸 允	吸 孔	吸 引	吸 引 人	吸 引 力	吸 引 外 資	
吸 引 物	吸 引 著	吸 水	吸 出	吸 出 器	吸 奶	吸 收	吸 收 比	
吸 收 外 資	吸 收 光 譜	吸 收 性	吸 收 度	吸 收 率	吸 收 劑	吸 收 器	吸 收 體	
吸 血	吸 血 鬼	吸 住	吸 吮	吸 到	吸 取	吸 取 教 訓	吸 法	
吸 附	吸 附 劑	吸 毒	吸 毒 者	吸 食	吸 氣	吸 氧	吸 納	
吸 起	吸 乾	吸 著	吸 著 物	吸 著 劑	吸 進	吸 煙	吸 煙 者	
吸 煙 室	吸 飽	吸 塵	吸 塵 器	吸 管	吸 熱	吸 熱 性	吸 盤	
吸 墨 紙	吸 濕	吸 聲	吸 蟲	吮 吸	吮 乳	吮 乾	吮 癰 舐 痔	
吵 吵	吵 吵 鬧 鬧	吵 吵 嚷 嚷	吵 者	吵 架	吵 得	吵 著	吵 過	
吵 嘴	吵 鬧	吵 鬧 聲	吵 醒	吵 翻	吵 雜	吵 嚷	吶 喊	
吠 月	吠 叫	吠 吠	吠 形 吠 聲	吠 非 其 主	吠 影 吠 聲	吠 聲	吼 出	
吼 叫	吼 道	吼 聲	呀 呀	吱 叫	吱 吾	吱 吱	吱 吱 叫	
吱 吱 響	吱 唔	吱 喳	吱 聲	吱 響	含 山	含 水	含 水 量	
含 水 層	含 石 油	含 在	含 多	含 有	含 有 量	含 而 不 露	含 血 噴 人	
含 吞	含 含 糊 糊	含 沙	含 沙 射 影	含 辛 茹 苦	含 於	含 油	含 金	
含 金 量	含 垢 忍 恥	含 垢 忍 辱	含 垢 納 污	含 垢 藏 疾	含 怒	含 恨	含 括	
含 毒	含 英 咀 華	含 苞	含 苞 待 放	含 苞 欲 放	含 冤	含 冤 負 屈	含 哺 鼓 腹	
含 氣	含 氧	含 氧 酸	含 病 毒	含 笑	含 笑 九 泉	含 笑 入 地	含 酒 精	
含 情 脈 脈	含 混	含 混 不 清	含 淚	含 羞	含 羞 草	含 雪	含 無	
含 著	含 量	含 鈣	含 意	含 義	含 飴 弄 孫	含 碳	含 蓄	
含 酸	含 糊	含 糊 不 清	含 糊 其 辭	含 鴉 片	含 齒 戴 發	含 糖	含 濕 氣	
含 蘊	含 鐵	含 鐵 質	含 纖 維	含 鹼	含 鹽 量	含 蓼 問 疾	吟 子 打 死	
吟 味	吟 風 弄 月	吟 風 詠 月	吟 唱	吟 唱 者	吟 詠	吟 詩	吟 遊	
吟 頌	吟 誦	吟 篇	困 人	困 厄	困 心 衡 慮	困 乏	困 守	
困 死	困 住	困 局	困 於	困 知 勉 行	困 苦	困 迫	困 時	
困 惑	困 惱	困 窘	困 頓	困 境	困 憊	困 擾	困 繞	
困 獸	困 獸 猶 斗	困 鏡	困 難	困 難 戶	困 難 重 重	囤 積	囤 積 居 奇	
囤 積 者	囫 圇	囫 圇 吞 棗	坑 人	坑 口	坑 內	坑 木	坑 穴	
坑 坑 窪 窪	坑 洞	坑 害	坑 裡	坑 道	坑 蒙 拐 騙	坑 儒	坑 騙	
坍 方	坍 惡 不 赦	坍 塌	均 一	均 已	均 不	均 不 能	均 分	
均 勻	均 以	均 占	均 可	均 未	均 用	均 田	均 由	
均 列	均 收	均 有	均 享	均 依	均 受	均 居	均 按	
均 指	均 為	均 相	均 要	均 重	均 值	均 能	均 被	
均 設	均 貧	均 富	均 無	均 等	均 等 性	均 須	均 勢	
均 達	均 稱	均 與	均 豪 精 密	均 需	均 數	均 熱	均 質	
均 遭	均 據	均 衡	均 衡 生 產	均 衡 性	均 衡 說	均 衡 器	均 應	
均 屬	均 攤	均 權	均 權 制 度	坎 井 之 蛙	坎 比	坎 兒	坎 兒 井	
坎 坷	坎 肩	坎 城	坎 培 拉	坎 窪	坐 了	坐 下	坐 上	
坐 大	坐 山	坐 山 看 虎 鬥	坐 山 觀 虎 鬥	坐 不 安 席	坐 不 垂 堂	坐 不 窺 堂	坐 井	
坐 井 觀 天	坐 化	坐 支	坐 月 子	坐 木 筏	坐 以 待 旦	坐 以 待 斃	坐 功	
坐 失	坐 失 良 機	坐 立	坐 立 不 安	坐 向	坐 吃 山 空	坐 吃 山 崩	坐 地 分 贓	
坐 在	坐 好	坐 守	坐 收	坐 收 漁 利	坐 此	坐 而 待 旦	坐 而 待 斃	
坐 而 論 道	坐 位	坐 冷 板 凳	坐 吧	坐 呀	坐 牢	坐 言 起 行	坐 車	
坐 享 其 成	坐 到	坐 取	坐 定	坐 往	坐 的 人	坐 者	坐 臥	
坐 臥 不 安	坐 臥 不 寧	坐 姿	坐 待	坐 背	坐 倒	坐 席	坐 浴	
坐 起	坐 骨	坐 骨 神 經	坐 商	坐 得	坐 探	坐 票	坐 船	
坐 莊	坐 椅	坐 無 車 公	坐 等	坐 著	坐 視	坐 視 不 救	坐 視 成 敗	
坐 會	坐 落	坐 墊	坐 慣	坐 滿	坐 標	坐 標 軸	坐 艙	
坐 禪	坐 薪 嘗 膽	坐 薪 懸 膽	坐 鎮	坐 騎	坐 懷 不 亂	坐 籌 帷 幄	坐 觀	
坐 觀 成 敗	壯 丁	壯 士	壯 士 解 腕	壯 士 斷 腕	壯 大	壯 工	壯 心	
壯 心 不 已	壯 年	壯 志	壯 志 未 酬	壯 志 凌 雲	壯 的	壯 美	壯 苗	
壯 氣 吞 牛	壯 烈	壯 健	壯 族	壯 圍	壯 圍 鄉	壯 陽 劑	壯 實	
壯 碩	壯 語	壯 膽	壯 舉	壯 闊	壯 麗	壯 麗 堂 皇	壯 觀	
夾 七 夾 八	夾 了	夾 入	夾 上	夾 子	夾 心	夾 生	夾 生 飯	
夾 石	夾 竹 桃	夾 衣	夾 住	夾 克	夾 攻	夾 牢	夾 角	
夾 具	夾 板	夾 持	夾 指	夾 背	夾 套	夾 起	夾 針	
夾 帶	夾 敘	夾 被	夾 袍	夾 袋 中 人 物	夾 棍	夾 棉 衣	夾 痛	
夾 著	夾 菜	夾 道	夾 道 歡 迎	夾 鉗	夾 緊	夾 層	夾 盤	
夾 擊	夾 縫	夾 雜	夾 襖	妒 火 中 燒	妒 忌	妒 恨	妒 嫉	
妒 意	妒 賢 疾 能	妒 賢 嫉 能	妨 害	妨 害 公 務	妨 害 公 務 罪	妨 害 者	妨 害 風 化	
妨 害 風 化 罪	妨 訴	妨 礙	妨 礙 者	妞 妞	妙 人	妙 不	妙 不 可 言	
妙 手	妙 手 丹 青	妙 手 回 春	妙 手 空 空	妙 方	妙 句	妙 用	妙 言 要 道	
妙 事	妙 法	妙 哉	妙 思	妙 計	妙 理	妙 處	妙 處 不 傳	
妙 訣	妙 喻 取 譬	妙 棋	妙 策	妙 筆	妙 絕	妙 絕 一 時	妙 絕 時 人	
妙 想	妙 極	妙 極 了	妙 境	妙 算	妙 舞 清 歌	妙 語	妙 語 連 珠	
妙 語 解 頤	妙 論	妙 趣	妙 趣 橫 生	妙 趣 橫 溢	妙 藥	妙 辭	妙 齡	
妖 人	妖 女	妖 由 人 興	妖 似	妖 冶	妖 形 怪 狀	妖 言	妖 言 惑 眾	
妖 邪	妖 怪	妖 法	妖 物	妖 風	妖 氣	妖 婦	妖 教	
妖 術	妖 媚	妖 裡 妖 氣	妖 道	妖 精	妖 嬈	妖 鏡	妖 孽	
妖 魔	妖 魔 鬼 怪	妖 艷	妍 皮 癡 骨	妓 女	妓 院	妊 娠	妊 娠 前	
妊 婦	妥 用	妥 否	妥 妥	妥 妥 貼 貼	妥 協	妥 帖	妥 為	
妥 善	妥 善 安 置	妥 善 處 理	妥 善 解 決	妥 貼	妥 當	妥 當 性	妥 實	
妥 靠	孝 女	孝 子	孝 子 順 孫	孝 子 慈 孫	孝 子 賢 孫	孝 心	孝 行	
孝 衣	孝 男	孝 服	孝 祥	孝 順	孝 廉	孝 感	孝 敬	
孝 經 起 序	孝 道	孜 孜	孜 孜 不 怠	孜 孜 不 倦	孜 孜 以 求	完 了	完 人	
完 小	完 工	完 全	完 全 可 以	完 全 可 能	完 全 必 要	完 全 正 確	完 全 同 意	
完 全 性	完 全 符 合	完 全 避 免	完 好	完 好 率	完 好 無 損	完 成	完 成 任 務	
完 成 式	完 成 時	完 完 全 全	完 形	完 事	完 美	完 美 無 缺	完 美 無 瑕	
完 值	完 婚	完 畢	完 蛋	完 備	完 場	完 稅	完 結	
完 善	完 滿	完 稿	完 膚	完 壁	完 整	完 整 性	完 整 無 缺	
完 整 無 損	完 璧	完 璧 歸 趙	完 糧	宋 元	宋 少 卿	宋 斤 魯 削	宋 代	
宋 史	宋 明	宋 書	宋 朝	宋 畫 吳 冶	宋 詞	宋 楚 瑜	宋 詩	
宋 學	宋 濤	宋 體	宋 體 字	宏 大	宏 代 碼	宏 功 能	宏 巨 建 設	
宏 光	宏 名	宏 旨	宏 壯	宏 亞 食 品	宏 命 令	宏 東 洋 實	宏 亮	
宏 指 令	宏 恩	宏 效	宏 泰 電 工	宏 益 纖 維	宏 偉	宏 偉 目 標	宏 盛 建 設	
宏 都 拉 斯	宏 都 建 設	宏 揚	宏 普 建 設	宏 程 序	宏 匯	宏 彙 編	宏 業	
宏 圖	宏 圖 大 略	宏 福 建 設	宏 遠 興 業	宏 論	宏 璟 建 設	宏 錄	宏 總 建 設	
宏 願	宏 麗	宏 觀	宏 觀 世 界	宏 觀 能 力	宏 觀 控 制	宏 觀 經 濟	宏 觀 經 濟 學	
宏 觀 圖	宏 觀 管 理	宏 觀 調 控	宏 觀 調 節	宏 �� 科 技	宏 �� 電 腦	局 子	局 內	
局 外	局 外 人	局 委	局 長	局 限	局 限 性	局 限 於	局 面	
局 級	局 域	局 域 網	局 部	局 部 化	局 部 地 區	局 部 利 益	局 部 戰 爭	
局 勢	局 勢 穩 定	局 饕	屁 用	屁 股	屁 眼	屁 話	屁 滾 尿 流	
屁 精	尿 失 禁	尿 布	尿 布 疹	尿 布 墊	尿 床	尿 泡	尿 炕	
尿 肥	尿 花	尿 毒	尿 毒 症	尿 流 屁 滾	尿 盆	尿 素	尿 液	
尿 閉	尿 壺	尿 路 結 石	尿 路 腫 瘤	尿 道	尿 道 炎	尿 管	尿 酸	
尿 頻	尾 大 不 掉	尾 大 難 掉	尾 巴	尾 欠	尾 羽	尾 板	尾 注	
尾 狀 物	尾 花	尾 流	尾 苗	尾 音	尾 座	尾 氣	尾 追	
尾 酒	尾 骨	尾 部	尾 款	尾 端	尾 語	尾 數	尾 燈	
尾 隨	尾 擊	尾 翼	尾 聲	尾 礦	尾 鰭	岐 視	岐 點	
岔 口	岔 子	岔 尾	岔 河	岔 氣	岔 眼	岔 開	岔 路	
岔 路 口	岔 道	岌 岌	岌 岌 可 危	巫 山	巫 山 洛 水	巫 山 雲 雨	巫 山 落 浦	
巫 峽	巫 師	巫 師 隊	巫 神	巫 婆	巫 術	巫 醫	希 世 之 珍	
希 有	希 求	希 罕	希 里 嘩 啦	希 奇	希 拉 蕊	希 特 勒	希 望	
希 望 有	希 斯 里	希 華 晶 體	希 圖	希 爾	希 爾 頓	希 冀	希 臘	
希 臘 人	希 臘 王	希 臘 神 話	希 臘 語	序 文	序 列	序 名	序 曲	
序 位	序 言	序 時	序 跋	序 號	序 詩	序 幕	序 漸	
序 數	序 樂	序 論	序 戰	庇 佑	庇 蔭	庇 護	庇 護 所	
床	床 下	床 下 安 床	床 上	床 上 用 品	床 上 安 床	床 上 施 床	床 子	
床 位	床 身	床 板	床 沿	床 柱	床 架	床 旅	床 側	
床 第 之 私	床 被	床 單	床 罩	床 腳	床 號	床 墊	床 榻	
床 褥	床 頭	床 頭 板	床 頭 金 盡	床 邊	床 舖	廷 杖	廷 爭 面 折	
廷 尉	弄 人	弄 上	弄 口 鳴 舌	弄 小	弄 不 好	弄 不 清	弄 月 嘲 風	
弄 月 摶 風	弄 水	弄 出	弄 巧	弄 巧 成 拙	弄 平	弄 玉 偷 香	弄 瓦	
弄 瓦 之 喜	弄 白	弄 好	弄 成	弄 成 一 團	弄 死	弄 污	弄 臣	
弄 兵	弄 兵 潢 池	弄 弄	弄 走	弄 到	弄 到 手	弄 性 尚 氣	弄 斧 班 門	
弄 昏	弄 法	弄 法 舞 文	弄 直	弄 垮	弄 姿	弄 歪	弄 苦	
弄 倒	弄 凌 亂	弄 破	弄 粉 調 朱	弄 鬼	弄 鬼 妝 么	弄 鬼 掉 猴	弄 乾	
弄 乾 淨	弄 假	弄 假 成 真	弄 堂	弄 得	弄 得 清	弄 斜	弄 淡	
弄 清	弄 清 楚	弄 混	弄 甜	弄 粗	弄 細	弄 蛇	弄 蛇 者	
弄 通	弄 喧 搗 鬼	弄 痛	弄 短	弄 筆	弄 著	弄 虛	弄 虛 作 假	
弄 鈍	弄 開	弄 飯	弄 黑	弄 亂	弄 傷	弄 圓	弄 暗	
弄 盞 傳 杯	弄 碎	弄 槍	弄 熄	弄 僵	弄 嘴 弄 舌	弄 寬	弄 潮	
弄 熱	弄 璋 之 喜	弄 璋 之 慶	弄 皺	弄 確 實	弄 窮	弄 糊 塗	弄 醉	
弄 整 潔	弄 縐	弄 醒	弄 錯	弄 錢	弄 懂	弄 濕	弄 糟	
弄 斷	弄 翻	弄 壞	弄 壞 了	弄 壞 事	弄 彎	弄 彎 曲	弄 權	
弄 髒	弄 髒 了	弟 子	弟 兄	弟 兄 們	弟 弟	弟 妹	弟 婦	
弟 媳	弟 親	彤 彤	彤 雲	形 只 影 單	形 石	形 同	形 同 虛 設	
形 好	形 如	形 式	形 式 上	形 式 化	形 式 主 義	形 式 多 樣	形 式 邏 輯	
形 成	形 成 核	形 成 層	形 而	形 而 上 學	形 似	形 形 色 色	形 物	
形 狀	形 狀 好	形 的	形 音	形 容	形 容 詞	形 旁	形 格 勢 禁	
形 單	形 單 影 隻	形 象	形 象 化	形 象 思 維	形 象 清 新	形 勢	形 勢 教 育	
形 勢 發 展	形 勢 逼 人	形 義	形 跡	形 跡 可 疑	形 像	形 像 化	形 圖	
形 態	形 態 上	形 態 美	形 態 論	形 態 學	形 貌	形 影	形 影 不 離	
形 影 相 吊	形 影 相 依	形 影 相 追	形 影 相 隨	形 影 相 顧	形 碼	形 銷 骨 立	形 牆	
形 聲	形 穢	形 蟲	形 變	形 體	形 體 化	彷 彿	彷 徨	
役 男	役 使	役 制	役 卒	役 法	役 長	役 政 司	役 畜	
役 齡	忘 了	忘 不	忘 不 了	忘 乎 所 以	忘 本	忘 生 捨 死	忘 年	
忘 年 之 交	忘 年 之 好	忘 年 之 契	忘 年 交	忘 形	忘 形 之 交	忘 形 之 契	忘 我	
忘 我 工 作	忘 我 勞 動	忘 我 精 神	忘 私	忘 事	忘 其 所 以	忘 性	忘 返	
忘 卻	忘 恩	忘 恩 失 義	忘 恩 背 義	忘 恩 負 義	忘 神	忘 記	忘 記 了	
忘 啦	忘 帶	忘 情	忘 掉	忘 象 得 意	忘 寢 廢 食	忘 憂	忘 戰 必 危	
忘 戰 者 危	忘 餐 失 寢	忘 餐 廢 寢	忘 舊	忘 懷	忌 口	忌 日	忌 妒	
忌 辰	忌 食	忌 酒	忌 語	忌 嘴	忌 憚	忌 諱	忌 醫	
志 士	志 士 仁 人	志 大 才 疏	志 大 才 短	志 同 道 合	志 向	志 在	志 在 千 里	
志 在 四 方	志 沖 鬥 牛	志 足 意 滿	志 於	志 信 運 輸	志 哀	志 氣	志 氣 凌 雲	
志 高 氣 揚	志 得 意 滿	志 聖 工 業	志 誠 君 子	志 滿 氣 得	志 廣 才 疏	志 趣	志 聯 工 業	
志 薄	志 願	志 願 人 員	志 願 兵	志 願 者	志 願 軍	志 願 書	志 驕 意 滿	
忍 下	忍 不 住	忍 心	忍 心 害 理	忍 住	忍 受	忍 性	忍 俊 不 禁	
忍 垢 偷 生	忍 耐	忍 耐 力	忍 恥 含 垢	忍 恥 含 羞	忍 恥 偷 生	忍 氣	忍 氣 吞 聲	
忍 笑	忍 辱	忍 辱 含 垢	忍 辱 含 羞	忍 辱 求 全	忍 辱 負 重	忍 辱 偷 生	忍 得 住	
忍 從	忍 無 可 忍	忍 痛	忍 痛 割 愛	忍 著	忍 饑 受 渴	忍 饑 受 餓	忍 饑 挨 餓	
忍 讓	快 了	快 人	快 人 快 事	快 人 快 語	快 刀	快 刀 斬 亂 麻	快 干	
快 中 子	快 手	快 叫	快 件	快 吃	快 好	快 死	快 而	
快 舌	快 別	快 快	快 快 樂 樂	快 把	快 攻	快 步	快 步 走	
快 步 流 星	快 步 跑	快 走	快 車	快 車 道	快 事	快 些	快 來	
快 到	快 取	快 拍	快 於	快 板	快 的	快 門	快 門 兒	
快 信	快 活	快 活 人	快 看	快 要	快 書	快 班	快 訊	
快 追	快 馬	快 馬 加 鞭	快 得 多	快 捷	快 捷 方 式	快 捷 鍵	快 球	
快 船	快 速	快 速 反 應	快 速 道 路	快 報	快 婿	快 跑	快 進	
快 郵	快 意	快 感	快 溺 死	快 滑	快 照	快 當	快 艇	
快 慢	快 槍	快 種	快 說	快 遞	快 嘴	快 慰	快 樂	
快 樂 島	快 樂 論	快 餐	快 餐 店	快 檔	快 點	快 轉	忸 怩	
忸 怩 作 態	忸 暱	戒 尺	戒 心	戒 去	戒 色	戒 忌	戒 性	
戒 者	戒 勉	戒 律	戒 急 用 忍	戒 指	戒 毒	戒 書	戒 酒	
戒 除	戒 掉	戒 棄	戒 條	戒 備	戒 備 狀 態	戒 備 森 嚴	戒 絕	
戒 煙	戒 禁	戒 賭	戒 嚴	戒 嚴 令	戒 嚴 部 隊	戒 懼	戒 驕	
戒 驕 戒 躁	我 一	我 了	我 人	我 方	我 台	我 向	我 回 五 次	
我 自 己	我 行 我 素	我 吧	我 呀	我 局	我 把	我 見 猶 憐	我 抱	
我 爸	我 的	我 咬	我 娃	我 省	我 看	我 軍	我 倆	
我 們	我 們 自 己	我 剛	我 哥	我 家	我 校	我 院	我 國	
我 從	我 眼	我 處	我 喜	我 等	我 給	我 媽	我 意	
我 愛	我 廠	我 輩	我 醉 欲 眠	我 親 自	我 黨	我 黨 我 軍	抄 公	
抄 手	抄 本	抄 用	抄 件	抄 列	抄 回	抄 在	抄 收	
抄 抄	抄 走	抄 身	抄 近	抄 查	抄 家	抄 書	抄 送	
抄 送 單 位	抄 斬	抄 報	抄 發	抄 集	抄 道	抄 寫	抄 寫 者	
抄 寫 員	抄 錄	抄 獲	抄 襲	抗 力	抗 大	抗 干 擾	抗 反 射	
抗 日	抗 日 救 國	抗 日 戰 爭	抗 火	抗 生	抗 生 素	抗 用	抗 血 清	
抗 旱	抗 災	抗 命	抗 性	抗 拒	抗 拒 從 嚴	抗 爭	抗 毒	
抗 毒 性	抗 毒 素	抗 洪	抗 洪 救 災	抗 洪 搶 險	抗 活	抗 美	抗 美 援 朝	
抗 風	抗 倒 伏	抗 倭 鬥 爭	抗 原	抗 捐	抗 氧	抗 氧 化	抗 氧 劑	
抗 病	抗 逆 性	抗 排 斥 藥 物	抗 寒	抗 稅	抗 著	抗 菌	抗 菌 法	
抗 菌 素	抗 菌 劑	抗 訴	抗 感 染	抗 溶	抗 溶 劑	抗 過	抗 塵 走 俗	
抗 磁	抗 酸	抗 敵	抗 暴	抗 熱	抗 震	抗 震 性	抗 震 救 災	
抗 凝	抗 凝 固	抗 戰	抗 禦	抗 衡	抗 靜 電	抗 壓	抗 擊	
抗 癌	抗 禮	抗 蟲	抗 壞 血 酸	抗 繳	抗 藥	抗 藥 性	抗 議	
抗 議 者	抗 辯	抗 辯 人	抗 辯 者	抗 體	抗 鹼	抗 澇	抖 出	
抖 去	抖 松	抖 索	抖 動	抖 著	抖 開	抖 亂	抖 落	
抖 摟	抖 縮	抖 擻	抖 翻	技 士	技 工	技 工 貿	技 工 學 校	
技 巧	技 巧 運 動	技 改	技 法	技 師	技 校	技 能	技 能 上	
技 能 檢 定	技 高 一 籌	技 措	技 術	技 術 上	技 術 交 流	技 術 性	技 術 咨 詢	
技 術 室	技 術 科	技 術 革 命	技 術 革 新	技 術 員	技 術 家	技 術 部	技 術 發 展	
技 術 開 發 部	技 術 標 準	技 術 學 校	技 術 學 院	技 貿	技 嘉 科 技	技 窮	技 壓 群 芳	
技 壓 群 雄	技 擊	技 藝	技 藝 家	扶 手	扶 正	扶 正 黜 邪	扶 正 祛 邪	
扶 危 定 亂	扶 危 定 傾	扶 危 拯 溺	扶 危 救 困	扶 危 濟 困	扶 危 翼 傾	扶 她	扶 老 攜 幼	
扶 住	扶 余	扶 助	扶 直	扶 恤 金	扶 持	扶 風	扶 弱 助 殘	
扶 桑	扶 病	扶 起	扶 梯	扶 疏	扶 貧	扶 椅	扶 植	
扶 善 懲 惡	扶 著	扶 傾 濟 弱	扶 搖 直 上	扶 溝	扶 綏	扶 輪 社	扶 養	
扶 養 者	扶 養 費	扶 壁	扶 牆	扶 牆 摸 壁	扶 織	扶 顛 持 危	扶 欄	
扶 靈	抉 瑕 掩 瑜	抉 擇	扭 了	扭 力	扭 下	扭 手 扭 腳	扭 斗	
扭 出	扭 去	扭 打	扭 回	扭 成	扭 曲	扭 曲 作 直	扭 住	
扭 扭	扭 扭 捏 捏	扭 身	扭 卷	扭 股	扭 是 為 非	扭 歪	扭 倒	
扭 捏	扭 矩	扭 秤	扭 秧 歌	扭 送	扭 動	扭 得	扭 痛	
扭 絞	扭 絞 者	扭 結	扭 著	扭 開	扭 傷	扭 搭	扭 腰	
扭 緊	扭 頭	扭 頭 別 項	扭 臉	扭 虧	扭 虧 為 盈	扭 虧 為 贏	扭 虧 增 盈	
扭 擺	扭 斷	扭 轉	扭 轉 局 面	扭 轉 乾 坤	扭 彎	把 子	把 手	
把 兄 弟	把 在	把 好	把 守	把 式	把 住	把 你	把 完	
把 尿	把 弄	把 抓	把 牢	把 兒	把 於	把 玩	把 玩 無 厭	
把 門	把 持	把 持 不 定	把 柄	把 風	把 素 持 齋	把 脈	把 酒	
把 舵	把 握	把 給	把 飯 叫 饑	把 勢	把 頭	把 戲	把 臂 入 林	
把 穩	把 關	扼 守	扼 死	扼 住	扼 吭 拊 背	扼 制	扼 流 圈	
扼 要	扼 殺	扼 殺 者	扼 腕	扼 臂	找 了	找 人	找 上 門 來	
找 工 作	找 不 著	找 他	找 出	找 平	找 回	找 死	找 我	
找 找	找 那	找 事	找 些	找 來	找 到	找 到 了	找 空	
找 個	找 准	找 時	找 病	找 得 著	找 麻 煩	找 尋	找 著	
找 補	找 話	找 遍	找 齊	找 誰	找 錯	找 錢	找 頭	
找 還	找 點 事 幹	找 點 活 干	找 竅 門	找 茬	批 亢 搗 虛	批 文	批 斗	
批 毛 求 疵	批 示	批 件	批 回	批 次	批 死	批 判	批 判 者	
批 改	批 注	批 紅 判 白	批 風 抹 月	批 准	批 准 者	批 准 書	批 條	
批 條 子	批 處 理	批 貨	批 復	批 發	批 發 市 場	批 發 商	批 發 部	
批 發 價 格	批 給	批 評	批 評 性	批 評 指 正	批 評 家	批 評 與 自 我 批 評	批 量	
批 量 生 產	批 號	批 語	批 駁	批 審	批 閱	批 辦	批 購	
批 轉	批 驗	扳 子	扳 手	扳 回	扳 動	扳 開	扳 道	
扳 道 員	扳 鉗	扳 閘	扳 緊	扳 機	扳 頭	抒 情	抒 情 詩	
抒 發	抒 意	抒 解	抒 寫	抒 懷	扯 了	扯 下	扯 上	
扯 手	扯 去	扯 平	扯 白	扯 皮	扯 成	扯 住	扯 到	
扯 拉	扯 直	扯 空 砑 光	扯 後	扯 後 腿	扯 倒	扯 破	扯 起	
扯 起 來	扯 掉	扯 淡	扯 著	扯 裂	扯 進	扯 開	扯 閒	
扯 碎	扯 鈴	扯 鼓 奪 旗	扯 旗	扯 遠	扯 談	扯 篷 拉 縴	扯 謊	
扯 斷	扯 離	折 刀	折 子 戲	折 小	折 中	折 中 主 義	折 反	
折 尺	折 半	折 本	折 光	折 向	折 合	折 回	折 成	
折 扣	折 扣 戰	折 曲	折 行	折 兌	折 床	折 沖 尊 俎	折 沖 厭 難	
折 沖 禦 侮	折 角	折 受	折 抵	折 服	折 枝	折 物	折 股	
折 返	折 長 補 短	折 信	折 柳 攀 花	折 迭	折 頁	折 倒	折 射	
折 射 性	折 射 計	折 射 器	折 扇	折 桂 攀 蟾	折 秤	折 紙	折 耗	
折 衷	折 衷 派	折 起	折 殺	折 現	折 痕	折 傘	折 戟	
折 戟 沉 沙	折 椅	折 款	折 損	折 節 下 士	折 節 待 士	折 節 禮 士	折 腰	
折 腰 五 斗	折 腰 升 斗	折 號	折 凳	折 壽	折 福	折 算	折 價	
折 皺	折 箭	折 線	折 磨	折 縫	折 斷	折 斷 撉	折 舊	
折 舊 率	折 舊 費	折 轉	折 邊	折 騰	折 彎	折 疊	折 疊 式	
折 讓	扮 白	扮 成	扮 作	扮 男	扮 的	扮 相	扮 個	
扮 鬼	扮 做	扮 得	扮 裝	扮 像	扮 演	扮 演 者	扮 戲	
投 入	投 入 市 場	投 入 生 產	投 入 產 出	投 下	投 山 竄 海	投 中	投 井	
投 井 下 石	投 戈 講 藝	投 手	投 木 報 瓊	投 水	投 以	投 出	投 去	
投 石	投 石 下 井	投 石 者	投 石 問 路	投 石 器	投 向	投 合	投 回	
投 考	投 考 者	投 身	投 身 於	投 阱 下 石	投 其 所 好	投 函	投 到	
投 奔	投 放	投 放 市 場	投 於	投 明	投 杼 之 感	投 杼 之 疑	投 杼 市 虎	
投 注	投 河	投 河 奔 井	投 河 覓 井	投 股	投 信	投 保	投 保 人	
投 看	投 胎	投 軍	投 降	投 降 書	投 射	投 射 物	投 師	
投 效	投 料	投 書	投 案	投 案 自 首	投 桃 之 報	投 桃 報 李	投 海	
投 袂 而 起	投 袂 荷 戈	投 袂 援 戈	投 送	投 寄	投 宿	投 宿 者	投 棄	
投 梭	投 梭 折 齒	投 殺	投 球	投 產	投 票	投 票 人	投 票 所	
投 票 者	投 票 數	投 票 權	投 報	投 壺	投 筆	投 筆 從 戎	投 筆 膚 談	
投 訴	投 訴 者	投 訴 信	投 進	投 閒 置 散	投 誠	投 資	投 資 者	
投 資 氣 氛	投 資 規 模	投 資 銀 行	投 資 數	投 資 選 擇	投 資 環 境	投 資 總 額	投 資 額	
投 鼠 之 忌	投 鼠 忌 器	投 幣	投 幣 孔	投 槍	投 膏 止 火	投 遞	投 遞 送	
投 彈	投 彈 手	投 彈 員	投 影	投 影 面	投 影 機	投 敵	投 標	
投 標 人	投 標 者	投 稿	投 稿 者	投 緣	投 靠	投 機	投 機 取 巧	
投 機 者	投 機 倒 把	投 機 商	投 親	投 親 靠 友	投 錢 戲	投 擊	投 環	
投 擲	投 擲 者	投 鞭 斷 流	投 藥	投 籃	投 欄	投 顧	投 顧 投 信	
投 畀 豺 虎	抓 了	抓 人	抓 斗	抓 出	抓 去	抓 好	抓 尖 要 強	
抓 耳 搔 腮	抓 耳 撓 腮	抓 住	抓 牢	抓 走	抓 到	抓 取	抓 背 用	
抓 苗 頭	抓 差	抓 破	抓 起	抓 得	抓 掀	抓 痕	抓 握	
抓 著	抓 詞	抓 傷	抓 過	抓 鉤	抓 緊	抓 緊 抓 好	抓 綱	
抓 撓	抓 瞎	抓 賭	抓 頭 挖 耳	抓 獲	抓 舉	抓 點	抓 藥	
抓 癢	抓 辮 子	抓 鬮	抑 止	抑 低	抑 抑	抑 制	抑 制 物	
抑 制 者	抑 制 劑	抑 制 器	抑 或	抑 是	抑 音	抑 格	抑 強 扶 弱	
抑 惡 揚 善	抑 揚	抑 揚 頓 挫	抑 菌	抑 貶	抑 塞 磊 落	抑 壓	抑 壓 者	
抑 壓 器	抑 鬱	抑 鬱 不 樂	抑 鬱 寡 歡	改 口	改 小	改 之	改 元	
改 天	改 天 換 地	改 日	改 打	改 正	改 正 缺 點	改 正 錯 誤	改 玉 改 行	
改 用	改 由	改 任	改 向	改 名	改 名 易 姓	改 名 換 姓	改 回	
改 成	改 次	改 行	改 行 遷 善	改 作	改 判	改 改	改 步 改 玉	
改 良	改 良 主 義	改 良 者	改 良 品 種	改 良 派	改 邪	改 邪 歸 正	改 制	
改 姓	改 姓 更 名	改 弦 更 張	改 弦 易 調	改 弦 易 轍	改 弦 換 張	改 易	改 版	
改 信	改 俗 遷 風	改 則	改 型	改 建	改 為	改 訂	改 述	
改 革	改 革 者	改 革 派	改 革 家	改 乘	改 修	改 悔	改 記	
改 做	改 動	改 寄	改 帳	改 張 易 調	改 掉	改 產	改 組	
改 習	改 造	改 造 社 會	改 造 思 想	改 途	改 惡 向 善	改 惡 行 善	改 惡 從 善	
改 換	改 換 門 庭	改 換 門 閭	改 換 家 門	改 期	改 朝 換 代	改 善	改 善 生 活	
改 進	改 進 工 作	改 嫁	改 葬	改 裝	改 道	改 過	改 過 不 吝	
改 過 向 善	改 過 自 新	改 過 作 新	改 過 從 善	改 過 遷 善	改 種	改 稱	改 說	
改 嘴	改 寫	改 樣	改 稿	改 編	改 編 本	改 調	改 選	
改 錯	改 頭 換 面	改 擊	改 轅 易 轍	改 轍	改 變	改 變 方 向	改 變 者	
改 變 面 貌	改 觀	攻 入	攻 下	攻 不 破	攻 心	攻 心 戰	攻 心 戰 術	
攻 打	攻 守	攻 守 同 盟	攻 佔	攻 克	攻 事	攻 其	攻 其 不 備	
攻 取	攻 於	攻 城	攻 城 掠 地	攻 城 略 地	攻 城 野 戰	攻 為	攻 苦 食 淡	
攻 效	攻 破	攻 訐	攻 堅	攻 堅 戰	攻 陷	攻 無 不 克	攻 勢	
攻 錯	攻 擊	攻 擊 者	攻 關	攻 關 項 目	攻 殲	攻 讀	攸 關	
旱 井	旱 生	旱 田	旱 冰	旱 冰 場	旱 地	旱 年	旱 災	
旱 季	旱 苗 得 雨	旱 秧	旱 荒	旱 情	旱 船	旱 傘	旱 棲	
旱 象	旱 煙	旱 煙 袋	旱 路	旱 道	旱 稻	旱 練	旱 橋	
旱 獺	旱 澇	旱 澇 保 收	旱 魃 為 虐	更 人	更 上 一 層 樓	更 口	更 大	
更 大 程 度 上	更 小	更 不	更 不 用 說	更 不 待 言	更 不 待 說	更 夫	更 少	
更 加	更 加 重 要	更 正	更 生	更 兇	更 向	更 向 前	更 名	
更 名 改 姓	更 多	更 多 更 好	更 好	更 安 靜	更 年	更 年 期	更 早	
更 有	更 有 甚 者	更 有 意 義	更 衣	更 衣 室	更 何 況	更 低	更 冷	
更 妙	更 快	更 改	更 改 者	更 辛 苦	更 佳	更 具	更 其	
更 始	更 弦 易 張	更 往 前	更 性	更 易	更 長	更 長 夢 短	更 長 漏 永	
更 勇 敢	更 待 何 時	更 後	更 挑 剔	更 是	更 是 如 此	更 是 這 樣	更 為	
更 為 重 要	更 為 嚴 重	更 美	更 要	更 迭	更 重	更 容 易	更 差	
更 能	更 高	更 高 興	更 偉 大	更 動	更 常 用	更 張	更 深	
更 深 人 靜	更 深 夜 靜	更 鳥	更 勝 一 籌	更 喜 歡	更 惡 化	更 換	更 換 者	
更 替	更 短	更 硬	更 舒 松	更 進 一 步	更 進 一 竿	更 新	更 新 換 代	
更 暗	更 鼓	更 僕 難 數	更 端	更 緊	更 輕	更 遠	更 寬	
更 廣	更 樓	更 確 切 地 說	更 適 宜	更 遲	更 優	更 優 越	更 應	
更 應 該	更 聰 明	更 趨	更 闌 人 靜	更 簡 單	更 壞	更 穩	更 難	
更 嚴	更 屬 不 易	更 顯	更 讓	束 力	束 之 高 閣	束 手	束 手 束 腳	
束 手 待 死	束 手 待 斃	束 手 旁 觀	束 手 就 擒	束 手 就 縛	束 手 就 斃	束 手 無 計	束 手 無 措	
束 手 無 策	束 以	束 成	束 住	束 杖 理 民	束 身	束 身 自 好	束 身 自 修	
束 身 修 行	束 身 就 縛	束 修	束 修 自 好	束 胸	束 馬 懸 車	束 帶	束 腰	
束 裝	束 裝 盜 金	束 緊	束 髮	束 髮 封 帛	束 髮 帶	束 縛	束 縛 物	
束 環 索	李 下 不 整 冠	李 下 瓜 天	李 子	李 小 璐	李 心 潔	李 木	李 代 桃 僵	
李 四	李 四 端	李 白	李 安	李 亨 澤	李 典 勇	李 奇 蒙	李 宗 盛	
李 長 榮	李 保 田	李 度	李 洪 志	李 家 同	李 泰 祥	李 曼	李 敖	
李 連 杰	李 斯 特	李 登 輝	李 逵	李 奧 納 多 狄 卡 普 利 歐	李 煥	李 維 拉	李 肇 星	
李 遠 哲	李 慶 華	李 樹	李 澤 楷	李 鴻 禧	李 鵬	李 麗 珍	李 琇 媛	
杏 子	杏 干	杏 仁	杏 色	杏 花	杏 雨 梨 雲	杏 紅	杏 核	
杏 眼	杏 脯	杏 黃	杏 樹	杏 臉 桃 腮	材 大 難 用	材 料	材 料 費	
材 料 廠	材 能 兼 備	材 高 知 深	材 疏 志 大	材 輕 德 薄	材 質	村 人	村 上 春 樹	
村 口	村 女	村 子	村 內	村 夫	村 夫 俗 子	村 夫 野 老	村 史	
村 外	村 民	村 生 泊 長	村 名	村 式	村 坊	村 村 寨 寨	村 委 會	
村 姑	村 社	村 長	村 前 村 後	村 級	村 婦	村 捨	村 莊	
村 野	村 童	村 筋 俗 骨	村 幹 部	村 落	村 裡	村 寨	村 學	
村 辦	村 鎮	杜 口 吞 聲	杜 口 無 言	杜 口 結 舌	杜 口 絕 舌	杜 口 絕 言	杜 口 裹 足	
杜 比	杜 瓦	杜 仲	杜 冷 丁	杜 甫	杜 邦	杜 松	杜 門 不 出	
杜 門 自 絕	杜 門 卻 掃	杜 門 屏 跡	杜 門 晦 跡	杜 門 謝 客	杜 書 伍	杜 琪 克	杜 絕	
杜 絕 後 患	杜 郵 之 戮	杜 微 慎 防	杜 漸	杜 漸 防 萌	杜 漸 防 微	杜 漸 除 微	杜 撰	
杜 撰 者	杜 魯 門	杜 樹	杜 衡	杜 鵑	杜 鵑 花	杜 鵑 鳥	杜 麗 莊	
杖 刑	杖 擊	杞 人 之 憂	杞 人 憂 天	杞 子	杞 宋 無 征	杞 國 憂 天	杞 憂 者	
杉 山 愛	杉 木	杉 木 製	杉 林	杉 樹	步 人 後 塵	步 入	步 入 正 軌	
步 子	步 斗 踏 罡	步 月 登 雲	步 出	步 伐	步 伐 蹣 跚	步 行	步 行 者	
步 行 道	步 兵	步 兵 師	步 步	步 步 生 蓮 花	步 步 為 營	步 法	步 哨	
步 涉 者	步 速	步 幅	步 測	步 程 計	步 進	步 量	步 話 機	
步 道	步 態	步 槍	步 槍 隊	步 履	步 履 維 艱	步 履 輕 盈	步 履 艱 難	
步 數 計	步 線 行 針	步 調	步 調 一 致	步 操	步 機	步 聲	步 驟	
步 罡 踏 斗	每 一	每 一 寸 土 地	每 一 方	每 一 年	每 一 個	每 一 種	每 七 年	
每 二	每 人	每 人 每 年	每 八 年	每 十 年	每 下 愈 況	每 小 時	每 五 年	
每 分 鐘	每 匹	每 天	每 戶	每 斤	每 日	每 日 性	每 月	
每 片	每 包	每 半 年	每 四 天	每 四 年	每 平 方 米	每 打	每 本	
每 件	每 件 事	每 份	每 回	每 地	每 年	每 旬	每 次	
每 位	每 克	每 批	每 每	每 車	每 兩	每 刻	每 到	
每 夜	每 季	每 屆	每 況 愈 下	每 股	每 星 期	每 秒	每 秒 鐘	
每 英 寸	每 頁	每 個	每 個 人	每 套	每 家	每 座	每 時	
每 時 每 刻	每 畝	每 張	每 排	每 晚	每 條	每 瓶	每 組	
每 處	每 逢	每 部	每 頃	每 單 位	每 場	每 期	每 筆	
每 週	每 隊	每 集	每 項	每 飯 不 忘	每 當	每 節	每 隔	
每 頓	每 種	每 層	每 樣	每 磅	每 窯	每 輛	每 噸	
每 縣	每 頭	每 顆	每 轉	每 雙	每 類	求 人	求 人 不 如 求 己	
求 三 拜 四	求 乞	求 大 同	求 大 同 存 小 異	求 子	求 才	求 才 若 渴	求 之	
求 之 不 得	求 之 過 急	求 仁 得 仁	求 主	求 出	求 生	求 生 不 生 求 死 不 死	求 生 不 得 求 死 不 能	
求 生 害 義	求 田 問 捨	求 全	求 全 之 毀	求 全 責 備	求 同	求 同 存 異	求 名 求 利	
求 名 責 實	求 名 奪 利	求 好	求 成	求 成 過 急	求 死	求 死 不 得	求 你	
求 利	求 助	求 助 於	求 告	求 我	求 求	求 求 你	求 見	
求 其 友 聲	求 取	求 和	求 法	求 知	求 知 慾	求 雨	求 是	
求 活	求 降	求 值	求 效 益	求 根	求 真	求 神	求 神 問 卜	
求 馬 唐 肆	求 偶	求 婚	求 得	求 情	求 救	求 教	求 魚 緣 木	
求 備 一 人	求 勝	求 勝 心 切	求 援	求 診	求 愛	求 愛 者	求 新	
求 新 立 異	求 補	求 解	求 過	求 實	求 榮 賣 國	求 福	求 福 禳 災	
求 精	求 遠	求 劍 刻 舟	求 賢	求 賢 下 士	求 賢 用 士	求 賢 如 渴	求 賢 若 渴	
求 冪	求 學	求 戰	求 積	求 積 分	求 親	求 親 靠 友	求 職	
求 醫	求 穩	求 藝	求 證	求 饒	求 變	汞 合 金	汞 污 泥	
汞 溴	汞 劑	沙 一 般	沙 丁 魚	沙 土	沙 子	沙 中	沙 化	
沙 文	沙 文 主 義	沙 丘	沙 包	沙 司	沙 田	沙 石	沙 地	
沙 坑	沙 沙	沙 沙 聲	沙 拉	沙 河	沙 門	沙 俄	沙 柱	
沙 皇	沙 皇 制	沙 烏 地 阿 拉 伯	沙 特	沙 特 阿 拉 伯	沙 荒	沙 啞	沙 堆	
沙 崗	沙 眼	沙 粒	沙 袋	沙 魚	沙 鹿	沙 鹿 鎮	沙 場	
沙 棗	沙 發	沙 窗	沙 腦 魚	沙 裡 淘 金	沙 塵	沙 漠	沙 漠 中	
沙 漠 化	沙 漠 研 究	沙 漠 綠 洲	沙 漏	沙 層	沙 暴	沙 盤	沙 質	
沙 糖	沙 頭 角	沙 龍	沙 聲	沙 鍋	沙 礫	沙 灘	沙 灘 排 球	
沙 鷗	沙 灣	沁 人 心 肺	沁 人 心 脾	沁 人 肺 腑	沁 入	沁 入 心 脾	沈 氏 印 刷	
沈 世 朋	沈 思	沈 春 華	沈 寂	沈 悶	沈 溺	沈 腰 潘 鬢	沈 慶 京	
沈 澱 物	沈 澱 素	沈 澱 劑	沈 靜	沈 默	沈 默 寡 言	沈 嶸	沈 謎 於	
沉 了	沉 入	沉 下	沉 不 住 氣	沉 井	沉 舟	沉 舟 破 釜	沉 住 氣	
沉 吟	沉 吟 不 決	沉 吟 不 語	沉 吟 未 決	沉 床	沉 李 浮 瓜	沉 沉	沉 沒	
沉 灶 產 蛙	沉 甸 甸	沉 河	沉 物	沉 厚 寡 言	沉 思	沉 思 冥 想	沉 思 默 想	
沉 重	沉 重 少 言	沉 重 打 擊	沉 重 負 擔	沉 重 寡 言	沉 降	沉 冤	沉 冤 莫 白	
沉 浸	沉 浸 於	沉 浮	沉 迷	沉 寂	沉 得	沉 淪	沉 船	
沉 陷	沉 魚 落 雁	沉 博 絕 麗	沉 悶	沉 渣	沉 湎	沉 湎 淫 逸	沉 痛	
沉 痛 懷 念	沉 著	沉 著 痛 快	沉 著 應 戰	沉 雄 古 逸	沉 雄 悲 壯	沉 滓 泛 起	沉 溺	
沉 溺 於	沉 落	沉 滯	沉 漸 剛 克	沉 睡	沉 毅	沉 潛 剛 克	沉 緬	
沉 醉	沉 醉 於	沉 澱	沉 澱 出	沉 澱 法	沉 澱 物	沉 積	沉 積 物	
沉 積 巖	沉 靜	沉 靜 少 言	沉 靜 寡 言	沉 默	沉 默 不 語	沉 默 寡 言	沉 穩	
沉 鬱	沉 鬱 頓 挫	沉 痾	沅 江	沅 陵	沛 雨 甘 霖	沛 縣	汪 汪	
汪 洋	汪 洋 大 海	汪 洋 自 恣	汪 洋 自 肆	汪 洋 浩 博	汪 洋 閎 肆	汪 流	汪 道 涵	
決 一 死 戰	決 一 勝 負	決 一 雌 雄	決 口	決 不	決 不 可	決 不 再	決 不 是	
決 不 食 言	決 不 能	決 不 會	決 不 罷 休	決 心	決 心 很 大	決 心 要	決 心 書	
決 出	決 出 名 次	決 死	決 而 不 行	決 志	決 定	決 定 了	決 定 因 素	
決 定 作 用	決 定 性	決 定 論	決 定 權	決 於	決 非	決 計	決 鬥	
決 鬥 者	決 勝	決 勝 千 里	決 堤	決 無	決 然	決 策	決 策 人	
決 策 千 里	決 策 者	決 策 論	決 策 學	決 絕	決 裂	決 意	決 獄 斷 刑	
決 疑	決 疑 論	決 算	決 戰	決 選	決 賽	決 賽 權	決 斷	
決 斷 如 流	決 竅	決 議	決 議 案	決 癰 潰 疽	沐 川	沐 雨 櫛 風	沐 浴	
沐 浴 者	沐 猴 而 冠	沐 猴 衣 冠	沐 猴 冠 冕	汰 舊 換 新	汨 汨	沖 天	沖 天 爐	
沖 孔	沖 水	沖 失	沖 犯	沖 件	沖 州 撞 府	沖 兌	沖 床	
沖 決	沖 沖	沖 走	沖 刷	沖 抵	沖 服	沖 垮	沖 流	
沖 洗	沖 倒	沖 茶	沖 退	沖 堅 陷 陣	沖 帳	沖 掉	沖 涼	
沖 淡	沖 喜	沖 減	沖 程	沖 越	沖 量	沖 開	沖 塌	
沖 毀	沖 溝	沖 電 器	沖 賬	沖 銷	沖 劑	沖 擋	沖 積	
沖 積 平 原	沖 積 物	沖 積 層	沖 頭	沖 壓	沖 轉	沖 壞	沖 繩	
沖 繩 島	沖 繩 縣	沖 曬	沒 了	沒 人	沒 人 騎	沒 入	沒 力 氣	
沒 大 沒 小	沒 不 暇 給	沒 中	沒 什 麼	沒 分 開	沒 心 沒 肺	沒 日 沒 夜	沒 世 不 忘	
沒 世 難 忘	沒 打 中	沒 生	沒 用	沒 用 過	沒 皮 沒 臉	沒 交	沒 多 久	
沒 好	沒 收	沒 收 物	沒 有	沒 有 人	沒 有 洗	沒 有 家	沒 有 單	
沒 有 過	沒 有 歌	沒 有 錢	沒 有 關 係	沒 而 不 朽	沒 住	沒 完	沒 完 沒 了	
沒 弄 髒	沒 把	沒 投 票	沒 沒 無 聞	沒 良 心	沒 身 不 忘	沒 事	沒 事 找 事	
沒 事 兒	沒 來	沒 到	沒 受	沒 命	沒 奈 何	沒 放	沒 於	
沒 法	沒 法 沒 天	沒 治	沒 治 了	沒 信 心	沒 勇 氣	沒 勁	沒 思 想	
沒 看 到	沒 風 味	沒 食	沒 拿 到	沒 氣 力	沒 病	沒 能	沒 骨 頭	
沒 問 題	沒 情 沒 緒	沒 清	沒 深 沒 淺	沒 細 菌	沒 羞	沒 處	沒 被	
沒 頂	沒 圍	沒 幾 天	沒 想	沒 想 到	沒 準	沒 當 回 事	沒 經 驗	
沒 腳	沒 腦 筋	沒 落	沒 話	沒 路	沒 過 多 久	沒 過 幾 天	沒 預 備	
沒 種	沒 精 打 采	沒 精 打 彩	沒 精 神	沒 認	沒 趕 上	沒 輕 沒 重	沒 領 會	
沒 影	沒 數	沒 熱 情	沒 趣	沒 趣 味	沒 醉	沒 齒 不 忘	沒 齒 難 忘	
沒 齒 難 泯	沒 錯	沒 錢	沒 頭 沒 腦	沒 頭 官 司	沒 頭 腦	沒 臉	沒 臉 見 人	
沒 轍	沒 懷	沒 藥	沒 譜	沒 關	沒 關 係	沒 覺	沒 聽	
沒 變	沒 啥	汽 化	汽 化 物	汽 化 計	汽 化 器	汽 水	汽 水 工 業 同 業 公 會	
汽 車	汽 車 工 業	汽 車 狂	汽 車 股	汽 車 保 養 修 護	汽 車 庫	汽 車 站	汽 車 產 業	
汽 車 道	汽 車 零 件	汽 車 製 造	汽 車 廠	汽 車 模 型	汽 車 竊 盜	汽 油	汽 油 彈	
汽 油 醇	汽 油 機	汽 泵	汽 缸	汽 浴	汽 酒	汽 配	汽 球	
汽 笛	汽 笛 聲	汽 船	汽 艇	汽 運	汽 閘	汽 電 共 生	汽 槍	
汽 輪	汽 輪 機	汽 燈	汽 鍋	汽 錘	汽 體	沃 土	沃 田	
沃 地	沃 基	沃 野	沃 野 千 里	沃 壤	汲 干	汲 水	汲 水 桶	
汲 出	汲 汲 皇 皇	汲 取	汲 盡	汾 水	汾 河	汾 酒	沆 瀣	
沆 瀣 一 氣	汶 萊	沂 水	沂 水 春 風	沂 河	沂 南	灶 上 騷 除	灶 火	
灶 台	灶 匠	灶 君	灶 具	灶 房	灶 間	灶 頭	灶 雞	
灼 艾 分 痛	灼 灼	灼 見	灼 見 真 知	灼 背 燒 頂	灼 痛	灼 傷	灼 熱	
灼 燒	災 民	災 年	災 後 重 建	災 星	災 殃	災 害	災 害 救 濟	
災 荒	災 區	災 患	災 情	災 禍	災 難	災 難 性	災 變	
牢 不 可 拔	牢 不 可 破	牢 牢	牢 系	牢 固	牢 房	牢 門	牢 記	
牢 裡	牢 獄	牢 靠	牢 騷	牢 籠	牡 丹	牡 丹 江	牡 牛	
牡 蠣	狄 克 西 三 人 組	狄 斯 可	狄 龍	狄 鶯	狂 人	狂 三 詐 四	狂 女	
狂 文	狂 犬	狂 犬 病	狂 叫	狂 奴 故 態	狂 妄	狂 似	狂 吹	
狂 吠	狂 吼	狂 吟 老 監	狂 言	狂 呼	狂 奔	狂 放	狂 者	
狂 花 病 葉	狂 信	狂 信 者	狂 怒	狂 風	狂 風 沙	狂 風 暴 雨	狂 風 驟 雨	
狂 徒	狂 氣	狂 烈	狂 病 人	狂 笑	狂 草	狂 喜	狂 跑	
狂 跌	狂 飲	狂 亂	狂 傲	狂 想	狂 想 曲	狂 蜂 浪 蝶	狂 詩	
狂 誇	狂 話	狂 跳	狂 態	狂 歌	狂 滿	狂 漲	狂 說	
狂 嘯	狂 暴	狂 樂 亂 舞	狂 潮	狂 熱	狂 熱 者	狂 熱 家	狂 鬧	
狂 濤 巨 浪	狂 濤 駭 浪	狂 瀾	狂 躁	狂 轟	狂 轟 濫 炸	狂 歡	狂 歡 的	
狂 歡 節	狂 襲	狂 戀	狂 飆	甬 道	男 人	男 人 似	男 人 們	
男 人 家	男 士	男 大 須 婚	男 大 當 婚	男 女	男 女 平 等	男 女 有 別	男 女 老 少	
男 女 老 幼	男 女 授 受 不 親	男 女 隊	男 女 雙 方	男 子	男 子 名	男 子 似	男 子 氣	
男 子 單 打	男 子 漢	男 子 雙 打	男 工	男 中 音	男 方	男 主 角	男 外 套	
男 左	男 生	男 用	男 同 志	男 名	男 式	男 色	男 低 音	
男 巫	男 扮 女 裝	男 男 女 女	男 系	男 侍	男 兒	男 性	男 性 化	
男 性 素	男 服	男 朋 友	男 的	男 青 年	男 娃	男 孩	男 孩 兒	
男 室 女 家	男 星	男 家	男 耕 女 織	男 高 音	男 唱 女 隨	男 娼	男 婚 女 娉	
男 婚 女 嫁	男 排	男 捨	男 教 師	男 單	男 媒 女 妁	男 尊 女 卑	男 廁	
男 廁 所	男 盜 女 娼	男 童	男 隊	男 裝	男 僕	男 像 柱	男 團	
男 演 員	男 網	男 賓	男 輩	男 儐 相	男 學 生	男 褲	男 親 屬	
男 嬰	男 爵	男 聲	男 雙	男 籃	男 歡 女 愛	甸 園	皂 化	
皂 片	皂 皮 樹	皂 液	皂 盒	皂 莢	皂 絲 麻 線	皂 隸	盯 人	
盯 住	盯 梢	盯 著	盯 著 看	盯 視	私 了	私 人	私 人 企 業	
私 人 訪 問	私 人 資 本	私 人 關 係	私 下	私 下 交 易	私 下 談	私 之 處	私 仇	
私 仇 不 及 公	私 分	私 心	私 心 雜 念	私 方	私 占	私 生	私 生 子	
私 生 活	私 用	私 立	私 交	私 刑	私 印	私 宅	私 有	
私 有 化	私 有 制	私 有 財 產	私 自	私 利	私 吞	私 見	私 事	
私 刻	私 奔	私 念	私 房	私 房 話	私 房 錢	私 法	私 股	
私 邸	私 信	私 室	私 怨	私 活	私 相 授 受	私 相 傳 授	私 家	
私 恩 小 惠	私 拿	私 財	私 逃	私 酒	私 商	私 售	私 娼	
私 情	私 掠 船	私 淑 弟 子	私 產	私 船	私 處	私 訪	私 設	
私 設 公 堂	私 販	私 貨	私 通	私 通 者	私 章	私 喻	私 費	
私 買	私 債	私 意	私 會	私 話	私 運	私 道	私 塾	
私 罰	私 蓄	私 語	私 增	私 慾	私 憤	私 線	私 賣	
私 銷	私 養	私 學	私 營	私 營 企 業	私 藏	私 黨	私 囊	
私 鹽	秀 才	秀 才 人 情	秀 水	秀 出 班 行	秀 外 惠 中	秀 外 慧 中	秀 而 不 實	
秀 色	秀 色 可 餐	秀 姑 巒 溪	秀 拔	秀 林 鄉	秀 眉	秀 美	秀 峰	
秀 氣	秀 媚	秀 逸	秀 雅	秀 髮	秀 麗	秀 蘭 瑪 雅	禿 子	
禿 山	禿 石	禿 禿	禿 頂	禿 筆	禿 瘡	禿 髮	禿 髮 症	
禿 樹	禿 頭	禿 頭 藥	禿 鷹	禿 鷹 似	禿 驢	究 其	究 其 原 因	
究 其 根 源	究 理	究 竟	究 辦	系 人	系 內	系 主 任	系 以	
系 刊	系 外	系 由	系 列	系 列 化	系 列 片	系 列 產 品	系 列 劇	
系 有	系 而 不 食	系 牢	系 念	系 指	系 柱	系 風 捕 景	系 風 捕 影	
系 栓	系 帶	系 從	系 統	系 統 工 程	系 統 工 程 學	系 統 分 析	系 統 化	
系 統 性	系 統 研 究	系 統 控 制	系 統 電 子	系 統 管 理	系 統 論	系 船	系 通 科 技	
系 窗	系 結 物	系 詞	系 領 帶	系 數	系 繩	罕 用	罕 有	
罕 至	罕 見	罕 事	罕 到	罕 物	罕 聞	罕 譬 而 喻	肖 邦	
肖 像	肖 像 畫	肖 像 權	肝 火	肝 片	肝 功 能	肝 色	肝 炎	
肝 疾	肝 病	肝 部	肝 硬 化	肝 腸 寸 斷	肝 腫 大	肝 腦	肝 腦 塗 地	
肝 糖	肝 癌	肝 膽	肝 膽 相 照	肝 膽 胡 越	肝 膽 塗 地	肝 膽 楚 越	肝 膽 照 人	
肝 臟	肘 子	肘 狀 物	肘 推	肘 部	肘 腋 之 患	肘 腋 之 憂	肘 窩	
肘 擠	肛 門	肚 子	肚 子 痛	肚 白	肚 皮	肚 兜	肚 帶	
肚 喉 科	肚 量	肚 腸	肚 臍	育 人	育 才	育 幼 院	育 成	
育 兒	育 兒 室	育 林	育 空 河	育 肥	育 苗	育 秧	育 種	
育 嬰	育 嬰 室	育 雛	育 齡	良 久	良 工 心 苦	良 友	良 心	
良 方	良 民	良 民 證	良 田	良 好	良 材	良 言	良 辰	
良 辰 吉 日	良 辰 美 景	良 辰 媚 景	良 性	良 性 循 環	良 物	良 知	良 金 美 玉	
良 苦	良 家	良 宵	良 宵 好 景	良 宵 美 景	良 師	良 師 益 友	良 時 美 景	
良 將	良 得 電 子	良 莠	良 莠 不 一	良 莠 不 分	良 莠 不 齊	良 莠 淆 雜	良 港	
良 策	良 善	良 種	良 緣	良 質 美 手	良 導 體	良 機	良 醫	
良 藥	良 藥 苦 口	良 癩 蝦 蟆	芒 芒 苦 海	芒 刺	芒 刺 在 背	芒 果	芒 剌	
芒 涸 魂 湯	芒 寒 色 正	芒 然 自 失	芒 硝	芒 種	芋 頭	芍 藥	見 了	
見 人	見 不	見 不 得	見 不 得 人	見 之	見 之 不 取 思 之 千 里	見 之 於	見 仁	
見 仁 見 智	見 分 曉	見 天	見 方	見 世 面	見 可 而 進 知 難 而 退	見 外	見 光	
見 危 之 萌	見 危 受 命	見 危 致 命	見 地	見 多 不 怪	見 多 識 廣	見 好	見 好 就 收	
見 死 不 救	見 血	見 似	見 利	見 利 忘 義	見 利 思 義	見 事 風 生	見 兔 放 鷹	
見 兔 顧 犬	見 到	見 底	見 怪	見 怪 不 怪	見 所 未 見	見 於	見 物	
見 物 不 見 人	見 物 不 取 失 之 千 里	見 狀	見 者	見 表	見 長	見 重	見 面	
見 面 禮	見 風	見 風 使 帆	見 風 使 舵	見 風 駛 舵	見 風 轉 舵	見 風 轉 篷	見 效	
見 烈 心 喜	見 神	見 神 見 鬼	見 笑	見 笑 大 方	見 財 起 意	見 鬼	見 鬼 去	
見 得	見 教	見 棄	見 異	見 異 思 遷	見 習	見 習 生	見 報	
見 景 生 情	見 智	見 智 見 仁	見 短	見 著	見 微 知 著	見 新	見 溺 不 救	
見 義	見 義 勇 為	見 解	見 過	見 圖	見 慣	見 慣 不 驚	見 慣 司 空	
見 稱	見 聞	見 聞 錄	見 貌 辨 色	見 輕	見 噎 廢 食	見 廣	見 德 思 齊	
見 諒	見 諸	見 諸 行 動	見 諸 於	見 諸 報 端	見 賢 不 隱	見 賢 思 齊	見 鞍 思 馬	
見 機	見 機 而 行	見 機 而 作	見 機 行 事	見 錢 眼 紅	見 錢 眼 開	見 縫 插 針	見 禮	
見 識	見 證	見 證 人	見 驥 一 毛	角 力	角 上	角 巾 私 第	角 分	
角 尺	角 加 速 度	角 色	角 位 移	角 形	角 兒	角 果	角 板	
角 門	角 度	角 度 計	角 料	角 鬥	角 球	角 票	角 速 度	
角 逐	角 落	角 樓	角 膜	角 膜 炎	角 質	角 質 層	角 鋼	
角 錐	角 頻 率	角 頭	角 鐵	言 人 人 殊	言 十 妄 九	言 三 語 四	言 下	
言 下 之 意	言 不 及 私	言 不 及 義	言 不 由 中	言 不 由 衷	言 不 逮 意	言 不 詭 隨	言 不 盡 意	
言 不 踐 行	言 不 諳 典	言 不 顧 行	言 中	言 之	言 之 不 文 行 之 不 遠	言 之 不 渝	言 之 不 預	
言 之 不 盡	言 之 成 理	言 之 有 物	言 之 有 理	言 之 無 文 行 之 不 遠	言 之 無 文 行 而 不 遠	言 之 無 物	言 之 過 甚	
言 之 諄 諄 聽 之 藐 藐	言 之 鑿 鑿	言 及	言 出	言 出 法 隨	言 出 患 入	言 外	言 外 之 意	
言 必 有 中	言 必 有 據	言 必 信	言 必 信 行 必 果	言 多	言 多 失 實	言 多 必 失	言 多 語 失	
言 而 不 信	言 而 有 信	言 而 無 文 行 之 不 遠	言 而 無 信	言 行	言 行 一 致	言 行 不 一	言 行 若 一	
言 行 計 從	言 兵 事 疏	言 狂 意 妄	言 事 若 神	言 來 語 去	言 和	言 明	言 者	
言 者 無 罪	言 者 無 罪 聞 者 足 戒	言 表	言 近 旨 遠	言 為 心 聲	言 若 懸 河	言 重	言 笑 自 如	
言 笑 晏 晏	言 笑 嘻 怡	言 高 語 低	言 從 計 行	言 從 計 納	言 情	言 情 小 說	言 教	
言 理 學	言 喻	言 無 二 價	言 無 不 盡	言 猶 未 盡	言 猶 在 耳	言 詞	言 亂	
言 傳	言 傳 身 教	言 微 旨 遠	言 賅	言 路	言 道	言 過 其 詞	言 過 其 實	
言 盡 旨 遠	言 盡 指 遠	言 稱	言 語	言 語 上	言 說	言 輕	言 輕 行 濁	
言 談	言 談 話 語	言 談 舉 止	言 論	言 論 自 由	言 論 集	言 聲	言 歸 正 傳	
言 歸 和 好	言 歸 於 好	言 簡 意 明	言 簡 意 賅	言 辭	言 類 懸 河	言 顛 語 倒	言 聽 行 從	
言 聽 計 用	言 聽 計 行	言 聽 計 從	谷 口	谷 子	谷 川	谷 地	谷 底	
谷 物	谷 雨	谷 苗	谷 倉	谷 氨 酸	谷 粉	谷 草	谷 堆	
谷 梁	谷 粒	谷 鳥	谷 場	谷 種	谷 賤 傷 農	谷 穗	谷 類	
谷 類 作 物	豆 子	豆 汁	豆 夾	豆 形	豆 沙	豆 角	豆 豆	
豆 乳	豆 兒	豆 油	豆 狀	豆 芽	豆 花	豆 科	豆 苗	
豆 重 榆 瞑	豆 面	豆 剖 瓜 分	豆 料	豆 粉	豆 素	豆 條	豆 粒	
豆 莢	豆 渣	豆 象	豆 鼠	豆 綠	豆 腐	豆 腐 皮	豆 腐 乳	
豆 腐 乾	豆 腐 腦	豆 蓉	豆 製 品	豆 餅	豆 漿	豆 薯	豆 醬	
豆 瓣	豆 類	豆 秸	豆 萁	豆 蔻	豆 蔻 年 華	豕 突 狼 奔	貝 加 爾 湖	
貝 母	貝 多 芬	貝 克	貝 里 斯	貝 拉	貝 林 格	貝 特	貝 勒	
貝 殼	貝 雷 帽	貝 寧	貝 幣	貝 爾	貝 魯 特	貝 錦 萁 菲	貝 雕	
貝 闕 珠 宮	貝 類	赤 口 白 舌	赤 口 毒 舌	赤 子	赤 子 之 心	赤 化	赤 心	
赤 心 奉 國	赤 心 忠 膽	赤 心 報 國	赤 手	赤 手 空 拳	赤 手 起 家	赤 日	赤 日 炎 炎	
赤 水	赤 地 千 里	赤 字	赤 舌 燒 城	赤 色	赤 忱	赤 豆	赤 足	
赤 身	赤 身 裸 體	赤 身 露 體	赤 兔	赤 松	赤 狐	赤 金	赤 眉	
赤 紅	赤 革	赤 峰	赤 崁 紡 織	赤 條	赤 條 條	赤 貧	赤 痢	
赤 楊	赤 腳	赤 腳 醫 生	赤 誠	赤 道	赤 道 幾 內 亞	赤 道 儀	赤 膊	
赤 膊 上 陣	赤 裸	赤 裸 裸	赤 銅	赤 銅 礦	赤 熱	赤 衛 軍	赤 衛 隊	
赤 褐	赤 壁	赤 壁 鏖 兵	赤 橙	赤 縣	赤 縣 神 州	赤 臂	赤 膽	
赤 膽 忠 心	赤 膽 忠 肝	赤 繩 系 足	赤 繩 綰 足	赤 鐵 礦	赤 露	赤 體	赤 體 上 陣	
赤 黴 素	赤 黴 菌	赤 灣	走 了	走 了 和 尚 走 不 了 廟	走 人	走 入	走 下	
走 下 坡	走 上	走 上 位	走 山	走 之	走 及 奔 馬	走 水	走 火	
走 出	走 去	走 失	走 失 協 尋	走 石 飛 砂	走 穴	走 光	走 向	
走 向 世 界	走 回	走 在	走 好	走 江 湖	走 肉	走 肉 行 屍	走 色	
走 吧	走 完	走 形	走 投 沒 路	走 投 無 路	走 村 串 戶	走 步	走 私	
走 私 犯	走 私 者	走 私 案	走 走	走 來	走 來 走 去	走 兩 步	走 到	
走 卒	走 味	走 狗	走 的	走 者	走 近	走 俏	走 南 闖 北	
走 哇	走 後	走 後 門	走 查	走 歪	走 流 性	走 為	走 相	
走 紅	走 風	走 時	走 神	走 起	走 馬	走 馬 上 任	走 馬 之 任	
走 馬 到 任	走 馬 看 花	走 馬 赴 任	走 馬 章 台	走 馬 換 將	走 馬 燈	走 馬 觀 花	走 骨 行 屍	
走 高	走 動	走 啦	走 帶	走 帳	走 得	走 掉	走 眼	
走 累	走 船	走 訪	走 廊	走 散	走 棋	走 筆 成 文	走 筆 成 章	
走 著	走 著 瞧	走 街 串 巷	走 街 穿 巷	走 進	走 開	走 亂	走 勢	
走 勢 洶 湧	走 勢 凌 厲	走 極 端	走 禽	走 話	走 資 派	走 路	走 路 快	
走 運	走 道	走 過	走 過 場	走 遍	走 嘍	走 慢	走 漏	
走 漏 天 機	走 漏 風 聲	走 遠	走 嘴	走 樣	走 調	走 趟	走 壁	
走 親 訪 友	走 錯	走 錯 路	走 頭 沒 路	走 頭 無 路	走 獸	走 繩	走 邊	
走 贏	走 彎 路	走 讀	走 讀 生	足 下	足 不 出 戶	足 不 逾 戶	足 不 窺 戶	
足 內	足 月	足 以	足 可	足 用	足 先	足 尖	足 有	
足 色	足 見	足 赤	足 足	足 使	足 協	足 取	足 底	
足 板	足 金	足 信	足 科	足 背	足 致	足 重	足 音 跫 然	
足 食 足 兵	足 食 豐 衣	足 紋	足 高 氣 揚	足 夠	足 球	足 球 員	足 球 場	
足 球 隊	足 球 賽	足 趾	足 部	足 智	足 智 多 謀	足 量	足 歲	
足 跡	足 跟	足 數	足 標	足 壇	足 蹈 手 舞	足 禮	足 額	
足 類	身 上	身 亡	身 子	身 不 由 己	身 不 由 主	身 不 遇 時	身 心	
身 心 交 病	身 心 交 瘁	身 心 健 康	身 手	身 世	身 外	身 外 之 物	身 孕	
身 份	身 份 證	身 份 證 字 號	身 先	身 先 士 卒	身 先 士 眾	身 先 朝 露	身 名 俱 泰	
身 名 俱 滅	身 在	身 在 江 湖 心 懸 魏 闕	身 在 林 泉 心 懷 魏 闕	身 在 曹 營 心 在 漢	身 死 名 辱	身 自 為 之	身 形	
身 材	身 材 高 大	身 材 短	身 材 魁 梧	身 事	身 受	身 居	身 居 要 職	
身 居 高 位	身 板	身 長	身 非 木 石	身 前	身 契	身 姿	身 後	
身 段	身 為	身 穿	身 負	身 負 重 任	身 負 重 傷	身 首 分 離	身 首 異 處	
身 兼	身 兼 數 職	身 家	身 家 性 命	身 旁	身 退 功 成	身 高	身 做 身 當	
身 寄 虎 吻	身 帶	身 強 力 壯	身 強 體 壯	身 患	身 教	身 敗	身 敗 名 裂	
身 敗 名 隳	身 條	身 處	身 貧 如 洗	身 殘 志 不 殘	身 殘 志 堅	身 無	身 無 寸 縷	
身 無 分 文	身 無 完 膚	身 無 長 物	身 著	身 微	身 當 矢 石	身 當 其 境	身 經	
身 經 百 戰	身 說	身 輕	身 輕 言 微	身 輕 體 健	身 遠 心 近	身 遙 心 邇	身 價	
身 價 百 倍	身 價 倍 增	身 廢 名 裂	身 影	身 歷	身 歷 聲	身 臨	身 臨 其 境	
身 軀	身 懷 六 甲	身 懷 絕 技	身 邊	身 顯 名 揚	身 體	身 體 力 行	身 體 上	
身 體 健 康	車 □ 轆	車 刀	車 上	車 子	車 工	車 內	車 手	
車 斗	車 水	車 水 馬 龍	車 主	車 台	車 用	車 皮	車 伕	
車 份	車 光	車 匠	車 在 馬 前	車 次	車 臣	車 行	車 行 道	
車 床	車 技	車 把	車 把 式	車 攻 馬 同	車 身	車 兒	車 底	
車 房	車 直	車 花	車 長	車 門	車 前	車 前 草	車 型	
車 城	車 後	車 架	車 殆 馬 煩	車 流	車 胎	車 修	車 匪	
車 套	車 展	車 庫	車 座	車 捐	車 站	車 軒	車 陣	
車 馬	車 馬 盈 門	車 馬 費	車 馬 輻 輳	車 馬 駢 闐	車 骨	車 務	車 務 人 員	
車 匙	車 圈	車 條	車 票	車 組	車 船	車 速	車 頂	
車 場	車 廂	車 棚	車 殼	車 無 退 表	車 牌	車 程	車 程 表	
車 程 計	車 窗	車 貼	車 費	車 軸	車 量	車 間	車 間 主 任	
車 隊	車 照	車 補	車 裡	車 資	車 載	車 載 斗 量	車 道	
車 鉤	車 塵 馬 跡	車 墊	車 禍	車 種	車 蓋	車 盤	車 箱	
車 蓬	車 輛	車 輛 保 養	車 輛 發 動 機	車 輛 勤 務	車 輛 管 理	車 輪	車 輪 戰	
車 駕	車 燈	車 輻	車 錢	車 頭	車 篷	車 轅	車 鍊	
車 轍	車 轍 馬 跡	車 鎖	車 邊	車 齡	車 體	辛 丑	辛 巴 威	
辛 亥	辛 亥 革 命	辛 吉 絲	辛 辛 那 提	辛 辛 苦 苦	辛 酉	辛 苦	辛 勞	
辛 勤	辛 勤 工 作	辛 勤 勞 動	辛 辣	辛 酸	辛 烷	辛 烷 值	辰 光	
辰 砂	辰 時	迂 曲	迂 怪 不 經	迂 拙	迂 直	迂 迴	迂 迴 曲 折	
迂 腐	迂 談 闊 論	迂 闊	迅 即	迅 風 暴 雨	迅 捷	迅 猛	迅 猛 發 展	
迅 速	迅 速 發 展	迅 速 增 長	迅 雷	迅 雷 不 及 掩 耳	迄 今	迄 今 為 止	迄 未	
迄 未 成 功	迄 至	迄 某 時	迄 根	巡 弋	巡 守	巡 行	巡 防	
巡 夜	巡 於	巡 查	巡 洋	巡 洋 艦	巡 哨	巡 展	巡 捕	
巡 航	巡 迴	巡 迴 展 覽	巡 迴 演 出	巡 迴 賽	巡 迴 醫 療	巡 票	巡 游	
巡 視	巡 視 者	巡 視 員	巡 診	巡 道	巡 察	巡 撫	巡 檢	
巡 禮	巡 邋	巡 警	巡 邏	巡 邏 者	巡 邏 隊	邑 犬 群 吠	邢 台	
邪 不 干 正	邪 不 勝 正	邪 心	邪 行	邪 念	邪 物	邪 門	邪 門 歪 道	
邪 氣	邪 祟	邪 神	邪 財	邪 唬	邪 教	邪 術	邪 途	
邪 惡	邪 路	邪 道	邪 語	邪 說	邪 說 異 端	邪 僻	邪 魔	
邪 魔 外 道	邦 交	邦 交 正 常 化	邦 茲	邦 國	邦 聯	那 一	那 一 點	
那 人	那 又	那 才	那 不	那 天	那 支	那 方	那 日	
那 片	那 布 勒 斯	那 末	那 件	那 份	那 曲	那 有	那 次	
那 串	那 位	那 車	那 事	那 些	那 些 天	那 兒	那 怕	
那 的	那 咱	那 怎 麼 行	那 段	那 個	那 個 人	那 家	那 座	
那 時	那 時 候	那 能	那 般	那 陣 子	那 將	那 張	那 條	
那 處	那 部	那 堪	那 就 是 說	那 幾 年	那 斯 達 克	那 筆	那 間	
那 塊	那 會 兒	那 裡	那 話	那 種	那 麼	那 麼 回 事	那 麼 些	
那 麼 樣	那 廝	那 樣	那 輛	那 魯 灣	那 還 用 說	那 點	那 雙	
那 邊	酉 時	里 拉	里 昂	里 昂 市	里 巷	里 斯 本	里 港 鄉	
里 程	里 程 表	里 程 計	里 程 碑	里 鄰 社 區	防 人 之 口 甚 於 防 川	防 不 及 防	防 不 勝 防	
防 化 兵	防 日 曬	防 止	防 水	防 水 布	防 水 衣	防 火	防 火 衣	
防 火 道	防 火 線	防 火 牆	防 功 害 能	防 民 之 口 甚 於 防 川	防 民 之 水 甚 於 防 川	防 光	防 冰	
防 地	防 守	防 汗	防 汛	防 汛 期	防 老	防 旱	防 沙 林	
防 災	防 身	防 於	防 波 堤	防 治	防 治 所	防 空	防 空 洞	
防 空 軍	防 空 導 彈	防 芽 遏 萌	防 雨	防 雨 布	防 雨 帽	防 拴	防 毒	
防 毒 面 具	防 毒 程 式	防 洪	防 炸	防 疫	防 疫 注 射 證 明	防 疫 站	防 疫 針	
防 砂	防 音	防 風	防 風 林	防 修	防 凍	防 凍 劑	防 原 子	
防 害	防 核 安 全	防 浪	防 病	防 臭	防 臭 劑	防 務	防 務 協 定	
防 區	防 患	防 患 未 然	防 患 於 未 然	防 細 菌	防 雪	防 雪 裝	防 備	
防 寒	防 暑	防 暑 降 溫	防 盜	防 萌 杜 漸	防 菌	防 微 杜 漸	防 微 慮 遠	
防 意 如 城	防 損	防 滑	防 煙	防 碎	防 雷	防 電 劑	防 鼠	
防 塵	防 塵 板	防 漏	防 滲	防 磁	防 腐	防 腐 法	防 腐 劑	
防 蝕 劑	防 彈	防 暴	防 暴 武 器	防 潛	防 潮	防 熱	防 範	
防 線	防 蔽 耳 目	防 衛	防 衛 物	防 衛 計 劃	防 衛 廳	防 震	防 霉	
防 噪 音	防 磨	防 禦	防 禦 性	防 禦 物	防 禦 者	防 禦 戰	防 靜 電	
防 濕	防 癆	防 避	防 霜	防 爆	防 礙	防 饑	防 護	
防 護 服	防 護 林	防 護 物	防 護 著	防 曬	防 曬 用 品	防 曬 油	防 齲	
防 澇	防 ��	防 �� 油	防 �� 漆	阮 虔 芷	阮 囊 羞 澀	阪 上 走 丸	並 入	
並 力	並 已	並 不	並 不 以 此 為 滿 足	並 不 矛 盾	並 不 是	並 不 能	並 不 等 於	
並 且	並 以	並 可	並 未	並 用	並 由	並 立	並 列	
並 同	並 在	並 存	並 行	並 行 口	並 行 不 悖	並 作	並 把	
並 沒 有	並 使	並 例	並 於	並 者	並 肩	並 肩 作 戰	並 肩 戰 鬥	
並 附	並 非	並 非 如 此	並 非 易 事	並 按	並 施	並 為	並 軌	
並 重	並 修	並 案 辦 理	並 能	並 將	並 從	並 排	並 被	
並 報	並 就	並 提	並 無	並 發	並 給	並 進	並 當	
並 經	並 置	並 蒂 蓮	並 解	並 對	並 對 於	並 稱	並 端	
並 網	並 網 發 電	並 與	並 請	並 論	並 駕 齊 驅	並 隨	並 聯	
並 舉	並 轉	乖 巧	乖 舛	乖 乖	乖 兒	乖 戾	乖 的	
乖 孩 子	乖 順	乖 漲	乖 僻	乖 癖	乖 謬	乖 覺	乳 山	
乳 化	乳 水 交 融	乳 牙	乳 牛	乳 母	乳 汁	乳 汁 狀	乳 白	
乳 白 光	乳 白 色	乳 皮	乳 石	乳 名	乳 色	乳 兒	乳 制	
乳 房	乳 房 炎	乳 房 狀	乳 油	乳 狀	乳 狀 物	乳 品	乳 品 店	
乳 突 炎	乳 香	乳 香 脂	乳 香 樹	乳 娘	乳 峰	乳 粉	乳 脂	
乳 脂 狀	乳 臭	乳 臭 未 乾	乳 液	乳 暈	乳 源	乳 溝	乳 罩	
乳 腺	乳 腺 炎	乳 酪	乳 製 品	乳 酸	乳 酸 菌	乳 酸 鹽	乳 漿	
乳 膠	乳 膠 液	乳 豬	乳 齒	乳 齒 象	乳 劑	乳 劑 質	乳 濁 液	
乳 糖	乳 糖 □	乳 頭	乳 頭 狀	乳 癌	乳 鴿	乳 體	事 上	
事 已 至 此	事 不 宜 遲	事 不 關 己 高 高 掛 起	事 月 表	事 主	事 出	事 出 不 意	事 出 有 因	
事 半 功 倍	事 外	事 必	事 必 躬 親	事 生 肘 腋	事 用	事 由	事 件	
事 先	事 危 累 卵	事 在 人 為	事 在 必 行	事 成	事 事	事 例	事 兒	
事 典	事 到	事 到 臨 頭	事 宜	事 或 物	事 物	事 前	事 前 審 計	
事 後	事 後 諸 葛 亮	事 故	事 故 學	事 為	事 倍	事 倍 功 半	事 假	
事 務	事 務 所	事 務 長	事 務 處 理	事 務 管 理	事 情	事 敗 垂 成	事 理	
事 略	事 處	事 項	事 業	事 業 心	事 業 成 功	事 業 單 位	事 業 費	
事 跡	事 過 境 遷	事 隔	事 實	事 實 上	事 實 性	事 實 真 相	事 實 勝 於 雄 辨	
事 實 確 鑿	事 實 證 明	事 態	事 端	事 與 願 違	事 機	事 蹟	事 關 大 局	
事 關 全 局	事 關 重 大	事 變	事 體	些 個	些 許	些 微	亞 力 電 機	
亞 太	亞 太 地 區	亞 太 經 合 會	亞 太 銀 行	亞 共 析 鋼	亞 旭 電 腦	亞 克 力 棉	亞 於	
亞 肩 迭 背	亞 非	亞 洲	亞 洲 人	亞 洲 化 學	亞 洲 水 泥	亞 洲 司	亞 洲 史	
亞 洲 光 學	亞 洲 地 區	亞 洲 信 託	亞 洲 紀 錄	亞 洲 射 擊 錦 標 賽	亞 洲 國 家	亞 洲 開 發 銀 行	亞 洲 聚 合	
亞 洲 證 券	亞 美	亞 美 尼 亞	亞 美 利 加	亞 軍	亞 音 速	亞 音 頻	亞 特 蘭 大	
亞 馬 遜	亞 硫 酸	亞 硫 酸 鹽	亞 細 亞	亞 都 麗 緻	亞 麻	亞 寒 帶	亞 崴 機 電	
亞 硝 酸	亞 硝 酸 鹽	亞 塞 拜 然	亞 瑟 科 技	亞 當	亞 裔	亞 運	亞 運 村	
亞 運 會	亞 種	亞 綱	亞 銀	亞 歐	亞 歐 大 陸	亞 熱	亞 熱 帶	
亞 歷 桑 那	亞 磷 酸	亞 聯	亞 賽	亞 鐵	亞 鐵 鹽	亞 變 種	享 用	
享 年	享 有	享 有 盛 名	享 有 盛 譽	享 利	享 受	享 壽	享 盡	
享 福	享 樂	享 樂 主 義	享 譽	京 九	京 人	京 白	京 西	
京 杭	京 東	京 城	京 城 建 設	京 津	京 派	京 胡	京 郊	
京 師	京 海	京 族	京 都	京 腔	京 華	京 華 投 信	京 華 投 顧	
京 華 證 券	京 漢	京 滬	京 劇	京 劇 團	京 廣	京 廣 線	京 畿	
京 戲	京 韻	京 灣	佯 死	佯 攻	佯 狂	佯 言	佯 為	
佯 降	佯 笑	佯 動	佯 敗	佯 羞	佯 裝	佯 裝 不 知	佯 裝 者	
佯 稱	依 人	依 山 傍 水	依 仗	依 字 母	依 存	依 托	依 次	
依 次 為	依 此	依 此 類 推	依 余 類 推	依 序	依 我 來 看	依 我 看	依 我 看 來	
依 言	依 依	依 依 不 捨	依 依 惜 別	依 例	依 其	依 法	依 法 治 理	
依 法 查 處	依 法 處 理	依 法 辦 事	依 直	依 阿 取 容	依 附	依 附 於	依 律	
依 後	依 流 平 進	依 約	依 草 附 木	依 偎	依 從	依 條 約	依 率	
依 循	依 期	依 然	依 然 如 我	依 然 如 故	依 然 故 我	依 然 是	依 稀	
依 順	依 順 序	依 照	依 樣	依 樣 畫 葫 蘆	依 樣 葫 蘆	依 靠	依 靠 人 民	
依 靠 集 體	依 靠 群 眾	依 據	依 據 事 實	依 賴	依 賴 心	依 賴 性	依 賴 於	
依 賴 思 想	依 舊	依 蘭	依 戀	依 體 畫 葫 蘆	侍 女	侍 中	侍 弄	
侍 役	侍 制	侍 奉	侍 者	侍 郎	侍 候	侍 婢	侍 從	
侍 童	侍 僕	侍 衛	侍 養	侍 應	侍 應 生	佳 人	佳 人 才 子	
佳 人 薄 命	佳 大 實 業	佳 化	佳 日	佳 木 斯	佳 冬	佳 句	佳 地	
佳 作	佳 兵 不 祥	佳 妙	佳 里	佳 和 實 業	佳 品	佳 客	佳 茂	
佳 茂 精 工	佳 音	佳 格 食 品	佳 能	佳 能 企 業	佳 偶	佳 景	佳 期	
佳 節	佳 話	佳 鼎 科 技	佳 境	佳 賓	佳 篇	佳 錄 科 技	佳 餚	
佳 績	佳 總 興 業	佳 麗	佳 譽	佳 釀	使 入	使 力	使 下	
使 上	使 女	使 不	使 不 得	使 之	使 以	使 出	使 功 不 如 使 過	
使 犯	使 用	使 用 不 當	使 用 手 冊	使 用 方 法	使 用 者	使 用 報 告	使 用 期	
使 用 費	使 用 說 明	使 用 價 值	使 用 範 圍	使 用 權	使 由	使 再	使 因	
使 她	使 如	使 成	使 有	使 羊 將 狼	使 而	使 臣	使 至	
使 住	使 作	使 完	使 役	使 我	使 我 們	使 更	使 具	
使 其	使 到	使 受	使 命	使 命 感	使 於	使 服	使 者	
使 勁	使 勁 兒	使 為	使 看	使 負	使 氣	使 能	使 蚊 負 山	
使 起	使 動	使 帶	使 得	使 您	使 現	使 被	使 貪 使 愚	
使 最	使 喚	使 惡	使 智 使 勇	使 無	使 然	使 著	使 當	
使 節	使 該	使 達	使 過	使 對	使 慣	使 與	使 領 館	
使 熱	使 遭	使 館	使 獲	使 臂 使 指	使 壞	佬 族	供 人	
供 大 於 求	供 不 應 求	供 方	供 水	供 水 栓	供 片	供 以	供 出	
供 住	供 佛	供 作	供 求	供 求 矛 盾	供 求 關 係	供 奉	供 油	
供 物	供 狀	供 信	供 品	供 述	供 桌	供 氣	供 神	
供 售	供 產 銷	供 貨	供 給	供 給 制	供 給 者	供 給 量	供 詞	
供 量	供 暖	供 資	供 過 於 求	供 電	供 電 局	供 電 系 統	供 稱	
供 認	供 認 不 諱	供 需	供 需 矛 盾	供 需 見 面	供 價	供 熱	供 稿	
供 銷	供 銷 合 作 社	供 銷 系 統	供 銷 社	供 銷 部 門	供 養	供 膳	供 應	
供 應 者	供 應 站	供 應 商	供 應 量	供 應 價 格	供 應 標 準	供 應 點	供 應 體 制	
供 糧	供 職	供 證	例 子	例 文	例 句	例 外	例 示	
例 如	例 行	例 行 公 事	例 言	例 案	例 假	例 假 日 除 外	例 規	
例 程	例 項	例 會	例 題	例 證	來 人	來 人 來 函	來 已	
來 不	來 不 了	來 不 及	來 不 得	來 之	來 之 不 易	來 手	來 文	
來 日	來 日 大 難	來 日 方 長	來 日 正 長	來 月 經	來 水	來 火	來 世	
來 世 論	來 去	來 去 匆 匆	來 去 自 由	來 犯	來 犯 之 敵	來 生	來 由	
來 件	來 回	來 回 票	來 地	來 安	來 年	來 式	來 此	
來 自	來 自 於	來 舟	來 作	來 吧	來 呀	來 抓	來 京	
來 來	來 來 往 往	來 函	來 到	來 往	來 往 港 口	來 的	來 的 人	
來 者	來 者 不 拒	來 者 不 善	來 信	來 勁	來 客	來 看	來 風	
來 個	來 拿 去	來 料	來 料 加 工	來 書	來 氣	來 做	來 唱	
來 得	來 得 及	來 接	來 猜	來 聊 天	來 處	來 訪	來 訪 者	
來 貨	來 這	來 就	來 復 電 路	來 給	來 華	來 華 訪 問	來 著	
來 勢	來 勢 兇 猛	來 勢 洶 洶	來 意	來 源	來 源 於	來 碗	來 義 鄉	
來 試	來 路	來 過	來 電	來 福 槍	來 說	來 賓	來 鳳	
來 寫	來 敵	來 樣	來 樣 加 工	來 潮	來 稿	來 請	來 養	
來 歷	來 歷 不 明	來 遲	來 頭	來 龍 去 脈	來 臨	來 講	來 蹤	
來 蹤 去 跡	來 蘇	來 襲	來 變	侃 山	侃 侃	侃 侃 而 談	侃 侃 諤 諤	
併 合	併 吞	併 發 症	併 購	併 攏	侈 奢	侈 談	佩 刀	
佩 玉	佩 地	佩 服	佩 花	佩 思	佩 韋 佩 弦	佩 帶	佩 掛	
佩 飾	佩 劍	佩 戴	侏 儒	侏 儒 觀 戲	侏 羅	侏 羅 紀	兔 子	
兔 子 窩	兔 毛	兔 皮	兔 年	兔 死 狗 烹	兔 死 狐 悲	兔 肉	兔 角 龜 毛	
兔 走 烏 飛	兔 走 鳥 飛	兔 兒	兔 唇	兔 料	兔 起 鳧 舉	兔 起 鶻 落	兔 脯	
兔 脫	兔 絲 燕 麥	兔 盡 狗 烹	兔 類	兔 崽 子	兒 人	兒 女	兒 女 之 情	
兒 女 心 腸	兒 女 情 多	兒 女 情 長	兒 子	兒 子 般	兒 手	兒 去	兒 老	
兒 車	兒 科	兒 科 學	兒 音	兒 倆	兒 們	兒 孫	兒 時	
兒 書	兒 茶	兒 茶 酚	兒 馬	兒 啊	兒 童	兒 童 心 理 學	兒 童 受 虐	
兒 童 受 虐 事 件	兒 童 節	兒 童 團	兒 童 劇 團	兒 童 樂 園	兒 媳	兒 媳 婦	兒 歌	
兒 語	兒 戲	兩 人	兩 三 個	兩 下	兩 下 子	兩 千	兩 叉	
兩 口	兩 口 子	兩 大	兩 大 陣 營	兩 大 黨	兩 小 無 猜	兩 不	兩 分	
兩 分 法	兩 分 鐘	兩 匹	兩 天	兩 手	兩 手 空 空	兩 支	兩 方	
兩 方 面	兩 日	兩 月	兩 毛	兩 世 為 人	兩 代	兩 半	兩 可	
兩 只	兩 台	兩 句	兩 本	兩 用	兩 用 人 才	兩 用 衫	兩 立	
兩 件	兩 件 式	兩 份	兩 全	兩 全 其 美	兩 向	兩 名	兩 回	
兩 回 事	兩 地	兩 字	兩 州	兩 年	兩 次	兩 次 三 番	兩 江	
兩 羽 狀	兩 耳	兩 肋	兩 肋 插 刀	兩 色	兩 行	兩 位	兩 利	
兩 宋 時 代	兩 步	兩 角	兩 豆 塞 耳	兩 足	兩 車	兩 迄	兩 例	
兩 兩	兩 兩 三 三	兩 制	兩 周	兩 岸	兩 岸 三 地	兩 岸 政 策	兩 岸 經 貿	
兩 岸 關 係	兩 性	兩 抵	兩 者	兩 者 之 間	兩 者 都	兩 虎 共 鬥	兩 虎 相 爭	
兩 虎 相 鬥	兩 便	兩 便 士	兩 則	兩 指	兩 星 期	兩 省	兩 相	
兩 相 情 願	兩 秒	兩 軍	兩 重	兩 重 性	兩 面	兩 面 三 刀	兩 面 凹	
兩 面 凸	兩 面 性	兩 面 派	兩 倍	兩 個	兩 個 文 明	兩 個 月	兩 個 建 設	
兩 個 基 本 點	兩 唇	兩 唇 形	兩 套	兩 家	兩 座	兩 徑 間	兩 旁	
兩 晉 時 代	兩 根	兩 班	兩 級	兩 訖	兩 院	兩 院 制	兩 側	
兩 圈	兩 國	兩 國 人 民	兩 國 之 間	兩 國 間	兩 國 論	兩 國 關 係	兩 張	
兩 強 相 鬥	兩 得	兩 排	兩 敗	兩 敗 俱 傷	兩 條	兩 條 路 線	兩 條 道 路	
兩 條 腿 走 路	兩 淮	兩 瓶	兩 眼	兩 眼 發 黑	兩 袖	兩 袖 清 風	兩 部	
兩 部 分	兩 場	兩 廂	兩 廂 情 願	兩 棲	兩 棲 作 戰	兩 棲 進 攻	兩 棲 類	
兩 湖	兩 筆	兩 間	兩 項	兩 塊	兩 極	兩 極 分 化	兩 極 性	
兩 歲	兩 萬	兩 義	兩 腳	兩 腳 台	兩 腳 規	兩 葉 掩 目	兩 路	
兩 鼠 斗 穴	兩 睡	兩 種	兩 種 制 度	兩 端	兩 維	兩 腿	兩 價	
兩 層	兩 廣	兩 樣	兩 碼	兩 碼 事	兩 線	兩 輛	兩 輪	
兩 頰	兩 頭	兩 頭 白 面	兩 翼	兩 聲	兩 臂	兩 鍵	兩 顆	
兩 點	兩 點 論	兩 斷	兩 瞽 相 扶	兩 邊	兩 難	兩 類	兩 黨	
兩 黨 關 係	兩 霸	兩 權 分 離	兩 鬢	具 文	具 交	具 名	具 有	
具 備	具 備 條 件	具 結	具 體	具 體 化	具 體 地 說	具 體 而 微	具 體 來 說	
具 體 勞 動	具 體 說 來	其 一	其 二	其 人	其 人 其 事	其 三	其 下	
其 上	其 中	其 中 之 一	其 內	其 反	其 父	其 他	其 他 人	
其 他 布	其 他 運 動	其 他 類	其 他 類 股	其 外	其 它	其 它 的	其 它 窗 口	
其 母	其 生	其 名	其 次	其 色	其 形	其 言	其 事	
其 來	其 味	其 味 無 窮	其 所	其 的	其 後	其 是	其 為	
其 害	其 家	其 時	其 情	其 處	其 然	其 短	其 詞	
其 量	其 間	其 勢	其 勢 洶 洶	其 解	其 境	其 實	其 實 不 然	
其 實 難 副	其 說	其 貌	其 貌 不 揚	其 數	其 樂	其 樂 不 窮	其 樂 無 窮	
其 談	其 餘	其 應 若 響	其 辭	其 難	典 出 人	典 刑	典 式	
典 押	典 型	典 型 示 範	典 型 的	典 型 調 查	典 契	典 故	典 借	
典 書	典 章	典 章 制 度	典 雅	典 當	典 當 商	典 當 業	典 裝	
典 獄	典 價	典 範	典 賣	典 禮	典 藏	典 籍	函 大	
函 內	函 令	函 件	函 作	函 告	函 索	函 商	函 授	
函 授 大 學	函 授 生	函 授 教 育	函 授 部	函 授 學 校	函 發	函 詢	函 電	
函 數	函 請	函 調	函 館	函 購	刻 了	刻 刀	刻 下	
刻 上	刻 不 容 緩	刻 木 為 吏	刻 出	刻 本	刻 印	刻 在	刻 字	
刻 成	刻 有	刻 肌 刻 骨	刻 舟	刻 舟 求 劍	刻 足 適 屨	刻 其	刻 制	
刻 於	刻 板	刻 版	刻 物	刻 度	刻 度 尺	刻 毒	刻 為	
刻 苦	刻 苦 自 勵	刻 苦 耐 勞	刻 紋	刻 記	刻 骨	刻 骨 銘 心	刻 骨 鏤 心	
刻 痕	刻 細	刻 畫	刻 畫 無 鹽	刻 絲	刻 意	刻 劃	刻 蝕	
刻 寫	刻 線	刻 薄	刻 薄 話	刻 鐘	券 別	券 面	券 商	
券 商 公 會	券 種	刷 上	刷 子	刷 牙	刷 卡 機	刷 去	刷 白	
刷 色	刷 洗	刷 新	刷 新 紀 錄	刷 漆	刷 寫	刺 人	刺 入	
刺 刀	刺 孔	刺 毛 輥	刺 出	刺 史	刺 目	刺 刑	刺 字	
刺 死	刺 耳	刺 住	刺 兒	刺 兒 頭	刺 刺	刺 刺 不 休	刺 股	
刺 股 懸 樑	刺 青	刺 客	刺 穿	刺 捕	刺 破	刺 配	刺 針 飛 彈	
刺 骨	刺 骨 懸 樑	刺 探	刺 探 者	刺 殺	刺 痕	刺 眼	刺 透	
刺 畫	刺 痛	刺 進	刺 開	刺 傷	刺 槐	刺 網	刺 鼻	
刺 激	刺 激 性	刺 激 物	刺 激 者	刺 激 劑	刺 叢	刺 戳	刺 繡	
刺 蝟	到 一 起	到 了	到 人	到 下	到 上 面	到 中 途	到 之	
到 今	到 今 天 為 止	到 戶	到 手	到 本 世 紀 末	到 目 前 為 止	到 任	到 有	
到 此	到 此 為 止	到 此 處	到 自	到 位	到 尾	到 來	到 岸	
到 底	到 者	到 某 處	到 家	到 庭	到 旁 邊	到 時	到 時 候	
到 時 候 再 說	到 校	到 站	到 國 外	到 現 在 為 止	到 處	到 訪	到 貨	
到 頂	到 場	到 期	到 港	到 會	到 群 眾 中 去	到 達	到 達 者	
到 達 站	到 過	到 齊	到 數	到 頭	到 頭 來	到 點	到 職	
刮 刀	刮 勺	刮 大 風	刮 毛	刮 出	刮 去	刮 平	刮 皮	
刮 目	刮 目 相 待	刮 目 相 看	刮 目 相 視	刮 光	刮 在	刮 舌	刮 刮	
刮 弧	刮 削	刮 垢 磨 光	刮 宮	刮 破	刮 起	刮 除	刮 骨	
刮 骨 刀	刮 匙	刮 得	刮 掉	刮 傷	刮 腸 洗 胃	刮 過	刮 鼻 子	
刮 錢	刮 臉	刮 鬍 刀	刮 鬍 子	刮 痧	制 止	制 止 物	制 止 者	
制 止 動 亂	制 伏	制 件	制 式	制 住	制 取	制 定	制 服	
制 板 機	制 空	制 空 權	制 門 器	制 度	制 度 上	制 度 化	制 約	
制 約 力	制 訂	制 革	制 革 廠	制 氣	制 海 權	制 釘 者	制 高 點	
制 做	制 動	制 動 閘	制 動 器	制 動 機	制 得	制 備	制 勝	
制 勝 因 素	制 單	制 景	制 裁	制 黃	制 黃 販 黃	制 幣	制 敵	
制 熱	制 鞋	制 劑	制 導	制 導 技 術	制 導 武 器	制 憲	制 憲 會 議	
制 糖	制 糖 廠	制 衡	制 錢	制 鹽	剁 者	剁 碎	卒 子	
卒 中	卒 於	卒 歲	協 人	協 力	協 力 同 心	協 心 同 力	協 同	
協 同 作 戰	協 同 通 信	協 同 學	協 作	協 作 者	協 作 單 位	協 作 關 係	協 助	
協 助 者	協 和	協 定	協 性	協 奏	協 奏 曲	協 查	協 洽	
協 約	協 約 國	協 迫	協 商	協 商 一 致	協 商 者	協 商 會 議	協 從	
協 理	協 處	協 稅	協 會	協 談	協 調	協 調 委 員 會	協 調 官	
協 調 者	協 調 發 展	協 調 會	協 調 論	協 辦	協 議	協 議 書	卓 有	
卓 有 成 效	卓 見	卓 約	卓 然	卓 然 不 群	卓 絕	卓 著	卓 越	
卓 溪	卓 溪 鄉	卓 葷 不 羈	卓 資	卓 爾 不 群	卓 爾 出 群	卓 識	卓 蘭	
卑 下	卑 己 自 牧	卑 之 無 甚 高 論	卑 以 自 牧	卑 劣	卑 劣 下 流	卑 污	卑 屈	
卑 怯	卑 俗	卑 南 鄉	卑 陋	卑 陋 齷 齪	卑 宮 菲 食	卑 恭	卑 恭 屈 節	
卑 躬 屈 節	卑 躬 屈 膝	卑 視	卑 微	卑 遜	卑 鄙	卑 鄙 的 人	卑 鄙 無 恥	
卑 賤	卑 謙	卑 禮 厚 幣	卑 職	卑 辭	卑 辭 厚 禮	卦 算	卷 子	
卷 毛	卷 片	卷 冊	卷 布	卷 帆 索	卷 收	卷 有	卷 兒	
卷 宗	卷 首	卷 紙	卷 紙 煙	卷 揚 機	卷 軸	卷 裝	卷 旗 息 鼓	
卷 緊	卷 餅	卷 層 雲	卷 標	卷 髮	卷 髮 紙	卷 髮 器	卷 積 雲	
卷 頭	卷 邊	卷 帙	卸 下	卸 下 船	卸 上	卸 去	卸 任	
卸 妝	卸 車	卸 肩	卸 除	卸 掉	卸 脫	卸 貨	卸 貨 人	
卸 煤 機	卸 裝	卸 載	卸 鞍	卸 橋	卸 磨 殺 驢	取 刀	取 下	
取 才	取 之	取 之 不 保	取 之 不 盡	取 之 不 盡 用 之 不 竭	取 之 於	取 水	取 火	
取 代	取 出	取 去	取 巧	取 用	取 向	取 名	取 名 為	
取 回	取 而	取 而 代 之	取 自	取 材	取 決	取 決 於	取 走	
取 來	取 其	取 法	取 物	取 的	取 長 補 短	取 青 配 白	取 信	
取 信 於 民	取 保	取 值	取 悅	取 悅 於	取 書	取 消	取 消 後	
取 消 組	取 笑	取 送	取 得	取 得 實 效	取 掉	取 捨	取 捨 權	
取 教	取 貨	取 勝	取 景	取 款	取 給	取 費	取 暖	
取 經	取 道	取 盡	取 精	取 精 用 弘	取 綽 號	取 齊	取 樣	
取 樂	取 締	取 閱	取 整	取 錢	取 靜	取 證	叔 公	
叔 父	叔 母	叔 伯	叔 叔	叔 祖	叔 婆	叔 嫂	叔 舅	
叔 嬸	叔 侄	受 了	受 人	受 力	受 不 了	受 之	受 之 有 愧	
受 支 配	受 主	受 孕	受 打	受 用	受 刑	受 好 評	受 托	
受 托 人	受 有	受 血 者	受 住	受 作	受 困	受 困 惑	受 戒	
受 災	受 災 面 積	受 刺 激	受 到	受 到 了	受 到 好 評	受 到 重 視	受 到 限 制	
受 到 破 壞	受 到 影 響	受 到 衝 擊	受 制	受 命	受 奉	受 治 於	受 治 療	
受 阻	受 非 難	受 信	受 信 人	受 保 人	受 俘	受 封	受 後 付 款	
受 洗	受 看	受 約 人	受 約 束	受 胎	受 苦	受 苦 受 難	受 苦 者	
受 虐 待	受 重 視	受 限	受 限 制	受 降	受 俸	受 俸 者	受 凍	
受 害	受 害 人	受 害 者	受 恐 怖	受 恐 慌	受 挫	受 挫 折	受 氣	
受 益	受 益 人	受 益 不 淺	受 益 者	受 益 匪 淺	受 益 憑 證	受 粉	受 訓	
受 辱	受 夠	受 控	受 控 制	受 救	受 教	受 涼	受 理	
受 累	受 創 傷	受 寒	受 尊 敬	受 惠	受 惠 者	受 援	受 款 人	
受 窘	受 著	受 詛 咒	受 雇	受 雇 者	受 傷	受 傷 者	受 傷 處	
受 損	受 損 失	受 損 害	受 業	受 祿	受 罪	受 聘	受 試	
受 話 器	受 賄	受 賄 者	受 賄 案	受 賄 罪	受 過	受 頒	受 僱 用	
受 盡	受 精	受 精 卵	受 罰	受 領	受 審	受 德	受 敵	
受 潮	受 熱	受 獎	受 賞	受 勳	受 操 縱	受 遺	受 擊	
受 邀	受 霜 害	受 禮	受 寵	受 寵 若 驚	受 贈	受 贈 者	受 難	
受 難 者	受 騙	受 騙 上 當	受 權	受 歡 迎	受 聽	受 驚	受 驚 嚇	
受 體	受 讓	受 讓 人	受 澇	味 王	味 王 公 司	味 汁	味 甘 美	
味 全	味 全 食 品	味 同 嚼 臘	味 同 嚼 蠟	味 好	味 如 雞 肋	味 如 嚼 蠟	味 兒	
味 美	味 差	味 料	味 素	味 淡	味 著	味 道	味 道 好	
味 道 差	味 精	味 數	味 濃	味 蕾	味 覺	呵 欠	呵 欠 蟲	
呵 叱	呵 斥	呵 成	呵 佛 罵 祖	呵 呵	呵 氣	呵 責	呵 喝	
呵 壁 問 天	呵 癢	呵 護	咖 哩	咖 哩 汁	咖 哩 粉	咖 啡	咖 啡 色	
咖 啡 豆	咖 啡 店	咖 啡 粉	咖 啡 茶	咖 啡 壺	咖 啡 館	咖 啡 鹼	咖 啡 廳	
咖 喱	呸 聲	咕 叫	咕 咕	咕 咚	咕 嘟	咕 噥	咕 嚕	
咀 嚼	呻 吟	呻 吟 聲	呷 茶	咄 咄	咄 咄 怪 事	咄 咄 逼 人	咄 嗟 便 辦	
咒 文	咒 符	咒 逐	咒 詛	咒 語	咒 罵	咆 哮	咆 哮 如 雷	
咆 哮 者	咆 哮 聲	咆 嘯	呼 入	呼 之 即 來	呼 之 即 來 揮 之 即 去	呼 之 欲 出	呼 天 搶 地	
呼 孔	呼 牛 作 馬	呼 牛 呼 馬	呼 出	呼 叫	呼 叫 者	呼 叫 器	呼 市	
呼 地	呼 吸	呼 吸 作 用	呼 吸 系 統	呼 吸 者	呼 吸 相 通	呼 吸 氣	呼 吸 道	
呼 吸 器	呼 呼	呼 呼 大 睡	呼 和 浩 特	呼 和 浩 特 市	呼 庚 呼 癸	呼 朋 引 類	呼 的	
呼 風 喚 雨	呼 倫 貝 爾 盟	呼 氣	呼 啦	呼 啦 啦	呼 救	呼 救 聲	呼 喊	
呼 喊 者	呼 喚	呼 嗤	呼 號	呼 鼓 而 攻 之	呼 麼 喝 六	呼 嘯	呼 嘯 山 莊	
呼 嘯 聲	呼 機	呼 盧 喝 雉	呼 應	呼 聲	呼 聲 最 高	呼 嚕	呼 蘭	
呼 響	呼 籲	呼 籲 書	呼 哧	呱 呱	呱 呱 叫	呶 呶	呶 呶 不 休	
和 大 工 業	和 平	和 平 力 量	和 平 友 好	和 平 主 義	和 平 共 處	和 平 利 用	和 平 建 議	
和 平 區	和 平 統 一	和 平 統 一 祖 國	和 平 部 隊	和 平 鄉	和 平 隊	和 平 裡	和 平 解 決	
和 平 運 動	和 平 過 渡	和 平 演 變	和 平 談 判	和 平 鴿	和 平 競 賽	和 田	和 立 科 技	
和 光 同 塵	和 好	和 成 欣 業	和 而 不 同	和 局	和 我	和 事 佬	和 和 氣 氣	
和 尚	和 弦	和 或	和 旺 建 設	和 服	和 信 投 顧	和 政	和 約	
和 美	和 面 板	和 音	和 風	和 風 細 雨	和 風 麗 日	和 家 馨	和 容 悅 氣	
和 悅	和 桐 化 學	和 氣	和 氣 生 財	和 氣 致 祥	和 泰 汽 車	和 益 化 工	和 衷 共 濟	
和 混	和 棋	和 稀 泥	和 善	和 暖	和 會	和 煦	和 睦	
和 睦 相 處	和 解	和 解 人	和 解 性	和 解 者	和 解 稅	和 詩	和 碩	
和 數	和 樂	和 盤 托 出	和 緩	和 談	和 親	和 親 政 策	和 諧	
和 諧 一 致	和 靜	和 龍	和 聲	和 聲 學	和 璧 隋 珠	和 顏 悅 色	和 藹	
和 藹 可 親	和 議	咚 咚	呢 子	呢 喃	呢 喃 細 語	呢 帽	呢 絨	
呢 絨 商	呢 稱	周 口	周 六	周 公 吐 哺	周 天	周 日	周 代	
周 未	周 正	周 全	周 地	周 而 不 比	周 至	周 折	周 角	
周 到	周 易	周 波	周 知	周 長	周 俊 偉	周 急 繼 乏	周 界	
周 相	周 郎 顧 曲	周 密	周 旋	周 率	周 圍	周 圍 環 境	周 華 健	
周 詳	周 遊	周 遊 世 界	周 遍	周 夢 蝶	周 慧 婷	周 潤 發	周 線	
周 濟	周 薪	周 禮	周 轉	周 轉 率	周 轉 期	周 轉 量	周 轉 資 金	
周 邊	周 邊 設 備	咋 回 事	咋 舌	咋 呼	咋 辦	命 人	命 中	
命 中 注 定	命 中 率	命 世 之 才	命 令	命 令 式	命 令 行	命 令 書	命 名	
命 名 人	命 名 大 會	命 名 者	命 名 為	命 定	命 苦	命 案	命 根	
命 根 子	命 脈	命 筆	命 該	命 運	命 運 攸 關	命 儔 嘯 侶	命 薄	
命 題	命 蹇 時 乖	咎 由 自 取	咎 於	固 化	固 化 劑	固 本	固 用	
固 件	固 守	固 有	固 有 性	固 有 振 蕩	固 有 頻 率	固 色 劑	固 步 自 封	
固 沙	固 沙 林	固 始	固 定	固 定 物	固 定 通 信 網 路	固 定 資 本	固 定 資 產	
固 定 器	固 持	固 持 己 見	固 若 金 湯	固 原	固 執	固 執 己 見	固 執 者	
固 堤	固 氮	固 氮 菌	固 然	固 結	固 著	固 溶 體	固 置	
固 態	固 網	固 緯 電 子	固 醇	固 鎮	固 體	固 體 性	固 體 物	
固 體 燃 料	垃 圾	垃 圾 堆	垃 圾 掩 埋 場	垃 圾 桶	垃 圾 處 理	垃 圾 場	垃 圾 費	
垃 圾 箱	垃 圾 蟲	坷 垃	坪 林 鄉	坪 壩	坩 堝	坩 鍋	坡 田	
坡 地	坡 狀	坡 度	坡 路	坡 道	坦 平	坦 白	坦 白 從 寬	
坦 克	坦 克 部 隊	坦 言	坦 坦	坦 尚 尼 亞	坦 承	坦 直	坦 桑 尼 亞	
坦 胸	坦 率	坦 途	坦 陳 衷 曲	坦 然	坦 然 自 若	坦 腹	坦 腹 東 床	
坦 誠	坦 誠 相 見	坦 誠 相 待	坦 說	坦 噶	坦 蕩	坦 懷	坦 露	
夜 叉	夜 大	夜 大 學	夜 工	夜 不 能 寐	夜 不 閉 戶	夜 月 花 朝	夜 以 接 日	
夜 以 繼 日	夜 以 繼 晝	夜 半	夜 半 三 更	夜 市	夜 生 活	夜 光	夜 光 雲	
夜 曲	夜 色	夜 行	夜 行 被 繡	夜 車	夜 來	夜 來 香	夜 夜	
夜 明 珠	夜 的	夜 盲	夜 盲 症	夜 空	夜 長	夜 長 夢 多	夜 雨 對 床	
夜 郎	夜 郎 自 大	夜 宵	夜 校	夜 班	夜 航	夜 晚	夜 深	
夜 深 人 靜	夜 閉	夜 場	夜 壺	夜 景	夜 盜	夜 短	夜 視	
夜 視 技 術	夜 視 儀	夜 視 器 材	夜 間	夜 間 部	夜 勤	夜 裡	夜 話	
夜 賊	夜 遊	夜 遊 神	夜 幕	夜 談	夜 課	夜 戰	夜 貓	
夜 靜 更 長	夜 靜 更 深	夜 靜 更 闌	夜 餐	夜 總 會	夜 闌 人 靜	夜 禮 服	夜 禱	
夜 霧	夜 警	夜 鶯	夜 襲	夜 讀	夜 讀 拾 零	夜 鷹	夜 鷺	
奉 上	奉 上 一 函	奉 公	奉 公 不 阿	奉 公 守 法	奉 公 執 法	奉 天	奉 天 承 運	
奉 令	奉 令 承 教	奉 召	奉 如 神 明	奉 旨	奉 此	奉 行	奉 行 者	
奉 行 故 事	奉 告	奉 系 軍 閥	奉 命	奉 命 唯 謹	奉 承	奉 承 者	奉 祀	
奉 迎	奉 為	奉 為 神	奉 為 楷 模	奉 約	奉 若 神 明	奉 送	奉 悉	
奉 陪	奉 陪 到 底	奉 揚 仁 風	奉 新	奉 節	奉 道 齋 僧	奉 賢	奉 養	
奉 頭 鼠 竄	奉 還	奉 職	奉 贈	奉 辭 伐 罪	奉 勸	奉 獻	奉 獻 物	
奉 獻 者	奉 獻 給	奉 獻 精 神	奉 獻 禮	奇 人	奇 山 異 水	奇 才	奇 心	
奇 文 共 賞	奇 文 瑰 句	奇 功	奇 巧	奇 兵	奇 妙	奇 形 怪 狀	奇 志	
奇 技 淫 巧	奇 言	奇 事	奇 奇 怪 怪	奇 怪	奇 招	奇 花 異 卉	奇 花 異 草	
奇 門 遁 甲	奇 思	奇 珍 異 寶	奇 峰	奇 恥 大 辱	奇 效	奇 校 驗	奇 特	
奇 特 性	奇 缺	奇 偶	奇 情	奇 異	奇 異 幻 想	奇 術	奇 貨	
奇 貨 可 居	奇 寒	奇 普 仕	奇 景	奇 想	奇 想 家	奇 葩	奇 裝 異 服	
奇 詩	奇 跡	奇 跡 般 地	奇 遇	奇 境	奇 禍	奇 聞	奇 聞 怪 事	
奇 語	奇 貌	奇 劇	奇 數	奇 熱	奇 緣	奇 談	奇 談 怪 論	
奇 趣	奇 謀	奇 牆 外 漢	奇 醜	奇 龐 福 艾	奇 癢	奇 襲	奇 襲 者	
奇 觀	奇 伎 淫 巧	奈 及 利 亞	奈 何	奈 何 以 死 懼 之	奈 良	奈 良 市	奈 特	
奄 奄	奄 奄 一 息	奄 然 而 逝	奔 去	奔 向	奔 忙	奔 走	奔 走 之 友	
奔 走 如 市	奔 走 呼 號	奔 走 相 告	奔 車 朽 索	奔 命	奔 放	奔 波	奔 流	
奔 赴	奔 逃	奔 喪	奔 湧	奔 跑	奔 跑 戲 耍	奔 逸 絕 塵	奔 跳	
奔 馳	奔 駛	奔 頭	奔 瀉	奔 騰	奔 襲	妾 身	妾 侍	
妾 婦	妻 女	妻 子	妻 兒 老 小	妻 妾	妻 室	妻 離 子 散	委 內 瑞 拉	
委 以	委 付	委 用	委 任	委 任 狀	委 任 者	委 曲	委 曲 求 全	
委 肉 虎 蹊	委 身	委 制	委 屈	委 屈 成 全	委 屈 周 全	委 派	委 為	
委 重 投 艱	委 員	委 員 長	委 員 會	委 託	委 託 人	委 託 物	委 託 者	
委 託 書	委 婉	委 常 之 懼	委 部	委 罪	委 聘	委 頓	委 實	
委 辦	委 靡 不 振	妹 子	妹 夫	妹 妹	妹 婿	姑 丈	姑 夫	
姑 父	姑 且	姑 奶	姑 奶 奶	姑 母	姑 妄	姑 妄 言 之	姑 妄 試 之	
姑 妄 聽 之	姑 老 爺	姑 姑	姑 表	姑 娘	姑 娘 家	姑 射 神 人	姑 息	
姑 息 者	姑 息 遷 就	姑 息 養 奸	姑 婆	姑 媽	姑 嫂	姑 爺	姑 舅	
姆 指	姐 丈	姐 夫	姐 弟	姐 兒	姐 妹	姐 妹 班	姐 姐	
姐 們 兒	姍 姍	姍 姍 來 遲	始 末	始 生 代	始 自	始 行	始 作 俑 者	
始 定	始 於	始 於 足 下	始 建 於	始 皇	始 料	始 料 所 及	始 祖	
始 能	始 動	始 終	始 終 一 貫	始 終 不 渝	始 終 不 懈	始 終 如 一	始 終 保 持	
始 發	始 發 站	始 亂 終 棄	始 興	始 點	姓 氏	姓 名	姓 名 權	
姊 妹	妯 娌	孟 子	孟 加	孟 加 拉	孟 加 拉 國	孟 庭 葦	孟 庭 麗	
孟 買	孟 買 市	孟 詩 韓 筆	孟 德 斯 鳩	孤 女	孤 山	孤 本	孤 立	
孤 立 無 助	孤 立 無 援	孤 立 點	孤 老	孤 臣 孽 子	孤 行	孤 行 己 見	孤 行 己 意	
孤 形 弔 影	孤 形 只 影	孤 形 單 影	孤 身	孤 身 一 人	孤 身 只 影	孤 兒	孤 兒 院	
孤 兒 寡 母	孤 兒 寡 婦	孤 孤 單 單	孤 注 一 擲	孤 芳 自 賞	孤 苦	孤 苦 伶 仃	孤 軍	
孤 軍 作 戰	孤 軍 深 入	孤 軍 奮 戰	孤 陋	孤 陋 寡 聞	孤 家 寡 人	孤 峰	孤 島	
孤 高	孤 高 自 許	孤 寂	孤 貧	孤 單	孤 掌 難 鳴	孤 雲 野 鶴	孤 傲	
孤 零	孤 零 零	孤 寡	孤 寡 老 人	孤 聞	孤 雌 生 殖	孤 魂	孤 僻	
孤 獨	孤 獨 心 理 學	孤 獨 感	孤 膽	孤 膽 英 雄	孤 點	孤 雛 腐 鼠	孤 犢 觸 乳	
孤 孀	孤 鸞 寡 鶴	季 刊	季 布 一 諾	季 末	季 花	季 初	季 度	
季 軍	季 風	季 風 氣 候	季 候 風	季 孫 之 憂	季 常 之 懼	季 票	季 報	
季 節	季 節 性	季 節 風	季 節 差 價	季 稻	宗 主	宗 主 國	宗 主 權	
宗 兄	宗 史	宗 旨	宗 姓	宗 法	宗 法 觀 念	宗 室	宗 派	
宗 派 主 義	宗 師	宗 祠	宗 教	宗 教 上	宗 教 信 仰	宗 教 政 策	宗 教 界	
宗 教 團 體	宗 教 儀 式	宗 教 斂 財	宗 族	宗 廟	宗 廟 丘 墟	宗 親	宗 親 會	
宗 譜	宗 權	宗 祧	定 了	定 人	定 力	定 下	定 上	
定 子	定 不	定 心	定 心 丸	定 日	定 比	定 出	定 向	
定 名	定 名 為	定 名 稱	定 好	定 存	定 州	定 式	定 有	
定 色	定 位	定 位 器	定 作	定 址	定 局	定 序	定 形	
定 見	定 角 色	定 言	定 使	定 來	定 居	定 居 者	定 居 點	
定 弦	定 性	定 性 分 析	定 於	定 於 一 尊	定 版	定 物	定 的	
定 的 話	定 金	定 則	定 型	定 律	定 為	定 界	定 界 限	
定 界 符	定 界 線	定 約	定 苗	定 要	定 計	定 計 劃	定 限	
定 音	定 音 鼓	定 准	定 員	定 座	定 息	定 時	定 時 炸 彈	
定 時 間	定 時 器	定 案	定 格	定 海	定 神	定 級	定 能	
定 做	定 婚	定 崗	定 理	定 產	定 規	定 貨	定 都	
定 陪	定 陵	定 陶	定 單	定 幅	定 期	定 期 性	定 然	
定 稅	定 稅 額	定 等 級	定 結	定 距	定 量	定 量 分 析	定 量 配	
定 項	定 順 序	定 會	定 滑 輪	定 當	定 睛	定 置	定 罪	
定 義	定 義 域	定 奪	定 製	定 語	定 價	定 寬	定 影	
定 影 劑	定 數	定 數 額	定 樣	定 標	定 標 器	定 稿	定 編	
定 調	定 調 子	定 論	定 親	定 錢	定 購	定 點	定 職	
定 職 位	定 額	定 額 工 資 制	定 額 管 理	官 人	官 方	官 方 化	官 止 神 行	
官 令	官 冊	官 司	官 田	官 田 鄉	官 吏	官 吏 們	官 名	
官 地	官 式	官 式 訪 問	官 位	官 兵	官 兵 一 致	官 兵 關 係	官 使	
官 兒	官 制	官 官	官 官 相 為	官 官 相 護	官 府	官 服	官 法 如 爐	
官 邸	官 長	官 宦	官 架	官 架 子	官 軍	官 倒	官 員	
官 家	官 差	官 氣	官 級	官 能	官 能 團	官 虔 吏 狠	官 商	
官 商 合 資	官 情 紙 薄	官 紳	官 場	官 場 如 戲	官 報	官 報 私 仇	官 復 原 職	
官 腔	官 詞	官 階	官 祿	官 署	官 衙	官 話	官 運	
官 運 亨 通	官 道	官 逼	官 逼 民 反	官 僚	官 僚 主 義	官 僚 資 本	官 僚 資 本 主 義	
官 銜	官 餉	官 價	官 樣	官 樣 文 章	官 窯	官 學	官 辦	
官 營	官 爵	官 癖	官 職	官 轎	官 屬	官 癮	官 廳	
宜 人	宜 中	宜 在	宜 於	宜 昌	宜 室 宜 家	宜 將	宜 喜 宜 嗔	
宜 進 實 業	宜 敲 勿 捧	宜 賓	宜 興	宜 蘭	宜 蘭 農 專	宜 蘭 縣 史 館	宜 嗔 宜 喜	
宙 斯	宛 如	宛 若	宛 然	宛 然 在 目	宛 轉	宛 蜒	尚 不	
尚 不 安	尚 方 寶 劍	尚 且	尚 可	尚 未	尚 在	尚 好	尚 有	
尚 克 勞 德 范 達 美	尚 志	尚 佳	尚 武	尚 待	尚 是	尚 看	尚 書	
尚 缺	尚 能	尚 無	尚 須	尚 感	尚 義	尚 需	尚 鋒 興 業	
尚 應	尚 難	尚 屬	屈 一 伸 萬	屈 下 身	屈 才	屈 水 性	屈 打 成 招	
屈 光	屈 光 度	屈 曲	屈 死	屈 伸	屈 身	屈 居	屈 服	
屈 服 於	屈 指	屈 指 一 算	屈 指 可 數	屈 流 性	屈 原	屈 辱	屈 從	
屈 尊	屈 尊 俯 就	屈 就	屈 撓	屈 膝	屈 駕	屈 艷 班 香	居 人	
居 下 訕 上	居 上	居 士	居 大 不 易	居 不 重 席	居 不 重 茵	居 中	居 中 調 停	
居 之 不 疑	居 仁 由 義	居 心	居 心 叵 測	居 世 界 前 列	居 世 界 首 位	居 世 界 第 一 位	居 世 界 領 先 地 位	
居 功	居 功 不 傲	居 功 自 恃	居 功 自 傲	居 功 厥 偉	居 民	居 民 身 份 證	居 民 委 員 會	
居 民 區	居 民 購 買 力	居 民 點	居 先	居 全 國 之 首	居 全 國 首 位	居 多	居 安 思 危	
居 安 慮 危	居 次	居 住	居 住 於	居 住 者	居 住 面 積	居 住 區	居 奇	
居 委 會	居 官 守 法	居 所	居 於	居 者	居 前	居 室	居 後	
居 首 功	居 首 位	居 家	居 留	居 留 權	居 高 不 下	居 高 臨 下	居 區	
居 處	居 喪	居 無 求 安	居 然	居 間	居 裡	居 領 先 地 位	居 點	
居 禮	屆 時	屆 期	屆 滿	屆 臨	岷 山	岷 江	岡 山	
岡 比 亞	岸 上	岸 的	岸 然	岸 然 道 貌	岸 標	岸 壁	岸 頭	
岸 邊	岳 丈	岳 父	岳 父 母	岳 母	岳 池	岳 西	岳 飛	
岳 翎	岳 陽	帖 子	帖 服	帕 米 爾	帛 品	帛 書	帛 琉	
帛 畫	幸 中	幸 勿	幸 未	幸 好	幸 而	幸 災 樂 禍	幸 事	
幸 甚	幸 得	幸 喜	幸 會	幸 運	幸 運 兒	幸 福	幸 福 人 壽	
幸 福 水 泥	幸 虧	庚 子	庚 午	庚 申	庚 戌	庚 癸 之 呼	店 內	
店 主	店 外	店 伙 計	店 名	店 東	店 面	店 面 廣 告	店 風	
店 員	店 家	店 堂	店 捨	店 裡	店 鈴	店 頭	店 頭 市 場	
店 頭 基 金	店 類	店 舖	府 上	府 中	府 尹	府 外	府 志	
府 邸	府 城	府 庫	府 第	府 綢	底 下	底 上	底 子	
底 分	底 孔	底 止	底 火	底 片	底 冊	底 本	底 色	
底 行	底 角	底 使	底 兒	底 抽	底 板	底 版	底 肥	
底 架	底 洞	底 限	底 面	底 座	底 框	底 特 律	底 特 律 老 虎 隊	
底 紋	底 帳	底 梁	底 細	底 船	底 貨	底 部	底 牌	
底 裡	底 墊	底 漆	底 獄	底 端	底 閥	底 價	底 寬	
底 層	底 數	底 樣	底 盤	底 碼	底 稿	底 線	底 褲	
底 襟	底 邊	底 蘊	庖 丁	庖 丁 解 牛	庖 疹	延 平 鄉	延 用	
延 安	延 安 精 神	延 年	延 年 益 壽	延 至	延 伸	延 性	延 拓	
延 於	延 長	延 後	延 展	延 展 性	延 時	延 時 器	延 報	
延 期	延 發 性	延 聘	延 壽	延 滯	延 誤	延 緩	延 請	
延 燒	延 穎 實 業	延 遲	延 頸 企 踵	延 頸 舉 踵	延 擱	延 邊	延 續	
延 髓	延 攬	延 宕	弦 子	弦 切 角	弦 比	弦 外 之 音	弦 外 之 意	
弦 音	弦 音 器	弦 規	弦 琴	弦 歌	弦 樂	弦 樂 隊	弦 樂 器	
弦 線	弦 器	弦 聲	弧 光	弧 光 燈	弧 形	弧 度	弧 面	
弧 菌	弧 線	弩 手	往 下	往 下 看	往 上	往 上 爬	往 上 調	
往 不	往 之	往 內	往 日	往 世	往 北	往 右	往 外	
往 外 看	往 左	往 回	往 年	往 西	往 西 南	往 那	往 那 裡	
往 事	往 例	往 來	往 其 所 以	往 往	往 昔	往 東	往 東 南	
往 直	往 返	往 返 運 輸	往 前	往 南	往 後	往 後 面	往 家	
往 時	往 常	往 情	往 訪	往 復	往 裡	往 裡 走	往 樓 上	
往 還	征 友	征 伐	征 地	征 自	征 衣	征 免	征 足	
征 到	征 服	征 服 者	征 派	征 訂	征 風 召 雨	征 借	征 納	
征 討	征 途	征 期	征 程	征 解	征 稿	征 戰	征 購	
征 購 糧	征 糧	征 繳	彼 一 時 此 一 時	彼 人	彼 伏	彼 此	彼 此 之 間	
彼 此 協 作	彼 岸	彼 倡 此 和	彼 時	彼 特	彼 側	彼 唱 此 和	彼 得	
彼 得 堡	彼 棄 我 取	彼 眾 我 寡	彼 處	彼 等	彼 竭 無 盈	忠 心	忠 心 赤 膽	
忠 心 耿 耿	忠 心 貫 日	忠 臣	忠 臣 不 事 二 主	忠 臣 烈 士	忠 臣 雙 全	忠 君 報 國	忠 君 愛 國	
忠 告	忠 告 者	忠 孝	忠 孝 兩 全	忠 孝 節 烈	忠 孝 節 義	忠 肝 義 膽	忠 良	
忠 言	忠 言 奇 謀	忠 言 逆 耳	忠 言 嘉 謨	忠 言 讜 論	忠 於	忠 於 祖 國	忠 於 職 守	
忠 信	忠 勇	忠 厚	忠 貞	忠 貞 不 渝	忠 烈	忠 貫 白 日	忠 順	
忠 義	忠 誠	忠 誠 人	忠 誠 老 實	忠 僕	忠 實	忠 實 於	忽 上 忽 下	
忽 左 忽 右	忽 必 烈	忽 地	忽 有	忽 米	忽 而	忽 冷	忽 身	
忽 兒	忽 忽	忽 忽 不 樂	忽 明	忽 飛	忽 哨	忽 起	忽 閃	
忽 高 忽 低	忽 悠	忽 現	忽 略	忽 減	忽 然	忽 然 間	忽 發	
忽 視	忽 滅	忽 落	忽 聞	忽 熱	忽 隱 忽 現	忽 聽	念 上	
念 之	念 及	念 心	念 以	念 冊	念 叨	念 本	念 白	
念 佛	念 念 不 忘	念 珠	念 茲 在 茲	念 起	念 著	念 詩	念 道	
念 過	念 錯	念 頭	念 舊	忿 不 顧 身	忿 忿	忿 怒	忿 恨	
忿 然 作 色	怏 怏	怏 怏 不 平	怏 怏 不 悅	怏 怏 不 樂	怏 然	怔 地	怔 怔	
怯 生	怯 生 生	怯 怯	怯 相	怯 弱	怯 陣	怯 羞	怯 場	
怯 意	怯 疑	怯 頭 怯 腦	怯 懦	怯 聲 怯 氣	怵 目 驚 心	怪 人	怪 力 亂 神	
怪 不	怪 不 得	怪 手	怪 叫	怪 石	怪 行	怪 事	怪 到	
怪 味	怪 念	怪 念 頭	怪 怪	怪 怪 的	怪 物	怪 物 似	怪 的	
怪 哉	怪 客	怪 怨	怪 相	怪 胎	怪 病	怪 笑	怪 圈	
怪 異	怪 異 事	怪 給	怪 象	怪 想	怪 罪	怪 裡 怪 氣	怪 話	
怪 道	怪 僻	怪 影	怪 樣	怪 樣 子	怪 模	怪 談	怪 誕	
怪 誕 不 經	怪 論	怪 聲	怪 臉	怪 癖	怪 謬	怪 獸	怪 獸 對 打 機	
怕 人	怕 三 怕 四	怕 水	怕 火	怕 只 怕	怕 生	怕 丟 面 子	怕 死	
怕 死 貪 生	怕 老 婆	怕 冷	怕 事	怕 怕	怕 是	怕 苦	怕 苦 怕 累	
怕 疼	怕 累	怕 羞	怕 硬 欺 軟	怕 熱	怕 難 為 情	怕 癢	怡 人	
怡 目	怡 安 科 技	怡 和	怡 情 悅 性	怡 富 投 信	怡 然	怡 然 自 足	怡 然 自 娛	
怡 然 自 得	怡 然 自 樂	怡 華 實 業	性 子	性 本 能	性 犯 罪 案	性 生 活	性 交	
性 同	性 地	性 好	性 如	性 行 為	性 別	性 形	性 技	
性 命	性 命 交 關	性 命 攸 關	性 狀	性 的	性 侵 害	性 侵 害 防 治	性 侵 害 防 治 委 員 會	
性 急	性 急 人	性 科	性 科 學	性 虐	性 倒	性 倒 錯	性 弱	
性 格	性 格 好	性 氣	性 病	性 能	性 能 超 群	性 衰	性 強	
性 情	性 情 好	性 野	性 惡	性 善	性 感	性 愛	性 腺	
性 態	性 徵	性 慾	性 模	性 樂	性 質	性 質 上	性 器	
性 學	性 歷	性 激 素	性 興 奮	性 穩	性 藥	性 靈	怛 然 失 色	
或 大	或 不	或 之 後	或 少	或 以	或 用	或 由	或 因	
或 在	或 多 或 少	或 如	或 早	或 有	或 有 意	或 否	或 使	
或 到	或 明 或 暗	或 者	或 非	或 則	或 是	或 為	或 時	
或 能	或 將	或 晚	或 許	或 然	或 然 性	或 然 率	或 意	
或 當	或 稱	或 變	戕 害	戕 害 不 辜	房 子	房 山	房 主	
房 地	房 地 產	房 地 產 業	房 改	房 車	房 事	房 店	房 東	
房 舍	房 門	房 契	房 室	房 客	房 屋	房 屋 建 築	房 屋 稅	
房 屋 結 構	房 後	房 捐	房 租	房 租 費	房 脊	房 基	房 梁	
房 產	房 產 證	房 頂	房 費	房 間	房 源	房 管	房 管 局	
房 價	房 謀 杜 斷	房 錢	房 簷	所 不	所 云	所 及	所 欠	
所 以	所 以 然	所 付	所 出	所 加	所 外	所 未	所 犯	
所 生	所 用	所 立	所 交	所 列	所 向	所 向 披 靡	所 向 風 靡	
所 向 無 前	所 向 無 敵	所 在	所 在 之 處	所 在 地	所 在 單 位	所 好	所 存	
所 成	所 扣	所 托	所 有	所 有 人	所 有 制	所 有 物	所 有 者	
所 有 格	所 有 這 些	所 有 權	所 至	所 住	所 佔	所 作	所 作 所 為	
所 含	所 困	所 希 望	所 求	所 見	所 見 所 聞	所 言	所 到 之 處	
所 取	所 定	所 幸	所 征	所 知	所 長	所 長 所 至	所 附	
所 建	所 持	所 指	所 派	所 為	所 研	所 穿	所 致	
所 要	所 迫	所 限	所 乘	所 倡	所 料	所 能	所 做	
所 唱	所 問	所 帶	所 得	所 得 稅	所 欲	所 處	所 設	
所 部	所 剩	所 剩 無 幾	所 喜	所 畫	所 發	所 著	所 費	
所 費 不 資	所 傷	所 幹	所 感	所 愛	所 當	所 經	所 裡	
所 運	所 圖 不 軌	所 夢	所 稱	所 聞	所 需	所 寫	所 編	
所 請	所 學	所 謂	所 辦	所 選	所 獲	所 講	所 賺	
所 購	所 趨	所 轄	所 覆	所 簽	所 羅 門	所 羅 門 群 島	所 難	
所 願	所 屬	所 屬 單 位	所 攜	所 變	承 上 啟 下	承 心	承 付	
承 包	承 包 人	承 包 工 程	承 包 制	承 包 者	承 包 商	承 包 責 任 制	承 包 費	
承 包 經 營	承 包 經 營 責 任 制	承 台	承 先 啟 後	承 印	承 佃	承 兌	承 兌 人	
承 兌 匯 票	承 扶	承 典	承 典 人	承 受	承 受 人	承 受 力	承 受 不 住	
承 受 能 力	承 保 人	承 前 啟 後	承 建	承 重	承 面	承 風 希 旨	承 租	
承 租 人	承 情	承 接	承 啟 科 技	承 造	承 發 包	承 當	承 載	
承 運	承 運 人	承 蒙	承 製	承 認	承 認 者	承 認 書	承 認 錯 誤	
承 德	承 銷	承 擔	承 擔 人	承 擔 者	承 擔 責 任	承 擔 義 務	承 諾	
承 諾 人	承 辦	承 辦 人	承 辦 者	承 辦 商	承 應	承 購	承 顏 候 色	
承 繼	承 歡 膝 下	承 歡 獻 媚	承 襲	承 攬	拉 丁	拉 丁 人	拉 丁 化	
拉 丁 文	拉 丁 字 母	拉 丁 美 洲	拉 丁 語	拉 了	拉 人	拉 入	拉 力	
拉 三 扯 四	拉 下	拉 上	拉 大	拉 大 旗 作 虎 皮	拉 小	拉 弓	拉 勾	
拉 巴	拉 手	拉 出	拉 去	拉 平	拉 生 意	拉 皮 條	拉 回	
拉 在	拉 成	拉 托 維 亞	拉 曳	拉 朽 摧 枯	拉 住	拉 伸	拉 床	
拉 扯	拉 走	拉 車	拉 到	拉 制	拉 延	拉 拉	拉 拉 扯 扯	
拉 拉 隊	拉 拉 雜 雜	拉 拔	拉 松	拉 法 葉 巡 防 艦	拉 直	拉 近	拉 長	
拉 門	拉 亮	拉 客	拉 屎	拉 後 腿	拉 拽	拉 美	拉 美 國 家	
拉 倒	拉 家 常	拉 家 帶 口	拉 起	拉 動	拉 得	拉 掉	拉 桿	
拉 桿 機	拉 條	拉 票	拉 細	拉 脫 維 亞	拉 貨	拉 斯 維 加 斯	拉 琴	
拉 稀	拉 窗	拉 絲	拉 著	拉 裂	拉 開	拉 開 序 幕	拉 開 帷 幕	
拉 開 距 離	拉 開 戰 幕	拉 開 檔 次	拉 傷	拉 過	拉 管	拉 緊	拉 網	
拉 練	拉 線	拉 選 票	拉 鋸	拉 幫 結 伙	拉 幫 結 派	拉 環	拉 鍊	
拉 斷	拉 簧	拉 薩	拉 薩 市	拉 鎖	拉 雜	拉 壞	拉 攏	
拉 關 係	拌 入	拌 勺	拌 勻	拌 用	拌 住	拌 和	拌 菜	
拌 種	拌 嘴	拄 著	抿 住	抿 沒	抿 著	抿 嘴	拂 去	
拂 衣 而 去	拂 到	拂 拂	拂 拭	拂 面	拂 袖	拂 袖 而 去	拂 袖 而 起	
拂 袖 而 歸	拂 煦	拂 塵	拂 曉	抹 了	抹 刀	抹 上	抹 不 掉	
抹 月 批 風	抹 去	抹 布	抹 灰	抹 角	抹 角 轉 彎	抹 抹	抹 面	
抹 香	抹 香 粉	抹 消	抹 粉	抹 粉 施 脂	抹 掉	抹 殺	抹 淚 揉 眵	
抹 脖	抹 稀 泥	抹 黑	抹 黑 了	抹 煞	抹 磁	抹 嘴	抹 臉	
拒 人 千 里 之 外	拒 不	拒 不 悔 改	拒 不 執 行	拒 不 接 受	拒 不 認 付	拒 之	拒 之 門 外	
拒 付	拒 斥	拒 交	拒 收	拒 受	拒 服	拒 虎 進 狼	拒 捕	
拒 留	拒 絕	拒 絕 者	拒 絕 執 行	拒 給	拒 開	拒 賄	拒 腐 防 變	
拒 敵	拒 賠	拒 諫	拒 諫 飾 非	拒 禮	拒 繳	招 人	招 亡 納 叛	
招 工	招 干	招 引	招 手	招 生	招 生 工 作	招 安	招 式	
招 收	招 考	招 兵	招 兵 買 馬	招 災	招 災 惹 禍	招 災 攬 禍	招 事	
招 供	招 來	招 到	招 呼	招 法	招 股	招 花 惹 草	招 門 納 婿	
招 待	招 待 人	招 待 所	招 待 員	招 待 費	招 待 會	招 是 惹 非	招 是 攬 非	
招 架	招 架 不 住	招 致	招 軍 買 馬	招 降	招 降 納 叛	招 風	招 風 惹 雨	
招 風 惹 草	招 風 攬 火	招 展	招 租	招 財 進 寶	招 起	招 鬼	招 商	
招 商 引 店	招 商 局	招 徠	招 眼	招 牌	招 貼	招 貼 畫	招 集	
招 募	招 惹	招 搖	招 搖 過 市	招 搖 撞 騙	招 聘	招 聘 制	招 蜂	
招 禍	招 認	招 領	招 魂	招 撫	招 數	招 標	招 請	
招 賢	招 賢 下 士	招 賢 納 士	招 親	招 議	招 權 納 賄	招 權 納 賂	招 權 納 賕	
招 攬	招 攬 生 意	披 上	披 巾	披 心 瀝 血	披 毛 求 疵	披 毛 戴 角	披 古 通 今	
披 甲	披 在	披 沙 剖 璞	披 沙 揀 金	披 沙 簡 金	披 肝 掛 膽	披 肝 瀝 血	披 肝 瀝 膽	
披 肝 露 膽	披 肩	披 星 帶 月	披 星 戴 月	披 紅	披 紅 掛 彩	披 風	披 荊 斬 棘	
披 掛	披 掛 上 陣	披 袍 擐 甲	披 麻	披 麻 帶 孝	披 麻 帶 索	披 麻 救 火	披 散	
披 著	披 榛 采 蘭	披 緇 削 髮	披 蓋	披 閱	披 髮 纓 冠	披 頭	披 頭 散 髮	
披 瀝 肝 膽	披 靡	披 露	披 露 肝 膽	披 庥 帶 孝	披 枷 帶 鎖	拓 土 開 疆	拓 片	
拓 本	拓 展	拓 荒	拓 荒 者	拓 荒 者 隊	拓 草	拓 殖	拓 跋	
拓 開	拓 落 不 羈	拓 補	拓 寬	拓 廣	拓 撲	拓 撲 學	拓 樸	
拓 邊	拔 了	拔 刀 抽 楔	拔 刀 相 助	拔 刀 相 濟	拔 十 失 五	拔 十 得 五	拔 下	
拔 山 扛 鼎	拔 山 超 海	拔 山 舉 鼎	拔 毛	拔 火	拔 牙	拔 出	拔 去	
拔 本 塞 源	拔 地 而 起	拔 地 倚 天	拔 地 參 天	拔 地 搖 山	拔 宅 上 升	拔 宅 飛 升	拔 尖	
拔 尖 兒	拔 身	拔 來 報 往	拔 取	拔 河	拔 染	拔 茅 連 茹	拔 苗	
拔 苗 助 長	拔 海	拔 涉	拔 草	拔 起	拔 除	拔 高	拔 動	
拔 掉	拔 犀 擢 象	拔 絲	拔 萃	拔 萃 出 群	拔 萃 出 類	拔 開	拔 新 領 異	
拔 萬 論 千	拔 萬 輪 千	拔 節	拔 群 出 類	拔 腳	拔 葵 去 織	拔 葵 斷 棗	拔 腿	
拔 劍	拔 樹 尋 根	拔 樹 撼 山	拔 營	拔 還	拔 錨	拔 類 超 群	拋 下	
拋 戈 卸 甲	拋 戈 棄 甲	拋 手	拋 出	拋 光	拋 光 機	拋 向	拋 投	
拋 物	拋 物 面	拋 物 線	拋 空	拋 金 棄 鼓	拋 射	拋 射 物	拋 射 體	
拋 荒	拋 起	拋 售	拋 掉	拋 棄	拋 球	拋 媚 眼	拋 進	
拋 開	拋 撒	拋 磚	拋 磚 引 玉	拋 頭 露 面	拋 錨	拋 擲	拋 灑	
拋 鸞 拆 鳳	拈 斤 播 兩	拈 弄	拈 來	拈 花	拈 花 弄 月	拈 花 微 笑	拈 花 惹 草	
拈 花 摘 草	拈 花 摘 葉	拈 香	拈 量	拈 輕	拈 輕 怕 重	拈 酸 吃 醋	抨 擊	
抽 支 煙	抽 斗	抽 水	抽 水 站	抽 水 馬 桶	抽 水 機	抽 出	抽 出 物	
抽 去	抽 打	抽 回	抽 成	抽 考	抽 血	抽 冷 子	抽 吸	
抽 完	抽 走	抽 身	抽 到	抽 取	抽 泣	抽 空	抽 芽	
抽 青 配 白	抽 查	抽 泵	抽 胎 換 骨	抽 風	抽 氣	抽 氣 機	抽 紗	
抽 釘 拔 楔	抽 乾	抽 動	抽 屜	抽 得 出	抽 掉	抽 殺	抽 提	
抽 換	抽 稅	抽 筋	抽 筋 剝 皮	抽 絲	抽 著	抽 黃 對 白	抽 暇	
抽 煙	抽 煙 斗	抽 煙 者	抽 資	抽 像	抽 像 化	抽 像 性	抽 像 思 維	
抽 像 派	抽 像 勞 動	抽 像 概 念	抽 盡	抽 緊	抽 鳳	抽 噎	抽 審	
抽 撥	抽 樣	抽 樣 調 查	抽 樣 檢 查	抽 獎	抽 線	抽 調	抽 閱	
抽 機	抽 頭	抽 檢	抽 穗	抽 穗 期	抽 縮	抽 薪 止 沸	抽 點	
抽 簡 祿 馬	抽 繹	抽 籤	抽 驗	抽 搐	押 人	押 上	押 出	
押 住	押 尾	押 車	押 往	押 抵	押 注	押 物	押 金	
押 後	押 租	押 送	押 陣	押 款	押 給	押 著	押 匯	
押 當	押 解	押 運	押 賬	押 韻	押 寶	拐 入	拐 子	
拐 去	拐 杖	拐 角	拐 角 處	拐 走	拐 品	拐 帶	拐 脖	
拐 棍	拐 過	拐 誘	拐 賣	拐 騙	拐 彎	拐 彎 抹 角	拙 口 鈍 腮	
拙 口 鈍 辭	拙 劣	拙 行	拙 作	拙 見	拙 笨	拙 筆	拙 著	
拙 集	拙 嘴	拙 嘴 笨 舌	拇 指	拇 指 痕	拍 人	拍 子	拍 巴 掌	
拍 手	拍 手 叫 好	拍 手 拍 腳	拍 手 者	拍 手 稱 快	拍 手 聲	拍 片	拍 去	
拍 打	拍 打 物	拍 成	拍 快 照	拍 岸	拍 拍	拍 拖	拍 板	
拍 板 成 交	拍 板 定 案	拍 背	拍 案	拍 案 叫 絕	拍 案 而 起	拍 案 稱 奇	拍 案 驚 奇	
拍 馬	拍 馬 屁	拍 馬 者	拍 動	拍 掉	拍 球	拍 掌	拍 發	
拍 著	拍 照	拍 電 影	拍 賣	拍 賣 人	拍 賣 場	拍 擊	拍 檔	
拍 聲	拍 攝	抵 付	抵 充	抵 用	抵 交	抵 扣	抵 死 瞞 生	
抵 死 謾 生	抵 作	抵 免	抵 抗	抵 抗 力	抵 抗 性	抵 抗 者	抵 扳	
抵 沖	抵 足 而 臥	抵 足 而 眠	抵 足 談 心	抵 制	抵 命	抵 押	抵 押 者	
抵 押 品	抵 押 權	抵 借	抵 悟	抵 消	抵 留	抵 帳	抵 得 住	
抵 頂	抵 掌 而 談	抵 換	抵 減	抵 稅	抵 債	抵 毀	抵 瑕 蹈 隙	
抵 罪	抵 補	抵 達	抵 過	抵 撞	抵 撥	抵 敵	抵 賬	
抵 銷	抵 擋	抵 禦	抵 賴	抵 償	抵 還	抵 觸	抵 觸 情 緒	
拚 死	拚 死 拼 活	拚 到	拚 命	拚 命 吃	拚 法	拚 搏	拚 搏 精 神	
拚 寫	抱 了	抱 子 弄 孫	抱 不	抱 不 平	抱 以	抱 令 守 律	抱 布 貿 絲	
抱 在	抱 存	抱 成 一 團	抱 有	抱 有 成 見	抱 有 偏 見	抱 住	抱 佛 腳	
抱 定	抱 屈	抱 抱	抱 枕	抱 者	抱 怨	抱 恨	抱 恨 終 天	
抱 恨 終 身	抱 持	抱 負	抱 負 不 凡	抱 恙	抱 拳	抱 病	抱 素 懷 樸	
抱 草	抱 起	抱 偏 見	抱 蛋	抱 殘	抱 殘 守 缺	抱 殘 守 闕	抱 著	
抱 進	抱 愧	抱 誠 守 真	抱 境 息 民	抱 歉	抱 緊	抱 蔓 摘 瓜	抱 養	
抱 憾	抱 頭	抱 頭 大 哭	抱 頭 痛 哭	抱 頭 鼠 竄	抱 頭 縮 項	抱 薪 救 火	抱 薪 救 焚	
抱 關 擊 柝	抱 寶 懷 珍	抱 槧 懷 鉛	拘 文 牽 俗	拘 文 牽 義	拘 役	拘 束	拘 束 不 安	
拘 押	拘 於	拘 泥	拘 泥 小 節	拘 俗 守 常	拘 拿	拘 捕	拘 留	
拘 留 犯	拘 留 所	拘 票	拘 禁	拘 管	拘 禮	拘 謹	拘 攣 補 衲	
拖 人 下 水	拖 入	拖 力	拖 下	拖 天 掃 地	拖 斗	拖 欠	拖 出	
拖 吊	拖 吊 業	拖 地	拖 曳	拖 曳 物	拖 曳 機	拖 曳 纜	拖 至	
拖 行	拖 住	拖 把	拖 男 挾 女	拖 男 帶 女	拖 走	拖 足	拖 車	
拖 車 頭	拖 來	拖 來 拖 去	拖 兒 帶 女	拖 到	拖 延	拖 延 者	拖 拉	
拖 拉 機	拖 拉 機 手	拖 拉 機 廠	拖 拖 拉 拉	拖 放	拖 板	拖 泥	拖 泥 帶 水	
拖 長	拖 青 紆 紫	拖 垮	拖 後	拖 後 腿	拖 洗	拖 家 帶 口	拖 柴 垂 青	
拖 航	拖 動	拖 帶	拖 累	拖 船	拖 麻 拽 布	拖 湍	拖 著	
拖 運	拖 網	拖 駁	拖 撈	拖 撈 船	拖 輪	拖 鞋	拖 鍊	
拖 繩	拖 髒	拖 沓	拗 口	拗 口 令	拗 曲 作 直	拗 性	拗 斷	
拆 了	拆 下	拆 分	拆 去	拆 台	拆 用	拆 白 道 字	拆 伙	
拆 字	拆 成	拆 西 補 東	拆 兌	拆 角	拆 卸	拆 東 補 西	拆 股	
拆 封	拆 屋	拆 洗	拆 穿	拆 借	拆 息	拆 除	拆 帳	
拆 接	拆 掉	拆 船	拆 船 業	拆 散	拆 開	拆 毀	拆 碑 道 字	
拆 裝	拆 解 開	拆 線	拆 賬	拆 賣	拆 遷	拆 橋	拆 牆 腳	
拆 舊	抬 不	抬 不 起 頭 來	抬 升	抬 出	抬 走	抬 抬	抬 的	
抬 肩	抬 起	抬 起 頭 來	抬 高	抬 捧	抬 棺 者	抬 筐	抬 著	
抬 槓	抬 槍	抬 閣	抬 價	抬 頭	抬 臉	抬 舉	抬 轎	
放 了	放 入	放 刁 撒 潑	放 下	放 下 包 袱	放 下 架 子	放 下 屠 刀	放 下 屠 刀 立 地 成 佛	
放 上	放 大	放 大 系 數	放 大 率	放 大 器	放 大 機	放 大 鏡	放 工	
放 干	放 之 四 海 而 皆 准	放 心	放 心 不 下	放 手	放 水	放 火	放 火 狂	
放 火 者	放 牛	放 牛 歸 馬	放 出	放 生	放 任	放 任 自 流	放 光	
放 回	放 在	放 在 心 上	放 在 首 位	放 在 眼 裡	放 在 第 一 位	放 在 優 先 地 位	放 好	
放 羊	放 血	放 行	放 低	放 冷 風	放 屁	放 步	放 言	
放 言 高 論	放 走	放 到	放 於	放 牧	放 空	放 空 炮	放 虎	
放 虎 自 衛	放 虎 歸 山	放 長	放 青	放 後	放 映	放 映 師	放 映 機	
放 毒	放 洋	放 活	放 炮	放 音	放 風	放 風 箏	放 哨	
放 射	放 射 性	放 射 狀	放 射 病	放 射 率	放 射 線	放 氣	放 浪	
放 浪 不 羈	放 浪 形 骸	放 荒	放 起	放 送	放 針	放 馬	放 高	
放 假	放 情 丘 壑	放 掉	放 棄	放 棄 者	放 球	放 眼	放 眼 世 界	
放 逐	放 散	放 晴	放 款	放 著	放 貸	放 進	放 開	
放 開 經 營	放 開 價 格	放 債	放 置	放 肆	放 達	放 過	放 電	
放 對	放 慢	放 槍	放 歌	放 誘 餌	放 輕	放 遠	放 寬	
放 影 機	放 熱	放 熱 器	放 線 菌	放 誕 不 拘	放 誕 不 羈	放 誕 風 流	放 賬	
放 養	放 學	放 學 後	放 蕩	放 蕩 不 拘	放 蕩 不 羈	放 蕩 者	放 錯	
放 錢	放 縱	放 縱 不 拘	放 縱 不 羈	放 聲	放 膽	放 鬆	放 權	
放 鷹 逐 犬	斧 子	斧 正	斧 斬	斧 頭	於 人	於 下	於 己 於 人	
於 中	於 今	於 今 為 烈	於 心	於 心 不 甘	於 心 不 忍	於 心 何 忍	於 世	
於 外	於 民	於 民 潤 國	於 此	於 形	於 那	於 事	於 事 無 補	
於 呼 哀 哉	於 是	於 是 乎	於 家 為 國	旺 月	旺 火	旺 市	旺 宏 電 子	
旺 角	旺 季	旺 泉	旺 盛	旺 期	旺 詮 公 司	旺 銷	昔 人	
昔 日	昔 比	昔 年	昔 似	昔 者	昔 非 今 比	昔 時	昔 陽	
昔 歲	易 人	易 卜	易 分 裂	易 切 斷	易 手	易 主	易 出 錯	
易 犯	易 犯 罪	易 生	易 用	易 名	易 地	易 如 反 掌	易 如 拾 芥	
易 如 翻 掌	易 成	易 曲 折	易 行	易 位	易 利 信	易 弄	易 弄 碎	
易 忘	易 忘 記	易 攻 佔	易 攻 擊	易 見	易 使	易 使 用	易 取	
易 受	易 受 騙	易 受 驚	易 延 展	易 拆	易 於	易 明 了	易 欣 工 程	
易 物	易 知	易 長	易 門	易 俗	易 俗 移 風	易 勃 起	易 怒	
易 怒 者	易 染 色	易 流 淚	易 倒	易 哭	易 消 散	易 破	易 破 碎	
易 起	易 逃 逸	易 做	易 動	易 患	易 控 制	易 接	易 接 受	
易 接 近	易 掉	易 教	易 旋 轉	易 液 化	易 混 合	易 理 解	易 脫 節	
易 處 理	易 被	易 貨	易 陷 於	易 揮 發	易 散 發	易 景 茜	易 發	
易 發 生	易 裂	易 裂 性	易 傳	易 傳 染	易 傷 感	易 感 知	易 感 染	
易 感 動	易 損	易 損 性	易 損 害	易 滑	易 碎	易 經	易 裝	
易 解	易 察 覺	易 對	易 腐	易 腐 敗	易 腐 壞	易 腐 爛	易 與	
易 誤 會	易 誤 解	易 幟	易 撕 碎	易 撫 慰	易 潮 解	易 蔓 延	易 賣	
易 遭	易 醉	易 震 動	易 駕 馭	易 學	易 激 動	易 燃	易 燃 性	
易 燃 易 爆	易 燃 物	易 興 奮	易 辦	易 錯	易 壓 碎	易 懂	易 舉	
易 壞	易 爆	易 爆 發	易 騙	易 讀	易 讀 性	易 變	易 變 性	
易 變 動	易 粘 住	昌 平	昌 吉	昌 邑	昌 明	昌 益 建 設	昌 益 開 發	
昌 盛	昌 魚	昆 士 蘭	昆 山	昆 山 片 玉	昆 曲	昆 弟 之 好	昆 明	
昆 明 市	昆 明 湖	昆 盈 企 業	昆 泰 營 造	昆 腔	昆 劇	昆 蟲	昆 蟲 學	
昆 蟲 館	昂 昂	昂 首	昂 首 挺 胸	昂 首 闊 步	昂 揚	昂 然	昂 然 自 得	
昂 貴	昂 頭	昂 頭 天 外	明 了	明 人	明 人 不 作 暗 事	明 人 不 做 暗 事	明 升 暗 降	
明 升 實 降	明 天	明 天 見	明 心 見 性	明 文	明 文 規 定	明 日	明 日 黃 花	
明 月	明 月 入 懷	明 月 清 風	明 火	明 火 持 杖	明 火 執 仗	明 代	明 令	
明 冬	明 尼 蘇 達	明 正 典 刑	明 用	明 白	明 目	明 目 張 膽	明 目 達 聰	
明 示	明 刑 弼 教	明 年	明 年 初	明 早	明 此	明 快	明 見 萬 里	
明 言	明 來 暗 往	明 兒	明 定	明 性	明 明	明 明 白 白	明 法 審 令	
明 治	明 爭	明 爭 暗 鬥	明 物	明 知	明 知 故 犯	明 知 故 問	明 亮	
明 亮 度	明 信 片	明 後 天	明 政	明 春	明 星	明 星 志 願 ２	明 查	
明 若 觀 火	明 修 棧 道	明 修 棧 道 暗 度 陳 倉	明 哲	明 哲 保 身	明 恥 教 戰	明 效	明 效 大 驗	
明 時	明 晃	明 晃 晃	明 書	明 朗	明 朗 化	明 珠	明 珠 生 蚌	
明 珠 暗 投	明 珠 彈 雀	明 起	明 堂	明 婚 正 配	明 情	明 教	明 晚	
明 清	明 淨	明 理	明 眼	明 眼 人	明 眸 皓 齒	明 細	明 細 表	
明 細 帳	明 細 賬	明 處	明 創	明 喻	明 媚	明 媒 正 娶	明 揚 仄 陋	
明 晰	明 智	明 朝	明 渠	明 窗 淨 幾	明 等	明 華 園	明 華 園 歌 仔 戲 團	
明 間	明 搶	明 暗	明 暗 法	明 溝	明 道	明 達	明 察	
明 察 秋 毫	明 察 暗 訪	明 暢	明 槍	明 槍 好 躲 暗 箭 難 防	明 槍 易 躲 暗 箭 難 防	明 槍 容 易 躲	明 槍 暗 箭	
明 澈	明 與 暗	明 誓	明 說	明 德	明 德 水 庫	明 德 惟 馨	明 德 慎 罰	
明 慧	明 確	明 確 性	明 碼	明 碼 標 價	明 膠	明 賞 慎 罰	明 器	
明 燈	明 辨	明 辨 是 非	明 講	明 擺	明 擺 著	明 斷	明 證	
明 鏡	明 鏡 高 懸	明 麗	明 礬	明 礬 石	明 覺	明 顯	明 舖 暗 蓋	
明 �� 電 通	明 �� 電 腦	昏 了	昏 天	昏 天 黑 地	昏 在	昏 君	昏 沉	
昏 沉 沉	昏 定 晨 省	昏 昏	昏 昏 入 睡	昏 昏 沉 沉	昏 昏 欲 睡	昏 花	昏 倒	
昏 眩	昏 迷	昏 迷 不 醒	昏 庸	昏 厥	昏 黃	昏 黑	昏 亂	
昏 暗	昏 暈	昏 話	昏 過 去	昏 睡	昏 頭	昏 頭 昏 腦	昏 頭 搭 腦	
昏 頭 轉 向	昏 謎	昏 鏡 重 明	昏 鏡 重 磨	昏 聵	昊 天 不 吊	昊 天 罔 極	昇 華	
服 了	服 人	服 下	服 水 土	服 用	服 刑	服 刑 者	服 低 做 小	
服 兵 役	服 役	服 役 者	服 侍	服 帖	服 於	服 於 組 織	服 服 帖 帖	
服 毒	服 食	服 氣	服 氣 吞 露	服 氣 餐 霞	服 冕 乘 軒	服 務	服 務 上 門	
服 務 台	服 務 市 場	服 務 生	服 務 行 業	服 務 到 家	服 務 性	服 務 性 行 業	服 務 於	
服 務 者	服 務 型	服 務 員	服 務 站	服 務 處	服 務 部	服 務 費	服 務 隊	
服 務 項 目	服 務 業	服 務 態 度	服 務 網	服 務 質 量	服 務 器	服 務 機 構	服 從	
服 從 分 配	服 從 需 要	服 理	服 喪	服 貼	服 罪	服 裝	服 裝 秀	
服 裝 商	服 裝 廠	服 飾	服 滿	服 輸	服 鎮	服 藥	朋 友	
朋 友 們	朋 友 遍 天 下	朋 比 為 奸	朋 只 作 奸	朋 馳	朋 輩	朋 黨	朋 黨 比 周	
朋 黨 政 治	杭 州	杭 州 市	枋 山	枋 寮	枕 上	枕 巾	枕 中 鴻 寶	
枕 戈 汗 馬	枕 戈 坐 甲	枕 戈 泣 血	枕 戈 待 旦	枕 戈 待 敵	枕 戈 飲 膽	枕 戈 嘗 膽	枕 戈 寢 甲	
枕 木	枕 石 漱 流	枕 冷 衾 寒	枕 芯	枕 流 漱 石	枕 套	枕 席	枕 梁	
枕 墊	枕 頭	枕 頭 套	枕 頭 般	枕 頭 奪	枕 邊	東 口	東 山	
東 山 之 志	東 山 再 起	東 山 高 臥	東 山 復 起	東 川	東 元 電 機	東 升	東 友 科 技	
東 方	東 方 人	東 方 千 騎	東 方 式	東 方 紅	東 方 國 家	東 方 通	東 方 灣	
東 加	東 加 王 國	東 北	東 北 三 省	東 北 向	東 北 地 區	東 北 角	東 北 亞	
東 北 季 風	東 北 東	東 北 風	東 北 部	東 半 球	東 去	東 台	東 台 精 機	
東 四	東 市 朝 衣	東 正 元 電	東 石 鄉	東 向	東 安	東 行	東 西	
東 西 方	東 西 南 北	東 西 南 北 人	東 西 南 北 客	東 西 歐	東 吳	東 床 坦 腹	東 床 嬌 客	
東 床 嬌 婿	東 抄 西 襲	東 扶 西 倒	東 扭 西 捏	東 扯 西 拉	東 沙	東 沙 群 島	東 走 西 撞	
東 亞	東 京	東 京 三 菱 銀 行	東 來	東 來 西 去	東 來 紫 氣	東 兔 西 烏	東 協 國 家	
東 和 紡 織	東 和 鋼 鐵	東 周	東 坡	東 奔 西 向	東 奔 西 走	東 奔 西 跑	東 奔 西 撞	
東 奔 西 闖	東 岸	東 征 西 怨	東 征 西 討	東 征 戰 役	東 拉 西 扯	東 東	東 河	
東 河 鄉	東 直 門	東 芝	東 門	東 門 黃 犬	東 非	東 侵	東 南	
東 南 之 美	東 南 方	東 南 水 泥	東 南 竹 箭	東 南 西 北	東 南 角	東 南 亞	東 南 亞 股 市	
東 南 亞 國 家 聯 盟	東 南 東	東 南 沿 海	東 南 風	東 南 部	東 南 鹼 業	東 城	東 城 區	
東 帝 汶	東 帝 汶 暴 亂	東 建	東 拼 西 湊	東 施 效 顰	東 歪 西 倒	東 段	東 洋	
東 洋 大 海	東 流	東 穿 西 撞	東 郊	東 面	東 風	東 風 十 一 型	東 風 吹 馬 耳	
東 風 射 馬 耳	東 風 壓 倒 西 風	東 食 西 宿	東 倒 西 歪	東 家	東 家 效 顰	東 宮	東 差 西 誤	
東 挪 西 借	東 挪 西 湊	東 挪 西 輳	東 挨 西 撞	東 晉	東 泰 產 險	東 海	東 海 揚 塵	
東 海 撈 針	東 站	東 航	東 討 西 伐	東 討 西 征	東 訊	東 訊 公 司	東 逃 西 竄	
東 閃 西 挪	東 馬	東 側	東 偷 西 摸	東 區	東 張 西 望	東 張 西 覷	東 徙 西 遷	
東 掩 西 遮	東 莞	東 部	東 郭	東 陵	東 勞 西 燕	東 單	東 尋 西 覓	
東 揚 西 蕩	東 森 多 媒 體	東 港	東 渡	東 湖	東 窗 事 犯	東 窗 事 發	東 華 合 纖	
東 華 門	東 街	東 跑 西 顛	東 鄉	東 量 西 折	東 陽	東 陽 實 業	東 隆 五 金	
東 隆 興 業	東 雲	東 雲 公 司	東 勢	東 勢 鄉	東 勢 鎮	東 塗 西 摸	東 溝	
東 盟	東 盟 國 家	東 碰 西 撞	東 經	東 補 西 湊	東 路	東 躲 西 逃	東 躲 西 閃	
東 躲 西 跑	東 躲 西 藏	東 遊 西 逛	東 道	東 道 主	東 道 國	東 零 西 散	東 零 西 落	
東 僑	東 榮 纖 維	東 漢	東 端	東 鳴 西 應	東 德	東 撈 西 摸	東 撙 西 節	
東 樓	東 歐	東 歐 人	東 歐 國 家	東 線	東 衝 西 突	東 遮 西 掩	東 遷 西 徙	
東 鄰 西 捨	東 蕩 西 除	東 營	東 瞧 西 望	東 聯 化 學	東 翻 西 倒	東 藏 西 躲	東 瀛	
東 邊	東 飄 西 蕩	東 鱗 西 爪	東 鱗 西 瓜	東 觀 之 殃	東 觀 西 望	東 誆 西 騙	果 子	
果 子 凍	果 子 酒	果 不 其 然	果 仁	果 心	果 木	果 汁	果 汁 器	
果 汁 機	果 皮	果 如 其 言	果 如 所 料	果 肉	果 決	果 豆	果 味	
果 枝	果 品	果 是	果 柄	果 洛	果 為	果 凍	果 料	
果 核	果 真	果 真 如 此	果 粉	果 酒	果 球	果 脯	果 敢	
果 殼	果 渣	果 然	果 然 不 出 所 料	果 菜	果 園	果 腹	果 農	
果 實	果 酸	果 毅	果 盤	果 膠	果 樹	果 樹 材	果 糖	
果 餡 餅	果 嶺	果 穗	果 斷	果 蟲	果 醬	果 蠅	果 類	
杳 如	杳 渺	杳 無 人 煙	杳 無 人 跡	杳 無 信 息	杳 無 音 信	杳 無 音 訊	杳 無 消 息	
杳 無 黃 鶴	杳 無 蹤 跡	杳 無 蹤 影	枇 杷	枇 杷 門 巷	枝 子	枝 多	枝 江	
枝 形	枝 枝 節 節	枝 狀	枝 附 影 從	枝 條	枝 詞 蔓 語	枝 幹	枝 節	
枝 葉	枝 葉 扶 疏	枝 葉 扶 蘇	枝 頭	枝 繁	枝 繁 葉 茂	枝 杈	枝 椏	
林 三 號	林 下	林 下 風 致	林 下 風 氣	林 下 風 範	林 下 高 風	林 口	林 口 鄉	
林 子	林 中	林 內	林 內 鄉	林 心 如	林 木	林 立	林 仲 秋	
林 光 華	林 地	林 在 培	林 色	林 志 炫	林 志 穎	林 甸	林 林 總 總	
林 肯	林 芝	林 冠	林 型	林 相	林 美 貞	林 苑	林 海	
林 副 產 品	林 區	林 帶	林 產	林 產 品	林 莽	林 彪	林 陰	
林 場	林 間	林 園	林 園 鄉	林 業	林 業 局	林 業 部	林 業 部 門	
林 業 廳	林 瑞 圖	林 義 夫	林 義 雄	林 農	林 熙 蕾	林 語 堂	林 蔭	
林 蔭 大 道	林 蔭 夾 道	林 蔭 徑	林 蔭 道	林 墾	林 憶 蓮	林 曉 培	林 濁 水	
林 縣	林 嶺 東	林 豐 正	林 懷 民	林 獸	林 邊	林 邊 鄉	林 煒	
杯 子	杯 弓 蛇 影	杯 中	杯 中 之 物	杯 中 物	杯 水 車 薪	杯 水 粒 粟	杯 水 輿 薪	
杯 底	杯 狀	杯 酒 戈 矛	杯 蛇 鬼 車	杯 盞	杯 葛	杯 墊	杯 盤 狼 藉	
杯 盤 狼 籍	杯 觥 交 錯	板 下	板 上 釘 釘	板 子	板 片	板 牙	板 石	
板 式	板 床	板 材	板 車	板 刷	板 房	板 斧	板 油	
板 信 商 銀	板 架	板 胡	板 面	板 書	板 栗	板 烤	板 條	
板 球	板 眼	板 報	板 畫	板 結	板 著 臉	板 塊	板 極	
板 凳	板 樓	板 橋	板 橋 市	板 機	板 鴨	板 擦	板 牆	
板 臉	板 巖	板 舖	枉 口 拔 舌	枉 己 正 人	枉 尺 直 尋	枉 用 心 機	枉 死	
枉 法	枉 法 徇 私	枉 突 徙 薪	枉 然	枉 費	枉 費 工 夫	枉 費 心 力	枉 費 心 計	
枉 費 心 機	枉 費 日 月	枉 費 唇 舌	枉 費 時 日	枉 道 事 人	枉 擔 虛 名	松 下	松 下 電 器	
松 口	松 土	松 土 機	松 子	松 山	松 山 區	松 心	松 木	
松 毛 蟲	松 江	松 明	松 果	松 林	松 油	松 花	松 花 江	
松 花 蛋	松 勁	松 柏	松 柏 之 茂	松 柏 後 雕	松 香	松 島 菜 菜 子	松 桃	
松 氣	松 耗	松 脂	松 針	松 帶	松 球	松 喬 之 壽	松 隆 子	
松 節	松 節 油	松 筠 之 節	松 葉	松 鼠	松 樹	松 糕	松 濤	
松 雞	松 蘑	松 蘿 共 倚	析 出	析 圭 但 爵	析 取	析 法	析 律 貳 端	
析 律 舞 文	析 毫 剖 厘	析 義	析 疑 匡 謬	析 骸 易 子	析 縷 分 條	析 離	枚 假	
枚 舉	杼 柚 其 空	欣 天 然	欣 生 惡 死	欣 欣	欣 欣 大 眾	欣 欣 向 榮	欣 欣 自 得	
欣 悅	欣 泰 石 油	欣 高 石 油	欣 悉	欣 喜	欣 喜 若 狂	欣 喜 雀 躍	欣 然	
欣 然 自 得	欣 然 自 喜	欣 然 自 樂	欣 然 命 筆	欣 雄	欣 羨	欣 慰	欣 賞	
欣 興 電 子	欣 錩 國 際	武 人	武 人 不 惜 死	武 力	武 土	武 士	武 士 道	
武 工	武 丑	武 不 善 作	武 功	武 打	武 旦	武 生	武 夷	
武 夷 山	武 官	武 昌	武 昌 剩 竹	武 林	武 松	武 俠	武 俠 小 說	
武 紀	武 師	武 庫	武 神	武 鬥	武 偃 文 修	武 將	武 術	
武 陵	武 備	武 進	武 當	武 裝	武 裝 入 侵	武 裝 力 量	武 裝 挑 釁	
武 裝 鬥 爭	武 裝 部	武 裝 部 隊	武 裝 衝 突	武 裝 警 察	武 漢	武 漢 市	武 廟	
武 衛	武 器	武 器 庫	武 器 裝 備	武 器 彈 藥	武 戲	武 斷	武 職	
武 藏 丸	武 藝	武 藝 高 強	武 警	武 警 部 隊	武 警 戰 士	歧 見	歧 異	
歧 途	歧 視	歧 義	歧 路	歧 路 亡 羊	歧 嶇	歿 而 不 朽	歿 而 無 朽	
氛 圍	泣 下 如 雨	泣 下 沾 襟	泣 不 成 聲	泣 血 枕 戈	泣 血 捶 膺	泣 血 椎 心	泣 血 漣 如	
泣 血 稽 顙	泣 別	泣 者	泣 然	泣 訴	泣 聲	泣 謝	注 入	
注 入 器	注 口	注 文	注 水	注 以	注 出	注 本	注 目	
注 有	注 色	注 定	注 重	注 重 實 效	注 重 質 量	注 音	注 射	
注 射 者	注 射 筒	注 射 劑	注 射 器	注 視	注 視 者	注 塑	注 意	
注 意 力	注 意 事 項	注 意 到	注 意 著	注 意 聽	注 解	注 資	注 過 冊	
注 滿	泳 池	泳 衣	泳 者	泳 時	泳 動	泳 將	泳 場	
泳 裝	泳 壇	泳 褲	泳 賽	泌 尿	泌 液	泌 陽	泌 腺	
泥 人	泥 刀	泥 土	泥 工	泥 中	泥 中 隱 刺	泥 巴	泥 水	
泥 水 匠	泥 牛 入 海	泥 古 非 今	泥 瓦 匠	泥 石	泥 石 流	泥 多 佛 大	泥 污	
泥 灰	泥 灰 質	泥 灰 磚	泥 灰 巖	泥 色	泥 坑	泥 沙	泥 沙 俱 下	
泥 足 巨 人	泥 板	泥 沼	泥 垢	泥 封	泥 流	泥 炭	泥 盆 紀	
泥 面	泥 料	泥 船 渡 河	泥 魚	泥 渣	泥 菩 薩	泥 菩 薩 落 水	泥 菩 薩 過 江	
泥 飯 碗	泥 塑	泥 塑 木 雕	泥 塘	泥 煤	泥 煤 似	泥 廠	泥 槳	
泥 漿	泥 潭	泥 豬 瓦 狗	泥 磚	泥 濘	泥 鰍	泥 淖	河 口	
河 山	河 山 帶 礪	河 川	河 工	河 不 出 圖	河 中	河 內	河 心	
河 水	河 北	河 北 省	河 北 梆 子	河 外	河 名	河 江	河 池	
河 西	河 床	河 汾 門 下	河 系	河 谷	河 身	河 防	河 岸	
河 底	河 東	河 東 獅 吼	河 泥	河 沿	河 南	河 南 省	河 柳	
河 段	河 流	河 流 地 貌 學	河 津	河 面	河 套	河 畔	河 神	
河 粉	河 蚌	河 馬	河 清 海 晏	河 清 難 俟	河 豚	河 魚	河 魚 之 疾	
河 魚 腹 疾	河 堤	河 港	河 渠	河 間	河 塘	河 源	河 溝	
河 落 海 乾	河 裡	河 運	河 道	河 鼠	河 網	河 槽	河 濱	
河 蟹	河 邊	河 彎	河 灘	河 壩	河 灣	沽 名	沽 名 干 譽	
沽 名 吊 譽	沽 名 釣 譽	沽 名 邀 譽	沽 酒 當 壚	沽 售	沾 上	沾 手	沾 水	
沾 光	沾 污	沾 血	沾 沾 自 足	沾 沾 自 喜	沾 沾 自 滿	沾 花 惹 草	沾 染	
沾 滿	沾 親 帶 故	沾 濕	沾 襟	沾 邊	沾 體 塗 足	沼 氣	沼 氣 發 電 廠	
沼 澤	沼 澤 地	沼 澤 似	波 士	波 士 尼 亞	波 士 頓	波 及	波 及 面	
波 平 浪 靜	波 光	波 光 粼 粼	波 多 黎 各	波 形	波 形 圖	波 折	波 束	
波 谷	波 狀	波 長	波 型	波 段	波 美 度	波 面	波 音	
波 音 公 司	波 音 航 空	波 哥 大	波 峰	波 恩	波 浪	波 浪 式	波 浪 形	
波 特	波 特 蘭	波 紋	波 茨 坦	波 動	波 動 起 伏	波 帶	波 痕	
波 速	波 堤	波 幅	波 斯	波 斯 人	波 斯 王 子	波 斯 教	波 斯 語	
波 斯 灣	波 斯 灣 地 區	波 黑	波 塞	波 源	波 腹	波 路 壯 闊	波 道	
波 爾 多 液	波 影	波 導	波 導 管	波 濤	波 濤 洶 湧	波 羅 地 海	波 羅 的 海	
波 譎 雲 詭	波 瀾	波 瀾 老 成	波 瀾 壯 闊	波 瀾 起 伏	波 蘭	波 蘭 人	波 蘭 化	
波 蘭 史	波 蘭 幣	波 蘭 舞	波 蘭 語	沫 子	沫 兒	沫 狀	法 人	
法 人 地 位	法 人 資 格	法 力	法 力 無 邊	法 上	法 子	法 文	法 令	
法 出 多 門	法 史	法 外	法 外 施 仁	法 名	法 式	法 旨	法 老	
法 老 王	法 衣	法 衣 室	法 西 斯	法 西 斯 黨	法 位	法 事	法 兒	
法 典	法 制	法 制 化	法 制 史	法 制 建 設	法 制 軌 道	法 制 觀 念	法 定	
法 定 人 數	法 定 年 齡	法 定 繼 承 人	法 官	法 官 席	法 拉	法 拉 第	法 治	
法 物	法 盲	法 者	法 金 幣	法 門	法 則	法 度	法 律	
法 律 上	法 律 界	法 律 學	法 律 學 家	法 律 顧 問	法 政	法 派	法 科	
法 紀	法 紀 教 育	法 郎	法 家	法 師	法 庫	法 庭	法 庭 調 查	
法 庭 辯 論	法 朗	法 案	法 案 修 訂	法 院	法 務	法 務 部	法 國	
法 國 人	法 國 式	法 條	法 理	法 理 學	法 統	法 術	法 規	
法 規 彙 編	法 場	法 新 社	法 會	法 禁	法 裔	法 幣	法 種	
法 網	法 網 恢 恢	法 網 恢 恢 疏 而 不 漏	法 語	法 碼	法 線	法 輪 功	法 器	
法 學	法 學 家	法 辦	法 醫	法 醫 學	法 寶	法 警	法 屬	
法 蘭	法 蘭 西	法 蘭 克 福	法 蘭 絨	法 蘭 盤	法 權	沸 反 盈 天	沸 水	
沸 石	沸 沸	沸 沸 揚 揚	沸 熱	沸 點	沸 騰	沸 騰 床	沸 騰 鋼	
油 了	油 井	油 孔	油 毛 氈	油 水	油 布	油 田	油 石	
油 光	油 印	油 印 機	油 池	油 污	油 灰	油 坊	油 車	
油 制	油 性	油 松	油 泥	油 油	油 炒	油 狀	油 門	
油 亮	油 品	油 封	油 柑	油 泵	油 炸	油 炸 餅	油 炸 鍋	
油 缸	油 頁 巖	油 香	油 庫	油 料	油 桐	油 氣	油 站	
油 紙	油 耗	油 脂	油 茶	油 彩	油 桶	油 條	油 瓶	
油 票	油 船	油 壺	油 棕	油 款	油 渣	油 然	油 然 而 生	
油 畫	油 稅	油 腔 滑 調	油 菜	油 菜 籽	油 量	油 黑	油 溫	
油 滑	油 煎	油 煎 火 燎	油 煎 餅	油 煙	油 跡	油 槍	油 滴	
油 漬	油 漬 麻 花	油 漆	油 漆 工	油 漆 匠	油 漆 業	油 管	油 精	
油 綠	油 膏	油 酸	油 餅	油 價	油 價 調 整	油 嘴	油 嘴 狗 舌	
油 嘴 滑 舌	油 層	油 廠	油 槽	油 箱	油 輪	油 墨	油 橄 欖	
油 燈	油 磨	油 膩	油 鋸	油 頭 粉 面	油 頭 滑 腦	油 頭 滑 臉	油 壓	
油 氈	油 鍋	油 藏	油 類	油 礦	油 罐	油 鹽 醬 醋	油 酯	
況 且	沮 喪	泗 水	泗 洪	泗 陽	泅 水	泅 泳	泅 渡	
泱 泱	泱 泱 大 國	沿 上	沿 用	沿 用 至 今	沿 江	沿 伸	沿 兒	
沿 岸	沿 河	沿 波 討 源	沿 門 托 缽	沿 流 討 源	沿 流 溯 源	沿 革	沿 海	
沿 海 地 區	沿 海 地 帶	沿 海 港 口	沿 海 發 展 戰 略	沿 海 開 放 城 市	沿 海 經 濟	沿 習	沿 途	
沿 帽	沿 著	沿 街	沿 路	沿 線	沿 邊	沿 襲	治 山	
治 不 好	治 水	治 世	治 本	治 多	治 好	治 安	治 安 工 作	
治 安 員	治 安 管 理	治 兵	治 肝 病	治 性	治 所	治 河	治 保	
治 保 主 任	治 軍	治 家	治 病	治 病 救 人	治 國	治 國 安 民	治 理	
治 理 整 頓	治 理 環 境	治 這	治 喘	治 喪	治 絲 而 棼	治 黃	治 亂	
治 亂 存 亡	治 亂 興 亡	治 愚 治 窮	治 罪	治 裝	治 標	治 學	治 療	
治 療 □	治 療 法	治 療 前	治 療 學	治 癒	泡 一 下	泡 上	泡 在	
泡 妞	泡 沫	泡 沫 狀	泡 沫 塑 料	泡 泡	泡 狀	泡 桐	泡 浸	
泡 病	泡 疹	泡 茶	泡 湯	泡 菜	泡 開	泡 飯	泡 製	
泡 影	泡 濕	泡 藥	泡 蘑 菇	泡 麵	泛 光	泛 光 燈	泛 回	
泛 舟	泛 色	泛 亞 銀 行	泛 味	泛 泛	泛 泛 而 談	泛 非 主 義	泛 指	
泛 紅	泛 美	泛 美 主 義	泛 音	泛 島	泛 神	泛 神 論	泛 起	
泛 愛	泛 稱	泛 酸	泛 論	泛 頻	泛 讀	泊 地	泊 位	
泊 車	泊 定	泊 岸	泊 船	泊 頭	泯 沒	泯 滅	炕 下	
炕 上	炕 去	炕 床	炕 沿	炕 洞	炕 席	炕 桌	炕 頭	
炎 炎	炎 洲 企 業	炎 夏	炎 症	炎 涼	炎 涼 世 態	炎 暑	炎 黃	
炎 黃 子 孫	炎 熱	炒 勺	炒 勻	炒 向	炒 地 皮	炒 米	炒 作	
炒 作 股 票	炒 股 票	炒 青	炒 粉	炒 蛋	炒 貨	炒 菜	炒 買 炒 賣	
炒 飯	炒 匯	炒 過	炒 熟	炒 賣	炒 魷 魚	炒 鍋	炒 麵	
炊 火	炊 臼 之 戚	炊 臼 之 痛	炊 沙 作 飯	炊 沙 鏤 冰	炊 事	炊 事 員	炊 事 班	
炊 具	炊 金 饌 飯	炊 煙	炙 手 可 熱	炙 手 而 熱	炙 冰 使 燥	炙 烤	炙 鳳 烹 龍	
炙 熱	炙 膚 皸 足	炙 雞 漬 酒	爬 下	爬 上	爬 山	爬 山 者	爬 升	
爬 出	爬 耳 搔 腮	爬 行	爬 行 者	爬 行 動 物	爬 到	爬 坡	爬 泳	
爬 梳 剔 抉	爬 高	爬 動	爬 得	爬 犁	爬 著	爬 著 走	爬 進	
爬 過	爬 滿	爬 網	爬 樹	爬 牆	爬 蟲	爬 蟲 類	爬 繩	
爬 羅 剔 抉	爬 籐	爬 巖	爬 巖 術	爭 分 奪 妙	爭 分 奪 秒	爭 斤 論 兩	爭 功	
爭 用	爭 光	爭 先	爭 先 士 卒	爭 先 恐 後	爭 名	爭 名 於 朝 爭 利 於 市	爭 名 逐 利	
爭 名 奪 利	爭 名 競 利	爭 收	爭 作	爭 利	爭 吵	爭 妍 鬥 奇	爭 妍 鬥 艷	
爭 取	爭 取 和 平	爭 奇	爭 奇 斗 異	爭 奇 鬥 勝	爭 奇 鬥 艷	爭 性	爭 者	
爭 長 爭 短	爭 長 論 短	爭 長 競 短	爭 冠	爭 持	爭 相	爭 紅 斗 紫	爭 風 吃 醋	
爭 個	爭 氣	爭 起	爭 鬥	爭 執	爭 執 不 下	爭 執 不 休	爭 強	
爭 強 好 勝	爭 強 鬥 勝	爭 強 顯 勝	爭 得	爭 球	爭 產	爭 逐	爭 創	
爭 勝	爭 著	爭 雄	爭 搶	爭 當	爭 奪	爭 奪 戰	爭 端	
爭 鳴	爭 價	爭 嘴	爭 論	爭 論 不 休	爭 論 中	爭 論 者	爭 論 點	
爭 鋒	爭 鬧	爭 辨	爭 辦	爭 臉	爭 購	爭 寵	爭 議	
爭 議 地 區	爭 辯	爭 霸	爭 權	爭 權 奪 利	爭 權 攘 利	爭 艷	爸 爸	
版 工	版 心	版 本	版 式	版 次	版 色	版 位	版 材	
版 刻	版 版 六 十 四	版 物	版 面	版 彩	版 術	版 畫	版 稅	
版 照	版 圖	版 築 飯 牛	版 權	版 權 所 有	牧 人	牧 女	牧 工	
牧 牛	牧 牛 者	牧 主	牧 奴	牧 民	牧 地	牧 羊	牧 羊 人	
牧 羊 女	牧 羊 場	牧 豕 聽 經	牧 放	牧 活	牧 郎	牧 師	牧 師 會	
牧 畜	牧 草	牧 草 地	牧 馬	牧 馬 者	牧 區	牧 笛	牧 場	
牧 童	牧 業	牧 群	牧 歌	牧 漁	牧 廠	牧 豬 奴 戲	牧 養	
物 力	物 力 維 艱	物 不 平 則 鳴	物 中	物 化	物 主	物 以 稀 為 貴	物 以 類 聚	
物 件	物 至 則 反	物 色	物 事	物 性	物 物	物 阜 民 安	物 阜 民 熙	
物 品	物 建	物 是 人 非	物 架	物 流	物 流 業	物 美	物 美 價 廉	
物 面	物 候	物 倉	物 料	物 耗	物 堆	物 探	物 理	
物 理 上	物 理 化 學	物 理 光 學	物 理 性 質	物 理 量	物 理 學	物 理 學 家	物 理 變 化	
物 產	物 盛 則 衰	物 博	物 換 星 移	物 華 天 寶	物 象	物 傷 其 類	物 業	
物 極 必 反	物 極 則 衰	物 資	物 資 局	物 資 部	物 態	物 盡 其 用	物 種	
物 種 學	物 腐 蟲 生	物 語	物 誘	物 價	物 價 上 漲	物 價 工 作	物 價 局	
物 價 改 革	物 價 指 數	物 價 政 策	物 價 補 貼	物 價 管 理	物 價 檢 查	物 慾	物 論 沸 騰	
物 質	物 質 文 明	物 質 性	物 質 財 富	物 歸 原 主	物 歸 舊 主	物 離 鄉 貴	物 證	
物 鏡	物 類	物 競 天 擇	物 議 沸 騰	物 體	狀 子	狀 小	狀 元	
狀 好	狀 況	狀 詞	狀 態	狀 語	狀 貌	狀 膽	狎 弄	
狎 客	狙 擊	狙 擊 手	狙 擊 兵	狗	狗 一 樣	狗 口 裡 吐 不 出 象 牙	狗 仗 人 勢	
狗 仗 官 勢	狗 叫	狗 皮	狗 皮 膏 藥	狗 肉	狗 血	狗 血 淋 頭	狗 血 噴 頭	
狗 行 狼 心	狗 似	狗 吠	狗 吠 之 警	狗 吠 非 主	狗 吠 聲	狗 屁	狗 屁 不 通	
狗 尾 草	狗 尾 續 貂	狗 命	狗 肺 狼 心	狗 咬 呂 洞 賓	狗 咬 狗	狗 屎	狗 屎 堆	
狗 屋	狗 急 跳 牆	狗 洞	狗 苟 蠅 營	狗 食	狗 拿 耗 子	狗 追 耗 子	狗 馬 之 心	
狗 馬 聲 色	狗 偷 鼠 竊	狗 盜 鼠 竊	狗 盜 雞 鳴	狗 群	狗 熊	狗 窩	狗 腿	
狗 腿 子	狗 嘴 裡 吐 不 出 象 牙	狗 橇	狗 頭	狗 頭 軍 師	狗 膽	狗 膽 包 天	狗 顛 屁 股	
狗 黨	狗 黨 狐 群	狗 續 貂 尾	狗 彘 不 若	狗 彘 不 食	狐 仙	狐 穴	狐 死 兔 泣	
狐 死 首 丘	狐 步	狐 步 舞	狐 兔 之 悲	狐 奔 鼠 竄	狐 性	狐 朋 狗 友	狐 朋 狗 黨	
狐 虎 之 威	狐 狸	狐 狸 似	狐 狸 尾 巴	狐 狸 精	狐 臭	狐 假 虎 威	狐 假 鴟 張	
狐 媚	狐 媚 猿 攀	狐 媚 魘 道	狐 群 狗 黨	狐 裘	狐 裘 羔 袖	狐 裘 蒙 戎	狐 裘 蒙 茸	
狐 裘 龍 茸	狐 鼠 之 徒	狐 疑	狐 疑 未 決	狐 精	狐 鳴 狗 盜	狐 鳴 魚 書	狐 潛 鼠 伏	
狐 憑 鼠 伏	狐 藉 虎 威	玩 人 喪 德	玩 木	玩 水	玩 火	玩 火 自 焚	玩 世	
玩 世 不 恭	玩 世 不 羈	玩 地	玩 伴	玩 完	玩 弄	玩 兒	玩 兒 完	
玩 兒 鬧	玩 具	玩 具 店	玩 具 狗	玩 具 展	玩 具 箱	玩 味	玩 命	
玩 忽	玩 忽 職 守	玩 法	玩 物	玩 物 喪 志	玩 玩	玩 耍	玩 笑	
玩 起	玩 偶	玩 票	玩 蛇	玩 場	玩 牌	玩 意	玩 意 兒	
玩 遍	玩 厭	玩 滾	玩 樂	玩 賞	玩 鬧	玩 器	玩 癖	
玩 藝	玫 瑰	玫 瑰 色	玫 瑰 油	玫 瑰 花	疝 氣	疝 氣 痛	疙 疙 瘩 瘩	
疙 瘩	疚 心 疾 首	的 下 方	的 士	的 卡	的 呢	的 時 候	的 當	
的 話	的 樣 子	的 確	的 確 良	盂 方 水 方	盲 人	盲 人 把 燭	盲 人 摸 象	
盲 人 說 象	盲 人 瞎 馬	盲 女	盲 干	盲 文	盲 打	盲 生	盲 目	
盲 目 不 盲 心	盲 目 生 產	盲 目 性	盲 目 發 展	盲 目 樂 觀	盲 字	盲 者	盲 者 得 鏡	
盲 信	盲 流	盲 胞	盲 症	盲 動	盲 區	盲 啞	盲 從	
盲 眼	盲 眼 無 珠	盲 棋	盲 腸	盲 腸 炎	盲 障	盲 點	盲 騎 瞎 馬	
盲 聾	盲 聾 啞	直 入	直 下	直 上	直 上 青 雲	直 不	直 內 方 外	
直 升	直 升 飛 機	直 升 機	直 尺	直 方 圖	直 木 必 伐	直 布 羅 陀	直 立	
直 交	直 而 不 挺	直 至	直 行	直 抒	直 抒 己 見	直 系	直 系 血 親	
直 系 親 屬	直 角	直 角 三 角 形	直 角 尺	直 角 坐 標	直 角 器	直 言	直 言 不 諱	
直 言 勿 諱	直 言 止 論	直 言 正 色	直 言 正 諫	直 言 危 行	直 言 取 禍	直 言 骨 鯁	直 言 無 諱	
直 言 無 隱	直 言 極 諫	直 言 賈 禍	直 言 盡 意	直 言 讜 議	直 走	直 到	直 到 現 在	
直 呼	直 奔	直 定	直 性 子	直 拍	直 抵	直 昇 機	直 直	
直 門	直 前	直 待	直 指	直 是	直 流	直 流 電	直 眉	
直 眉 瞪 眼	直 述	直 飛	直 哭	直 射	直 峭	直 徑	直 挺	
直 挺 挺	直 書	直 航	直 送	直 退	直 情 徑 行	直 接	直 接 了 當	
直 接 投 資	直 接 原 因	直 接 參 與	直 接 稅	直 接 費 用	直 接 貿 易	直 接 進 行	直 接 經 驗	
直 接 對 話	直 接 領 導	直 接 影 響	直 接 選 舉	直 排	直 排 輪	直 敘	直 條	
直 爽	直 率	直 通	直 通 車	直 喘 氣	直 喻	直 插	直 筆	
直 著	直 視	直 進	直 搗	直 搗 黃 龍	直 溜	直 節 勁 氣	直 經	
直 腸	直 腸 炎	直 腸 鏡	直 落	直 號	直 話	直 路	直 跳	
直 運	直 道	直 道 不 容	直 道 而 行	直 道 事 人	直 達	直 逼	直 截	
直 截 了 當	直 瞄	直 說	直 撞	直 撞 橫 衝	直 撥	直 播	直 碼 尺	
直 線	直 衝 橫 撞	直 諒 多 聞	直 躺	直 銷	直 銷 公 司	直 駛	直 瞪 瞪	
直 講	直 轄	直 轄 市	直 鍊	直 隸	直 證	直 覺	直 譯	
直 屬	直 屬 單 位	直 屬 機 構	直 屬 機 關	直 觀	知 一 不 知 十	知 一 而 不 知 二	知 了	
知 人	知 人 下 士	知 人 之 明	知 人 之 術	知 人 則 哲	知 人 待 士	知 人 料 事	知 人 善 任	
知 人 善 察	知 人 論 世	知 子 莫 如 父	知 小 謀 大	知 己	知 己 之 遇	知 己 知 彼	知 已	
知 不	知 不 詐 愚	知 之 不 辱	知 之 為 知 之	知 之 甚 少	知 之 甚 多	知 今 博 古	知 心	
知 心 人	知 心 朋 友	知 心 著 意	知 心 話	知 止 不 辱 知 足 不 殆	知 水 仁 山	知 必 言 言 必 盡	知 本 老 爺	
知 白 守 黑	知 交	知 名	知 名 人 士	知 名 人 物	知 名 度	知 名 當 世	知 地 知 天	
知 安 忘 危	知 而 不 言	知 更 鳥	知 足	知 足 不 辱 知 止 不 殆	知 足 知 止	知 足 者 常 樂	知 足 常 足	
知 足 常 樂	知 足 無 求	知 事	知 來 藏 往	知 其 一 不 知 其 二	知 其 一 不 達 其 二	知 其 一 未 睹 其 二	知 命	
知 命 之 年	知 命 安 身	知 命 樂 天	知 府	知 底	知 往 鑒 今	知 彼 知 己	知 性	
知 易 行 難	知 法	知 法 犯 法	知 者	知 返	知 青	知 面 不 知 心	知 面 伯 明	
知 面 伯 鑒	知 音	知 音 諳 呂	知 音 識 曲	知 音 識 趣	知 恥	知 恩	知 恩 報 恩	
知 恩 報 德	知 時 識 務	知 書	知 書 知 禮	知 書 達 禮	知 書 識 禮	知 根 知 底	知 疼 著 熱	
知 高 識 低	知 悉	知 情	知 情 人	知 情 不 報	知 情 不 舉	知 情 者	知 情 達 理	
知 情 認 趣	知 情 識 趣	知 羞 識 廉	知 章 知 微	知 無 不 言	知 無 不 言 言 無 不 盡	知 無 不 言 言 無 不 聽	知 無 不 為	
知 無 不 盡	知 雄 守 雌	知 微 知 彰	知 罪	知 道	知 遇	知 遇 之 恩	知 遇 之 榮	
知 過	知 過 必 改	知 過 能 改	知 盡 能 索	知 數	知 畿 其 神	知 趣	知 曉	
知 機 識 竅	知 機 識 變	知 縣	知 錯 必 改	知 禮	知 識	知 識 分 子	知 識 化	
知 識 更 新	知 識 性	知 識 青 年	知 識 界	知 識 面	知 識 密 集	知 識 產 權	知 識 產 權 法	
知 識 就 是 力 量	知 識 結 構	知 識 競 賽	知 難 而 上	知 難 而 行	知 難 而 退	知 難 而 進	知 難 行 易	
知 覺	知 覺 力	知 覺 外	矽 土	矽 片	矽 石	矽 谷	矽 肺	
矽 肺 病	矽 品 精 密	矽 統	矽 統 科 技	矽 酸	矽 酸 鹽	矽 膠	矽 鋼	
矽 鋼 片	矽 豐 公 司	社 工	社 友	社 火	社 交	社 交 上	社 交 性	
社 交 室	社 交 活 動	社 交 界	社 交 藝 術	社 址	社 長	社 科	社 科 院	
社 紀	社 員	社 區	社 區 大 學	社 區 工 作	社 區 發 展	社 區 意 識	社 區 學 院	
社 教	社 評	社 隊	社 會	社 會 上	社 會 公 益	社 會 公 德	社 會 化	
社 會 主 義	社 會 司	社 會 局	社 會 抗 爭	社 會 制 度	社 會 性	社 會 科 學	社 會 科 學 院	
社 會 救 助	社 會 團 體	社 會 實 踐	社 會 福 利	社 會 學	社 會 關 係	社 會 黨	社 群	
社 運 人 士	社 鼠 城 狐	社 團	社 團 組 織	社 旗	社 稷	社 稷 之 臣	社 稷 之 役	
社 稷 之 器	社 稷 生 民	社 稷 為 墟	社 論	社 頭	社 頭 鄉	社 戲	祀 奉	
祀 為 神	祀 堂	祁 東	祁 門	祁 紅	祁 奚 之 舉	祁 奚 舉 子	祁 奚 舉 午	
祁 連	祁 寒 暑 雨	祁 寒 溽 雨	秉 公	秉 公 而 斷	秉 公 無 私	秉 公 辦 事	秉 性	
秉 承	秉 直	秉 持	秉 政	秉 要 執 本	秉 筆 直 書	秉 賦	秉 燭 夜 遊	
秉 笏 披 袍	空 了	空 人	空 口	空 口 湯 圓	空 口 無 憑	空 口 說 白 話	空 子	
空 中	空 中 巴 士	空 中 加 油	空 中 預 警 機	空 中 樓 閣	空 幻	空 心	空 心 架 子	
空 心 湯 圓	空 心 湯 團	空 心 磚	空 手	空 手 道	空 文	空 乏	空 出	
空 白	空 白 支 票	空 白 點	空 穴	空 穴 來 風	空 地	空 地 導 彈	空 地 戰	
空 竹	空 行	空 位	空 余	空 投	空 肚	空 言 無 補	空 言 虛 語	
空 谷 足 音	空 谷 幽 蘭	空 谷 傳 聲	空 身	空 車	空 防	空 兒	空 坦	
空 房	空 板 子	空 泛	空 的	空 空	空 空 如 也	空 空 洞 洞	空 空 導 彈	
空 花 繡	空 門	空 信	空 前	空 前 未 有	空 前 絕 後	空 前 團 結	空 城	
空 城 計	空 室	空 屋	空 巷	空 架 子	空 洞	空 洞 音	空 洞 無 物	
空 炮	空 軍	空 降	空 降 兵	空 頁	空 格	空 格 鍵	空 氣	
空 氣 污 染	空 氣 床	空 氣 狀	空 氣 動 力 學	空 氣 瓶	空 氣 團	空 缺	空 耗	
空 域	空 寂	空 桶	空 理	空 瓶	空 疏	空 處	空 速	
空 喊	空 就	空 無	空 無 一 人	空 等	空 給	空 著	空 虛	
空 跑	空 間	空 間 性	空 間 站	空 間 電 荷	空 閒	空 勤	空 想	
空 想 社 會 主 義	空 想 者	空 想 家	空 置	空 腸	空 腹	空 腹 便 便	空 腹 高 心	
空 話	空 話 連 篇	空 載	空 運	空 道	空 對	空 對 地	空 對 空	
空 廓	空 管	空 說	空 隙	空 際	空 彈	空 盤	空 箱	
空 談	空 談 者	空 調	空 調 器	空 調 機	空 論	空 論 家	空 戰	
空 擋	空 艙	空 蕩	空 蕩 蕩	空 頭	空 頭 支 票	空 檔	空 檢	
空 闊	空 擾	空 翻	空 轉	空 額	空 懷	空 曠	空 難	
空 攝	空 襲	空 罐	穹 天	穹 頂	穹 隆	穹 蒼	穹 窿	
糾 分	糾 正	糾 合	糾 合 之 眾	糾 查	糾 紛	糾 紛 案	糾 偏	
糾 眾	糾 結	糾 集	糾 葛	糾 察	糾 察 員	糾 察 隊	糾 繆 繩 違	
糾 纏	糾 纏 不 休	糾 纏 不 清	罔 上 虐 下	罔 知 所 措	羌 族	羌 無 故 實	者 也 之 乎	
肺 泡	肺 炎	肺 活 量	肺 氣 腫	肺 病	肺 病 患 者	肺 病 熱	肺 部	
肺 循 環	肺 結 核	肺 結 核 病	肺 腑	肺 腑 之 言	肺 葉	肺 塵	肺 靜 脈	
肺 癆	肺 癌	肺 臟	肥 力	肥 大	肥 大 症	肥 分	肥 水	
肥 田	肥 田 粉	肥 肉	肥 西	肥 壯	肥 沃	肥 皂	肥 皂 水	
肥 皂 泡	肥 皂 般	肥 皂 劇	肥 皂 箱	肥 育	肥 東	肥 肥	肥 厚	
肥 城	肥 美	肥 胖	肥 胖 症	肥 效	肥 料	肥 缺	肥 馬 虯 裘	
肥 鄉	肥 圓	肥 源	肥 遁 鳴 高	肥 實	肥 碩	肥 瘦	肥 豬	
肥 膩	肥 頭	肥 頭 大 耳	肢 節	肢 解	肢 窩	肢 體	肢 體 殘 障 福 利 協 進 會	
肱 骨	股 子	股 分	股 市	股 市 大 盤	股 市 低 迷	股 本	股 民	
股 份	股 份 公 司	股 份 有 限 公 司	股 份 制	股 份 經 濟	股 肉	股 利	股 利 配 發	
股 東	股 東 大 會	股 東 會	股 東 臨 時 會	股 疝	股 金	股 長	股 勁	
股 室	股 指	股 員	股 息	股 骨	股 票	股 票 市 場	股 票 交 易 所	
股 票 股 利	股 票 指 數	股 掌 之 上	股 款	股 溝	股 資	股 價	股 價 指 數	
股 數	股 繩	股 權	肩 上	肩 扛	肩 並 肩	肩 挑	肩 背 相 望	
肩 胛	肩 胛 骨	肩 負	肩 負 重 任	肩 負 起	肩 骨	肩 帶	肩 部	
肩 章	肩 筐	肩 窩	肩 膀	肩 寬	肩 摩 踵 接	肩 摩 轂 擊	肩 擔 兩 頭 脫	
肩 頭	肯 干	肯 切	肯 尼 亞	肯 尼 亞 人	肯 尼 迪	肯 亞	肯 定	
肯 定 性	肯 於	肯 堂 肯 構	肯 塔 基	肯 塔 基 州	肯 構 肯 堂	肯 德 基	臥 下	
臥 不 安 枕	臥 不 安 席	臥 地	臥 式	臥 床	臥 床 不 起	臥 車	臥 車 舖	
臥 具	臥 底	臥 房	臥 虎	臥 姿	臥 室	臥 軌	臥 倒	
臥 狼 當 道	臥 病	臥 病 在 床	臥 雪 眠 霜	臥 椅	臥 鼓 偃 旗	臥 旗 息 鼓	臥 榻	
臥 榻 之 側	臥 談	臥 艙	臥 龍	臥 薪 嘗 膽	臥 舖	舍 下	舍 弟	
舍 監	芳 心	芳 名	芳 苑	芳 苑 鄉	芳 香	芳 香 油	芳 香 族	
芳 香 烴	芳 容	芳 草	芳 華	芳 菲	芳 醇	芳 蹤	芳 齡	
芳 蘭 竟 體	芳 烴	芝 加 哥	芝 加 哥 公 牛	芝 加 哥 市	芝 艾 俱 盡	芝 麻	芝 麻 油	
芝 麻 醬	芝 焚 蕙 歎	芝 蘭 之 室	芝 蘭 玉 樹	芙 蓉	芙 蓉 出 水	芭 芭 拉	芭 達 雅	
芭 蕉	芭 蕾	芭 蕾 舞	芽 型	芽 胞	芽 蟲	芽 體	芟 繁 就 簡	
芹 菜	花 了	花 上	花 子	花 分	花 天 百 日 紅	花 天 酒 地	花 心	
花 木	花 木 瓜	花 王	花 王 企 業	花 仙 子	花 卉	花 去	花 台	
花 市	花 布	花 旦	花 生	花 生 米	花 生 油	花 生 餅	花 用	
花 甲	花 白	花 光	花 匠	花 名	花 名 冊	花 在	花 好 月 圓	
花 式	花 式 滑 冰	花 托	花 朵	花 池	花 色	花 色 品 種	花 衣	
花 似	花 坊	花 完	花 序	花 束	花 言	花 言 巧 語	花 車	
花 兒	花 刺	花 到	花 呢	花 季	花 店	花 房	花 招	
花 明 柳 暗	花 果	花 枝 招 展	花 狀	花 的	花 芽	花 花	花 花 公 子	
花 花 太 歲	花 花 世 界	花 花 腸 子	花 花 綠 綠	花 門 柳 戶	花 青 素	花 冠	花 前 月 下	
花 柱	花 架	花 架 子	花 柳	花 柳 病	花 炮	花 盆	花 科	
花 籽	花 紅	花 紅 柳 綠	花 苗	花 苞	花 香	花 香 鳥 語	花 哨	
花 圃	花 容 月 貌	花 展	花 徑	花 拳	花 料	花 海	花 粉	
花 粉 管	花 粉 熱	花 紋	花 般	花 草	花 草 樹 木	花 茶	花 酒	
花 圈	花 崗 石	花 崗 巖	花 彫	花 得	花 掉	花 晨 月 夕	花 梗	
花 瓶	花 盒	花 眼	花 莖	花 蛋	花 被	花 都	花 閉 月 羞	
花 鳥	花 斑	花 期	花 朝 月 夕	花 朝 月 夜	花 椒	花 棚	花 殘 月 缺	
花 筒	花 絮	花 絲	花 腔	花 菜	花 街 柳 巷	花 街 柳 陌	花 費	
花 費 者	花 軸	花 開	花 開 了	花 開 著	花 黃	花 園	花 園 口	
花 會	花 椰 菜	花 蒂	花 萼	花 裡 胡 哨	花 農	花 飾	花 鼓	
花 鼓 戲	花 團	花 團 錦 簇	花 旗	花 旗 銀 行	花 槍	花 種	花 魁	
花 劍	花 樣	花 樣 游 泳	花 樣 滑 冰	花 樣 翻 新	花 蓮	花 蓮 港	花 遮 柳 掩	
花 遮 柳 隱	花 銷	花 壇	花 壇 鄉	花 燈	花 縣	花 蕊	花 錢	
花 燭	花 燭 洞 房	花 牆	花 環	花 簇 錦 簇	花 簇 錦 攢	花 臉	花 蕾	
花 鍵	花 叢	花 蟲	花 蟲 類	花 顏 月 貌	花 瓣	花 藝	花 藥	
花 轎	花 邊	花 邊 人 物	花 邊 新 聞	花 籃	花 露	花 魔 酒 病	芬 利	
芬 芳	芬 香	芬 蘭	芬 蘭 人	芬 蘭 烏	芬 蘭 語	芬 蘭 戰 爭	芥 子	
芥 子 氣	芥 末	芥 菜	芥 蒂	芥 藍	芯 子	芯 片	芯 片 組	
芯 件	芸 豆	芸 芸	芸 芸 眾 生	虎 入 羊 群	虎 口	虎 口 拔 牙	虎 口 逃 生	
虎 口 餘 生	虎 子	虎 牙	虎 丘	虎 皮	虎 皮 羊 質	虎 穴	虎 穴 龍 潭	
虎 伏	虎 年	虎 耳	虎 尾	虎 尾 春 冰	虎 尾 鎮	虎 步 龍 行	虎 兕 出 柙	
虎 林	虎 虎	虎 門	虎 威	虎 威 狐 假	虎 毒 不 食 兒	虎 背 熊 腰	虎 狼	
虎 鬥	虎 鬥 龍 爭	虎 將	虎 略 龍 韜	虎 眼 石	虎 符	虎 視	虎 視 鷹 瞵	
虎 視 眈 眈	虎 勢	虎 窟 龍 潭	虎 落 平 川	虎 鉗	虎 嘯	虎 嘯 龍 吟	虎 踞	
虎 踞 龍 盤	虎 踞 龍 蟠	虎 魄	虎 蕩 羊 群	虎 頭 虎 腦	虎 頭 埤	虎 頭 蛇 尾	虎 頭 鉗	
虎 頭 鼠 尾	虎 頭 燕 頷	虎 擲 龍 拿	虎 嚥 狼 吞	虎 類	虎 躍 龍 騰	虎 體 熊 腰	虱 子	
虱 卵	初 一	初 七	初 九	初 二	初 八	初 十	初 三	
初 上	初 小	初 中	初 中 生	初 五	初 六	初 冬	初 出	
初 出 茅 廬	初 加 工	初 四	初 犯	初 生 之 犢	初 生 之 犢 不 怕 虎	初 生 之 犢 不 畏 虎	初 生 牛 犢 不 怕 虎	
初 交	初 伏	初 年	初 旬	初 次	初 次 用	初 步	初 見	
初 見 成 效	初 來 乍 到	初 具	初 具 規 模	初 始	初 始 化	初 版	初 度	
初 建	初 春	初 映	初 查	初 為	初 看	初 秋	初 值	
初 唐	初 夏	初 時	初 校	初 紡	初 級	初 級 中 學	初 級 社	
初 級 班	初 級 產 品	初 級 階 段	初 級 線 圈	初 級 職 稱	初 級 讀 本	初 衷	初 婚	
初 探	初 現	初 產	初 訪	初 設	初 速	初 雪	初 鹿 牧 場	
初 創	初 喪	初 期	初 等	初 等 教 育	初 等 數 學	初 評	初 診	
初 進	初 開	初 葉	初 試	初 態	初 演	初 算	初 審	
初 寫 黃 庭	初 潮	初 稿	初 學	初 學 者	初 戰	初 戰 告 捷	初 選	
初 賽	初 願	初 露	初 露 鋒 芒	初 讀	初 戀	表 上	表 土	
表 土 層	表 中	表 內	表 尺	表 兄	表 兄 弟	表 冊	表 功	
表 外	表 白	表 皮	表 示	表 示 同 情	表 示 尊 敬	表 式	表 尾	
表 弟	表 形	表 形 碼	表 決	表 決 權	表 叔	表 妹	表 姑	
表 姐	表 姊	表 性	表 明	表 明 是	表 明 態 度	表 姨	表 姨 父	
表 為	表 述	表 面	表 面 上	表 面 化	表 面 光	表 面 性	表 面 張 力	
表 面 積	表 音	表 音 文 字	表 哥	表 格	表 針	表 帶	表 情	
表 情 豐 富	表 淺	表 率	表 率 作 用	表 現	表 現 力	表 現 主 義	表 袋	
表 單	表 揚	表 殼	表 筆	表 象	表 項	表 意	表 意 文 字	
表 舅	表 舅 母	表 號	表 裡	表 裡 一 致	表 裡 山 河	表 裡 不 一	表 裡 如 一	
表 裡 受 敵	表 裡 相 合	表 裡 相 應	表 裡 相 濟	表 達	表 達 力 強	表 達 方 式	表 達 式	
表 達 性	表 達 法	表 達 清 晰	表 團	表 彰	表 彰 大 會	表 彰 會	表 態	
表 演	表 演 者	表 演 唱	表 演 賽	表 演 藝 術	表 演 藝 術 家	表 語	表 層	
表 徵	表 盤	表 親	表 頭	表 露	表 觀	表 侄	軋 平	
軋 成	軋 死	軋 制	軋 軋	軋 軋 聲	軋 染	軋 帶	軋 棉	
軋 棉 機	軋 傷	軋 碎	軋 輥	軋 機	軋 鋼	軋 鋼 廠	軋 聲	
迎 上	迎 刃 而 解	迎 出	迎 合	迎 奸 賣 俏	迎 考	迎 來	迎 來 送 往	
迎 客	迎 春	迎 春 花	迎 面	迎 風	迎 風 開	迎 候	迎 神	
迎 送	迎 娶	迎 接	迎 接 挑 戰	迎 著	迎 詞	迎 意 承 旨	迎 新	
迎 新 送 故	迎 新 送 舊	迎 賓	迎 賓 曲	迎 賓 館	迎 敵	迎 戰	迎 親	
迎 頭	迎 頭 痛 擊	迎 頭 趕 上	迎 擊	迎 辭	返 工	返 本 還 源	返 正 撥 亂	
返 回	返 回 地 面	返 老 還 童	返 老 歸 童	返 於	返 青	返 城	返 省	
返 修	返 家	返 校	返 祖	返 航	返 躬 內 省	返 送	返 國	
返 程	返 鄉	返 照	返 照 會 光	返 聘	返 潮	返 銷	返 銷 糧	
返 駛	返 樸 歸 真	返 還	近 一 年 來	近 一 點	近 人	近 支	近 日	
近 日 來	近 日 點	近 月 點	近 水	近 水 樓 台	近 水 樓 台 先 得 月	近 火	近 火 先 焦	
近 世	近 乎	近 乎 零	近 代	近 代 化	近 代 史	近 古	近 因	
近 地	近 地 點	近 在	近 在 咫 尺	近 在 眉 睫	近 年	近 年 來	近 朱 者 赤	
近 朱 者 赤 近 墨 者 黑	近 百 年 來	近 色	近 位	近 似	近 似 計 算	近 似 值	近 作	
近 利	近 些	近 些 日 子	近 些 年	近 些 年 來	近 來	近 兩	近 兩 年	
近 岸	近 於	近 於 零	近 東	近 況	近 的	近 便	近 前	
近 看	近 郊	近 郊 區	近 悅 遠 來	近 旁	近 海	近 海 岸	近 情	
近 現 代 史	近 處	近 陸	近 幾 天	近 幾 天 來	近 幾 年	近 幾 年 來	近 幾 周 來	
近 幾 個 月	近 景	近 期	近 期 中	近 期 內	近 程	近 視	近 視 眼	
近 距	近 極	近 歲	近 義 詞	近 路	近 道	近 聞	近 憂	
近 衛	近 衛 軍	近 鄰	近 墨	近 墨 者 黑	近 戰	近 親	近 點	
近 體	近 體 詩	邸 宅	邱 正 雄	邱 吉 爾	邱 復 生	邱 進 益	邱 義 仁	
采 收	采 自	采 沙 坑	采 邑	采 制	采 油	采 空 區	采 金	
采 金 區	采 風	采 勘	采 區	采 船 不 斫	采 貨	采 割	采 結	
采 暖	采 煤	采 煉	采 種	采 寫	采 撈	采 樣	采 編	
采 錄	采 薪 之 疾	采 薪 之 憂	采 蘭 贈 芍	金 三 角	金 口	金 口 木 舌	金 口 玉 言	
金 大 中	金 子	金 山	金 山 鄉	金 川	金 工	金 不 換	金 丹	
金 元	金 友 玉 昆	金 戈	金 戈 鐵 馬	金 文	金 斗	金 牙	金 牛	
金 牛 座	金 代	金 玉	金 玉 之 言	金 玉 良 言	金 玉 其 外 敗 絮 其 中	金 玉 滿 堂	金 田 起 義	
金 石	金 石 不 渝	金 石 之 交	金 石 之 言	金 石 交 情	金 石 至 交	金 石 良 言	金 石 為 開	
金 石 絲 竹	金 光	金 光 閃 閃	金 匠	金 合 歡	金 字	金 字 招 牌	金 字 塔	
金 舌 弊 口	金 色	金 利 精 密	金 吾 不 禁	金 沙	金 沙 江	金 沙 百 貨	金 沙 薩	
金 谷 酒 數	金 佳 映	金 店	金 枝 玉 葉	金 花	金 門	金 雨 企	金 雨 企 業	
金 冠	金 品	金 城	金 城 武	金 城 湯 池	金 屋	金 屋 貯 嬌	金 屋 藏 嬌	
金 星	金 盃	金 相	金 相 玉 質	金 盾	金 科 玉 律	金 科 玉 條	金 秋	
金 美 克 能	金 剛	金 剛 石	金 剛 努 目	金 剛 怒 目	金 剛 砂	金 剛 隊	金 剛 鑽	
金 峰 鄉	金 庫	金 桔	金 海	金 粉	金 素 梅	金 翅 擘 海	金 迷 紙 醉	
金 針 度 人	金 針 菜	金 馬 玉 堂	金 馬 地 區	金 堂	金 婚	金 庸	金 條	
金 瓶 梅	金 蛋	金 釵	金 釵 十 二	金 陵	金 魚	金 魚 草	金 魚 藻	
金 凱 瑞	金 湖	金 湯	金 牌	金 牌 獎	金 童 玉 女	金 筆	金 絲	
金 絲 雀	金 絲 猴	金 絲 燕	金 華	金 貂 換 酒	金 超 群	金 量	金 黃	
金 黃 色	金 嗓 子	金 塔	金 塊	金 殿	金 盞 花	金 飾	金 鼎 證 券	
金 鼓	金 鼓 連 天	金 鼓 喧 天	金 鼓 齊 鳴	金 像	金 像 電 子	金 匱 石 室	金 寨	
金 幣	金 榜	金 榜 掛 名	金 榜 題 名	金 槍 魚	金 碧	金 碧 熒 煌	金 碧 輝 煌	
金 箔	金 箔 匠	金 製	金 銀	金 銀 花	金 銀 財 寶	金 價	金 獎	
金 盤	金 緯 纖 維	金 蓮	金 質	金 質 獎	金 質 獎 章	金 髮	金 器	
金 壁 輝 煌	金 壇	金 橘	金 甌 無 缺	金 磚	金 融	金 融 危 機	金 融 股	
金 融 信 息	金 融 政 策	金 融 界	金 融 統 計	金 融 期 貨	金 融 業	金 融 資 本	金 融 寡 頭	
金 融 弊 案	金 融 體 制	金 錠	金 錶	金 錢	金 錢 上	金 錢 至 上	金 錢 花	
金 錢 豹	金 鋼	金 鋼 石	金 龍 旗 青 棒 賽	金 龜	金 龜 子	金 燦 燦	金 聲 玉 振	
金 繡	金 蟬	金 蟬 脫 殼	金 鎊	金 雞	金 雞 獎	金 雞 獨 立	金 額	
金 蟾 脫 殼	金 邊	金 鏈	金 寶 電 子	金 礦	金 鐘	金 鐘 獎	金 屬	
金 屬 元 素	金 屬 材 料	金 屬 性	金 屬 絲	金 屬 製 品	金 屬 模	金 屬 學	金 屬 鍵	
金 蘭	金 蘭 之 契	金 鐲	金 鶯	金 黴 素	金 鑰 匙	長 一 志	長 一 智	
長 了	長 上	長 久	長 久 遠 源	長 大	長 大 了	長 大 成 人	長 大 衣	
長 女	長 子	長 工	長 文	長 方	長 方 形	長 方 體	長 日	
長 木 條	長 毛	長 毛 絨	長 毛 象	長 牙	長 世	長 兄	長 出	
長 外 衣	長 生	長 生 久 視	長 生 不 死	長 生 不 老	長 生 電 廠	長 白	長 白 山	
長 矛	長 石	長 列	長 吁 短 歎	長 吃	長 在	長 存	長 安	
長 安 街	長 安 道 上	長 年	長 年 累 月	長 成	長 曲	長 有	長 此	
長 此 下 去	長 此 以 往	長 江	長 江 三 角 洲	長 江 口	長 江 大 橋	長 江 流 域	長 羽 毛	
長 老	長 老 會	長 耳	長 舌	長 舌 者	長 舌 婦	長 衣	長 尾	
長 形	長 沙	長 沙 市	長 男	長 角	長 谷 建 設	長 足	長 足 進 展	
長 制	長 命	長 命 百 歲	長 命 富 貴	長 夜	長 夜 難 明	長 官	長 官 意 志	
長 庚 醫 院	長 征	長 於	長 明	長 服	長 枕	長 枕 大 被	長 枝	
長 林 豐 草	長 河	長 波	長 治	長 治 久 安	長 治 鄉	長 物	長 的	
長 直	長 空	長 者	長 肥	長 肥 了	長 長	長 青	長 亭 短 亭	
長 信	長 型	長 垣	長 城	長 度	長 思	長 恨	長 春	
長 春 市	長 春 籐	長 柄	長 段 時 間	長 流	長 流 不 息	長 活	長 為	
長 相	長 胖	長 虹	長 衫	長 音	長 風 破 浪	長 孫	長 峽	
長 師	長 拳	長 效	長 時	長 時 期	長 時 期 以 來	長 時 間	長 眠	
長 窄	長 草	長 釘	長 高	長 假	長 崎	長 得	長 排	
長 斜	長 梯	長 條	長 條 圖	長 笛	長 粗	長 統 靴	長 統 襪	
長 處	長 蛇 陣	長 袖	長 袖 善 舞	長 袍	長 袋 網	長 逝	長 途	
長 途 汽 車	長 途 跋 涉	長 途 運 輸	長 途 電 話	長 圍 巾	長 堤	長 廊	長 惡 不 悛	
長 揖	長 揖 不 拜	長 期	長 期 化	長 期 存 在	長 期 有 效	長 期 性	長 期 間	
長 期 戰	長 椅	長 短	長 程	長 策	長 筒	長 絨	長 絲	
長 著	長 街	長 距 離	長 跑	長 進	長 隊	長 順	長 勢	
長 勢 喜 人	長 圓	長 圓 形	長 媳	長 煙 袋	長 腳	長 號	長 裙	
長 裙 褲	長 裝	長 詩	長 話	長 路	長 跪	長 達	長 靴	
長 凳	長 壽	長 夢	長 寧	長 榮 海 運	長 榮 航 空	長 榮 貨 櫃	長 榮 運 輸	
長 槍	長 歌 當 哭	長 滿	長 滿 草	長 睡 衣	長 算 遠 略	長 腿	長 遠	
長 遠 打 算	長 遠 目 標	長 遠 利 益	長 遠 規 劃	長 銘 實 業	長 鼻	長 齊	長 億 實 業	
長 劍	長 嘴	長 嘯	長 寬	長 憂	長 樂	長 歎	長 熟	
長 瘤	長 瘡	長 篇	長 篇 大 論	長 篇 小 說	長 篇 累 牘	長 篇 連 載	長 篇 闊 論	
長 線	長 膘	長 談	長 調	長 輩	長 靠 椅	長 髮	長 整 型	
長 機	長 興	長 興 化 學	長 褲	長 親	長 頸	長 頸 鹿	長 龍	
長 嶺	長 臂	長 臂 猿	長 錘	長 鴻 營 造	長 點	長 蟲	長 鞭	
長 繩 系 日	長 繩 系 景	長 辭	長 鏡 頭	長 襪	長 驅	長 驅 而 入	長 驅 直 入	
長 驅 徑 入	長 轡 遠 御	長 轡 遠 馭	長 鬚	長 纓	長 纖 布	門 人	門 下	
門 上	門 口	門 子	門 不 夜 關	門 不 夜 扃	門 不 停 賓	門 內	門 戶	
門 戶 之 見	門 戶 之 爭	門 戶 開 放	門 斗	門 牙	門 可 張 羅	門 可 羅 雀	門 外	
門 外 漢	門 市	門 市 部	門 生	門 生 古 吏	門 扣	門 坎	門 志	
門 技	門 把	門 見	門 兒	門 到 戶 說	門 到 門 服 務	門 店	門 房	
門 板	門 門	門 前	門 前 三 包	門 客	門 後	門 柱	門 柄	
門 洞	門 閂	門 限	門 面	門 庭	門 庭 冷 落	門 庭 若 市	門 庭 若 縭	
門 庭 赫 奕	門 徒	門 徑	門 扇	門 框	門 栓	門 神	門 衰 祚 薄	
門 側	門 崗	門 票	門 第	門 堪 羅 雀	門 廊	門 插	門 插 銷	
門 無 雜 賓	門 牌	門 牌 號	門 窗	門 診	門 診 所	門 診 室	門 診 部	
門 開	門 階	門 楣	門 煙	門 當 戶 對	門 禁 森 嚴	門 號	門 裡	
門 路	門 道	門 鈴	門 電 路	門 緊	門 閥	門 隙	門 樓	
門 衛	門 齒	門 橋	門 頭 溝	門 牆	門 牆 桃 李	門 環	門 縫	
門 聯	門 臉	門 臉 兒	門 檻	門 檻 兒	門 鎖	門 簾	門 邊	
門 類	門 警	門 廳	阜 外	阜 陽	阜 新	陀 螺	陀 羅	
阿 公	阿 斗	阿 司 匹 林	阿 托 品	阿 伯	阿 其 所 好	阿 叔	阿 妹	
阿 妹 妹	阿 姆 斯 特 丹	阿 拉	阿 拉 丁	阿 拉 木 圖	阿 拉 伯	阿 拉 伯 人	阿 拉 伯 阿 盟	
阿 拉 伯 阿 灣	阿 拉 伯 語	阿 拉 伯 數 字	阿 拉 伯 聯 合 大 公 國	阿 拉 伯 聯 合 酋 長 國	阿 拉 伯 聯 盟	阿 拉 法 特	阿 拉 斯 加	
阿 拉 善 盟	阿 波 羅	阿 波 羅 神	阿 爸	阿 狗	阿 肯 色	阿 門	阿 亮	
阿 保 之 功	阿 保 之 勞	阿 姨	阿 飛	阿 哥	阿 娘	阿 根 廷	阿 根 廷 人	
阿 格 西	阿 爹	阿 曼	阿 基 米 德	阿 婆	阿 富 汗	阿 富 汗 人	阿 富 汗 語	
阿 尊 事 貴	阿 斯 匹 林	阿 雅	阿 雅 超 時 空 歷 險	阿 順 取 容	阿 塞 拜 疆	阿 媽	阿 意 順 旨	
阿 爺	阿 裡 山	阿 裡 巴 巴	阿 裡 斯 多 德	阿 爾 及 利 亞	阿 爾 及 爾	阿 爾 巴 尼 亞	阿 爾 卑 斯	
阿 膠	阿 蓮 鄉	阿 諛	阿 諛 取 容	阿 諛 奉 承	阿 諛 逢 迎	阿 諛 順 旨	阿 諛 順 意	
阿 諾 史 瓦 辛 格	阿 貓	阿 嚏	阿 彌 佗 佛	阿 彌 陀 佛	阿 聯	阿 聯 大 公 國	阿 嬸	
阿 寶	阿 癩	阻 力	阻 止	阻 止 物	阻 尼	阻 抗	阻 值	
阻 害	阻 援	阻 塞	阻 塞 物	阻 遏	阻 隔	阻 截	阻 滯	
阻 滯 劑	阻 撓	阻 擋	阻 擋 物	阻 擊	阻 擊 戰	阻 擾	阻 擾 性	
阻 斷	阻 斷 器	阻 礙	阻 礙 物	阻 礙 者	阻 攔	附 力	附 下 罔 上	
附 上	附 上 罔 下	附 小	附 中	附 文	附 以	附 刊	附 加	
附 加 物	附 加 條 件	附 加 稅	附 加 費	附 生	附 件	附 列	附 名	
附 合	附 合 聲	附 在	附 有	附 耳	附 言	附 和	附 征	
附 性	附 於	附 物	附 表	附 近	附 近 地 區	附 則	附 後	
附 背 扼 喉	附 頁	附 記	附 送	附 寄	附 帶	附 庸	附 庸 風 雅	
附 庸 國	附 從	附 啟	附 設	附 單	附 報	附 發	附 筆	
附 著	附 著 力	附 著 物	附 註	附 勢	附 會	附 載	附 圖	
附 鳳 攀 龍	附 錄	附 隨	附 營	附 膺 頓 足	附 點	附 織	附 贅 縣 疣	
附 識	附 贈	附 議	附 議 者	附 屬	附 屬 物	附 屬 品	附 屬 國	
附 體	附 驥 攀 鴻	附 膻 逐 臭	附 膻 逐 穢	雨 中	雨 天	雨 水	雨 布	
雨 打	雨 打 風 吹	雨 衣	雨 夾 雪	雨 具	雨 夜	雨 季	雨 披	
雨 果	雨 林	雨 花 台	雨 前	雨 後	雨 後 春 筍	雨 急 下	雨 柱	
雨 珠	雨 停 了	雨 區	雨 帶	雨 情	雨 淋	雨 雪	雨 傘	
雨 散 雲 收	雨 棚	雨 絲	雨 量	雨 量 表	雨 量 計	雨 順 風 調	雨 勢	
雨 滑	雨 罩	雨 過 天 青	雨 過 天 晴	雨 靴	雨 幕	雨 滴	雨 線	
雨 鞋	雨 篷	雨 聲	雨 點	雨 點 兒	雨 簾	雨 霧	雨 露	
雨 露 之 恩	青 山	青 山 綠 水	青 川	青 工	青 天	青 天 白 日	青 天 霹 靂	
青 少 年	青 少 年 公 益 組 織	青 少 年 時 代	青 少 年 問 題	青 木 功	青 出 於 藍	青 史	青 史 名 留	
青 史 留 名	青 史 留 芳	青 史 傳 名	青 玉 色	青 白	青 皮	青 石	青 光 眼	
青 州 從 事	青 年	青 年 一 代	青 年 人	青 年 工 人	青 年 才 俊	青 年 心 理 學	青 年 社 會 學	
青 年 活 動	青 年 突 擊 手	青 年 組 織	青 年 期	青 年 幹 部	青 年 節	青 年 節 日	青 年 運 動	
青 年 團	青 年 學	青 年 學 生	青 年 聯 歡 節	青 灰	青 灰 色	青 色	青 衣	
青 壯 年	青 豆	青 松	青 河	青 花	青 青	青 春	青 春 豆	
青 春 兩 敵	青 春 活 力	青 春 期	青 紅 皂 白	青 苗	青 苔	青 面 獠 牙	青 島	
青 浦	青 海	青 海 省	青 草	青 茶	青 商 會	青 商 總 會	青 梅	
青 梅 竹 馬	青 瓷	青 眼	青 粗 飼 料	青 魚	青 棒	青 椒	青 筋	
青 紫	青 絲	青 菜	青 蛙	青 詠 有 耳	青 貯	青 陽	青 雲	
青 雲 直 上	青 雲 萬 里	青 雲 電 器	青 須 公	青 黃	青 黃 不 接	青 睞	青 稞	
青 腫	青 葉	青 過 於 藍	青 飼 料	青 綠	青 綠 色	青 翠	青 輔 會	
青 銅	青 銅 匠	青 銅 色	青 銅 器	青 樓	青 蓮	青 蔥	青 鞋 布 襪	
青 燈 黃 卷	青 錢 萬 選	青 龍	青 幫	青 聯	青 臉 獠 牙	青 藏	青 藍	
青 蠅 染 白	青 蠅 點 素	青 籐	青 巖	青 黴 素	青 黴 菌	非 一 日 之 寒	非 一 狐 之 白	
非 人	非 人 工	非 人 不 傳	非 人 道	非 人 類	非 凡	非 凡 人	非 也	
非 不	非 公 莫 入	非 公 開	非 分	非 分 之 想	非 天 然	非 比	非 主 要	
非 可	非 古 典	非 必 要	非 本	非 本 意	非 本 質	非 正 式	非 正 統	
非 正 規	非 正 規 軍	非 永 久	非 生 物	非 生 產 性	非 白 人	非 交 互	非 交 戰	
非 企 業	非 同	非 同 一 般	非 同 小 可	非 同 以 往	非 同 步	非 同 尋 常	非 尖 峰	
非 有	非 此	非 此 即 彼	非 池 中 物	非 而	非 自 然	非 但	非 你 莫 屬	
非 妥	非 我	非 我 族 類 七 心 必 異	非 決 定	非 亞	非 例 外	非 典 型	非 到	
非 命	非 宗 教	非 官 方	非 昔 是 今	非 法	非 法 性	非 法 者	非 法 捕 魚	
非 物 質	非 社 會	非 金 屬	非 保 密	非 政	非 政 治	非 故	非 故 意	
非 洲	非 洲 人	非 洲 大 陸	非 洲 之 角	非 洲 國 家	非 活 動	非 要	非 負 值	
非 軍 事	非 音 樂	非 個	非 個 人	非 原 先	非 笑	非 純 種	非 高 峰	
非 偽 造	非 做	非 唯 心	非 婚 生 子 女	非 專 利	非 專 家	非 常	非 常 好	
非 常 低	非 常 重	非 彩 色	非 得	非 條 件 反 射	非 理 智	非 現 世	非 現 實	
非 異 人 任	非 被	非 規 範	非 復 選	非 晶 體	非 等	非 週 期	非 愚 則 誣	
非 意	非 意 相 干	非 會 員	非 經	非 道 德	非 電 子	非 電 解 質	非 零	
非 預 謀	非 塵 世	非 實 在	非 實 質	非 對 抗 性	非 對 偶	非 對 稱	非 暴 力	
非 標 準	非 確 定	非 線 性	非 請	非 賣 品	非 適 應	非 學 來	非 導 體	
非 戰	非 戰 鬥	非 機 動 車	非 獨	非 親 非 故	非 隨 機	非 應 用	非 營 利	
非 禮	非 職	非 職 業	非 離 散	非 穩 定	非 藝 術	非 關 稅	非 難	
非 難 者	非 議	非 黨	非 黨 員	非 屬	非 聽 覺	非 邏 輯	非 驢 非 馬	
亟 待	亟 欲	亟 需	亭 子	亭 台 樓 閣	亭 亭	亭 亭 玉 立	亭 室	
亭 裡	亮 了	亮 丑	亮 出	亮 光	亮 光 區	亮 色	亮 底	
亮 的	亮 度	亮 相	亮 起	亮 閃 閃	亮 堂	亮 堂 堂	亮 眼	
亮 晶 晶	亮 牌	亮 著	亮 節	亮 錚 錚	亮 點	亮 麗	信 上	
信 口 開 河	信 口 雌 黃	信 大 水 泥	信 不 過	信 中	信 元 實 業	信 及 豚 魚	信 天 翁	
信 天 游	信 心	信 心 倍 增	信 手	信 手 拈 來	信 以 為 真	信 令	信 外	
信 札	信 用	信 用 卡	信 用 交 易	信 用 合 作 社	信 用 狀	信 用 社	信 用 度	
信 用 評 等	信 用 證	信 皮	信 立 化 學	信 件	信 任	信 任 投 票	信 任 狀	
信 任 票	信 任 感	信 仰	信 仰 者	信 合 社	信 她	信 守	信 守 合 同	
信 而 有 徵	信 址	信 步	信 使	信 函	信 奉	信 念	信 服	
信 物	信 者	信 南	信 南 建 設	信 封	信 政	信 風	信 差	
信 徒	信 息	信 息 中 心	信 息 系 統	信 息 社 會	信 息 高 速 公 路	信 息 處 理	信 息 量	
信 息 論	信 息 戰	信 益 陶 瓷	信 神	信 紙	信 託	信 託 公 司	信 馬 游 韁	
信 區	信 得 過	信 徙	信 從	信 教	信 條	信 訪	信 筆 塗 鴉	
信 筒	信 貸	信 貸 員	信 貸 資 金	信 匯	信 義	信 義 房 屋	信 義 區	
信 義 鄉	信 號	信 號 手	信 號 台	信 號 曲	信 號 彈	信 號 器	信 號 機	
信 號 燈	信 裡	信 道	信 管	信 箋	信 箋 簿	信 誓	信 誓 旦 旦	
信 說	信 標	信 箱	信 賞 必 罰	信 賴	信 賴 者	信 檔	信 鴿	
信 譽	信 譽 第 一	侵 入	侵 入 者	侵 犯	侵 犯 者	侵 佔	侵 吞	
侵 染	侵 害	侵 害 人	侵 害 者	侵 略	侵 略 者	侵 略 軍	侵 略 國	
侵 略 戰 爭	侵 略 擴 張	侵 透	侵 華	侵 越	侵 奪	侵 蝕	侵 擾	
侵 權	侵 權 人	侵 權 糾 紛	侵 襲	侯 孝 賢	侯 炳 瑩	侯 馬	侯 鳥	
侯 湘 婷	侯 選 人	侯 爵	便 了	便 士	便 中	便 卡	便 可	
便 民	便 民 服 務	便 有	便 池	便 而	便 血	便 衣	便 衣 警 察	
便 利	便 利 設 施	便 利 超 商	便 床	便 把 令 來 行	便 車	便 使	便 函	
便 宜	便 宜 行 事	便 宜 從 事	便 宜 貨	便 所	便 於	便 於 工 作	便 於 解 決	
便 於 管 理	便 服	便 狀	便 門	便 後	便 是	便 盆	便 宴	
便 秘	便 能	便 將	便 得	便 從	便 捷	便 桶	便 條	
便 條 紙	便 被	便 壺	便 帽	便 菜	便 飯	便 會	便 溺	
便 當	便 裝	便 道	便 箋	便 與	便 鞋	便 器	便 橋	
便 褲	便 餐	便 餞	便 攜	便 攜 式	便 攜 機	便 覽	俠 士	
俠 女	俠 客	俠 氣	俠 送	俠 骨	俠 盜	俠 義	俏 皮	
俏 皮 話	俏 似	俏 步	俏 俊	俏 麗	保 □	保 人	保 不 住	
保 加 利 亞	保 本	保 用	保 田	保 甲	保 全	保 全 工	保 全 面 子	
保 全 業	保 存	保 存 性	保 存 物	保 存 者	保 存 期	保 存 實 力	保 守	
保 守 主 義	保 守 性	保 守 派	保 守 機 密	保 守 黨	保 守 黨 人	保 安	保 安 族	
保 安 隊	保 收	保 有	保 住	保 佑	保 利	保 育	保 育 員	
保 育 院	保 育 器	保 良	保 身	保 姆	保 定	保 官	保 底	
保 長	保 亭	保 持	保 持 一 致	保 持 性	保 持 者	保 持 原 狀	保 持 清 潔	
保 持 穩 定	保 持 警 惕	保 皇	保 皇 黨	保 苗	保 重	保 重 身 體	保 值	
保 值 儲 蓄	保 修	保 修 期	保 家 衛 國	保 留	保 留 版 權	保 留 物	保 留 權	
保 真	保 送	保 健	保 健 活 動	保 健 食 品	保 健 員	保 健 站	保 健 操	
保 國 安 民	保 密	保 密 性	保 康	保 教	保 票	保 單	保 殘 守 缺	
保 稅	保 稅 制	保 稅 區	保 費	保 費 調 整	保 量	保 暖	保 業	
保 溫	保 溫 杯	保 溫 瓶	保 誠 人 壽	保 靖	保 管	保 管 人	保 管 員	
保 管 處	保 障	保 障 人	保 障 機 制	保 價	保 價 函 件	保 德	保 潔	
保 熱	保 衛	保 衛 工 作	保 衛 和 平	保 衛 科	保 衛 祖 國	保 衛 戰	保 質	
保 質 保 量	保 養	保 養 品	保 養 費	保 駕	保 險	保 險 人	保 險 公 司	
保 險 金	保 險 套	保 險 商	保 險 理 賠	保 險 單	保 險 期	保 險 期 限	保 險 絲	
保 險 費	保 險 業	保 險 業 者	保 險 業 務	保 險 槓	保 險 箱	保 險 櫃	保 舉	
保 鮮	保 鮮 劑	保 藏	保 薦	保 薦 書	保 羅	保 證	保 證 人	
保 證 供 給	保 證 供 應	保 證 金	保 證 書	保 證 需 要	保 證 質 量	保 鏢	保 麗 龍	
保 釋	保 釋 人	保 釋 者	保 釋 金	保 齡	保 齡 球	保 齡 球 館	保 護	
保 護 人	保 護 主 義	保 護 色	保 護 金	保 護 區	保 護 國	保 護 傘	保 護 視 力	
保 護 裝 置	保 護 網	保 護 層	保 鑣	促 生 產	促 成	促 使	促 其	
促 動	促 產	促 發	促 進	促 進 生 產	促 進 作 用	促 進 改 革	促 進 性	
促 進 者	促 進 派	促 進 產 業 升 級 條 例	促 進 會	促 進 劑	促 熟	促 膝	促 膝 談 心	
促 請	促 銷	俘 虜	俘 虜 政 策	俘 管 工 作	俘 營	俘 獲	俟 河 之 清	
俊 秀	俊 俏	俊 美	俊 馬	俊 爽	俊 傑	俊 逸	俊 雅	
俗 人	俗 不 可 耐	俗 不 堪 耐	俗 心	俗 世	俗 用	俗 名	俗 事	
俗 例	俗 定	俗 尚	俗 念	俗 性	俗 物	俗 套	俗 家	
俗 氣	俗 義	俗 話	俗 話 說	俗 態	俗 稱	俗 語	俗 劇	
俗 緣	俗 論	俗 諺	俗 麗	俗 體	俗 艷	侮 辱	侮 辱 性	
侮 蔑	俐 牙 俐 齒	俐 齒 伶 牙	俄 文	俄 亥 俄	俄 亥 俄 州	俄 而	俄 勒 岡	
俄 國	俄 國 人	俄 頃	俄 裔	俄 語	俄 羅 斯	俄 羅 斯 人	俚 言	
俚 俗	俚 語	俚 諺	侷 促	侷 促 不 安	冒 了	冒 天 下 之 大 不 韙	冒 火	
冒 充	冒 充 者	冒 充 貨	冒 出	冒 失	冒 失 鬼	冒 犯	冒 犯 者	
冒 用	冒 名	冒 名 頂 替	冒 尖	冒 汗	冒 泡	冒 雨	冒 冒	
冒 冒 失 失	冒 昧	冒 風 雨	冒 風 險	冒 氣	冒 起	冒 頂	冒 然	
冒 牌	冒 牌 者	冒 牌 貨	冒 著	冒 著 煙	冒 進	冒 煙	冒 號	
冒 稱	冒 認	冒 領	冒 險	冒 險 干	冒 險 性	冒 險 家	冒 險 跳	
冒 頭	冠 心 病	冠 以	冠 亞 軍	冠 狀	冠 狀 動 脈	冠 軍	冠 軍 杯	
冠 軍 賽	冠 冕	冠 冕 堂 皇	冠 冕 堂 煌	冠 帶	冠 詞	冠 塚	冠 蓋 如 雲	
冠 蓋 相 望	冠 蓋 相 屬	冠 履 倒 易	冠 履 倒 置	冠 德 建 設	冠 縣	剎 住	剎 車	
剎 那	剎 那 間	剎 時	剃 刀	剃 光	剃 度	剃 胡 刀	剃 掉	
剃 發	剃 著	剃 頭	剃 鬚	剃 鬚 刀	削 下	削 方 為 圓	削 木 為 吏	
削 水	削 去	削 平	削 打	削 皮	削 皮 器	削 尖	削 成	
削 角	削 足 適 履	削 刮	削 面	削 弱	削 除	削 除 者	削 掉	
削 球	削 趾 適 屨	削 減	削 價	削 髮	削 整	削 磨	削 擊	
削 薄	削 薄 片	削 職	削 鐵 如 泥	削 觚 為 圓	前 一	前 一 年	前 一 刻	
前 一 段	前 一 段 時 間	前 人	前 人 栽 樹 後 任 乘 涼	前 三 名	前 夕	前 不 久	前 仆 後 起	
前 仆 後 繼	前 仇	前 天	前 夫	前 文	前 方	前 日	前 月	
前 片	前 世	前 代	前 功	前 功 盡 棄	前 功 盡 滅	前 半 部	前 半 場	
前 去	前 史	前 台	前 生	前 件	前 任	前 任 者	前 仰 後 合	
前 兆	前 列	前 列 腺	前 同	前 因	前 因 後 果	前 年	前 有	
前 次	前 行	前 作	前 言	前 言 不 搭 後 語	前 走	前 足	前 身	
前 車	前 車 之 鑒	前 車 可 鑒	前 事	前 事 不 忘 後 事 之 師	前 些	前 些 天	前 些 年	
前 些 時 候	前 例	前 來	前 兒	前 呼	前 呼 後 仰	前 呼 後 偃	前 呼 後 擁	
前 坡	前 夜	前 妻	前 委	前 屈	前 岸	前 往	前 怕 狼	
前 怕 狼 後 怕 虎	前 房	前 所	前 所 未 有	前 所 未 聞	前 松 後 緊	前 沿	前 者	
前 肢	前 門	前 門 拒 虎 後 門 進 狼	前 前 後 後	前 奏	前 奏 曲	前 度 劉 郎	前 後	
前 後 左 右	前 後 矛 盾	前 思 後 想	前 政 府	前 柱 式	前 段 時 間	前 看	前 科	
前 科 犯	前 茅	前 赴 後 繼	前 述	前 面	前 首 相	前 倒	前 倨 後 卑	
前 倨 後 恭	前 哨	前 哨 陣 地	前 哨 戰	前 庭	前 桅	前 殉 後 繼	前 站	
前 胸	前 院	前 堂	前 推	前 排	前 旋 肌	前 晚	前 條	
前 清 後 欠	前 處	前 途	前 途 無 量	前 途 廣 闊	前 部	前 場	前 寒	
前 幾 天	前 幾 年	前 提	前 提 下	前 景	前 期	前 款	前 無	
前 無 古 人	前 程	前 程 萬 里	前 跑	前 軸	前 進	前 項	前 傾	
前 嫌	前 意 識	前 置	前 置 詞	前 腳	前 腦	前 塵	前 塵 影 事	
前 歌 後 舞	前 滾 翻	前 端	前 緊 後 松	前 綴	前 腿	前 舞 台	前 層	
前 敵	前 線	前 衛	前 衛 戰	前 輩	前 輪	前 遮 後 擁	前 鋒	
前 齒	前 導	前 橋	前 燈	前 蹄	前 頭	前 總 理	前 總 統	
前 臂	前 瞻	前 瞻 性	前 轉	前 鎮 區	前 額	前 題	前 邊	
前 驅	前 驅 性	前 灘	前 廳	剌 破	剋 扣	剋 星	則 以	
則 由	則 在	則 有	則 否	則 怎	則 指	則 是	則 為	
則 從	則 廢	則 應	勇 士	勇 士 隊	勇 夫 悍 卒	勇 斗 歹 徒	勇 而 無 謀	
勇 男 蠢 婦	勇 往	勇 往 直 前	勇 於	勇 武	勇 者	勇 冠 三 軍	勇 挑	
勇 挑 重 擔	勇 為	勇 氣	勇 退	勇 退 激 流	勇 動 多 怨	勇 猛	勇 猛 果 敢	
勇 猛 直 前	勇 猛 精 進	勇 敢	勇 奪	勉 力	勉 勉 強 強	勉 為 其 難	勉 強	
勉 強 能	勉 從	勉 勵	勃 利	勃 勃	勃 勃 生 機	勃 起	勃 然	
勃 然 大 怒	勃 發	勁 力	勁 打	勁 地	勁 兒	勁 拉	勁 松	
勁 直	勁 風	勁 旅	勁 草	勁 骨 豐 肌	勁 敵	勁 頭	匍 匐	
匍 匐 之 救	南 丁 格 爾	南 人	南 下	南 山	南 山 人 壽	南 山 可 移	南 山 隱 約	
南 川	南 化	南 太 平 洋	南 方	南 方 人	南 方 朔	南 充	南 北	
南 北 方	南 北 極	南 北 管	南 北 戰 爭	南 北 議 和	南 半 球	南 卡 州	南 卡 羅 萊 納 州	
南 市	南 瓜	南 瓜 子	南 向	南 回 線	南 州 冠 冕	南 至	南 行	
南 宋	南 投	南 投 縣	南 沙	南 沙 群 島	南 巡	南 阮 北 阮	南 亞	
南 亞 科	南 亞 科 技	南 亞 塑 膠	南 京	南 京 市	南 來	南 坪	南 岸	
南 征	南 征 北 伐	南 征 北 討	南 征 北 戰	南 昌	南 昌 市	南 昌 起 義	南 泥 灣	
南 門	南 非	南 非 洲	南 南 合 作	南 城	南 帝	南 帝 化 工	南 柯 一 夢	
南 段	南 洋	南 洋 杉	南 洋 染 整	南 科	南 美	南 美 洲	南 美 鷹	
南 苑	南 軍	南 郊	南 面	南 面 百 城	南 風	南 風 不 競	南 宮	
南 島	南 浦	南 海	南 海 諸 島	南 側	南 區	南 國	南 國 風 光	
南 貨	南 通	南 部	南 部 人	南 部 非 洲	南 陵	南 斯 拉 夫	南 朝	
南 朝 鮮	南 港 輪 胎	南 湖	南 腔 北 調	南 街	南 越	南 進	南 開	
南 陽	南 匯	南 園	南 極	南 極 洲	南 極 區	南 極 圈	南 路	
南 僑 化 工	南 寧	南 寧 市	南 端	南 樓	南 歐	南 歐 人	南 緯	
南 緯 實 業	南 線	南 橘 北 枳	南 澳	南 澳 鄉	南 縣	南 轅 北 轍	南 韓	
南 韓 股 市	南 疆	南 邊	南 麓	南 鷂 北 鷹	南 蠻	南 庄	南 庄 鄉	
卻 也	卻 已	卻 不	卻 之 不 恭	卻 可	卻 向	卻 因	卻 在	
卻 有	卻 把	卻 步	卻 見	卻 其	卻 是	卻 為	卻 要	
卻 病 延 年	卻 能	卻 被	卻 給	卻 像	卻 說	厚 了	厚 今 薄 古	
厚 片	厚 古 薄 今	厚 外 套	厚 生	厚 生 公 司	厚 皮	厚 此	厚 此 薄 彼	
厚 舌	厚 利	厚 角	厚 味	厚 味 臘 毒	厚 底	厚 板	厚 的	
厚 厚	厚 度	厚 待	厚 恩	厚 紙	厚 望	厚 絨 布	厚 著	
厚 著 臉 皮	厚 意	厚 愛	厚 祿	厚 祿 高 官	厚 葬	厚 運	厚 道	
厚 達	厚 實	厚 漆	厚 貌 深 情	厚 德 載 物	厚 德 載 福	厚 賜	厚 斂	
厚 臉	厚 臉 皮	厚 薄	厚 禮	厚 顏	厚 顏 無 恥	厚 邊	叛 民	
叛 者	叛 軍	叛 匪	叛 徒	叛 逆	叛 逆 者	叛 逆 罪	叛 逃	
叛 國	叛 將	叛 教	叛 教 者	叛 亂	叛 亂 者	叛 意	叛 賣	
叛 離	叛 黨	叛 黨 者	叛 變	咬 一 口	咬 了	咬 人	咬 下	
咬 文	咬 文 嚼 字	咬 牙	咬 牙 切 齒	咬 合	咬 字	咬 住	咬 定	
咬 咬 牙	咬 釘 嚼 鐵	咬 得 菜 根	咬 掉	咬 著	咬 傷	咬 碎	咬 緊	
咬 斷	咬 嚼	哀 叫	哀 吊	哀 而 不 傷	哀 兵 必 勝	哀 告	哀 求	
哀 呼	哀 泣	哀 哉	哀 思	哀 怨	哀 苦	哀 哭	哀 婉	
哀 惜	哀 悼	哀 啟	哀 梨 蒸 食	哀 祭	哀 莫 大 於 心 死	哀 啼	哀 喚	
哀 痛	哀 絲 豪 竹	哀 訴	哀 傷	哀 感 頑 艷	哀 愁	哀 毀 骨 立	哀 號	
哀 詩	哀 慟	哀 歌	哀 鳴	哀 憐	哀 樂	哀 歎	哀 嚎	
哀 懇	哀 聲	哀 鴻 遍 地	哀 鴻 遍 野	哀 辭	哀 勸	咨 文	咨 詢	
咨 詢 中 心	咨 詢 委 員 會	咨 詢 服 務	咨 詢 機 構	哎 呀	哎 唷	哎 喲	哎 呦	
咸 宜	咸 陽	咸 豐	咳 出	咳 出 物	咳 血	咳 得	咳 唾 成 珠	
咳 痰	咳 嗽	咳 聲	咳 藥	哇 叫	哇 哇	哇 哇 叫	哇 哇 哭	
哇 啦	哇 塞	哇 語	哇 聲	咽 炎	咽 喉	咽 喉 炎	咽 腫	
咽 頭 炎	咪 叫	咪 咪	品 月	品 目	品 名	品 竹 彈 絲	品 竹 調 弦	
品 竹 調 絲	品 行	品 位	品 系	品 佳 公 司	品 味	品 定	品 性	
品 花	品 紅	品 紅 色	品 家	品 格	品 級	品 茶	品 茗	
品 酒	品 晤	品 脫	品 牌	品 牌 包 裝	品 等	品 評	品 夢	
品 種	品 管	品 貌	品 德	品 德 高 尚	品 德 教 育	品 質	品 質 超 群	
品 質 管 制	品 學	品 學 兼 憂	品 學 兼 優	品 頭 論 足	品 頭 題 足	品 嚐	品 檢	
品 糧	品 類	哄 人	哄 弄	哄 抬	哄 抬 物 價	哄 哄	哄 笑	
哄 動	哄 堂	哄 堂 大 笑	哄 然	哄 然 大 笑	哄 傳	哄 搶	哄 誘	
哄 騙	哄 勸	哈 巴	哈 欠	哈 瓦 那	哈 佛	哈 佛 大 學	哈 吧 狗	
哈 姆 雷 特	哈 哈	哈 哈 大 笑	哈 氣	哈 密	哈 密 瓜	哈 腰	哈 達	
哈 爾 濱	哈 爾 濱 市	哈 蜜 瓜	哈 德 威	哈 薩 克	哈 羅	咯 叫	咯 血	
咯 吱	咯 吱 聲	咯 兒	咯 肢	咯 咯	咯 咯 聲	咯 笑	咯 聲	
咫 尺	咫 尺 千 里	咫 尺 天 涯	咫 尺 萬 里	咫 角 驂 駒	咱 村	咱 娃	咱 倆	
咱 們	咱 家	咱 得	咱 這	咱 就	咱 爺	咻 聲	咩 咩	
咧 著	咧 開	咧 嘴	咿 呀	咿 咿	囿 於	囿 於 成 見	垂 下	
垂 心	垂 手	垂 手 而 得	垂 片	垂 布	垂 危	垂 曲 線	垂 死	
垂 死 掙 扎	垂 老	垂 耳	垂 肉	垂 肌	垂 足	垂 直	垂 直 平 分 線	
垂 直 性	垂 直 面	垂 直 線	垂 青	垂 度	垂 拱 而 治	垂 柳	垂 涎	
垂 涎 三 尺	垂 涎 欲 摘	垂 涎 欲 滴	垂 部	垂 釣	垂 就	垂 裕 後 昆	垂 詢	
垂 幕	垂 暮	垂 暮 之 年	垂 線	垂 頭 喪 氣	垂 頭 縮 肩	垂 頭 彎 腰	垂 簾	
垂 簾 聽 政	垂 顧	垂 體	型 式	型 材	型 車	型 板	型 砂	
型 款	型 號	型 鋼	垢 污	垢 物	垢 面	垢 閡	城 人	
城 下	城 下 之 盟	城 口	城 中	城 內	城 主	城 北 徐 公	城 外	
城 市	城 市 化	城 市 居 民	城 市 間	城 市 學	城 池	城 西	城 形	
城 步	城 邦	城 防	城 固	城 府	城 弧	城 河	城 狐 社 鼠	
城 門	城 門 失 火	城 門 失 火 殃 及 池 魚	城 南	城 垣	城 建	城 建 局	城 郊	
城 根	城 區	城 郭	城 堡	城 廂	城 鄉	城 隍	城 裡	
城 裡 人	城 運 會	城 廓	城 樓	城 壁	城 頭	城 壕	城 牆	
城 牆 外	城 壘	城 鎮	城 關	城 關 鎮	城 體	垮 了	垮 台	
垮 掉	奕 奕	契 人	契 丹	契 友	契 文	契 合 金 蘭	契 東	
契 約	契 約 者	契 若 金 蘭	契 紙	契 稅	契 據	契 機	契 證	
奏 出	奏 功	奏 本	奏 曲	奏 折	奏 明	奏 者	奏 表	
奏 效	奏 書	奏 捷	奏 疏	奏 章	奏 凱	奏 鳴	奏 鳴 曲	
奏 樂	奏 議	奏 響	奎 寧	姜 太 公 釣 魚	姜 味	姜 粉	姜 絲	
姜 黃	姘 夫	姘 居	姘 婦	姘 頭	姿 色	姿 容	姿 勢	
姿 態	姣 生 貫 養	姣 好	姣 美	姨 丈	姨 子	姨 夫	姨 太	
姨 太 太	姨 父	姨 母	姨 兒	姨 姐	姨 表	姨 娘	姨 婆	
姨 媽	娃 子	娃 兒	娃 娃	娃 娃 車	娃 臉	姥 姥	姥 爺	
姚 黃 魏 紫	姚 黛 瑋	姦 污	姦 情	姦 殺	姦 淫	威 力	威 士 忌	
威 士 忌 酒	威 化	威 尼 斯	威 名	威 而 不 猛	威 而 鋼	威 呵	威 服	
威 武	威 武 不 屈	威 法	威 肯 斯	威 虎	威 金 斯	威 信	威 信 掃 地	
威 致 鋼 鐵	威 迫	威 迫 利 誘	威 風	威 風 一 羽	威 風 掃 地	威 風 祥 麟	威 風 凜 凜	
威 振 天 下	威 海	威 脅	威 脅 利 誘	威 脅 性	威 脅 要	威 望	威 猛	
威 盛	威 盛 電 子	威 尊 命 賤	威 斯 伍 德	威 斯 康 辛	威 視	威 勢	威 廉	
威 逼	威 逼 利 誘	威 爾 史 密 斯	威 爾 森	威 福 由 己	威 福 自 己	威 赫	威 遠	
威 儀	威 儀 孔 時	威 震	威 震 天 下	威 嚇	威 嚇 性	威 嚇 者	威 壓	
威 嚴	威 懾	威 懾 力 量	威 懾 理 論	威 權	姻 緣	姻 親	孩 子	
孩 子 似	孩 子 們	孩 子 氣	孩 子 頭	孩 似	孩 兒	孩 提	孩 童	
孩 童 們	宣 化	宣 召	宣 示	宣 州	宣 佈	宣 判	宣 告	
宣 告 者	宣 言	宣 言 者	宣 武	宣 洩	宣 紙	宣 得	宣 教	
宣 統	宣 揚	宣 揚 者	宣 傳	宣 傳 工 作	宣 傳 月	宣 傳 周	宣 傳 性	
宣 傳 者	宣 傳 品	宣 傳 科	宣 傳 員	宣 傳 教 育	宣 傳 部	宣 傳 部 長	宣 傳 報 道	
宣 傳 提 綱	宣 傳 畫	宣 傳 隊	宣 稱	宣 誓	宣 誓 書	宣 誓 就 職	宣 戰	
宣 講	宣 讀	宦 官	宦 海	宦 途	宦 鄉	室 中	室 內	
室 內 休 閒	室 內 樂	室 友	室 主 任	室 外	室 名	室 如 懸 磐	室 如 懸 罄	
室 前	室 怒 市 色	室 員	室 溫	室 裡	室 樂	室 邇 人 遐	室 邇 人 遠	
室 廳	客 人	客 上	客 戶	客 地	客 死	客 串	客 位	
客 車	客 車 廂	客 來	客 官	客 居	客 店	客 性	客 房	
客 物	客 舍	客 客 氣 氣	客 流	客 流 量	客 卿	客 員	客 套	
客 套 話	客 家	客 座	客 氣	客 站	客 商	客 堂	客 票	
客 船	客 貨	客 棧	客 隊	客 飯	客 歲	客 運	客 運 量	
客 運 碼 頭	客 滿	客 駁	客 輪	客 機	客 艙	客 幫	客 籍	
客 囊 羞 澀	客 體	客 廳	客 觀	客 觀 化	客 觀 主 義	客 觀 存 在	客 觀 事 實	
客 觀 性	客 觀 原 因	客 觀 真 理	客 觀 唯 心 主 義	客 觀 情 況	客 觀 條 件	客 觀 規 律	客 觀 實 在	
封 一	封 二	封 入	封 上	封 口	封 口 蠟	封 山	封 山 育 林	
封 火	封 皮	封 印	封 地	封 存	封 死	封 臣	封 住	
封 牢	封 豕 長 蛇	封 函	封 妻 陰 子	封 妻 蔭 子	封 官	封 官 許 願	封 底	
封 泥	封 河	封 門	封 信	封 侯	封 封	封 建	封 建 主	
封 建 主 義	封 建 制 度	封 建 性	封 建 社 會	封 為	封 胡 遏 末	封 胡 羯 末	封 面	
封 候	封 凍	封 套	封 神	封 帳	封 條	封 殺	封 袋	
封 閉	封 閉 式	封 閉 型	封 閉 器	封 頂	封 喉	封 港	封 開	
封 號	封 裝	封 裡	封 奪	封 網	封 蓋	封 緘	封 賞	
封 艙	封 爵	封 鎖	封 鎖 線	封 疆	封 簽	封 贈	封 蠟	
屎 尿	屏 住	屏 東	屏 門	屏 風	屏 息	屏 氣	屏 隔	
屏 幕	屏 幕 提 示	屏 障	屏 蔽	屏 縣	屏 邊	屍 布	屍 衣	
屍 身	屍 首	屍 骨	屍 骨 未 寒	屍 斑	屍 魂	屍 橫 遍 野	屍 骸	
屍 體	屋 下 架 屋	屋 下 蓋 屋	屋 上 建 瓴	屋 子	屋 內	屋 主	屋 外	
屋 宇	屋 角	屋 舍	屋 門	屋 前	屋 後	屋 架	屋 面	
屋 烏 推 愛	屋 脊	屋 基	屋 頂	屋 頂 板	屋 頂 室	屋 裡	屋 樑	
屋 頭	屋 簷	屋 町	峙 立	巷 口	巷 子	巷 尾	巷 尾 街 頭	
巷 裡	巷 道	巷 戰	巷 議 街 談	帝 力	帝 王	帝 王 般	帝 王 將 相	
帝 名	帝 位	帝 君	帝 汶	帝 制	帝 政	帝 皇	帝 國	
帝 國 主 義	帝 國 主 義 者	帝 都	帝 業	帝 廟	帝 權	帥 才	帥 印	
帥 呆 了	帥 哥	帥 氣	帥 權	幽 女	幽 囚 受 辱	幽 谷	幽 居	
幽 明	幽 明 異 路	幽 門	幽 室	幽 幽	幽 思	幽 怨	幽 美	
幽 香	幽 冥	幽 浮	幽 婉	幽 寂	幽 情	幽 深	幽 閉	
幽 期 密 約	幽 閒	幽 雅	幽 微	幽 暗	幽 會	幽 禁	幽 魂	
幽 靜	幽 默	幽 默 家	幽 默 畫	幽 默 感	幽 默 滑 稽	幽 默 話	幽 蘭	
幽 靈	幽 靈 似	度 尺	度 日	度 日 如 年	度 日 如 歲	度 外	度 表	
度 夏	度 假	度 假 者	度 量	度 量 大	度 量 衡	度 過	度 過 難 關	
度 蜜 月	度 德 量 力	度 數	建 下	建 大 工 業	建 子	建 工	建 中	
建 戶	建 水	建 功	建 功 立 事	建 功 立 業	建 台 水 泥	建 弘 投 信	建 弘 證 券	
建 立	建 立 者	建 立 健 全	建 交	建 同 一 氣	建 同 作 弊	建 好	建 安	
建 成	建 成 投 產	建 有	建 兵	建 材	建 材 工 業	建 制	建 委	
建 始	建 房	建 所	建 於	建 初	建 省	建 軍	建 軍 節	
建 校	建 站	建 起	建 院	建 國	建 國 工 程	建 國 方 針	建 國 以 來	
建 國 黨	建 帳	建 康	建 設	建 設 中	建 設 公 司	建 設 公 債	建 設 性	
建 設 者	建 設 部	建 設 銀 行	建 設 廳	建 通 精 密	建 造	建 造 者	建 都	
建 陽	建 準 電 機	建 置	建 寧	建 榮 工 業	建 構	建 廠	建 德	
建 模	建 樹	建 橋	建 甌	建 築	建 築 上	建 築 材 料	建 築 法 令	
建 築 物	建 築 者	建 築 面 積	建 築 師	建 築 術	建 築 設 計	建 築 隊	建 築 業	
建 築 群	建 築 模 型	建 築 學	建 築 藝 術	建 館	建 檔	建 議	建 議 者	
建 議 書	建 黨	建 黨 思 想	建 瓴 高 屋	建 ��	弭 撒	彥 武 企 業	很 下	
很 上	很 久	很 大	很 小	很 不	很 內 向	很 少	很 少 數	
很 可	很 可 怕	很 可 能	很 外 向	很 多	很 多 人	很 好	很 忙	
很 早	很 老	很 低	很 冷	很 快	很 沉	很 受	很 近	
很 長	很 非 常	很 厚	很 帥	很 挑 剔	很 是	很 為	很 美	
很 苦	很 重	很 香	很 值 得	很 容 易	很 差	很 破	很 窄	
很 脆	很 能	很 高	很 高 興	很 強	很 晚	很 涼	很 淺	
很 深	很 甜	很 累	很 規 矩	很 野	很 富	很 悶	很 痛 快	
很 短	很 順 從	很 感	很 感 興 趣	很 想	很 暗	很 會	很 滑	
很 飽	很 像	很 對	很 慢	很 緊	很 輕	很 遠	很 廣	
很 熱	很 窮	很 衛 生	很 複 雜	很 懊 悔	很 橫	很 遲	很 靜	
很 糟	很 薄	很 壞	很 難	很 難 說	很 嚴	很 響	很 髒	
待 人	待 人 刻 薄	待 人 接 物	待 人 處 事	待 工	待 己	待 之 如 友	待 月 西 廂	
待 用	待 印	待 在	待 扣	待 收	待 考	待 批	待 決	
待 沖	待 到	待 制	待 命	待 命 狀 態	待 定	待 征	待 承	
待 放	待 物	待 客	待 挑	待 修	待 哺	待 員	待 時 守 分	
待 時 而 動	待 時 而 舉	待 送	待 退	待 售	待 產	待 發	待 發 箱	
待 雇	待 會	待 會 兒	待 業	待 業 青 年	待 業 保 險	待 聘	待 補	
待 解	待 遇	待 遇 好	待 說	待 領	待 價 而 沽	待 價 藏 珠	待 審	
待 銷	待 機	待 機 而 動	待 辦	待 優	待 斃	待 繳	待 證	
待 續	待 攤	律 己	律 令	律 性	律 的	律 師	律 師 事 務 所	
律 師 制 度	律 詩	律 論	徇 公 忘 己	徇 公 滅 私	徇 私	徇 私 作 弊	徇 私 舞 弊	
徇 私 廢 公	徇 國 亡 家	徇 國 忘 身	徇 情	徇 情 枉 法	後 一 段	後 人	後 入	
後 又	後 已	後 才	後 不 為 例	後 之	後 仍	後 勾 拳	後 天	
後 天 性	後 手	後 手 不 接	後 文	後 方	後 方 防 衛	後 方 補 給	後 日	
後 世	後 主	後 以	後 付	後 代	後 冬	後 加	後 半	
後 半 生	後 半 夜	後 半 部	後 半 場	後 半 期	後 召	後 台	後 台 老 闆	
後 母	後 生	後 生 小 子	後 生 可 畏	後 生 晚 學	後 用	後 甲 板	後 任	
後 仰	後 仰 前 合	後 再	後 列	後 合 前 仰	後 年	後 成	後 行	
後 即	後 坐	後 序	後 沖	後 沒	後 身	後 車 之 戒	後 事	
後 來	後 來 之 秀	後 來 居 上	後 來 者 居 上	後 屈	後 延	後 怕	後 房	
後 明	後 果	後 果 自 負	後 果 前 因	後 的	後 空 翻	後 者	後 肢	
後 門	後 勁	後 奏 曲	後 屋	後 巷	後 巷 前 街	後 查	後 段	
後 為	後 盾	後 背	後 述	後 面	後 唐	後 娘	後 宮	
後 座	後 恭 前 倨	後 悔	後 悔 不 及	後 悔 不 該	後 悔 何 及	後 悔 莫 及	後 悔 無 及	
後 悔 藥	後 效	後 浪	後 浪 崔 前 浪	後 浪 推 前 浪	後 爹	後 胸	後 能	
後 記	後 起	後 起 之 秀	後 退	後 逃	後 院	後 圈	後 婚	
後 患	後 患 無 窮	後 掠 角	後 接	後 推	後 排	後 梁	後 被	
後 設	後 部	後 備	後 備 軍	後 備 幹 部	後 援	後 景	後 期	
後 港	後 發 制 人	後 窗	後 街	後 視	後 視 圖	後 視 鏡	後 軸	
後 進	後 進 變 先 進	後 項	後 傾	後 勤	後 勤 工 作	後 勤 史	後 勤 技 術	
後 勤 法 規	後 勤 保 障	後 勤 建 設	後 勤 思 想	後 勤 理 論	後 勤 部	後 勤 裝 備	後 勤 管 理	
後 勤 學	後 勤 體 制	後 勢 看 俏	後 嗣	後 媽	後 想	後 會 可 期	後 會 有 期	
後 會 難 期	後 殿	後 置	後 置 詞	後 腳	後 腦	後 腦 勺	後 葉	
後 蜀	後 裔	後 補	後 補 者	後 跟	後 路	後 塵	後 實 先 聲	
後 撤	後 漢	後 漢 書	後 滯	後 福	後 端	後 綴	後 腿	
後 語	後 影	後 膛	後 衛	後 輩	後 輪	後 壁	後 學	
後 擁	後 擁 前 呼	後 擁 前 遮	後 擁 前 驅	後 橋	後 燈	後 艙	後 選	
後 遺	後 遺 症	後 頭	後 龍	後 擺	後 轉	後 邊	後 類	
後 繼	後 繼 乏 人	後 繼 有 人	後 繼 者	後 繼 無 人	後 續	後 顧	後 顧 之 患	
後 顧 之 虞	後 顧 之 慮	後 顧 之 憂	後 變	後 廳	怒 不 可 遏	怒 火	怒 火 中 燒	
怒 火 沖 天	怒 斥	怒 目	怒 目 切 齒	怒 目 而 視	怒 目 橫 眉	怒 江	怒 色	
怒 吠	怒 吼	怒 形	怒 形 於 色	怒 沖 沖	怒 放	怒 容	怒 氣	
怒 氣 沖 天	怒 氣 沖 沖	怒 氣 沖 霄	怒 族	怒 喊	怒 喝	怒 發	怒 發 衝 冠	
怒 視	怒 意	怒 號	怒 毆	怒 毆 者	怒 潮	怒 罵	怒 嚇	
怒 濤	怒 臂 當 車	怒 臂 當 轍	思 凡	思 不 出 位	思 古	思 如 泉 湧	思 如 湧 泉	
思 忖	思 考	思 考 者	思 考 題	思 而 後 行	思 念	思 前	思 前 想 後	
思 前 算 後	思 春	思 春 期	思 是	思 科	思 若 泉 湧	思 若 湧 泉	思 冥	
思 時	思 索	思 索 性	思 索 者	思 甜	思 鄉	思 鄉 病	思 量	
思 亂	思 想	思 想 上	思 想 方 法	思 想 史	思 想 性	思 想 家	思 想 庫	
思 愁	思 源	思 源 科 技	思 義	思 路	思 過 半 矣	思 維	思 維 方 式	
思 維 科 學	思 維 能 力	思 緒	思 緒 萬 千	思 慮	思 慕	思 潮	思 熟	
思 賢 如 渴	思 遷	思 戰	思 親	思 謀	思 錄	思 歸	思 議	
思 辯	思 戀	思 變	怠 工	怠 忽	怠 惰	怠 慢	怠 墮	
急 了	急 人	急 人 之 困	急 人 之 難	急 人 所 急	急 下 降	急 不 可 待	急 不 可 耐	
急 不 擇 言	急 中	急 中 生 智	急 公 好 義	急 切	急 升	急 火	急 功 近 名	
急 功 近 利	急 匆 匆	急 用	急 件	急 先 鋒	急 如 星 火	急 如 風 火	急 忙	
急 死	急 竹 繁 絲	急 行	急 行 軍	急 呀	急 扯	急 抓	急 步	
急 走	急 事	急 來 抱 佛 腳	急 奔	急 征 重 斂	急 性	急 性 子	急 性 病	
急 性 傳 染 病	急 拉	急 抽	急 拍	急 於	急 於 求 成	急 於 想	急 的	
急 促	急 剎 車	急 待	急 急 如 律 令	急 急 忙 忙	急 流	急 流 勇 退	急 流 勇 進	
急 流 險 灘	急 派	急 要	急 迫	急 降	急 風	急 風 暴 雨	急 飛	
急 修	急 射	急 座	急 病	急 症	急 脈 緩 受	急 起 直 追	急 送	
急 退	急 務	急 得	急 救	急 救 中 心	急 救 員	急 救 站	急 眼	
急 速	急 造	急 報	急 景 流 年	急 景 凋 年	急 發	急 著	急 診	
急 診 室	急 跑	急 進	急 煞	急 聘	急 電	急 馳	急 管 繁 弦	
急 聚	急 語	急 趕	急 需	急 需 品	急 需 處 理	急 需 解 決	急 劇	
急 劇 下 降	急 衝	急 遽	急 轉	急 轉 直 下	急 轉 彎	急 壞	急 難 救 護	
急 躁	急 彎	急 變	急 讓	急 驟	急 茬	怎 了	怎 不	
怎 地	怎 好 意 思	怎 奈	怎 的	怎 知	怎 肯	怎 個	怎 能	
怎 啦	怎 就	怎 敢	怎 敢 不 低 頭	怎 會	怎 說	怎 麼	怎 麼 了	
怎 麼 回 事	怎 麼 著	怎 麼 樣	怎 麼 辦	怎 樣	怎 辦	怨 入 骨 髓	怨 女	
怨 女 曠 夫	怨 不 得	怨 天 尤 人	怨 天 怨 地	怨 艾	怨 言	怨 恨	怨 氣	
怨 氣 沖 天	怨 鬼	怨 偶	怨 報	怨 憤	怨 歎	怨 聲	怨 聲 盈 路	
怨 聲 載 路	怨 聲 載 道	怨 聲 滿 道	恍 如 隔 世	恍 忽	恍 恍 忽 忽	恍 恍 惚 惚	恍 若	
恍 惚	恍 惚 迷 離	恍 然	恍 然 大 悟	恰 切	恰 巧	恰 在 此 時	恰 好	
恰 好 相 反	恰 如	恰 如 其 分	恰 似	恰 克 與 飛 鳥	恰 到	恰 到 好 處	恰 恰	
恰 恰 相 反	恰 值	恰 逢	恰 當	恨 人	恨 入 心 髓	恨 入 骨 髓	恨 不	
恨 不 能	恨 不 得	恨 之	恨 之 入 骨	恨 死	恨 事	恨 恨	恨 相 見 晚	
恨 相 知 晚	恨 透	恨 意	恨 鐵 不 成 鋼	恢 弘	恢 宏	恢 宏 大 度	恢 恢	
恢 復	恢 復 生 產	恢 復 名 譽	恢 復 期	恢 復 黨 籍	恢 廓 大 度	恢 諧	恆 久	
恆 心	恆 定	恆 定 性	恆 河 沙 數	恆 春	恆 星	恆 產	恆 等	
恆 等 式	恆 量	恆 溫	恆 溫 器	恆 義 食 品	恆 壓	恆 壓 器	恆 濕	
恆 濕 器	恃 才	恃 才 矜 己	恃 才 敖 物	恃 才 揚 己	恃 才 傲 物	恃 強 凌 弱	恃 強 欺 弱	
恃 勢	恬 不 知 怪	恬 不 知 恥	恬 不 為 怪	恬 不 為 意	恬 妞	恬 淡	恬 淡 卦 欲	
恬 淡 無 為	恬 淡 無 慾	恬 然	恬 靜	恫 言	恫 疑 虛 喝	恫 嚇	恪 守	
恪 守 成 式	恪 守 成 規	恪 盡 職 守	恪 遵	恤 老 憐 貧	恤 孤 念 苦	恤 孤 念 寡	恤 衫	
扁 了	扁 平	扁 平 足	扁 舟	扁 形	扁 形 蟲	扁 豆	扁 長	
扁 扁	扁 食	扁 桃	扁 桃 腺	扁 桃 腺 炎	扁 桃 體	扁 桃 體 炎	扁 骨	
扁 魚	扁 圓	扁 圓 形	扁 擔	扁 鋼	扁 頭	扁 鵲	拜 人	
拜 台	拜 年	拜 佛	拜 別	拜 把	拜 見	拜 到	拜 受	
拜 官	拜 物	拜 物 教	拜 金	拜 金 主 義	拜 城	拜 客	拜 拜	
拜 泉	拜 相 封 候	拜 倒	拜 倒 轅 門	拜 倫	拜 師	拜 神	拜 託	
拜 鬼	拜 鬼 求 神	拜 堂	拜 將 封 候	拜 掃	拜 望	拜 祭	拜 訪	
拜 揖	拜 賀	拜 會	拜 跪	拜 墓	拜 壽	拜 謁	拜 謝	
拜 讀	挖 土	挖 土 機	挖 井	挖 方	挖 出	挖 去	挖 地	
挖 地 道	挖 成	挖 耳 當 擋	挖 肉 補 瘡	挖 坑 道	挖 沙	挖 走	挖 取	
挖 泥	挖 泥 船	挖 空	挖 空 心 思	挖 挖	挖 洞	挖 苦	挖 苦 話	
挖 除	挖 剪	挖 掘	挖 掘 者	挖 掘 潛 力	挖 掘 器	挖 掘 機	挖 掉	
挖 渠	挖 開	挖 溝	挖 溝 人	挖 溝 機	挖 煤	挖 補	挖 墓	
挖 墓 者	挖 槽	挖 潛	挖 壕	挖 壕 機	挖 牆 角	挖 牆 腳	按 了	
按 人	按 人 均 計 算	按 下	按 上 級 規 定	按 戶	按 手	按 日	按 月	
按 比 例	按 打	按 甲 休 兵	按 甲 寢 兵	按 件	按 名 責 實	按 在	按 年	
按 扣	按 旬	按 次	按 此	按 住	按 兵	按 兵 不 動	按 兵 不 舉	
按 址	按 序	按 步 就 班	按 使	按 例	按 兩 次	按 其	按 季	
按 指	按 計 劃	按 倒	按 原 計 劃	按 原 樣	按 時	按 時 完 成	按 紐	
按 級	按 脈	按 動	按 國 家 有 關 規 定	按 堵 如 故	按 捺	按 捺 不 住	按 理	
按 理 說	按 規 定	按 部	按 部 就 班	按 勞 分 配	按 勞 付 酬	按 勞 取 酬	按 喇 叭	
按 揭	按 期	按 期 歸 還	按 著	按 量	按 鈕	按 照	按 鈴	
按 圖 索 駿	按 圖 索 驥	按 慣 例	按 語	按 說	按 需 分 配	按 價	按 摩	
按 摩 師	按 碼	按 質	按 質 論 價	按 噸	按 辦	按 壓	按 鍵	
按 類	按 觸	拼 了	拼 上	拼 出	拼 合	拼 字	拼 字 法	
拼 成	拼 刺	拼 板	拼 法	拼 版	拼 音	拼 音 文 字	拼 音 字 母	
拼 做	拼 接	拼 殺	拼 湊	拼 貼	拼 圖	拼 綴	拼 寫	
拼 盤	拼 錯	拼 錯 字	拼 雙	拼 讀	拭 了	拭 去	拭 目	
拭 目 以 俟	拭 目 以 待	拭 目 以 觀	拭 目 而 待	拭 目 傾 耳	拭 除	拭 淚	拭 擦	
持 人	持 人 長 短	持 刀	持 刀 弄 棒	持 刀 動 仗	持 力	持 久	持 久 力	
持 久 之 計	持 久 和 平	持 久 性	持 久 戰	持 久 穩 固	持 不	持 不 同 政 見 者	持 不 同 看 法	
持 之	持 之 以 恆	持 之 有 故	持 反 對 態 度	持 火	持 平	持 平 之 論	持 正 不 阿	
持 正 不 撓	持 矛	持 危 扶 顛	持 有	持 有 人	持 有 異 議	持 兵	持 否 定 態 度	
持 批 評 態 度	持 身	持 物	持 者	持 股	持 股 公 司	持 肯 定 態 度	持 盈 保 泰	
持 重	持 家	持 留	持 帶	持 械	持 球	持 異 議	持 祿 取 容	
持 祿 固 寵	持 祿 保 位	持 祿 養 交	持 祿 養 身	持 槍	持 滿 戒 盈	持 疑 不 決	持 疑 不 定	
持 樂 觀 態 度	持 齋 把 素	持 謹 慎 態 度	持 寵 生 驕	持 懷 疑 態 度	持 籌 握 算	持 續	持 續 力	
持 續 不 斷	持 續 性	持 續 很 久	持 續 時 間	持 續 增 長	持 續 穩 定 地 增 長	持 蠡 測 海	拮 据	
拽 了	拽 布 披 麻	拽 住	拽 拳 丟 跌	拽 耙 扶 犁	拽 著	拽 象 拖 犀	指 一 說 十	
指 人	指 山 說 磨	指 山 賣 磨	指 不 勝 屈	指 天 為 誓	指 天 畫 地	指 天 誓 心	指 天 誓 日	
指 天 說 地	指 引	指 手	指 手 畫 腳	指 手 頓 腳	指 手 劃 腳	指 手 點 腳	指 日	
指 日 可 待	指 日 成 功	指 日 而 待	指 水 盟 松	指 令	指 令 系 統	指 令 性	指 令 性 計 劃	
指 令 表	指 出	指 古 摘 今	指 斥	指 正	指 用	指 甲	指 甲 刀	
指 甲 剪	指 甲 蓋	指 示	指 示 字	指 示 物	指 示 者	指 示 牌	指 示 精 神	
指 示 劑	指 示 器	指 示 燈	指 印	指 向	指 名	指 名 道 姓	指 在	
指 尖	指 皂 為 白	指 事	指 使	指 定	指 定 者	指 明	指 東 打 西	
指 東 畫 西	指 東 話 西	指 東 說 西	指 法	指 狀 物	指 的	指 空 話 空	指 南	
指 南 打 北	指 南 針	指 指	指 指 戳 戳	指 是	指 洞	指 派	指 為	
指 時 針	指 桑	指 桑 說 槐	指 桑 罵 槐	指 破 迷 團	指 紋	指 紋 比 對	指 紋 學	
指 針	指 針 式	指 骨	指 做	指 控	指 教	指 教 員	指 望	
指 痕	指 眼 睛	指 責	指 責 者	指 鹿 作 馬	指 鹿 為 馬	指 掌 可 取	指 揮	
指 揮 中 心	指 揮 系 統	指 揮 官	指 揮 所	指 揮 者	指 揮 若 定	指 揮 員	指 揮 家	
指 揮 控 制 系 統	指 揮 部	指 揮 棒	指 揮 塔	指 揮 儀	指 揮 學 院	指 揮 機 構	指 揮 機 關	
指 揮 藝 術	指 給	指 著	指 距	指 雁 為 羹	指 瑕 造 隙	指 腸	指 腹 成 親	
指 腹 為 婚	指 腹 為 親	指 腹 割 衿	指 腹 裁 襟	指 路 明 燈	指 摘	指 稱	指 端	
指 認	指 彈	指 數	指 數 函 數	指 數 期 貨	指 標	指 豬 罵 狗	指 靠	
指 導	指 導 下	指 導 工 作	指 導 方 針	指 導 生	指 導 作 用	指 導 性 計 劃	指 導 者	
指 導 思 想	指 導 員	指 導 意 義	指 戰 員	指 親 托 故	指 錯	指 頭	指 壓	
指 環	指 縫	指 點	指 點 江 山	指 戳	指 雞 罵 狗	指 證	指 顧 之 間	
指 顧 之 際	拱 了	拱 心 石	拱 手	拱 手 而 降	拱 手 投 降	拱 手 垂 裳	拱 手 相 讓	
拱 手 聽 命	拱 月	拱 木	拱 出	拱 北	拱 立	拱 曲	拱 壯	
拱 形	拱 抱	拱 狀	拱 肩 縮 背	拱 門	拱 洞	拱 背	拱 面	
拱 起	拱 圈	拱 頂	拱 頂 石	拱 廊	拱 廊 似	拱 腰	拱 道	
拱 衛	拱 壁	拱 橋	拱 翻	拷 火	拷 打	拷 貝	拷 紗	
拷 問	拷 問 台	拷 綢	拷 盤	拷 邊	拷 邊 工	拯 危 扶 溺	拯 救	
拯 溺 扶 危	拯 溺 救 焚	括 入	括 在	括 弧	括 約 肌	括 號	括 囊 守 祿	
括 囊 拱 手	拾 人 牙 慧	拾 人 余 唾	拾 人 涕 唾	拾 人 唾 余	拾 人 唾 涕	拾 元	拾 去	
拾 到	拾 取	拾 取 者	拾 者	拾 金 不 昧	拾 音 器	拾 級	拾 荒	
拾 起	拾 得	拾 得 品	拾 零	拾 趣	拾 遺	拾 遺 補 闕	拾 掇	
拴 上	拴 在	拴 住	拴 牢	拴 著	拴 緊	拴 鎖	拴 繩	
挑 一	挑 了	挑 三 揀 四	挑 三 窩 四	挑 三 豁 四	挑 么 挑 六	挑 大 樑	挑 子	
挑 夫	挑 毛 剔 刺	挑 毛 病	挑 水	挑 牙 料 唇	挑 出	挑 使	挑 刺	
挑 取	挑 拔	挑 肥 揀 瘦	挑 花	挑 挑	挑 挑 揀 揀	挑 重 擔	挑 食	
挑 剔	挑 唆	挑 唇 料 嘴	挑 起	挑 針	挑 動	挑 眼	挑 逗	
挑 逗 性	挑 揀	挑 著	挑 開	挑 運	挑 撥	挑 撥 離 間	挑 戰	
挑 戰 者	挑 戰 書	挑 擔	挑 激	挑 燈	挑 選	挑 釁	挑 釁 性	
政 大	政 工	政 工 幹 部	政 令	政 令 不 一	政 出 多 門	政 企	政 企 分 開	
政 局	政 局 演 變	政 見	政 見 發 表	政 事	政 協	政 協 委 員	政 和	
政 委	政 府	政 府 工 作	政 府 工 作 報 告	政 府 代 表	政 府 官 員	政 府 軍	政 府 首 腦	
政 府 機 構	政 府 機 關	政 府 總 理	政 法	政 法 部 門	政 治	政 治 人 物	政 治 上	
政 治 干 預	政 治 方 向	政 治 史	政 治 犯	政 治 生 活	政 治 任 務	政 治 危 機	政 治 地 位	
政 治 局	政 治 局 勢	政 治 形 勢	政 治 改 革	政 治 事 件	政 治 制 度	政 治 協 商 會 議	政 治 協 議	
政 治 委 員	政 治 社 會 學	政 治 宣 傳	政 治 思 想 工 作	政 治 思 想 史	政 治 思 想 教 育	政 治 思 潮	政 治 活 動	
政 治 派 別	政 治 面 目	政 治 家	政 治 追 求	政 治 追 討	政 治 鬥 爭	政 治 動 員	政 治 問 題	
政 治 常 識	政 治 情 況	政 治 理 念	政 治 理 論	政 治 統 計	政 治 處	政 治 責 任	政 治 部	
政 治 陰 謀	政 治 報 告	政 治 集 團	政 治 經 濟	政 治 經 濟 學	政 治 解 決	政 治 路 線	政 治 運 動	
政 治 綱 領	政 治 領 導	政 治 談 判	政 治 課	政 治 學	政 治 學 院	政 治 戰 略	政 治 機 關	
政 治 謀 略	政 治 避 難	政 治 醜 聞	政 治 關 係	政 治 獻 金	政 治 權 力	政 治 權 利	政 治 體 制	
政 客	政 界	政 紀	政 紀 處 分	政 要	政 風	政 務	政 務 官	
政 務 院	政 務 會	政 區	政 商	政 情	政 教	政 清 獄 簡	政 略	
政 略 性	政 通	政 通 人 和	政 策	政 策 主 張	政 策 性	政 策 法 規	政 策 界 限	
政 策 研 究	政 策 虧 損	政 經	政 綱	政 審	政 敵	政 論	政 壇	
政 戰	政 績	政 簡 刑 清	政 黨	政 權	政 權 建 設	政 權 移 交	政 權 機 關	
政 權 轉 移	政 變	政 體	故 人	故 土	故 土 難 移	故 友	故 世	
故 主	故 去	故 犯	故 交	故 吏	故 名	故 地	故 地 重 遊	
故 在	故 多	故 此	故 老	故 而	故 作	故 作 多 情	故 作 姿 態	
故 址	故 弄	故 弄 玄 虛	故 弄 懸 虛	故 我	故 技 重 演	故 步 自 封	故 里	
故 事	故 事 片	故 事 書	故 事 詩	故 事 影 片	故 事 體	故 居	故 知	
故 要	故 家 子 弟	故 宮	故 宮 禾 黍	故 宮 博 物 院	故 書	故 紙 堆	故 做	
故 國	故 都	故 鄉	故 園	故 意	故 道	故 態	故 態 復 萌	
故 稱	故 障	故 劍 情 深	故 賬	故 縱	故 舊	故 舊 不 棄	故 伎	
故 伎 重 演	斫 方 為 圓	斫 輪 老 手	斫 雕 為 樸	施 工	施 工 單 位	施 工 隊	施 工 圖	
施 不 望 報	施 丹 傅 粉	施 予	施 仁 布 恩	施 仁 布 德	施 仁 布 澤	施 文 彬	施 主	
施 以	施 加	施 加 影 響	施 加 壓 力	施 用	施 用 量	施 朱 傅 粉	施 行	
施 巫 術	施 事 者	施 放	施 明 德	施 法	施 秉	施 肥	施 肥 耙	
施 威	施 拾 者	施 政	施 政 報 告	施 為	施 展	施 展 才 能	施 展 才 華	
施 恩	施 粉	施 捨	施 捨 物	施 救	施 教	施 惠	施 惠 於	
施 給	施 催	施 與	施 賑	施 暴	施 謀 用 計	施 謀 用 智	施 謀 設 計	
施 壓	施 禮	施 藥	施 贈 者	施 屬	既 已	既 不	既 犬 不 留	
既 可	既 可 以	既 在	既 成 事 實	既 有	既 有 今 日 何 必 當 初	既 而	既 使	
既 來 之	既 來 之 則 安 之	既 定	既 定 方 針	既 往	既 往 不 咎	既 非	既 是	
既 為	既 要	既 能	既 得	既 得 利 益	既 無	既 然	既 然 如 此	
春 上	春 小 麥	春 山 八 字	春 山 如 笑	春 分	春 天	春 心	春 日	
春 日 鄉	春 日 融 融	春 牛	春 去 秋 來	春 生 秋 殺	春 光	春 光 如 海	春 光 明 媚	
春 光 漏 洩	春 回 大 地	春 忙	春 江	春 池 開 發	春 汛	春 色	春 色 滿 園	
春 旱	春 事 闌 珊	春 來 秋 去	春 卷	春 和 景 明	春 季	春 季 賽	春 花	
春 花 秋 月	春 雨	春 雨 工 廠	春 雨 綿 綿	春 城	春 祈 秋 報	春 秋	春 秋 時 代	
春 秋 筆 法	春 秋 鼎 盛	春 秋 戰 國	春 風	春 風 一 度	春 風 化 雨	春 風 和 氣	春 風 風 人	
春 風 夏 雨	春 風 得 意	春 風 滿 面	春 夏	春 夏 秋 冬	春 宮	春 宵	春 宵 一 刻	
春 神	春 耕	春 耕 生 產	春 茶	春 蚓 秋 蛇	春 假	春 情	春 深 似 海	
春 麥	春 寒	春 景	春 筍	春 華 秋 實	春 意	春 意 盎 然	春 暉	
春 暖	春 暖 花 香	春 暖 花 開	春 源 鋼 鐵	春 節	春 義 闌 珊	春 裝	春 運	
春 遊	春 雷	春 夢	春 夢 無 痕	春 滿 人 間	春 種	春 誦 夏 弦	春 播	
春 潮	春 輝	春 樹 暮 雲	春 聯	春 蕾	春 歸 人 老	春 藥	春 灌	
春 蘭	春 蘭 秋 菊	春 露 秋 霜	春 蠶	春 蠶 到 死 絲 方 盡	春 菇	昭 示	昭 昭	
昭 雪	昭 然	昭 然 若 揭	昭 著	昭 彰	映 入	映 山 紅	映 片	
映 出	映 射	映 泰 公 司	映 雪 囊 螢	映 雪 讀 書	映 著	映 照	映 像	
映 像 管	映 襯	昧 己 瞞 心	昧 天 瞞 地	昧 心	昧 旦 晨 興	昧 地 謾 天	昧 死 以 聞	
昧 於	昧 著	昧 著 良 心	是 了	是 不 是	是 日	是 乎	是 以	
是 古 非 今	是 次	是 否	是 的	是 長 是 短	是 非	是 非 人 我	是 非 不 分	
是 非 之 心	是 非 之 地	是 非 分 明	是 非 功 過	是 非 曲 直	是 非 問 題	是 非 得 失	是 非 顛 倒	
是 指	是 故	是 是 非 非	是 要	是 嗎	星 斗	星 火	星 火 計 劃	
星 火 燎 原	星 占 術	星 光	星 光 燦 爛	星 名	星 行 夜 歸	星 位	星 形	
星 形 物	星 形 線	星 系	星 系 間	星 言 夙 駕	星 辰	星 兒	星 夜	
星 奔 川 騖	星 河	星 狀	星 狀 物	星 狀 體	星 空	星 前 月 下	星 星	
星 星 之 火	星 星 之 火 可 以 燎 原	星 星 點 點	星 洲	星 相	星 相 學	星 座	星 座 運 勢	
星 國	星 宿	星 彩	星 球	星 眸 皓 齒	星 移 斗 換	星 移 斗 轉	星 移 物 換	
星 陳 夙 駕	星 散 於	星 期	星 期 一	星 期 二	星 期 三	星 期 五	星 期 六	
星 期 天	星 期 日	星 期 四	星 象	星 雲	星 群	星 落 雲 散	星 號	
星 運	星 馳 電 走	星 馳 電 發	星 團	星 際	星 際 間	星 盤	星 點	
星 蟲	星 羅 棋 布	星 羅 雲 布	星 體	昨 天	昨 天 下 午	昨 天 夜 間	昨 天 晚 間	
昨 日	昨 沒	昨 兒	昨 兒 個	昨 夜	昨 非 今 是	昨 甚	昨 能	
昨 晚	昱 成 建 設	柿 子	柿 餅	染 上	染 工	染 化 廠	染 手	
染 布	染 印	染 成	染 有	染 污	染 色	染 色 性	染 色 質	
染 色 體	染 血	染 坊	染 房	染 法	染 花	染 指	染 指 於 鼎	
染 指 垂 涎	染 眉	染 紅	染 缸	染 風 習 俗	染 料	染 疾	染 病	
染 得	染 患	染 發 劑	染 絲 之 變	染 業	染 睫	染 遍	染 髮	
染 劑	染 翰 操 紙	柱 子	柱 石	柱 式	柱 形	柱 形 圖	柱 身	
柱 狀	柱 面	柱 頂	柱 廊	柱 塞	柱 頭	柱 體	柔 心 弱 骨	
柔 毛	柔 毛 狀	柔 光	柔 如 剛 吐	柔 色	柔 佛	柔 沛	柔 和	
柔 性	柔 枝 嫩 條	柔 枝 嫩 葉	柔 板	柔 姿 紗	柔 美	柔 弱	柔 能 制 剛	
柔 茹 寡 斷	柔 情	柔 情 似 水	柔 情 密 意	柔 情 媚 態	柔 情 綽 態	柔 細	柔 術	
柔 軟 操	柔 媚	柔 韌	柔 韌 性	柔 順	柔 滑	柔 腸 寸 斷	柔 腸 百 結	
柔 腸 百 轉	柔 道	柔 嫩	柔 遠 能 邇	柔 懦 寡 斷	柔 聲 下 氣	某 一	某 一 方 面	
某 一 地 方	某 一 個	某 一 時 間	某 人	某 大	某 女	某 天	某 日	
某 月	某 台	某 甲	某 件	某 地	某 年	某 位	某 君	
某 村	某 事	某 些	某 些 人	某 些 方 面	某 些 地 區	某 物	某 某	
某 段	某 軍	某 個	某 時	某 國	某 處	某 部	某 隊	
某 項	某 種	某 種 原 因	某 種 程 度	某 種 意 義	某 類	柬 帖	柬 埔 寨	
柬 浦 寨	柬 國	架 上	架 子	架 子 車	架 不 住	架 好	架 式	
架 托 梁	架 有	架 次	架 住	架 豆	架 走	架 於	架 空	
架 架	架 海 金 梁	架 海 擎 天	架 站	架 起	架 設	架 開	架 勢	
架 塔	架 電	架 構	架 線	架 橋	架 謊 鑿 空	枯 井	枯 木	
枯 木 生 花	枯 木 再 生	枯 木 朽 株	枯 木 死 灰	枯 木 逢 春	枯 水	枯 水 位	枯 水 期	
枯 朽	枯 死	枯 坐	枯 形 灰 心	枯 枝	枯 枝 再 春	枯 株 朽 木	枯 草	
枯 草 桿 菌	枯 骨	枯 乾	枯 寂	枯 魚 之 肆	枯 魚 病 鶴	枯 魚 涸 轍	枯 魚 銜 索	
枯 菱	枯 萎	枯 黃	枯 黑	枯 葉	枯 葉 劑	枯 槁	枯 竭	
枯 瘦	枯 樹	枯 樹 開 花	枯 澀	枯 燥	枯 燥 乏 味	枯 燥 無 味	枯 體 灰 心	
柵 門	柵 格	柵 極	柵 欄	柩 台	柩 衣	柩 車	柯 一 正	
柯 以 敏	柯 受 良	柯 林 頓	柯 茲 兒	柯 達	柄 勺	柄 梢	柄 腳	
柄 端	柑 桔	柑 橘	柑 橘 園	柚 子	柚 木	查 出	查 字	
查 收	查 考	查 兌 者	查 完	查 抄	查 找	查 私	查 究	
查 到	查 夜	查 定	查 房	查 明	查 明 具 報	查 表	查 封	
查 查	查 看	查 哨	查 核	查 案	查 訖	查 退	查 勘	
查 問	查 帳	查 帳 員	查 清	查 票	查 處	查 訪	查 透	
查 報	查 尋	查 無 此 人	查 無 實 據	查 稅	查 禁	查 號 台	查 補	
查 詢	查 詢 專 線	查 詢 電 話	查 過	查 實	查 對	查 價	查 德	
查 緝	查 賬	查 閱	查 辦	查 錯	查 獲	查 點	查 證	
查 覺	查 驗	查 舖	枸 杞	枸 杞 子	柏 木	柏 舟 之 節	柏 舟 之 誓	
柏 克 萊	柏 克 萊 加 大	柏 忌	柏 承 科 技	柏 拉 圖	柏 林	柏 林 影 展	柏 油	
柏 油 路	柏 楊	柏 樹	柞 絲	柞 綢	柞 蠶	柞 蠶 絲	柳 戶 花 門	
柳 木	柳 州	柳 江	柳 杉	柳 枝	柳 林	柳 松 菇	柳 河	
柳 巷 花 街	柳 眉	柳 眉 倒 豎	柳 眉 剔 豎	柳 眉 踢 豎	柳 陌 花 巷	柳 陌 花 街	柳 陌 花 衢	
柳 條	柳 條 工	柳 條 做	柳 條 編	柳 啼 花 怨	柳 媚 花 明	柳 琴	柳 絮	
柳 絲	柳 暗 花 明	柳 暗 花 明 又 一 村	柳 聖 花 神	柳 腰	柳 葉 刀	柳 綠 花 紅	柳 綠 桃 紅	
柳 影 花 陰	柳 樹	柳 營 鄉	柳 體	歪 七 扭 八	歪 七 豎 八	歪 了	歪 心 邪 意	
歪 打	歪 打 正 著	歪 向	歪 曲	歪 曲 事 實	歪 形	歪 門 邪 道	歪 姿 斜 態	
歪 歪	歪 歪 扭 扭	歪 歪 斜 斜	歪 風	歪 風 邪 氣	歪 倒	歪 斜	歪 理	
歪 脖	歪 詩	歪 像	歪 嘴	歪 談 亂 道	殃 及	殃 及 池 魚	殃 民	
殃 殃	殃 國 禍 家	殆 無 孑 遺	殆 無 虛 日	殆 盡	段 子	段 式	段 長	
段 落	段 燒	毒 力	毒 力 因 子	毒 化	毒 手	毒 手 尊 拳	毒 牙	
毒 打	毒 汁	毒 瓦 斯	毒 刑	毒 死	毒 舌	毒 刺	毒 性	
毒 物	毒 物 學	毒 狗 草	毒 品	毒 品 危 害 防 制 條 例	毒 品 走 私	毒 品 走 私 案	毒 品 販	
毒 計	毒 害	毒 氣	毒 氣 彈	毒 氣 戰	毒 症	毒 素	毒 草	
毒 酒	毒 婦	毒 教	毒 殺	毒 液	毒 理 學	毒 蛇	毒 蛇 猛 獸	
毒 菌	毒 腺	毒 蛾	毒 蜘 蛛	毒 辣	毒 餌	毒 瘤	毒 瘡	
毒 箭	毒 劑	毒 劑 化 學	毒 劑 彈	毒 謀	毒 蟲	毒 藥	毒 藥 苦 口	
毒 癮	毗 連	毗 鄰	氟 化 物	氟 化 氫	氟 化 鈣	氟 化 銀	氟 石	
氟 利 昂	氟 氯 碳 化 物	氟 酸	泉 下	泉 水	泉 石 膏 肓	泉 州	泉 城	
泉 眼	泉 源	洋 人	洋 化	洋 文	洋 火	洋 奴	洋 奴 哲 學	
洋 布	洋 白 菜	洋 地 黃	洋 式	洋 灰	洋 灰 漿	洋 行	洋 兵	
洋 車	洋 房	洋 服	洋 法	洋 姜	洋 娃 娃	洋 洋	洋 洋 大 觀	
洋 洋 自 得	洋 洋 得 意	洋 洋 灑 灑	洋 流	洋 派	洋 為 中 用	洋 相	洋 紅	
洋 紅 色	洋 氣	洋 浦	洋 粉	洋 紗	洋 財	洋 酒	洋 釘	
洋 鬼	洋 鬼 子	洋 務	洋 務 派	洋 務 運 動	洋 基	洋 基 隊	洋 毫	
洋 瓷	洋 船	洋 貨	洋 傘	洋 場	洋 腔	洋 菜	洋 嗓 子	
洋 溢	洋 煙	洋 裝	洋 裡 洋 氣	洋 槐	洋 銀	洋 樓	洋 蔥	
洋 蔥 似	洋 調	洋 澱	洋 錢	洋 鋼	洋 藥	洋 艦	洋 鐵	
洲 產	洲 際	洲 際 導 彈	洪 大	洪 水	洪 水 猛 獸	洪 水 論	洪 江	
洪 災	洪 泛 區	洪 亮	洪 流	洪 洞	洪 峰	洪 恩	洪 荒	
洪 區	洪 啟 峰	洪 都 拉 斯	洪 湖	洪 量	洪 雅	洪 溝	洪 道	
洪 福	洪 福 齊 天	洪 澤	洪 積 說	洪 積 層	洪 濤	洪 爐 燎 發	洪 鐘	
洪 澇	流 了	流 入	流 入 物	流 下	流 亡	流 亡 者	流 亡 政 府	
流 口 水	流 水	流 水 不 腐	流 水 行 雲	流 水 作 業	流 水 高 山	流 水 帳	流 水 無 情	
流 水 落 花	流 水 線	流 出	流 出 物	流 出 量	流 去	流 失	流 民	
流 用	流 光	流 光 瞬 息	流 向	流 回	流 年	流 汗	流 汗 浹 背	
流 血	流 血 千 里	流 血 成 河	流 血 成 渠	流 血 事 件	流 血 浮 屍	流 血 漂 杵	流 血 漂 鹵	
流 行	流 行 色	流 行 性	流 行 時 尚	流 行 病	流 行 著	流 行 感 冒	流 行 榜	
流 行 歌 曲	流 行 語	流 行 樂	流 利	流 沙	流 言	流 言 飛 文	流 言 惑 眾	
流 言 蜚 語	流 到	流 往	流 性 學	流 放	流 於	流 於 形 式	流 氓	
流 氓 案 件	流 氓 般	流 注	流 物	流 的	流 芳	流 芳 千 古	流 芳 百 世	
流 芳 後 世	流 芳 萬 古	流 芳 遺 臭	流 表	流 金 鑠 石	流 俗	流 星	流 星 似	
流 星 坎 止	流 星 趕 月	流 星 體	流 毒	流 派	流 派 風 格	流 風 回 雪	流 風 余 俗	
流 風 餘 韻	流 風 遺 俗	流 風 遺 烈	流 風 遺 跡	流 風 遺 澤	流 風 遺 躅	流 浪	流 浪 汗	
流 浪 者	流 浪 漢	流 涕	流 乾	流 動	流 動 人 口	流 動 性	流 動 物	
流 動 紅 旗	流 動 基 金	流 動 資 本	流 動 資 金	流 動 資 產	流 域	流 寇	流 掉	
流 涎	流 淌	流 淚	流 產	流 通	流 通 手 段	流 通 渠 道	流 通 量	
流 通 業	流 通 領 域	流 連	流 連 忘 返	流 速	流 速 計	流 逝	流 散	
流 程	流 著	流 進	流 量	流 量 計	流 傳	流 傳 廣	流 感	
流 感 病 毒	流 經	流 腦	流 落	流 落 不 偶	流 裡 流 氣	流 過	流 遍 全 身	
流 電	流 電 學	流 弊	流 暢	流 盡	流 鼻 水	流 鼻 涕	流 層	
流 彈	流 槽	流 線	流 線 型	流 質	流 輝	流 蕩	流 蕩 忘 反	
流 螢	流 膿	流 點	流 瀉	流 竄	流 竄 犯	流 轉	流 離	
流 離 失 所	流 離 瑣 尾	流 離 顛 沛	流 蘇	流 覽	流 露	流 露 出	流 戀	
流 體	流 體 力 學	流 體 動 力 學	津 巴 布 韋	津 市	津 津	津 津 公 司	津 津 有 味	
津 津 樂 道	津 浦	津 貼	洞 口	洞 子	洞 中	洞 中 肯 綮	洞 內	
洞 天 福 地	洞 孔	洞 穴	洞 見	洞 見 癥 結	洞 兒	洞 府	洞 房	
洞 房 花 燭	洞 房 花 燭 夜	洞 洞	洞 洞 裝	洞 若 觀 火	洞 庭 湖	洞 悉	洞 窟	
洞 裡	洞 察	洞 察 力	洞 察 其 奸	洞 徹	洞 頭	洞 燭 其 奸	洞 鑒	
洞 鑒 古 今	洗 心 自 新	洗 心 革 志	洗 心 革 面	洗 心 革 意	洗 心 換 骨	洗 心 滌 慮	洗 手	
洗 手 奉 職	洗 手 間	洗 去	洗 印	洗 米	洗 耳 拱 聽	洗 耳 恭 聽	洗 衣	
洗 衣 工	洗 衣 日	洗 衣 店	洗 衣 房	洗 衣 所	洗 衣 板	洗 衣 盆	洗 衣 粉	
洗 衣 婦	洗 衣 處	洗 衣 間	洗 衣 機	洗 劫	洗 劫 一 空	洗 足	洗 足 禮	
洗 身	洗 車	洗 車 場	洗 刷	洗 法	洗 物 槽	洗 削 更 革	洗 垢 求 瘢	
洗 垢 索 瘢	洗 垢 匿 瑕	洗 垢 尋 痕	洗 染	洗 洗	洗 面	洗 冤	洗 消	
洗 消 器 材	洗 浴	洗 掉	洗 液	洗 清	洗 淨	洗 理 費	洗 瓶 刷	
洗 眼 杯	洗 眼 液	洗 脫	洗 雪	洗 牌	洗 菜	洗 煤	洗 碗	
洗 碗 池	洗 碗 機	洗 罪	洗 腸	洗 腳	洗 腦	洗 過	洗 塵	
洗 漱	洗 滌	洗 滌 日	洗 滌 者	洗 滌 槽	洗 滌 劑	洗 滌 器	洗 碟	
洗 熨	洗 髮	洗 髮 精	洗 髮 膏	洗 劑	洗 澡	洗 澡 間	洗 燙	
洗 選	洗 頭	洗 擦	洗 擦 者	洗 濯 盆	洗 臉	洗 臉 盆	洗 臉 間	
洗 禮	洗 禮 盆	洗 禮 堂	活 了	活 人	活 力	活 下 來	活 上	
活 口	活 土 層	活 不 活 死 不 死	活 化	活 化 劑	活 水	活 火	活 火 山	
活 生 生	活 用	活 在	活 在 世 上	活 字	活 字 印 刷	活 扣	活 血	
活 佛	活 見 鬼	活 來	活 兒	活 到	活 受 罪	活 命	活 命 哲 學	
活 底	活 性	活 性 染 料	活 性 炭	活 性 劑	活 法	活 版	活 的	
活 門	活 度	活 活	活 計	活 頁	活 剝	活 埋	活 捉	
活 神	活 動	活 動 力	活 動 中	活 動 中 心	活 動 分 子	活 動 日	活 動 性	
活 動 門	活 動 家	活 動 能 力	活 動 場 所	活 得	活 現	活 脫	活 脫 脫	
活 魚	活 勞 動	活 期	活 結	活 絡	活 菩 薩	活 著	活 塞	
活 塞 桿	活 塞 隊	活 塞 環	活 該	活 話	活 路	活 過	活 像	
活 潑	活 豬	活 樹	活 錢	活 龍 活 現	活 寶	活 躍	活 體	
活 靈 活 現	洽 借	洽 商	洽 詢	洽 聞 強 記	洽 聞 博 見	洽 談	洽 談 會	
洽 辦	洽 購	派 人	派 上	派 方	派 出	派 出 所	派 出 機 構	
派 生	派 生 物	派 生 詞	派 任 職	派 克	派 兵	派 別	派 系	
派 來	派 定	派 往	派 性	派 派	派 軍	派 員	派 送	
派 場	派 給	派 進	派 對	派 遣	派 駐	派 頭	派 購	
洶 洶	洶 湧	洶 湧 澎 湃	洛 川	洛 克	洛 杉 磯	洛 河	洛 陽	
洛 陽 才 子	洛 陽 市	洛 陽 紙 貴	泵 水	泵 房	洩 了	洩 出	洩 私 憤	
洩 底	洩 物	洩 勁	洩 恨	洩 洪	洩 洪 道	洩 氣	洩 密	
洩 漏	洩 漏 天 機	洩 憤	洩 藥	洩 露	炫 玉 賈 石	炫 目	炫 示	
炫 晝 縞 夜	炫 異 爭 奇	炫 耀	為 了	為 人	為 人 正 直	為 人 民	為 人 民 服 務	
為 人 作 嫁	為 人 所 知	為 人 為 徹	為 人 師 表	為 人 處 事	為 上	為 己	為 之	
為 之 一 振	為 仁 不 富	為 什 麼	為 公	為 方 便 用 戶	為 止	為 王	為 主	
為 奴	為 本	為 民	為 民 除 害	為 民 請 命	為 生	為 由	為 伍	
為 向	為 名	為 多	為 好	為 好 成 歉	為 安	為 成	為 有	
為 此	為 臣 死 忠 為 子 死 孝	為 自 豪	為 何	為 你	為 利	為 序	為 我	
為 我 所 用	為 把	為 求	為 私	為 依 據	為 佳	為 使	為 例	
為 典 型	為 受	為 妻	為 官	為 宜	為 所	為 所 欲 為	為 法 自 弊	
為 的	為 虎 作 倀	為 虎 添 翼	為 虎 傅 翼	為 非 作 歹	為 信	為 度	為 政	
為 政 清 廉	為 是	為 甚 麼	為 界	為 盼	為 虺 弗 摧 為 蛇 若 何	為 要	為 重	
為 限	為 首	為 害	為 害 最 烈	為 差	為 師	為 時	為 時 已 晚	
為 時 不 晚	為 時 尚 早	為 時 過 早	為 特 徵	為 真	為 真 理 而 鬥 爭	為 能	為 高	
為 做	為 副	為 區 別	為 國	為 國 出 力	為 國 爭 光	為 國 為 民	為 國 為 蜮	
為 國 捐 軀	為 基 礎	為 從	為 患	為 您	為 淵 驅 魚	為 淵 驅 魚 為 叢 驅 雀	為 蛇 添 足	
為 蛇 畫 足	為 最	為 富 不 仁	為 惡 不 悛	為 期	為 期 不 遠	為 善	為 善 最 樂	
為 著	為 慎 重 起 見	為 準	為 群 眾 服 務	為 裘 為 箕	為 零	為 榮	為 輔	
為 德 不 卒	為 敵	為 數	為 數 不 少	為 數 不 多	為 樂	為 整	為 營	
為 總	為 避 免	為 叢 驅 雀	為 題	為 懷	為 證	為 難	為 繼	
為 啥	炳 如 日 星	炳 炳 麟 麟	炳 炳 鑿 鑿	炳 若 日 星	炳 燭 夜 遊	炳 耀 千 秋	炬 者	
炯 炯	炯 炯 有 神	炭 化	炭 火	炭 材	炭 刷	炭 盆	炭 疽 病	
炭 素	炭 棒	炭 畫	炭 筆	炭 黑	炭 精	炭 層	炭 窯	
炭 爐	炸 丸 子	炸 土	炸 出	炸 成	炸 死	炸 肉 排	炸 破	
炸 得	炸 掉	炸 裂	炸 開	炸 傷	炸 毀	炸 窩	炸 餅	
炸 彈	炸 機	炸 聲	炸 薯 片	炸 鍋	炸 斷	炸 醬	炸 雞	
炸 雞 翅	炸 雞 褪	炸 壞	炸 藥	炮 口	炮 手	炮 火	炮 火 連 天	
炮 仗	炮 台	炮 打	炮 灰	炮 衣	炮 位	炮 兵	炮 兵 連	
炮 兵 營	炮 身	炮 車	炮 架	炮 座	炮 栓	炮 索	炮 眼	
炮 術	炮 筒	炮 隊	炮 塔	炮 艇	炮 種	炮 管	炮 製	
炮 鳳 烹 龍	炮 彈	炮 樓	炮 戰	炮 龍 烹 鳳	炮 擊	炮 聲	炮 艦	
炮 艦 政 策	炮 轟	牲 口	牲 品	牲 畜	牯 牛	狩 獵	狠 心	
狠 心 腸	狠 打	狠 抓	狠 命	狠 治	狠 剎	狠 勁	狠 拱	
狠 毒	狠 狠	狠 愎 自 用	狠 揍	狡 免 三 窟	狡 兔	狡 兔 三 穴	狡 兔 三 窟	
狡 兔 死 良 犬 烹	狡 兔 死 良 狗 烹	狡 詐	狡 滑	狡 猾	狡 賴	狡 濤 作 浪	狡 黠	
狡 譎	狡 辯	狡 獪	玷 污	珊 卓 布 拉 克	珊 湖	珊 瑚	珊 瑚 石	
珊 瑚 在 網	珊 瑚 色	珊 瑚 狀	珊 瑚 島	珊 瑚 礁	珊 瑚 蟲	玻 利 維 亞	玻 璃	
玻 璃 化	玻 璃 似	玻 璃 杯	玻 璃 板	玻 璃 沫	玻 璃 狀	玻 璃 股	玻 璃 缸	
玻 璃 珠	玻 璃 粉	玻 璃 紗	玻 璃 紙	玻 璃 瓶	玻 璃 陶 瓷	玻 璃 陶 瓷 股	玻 璃 絲	
玻 璃 罩	玻 璃 幕 牆	玻 璃 質	玻 璃 器 皿	玻 璃 鋼	玻 璃 櫃	玻 璃 纖 維	玻 璃 體	
玲 瓏	玲 瓏 剔 透	珍 本	珍 奇	珍 妮 佛 羅 培 玆	珍 妮 佛 羅 培 茲	珍 品	珍 重	
珍 珠	珍 珠 色	珍 珠 似	珍 珠 質	珍 秘	珍 惜	珍 異	珍 稀	
珍 稀 動 物	珍 視	珍 貴	珍 貴 文 物	珍 愛	珍 禽	珍 禽 異 獸	珍 聞	
珍 藏	珍 寶	珍 饈	珀 金	玳 瑁	甚 大	甚 小	甚 少	
甚 多	甚 而	甚 至	甚 至 於	甚 低 頻	甚 佳	甚 或	甚 於	
甚 為	甚 高	甚 高 頻	甚 深	甚 微	甚 解	甚 輕	甚 遠	
甚 麼	甚 廣	甚 囂 塵 上	甭 提	甭 管	甭 說	畏 口	畏 之 如 虎	
畏 友	畏 天 知 命	畏 天 恤 民	畏 天 愛 民	畏 光	畏 死	畏 死 貪 生	畏 忌	
畏 怯	畏 威 懷 德	畏 首 畏 尾	畏 首 畏 足	畏 神	畏 途	畏 敬	畏 歲	
畏 罪	畏 影 而 走	畏 嚇	畏 縮	畏 縮 不 前	畏 難	畏 難 苟 安	畏 難 情 緒	
畏 懼	畏 葸 不 前	界 尺	界 外	界 外 球	界 外 線	界 石	界 址	
界 志	界 定	界 於	界 河	界 狀	界 約	界 限	界 面	
界 首	界 值	界 第	界 符	界 碑	界 說	界 層	界 樁	
界 標	界 線	界 點	畎 母 下 才	畎 畝 之 中	疫 性	疫 苗	疫 苗 注 射	
疫 苗 開 發	疫 病	疫 區	疫 情	疤 痕	疤 點	疥 瘡	疥 賴 之 疾	
疥 蟲	疥 癩 之 患	疥 癬	疥 癬 之 疾	疣 腫	癸 丑	癸 未	癸 亥	
癸 酉	皆 大	皆 大 歡 喜	皆 巳	皆 不	皆 以	皆 可	皆 白	
皆 有	皆 兵	皆 佳	皆 知	皆 空	皆 是	皆 為	皆 無	
皆 然	皆 輸	皆 縱 即 逝	皇 上	皇 女	皇 子	皇 天	皇 天 不 親 惟 德 是 輔	
皇 天 后 土	皇 太	皇 太 子	皇 太 后	皇 后	皇 位	皇 昌 營 造	皇 冠	
皇 城	皇 室	皇 帝	皇 皇	皇 家	皇 宮	皇 族	皇 統	
皇 統 光 碟	皇 莊	皇 陵	皇 普 建 設	皇 朝	皇 翔 建 設	皇 旗 資 訊	皇 歷	
皇 親 國 戚	皇 儲	皇 糧	皇 黨	皇 權	皈 依	皈 依 者	盈 千 累 百	
盈 千 累 萬	盈 尺 之 地	盈 月	盈 利	盈 門	盈 則 不 虧	盈 盈	盈 盈 一 水	
盈 盈 在 目	盈 盈 秋 水	盈 眶	盈 溢	盈 滿	盈 滿 之 咎	盈 篇 累 牘	盈 餘	
盈 虧	盆 子	盆 中	盆 地	盆 兒	盆 狀	盆 花	盆 架	
盆 栽	盆 浴	盆 堂	盆 景	盆 植	盆 湯	盆 腔	盆 菜	
盆 傾 甕 倒	盆 塘	省 力	省 下	省 小 錢	省 工	省 中	省 內	
省 內 外	省 心	省 方 觀 民	省 方 觀 俗	省 主 席	省 去	省 外	省 市	
省 市 區	省 用	省 用 足 財	省 立	省 份	省 刑 薄 斂	省 吃 儉 用	省 字	
省 行	省 局	省 事	省 委	省 委 員 會	省 委 書 記	省 府	省 直	
省 直 機 關	省 長	省 便	省 俗 觀 風	省 卻	省 城	省 思	省 政 府	
省 界	省 科 委	省 紀	省 紀 委	省 軍 級	省 軍 區	省 悟	省 料	
省 時	省 級	省 區	省 得	省 掉	省 欲 去 箸	省 略	省 略 句	
省 略 號	省 部 級	省 港	省 視	省 會	省 煩 從 簡	省 道	省 過	
省 電	省 儉	省 縣	省 親	省 錢	省 優	省 轄	省 點	
省 籍	省 屬	盹 兒	相 一 致	相 士	相 干	相 中	相 互	
相 互 矛 盾	相 互 作 用	相 互 性	相 互 配 合	相 互 理 解	相 互 間	相 互 輝 映	相 公	
相 切	相 匹 敵	相 反	相 反 物	相 反 相 成	相 夫	相 比	相 比 之 下	
相 比 較	相 片	相 冊	相 加	相 去 不 遠	相 去 天 淵	相 去 咫 尺	相 去 甚 遠	
相 去 無 幾	相 左	相 斥	相 生	相 生 相 剋	相 交	相 仿	相 同	
相 同 之 處	相 同 樣	相 合	相 奸	相 好	相 守	相 安	相 安 無 事	
相 成	相 托	相 位	相 位 角	相 位 差	相 伴	相 似	相 似 形	
相 似 性	相 似 物	相 告	相 吻 合	相 形	相 形 失 色	相 形 見 絀	相 形 見 遜	
相 忍	相 忍 為 國	相 扶	相 投	相 求	相 沖	相 見	相 見 恨 晚	
相 見 無 日	相 角	相 依	相 依 為 命	相 命	相 宜	相 抵	相 沿	
相 爭	相 知	相 知 恨 晚	相 知 相 惜	相 者	相 迎	相 近	相 門 出 相	
相 門 有 相	相 信	相 信 人	相 信 組 織	相 信 群 眾	相 剋	相 待	相 待 如 賓	
相 待 而 成	相 思	相 思 豆	相 思 病	相 思 鳥	相 持	相 持 不 下	相 映	
相 映 成 趣	相 架	相 為 表 裡	相 看	相 約	相 背	相 迫	相 面	
相 風 使 帆	相 乘	相 倚 為 命	相 倚 為 強	相 家	相 容	相 容 性	相 差	
相 差 無 幾	相 差 懸 殊	相 師	相 悖	相 時 而 動	相 書	相 紙	相 配	
相 除	相 鬥	相 偎	相 商	相 國	相 得 恨 晚	相 得 益 彰	相 從	
相 情	相 接	相 望	相 混	相 混 合	相 異	相 符	相 符 合	
相 處	相 術	相 許	相 通	相 連	相 逢	相 逢 恨 晚	相 逢 狹 路	
相 陪	相 惡	相 提 並 論	相 棋	相 減	相 等	相 等 物	相 結	
相 結 合	相 善	相 視	相 視 莫 逆	相 距	相 間	相 須 而 行	相 須 為 命	
相 傳	相 媲 美	相 愛	相 敬 如 賓	相 會	相 滅 相 生	相 煎 何 急	相 煩	
相 當	相 當 大	相 當 可 觀	相 當 多	相 當 於	相 當 陡	相 當 規 模	相 碰	
相 補	相 遇	相 電 流	相 像	相 對	相 對 比	相 對 而 言	相 對 來 說	
相 對 性	相 對 於	相 對 物	相 對 運 動	相 對 誤 差	相 對 說 來	相 對 數	相 對 論	
相 對 濕 度	相 稱	相 聚	相 與	相 與 為 命	相 認	相 貌	相 貌 堂 堂	
相 輔	相 輔 而 行	相 輔 相 成	相 輕	相 憐	相 撞	相 撲	相 熟	
相 罵	相 談	相 適 合	相 適 應	相 鄰	相 學	相 機	相 機 而 行	
相 機 而 言	相 機 而 動	相 機 行 事	相 機 觀 變	相 親	相 親 相 愛	相 隨	相 館	
相 幫	相 應	相 應 措 施	相 濡	相 濡 一 沫	相 濡 以 沫	相 聲	相 聯	
相 聯 繫	相 禮	相 離	相 簿	相 識	相 識 人	相 譏	相 關	
相 關 性	相 關 物	相 關 者	相 關 圖	相 關 器	相 類 相 從	相 勸	相 繼	
相 繼 問 世	相 觸	相 顧	相 顧 失 色	相 襯	相 變	相 驚 伯 有	相 讓	
眉 山	眉 心	眉 月	眉 毛	眉 目	眉 目 不 清	眉 目 如 畫	眉 目 傳 情	
眉 宇	眉 肌	眉 形	眉 批	眉 來 眼 去	眉 來 語 去	眉 注	眉 花 眼 笑	
眉 南 面 北	眉 飛	眉 飛 色 舞	眉 峰	眉 高 眼 低	眉 梢	眉 清 目 秀	眉 眼	
眉 眼 高 低	眉 眼 傳 情	眉 鳥	眉 筆	眉 開 眼 笑	眉 睫	眉 睫 之 內	眉 睫 之 利	
眉 睫 之 禍	眉 頭	眉 頭 一 皺 計 上 心 來	眉 額	眉 題	眉 歡 眼 笑	看 一 下	看 了	
看 人	看 人 行 事	看 人 眉 睫	看 下	看 上	看 上 去	看 上 去 是	看 不	
看 不 上 眼	看 不 出	看 不 見	看 不 起	看 不 順 眼	看 不 慣	看 中	看 手	
看 文 巨 眼	看 文 老 眼	看 他	看 出	看 去	看 用	看 在	看 在 眼 裡	
看 好	看 守	看 守 人	看 守 內 閣	看 守 所	看 守 者	看 成	看 有	
看 朱 成 碧	看 似	看 作	看 低	看 吧	看 完	看 見	看 車	
看 些	看 來	看 來 好 像	看 到	看 定	看 押	看 法	看 的	
看 者	看 花	看 表	看 門	看 門 人	看 門 犬	看 門 狗	看 孩 子	
看 待	看 後	看 扁	看 相	看 看	看 穿	看 重	看 風	
看 風 行 事	看 風 使 帆	看 風 使 舵	看 風 使 船	看 風 駛 篷	看 風 轉 舵	看 家	看 家 狗	
看 書	看 病	看 破	看 破 紅 塵	看 起 來	看 做	看 啊	看 得	
看 得 出	看 得 見	看 得 起	看 得 清	看 得 慣	看 得 遠	看 您	看 望	
看 清	看 這	看 透	看 都 不 看	看 報	看 景 生 情	看 著	看 菜 吃 飯 量 體 裁 衣	
看 跌	看 準	看 過	看 電 視	看 電 影	看 厭	看 圖	看 慣	
看 漏	看 漲	看 管	看 管 者	看 臺	看 輕	看 齊	看 樣	
看 樣 子	看 錯	看 頭	看 懂	看 戲	看 醫	看 護	看 護 人	
盾 形	盾 板	盾 狀	盾 牌	盼 望	盼 頭	矜 己 任 智	矜 己 自 飾	
矜 才 使 氣	矜 功 不 立	矜 功 伐 善	矜 功 自 伐	矜 功 恃 寵	矜 功 負 氣	矜 功 負 勝	矜 名 妒 能	
矜 名 嫉 能	矜 奇 立 異	矜 糾 收 繚	矜 持	矜 矜 業 業	矜 重	矜 能 負 才	矜 貧 恤 獨	
矜 貧 救 厄	矜 智 負 能	矜 寡 孤 獨	砂 土	砂 子	砂 布	砂 石	砂 石 車	
砂 金 石	砂 型	砂 紙	砂 堆	砂 眼	砂 樣	砂 模	砂 漿	
砂 輪	砂 器	砂 糖	砂 鍋	砂 燼	砂 礫	砂 巖	研 光	
研 成	研 考 會	研 判	研 究	研 究 人 員	研 究 工 作	研 究 中 心	研 究 出	
研 究 生	研 究 成 果	研 究 所	研 究 者	研 究 室	研 究 員	研 究 院	研 究 報 告	
研 究 會	研 究 資 料	研 究 機 構	研 京 練 都	研 定	研 修	研 修 班	研 桑 心 計	
研 粉	研 討	研 討 會	研 商 對 策	研 深 覃 精	研 習	研 幾 析 理	研 幾 探 賾	
研 揚 科 技	研 發	研 華	研 華 公 司	研 華 科 技	研 碎	研 精 苦 思	研 精 覃 思	
研 精 覃 奧	研 精 覃 慮	研 精 鉤 深	研 精 靜 慮	研 精 鑄 史	研 製	研 製 出	研 製 成	
研 製 者	研 磨	研 磨 用	研 磨 者	研 磨 料	研 磨 劑	研 磨 機	研 擬	
研 讀	砌 石	砌 成	砌 磚	砌 牆	砌 體	砍 刀	砍 下	
砍 木	砍 去	砍 瓜 切 菜	砍 伐	砍 伐 者	砍 光	砍 成	砍 死	
砍 到	砍 林	砍 倒	砍 柴	砍 得	砍 掉	砍 殺	砍 痕	
砍 開	砍 傷	砍 頭	砍 斷	砍 壞	祉 助 金	祈 佑	祈 免	
祈 求	祈 求 者	祈 使	祈 使 法	祈 雨	祈 望	祈 晴 禱 雨	祈 福	
祈 請	祈 樹 有 緣	祈 禱	祈 禱 文	祈 禱 者	祈 願	禹 行 舜 趨	科 大	
科 幻	科 以	科 白	科 目	科 名	科 別	科 技	科 技 人 員	
科 技 司	科 技 股	科 技 型	科 技 界	科 技 產 業	科 技 資 訊	科 技 館	科 協	
科 協 工 作	科 委	科 林	科 盲	科 股	科 長	科 威 特	科 威 特 人	
科 室	科 建 顧 問 公 司	科 研	科 研 成 果	科 研 所	科 研 部	科 倫 坡	科 員	
科 海	科 班	科 班 出 身	科 索 沃	科 級	科 教	科 教 片	科 教 興 國	
科 組	科 博 館	科 場	科 普	科 普 讀 物	科 隆	科 學	科 學 上	
科 學 分 析	科 學 化	科 學 技 術	科 學 性	科 學 界	科 學 研 究	科 學 家	科 學 院	
科 學 管 理	科 學 學	科 頭 箕 踞	科 頭 箕 裾	科 頭 跣 足	科 舉	科 舉 考 試	科 舉 制	
科 羅 拉 多	秒 秒	秒 針	秒 錶	秒 鐘	秋 分	秋 天	秋 日	
秋 月	秋 月 春 花	秋 月 春 風	秋 月 寒 江	秋 水	秋 水 仙	秋 水 伊 人	秋 令	
秋 冬	秋 冬 季	秋 田	秋 成	秋 收	秋 收 冬 藏	秋 收 起 義	秋 汛	
秋 色	秋 衣	秋 決	秋 季	秋 征	秋 波	秋 雨	秋 雨 印 刷	
秋 後	秋 後 算 帳	秋 思	秋 風	秋 風 掃 落 葉	秋 風 落 葉	秋 風 過 耳	秋 風 團 扇	
秋 香	秋 海 棠	秋 耕	秋 草 人 請	秋 高 氣 爽	秋 高 氣 肅	秋 高 馬 肥	秋 假	
秋 毫	秋 毫 不 犯	秋 毫 之 末	秋 毫 無 犯	秋 涼	秋 荼 密 網	秋 麥	秋 景	
秋 殘	秋 游	秋 意	秋 節	秋 試	秋 播	秋 瑾	秋 樹	
秋 褲	秋 聲	秋 霜	秋 糧	秋 蟬	秋 蟲	穿 入	穿 上	
穿 小 鞋	穿 山 甲	穿 山 越 嶺	穿 不 下	穿 孔	穿 孔 者	穿 孔 員	穿 孔 器	
穿 孔 機	穿 以	穿 用	穿 用 者	穿 在	穿 好	穿 耳	穿 行	
穿 衣	穿 衣 服	穿 衣 鏡	穿 住	穿 孝	穿 來	穿 刺	穿 制	
穿 制 服	穿 房 入 戶	穿 花 蛺 蝶	穿 便 衣	穿 洞	穿 紅 著 綠	穿 破	穿 釘	
穿 針	穿 針 引 線	穿 堂	穿 堂 風	穿 帶	穿 得	穿 得 好	穿 梭	
穿 梭 外 交	穿 梭 往 返	穿 通	穿 透	穿 透 性	穿 透 電 流	穿 插	穿 換	
穿 著	穿 著 入 時	穿 著 打 扮	穿 著 者	穿 越	穿 進	穿 雲	穿 雲 破 霧	
穿 雲 裂 石	穿 暖	穿 楊	穿 過	穿 靴	穿 鼻	穿 線	穿 鞋	
穿 幫	穿 戴	穿 牆	穿 壞	穿 爛	穿 襪	穿 鑿	穿 鑿 附 會	
穿 窬 之 盜	突 入	突 兀	突 升	突 出	突 出 表 現	突 出 貢 獻	突 出 點	
突 尼 西 亞	突 尼 斯	突 地	突 如	突 如 其 來	突 泉	突 突	突 降	
突 飛	突 飛 猛 進	突 破	突 破 口	突 破 防 禦	突 破 性	突 破 者	突 破 點	
突 破 難 關	突 起	突 梯 滑 稽	突 現	突 厥	突 厥 人	突 圍	突 堤	
突 然	突 然 性	突 然 間	突 然 襲 擊	突 發	突 發 性	突 進	突 感	
突 遭	突 擊	突 擊 手	突 擊 組	突 擊 隊	突 擊 隊 員	突 轉	突 觸	
突 襲	突 變	突 變 型	突 變 種	突 變 論	突 變 學	竿 子	竿 跳	
竿 頭 一 步	籽 粒	籽 棉	紅 了	紅 人	紅 人 隊	紅 十 字	紅 十 字 會	
紅 土	紅 小 兵	紅 丹	紅 五 軍 團	紅 六 軍 團	紅 心	紅 日	紅 日 三 竿	
紅 木	紅 毛	紅 水 晶	紅 火	紅 包	紅 外	紅 外 技 術	紅 外 測 距	
紅 外 對 抗	紅 外 熱 像 儀	紅 外 線	紅 布	紅 白	紅 白 喜 事	紅 皮	紅 光	
紅 光 滿 面	紅 字	紅 色	紅 色 政 權	紅 血 球	紅 衣	紅 利	紅 妝	
紅 彤 彤	紅 杏 出 牆	紅 杉	紅 杉 木	紅 男 綠 女	紅 豆	紅 豆 相 思	紅 果	
紅 松	紅 河	紅 油	紅 的	紅 股	紅 花	紅 星	紅 柳	
紅 紅	紅 軍	紅 原	紅 娘	紅 案	紅 海	紅 粉	紅 粉 青 蛾	
紅 粉 青 樓	紅 茶	紅 衰 綠 減	紅 酒	紅 專	紅 得 發 紫	紅 梅	紅 眼	
紅 眼 病	紅 眼 圈	紅 細 胞	紅 袖 添 香	紅 透	紅 雀	紅 雀 隊	紅 魚	
紅 麻	紅 場	紅 帽 子	紅 斑	紅 棗	紅 椒	紅 牌	紅 絲 待 選	
紅 絲 暗 系	紅 著 臉	紅 愁 綠 慘	紅 暈	紅 極 一 時	紅 腸	紅 腫	紅 葉	
紅 葉 之 題	紅 葡 萄 酒	紅 塵	紅 塵 客 夢	紅 旗	紅 旗 手	紅 旗 報 捷	紅 旗 競 賽	
紅 榜	紅 種	紅 綠	紅 綠 燈	紅 綢	紅 腐 貫 朽	紅 與 黑	紅 銅	
紅 領 巾	紅 撲 撲	紅 樓	紅 樓 夢	紅 潮	紅 潤	紅 熱	紅 瘦 綠 肥	
紅 線	紅 衛 兵	紅 褐	紅 褐 色	紅 輝	紅 鞋	紅 髮	紅 學	
紅 橙 色	紅 樹	紅 樹 林	紅 燒	紅 燈	紅 磚	紅 糖	紅 頭 髮	
紅 燭	紅 磷	紅 臉	紅 薯	紅 霞	紅 藍	紅 顏	紅 顏 薄 命	
紅 藥 水	紅 壤	紅 寶 石	紅 礬	紅 櫻 槍	紅 襪 隊	紅 纓	紅 蘿 蔔	
紅 黴 素	紅 艷	紅 艷 艷	紅 苕	紀 元	紀 年	紀 行	紀 事	
紀 委	紀 念	紀 念 日	紀 念 冊	紀 念 物	紀 念 品	紀 念 封	紀 念 活 動	
紀 念 堂	紀 念 章	紀 念 郵 票	紀 念 塔	紀 念 會	紀 念 碑	紀 念 館	紀 律	
紀 律 性	紀 律 科	紀 律 處 分	紀 律 整 頓	紀 律 嚴 明	紀 要	紀 效 新 書	紀 傳 體	
紀 實	紀 實 小 說	紀 實 文 學	紀 綱	紀 綱 人 倫	紀 層	紀 曉 君	紀 錄	
紀 錄 片	紀 錄 影 片	紀 檢	紀 檢 委	紇 字 不 識	約 人	約 之	約 分	
約 他	約 占	約 去	約 旦	約 旦 人	約 旦 河	約 同	約 在	
約 好	約 成	約 有	約 束	約 束 力	約 見	約 言	約 定	
約 定 俗 成	約 法	約 法 三 章	約 者	約 為	約 計	約 值	約 晤	
約 略	約 莫	約 期	約 集	約 會	約 瑟 夫	約 摸	約 需	
約 數	約 稿	約 談	約 請	約 翰	約 翰 遜	紆 子	紆 介 不 遺	
紆 朱 懷 金	紆 青 拖 紫	紆 尊 降 貴	缸 瓦	缸 盆	缸 裡	缸 蓋	缸 體	
美 了	美 人	美 人 計	美 人 香 草	美 人 魚	美 人 遲 暮	美 口 語	美 女	
美 女 破 舌	美 女 簪 花	美 工	美 才	美 不 美	美 不 勝 收	美 中	美 中 不 足	
美 元	美 分	美 化	美 方	美 日	美 加	美 玉	美 玉 無 瑕	
美 目	美 光 科 技	美 名	美 好	美 好 生 活	美 如	美 如 冠 玉	美 式	
美 式 足 球	美 式 傢 俱	美 死	美 色	美 衣 玉 食	美 西	美 西 部	美 利 堅	
美 利 達	美 吾 華	美 妙	美 男 破 老	美 育	美 言	美 言 不 信	美 足 球	
美 邦 證 券	美 事	美 亞 鋼 管	美 其	美 其 名 曰	美 味	美 味 佳 餚	美 服	
美 的	美 金	美 俚	美 冠	美 南 部	美 姿	美 律 實 業	美 洲	
美 洲 股 市	美 洲 虎	美 洲 豹	美 洲 國 家	美 洲 獅	美 派	美 眉	美 美	
美 英	美 軍	美 食	美 食 主 義	美 食 甘 寢	美 食 法	美 食 者	美 食 家	
美 食 展	美 食 學	美 容	美 容 師	美 容 業	美 展	美 差	美 栗	
美 格 科 技	美 氣	美 神	美 能 達	美 酒	美 院	美 國	美 國 人	
美 國 中 央 情 報 局	美 國 化	美 國 兵	美 國 佬	美 國 股 市	美 國 政 治	美 國 陸 軍 部	美 國 華 人	
美 國 運 通 銀 行	美 國 銀 行	美 國 線 上	美 國 總 統	美 國 職 棒	美 術	美 術 片	美 術 品	
美 術 界	美 術 家	美 術 館	美 景	美 景 良 辰	美 滋 滋	美 鈔	美 隆 電 器	
美 傳	美 意	美 意 延 年	美 感	美 詩	美 飾	美 僑	美 夢	
美 歌	美 滿	美 稱	美 語	美 貌	美 德	美 獎	美 談	
美 質	美 輪 美 奐	美 學	美 學 家	美 濃	美 餐	美 聯 社	美 顏	
美 麗	美 麗 島 事 件	美 麗 動 人	美 籍	美 籍 華 人	美 譽	美 艷	美 觀	
美 觀 大 方	耄 耋	耐 人	耐 人 尋 味	耐 力	耐 久	耐 久 力	耐 久 性	
耐 心	耐 火	耐 火 磚	耐 用	耐 用 品	耐 用 消 費 品	耐 光	耐 住	
耐 抗	耐 旱	耐 受	耐 性	耐 洗	耐 穿	耐 苦	耐 風	
耐 風 雨	耐 飛	耐 飛 性	耐 航	耐 勞	耐 寒	耐 著 性 子	耐 煩	
耐 酸	耐 熱	耐 震	耐 震 度	耐 燙	耐 磨	耐 磨 性	耐 壓	
耐 饑	耐 曬	耐 變	耐 鹼	耍 心 眼	耍 弄	耍 花 招	耍 派	
耍 耍	耍 笑	耍 蛇	耍 筆 桿 子	耍 態 度	耍 鬧	耍 賴	耶 人	
耶 和	耶 和 華	耶 酥	耶 路	耶 誕	耶 誕 節	耶 魯	耶 穌	
耶 穌 會	胖 子	胖 乎 乎	胖 的	胖 胖	胖 墩 墩	胖 瘦	胚 子	
胚 孔	胚 布	胚 乳	胚 芽	胚 後 發 育	胚 胎	胚 胎 學	胚 根	
胚 珠	胚 軸	胚 葉	胚 種	胚 層	胚 盤	胚 膜	胚 囊	
胚 體	胃 下 垂	胃 口	胃 中	胃 內	胃 灼 熱	胃 炎	胃 病	
胃 液	胃 液 素	胃 部	胃 痛	胃 舒 平	胃 腸	胃 腸 炎	胃 腺	
胃 酸	胃 潰 瘍	胃 壁	胃 癌	胃 藥	胃 鏡	背 上	背 山 起 樓	
背 井	背 井 離 鄉	背 心	背 心 褲	背 水 一 戰	背 水 擊	背 出	背 包	
背 包 袱	背 生 芒 刺	背 光	背 光 式	背 光 性	背 向	背 地	背 地 裡	
背 的	背 信	背 信 忘 義	背 信 棄 義	背 叛	背 城 一 戰	背 城 借 一	背 後	
背 後 議 論	背 約	背 若 芒 刺	背 負	背 面	背 風	背 恩 忘 義	背 時	
背 書	背 疼	背 脊	背 脊 骨	背 起	背 骨	背 側	背 帶	
背 斜	背 棄	背 理	背 袋	背 部	背 陰	背 景	背 景 牆	
背 椅	背 痛	背 紫 腰 金	背 著	背 街	背 飯	背 黑 鍋	背 債	
背 暗 投 明	背 義 忘 恩	背 運	背 道 而 馳	背 過	背 馳	背 對 背	背 誦	
背 誓	背 影	背 槽 拋 糞	背 熟	背 靠	背 靠 背	背 牆	背 簍	
背 謬	背 離	背 簽	背 籃	背 鰭	背 囊	胡 人	胡 天 胡 帝	
胡 瓜	胡 同	胡 吃	胡 作 非 為	胡 吹	胡 弄	胡 志 明 市	胡 志 強	
胡 扯	胡 言	胡 言 亂 語	胡 言 漢 語	胡 豆	胡 來	胡 定 華	胡 服	
胡 思	胡 思 亂 量	胡 思 亂 想	胡 風	胡 借	胡 家	胡 桃	胡 桃 木	
胡 桃 色	胡 桃 樹	胡 椒	胡 琴	胡 亂	胡 搞	胡 話	胡 圖	
胡 說	胡 說 八 道	胡 說 白 道	胡 說 亂 道	胡 說 亂 講	胡 慧 中	胡 編 亂 造	胡 蝶	
胡 適	胡 鬧	胡 纏	胡 攪	胡 攪 蠻 纏	胡 蘿 蔔	胡 蘿 蔔 素	胡 笳	
胡 謅	胎 中	胎 內	胎 毛	胎 外	胎 生	胎 生 學	胎 位	
胎 兒	胎 兒 學	胎 毒	胎 面	胎 氣	胎 記	胎 教	胎 痣	
胎 發	胎 盤	胎 膜	胎 爆	胞 子	胞 兄	胞 衣	胞 弟	
胞 叔	胞 妹	胞 姐	胞 波	胞 狀	胞 芽	胞 胚	胞 胎	
胞 蟲	胞 囊	致 力	致 力 於	致 上	致 公 黨	致 以	致 用	
致 好	致 死	致 伸 實 業	致 冷	致 使	致 函	致 和	致 命	
致 於	致 信	致 哀	致 茂 電 子	致 書	致 病	致 病 性	致 祝 詞	
致 勝	致 富	致 殘	致 詞	致 賀	致 傷	致 意	致 敬	
致 敬 意	致 敬 禮	致 電	致 歉	致 福 電 子	致 遠 任 重	致 癌	致 謝	
致 禮	致 辭	致 歡	舢 板	苧 麻	范 姓 宗 親 會	范 張 雞 黍	范 巽 綠	
范 曉 萱	茅 台	茅 台 酒	茅 利 塔 尼 亞	茅 坑	茅 房	茅 舍	茅 室 土 階	
茅 屋	茅 盾	茅 草	茅 茨 土 階	茅 廁	茅 棚	茅 塞	茅 塞 頓 開	
茅 廬	茅 蘆 三 顧	苛 斥	苛 吏	苛 求	苛 刻	苛 征	苛 性 鈉	
苛 性 鉀	苛 性 鹼	苛 待	苛 政	苛 政 猛 於 虎	苛 捐	苛 捐 雜 稅	苛 細	
苛 責	苛 評	苛 評 家	苛 斂	苛 薄	苦 人	苦 力	苦 口	
苦 口 逆 耳	苦 口 婆 心	苦 大 仇 深	苦 工	苦 不 可 言	苦 不 聊 生	苦 不 堪 言	苦 中 作 樂	
苦 心	苦 心 孤 詣	苦 心 焦 思	苦 心 極 力	苦 心 經 營	苦 心 竭 力	苦 水	苦 功	
苦 汁	苦 瓜	苦 守	苦 肉 計	苦 艾 酒	苦 行	苦 行 僧	苦 役	
苦 求	苦 事	苦 味	苦 味 酸	苦 命	苦 怔 惡 戰	苦 於	苦 果	
苦 爭 惡 戰	苦 的	苦 花	苦 雨 淒 風	苦 思	苦 思 苦 想	苦 思 冥 想	苦 思 惡 想	
苦 活	苦 相	苦 苦	苦 苦 哀 求	苦 苓	苦 修	苦 差	苦 差 事	
苦 海	苦 海 茫 茫	苦 海 無 涯	苦 海 無 邊	苦 笑	苦 衷	苦 酒	苦 鬥	
苦 掙	苦 累	苦 處	苦 鹵	苦 寒	苦 悶	苦 惱	苦 痛	
苦 幹	苦 感	苦 想	苦 愛	苦 楚	苦 話	苦 僧	苦 境	
苦 盡	苦 盡 甘 來	苦 盡 甜 來	苦 盡 焦 思	苦 辣	苦 樂	苦 熬	苦 練	
苦 學	苦 戰	苦 頭	苦 戲	苦 澀	苦 膽	苦 臉	苦 薄 荷	
苦 難	苦 勸	苦 讀	苦 戀	茄 子	茄 克	茄 克 衫	茄 萣	
茄 萣 鄉	若 乃 花	若 干	若 干 個	若 不	若 且	若 以	若 出 一 轍	
若 合 符 節	若 在	若 有	若 有 所 亡	若 有 所 失	若 有 所 思	若 有 所 喪	若 何	
若 你	若 即 若 離	若 使	若 明 若 暗	若 果	若 非	若 按	若 昧 平 生	
若 是	若 為	若 要	若 時	若 真	若 問	若 將	若 敖 鬼 餒	
若 喪 考 妣	若 無	若 無 其 事	若 想	若 數 家 珍	若 隱 若 現	若 隱 若 顯	若 騖	
若 釋 重 負	若 饑 若 渴	茂 名	茂 竹	茂 林	茂 林 鄉	茂 密	茂 盛	
茂 實 英 聲	茂 德 科 技	茉 莉	茉 莉 花	茉 莉 花 茶	苗 人	苗 子	苗 木	
苗 而 不 秀	苗 床	苗 兒	苗 芽	苗 苗	苗 圃	苗 栗	苗 族	
苗 族 人	苗 條	苗 期	苗 距	苗 裔	苗 種	苗 頭	苗 豐 強	
英 人	英 子	英 寸	英 才	英 尺	英 尺 高	英 文	英 方	
英 王	英 史	英 名	英 年	英 式	英 式 足 球	英 里	英 兩	
英 制	英 明	英 武	英 法	英 俊	英 俚	英 勇	英 勇 鬥 爭	
英 勇 善 戰	英 勇 獻 身	英 姿	英 姿 颯 爽	英 姿 邁 往	英 美	英 軍	英 倫	
英 哩	英 格 蘭	英 格 蘭 人	英 氣	英 烈	英 特	英 特 爾	英 特 網	
英 特 邁 往	英 畝	英 畝 數	英 國	英 國 人	英 國 女 王	英 國 式	英 貨 幣	
英 傑	英 華	英 雄	英 雄 人 物	英 雄 主 義	英 雄 式	英 雄 有 用 武 之 地	英 雄 形 象	
英 雄 事 跡	英 雄 所 見 略 同	英 雄 氣 短	英 雄 無 用 武 之 地	英 雄 短 氣	英 雄 模 範	英 雄 輩 出	英 業 達	
英 漢	英 漢 通	英 誌 企	英 誌 企 業	英 語	英 語 化	英 語 學	英 豪	
英 魂	英 德	英 模	英 模 代 表	英 模 事 跡	英 擔	英 聲 茂 實	英 聯 邦	
英 鎊	英 譯 本	英 屬	英 靈	茁 壯	茁 壯 成 長	茁 長 素	茁 實	
苜 蓿	苔 衣	苔 絲	苔 蘚	苔 癬	苑 裡	苞 米	苞 谷	
苞 藏 禍 心	苞 苴 公 行	苞 苴 竿 牘	苞 苴 賄 賂	苓 雅 區	苟 且	苟 且 偷 生	苟 且 偷 安	
苟 同	苟 合	苟 合 取 容	苟 安	苟 安 一 隅	苟 延 殘 息	苟 延 殘 喘	苟 活	
苟 留 殘 喘	苯	苯 乙 烯	苯 乙 烯 丁 二 烯	苯 甲 基	苯 甲 酸	苯 氨	苯 基	
苯 環	苯 胺	苯 酚	虐 子 孤 臣	虐 打	虐 刑	虐 待	虐 待 狂	
虐 待 症	虐 疾	虐 殺	虐 童 案	虹 口	虹 光 精 密	虹 吸	虹 吸 管	
虹 膜	虹 橋	虹 鱒	衍 生	衍 生 物	衍 射	衍 變	要 人	
要 不	要 不 是	要 不 要	要 不 得	要 不 就	要 不 然	要 以	要 犯	
要 用	要 由	要 目	要 件	要 同	要 吐	要 向	要 吃	
要 回	要 地	要 地 防 空	要 多	要 好	要 好 成 歉	要 旨	要 有	
要 死	要 死 不 活	要 而 不 言	要 找	要 求	要 求 者	要 沖	要 見	
要 言 不 煩	要 言 妙 道	要 事	要 使	要 來	要 到	要 和	要 命	
要 物	要 的	要 者	要 花	要 則	要 勁	要 勁 兒	要 是	
要 津	要 洗	要 看	要 倒	要 哭	要 員	要 害	要 害 之 地	
要 挾	要 案	要 素	要 能	要 務	要 將	要 帳	要 強	
要 得	要 從	要 略	要 訣	要 就	要 無	要 等	要 給	
要 買	要 飯	要 塞	要 塌	要 意	要 想	要 義	要 跟	
要 道	要 隘	要 圖	要 對	要 緊	要 聞	要 與	要 說	
要 領	要 麼	要 價	要 請	要 錢	要 臉	要 還	要 點	
要 職	要 寵 召 禍	觔 斗	計 入	計 上	計 上 心 來	計 上 心 頭	計 工	
計 不 旋 踵	計 分	計 日 而 俟	計 日 而 待	計 日 奏 功	計 日 程 功	計 付	計 出 萬 全	
計 功 行 賞	計 功 受 賞	計 功 受 爵	計 功 補 過	計 生	計 件	計 件 工 資	計 在	
計 收	計 有	計 行 慮 義	計 步 器	計 取	計 委	計 征	計 表	
計 為	計 秒	計 秒 錶	計 息	計 時	計 時 工 資	計 時 員	計 時 器	
計 將 安 出	計 深 慮 遠	計 速	計 勞 納 封	計 提	計 無 所 出	計 無 所 施	計 畫	
計 發	計 程	計 程 車	計 程 表	計 程 儀	計 程 器	計 稅	計 策	
計 費	計 量	計 量 局	計 量 法	計 量 者	計 量 竿	計 量 單 位	計 量 經 濟 學	
計 量 器	計 量 學	計 會	計 經 委	計 較	計 過	計 過 自 訟	計 酬	
計 劃	計 劃 內	計 劃 司	計 劃 外	計 劃 生 育	計 劃 委 員 會	計 劃 性	計 劃 者	
計 劃 表	計 劃 指 標	計 劃 書	計 劃 商 品 經 濟	計 劃 等	計 劃 經 濟	計 劃 體 制	計 塵 器	
計 盡	計 盡 力 窮	計 算	計 算 中 心	計 算 尺	計 算 所	計 算 者	計 算 站	
計 算 器	計 算 機	計 價	計 數	計 數 器	計 窮	計 窮 力 屈	計 窮 力 極	
計 窮 力 盡	計 窮 力 竭	計 窮 途 拙	計 窮 勢 蹙	計 銷	計 謀	計 議	訂 下	
訂 戶	訂 出	訂 本	訂 正	訂 立	訂 合 同	訂 有	訂 位	
訂 作	訂 定	訂 於	訂 金	訂 契	訂 為	訂 約	訂 座	
訂 書 釘	訂 書 機	訂 做	訂 婚	訂 婚 禮	訂 票 中 心	訂 貨	訂 貨 單	
訂 貨 會	訂 單	訂 報	訂 過 婚	訂 製	訂 價	訂 閱	訂 親	
訂 餐	訂 購	訃 文	訃 告	訃 聞	貞 女	貞 夫 烈 婦	貞 風 亮 節	
貞 烈	貞 高 絕 俗	貞 婦	貞 節	貞 德	貞 潔	貞 操	貞 觀 政 要	
負 土 成 墳	負 山 戴 岳	負 才 任 氣	負 才 使 氣	負 反 饋	負 心	負 心 人	負 心 違 願	
負 方	負 片	負 石 赴 河	負 有	負 有 重 任	負 有 責 任	負 老 提 幼	負 固 不 服	
負 固 不 悛	負 屈 含 冤	負 屈 銜 冤	負 弩 前 驅	負 性	負 於	負 疚	負 指 數	
負 盈	負 約	負 重	負 重 致 遠	負 重 涉 遠	負 面	負 乘 致 寇	負 值	
負 差	負 效 應	負 氣	負 氣 仗 義	負 氧	負 荊 請 罪	負 起	負 荷	
負 荷 者	負 責	負 責 人	負 責 任	負 責 同 志	負 責 制	負 責 幹 部	負 隅 頑 抗	
負 項	負 債	負 債 纍 纍	負 傷	負 極	負 罪	負 義 忘 恩	負 號	
負 載	負 電	負 電 子	負 電 荷	負 鼎 之 願	負 圖 之 托	負 數	負 擔	
負 擔 量	負 擔 過 重	負 壓	負 薪 之 疾	負 薪 之 病	負 薪 之 資	負 薪 之 憂	負 薪 之 議	
負 薪 救 火	負 虧	負 離 子	負 笈	負 笈 擔 簦	赴 火 蹈 刃	赴 叩	赴 任	
赴 死	赴 死 如 歸	赴 考	赴 約	赴 宴	赴 湯 投 火	赴 湯 跳 火	赴 湯 蹈 火	
赴 會	赴 試	赴 蹈 湯 火	赴 難	赳 赳	赳 赳 武 夫	趴 下	趴 在	
軍 人	軍 人 地 位	軍 人 修 養	軍 人 倫 理	軍 人 道 德	軍 人 優 撫	軍 刀	軍 力	
軍 士	軍 士 制 度	軍 工	軍 工 生 產	軍 工 企 業	軍 工 產 品	軍 不 血 刃	軍 中	
軍 分 區	軍 屯	軍 心	軍 方	軍 火	軍 火 公 司	軍 火 交 易	軍 火 庫	
軍 火 商	軍 火 貿 易	軍 犬	軍 代 表	軍 令	軍 令 如 山	軍 令 狀	軍 功	
軍 史	軍 史 知 識	軍 民	軍 民 一 致	軍 民 團 結	軍 用	軍 地	軍 多 將 廣	
軍 衣	軍 兵 種	軍 車	軍 事	軍 事 上	軍 事 化	軍 事 委 員 會	軍 事 家	
軍 事 區	軍 事 基 地	軍 事 演 習	軍 事 學	軍 制	軍 制 史	軍 委	軍 委 主 席	
軍 委 各 總 部	軍 官	軍 官 室	軍 服	軍 法	軍 法 從 事	軍 長	軍 品	
軍 品 採 購	軍 姿	軍 威	軍 政	軍 政 大 學	軍 政 府	軍 界	軍 紀	
軍 風	軍 風 紀	軍 容	軍 容 風 紀	軍 師	軍 旅	軍 校	軍 烈 屬	
軍 訓	軍 馬	軍 務	軍 務 工 作	軍 區	軍 售	軍 國	軍 國 化	
軍 國 主 義	軍 國 主 義 者	軍 情	軍 情 局	軍 械	軍 械 庫	軍 略	軍 眷	
軍 統	軍 統 局	軍 規	軍 部	軍 備	軍 備 控 制	軍 備 競 賽	軍 帽	
軍 援	軍 棋	軍 毯	軍 港	軍 費	軍 費 開 支	軍 費 預 算	軍 郵	
軍 隊	軍 隊 化	軍 隊 式	軍 階	軍 群	軍 號	軍 裝	軍 靴	
軍 鼓	軍 團	軍 旗	軍 歌	軍 種	軍 種 體 制	軍 管	軍 管 會	
軍 語	軍 語 詞 典	軍 銜	軍 銜 制	軍 閥	軍 閥 混 戰	軍 需	軍 需 官	
軍 需 品	軍 需 部	軍 餉	軍 樂	軍 樂 隊	軍 調 部	軍 鞋	軍 墾	
軍 操	軍 機	軍 機 處	軍 辦	軍 徽	軍 營	軍 總	軍 臨 城 下	
軍 購	軍 禮	軍 糧	軍 職	軍 轉 民	軍 醫	軍 醫 大 學	軍 醫 學 院	
軍 籍	軍 艦	軍 警	軍 齡	軍 屬	軍 權	軌 桿	軌 距	
軌 跡	軌 跡 線	軌 道	軌 範	述 及	述 心	述 作	述 法	
述 評	述 詞	述 語	述 說	述 論	述 職	迢 而 不 作	迢 迢	
迢 迢 千 里	迪 士 尼	迪 拜	迪 斯 尼	迪 斯 科	迥 乎 不 同	迥 迥	迥 異	
迥 然	迥 然 不 同	迥 隔 霄 壤	迭 片	迭 代	迭 加	迭 次	迭 見 雜 出	
迭 起	迭 蓋	迭 層	迭 影	迭 蕩 放 言	迫 不 及 待	迫 不 急 待	迫 不 得 已	
迫 切	迫 切 希 望	迫 切 性	迫 切 要 求	迫 切 需 要	迫 令	迫 在	迫 在 眉 睫	
迫 至	迫 使	迫 於	迫 於 眉 睫	迫 近	迫 降	迫 害	迫 害 者	
迫 問	迫 緊	迫 敵	迫 擊 炮	迤 邐	迤 邐 不 絕	郊 外	郊 區	
郊 野	郊 寒 島 瘦	郊 遊	郊 縣	郎 才 女 姿	郎 才 女 貌	郎 中	郎 月 清 風	
郎 目 疏 眉	郎 君	郎 神	郎 溪	郎 當	郎 舅	郁 血	郁 烈	
郁 滯	酋 長	酋 長 國	重 入	重 力	重 力 加 速 度	重 力 場	重 又	
重 土	重 大	重 大 手 術	重 大 疾 病	重 山 峻 嶺	重 工	重 工 業	重 心	
重 心 低	重 文	重 水	重 刊	重 打	重 犯	重 生	重 生 父 母	
重 用	重 申	重 石	重 任	重 光	重 光 累 洽	重 刑	重 印	
重 名	重 合	重 回	重 地	重 好	重 成	重 托	重 考	
重 臣	重 行	重 估	重 作	重 兵	重 利	重 利 忘 義	重 利 罪	
重 利 盤 剝	重 孝	重 抄	重 步 走	重 災	重 男 輕 女	重 肚 天 日	重 見	
重 見 天 日	重 言	重 走	重 足 而 立	重 來	重 典	重 制	重 命 名	
重 定	重 定 向	重 拍	重 放	重 於	重 於 泰 山	重 東 西	重 武	
重 武 器	重 法	重 油	重 版	重 物	重 的	重 者	重 返	
重 返 家 園	重 金	重 金 屬	重 金 屬 音 樂	重 門 擊 柝	重 則	重 厚 少 文	重 型	
重 型 機 車	重 奏	重 奏 曲	重 建	重 建 家 園	重 拾	重 映	重 染	
重 洗 牌	重 活	重 炮	重 要	重 要 文 件	重 要 性	重 要 的	重 計	
重 訂	重 負	重 軌	重 述	重 迭	重 重	重 重 困 難	重 音	
重 修	重 孫	重 拳	重 振	重 振 旗 鼓	重 挫	重 核 子	重 氣 輕 身	
重 病	重 症	重 砲 手	重 級	重 記	重 做	重 商	重 唱	
重 婚	重 婚 者	重 將	重 得	重 情	重 排	重 晚	重 望	
重 氫	重 氫 子	重 現	重 組	重 規 迭 矩	重 規 累 矩	重 訪	重 設	
重 造	重 逢	重 創	重 圍	重 場	重 描	重 提	重 晶 石	
重 畫	重 發	重 稅	重 視	重 評	重 貼	重 量	重 量 級	
重 開	重 陽	重 傳	重 傷	重 塑	重 填	重 想	重 新	
重 新 認 識	重 溫	重 溫 舊 業	重 溫 舊 夢	重 置	重 罪	重 罪 人	重 罪 犯	
重 義	重 義 輕 生	重 義 輕 財	重 落	重 裝	重 試	重 話	重 載	
重 農	重 遊	重 達	重 酬	重 電 子	重 劃	重 實 效	重 敲	
重 演	重 熙 累 洽	重 碳	重 算	重 罰	重 聚	重 說	重 價	
重 劍	重 審	重 寫	重 寫 本	重 彈	重 慶	重 慶 市	重 撥	
重 播	重 獎	重 磅	重 碼	重 編	重 複	重 複 句	重 複 性	
重 複 者	重 複 說	重 調	重 賞	重 賞 之 下 必 有 勇 夫	重 賦	重 賭	重 踏	
重 遷	重 操 舊 業	重 擔	重 整	重 整 旗 鼓	重 機	重 機 槍	重 機 關 鎗	
重 辦	重 選	重 頭	重 頭 戲	重 壓	重 擊	重 獲	重 臂	
重 臨	重 講	重 賽	重 蹈	重 蹈 覆 轍	重 還	重 錘	重 點	
重 點 工 作	重 點 工 程	重 點 企 業	重 點 保 護	重 點 建 設 項 目	重 點 單 位	重 點 項 目	重 繞	
重 覆	重 鎮	重 懲	重 繭	重 譯	重 疊	重 聽	重 讀	
重 鑄	重 鹽	重 茬	重 粘 土	閂 上	閂 住	閂 門	閂 掩	
閂 鎖	限 內	限 止	限 令	限 地	限 此	限 位	限 制	
限 制 性	限 制 級	限 制 區	限 制 器	限 定	限 定 性	限 定 詞	限 於	
限 武 談 判	限 長	限 度	限 流	限 派	限 界	限 值	限 時	
限 產	限 產 壓 庫	限 幅	限 期	限 期 完 成	限 量	限 電	限 價	
限 購	限 額	陋 地	陋 行	陋 見	陋 俗	陋 室	陋 屋	
陋 巷	陋 巷 簞 瓢	陋 習	陋 規	陋 寡	陌 生	陌 生 人	陌 乖	
陌 路	陌 路 相 逢	降 下	降 下 帷 幕	降 升	降 心 相 從	降 水	降 水 量	
降 火	降 世	降 生	降 伏	降 至	降 位	降 低	降 低 成 本	
降 低 消 耗	降 妖	降 序	降 志 辱 身	降 到	降 服	降 法	降 雨	
降 雨 量	降 度	降 為	降 值	降 書	降 格	降 格 一 求	降 格 以 求	
降 神	降 神 術	降 級	降 將	降 雪	降 雪 量	降 幅	降 等	
降 貴 紆 尊	降 量	降 順	降 溫	降 落	降 落 傘	降 旗	降 福	
降 禍	降 禍 於	降 價	降 調	降 賜	降 冪	降 龍	降 龍 伏 虎	
降 壓	降 臨	降 臨 到	降 職	降 靈	面 人	面 下	面 上	
面 子	面 子 上	面 巾	面 不 改 色	面 友	面 孔	面 手	面 世	
面 北 眉 南	面 斥	面 生	面 皮	面 皮 薄	面 目	面 目 一 新	面 目 可 憎	
面 目 全 非	面 交	面 向	面 向 前	面 如 土 色	面 如 灰 土	面 如 冠 玉	面 如 桃 花	
面 有 菜 色	面 有 難 色	面 色	面 色 如 土	面 似	面 呈	面 告	面 折 廷 爭	
面 見	面 具	面 卷	面 和 心 不 和	面 命 相 提	面 板	面 泛	面 的	
面 前	面 奏	面 洽	面 派	面 為	面 盆	面 相	面 紅	
面 紅 耳 赤	面 面	面 面 相 窺	面 面 相 覷	面 面 俱 到	面 面 廝 覷	面 面 觀	面 值	
面 倒	面 容	面 料	面 書	面 站	面 紗	面 紙	面 商	
面 帶	面 帶 笑 容	面 帶 難 色	面 授	面 授 機 宜	面 晤	面 票	面 部	
面 陳	面 朝	面 無 人 色	面 善	面 象	面 黃	面 黃 肌 瘦	面 黃 葫 蘆	
面 稟	面 罩	面 試	面 試 者	面 像	面 嫩	面 對	面 對 面	
面 對 面 地	面 對 現 實	面 語	面 貌	面 貌 一 新	面 寬	面 層	面 廣	
面 影	面 熟	面 膜	面 談	面 壁	面 壁 功 深	面 壁 思 過	面 磚	
面 積	面 積 分	面 積 圖	面 縛 銜 璧	面 縛 輿 櫬	面 諭	面 頰	面 牆	
面 牆 而 立	面 臨	面 謝	面 邀	面 霜	面 額	面 龐	面 議	
面 譽 背 毀	面 露	面 體	革 凡 登 聖	革 心	革 匠	革 命	革 命 化	
革 命 史	革 命 志 士	革 命 性	革 命 者	革 命 派	革 命 軍	革 命 家	革 委 會	
革 故 鼎 新	革 面 洗 心	革 除	革 新	革 新 者	革 新 能 手	革 製 品	革 職	
革 舊 鼎 新	韋 氏	韋 布 匹 夫	韋 伯	韋 編 三 絕	韭 菜	韭 黃	音 叉	
音 大	音 名	音 色	音 位	音 序	音 序 器	音 步	音 協	
音 波	音 波 計	音 表	音 長	音 信	音 信 全 無	音 信 杳 無	音 信 杳 然	
音 型	音 度	音 律	音 美	音 准	音 容	音 容 如 在	音 容 宛 在	
音 容 笑 貌	音 容 淒 斷	音 師	音 效	音 栓	音 素	音 耗 不 絕	音 訊	
音 訊 杳 然	音 高	音 區	音 問 兩 絕	音 問 杳 然	音 問 相 繼	音 域	音 帶	
音 符	音 速	音 部	音 程	音 稀 信 杳	音 量	音 量 控 制	音 階	
音 感	音 節	音 義	音 鼓	音 像	音 障	音 標	音 樂	
音 樂 上	音 樂 性	音 樂 界	音 樂 家	音 樂 般	音 樂 會	音 樂 節 目	音 樂 劇	
音 樂 學	音 樂 廳	音 碼	音 箱	音 調	音 調 高	音 質	音 壁	
音 頻	音 聲 如 鐘	音 韻	音 韻 學	音 譯	音 響	音 響 好	音 響 器	
音 響 學	音 變	頁 次	頁 角	頁 長	頁 眉	頁 面	頁 書	
頁 符	頁 腳	頁 號	頁 寬	頁 數	頁 碼	頁 邊	頁 邊 距	
頁 巖	風 刀 霜 劍	風 力	風 力 計	風 口	風 口 浪 尖	風 土	風 土 人 情	
風 土 民 情	風 大	風 不 鳴 條	風 中	風 中 之 燭	風 中 秉 燭	風 公 正 己	風 化	
風 化 案	風 化 案 件	風 斗	風 月	風 月 常 新	風 月 無 邊	風 木 之 思	風 木 之 悲	
風 木 含 悲	風 水	風 火	風 火 輪	風 平	風 平 波 息	風 平 波 靜	風 平 浪 跡	
風 平 浪 靜	風 光	風 光 旖 旎	風 向	風 向 草 偃	風 向 標	風 帆	風 成 化 習	
風 色	風 行	風 行 一 時	風 行 水 上	風 行 草 偃	風 行 草 從	風 行 草 靡	風 行 雲 蒸	
風 行 雷 厲	風 行 電 擊	風 衣	風 似	風 兵 草 甲	風 吹	風 吹 日 曬	風 吹 雨 打	
風 吹 浪 打	風 吹 草 動	風 沙	風 災	風 言	風 言 俏 語	風 言 風 語	風 言 醋 語	
風 車	風 車 雨 馬	風 車 雲 馬	風 來	風 味	風 味 小 吃	風 和 日 美	風 和 日 暖	
風 和 日 暄	風 和 日 麗	風 尚	風 波	風 波 平 地	風 油 精	風 物	風 知	
風 花 雪 月	風 虎 雲 龍	風 采	風 門	風 雨	風 雨 不 改	風 雨 不 透	風 雨 交 加	
風 雨 同 舟	風 雨 如 晦	風 雨 如 磐	風 雨 時 若	風 雨 晦 暝	風 雨 淒 淒	風 雨 無 阻	風 雨 對 床	
風 雨 蕭 條	風 雨 飄 搖	風 信 旗	風 俗	風 俗 人 情	風 俗 民 情	風 俗 習 慣	風 前 月 下	
風 城	風 姿	風 度	風 度 好	風 恬 浪 靜	風 流	風 流 人 物	風 流 千 古	
風 流 才 子	風 流 佳 事	風 流 雨 散	風 流 宰 相	風 流 雲 散	風 流 罪 過	風 流 爾 雅	風 流 儒 雅	
風 流 醞 藉	風 流 瀟 灑	風 流 韻 事	風 流 蘊 藉	風 流 倜 儻	風 洞	風 派	風 泵	
風 紀	風 紀 扣	風 風 火 火	風 風 雨 雨	風 風 韻 韻	風 飛 雲 會	風 哮 雨 嚎	風 扇	
風 格	風 氣	風 浪	風 浪 板	風 疹	風 級	風 起	風 起 雲 布	
風 起 雲 湧	風 起 潮 湧	風 馬 不 接	風 馬 牛	風 馬 牛 不 相 及	風 馬 雲 車	風 骨	風 骨 峭 峻	
風 乾	風 動	風 圈	風 從 虎 雲 從 龍	風 從 響 應	風 情	風 情 月 思	風 情 月 債	
風 情 月 意	風 捲 殘 雪	風 捲 殘 雲	風 掃	風 涼	風 涼 話	風 清 月 白	風 清 月 明	
風 清 月 朗	風 清 月 皎	風 清 弊 絕	風 移 俗 改	風 移 俗 易	風 移 俗 變	風 笛	風 笛 曲	
風 速	風 速 表	風 速 計	風 雪	風 鳥	風 喚	風 寒	風 帽	
風 掣 雷 行	風 景	風 景 如 畫	風 景 秀 麗	風 景 區	風 景 勝	風 景 畫	風 景 優 美	
風 景 點	風 琴	風 琴 手	風 發	風 華	風 華 正 茂	風 量	風 雅	
風 雲	風 雲 人 物	風 雲 不 測	風 雲 之 志	風 雲 月 露	風 雲 叱 吒	風 雲 突 變	風 雲 開 闔	
風 雲 際 會	風 雲 變 幻	風 雲 變 態	風 順	風 飧 水 宿	風 飧 露 宿	風 傳	風 勢	
風 微 浪 穩	風 暖 日 麗	風 煙	風 痺	風 葉	風 裡	風 裡 楊 花	風 道	
風 鈴	風 雷	風 馳	風 馳 雨 驟	風 馳 電 卷	風 馳 電 赴	風 馳 電 逝	風 馳 電 掣	
風 塵	風 塵 外 物	風 塵 物 表	風 塵 表 物	風 塵 僕 僕	風 管	風 箏	風 聞	
風 蝕	風 貌	風 輕 日 暖	風 輕 雲 淡	風 輕 雲 淨	風 嬌 日 暖	風 暴	風 暴 潮	
風 標	風 潮	風 箱	風 範	風 範 長 存	風 調	風 調 雨 順	風 趣	
風 趣 橫 生	風 輪	風 操	風 樹 之 悲	風 樹 之 感	風 機	風 激 電 飛	風 激 電 駭	
風 選	風 險	風 險 投 資	風 險 抵 押	風 靜 浪 平	風 頭	風 餐 水 宿	風 餐 水 棲	
風 餐 雨 宿	風 餐 露 宿	風 壓	風 壓 角	風 壓 差	風 櫛 雨 沐	風 檣 陣 馬	風 濕	
風 濕 病	風 濕 症	風 燭 草 露	風 燭 殘 年	風 聲	風 聲 目 色	風 聲 鶴 唳	風 聲 鶴 唳 草 木 皆 兵	
風 舉 雲 搖	風 謠	風 錘	風 霜	風 鎬	風 瀟 雨 晦	風 簷 寸 晷	風 鏡	
風 鏟	風 靡	風 靡 一 時	風 靡 雲 湧	風 靡 雲 蒸	風 韻	風 爐	風 飄	
風 騷	風 驅 電 掃	風 驅 電 擊	風 鑽	風 鬟 雨 鬢	風 鬟 霧 鬢	飛 了	飛 人	
飛 刀	飛 土 逐 肉	飛 天	飛 文 染 翰	飛 毛	飛 毛 腿	飛 父 子 兵	飛 出	
飛 去	飛 向	飛 回	飛 米 轉 芻	飛 行	飛 行 者	飛 行 前	飛 行 員	
飛 行 家	飛 行 術	飛 行 傘	飛 行 隊	飛 行 雲	飛 行 運 動	飛 行 器	飛 利 浦	
飛 吻	飛 宏	飛 宏 企 業	飛 快	飛 沙 走 石	飛 沙 走 礫	飛 沙 揚 礫	飛 沙 轉 石	
飛 災 橫 禍	飛 走	飛 車	飛 車 走 壁	飛 來	飛 來 飛 去	飛 來 橫 禍	飛 奔	
飛 往	飛 沫	飛 花	飛 虎	飛 近	飛 殃 走 禍	飛 流 短 長	飛 砂 走 石	
飛 砂 揚 礫	飛 赴	飛 射	飛 書 走 檄	飛 芻 挽 粒	飛 芻 挽 粟	飛 芻 挽 糧	飛 芻 轉 餉	
飛 蚊 症	飛 起	飛 針 走 線	飛 馬	飛 馬 座	飛 動	飛 得	飛 得 高	
飛 掠	飛 掠 而 過	飛 旋	飛 球	飛 眼	飛 眼 傳 情	飛 船	飛 速	
飛 逝	飛 雪	飛 魚	飛 鳥	飛 鳥 依 人	飛 揚	飛 揚 浮 躁	飛 揚 跋 扈	
飛 散	飛 短 流 長	飛 翔	飛 越	飛 跑	飛 進	飛 雲 掣 電	飛 黃 騰 達	
飛 瑞	飛 瑞 公 司	飛 禽	飛 禽 走 獸	飛 艇	飛 落	飛 蛾	飛 蛾 投 火	
飛 蛾 投 焰	飛 蛾 赴 火	飛 蛾 赴 焰	飛 蛾 赴 燭	飛 蛾 撲 火	飛 賊	飛 過	飛 遁 離 俗	
飛 靶	飛 馳	飛 塵	飛 漲	飛 熊 入 夢	飛 碟	飛 禍	飛 舞	
飛 蒼 走 黃	飛 鳴	飛 彈	飛 撲	飛 播	飛 盤	飛 蓬 乘 風	飛 蓬 隨 風	
飛 蝶	飛 蝗	飛 輪	飛 駛	飛 機	飛 機 失 事	飛 機 庫	飛 機 場	
飛 機 棚	飛 機 模 型	飛 燕 草	飛 燕 遊 龍	飛 龍	飛 龍 在 天	飛 龍 乘 雲	飛 牆 走 壁	
飛 聲 騰 實	飛 臨	飛 鴻	飛 鴻 印 雪	飛 鴻 雪 爪	飛 鴻 踏 雪	飛 濺	飛 瀑	
飛 糧 挽 秣	飛 蟲	飛 離	飛 簷	飛 簷 走 脊	飛 簷 走 壁	飛 蠅 垂 珠	飛 邊	
飛 鏢	飛 難	飛 騰	飛 躍	飛 灑	飛 鑣	飛 鷹 走 犬	飛 鷹 走 狗	
飛 鷹 走 馬	食 人	食 人 肉	食 人 者	食 人 族	食 不 二 味	食 不 下 嚥	食 不 充 口	
食 不 充 腸	食 不 充 饑	食 不 甘 味	食 不 求 甘	食 不 求 飽	食 不 念 飽	食 不 果 腹	食 不 知 味	
食 不 重 肉	食 不 重 味	食 不 兼 肉	食 不 兼 味	食 不 累 味	食 不 終 味	食 不 暇 飽	食 不 遑 味	
食 不 厭 精	食 不 糊 口	食 之 五 味 棄 之 不 甘	食 之 無 味 棄 之 可 惜	食 少 事 繁	食 日 萬 錢	食 毛 踐 土	食 水	
食 火 鳥	食 火 雞	食 古 不 化	食 玉 炊 桂	食 用	食 用 油	食 用 豬	食 而 不 化	
食 肉	食 肉 寢 皮	食 色	食 住	食 伴	食 言	食 言 而 肥	食 谷 類	
食 具	食 具 櫃	食 具 櫥	食 味 方 丈	食 店	食 性	食 油	食 物	
食 物 中 毒	食 物 鍊	食 物 櫥	食 前 方 丈	食 品	食 品 工 業	食 品 公 司	食 品 店	
食 品 股	食 品 室	食 品 廠	食 品 衛 生	食 品 櫃	食 客	食 屍 鬼	食 指	
食 指 大 動	食 施	食 料	食 租 衣 稅	食 草	食 堂	食 宿	食 宿 自 理	
食 宿 費	食 盒	食 貨	食 魚	食 無 求 飽	食 菌	食 量	食 祿	
食 禁	食 蜂 鳥	食 道	食 道 癌	食 管	食 慾	食 慾 不 振	食 槽	
食 糖	食 療	食 癖	食 糧	食 蟲	食 蟲 類	食 蟻	食 蟻 獸	
食 譜	食 鹽	首 下 尻 高	首 日 封	首 丘 之 念	首 丘 之 思	首 丘 之 情	首 丘 之 望	
首 丘 夙 願	首 功	首 台	首 句	首 犯	首 件	首 任	首 先	
首 先 應	首 如 飛 蓬	首 次	首 行	首 位	首 利 實 業	首 尾	首 尾 共 濟	
首 尾 夾 攻	首 尾 乖 互	首 尾 兩 端	首 尾 受 敵	首 尾 相 赴	首 尾 相 接	首 尾 相 救	首 尾 相 連	
首 尾 相 援	首 尾 相 衛	首 尾 相 鄰	首 尾 相 應	首 尾 相 繼	首 尾 狼 狽	首 尾 貫 通	首 批	
首 足 異 處	首 身 份 離	首 例	首 屈 一 指	首 屆	首 府	首 枚	首 肯	
首 長	首 度	首 施 兩 端	首 映	首 架	首 相	首 要	首 要 分 子	
首 要 任 務	首 要 地 位	首 要 條 件	首 頁	首 倡	首 倡 義 舉	首 家	首 席	
首 席 代 表	首 座	首 級	首 唱	首 唱 義 兵	首 推	首 晚	首 部	
首 都	首 都 機 場	首 創	首 創 者	首 創 精 神	首 場	首 富	首 惡	
首 惡 必 辦	首 期	首 發 式	首 善 之 地	首 善 之 區	首 開	首 隊	首 項	
首 當	首 當 其 衝	首 義	首 腦	首 腦 會 晤	首 腦 會 議	首 飾	首 鼠 兩 端	
首 鼠 模 稜	首 奪	首 語	首 領	首 層	首 輪	首 戰	首 戰 告 捷	
首 艙	首 選	首 選 項	首 鋼	首 檢	首 離 眾 盼	香 山	香 木	
香 水	香 水 瓶	香 火	香 火 不 絕	香 火 不 斷	香 火 兄 弟	香 火 因 緣	香 火 姊 妹	
香 片	香 瓜	香 灰	香 皂	香 味	香 奈 兒	香 河	香 波	
香 油	香 油 樹	香 的	香 芹	香 花	香 花 供 養	香 客	香 柏	
香 風	香 香	香 島	香 料	香 料 店	香 料 商	香 料 類	香 案	
香 格 里 拉	香 氣	香 氣 撲 鼻	香 消 玉 減	香 消 玉 損	香 消 玉 碎	香 消 玉 殞	香 粉	
香 脂	香 脆	香 臭	香 草	香 草 美 人	香 茶	香 酒	香 液	
香 甜	香 袋	香 港	香 港 股 市	香 港 特 區	香 菌	香 菜	香 象 渡 河	
香 象 絕 流	香 溫 玉 軟	香 滑	香 煙	香 腸	香 葷	香 幣	香 精	
香 精 油	香 辣	香 閨	香 閨 繡 閣	香 餅	香 餌	香 餌 之 下 必 有 死 魚	香 噴 噴	
香 嬌 玉 嫩	香 樟	香 潤 玉 溫	香 蔥	香 銷 玉 沉	香 橙	香 樹	香 濃	
香 澤	香 蕉	香 檀	香 燭	香 檳	香 檳 色	香 檳 酒	香 爐	
香 饑 玉 體	香 蘭	香 囊	香 菇	香 椿	乘 人 不 備	乘 人 之 厄	乘 人 之 危	
乘 上	乘 方	乘 以	乘 用	乘 此	乘 坐	乘 快 艇	乘 汽 車	
乘 車	乘 車 者	乘 車 戴 笠	乘 其 不 意	乘 法	乘 法 器	乘 肥 衣 輕	乘 客	
乘 風	乘 風 破 浪	乘 飛 機	乘 員	乘 座	乘 除	乘 偽 行 詐	乘 務	
乘 務 員	乘 堅 驅 良	乘 涼	乘 船	乘 勝	乘 勝 前 進	乘 勝 追 擊	乘 勝 逐 北	
乘 筏 者	乘 虛	乘 虛 而 入	乘 間 投 隙	乘 間 策 肥	乘 勢	乘 號	乘 算 器	
乘 輕 驅 肥	乘 隙	乘 隙 而 入	乘 數	乘 冪	乘 機	乘 機 應 變	乘 積	
乘 興	乘 興 而 來	乘 龍 快 婿	乘 輿 播 越	乘 輿 播 遷	乘 警	亳 州	倍 加	
倍 兒 棒	倍 受	倍 受 尊 敬	倍 受 鼓 舞	倍 受 歡 迎	倍 於	倍 率	倍 減	
倍 感	倍 道 兼 行	倍 道 兼 進	倍 增	倍 數	倍 頻	倣 傚	俯 下	
俯 伏	俯 仰	俯 仰 之 間	俯 仰 由 人	俯 仰 無 愧	俯 在	俯 角	俯 身	
俯 泳	俯 臥	俯 臥 撐	俯 垂	俯 拾 地 芥	俯 拾 即 是	俯 拾 青 紫	俯 拾 皆 是	
俯 看	俯 首	俯 首 帖 耳	俯 首 貼 耳	俯 首 聽 命	俯 就	俯 街	俯 視	
俯 視 圖	俯 衝	俯 賜	俯 瞰	俯 覽	倦 怠	倦 容	倦 鳥	
倦 意	倦 感	倥 傯	俸 躬	俸 祿	倩 影	倖 存	倖 存 者	
倖 免	倖 免 於 死	倆 人	倆 眼	值 了	值 日	值 此	值 表	
值 班	值 班 室	值 班 員	值 得	值 得 一 提	值 得 注 視	值 得 注 意	值 得 要	
值 得 做	值 勤	值 當	值 錢	借 了	借 人	借 入	借 刀 殺 人	
借 口	借 予	借 支	借 方	借 水 行 舟	借 火	借 主	借 出	
借 古 諷 今	借 用	借 用 人	借 光	借 此	借 此 機 會	借 而	借 位	
借 住	借 余	借 助	借 助 於	借 來	借 取	借 的	借 者	
借 花	借 花 獻 佛	借 屍 還 魂	借 重	借 風 使 船	借 差	借 書	借 酒	
借 酒 澆 愁	借 問	借 寇 兵 □ 盜 糧	借 宿	借 帳	借 得	借 條	借 單	
借 喻	借 景 抒 情	借 期	借 款	借 減	借 給	借 貸	借 債	
借 道	借 過	借 墊	借 端	借 箸 代 籌	借 與	借 領	借 增	
借 調	借 閱	借 據	借 錢	借 還	借 題	借 題 發 揮	借 讀	
借 鑒	倚 山	倚 天	倚 天 資 訊	倚 仗	倚 玉 偎 香	倚 立	倚 老	
倚 老 賣 老	倚 官 仗 勢	倚 門	倚 門 倚 閭	倚 門 傍 戶	倚 門 賣 俏	倚 門 賣 笑	倚 恃	
倚 重	倚 音	倚 草 附 木	倚 財 仗 勢	倚 馬 可 待	倚 強 凌 弱	倚 望	倚 勢 挾 權	
倚 翠 偎 紅	倚 閭 之 望	倚 靠	倚 賴	倚 牆	倒 了	倒 入	倒 三 顛 四	
倒 下	倒 山 傾 海	倒 不 如	倒 戈	倒 戈 卸 甲	倒 手	倒 牙	倒 出	
倒 去	倒 台	倒 四 顛 三	倒 打	倒 打 一 耙	倒 立	倒 休	倒 伏	
倒 回	倒 地	倒 在	倒 忙	倒 扣	倒 有	倒 行	倒 行 逆 施	
倒 序	倒 把	倒 把 投 機	倒 車	倒 刺	倒 帖	倒 抽	倒 放	
倒 於	倒 枕 捶 床	倒 果 為 因	倒 注 口	倒 注 者	倒 空	倒 臥	倒 軋	
倒 冠 落 佩	倒 持 泰 阿	倒 映	倒 是	倒 流	倒 胃 口	倒 背 如 流	倒 要	
倒 計 時	倒 倉	倒 屐 而 迎	倒 屐 迎 賓	倒 屐 相 迎	倒 栽	倒 栽 蔥	倒 海	
倒 海 反 江	倒 海 移 山	倒 海 翻 江	倒 班	倒 茶	倒 逆	倒 退	倒 帳	
倒 彩	倒 掛	倒 推	倒 敘	倒 閉	倒 插	倒 換	倒 貼	
倒 買 倒 賣	倒 開	倒 嗓	倒 塌	倒 楣	倒 爺	倒 睫 症	倒 置	
倒 置 干 戈	倒 落	倒 裝	倒 載 干 戈	倒 運	倒 過 來	倒 鉤	倒 像	
倒 滿	倒 算	倒 裳 索 領	倒 閣	倒 鳳 顛 鸞	倒 寫	倒 影	倒 撥	
倒 數	倒 豎	倒 賣	倒 踏 門	倒 霉	倒 錯	倒 頭	倒 擠	
倒 斃	倒 檔	倒 繃 孩 兒	倒 翻	倒 轉	倒 鎖	倒 懸	倒 懸 之 危	
倒 懸 之 急	倒 懸 之 苦	倒 騰	倒 灌	倒 讀	倒 茬	俺 們	倔 強	
倔 頭 倔 腦	倨 傲	俱 全	俱 在	俱 收 並 蓄	俱 利	俱 佳	俱 到	
俱 備	俱 樂	俱 樂 部	俱 興	倡 行	倡 言	倡 真	倡 條 冶 葉	
倡 導	倡 導 者	倡 優	倡 議	倡 議 書	個 人	個 人 主 義	個 人 問 題	
個 人 意 見	個 子	個 子 矮	個 中	個 月	個 位	個 別	個 別 人	
個 別 談 話	個 把	個 例	個 兒	個 性	個 性 化	個 股	個 股 分 析	
個 個	個 展	個 案	個 夢	個 數	個 樣	個 頭	個 舊	
個 體	個 體 化	個 體 戶	個 體 手 工 業	個 體 經 濟	候 車	候 車 室	候 命	
候 服 玉 衣	候 門 如 海	候 梯 廳	候 船	候 鳥	候 場	候 診	候 診 室	
候 補	候 補 委 員	候 領	候 審	候 駕	候 機	候 機 室	候 選	
候 選 人	候 爵	候 糧	倘 不	倘 不 如 此	倘 未	倘 有	倘 佯	
倘 使	倘 來 之 物	倘 或	倘 若	倘 能	倘 然	修 了	修 士	
修 女	修 文	修 文 偃 武	修 正	修 正 主 義	修 正 者	修 正 案	修 正 稿	
修 光	修 好	修 成	修 行	修 改	修 改 草 案	修 改 量	修 改 意 見	
修 改 稿	修 身	修 身 齊 家	修 身 養 性	修 車	修 到	修 定	修 性	
修 房	修 枝	修 武	修 法	修 治	修 表	修 長	修 建	
修 指	修 指 甲	修 訂	修 訂 本	修 訂 版	修 訂 者	修 訂 稿	修 面	
修 修	修 書	修 起	修 配	修 剪	修 剪 者	修 理	修 理 工	
修 理 行 業	修 理 者	修 習	修 船	修 造	修 堤	修 復	修 復 一 新	
修 復 者	修 描	修 期	修 短	修 詞	修 業	修 煉	修 腳	
修 補	修 補 者	修 路	修 道	修 道 士	修 道 院	修 過	修 飾	
修 飾 語	修 飾 邊 幅	修 練	修 編	修 鞋	修 養	修 整	修 橋	
修 橋 補 路	修 築	修 臉	修 繕	修 繕 一 新	修 繕 者	修 舊	修 舊 利 廢	
修 辭	修 辭 學	修 護	修 讀	修 葺	倭 奴	倭 寇	俾 晝 作 夜	
倫 巴	倫 次	倫 飛 電 腦	倫 常	倫 理	倫 理 思 想	倫 理 道 德	倫 理 學	
倫 理 學 史	倫 理 學 家	倫 敦	倫 敦 人	倫 琴	倉 卒 防 禦	倉 房	倉 促	
倉 皇	倉 皇 失 措	倉 皇 無 措	倉 庫	倉 庫 管 理	倉 租	倉 惶	倉 鼠	
倉 頡	倉 儲	倉 猝	倉 廩	兼 之	兼 用	兼 任	兼 收	
兼 收 並 蓄	兼 有	兼 而 有 之	兼 作	兼 併	兼 具	兼 到	兼 施	
兼 容	兼 容 並 包	兼 容 性	兼 容 機	兼 差	兼 弱 攻 昧	兼 做	兼 售	
兼 得	兼 理	兼 備	兼 程	兼 演	兼 管	兼 課	兼 辦	
兼 優	兼 營	兼 職	兼 職 教 師	兼 顧	兼 權 熟 計	兼 聽	兼 聽 則 明	
冤 仇	冤 天 屈 地	冤 各 有 頭 債 各 有 主	冤 有 頭 債 有 主	冤 呀	冤 屈	冤 枉	冤 冤 相 報	
冤 家	冤 家 路 狹	冤 家 路 窄	冤 案	冤 鬼	冤 假 錯 案	冤 情	冤 獄	
冤 魂	冤 孽	冥 王 星	冥 府	冥 思	冥 思 苦 索	冥 思 苦 想	冥 界	
冥 冥	冥 紙	冥 想	冥 想 者	冥 頑	冥 頑 不 靈	冥 錢	凍 了	
凍 土	凍 干	凍 手	凍 手 凍 腳	凍 奶	凍 冰	凍 死	凍 住	
凍 狀	凍 省	凍 害	凍 庫	凍 得	凍 硬	凍 結	凍 著	
凍 裂	凍 傷	凍 解 冰 釋	凍 過	凍 僵	凍 瘡	凍 餓	凍 餒	
凍 劑	凍 機	凍 糕	凍 霜	凍 雞	凍 壞	凌 汛	凌 空	
凌 辱	凌 晨	凌 陽	凌 陽 科 技	凌 雲	凌 亂	凌 群 電 腦	凌 厲	
凌 駕	凌 遲	凌 雜	凌 雜 米 鹽	准 入	准 之	准 予	准 尺	
准 心	准 件	准 收	准 有	准 位	准 男 爵	准 其	准 保	
准 軍 事	准 軌	准 郊 外	准 差	准 假	准 將	准 接	准 規	
准 許	准 距	准 運 證	准 線	准 點	准 證	准 寶 石	凋 花	
凋 敝	凋 敞	凋 殘	凋 萎	凋 落	凋 零	凋 謝	剖 心 析 肝	
剖 心 瀝 肝	剖 比	剖 白	剖 決 如 流	剖 肝 瀝 膽	剖 明	剖 析	剖 析 器	
剖 面	剖 面 圖	剖 視	剖 視 圖	剖 開	剖 腹	剖 腹 術	剖 腹 藏 珠	
剖 解	剖 釋	剜 肉 補 瘡	剔 牙	剔 出	剔 去	剔 紅	剔 除	
剔 骨	剔 透	剔 蠍 撩 蜂	剛 一	剛 入	剛 才	剛 毛	剛 出 生	
剛 出 巢	剛 出 現	剛 出 爐	剛 巧	剛 正	剛 正 不 阿	剛 玉	剛 生 下	
剛 好	剛 來	剛 到	剛 性	剛 戾 自 用	剛 果	剛 果 人	剛 果 共 和 國	
剛 果 紅	剛 直	剛 直 不 阿	剛 勇	剛 勁	剛 度	剛 柔	剛 柔 相 濟	
剛 砂	剛 要	剛 剛	剛 烈	剛 健	剛 強	剛 從	剛 愎	
剛 愎 自 用	剛 硬	剛 開 始	剛 過	剛 過 去	剛 毅	剛 毅 木 訥	剛 褊 自 用	
剛 離	剛 體	剛 鑽	剝 下	剝 出	剝 去	剝 皮	剝 光	
剝 削	剝 削 制 度	剝 削 者	剝 削 階 級	剝 剝	剝 除	剝 掉	剝 脫	
剝 殼	剝 開	剝 落	剝 奪	剝 奪 人 權	剝 奪 政 治 權 利 終 身	剝 蝕	剝 膚 椎 髓	
剝 離	匪 片	匪 石 之 心	匪 穴	匪 夷 所 思	匪 兵	匪 邦	匪 軍	
匪 首	匪 徒	匪 躬 之 操	匪 巢	匪 患	匪 朝 伊 夕	匪 禍	匪 幫	
匪 警	匪 黨	卿 士	卿 大 夫	卿 相	卿 卿	卿 卿 我 我	卿 魚	
原 □	原 子	原 子 序 數	原 子 時	原 子 核	原 子 能	原 子 能 委 員 會	原 子 筆	
原 子 量	原 子 說	原 子 價	原 子 彈	原 子 數	原 子 論	原 子 學	原 子 爐	
原 子 鐘	原 戶 籍	原 文	原 木	原 主	原 以	原 以 為	原 本	
原 民 會	原 汁	原 生	原 生 代	原 生 動 物	原 生 質	原 生 體	原 由	
原 石 器	原 件	原 任	原 先	原 名	原 因	原 因 論	原 地	
原 地 區	原 成	原 有	原 色	原 位	原 住	原 住 民	原 住 民 委 員 會	
原 住 民 就 業	原 作	原 作 者	原 判	原 告	原 址	原 形	原 形 畢 露	
原 材 料	原 來	原 函 數	原 味	原 委	原 委 會	原 始	原 始 公 社	
原 始 反 終	原 始 見 終	原 始 林	原 始 狀	原 始 社 會	原 始 要 終	原 始 森 林	原 始 積 累	
原 定	原 居	原 油	原 版	原 物	原 狀	原 則	原 則 立 場	
原 則 性	原 則 問 題	原 則 通 過	原 型	原 封	原 封 不 動	原 指	原 故	
原 是	原 為	原 計 劃	原 訂	原 值	原 原 本 本	原 料	原 核 細 胞	
原 核 質	原 案	原 班	原 班 人 馬	原 級	原 配	原 動	原 動 力	
原 理	原 產	原 處	原 設	原 速	原 野	原 創	原 單 位	
原 場	原 就	原 棉	原 款	原 殖 民	原 稅	原 著	原 訴	
原 意	原 極	原 煤	原 義	原 義 是	原 裝	原 詩	原 話	
原 路	原 載	原 電 池	原 圖	原 貌	原 價	原 審	原 樣	
原 碼	原 稿	原 線 圈	原 諒	原 質	原 糖	原 聲	原 點	
原 糧	原 職	原 蟲	原 證	原 礦	原 籍	原 屬	原 體	
原 鹽	厝 火 積 薪	厝 薪 於 火	哨 子	哨 卡	哨 位	哨 兵	哨 房	
哨 所	哨 音	哨 棒	哨 艇	哨 聲	唐 人	唐 人 街	唐 山	
唐 太 宗	唐 王	唐 代	唐 老 鴨	唐 宋	唐 李 問 對	唐 明 皇	唐 哉 皇 哉	
唐 突	唐 突 西 施	唐 飛	唐 朝	唐 詩	唐 僧	唐 鋒 實 業	唐 臨 晉 帖	
唁 函	唁 電	哼 了	哼 者	哼 哈	哼 唷	哼 哼	哼 唱	
哼 著	哼 著 唱	哼 催	哼 歌	哼 聲	哼 哧	哥 本 哈 根	哥 白 尼	
哥 兒	哥 兒 們	哥 兒 們 義 氣	哥 們	哥 們 兒	哥 倫 比 亞	哥 倫 布	哥 哥	
哥 斯 大 黎 加	哥 嫂	哲 人	哲 人 其 萎	哲 理	哲 學	哲 學 上	哲 學 史	
哲 學 思 想	哲 學 思 潮	哲 學 流 派	哲 學 家	哲 學 理 論	哲 學 筆 記	哲 學 著 作	哲 學 評 論	
哲 學 學 派	哲 學 體 系	唆 使	唆 者	唆 唆	哺 育	哺 乳	哺 乳 室	
哺 乳 動 物	哺 乳 期	哺 乳 類	哺 期	哺 養	哭 了	哭 天	哭 出	
哭 叫	哭 似	哭 吧	哭 泣	哭 泣 者	哭 的	哭 哭	哭 哭 啼 啼	
哭 笑	哭 笑 不 得	哭 得	哭 啼	哭 啼 啼	哭 喊	哭 喪	哭 喪 著 臉	
哭 著	哭 訴	哭 號	哭 過	哭 鼻	哭 鼻 子	哭 罵	哭 鬧	
哭 聲	員 山 鄉	員 工	員 外	員 林	員 林 鎮	唉 呀	唉 喲	
唉 歎	唉 聲 歎 氣	哮 喘	哪 一	哪 一 個	哪 一 種	哪 天	哪 由	
哪 份	哪 年 哪 月	哪 有	哪 次	哪 位	哪 找	哪 些	哪 兒	
哪 怕	哪 門	哪 是	哪 為	哪 科	哪 要	哪 個	哪 家	
哪 能	哪 區	哪 許	哪 項	哪 會	哪 裡	哪 種	哪 樣	
哪 點	哪 邊	哦 呵	哦 喲	唧 叫	唧 唧	唧 唧 叫	唧 喳 聲	
唧 筒	唧 聲	唇 下	唇 亡 齒 寒	唇 舌	唇 形	唇 角	唇 狀	
唇 紅 齒 白	唇 音	唇 音 化	唇 部	唇 焦 舌 敝	唇 裂	唇 飾	唇 槍 舌 劍	
唇 膏	唇 語	唇 齒	唇 齒 相 依	唇 齒 音	唇 聲	唇 瓣	哽 住	
哽 咽	哽 塞	哽 噎	唏 噓	埔 心 鄉	埔 里	埔 鹽 鄉	埋 入	
埋 下	埋 天 怨 地	埋 伏	埋 名	埋 在	埋 沒	埋 怨	埋 首	
埋 首 於	埋 冤	埋 設	埋 著	埋 置	埋 葬	埋 葬 者	埋 頭	
埋 頭 工 作	埋 頭 苦 幹	埋 藏	埃 及	埃 及 人	埃 及 語	埃 塞 俄 比 亞	夏 五 郭 公	
夏 天	夏 文 化	夏 日	夏 日 可 畏	夏 令	夏 令 時	夏 令 營	夏 收	
夏 收 夏 種	夏 至	夏 利	夏 邑	夏 季	夏 初	夏 雨 雨 人	夏 娃	
夏 威 夷	夏 玲 玲	夏 時 制	夏 眠	夏 草	夏 莉 茲 賽 隆	夏 被	夏 裝	
夏 種	夏 熟	夏 熟 作 物	夏 歷	夏 糧	夏 蟲 不 可 語 冰	夏 蟲 朝 菌	夏 蟲 疑 冰	
夏 爐 冬 扇	套 入	套 上	套 口	套 子	套 用	套 印	套 在	
套 色	套 色 版	套 衣	套 住	套 作	套 杉	套 牢	套 系	
套 車	套 取	套 房	套 服	套 版	套 衫	套 套	套 料	
套 索	套 耕	套 問	套 圈	套 掛	套 袖	套 筒	套 裁	
套 進	套 間	套 匯	套 裙	套 裝	套 話	套 路	套 靴	
套 種	套 管	套 管 針	套 算	套 語	套 領	套 寫	套 數	
套 鞋	套 頭	套 餐	套 環	套 購	奚 落	娘 子	娘 子 軍	
娘 兒	娘 兒 們	娘 姨	娘 胎	娘 娘	娘 娘 腔	娘 家	娘 腔	
娘 舅	娘 樹	娘 親	娟 秀	娟 娟	娛 人	娛 樂	娛 樂 性	
娛 樂 室	娛 樂 活 動	娛 樂 區	娛 樂 場 所	娛 樂 稅	娓 娓	娓 娓 不 倦	娓 娓 可 聽	
娓 娓 而 談	娓 娓 動 聽	娓 娓 道 來	孫 女	孫 子	孫 子 兵 法	孫 中 山	孫 吳	
孫 兒	孫 悟 空	孫 婿	孫 媳	孫 運 璿	孫 道 存	孫 燕 姿	孫 臏	
孫 鵬	孫 耀 威	孫 權	宰 羊	宰 相	宰 食	宰 殺	宰 割	
害 了	害 人	害 人 不 淺	害 人 蟲	害 口	害 己	害 死	害 自	
害 我	害 命	害 怕	害 性	害 於	害 病	害 羞	害 處	
害 鳥	害 群 之 馬	害 蟲	害 臊	家 丁	家 人	家 上	家 口	
家 小	家 中	家 公	家 天 下	家 父	家 犬	家 世	家 兄	
家 史	家 奴	家 母	家 用	家 用 電 腦	家 用 電 器	家 名	家 宅	
家 有	家 有 敝 帚 享 之 千 金	家 臣	家 至 人 說	家 至 戶 曉	家 扶 中 心	家 事	家 兔	
家 具	家 具 業	家 姓	家 居	家 底	家 弦 戶 誦	家 法	家 狗	
家 長	家 長 式	家 長 制	家 長 裡 短	家 門	家 信	家 室	家 政	
家 政 學	家 珍	家 計	家 風	家 家	家 家 戶 戶	家 宴	家 庭	
家 庭 中	家 庭 手 工 業	家 庭 出 身	家 庭 式	家 庭 似	家 庭 制	家 庭 副 業	家 庭 婦 女	
家 庭 醫 學	家 徒 四 壁	家 徒 壁 立	家 書	家 畜	家 破 人 亡	家 破 身 亡	家 祠	
家 祖	家 訓	家 財	家 務	家 務 事	家 務 活	家 務 勞 動	家 區	
家 常	家 常 服	家 常 便 飯	家 常 茶 飯	家 教	家 敗 人 亡	家 族	家 族 制 度	
家 產	家 眷	家 缽	家 規	家 訪	家 貧 如 洗	家 喻 戶 曉	家 無 擔 石	
家 無 儋 石	家 給 人 足	家 給 民 足	家 鄉	家 鄉 人	家 鄉 話	家 傳	家 園	
家 業	家 當	家 禽	家 禽 肉	家 裡	家 賊 難 防	家 資	家 道	
家 道 消 乏	家 道 從 容	家 電	家 僕	家 境	家 樂 福	家 養	家 學	
家 學 淵 源	家 貓	家 醜	家 醜 不 可 外 揚	家 翻 宅 亂	家 雞 野 雉	家 雞 野 鶩	家 譜	
家 屬	家 屬 區	家 屬 宿 舍	家 蠶	宴 安 鴆 毒	宴 客	宴 席	宴 會	
宴 會 廳	宴 樂	宴 請	宮 人	宮 女	宮 內	宮 外	宮 刑	
宮 廷	宮 廷 政 變	宮 門	宮 保	宮 保 雞 丁	宮 城	宮 室	宮 崎 駿	
宮 雪 花	宮 畫	宮 殿	宮 殿 似	宮 裡	宮 調	宮 澤 里 惠	宮 澤 理 惠	
宮 燈	宮 頸	宮 牆	宮 闕	宮 鏡	宮 體	宵 衣 旰 食	宵 夜	
宵 禁	宵 旰 焦 勞	宵 旰 圖 治	宵 旰 憂 勞	宵 旰 憂 勤	容 人	容 下	容 不 得	
容 光	容 光 煥 發	容 忍	容 忍 度	容 抗	容 身	容 幸	容 易	
容 易 哭	容 易 教	容 易 發	容 易 錯	容 度	容 留	容 祖 兒	容 納	
容 納 物	容 得	容 情	容 許	容 許 有	容 量	容 量 大	容 量 瓶	
容 電 器	容 貌	容 緩	容 器	容 積	容 積 計	容 積 率	容 錯	
容 頭 過 身	容 顏	射 入	射 中	射 孔	射 手	射 出	射 石 飲 羽	
射 向	射 完	射 角	射 到	射 門	射 洪	射 流	射 倒	
射 能	射 釘	射 殺	射 速	射 程	射 陽	射 極	射 電	
射 精	射 層	射 彈	射 影	射 箭	射 線	射 頻	射 頻 武 器	
射 擊	射 擊 訓 練	射 擊 理 論	射 擊 場	射 獵	屑 於	展 出	展 示	
展 示 者	展 示 場	展 示 會	展 到	展 延	展 性	展 板	展 品	
展 為	展 翅	展 望	展 望 鏡	展 現	展 眼 舒 眉	展 期	展 牌	
展 評	展 開	展 開 式	展 團	展 寬	展 播	展 賣	展 銷	
展 銷 品	展 銷 會	展 轉 反 側	展 顏	展 顏 微 笑	展 覽	展 覽 者	展 覽 品	
展 覽 會	展 覽 館	展 露	展 廳	展 觀	屐 履 造 門	峭 立	峭 拔	
峭 直	峭 壁	峽 口	峽 江	峽 谷	峻 地	峻 阪 鹽 車	峻 法	
峻 峭	峻 筆	峻 嶺	峻 嶺 崇 山	峪 口	峨 冠 博 帶	峨 眉 山	峨 眉 鄉	
峨 嵋	峰 丘	峰 安 金 屬	峰 值	峰 迴 路 轉	峰 頂	峰 期	峰 巔	
峰 巒	島 人	島 上	島 民	島 名	島 狀 物	島 國	島 產	
島 瘦 郊 寒	島 嶼	崁 頂	崁 頂 鄉	差 一 點	差 一 點 兒	差 人	差 三 錯 四	
差 不 多	差 不 離	差 之 千 里	差 之 毫 釐	差 之 毫 釐 失 之 千 里	差 之 毫 釐 繆 以 千 里	差 分	差 以 毫 釐 謬 以 千 里	
差 池	差 別	差 役	差 事	差 些	差 使	差 者	差 勁	
差 值	差 旅	差 旅 費	差 動	差 強 人 意	差 得	差 率	差 異	
差 速 器	差 等	差 距	差 遠	差 遣	差 價	差 價 款	差 數	
差 辦	差 錯	差 點	差 點 兒	差 額	差 額 選 舉	席 下	席 上	
席 上 之 珍	席 子	席 不 暇 暖	席 地	席 地 而 坐	席 地 幕 天	席 位	席 哈 克	
席 珍 待 聘	席 面	席 草	席 捲	席 捲 一 空	席 捲 而 來	席 琳 狄 翁	席 間	
席 墊	席 夢 思	席 箔	席 維 斯 史 特 龍	席 豐 履 厚	師 大	師 友	師 心 自 用	
師 心 自 是	師 父	師 兄	師 出 有 名	師 出 無 名	師 母	師 生	師 老 兵 疲	
師 弟	師 事	師 妹	師 姐	師 宗	師 承	師 法	師 直 為 壯	
師 表	師 長	師 門	師 哥	師 娘	師 徒	師 恩	師 級	
師 院	師 專	師 傅	師 尊	師 傳	師 爺	師 資	師 道	
師 道 尊 嚴	師 團	師 範	師 範 大 學	師 範 院 校	師 範 教 育	師 範 學 校	師 範 學 院	
師 嚴 道 尊	庫 存	庫 存 內	庫 存 品	庫 存 量	庫 車	庫 侖	庫 侖 計	
庫 妮 可 娃	庫 房	庫 柯 奇	庫 頁 島	庫 容	庫 特	庫 單	庫 款	
庫 瑞 爾	庫 裡	庫 爾 勒	庫 藏	庭 上	庭 令	庭 長	庭 院	
庭 院 經 濟	庭 期	庭 園	庭 園 裡	庭 審	庭 議	座 力	座 上	
座 上 客	座 上 賓	座 子	座 中	座 右 銘	座 次	座 位	座 車	
座 者	座 前	座 員	座 套	座 席	座 骨	座 椅	座 無 空 席	
座 無 虛 席	座 落	座 像	座 墊	座 層	座 標	座 談	座 談 會	
座 機	座 艙	座 頭 鯨	座 鐘	弱 小	弱 不 好 弄	弱 不 勝 衣	弱 不 禁 風	
弱 化	弱 肉 強 食	弱 性	弱 拍	弱 者	弱 型	弱 音	弱 國	
弱 敗	弱 智	弱 智 兒 童	弱 視	弱 隊	弱 項	弱 勢	弱 勢 族 群	
弱 電	弱 酸	弱 敵	弱 點	弱 鹼	弱 鹼 性	徒 子 徒 孫	徒 工	
徒 手	徒 手 空 拳	徒 手 格 鬥	徒 生	徒 刑	徒 宅 忘 妻	徒 托 空 言	徒 有	
徒 有 其 名	徒 有 虛 名	徒 作	徒 弟	徒 步	徒 步 旅 行	徒 步 浮 橋	徒 具	
徒 長	徒 孫	徒 書	徒 耗	徒 陳 空 文	徒 勞	徒 勞 無 功	徒 勞 無 益	
徒 然	徒 費 唇 舌	徒 費 無 益	徒 亂 人 意	徒 傳	徒 增	徒 廢 唇 舌	徒 錄	
徑 向	徑 直	徑 流	徑 情 直 遂	徑 間	徑 跡	徑 賽	徐 乃 麟	
徐 生 明	徐 州	徐 行	徐 亨	徐 志 摩	徐 步	徐 若 瑄	徐 風	
徐 娘 半 老	徐 徐	徐 匯	徐 聞	徐 緩	恣 心 所 欲	恣 行 無 忌	恣 情	
恣 情 縱 欲	恣 意	恣 意 妄 行	恣 意 妄 為	恣 睢 無 忌	恣 肆 無 忌	恣 橫	恥 言 人 過	
恥 居 人 下	恥 笑	恥 辱	恥 骨	恐 不	恐 水	恐 水 病	恐 水 症	
恐 外	恐 味	恐 怖	恐 怖 主 義	恐 怖 份 子	恐 怖 行 動	恐 怖 事 件	恐 怖 活 動	
恐 怖 組 織	恐 怖 集 團	恐 怖 感	恐 怕	恐 俄 症	恐 後 爭 先	恐 荒	恐 高	
恐 慌	恐 慌 萬 狀	恐 龍	恐 嚇	恐 嚇 取 財	恐 獸	恐 懼	恐 懼 心 理	
恐 懼 症	恐 懼 感	恕 己 及 人	恕 己 及 物	恕 不	恕 不 奉 陪	恕 不 從 命	恕 不 接 待	
恕 免	恕 我	恕 我 直 言	恕 性	恕 罪	恕 邀	恕 難 從 命	恕 贖	
恭 子	恭 行 天 罰	恭 服	恭 迎	恭 城	恭 候	恭 恭	恭 恭 敬 敬	
恭 祝	恭 從	恭 桶	恭 逢 其 盛	恭 喜	恭 賀	恭 賀 新 禧	恭 順	
恭 敬	恭 敬 不 如 從 命	恭 敬 桑 梓	恭 維	恭 維 話	恭 請	恭 謁	恭 謙	
恭 謹	恭 聽	恩 人	恩 山 義 海	恩 仇	恩 主	恩 同 父 母	恩 同 再 造	
恩 典	恩 奎 斯 特	恩 威 並 用	恩 威 並 行	恩 威 並 施	恩 威 並 著	恩 怨	恩 重 丘 山	
恩 重 如 山	恩 師	恩 格 斯	恩 格 爾	恩 益 禧	恩 將 仇 報	恩 情	恩 深 義 重	
恩 惠	恩 愛	恩 德	恩 德 實 業	恩 賜	恩 澤	恩 戴	恩 斷 意 絕	
恩 斷 義 絕	恩 寵	息 肉	息 兵	息 技	息 事	息 事 寧 人	息 怒	
息 息	息 息 相 通	息 息 相 關	息 票	息 鼓	息 影	息 憩	息 戰	
息 聲	息 黥 補 劓	悄 悄	悄 悄 兒	悄 然	悄 聲	悟 力	悟 出	
悟 性	悟 空	悟 道	悟 學	悚 然	悍 妻	悍 匪	悍 婦	
悍 將	悍 接	悍 然	悍 然 不 顧	悔 不	悔 不 當 初	悔 不 該	悔 之	
悔 之 亡 及	悔 之 不 及	悔 之 何 及	悔 之 晚 矣	悔 之 莫 及	悔 之 無 及	悔 改	悔 恨	
悔 悟	悔 氣	悔 棋	悔 意	悔 罪	悔 罪 自 新	悔 罪 者	悔 過	
悔 過 自 責	悔 過 自 新	悔 過 自 懺	悔 幫	悅 人	悅 心 娛 目	悅 目	悅 目 娛 心	
悅 耳	悅 耳 動 聽	悅 色	悅 近 來 遠	悖 入 悖 出	悖 文	悖 逆	悖 晦	
悖 理	悖 禮	扇 人	扇 子	扇 火 止 沸	扇 形	扇 貝	扇 車	
扇 具	扇 枕 溫 被	扇 狀	扇 狀 尾	扇 面	扇 風	扇 風 點 火	扇 動	
扇 區	拳 手	拳 斗	拳 王	拳 王 阿 里	拳 打	拳 打 腳 踢	拳 法	
拳 師	拳 拳	拳 拳 服 膺	拳 術	拳 棒	拳 腳	拳 腳 交 加	拳 道	
拳 壇	拳 頭	拳 頭 產 品	拳 擊	拳 擊 手	拳 擊 家	拳 擊 賽	拳 賽	
挈 瓶 小 智	挈 瓶 之 知	拿 人	拿 下	拿 上	拿 大	拿 大 頭	拿 不	
拿 不 定 主 意	拿 不 準	拿 手	拿 手 好 戲	拿 主 意	拿 出	拿 出 來	拿 去	
拿 用	拿 回	拿 好	拿 住	拿 走	拿 事	拿 來	拿 到	
拿 定	拿 近 點	拿 架 子	拿 捏	拿 班 作 勢	拿 破 侖	拿 起	拿 得	
拿 掉	拿 粗 挾 細	拿 給	拿 腔 作 勢	拿 腔 拿 調	拿 著	拿 開	拿 雲 捉 月	
拿 雲 握 霧	拿 督	拿 賊 見 贓	拿 賊 要 贓 拿 奸 要 雙	拿 賊 拿 贓	拿 槍	拿 糖 作 醋	拿 辦	
拿 錢	拿 獲	拿 薪 水	拿 穩	拿 權	捎 色	捎 來	捎 信	
捎 帶	捎 關 打 節	挾 人 捉 將	挾 山 超 海	挾 天 子 以 令 諸 侯	挾 主 行 令	挾 冰 求 溫	挾 制	
挾 取	挾 朋 樹 黨	挾 恨	挾 持	挾 帶	挾 細 拿 粗	挾 貴 倚 勢	挾 勢 弄 權	
挾 嫌	挾 權 倚 勢	振 片	振 民 育 德	振 耳	振 衣 提 領	振 衣 濯 足	振 作	
振 作 有 為	振 作 精 神	振 振 有 詞	振 振 有 辭	振 翅	振 起	振 動	振 動 子	
振 動 者	振 動 計	振 動 器	振 動 篩	振 貧 濟 乏	振 幅	振 發 實 業	振 筆	
振 筆 疾 書	振 裘 持 領	振 領 提 綱	振 窮 恤 貧	振 窮 恤 寡	振 奮	振 奮 人 心	振 奮 精 神	
振 興	振 興 中 華	振 蕩	振 蕩 器	振 翼	振 臂	振 臂 一 呼	振 臂 高 呼	
振 響	振 聾 發 聵	捕 手	捕 收	捕 快	捕 房	捕 風 弄 月	捕 風 系 影	
捕 風 捉 影	捕 食	捕 食 性	捕 拿	捕 捉	捕 殺	捕 魚	捕 魚 人	
捕 魚 用	捕 鳥	捕 鼠	捕 鼠 機	捕 盡	捕 影 系 風	捕 影 拿 風	捕 撈	
捕 蝦	捕 頭	捕 獲	捕 獲 量	捕 蠅 紙	捕 蠅 器	捕 蟹	捕 鯨 船	
捂 到	捂 著	捂 蓋 子	捂 霧 拿 雲	捆 上	捆 干	捆 扎	捆 包	
捆 包 繩	捆 在	捆 好	捆 成	捆 住	捆 起	捆 綁	捆 裝	
捆 緊	捆 稻 草	捆 縛	捆 縛 術	捏 一 把 汗	捏 手 捏 腳	捏 合	捏 成	
捏 住	捏 告	捏 弄	捏 制	捏 咕	捏 捏	捏 捏 扭 扭	捏 造	
捏 造 者	捏 陶	捏 報	捏 腔 拿 調	捏 著	捏 詞	捏 碎	捏 腳 捏 手	
捏 稱	捉 生 替 死	捉 住	捉 弄	捉 到	捉 虎 擒 蛟	捉 姦	捉 姦 見 床	
捉 姦 捉 雙	捉 拿	捉 拿 歸 案	捉 班 做 勢	捉 迷 藏	捉 將 官 裡 去	捉 將 挾 人	捉 筆	
捉 賊 見 贓 捉 姦 見 雙	捉 鼠 拿 貓	捉 摸	捉 摸 不 定	捉 影	捉 影 捕 風	捉 影 追 風	捉 雞 罵 狗	
捉 襟 肘 見	捉 襟 見 肘	捉 衿 見 肘	挺 出	挺 立	挺 兇	挺 好	挺 而 走 險	
挺 住	挺 伸	挺 秀	挺 身	挺 身 而 出	挺 到	挺 拔	挺 直	
挺 括	挺 香	挺 挺	挺 胸	挺 胸 凸 肚	挺 胸 迭 肚	挺 起	挺 堅	
挺 桿	挺 脫	挺 棒	挺 硬	挺 著	挺 進	挺 愛	挺 過	
挺 舉	捐 出	捐 生 殉 國	捐 血	捐 助	捐 助 人	捐 忿 棄 瑕	捐 金 抵 璧	
捐 棄	捐 棄 前 嫌	捐 款	捐 款 人	捐 款 者	捐 殘 去 殺	捐 稅	捐 給	
捐 華 務 實	捐 資	捐 錢	捐 軀	捐 軀 赴 難	捐 軀 報 國	捐 軀 濟 難	捐 軀 殞 首	
捐 贈	捐 贈 者	捐 獻	捐 獻 者	挽 力	挽 手	挽 回	挽 回 經 濟 損 失	
挽 衣 女	挽 住	挽 弩 自 射	挽 留	挽 留 者	挽 起	挽 唱	挽 救	
挽 袖	挽 著	挽 詞	挽 詩	挽 幛	挽 臂	挪 出	挪 占	
挪 用	挪 作 他 用	挪 言	挪 走	挪 威	挪 威 人	挪 威 幣	挪 威 語	
挪 借	挪 動	挪 移	挪 款	挪 開	挪 窩	挫 折	挫 骨 揚 灰	
挫 敗	挫 傷	挫 敵	挨 刀	挨 上	挨 山 塞 海	挨 戶	挨 打	
挨 次	挨 到	挨 受	挨 肩	挨 肩 迭 背	挨 肩 搭 背	挨 肩 擦 背	挨 肩 擦 膀	
挨 肩 擦 臉	挨 近	挨 門	挨 門 逐 戶	挨 風 緝 縫	挨 個	挨 個 兒	挨 凍	
挨 家	挨 家 挨 戶	挨 訓	挨 得	挨 揍	挨 著	挨 黑	挨 過	
挨 罵	挨 靠	挨 餓	挨 整	挨 擠	挨 邊	捍 衛	效 力	
效 上	效 用	效 仿	效 命	效 忠	效 果	效 果 宏 大	效 果 顯 著	
效 益	效 益 年 活 動	效 能	效 率	效 率 高	效 勞	效 應	效 驗	
效 顰 學 步	料 子	料 不 到	料 中	料 及	料 斗	料 車	料 事	
料 事 如 神	料 到	料 定	料 架	料 峭	料 耗	料 酒	料 堆	
料 淨	料 理	料 單	料 場	料 款	料 費	料 想	料 想 到	
料 管	料 算	料 遠 若 近	料 敵 制 勝	料 敵 若 神	料 器	料 醫 少 卜	旁 人	
旁 切	旁 及	旁 支	旁 出	旁 生	旁 白	旁 行 斜 上	旁 岔	
旁 求 俊 彥	旁 系	旁 系 血 親	旁 系 親 屬	旁 見 側 出	旁 枝	旁 注	旁 物	
旁 門	旁 門 外 道	旁 門 左 道	旁 若 無 人	旁 軌	旁 風	旁 側	旁 通	
旁 通 道	旁 街	旁 搜 博 采	旁 搜 遠 紹	旁 落	旁 路	旁 道	旁 敲 側 擊	
旁 徵 博 引	旁 線	旁 壓	旁 證	旁 證 博 引	旁 邊	旁 聽	旁 聽 席	
旁 觀	旁 觀 者	旁 觀 者 清	旁 觀 袖 手	旅 人	旅 日	旅 行	旅 行 支 票	
旅 行 包	旅 行 用	旅 行 車	旅 行 社	旅 行 者	旅 行 袋	旅 行 團	旅 行 圖	
旅 伴	旅 居	旅 居 者	旅 店	旅 社	旅 舍	旅 長	旅 客	
旅 客 之 家	旅 客 列 車	旅 客 機	旅 途	旅 程	旅 費	旅 進 旅 退	旅 順	
旅 遊	旅 遊 地	旅 遊 局	旅 遊 事 業	旅 遊 服 務	旅 遊 者	旅 遊 城 市	旅 遊 指 南	
旅 遊 活 動	旅 遊 展	旅 遊 區	旅 遊 勝 地	旅 遊 業	旅 遊 資 訊	旅 遊 資 源	旅 遊 團	
旅 遊 鞋	旅 遊 點	旅 館	旅 館 費	時 人	時 不	時 不 可 失	時 不 再 來	
時 不 我 待	時 不 我 與	時 不 時	時 分	時 文	時 方	時 日	時 代	
時 代 氣 息	時 代 特 徵	時 代 華 納	時 代 感	時 令	時 出	時 必	時 伏	
時 光	時 光 似 箭 日 月 如 梭	時 在	時 式	時 有	時 而	時 至	時 至 今 日	
時 行	時 冷 時 熱	時 局	時 序	時 快 時 慢	時 見	時 辰	時 並	
時 乖 命 蹇	時 乖 運 乖	時 乖 運 拙	時 乖 運 蹇	時 事	時 事 性	時 事 知 識	時 事 社	
時 事 評 論	時 來 運	時 來 運 來	時 來 運 旋	時 來 運 轉	時 刻	時 刻 表	時 制	
時 取	時 和 年 豐	時 和 歲 稔	時 和 歲 豐	時 宜	時 尚	時 空	時 空 觀	
時 政	時 段	時 疫	時 穿	時 限	時 風	時 值	時 候	
時 害	時 差	時 效	時 效 性	時 時	時 時 刻 刻	時 氣	時 能	
時 針	時 務	時 區	時 常	時 望 所 歸	時 現	時 產	時 異 事 殊	
時 異 勢 殊	時 移 世 變	時 移 事 改	時 移 事 遷	時 移 俗 易	時 絀 舉 贏	時 速	時 逢	
時 報	時 報 文 化	時 報 出 版	時 期	時 程 表	時 評	時 間	時 間 上	
時 間 性	時 間 表	時 間 差	時 間 等	時 間 跨 度	時 間 管 理	時 間 學	時 勢	
時 勢 造 英 雄	時 新	時 會	時 節	時 裝	時 裝 表	時 運	時 運 不 濟	
時 運 亨 通	時 過 境 遷	時 隔	時 隔 不 久	時 弊	時 態	時 漏	時 髦	
時 髦 人	時 價	時 數	時 樣	時 談 物 議	時 調	時 賢	時 機	
時 興	時 舉	時 隱 時 現	時 鮮	時 點	時 斷 時 續	時 鐘	時 續	
晉 中	晉 升	晉 升 制 度	晉 升 為	晉 代	晉 江	晉 見	晉 京	
晉 城	晉 封	晉 級	晉 國	晉 朝	晉 察 冀	晉 劇	晉 謁	
晏 子	晏 開 之 警	晃 來 晃 去	晃 晃	晃 晃 悠 悠	晃 動	晃 悠	晃 眼	
晃 著	晃 腦	晃 蕩	晃 頭	晌 午	晌 飯	晌 覺	晁 錯	
書 人	書 上	書 不 盡 言	書 中	書 五	書 文	書 冊	書 刊	
書 包	書 外	書 市	書 本	書 本 知 識	書 札	書 生	書 生 氣	
書 用	書 皮	書 目	書 目 工 作	書 立	書 名	書 名 號	書 坊	
書 夾	書 局	書 函	書 卷	書 店	書 房	書 法	書 法 家	
書 法 展	書 物	書 狀	書 社	書 亭	書 信	書 信 集	書 城	
書 契	書 屋	書 後	書 架	書 眉	書 面	書 面 材 料	書 面 通 知	
書 面 報 告	書 面 發 言	書 面 語 言	書 面 聲 明	書 頁	書 香	書 香 門 第	書 套	
書 展	書 庫	書 案	書 桌	書 缺 簡 脫	書 脊	書 記	書 記 員	
書 記 處	書 釘	書 院	書 商	書 堆	書 符 咒 水	書 通 二 酉	書 場	
書 報	書 報 費	書 富 五 車	書 扉	書 款	書 畫	書 評	書 號	
書 裡	書 僮	書 摘	書 劍 飄 零	書 寫	書 寫 者	書 寫 器	書 稿	
書 箱	書 學	書 錄	書 館	書 檔	書 聲 朗 朗	書 聲 琅 琅	書 齋	
書 櫃	書 歸 正 傳	書 癖	書 簡	書 蟲	書 櫥	書 癡	書 證	
書 籍	書 籍 商	書 籍 裝 幀	書 攤	書 讀 五 車	書 籤	書 體	書 獃 子	
朔 日	朔 風	朔 望	朗 峰	朗 朗	朗 誦	朗 誦 者	朗 誦 會	
朗 語	朗 讀	校 工	校 內	校 友	校 友 會	校 方	校 刊	
校 史	校 外	校 外 活 動	校 本	校 正	校 正 者	校 址	校 改	
校 車	校 定	校 官	校 服	校 花	校 長	校 門	校 訂	
校 訂 本	校 音	校 風	校 員	校 站	校 級	校 訓	校 務	
校 勘	校 尉	校 捨	校 產	校 規	校 場	校 報	校 量	
校 間	校 隊	校 園	校 園 暴 力	校 準	校 董	校 團	校 團 委	
校 對	校 對 人	校 對 者	校 對 室	校 對 員	校 對 機	校 旗	校 歌	
校 監	校 際	校 慶	校 樣	校 稿	校 編	校 閱	校 辦	
校 辦 工 廠	校 徽	校 檢	校 醫	校 警	校 黨 委	校 屬	校 驗	
核 人	核 入	核 力	核 力 量	核 子	核 子 彈 頭	核 工 業	核 工 業 部	
核 仁	核 反 應	核 反 應 堆	核 心	核 心 作 用	核 心 家 庭	核 心 機 密	核 四	
核 四 廠	核 外 電 子	核 甘 酸	核 交	核 安 全	核 收	核 肉	核 技	
核 技 術	核 批	核 防 護	核 定	核 果	核 武	核 武 器	核 物 理	
核 威 脅	核 後 時 代	核 查	核 研 所	核 計	核 准	核 員	核 桃	
核 能	核 能 研 究 所	核 能 發 電	核 動 力	核 理 論	核 蛋 白	核 訛 詐	核 報	
核 減	核 發	核 給	核 裁	核 裁 軍	核 裂 變	核 黃 素	核 試 驗	
核 資	核 電	核 電 站	核 實	核 對	核 磁	核 磁 共 振	核 算	
核 算 單 位	核 酸	核 酸 序 列	核 酸 探 針	核 酸 糖	核 價	核 增	核 彈	
核 彈 頭	核 潛 艇	核 膜	核 銷	核 戰	核 戰 爭	核 戰 略	核 燃 料	
核 糖	核 糖 核 酸	核 糖 體	核 輻 射	核 辦	核 擴 散	核 壟 斷	核 爆	
核 爆 炸	核 簽	核 驗	核 體	案 人	案 子	案 冊	案 犯	
案 由	案 目	案 件	案 例	案 卷	案 底	案 板	案 首	
案 書	案 桌	案 秤	案 情	案 發	案 發 地 點	案 詩	案 語	
案 頭	案 證	案 驗	框 子	框 內	框 死	框 兒	框 定	
框 架	框 框	框 格	框 項	框 圖	框 緣	根 子	根 毛	
根 巧 枝 枯	根 本	根 本 上	根 本 性	根 本 法	根 由	根 尖	根 式	
根 壯 葉 茂	根 究	根 系	根 兒	根 底	根 拔	根 於	根 治	
根 狀	根 狀 部	根 芽	根 冠	根 指 數	根 苗	根 特	根 除	
根 基	根 基 營 造	根 接	根 深	根 深 土 長	根 深 蒂 固	根 深 葉 茂	根 莖	
根 部	根 植	根 絕	根 源	根 號	根 瘤	根 瘤 菌	根 據	
根 據 地	桂 子 飄 香	桂 子 蘭 孫	桂 平	桂 皮	桂 宏 企 業	桂 東	桂 林	
桂 林 一 枝	桂 林 市	桂 芝	桂 花	桂 冠	桂 宮 柏 寢	桂 魚	桂 圓	
桂 樹	桔 子	桔 汁	桔 色	桔 紅	桔 梗	桔 絡	桔 黃	
桔 餅	桔 樹	栩 栩	栩 栩 如 生	梳 子	梳 毛	梳 毛 紗	梳 成	
梳 妝	梳 妝 台	梳 刷	梳 洗	梳 理	梳 頭	梳 頭 髮	梳 攏	
梳 鏡	栗 子	栗 色	栗 粒 狀	栗 樹	桌 下	桌 上	桌 上 型	
桌 上 型 電 腦	桌 子	桌 巾	桌 布	桌 兒	桌 前	桌 架	桌 面	
桌 面 兒	桌 案	桌 球	桌 椅	桌 椅 板 凳	桌 腳	桌 燈	桌 邊	
桑 中 之 約	桑 巴	桑 巴 舞	桑 田	桑 那	桑 弧 蓬 矢	桑 拿	桑 梓	
桑 植	桑 間 濮 上	桑 園	桑 塔 納	桑 榆	桑 榆 末 景	桑 榆 暮 景	桑 榆 暮 影	
桑 葉	桑 樞 甕 牖	桑 樹	桑 蠶	桑 椹	栽 作	栽 法	栽 花	
栽 倒	栽 秧	栽 培	栽 培 技 術	栽 培 物	栽 培 者	栽 植	栽 進	
栽 跟 頭	栽 種	栽 樹	栽 贓	栽 體	柴 火	柴 禾	柴 立 不 阿	
柴 米	柴 米 油 鹽	柴 把	柴 松 林	柴 油	柴 油 機	柴 門	柴 屋	
柴 科 夫 斯 基	柴 胡	柴 草	柴 堆	柴 毀 骨 立	柴 毀 滅 性	柴 窯	桐 子	
桐 油	桐 城	桐 柏	桐 鄉	桐 廬	桀 犬 吠 堯	桀 紂	桀 逆 放 恣	
桀 敖 不 馴	桀 驁	桀 驁 不 恭	桀 驁 不 馴	桀 驁 難 馴	格 子	格 子 呢	格 子 窗	
格 令	格 古 通 今	格 外	格 式	格 式 上	格 式 化	格 式 紙	格 式 欄	
格 局	格 形	格 言	格 兒	格 呢	格 於 成 例	格 林	格 物	
格 物 致 知	格 物 窮 理	格 狀	格 律	格 格	格 格 不 入	格 格 笑	格 紙	
格 高 意 遠	格 鬥	格 勒	格 殺 不 論	格 殺 勿 論	格 陵 蘭	格 雷	格 線	
格 調	格 魯 吉 亞	桃 子	桃 之 夭 夭	桃 井 薰	桃 仁	桃 木	桃 江	
桃 汛	桃 色	桃 色 糾 紛	桃 夾	桃 李	桃 李 不 言 下 自 成 蹊	桃 李 爭 妍	桃 李 爭 輝	
桃 李 門 牆	桃 李 無 言 下 自 成 蹊	桃 李 遍 天 下	桃 李 滿 天 下	桃 來 李 答	桃 花	桃 花 人 面	桃 花 源	
桃 花 運	桃 花 薄 命	桃 柳 爭 妍	桃 紅	桃 紅 色	桃 紅 柳 綠	桃 核	桃 符	
桃 羞 杏 讓	桃 脯	桃 園	桃 園 航 勤 公 司	桃 園 港	桃 源	桃 源 鄉	桃 腮 杏 臉	
桃 樹	株 式	株 式 會 社	株 洲	株 連	株 距	株 選	桅 木	
桅 帆	桅 桿	桅 船	桅 頂	桅 燈	栓 上	栓 子	栓 住	
栓 牢	栓 塞	栓 塞 物	栓 劑	栓 鎖 帶	栓 繩	桁 架	殊 不 知	
殊 方 同 致	殊 方 異 域	殊 方 異 類	殊 方 絕 域	殊 功	殊 功 勁 節	殊 死	殊 死 搏 鬥	
殊 形 妙 狀	殊 形 怪 狀	殊 形 詭 色	殊 形 詭 狀	殊 言 別 語	殊 異	殊 途 同 歸	殊 滋 異 味	
殊 塗 同 致	殊 塗 同 會	殊 塗 同 歸	殊 煞 風 景	殊 路 同 歸	殊 榮	殊 勳	殊 勳 茂 績	
殊 勳 異 績	殊 禮	殉 國	殉 情	殉 教	殉 教 史	殉 教 者	殉 節	
殉 義 忘 身	殉 葬	殉 葬 品	殉 道	殉 道 者	殉 職	殉 難	殉 難 者	
殷 切	殷 天 動 地	殷 天 震 地	殷 民 阜 利	殷 民 阜 財	殷 紅	殷 殷	殷 殷 田 田	
殷 殷 教 導	殷 殷 勤 勤	殷 浩 書 空	殷 商	殷 望	殷 富	殷 琪	殷 勤	
殷 資	殷 實	殷 憂 啟 聖	殷 鑒	殷 鑒 不 遠	氣 人	氣 力	氣 口	
氣 大	氣 井	氣 化	氣 孔	氣 充 志 定	氣 充 志 驕	氣 功	氣 生 氣 死	
氣 田	氣 穴	氣 吐 眉 揚	氣 吐 虹 霓	氣 多	氣 宇	氣 宇 昂 昂	氣 宇 軒 昂	
氣 死	氣 死 人	氣 色	氣 色 好	氣 血	氣 血 方 剛	氣 克 鬥 牛	氣 冷	
氣 吞 山 河	氣 吞 牛 斗	氣 吞 河 山	氣 壯	氣 壯 山 河	氣 壯 河 山	氣 壯 理 直	氣 床	
氣 忍 聲 吞	氣 我	氣 沖 牛 斗	氣 沖 沖	氣 沖 鬥 牛	氣 沖 霄 漢	氣 味	氣 味 相 投	
氣 呼 呼	氣 和	氣 性	氣 昂 昂	氣 昏	氣 氛	氣 泡	氣 狀	
氣 門	氣 門 心	氣 冠 三 軍	氣 咽 聲 絲	氣 度	氣 度 不 凡	氣 急	氣 急 敗 喪	
氣 急 敗 壞	氣 流	氣 派	氣 泵	氣 盆	氣 缸	氣 胎	氣 候	
氣 候 上	氣 候 異 常	氣 候 學	氣 候 變 化	氣 凌 霄 漢	氣 哼 哼	氣 息	氣 息 奄 奄	
氣 息 長	氣 時	氣 氣	氣 浪	氣 消 膽 奪	氣 浴	氣 病	氣 胸	
氣 般	氣 動	氣 動 力	氣 動 車	氣 密	氣 得	氣 得 志 滿	氣 旋	
氣 殺	氣 殺 鍾 馗	氣 焊	氣 球	氣 瓶	氣 盛	氣 眼	氣 笛	
氣 船	氣 貫 長 虹	氣 割	氣 喘	氣 喘 吁 吁	氣 喘 如 牛	氣 喘 聲	氣 悶	
氣 慨	氣 惱	氣 湧 如 山	氣 渦	氣 焰	氣 焰 囂 張	氣 焰 熏 天	氣 痛	
氣 短	氣 窗	氣 筒	氣 絕	氣 絕 身 亡	氣 腔	氣 脹	氣 虛	
氣 象	氣 象 台	氣 象 局	氣 象 計	氣 象 站	氣 象 情 報	氣 象 萬 千	氣 象 雷 達	
氣 象 圖	氣 象 學	氣 象 學 校	氣 象 觀 測	氣 量	氣 傲 心 高	氣 勢	氣 勢 洶 洶	
氣 勢 浩 大	氣 勢 磅 礡	氣 勢 熏 灼	氣 極	氣 概	氣 溶 膠	氣 溫	氣 滑 式	
氣 節	氣 義 相 投	氣 腫	氣 艇	氣 話	氣 運	氣 逾 霄 漢	氣 閘	
氣 鼓	氣 團	氣 墊	氣 墊 船	氣 態	氣 槍	氣 滿 志 驕	氣 管	
氣 管 炎	氣 管 鏡	氣 蓋 山 河	氣 閥	氣 層	氣 憤	氣 憤 等	氣 數	
氣 潮	氣 誼 相 投	氣 質	氣 輪 機	氣 餒	氣 魄	氣 燈	氣 壓	
氣 壓 山 河	氣 壓 計	氣 壓 帶	氣 壓 圖	氣 壓 層	氣 鍋	氣 錘	氣 壞	
氣 爆	氣 爐	氣 囊	氣 驕 志 滿	氣 體	氣 體 狀	氣 夯 胸 脯	氧 乙 炔	
氧 化	氧 化 □	氧 化 物	氧 化 焰	氧 化 鈣	氧 化 鉛	氧 化 鈹	氧 化 誥	
氧 化 銅	氧 化 鋅	氧 化 鋁	氧 化 鋇	氧 化 鋰	氧 化 劑	氧 化 鎂	氧 化 鐵	
氧 化 釔	氧 化 鐿	氧 水	氧 性	氧 氣	氧 氨	氧 炔 吹 管	氨 化	
氨 水	氨 氣	氨 基	氨 基 塑 料	氨 基 酸	氨 基 樹 脂	氨 酸	氦 氖	
氦 氣	泰 人	泰 山	泰 山 之 安	泰 山 北 斗	泰 山 可 倚	泰 山 企 業	泰 山 其 頹	
泰 山 若 厲	泰 山 梁 木	泰 山 壓 卵	泰 山 壓 頂	泰 山 鴻 毛	泰 戈 爾	泰 斗	泰 王	
泰 安	泰 安 鄉	泰 而 不 費	泰 來 否 往	泰 來 否 極	泰 林 科 技	泰 阿 倒 持	泰 恩 布 德	
泰 拳	泰 勒	泰 國	泰 國 人	泰 國 語	泰 國 盤 谷 銀 行	泰 晤	泰 晤 士	
泰 晤 士 河	泰 晤 士 報	泰 勞	泰 森	泰 然	泰 然 自 若	泰 然 居 之	泰 然 處 之	
泰 極 而 否	泰 裕	泰 語	泰 銘	泰 銘 實 業	泰 豐 輪 胎	浪 人	浪 女	
浪 子	浪 兒	浪 拍	浪 板	浪 花	浪 恬 波 靜	浪 費	浪 費 狂	
浪 費 者	浪 費 時 間	浪 費 掉	浪 跡	浪 跡 天 下	浪 跡 天 涯	浪 跡 江 湖	浪 跡 萍 蹤	
浪 鼓	浪 漫	浪 漫 化	浪 漫 主 義	浪 潮	浪 蝶 狂 蜂	浪 蝶 游 蜂	浪 蕩	
浪 靜	浪 靜 風 恬	浪 頭	浪 濤	浪 譜	涕 泣	涕 泗 交 下	涕 泗 交 流	
涕 泗 交 頤	涕 泗 滂 沱	涕 泗 橫 流	涕 泗 縱 橫	涕 淚	涕 淚 交 下	涕 淚 交 加	涕 淚 交 垂	
涕 淚 交 流	涕 淚 交 集	涕 淚 交 零	涕 零	消 亡	消 化	消 化 □	消 化 力	
消 化 吸 收	消 化 性	消 化 液	消 化 管	消 化 劑	消 火 栓	消 去	消 失	
消 失 了	消 石 灰	消 色	消 沉	消 災	消 防	消 防 局	消 防 車	
消 防 隊	消 防 塞	消 防 署	消 防 艇	消 受	消 炎	消 炎 片	消 長	
消 保 會	消 弭	消 毒	消 毒 劑	消 音	消 音 器	消 食	消 夏	
消 息	消 息 閉 塞	消 息 報	消 息 靈 通	消 息 靈 通 人 士	消 氣	消 納	消 納 整 合	
消 耗	消 耗 用	消 耗 性	消 耗 量	消 耗 標 準	消 能	消 退	消 除	
消 除 者	消 停	消 基 會	消 逝	消 散	消 暑	消 減	消 渴	
消 費	消 費 水 平	消 費 市 場	消 費 合 作 社	消 費 者	消 費 者 協 會	消 費 者 物 價 指 數	消 費 品	
消 費 基 金	消 費 稅	消 費 結 構	消 費 量	消 費 資 料	消 閒	消 愁	消 愁 解 悶	
消 愁 釋 悶	消 愁 釋 憒	消 損	消 暈	消 極	消 極 因 素	消 極 怠 工	消 極 態 度	
消 極 影 響	消 歇	消 溶	消 滅	消 禁	消 腫	消 解	消 像 散	
消 磁	消 磁 器	消 蝕	消 遣	消 魂	消 熱	消 瘦	消 緩	
消 震	消 磨	消 磨 時 光	消 融	消 險 固 堤	消 聲	消 聲 匿 跡	消 聲 滅 跡	
消 聲 器	消 釋	消 譴	涇 川	涇 渭 不 分	涇 渭 分 明	浦 口	浦 北	
浦 江	浦 東	浦 隆 地	浸 入	浸 水	浸 以	浸 出	浸 在	
浸 沉	浸 沒	浸 於	浸 明 浸 昌	浸 泡	浸 泡 物	浸 染	浸 洗	
浸 液	浸 軟	浸 透	浸 透 性	浸 著	浸 微 浸 消	浸 微 浸 滅	浸 會	
浸 溶	浸 過	浸 漬	浸 漬 者	浸 滿	浸 種	浸 蝕	浸 潤	
浸 潤 之 譖	浸 劑	浸 濕	浸 禮	海 上	海 上 交 通	海 上 交 通 線	海 上 巡 邏	
海 上 封 鎖	海 上 運 輸	海 口	海 口 市	海 子	海 不 波 溢	海 不 揚 波	海 中	
海 中 撈 月	海 內	海 內 外	海 內 存 知 己	海 內 無 雙	海 水	海 水 不 可 斗 量	海 水 浴	
海 水 群 飛	海 水 難 量	海 牙	海 牛	海 王 星	海 北	海 北 天 南	海 外	
海 外 投 資	海 外 奇 談	海 外 版	海 外 旅 行	海 外 基 金	海 外 華 人	海 外 僑 胞	海 外 關 係	
海 市	海 市 蜃 摟	海 市 蜃 樓	海 平 面	海 平 線	海 地	海 地 人	海 地 幣	
海 米	海 妖	海 床	海 芋	海 角	海 角 天 涯	海 巡 署	海 防	
海 事	海 事 仲 裁	海 兔	海 味	海 岸	海 岸 巡 防 署	海 岸 防 禦	海 岸 線	
海 岸 邊	海 底	海 底 撈 月	海 底 撈 針	海 底 隧 道	海 怪	海 拔	海 明 威	
海 東	海 林	海 河	海 波	海 波 不 驚	海 沸 山 裂	海 沸 山 搖	海 沸 江 翻	
海 沸 河 翻	海 沸 波 翻	海 狗	海 空	海 門	海 南	海 南 省	海 南 島	
海 城	海 屋 添 籌	海 屋 籌 添	海 星	海 枯 石 爛	海 洋	海 洋 生 物	海 洋 生 物 館	
海 洋 地 理	海 洋 污 染	海 洋 法	海 洋 科 學	海 洋 間	海 洋 資 源	海 洋 學	海 洋 霸 權	
海 流	海 洛 因	海 洛 英	海 相	海 軍	海 軍 基 地	海 軍 部	海 軍 陸 戰 隊	
海 面	海 面 下	海 風	海 哩	海 員	海 員 般	海 峽	海 峽 地 帶	
海 峽 防 禦	海 峽 兩 岸	海 島	海 晏 河 清	海 浪	海 狸	海 神	海 草	
海 豹	海 馬	海 區	海 參	海 域	海 基 會	海 帶	海 梨 柑	
海 涵	海 產	海 產 品	海 船	海 豚	海 豚 隊	海 貨	海 陸	
海 陸 空	海 魚	海 鳥	海 堤	海 報	海 景	海 景 畫	海 棠	
海 棠 花	海 棠 樹	海 棉	海 棉 狀	海 港	海 盜	海 盜 船	海 盜 隊	
海 筍	海 菜	海 量	海 塘	海 塗	海 損	海 溝	海 獅	
海 禁	海 葵	海 葬	海 蜇	海 裡	海 賊	海 路	海 運	
海 運 業	海 道	海 圖	海 端	海 綠 色	海 綿	海 綿 狀	海 誓	
海 誓 山 盟	海 魂 衫	海 嘯	海 嘯 山 崩	海 德 格 爾	海 德 堡	海 撈	海 模 型	
海 潮	海 線	海 蝦	海 輪	海 震	海 學	海 戰	海 澱	
海 澱 區	海 燕	海 龍	海 龜	海 濱	海 濱 浴 場	海 濤	海 礁	
海 膽	海 螺	海 闊 天 空	海 鮮	海 豐	海 獸	海 獺	海 疆	
海 蟹	海 邊	海 關	海 關 進 出 口	海 關 檢 查	海 關 總 署	海 難	海 難 船	
海 藻	海 灘	海 灘 裝	海 鷗	海 鹽	海 灣	海 灣 危 機	海 灣 地 區	
海 灣 戰 爭	海 鱺	浙 江	浙 江 省	浙 南	涓 涓	涓 滴	涓 滴 歸 公	
涉 及	涉 水	涉 水 者	涉 水 登 山	涉 世	涉 外	涉 外 工 作	涉 外 企 業	
涉 外 活 動	涉 外 單 位	涉 外 經 濟	涉 足	涉 足 其 間	涉 事	涉 者	涉 計	
涉 海 登 山	涉 堅 履 微	涉 堅 履 險	涉 嫌	涉 過	涉 險	涉 獵	浮 一 大 白	
浮 力	浮 上	浮 土	浮 子	浮 山	浮 升	浮 木	浮 水	
浮 出	浮 凸	浮 瓜 沉 李	浮 生	浮 生 若 寄	浮 生 若 夢	浮 皮 潦 草	浮 石	
浮 石 沉 木	浮 光 掠 影	浮 冰	浮 名	浮 名 虛 利	浮 名 虛 譽	浮 名 薄 利	浮 在	
浮 舟	浮 床	浮 沉	浮 言	浮 沫	浮 泛	浮 物	浮 花 浪 蕊	
浮 屍	浮 面	浮 家 浮 宅	浮 島	浮 浪	浮 財	浮 起	浮 動	
浮 動 工 資	浮 動 價 格	浮 圈	浮 屠	浮 掠	浮 梁	浮 淺	浮 現	
浮 船 塢	浮 游	浮 游 生 物	浮 游 動 物	浮 游 植 物	浮 渣	浮 筒	浮 萍	
浮 萍 浪 梗	浮 華	浮 詞 曲 說	浮 雲	浮 雲 富 貴	浮 雲 朝 露	浮 雲 蔽 日	浮 想	
浮 想 聯 翩	浮 腫	浮 誇	浮 誇 風	浮 塵	浮 翠 流 丹	浮 語 虛 辭	浮 標	
浮 橋	浮 蕩	浮 選	浮 雕	浮 點	浮 躁	浮 囊	浴 巾	
浴 池	浴 血	浴 血 奮 戰	浴 衣	浴 者	浴 室	浴 盆	浴 缸	
浴 堂	浴 液	浴 場	浴 裝	浴 療	浴 療 學	浩 大	浩 如 煙 海	
浩 劫	浩 氣	浩 氣 長 存	浩 浩	浩 浩 蕩 蕩	浩 渺	浩 然	浩 然 之 氣	
浩 然 正 氣	浩 翰	浩 蕩	浩 繁	浩 瀚	浩 淼	浩 鑫	浩 鑫 公 司	
浹 髓 淪 肌	浹 髓 淪 膚	涅 而 不 緇	涔 涔	烘 成	烘 托	烘 房	烘 缸	
烘 烘	烘 烤	烘 烤 似	烘 烤 器	烘 乾	烘 乾 機	烘 焙	烘 焦	
烘 雲 托 月	烘 碗 機	烘 箱	烘 爐	烘 襯	烤 火	烤 成	烤 肉	
烤 肉 叉	烤 肉 館	烤 的	烤 架	烤 面	烤 乾	烤 焦	烤 著	
烤 煙	烤 過	烤 餅	烤 盤	烤 箱	烤 鴨	烤 雞	烤 爐	
烤 麵 包	烙 刑	烙 印	烙 制	烙 痕	烙 畫	烙 畫 術	烙 餅	
烙 鐵	烈 士	烈 士 徇 名	烈 士 陵 園	烈 士 墓	烈 女	烈 女 不 更 二 夫	烈 女 不 嫁 二 夫	
烈 日	烈 火	烈 火 見 真 金	烈 火 真 金	烈 火 乾 柴	烈 性	烈 性 酒	烈 度	
烈 軍 屬	烈 風	烈 烈 轟 轟	烈 酒	烈 馬	烈 婦	烈 鳥	烈 暑	
烈 焰	烈 節	烈 屬	烏 七 八 槽	烏 七 八 糟	烏 干 達	烏 干 達 人	烏 之 雌 雄	
烏 天 黑 地	烏 日 鄉	烏 木	烏 合	烏 合 之 卒	烏 合 之 眾	烏 托 邦	烏 有	
烏 有 先 生	烏 江	烏 衣 子 弟	烏 克 蘭	烏 克 蘭 人	烏 孜 別 克	烏 來	烏 來 鄉	
烏 呼	烏 拉	烏 拉 圭	烏 拉 圭 人	烏 金	烏 亮	烏 飛 兔 走	烏 紗 帽	
烏 茲 別 克	烏 梅	烏 焉 成 馬	烏 魚	烏 鳥 之 情	烏 鳥 私 情	烏 棗	烏 絲	
烏 雲	烏 雲 密 佈	烏 黑	烏 煙 瘴 氣	烏 煤	烏 舅 金 奴	烏 賊	烏 賊 車	
烏 魯 木 齊	烏 魯 木 齊 市	烏 鴉	烏 燈 黑 火	烏 頭	烏 頭 白 馬 生 角	烏 龍	烏 龍 茶	
烏 龜	烏 龜 殼	烏 鵲 通 巢	烏 蘭	烏 蘭 巴 托	烏 蘭 牧 騎	烏 坵 海 域	爹 娘	
爹 爹	爹 媽	特 力	特 力 公 司	特 大	特 小	特 工	特 出	
特 刊	特 用	特 立 獨 行	特 任	特 向	特 地	特 好	特 有	
特 此	特 此 通 知	特 此 證 明	特 色	特 作	特 免	特 別	特 別 小	
特 別 代 辦	特 別 行 政 區	特 別 法	特 別 法 庭	特 別 室	特 別 高	特 別 強 調	特 別 會 議	
特 別 獎	特 別 嚴 重	特 告	特 困 戶	特 快	特 快 郵 遞	特 技	特 批	
特 使	特 例	特 來	特 命	特 命 全 權 大 使	特 定	特 定 條 件	特 定 場 合	
特 怪	特 性	特 拉 華	特 長	特 急	特 指	特 派	特 派 員	
特 洛 伊	特 為	特 約	特 計	特 准	特 座	特 效	特 效 藥	
特 書	特 案	特 殊	特 殊 化	特 殊 任 務	特 殊 作 用	特 殊 性	特 殊 政 策	
特 殊 要 求	特 殊 情 況 下	特 殊 教 育	特 殊 符 號	特 殊 需 要	特 級	特 郡	特 務	
特 區	特 區 建 設	特 強	特 教	特 混	特 產	特 異	特 異 功 能	
特 異 性	特 異 質	特 組	特 許	特 許 證	特 設	特 赦	特 逗	
特 備	特 惠	特 發 症	特 等	特 等 功	特 等 獎	特 集	特 項 經 費	
特 嫌	特 意	特 煩	特 聘	特 載	特 種	特 種 兵	特 種 部 隊	
特 種 營 業	特 稱	特 製	特 製 品	特 遣	特 遣 隊	特 需	特 價	
特 價 品	特 寫	特 徵	特 徵 值	特 徵 群	特 憂	特 獎	特 瘦	
特 稿	特 談	特 賣	特 質	特 艙	特 輯	特 選	特 錯	
特 優	特 邀	特 邀 代 表	特 點	特 護	特 權	特 權 階 級	狼 人	
狼 子 野 心	狼 子 獸 心	狼 心 狗 行	狼 心 狗 肺	狼 牙	狼 牙 棒	狼 犬	狼 叼	
狼 皮	狼 吞 虎 噬	狼 吞 虎 嚥	狼 奔 豕 突	狼 奔 鼠 竄	狼 狗	狼 孩	狼 狽	
狼 狽 不 堪	狼 狽 為 奸	狼 般	狼 毫	狼 猛 蜂 毒	狼 貪 鼠 竊	狼 飧 虎 嚥	狼 煙	
狼 煙 四 起	狼 群	狼 瘡	狼 瘡 性	狼 餐 虎 嚥	狼 嚎	狼 嚎 鬼 哭	狼 藉	
狼 顧 狐 疑	狹 小	狹 尖	狹 谷	狹 長	狹 巷	狹 軌	狹 窄	
狹 航 道	狹 帶	狹 量	狹 義	狹 路	狹 路 相 逢	狹 道	狹 隘	
狹 槽	狹 縫	狸 鼠	狸 貓	班 上	班 子	班 主 任	班 功 行 賞	
班 外	班 次	班 衣 戲 彩	班 車	班 亞 佛 列 克	班 固	班 底	班 房	
班 長	班 門 弄 斧	班 香 宋 艷	班 師	班 師 得 勝	班 班	班 級	班 荊 道 故	
班 荊 道 舊	班 馬 文 章	班 副	班 務	班 務 會	班 組	班 組 長	班 會	
班 裡	班 瑪	班 際	班 數	班 輪	班 機	班 禪	琉 球	
琉 璃	琉 璃 工 房	琉 璃 瓦	珠 子	珠 干 玉 戚	珠 玉 之 論	珠 玉 在 側	珠 玉 在 傍	
珠 光	珠 光 寶 氣	珠 光 體	珠 江	珠 江 口	珠 串	珠 沉 玉 沒	珠 沉 璧 碎	
珠 兒	珠 宮 貝 闕	珠 峰	珠 海	珠 圍 翠 繞	珠 殘 玉 碎	珠 圓 玉 潤	珠 飾	
珠 算	珠 翠 羅 綺	珠 質	珠 輝 玉 麗	珠 璣	珠 璣 咳 唾	珠 穆 朗 瑪	珠 穆 朗 瑪 峰	
珠 聯 璧 合	珠 還 合 浦	珠 繞 翠 圍	珠 簾	珠 寶	珠 寶 店	珠 寶 展	珠 寶 商	
珠 寶 翠 鑽	珠 寶 箱	畝 產	畝 產 量	畝 數	畜 力	畜 生	畜 羊	
畜 牧	畜 牧 場	畜 牧 業	畜 牧 學	畜 牲	畜 疫	畜 捨 內	畜 產	
畜 產 品	畜 禽	畜 群	畜 養	畜 類	畚 箕	留 一 手	留 了	
留 下	留 中 不 發	留 心	留 出	留 用	留 任	留 名	留 在	
留 存	留 守	留 守 處	留 成	留 有	留 有 餘 地	留 住	留 作	
留 步	留 言	留 言 板	留 言 條	留 言 簿	留 足	留 到	留 居	
留 底	留 念	留 法	留 治	留 空	留 信	留 客	留 待	
留 後 手	留 後 路	留 洋	留 美	留 個	留 校	留 校 察 看	留 神	
留 神 聽	留 級	留 起	留 宿	留 情	留 痕 跡	留 連	留 給	
留 著	留 傳	留 意	留 意 到	留 置	留 置 權	留 解	留 話	
留 廠 察 看	留 影	留 餘 地	留 駐	留 學	留 學 生	留 聲	留 聲 機	
留 點	留 歸	留 職	留 職 停 薪	留 醫	留 黨 察 看	留 戀	留 戀 不 捨	
疾 之 如 仇	疾 之 若 仇	疾 世 憤 俗	疾 如 旋 踵	疾 如 雷 電	疾 行	疾 步	疾 言	
疾 言 厲 色	疾 言 遽 色	疾 走	疾 足 先 得	疾 呼	疾 苦	疾 風	疾 風 知 勁 草	
疾 風 勁 草	疾 風 甚 雨	疾 風 掃 落 葉	疾 風 暴 雨	疾 風 驟 雨	疾 飛	疾 首	疾 首 痛 心	
疾 首 蹙 額	疾 書	疾 病	疾 病 管 制 局	疾 患	疾 速	疾 惡 好 善	疾 惡 如 仇	
疾 惡 若 仇	疾 痛 慘 怛	疾 跑	疾 雷 不 及 掩 耳	疾 雷 不 及 塞 耳	疾 馳	疾 駛	疾 聲 大 呼	
疾 聲 厲 色	疾 驅	病 了	病 人	病 人 用	病 入 膏 肓	病 中	病 友	
病 夫	病 由 口 入	病 休	病 兆	病 危	病 名	病 因	病 在 膏 肓	
病 死	病 床	病 灶	病 狂 喪 心	病 身	病 事 假	病 例	病 房	
病 況	病 狀	病 的	病 者	病 室	病 急 亂 投 醫	病 故	病 染 膏 肓	
病 毒	病 毒 基 因	病 毒 學	病 毒 學 家	病 科	病 重	病 倒	病 候	
病 原	病 原 性	病 原 菌	病 原 體	病 員	病 害	病 容	病 弱	
病 弱 者	病 案	病 根	病 株	病 症	病 退	病 院	病 假	
病 區	病 啦	病 國 殃 民	病 得	病 從 口 入	病 患	病 情	病 情 復 發	
病 情 惡 化	病 理	病 理 上	病 理 學	病 理 學 者	病 理 學 家	病 逝	病 殘	
病 痛	病 發	病 程	病 菌	病 象	病 勢	病 源	病 號	
病 態	病 榻	病 徵	病 學	病 歷	病 癒	病 蟲	病 蟲 害	
病 藥	病 魔	病 魔 纏 身	病 變	病 體	症 侯	症 侯 群	症 候	
症 候 群	症 像	疲 乏	疲 於	疲 於 奔 命	疲 倦	疲 倦 了	疲 倦 不 堪	
疲 弱	疲 軟	疲 勞	疲 勞 強 度	疲 勞 極 限	疲 塌	疲 頓	疲 憊	
疲 憊 不 堪	疲 憊 感	疳 瘡	疽 病	疽 熱	疼 不	疼 心 泣 血	疼 痛	
疼 愛	疹 子	疸 病	皋 蘭	益 上 損 下	益 友	益 加	益 性	
益 於	益 氣	益 高	益 國 利 民	益 處	益 鳥	益 智	益 無 忌 憚	
益 發	益 善	益 華	益 華 公 司	益 壽	益 壽 延 年	益 謙 虧 盈	益 蟲	
盎 士	盎 司	盎 盂 相 敲	盎 盂 相 擊	盎 格 魯	盎 斯	盎 然	眩 人	
眩 目	眩 目 震 耳	眩 光	眩 眼	眩 惑	眩 亂	眩 暈	眩 麗	
眩 耀	真 人	真 人 真 事	真 刀 真 槍	真 刀 實 槍	真 大	真 才	真 才 實 學	
真 不	真 不 容 易	真 切	真 心	真 心 真 意	真 心 誠 意	真 心 話	真 心 實 意	
真 主	真 功 夫	真 叫	真 巧	真 本	真 正	真 皮	真 丟 臉	
真 兇 實 犯	真 名 實 姓	真 地	真 好	真 如	真 似	真 我	真 抓 實 干	
真 沒 想 到	真 言	真 言 真 語	真 那	真 事	真 奇 怪	真 怪	真 性	
真 所	真 的	真 知	真 知 灼 見	真 空	真 空 計	真 空 管	真 金	
真 金 不 怕 火 煉	真 金 不 怕 火 燒	真 金 烈 火	真 品	真 是	真 相	真 相 大 白	真 面 目	
真 個	真 書	真 核 細 胞	真 格	真 氣	真 真	真 神	真 偽	
真 偽 莫 辨	真 假	真 假 難 辨	真 夠	真 情	真 情 實 意	真 情 實 感	真 理	
真 理 報	真 理 論	真 逗	真 敢	真 棒	真 善 美	真 菌	真 傳	
真 傻	真 意	真 想	真 愛	真 義	真 誠	真 話	真 跡	
真 像	真 實	真 實 性	真 實 感	真 槍	真 槍 實 彈	真 寫	真 摯	
真 確	真 憑 實 據	真 諦	真 壞	真 贓 實 犯	真 髓	眠 曲	眠 花 臥 柳	
眠 花 宿 柳	眠 思 夢 想	眠 雙 臥 雪	眨 巴	眨 動	眨 眼	眨 眼 睛	矩 形	
矩 步 方 行	矩 陣	砰 地	砰 地 一 聲	砰 砰	砰 然	砰 然 聲	砰 擊 聲	
砰 聲	砧 子	砧 木	砧 台	砧 板	砸 了	砸 下	砸 在	
砸 死	砸 舌	砸 開	砸 傷	砸 搶	砸 毀	砸 碎	砸 鍋	
砸 鍋 賣 鐵	砸 壞	砸 爛	砝 碼	破 了	破 口 大 罵	破 土	破 土 動 工	
破 天 荒	破 片	破 四	破 布	破 瓦 寒 窯	破 瓦 頹 垣	破 皮	破 冰	
破 冰 船	破 成	破 竹 之 勢	破 竹 建 瓴	破 衣	破 衣 服	破 戒	破 折	
破 折 號	破 車	破 例	破 門	破 門 而 入	破 城	破 洞	破 相	
破 紀 錄	破 計	破 家 危 國	破 家 為 國	破 家 散 業	破 家 鬻 子	破 案	破 案 率	
破 格	破 浪	破 涕 為 笑	破 破	破 破 爛 爛	破 記 錄	破 財	破 釜 沉 舟	
破 釜 沉 船	破 陣	破 除	破 除 迷 信	破 國 亡 宗	破 密	破 掉	破 敗	
破 產	破 產 法	破 產 者	破 產 宣 告	破 船	破 規 為 圜	破 帽	破 殼	
破 琴 絕 弦	破 裂	破 裂 音	破 費	破 鈔	破 傷 風	破 損	破 業 失 產	
破 滅	破 碎	破 碎 支 離	破 碎 片	破 碎 虛 空	破 落	破 解	破 漏	
破 綻	破 綻 百 出	破 廟	破 潰	破 鞋	破 壁 飛 去	破 曉	破 獲	
破 膽 喪 魂	破 膽 寒 心	破 舊	破 舊 不 堪	破 舊 立 新	破 題	破 壞	破 壞 力	
破 壞 分 子	破 壞 性	破 壞 者	破 壞 活 動	破 鏡	破 鏡 分 釵	破 鏡 重 合	破 鏡 重 圓	
破 鏡 重 歸	破 關	破 關 斬 將	破 譯	破 爛	破 爛 不 堪	破 爛 貨	破 罐 破 摔	
破 觚 為 圓	破 觚 為 圜	破 嘵	破 甑 生 塵	砷 化 物	砷 酸 鹽	砥 平 繩 直	砥 石	
砥 名 勵 節	砥 行 立 名	砥 行 磨 名	砥 兵 礪 伍	砥 柱	砥 柱 中 流	砥 節 守 公	砥 節 奉 公	
砥 節 礪 行	砥 礪	砥 礪 名 行	砥 礪 名 節	砥 礪 名 號	砥 礪 風 節	砥 礪 清 節	砥 礪 廉 隅	
祠 堂	祟 高	祖 上	祖 父	祖 父 母	祖 母	祖 先	祖 宗	
祖 居	祖 性	祖 述 堯 舜 憲 章 文 武	祖 孫	祖 師	祖 祖 輩 輩	祖 國	祖 國 各 地	
祖 國 統 一	祖 產	祖 逖 之 誓	祖 舜 宗 堯	祖 傳	祖 傳 秘 方	祖 業	祖 墳	
祖 輩	祖 遺	祖 龍 一 炬	祖 籍	神 人	神 人 共 悅	神 人 鑒 知	神 力	
神 上	神 女	神 女 生 涯	神 工 妙 力	神 工 鬼 力	神 工 鬼 斧	神 不 主 體	神 不 守 舍	
神 不 知 鬼 不 覺	神 丹	神 丹 妙 藥	神 分 志 奪	神 化	神 戶	神 木	神 水	
神 父	神 主	神 乎 其 神	神 仙	神 仙 中 人	神 仙 眷 屬	神 出 鬼 入	神 出 鬼 沒	
神 功	神 交	神 名	神 安 氣 定	神 州	神 州 大 地	神 州 赤 縣	神 州 陸 沉	
神 曲	神 池	神 而 明 之 存 乎 其 人	神 色	神 色 不 動	神 色 不 對	神 色 不 撓	神 色 不 驚	
神 色 自 若	神 色 自 得	神 色 怡 然	神 位	神 似	神 兵	神 助	神 助 似	
神 妙	神 完 氣 足	神 巫	神 志	神 志 不 清	神 甫	神 來 之 筆	神 侃	
神 奇	神 奇 荒 怪	神 宗	神 岡	神 往	神 怪	神 怡	神 怡 心 醉	
神 怡 心 曠	神 明	神 昏 意 亂	神 物	神 社	神 采	神 采 奕 奕	神 采 奕 然	
神 采 英 拔	神 采 飛 揚	神 采 煥 發	神 勇	神 品	神 威	神 怒 人 怨	神 怒 人 棄	
神 怒 天 誅	神 怒 民 怨	神 怒 民 痛	神 怒 鬼 怨	神 思	神 思 恍 惚	神 施 鬼 設	神 風	
神 飛 色 動	神 飛 色 舞	神 差 鬼 使	神 悟	神 效	神 氣	神 氣 十 足	神 氣 活 現	
神 氣 揚 揚	神 秘	神 秘 化	神 秘 色 彩	神 秘 感	神 秘 學	神 迷	神 馬	
神 鬼 不 測	神 鬼 出 沒	神 鬼 莫 測	神 鬼 難 測	神 動 色 飛	神 情	神 情 恍 惚	神 教	
神 清 氣 正	神 清 氣 全	神 清 氣 郎	神 清 氣 爽	神 清 骨 秀	神 異	神 聊	神 術	
神 術 妙 法	神 術 妙 計	神 術 妙 策	神 通	神 通 廣 大	神 通 鬱 壘	神 速	神 勞 形 瘁	
神 智	神 童	神 塔	神 意	神 搖 目 眩	神 搖 意 奪	神 搖 魂 蕩	神 會 心 契	
神 殿	神 爺	神 經	神 經 中 樞	神 經 元 萎 縮	神 經 末 梢	神 經 系 統	神 經 原	
神 經 病	神 經 衰 弱	神 經 細 胞	神 經 痛	神 經 節	神 經 過 敏	神 經 質	神 經 學	
神 經 錯 亂	神 經 鍵	神 經 纖 維	神 聖	神 聖 不 可 侵 犯	神 聖 化	神 聖 同 盟	神 號 鬼 哭	
神 話	神 話 般	神 農	神 農 架	神 遊	神 道	神 道 設 教	神 達 電 腦	
神 馳	神 像	神 態	神 態 自 若	神 槍 手	神 算	神 魂	神 魂 飛 越	
神 魂 搖 蕩	神 魂 撩 亂	神 魂 蕩 揚	神 魂 顛 倒	神 魂 飄 蕩	神 廟	神 論	神 器	
神 壇	神 學	神 學 者	神 機 妙 用	神 機 妙 術	神 機 妙 策	神 機 妙 算	神 機 莫 測	
神 燈	神 謀 妙 策	神 謀 妙 算	神 諭	神 頭 鬼 面	神 龍 失 勢	神 龍 見 首 不 見 尾	神 嚎 鬼 哭	
神 職	神 職 者	神 醫	神 離	神 離 貌 合	神 藥	神 韻	神 權	
神 籟 自 韻	神 靈	神 龕	祝 你	祝 君	祝 哽 祝 噎	祝 宴	祝 酒	
祝 酒 詞	祝 酒 歌	祝 酒 辭	祝 婚	祝 您	祝 捷	祝 詞	祝 賀	
祝 賀 者	祝 壽	祝 壽 延 年	祝 歌	祝 福	祝 福 者	祝 辭	祝 願	
秤 星	秤 架	秤 桿	秤 鉤	秤 稱	秤 盤	秤 錘	秤 砣	
秣 員	秣 馬	秣 馬 利 兵	秣 馬 厲 兵	秧 田	秧 苗	秧 歌	秧 齡	
租 人	租 入	租 下	租 子	租 戶	租 方	租 出	租 用	
租 地	租 地 人	租 米	租 住	租 佃	租 佃 關 係	租 車	租 房	
租 房 子	租 金	租 契	租 客	租 屋	租 屋 人	租 屋 者	租 界	
租 約	租 借	租 借 人	租 借 物	租 借 者	租 息	租 售	租 得	
租 船	租 期	租 稅	租 稅 轉 嫁	租 給	租 費	租 貸	租 貸 人	
租 賃	租 賃 承 包	租 賃 業	租 賃 經 營	租 價	租 額	租 籍	秦 王	
秦 代	秦 失 其 鹿	秦 池	秦 始 皇	秦 皇	秦 皇 島	秦 庭 之 哭	秦 庭 郎 鏡	
秦 晉 之 好	秦 晉 之 緣	秦 國	秦 朝	秦 腔	秦 樓 楚 館	秦 樓 謝 館	秦 嶺	
秦 鏡 高 懸	秦 歡 晉 愛	秩 序	秩 序 井 然	秘 方	秘 史	秘 本	秘 地	
秘 而 不 宣	秘 而 不 露	秘 技	秘 牢	秘 法	秘 法 家	秘 室	秘 洞	
秘 書	秘 書 工 作	秘 書 長	秘 書 處	秘 書 學	秘 密	秘 密 社 會	秘 密 活 動	
秘 密 組 織	秘 密 會 晤	秘 教	秘 訣	秘 結	秘 結 性	秘 傳	秘 說	
秘 魯	秘 魯 人	秘 魯 幣	秘 藥	秘 議	窄 小	窄 打	窄 用	
窄 地	窄 床	窄 門	窄 門 窄 戶	窄 巷	窄 軌	窄 幅	窄 路	
窄 道	窄 播	窄 橋	窈 窕	窈 窕 冥 冥	窈 窕 淑 女	站 了	站 人	
站 下	站 上	站 不 住	站 不 住 腳	站 友	站 台	站 立	站 名	
站 在	站 好	站 位	站 住	站 住 腳	站 兒	站 到	站 定	
站 或 坐	站 的	站 直	站 長	站 前	站 相	站 起	站 起 來	
站 崗	站 得 住	站 得 住 腳	站 得 高	站 得 穩	站 票	站 牌	站 著	
站 開	站 隊	站 端	站 檢	站 點	站 櫃 台	站 攏	站 穩	
站 穩 腳 跟	笆 斗	笆 圍	笑 了	笑 不 河 清	笑 出	笑 死	笑 吟 吟	
笑 呵 呵	笑 者	笑 咪 咪	笑 哈 哈	笑 後	笑 柄	笑 盈 盈	笑 面 外 交	
笑 面 夜 叉	笑 面 虎	笑 容	笑 容 可 掬	笑 料	笑 氣	笑 破	笑 笑	
笑 紋	笑 納	笑 啦	笑 得	笑 掉	笑 眼	笑 逐 顏 開	笑 渦	
笑 著	笑 著 說	笑 傲	笑 意	笑 裡 藏 刀	笑 話	笑 話 書	笑 窩	
笑 語	笑 說	笑 貌	笑 劇	笑 嘻 嘻	笑 瞇 瞇	笑 罵	笑 罵 從 汝	
笑 談	笑 聲	笑 臉	笑 臉 相 迎	笑 顏	笑 靨	粉 □	粉 末	
粉 末 冶 金	粉 末 狀	粉 白	粉 白 墨 黑	粉 白 黛 黑	粉 白 黛 綠	粉 皮	粉 色	
粉 坊	粉 妝 玉 琢	粉 身 灰 骨	粉 身 碎 骨	粉 刷	粉 刺	粉 沫	粉 狀	
粉 紅	粉 紅 色	粉 面	粉 面 油 頭	粉 料	粉 骨 碎 身	粉 彩	粉 條	
粉 盒	粉 筆	粉 絲	粉 煤	粉 煤 灰	粉 碎	粉 碎 器	粉 碎 機	
粉 腸	粉 飾	粉 飾 太 平	粉 塵	粉 嫩	粉 膏	粉 蜜	粉 語	
粉 餅	粉 撲	粉 漿	粉 蝶	粉 墨	粉 墨 登 場	粉 劑	粉 擦	
粉 牆	粉 黛	粉 蠟 筆	紡 成	紡 車	紡 拓 會	紡 紗	紡 紗 機	
紡 絲	紡 綢	紡 線	紡 錠	紡 錘	紡 錘 形	紡 錘 狀	紡 織	
紡 織 工 業 部	紡 織 成	紡 織 品	紡 織 部	紡 織 業	紡 織 廠	紡 織 機	紡 纖 股	
紗 巾	紗 包	紗 布	紗 車	紗 帶	紗 窗	紗 筒	紗 管	
紗 綻	紗 廠	紗 線	紗 燈	紗 錠	紗 頭	紗 櫥	紗 籠	
紋 布	紋 印	紋 身	紋 兒	紋 法	紋 眉	紋 面	紋 風 不 動	
紋 病 毒	紋 理	紋 理 狀	紋 章	紋 章 學	紋 絲	紋 絲 不 動	紋 溝	
紋 路	紋 銀	紋 線	紊 流	紊 亂	素 口 罵 人	素 不 相 識	素 什 錦	
素 日	素 以	素 未	素 交	素 仰	素 有	素 色	素 衣	
素 材	素 車 白 馬	素 來	素 性	素 服	素 油	素 門 凡 流	素 昧 平 生	
素 昧 生 平	素 面 朝 天	素 食	素 食 主 義	素 食 者	素 席	素 酒	素 淡	
素 淨	素 描	素 絲 良 馬	素 絲 羔 羊	素 菜	素 雅	素 愛	素 聞	
素 數	素 緞	素 質	素 養	素 樸	素 鋼	素 餐	素 餐 屍 位	
素 隱 行 怪	素 雞	素 願	索 人	索 引	索 引 簿	索 尼	索 回	
索 求	索 沙	索 具	索 取	索 命	索 性	索 非 亞	索 垢 尋 疵	
索 要	索 拿	索 捕	索 索	索 討	索 馬 利 亞	索 馬 裡	索 馬 裡 人	
索 然	索 然 無 味	索 債	索 賄	索 道	索 盡 枯 腸	索 餌 洄 游	索 價	
索 價 高	索 賠	索 賠 者	索 橋	索 興	索 環	索 還	索 隱 行 怪	
索 羅 門	索 韻	純 一	純 小 數	純 化	純 毛	純 牛 奶	純 正	
純 白	純 收	純 收 入	純 收 益	純 色	純 血 統	純 血 種	純 作	
純 利	純 利 潤	純 系	純 金	純 度	純 為	純 美	純 苯	
純 音	純 氧	純 真	純 純	純 淨	純 理	純 棉	純 然	
純 愛	純 態	純 種	純 種 馬	純 粹	純 綿	純 銀	純 潔	
純 熟	純 樸	純 鋼	純 羹 鱸 膾	純 屬	純 屬 偶 然	純 鐵	純 鹼	
純 鱸 之 思	紐 扣	紐 扣 兒	紐 西 蘭	紐 西 蘭 銀 行	紐 芬 蘭	紐 芬 蘭 人	紐 約	
紐 約 人 壽	紐 約 大 都 會 隊	紐 倫 堡	紐 國	紐 帶	紐 新 企 業	紐 澤 西 籃 網 隊	紕 漏	
紕 繆	級 任	級 次	級 別	級 差	級 差 地 租	級 距	級 數	
紜 紜	納 人	納 入	納 士 招 賢	納 污	納 米 比 亞	納 西	納 西 族	
納 言	納 妾	納 芬	納 垢 藏 污	納 秒	納 降	納 員	納 貢	
納 貢 稱 臣	納 骨 堂	納 骨 塔	納 涼	納 悶	納 悶 兒	納 稅	納 稅 人	
納 新	納 新 吐 故	納 賄	納 屢 踵 決	納 粹	納 粹 化	納 鞋	納 樹	
納 諫	納 諫 如 流	紙 人	紙 刀	紙 上	紙 上 談 兵	紙 巾	紙 孔	
紙 片	紙 灰	紙 老 虎	紙 色	紙 夾	紙 卷	紙 杯	紙 板	
紙 板 盒	紙 版	紙 花	紙 芯	紙 型	紙 面	紙 頁	紙 風 車	
紙 屑	紙 扇	紙 框	紙 做	紙 堆	紙 帶	紙 張	紙 捻	
紙 桶	紙 條	紙 盒	紙 盒 紙	紙 袋	紙 傘	紙 媒	紙 牌	
紙 短 情 長	紙 筆	紙 貴 洛 城	紙 煙	紙 裡 包 不 住 火	紙 飾	紙 團	紙 墊	
紙 幣	紙 管	紙 廠	紙 槳	紙 漿	紙 漿 質	紙 盤	紙 箱	
紙 糊	紙 醉 金 迷	紙 燈	紙 錢	紙 頭	紙 壓	紙 簍	紙 簿	
紙 繩	紙 證	紙 邊	紙 類	紙 類 股	紛 至 沓 來	紛 呈	紛 吹	
紛 爭	紛 紅 駭 綠	紛 飛	紛 紜	紛 紜 雜 沓	紛 紛	紛 紛 揚 揚	紛 紛 攘 攘	
紛 紛 籍 籍	紛 亂	紛 落	紛 聚	紛 繁	紛 擾	紛 雜	紛 沓	
缺 一	缺 口	缺 少	缺 心 少 肺	缺 心 眼 兒	缺 斤 少 兩	缺 斤 短 兩	缺 月 再 圓	
缺 欠	缺 水	缺 乏	缺 乏 著	缺 失	缺 考	缺 衣 少 食	缺 油	
缺 門	缺 省	缺 面	缺 食 無 衣	缺 員	缺 席	缺 席 者	缺 料	
缺 氧	缺 氧 症	缺 略	缺 貨	缺 陷	缺 詞	缺 量	缺 項	
缺 勤	缺 損	缺 疑	缺 德	缺 編	缺 課	缺 憾	缺 錢	
缺 點	缺 醫 少 藥	缺 額	羔 皮	羔 羊	羔 羊 皮	翅 片	翅 狀	
翅 脈	翅 膀	翁 仲	翁 虹	翁 倩 玉	翁 婿	翁 聲	耆 年 碩 德	
耆 儒 碩 老	耆 儒 碩 望	耆 儒 碩 德	耕 牛	耕 田	耕 地	耕 地 面 積	耕 作	
耕 作 制 度	耕 作 層	耕 具	耕 法	耕 畜	耕 耘	耕 犁	耕 農	
耕 種	耕 戰	耕 機	耕 翻	耙 子	耙 犁	耗 子	耗 水	
耗 去	耗 用	耗 光	耗 油	耗 油 率	耗 料	耗 時	耗 氣	
耗 能	耗 掉	耗 散	耗 散 結 構	耗 減	耗 費	耗 量	耗 損	
耗 損 量	耗 資	耗 電	耗 電 量	耗 盡	耗 竭	耗 熱	耗 糧	
耽 心	耽 於	耽 於 酒 色	耽 迷	耽 迷 肉 慾	耽 溺	耽 誤	耽 擱	
耽 驚 受 怕	耿 介	耿 直	耿 耿	耿 耿 於 心	耿 耿 於 懷	耿 鼎	耿 鼎 企 業	
脂 性	脂 肪	脂 肪 酸	脂 肪 瘤	脂 肪 質	脂 粉	脂 蛋 白	脂 膏	
胰 子	胰 島	胰 島 素	胰 液	胰 蛋 白 □	胰 腺	胰 腺 炎	胰 臟 炎	
胰 髒	脅 肩 諂 笑	脅 持	脅 迫	脅 從	胭 脂	胭 脂 紅	胴 體	
脆 生	脆 皮	脆 目	脆 而 不 堅	脆 耳	脆 快	脆 性	脆 弱	
脆 骨	脆 過	脆 餅	脆 熟	胸 口	胸 中	胸 中 有 數	胸 中 宿 物	
胸 中 無 數	胸 毛	胸 有 丘 壑	胸 有 甲 兵	胸 有 成 竹	胸 肌	胸 衣	胸 花	
胸 前	胸 針	胸 骨	胸 側	胸 脯	胸 部	胸 章	胸 圍	
胸 椎	胸 無 大 志	胸 無 城 府	胸 無 點 墨	胸 腔	胸 罩	胸 腹	胸 腺	
胸 裡	胸 飾	胸 像	胸 線	胸 膛	胸 膜	胸 膜 炎	胸 壁	
胸 牆	胸 懷	胸 懷 大 局	胸 懷 大 志	胸 襟	胸 鰭	胳 肢	胳 膊	
胳 臂	脈 中	脈 內	脈 石	脈 沖	脈 沖 星	脈 沖 計	脈 沖 雷 達	
脈 波	脈 波 計	脈 門	脈 息	脈 脈	脈 動	脈 理	脈 斑 巖	
脈 絡	脈 搏	脈 搏 表	脈 搏 計	脈 跳	脈 管	脈 碼	脈 橫	
能 人	能 力	能 上	能 上 能 下	能 士	能 工 巧 匠	能 不	能 不 能	
能 分	能 分 泌	能 分 開	能 化	能 及	能 手	能 文	能 文 能 武	
能 以	能 生 存	能 生 育	能 生 活	能 生 產	能 用	能 交 換	能 共 處	
能 再	能 吃	能 在	能 成	能 成 為	能 曲 解	能 有	能 行	
能 住	能 伸	能 克 服	能 否	能 吸 收	能 忍	能 忍 耐	能 把	
能 投 票	能 改	能 改 變	能 育 性	能 見	能 見 度	能 言 舌 辯	能 言 快 語	
能 言 取 譬	能 言 善 辯	能 走 動	能 防 護	能 事	能 使	能 到	能 屈 能 伸	
能 征 慣 戰	能 放	能 知	能 者	能 者 多 勞	能 者 為 師	能 勃 起	能 按	
能 活	能 為	能 看	能 穿 孔	能 耐	能 負 責	能 飛	能 飛 翔	
能 倒	能 修 補	能 容	能 容 納	能 振 動	能 租 用	能 笑	能 級	
能 耗	能 航 行	能 送	能 做	能 動	能 動 性	能 夠	能 夠 使	
能 將	能 帶	能 接 受	能 推 理	能 理 解	能 被	能 透 過	能 勝 任	
能 測	能 視 度	能 越	能 量	能 開	能 傳 送	能 傳 達	能 幹	
能 想	能 想 到	能 想 像	能 損 壞	能 源	能 源 工 業	能 源 技 術	能 源 供 應	
能 源 科 學	能 源 部	能 源 開 發	能 源 經 濟	能 源 管 理	能 解 釋	能 達	能 達 到	
能 實 行	能 對	能 歌 善 舞	能 算	能 認	能 說	能 說 會 道	能 潛 水	
能 賞 債	能 適 應	能 養	能 養 活	能 學	能 整 除	能 橫 越	能 辨	
能 償 債	能 瞭 解	能 避 免	能 識	能 證	能 證 實	能 勸 告	能 譯	
能 聽	能 變	能 掐 會 算	脊 丘	脊 柱	脊 背	脊 神 經	脊 索	
脊 骨	脊 椎	脊 椎 炎	脊 椎 骨	脊 椎 動 物	脊 樑	脊 樑 骨	脊 髓	
脊 髓 炎	胼 手 胝 足	胼 手 胼 足	胯 下	胯 子	胯 骨	胯 帶	胯 裙	
臭 不	臭 不 可 當	臭 不 可 聞	臭 名	臭 名 昭 著	臭 名 昭 彰	臭 名 遠 揚	臭 老 九	
臭 事	臭 味	臭 味 相 投	臭 的	臭 美	臭 氣	臭 氣 熏 天	臭 氧	
臭 氧 層	臭 魚	臭 跡	臭 彈	臭 罵	臭 錢	臭 蟲	臭 椿	
舀 出	舀 起	舀 湯	舐 食	舐 犢	航 天	航 天 工 業 部	航 天 飛 機	
航 天 部	航 天 器	航 太 工 業	航 向	航 宇	航 次	航 行	航 行 於	
航 行 者	航 材	航 空	航 空 公 司	航 空 母 艦	航 空 兵	航 空 信	航 空 站	
航 空 術	航 空 港	航 空 隊	航 空 器	航 空 學	航 政	航 員	航 校	
航 海	航 海 史	航 海 家	航 海 術	航 海 圖	航 海 證	航 班	航 務	
航 船	航 速	航 期	航 渡	航 測	航 程	航 照	航 跡	
航 路	航 運	航 運 史	航 運 股	航 運 業	航 道	航 圖	航 標	
航 模	航 線	航 艦	航 權 談 判	般 配	芻 議	茫 茫	茫 茫 苦 海	
茫 茫 然	茫 無 頭 緒	茫 然	茫 然 不 解	茫 然 自 失	茫 然 若 失	茫 然 若 迷	茫 然 費 解	
荒 土	荒 山	荒 山 野 嶺	荒 丘	荒 地	荒 年	荒 村	荒 沙	
荒 災	荒 坡	荒 怪 不 經	荒 郊	荒 郊 曠 野	荒 原	荒 唐	荒 唐 不 經	
荒 唐 言 行	荒 唐 事	荒 唐 無 稽	荒 島	荒 時	荒 時 暴 月	荒 涼	荒 淫	
荒 淫 無 恥	荒 疏	荒 野	荒 無	荒 無 人 煙	荒 發	荒 亂	荒 漠	
荒 僻	荒 廢	荒 數	荒 瘠	荒 誕	荒 誕 不 經	荒 誕 主 義	荒 誕 派	
荒 蕪	荒 謬	荒 謬 絕 倫	荒 灘	荔 枝	荊 天 棘 地	荊 州	荊 芥	
荊 門	荊 條	荊 釵 布 裙	荊 釵 布 襖	荊 釵 裙 布	荊 棘	荊 棘 多	荊 棘 塞 途	
荊 棘 銅 駝	荊 棘 叢 生	荊 榛 滿 目	茸 毛	茸 茸	草 屯 鎮	草 木	草 木 灰	
草 木 皆 兵	草 包	草 本	草 本 植 物	草 用	草 皮	草 地	草 地 般	
草 字	草 灰	草 色	草 行 露 宿	草 衣 木 食	草 甸	草 豆	草 函	
草 制	草 坪	草 底	草 房	草 狀	草 芥	草 長 鶯 飛	草 屋	
草 炭	草 科	草 籽	草 約	草 食	草 食 動 物	草 原	草 料	
草 書	草 書 體	草 案	草 根	草 紙	草 荒	草 草	草 草 了 事	
草 偃 風 行	草 偃 風 從	草 動	草 堆	草 堂	草 寇	草 率	草 率 行 事	
草 率 將 事	草 率 從 事	草 笠	草 莽	草 莓	草 魚	草 創	草 場	
草 帽	草 棚	草 稈	草 菅	草 菅 人 命	草 間 求 活	草 黃	草 葉	
草 裙 舞	草 圖	草 墊	草 墊 子	草 種	草 窪	草 窩	草 綠	
草 綠 色	草 蓆	草 酸	草 酸 鹽	草 餅	草 寫	草 履 蟲	草 稿	
草 蝦	草 鞋	草 澤	草 褥	草 頭	草 頭 天 子	草 擬	草 叢	
草 蟲	草 雞	草 廬	草 廬 三 顧	草 簾	草 簽	草 繩	草 藥	
草 靡 風 行	草 類	草 體	草 垛	草 舖	茴 香	荏 苒	茲 有	
茲 事 體 大	茲 將	茹 毛	茹 毛 飲 血	茹 古 涵 今	茹 泣 吐 悲	茹 柔 吐 剛	茹 苦 含 辛	
茶 几	茶 山	茶 巾	茶 水	茶 市	茶 托	茶 色	茶 余 酒 後	
茶 坊	茶 具	茶 味	茶 房	茶 杯	茶 油	茶 社	茶 花	
茶 花 女	茶 室	茶 缸	茶 食	茶 香	茶 宴	茶 座	茶 匙	
茶 商	茶 場	茶 壺	茶 壺 嘴	茶 晶	茶 湯	茶 稅	茶 筒	
茶 飯	茶 園	茶 會	茶 碗	茶 葉	茶 葉 罐	茶 話	茶 話 會	
茶 資	茶 農	茶 道	茶 碟	茶 精	茶 餅	茶 樓	茶 盤	
茶 褐 色	茶 質	茶 餘 飯 後	茶 餘 飯 飽	茶 樹	茶 錢	茶 館	茶 點	
茶 禮	茶 鏡	茶 爐	茶 罐	茶 鹼	茶 ��	茗 茶	荀 子	
茱 莉 安 娜 馬 格 里 斯	茱 萸	茱 麗 葉 畢 諾 西	荃 灣	虔 心	虔 信 派	虔 敬	虔 誠	
蚊 力 負 山	蚊 子	蚊 香	蚊 帳	蚊 煙	蚊 蟲	蚊 蠅	蚊 類	
蚤 類	蚩 蚩 群 氓	蚌 埠	蚌 殼	蚌 蠣	蚜 蟲	衰 亡	衰 世	
衰 朽	衰 老	衰 弱	衰 弱 性	衰 退	衰 退 中	衰 敗	衰 期	
衰 減	衰 減 器	衰 亂	衰 微	衰 落	衰 落 者	衰 竭	衰 頹	
衰 邁	衰 變	衷 心	衷 心 希 望	衷 心 感 謝	衷 曲	衷 情	衷 腸	
袁 詠 儀	記 人	記 入	記 下	記 上	記 大 過	記 工	記 工 員	
記 不 起	記 仇	記 分	記 分 冊	記 分 卡	記 分 板	記 分 牌	記 分 簿	
記 日 記	記 出	記 功	記 名	記 在	記 好	記 有	記 住	
記 作	記 牢	記 事	記 事 本	記 取	記 念	記 性	記 性 好	
記 於	記 法	記 的	記 者	記 者 來 信	記 者 招 待 會	記 者 站	記 恨	
記 要	記 述	記 時	記 時 計	記 時 器	記 起	記 帳	記 得	
記 掛	記 敘	記 敘 文	記 著	記 號	記 號 法	記 載	記 載 了	
記 過	記 實	記 賬	記 憶	記 憶 力	記 憶 猶 新	記 憶 體	記 錯	
記 錄	記 錄 本	記 錄 在 案	記 錄 員	記 錄 器	討 人 喜 愛	討 人 喜 歡	討 人 嫌	
討 人 厭	討 乞	討 巧	討 平	討 伐	討 好	討 取	討 便 宜	
討 是 尋 非	討 逆 除 暴	討 帳	討 教	討 惡 剪 暴	討 飯	討 債	討 嫌	
討 厭	討 價	討 價 還 價	討 論	討 論 決 定	討 論 者	討 論 家	討 論 通 過	
討 論 會	討 論 課	討 賞	討 賬	討 親	討 錢	討 還	討 饒	
訕 笑	訊 中	訊 台	訊 利 電 業	訊 息	訊 問	訊 問 者	訊 康 科 技	
訊 連 科 技	訊 號	訊 號 炮	訊 碟 科 技	訓 人	訓 令	訓 斥	訓 示	
訓 兵 秣 馬	訓 戒	訓 勉	訓 馬 師	訓 喻	訓 詞	訓 詁	訓 話	
訓 語	訓 誡	訓 誡 者	訓 誨	訓 練	訓 練 大 綱	訓 練 任 務	訓 練 有 素	
訓 練 制 度	訓 練 法	訓 練 者	訓 練 保 障	訓 練 師	訓 練 班	訓 練 過	訓 導	
訓 導 長	訓 諭	訖 站	訖 號	訖 證	豈 不	豈 不 怪 哉	豈 不 是	
豈 止	豈 可	豈 只	豈 有 他 哉	豈 有 此 理	豈 但	豈 弟 君 子	豈 知	
豈 非	豈 是	豈 容 他 人 鼾 睡	豈 能	豈 敢	豺 虎 肆 虐	豺 狼	豺 狼 成 性	
豺 狼 野 心	豺 狼 塞 道	豺 狼 當 塗	豺 狼 當 路	豺 狼 當 道	豺 狼 橫 道	豹 子	豹 皮	
豹 死 留 皮	財 力	財 力 物 力	財 大 氣 粗	財 主	財 多 命 殆	財 東	財 物	
財 政	財 政 危 機	財 政 局	財 政 部	財 政 部 長	財 政 學	財 氣	財 神	
財 神 爺	財 迷	財 迷 心 竅	財 務	財 務 危 機	財 務 收 支	財 務 員	財 務 處	
財 務 預 測	財 務 預 算	財 務 管 理	財 產	財 產 稅	財 產 權	財 貨	財 富	
財 測	財 稅	財 貿	財 會	財 源	財 源 茂 盛	財 經	財 經 政 策	
財 路	財 運	財 運 亨 通	財 匱 為 絀	財 團	財 竭 力 盡	財 閥	財 禮	
財 寶	財 權	財 殫 力 盡	貢 物	貢 品	貢 禹 彈 冠	貢 院	貢 稅	
貢 寮	貢 禮	貢 獻	貢 獻 力 量	貢 獻 出	貢 獻 者	起 了	起 子	
起 手 回 春	起 止	起 毛	起 毛 機	起 水	起 火	起 用	起 立	
起 伏	起 伏 變 化	起 先	起 吊	起 名	起 因	起 回 聲	起 早	
起 早 貪 黑	起 早 摸 黑	起 死 人 肉 白 骨	起 死 回 生	起 自	起 色	起 作	起 作 用	
起 兵	起 兵 動 眾	起 坐	起 床	起 床 號	起 折	起 更	起 步	
起 決 定 作 用	起 見	起 身	起 事	起 事 者	起 來	起 到	起 卸	
起 始	起 居	起 居 室	起 岸	起 征	起 承 轉 合	起 於	起 波 紋	
起 泡	起 泡 沫	起 初	起 勁	起 勁 兒	起 哄	起 封	起 急	
起 計	起 重	起 重 機	起 降	起 風	起 飛	起 飛 前	起 首	
起 家	起 師 動 眾	起 浪	起 租	起 站	起 航	起 草	起 草 者	
起 訖	起 動	起 動 器	起 眼	起 貨	起 復	起 斑 點	起 痙 攣	
起 程	起 筆	起 著	起 訴	起 訴 人	起 訴 狀	起 訴 者	起 訴 書	
起 跑	起 跑 線	起 跑 器	起 開	起 搏 器	起 搏 點	起 敬	起 源	
起 源 於	起 義	起 義 者	起 義 將 領	起 義 領 袖	起 腳	起 落	起 落 架	
起 跳	起 運	起 電	起 電 盤	起 疑	起 端	起 算	起 網	
起 舞	起 誓	起 價	起 皺	起 皺 紋	起 碼	起 稿	起 縐	
起 頭	起 獲	起 聲	起 錨	起 錨 機	起 鍋	起 霜	起 點	
起 爆	起 贓	起 曬 斑	躬 先 士 卒	躬 先 表 率	躬 自 菲 薄	躬 行	躬 行 節 儉	
躬 行 實 踐	躬 作	躬 身	躬 耕	躬 耕 樂 道	躬 逢 其 盛	躬 新 細 務	躬 蹈 矢 石	
躬 體 力 行	躬 擐 甲 冑	軒 昂	軒 昂 自 若	軒 昂 氣 宇	軒 軒 甚 得	軒 敞	軒 然	
軒 然 大 波	軒 然 巨 波	軒 轅	軒 轅 劍	辱 名	辱 沒	辱 身 敗 名	辱 門 敗 戶	
辱 國	辱 國 喪 師	辱 罵	辱 罵 者	送 一	送 人	送 人 情	送 入	
送 上	送 子	送 方	送 以	送 出	送 去	送 交	送 回	
送 存	送 死	送 至	送 行	送 別	送 走	送 來	送 到	
送 命	送 往	送 往 事 居	送 往 迎 來	送 信	送 信 人	送 客	送 故 迎 新	
送 秋 波	送 展	送 時	送 氣	送 送	送 掉	送 畢	送 眼 流 眉	
送 終	送 貨	送 貨 人	送 貨 上 門	送 貨 單	送 喪	送 報	送 報 生	
送 給	送 評	送 進	送 暖 偷 寒	送 歲	送 煤	送 經	送 葬	
送 話	送 話 器	送 達	送 電	送 與	送 審	送 稿	送 親	
送 錯	送 錢	送 檢	送 還	送 殯	送 禮	送 糧	送 舊 迎 新	
送 驗	逆 子	逆 子 賊 臣	逆 反	逆 反 心 理	逆 反 應	逆 天	逆 天 犯 順	
逆 天 背 理	逆 天 悖 理	逆 天 違 理	逆 天 暴 物	逆 水	逆 水 行 舟	逆 火	逆 光	
逆 向	逆 耳	逆 耳 之 言	逆 耳 利 行	逆 耳 忠 言	逆 臣	逆 臣 賊 子	逆 行	
逆 行 倒 施	逆 來 順 受	逆 取 順 守	逆 命	逆 定 理	逆 信	逆 施	逆 流	
逆 流 而 上	逆 風	逆 風 撐 船	逆 差	逆 旅	逆 時 針	逆 浪	逆 動	
逆 情 悖 理	逆 旋 風	逆 理 違 天	逆 進	逆 運 算	逆 電	逆 境	逆 對 數	
逆 轉	逆 鏡	逆 黨	逆 襲	逆 變	迷 了	迷 人	迷 人 眼 目	
迷 幻 劑	迷 幻 藥	迷 失	迷 失 方 向	迷 而 不 反	迷 而 不 返	迷 而 知 返	迷 住	
迷 你	迷 你 品	迷 你 裙	迷 走	迷 念	迷 於	迷 盲	迷 花 眼 笑	
迷 信	迷 信 活 動	迷 津	迷 迭 香	迷 宮	迷 宮 般	迷 留 沒 亂	迷 航	
迷 茫	迷 迷 糊 糊	迷 陣 似	迷 惘	迷 途	迷 途 知 反	迷 途 知 返	迷 惑	
迷 惑 人	迷 惑 不 解	迷 亂	迷 路	迷 夢	迷 漫	迷 魂	迷 魂 陣	
迷 魂 奪 魄	迷 嬉 裝	迷 糊	迷 醉	迷 濛	迷 瞪	迷 朦	迷 藏	
迷 蹤 失 路	迷 離	迷 離 撲 朔	迷 離 惝 恍	迷 霧	迷 戀	退 一 步	退 一 步 說	
退 一 步 講	退 入	退 下	退 化	退 火	退 付	退 出	退 去	
退 伙	退 伍	退 伍 軍 人	退 休	退 休 工 人	退 休 制 度	退 休 者	退 休 金	
退 休 軍 官	退 休 條 例	退 休 費	退 休 幹 部	退 回	退 守	退 有 後 言	退 色	
退 行	退 位	退 兵	退 役	退 役 安 置	退 役 制 度	退 役 軍 官	退 步	
退 走	退 到	退 坡	退 定	退 居	退 居 二 線	退 房	退 股	
退 卻	退 後	退 思 補 過	退 席	退 庭	退 料	退 格	退 租	
退 除 役 官 兵 輔 導 委 員 會	退 堂	退 婚	退 徙 三 捨	退 掉	退 敗	退 現	退 票	
退 票 金 額	退 票 張 數	退 貨	退 場	退 換	退 朝	退 款	退 稅	
退 給	退 貼 金	退 匯	退 落	退 號	退 補	退 路	退 磁	
退 輔 會	退 撫 基 金	退 敵	退 漿	退 潮	退 熱	退 熱 藥	退 稿	
退 賠	退 養	退 學	退 燒	退 親	退 錢	退 縮	退 縮 不 前	
退 避	退 避 三 舍	退 還	退 隱	退 繞	退 職	退 離	退 關	
退 黨	退 贓	退 讓	迴 力 球	迴 光 返 照	迴 旋	迴 旋 加 速 器	迴 旋 狀	
迴 旋 餘 地	迴 廊	迴 腸	迴 腸 九 轉	迴 腸 寸 斷	迴 腸 傷 氣	迴 腸 蕩 氣	迴 環	
迴 盪	迴 避	迴 響	逃 入	逃 亡	逃 亡 者	逃 不 掉	逃 不 過	
逃 之 夭 夭	逃 出	逃 犯	逃 生	逃 回	逃 兵	逃 災 躲 難	逃 災 避 難	
逃 走	逃 到	逃 命	逃 奔	逃 往	逃 卻	逃 家	逃 荒	
逃 匿	逃 婚	逃 掉	逃 脫	逃 脫 法	逃 脫 者	逃 脫 術	逃 術	
逃 散	逃 稅	逃 稅 者	逃 跑	逃 逸	逃 進	逃 開	逃 債	
逃 罪	逃 路	逃 過	逃 遁	逃 漏	逃 課	逃 學	逃 學 生	
逃 學 者	逃 避	逃 避 者	逃 避 現 實	逃 歸	逃 竄	逃 離	逃 繳	
逃 難	追 上	追 亡 逐 北	追 及	追 加	追 打	追 本 穹 源	追 本 窮 源	
追 交	追 任	追 名 逐 利	追 回	追 兵	追 抓	追 求	追 究	
追 究 刑 事 責 任	追 究 責 任	追 來	追 到	追 命	追 奔 逐 北	追 底	追 征	
追 念	追 昔	追 者	追 肥	追 封	追 思	追 星	追 查	
追 查 出	追 述	追 風 捕 影	追 風 覓 影	追 風 逐 電	追 風 躡 影	追 悔	追 悔 不 及	
追 悔 何 及	追 悔 莫 及	追 捕	追 根 究 底	追 根 溯 源	追 索	追 索 權	追 記	
追 討	追 偶	追 問	追 悼	追 悼 會	追 授	追 敘	追 殺	
追 逐	追 尋	追 期	追 減	追 著	追 訴	追 剿	追 想	
追 溯	追 補	追 逼	追 過	追 認	追 趕	追 趕 者	追 遠 慎 終	
追 魂 攝 魄	追 賠	追 駟 不 及	追 憶	追 隨	追 隨 者	追 擊	追 獲	
追 還	追 獵	追 獵 聲	追 蹤	追 蹤 覓 跡	追 蹤 覓 影	追 蹤 報 道	追 懷	
追 繳	追 贈	追 贓	追 歡 取 樂	追 歡 買 笑	迸 出	迸 出 物	迸 發	
迸 裂	郡 王	郡 主	郡 長	郡 候	郡 縣	郝 西 瑟	郝 免	
郝 柏 村	郢 匠 揮 斤	郢 書 燕 說	酒 入 舌 出	酒 巴	酒 巴 女	酒 令	酒 仙	
酒 地 花 天	酒 曲	酒 有 別 腸	酒 池 肉 林	酒 肉	酒 肉 朋 友	酒 色	酒 色 之 徒	
酒 色 財 氣	酒 伴	酒 吧	酒 吧 間	酒 坊	酒 狂	酒 足 飯 飽	酒 味	
酒 店	酒 店 主	酒 性	酒 杯	酒 花	酒 保	酒 後	酒 後 開 車	
酒 泉	酒 盅	酒 食	酒 食 地 獄	酒 食 過 從	酒 食 徵 逐	酒 香	酒 倉	
酒 員	酒 家	酒 宴	酒 席	酒 徒	酒 神	酒 神 祭	酒 神 節	
酒 鬼	酒 桶	酒 瓶	酒 袋	酒 壺	酒 渣	酒 渦	酒 稅	
酒 窖	酒 菜	酒 酣 耳 熱	酒 量	酒 量 大	酒 間	酒 飯	酒 意	
酒 會	酒 煙	酒 碗	酒 話	酒 過	酒 瘋	酒 窩	酒 窩 兒	
酒 精	酒 精 表	酒 精 燈	酒 綠 燈 紅	酒 遞	酒 廠	酒 樓	酒 漿	
酒 質	酒 醉	酒 醉 駕 車	酒 器	酒 興	酒 錢	酒 館	酒 糟	
酒 糟 鼻 子	酒 櫃	酒 甕 飯 囊	酒 藥	酒 類	酒 囊 飯 袋	酒 癮	酒 罐	
酒 釀	酒 舖	配 人	配 上	配 子	配 工	配 手	配 方	
配 比	配 平	配 件	配 全	配 列	配 合	配 合 默 契	配 好	
配 成	配 有	配 色	配 位	配 系	配 角	配 房	配 股	
配 音	配 套	配 套 工 程	配 套 成 龍	配 套 技 術	配 套 改 革	配 息	配 料	
配 送	配 偶	配 偶 體	配 售	配 得 上	配 備	配 備 有	配 景	
配 發	配 給	配 給 品	配 菜	配 量	配 搭	配 置	配 置 文 件	
配 載	配 電	配 電 盤	配 飾	配 對	配 對 物	配 槍	配 種	
配 製	配 齊	配 樂	配 線	配 銷	配 器	配 糖 物	配 錯	
配 餐	配 戴	配 額	配 藥	配 藥 者	配 藥 學	配 屬	酌 予	
酌 加	酌 古 御 今	酌 收	酌 定	酌 情	酌 情 處 理	酌 減	酌 量	
酌 辦	酌 議	釘 入	釘 上	釘 子	釘 子 戶	釘 在	釘 扣	
釘 死	釘 住	釘 牢	釘 書	釘 書 機	釘 耙	釘 釘	釘 梢	
釘 眼	釘 帽	釘 進	釘 鉗	釘 槍	釘 緊	釘 樁	釘 頭	
釘 頭 槌	釘 錘	針 孔	針 尖	針 尖 狀	針 形	針 灸	針 灸 療 法	
針 芒	針 角	針 刺	針 法	針 狀	針 狀 葉	針 狀 體	針 砭	
針 桿	針 眼	針 棒	針 筒	針 貶	針 葉 林	針 葉 樹	針 對	
針 對 性	針 管	針 鼻	針 編	針 線	針 線 包	針 線 盒	針 線 袋	
針 鋒 相 對	針 劑	針 頭	針 壓 法	針 療	針 織	針 織 物	針 織 品	
針 織 機	釜 山	釜 中 之 魚	釜 中 生 魚	釜 底 抽 薪	釜 底 枯 魚	釜 底 游 魚	釜 魚 幕 燕	
釜 裡 之 魚	閃 出	閃 失	閃 光	閃 光 燈	閃 回	閃 身	閃 放	
閃 亮	閃 亮 物	閃 閃	閃 閃 發 光	閃 動	閃 現	閃 開	閃 腰	
閃 躲	閃 過	閃 電	閃 電 式	閃 語	閃 鋅 礦	閃 燈	閃 擊	
閃 避	閃 點	閃 爍	閃 爍 其 詞	閃 爍 其 辭	閃 耀	院 士	院 子	
院 中	院 內	院 方	院 外	院 地	院 址	院 系	院 制	
院 定	院 所	院 長	院 門	院 校	院 校 訓 練	院 校 教 育	院 校 體 制	
院 部	院 會	院 落	院 裡	院 牆	院 職	陣 亡	陣 子	
陣 列	陣 地	陣 地 防 禦	陣 地 戰	陣 式	陣 形	陣 法	陣 雨	
陣 雨 般	陣 前	陣 紀	陣 風	陣 容	陣 陣	陣 痛	陣 發 性	
陣 勢	陣 腳	陣 線	陣 營	陡 立	陡 坡	陡 岸	陡 直	
陡 度	陡 降	陡 峭	陡 峻	陡 然	陡 增	陡 壁	陡 變	
陛 下	陝 人	陝 北	陝 甘 寧 邊 區	陝 西	陝 西 省	陝 縣	除 了	
除 了 他	除 夕	除 夕 之 夜	除 毛	除 以	除 四 害	除 外	除 皮	
除 冰	除 名	除 奸	除 此	除 此 之 外	除 此 以 外	除 此 而 外	除 污	
除 災	除 邪	除 法	除 非	除 卻	除 垢	除 害	除 害 物	
除 息	除 根	除 疾 遺 類	除 病	除 臭	除 臭 劑	除 草	除 草 人	
除 草 者	除 草 劑	除 草 機	除 得	除 患 興 利	除 掉	除 莠 劑	除 雪 機	
除 喪	除 惡	除 惡 務 本	除 惡 務 盡	除 殘 去 穢	除 開	除 痰	除 腥	
除 號	除 塵	除 塵 器	除 弊	除 盡	除 磁	除 數	除 暴	
除 暴 安 良	除 錯	除 濕	除 濕 機	除 霜	除 舊	除 舊 布 新	除 舊 更 新	
除 蟲	除 蟲 菊	除 蟲 劑	除 雜 草	除 額	除 霧	除 權	除 澇	
除 ��	陞 技 電 腦	陞 官	陞 官 發 財	陞 遷	隻 字	隻 字 不 提	隻 字 片 言	
隻 羊	隻 身	隻 身 孤 影	隻 雞 鬥 酒	隻 雞 絮 酒	馬 丁	馬 丁 尼 茲	馬 刀	
馬 力	馬 上	馬 口 鐵	馬 大 哈	馬 子	馬 工 枚 速	馬 不 停 蹄	馬 六 甲	
馬 匹	馬 太 福 音	馬 扎	馬 牛 襟 裾	馬 王 堆	馬 可 波 羅	馬 奶	馬 尼 拉	
馬 弁	馬 札	馬 甲	馬 皮	馬 伕	馬 仰 人 翻	馬 列	馬 列 主 義	
馬 耳 他	馬 耳 東 風	馬 肉	馬 伴	馬 克	馬 克 思	馬 克 思 主 義	馬 克 思 主 義 者	
馬 克 思 列 寧 主 義	馬 利 諾	馬 壯	馬 壯 人 強	馬 屁	馬 尾	馬 尾 巴	馬 尾 松	
馬 志 玲	馬 步	馬 肚 帶	馬 車	馬 車 伕	馬 里 諾	馬 來	馬 來 人	
馬 來 半 島	馬 來 西 亞	馬 來 亞	馬 來 亞 人	馬 來 群 島	馬 來 語	馬 兒	馬 其 頓	
馬 刺	馬 刺 隊	馬 到 成 功	馬 房	馬 拉	馬 拉 松	馬 拉 松 比 賽	馬 拉 威	
馬 拉 度 那	馬 放 南 山	馬 林 魚	馬 虎	馬 前	馬 前 卒	馬 勃 牛 溲	馬 哈	
馬 哈 地	馬 奎 爾	馬 威	馬 後	馬 後 炮	馬 後 腳	馬 約 卡	馬 背	
馬 英 九	馬 革	馬 革 裹 屍	馬 飛 奔	馬 首	馬 首 是 瞻	馬 座	馬 恩 列 斯	
馬 格 麗 特	馬 祖	馬 馬 虎 虎	馬 國 畢	馬 桶	馬 球	馬 紹 爾	馬 紹 爾 群 島	
馬 術	馬 術 家	馬 販	馬 場	馬 廄	馬 掌	馬 棚	馬 隊	
馬 雅 人	馬 雅 族	馬 雅 語	馬 塞 諸 塞	馬 歇 爾	馬 群	馬 腳	馬 蜂	
馬 裡 蘭	馬 賊	馬 路	馬 達	馬 達 加 斯 加	馬 鈴	馬 鈴 薯	馬 靴	
馬 槍	馬 爾 他	馬 爾 薩 斯	馬 腿	馬 舞 之 災	馬 褂	馬 赫	馬 赫 計	
馬 赫 數	馬 嘴	馬 嘶 聲	馬 德 望	馬 德 裡	馬 槽	馬 鞍	馬 鞍 山	
馬 鞍 形	馬 駒	馬 齒 徒 增	馬 齒 莧	馬 燈	馬 褲	馬 褲 呢	馬 蹄	
馬 蹄 形	馬 蹄 蓮	馬 蹄 鐵	馬 頸 圈	馬 頭	馬 龍	馬 龍 白 蘭 度	馬 幫	
馬 戲	馬 戲 團	馬 糞	馬 糞 紙	馬 臉	馬 賽	馬 賽 曲	馬 賽 克	
馬 賽 網 賽	馬 鞭	馬 鬃	馬 繩	馬 類	馬 嚼 子	骨 子	骨 子 裡	
骨 內 膜	骨 化	骨 片	骨 朵 兒	骨 灰	骨 灰 盒	骨 肉	骨 肉 分 離	
骨 肉 同 胞	骨 肉 至 親	骨 肉 相 連	骨 肉 相 殘	骨 肉 情	骨 肉 團 圓	骨 肉 離 散	骨 形	
骨 折	骨 刺	骨 架	骨 盆	骨 科	骨 科 學	骨 料	骨 氣	
骨 粉	骨 胳	骨 牌	骨 痛	骨 痛 熱	骨 幹	骨 幹 力 量	骨 幹 企 業	
骨 碌	骨 碌 碌	骨 節	骨 瘤	骨 瘦 如 柴	骨 瘦 如 豺	骨 膜	骨 膜 炎	
骨 膠	骨 質	骨 質 疏 鬆	骨 質 疏 鬆 症	骨 質 增 生	骨 器	骨 頭	骨 骸	
骨 骼	骨 骼 肌	骨 癌	骨 關 節	骨 騰 肉 飛	骨 顫 肉 驚	骨 髓	骨 髓 炎	
骨 鯁 之 臣	骨 鯁 在 喉	高 一	高 人	高 人 一 等	高 人 一 頭	高 人 勝 士	高 人 逸 士	
高 三	高 下	高 下 任 心	高 下 在 心	高 下 其 手	高 大	高 小	高 山	
高 山 仰 之	高 山 仰 止	高 山 流 水	高 山 峰	高 山 景 行	高 工	高 干	高 才	
高 才 大 德	高 才 大 學	高 才 生	高 才 卓 識	高 才 捷 足	高 才 博 學	高 才 絕 學	高 才 碩 學	
高 才 遠 識	高 不	高 不 可 登	高 不 可 攀	高 不 成	高 不 成 低 不 就	高 不 湊 低 不 就	高 不 輳 低 不 就	
高 中	高 中 生	高 亢	高 分	高 分 子	高 分 子 化 學	高 分 辨	高 分 辨 率	
高 天	高 天 厚 地	高 手	高 手 林 立	高 文 大 冊	高 文 典 冊	高 比 重	高 水 平	
高 牙 大 纛	高 出	高 凸	高 加 索	高 功	高 功 率	高 卡 路 裡	高 台	
高 市	高 立	高 地	高 年	高 年 級	高 考	高 而 不 危	高 而 尖	
高 自 位 置	高 自 標 置	高 自 標 樹	高 自 驕 大	高 血 壓	高 位	高 位 厚 祿	高 位 重 祿	
高 估	高 低	高 低 槓	高 利	高 利 率	高 利 貸	高 利 貸 者	高 坐	
高 妙	高 技	高 技 企 業	高 技 術	高 材	高 材 生	高 材 疾 足	高 材 捷 足	
高 步 通 衢	高 步 雲 衢	高 男	高 見	高 見 遠 視	高 足	高 足 弟 子	高 車 駟 馬	
高 呼	高 坡	高 官	高 官 厚 祿	高 官 極 品	高 尚	高 尚 風 格	高 居	
高 岸 深 谷	高 怡 平	高 性 能	高 招	高 抬 明 鏡	高 抬 貴 手	高 於	高 於 一 切	
高 昂	高 明	高 明 遠 見	高 明 遠 視	高 昇	高 朋 故 戚	高 朋 滿 座	高 枕 不 虞	
高 枕 勿 憂	高 枕 安 臥	高 枕 安 寢	高 枕 而 臥	高 枕 無 事	高 枕 無 虞	高 枕 無 憂	高 林 實 業	
高 法	高 沸 點	高 的	高 空	高 空 作 業	高 空 彈 跳	高 者	高 臥	
高 臥 東 山	高 保 真	高 保 真 度	高 品 質	高 屋	高 屋 建 瓴	高 度	高 度 計	
高 架	高 架 橋	高 科 技	高 背	高 胡	高 限	高 音	高 音 符	
高 音 喇 叭	高 音 調	高 風	高 風 亮 節	高 風 勁 節	高 風 峻 節	高 飛	高 飛 球	
高 飛 遠 走	高 飛 遠 翔	高 飛 遠 集	高 飛 遠 遁	高 飛 遠 舉	高 倍	高 值	高 個	
高 個 子	高 原	高 原 寒 區	高 唐	高 射	高 射 炮	高 峻	高 峰	
高 峰 期	高 差	高 座	高 徒	高 效	高 效 能	高 效 率	高 校	
高 根	高 根 鞋	高 氣 壓	高 消 費	高 祖	高 級	高 級 人 民 法 院	高 級 工 程 師	
高 級 中 學	高 級 法 院	高 級 的	高 級 社	高 級 建 築 師	高 級 軍 官	高 級 班	高 級 專 員	
高 級 教 師	高 級 階 段	高 級 幹 部	高 級 會 計 師	高 級 經 濟 師	高 級 農 藝 師	高 級 領 導 人	高 級 職 稱	
高 能	高 能 物 理	高 起	高 高	高 高 在 上	高 高 興 興	高 唱	高 堂	
高 密	高 密 度 聚 乙 烯	高 強	高 強 度	高 掛	高 教	高 啟	高 淳	
高 清 愿	高 深	高 深 莫 測	高 球	高 球 公 開 賽	高 球 賽	高 產	高 產 量	
高 產 穩 產	高 票	高 處	高 蛋 白	高 速	高 速 公 路	高 速 度	高 速 鋼	
高 勝 美	高 喊	高 喚	高 報	高 寒	高 寒 地 區	高 寒 區	高 就	
高 帽	高 帽 子	高 揚	高 敞	高 斯	高 棉	高 棉 人	高 棉 語	
高 棚	高 畫 質	高 稈 作 物	高 程	高 稅	高 窗	高 等	高 等 法 院	
高 等 院 校	高 等 動 物	高 等 教 育	高 等 植 物	高 等 數 學	高 等 學 校	高 腔	高 視	
高 視 闊 步	高 貴	高 貴 者	高 超	高 郵	高 階	高 陽 公 子	高 陽 狂 客	
高 陽 酒 徒	高 雅	高 雅 簡 樸	高 雄	高 雄 市	高 雄 企 銀	高 雄 港	高 雄 銀 行	
高 雄 縣	高 雲	高 傲	高 塔	高 新	高 新 技 術	高 新 商 銀	高 業 弟 子	
高 溫	高 溫 計	高 煙 囪	高 照	高 矮	高 節 清 風	高 節 邁 俗	高 粱	
高 粱 米	高 義 薄 雲	高 腰	高 腳	高 腳 櫥	高 跟	高 跟 鞋	高 達	
高 過	高 僧	高 壽	高 對	高 歌	高 歌 猛 進	高 漲	高 爾	
高 爾 夫	高 爾 夫 球	高 爾 基	高 碳 鋼	高 端	高 精	高 精 尖	高 精 度	
高 綿	高 聚 物	高 閣	高 價	高 層	高 層 次	高 層 建 築	高 層 雲	
高 標	高 標 準	高 標 號	高 樓	高 樓 大 廈	高 潔	高 潮	高 潮 迭 起	
高 潮 線	高 熱	高 瘦	高 緯 度	高 談	高 談 闊 論	高 調	高 論	
高 質	高 質 量	高 踞	高 鋁 金	高 鋁 金 屬	高 鋒 工 業	高 樹	高 樹 鄉	
高 橋 克 典	高 燒	高 築	高 縣	高 興	高 興 昌	高 錳 酸 鉀	高 頻	
高 頻 率	高 頭	高 壓	高 壓 手 段	高 壓 政 策	高 壓 電	高 壓 線	高 壓 鍋	
高 嶺 土	高 嶺 石	高 檔	高 檔 商 品	高 檢 署	高 爵 厚 祿	高 爵 重 祿	高 爵 豐 祿	
高 牆	高 聲	高 聳	高 舉	高 薪	高 點	高 瞻 遠 囑	高 瞻 遠 矚	
高 職	高 額	高 額 頭	高 攀	高 櫥	高 識 遠 見	高 識 遠 度	高 蹺	
高 難 度	高 麗	高 懸	高 爐	高 齡	高 欄	高 鐵	高 顯	
鬥 士	鬥 牛	鬥 牛 士	鬥 志	鬥 志 昂 揚	鬥 爭	鬥 爭 史	鬥 爭 性	
鬥 爭 者	鬥 垮	鬥 拳	鬥 氣	鬥 酒 百 篇	鬥 酒 隻 雞	鬥 酒 學 士	鬥 智	
鬥 劍 者	鬥 嘴	鬥 毆	鬥 輸	鬥 雞	鬥 雞 走 狗	鬥 雞 眼	鬼 大	
鬼 子	鬼 才	鬼 火	鬼 出 電 入	鬼 叫	鬼 目	鬼 似	鬼 把 戲	
鬼 使	鬼 使 神 差	鬼 怪	鬼 怕 惡 人	鬼 斧	鬼 斧 神 工	鬼 斧 神 功	鬼 物	
鬼 門	鬼 門 關	鬼 剃 頭	鬼 屋	鬼 胎	鬼 計	鬼 計 多 端	鬼 哭	
鬼 哭 狼 嚎	鬼 哭 神 嚎	鬼 氣	鬼 祟	鬼 神	鬼 神 學	鬼 迷 心 竅	鬼 鬼 祟 祟	
鬼 崇	鬼 混	鬼 筆	鬼 節	鬼 話	鬼 說	鬼 魂	鬼 魅	
鬼 魅 伎 倆	鬼 頭 鬼 腦	鬼 臉	鬼 點	鬼 蜮	鬼 蜮 伎 倆	乾 巴	乾 巴 巴	
乾 冰	乾 安	乾 肉	乾 肉 片	乾 肉 餅	乾 旱	乾 旱 地 區	乾 兒 子	
乾 坤	乾 坤 再 造	乾 性 油	乾 果	乾 杯	乾 咳	乾 屍	乾 枯	
乾 洗	乾 娘	乾 柴	乾 爹	乾 笑	乾 脆	乾 草	乾 草 架	
乾 草 粉	乾 草 堆	乾 草 機	乾 乾 淨 淨	乾 涸	乾 淨	乾 淨 利 落	乾 爽	
乾 貨	乾 透	乾 渴	乾 硬	乾 著 急	乾 菜	乾 裂	乾 隆	
乾 媽	乾 電 池	乾 瘦	乾 縣	乾 嚎	乾 濕	乾 燥	乾 燥 窯	
乾 燥 箱	乾 燥 劑	乾 燥 器	乾 薪	乾 糧	乾 糧 袋	乾 癟	偽 本	
偽 劣	偽 劣 商 品	偽 名	偽 托	偽 作	偽 君 子	偽 言	偽 足	
偽 品	偽 軍	偽 書	偽 造	偽 造 文 書	偽 造 物	偽 造 者	偽 造 品	
偽 造 貨 幣 罪	偽 造 鈔 票 罪	偽 造 罪	偽 筆	偽 善	偽 鈔	偽 鈔 犯 罪	偽 鈔 集 團	
偽 經	偽 裝	偽 幣	偽 滿	偽 稱	偽 誓	偽 誓 者	偽 職	
偽 藥	偽 證	偽 證 者	偽 證 罪	停 了	停 下	停 下 來	停 工	
停 工 待 料	停 勻	停 手	停 止	停 止 工 作	停 止 者	停 水	停 火	
停 火 協 議	停 付	停 刊	停 用	停 在	停 住	停 妥	停 步	
停 車	停 車 站	停 車 場	停 車 塔	停 辛 佇 苦	停 征	停 放	停 泊	
停 泊 所	停 泊 處	停 泊 稅	停 泊 費	停 表	停 建	停 指	停 柩	
停 飛	停 食	停 員	停 息	停 留	停 留 在	停 留 時 間	停 站	
停 航	停 掉	停 產	停 閉	停 發	停 著	停 雲 落 月	停 業	
停 業 整 頓	停 歇	停 當	停 話	停 電	停 頓	停 滯	停 滯 不 前	
停 撥	停 播	停 課	停 靠	停 駐	停 駛	停 學	停 戰	
停 機	停 機 坪	停 機 庫	停 機 場	停 辦	停 薪	停 薪 留 職	停 擺	
停 職	停 職 檢 查	停 轉	停 繳	假 人	假 力 於 人	假 大 空	假 山	
假 中	假 仁	假 仁 假 義	假 公	假 公 濟 私	假 分 數	假 手	假 手 於 人	
假 支 票	假 日	假 牙	假 以	假 以 辭 色	假 充	假 正 經	假 皮	
假 列	假 劣	假 名	假 如	假 扣	假 托	假 死	假 作	
假 扮	假 言 判 斷	假 足	假 使	假 定	假 定 者	假 性	假 泣	
假 的	假 肢	假 虎 張 威	假 冒	假 冒 者	假 冒 品	假 品	假 科 學	
假 若	假 面	假 面 具	假 面 舞	假 面 劇	假 音	假 借	假 借 名 義	
假 哭	假 哭 者	假 娘	假 案	假 根	假 珠 寶	假 笑	假 假	
假 帳	假 情 假 義	假 情 報	假 條	假 眼	假 票	假 紳 士	假 設	
假 貨	假 造	假 途 滅 虢	假 寐	假 惡 丑	假 惺 惺	假 期	假 植	
假 鈔	假 嗓	假 意	假 想	假 義	假 裝	假 話	假 像	
假 像 牙	假 幣	假 漆	假 睡	假 誓	假 說	假 髮	假 戲	
假 戲 真 做	假 聲	假 藍	假 藥	假 證	假 鬍 子	假 釋	假 釋 犯	
偃 兵 息 甲	偃 武 修 文	偃 師	偃 鼠 飲 河	偃 旗 臥 鼓	偃 旗 息 鼓	偌 大	做 了	
做 人	做 上	做 女	做 小 伏 低	做 工	做 不 完	做 不 到	做 手	
做 手 勢	做 手 腳	做 文 章	做 主	做 出	做 功	做 生 日	做 生 意	
做 白 日 夢	做 好	做 好 事	做 好 做 歹	做 成	做 早 操	做 伴	做 作	
做 完	做 弄	做 事	做 些	做 到	做 官	做 於	做 東	
做 法	做 客	做 活	做 派	做 為	做 個	做 笑	做 記 號	
做 起	做 鬼	做 鬼 臉	做 假	做 做	做 張 做 智	做 得	做 得 好	
做 得 成	做 莊	做 媚 眼	做 媒	做 牌	做 絕	做 著	做 菜	
做 裁 縫	做 買 賣	做 飯	做 飯 菜	做 愛	做 詩	做 賊	做 賊 心 虛	
做 遊 戲	做 壽	做 夢	做 弊	做 歉 做 好	做 算 術	做 廣 告	做 樣	
做 操	做 親	做 錯	做 戲	做 聲	做 題	做 壞	做 壞 事	
做 響	偉 人	偉 大	偉 大 事 業	偉 大 意 義	偉 全 實 業	偉 業	偉 詮 電 子	
偉 績	偉 聯 工 業	偉 聯 運 輸	健 力	健 立	健 全	健 全 制 度	健 全 法 制	
健 在	健 行	健 壯	健 壯 性	健 忘	健 忘 者	健 忘 症	健 步	
健 身	健 身 房	健 身 術	健 兒	健 旺	健 保	健 保 局	健 美	
健 美 操	健 胃	健 胃 劑	健 將	健 康	健 康 小 百 科	健 康 法	健 康 食 品	
健 康 種 苗	健 康 檢 查	健 康 講 座	健 脾	健 談	偶 一 為 之	偶 犯	偶 生	
偶 合	偶 而	偶 見	偶 者	偶 校 驗	偶 然	偶 然 性	偶 然 論	
偶 發	偶 發 事 件	偶 發 性	偶 筆	偶 感	偶 極	偶 遇	偶 像	
偶 像 化	偶 爾	偶 語	偶 數	偎 依	偎 抱	偎 紅 依 翠	偎 香 依 玉	
偎 著	偕 同	偕 老	偕 行	偵 查	偵 毒	偵 破	偵 訊	
偵 探	偵 探 小 說	偵 速	偵 測	偵 察	偵 察 出	偵 察 兵	偵 察 者	
偵 察 員	偵 察 排	偵 察 機	偵 緝	偵 辦	偵 檢	偵 聽	偵 聽 器	
側 方	側 目	側 目 而 視	側 光	側 向	側 耳	側 耳 細 聽	側 耳 傾 聽	
側 投 球	側 投 影	側 身	側 身 政 檀	側 房	側 枝	側 板	側 泳	
側 臥	側 芽	側 門	側 室	側 扁	側 柏	側 重	側 重 於	
側 重 點	側 面	側 面 像	側 面 圖	側 頁	側 風	側 根	側 記	
側 部	側 筆	側 視	側 視 圖	側 進	側 滑	側 道	側 過	
側 睡	側 聞	側 標	側 線	側 壁	側 燈	側 壓	側 擊	
側 翼	側 櫥	側 邊	側 體	偷 了	偷 人	偷 工	偷 工 減 料	
偷 天 換 日	偷 心	偷 手	偷 去	偷 巧	偷 生	偷 合 取 容	偷 合 苟 容	
偷 吃	偷 奸 取 巧	偷 安	偷 有	偷 走	偷 取	偷 取 者	偷 拍	
偷 東 摸 西	偷 空	偷 看	偷 食	偷 香 竊 玉	偷 乘	偷 笑	偷 逃	
偷 做	偷 偷	偷 偷 干	偷 偷 做	偷 偷 摸 摸	偷 售	偷 帶	偷 得	
偷 情	偷 採	偷 梁 換 柱	偷 眼	偷 寒 送 暖	偷 換	偷 渡	偷 渡 者	
偷 牌	偷 盜	偷 稅	偷 稅 漏 稅	偷 著	偷 越	偷 閒	偷 愛	
偷 運	偷 過	偷 摸	偷 漏	偷 漏 稅	偷 學	偷 窺	偷 錢	
偷 營	偷 獵 者	偷 雞 不 著 蝕 把 米	偷 雞 盜 狗	偷 雞 摸 狗	偷 懶	偷 懶 者	偷 歡	
偷 聽	偷 聽 者	偷 襲	偷 竊	偏 了	偏 下	偏 上	偏 大	
偏 小	偏 才	偏 不	偏 少	偏 心	偏 心 輪	偏 方	偏 右	
偏 巧	偏 左	偏 正	偏 生	偏 光	偏 光 計	偏 光 器	偏 光 鏡	
偏 向	偏 多	偏 好	偏 安	偏 西	偏 低	偏 序	偏 見	
偏 角	偏 房	偏 於	偏 松	偏 析	偏 門	偏 信	偏 信 則 暗	
偏 南	偏 歪	偏 流	偏 要	偏 重	偏 重 於	偏 食	偏 倚	
偏 差	偏 振	偏 振 片	偏 振 光	偏 旁	偏 狹	偏 窄	偏 航	
偏 高	偏 偏	偏 執	偏 執 狂	偏 將	偏 斜	偏 移	偏 移 量	
偏 袒	偏 距	偏 愛	偏 極	偏 滑	偏 緊	偏 輕	偏 遠	
偏 頗	偏 僻	偏 僻 處	偏 寬	偏 廢	偏 激	偏 頭 痛	偏 壓	
偏 轉	偏 轉 線 圈	偏 離	偏 護	偏 聽	偏 聽 偏 信	偏 癱	倏 來 忽 往	
倏 忽	倏 然	兜 抄	兜 兒	兜 底	兜 風	兜 兜	兜 售	
兜 圈	兜 圈 子	兜 著	兜 著 走	兜 裡	兜 銷	兜 攬	冕 寧	
冕 禮	剪 刀	剪 刀 差	剪 力	剪 下	剪 子	剪 切	剪 切 板	
剪 切 塊	剪 毛	剪 出	剪 去	剪 字	剪 成	剪 羊	剪 羊 毛	
剪 床	剪 取	剪 枝	剪 枝 竭 流	剪 砍	剪 修	剪 紙	剪 草	
剪 草 除 根	剪 除	剪 接	剪 掉	剪 票	剪 報	剪 惡 除 奸	剪 畫	
剪 短	剪 著	剪 裁	剪 貼	剪 貼 板	剪 貼 簿	剪 開	剪 須 和 藥	
剪 過	剪 綵	剪 齊	剪 影	剪 髮	剪 輯	剪 應 力	剪 燭 西 窗	
剪 斷	副 井	副 反 應	副 手	副 主 任	副 主 席	副 主 教	副 主 祭	
副 主 管	副 主 編	副 代 表	副 刊	副 司 令 員	副 司 長	副 外 長	副 市 長	
副 本	副 甲	副 件	副 印	副 作 用	副 局 長	副 委 員	副 委 員 長	
副 官	副 官 職	副 社 長	副 品	副 省 長	副 研	副 研 究 員	副 科 長	
副 食	副 食 品	副 首 相	副 修	副 書 記	副 校 長	副 秘 書 長	副 站 長	
副 郡 長	副 院 長	副 參 謀 長	副 堂	副 執 事	副 將	副 教 授	副 族 元 素	
副 理 事 長	副 產	副 產 品	副 組 長	副 處 長	副 部 長	副 腎	副 詞	
副 業	副 經 理	副 署	副 團 長	副 監 督	副 領 事	副 審	副 標	
副 標 題	副 熱 帶	副 編 審	副 線	副 線 圈	副 駕 駛	副 縣 長	副 館 長	
副 總	副 總 工 程 師	副 總 參 謀 長	副 總 理	副 總 統	副 總 裁	副 總 督	副 總 經 理	
副 總 編	副 總 編 輯	副 翼	副 聯	副 職	副 醫 師	副 題	副 藥	
副 證	副 關 節	副 議 長	副 譯 審	勒 人	勒 支	勒 令	勒 死	
勒 住	勒 抑	勒 索	勒 索 者	勒 馬	勒 馬 懸 崖	勒 殺	勒 緊	
勒 頸	勒 壓	勒 贖	務 川	務 工	務 公	務 必	務 本	
務 本 力 穡	務 本 抑 末	務 正	務 生	務 求	務 使	務 派	務 時	
務 商	務 期	務 虛	務 須	務 當	務 農	務 實	務 實 去 華	
務 盡	務 請	勘 正	勘 災	勘 定	勘 查	勘 探	勘 探 者	
勘 探 隊	勘 測	勘 亂	勘 察	勘 漏	勘 誤	勘 誤 表	勘 謬	
勘 驗	動 了	動 人	動 人 心 弦	動 力	動 力 化	動 力 火 車	動 力 室	
動 力 計	動 力 學	動 力 機	動 土	動 工	動 不 動	動 之 以 情	動 心	
動 心 忍 性	動 心 怵 目	動 心 娛 目	動 心 駭 目	動 手	動 手 動 腳	動 手 術	動 支	
動 火	動 用	動 刑	動 向	動 名 詞	動 因	動 地 驚 天	動 如 參 商	
動 如 脫 兔	動 作	動 作 學	動 兵	動 身	動 念	動 武	動 物	
動 物 化	動 物 似	動 物 性	動 物 所	動 物 油	動 物 保 育	動 物 界	動 物 病	
動 物 園	動 物 極	動 物 誌	動 物 衛 生 檢 驗 所	動 物 學	動 怒	動 員	動 員 大 會	
動 員 令	動 員 會	動 員 群 眾	動 容	動 悟	動 氣	動 脈	動 脈 血	
動 脈 炎	動 脈 狀	動 脈 硬 化	動 脈 瘤	動 能	動 動	動 情	動 產	
動 眾	動 粗	動 換	動 植 物	動 畫	動 畫 片	動 畫 電 影	動 筆	
動 著	動 詞	動 詞 化	動 量	動 量 矩	動 亂	動 勢	動 搖	
動 滑 輪	動 腦	動 腦 筋	動 電 學	動 態	動 態 平 衡	動 態 規 劃	動 賓	
動 輒	動 輒 得 咎	動 嘴	動 彈	動 彈 不 得	動 輪	動 魄 驚 心	動 機	
動 靜	動 盪	動 盪 不 安	動 點	動 轉	動 覺	動 議	動 聽	
匐 行	匐 枝	匐 匍	匏 瓜 空 懸	匙 兒	匿 伏	匿 名	匿 名 信	
匿 於	匿 處	匿 報	匿 跡	匿 跡 潛 形	匿 跡 銷 聲	匿 跡 隱 形	匿 影 藏 形	
匿 藏	區 上	區 內	區 公 所	區 分	區 分 開	區 分 線	區 外	
區 名	區 宇 一 清	區 位	區 位 碼	區 別	區 別 不 同 情 況	區 別 於	區 別 對 待	
區 別 輕 重 緩 急	區 局	區 委	區 長	區 政	區 政 府	區 段	區 界	
區 時	區 級	區 院	區 區	區 區 小 事	區 域	區 域 合 作	區 域 性	
區 域 經 濟	區 域 經 濟 學	區 域 網 路	區 間	區 號	區 裡	區 隔	區 劃	
區 標	區 縣	區 屬	匾 的	匾 額	參 天	參 天 兩 地	參 天 貳 地	
參 加	參 加 者	參 加 革 命	參 加 著	參 半	參 考	參 考 文	參 考 咨 詢	
參 考 書	參 考 書 目	參 考 資 料	參 見	參 辰 日 月	參 辰 卯 酉	參 事	參 股	
參 奏	參 拜	參 政	參 政 議 政	參 政 權	參 看	參 軍	參 軍 入 伍	
參 展	參 差	參 差 不 齊	參 酌	參 院	參 參 伍 伍	參 將	參 啟	
參 量	參 照	參 照 物	參 照 實 行	參 預	參 演	參 疑	參 與	
參 與 制	參 與 者	參 審 制 度	參 數	參 閱	參 戰	參 謀	參 謀 長	
參 謀 部	參 辦	參 選	參 賽	參 賽 者	參 贊	參 議	參 議 員	
參 議 院	參 議 會	參 變	參 變 量	參 驗	參 觀	參 觀 者	參 觀 指 導	
參 觀 團	曼 谷	曼 延	曼 陀 林	曼 陀 草	曼 陀 琳	曼 陀 羅	曼 哈 頓	
曼 菲 斯	曼 徹 斯 特	曼 聯	商 人	商 人 們	商 戶	商 丘	商 代	
商 用	商 合 行	商 而 優 則 仕	商 行	商 住 樓	商 妥	商 局	商 事	
商 定	商 店	商 店 街	商 法	商 社	商 亭	商 品	商 品 化	
商 品 生 產	商 品 交 易 會	商 品 交 換	商 品 形 象	商 品 性	商 品 房	商 品 流 通	商 品 率	
商 品 期 貨	商 品 經 濟	商 品 質 量	商 品 銷 售	商 品 檢 驗	商 品 糧	商 城	商 洽	
商 洛	商 界	商 約	商 計	商 訂	商 家	商 展	商 旅	
商 討	商 酌	商 務	商 務 印 書 館	商 務 辦 事 處	商 商	商 埠	商 得	
商 情	商 船	商 販	商 都	商 場	商 報	商 朝	商 棧	
商 港	商 貿	商 量	商 隊	商 會	商 業	商 業 化	商 業 用 地	
商 業 企 業	商 業 局	商 業 系 統	商 業 性	商 業 界	商 業 區	商 業 部	商 業 部 門	
商 業 經 濟	商 業 網	商 業 職 工	商 祺	商 號	商 賈	商 路	商 團	
商 榷	商 數	商 標	商 標 名	商 標 法	商 談	商 學	商 學 院	
商 戰	商 辦	商 擬	商 檢	商 檢 局	商 總	商 聯	商 議	
商 議 好	商 議 者	商 議 會	商 權	啪 啪	啪 啦	啪 達	啪 聲	
啪 響	啪 噠	啦 行	啦 啦	啦 啦 隊	啄 木 鳥	啄 食	啄 破	
啄 痕	啞 人	啞 口	啞 口 無 言	啞 子	啞 子 得 夢	啞 巴	啞 巴 吃 黃 連	
啞 叫	啞 炮	啞 啞	啞 場	啞 然	啞 然 失 笑	啞 補	啞 鈴	
啞 語	啞 劇	啞 劇 中	啞 彈	啞 默 悄 聲	啞 聲	啞 謎	啃 去	
啃 書	啃 掉	啃 著	啊 呀	啊 呸	啊 哈	啊 唷	啊 喲	
啊 嚏	唱 了	唱 下	唱 反 調	唱 片	唱 片 市 場	唱 主 角	唱 出	
唱 本	唱 名	唱 曲	唱 作	唱 吧	唱 和	唱 法	唱 者	
唱 段	唱 家	唱 班	唱 起	唱 針	唱 高 調	唱 得	唱 票	
唱 腔	唱 著	唱 詞	唱 詩	唱 詩 班	唱 過	唱 酬	唱 對 台 戲	
唱 歌	唱 歌 者	唱 碟	唱 盤	唱 機	唱 獨 角 戲	唱 戲	唱 籌 量 沙	
問 人	問 卜	問 上	問 及	問 及 此 事	問 心	問 心 無 愧	問 牛 知 馬	
問 世	問 他	問 出	問 句	問 好	問 她	問 安	問 安 視 膳	
問 羊 知 馬	問 自 己	問 住	問 你	問 事	問 到	問 卷	問 明	
問 法	問 者	問 長 問 短	問 侯	問 俗	問 政	問 柳 尋 花	問 津	
問 倒	問 候	問 員	問 案	問 訊	問 起	問 問	問 斬	
問 這	問 寒 問 暖	問 答	問 答 法	問 答 者	問 著	問 罪	問 罪 之 師	
問 號	問 話	問 詢	問 路	問 道	問 道 於 盲	問 鼎	問 價	
問 諸 水 濱	問 題	問 題 少 年	問 題 兒 童	問 難	問 鐘 點	唯 一	唯 才 是 舉	
唯 心	唯 心 主 義	唯 心 主 義 者	唯 心 史 觀	唯 心 論	唯 有	唯 利 是 求	唯 利 是 從	
唯 利 是 圖	唯 吾 獨 尊	唯 妙	唯 妙 唯 肖	唯 我	唯 我 論	唯 我 獨 尊	唯 肖	
唯 其	唯 命 是 從	唯 命 是 聽	唯 命 論	唯 物	唯 物 主 義	唯 物 主 義 者	唯 物 史 觀	
唯 物 論	唯 物 辯 證 法	唯 信	唯 美	唯 若	唯 恐	唯 唯	唯 唯 否 否	
唯 唯 諾 諾	唯 理 論	唯 實	唯 賢	唯 獨	唯 親	唯 錢 是 圖	唯 讀	
啤 酒	啤 酒 杯	啤 灑	唸 咒	唸 書	唸 唸	唸 唸 有 詞	唸 經	
售 出	售 完	售 性	售 房	售 物	售 後	售 後 服 務	售 值	
售 書 員	售 缺	售 得	售 票	售 票 口	售 票 員	售 票 處	售 貨	
售 貨 員	售 給	售 與	售 價	售 樓	售 賣	售 罄	售 攤	
售 讓	啜 泣	啜 食	啜 菽 飲 水	啜 飲	唬 人	唬 地	唬 住	
唬 神 瞞 鬼	唬 唬	啁 啾	啁 啾 叫	圈 上	圈 子	圈 之	圈 內	
圈 占	圈 外	圈 地	圈 住	圈 兒	圈 套	圈 起	圈 圈	
圈 椅	圈 結	圈 進	圈 奪	圈 餅	圈 閱	圈 環	圈 點	
國 人	國 力	國 土	國 士 無 雙	國 大	國 大 代 表	國 小	國 工 局	
國 中	國 內	國 內 外	國 內 市 場	國 內 先 進 水 平	國 內 形 勢	國 內 法	國 內 政 策	
國 內 革 命 戰 爭	國 內 航 線	國 內 基 金	國 內 貿 易	國 公	國 手	國 文	國 父	
國 父 紀 念 館	國 王	國 王 隊	國 代	國 史	國 外	國 外 市 場	國 外 旅 遊	
國 外 經 驗	國 巨	國 巨 公 司	國 民	國 民 大 會	國 民 生 產	國 民 生 產 總 值	國 民 年 金	
國 民 收 入	國 民 西 敏 銀 行	國 民 性	國 民 所 得	國 民 政 府	國 民 軍	國 民 教 育	國 民 經 濟	
國 民 總 收 入	國 民 總 產 值	國 民 議 會	國 民 警 衛 隊	國 民 黨	國 民 黨 投 管 會	國 用	國 立	
國 企	國 光	國 共	國 共 兩 黨	國 共 和 談	國 共 關 係	國 名	國 字	
國 宅	國 宅 政 策	國 安 局	國 安 基 金	國 式	國 有	國 有 化	國 有 財 產 局	
國 老	國 色	國 色 天 姿	國 色 天 香	國 別	國 別 史	國 君	國 步 艱 難	
國 防	國 防 政 策	國 防 科 工 委	國 防 軍	國 防 部	國 防 費	國 防 醫 學 院	國 事	
國 事 訪 問	國 府	國 法	國 花	國 門	國 威	國 度	國 後	
國 政	國 是	國 界	國 界 法	國 科 會	國 計	國 計 民 生	國 軍	
國 音	國 風	國 家	國 家 元 首	國 家 公 園	國 家 化	國 家 安 全 局	國 家 利 益	
國 家 法	國 家 音 樂 廳	國 家 級	國 家 副 主 席	國 家 隊	國 家 劇 院	國 家 賠 償	國 家 機 器	
國 家 機 關	國 宴	國 師	國 庫	國 庫 券	國 恥	國 旅	國 書	
國 格	國 泰	國 泰 人 壽	國 泰 化 工	國 泰 民 安	國 泰 投 信	國 泰 建 設	國 破 家 亡	
國 務	國 務 委 員	國 務 卿	國 務 院	國 務 院 辦 公 廳	國 務 部 長	國 務 會 議	國 務 總 理	
國 國	國 專	國 將 不 國	國 情	國 情 咨 文	國 戚	國 教	國 產	
國 產 化	國 產 車	國 產 實 業	國 產 機	國 眾 電 腦	國 祭	國 統 區	國 術	
國 貨	國 都	國 鳥	國 喪	國 喬 石 化	國 富	國 富 民 安	國 富 兵 強	
國 揚 建 設	國 畫	國 發	國 稅	國 稅 局	國 策	國 策 顧 問	國 華 人 壽	
國 貿	國 貿 局	國 債	國 勢	國 會	國 會 議 員	國 腳	國 舅	
國 葬	國 號	國 賊	國 道	國 道 新 建 工 程 局	國 境	國 境 管 理	國 境 線	
國 幣	國 旗	國 歌	國 爾 忘 家	國 碩	國 碩 科 技	國 粹	國 與 國	
國 語	國 賓	國 賓 陶 瓷	國 賓 飯 店	國 賓 館	國 際	國 際 人 權	國 際 上	
國 際 互 連 網	國 際 化	國 際 主 義	國 際 快 遞 業	國 際 足 球 總 會	國 際 性	國 際 法	國 際 股 市	
國 際 青 年 商 會	國 際 政 治	國 際 海 纜	國 際 能 源 署	國 際 票 券	國 際 組 織	國 際 貨 幣 基 金	國 際 貨 幣 基 金 會	
國 際 象 棋	國 際 間	國 際 奧 會	國 際 電 話	國 際 歌	國 際 舞 台	國 際 談 判	國 際 駕 照	
國 魂	國 劇	國 慶	國 慶 日	國 慶 節	國 標	國 標 碼	國 樂	
國 殤	國 學	國 歷	國 辦	國 優	國 徽	國 營	國 營 企 業	
國 聯	國 聯 光 電	國 豐 實 業	國 璽	國 藝 會	國 藥	國 難	國 寶	
國 寶 人 壽	國 籍	國 體	國 �� 電 子	域 外	域 名	域 網	堅 不 可 摧	
堅 甲 利 兵	堅 石	堅 如	堅 如 磐 石	堅 如 鋼	堅 守	堅 守 崗 位	堅 忍	
堅 忍 不 拔	堅 決	堅 牢	堅 牢 度	堅 固	堅 固 性	堅 固 耐 用	堅 定	
堅 定 不 移	堅 定 性	堅 拒	堅 果	堅 果 仁	堅 果 殼	堅 信	堅 信 不 移	
堅 城 深 池	堅 度	堅 持	堅 持 不 渝	堅 持 不 懈	堅 持 四 項 基 本 原 則	堅 持 原 則	堅 持 真 理	
堅 苦 卓 絕	堅 貞	堅 貞 不 屈	堅 挺	堅 強	堅 強 不 屈	堅 強 意 志	堅 硬	
堅 韌	堅 韌 不 拔	堅 實	堅 稱	堅 毅	堅 壁	堅 壁 清 野	堊 版	
堊 紀	堆 入	堆 土 機	堆 木 場	堆 丘	堆 石	堆 存 處	堆 成	
堆 放	堆 於	堆 肥	堆 金 積 玉	堆 砌	堆 迭	堆 倉	堆 笑	
堆 起	堆 焊	堆 棧	堆 集	堆 搓	堆 裝 物	堆 裡	堆 滿	
堆 積	堆 積 如 山	堆 積 物	堆 疊	堆 垛	埠 頭	埤 頭 鄉	基 木	
基 本	基 本 上	基 本 工 資	基 本 方 針	基 本 功	基 本 矛 盾	基 本 性	基 本 法	
基 本 金	基 本 建 設	基 本 原 則	基 本 國 策	基 本 粒 子	基 本 概 念	基 本 點	基 石	
基 件	基 因	基 因 工 程	基 因 改 造	基 因 型	基 因 體	基 地	基 地 址	
基 地 防 禦	基 多	基 年	基 色	基 佛	基 坑	基 址	基 辛 格	
基 底	基 於	基 肥	基 金	基 金 組 織	基 金 會	基 度 山	基 建	
基 音	基 值	基 座	基 時	基 泰 建 設	基 部	基 隆	基 隆 市	
基 隆 港	基 幹	基 業	基 極	基 準	基 準 面	基 督	基 督 徒	
基 督 教	基 達	基 團	基 態	基 輔	基 價	基 層	基 層 社	
基 數	基 線	基 調	基 質	基 頻	基 點	基 礎	基 礎 上	
基 礎 性	基 礎 教 育	基 礎 理 論	基 礎 課	基 巖	基 體	堂 上	堂 兄	
堂 外	堂 而 皇 之	堂 弟	堂 叔	堂 姐	堂 房	堂 客	堂 屋	
堂 皇	堂 皇 正 大	堂 皇 富 麗	堂 風	堂 倌	堂 高 廉 遠	堂 堂	堂 堂 正 正	
堂 堂 皇 皇	堂 奧	堂 會	堂 煌	堂 鼓	堂 課	堂 侄	堵 了	
堵 水	堵 在	堵 死	堵 住	堵 車	堵 門	堵 氣	堵 著	
堵 塞	堵 截	堵 漏	堵 嘴	堵 擋	堵 擊	堵 牆	執 牛 耳	
執 白	執 而 不 化	執 行	執 行 人	執 行 主 席	執 行 任 務	執 行 委 員 會	執 行 官	
執 行 者	執 行 情 況	執 言	執 事	執 兩 用 中	執 委 會	執 念	執 拗	
執 法	執 法 不 嚴	執 法 必 嚴	執 法 犯 法	執 法 如 山	執 政	執 政 官	執 政 者	
執 政 黨	執 柯 作 伐	執 迷	執 迷 不 悟	執 教	執 掌	執 筆	執 筆 人	
執 著	執 黑	執 勤	執 意	執 業	執 照	執 照 稅	執 達 員	
執 導	執 鞭	執 鞭 墜 鐙	執 鞭 隨 鐙	培 土	培 育	培 修	培 根	
培 訓	培 訓 中 心	培 訓 班	培 訓 基 地	培 訓 教 材	培 基	培 植	培 養	
培 養 人 才	培 養 皿	培 養 目 標	培 養 者	培 養 基	培 養 教 育	夠 了	夠 大	
夠 本	夠 用	夠 交 情	夠 多	夠 忍	夠 刺 激	夠 到	夠 受	
夠 味	夠 朋 友	夠 時	夠 格	夠 做	夠 啦	夠 得 著	夠 量	
夠 嗆	夠 數	夠 標 準	夠 瞧	夠 戧	奢 求	奢 侈	奢 侈 品	
奢 侈 逸 樂	奢 望	奢 淫	奢 華	奢 想	奢 談	奢 靡	娶 你	
娶 到	娶 妻	娶 媳	娶 親	婁 族	婉 言	婉 言 謝 絕	婉 拒	
婉 約	婉 婉	婉 詞	婉 順	婉 語	婉 謝	婉 轉	婉 辭	
婦 人	婦 人 之 仁	婦 人 帽	婦 女	婦 女 用	婦 女 新 知 基 金 會	婦 女 會	婦 女 節	
婦 代 會	婦 幼	婦 幼 保 健	婦 幼 保 健 站	婦 姑 勃 溪	婦 科	婦 產	婦 產 科	
婦 產 醫 院	婦 短	婦 道	婦 儒	婦 嬰	婦 孺	婦 孺 皆 知	婦 聯	
婦 聯 會	婦 職	婦 權	婀 娜	娼 妓	娼 婦	娼 寮	婢 女	
婢 奴	婢 作 夫 人	婢 僕	婢 學 夫 人	婚 外	婚 外 戀	婚 生 子 女	婚 式	
婚 否	婚 事	婚 事 新 辦	婚 者	婚 前	婚 姻	婚 姻 大 事	婚 姻 介 紹 所	
婚 姻 生 活	婚 姻 自 主	婚 姻 自 由	婚 姻 制 度	婚 姻 法	婚 姻 登 記	婚 姻 關 係	婚 後	
婚 約	婚 宴	婚 書	婚 紗 業	婚 紗 攝 影	婚 配	婚 假	婚 喪	
婚 喪 喜 慶	婚 喪 嫁 娶	婚 期	婚 嫁	婚 詩	婚 筵	婚 禮	婚 齡	
婚 戀	婆 子	婆 心	婆 母	婆 姨	婆 娑	婆 娘	婆 家	
婆 婆	婆 婆 媽 媽	婆 媳	婆 媳 關 係	婆 羅	婊 子	孰 知	孰 若	
寅 支 卯 糧	寅 吃 卯 糧	寅 憂 夕 惕	寄 人 籬 下	寄 上	寄 予	寄 主	寄 出	
寄 去	寄 生	寄 生 物	寄 生 蟲	寄 交	寄 件 人	寄 回	寄 存	
寄 存 器	寄 托	寄 托 人	寄 自	寄 至	寄 住	寄 希 望 於	寄 身	
寄 來	寄 到	寄 居	寄 往	寄 放	寄 的	寄 信	寄 信 人	
寄 送	寄 售	寄 售 品	寄 宿	寄 宿 人	寄 宿 生	寄 宿 舍	寄 情	
寄 望	寄 寓	寄 發	寄 給	寄 費	寄 達	寄 語	寄 遞	
寄 賣	寄 銷	寄 養	寄 錢	寄 贈	寄 贈 本	寂 若 死 灰	寂 若 無 人	
寂 然	寂 寞	寂 寥	寂 靜	宿 仇	宿 世 冤 家	宿 主	宿 州	
宿 命	宿 命 論	宿 於	宿 舍	宿 怨	宿 星	宿 疾	宿 務	
宿 將	宿 將 舊 卒	宿 費	宿 敵	宿 衛	宿 遷	宿 學 舊 儒	宿 營	
宿 願	密 不 可 分	密 不 透 風	密 切	密 切 合 作	密 切 協 作	密 切 相 關	密 切 配 合	
密 切 接 觸	密 切 聯 繫 群 眾	密 切 關 係	密 友	密 令	密 穴	密 件	密 旨	
密 西 西 比	密 西 根	密 佈	密 告	密 告 者	密 技	密 事	密 使	
密 函	密 定	密 林	密 法	密 信	密 室	密 封	密 封 圈	
密 封 劑	密 封 器	密 封 艙	密 度	密 約	密 茂	密 氣	密 紋 唱 片	
密 級	密 商	密 密	密 密 麻 麻	密 密 層 層	密 探	密 訪	密 訣	
密 閉	密 報	密 斯	密 植	密 集	密 集 井 群	密 集 物	密 集 型	
密 集 體	密 雲	密 雲 不 雨	密 歇 根	密 電	密 電 碼	密 實	密 語	
密 碼	密 碼 法	密 碼 術	密 碼 學	密 碼 機	密 緻	密 談	密 謀	
密 謀 者	密 藏	密 蘇 裡	密 蘇 裡 洲	密 議	密 鑰	密 鑼 緊 鼓	尉 官	
專 一	專 一 性	專 人	專 才	專 心	專 心 一 志	專 心 一 意	專 心 致 志	
專 心 敬 業	專 戶	專 文	專 刊	專 功	專 司	專 用	專 用 名 詞	
專 用 設 備	專 用 章	專 用 線	專 任	專 列	專 向	專 名	專 有	
專 有 權	專 而 精	專 利	專 利 局	專 利 制 度	專 利 法	專 利 者	專 利 權	
專 攻	專 車	專 事	專 使	專 供	專 函	專 制	專 制 主 義	
專 於	專 注	專 治	專 長	專 門	專 門 人 才	專 門 化	專 門 從 事	
專 門 調 查	專 門 機 構	專 指	專 挑	專 政	專 政 對 像	專 政 機 關	專 為	
專 科	專 科 化	專 科 學 校	專 修	專 員	專 員 公 署	專 家	專 家 系 統	
專 家 級	專 家 組	專 家 學 者	專 差	專 席	專 庫	專 座	專 案	
專 送	專 區	專 唱	專 售	專 訪	專 設	專 責	專 場	
專 揀	專 款	專 款 專 用	專 發	專 程	專 著	專 集	專 項	
專 項 合 同	專 愛	專 業	專 業 人 才	專 業 人 員	專 業 分 工	專 業 化	專 業 戶	
專 業 知 識	專 業 英 語	專 業 對 口	專 業 銀 行	專 業 課	專 業 學 校	專 署	專 號	
專 電	專 管	專 網	專 遞	專 線	專 論	專 賣	專 賣 店	
專 賣 者	專 擅	專 橫	專 橫 跋 扈	專 機	專 輯	專 營	專 斷	
專 櫃	專 職	專 職 幹 部	專 題	專 題 片	專 題 研 究	專 題 討 論	專 題 報 告	
專 屬	專 屬 經 濟 區	專 欄	專 權	將 上	將 士	將 才	將 不	
將 心 比 心	將 比	將 且	將 以	將 他	將 令	將 功 折 罪	將 功 折 過	
將 功 補 過	將 功 贖 罪	將 去	將 它	將 打 開	將 本 圖 利	將 由	將 同	
將 向	將 她	將 如	將 成	將 有	將 此	將 死	將 至	
將 伯 之 助	將 那	將 使	將 來	將 來 臨	將 其	將 到	將 官	
將 或	將 於	將 近	將 門	將 門 出 將	將 門 有 將	將 信 將 疑	將 帥	
將 是	將 為	將 相	將 要	將 要 來	將 計 就 計	將 軍	將 軍 鄉	
將 息	將 校	將 從	將 略	將 就	將 朝	將 牌	將 給	
將 勤 補 拙	將 會	將 遇 良 才	將 對	將 領	將 增	將 樂	將 蝦 釣 鱉	
將 機 就 計	將 機 就 機	將 錯 就 錯	將 臨	屠 刀	屠 夫	屠 戶	屠 門 大 嚼	
屠 城	屠 宰	屠 宰 場	屠 殺	屠 殺 場	屠 場	屠 戮	屠 龍	
屠 龍 之 技	屠 龍 之 伎	崇 山	崇 山 峻 嶺	崇 仁	崇 友 實 業	崇 文	崇 外	
崇 左	崇 本 抑 末	崇 光 百 貨	崇 尚	崇 信	崇 拜	崇 拜 者	崇 洋	
崇 洋 媚 外	崇 高	崇 高 品 質	崇 高 理 想	崇 越 科 技	崇 敬	崇 禎	崇 論 宏 議	
崇 論 閎 議	崇 禮	崎 嶇	崎 嶇 險 阻	崛 起	崖 壁	崢 嶸	崢 嶸 歲 月	
崑 崙	崩 坍	崩 裂	崩 塌	崩 落	崩 解	崩 潰	崩 盤	
崩 龍	崔 述	崙 背 鄉	崧 生 岳 降	崗 子	崗 石	崗 地	崗 位	
崗 亭	崗 哨	崗 樓	崗 警	崗 巒	巢 中	巢 穴	巢 居	
巢 居 穴 處	巢 房	巢 狀	巢 湖	巢 傾 卵 覆	巢 毀 卵 破	巢 窟	巢 窩	
巢 縣	常 人	常 比	常 以	常 平	常 用	常 用 字	常 用 對 數	
常 任	常 任 理 事 國	常 在	常 州	常 年	常 年 不 懈	常 年 不 斷	常 有	
常 住	常 作	常 坐	常 把	常 抓	常 抓 不 懈	常 見	常 見 病	
常 言	常 言 道	常 言 說	常 言 說 得 好	常 事	常 使	常 例	常 來 常 往	
常 到	常 委	常 委 會	常 往	常 怪	常 於	常 服	常 青	
常 客	常 指	常 春	常 春 籐	常 為	常 相 知	常 看	常 赴	
常 軌	常 食	常 務	常 務 主 席	常 務 委 員 會	常 務 理 事	常 務 會 議	常 問	
常 常	常 情	常 理	常 被	常 規	常 規 武 器	常 規 戰	常 規 戰 爭	
常 訪	常 設	常 設 機 構	常 備	常 備 不 懈	常 備 兵	常 備 軍	常 備 藥	
常 勝	常 勝 將 軍	常 喝	常 量	常 開	常 飲 酒	常 會	常 溫	
常 態	常 態 化	常 磁 性	常 綠	常 綠 植 物	常 綠 闊 葉 林	常 與	常 說	
常 德	常 數	常 樂	常 熟	常 談	常 駐	常 駐 機 構	常 褲	
常 壓	常 禮	常 繞	常 識	帶 入	帶 下	帶 上	帶 子	
帶 月 披 星	帶 水 拖 泥	帶 牛 佩 犢	帶 出	帶 去	帶 回	帶 回 家	帶 扣	
帶 有	帶 兵	帶 兵 藝 術	帶 冷 笑	帶 孝	帶 材	帶 步 人	帶 走	
帶 來	帶 刺	帶 到	帶 呼	帶 河 厲 山	帶 狀	帶 狀 條	帶 金 佩 紫	
帶 青 色	帶 信	帶 勁	帶 柄	帶 紅 色	帶 病	帶 送	帶 動	
帶 眼 鏡	帶 魚	帶 斑 點	帶 紫 色	帶 給	帶 著	帶 菌 者	帶 進	
帶 隊	帶 黃 色	帶 罪 立 功	帶 裝	帶 路	帶 過	帶 電	帶 電 作 業	
帶 飾	帶 槍	帶 酸 味	帶 領	帶 寬	帶 褐 色	帶 鋸	帶 錯	
帶 鋼	帶 頭	帶 頭 人	帶 頭 巾	帶 頭 作 用	帶 壞	帶 礪 山 河	帶 礪 河 山	
帶 響	帳 上	帳 子	帳 內	帳 戶	帳 冊	帳 卡	帳 外	
帳 本	帳 目	帳 夾	帳 房	帳 表	帳 面	帳 頁	帳 家	
帳 釘	帳 務	帳 單	帳 棚	帳 款	帳 號	帳 鉤	帳 幕	
帳 據	帳 篷	帳 簿	帳 證	帷 子	帷 帳	帷 幕	帷 幔	
帷 薄 不 修	帷 幄	康 乃 馨	康 平	康 那 香	康 和 證 券	康 定	康 明 杉	
康 采 恩	康 保	康 哉 之 歌	康 柏	康 泰	康 健	康 康	康 莊	
康 莊 大 道	康 復	康 寧	康 熙	康 銅	康 德	康 樂	庸 人	
庸 人 自 擾	庸 人 自 擾 之	庸 才	庸 中 皎 皎	庸 中 佼 佼	庸 俗	庸 俗 化	庸 俗 低 級	
庸 俗 者	庸 品	庸 國	庸 庸 碌 碌	庸 碌	庸 醫	庸 醫 殺 人	庶 人	
庶 子	庶 母	庶 民	庶 生	庶 務	庵 堂	庾 澄 慶	張 力	
張 力 計	張 三	張 三 李 四	張 口	張 口 結 舌	張 大	張 小 燕	張 公 吃 酒 李 公 醉	
張 牙 舞 爪	張 牙 舞 瓜	張 本 瑜	張 目	張 宇	張 老 師	張 艾 嘉	張 作 驥	
張 狂	張 帖	張 忠 謀	張 昌 邦	張 信 哲	張 冠 李 戴	張 昭 雄	張 柏 芝	
張 眉 努 眼	張 家 口	張 家 港	張 泰 山	張 曼 玉	張 國 立	張 張	張 掛	
張 敏 之	張 望	張 清 芳	張 惠 妹	張 惶 失 措	張 惶 失 錯	張 揚	張 敞 畫 眉	
張 智 霖	張 菲	張 貼	張 量	張 開	張 雅 琴	張 溫 鷹	張 瑞 哲	
張 榜	張 榜 公 佈	張 榮 味	張 網	張 鳳 書	張 鳳 鳳	張 嘴	張 德 培	
張 數	張 衛 健	張 震	張 學 友	張 燈 掛 彩	張 燈 結 彩	張 羅	強 人	
強 人 所 難	強 力	強 力 膠	強 大	強 不 知 以 為 知	強 中 自 有 強 中 手	強 中 更 有 強 中 手	強 化	
強 化 物	強 化 訓 練	強 心 劑	強 手	強 手 如 林	強 手 如 雲	強 加	強 加 於	
強 加 於 人	強 尼 戴 普	強 打	強 打 手	強 本 弱 知	強 本 節 用	強 光	強 曳	
強 有 力	強 有 力 地	強 死 強 活	強 行	強 行 攤 派	強 佔	強 似	強 作	
強 作 笑 顏	強 壯	強 壯 人	強 壯 劑	強 忍	強 扯	強 攻	強 求	
強 身	強 身 健 體	強 使	強 制	強 制 性	強 制 執 行 法	強 制 措 施	強 取	
強 取 豪 奪	強 固	強 弩 之 末	強 征	強 拉	強 拉 硬 扯	強 拍	強 的	
強 者	強 勁	強 姦	強 姦 民 意	強 姦 犯	強 姦 者	強 度	強 派	
強 茂 公 司	強 要	強 迫	強 迫 人	強 迫 性	強 音	強 音 部	強 風	
強 食	強 借	強 射	強 弱	強 悍	強 悍 人	強 烈	強 烈 抗 議	
強 留	強 記	強 記 洽 聞	強 記 博 聞	強 健	強 國	強 國 之 路	強 國 富 民	
強 將 之 下 無 弱 兵	強 將 手 下 無 弱 兵	強 推	強 梁	強 盛	強 盛 染 整	強 渡	強 渡 江 河	
強 盜	強 盜 罪	強 盜 罪 嫌	強 硬	強 硬 派	強 硬 態 度	強 聒 不 捨	強 詞 奪 理	
強 買	強 開	強 韌	強 項	強 勢	強 幹 弱 枝	強 搶	強 新 工 業	
強 逼	強 過	強 電	強 奪	強 磁	強 磁 性	強 酸	強 颱 風	
強 嘴	強 敵	強 暴	強 調	強 震	強 橫	強 龍 不 壓 地 頭 蛇	強 壓	
強 壓 怒 火	強 擊 機	強 辯	強 權	強 權 政 治	強 襲	強 鹼	彗 星	
彗 汜 畫 塗	彬 彬	彬 彬 文 質	彬 彬 有 禮	彬 縣	彩 巾	彩 旦	彩 印	
彩 色	彩 色 化	彩 色 片	彩 色 畫	彩 色 照 片	彩 色 電 視	彩 色 電 視 機	彩 色 電 影	
彩 色 監 視 器	彩 色 影 片	彩 色 膠 卷	彩 妝	彩 車	彩 券	彩 卷	彩 金	
彩 虹	彩 虹 樂 團	彩 珠	彩 病 毒	彩 紙	彩 條	彩 瓷	彩 票	
彩 袋	彩 陶	彩 畫	彩 筆	彩 雲	彩 雲 易 散	彩 塑	彩 照	
彩 釉	彩 電	彩 像	彩 旗	彩 管	彩 鳳 隨 鴉	彩 噴	彩 層	
彩 燈	彩 霞	彩 禮	彩 繪	彩 顯	彫 零	彫 謝	彫 蟲 小 技	
彫 蟲 小 藝	彫 蟲 篆 刻	得 一 忘 十	得 了	得 人 心	得 人 死 力	得 人 者 昌	得 人 者 昌 失 人 者 亡	
得 力	得 力 實 業	得 上	得 大 於 失	得 寸 入 尺	得 寸 思 尺	得 寸 進 尺	得 不	
得 不 到	得 不 補 失	得 不 酬 失	得 不 賞 失	得 不 償 失	得 分	得 及	得 天 獨 厚	
得 尺 得 寸	得 心 應 手	得 手	得 手 應 心	得 比	得 以	得 出	得 去	
得 失	得 失 在 人	得 失 成 敗	得 失 相 半	得 失 榮 枯	得 未 曾 有	得 未 嘗 有	得 用	
得 名	得 好	得 此	得 而	得 而 復 失	得 住	得 克 薩 斯	得 免	
得 利	得 志	得 快	得 步 進 步	得 見	得 使	得 來	得 來 全 不 費 工 夫	
得 其 三 昧	得 其 所 哉	得 到	得 宜	得 法	得 的	得 知	得 空	
得 勁	得 很	得 計	得 准	得 病	得 益	得 起	得 做	
得 啦	得 悉	得 救	得 理 讓 人	得 票	得 第 一 名	得 逞	得 魚 忘 筌	
得 勝	得 勝 回 朝	得 勝 頭 回	得 勢	得 意	得 意 之 極	得 意 忘 形	得 意 忘 言	
得 意 忘 象	得 意 門 生	得 意 非 凡	得 意 洋 洋	得 意 揚 揚	得 新 忘 舊	得 當	得 罪	
得 罪 人	得 道 多 助	得 過 且 過	得 對	得 說	得 數	得 獎	得 獎 人	
得 獎 者	得 懂	得 寵	得 隴 望 蜀	得 饒 人 處 且 饒 人	得 聾 望 蜀	得 體	徙 步	
徙 居	從 一 以 終	從 一 而 終	從 一 般 意 義 上	從 下	從 下 到 上	從 上	從 上 到 下	
從 上 往 下	從 大 局 出 發	從 大 處 著 眼	從 小	從 小 到 大	從 小 處 著 手	從 工 作 出 發	從 不	
從 不 間 斷	從 中	從 中 央 到 地 方	從 中 作 梗	從 井 救 人	從 今	從 今 之 後	從 今 天 起	
從 今 以 後	從 今 年 起	從 今 往 後	從 內	從 化	從 天 而 降	從 心 所 欲	從 文	
從 父	從 世	從 以 後	從 令 如 流	從 北 向 南	從 北 到 南	從 古 至 今	從 古 到 今	
從 右	從 右 到 左	從 句	從 外 到 裡	從 外 部	從 左	從 左 到 右	從 未	
從 未 用 過	從 未 有 過	從 母	從 犯	從 任 何 意 義 上	從 先	從 各 個 方 面	從 戎	
從 早	從 早 到 晚	從 此	從 此 以 後	從 而	從 自 己 做 起	從 西 向 東	從 何	
從 何 下 手	從 何 談 起	從 低	從 尾	從 我 做 起	從 技 術 上	從 良	從 那	
從 那 時	從 那 時 起	從 那 裡	從 事	從 事 於	從 來	從 來 不	從 來 沒 有	
從 來 沒 有 過	從 其	從 命	從 始 至 終	從 於	從 明 年 起	從 東	從 東 向 西	
從 者	從 表 面 上 看	從 長 計 議	從 長 遠 來 看	從 長 遠 看	從 俗	從 俗 就 簡	從 前	
從 南 到 北	從 政	從 某 種 程 度 上	從 某 種 意 義 上	從 軍	從 重	從 重 從 快	從 革 命 利 益 出 發	
從 風 而 靡	從 容	從 容 不 迫	從 容 自 若	從 容 就 義	從 師	從 根 本 上	從 高	
從 動	從 商	從 從 容 容	從 現 在 起	從 現 在 做 起	從 現 在 開 始	從 略	從 這	
從 這 一 點	從 這 以 後	從 這 個 角 度 上	從 這 個 意 義 上	從 這 時 起	從 速	從 無 到 有	從 善	
從 善 如 流	從 善 如 登 從 惡 如 崩	從 量	從 開 始 起	從 新	從 業	從 業 人 員	從 群 眾 中 來	
從 裡	從 裡 到 外	從 僕	從 實 際 出 發	從 實 際 情 況 出 發	從 緊	從 領 導 做 起	從 價	
從 寬	從 寬 處 理	從 寬 發 落	從 輩	從 輪	從 諫 如 流	從 頭	從 頭 至 尾	
從 頭 到 尾	從 頭 到 腳	從 頭 開 始	從 優	從 總 的 情 況	從 總 體 上	從 簡	從 難 從 嚴	
從 嚴	從 嚴 治 黨	從 屬	從 屬 於	從 屬 國	從 權	徘 徊	御 下 蔽 上	
御 冬	御 用	御 地	御 旨	御 制	御 性	御 林	御 花 園	
御 前	御 風	御 座	御 書	御 寒	御 詔	御 溝 流 葉	御 溝 紅 葉	
御 賜	御 駕	御 駕 親 征	御 膳	御 膳 房	御 醫	御 轎	徜 徉	
患 了	患 上	患 有	患 兒	患 者	患 病	患 得 患 失	患 處	
患 癌	患 難	患 難 之 交	患 難 相 死	患 難 相 扶	患 難 相 恤	患 難 與 共	悉 心	
悉 心 畢 力	悉 心 竭 力	悉 心 戮 力	悉 尼	悉 由	悉 交 絕 游	悉 索 敝 賦	悉 索 薄 賦	
悉 數	悉 聽 尊 便	悠 久	悠 長	悠 哉 游 哉	悠 悠	悠 悠 忽 忽	悠 揚	
悠 然	悠 然 自 得	悠 然 自 適	悠 著 點	悠 閒	悠 閒 自 在	悠 遠	您 好	
您 的	您 們	您 瞧	惋 惜	惦 念	惦 記	惦 掛	惦 著	
惦 量	情 人	情 人 眼 裡 出 西 施	情 不 可 卻	情 不 自 勝	情 不 自 堪	情 不 自 禁	情 之 所 鐘	
情 分	情 夫	情 文	情 文 並 茂	情 火	情 史	情 由	情 份	
情 同 一 家	情 同 手 足	情 同 骨 肉	情 同 魚 水	情 曲	情 有 可 原	情 有 西 施	情 至	
情 至 意 盡	情 色	情 孚 意 合	情 形	情 投	情 投 意 合	情 投 意 洽	情 狂	
情 見 力 屈	情 見 乎 言	情 見 乎 詞	情 見 乎 辭	情 見 勢 屈	情 見 勢 竭	情 事	情 味	
情 況	情 況 下	情 況 匯 報	情 狀	情 侶	情 思	情 急	情 急 智 生	
情 若 手 足	情 郎	情 面	情 書	情 海	情 真	情 真 意 切	情 真 意 摯	
情 迷	情 婦	情 深	情 深 友 於	情 深 如 海	情 深 似 海	情 深 骨 肉	情 深 意 濃	
情 理	情 理 難 容	情 場	情 報	情 報 工 作	情 報 局	情 報 所	情 報 服 務	
情 報 活 動	情 報 界	情 報 員	情 報 統 計	情 報 組 織	情 報 部	情 報 源	情 報 網	
情 報 學	情 報 戰	情 報 機 構	情 報 檢 索	情 報 體 制	情 景	情 景 交 融	情 結	
情 絲	情 勢	情 意	情 感	情 愛	情 節	情 節 劇	情 節 嚴 重	
情 義	情 詩	情 話	情 逾 骨 肉	情 境	情 態	情 歌	情 種	
情 網	情 緒	情 緒 高 漲	情 慾	情 敵	情 緣	情 誼	情 調	
情 趣	情 操	情 隨 事 遷	情 懷	情 關	情 願	情 竇	情 竇 初 開	
情 愫	悻 悻	悻 然	悵 惘	悵 望	悵 然	悵 然 自 失	悵 然 若 失	
惜 力	惜 玉 憐 香	惜 老 憐 貧	惜 別	惜 孤 念 寡	惜 物	惜 指 失 掌	惜 時 如 命	
惜 售	惜 陰	惜 墨 如 金	悼 心 失 圖	悼 文	悼 念	悼 者	悼 唁	
悼 惜	悼 詞	悼 詩	悼 歌	悼 辭	惘 若 有 失	惘 然	惘 然 如 失	
惘 然 若 失	惕 而 不 漏	惆 悵	惆 然	惟 一	惟 有	惟 有 讀 書 高	惟 利 是 逐	
惟 利 是 視	惟 利 是 圖	惟 利 是 營	惟 妙 惟 肖	惟 我 獨 尊	惟 肖	惟 其	惟 命 是 從	
惟 命 是 聽	惟 恐	惟 恐 天 下 不 亂	惟 精 惟 一	惟 獨	悸 動	悸 愣	戚 友	
戚 戚	戚 誼	戚 憑	戛 玉 敲 冰	戛 玉 敲 金	戛 玉 鳴 金	戛 玉 鏘 金	戛 然	
戛 然 而 止	掠 人 之 美	掠 地	掠 地 攻 城	掠 角	掠 走	掠 取	掠 取 物	
掠 是 搬 非	掠 美	掠 食	掠 食 性	掠 食 者	掠 脂 斡 肉	掠 殺	掠 過	
掠 奪	掠 奪 兵	掠 奪 性	掠 奪 者	掠 奪 品	掠 影	控 方	控 名 責 實	
控 作	控 告	控 告 者	控 制	控 制 人 口	控 制 下	控 制 台	控 制 系 統	
控 制 者	控 制 室	控 制 區	控 制 桿	控 制 棒	控 制 項	控 制 論	控 制 器	
控 拆	控 矽	控 股	控 詞	控 訴	控 訴 人	控 訴 道	控 馭	
控 罪	控 管	控 製 麵 板	控 辦	控 購	捲 入	捲 上	捲 土 重 來	
捲 尺	捲 心	捲 心 菜	捲 回	捲 成	捲 曲	捲 舌	捲 走	
捲 浪	捲 起	捲 起 來	捲 動	捲 筒	捲 著	捲 進	捲 開	
捲 煙	捲 煙 廠	捲 過	捲 鋪 蓋	捲 縮	捲 縮 了	捲 縮 成	捲 縮 狀	
捲 縮 者	捲 繞	捲 簾 門	探 子	探 井	探 友	探 戈	探 戈 舞	
探 月	探 犬	探 出	探 本 溯 源	探 本 窮 源	探 求	探 求 者	探 究	
探 究 性	探 身	探 取	探 奇 訪 勝	探 奇 窮 異	探 明	探 玩	探 知	
探 空	探 空 儀	探 花	探 長	探 信	探 幽 索 隱	探 幽 窮 賾	探 春	
探 查	探 看	探 員	探 息	探 案	探 病	探 索	探 索 者	
探 討	探 討 問 題	探 針	探 馬	探 勘	探 勘 者	探 勘 員	探 問	
探 問 者	探 悉	探 掘	探 啟	探 望	探 淵 索 珠	探 異 玩 奇	探 船	
探 訪	探 尋	探 尋 者	探 測	探 測 儀	探 測 器	探 視	探 象	
探 傷	探 奧 索 隱	探 溯	探 源	探 照 燈	探 詢	探 路	探 過	
探 鉗	探 雷	探 雷 器	探 監	探 親	探 親 假	探 親 訪 友	探 險	
探 險 者	探 險 家	探 險 賽	探 頭	探 頭 探 腦	探 謊 器	探 礦	探 礦 者	
探 囊 取 物	探 聽	探 聽 者	探 聽 虛 實	探 驪 得 珠	探 賾 索 隱	接 二 連 三	接 力	
接 力 棒	接 力 賽	接 三 換 九	接 下	接 下 來	接 上	接 口	接 不	
接 手	接 木	接 水	接 火	接 生	接 生 婆	接 目 鏡	接 交	
接 任	接 任 者	接 合	接 合 物	接 合 處	接 合 部	接 合 線	接 合 點	
接 合 體	接 地	接 在	接 收	接 收 天 線	接 收 者	接 收 站	接 收 器	
接 收 機	接 耳	接 耳 交 頭	接 住	接 吻	接 牢	接 見	接 走	
接 防	接 來	接 來 送 往	接 到	接 受	接 受 者	接 受 體	接 和	
接 物	接 近	接 長	接 客	接 待	接 待 生	接 待 者	接 待 室	
接 待 員	接 待 站	接 活	接 洽	接 軌	接 風	接 班	接 班 人	
接 站	接 納	接 袂 成 帷	接 送	接 骨	接 骨 師	接 接	接 排	
接 球	接 眼	接 紹 香 煙	接 貨	接 通	接 連	接 連 不 斷	接 單	
接 替	接 替 者	接 棒	接 著	接 著 來	接 詞	接 貴 攀 高	接 進	
接 過	接 電 器	接 境	接 種	接 管	接 駁	接 盤 人	接 線	
接 線 生	接 線 盒	接 談	接 駕	接 機	接 踵	接 踵 比 肩	接 踵 而 至	
接 踵 而 來	接 辦	接 頭	接 頭 辭	接 應	接 應 不 暇	接 濟	接 獲	
接 環	接 穗	接 縫	接 點	接 辭	接 壤	接 觸	接 續	
接 續 而 來	接 續 香 煙	接 茬	接 碴	捷 元 公 司	捷 克	捷 克 人	捷 克 和 斯 洛 伐 克	
捷 克 斯 拉 夫 共 和 國	捷 克 幣	捷 克 語	捷 足	捷 足 先 得	捷 足 先 登	捷 者	捷 徑	
捷 報	捷 報 頻 傳	捷 運	捷 運 局	捧 人	捧 心 西 子	捧 住	捧 走	
捧 杯	捧 持	捧 起	捧 場	捧 著	捧 腹	捧 腹 大 笑	捧 腹 軒 渠	
捧 頭 鼠 竄	捧 轂 推 輪	掘 土	掘 土 機	掘 井	掘 以	掘 出	掘 地	
掘 坑	掘 到	掘 取	掘 於	掘 室 求 鼠	掘 洞	掘 洞 穴	掘 起	
掘 通	掘 進	掘 進 率	掘 溝	掘 墓	掘 墓 人	掘 壕	掘 翻	
掘 鑿 器	措 口	措 手	措 手 不 及	措 手 不 迭	措 失	措 施	措 施 不 力	
措 款	措 詞	措 詞 不 當	措 詞 巧 妙	措 置 有 方	措 顏 天 地	措 顏 乖 方	措 辭	
措 辭 上	措 辭 不 當	捱 三 頂 五	捱 三 頂 四	捱 風 緝 縫	捱 過	掩 人	掩 人 耳 目	
掩 上	掩 口	掩 口 胡 盧	掩 目 捕 雀	掩 耳	掩 耳 而 走	掩 耳 偷 鈴	掩 耳 盜 鈴	
掩 耳 盜 鐘	掩 住	掩 沒	掩 其 不 備	掩 其 無 備	掩 卷	掩 映	掩 映 生 姿	
掩 美 絕 俗	掩 面	掩 面 失 色	掩 埋	掩 埋 場	掩 掩	掩 惡 揚 善	掩 惡 溢 美	
掩 著	掩 瑕 藏 疾	掩 罪 飾 非	掩 飾	掩 飾 物	掩 旗 息 鼓	掩 蓋	掩 鼻	
掩 鼻 而 過	掩 鼻 偷 香	掩 蔽	掩 蔽 處	掩 賢 妒 善	掩 藏	掩 護	掩 護 物	
掩 體	掉 了	掉 入	掉 下	掉 以 輕 心	掉 出	掉 包	掉 在	
掉 舌 鼓 唇	掉 色	掉 到	掉 秤	掉 淚	掉 換	掉 進	掉 隊	
掉 落	掉 過	掉 價	掉 價 兒	掉 嘴 弄 舌	掉 膘	掉 頭	掉 頭 鼠 竄	
掉 臂 不 顧	掉 轉	掃 出	掃 去	掃 平	掃 田 刮 地	掃 穴 犁 庭	掃 光	
掃 地	掃 地 以 盡	掃 地 出 門	掃 地 俱 盡	掃 地 無 餘	掃 尾	掃 把	掃 到	
掃 刮	掃 帚	掃 房	掃 盲	掃 毒	掃 眉 才 子	掃 倒	掃 射	
掃 除	掃 除 天 下	掃 掠	掃 清	掃 雪	掃 描	掃 描 器	掃 視	
掃 黃	掃 黑	掃 滅	掃 過	掃 雷	掃 雷 戰	掃 雷 艦	掃 墓	
掃 榻 以 待	掃 瞄	掃 瞄 器	掃 興	掃 蕩	掃 邊	掛 一 漏 萬	掛 人	
掛 入	掛 上	掛 心	掛 斗	掛 欠	掛 出	掛 包	掛 去	
掛 失	掛 布	掛 印 懸 牌	掛 名	掛 在	掛 成	掛 羊 頭 賣 狗 肉	掛 衣	
掛 住	掛 孝	掛 肚 牽 心	掛 車	掛 弦	掛 念	掛 物 架	掛 花	
掛 表	掛 冠	掛 帥	掛 架	掛 紅	掛 面	掛 晃	掛 級	
掛 起	掛 帳	掛 彩	掛 接	掛 掉	掛 牽	掛 單	掛 毯	
掛 牌	掛 著	掛 腸 懸 膽	掛 號	掛 號 室	掛 運	掛 鉤	掛 零	
掛 飾	掛 圖	掛 漏	掛 滿	掛 慮	掛 靠	掛 齒	掛 擋	
掛 歷	掛 燈 結 彩	掛 氈	掛 斷	掛 職	掛 鎖	掛 懷	掛 鐘	
捫 心	捫 心 自 問	捫 心 無 愧	捫 虱 而 言	捫 參 歷 井	捫 隙 發 罅	推 了	推 入	
推 力	推 三 阻 四	推 三 挨 四	推 三 宕 四	推 上	推 亡 固 存	推 土	推 土 機	
推 子	推 己 及 人	推 及	推 天 搶 地	推 心	推 心 置 腹	推 手	推 出	
推 去	推 本 溯 源	推 向	推 托	推 而 廣 之	推 舟	推 舟 於 陸	推 行	
推 估	推 究	推 見	推 走	推 車	推 車 者	推 事	推 事 席	
推 來	推 到	推 卸	推 卸 責 任	推 宗 明 本	推 定	推 延	推 拉 門	
推 東 主 西	推 波 助 瀾	推 法	推 知	推 門	推 門 入 □	推 門 而 入	推 卻	
推 後	推 故	推 為	推 重	推 食 解 衣	推 倒	推 倒 重 來	推 展	
推 拿	推 挽	推 挽 式	推 病	推 起	推 送	推 動	推 動 力	
推 動 者	推 動 器	推 問	推 崇	推 崇 備 至	推 情 准 理	推 掉	推 推	
推 桿	推 理	推 理 者	推 移	推 脫	推 陳	推 陳 出 新	推 換	
推 測	推 測 上	推 測 學	推 給	推 著	推 進	推 進 力	推 進 改 革	
推 進 物	推 進 者	推 進 器	推 開	推 想	推 群 獨 步	推 誠	推 誠 布 公	
推 誠 布 信	推 誠 待 物	推 誠 相 見	推 誠 接 物	推 誠 置 腹	推 運	推 鉛 球	推 敲	
推 演	推 算	推 廣	推 廣 應 用	推 撞	推 諉	推 論	推 論 性	
推 賢 下 士	推 賢 任 人	推 賢 進 士	推 賢 進 善	推 賢 遜 能	推 賢 樂 善	推 賢 舉 善	推 賢 讓 能	
推 輪 捧 轂	推 銷	推 銷 員	推 銷 術	推 導	推 磨	推 選	推 遲	
推 戴	推 擠	推 檢 人 員	推 濤 作 浪	推 燥 居 濕	推 舉	推 謝	推 轂 薦 士	
推 斷	推 斷 出	推 翻	推 薦	推 薦 者	推 薦 書	推 襟 送 抱	推 辭	
推 聾 妝 啞	推 聾 做 啞	推 讓	推 搡	掄 刀	掄 眉 豎 目	掄 拳	掄 棍	
授 人	授 人 口 實	授 人 以 柄	授 予	授 予 者	授 手 援 溺	授 以	授 奶	
授 任	授 乳	授 乳 期	授 受	授 受 不 親	授 命	授 於	授 法	
授 冠 者	授 計	授 時	授 粉	授 動	授 給	授 意	授 業	
授 業 解 惑	授 旗	授 槍	授 稱 號	授 精	授 與	授 與 封	授 銜	
授 獎	授 課	授 勳	授 爵 位	授 職	授 職 者	授 職 惟 賢	授 權	
授 權 與	掙 扎	掙 來	掙 到	掙 個	掙 起	掙 得	掙 脫	
掙 著	掙 開	掙 飯	掙 錢	掙 點	掙 斷	採 用	採 石	
採 石 場	採 伐	採 光	採 光 剖 璞	採 取	採 取 不 正 當 的 手 段	採 取 多 種 形 式	採 取 措 施	
採 花	採 珠 業	採 納	採 納 者	採 茶	採 掘	採 訪	採 訪 工 作	
採 訪 者	採 訪 員	採 訪 層	採 訪 錄	採 買	採 集	採 集 箱	採 摘	
採 蜜 鳥	採 辦	採 選	採 購	採 購 供 應 站	採 購 者	採 購 員	採 購 弊 案	
採 擷	採 礦	採 礦 場	採 礦 業	掬 起	排 人	排 入	排 上	
排 山 倒 峽	排 山 倒 海	排 山 壓 卵	排 干	排 比	排 水	排 水 口	排 水 系 統	
排 水 渠	排 水 量	排 水 溝	排 水 管	排 水 槽	排 他	排 他 性	排 出	
排 去	排 外	排 它 性	排 斥	排 斥 異 己	排 列	排 印	排 名	
排 在	排 好	排 字	排 成	排 汗	排 污	排 行	排 兵 佈 陣	
排 卵	排 尿	排 尾	排 序	排 到	排 定	排 放	排 放 器	
排 法	排 泄	排 泄 物	排 泄 腔	排 版	排 空	排 長	排 長 隊	
排 便	排 架	排 洪	排 炮	排 風	排 氣	排 氣 口	排 班	
排 陣	排 除	排 除 異 己	排 除 萬 難	排 骨	排 患 解 紛	排 球	排 場	
排 筆	排 筏	排 華	排 鈕	排 開	排 隊	排 愁 破 涕	排 號	
排 解	排 雷	排 演	排 遣	排 障	排 齊	排 憂 解 難	排 練	
排 課	排 調	排 壇	排 擋	排 整 齊	排 錯	排 頭	排 頭 兵	
排 戲	排 擊	排 擠	排 擠 掉	排 檔	排 糞	排 膿	排 瀉 口	
排 難	排 難 解 紛	排 灌	排 澇	掏 出	掏 到	掏 取	掏 空	
掏 空 資 產	掏 給	掏 腰 包	掏 盡	掏 錢	掏 糞	掀 天 揭 地	掀 天 斡 地	
掀 到	掀 背 式	掀 風 鼓 浪	掀 起	掀 動	掀 掉	掀 開	掀 雷 決 電	
捻 角	捻 度	捻 軍	捻 神 捻 鬼	捻 捻	捻 著 鼻 子	捻 搓 機	捻 腳 撚 手	
捨 人	捨 入	捨 己	捨 己 成 人	捨 己 芸 人	捨 己 為 人	捨 己 為 公	捨 己 從 人	
捨 己 救 人	捨 己 就 人	捨 不 得	捨 友	捨 去	捨 本	捨 本 事 末	捨 本 問 末	
捨 本 逐 末	捨 正 從 邪	捨 生 存 義	捨 生 忘 死	捨 生 取 義	捨 安 就 危	捨 死 忘 生	捨 位	
捨 利	捨 利 塔	捨 我 其 誰	捨 我 復 誰	捨 身	捨 身 求 法	捨 身 為 國	捨 身 救 人	
捨 身 圖 報	捨 車 保 帥	捨 命	捨 命 救 人	捨 近	捨 近 即 遠	捨 近 求 遠	捨 近 務 遠	
捨 近 謀 遠	捨 得	捨 掉	捨 棄	捨 短 用 長	捨 短 取 長	捨 短 從 長	捨 短 錄 長	
捨 給	捨 間	捨 實 求 虛	捨 親	捺 印	敝 人	敝 局	敝 村	
敝 帚 自 珍	敝 店	敝 所	敝 社	敝 舍	敝 校	敝 國	敝 部	
敝 隊	敝 團	敝 縣	敝 體	敖 不 可 長	敖 幼 祥	救 了	救 人	
救 人 一 命	救 人 須 救 徹	救 亡	救 亡 圖 存	救 火	救 火 船	救 火 揚 沸	救 世	
救 世 主	救 出	救 去	救 母	救 民	救 民 水 火	救 生	救 生 衣	
救 生 員	救 生 索	救 生 圈	救 生 船	救 生 傘	救 生 筏	救 生 艇	救 死 扶 傷	
救 兵	救 助	救 困 扶 危	救 我	救 災	救 災 物 資	救 災 恤 患	救 命	
救 命 者	救 命 恩 人	救 法	救 治	救 者	救 急	救 星	救 活	
救 苦 救 難	救 荒	救 起	救 國	救 國 團	救 救	救 球	救 援	
救 援 工 作	救 焚 拯 溺	救 經 引 足	救 過 不 贍	救 過 補 闕	救 駕	救 險	救 應	
救 濟	救 濟 災 民	救 濟 者	救 濟 金	救 濟 院	救 濟 費	救 濟 糧	救 難	
救 難 者	救 難 船	救 護	救 護 車	救 護 所	教 一 識 百	教 了	教 人	
教 女	教 子	教 子 有 方	教 工	教 化	教 友	教 父	教 主	
教 他	教 代 會	教 令	教 史	教 外	教 本	教 正	教 母	
教 民	教 名	教 寺	教 成	教 廷	教 改	教 材	教 狂	
教 育	教 育 方 針	教 育 局	教 育 改 革	教 育 事 件	教 育 性	教 育 法	教 育 政 策	
教 育 界	教 育 家	教 育 部	教 育 學	教 育 廳	教 具	教 制	教 委	
教 宗	教 官	教 法	教 者	教 長	教 門	教 室	教 律	
教 派	教 界	教 皇	教 皇 權	教 研	教 研 室	教 研 組	教 科 文	
教 科 文 教	教 科 文 組 織	教 科 文 衛	教 科 書	教 唆	教 唆 犯	教 員	教 席	
教 師	教 師 隊 伍	教 師 節	教 徒	教 書	教 書 匠	教 書 育 人	教 案	
教 桌	教 益	教 祖	教 訓	教 訓 性	教 訓 者	教 務	教 務 科	
教 務 處	教 區	教 堂	教 授	教 授 法	教 教	教 條	教 條 主 義	
教 理	教 習	教 規	教 無 常 師	教 程	教 階	教 會	教 會 學 校	
教 義	教 義 學	教 過	教 團	教 誨	教 誨 者	教 範	教 練	
教 練 員	教 練 機	教 課	教 養	教 養 員	教 養 院	教 學	教 學 大 綱	
教 學 法	教 學 相 長	教 學 樓	教 導	教 導 員	教 導 處	教 導 隊	教 錯	
教 頭	教 職	教 職 工	教 職 員	教 職 員 工	教 鞭	教 壞	教 籍	
教 齡	教 權	教 猱 升 木	敗 了	敗 下 陣 來	敗 亡	敗 不 旋 踵	敗 化 傷 風	
敗 火	敗 仗	敗 北	敗 名	敗 血	敗 血 病	敗 血 症	敗 兵	
敗 局	敗 走	敗 事	敗 事 有 餘	敗 性	敗 於 垂 成	敗 法 亂 紀	敗 的	
敗 者	敗 俗	敗 俗 傷 化	敗 俗 傷 風	敗 柳 殘 花	敗 相	敗 胃	敗 軍	
敗 軍 之 將	敗 家 子	敗 草	敗 退	敗 逃	敗 陣	敗 國 亡 家	敗 國 喪 家	
敗 將	敗 將 殘 兵	敗 筆	敗 絮	敗 絮 其 中	敗 給	敗 訴	敗 落	
敗 葉	敗 過	敗 盡	敗 興	敗 績	敗 壞	敗 類	敗 露	
敗 鱗 殘 甲	啟 人 疑 竇	啟 口	啟 用	啟 示	啟 示 性	啟 示 者	啟 示 錄	
啟 事	啟 明	啟 阜 工 程	啟 阜 建 設	啟 奏	啟 封	啟 迪	啟 航	
啟 動	啟 動 市 場	啟 閉	啟 發	啟 發 式	啟 發 性	啟 發 者	啟 程	
啟 開	啟 稟	啟 運	啟 蒙	啟 齒	敏 原	敏 悟	敏 捷	
敏 感	敏 感 化	敏 感 性	敏 銳	敘 及	敘 永	敘 別	敘 利 亞	
敘 利 亞 人	敘 言	敘 事	敘 事 曲	敘 事 詩	敘 法	敘 者	敘 述	
敘 述 文	敘 述 性	敘 述 法	敘 述 者	敘 唱	敘 情	敘 說	敘 談	
敘 舊	敕 令	敕 許	斜 上	斜 井	斜 方 形	斜 交	斜 向	
斜 吹	斜 角	斜 身	斜 坡	斜 度	斜 面	斜 面 路	斜 風 細 雨	
斜 倚	斜 射	斜 桅	斜 紋	斜 紋 布	斜 斜	斜 率	斜 眼	
斜 堤	斜 著	斜 視	斜 視 眼	斜 陽	斜 暉	斜 照	斜 路	
斜 道	斜 過	斜 槓	斜 層	斜 線	斜 輝	斜 靠	斜 橋	
斜 頸	斜 壓	斜 邊	斜 體	斜 體 字	斬 妖	斬 決	斬 首	
斬 草 除 根	斬 釘 截 鐵	斬 將 奪 旗	斬 將 搴 旗	斬 殺	斬 蛇 逐 鹿	斬 碎	斬 盡 殺 絕	
斬 鋼 截 鐵	斬 獲	斬 斷	族 人	族 仇	族 兄	族 外	族 名	
族 姓	族 居	族 長	族 間	族 群	族 譜	族 類	族 權	
旋 升	旋 太 緊	旋 光	旋 回	旋 式	旋 即	旋 床	旋 弄	
旋 形	旋 扭	旋 松	旋 度	旋 律	旋 律 化	旋 律 學	旋 風	
旋 宮	旋 紐	旋 乾 轉 坤	旋 得	旋 梯	旋 渦	旋 鈕	旋 開	
旋 塞	旋 緊	旋 盤	旋 調 管	旋 翼	旋 翼 機	旋 繞	旋 轉	
旋 轉 物	旋 轉 體	旌 善 懲 惡	旌 旗	旌 旗 招 展	旌 旗 蔽 天	旌 旗 蔽 日	旌 旗 蔽 空	
旌 德	晝 日	晝 出 夜 息	晝 伏 夜 出	晝 伏 夜 遊	晝 夜	晝 夜 兼 行	晝 夜 兼 程	
晝 間	晝 錦 之 榮	晝 錦 榮 歸	晚 了	晚 上	晚 生	晚 生 後 學	晚 安	
晚 年	晚 育	晚 車	晚 些	晚 些 時 候	晚 到	晚 於	晚 近	
晚 春	晚 星	晚 秋	晚 秋 作 物	晚 風	晚 唐	晚 夏	晚 宴	
晚 班	晚 茶	晚 起	晚 婚	晚 婚 晚 育	晚 清	晚 場	晚 報	
晚 晴 協 會	晚 晴 婦 女 協 會	晚 景	晚 期	晚 湯	晚 間	晚 飯	晚 會	
晚 歲	晚 節	晚 節 不 終	晚 節 末 路	晚 節 黃 花	晚 補	晚 裝	晚 睡	
晚 睡 晚 起	晚 暮	晚 熟	晚 稻	晚 輩	晚 餐	晚 霜	晚 霞	
晚 點	晚 禮	晚 禱	晚 鐘	晚 戀	晤 見	晤 面	晤 商	
晤 談	晨 光	晨 曲	晨 昏	晨 昏 定 省	晨 炊 星 飯	晨 星	晨 風	
晨 參 暮 省	晨 參 暮 禮	晨 報	晨 間	晨 號	晨 操	晨 興 夜 寐	晨 霧	
晨 曦	晨 鐘	晨 鐘 暮 鼓	晦 氣	晦 暗	晦 跡 韜 光	晦 澀	曹 汝 霖	
曹 社 之 謀	曹 禺	曹 雪 芹	曹 竣 揚	曹 操	曹 興 誠	曹 錦 輝	望 人	
望 子 成 才	望 子 成 名	望 子 成 龍	望 不 到	望 不 到 邊	望 文 生 義	望 月	望 去	
望 台	望 外	望 安	望 江	望 而	望 而 生 畏	望 而 卻 步	望 杏 瞻 榆	
望 杏 瞻 蒲	望 見	望 角	望 其 肩 背	望 其 肩 項	望 其 項 背	望 到	望 門 大 嚼	
望 門 投 止	望 洋	望 洋 興 歎	望 洋 驚 歎	望 秋 先 零	望 穿	望 穿 秋 水	望 風	
望 風 瓦 解	望 風 而 走	望 風 而 降	望 風 而 逃	望 風 而 遁	望 風 承 旨	望 風 披 靡	望 風 捕 影	
望 風 響 應	望 族	望 望	望 梅 止 渴	望 眼 將 穿	望 眼 欲 穿	望 景	望 著	
望 雲 之 情	望 塵 不 及	望 塵 而 拜	望 塵 莫 及	望 聞 問 切	望 遠	望 遠 鏡	望 樓	
望 衡 對 宇	望 斷	梁 山	梁 木	梁 架	梁 家 榕	梁 家 輝	梁 朝 偉	
梁 詠 琪	梯 子	梯 山 航 海	梯 田	梯 式	梯 次	梯 次 配 備	梯 形	
梯 狀	梯 度	梯 架	梯 恩 梯	梯 級	梯 級 開 發	梯 隊	梯 隊 式	
梯 階 式	梯 繩	梢 孔	梢 部	梢 頭	梓 官 鄉	梵 文	梵 蒂 岡	
梵 語	梵 諦 岡	桿 子	桿 兒	桿 狀	桿 狀 病 毒	桿 狀 細 菌	桿 秤	
桿 菌	桿 塔	桿 檔	桶 口	桶 內	桶 孔	桶 形	桶 狀	
桶 裝	桶 裝 瓦 斯	桶 蓋	桶 槽	梧 桐	梧 棲	梧 鼠 之 技	梗 死	
梗 米	梗 直	梗 阻	梗 塞	梗 概	械 工	械 庫	械 鬥	
棄 之	棄 之 可 惜	棄 文 就 武	棄 世	棄 本 逐 末	棄 甲	棄 甲 曳 兵	棄 如 弁 髦	
棄 守	棄 邪 從 正	棄 邪 歸 正	棄 兒	棄 取	棄 官	棄 武 修 文	棄 物	
棄 若 敝 屣	棄 婦	棄 短 取 長	棄 絕	棄 暗 投 明	棄 瑕 取 用	棄 瑕 錄 用	棄 置	
棄 義	棄 過 圖 新	棄 學	棄 嬰	棄 職	棄 舊	棄 舊 圖 新	棄 舊 憐 新	
棄 權	棄 權 票	梭 子	梭 巡	梭 梭	梭 魚	梭 織	梆 子	
梆 梆	梅 子	梅 山	梅 的	梅 花	梅 花 形	梅 花 鹿	梅 雨	
梅 毒	梅 捷 企 業	梅 園	梅 爾 吉 勃 遜	梅 爾 喜	梅 樹	梅 縣	梅 蘭	
梅 蘭 芳	梅 豔 芳	梔 子	條 子	條 分 縷 晰	條 文	條 令	條 目	
條 石	條 件	條 件 下	條 件 反 射	條 件 刺 激	條 形	條 形 圖	條 形 碼	
條 例	條 板	條 板 箱	條 狀 物	條 約	條 捆	條 案	條 紋	
條 紋 羚	條 帶	條 條	條 條 框 框	條 條 塊 塊	條 理	條 理 分 明	條 痕	
條 規	條 陳	條 幅	條 款	條 絨	條 塊	條 塊 分 割	條 塊 結 合	
條 凳	條 播	條 數	條 碼	條 鋼	條 蟲	梨 子	梨 形	
梨 花	梨 園	梨 園 子 弟	梨 園 弟 子	梨 樹	梨 頰 微 渦	梟 首	梟 雄	
欲 人 勿 知 莫 若 勿 為	欲 人 勿 聞 莫 若 勿 言	欲 仙	欲 加 之 罪 何 患 無 辭	欲 求	欲 言 又 止	欲 取	欲 取 故 與	
欲 倒	欲 益 反 損	欲 售	欲 將	欲 得	欲 設	欲 速 不 達	欲 速 則 不 達	
欲 報 復	欲 裂	欲 想	欲 罪	欲 補	欲 試	欲 滴	欲 睡	
欲 與	欲 蓋 而 彰	欲 蓋 彌 彰	欲 語	欲 說 又 止	欲 說 還 休	欲 窮 千 里 目	欲 罷	
欲 罷 不 能	欲 擒	欲 擒 故 縱	欲 瞭 解	殺 一 利 百	殺 一 警 百	殺 一 儆 百	殺 人	
殺 人 不 見 血	殺 人 不 眨 眼	殺 人 犯	殺 人 如 芥	殺 人 如 草	殺 人 如 麻	殺 人 放 火	殺 人 者	
殺 人 盈 野	殺 人 越 貨	殺 人 滅 口	殺 人 罪	殺 人 償 命 欠 債 還 錢	殺 女	殺 子	殺 手	
殺 父	殺 幼	殺 生	殺 生 之 柄	殺 生 之 權	殺 生 與 奪	殺 伐	殺 光	
殺 死	殺 衣 縮 食	殺 低	殺 戒	殺 身	殺 身 之 禍	殺 身 出 生	殺 身 成 仁	
殺 身 成 名	殺 身 成 義	殺 身 救 國	殺 身 報 國	殺 妻	殺 妻 求 將	殺 性	殺 青	
殺 毒	殺 風 景	殺 害	殺 氣	殺 氣 騰 騰	殺 退	殺 除 劑	殺 馬 毀 車	
殺 掠	殺 掉	殺 菌	殺 菌 物	殺 菌 素	殺 菌 劑	殺 傷	殺 傷 力	
殺 傷 性	殺 滅	殺 鼠 藥	殺 價	殺 戮	殺 敵	殺 敵 致 果	殺 豬	
殺 機	殺 親	殺 頭	殺 嬰	殺 蟲	殺 蟲 劑	殺 雞	殺 雞 取 卵	
殺 雞 取 蛋	殺 雞 炊 黍	殺 雞 為 黍	殺 雞 焉 用 牛 刀	殺 雞 給 猴 看	殺 雞 駭 猴	殺 雞 嚇 猴	殺 彘 教 子	
毫 不	毫 不 介 意	毫 不 相 干	毫 不 留 情	毫 不 動 搖	毫 不 猶 豫	毫 不 遲 疑	毫 不 講 理	
毫 分 縷 析	毫 升	毫 巴	毫 毛	毫 末 之 利	毫 瓦	毫 伏	毫 安	
毫 安 表	毫 安 培	毫 米	毫 米 波	毫 米 數	毫 亨	毫 克	毫 周 波	
毫 秒	毫 脈	毫 無	毫 無 二 致	毫 無 根 據	毫 無 意 義	毫 無 疑 問	毫 無 疑 義	
毫 無 價 值	毫 無 關 係	毫 微	毫 微 米	毫 微 秒	毫 髮	毫 髮 不 犯	毫 髮 不 爽	
毫 釐	毫 釐 千 里	毫 釐 不 爽	氫 化	氫 化 物	氫 氟 酸	氫 核	氫 氣	
氫 氧	氫 氧 化 物	氫 氧 化 鈣	氫 氧 化 鈉	氫 氧 化 鉀	氫 氧 化 銨	氫 氧 化 鋁	氫 氧 根	
氫 氧 基	氫 酸	氫 酸 鹽	氫 彈	氫 鍵	氫 氰 酸	涎 皮 賴 臉	涼 了	
涼 山	涼 水	涼 台	涼 快	涼 拌	涼 拌 生 菜	涼 亭	涼 風	
涼 席	涼 氣	涼 粉	涼 爽	涼 瓶	涼 處	涼 傘	涼 廊	
涼 棚	涼 菜	涼 意	涼 鞋	涼 颼 颼	淳 化	淳 安	淳 厚	
淳 淳	淳 樸	淙 淙	液 化	液 化 氣	液 化 器	液 汁	液 位	
液 冷	液 泡	液 狀	液 計	液 面	液 氨	液 晶	液 晶 顯 示 器	
液 量	液 腺	液 態	液 態 氣	液 質	液 壓	液 體	淡 入	
淡 化	淡 水	淡 水 雪	淡 水 魚	淡 水 魚 類	淡 水 湖	淡 水 鎮	淡 出	
淡 光	淡 江 大 學	淡 灰 色	淡 色	淡 妝	淡 妝 濃 抹	淡 忘	淡 味	
淡 季	淡 泊	淡 的	淡 青	淡 青 色	淡 紅	淡 紅 色	淡 茶	
淡 啤	淡 啤 酒	淡 淡	淡 然	淡 然 處 之	淡 紫 色	淡 菜	淡 雅	
淡 飯	淡 黃	淡 黃 色	淡 黑	淡 塗	淡 裝	淡 漠	淡 綠	
淡 綠 色	淡 寫	淡 褐 色	淡 靜	淡 薄	淌 下	淌 口 水	淌 出	
淌 汗	淤 血	淤 沙	淤 泥	淤 泥 般	淤 斑	淤 塞	淤 積	
添 丁	添 入	添 上	添 加	添 加 物	添 加 劑	添 兵 減 灶	添 枝 加 葉	
添 注	添 油 加 醋	添 附	添 建	添 倉	添 添	添 設	添 湊	
添 菜	添 飯	添 亂	添 煤	添 置	添 補	添 滿	添 燃	
添 磚 加 瓦	添 翼	添 購	淺 土	淺 水	淺 灰	淺 色	淺 希 近 求	
淺 見	淺 見 寡 聞	淺 見 寡 識	淺 見 薄 識	淺 底	淺 易	淺 析	淺 近	
淺 盆	淺 紅	淺 陋	淺 海	淺 浮 雕	淺 笑	淺 淡	淺 淺	
淺 黃	淺 黃 色	淺 黑	淺 黑 色	淺 黑 型	淺 斟 低 酌	淺 斟 低 唱	淺 斟 低 謳	
淺 嘗	淺 嘗 輒 止	淺 窩	淺 綠	淺 綠 色	淺 說	淺 領	淺 層	
淺 盤	淺 談	淺 論	淺 薄	淺 鍋	淺 藍	淺 藍 色	淺 議	
淺 釋	淺 露	淺 灘	淺 顯	淺 顯 易 懂	清 一 色	清 人	清 三 電 子	
清 丈	清 心	清 心 省 事	清 心 寡 慾	清 欠	清 水	清 水 河	清 水 衙 門	
清 水 鎮	清 代	清 冊	清 史	清 平 世 界	清 末	清 正 廉 潔	清 白	
清 存 貨	清 早	清 灰 冷 灶	清 耳 悅 心	清 冷	清 廷	清 秀	清 官	
清 官 難 斷 家 務 事	清 明	清 明 節	清 河	清 波	清 油	清 空	清 芬	
清 初	清 亮	清 垢	清 客	清 幽	清 律	清 查	清 查 工 作	
清 泉	清 泉 崗 機 場	清 流	清 洗	清 苦	清 音	清 風	清 風 兩 袖	
清 風 明 月	清 風 勁 節	清 風 郎 月	清 風 峻 節	清 風 高 節	清 風 高 誼	清 香	清 倉	
清 宮	清 庫	清 朗	清 真	清 真 寺	清 純	清 脆	清 茶	
清 茶 淡 飯	清 退	清 除	清 除 出 黨	清 高	清 唱	清 帳	清 掃	
清 掃 者	清 教	清 教 徒	清 族	清 晨	清 曹 峻 府	清 涼	清 涼 油	
清 液	清 淡	清 清	清 清 白 白	清 清 楚 楚	清 淚	清 淨	清 淨 機	
清 爽	清 理	清 甜	清 產	清 產 核 資	清 規	清 規 戒 律	清 貧	
清 貧 如 洗	清 貧 寡 慾	清 野	清 單	清 場	清 寒	清 寒 情 操	清 廁 夫	
清 晰	清 晰 度	清 朝	清 渭 濁 涇	清 湯	清 湯 寡 水	清 稅	清 華	
清 華 大 學	清 詞 麗 句	清 越	清 閒	清 閒 自 在	清 雅	清 雅 絕 塵	清 剿	
清 嗓	清 塘	清 廉	清 新	清 新 俊 逸	清 楚	清 源	清 源 正 本	
清 聖 濁 賢	清 運	清 道	清 道 夫	清 零	清 塵 濁 水	清 歌 妙 舞	清 漆	
清 澈	清 福	清 算	清 算 人	清 蒸	清 樣	清 澄	清 潔	
清 潔 工	清 潔 化	清 潔 品	清 潔 衛 生	清 潔 劑	清 潔 器	清 澗	清 熱	
清 瘦	清 盤	清 稿	清 談	清 談 高 論	清 賬	清 醇	清 濁	
清 濁 同 流	清 燉	清 醒	清 靜	清 靜 無 為	清 靜 寡 慾	清 償	清 償 債 務	
清 還	清 邁	清 鍋 冷 灶	清 點	清 蹕 傳 道	清 繳	清 麗	清 麗 俊 逸	
清 議 不 容	清 馨	清 黨	清 譽	淇 淋	淋 了	淋 巴	淋 巴 液	
淋 巴 球	淋 巴 細 胞	淋 巴 結	淋 巴 腺	淋 巴 管	淋 水	淋 沖	淋 走	
淋 雨	淋 毒	淋 浴	淋 病	淋 淋	淋 菌	淋 漓	淋 漓 盡 致	
淋 濕	涯 子	淑 人 君 子	淑 女	涮 洗	淞 滬	淹 了	淹 水	
淹 旬 曠 月	淹 死	淹 沒	淹 淹 一 息	涸 澤 而 漁	涸 轍 之 枯	涸 轍 之 魚	涸 轍 之 鮒	
涸 轍 枯 魚	涸 轍 窮 魚	混 入	混 子	混 日 子	混 水 摸 魚	混 世 魔 王	混 以	
混 充	混 用	混 交 林	混 同	混 名	混 合	混 合 成	混 合 物	
混 合 劑	混 合 器	混 合 雙 打	混 合 體	混 在	混 成	混 成 曲	混 有	
混 有 鹽	混 血	混 血 兒	混 血 種	混 作	混 沌	混 身	混 事	
混 到	混 制	混 和	混 性	混 拌	混 放	混 俗 和 光	混 為	
混 為 一 談	混 為 一 體	混 紡	混 紡 紗	混 記	混 參	混 帳	混 得	
混 排	混 混	混 淆	混 淆 不 清	混 淆 是 非	混 淆 視 聽	混 淆 黑 白	混 蛋	
混 造 黑 白	混 棉	混 進	混 飯	混 亂	混 跡	混 跡 其 中	混 過	
混 種	混 語	混 熟	混 養	混 凝 土	混 戰	混 濁	混 濁 不 清	
混 頻	混 頻 器	混 雜	混 雜 物	混 騙	混 響	淵 博	淵 源	
淵 藪	淅 瀝	淒 切	淒 冷	淒 咽	淒 風 冷 雨	淒 風 苦 雨	淒 婉	
淒 涼	淒 清	淒 淒	淒 然	淒 愴	淒 楚	淒 滄	淒 慘	
淒 蒼	淒 厲	淒 嚦	涵 洞	涵 意	涵 義	涵 閘	涵 管	
涵 蓋	涵 養	涵 體	淚 人	淚 下	淚 下 如 雨	淚 水	淚 如 雨 下	
淚 如 泉 湧	淚 汪 汪	淚 花	淚 雨	淚 流	淚 流 滿 面	淚 珠	淚 液	
淚 痕	淚 眼	淚 眼 愁 眉	淚 腺	淚 滴	淚 管	淚 彈	淫 巧	
淫 行	淫 邪	淫 念	淫 雨	淫 威	淫 書	淫 婦	淫 媒	
淫 棍	淫 猥	淫 亂	淫 業	淫 話	淫 語	淫 慾	淫 樂	
淫 蕩	淫 戲	淫 癖	淫 穢	淫 穢 物 品	淘 出	淘 米	淘 沙	
淘 汰	淘 汰 賽	淘 空	淘 金	淘 洗	淘 氣	淘 氣 鬼	淘 淘	
淘 淨	淘 糞	淪 入	淪 亡	淪 肌 浹 髓	淪 為	淪 陷	淪 陷 區	
淪 喪	淪 滅	淪 落	深 一 層	深 入	深 入 人 心	深 入 分 析	深 入 生 活	
深 入 研 究	深 入 基 層	深 入 淺 出	深 入 群 眾	深 入 實 際	深 入 顯 出	深 山	深 山 老 林	
深 山 窮 谷	深 不 可 測	深 井	深 仇	深 仇 大 恨	深 切	深 化	深 化 改 革	
深 及	深 及 膝	深 文 功 劾	深 文 巧 詆	深 文 周 納	深 水	深 凹	深 加 工	
深 田 祐 介	深 交	深 圳	深 圳 市	深 圳 灣	深 奸 巨 猾	深 宅 大 院	深 有	
深 有 同 感	深 有 感 觸	深 有 體 會	深 灰	深 灰 色	深 色	深 吻	深 坑	
深 更 半 夜	深 沉	深 究	深 言	深 谷	深 刻	深 刻 性	深 到 腰	
深 受	深 受 其 害	深 呼 吸	深 夜	深 居 簡 出	深 底	深 的	深 知	
深 表	深 表 遺 憾	深 表 謝 意	深 長	深 信	深 信 不 疑	深 厚	深 厚 感 情	
深 巷	深 度	深 思	深 思 者	深 思 遠 慮	深 思 熟 慮	深 恨	深 為	
深 省	深 秋	深 紅	深 紅 色	深 致 謝 意	深 計 遠 慮	深 重	深 宮	
深 恐	深 根 固 柢	深 根 固 蒂	深 海	深 耕	深 耕 細 作	深 草	深 院	
深 得	深 得 人 心	深 悉	深 情	深 情 厚 誼	深 望	深 淺	深 淵	
深 淵 薄 冰	深 深	深 處	深 通	深 造	深 透	深 部	深 閉 固 距	
深 陷	深 惡	深 惡 痛 恨	深 惡 痛 絕	深 惡 痛 詆	深 惡 痛 嫉	深 測	深 痛	
深 痛 惡 絕	深 紫	深 傷	深 奧	深 意	深 感	深 愛	深 暗	
深 溝	深 溝 高 壁	深 溝 高 壘	深 溝 堅 壁	深 溝 堅 壘	深 窪	深 綠	深 綠 色	
深 遠	深 閨	深 厲 淺 揭	深 層	深 層 次	深 廣	深 慮	深 憂	
深 摯	深 槽	深 潭	深 稽 博 考	深 褐	深 褐 色	深 談	深 橙 色	
深 澤	深 謀	深 謀 遠 略	深 謀 遠 猷	深 謀 遠 慮	深 醒	深 翻	深 藏	
深 藏 若 虛	深 藏 遠 遁	深 藍	深 藍 色	深 邃	深 識 遠 慮	深 蘭 色	淮 北	
淮 安	淮 河	淮 南	淮 南 雞 犬	淮 海	淮 陰	淮 鹽	淨 土	
淨 化	淨 化 空 氣	淨 化 器	淨 手	淨 支	淨 水	淨 本	淨 光	
淨 地	淨 收 入	淨 余	淨 利	淨 身	淨 空	淨 室	淨 是	
淨 重	淨 值	淨 差	淨 高	淨 得	淨 剩	淨 量	淨 損	
淨 增	淨 數	淨 盤 將 軍	淨 銷	淨 辦	淨 賺	淨 額	淨 灘	
淄 博	涪 陵	淬 火	淬 透 性	涿 州	烹 犬 藏 弓	烹 具	烹 制	
烹 煮	烹 飪	烹 飪 法	烹 飪 學	烹 調	烹 調 法	烹 調 術	烹 調 學	
烹 龍 炮 鳳	焉 用	焉 有	焉 知	焉 能	焉 得	焉 敢	焊 口	
焊 工	焊 合	焊 牢	焊 料	焊 接	焊 接 工	焊 條	焊 絲	
焊 補	焊 槍	焊 管	焊 機	焊 錫	焊 頭	焊 縫	焊 藥	
烽 火	烽 火 連 天	烽 煙	烯 類	烯 烴	爽 口	爽 心 悅 目	爽 心 豁 目	
爽 地	爽 死 我 了	爽 利	爽 呆 了	爽 快	爽 言	爽 身 粉	爽 性	
爽 直	爽 朗	爽 氣	爽 脆	爽 然	爽 然 自 失	爽 然 若 失	牽 一 發 而 動 全 身	
牽 入	牽 力	牽 引	牽 引 力	牽 引 車	牽 引 量	牽 引 器	牽 引 機	
牽 牛	牽 牛 花	牽 合 附 會	牽 羊	牽 住	牽 伸	牽 扯	牽 車	
牽 制	牽 制 性	牽 拌	牽 涉	牽 涉 面	牽 起	牽 動	牽 帶	
牽 強	牽 強 附 會	牽 掛	牽 累	牽 連	牽 就	牽 掣	牽 腸 掛 肚	
牽 腸 割 肚	牽 線	牽 線 搭 橋	牽 頭	牽 蘿 補 屋	犁 牛	犁 田	犁 地	
犁 杖	犁 庭 掃 穴	犁 庭 掃 閭	犁 耕	犁 溝	犁 壁	犁 頭	犁 鏵	
猜 中	猜 出	猜 忌	猜 到	猜 度	猜 拳	猜 拳 行 令	猜 得 對	
猜 猜	猜 測	猜 嫌	猜 想	猜 遊 戲	猜 對	猜 疑	猜 獎	
猜 錯	猜 謎	猛 力	猛 士	猛 子	猛 干	猛 不 防	猛 升	
猛 火	猛 犬	猛 可	猛 打	猛 吃	猛 地	猛 吸	猛 扭	
猛 抓	猛 攻	猛 身	猛 使	猛 刺	猛 性	猛 拉	猛 拋	
猛 拐	猛 拍	猛 抬	猛 虎	猛 勁	猛 咬	猛 按	猛 拽	
猛 炸	猛 砍	猛 降	猛 射	猛 烈	猛 追	猛 酒	猛 將	
猛 推	猛 揍	猛 然	猛 然 間	猛 跌	猛 進	猛 禽	猛 落	
猛 奪	猛 敲	猛 漢	猛 漲	猛 增	猛 撞	猛 撲	猛 衝	
猛 衝 者	猛 醒	猛 擊	猛 擊 一 掌	猛 戳	猛 擲	猛 擺	猛 獸	
猛 襲	猖 狂	猖 獗	猙 獰	猙 獰 面 目	率 土 之 濱	率 土 同 慶	率 土 宅 心	
率 土 歸 心	率 以 為 常	率 由 舊 則	率 由 舊 章	率 先	率 兵	率 性 任 意	率 直	
率 師	率 真	率 馬 以 驥	率 部	率 隊	率 爾 成 章	率 爾 操 觚	率 領	
率 獸 食 人	琅 琅	琅 琅 上 口	琅 琊	琅 質	球 中	球 內	球 心	
球 手	球 王	球 半 徑	球 台	球 外	球 局	球 形	球 技	
球 拍	球 果	球 狀	球 狀 物	球 狀 體	球 門	球 星	球 架	
球 衫	球 面	球 面 幾 何	球 員	球 員 卡	球 徑 計	球 迷	球 區	
球 桿	球 莖	球 蛋 白	球 速	球 場	球 晶	球 棒	球 菌	
球 隊	球 腱	球 路	球 運	球 種	球 網	球 閥	球 鞋	
球 墨 鑄 鐵	球 壇	球 戲	球 膽	球 賽	球 蟲	球 藝	球 類	
球 類 比 賽	球 類 運 動	球 癮	球 體	理 人	理 工	理 工 科	理 不 忘 亂	
理 不 勝 詞	理 化	理 出	理 由	理 光	理 自	理 事	理 事 長	
理 事 會	理 固 當 然	理 屈	理 屈 事 窮	理 屈 詞 窮	理 念	理 性	理 性 認 識	
理 所 不 容	理 所 當 然	理 所 應 當	理 直 氣 壯	理 則 學	理 科	理 容	理 容 中 心	
理 紛 解 結	理 財	理 財 家	理 清	理 喻	理 智	理 發	理 發 店	
理 發 師	理 發 廳	理 短	理 隆 纖 維	理 順	理 想	理 想 化	理 想 主 義	
理 想 美	理 想 家	理 想 國	理 會	理 當	理 睬	理 解	理 解 力	
理 該	理 過	理 過 其 辭	理 監 事 改 選	理 論	理 論 上	理 論 工 作 者	理 論 化	
理 論 依 據	理 論 指 導	理 論 派	理 論 界	理 論 研 究	理 論 家	理 論 問 題	理 論 基 礎	
理 論 聯 繫 實 際	理 論 體 系	理 學	理 學 士	理 應	理 療	理 虧	現 下	
現 已	現 予	現 今	現 世	現 世 現 報	現 以	現 代	現 代 人	
現 代 五 項	現 代 化	現 代 史	現 代 式	現 代 性	現 代 派	現 代 感	現 代 戰 爭	
現 代 戲	現 出	現 正	現 用	現 任	現 地	現 在	現 存	
現 年	現 成	現 有	現 有 人 口	現 有 企 業	現 行	現 行 犯	現 行 制 度	
現 行 政 策	現 行 標 準	現 住 者	現 形	現 役	現 役 軍 人	現 身	現 身 說 法	
現 居	現 房	現 法	現 況	現 物	現 狀	現 金	現 金 股 利	
現 金 結 算	現 金 增 資	現 型	現 政 府	現 為	現 值	現 時	現 笑 容	
現 寄	現 將	現 率	現 眼	現 貨	現 貨 供 應	現 喜 色	現 場	
現 場 會	現 就	現 期	現 款	現 象	現 象 學	現 買	現 進	
現 鈔	現 階 段	現 飯	現 匯	現 經	現 像	現 實	現 實 主 義	
現 實 性	現 實 意 義	現 說	現 價	現 賣	現 錢	現 購	現 職	
現 饕	瓶 口	瓶 子	瓶 中	瓶 內	瓶 沉 簪 折	瓶 底	瓶 帽	
瓶 塞	瓶 裝	瓶 蓋	瓶 嘴	瓶 墜 簪 折	瓶 頸	瓶 膽	瓶 罐	
瓷 土	瓷 片	瓷 件	瓷 缸	瓷 偶	瓷 瓶	瓷 畫	瓷 窖	
瓷 碗	瓷 釉	瓷 實	瓷 漆	瓷 盤	瓷 窯	瓷 器	瓷 磚	
瓷 雕	甜 心	甜 水	甜 瓜	甜 瓜 類	甜 如 蜜	甜 言	甜 言 花 言	
甜 言 美 語	甜 言 軟 語	甜 言 媚 語	甜 言 蜜 語	甜 味	甜 的	甜 津 津	甜 美	
甜 面 醬	甜 食	甜 香	甜 料	甜 烈 酒	甜 笑	甜 酒	甜 甜 圈	
甜 甜 蜜 蜜	甜 棗	甜 椒	甜 滋 滋	甜 菜	甜 葉 菊	甜 蜜	甜 辣	
甜 酸	甜 酸 苦 辣	甜 餅	甜 嘴 蜜 舌	甜 潤	甜 調	甜 橙	甜 頭	
甜 點	甜 醬	產 士	產 中	產 仔	產 出	產 出 率	產 奶	
產 生	產 生 了	產 生 中	產 地	產 自	產 卵	產 卵 洄 游	產 床	
產 車	產 乳	產 供	產 供 銷	產 兒	產 制	產 房	產 於	
產 油	產 油 國	產 物	產 金	產 門	產 前	產 品	產 品 稅	
產 後	產 後 期	產 科	產 科 學	產 科 醫 生	產 科 醫 師	產 值	產 能	
產 假	產 區	產 婦	產 婆	產 術	產 麥	產 期	產 量	
產 業	產 業 化	產 業 升 級	產 業 界	產 業 軍	產 業 革 命	產 鉗	產 銷	
產 銷 者	產 銷 量	產 學 合 作	產 褥	產 褥 期	產 褥 熱	產 糧	產 糧 區	
產 額	產 籍	產 權	略 上	略 大	略 小	略 少	略 加	
略 去	略 可	略 白	略 示	略 先	略 同	略 地 攻 城	略 地 侵 城	
略 好	略 字	略 有	略 有 結 余	略 作	略 見	略 見 一 斑	略 底	
略 知	略 知 一 二	略 知 皮 毛	略 表	略 近	略 長	略 後	略 施	
略 為	略 看	略 述	略 記	略 高	略 高 一 籌	略 高 於	略 帶	
略 異	略 粗	略 勝	略 勝 一 籌	略 提	略 等	略 嫌	略 微	
略 跡 原 情	略 過	略 圖	略 慢	略 稱	略 語	略 說	略 輕	
略 遠	略 遜	略 寬	略 論	略 錄	略 懂	略 識 之 無	略 讀	
略 讀 者	略 顯	畦 田	畦 灌	畢 了 業	畢 力 同 心	畢 生	畢 其 功 於 一 役	
畢 恭 畢 敬	畢 竟	畢 業	畢 業 分 配	畢 業 文 憑	畢 業 生	畢 業 考 試	畢 業 典 禮	
畢 業 後	畢 業 班	畢 業 設 計	畢 業 論 文	畢 業 證 書	畢 露	異 人	異 口 同 音	
異 口 同 聲	異 口 同 辭	異 口 同 韻	異 己	異 才	異 元	異 化	異 心	
異 日	異 木 奇 花	異 父	異 乎	異 乎 尋 常	異 卉 奇 花	異 外	異 母	
異 同	異 名	異 地	異 地 相 逢	異 曲	異 曲 同 工	異 色	異 位	
異 形	異 步	異 見	異 言	異 邦	異 味	異 性	異 性 交 往	
異 性 體	異 或	異 於	異 服	異 物	異 狀	異 花	異 俗	
異 型	異 政 殊 俗	異 派 同 源	異 相	異 胎 同 岑	異 軍	異 軍 突 起	異 軍 特 起	
異 音	異 食	異 香	異 香 異 氣	異 香 撲 鼻	異 時	異 動	異 國	
異 國 風 光	異 國 情 趣	異 域	異 常	異 彩	異 教	異 教 者	異 教 徒	
異 族	異 處	異 途	異 途 同 歸	異 象	異 鄉	異 鄉 人	異 項	
異 意	異 想	異 想 天 開	異 義	異 路 同 歸	異 態	異 構	異 構 體	
異 種	異 端	異 端 邪 說	異 聞 傳 說	異 語	異 說	異 數	異 樣	
異 質	異 質 化	異 趣	異 聲	異 點	異 類	異 寶 奇 珍	異 議	
異 體	疏 了	疏 才 仗 義	疏 不 間 親	疏 不 謀 親	疏 水	疏 水 簞 瓢	疏 失	
疏 定	疏 忽	疏 忽 大 意	疏 於	疏 食 飲 水	疏 浚	疏 財 尚 氣	疏 財 重 義	
疏 密	疏 通	疏 備	疏 散	疏 落	疏 解	疏 慵 愚 鈍	疏 漏	
疏 遠	疏 學	疏 導	疏 謀 少 略	疏 縫	疏 闊	疏 離	疏 鬆	
疏 懶	疏 證	疏 宕 不 拘	痔 疾	痔 漏	痔 瘡	痕 跡	疵 瑕	
疵 點	疵 謬	疵 議	痊 癒	皎 月	皎 皎	皎 潔	盔 甲	
盔 甲 上	盒 子	盒 中	盒 尺	盒 式	盒 帶	盒 飯	盒 裝	
盛 入	盛 不 忘 衰	盛 水	盛 水 不 漏	盛 世	盛 必 慮 衰	盛 名	盛 名 之 下 其 實 難 副	
盛 名 難 副	盛 在	盛 年	盛 行	盛 事	盛 典	盛 放	盛 明	
盛 服	盛 況	盛 況 空 前	盛 怒	盛 食 厲 兵	盛 唐	盛 夏	盛 宴	
盛 時	盛 氣	盛 氣 凌 人	盛 氣 臨 人	盛 衰	盛 衰 利 寒	盛 衰 相 乘	盛 衰 榮 辱	
盛 衰 興 廢	盛 得 遺 范	盛 情	盛 情 款 待	盛 情 難 卻	盛 產	盛 暑	盛 暑 祈 寒	
盛 期	盛 開	盛 開 過	盛 飯	盛 傳	盛 勢	盛 意	盛 會	
盛 極	盛 極 一 時	盛 裝	盛 達	盛 達 電 業	盛 筵 必 散	盛 筵 易 散	盛 筵 難 再	
盛 德 不 泯	盛 餘 鋼 鐵	盛 器	盛 舉	盛 譽	盛 觀	盛 讚	眷 本	
眷 村	眷 念	眷 眷	眷 眷 之 心	眷 屬	眷 顧	眷 戀	眾 人	
眾 人 拾 柴 火 焰 高	眾 口	眾 口 一 詞	眾 口 交 攻	眾 口 交 薦	眾 口 同 聲	眾 口 紛 紜	眾 口 爍 金	
眾 口 難 調	眾 口 鑠 金	眾 口 熏 天	眾 女	眾 川 赴 海	眾 少 不 敵	眾 少 成 多	眾 心 成 城	
眾 心 拱 辰	眾 毛 攢 裘	眾 生	眾 目	眾 目 共 視	眾 目 共 睹	眾 目 具 瞻	眾 目 所 歸	
眾 目 昭 彰	眾 目 睽 睽	眾 矢 之 的	眾 多	眾 如 水 火	眾 位	眾 志 成 城	眾 走	
眾 取	眾 所	眾 所 周 知	眾 所 曙 目	眾 所 瞻 望	眾 所 矚 目	眾 盲 摸 象	眾 虎 同 心	
眾 叛 親 離	眾 怒	眾 怒 難 犯	眾 怒 難 任	眾 星	眾 星 拱 北	眾 星 捧 月	眾 神	
眾 神 廟	眾 院	眾 國	眾 望	眾 望 有 歸	眾 望 攸 歸	眾 望 所 依	眾 望 所 積	
眾 望 所 歸	眾 散 親 離	眾 毀 所 歸	眾 路	眾 寡 不 敵	眾 寡 莫 敵	眾 寡 勢 殊	眾 寡 難 敵	
眾 寡 懸 殊	眾 語	眾 說	眾 說 紛 紜	眾 謀	眾 擎 易 舉	眾 議	眾 議 成 林	
眾 議 員	眾 議 院	眼 力	眼 力 好	眼 下	眼 不 見 心 不 煩	眼 不 見 為 淨	眼 中	
眼 中 刺	眼 中 釘	眼 中 釘 肉 中 刺	眼 中 疔 肉 中 刺	眼 內 無 珠	眼 孔	眼 巴 巴	眼 水	
眼 去 眉 來	眼 生	眼 白	眼 皮	眼 目	眼 光	眼 光 敏 銳	眼 光 淺	
眼 光 短 淺	眼 光 遠 大	眼 尖	眼 色	眼 低	眼 形	眼 快	眼 見	
眼 見 為 實	眼 見 得	眼 角	眼 兒	眼 底	眼 明	眼 明 手 快	眼 明 手 捷	
眼 波	眼 狀 物	眼 空 四 海	眼 花	眼 花 耳 熱	眼 花 雀 亂	眼 花 撩 亂	眼 花 潦 亂	
眼 花 繚 亂	眼 亮	眼 前	眼 前 利 益	眼 屎	眼 界	眼 看	眼 看 著	
眼 科	眼 科 學	眼 穿 腸 斷	眼 紅	眼 旁	眼 珠	眼 珠 子	眼 疾	
眼 疾 手 快	眼 病	眼 疲 勞	眼 神	眼 笑	眼 高 手 低	眼 圈	眼 梢	
眼 液	眼 淚	眼 淚 洗 面	眼 球	眼 眶	眼 眸	眼 袋	眼 部	
眼 暈	眼 睛	眼 睛 尖	眼 睫 毛	眼 睜 睜	眼 罩	眼 裡	眼 跳	
眼 福	眼 窩	眼 窩 上	眼 網 膜	眼 影	眼 熟	眼 熱	眼 瞎	
眼 線	眼 線 膏	眼 壓	眼 瞼	眼 簾	眼 藥	眼 藥 水	眼 鏡	
眼 鏡 蛇	眼 鏡 堡	眼 鏡 腿	眼 觀	眼 觀 六 路 耳 聽 八 方	眼 觀 四 處 耳 聽 八 方	眼 饞	眼 饞 肚 飽	
眼 瞅	眸 子	眺 望	眺 遠	硫 分	硫 化	硫 化 汞	硫 化 物	
硫 化 氫	硫 化 鈉	硫 化 鉛	硫 化 碳	硫 化 鋅	硫 化 鐵	硫 化 鹼	硫 粉	
硫 黃	硫 酸	硫 酸 亞 鐵	硫 酸 鈣	硫 酸 鈉	硫 酸 鉀	硫 酸 銅	硫 酸 銨	
硫 酸 鋅	硫 酸 鋁	硫 酸 鋇	硫 酸 鎂	硫 酸 鐵	硫 酸 鹽	硫 醇	硫 磺	
硫 磺 色	硫 磺 般	硫 鐵 礦	硫 胺 素	硃 砂	祥 和	祥 林	祥 物	
祥 春	祥 符	祥 雲	祥 雲 瑞 氣	祥 雲 瑞 彩	祥 瑞	祥 補	祥 裕 電 子	
祥 麟 威 鳳	祥 麟 瑞 鳳	票 人	票 口	票 子	票 友	票 式	票 夾	
票 具	票 券	票 券 公 司	票 房	票 面	票 員	票 根	票 莊	
票 販 子	票 單	票 款	票 匯	票 源	票 號	票 價	票 價 調 整	
票 數	票 樣	票 箱	票 據	票 據 交 換 所	票 據 簿	票 選	票 選 黨 代 表	
票 頭	票 戲	票 額	票 簿	票 簽	票 證	祭 天	祭 文	
祭 日	祭 司	祭 司 席	祭 地	祭 位	祭 告	祭 灶	祭 典	
祭 服	祭 物	祭 祀	祭 品	祭 拜	祭 祖	祭 神	祭 神 如 神 在	
祭 酒	祭 掃	祭 奠	祭 墓	祭 儀	祭 器	祭 壇	祭 禮	
移 了	移 入	移 山	移 山 倒 海	移 山 添 海	移 天 易 日	移 天 徙 日	移 出	
移 去	移 民	移 民 政 策	移 用	移 交	移 伙	移 向	移 有 足 無	
移 至	移 位	移 作	移 孝 為 忠	移 步	移 走	移 防	移 來	
移 到	移 居	移 居 者	移 往	移 性	移 東 就 西	移 東 換 西	移 東 補 西	
移 花 接 木	移 近	移 星 換 斗	移 苗	移 軍	移 風 易 俗	移 值 體	移 宮 換 羽	
移 師	移 挪	移 栽	移 送	移 動	移 動 式	移 情	移 掉	
移 液 管	移 移	移 棲	移 植	移 植 手 術	移 植 法	移 開	移 項	
移 置	移 過	移 樽 就 教	移 歸	移 轉	移 靈	窒 息	窒 悶	
窒 礙	笠 草	笨 人	笨 口 拙 舌	笨 手 笨 腳	笨 瓜	笨 死	笨 拙	
笨 拙 不 雅	笨 的	笨 重	笨 笨	笨 蛋	笨 貨	笨 鳥 先 飛	笨 嘴 拙 舌	
笨 嘴 笨 舌	笨 頭 笨 腦	笨 舉	笨 驢	笛 子	笛 手	笛 卡 兒	笛 曲	
笛 膜	笛 聲	第 ４ 台	第 一	第 一 人 稱	第 一 千	第 一 天	第 一 手	
第 一 手 材 料	第 一 名	第 一 年	第 一 次	第 一 次 世 界 大 戰	第 一 百	第 一 百 萬	第 一 位	
第 一 把 手	第 一 步	第 一 季 度	第 一 屆	第 一 流	第 一 個	第 一 書 記	第 一 國 際	
第 一 章	第 一 飯 店	第 一 路 軍	第 一 銀 行	第 一 銅 鐵	第 一 線	第 一 輪	第 一 勸 業 銀 行	
第 七	第 七 十	第 七 年	第 七 音	第 七 商 銀	第 九	第 九 十	第 九 年	
第 二	第 二 十	第 二 天	第 二 手	第 二 日	第 二 世 界	第 二 名	第 二 年	
第 二 次	第 二 次 世 界 界 大 戰	第 二 位	第 二 把 手	第 二 批	第 二 季 度	第 二 流	第 二 音	
第 二 個	第 二 國 際	第 二 層	第 二 線	第 八	第 八 十	第 八 年	第 八 個 五 年 計 劃	
第 十	第 十 一	第 十 一 屆	第 十 七	第 十 九	第 十 二	第 十 二 屆	第 十 八	
第 十 三	第 十 五	第 十 六	第 十 四	第 十 年	第 十 億	第 三	第 三 十	
第 三 天	第 三 方	第 三 世 界	第 三 世 界 國 家	第 三 代	第 三 名	第 三 年	第 三 次	
第 三 步	第 三 季	第 三 季 度	第 三 波	第 三 者	第 三 流	第 三 級	第 三 國	
第 三 梯 隊	第 三 產 業	第 三 等	第 五	第 五 十	第 五 名	第 五 年	第 五 號 交 響 曲	
第 五 縱 隊	第 六	第 六 十	第 六 年	第 六 個	第 四	第 四 十	第 四 台	
第 四 名	第 四 年	第 四 卷	第 四 季	第 四 季 度	第 幾	第 幾 層	符 山 石	
符 木	符 合	符 咒	符 號	符 號 化	符 號 法	符 號 為	符 號 學	
笙 歌	笙 歌 鼎 沸	笙 簫	笞 打	笞 刑	粒 大	粒 子	粒 子 束	
粒 米 束 薪	粒 米 狼 戾	粒 兒	粒 狀	粒 狀 物	粒 肥	粒 度	粒 徑	
粒 質	粒 選	粒 巖	粗 人	粗 大	粗 工	粗 中 有 細	粗 心	
粗 心 大 意	粗 心 浮 氣	粗 毛	粗 毛 羊	粗 加 工	粗 加 工 製 品	粗 布	粗 劣	
粗 而	粗 衣 淡 飯	粗 衣 �B 食	粗 壯	粗 刻	粗 呢	粗 放	粗 服 亂 頭	
粗 枝	粗 枝 大 葉	粗 長	粗 俗	粗 俗 人	粗 俗 話	粗 查	粗 活	
粗 盈 守 成	粗 盈 守 虛	粗 眉	粗 重	粗 陋	粗 面	粗 風 暴 雨	粗 氣	
粗 紡	粗 紗	粗 茶	粗 茶 淡 飯	粗 啞	粗 淺	粗 率	粗 略	
粗 疏	粗 笨	粗 粗	粗 細	粗 蛋 白 質	粗 貨	粗 通	粗 野	
粗 野 無 禮	粗 鹵	粗 麻	粗 短	粗 硬	粗 絨	粗 話	粗 飼 料	
粗 實	粗 製	粗 製 品	粗 製 濫 造	粗 豪	粗 鄙	粗 鄙 下 流	粗 暴	
粗 碾	粗 線	粗 線 條	粗 賤	粗 魯	粗 魯 無 禮	粗 篩	粗 選	
粗 糠	粗 糙	粗 縫	粗 聲	粗 聲 粗 氣	粗 獷	粗 糧	粗 繩	
粗 覽	粗 讀	粗 體	粗 體 字	絆 住	絆 倒	絆 腳	絆 腳 石	
絆 網	統 一	統 一 人 壽	統 一 口 徑	統 一 大 業	統 一 分 配	統 一 化	統 一 企 業	
統 一 性	統 一 者	統 一 思 想	統 一 祖 國	統 一 教	統 一 組 織	統 一 規 劃	統 一 超 商	
統 一 集 團	統 一 經 營	統 一 實 業	統 一 認 識	統 一 領 導	統 一 標 準	統 一 戰 線	統 一 戰 線 理 論	
統 一 證 券	統 一 體	統 分	統 分 結 合	統 化	統 支	統 由	統 共	
統 合	統 合 開 發	統 收	統 考	統 制	統 治	統 治 者	統 治 權	
統 帥	統 帥 機 構	統 帥 體 制	統 建	統 派	統 計	統 計 工 作	統 計 分 析	
統 計 局	統 計 法	統 計 表	統 計 指 標	統 計 員	統 計 理 論	統 計 處	統 計 資 料	
統 計 監 督	統 計 數 字	統 計 數 據	統 計 調 查	統 計 學	統 計 學 史	統 借	統 記	
統 配	統 帶	統 御 力	統 率	統 統	統 馭	統 靴	統 稱	
統 管	統 領	統 領 百 貨	統 稿	統 緝	統 編	統 銷	統 戰	
統 戰 部	統 操	統 艙	統 選	統 懋 半 導	統 講	統 購	統 購 統 銷	
統 轄	統 還	統 籌	統 籌 安 排	統 籌 法	統 籌 兼 顧	統 籌 學	統 覺	
統 屬	統 攬	統 觀	紮 根	紮 實	紮 緊	紮 營	紹 酒	
紹 興	紹 興 市	細 了	細 大 不 捐	細 大 不 逾	細 大 無 遺	細 小	細 工	
細 不 容 發	細 分	細 切	細 化	細 孔	細 心	細 木	細 毛	
細 毛 羊	細 水 長 流	細 巧	細 布	細 末	細 目	細 如	細 作	
細 沙	細 究	細 底	細 枝	細 枝 末 節	細 枝 狀	細 枝 條	細 的	
細 表	細 長	細 雨	細 則	細 咬	細 品	細 故	細 查	
細 流	細 活	細 看	細 砂	細 胞	細 胞 內	細 胞 核	細 胞 液	
細 胞 膜	細 胞 質	細 胞 器	細 胞 壁	細 胞 學	細 胞 體	細 述	細 音	
細 弱	細 梳	細 粉	細 紡	細 紗	細 針 密 線	細 針 密 縷	細 高	
細 動 脈	細 密	細 帳	細 情	細 條	細 條 紋	細 瓷	細 痕	
細 粒	細 細	細 軟	細 部	細 棒	細 發	細 短	細 絲	
細 絲 狀	細 絲 帶	細 菌	細 菌 狀	細 菌 學	細 菌 戰	細 菜	細 量	
細 圓	細 微	細 想	細 溝	細 碎	細 節	細 腰	細 過	
細 鉛 字	細 嫩	細 察	細 管	細 算	細 語	細 說	細 彈	
細 數	細 潤	細 緻	細 線	細 膠 團	細 談	細 齒	細 膩	
細 選	細 頸	細 縫	細 聲	細 聲 細 氣	細 糧	細 繩	細 類	
細 嚼	細 嚼 慢 咽	細 讀	細 讀 者	紳 士	紳 士 們	紳 宦	組 件	
組 合	組 合 式	組 合 音 響	組 合 圖	組 合 櫃	組 成	組 成 者	組 成 部 分	
組 曲	組 別	組 委 會	組 版	組 長	組 建	組 員	組 訓	
組 配	組 畫	組 間	組 項	組 塊	組 裝	組 團	組 歌	
組 閣	組 播	組 稿	組 織	組 織 上	組 織 化	組 織 生 活	組 織 委 員	
組 織 性	組 織 沿 革	組 織 者	組 織 活 動	組 織 紀 律	組 織 紀 律 性	組 織 原 則	組 織 液	
組 織 部	組 織 部 長	組 織 部 門	組 織 學	組 織 關 係	組 織 體 制	組 織 觀 念	累 了	
累 人	累 土 至 山	累 土 聚 沙	累 及	累 月	累 月 經 年	累 加	累 加 器	
累 犯	累 瓦 結 繩	累 年	累 次	累 死	累 死 累 活	累 卵	累 卵 之 危	
累 見 不 鮮	累 足 成 步	累 垮	累 活	累 計	累 倒	累 病	累 退	
累 得	累 得 要 死	累 教 不 改	累 鳥	累 減	累 進	累 債	累 塊 積 蘇	
累 極	累 積	累 積 者	累 贅	累 壞	累 牘	累 牘 連 篇	終 一	
終 了	終 久	終 天	終 天 之 恨	終 天 之 慕	終 天 抱 恨	終 日	終 止	
終 世 若 一	終 古	終 句	終 生	終 生 教 育	終 因	終 如	終 年	
終 成	終 曲	終 有	終 老	終 而 復 始	終 局	終 究	終 身	
終 身 大 事	終 身 伴 侶	終 身 制	終 身 學 習	終 身 職	終 其	終 夜	終 始 不 渝	
終 性	終 於	終 南 捷 徑	終 值	終 站	終 將	終 焉 之 志	終 速	
終 竟	終 場	終 結	終 結 者	終 結 部	終 須	終 會	終 極	
終 歲	終 端	終 端 設 備	終 端 機	終 審	終 篇	終 點	終 點 站	
終 歸	缽 子	缽 衣	缽 僧	羞 人	羞 人 答 答	羞 以 牛 後	羞 死	
羞 色	羞 怯	羞 花	羞 花 閉 目	羞 面 見 人	羞 容	羞 恥	羞 辱	
羞 辱 性	羞 辱 者	羞 得	羞 羞 答 答	羞 赧	羞 答 答	羞 愧	羞 慚	
羞 與 為 伍	羞 與 噲 伍	羞 憤	羞 澀	羚 牛	羚 羊	羚 羊 掛 角	翌 日	
翌 年	翌 晨	翎 毛	習 水	習 以 成 性	習 以 成 俗	習 以 成 風	習 以 為 常	
習 用	習 而 不 察	習 作	習 見	習 尚	習 性	習 非 成 是	習 非 勝 是	
習 俗	習 染	習 氣	習 常	習 得	習 習	習 慣	習 慣 了	
習 慣 上	習 慣 成 自 然	習 慣 自 然	習 慣 性	習 慣 於	習 慣 勢 力	習 與 性 成	習 題	
習 題 集	習 藝	聊 了	聊 天	聊 天 兒	聊 且	聊 以 自 慰	聊 以 卒 歲	
聊 以 塞 責	聊 以 解 嘲	聊 事	聊 表	聊 得	聊 聊	聊 勝 於 無	聊 復 爾 爾	
聊 著	聊 話	聊 賴	聊 齋	聆 訊	聆 教	聆 聽	聆 聽 會	
脖 子	脖 圍	脖 領	脖 頸	脫 了	脫 了 臼	脫 下	脫 口	
脫 口 成 章	脫 口 而 出	脫 手	脫 毛	脫 毛 用	脫 水	脫 水 器	脫 水 機	
脫 出	脫 去	脫 皮	脫 光	脫 灰	脫 臼	脫 色	脫 衣	
脫 衣 服	脫 衣 舞	脫 位	脫 肛	脫 身	脫 來	脫 兔	脫 卸	
脫 泡	脫 盲	脫 者	脫 俗	脫 垂	脫 胎	脫 胎 換 骨	脫 軌	
脫 氧	脫 氧 核 糖	脫 氧 劑	脫 脂	脫 脂 乳	脫 脂 棉	脫 逃	脫 逃 術	
脫 除	脫 掉	脫 氫	脫 產	脫 產 幹 部	脫 產 學 習	脫 硫	脫 粒	
脫 粒 機	脫 貨 求 現	脫 貧	脫 貧 致 富	脫 帽	脫 散	脫 期	脫 殼	
脫 殼 金 蟬	脫 殼 機	脫 發	脫 開	脫 節	脫 罪	脫 落	脫 落 性	
脫 鉤	脫 靴	脫 靴 器	脫 漏	脫 盡	脫 碳	脫 網	脫 模	
脫 稿	脫 膠	脫 銷	脫 鞋	脫 機	脫 穎	脫 穎 而 出	脫 褲	
脫 險	脫 檔	脫 離	脫 離 危 險	脫 離 者	脫 離 群 眾	脫 離 實 際	脫 黨	
脫 韁	脫 韁 之 馬	脫 鹽	脫 坯	舵 工	舵 手	舵 手 室	舵 主	
舵 桿	舵 輪	舷 材	舷 側	舷 梯	舷 窗	舷 窗 蓋	舷 燈	
舶 位	舶 來 品	船 下	船 上	船 工	船 中	船 內	船 友	
船 夫	船 戶	船 支	船 主	船 台	船 外	船 民	船 名	
船 吃	船 帆	船 位	船 尾	船 床	船 形	船 材	船 身	
船 到 江 心 補 漏 遲	船 到 橋 門 自 會 直	船 底	船 東	船 板	船 狀	船 者	船 長	
船 室	船 客	船 政 局	船 首	船 首 艙	船 員	船 員 們	船 家	
船 桅	船 索	船 級	船 隻	船 側	船 務	船 埠	船 票	
船 舷	船 舶	船 期	船 殼	船 隊	船 塢	船 腹	船 艇	
船 艇 勤 務	船 載	船 運	船 閘	船 歌	船 廠	船 模	船 槳	
船 樑	船 漿	船 艙	船 錢	船 頭	船 幫	船 邊	船 難	
船 籍	船 齡	船 體	莎 士 比 亞	莎 朗 史 東	莎 瑪 海 雅 克	莞 熊	莞 爾	
莘 莘	荸 薺	莢 果	莢 膜	莢 蓬	莖 柄	莖 幹	莽 原	
莽 莽	莽 漢	莽 撞	莫 入	莫 三 比 克	莫 大	莫 不	莫 不 如 此	
莫 不 是	莫 之 能 御	莫 予 毒 也	莫 內	莫 及	莫 扎 特	莫 可	莫 可 名 狀	
莫 可 奈 何	莫 札 特	莫 名	莫 名 其 妙	莫 如	莫 此 為 甚	莫 希	莫 忘	
莫 亞	莫 怪	莫 明 其 妙	莫 知 所 措	莫 知 所 謂	莫 知 與 京	莫 非	莫 為	
莫 若	莫 展 一 籌	莫 桑 比 克	莫 能	莫 衷 一 是	莫 逆	莫 逆 之 友	莫 逆 之 交	
莫 高	莫 高 石 窟	莫 高 窟	莫 措 手 足	莫 理	莫 敢 誰 何	莫 斯 科	莫 測	
莫 測 高 深	莫 菲	莫 須	莫 須 有	莫 道	莫 過	莫 過 如 此	莫 過 於	
莫 寧	莫 管	莫 管 他 家 瓦 上 霜	莫 說	莫 撒 謊	莫 敵	莫 辨 楮 葉	莫 讓	
莒 光 號	莊 子	莊 戶	莊 主	莊 周 夢 蝶	莊 重	莊 員	莊 家	
莊 園	莊 園 主	莊 稼	莊 稼 人	莊 稼 地	莊 稼 院	莊 稼 漢	莊 嚴	
莉 莉	莠 草	荷 包	荷 花	荷 重	荷 馬	荷 塘	荷 腦	
荷 葉	荷 載	荷 槍 實 彈	荷 爾 蒙	荷 蘭	荷 蘭 人	荷 蘭 語	荷 蘭 銀 行	
荼 毒	荼 毒 生 靈	莆 田	莧 菜	處 女	處 女 地	處 女 似	處 女 作	
處 女 座	處 女 膜	處 之	處 之 泰 然	處 分	處 心 積 慮	處 方	處 世	
處 世 態 度	處 以	處 刑	處 在	處 安 思 危	處 死	處 死 刑	處 決	
處 私 刑	處 身	處 事	處 所	處 於	處 於 領 先 地 位	處 於 優 勢	處 治	
處 長	處 室	處 級	處 斬	處 理	處 理 不 當	處 理 系 統	處 理 者	
處 理 品	處 理 問 題	處 理 意 見	處 理 器	處 理 機	處 處	處 暑	處 絞 刑	
處 置	處 境	處 罰	處 罰 者	處 罰 金	彪 形	彪 形 大 漢	彪 炳 千 古	
蛇 一 般	蛇 口	蛇 心 佛 口	蛇 皮	蛇 年	蛇 行	蛇 尾	蛇 形	
蛇 性	蛇 咬 傷	蛇 神 牛 鬼	蛇 紋 石	蛇 崇 拜	蛇 蛻 皮	蛇 鼠 橫 行	蛇 蜥	
蛇 樣	蛇 頸	蛇 頭	蛇 膽	蛇 蠍	蛇 類	蛀 孔	蛀 牙	
蛀 洞	蛀 食	蛀 船 蟲	蛀 蝕	蛀 齒	蛀 蟲	蛀 壞	蛋 奶	
蛋 白	蛋 白 □	蛋 白 質	蛋 形	蛋 卷	蛋 花	蛋 青	蛋 品	
蛋 清	蛋 殼	蛋 黃	蛋 黃 素	蛋 製 品	蛋 餅	蛋 撻	蛋 糕	
蛋 雞	蛋 類	蚱 蜢	蚯 蚓	術 前	術 後	術 語	術 語 表	
術 語 學	袞 袞 諸 公	袈 裟	被 人	被 上 訴 人	被 子	被 子 植 物	被 山 帶 河	
被 支 撐 著	被 以	被 他	被 加 數	被 召	被 用	被 甲 枕 戈	被 甲 執 兵	
被 任 命 者	被 她	被 扣	被 扣 押 人	被 收 容 者	被 估	被 佔	被 佔 領 土	
被 判	被 判 死 刑	被 劫	被 告	被 告 人	被 告 席	被 困	被 夾	
被 弄	被 忘	被 投 訴	被 步 後 塵	被 災 蒙 禍	被 刺	被 往 情 深	被 征	
被 忽 略 了	被 承 認 了	被 拒 之 於 門 外	被 拋 棄 了	被 拘 留 者	被 放 逐 者	被 服	被 侵 略 者	
被 保 險 人	被 保 證 人	被 俘	被 指	被 指 名 人	被 施 魔 法	被 流 放 者	被 虐 待 狂	
被 迫	被 限 定 了	被 面	被 風	被 乘 數	被 凍	被 剔 除 者	被 剝	
被 剝 削	被 剝 削 階 級	被 套	被 害	被 害 人	被 害 者	被 捕	被 除 數	
被 動	被 動 元 件	被 動 式	被 動 局 面	被 動 原 件	被 問	被 堅 執 銳	被 控	
被 接 見 者	被 推 薦 者	被 授	被 救 濟 者	被 棄	被 殺	被 清 除 者	被 淹	
被 統 治 者	被 逐	被 逐 出 者	被 單	被 提 名 者	被 提 起	被 減 數	被 發 文 身	
被 發 左 衽	被 發 佯 狂	被 發 射	被 發 徒 跣	被 發 現	被 發 陽 狂	被 發 詳 狂	被 發 纓 冠	
被 發 拊 膺	被 盜	被 絮	被 評 為	被 開 方 數	被 雇	被 想 到	被 愛	
被 搞	被 罩	被 裝	被 裡	被 解 散 了	被 逼	被 監 護 人	被 稱 為	
被 窩	被 罰	被 認 為	被 領 導 者	被 膜	被 褐 懷 玉	被 褐 懷 珠	被 擁 抱 者	
被 澤 蒙 庥	被 瞞	被 褥	被 選	被 選 為	被 選 舉 權	被 遺 棄 者	被 錄 取 者	
被 頭	被 嚇	被 壓 迫	被 邀 請 者	被 覆	被 寵 若 驚	被 關	被 繼 承 人	
被 議	被 譽 為	被 驅 逐 者	被 竊	袒 胸	袒 胸 露 背	袒 胸 露 腹	袒 胸 露 臂	
袒 護	袒 露	袒 裼 裸 裎	袖 上	袖 口	袖 子	袖 孔	袖 手	
袖 手 旁 觀	袖 手 傍 觀	袖 扣	袖 珍	袖 珍 本	袖 珍 型	袖 套	袖 章	
袖 短	袖 筒	袖 管	袖 頭	袍 子	袍 哥	袍 澤	袍 笏 登 場	
袋 口	袋 子	袋 中	袋 內	袋 形	袋 狀	袋 裝	袋 裡	
袋 鼠	袋 熊	袋 類	覓 衣 求 食	覓 柳 尋 花	覓 食	覓 得	覓 愛 追 歡	
覓 寶	規 示	規 行 矩 上	規 行 矩 步	規 言 矩 步	規 定	規 定 了	規 定 者	
規 定 動 作	規 念 落 後	規 則	規 則 化	規 則 性	規 勉	規 律	規 律 性	
規 派	規 約	規 重 矩 疊	規 格	規 格 化	規 矩	規 矩 準 繩	規 矩 鉤 繩	
規 矩 繩 墨	規 退	規 條	規 規 矩 矩	規 章	規 章 制 度	規 程	規 費	
規 距 儀	規 劃	規 劃 論	規 模	規 範	規 範 化	規 範 性	規 整	
規 避	規 勸	規 圜 矩 方	訪 人	訪 友	訪 日	訪 求	訪 法	
訪 者	訪 客	訪 查	訪 美	訪 英	訪 問	訪 問 者	訪 問 記	
訪 問 期 間	訪 問 團	訪 問 演 出	訪 問 學 者	訪 華	訪 華 報 告	訪 華 團	訪 德	
訪 親	訪 錄	訪 蘇	訣 別	訣 要	訣 竅	許 下	許 久	
許 文 龍	許 仙	許 可	許 可 證	許 多	許 多 人	許 多 工 作	許 多 方 面	
許 多 水	許 信 良	許 是	許 配	許 許 多 多	許 景 淳	許 給	許 銘 傑	
許 鞍 華	許 諾	許 願	設 下	設 以	設 卡	設 立	設 伏	
設 在	設 有	設 坎	設 局	設 言 托 意	設 身 處 地	設 防	設 來	
設 定	設 定 區	設 拉 子	設 於	設 法	設 法 者	設 施	設 為	
設 計	設 計 所	設 計 者	設 計 員	設 計 家	設 計 師	設 計 院	設 計 理 論	
設 計 圖	設 計 說 明	設 計 機 構	設 限	設 埋 伏	設 宴	設 圈 套	設 崗	
設 帳	設 張 舉 措	設 陷 井	設 備	設 備 普 查	設 備 管 理	設 備 廠	設 想	
設 置	設 置 障 礙	設 路 障	設 廠	設 營	設 點	設 題	設 關	
訟 事	訟 爭	訟 者	訟 詞	訛 言 惑 眾	訛 言 謊 語	訛 詐	訛 傳	
訛 誤	豚 鼠	販 子	販 夫 走 卒	販 夫 俗 子	販 奴	販 私	販 官 鬻 爵	
販 毒	販 毒 分 子	販 毒 案	販 毒 集 團	販 運	販 賣	販 賣 者	責 己	
責 令	責 打	責 任	責 任 人	責 任 心	責 任 田	責 任 事 故	責 任 制	
責 任 書	責 任 區	責 任 感	責 成	責 怪	責 重 山 嶽	責 躬 省 過	責 問	
責 備	責 備 似	責 無 旁 貸	責 實 循 名	責 罰	責 罵	責 難	責 難 似	
貫 入	貫 犯	貫 朽 粟 紅	貫 朽 粟 腐	貫 耳	貫 串	貫 例	貫 注	
貫 穿	貫 穿 今 古	貫 穿 馳 騁	貫 通	貫 通 一 氣	貫 魚 之 次	貫 魚 承 寵	貫 徹	
貫 徹 執 行	貫 頤 奮 戟	貫 竊	貨 比 三 家	貨 主	貨 名	貨 色	貨 位	
貨 車	貨 到	貨 物	貨 物 周 轉 量	貨 物 稅	貨 亭	貨 品	貨 架	
貨 郎	貨 倉	貨 員	貨 真 價 實	貨 站	貨 商	貨 票	貨 船	
貨 單	貨 場	貨 棧	貨 棚	貨 款	貨 源	貨 源 充 足	貨 號	
貨 賄 公 行	貨 賂 公 行	貨 運	貨 運 站	貨 幣	貨 幣 回 籠	貨 幣 供 給	貨 幣 政 策	
貨 幣 流 通	貨 幣 貶 值	貨 幣 學	貨 種	貨 價	貨 樣	貨 箱	貨 輪	
貨 機	貨 艙	貨 櫃	貨 櫃 化	貨 櫃 船	貨 櫃 碼 頭	貨 攤	貨 垛	
貨 舖	貪 口 福	貪 大	貪 大 求 全	貪 小	貪 小 失 大	貪 小 便 宜	貪 天 之 功	
貪 天 之 功 為 己 有	貪 夫 徇 財	貪 心	貪 心 不 足	貪 心 妄 想	貪 心 者	貪 心 無 厭	貪 占	
貪 生	貪 生 怕 死	貪 生 畏 死	貪 生 害 義	貪 生 捨 義	貪 生 惡 死	貪 吏 猾 胥	貪 名 逐 利	
貪 名 圖 利	貪 吃	貪 吃 懶 做	貪 多	貪 多 務 得	貪 多 嚼 不 爛	貪 污	貪 污 分 子	
貪 污 犯	貪 污 受 賄	貪 污 盜 竊	貪 污 罪	貪 污 腐 化	貪 而 無 信	貪 色	貪 位 取 容	
貪 位 慕 祿	貪 利	貪 求	貪 求 無 已	貪 求 無 厭	貪 官	貪 官 污 吏	貪 官 蠹 役	
貪 杯	貪 玩	貪 者	貪 花 戀 酒	貪 便 宜	貪 冒 榮 寵	貪 狠	貪 看	
貪 食	貪 財	貪 財 好 色	貪 財 好 賄	貪 財 圖 利	貪 財 慕 勢	貪 酒	貪 婪	
貪 婪 無 厭	貪 得	貪 得 無 厭	貪 猥 無 厭	貪 賄 無 藝	貪 圖	貪 圖 安 逸	貪 圖 享 受	
貪 榮 冒 寵	貪 榮 慕 利	貪 睡	貪 睡 者	貪 鄙	貪 嘴	貪 嘴 人	貪 慾	
貪 慾 無 藝	貪 墨 之 風	貪 墨 敗 度	貪 錢	貪 聲 逐 色	貪 瀆	貪 贓	貪 贓 枉 法	
貪 贓 壞 法	貪 權 慕 祿	貪 權 竊 柄	貪 戀	貧 下	貧 下 中 農	貧 戶	貧 乏	
貧 民	貧 民 院	貧 民 區	貧 民 窟	貧 而 無 諂	貧 血	貧 血 症	貧 困	
貧 困 戶	貧 困 地 區	貧 困 線	貧 困 縣	貧 油	貧 苦	貧 弱	貧 病	
貧 病 交 加	貧 病 交 攻	貧 病 交 迫	貧 國	貧 寒	貧 富	貧 富 懸 殊	貧 無 立 錐	
貧 農	貧 道	貧 僧	貧 嘴	貧 嘴 賤 舌	貧 嘴 薄 舌	貧 瘠	貧 窮	
貧 窮 落 後	貧 賤	貧 賤 不 能 移	貧 賤 之 交	貧 賤 糟 糠	貧 賤 驕 人	貧 礦	赧 然	
赧 顏 汗 下	赦 令	赦 免	赦 罪	赦 過 宥 罪	趾 甲	趾 尖	趾 行 類	
趾 骨	趾 高 氣 揚	趾 頭	趺 坐	軟 □	軟 了	軟 刀	軟 化	
軟 化 劑	軟 尺	軟 木	軟 木 材	軟 木 斛	軟 木 塞	軟 毛	軟 水	
軟 片	軟 片 盒	軟 包 裝	軟 叭 叭	軟 布	軟 玉 溫 香	軟 玉 嬌 香	軟 皮	
軟 件	軟 件 包	軟 件 技 術	軟 任 務	軟 自 由	軟 床	軟 材	軟 皂	
軟 和	軟 呢 帽	軟 性	軟 板	軟 泥	軟 臥	軟 指 標	軟 科 學	
軟 革	軟 食	軟 香 溫 玉	軟 凍	軟 席	軟 座	軟 弱	軟 弱 性	
軟 弱 渙 散	軟 弱 無 力	軟 弱 無 能	軟 脂 酸	軟 骨	軟 骨 病	軟 骨 魚 類	軟 骨 輪	
軟 骨 頭	軟 梯	軟 軟	軟 帽	軟 殼	軟 硬	軟 硬 兼 施	軟 著 陸	
軟 飯	軟 禁	軟 腳 病	軟 腫	軟 墊	軟 磁 盤	軟 碟	軟 碟 機	
軟 管	軟 綢	軟 綿 綿	軟 膏	軟 語	軟 盤	軟 盤 片	軟 箱	
軟 緞	軟 調	軟 磨	軟 磨 硬 泡	軟 糖	軟 鋼	軟 瀝 青	軟 驅	
軟 體	軟 體 股	這 一	這 一 下	這 一 次	這 一 來	這 一 招	這 一 點	
這 一 類	這 人	這 下	這 大	這 山 望 著 那 山 高	這 太	這 支	這 以 後	
這 他	這 可	這 句	這 句 話	這 本	這 件	這 份	這 名	
這 回	這 有	這 次	這 死	這 位	這 你	這 把	這 批	
這 步	這 身	這 些	這 些 年	這 些 年 來	這 使	這 兒	這 招	
這 杯	這 股	這 則	這 娃	這 封	這 架	這 段	這 個	
這 個 月	這 個 時 候	這 套	這 家	這 座	這 時	這 時 候	這 真	
這 般	這 副	這 張	這 條	這 部	這 場	這 就 是 說	這 幅	
這 幾 天	這 幾 天 來	這 幾 年	這 幾 年 來	這 期	這 番 話	這 等	這 筆	
這 間	這 項	這 塊	這 會 兒	這 號	這 裡	這 話 一 點 不 假	這 道	
這 種	這 種 情 況 下	這 與	這 麼	這 麼 回 事	這 麼 些	這 麼 著	這 麼 樣	
這 價	這 幢	這 廝	這 樣	這 篇	這 輛	這 錢	這 幫	
這 還	這 顆	這 點	這 雙	這 邊	這 類	逍 遙	逍 遙 自 在	
逍 遙 自 娛	逍 遙 自 得	逍 遙 法 外	逍 遙 游	通 人 情	通 人 達 才	通 入	通 力	
通 力 合 作	通 大 便	通 才	通 才 練 識	通 今 博 古	通 分	通 天	通 天 徹 地	
通 心 面	通 心 粉	通 水	通 水 管	通 以	通 令	通 令 嘉 獎	通 功 易 事	
通 史	通 用	通 用 汽 車	通 用 性	通 共	通 向	通 名	通 吃	
通 州	通 式	通 考	通 行	通 行 無 阻	通 行 證	通 行 權	通 作	
通 告	通 告 板	通 告 者	通 志	通 身	通 車	通 迅 員	通 迅 錄	
通 例	通 典	通 函	通 到	通 夜	通 往	通 明	通 河	
通 法	通 知	通 知 者	通 知 書	通 知 單	通 者	通 信	通 信 工 程	
通 信 地 址	通 信 安 全	通 信 兵	通 信 技 術	通 信 系 統	通 信 保 障	通 信 員	通 信 條 令	
通 信 處	通 信 集	通 信 電 纜	通 信 對 抗	通 信 網	通 信 線 路	通 信 衛 星	通 信 器 材	
通 信 營	通 信 聯 絡	通 便	通 俗	通 俗 化	通 俗 易 懂	通 俗 劇	通 俗 讀 物	
通 則	通 姦	通 幽 洞 微	通 流 電	通 紅	通 約 性	通 風	通 風 口	
通 風 好	通 風 報 信	通 風 窗	通 風 道	通 風 管	通 風 機	通 家 之 好	通 宵	
通 宵 達 旦	通 時 達 變	通 氣	通 氣 口	通 氣 孔	通 病	通 航	通 訊	
通 訊 工 作	通 訊 系 統	通 訊 社	通 訊 者	通 訊 員	通 訊 衛 星	通 訊 錄	通 訊 類 股	
通 配 符	通 假 字	通 商	通 婚	通 常	通 常 用	通 常 用 於	通 常 指	
通 情 達 理	通 產	通 票	通 統	通 脫 不 拘	通 船	通 許	通 貨	
通 貨 膨 脹	通 貨 膨 脹 率	通 通	通 透	通 途	通 都 大 邑	通 報	通 報 批 評	
通 廊	通 渭	通 絡	通 脹	通 脹 率	通 象	通 郵	通 順	
通 勤	通 勤 者	通 榆	通 牒	通 經	通 義	通 話	通 路	
通 路 名	通 道	通 達	通 過	通 過 了	通 過 決 議	通 過 討 論	通 過 學 習	
通 過 鑒 定	通 電	通 暢	通 稱	通 語	通 敵	通 敵 者	通 盤	
通 盤 考 慮	通 篇	通 緝	通 緝 犯	通 論	通 霄	通 霄 達 旦	通 曉	
通 曉 事 理	通 融	通 諜	通 輯	通 聯	通 竅	通 關	通 寶	
通 譯	通 欄	通 欄 標 題	通 權 達 變	通 讀	通 體	通 衢	通 衢 廣 陌	
通 靈 術	通 觀 全 局	逗 人	逗 人 笑	逗 牛	逗 他	逗 她	逗 弄	
逗 性	逗 留	逗 笑	逗 得	逗 眼	逗 惱	逗 惹	逗 號	
逗 樂	逗 趣	逗 點	連 人	連 三 接 二	連 三 接 四	連 上	連 山	
連 中 三 元	連 天	連 天 烽 火	連 心	連 手	連 日	連 他	連 句	
連 打	連 本 帶 利	連 用	連 立	連 任	連 同	連 名	連 合	
連 在	連 字 符	連 宇 公 司	連 年	連 年 不 斷	連 忙	連 成	連 成 一 片	
連 有	連 衣 裙	連 串	連 作	連 坐	連 我	連 身	連 到	
連 夜	連 枝 分 葉	連 枝 比 翼	連 枝 帶 葉	連 長	連 城 之 珍	連 城 之 階	連 城 之 璧	
連 看 都 不 看	連 音	連 乘	連 個	連 射	連 根	連 珠	連 珠 合 璧	
連 珠 炮	連 袂	連 衽 成 帷	連 起	連 配	連 除	連 區	連 帶	
連 接	連 接 口	連 接 埠	連 接 詞	連 接 器	連 排	連 敗	連 桿	
連 桿 機 構	連 理	連 理 草	連 累	連 貫	連 貫 性	連 通	連 通 性	
連 通 管	連 通 器	連 連	連 陰 天	連 章 累 牘	連 凱	連 勝	連 勝 文	
連 朝 接 夕	連 發	連 結	連 結 者	連 結 詞	連 結 器	連 結 環	連 絡	
連 絡 站	連 著	連 詞	連 跑	連 軸 轉	連 隊	連 階 累 任	連 雲 港	
連 雲 疊 嶂	連 想	連 想 都 不 敢 想	連 署	連 署 人	連 號	連 載	連 運	
連 敲	連 綴	連 綿	連 綿 不 絕	連 綿 不 斷	連 綿 起 伏	連 說	連 寫	
連 撞	連 篇	連 篇 累 幅	連 篇 累 牘	連 線	連 線 作 業	連 遭	連 戰	
連 橫	連 輸	連 選 連 任	連 擊	連 環	連 環 畫	連 聲	連 賽	
連 鍋 端	連 翹	連 鎖	連 鎖 反 應	連 鎖 功 能	連 鎖 店	連 鎖 狀	連 鎖 商 店	
連 鎖 著	連 闖	連 繫	連 繫 辭	連 襟	連 類 比 物	連 贏	連 續	
連 續 不 斷	連 續 分 佈	連 續 打	連 續 光 譜	連 續 作 戰	連 續 函 數	連 續 性	連 續 音	
連 續 區	連 續 劇	連 響	連 鑣 並 軫	連 體	連 茬	速 比	速 成	
速 行	速 告	速 把	速 攻	速 決	速 決 戰	速 度	速 度 快	
速 度 計	速 度 慢	速 查	速 食 店	速 食 業	速 食 麵	速 凍	速 射	
速 射 炮	速 效	速 記	速 記 法	速 記 員	速 記 術	速 排	速 率	
速 勝	速 測	速 煮	速 發	速 滑	速 算	速 遞	速 寫	
速 戰	速 戰 速 決	速 辦	速 歸	速 簡	速 霸 陸	速 讀	速 顯	
逝 世	逝 去	逝 名	逝 者	逝 者 如 斯	逐 一	逐 戶	逐 日	
逐 月	逐 出	逐 出 者	逐 句	逐 外	逐 末 捨 本	逐 字	逐 字 逐 句	
逐 年	逐 次	逐 次 性	逐 行	逐 利 爭 名	逐 步	逐 步 完 善	逐 步 形 成	
逐 步 推 廣	逐 走	逐 放	逐 前	逐 客	逐 客 令	逐 頁	逐 個	
逐 浪 隨 波	逐 級	逐 臭 之 夫	逐 退	逐 條	逐 鹿	逐 鹿 中 原	逐 項	
逐 電 追 風	逐 漸	逐 漸 形 成	逕 自	逕 直	逕 庭	逞 己 失 眾	逞 兇	
逞 性 妄 為	逞 勇	逞 威	逞 能	逞 強	逞 強 稱 能	逞 異 誇 能	逞 惡	
造 化	造 化 小 兒	造 化 弄 人	造 反	造 天 立 極	造 冊	造 出	造 句	
造 句 法	造 田	造 字	造 成	造 成 了	造 成 直 接 經 濟 損 失	造 次	造 血	
造 血 器 官	造 作	造 車	造 房	造 林	造 林 於	造 林 術	造 林 學	
造 物	造 物 主	造 雨 者	造 型	造 紙	造 紙 工	造 紙 術	造 紙 業	
造 紙 廠	造 假	造 船	造 船 工 業	造 船 台	造 船 所	造 船 業	造 船 廠	
造 訪	造 雪	造 就	造 詞	造 勢	造 園 術	造 微 入 妙	造 愛	
造 極 登 峰	造 罪	造 詣	造 幣	造 幣 者	造 幣 廠	造 福	造 價	
造 影	造 橋	造 謗 生 事	造 謠	造 謠 中 傷	造 謠 生 事	造 謠 者	造 謠 惑 眾	
造 孽	透 了	透 入	透 力	透 孔	透 支	透 支 額	透 水	
透 出	透 光	透 有	透 汗	透 味	透 底	透 性	透 明	
透 明 度	透 明 圖	透 明 體	透 析	透 析 液	透 析 器	透 雨	透 亮	
透 信	透 紅	透 風	透 射	透 氣	透 骨	透 骨 通 今	透 骨 酸 心	
透 透	透 頂	透 著	透 視	透 視 性	透 視 畫	透 過	透 過 風	
透 徹	透 熱	透 壓	透 鏡	透 鏡 狀	透 闢	透 露	透 聽 力	
逢 一	逢 人 說 項	逢 山 開 道	逢 兇 化 吉	逢 年 過 節	逢 到	逢 迎	逢 春	
逢 場 作 樂	逢 場 作 戲	逛 去	逛 完	逛 來	逛 逛	逛 街	逛 蕩	
途 上	途 中	途 徑	途 程	途 經	部 下	部 分	部 分 地 區	
部 交	部 件	部 份	部 份 性	部 曲	部 位	部 呈	部 委	
部 長	部 長 級	部 長 會 議	部 門	部 門 主 管	部 後	部 首	部 級	
部 區	部 族	部 族 間	部 隊	部 隊 建 設	部 署	部 署 飛 彈	部 落	
部 落 制	部 頒	部 頒 標 準	部 標	部 機 關	部 優	部 類	部 屬	
郭 台 銘	郭 泓 志	郭 英 男	郭 泰 源	郭 富 城	郭 進 財	郭 源 治	郭 靄 明	
都 不	都 不 必	都 不 能	都 勻	都 比	都 去	都 可	都 可 以	
都 市	都 市 人	都 市 化	都 市 式	都 市 味	都 市 間	都 由	都 好	
都 存	都 忙	都 成	都 江 堰	都 把	都 沒	都 來	都 到	
都 城	都 很	都 是	都 柏 林	都 為	都 看	都 紅	都 能	
都 尉	都 將	都 從	都 統	都 被	都 愣	都 無	都 給	
都 想	都 愛	都 會	都 督	都 該	都 察 院	都 對	都 睡	
都 與	都 說	都 頭 異 姓	都 蘭	都 讓	酗 酒	野 人	野 丫 頭	
野 心	野 心 勃 勃	野 心 家	野 火	野 牛	野 史	野 外	野 外 作 業	
野 生	野 生 動 物	野 生 植 物	野 合	野 地	野 兔	野 味	野 性	
野 果	野 炊	野 狗	野 狗 似	野 芹 菜	野 花	野 花 閒 草	野 芥 子	
野 孩 子	野 炮	野 胡 蘿 蔔	野 茂 英 雄	野 食	野 草	野 馬	野 鬼	
野 鳥	野 麥	野 無 遺 才	野 無 遺 賢	野 腔	野 菊	野 菜	野 禽	
野 蜂	野 種	野 調 無 腔	野 豌 豆	野 豬	野 趣	野 戰	野 戰 軍	
野 貓	野 餐	野 鴨	野 鴨 肉	野 營	野 營 訓 練	野 薑 花	野 薔 薇	
野 雞	野 獸	野 蠻	野 蠻 人	野 蠻 化	野 蠻 裝 卸	野 驢	釣 友	
釣 名 沽 譽	釣 名 欺 世	釣 具	釣 客	釣 竿	釣 魚	釣 魚 人	釣 魚 台	
釣 魚 列 島	釣 魚 者	釣 絲	釣 鉤	釣 餌	釣 繩	釣 譽 沽 名	釩 鉛 礦	
釩 酸 鹽	閉 上	閉 口	閉 月	閉 月 羞 花	閉 止	閉 目	閉 目 塞 聽	
閉 目 養 神	閉 合	閉 合 電 路	閉 居	閉 明 塞 聰	閉 花	閉 門	閉 門 卻 掃	
閉 門 思 過	閉 門 造 車	閉 門 謝 客	閉 門 羹	閉 音	閉 氣	閉 眼	閉 著	
閉 塞	閉 會	閉 經	閉 路	閉 路 電 視	閉 幕	閉 幕 式	閉 幕 詞	
閉 閣 思 過	閉 嘴	閉 館	閉 環	閉 鎖	閉 關	閉 關 自 守	閉 關 鎖 國	
陪 同	陪 臣	陪 伴	陪 你	陪 床	陪 我	陪 侍	陪 房	
陪 客	陪 拜	陪 音	陪 笑	陪 送	陪 酒	陪 祭	陪 都	
陪 著	陪 嫁	陪 綁	陪 罪	陪 葬	陪 睡	陪 審	陪 審 制 度	
陪 審 員	陪 審 席	陪 審 團	陪 練	陪 禮	陪 襯	陪 襯 物	陪 讀	
陵 上 虐 下	陵 川	陵 園	陵 墓	陵 寢	陵 廟	陳 力 就 列	陳 大 豐	
陳 子 強	陳 水 扁	陳 可 辛	陳 必 照	陳 由 豪	陳 皮	陳 立 芹	陳 光	
陳 列	陳 列 品	陳 列 室	陳 列 說 明	陳 列 館	陳 列 櫥	陳 年	陳 年 老 帳	
陳 米	陳 兵	陳 沖	陳 言	陳 言 務 去	陳 谷	陳 谷 子 爛 芝 麻	陳 亞 蘭	
陳 放	陳 明 章	陳 金 鋒	陳 俊 生	陳 屍	陳 屍 所	陳 昭 榮	陳 映 真	
陳 珊 妮	陳 美 鳳	陳 述	陳 述 者	陳 純 甄	陳 酒	陳 國 富	陳 國 森	
陳 堅 執 銳	陳 情	陳 情 抗 議	陳 情 書	陳 淑 樺	陳 莎 莉	陳 規	陳 規 陋 習	
陳 設	陳 貨	陳 陳	陳 陳 相 因	陳 腔 濫 調	陳 腔 爛 調	陳 詞	陳 詞 濫 調	
陳 訴	陳 義 信	陳 該 發	陳 跡	陳 雷 膠 漆	陳 腐	陳 腐 無 味	陳 說	
陳 履 安	陳 德 容	陳 德 森	陳 毅	陳 潔 儀	陳 蔡 之 厄	陳 醋	陳 鋒	
陳 舊	陳 舊 觀 念	陳 辭	陳 寶 蓮	陸 上	陸 小 芬	陸 生	陸 地	
陸 沉	陸 委 會	陸 居 者	陸 岸	陸 封	陸 架	陸 軍	陸 海	
陸 海 空	陸 海 空 三 軍	陸 海 潘 江	陸 棲	陸 塊	陸 路	陸 運	陸 標	
陸 戰	陸 戰 區	陸 戰 隊	陸 橋	陸 龜	陸 離	陸 離 光 怪	陸 離 斑 駁	
陸 續	陰 天	陰 戶	陰 毛	陰 冷	陰 沉	陰 沉 沉	陰 私	
陰 刻	陰 府	陰 性	陰 虱	陰 門	陰 阜	陰 雨	陰 毒	
陰 狠	陰 風	陰 唇	陰 差 陽 錯	陰 核	陰 氣	陰 乾	陰 曹	
陰 曹 地 府	陰 涼	陰 涼 處	陰 盛 陽 衰	陰 莖	陰 部	陰 陰	陰 晴	
陰 森	陰 森 森	陰 著	陰 著 兒	陰 虛	陰 間	陰 陽	陰 陽 交 錯	
陰 陽 怪 氣	陰 陽 易 位	陰 雲	陰 暗	陰 暗 面	陰 暗 處	陰 極	陰 極 射 線 管	
陰 溝	陰 蒂	陰 道	陰 道 炎	陰 電	陰 電 子	陰 壽	陰 魂	
陰 魂 不 散	陰 影	陰 德	陰 歷	陰 歷 月	陰 歷 年	陰 謀	陰 謀 不 軌	
陰 謀 者	陰 謀 活 動	陰 謀 家	陰 謀 詭 計	陰 錯 陽 差	陰 險	陰 險 人	陰 濕	
陰 離	陰 離 子	陰 囊	陰 霾	陰 鬱	陶 土	陶 子	陶 工	
陶 犬 瓦 雞	陶 瓦	陶 冶	陶 冶 情 操	陶 制	陶 性	陶 瓷	陶 瓷 器	
陶 粒	陶 陶 自 得	陶 晶 瑩	陶 然 自 得	陶 管	陶 醉	陶 器	陶 器 廠	
陶 藝	陶 藝 家	陶 罐	陷 入	陷 入 困 境	陷 下	陷 井	陷 地	
陷 住	陷 坑	陷 沒	陷 身	陷 阱	陷 於	陷 於 絕 境	陷 者	
陷 害	陷 處	陷 溺	陷 落	陷 窩	陷 網	陷 撥	陷 敵	
雀 角 鼠 牙	雀 兒	雀 屏 中 選	雀 巢	雀 麥	雀 斑	雀 窩	雀 類	
雀 躍	雪 人	雪 上	雪 上 加 霜	雪 上 運 動	雪 山	雪 中	雪 中 送 炭	
雪 天	雪 水	雪 片	雪 丘	雪 仗	雪 白	雪 地	雪 杉	
雪 兒	雪 夜	雪 板	雪 松	雪 泥	雪 泥 鴻 爪	雪 盲	雪 盲 症	
雪 花	雪 花 膏	雪 亮	雪 恨	雪 茄	雪 茄 盒	雪 茄 煙	雪 虐 風 饕	
雪 冤	雪 原	雪 恥	雪 案 螢 窗	雪 案 螢 燈	雪 豹	雪 堆	雪 崩	
雪 梨	雪 深	雪 犁	雪 球	雪 鳥	雪 景	雪 窗 螢 火	雪 窗 螢 幾	
雪 窖 冰 天	雪 貂	雪 裡 紅	雪 裡 送 炭	雪 裡 蕻	雪 路	雪 歌 妮 薇 佛	雪 碧	
雪 餅	雪 撬	雪 線	雪 蓮	雪 鞋	雪 橇	雪 糕	雪 融	
雪 櫃	雪 鏟	章 台 楊 柳	章 句	章 句 之 徒	章 回	章 回 小 說	章 回 體	
章 孝 嚴	章 決 句 斷	章 法	章 則	章 魚	章 程	章 節	竟 未	
竟 有	竟 自	竟 至	竟 技 場	竟 爭	竟 是	竟 為	竟 能	
竟 敢	竟 然	竟 然 會	竟 會	竟 達	頂 了	頂 下	頂 上	
頂 子	頂 不 住	頂 天	頂 天 立 地	頂 牛	頂 用	頂 名	頂 回	
頂 多	頂 好	頂 尖	頂 行	頂 住	頂 吹	頂 角	頂 事	
頂 呱 呱	頂 板	頂 的	頂 肥	頂 芽	頂 門	頂 冒	頂 拱	
頂 架	頂 風	頂 風 冒 雨	頂 峰	頂 班	頂 真	頂 起	頂 針	
頂 崗	頂 得 住	頂 梁	頂 球	頂 部	頂 帽	頂 替	頂 棚	
頂 窗	頂 著	頂 碗	頂 罪	頂 葉	頂 摟	頂 端	頂 蓋	
頂 嘴	頂 寬	頂 層	頂 撞	頂 槽	頂 樓	頂 樑 柱	頂 蓬	
頂 頭	頂 頭 上 司	頂 戴	頂 篷	頂 點	頂 禮	頂 禮 膜 拜	頂 壞	
頃 刻	頃 刻 之 間	魚 丸	魚 叉	魚 子 醬	魚 水	魚 水 和 諧	魚 水 情	
魚 片	魚 目	魚 目 混 珠	魚 死 網 破	魚 池	魚 米 之 鄉	魚 肉	魚 尾	
魚 尾 狀	魚 尾 紋	魚 沉 雁 杳	魚 沉 雁 渺	魚 沉 雁 落	魚 肝 油	魚 肚	魚 兒	
魚 具	魚 刺	魚 油	魚 油 精	魚 花	魚 科	魚 缸	魚 苗	
魚 凍	魚 秧	魚 粉	魚 翅	魚 草	魚 骨	魚 排	魚 桿	
魚 條	魚 眼	魚 販	魚 貫	魚 貫 而 入	魚 貫 而 出	魚 魚 雅 雅	魚 場	
魚 游 釜 中	魚 游 釜 底	魚 粥	魚 塘	魚 塊	魚 群	魚 腥	魚 腹	
魚 道	魚 鉤	魚 雷	魚 雷 艇	魚 漂	魚 種	魚 網	魚 餌	
魚 潰 鳥 散	魚 膠	魚 蝦	魚 質 龍 文	魚 頭	魚 龍 混 雜	魚 龍 漫 衍	魚 龍 變 化	
魚 蟲	魚 鬆	魚 類	魚 爛 土 崩	魚 爛 而 亡	魚 躍	魚 躍 鳶 飛	魚 驚 鳥 散	
魚 驚 鳥 潰	魚 鱗	魚 鱗 坑	魚 鱗 松	鳥 人	鳥 弓	鳥 叫	鳥 叫 聲	
鳥 名	鳥 合 之 眾	鳥 托 邦	鳥 肉	鳥 尾	鳥 身	鳥 依	鳥 兒	
鳥 冠	鳥 屋	鳥 食	鳥 巢	鳥 捨	鳥 蛋	鳥 雀	鳥 啼	
鳥 喙 狀	鳥 散 魚 潰	鳥 群	鳥 道 羊 腸	鳥 槍	鳥 槍 換 炮	鳥 盡	鳥 盡 弓 藏	
鳥 種	鳥 窩	鳥 語	鳥 語 花 香	鳥 餌	鳥 鳴	鳥 嘴	鳥 嘴 狀	
鳥 瞰	鳥 瞰 圖	鳥 糞	鳥 翼	鳥 聲	鳥 獸	鳥 獸 散	鳥 類	
鳥 類 學	鳥 籠	鹵 化	鹵 化 物	鹵 汁	鹵 面	鹵 素	鹵 莽	
鹵 莽 滅 裂	鹵 蛋	鹵 過 魚	鹵 蝦	鹵 質	鹵 雞	鹿 人	鹿 皮	
鹿 死	鹿 死 不 擇 音	鹿 死 誰 手	鹿 肉	鹿 角	鹿 谷	鹿 谷 鄉	鹿 兒	
鹿 兒 島	鹿 特 丹	鹿 茸	鹿 草 鄉	鹿 豹 座	鹿 脯	鹿 野	鹿 野 鄉	
鹿 港	鹿 港 民 俗 文 物 館	鹿 港 鎮	鹿 裘 不 完	鹿 寨	麥 子	麥 片	麥 片 湯	
麥 片 粥	麥 牙 醋	麥 冬	麥 加	麥 可 傑 克 遜	麥 田	麥 地	麥 收	
麥 曲	麥 克	麥 克 風	麥 克 道 格 拉 斯	麥 芒	麥 角	麥 乳 精	麥 芽	
麥 芽 汁	麥 芽 糖	麥 金 塔	麥 秋	麥 苗	麥 浪	麥 特 戴 蒙	麥 草	
麥 桿	麥 粒	麥 晶	麥 稈	麥 當 勞	麥 蛾	麥 精	麥 寮	
麥 寮 鄉	麥 德 林	麥 麩	麥 穗	麥 穗 兩 岐	麥 茬	麥 秸	麻 子	
麻 仁	麻 木	麻 木 不 仁	麻 木 狀 態	麻 包	麻 布	麻 色	麻 衣	
麻 利	麻 豆	麻 制	麻 油	麻 花	麻 城	麻 省	麻 省 理 工 學 院	
麻 風	麻 風 病	麻 疹	麻 紡	麻 紗	麻 婆	麻 婆 豆 腐	麻 將	
麻 袋	麻 袋 布	麻 雀	麻 麻	麻 酥	麻 陽	麻 黃	麻 黃 素	
麻 黃 鹼	麻 煩	麻 煩 事	麻 痺	麻 痺 大 意	麻 痺 不 仁	麻 痺 思 想	麻 瘋	
麻 瘋 病	麻 線	麻 醉	麻 醉 性	麻 醉 品	麻 醉 師	麻 醉 劑	麻 醉 學	
麻 醉 藥	麻 糖	麻 蹄 聲	麻 鴨	麻 臉	麻 薯	麻 點	麻 織	
麻 醬	麻 繩	麻 藥	麻 癲	麻 秸	傢 伙	傢 俱	傢 俱 商	
傢 俱 業	傢 俬	傍 人 門 戶	傍 人 籬 壁	傍 午	傍 水	傍 花 隨 柳	傍 門 依 戶	
傍 柳 隨 花	傍 若 無 人	傍 軌	傍 晌	傍 晚	傍 黑	傍 靠	傍 邊	
傍 觀 者 清	傅 粉 何 郎	傅 粉 施 朱	備 下	備 不 住	備 用	備 用 金	備 用 品	
備 用 輪 胎	備 件	備 份	備 好	備 存	備 有	備 考	備 而 不 用	
備 至	備 位 充 數	備 忘	備 忘 錄	備 足	備 取	備 受	備 品	
備 查	備 軍	備 員	備 料	備 案	備 耕	備 荒	備 馬	
備 貨	備 換 服 裝	備 換 鞋	備 註	備 飯	備 置	備 詢	備 嘗 辛 苦	
備 嘗 艱 苦	備 齊	備 課	備 戰	備 辦	備 選	備 餐	傑 出	
傑 出 人 物	傑 出 代 表	傑 弗 遜	傑 作	傑 克	傑 克 遜	傀 儡	傀 儡 戲	
傘 兵	傘 形	傘 狀	傘 面	傘 齒 輪	傚 尤	傚 法	最 下	
最 下 方	最 下 部	最 上	最 上 等	最 上 策	最 久	最 大	最 大 公 約 數	
最 大 化	最 大 限 度	最 大 值	最 大 數	最 小	最 小 公 倍 數	最 小 化	最 小 值	
最 丑	最 不	最 中 間	最 內 部	最 少	最 主 要	最 北	最 外	
最 外 面	最 外 邊	最 末	最 末 端	最 先	最 多	最 奸	最 好	
最 好 成 績	最 尖	最 年 長	最 年 青	最 早	最 有	最 老	最 低	
最 低 分	最 低 化	最 低 水 平	最 低 音	最 低 溫 度	最 低 綱 領	最 低 潮	最 低 點	
最 低 額	最 冷	最 快	最 乖	最 佳	最 佳 化	最 佳 值	最 佳 陣 容	
最 受	最 底	最 底 下	最 底 層	最 性 感	最 易	最 東 部	最 初	
最 近	最 近 以 來	最 近 幾 年	最 長	最 亮	最 便 宜	最 保 險	最 前	
最 前 部	最 前 線	最 南	最 南 端	最 厚	最 後	最 後 方	最 後 決 議	
最 後 面	最 後 通 牒	最 後 頭	最 恨	最 為	最 甚	最 重	最 重 要	
最 重 要 的	最 值	最 差	最 弱	最 能	最 高	最 高 人 民 法 院	最 高 人 民 檢 察 院	
最 高 水 平	最 高 法 院	最 高 度	最 高 紀 錄	最 高 限 價	最 高 峰	最 高 氣 溫	最 高 級	
最 高 溫 度	最 高 綱 領	最 高 層	最 高 標 準	最 高 潮	最 高 獎	最 高 點	最 強	
最 接 近	最 晚	最 深	最 深 入	最 深 奧	最 理 想	最 笨	最 細	
最 終	最 終 目 的	最 軟	最 最	最 喜	最 惡 劣	最 惠 國	最 惠 國 待 遇	
最 短	最 硬	最 絕	最 黑	最 愛	最 新	最 新 式	最 新 版	
最 新 近	最 新 消 息	最 暗	最 慢	最 暢 銷	最 輕	最 遠	最 遠 方	
最 遠 點	最 熱	最 窮	最 適	最 適 宜	最 適 度	最 靠	最 靠 近	
最 親 近	最 遲	最 優	最 優 化	最 優 性	最 糟	最 聰 明	最 醜 惡	
最 簡 單	最 舊	最 壞	最 難	最 嚴 厲	凱 文 布 朗	凱 因 斯	凱 美 電 機	
凱 旋	凱 旋 式	凱 旋 而 歸	凱 旋 歸 來	凱 裡	凱 歌	凱 聚	凱 聚 公 司	
凱 撒	凱 衛 資 訊	凱 薩 琳 齊 塔 瓊 斯	割 下	割 切	割 去	割 地	割 肚 牽 腸	
割 取	割 法	割 股	割 席 分 坐	割 息	割 破	割 草	割 除	
割 掉	割 捨	割 痕	割 袍 斷 義	割 麥	割 絨	割 裂	割 開	
割 傷	割 愛	割 碎	割 腱 術	割 稻	割 線	割 膠	割 據	
割 頸	割 臂 盟 公	割 斷	割 禮	割 離	割 雞 焉 用 牛 刀	割 讓	創 一 流	
創 下	創 口	創 世	創 世 紀	創 刊	創 刊 號	創 巨 痛 深	創 立	
創 立 人	創 立 者	創 收	創 作	創 作 人	創 作 力	創 作 自 由	創 作 者	
創 作 思 想	創 作 經 驗	創 利	創 利 稅	創 投 公 司	創 見	創 始	創 始 人	
創 始 者	創 性	創 建	創 建 組	創 紀 錄	創 面	創 效	創 域	
創 痕	創 設	創 造	創 造 力	創 造 性	創 造 物	創 造 者	創 造 條 件	
創 造 學	創 傷	創 匯	創 匯 額	創 意	創 新	創 新 者	創 新 紀 錄	
創 業	創 業 史	創 業 板	創 業 者	創 業 垂 統	創 製	創 製 者	創 歷	
創 歷 史 最 高 水 平	創 歷 史 最 高 紀 錄	創 辦	創 辦 人	創 優	創 舉	剩 下	剩 水 殘 山	
剩 物	剩 料	剩 貨	剩 菜	剩 詞	剩 飯	剩 磁	剩 遺	
剩 錢	勞 力	勞 工	勞 工 住 宅	勞 工 局	勞 工 法	勞 工 黨	勞 心	
勞 心 焦 思	勞 支	勞 方	勞 乏	勞 民	勞 民 傷 財	勞 多 得	勞 而 無 功	
勞 而 無 獲	勞 作	勞 役	勞 改	勞 身 焦 思	勞 委 會	勞 保	勞 保 用 品	
勞 保 給 付	勞 勃 狄 尼 洛	勞 苦	勞 苦 大 眾	勞 苦 功 高	勞 軍	勞 師	勞 師 動 眾	
勞 師 襲 遠	勞 神	勞 退 基 金	勞 做	勞 務	勞 務 市 場	勞 務 費	勞 動	
勞 動 人 民	勞 動 力	勞 動 日	勞 動 生 產 力	勞 動 局	勞 動 改 造	勞 動 制	勞 動 法	
勞 動 者	勞 動 保 險	勞 動 紀 律	勞 動 致 富	勞 動 參 與	勞 動 部	勞 動 量	勞 動 節	
勞 動 資 料	勞 動 模 範	勞 動 黨	勞 動 權	勞 教	勞 教 所	勞 累	勞 累 過 度	
勞 凱 利	勞 斯 萊 斯	勞 逸	勞 逸 結 合	勞 傷	勞 瘁	勞 碌	勞 資	
勞 資 爭 議	勞 資 糾 紛	勞 資 科	勞 資 雙 方	勞 頓	勞 遜	勞 模	勞 駕	
勞 燕 分 飛	勞 績	勝 不 驕	勝 不 驕 敗 不 餒	勝 之	勝 天	勝 仗	勝 出	
勝 任	勝 任 愉 快	勝 地	勝 似	勝 利	勝 利 在 望	勝 利 果 實	勝 利 者	
勝 券	勝 於	勝 者	勝 負	勝 負 兵 家 常 勢	勝 負 難 測	勝 敗	勝 敗 乃 兵 家 常 事	
勝 造 七 級 浮 屠	勝 景	勝 智	勝 殘 去 殺	勝 華 科 技	勝 訴	勝 跡	勝 過	
勝 算	勝 數	博 士	博 士 生	博 士 買 驢	博 士 學 位	博 士 頭 銜	博 大	
博 大 精 深	博 引	博 文 約 禮	博 古	博 古 通 今	博 白	博 而 不 精	博 取	
博 物	博 物 多 聞	博 物 洽 聞	博 物 院	博 物 學 家	博 物 館	博 物 館 學	博 采	
博 采 各 家 之 長	博 采 眾 長	博 采 眾 家 之 長	博 奕	博 弈	博 弈 者	博 施 濟 眾	博 個 知 今	
博 茨 瓦 納	博 彩	博 得	博 野	博 湖	博 愛	博 愛 者	博 達 科 技	
博 爾 塔 拉	博 聞	博 聞 多 識	博 聞 強 志	博 聞 強 記	博 聞 強 識	博 學	博 學 多 才	
博 學 多 聞	博 學 洽 聞	博 羅	博 覽	博 覽 會	喀 什	喀 什 米 爾	喀 布 爾	
喀 麥 隆	喀 斯 特	喀 嚓	喧 天	喧 吵	喧 賓 奪 主	喧 鬧	喧 鬧 聲	
喧 擾	喧 嚷	喧 騰	喧 騰 不 息	喧 騷	喧 囂	啼 天 哭 地	啼 叫	
啼 叫 聲	啼 哭	啼 笑 皆 非	啼 聲	啼 饑 號 寒	喊 了	喊 人	喊 出	
喊 叫	喊 叫 者	喊 叫 聲	喊 它	喊 打	喊 好	喊 住	喊 到	
喊 冤	喊 冤 叫 屈	喊 冤 者	喊 著	喊 開	喊 嗓	喊 話	喊 道	
喊 價	喊 窮	喊 醒	喊 聲	喊 嚷	喝 了	喝 下	喝 上	
喝 口	喝 六 呼 麼	喝 止	喝 水	喝 令	喝 光	喝 成	喝 西 北 風	
喝 住	喝 完	喝 采	喝 茶	喝 酒	喝 乾	喝 問	喝 夠	
喝 彩	喝 彩 聲	喝 掉	喝 著	喝 道	喝 過	喝 醉	喝 醉 了	
喝 聲	喝 點	喘 不	喘 不 過 氣	喘 吁 吁	喘 狀	喘 息	喘 氣	
喘 氣 者	喘 喘	喘 著	喘 著 氣	喘 噓 噓	喘 聲	喂 以	喂 喂	
喂 豬	喂 藥	喜 人	喜 上 心 頭	喜 不 自 勝	喜 不 自 禁	喜 出 望 外	喜 功	
喜 地 歡 天	喜 好	喜 色	喜 孜 孜	喜 形	喜 形 於 色	喜 事	喜 帖	
喜 知	喜 迎	喜 雨	喜 冒 險	喜 怒	喜 怒 哀 樂	喜 怒 無 常	喜 洋 洋	
喜 眉 笑 眼	喜 看	喜 音	喜 香 憐 玉	喜 修	喜 宴	喜 悅	喜 氣	
喜 氣 洋 洋	喜 氣 盈 門	喜 笑	喜 笑 顏 開	喜 訊	喜 酒	喜 馬 拉 雅	喜 馬 拉 雅 山	
喜 從 天 降	喜 雀	喜 報	喜 惡	喜 亂	喜 愛	喜 新	喜 新 厭 舊	
喜 煉	喜 嘉	喜 對	喜 幛	喜 瑪 拉 雅	喜 筵	喜 聞	喜 聞 樂 見	
喜 餅	喜 劇	喜 慶	喜 憂 參 半	喜 談	喜 遷 新 居	喜 戰	喜 糖	
喜 錢	喜 獲	喜 獲 豐 收	喜 癖	喜 顏	喜 鵲	喜 歡	喪 子	
喪 天 害 理	喪 心	喪 心 病 狂	喪 失	喪 失 了	喪 失 者	喪 生	喪 曲	
喪 志	喪 身	喪 事	喪 命	喪 於 非 命	喪 明 之 痛	喪 服	喪 家	
喪 家 之 犬	喪 家 之 狗	喪 氣	喪 假	喪 偶	喪 期	喪 亂	喪 葬	
喪 葬 費	喪 盡 天 良	喪 魂	喪 魂 落 魄	喪 儀	喪 親	喪 膽	喪 膽 亡 魂	
喪 膽 銷 魂	喪 禮	喪 鐘	喪 鐘 聲	喪 權	喪 權 辱 國	喔 呀	喔 唷	
喔 喔	喇 叭	喇 叭 口	喇 叭 手	喇 叭 狀	喇 叭 筒	喇 叭 槍	喇 叭 管	
喇 叭 褲	喇 叭 聲	喇 嘛	喇 嘛 教	喇 嘛 廟	喋 血	喋 喋	喋 喋 不 休	
喋 喋 而 言	喃 喃	喃 喃 而 語	喃 喃 自 語	喃 喃 細 語	喳 喳	喳 聲	單 一	
單 一 化	單 一 性	單 人	單 人 床	單 人 座	單 人 獨 馬	單 刀	單 刀 直 入	
單 于	單 刃 劍	單 子	單 子 葉 植 物	單 干	單 干 戶	單 元	單 元 格	
單 元 論	單 內	單 分	單 夫 只 婦	單 孔	單 引 擎	單 手	單 方	
單 方 面	單 日	單 月	單 比	單 片	單 去	單 只	單 句	
單 打	單 打 一	單 本	單 用	單 立	單 交	單 件	單 列	
單 向	單 向 閥	單 字	單 字 集	單 次	單 耳	單 色	單 色 光	
單 色 版	單 色 畫	單 行	單 行 本	單 行 道	單 行 線	單 衣	單 位	
單 位 制	單 位 負 責 人	單 位 量	單 位 預 算	單 作	單 作 用	單 克 隆	單 利	
單 卵 性	單 步	單 足	單 身	單 身 貴 族	單 身 漢	單 車	單 車 旅 遊	
單 季 稻	單 弦	單 弦 琴	單 性	單 性 生 殖	單 指	單 是	單 相	
單 相 思	單 科	單 缸	單 軌	單 軌 制	單 軌 鐵 路	單 面	單 音	
單 頁	單 飛	單 倍 體	單 個	單 原 子	單 峰	單 座	單 座 式	
單 料	單 核 細 胞	單 株	單 純	單 脈 沖	單 動 式	單 張	單 排	
單 產	單 眼	單 眼 鏡	單 細 胞	單 設	單 單	單 報	單 就	
單 幅	單 循 環 賽	單 晶 體	單 發	單 程	單 程 票	單 絲	單 絲 不 線	
單 詞	單 跌	單 間	單 項	單 項 式	單 項 獎	單 傳	單 塊	
單 極	單 源 抗 體	單 義	單 腳 跳	單 葉	單 號	單 寧	單 寧 酸	
單 槓	單 槍	單 槍 匹 馬	單 褂	單 說	單 價	單 層	單 幢	
單 數	單 線	單 調	單 質	單 輪	單 輪 車	單 靠	單 養	
單 憑	單 據	單 機	單 獨	單 糖	單 褲	單 親 家 庭	單 選	
單 幫	單 擊	單 環	單 翼	單 聯	單 薄	單 鍵	單 擺	
單 簧 管	單 額	單 騎	單 鵠 寡 鳧	單 邊	單 戀	單 纖 維	單 顯	
單 體	喟 歎	唾 手	唾 手 可 取	唾 手 可 得	唾 吐	唾 沫	唾 面 自 們	
唾 面 自 乾	唾 棄	唾 液	唾 液 素	唾 液 腺	唾 腺	唾 罵	喚 人	
喚 出	喚 回	喚 作	喚 定	喚 狗	喚 起	喚 起 者	喚 醒	
喻 性	喻 為	喬 丹	喬 木	喬 布	喬 其 紗	喬 松 之 壽	喬 治	
喬 治 史 崔 特	喬 治 克 魯 尼	喬 治 亞	喬 治 亞 人 壽	喬 治 亞 州	喬 麥	喬 登	喬 腦	
喬 裝	喬 裝 打 扮	喬 裝 改 扮	喬 福 機 械	喬 遷	喬 遷 之 喜	啾 叫	啾 啾	
喉 舌	喉 炎	喉 科	喉 科 學	喉 音	喉 部	喉 痛	喉 結	
喉 塞	喉 管	喉 學	喉 頭	喉 頭 炎	喉 頭 鏡	喉 嚨	喉 嚨 痛	
喫 茶	喙 長 三 尺	圍 了	圍 子	圍 巾	圍 內	圍 以	圍 地	
圍 在	圍 成	圍 住	圍 作	圍 困	圍 坐	圍 攻	圍 攻 者	
圍 城	圍 城 打 援	圍 屏	圍 捕	圍 桌	圍 起	圍 兜	圍 圈	
圍 堵	圍 脖	圍 場	圍 堰	圍 棋	圍 棋 錦 標 賽	圍 著	圍 剿	
圍 腰 布	圍 腰 帶	圍 裙	圍 補	圍 網	圍 裹	圍 嘴	圍 嘴 兒	
圍 膝 毯	圍 墾	圍 擋	圍 擒	圍 擊	圍 牆	圍 點 打 援	圍 獵	
圍 繞	圍 繞 物	圍 魏 救 趙	圍 攏	圍 爐	圍 欄	圍 殲	圍 護	
圍 籠	圍 巖	圍 籬	圍 觀	堯 天 舜 日	堯 舜	堪 培 拉	堪 虞	
堪 稱	堪 稱 一 絕	堪 輿	堪 薩 斯	場 上	場 子	場 內	場 主	
場 外	場 白	場 合	場 地	場 次	場 址	場 券	場 所	
場 長	場 屋	場 界	場 面	場 租	場 站	場 記	場 院	
場 區	場 強	場 部	場 場	場 景	場 費	場 論	場 頻	
場 館	場 戲	堤 防	堤 岸	堤 圍	堤 堰	堤 道	堤 維 西	
堤 潰	堤 潰 蟻 孔	堤 壩	堰 內	堰 塞 湖	報 人	報 上	報 子	
報 仇	報 仇 雪 恨	報 仇 雪 恥	報 文	報 以	報 出	報 刊	報 刊 發 行	
報 刊 雜 誌	報 功	報 失	報 本 反 始	報 名	報 考	報 作	報 告	
報 告 人	報 告 文 學	報 告 會	報 告 團	報 夾	報 批	報 到	報 官	
報 的	報 知	報 社	報 表	報 信	報 怨	報 春	報 春 花	
報 查	報 界	報 冤	報 恩	報 效	報 效 祖 國	報 時	報 案	
報 紙	報 紙 雜 誌	報 送	報 務	報 務 員	報 國	報 帳	報 捷	
報 販 亭	報 章	報 喜	報 喜 也 報 憂	報 喜 不 報 憂	報 喪	報 單	報 復	
報 復 心 理	報 復 主 義	報 復 性	報 稅	報 童	報 答	報 費	報 損	
報 業	報 禁	報 經	報 裝	報 話 機	報 載	報 道	報 道 失 實	
報 酬	報 幕	報 稱	報 說	報 領	報 價	報 價 人	報 價 單	
報 審	報 廢	報 德	報 數	報 窮	報 請	報 賬	報 銷	
報 導	報 導 文 學	報 曉	報 錯	報 頭	報 館	報 償	報 應	
報 轉	報 繳	報 關	報 警	報 警 器	報 欄	報 攤	報 驗	
堡 子	堡 中	堡 主	堡 寨	堡 壘	堡 壘 戶	壹 套	壺 中	
壺 中 日 月	壺 裡 乾 坤	壺 嘴	壺 漿 塞 道	奠 立	奠 定	奠 基	奠 基 人	
奠 基 石	奠 基 典 禮	奠 基 者	奠 基 儀 式	奠 都	奠 儀	婷 婷	媚 人	
媚 外	媚 骨	媚 眼	媚 態	媒 人	媒 介	媒 介 物	媒 介 者	
媒 妁	媒 兒	媒 染	媒 染 劑	媒 婆	媒 鳥	媒 質	媒 體	
孳 生	孱 弱	寒 士	寒 心	寒 心 酸 鼻	寒 木 春 花	寒 冬	寒 冬 臘 月	
寒 光	寒 色	寒 衣	寒 冷	寒 來 暑 往	寒 夜	寒 性	寒 武 紀	
寒 舍	寒 花 晚 節	寒 泉 之 思	寒 流	寒 流 來 襲	寒 秋	寒 苦	寒 風	
寒 氣	寒 氣 逼 人	寒 症	寒 耕 熱 耘	寒 假	寒 帶	寒 梅	寒 傖	
寒 喧	寒 暑	寒 暑 表	寒 暑 假	寒 窗	寒 微	寒 意	寒 暄	
寒 酸	寒 潮	寒 熱	寒 噤	寒 戰	寒 霜	寒 蟬 仗 馬	寒 露	
寒 顫	寒 磣	富 人	富 士 山	富 士 通	富 戶	富 比 王 侯	富 可 敵 國	
富 民	富 民 政 策	富 同	富 有	富 有 成 效	富 而 好 禮	富 余	富 含	
富 足	富 邦	富 邦 投 信	富 邦 保 險	富 邦 銀 行	富 邦 證 券	富 里	富 里 鄉	
富 於	富 家	富 翁	富 商	富 國	富 國 安 民	富 國 強 兵	富 庶	
富 強	富 強 輪 胎	富 富 有 餘	富 貴	富 貴 不 能 淫	富 貴 不 淫	富 貴 利 達	富 貴 浮 雲	
富 貴 無 常	富 貴 逼 人	富 貴 榮 華	富 貴 驕 人	富 陽	富 想	富 裕	富 裕 中 農	
富 裕 戶	富 農	富 農 分 子	富 態	富 爾 不 驕	富 豪	富 麗	富 麗 堂 皇	
富 孀	富 礦	富 蘊	富 饒	富 蘭 克 林	富 埒 天 子	富 驊 企 業	寓 公	
寓 言	寓 言 中	寓 言 詩	寓 居	寓 所	寓 於	寓 教	寓 意	
寐 神	尊 口	尊 己 卑 人	尊 心	尊 古 卑 今	尊 年 尚 齒	尊 老 愛 幼	尊 卑	
尊 姓	尊 姓 大 名	尊 官 厚 祿	尊 府	尊 長	尊 為	尊 重	尊 重 人 才	
尊 重 事 實	尊 重 知 識	尊 重 客 觀 事 實	尊 容	尊 師	尊 師 重 教	尊 師 重 道	尊 師 貴 道	
尊 師 愛 徒	尊 酒 論 文	尊 崇	尊 貴	尊 敬	尊 稱	尊 賢 使 能	尊 賢 愛 物	
尊 親	尊 顏	尊 嚴	尋 人	尋 人 啟 事	尋 山 問 水	尋 出	尋 回	
尋 死	尋 死 覓 活	尋 行 數 墨	尋 址	尋 找	尋 求	尋 究	尋 事	
尋 事 生 非	尋 到	尋 味	尋 呼	尋 底	尋 花 問 柳	尋 幽 訪 勝	尋 思	
尋 根	尋 根 究 底	尋 根 問 底	尋 問	尋 問 者	尋 常	尋 覓	尋 訪	
尋 章 摘 句	尋 短 見	尋 跡	尋 道	尋 夢	尋 樂	尋 機	尋 親	
尋 蹤	尋 蹤 覓 跡	尋 寶	尋 歡	尋 歡 作 樂	尋 釁	就 干	就 不 能	
就 手	就 日 瞻 雲	就 比	就 以	就 可	就 可 以	就 可 能	就 叫	
就 任	就 任 者	就 合	就 地	就 地 正 法	就 地 取 材	就 在	就 在 於	
就 多	就 好	就 成	就 此	就 此 罷 休	就 位	就 坐	就 走	
就 事	就 事 論 事	就 來	就 到	就 坡 下 驢	就 近	就 便	就 很	
就 按	就 是	就 是 棒	就 是 說	就 為	就 要	就 席	就 座	
就 拿	就 班	就 能	就 做	就 夠	就 得	就 從	就 教 於	
就 被	就 連	就 都	就 棍 打 腿	就 虛 避 實	就 診	就 跑	就 勢	
就 會	就 業	就 業 人 數	就 業 問 題	就 業 機 會	就 義	就 道	就 像	
就 寢	就 算	就 緒	就 說	就 範	就 學	就 學 前	就 擒	
就 餐	就 賺	就 職	就 職 演 說	就 醫	就 讀	就 讓	嵌 入	
嵌 木	嵌 片	嵌 合	嵌 合 體	嵌 在	嵌 有	嵌 於	嵌 物	
嵌 金	嵌 套	嵌 紋 病 毒	嵌 接	嵌 進	嵌 塊	嵌 環	幅 度	
幅 面	幅 員	幅 員 遼 闊	幅 射	幅 射 線	幅 寬	帽 上	帽 子	
帽 扣	帽 沿	帽 架	帽 盔	帽 章	帽 頭	帽 徽	帽 邊	
幀 頻	幾 十	幾 十 年	幾 十 年 如 一 日	幾 十 年 來	幾 下	幾 千	幾 千 年	
幾 口	幾 內	幾 內 亞	幾 內 亞 人	幾 分	幾 天	幾 天 來	幾 天 幾 夜	
幾 支	幾 方 面	幾 日	幾 乎	幾 乎 不	幾 乎 沒 有	幾 代	幾 代 人	
幾 句	幾 句 話	幾 件	幾 列	幾 名	幾 多	幾 年	幾 年 如 一 日	
幾 年 來	幾 朵	幾 次	幾 次 三 番	幾 百	幾 百 年	幾 位	幾 何	
幾 何 級 數	幾 何 圖 形	幾 何 學	幾 何 體	幾 步	幾 周	幾 所	幾 近	
幾 度	幾 架	幾 倍	幾 個	幾 個 月	幾 套	幾 家	幾 時	
幾 隻	幾 張	幾 條	幾 率	幾 票	幾 粒	幾 組	幾 許	
幾 部	幾 部 分	幾 番	幾 筆	幾 間	幾 集	幾 項	幾 歲	
幾 萬	幾 經	幾 經 反 覆	幾 經 考 慮	幾 經 周 折	幾 群	幾 號	幾 遍	
幾 滴	幾 種	幾 億	幾 層	幾 樣	幾 點	幾 點 鐘 了	幾 類	
廊 下	廊 坊	廊 道	廁 坑	廁 所	廁 紙	廂 房	廄 肥	
彭 百 顯	彭 作 奎	彭 賢 能	復 子 明 辟	復 工	復 仇	復 仇 主 義	復 仇 者	
復 仇 雪 恥	復 元	復 方	復 比	復 出	復 刊	復 加	復 古	
復 旦	復 本	復 生	復 白	復 交	復 任	復 合	復 合 字	
復 合 材 料	復 合 函 數	復 合 肥 料	復 合 體	復 地	復 位	復 利	復 壯	
復 折	復 函	復 明	復 建	復 活	復 活 節	復 音	復 原	
復 員	復 員 軍 人	復 員 證	復 根	復 耕	復 航	復 唱 句	復 得	
復 現	復 訟	復 甦	復 發	復 華 證 券	復 華 證 金	復 視	復 評	
復 會	復 葉	復 辟	復 電	復 種	復 種 指 數	復 種 面 積	復 算	
復 駁	復 線	復 課	復 學	復 燃	復 興	復 興 者	復 興 鄉	
復 選	復 選 框	復 醒	復 擊	復 蹈 其 轍	復 蹈 前 轍	復 擺	復 歸	
復 禮 克 己	復 職	復 舊	復 轉	復 關	復 籍	復 議	復 鹽	
循 化	循 名 考 實	循 名 校 實	循 名 責 實	循 名 督 實	循 名 課 實	循 次 而 進	循 序	
循 序 見 進	循 序 漸 進	循 例	循 沿	循 常 席 故	循 規 矩 蹈	循 規 蹈 矩	循 循	
循 循 善 誘	循 循 誘 人	循 著	循 路	循 環	循 環 小 數	循 環 反 覆	循 環 系 統	
循 環 往 復	循 環 性	循 環 節	循 環 器	循 環 賽	循 聲 附 會	徨 徨	惑 世 盜 名	
惑 者	惑 眾	惡 人	惡 口	惡 化	惡 少	惡 犬	惡 兆	
惡 劣	惡 名	惡 名 昭 彰	惡 行	惡 衣 粗 食	惡 衣 惡 食	惡 衣 菲 食	惡 衣 蔬 食	
惡 衣 �B 食	惡 作 劇	惡 作 劇 者	惡 言	惡 言 漫 罵	惡 言 詈 辭	惡 事	惡 事 行 千 里	
惡 事 傳 千 里	惡 例	惡 念	惡 性	惡 性 倒 會	惡 性 循 環	惡 性 瘤	惡 果	
惡 狗	惡 直 丑 正	惡 者	惡 虎 饑 鷹	惡 俗	惡 政	惡 毒	惡 狠 狠	
惡 相	惡 徒	惡 浪	惡 疾	惡 病	惡 臭	惡 臭 物	惡 臭 膿	
惡 鬼	惡 婦	惡 婆	惡 習	惡 貫 滿 盈	惡 貫 禍 盈	惡 勞 好 逸	惡 棍	
惡 棍 似	惡 紫 奪 朱	惡 評	惡 評 昭 著	惡 意	惡 感	惡 稔 貫 盈	惡 稔 罪 盈	
惡 稔 禍 盈	惡 補	惡 運	惡 夢	惡 夢 似	惡 漢	惡 語	惡 語 中 傷	
惡 語 傷 人	惡 德	惡 罵	惡 論	惡 戰	惡 積 禍 盈	惡 聲	惡 癖	
惡 霸	惡 魔	惡 魔 似	惡 魔 般	悲 不 自 勝	悲 切	悲 天 憫 人	悲 心	
悲 壯	悲 泣	悲 哀	悲 哉	悲 怨	悲 恨	悲 秋	悲 苦	
悲 哭	悲 衷	悲 情	悲 悵	悲 悼	悲 戚	悲 涼	悲 啼	
悲 喜	悲 喜 交 切	悲 喜 交 至	悲 喜 交 並	悲 喜 交 集	悲 喜 兼 集	悲 喜 劇	悲 喜 劇 性	
悲 惻	悲 痛	悲 痛 欲 絕	悲 訴	悲 傷	悲 感	悲 愴	悲 號	
悲 慟	悲 慘	悲 慘 世 界	悲 慘 結 局	悲 慘 境 遇	悲 歌	悲 歌 慷 慨	悲 酸	
悲 鳴	悲 劇	悲 劇 性	悲 劇 演 員	悲 憫	悲 憤	悲 憤 填 膺	悲 歎	
悲 懷	悲 歡	悲 歡 合 散	悲 歡 離 合	悲 觀	悲 觀 主 義	悲 觀 失 望	悲 觀 厭 世	
悲 觀 論 者	悲 觀 論 調	悶 人	悶 死	悶 住	悶 倦	悶 氣	悶 笑	
悶 酒	悶 悶	悶 悶 不 樂	悶 葫 蘆	悶 雷	悶 睡	悶 熱	悶 談	
悶 燒	悶 頭	悶 聲 不 響	悶 罐 車	惠 予	惠 及	惠 水	惠 民	
惠 存	惠 安	惠 州	惠 而 不 費	惠 妮 休 斯 頓	惠 東	惠 河	惠 勝 實 業	
惠 普	惠 然 肯 來	惠 陽	惠 賜	惠 臨	惠 顧	惠 鑒	惠 靈 頓	
愜 意	愣 了	愣 地	愣 住	愣 神	愣 愣	愣 著	惺 忪	
惺 松	惺 惺	惺 惺 作 態	惺 惺 惜 惺 惺	愕 然	惰 性	惰 性 氣 體	惻 怛 之 心	
惻 然	惻 隱	惻 隱 之 心	惴 惴	惴 惴 不 安	慨 然	慨 然 允 諾	慨 然 領 諾	
慨 然 應 允	慨 解 義 囊	慨 歎	惱 人	惱 火	惱 怒	惱 恨	惱 羞	
惱 羞 成 怒	惱 羞 變 怒	惱 亂	惶 恐	惶 恐 不 安	惶 悚 不 安	惶 惑	惶 惶	
惶 惶 不 可 終 日	愉 快	愉 悅	戟 指 怒 目	扉 頁	掣 肘	掣 電	掣 襟 肘 見	
掣 襟 露 肘	掌 力	掌 上	掌 上 明 珠	掌 上 型	掌 上 型 電 腦	掌 上 觀 紋	掌 勺	
掌 子 面	掌 中	掌 心	掌 承	掌 故	掌 班	掌 財	掌 骨	
掌 舵	掌 舵 人	掌 握	掌 握 分 寸	掌 摑 聲	掌 管	掌 廚	掌 燈	
掌 擊	掌 聲	掌 聲 雷 動	掌 櫃	掌 鞭	掌 權	掌 舖	描 上	
描 出	描 字	描 成	描 法	描 眉 畫 眼	描 紅	描 述	描 淡 寫	
描 描	描 畫	描 圖	描 寫	描 摩 者	描 摹	描 繪	描 鸞 刺 鳳	
揀 出	揀 去	揀 佛 燒 香	揀 起	揀 精 揀 肥	揀 選	揀 選 出	揩 去	
揩 布	揩 油	揩 淚	揉 勻	揉 成	揉 背	揉 面	揉 面 槽	
揉 捻	揉 眼	揉 搓	揉 碎	揉 摩	揉 皺	揉 眵 抹 淚	插 入	
插 入 句	插 入 物	插 入 鍵	插 上	插 口	插 孔	插 手	插 句	
插 件	插 在	插 曲	插 住	插 言	插 足	插 身	插 車	
插 到	插 於	插 枝	插 板	插 法	插 花	插 架 萬 軸	插 科 打 渾	
插 科 打 諢	插 頁	插 值	插 座	插 栓	插 班	插 班 生	插 秧	
插 秧 機	插 翅	插 翅 難 飛	插 翅 難 逃	插 敘	插 條	插 袋	插 插 花 花	
插 畫	插 進	插 隊	插 隊 落 戶	插 腰	插 腳	插 補	插 話	
插 話 式	插 圖	插 旗	插 管	插 嘴	插 寫	插 槽	插 線	
插 銷	插 頭	插 戴	揣 手	揣 合 逢 迎	揣 奸 把 猾	揣 度	揣 歪 捏 怪	
揣 測	揣 著	揣 進	揣 想	揣 摩	提 了	提 干	提 不	
提 升	提 升 間	提 及	提 心	提 心 吊 膽	提 心 在 口	提 手	提 出	
提 出 申 請	提 出 抗 議	提 出 批 評	提 出 者	提 包	提 去	提 示	提 示 區	
提 示 符	提 交	提 名	提 名 者	提 名 權	提 存	提 成	提 早	
提 足	提 防	提 供	提 供 方 便	提 供 有	提 供 者	提 供 優 質 服 務	提 到	
提 制	提 取	提 取 物	提 拔	提 法	提 花	提 前	提 前 完 成	
提 要	提 倡	提 倡 者	提 挈	提 案	提 案 人	提 留	提 神	
提 神 藥	提 純	提 純 復 壯	提 級	提 級 提 價	提 起	提 退	提 高	
提 高 工 作 效 率	提 高 生 活 水 平	提 高 生 產 率	提 高 技 術	提 高 效 益	提 高 效 率	提 高 產 量	提 高 勞 動 效 率	
提 高 認 識	提 高 質 量	提 高 覺 悟	提 高 警 惕	提 問	提 梁	提 桶	提 異 議	
提 貨	提 貨 單	提 單	提 壺	提 提	提 款	提 牌 執 戟	提 琴	
提 筆	提 給	提 著	提 詞	提 意 見	提 溜	提 煉	提 煉 廠	
提 督	提 補	提 資	提 綱	提 綱 挈 領	提 價	提 劍 汗 馬	提 審	
提 撥	提 箱	提 線 木 偶	提 談	提 請	提 調	提 燈	提 親	
提 選	提 醒	提 醒 物	提 醒 者	提 舉	提 薪	提 鍊	提 職	
提 職 提 薪	提 籃	提 議	提 議 者	提 攜	提 灌	握 力	握 手	
握 手 言 和	握 手 言 歡	握 手 極 歡	握 有	握 住	握 別	握 牢	握 法	
握 股	握 雨 攜 雲	握 持	握 炭 流 湯	握 風 捕 影	握 拳	握 拳 透 掌	握 蛇 騎 虎	
握 發 吐 哺	握 著	握 雲 拿 霧	握 雲 攜 雨	握 瑜 怪 玉	握 鉤 伸 鐵	握 圖 臨 宇	握 緊	
握 緊 拳 頭	握 綱 提 領	握 槧 懷 鉛	揖 拜	揖 讓	揭 下	揭 丑	揭 出	
揭 去	揭 示	揭 示 者	揭 批	揭 帖	揭 底	揭 穿	揭 竿	
揭 竿 而 起	揭 面 紗	揭 破	揭 起	揭 掉	揭 發	揭 發 者	揭 短	
揭 開	揭 開 戰 幔	揭 陽	揭 債 還 債	揭 幕	揭 榜	揭 曉	揭 露	
揭 露 者	揮 刀	揮 之	揮 之 即 去	揮 戈	揮 戈 反 日	揮 戈 回 日	揮 手	
揮 出	揮 斥	揮 汗	揮 汗 如 雨	揮 汗 成 雨	揮 兵	揮 別	揮 金	
揮 金 如 土	揮 軍	揮 拳	揮 動	揮 動 者	揮 毫	揮 淚	揮 發	
揮 發 性	揮 發 油	揮 發 物	揮 旗	揮 舞	揮 劍	揮 劍 成 河	揮 翰 成 風	
揮 翰 臨 池	揮 霍	揮 霍 一 空	揮 霍 者	揮 擊	揮 臂	揮 鞭	揮 灑	
揮 灑 自 如	捶 平	捶 打	捶 床 拍 枕	捶 床 搗 枕	捶 胸 迭 腳	捶 胸 跌 足	捶 胸 頓 足	
捶 胸 頓 腳	援 引	援 手	援 古 證 今	援 外	援 用	援 兵	援 助	
援 例	援 建	援 軍	援 救	援 救 者	援 筆 立 成	援 筆 成 章	援 筆 而 就	
援 溺 振 渴	揪 人 心 肺	揪 心	揪 心 扒 肝	揪 出	揪 打	揪 住	揪 著	
揪 辮 子	換 了	換 人	換 入	換 上	換 工	換 文	換 日 偷 天	
換 水	換 牙	換 代	換 代 產 品	換 出	換 句 話 說	換 用	換 向	
換 回	換 式	換 成	換 行	換 行 符	換 位	換 言 之	換 車	
換 防	換 取	換 季	換 屆	換 帖	換 性 者	換 房	換 版	
換 契	換 洗	換 面	換 頁	換 乘	換 個	換 氣	換 班	
換 骨 脫 胎	換 骨 奪 胎	換 崗	換 掉	換 票	換 船	換 貨	換 換	
換 湯	換 湯 不 換 藥	換 牌	換 筆	換 進	換 開	換 匯	換 新	
換 裝	換 幕	換 稱	換 算	換 領	換 樣	換 線	換 鞋 底	
換 擋	換 親	換 錢	換 檔	換 藥	換 證	換 茬	摒 棄	
揚 上	揚 子	揚 子 江	揚 己 露 才	揚 中	揚 手	揚 水	揚 名	
揚 名 後 世	揚 名 顯 姓	揚 名 顯 親	揚 州	揚 帆	揚 言	揚 谷	揚 林	
揚 花	揚 長	揚 長 而 去	揚 長 補 短	揚 長 避 短	揚 威	揚 威 耀 武	揚 眉	
揚 眉 吐 氣	揚 眉 抵 掌	揚 眉 奮 髯	揚 砂 走 石	揚 起	揚 棄	揚 清 抑 濁	揚 清 激 濁	
揚 揚	揚 揚 自 得	揚 揚 得 意	揚 智 科 技	揚 湯 止 沸	揚 琴	揚 程	揚 善	
揚 善 抑 惡	揚 葩 振 藻	揚 鈴 打 鼓	揚 旗	揚 嘴	揚 幡 招 魂	揚 幡 擂 鼓	揚 聲	
揚 聲 器	揚 鞭	揚 鑣	揚 鑣 分 路	揚 鑼 搗 鼓	敞 口	敞 車	敞 亮	
敞 胸	敞 著	敞 開	敞 開 供 應	敞 開 思 想	敞 蓬	敞 篷	敞 篷 車	
敞 露	敦 化	敦 世 厲 俗	敦 吉 科 技	敦 刻	敦 促	敦 促 者	敦 南 科 技	
敦 厚	敦 風 厲 俗	敦 首	敦 陽 科 技	敦 煌	敦 煌 石 窟	敦 實	敦 請	
敦 樸	敦 勸	敢 干	敢 不 敢	敢 打	敢 打 敢 拼	敢 死	敢 死 隊	
敢 作	敢 作 敢 為	敢 作 敢 當	敢 抓	敢 言	敢 於	敢 於 創 新	敢 保	
敢 勇 當 先	敢 怒	敢 怒 不 敢 言	敢 怒 而 不 敢 言	敢 為	敢 看	敢 做	敢 做 敢 為	
敢 做 敢 當	敢 問	敢 情	敢 開	敢 想	敢 想 敢 干	敢 當	敢 管	
敢 說	敢 講	散 了	散 工	散 心	散 文	散 文 式	散 文 家	
散 文 詩	散 文 體	散 出	散 去	散 失	散 失 殆 盡	散 伙	散 件	
散 光	散 曲	散 佈	散 佈 性	散 兵	散 兵 游 勇	散 步	散 步 場	
散 步 道	散 沙	散 居	散 股	散 客	散 架	散 射	散 記	
散 酒	散 帶 衡 門	散 粒	散 貨	散 場	散 悶 消 愁	散 發	散 裂	
散 開	散 亂	散 會	散 碎	散 落	散 裝	散 漫	散 管	
散 彈	散 彈 鎗	散 播	散 熱	散 熱 器	散 劑	散 戲	散 點 圖	
散 轉	散 攤	散 體	斑 木	斑 白	斑 竹	斑 色	斑 狀	
斑 疹	斑 紋	斑 蚊	斑 馬	斑 馬 線	斑 痕	斑 斑	斑 駁	
斑 駁 陸 離	斑 點	斑 雜	斑 斕	斐 然	斐 然 向 風	斐 然 成 章	斐 濟	
斐 濟 人	斯 人	斯 大 林	斯 文	斯 文 委 地	斯 文 掃 地	斯 市	斯 里 蘭 卡	
斯 事 體 大	斯 奈	斯 拉 維 尼 亞	斯 洛 文 尼 亞	斯 洛 伐 克	斯 洛 發 克	斯 哥	斯 時	
斯 斯 文 文	斯 裡 蘭 卡	斯 圖	斯 語	斯 德 哥 爾 摩	普 大 興 業	普 及	普 及 型	
普 及 教 育	普 及 率	普 及 讀 物	普 天	普 天 之 下	普 天 同 慶	普 立 爾	普 列	
普 安	普 托	普 米	普 考	普 希 金	普 定	普 林 斯 頓	普 法	
普 法 教 育	普 陀	普 度	普 查	普 降	普 降 大 雨	普 降 喜 雨	普 降 瑞 雪	
普 格	普 通	普 通 人	普 通 心 理 學	普 通 股	普 通 教 育	普 通 話	普 揚 資 訊	
普 普 通 通	普 渡	普 照	普 遍	普 遍 化	普 遍 存 在	普 遍 行	普 遍 性	
普 遍 真 理	普 遍 推 廣	普 遍 規 律	普 遍 意 義	普 遍 認 為	普 爾	普 調	普 魯 士	
普 魯 士 人	普 選	普 濟 眾 生	普 濟 群 生	普 蘭	晴 天	晴 天 霹 靂	晴 毛	
晴 空	晴 空 萬 里	晴 雨	晴 雨 表	晴 朗	晴 雲 秋 月	晴 暖	晴 綸	
晴 轉 多 雲	晶 內 偏 析	晶 化	晶 片	晶 石	晶 狀	晶 亮	晶 面	
晶 核	晶 格	晶 粒	晶 晶	晶 華 酒 店	晶 軸	晶 圓	晶 瑩	
晶 磊	晶 質	晶 巖	晶 體	晶 體 二 極 管	晶 體 三 極 管	晶 體 振 蕩 器	晶 體 管	
晶 硅	景 山	景 天	景 仰	景 色	景 況	景 物	景 星 鳳 皇	
景 星 慶 雲	景 星 麟 鳳	景 美	景 美 女 高	景 氣	景 氣 預 測	景 氣 對 策 信 號	景 泰	
景 泰 工 業	景 泰 藍	景 區	景 從 雲 集	景 深	景 象	景 像	景 德 鎮	
景 緻	景 點	景 觀	暑 天	暑 來 寒 往	暑 往 寒 來	暑 氣	暑 假	
暑 期	暑 熱	智 力	智 力 年 齡	智 力 投 資	智 力 開 發	智 力 競 賽	智 小 言 大	
智 小 謀 大	智 牙	智 巧	智 利	智 利 人	智 均 力 敵	智 育	智 邦 科 技	
智 取	智 性	智 昏	智 者	智 者 千 慮	智 者 千 慮 必 有 一 失	智 者 見 智	智 勇	
智 勇 兼 全	智 勇 雙 全	智 原 科 技	智 能	智 商	智 略	智 勝	智 圓 行 方	
智 愚	智 盡 能 索	智 慧	智 慧 財 產 權	智 窮	智 齒	智 謀	智 識	
智 寶 電 子	智 囊	智 囊 團	智 體	晾 衣	晾 乾	晾 曬	曾 予	
曾 以	曾 母 投 杼	曾 用	曾 用 名	曾 任	曾 向	曾 在	曾 安 田	
曾 有	曾 志 偉	曾 亞 君	曾 使	曾 到	曾 和	曾 則	曾 是	
曾 為	曾 孫	曾 祖	曾 祖 父	曾 祖 母	曾 做	曾 參 殺 人	曾 問	
曾 國 城	曾 將	曾 被	曾 傑 志	曾 幾 何 時	曾 無 與 二	曾 給	曾 經	
曾 經 滄 海	曾 對	曾 與	替 人	替 天 行 道	替 手	替 他	替 代	
替 代 役	替 代 性	替 代 物	替 代 品	替 古 人 耽 憂	替 古 人 擔 憂	替 她	替 死	
替 死 鬼	替 身	替 物	替 品	替 派	替 為	替 拿	替 班	
替 您	替 換	替 換 物	替 罪	替 罪 人	替 罪 羊	替 補	期 中	
期 內	期 月 有 成	期 以	期 刊	期 刊 目 錄	期 刊 流 通	期 刊 索 引	期 刊 管 理	
期 末	期 末 考	期 交 所	期 交 稅	期 收	期 考	期 於	期 初	
期 前	期 待	期 律	期 盼	期 約	期 限	期 限 內	期 借	
期 航	期 望	期 望 中	期 票	期 終	期 船	期 貨	期 貨 市 場	
期 貨 交 易 所	期 期	期 期 艾 艾	期 間	期 匯	期 會	期 滿	期 數	
期 頤 之 壽	期 欄	期 權	朝 三 暮 四	朝 下	朝 下 風	朝 上	朝 夕	
朝 夕 不 倦	朝 夕 相 處	朝 不 及 夕	朝 不 保 夕	朝 不 保 暮	朝 不 圖 夕	朝 不 慮 夕	朝 不 謀 夕	
朝 中	朝 內	朝 天	朝 天 宮	朝 日	朝 日 關 係	朝 他	朝 代	
朝 令 夕 改	朝 令 暮 改	朝 出 夕 改	朝 北	朝 右	朝 四 暮 三	朝 外	朝 左	
朝 生 暮 合	朝 生 暮 死	朝 向	朝 臣	朝 行 夕 改	朝 西	朝 西 暮 東	朝 廷	
朝 更 夕 改	朝 更 暮 改	朝 見	朝 來 暮 去	朝 服	朝 東	朝 東 暮 西	朝 花 夕 拾	
朝 前	朝 南	朝 後	朝 思 夕 計	朝 思 夕 想	朝 思 暮 想	朝 拜	朝 政	
朝 氣	朝 氣 蓬 勃	朝 秦 暮 楚	朝 貢	朝 乾 夕 惕	朝 參 暮 禮	朝 梁 暮 晉	朝 梁 暮 陳	
朝 野	朝 朝	朝 朝 寒 食 夜 夜 元 宵	朝 朝 暮 暮	朝 發 夕 至	朝 華 夕 秀	朝 著	朝 陽	
朝 陽 區	朝 雲 暮 雨	朝 暉	朝 經 暮 史	朝 聖	朝 聖 者	朝 裡	朝 過 夕 改	
朝 兢 夕 惕	朝 榮 夕 悴	朝 榮 夕 斃	朝 榮 暮 落	朝 歌 夜 弦	朝 歌 暮 弦	朝 綱	朝 聞 夕 死	
朝 聞 道 夕 死 可 矣	朝 暮	朝 遷 市 變	朝 霞	朝 鮮	朝 鮮 人	朝 鮮 半 島	朝 鮮 軍 隊	
朝 鮮 族	朝 鮮 語	朝 鮮 戰 爭	朝 覲	朝 鐘 暮 鼓	朝 露	朝 歡 暮 樂	朝 齏 暮 鹽	
棺 木	棺 材	棺 槨	棕 毛	棕 色	棕 刷	棕 絲	棕 熊	
棕 編	棕 櫚	棕 櫚 樹	棕 繩	棠 梨	棠 樹	棘 手	棘 爪	
棘 棗	棘 輪	棗 子	棗 泥	棗 紅	棗 莊	棗 樹	椅 上	
椅 子	椅 披	椅 背	椅 套	椅 墊	棟 折 榱 崩	棟 號	棟 樑	
棟 樑 之 材	棵 粒	棵 樹	森 巴 舞	森 林	森 林 法	森 林 學	森 喜 朗	
森 森	森 羅 萬 象	森 嚴	森 嚴 壁 壘	棧 山 航 海	棧 房	棧 道	棧 橋	
棒 了	棒 子	棒 打	棒 冰	棒 材	棒 協	棒 狀	棒 球	
棒 球 場	棒 球 運 動	棒 喝	棒 棒 糖	棒 槌	棒 毆	棒 鋼	棲 木	
棲 止	棲 身	棲 居	棲 所	棲 於	棲 枝	棲 息	棲 息 於	
棲 息 鳥	棲 棲	棲 霞	棋 士	棋 子	棋 手	棋 王	棋 布 星 羅	
棋 局	棋 車	棋 法	棋 社	棋 品	棋 迷	棋 高	棋 逢 對 手	
棋 聖	棋 盤	棋 盤 格	棋 壇	棋 壇 新 秀	棋 戰	棋 賽	棋 藝	
棋 譜	棋 類	棍 子	棍 杖	棍 兒	棍 棒	植 入	植 入 物	
植 土	植 林	植 物	植 物 人	植 物 性	植 物 油	植 物 保 護	植 物 病 毒	
植 物 莖	植 物 園	植 物 群 落	植 物 學	植 物 學 家	植 物 鹼	植 保	植 苗	
植 株	植 被	植 樹	植 樹 造 林	植 蟲 學	植 蟲 類	植 黨 營 私	植 體	
椒 江	椒 油	椒 鹽	椎 心 泣 血	椎 牛 饗 士	椎 骨	椎 輪 大 輅	椎 體	
棉 毛	棉 毛 衫	棉 毛 褲	棉 火 藥	棉 布	棉 瓦	棉 田	棉 白 糖	
棉 衣	棉 束	棉 制	棉 卷	棉 花	棉 花 糖	棉 籽	棉 紅 鈴 蟲	
棉 胎	棉 套	棉 桃	棉 紡	棉 紡 廠	棉 紡 織	棉 紡 織 廠	棉 紗	
棉 紙	棉 蚜	棉 區	棉 條	棉 球	棉 被	棉 麻	棉 帽	
棉 毯	棉 絨	棉 絮	棉 絲	棉 農	棉 鈴 蟲	棉 墊	棉 廠	
棉 線	棉 緞	棉 樹	棉 褲	棉 織	棉 織 品	棉 襖	棉 蘭	
棚 子	棚 內	棚 戶	棚 外	棚 布	棚 式 床	棚 車	棚 屋	
棚 架	棚 圈	棚 裡	款 人	款 子	款 以	款 冬	款 目	
款 式	款 曲	款 步	款 物	款 型	款 度	款 待	款 洽	
款 員	款 宴	款 留	款 級	款 啟 寡 聞	款 款	款 項	款 源	
款 語 溫 言	款 學 寡 聞	款 額	款 簿	款 識	款 贈	欺 人	欺 人 之 談	
欺 人 太 甚	欺 人 自 欺	欺 人 者	欺 三 瞞 四	欺 上 罔 下	欺 上 瞞 下	欺 上 壓 下	欺 大 壓 小	
欺 公 罔 法	欺 天 罔 人	欺 天 罔 地	欺 天 誑 地	欺 心	欺 世 罔 俗	欺 世 釣 譽	欺 世 惑 俗	
欺 世 惑 眾	欺 世 盜 名	欺 世 亂 俗	欺 主 罔 上	欺 生	欺 君	欺 君 罔 上	欺 君 誤 國	
欺 侮	欺 哄	欺 負	欺 凌	欺 軟	欺 軟 怕 硬	欺 硬 怕 軟	欺 善 怕 惡	
欺 詐	欺 蒙	欺 瞞	欺 瞞 夾 帳	欺 壓	欺 霜 傲 雪	欺 騙	欺 騙 性	
欺 騙 者	欺 騙 著	欽 仰	欽 州	欽 佩	欽 佩 莫 名	欽 命	欽 定	
欽 差	欽 差 大 臣	欽 慕	欽 賞	欽 賢 好 士	欽 賜	殘 山 剩 水	殘 月	
殘 片	殘 冬	殘 冬 臘 月	殘 民 以 逞	殘 民 害 物	殘 瓦	殘 生	殘 存	
殘 存 物	殘 年	殘 次	殘 兵	殘 兵 敗 將	殘 局	殘 忍	殘 忍 人	
殘 卷	殘 夜	殘 杯 冷 炙	殘 物	殘 肢	殘 花	殘 花 敗 柳	殘 品	
殘 垣 斷 壁	殘 春	殘 星	殘 毒	殘 秋	殘 紅	殘 虐	殘 軍 敗 將	
殘 值	殘 匪	殘 害	殘 席	殘 弱	殘 料	殘 根	殘 留	
殘 留 影 像	殘 疾	殘 疾 人	殘 疾 人 聯 合 會	殘 破	殘 缺	殘 缺 不 全	殘 茶 剩 飯	
殘 酒	殘 啞	殘 敗	殘 殺	殘 貨	殘 部	殘 章 斷 簡	殘 喘	
殘 渣	殘 渣 餘 孽	殘 湯 剩 飯	殘 發	殘 陽	殘 雲	殘 損	殘 暉	
殘 滓	殘 照	殘 跡	殘 像	殘 酷	殘 酷 鬥 爭	殘 酷 無 情	殘 障	
殘 障 津 貼	殘 障 團 體	殘 障 福 利 服 務 協 會	殘 障 聯 盟	殘 廢	殘 廢 軍 人	殘 敵	殘 暴	
殘 篇	殘 篇 斷 簡	殘 編 斷 簡	殘 餘	殘 餘 分 子	殘 餘 物	殘 餘 勢 力	殘 燈	
殘 積	殘 遺	殘 餚	殘 骸	殘 燭	殘 牆	殘 聯	殘 羹	
殘 羹 冷 炙	殘 羹 冷 飯	殘 羹 剩 飯	殖 民	殖 民 主 義	殖 民 地	殖 民 於	殖 民 者	
殖 民 統 治	殼 子	殼 斗	殼 貝	殼 兒	殼 狀	殼 蟲	毯 子	
毯 類	氮 化	氮 化 合	氮 化 物	氮 肥	氮 氣	氮 族	氯 乙 烯	
氯 乙 烷	氯 丁	氯 丹	氯 化	氯 化 亞 錫	氯 化 物	氯 化 苦	氯 化 氫	
氯 化 鈣	氯 化 鈉	氯 化 鉀	氯 化 銨	氯 化 鋅	氯 化 鋁	氯 化 磷	氯 化 鎂	
氯 化 鐵	氯 化 氰	氯 水	氯 仿	氯 苯	氯 氣	氯 綸	氯 酸	
氯 酸 鈉	氯 酸 鉀	氯 酸 鹽	氯 黴 素	港 九	港 口	港 口 城 市	港 口 碼 頭	
港 元	港 內	港 令	港 台	港 外	港 市	港 名	港 式 月 餅	
港 局	港 府	港 客	港 員	港 務	港 務 局	港 務 長	港 區	
港 商	港 域	港 埠	港 都	港 都 電 台	港 郵	港 督	港 資	
港 幣	港 澳	港 澳 工 委	港 澳 台	港 澳 同 胞	港 澳 辦	港 澳 辦 公 室	港 艦	
港 警	港 灣	港 汊	游 刃	游 刃 有 餘	游 弋	游 尺	游 心 寓 目	
游 心 騁 目	游 手	游 手 好 閒	游 水	游 水 器	游 去	游 目 騁 懷	游 走	
游 來	游 於	游 泳	游 泳 池	游 泳 衣	游 泳 者	游 神	游 素 蘭	
游 動	游 移	游 魚	游 魚 出 聽	游 絲	游 絲 飛 絮	游 雲 驚 龍	游 蜂 浪 蝶	
游 蜂 戲 蝶	游 資	游 過	游 標	游 標 尺	游 標 卡 尺	游 談 無 根	游 擊	
游 擊 隊	游 擊 隊 員	游 擊 戰	游 擊 戰 術	游 離	游 騎 兵	游 騎 無 歸	游 辭 浮 說	
渡 口	渡 江	渡 河	渡 河 香 象	渡 河 器 材	渡 海	渡 假	渡 船	
渡 船 業	渡 期	渡 費	渡 過	渡 槽	渡 輪	渡 橋	渲 染	
渲 赫	湧 了	湧 入	湧 上	湧 出	湧 去	湧 向	湧 回	
湧 至	湧 來	湧 到	湧 往	湧 泉	湧 流	湧 浪	湧 起	
湧 動	湧 現	湧 進	湊 了	湊 手	湊 出	湊 巧	湊 份 子	
湊 合	湊 成	湊 足	湊 到	湊 近	湊 效	湊 集	湊 齊	
湊 數	湊 熱	湊 趣	湊 興	湊 錢	渠 溝	渠 道	渠 縣	
渠 灌	渥 太 華	渣 土	渣 子	渣 打	渣 打 券	渣 打 銀 行	渣 油	
渣 堆	渣 塊	渣 滓	渣 爐	減 人	減 小	減 少	減 少 量	
減 支	減 方	減 半	減 去	減 份	減 刑	減 收	減 至	
減 色	減 低	減 免	減 免 稅	減 災	減 並	減 到	減 法	
減 肥	減 肥 法	減 勁	減 按	減 為	減 盈	減 省	減 胖	
減 食	減 值	減 借	減 員	減 弱	減 息	減 振	減 振 器	
減 料	減 租	減 租 減 息	減 納	減 退	減 除	減 掉	減 產	
減 速	減 速 傘	減 速 劑	減 速 器	減 幅	減 減	減 稅	減 量	
減 債	減 損	減 號	減 資	減 慢	減 盡	減 緊	減 輕	
減 輕 負 擔	減 價	減 撥	減 數	減 數 分 裂	減 緩	減 震	減 震 器	
減 壓	減 壓 閥	減 壓 器	減 縮	減 薪	減 虧	減 額	湛 江	
湛 藍	湘 江	湘 西	湘 軍	湘 潭	湘 繡	渤 海	渤 海 灣	
湖 人	湖 人 隊	湖 上	湖 口	湖 口 鄉	湖 內 鄉	湖 心	湖 水	
湖 北	湖 北 省	湖 田	湖 光	湖 光 山 色	湖 名	湖 州	湖 州 粽	
湖 色	湖 沼	湖 沼 學	湖 泊	湖 南	湖 南 省	湖 面	湖 畔	
湖 區	湖 筆	湖 裡	湖 澤	湖 濱	湖 邊	湖 灘	湮 沒	
湮 滅	湮 補	渭 水	渭 陽 之 思	渭 陽 之 情	渦 形	渦 形 物	渦 卷	
渦 流	渦 旋	渦 旋 形	渦 陽	渦 漩	渦 輪	渦 輪 機	渦 蟲	
湯 勺	湯 水	湯 加	湯 加 人	湯 包	湯 汁	湯 池	湯 池 鐵 城	
湯 志 偉	湯 姆 克 魯 斯	湯 姆 斯 盃	湯 姆 漢 克	湯 品	湯 料	湯 匙	湯 壺	
湯 湯	湯 飯	湯 園	湯 圓	湯 團	湯 瑪 斯	湯 盤	湯 劑	
湯 鍋	湯 藥	湯 麵	湯 蘭 花	湯 罐	渴 死	渴 求	渴 念	
渴 望	渴 望 著	渴 著	渴 想	渴 驥 奔 泉	湍 急	湍 流	湍 湍	
渺 小	渺 茫	渺 無 人 煙	渺 無 音 信	渺 虛	渺 視	測 力	測 力 計	
測 力 器	測 方	測 出	測 光	測 向	測 地 學	測 取	測 定	
測 定 法	測 知	測 度	測 音 計	測 音 器	測 容 量	測 徑 器	測 時	
測 時 法	測 時 器	測 氣 管	測 高	測 高 法	測 高 計	測 高 學	測 得	
測 控	測 探	測 斜 器	測 深	測 測	測 程 器	測 評	測 距	
測 距 儀	測 距 器	測 距 機	測 量	測 量 用	測 量 者	測 量 桿	測 量 術	
測 量 儀	測 雲 儀	測 微 尺	測 微 表	測 微 計	測 微 術	測 慌	測 溫	
測 溫 器	測 試	測 試 版	測 試 者	測 試 儀	測 過	測 電	測 算	
測 震 表	測 壓	測 壓 管	測 聲 器	測 謊 器	測 繪	測 繪 學	測 驗	
渾 人	渾 子	渾 水	渾 水 摸 魚	渾 名	渾 成	渾 江	渾 沌	
渾 身	渾 身 是 膽	渾 金 璞 玉	渾 俗 和 光	渾 厚	渾 蛋	渾 渾	渾 渾 噩 噩	
渾 然	渾 然 一 色	渾 然 一 體	渾 然 天 成	渾 圓	渾 號	渾 儀	渾 噩	
渾 樸	渾 濁	滋 生	滋 育	滋 事	滋 味	滋 長	滋 滋	
滋 補	滋 補 品	滋 補 劑	滋 潤	滋 蔓	滋 蔓 難 圖	滋 養	滋 養 物	
滋 養 品	滋 擾	渙 散	渙 然	湎 於	湄 公 河	湟 源	焙 烤	
焙 燒	焚 化	焚 化 爐	焚 如 之 禍	焚 舟 破 釜	焚 身	焚 林 之 求	焚 林 而 田	
焚 林 而 畋	焚 芝 鋤 蕙	焚 屍	焚 屍 揚 灰	焚 香	焚 香 頂 禮	焚 書	焚 書 坑 儒	
焚 骨 揚 灰	焚 琴 煮 鶴	焚 毀	焚 膏 繼 晷	焚 燒	焦 土	焦 化	焦 心	
焦 心 勞 思	焦 木	焦 比	焦 成	焦 耳	焦 作	焦 沙 爛 石	焦 灼	
焦 油	焦 炙	焦 金 流 石	焦 急	焦 枯	焦 炭	焦 乾	焦 痕	
焦 渴	焦 焦	焦 距	焦 飯	焦 黃	焦 黑	焦 煤	焦 碳	
焦 慮	焦 熬 投 石	焦 熱 電	焦 頭 爛 額	焦 點	焦 類 無 遺	焦 爐	焦 躁	
焰 心	焰 火	焰 狀	無 一	無 一 不 知	無 一 不 備	無 一 例 外	無 一 倖 免	
無 了 無 休	無 人	無 人 之 地	無 人 之 境	無 人 住	無 人 性	無 人 知 曉	無 人 區	
無 人 問 津	無 人 跡	無 人 過 問	無 力	無 力 氣	無 下 箸 處	無 上	無 口 才	
無 土	無 土 地	無 大 無 小	無 子	無 干	無 不	無 中 生 有	無 公	
無 公 約	無 分	無 分 別	無 匹	無 匹 配	無 及	無 反	無 反 響	
無 太	無 孔	無 孔 不 入	無 心	無 手	無 支	無 支 票	無 支 援	
無 文	無 方	無 方 之 民	無 日	無 日 期	無 月	無 止	無 止 境	
無 比	無 毛	無 水	無 水 物	無 父	無 王 牌	無 主	無 主 義	
無 以	無 以 自 容	無 以 為 生	無 以 復 加	無 以 塞 責	無 他	無 冬 無 夏	無 出 其 右	
無 功	無 功 功 率	無 功 而 祿	無 功 受 祿	無 包	無 可	無 可 不 可	無 可 比 象	
無 可 比 擬	無 可 如 何	無 可 否 認	無 可 奉 告	無 可 奈 何	無 可 奈 何 花 落 去	無 可 爭 辯	無 可 非 議	
無 可 厚 非	無 可 指 責	無 可 救 藥	無 可 無 不 可	無 可 置 疑	無 可 辯 駁	無 可 辯 辯	無 巧	
無 巧 不 成 書	無 巧 不 成 話	無 必 要	無 本 之 木	無 母	無 生	無 生 命	無 生 物	
無 生 氣	無 生 產	無 用	無 用 物	無 用 處	無 由	無 目	無 目 地	
無 目 的	無 立 足 之 地	無 立 錐 之 地	無 休	無 休 止	無 休 無 止	無 任	無 任 之 祿	
無 光	無 光 澤	無 先 例	無 印 良 品	無 印 痕	無 印 象	無 向	無 名	
無 名 小 卒	無 名 小 輩	無 名 氏	無 名 指	無 名 英 雄	無 名 孽 火	無 回 答	無 回 聲	
無 地 自 容	無 地 自 處	無 地 址	無 妄 之 災	無 妄 之 福	無 好	無 如 之 何	無 如 奈 何	
無 成	無 收 差	無 次 序	無 污 點	無 米 之 炊	無 自 信	無 色	無 色 菌	
無 血	無 血 色	無 血 氣	無 伴	無 伴 奏	無 佛 處 稱 尊	無 何	無 何 有 之 鄉	
無 伸	無 判	無 利	無 利 可 圖	無 利 益	無 助	無 助 於	無 吸	
無 妨	無 尿 症	無 尾 熊	無 序	無 形	無 形 中	無 形 化	無 形 狀	
無 形 無 影	無 形 損 耗	無 形 體	無 我	無 把 握	無 批	無 抑 制	無 改	
無 束 無 拘	無 束 縛	無 決	無 決 斷	無 災	無 私	無 私 心	無 私 有 弊	
無 私 奉 獻	無 私 無 畏	無 系 統	無 角	無 言	無 言 以 對	無 言 對 答	無 足	
無 足 重 輕	無 足 輕 重	無 邪	無 防 備	無 事	無 事 不 登 三 寶 殿	無 事 生 非	無 事 自 擾	
無 依	無 依 無 靠	無 侍 從	無 供 給	無 兒 女	無 受 限	無 味	無 味 道	
無 呼 吸	無 咎 無 譽	無 奇	無 奇 不 有	無 奈	無 奈 我 何	無 妻	無 委	
無 始 無 終	無 宗 派	無 宗 教	無 定	無 定 向	無 定 形	無 定 期	無 官 一 身 輕	
無 尚 光 榮	無 底	無 底 洞	無 底 稿	無 往 不 利	無 往 不 勝	無 征 不 信	無 怪	
無 性	無 性 生 殖	無 性 別	無 性 雜 交	無 或	無 房 戶	無 所	無 所 不 及	
無 所 不 包	無 所 不 可	無 所 不 用 其 極	無 所 不 在	無 所 不 有	無 所 不 至	無 所 不 知	無 所 不 為	
無 所 不 容	無 所 不 能	無 所 不 措 手 足	無 所 不 通	無 所 不 談	無 所 不 曉	無 所 用 心	無 所 作 為	
無 所 忌 憚	無 所 忌 諱	無 所 事 事	無 所 畏 忌	無 所 畏 懼	無 所 適 從	無 所 謂	無 所 屬	
無 所 顧 忌	無 所 顧 憚	無 抵	無 拘 束	無 拘 無 束	無 服 之 喪	無 服 之 殤	無 朋 友	
無 果	無 歧 視	無 法	無 法 無 天	無 爭	無 爭 異	無 爭 論	無 物	
無 的	無 的 放 矢	無 知	無 知 人	無 知 識	無 知 覺	無 空 不 入	無 空 間	
無 花	無 花 果	無 表	無 表 情	無 門	無 阻	無 阻 礙	無 非	
無 信	無 信 心	無 信 仰	無 保 留	無 保 證	無 前	無 前 因	無 前 例	
無 前 途	無 垠	無 威 嚴	無 幽 不 燭	無 度	無 後	無 後 為 大	無 後 嗣	
無 思 無 慮	無 思 想	無 怨 無 悔	無 指	無 政 府	無 政 府 主 義	無 政 府 狀 態	無 故	
無 是 無 非	無 毒	無 毒 不 丈 夫	無 毒 無 副 作 用	無 活 力	無 派	無 為	無 為 而 治	
無 為 自 化	無 畏	無 籽	無 紀 律	無 約 束	無 苦 惱	無 要	無 計 可 施	
無 計 劃	無 計 謀	無 軌	無 軌 電 車	無 重	無 重 力	無 重 音	無 重 量	
無 限	無 限 大	無 限 制	無 限 期	無 面	無 面 目 見 江 東 父 老	無 音	無 風	
無 風 三 尺 浪	無 風 不 起 浪	無 風 生 浪	無 風 起 浪	無 風 趣	無 首	無 原 則	無 員	
無 害	無 家	無 家 可 奔	無 家 可 歸	無 容	無 容 身 之 地	無 差	無 差 別	
無 師 自 通	無 恙	無 恥	無 恥 之 尤	無 恥 之 徒	無 恐 懼	無 息	無 息 貸 款	
無 悔	無 悔 意	無 拳 無 勇	無 效	無 效 力	無 效 果	無 效 能	無 效 率	
無 時	無 時 無 刻	無 時 間	無 核	無 核 區	無 案	無 根	無 根 之 木 無 源 之 水	
無 根 據	無 格 式	無 氣	無 氣 力	無 氣 孔	無 氣 味	無 特 色	無 特 徵	
無 特 權	無 疾	無 病	無 病 自 灸	無 病 呻 吟	無 益	無 神	無 神 論	
無 神 論 者	無 秩 序	無 級	無 缺	無 缺 點	無 脂	無 能	無 能 力	
無 能 為 力	無 能 為 役	無 記 名	無 記 名 投 票	無 記 錄	無 訓 練	無 骨	無 偽 裝	
無 偏 見	無 偏 無 陂	無 偏 無 倚	無 偏 無 黨	無 副 作 用	無 動 於 衷	無 動 靜	無 國 籍	
無 堅 不 陷	無 堅 不 摧	無 基 礎	無 奢 望	無 專 利	無 常	無 帳	無 庸	
無 庸 置 疑	無 庸 置 辯	無 庸 諱 言	無 得 分	無 得 無 喪	無 從	無 從 說 起	無 從 談 起	
無 情	無 情 無 緒	無 接 縫	無 措	無 掩 飾	無 教 育	無 教 養	無 旋 律	
無 望	無 條 件	無 條 理	無 涯	無 淚	無 牽 無 掛	無 猜	無 理	
無 理 方 程	無 理 由	無 理 取 鬧	無 理 性	無 理 數	無 現 金	無 產	無 產 者	
無 產 階 級	無 產 階 級 專 政	無 異	無 異 於	無 異 議	無 痕	無 痕 跡	無 疵	
無 眼	無 票	無 符 號	無 細	無 組 織	無 終	無 終 止	無 聊	
無 聊 乏 味	無 聊 事	無 莖	無 處	無 處 不 在	無 被	無 袖	無 袖 子	
無 規 則	無 訛	無 責	無 責 任	無 貨	無 連 絡	無 野 心	無 雪	
無 報 答	無 幾	無 復 孑 遺	無 惡 不 作	無 惡 意	無 提 供	無 援	無 期	
無 期 徒 刑	無 款	無 欺	無 殼	無 焦 點	無 痛	無 痛 苦	無 發 展 前 途	
無 稅	無 策	無 答 覆	無 結 果	無 絕	無 絲	無 著	無 菌	
無 虛 飾	無 視	無 詞	無 辜	無 量	無 間	無 間 斷	無 雲	
無 須	無 傾 角	無 傷 大 雅	無 傷 痕	無 嫌 疑	無 微 不 至	無 微 不 致	無 意	
無 意 中	無 意 之 中	無 意 間	無 意 義	無 意 識	無 感 情	無 感 覺	無 愛	
無 愧	無 愧 於	無 損	無 損 傷	無 暗 影	無 暇	無 業	無 業 人 員	
無 極	無 源 之 水	無 源 之 水 無 本 之 木	無 準 備	無 煙	無 煙 火 藥	無 煙 囪 工 業	無 煙 煤	
無 照	無 照 經 營	無 瑕	無 瑕 可 擊	無 瑕 疵	無 節 制	無 節 操	無 經 驗	
無 罪	無 義	無 腸 公 子	無 腳	無 虞	無 補	無 補 於 事	無 補 於 時	
無 裝 備	無 裝 飾	無 解	無 誠 意	無 話	無 話 不 說	無 話 不 談	無 話 可 說	
無 資 格	無 資 源	無 跡 可 尋	無 路	無 道	無 過	無 過 失	無 鉛	
無 預 謀	無 夢	無 實 效	無 實 質	無 對	無 對 手	無 疑	無 疑 問	
無 疑 慮	無 盡	無 盡 無 休	無 盡 無 窮	無 睡	無 端	無 精 打 采	無 精 打 彩	
無 精 卵	無 精 神	無 聞	無 與	無 與 為 比	無 與 倫 比	無 蓋	無 語	
無 誤	無 說	無 遠 見	無 隙 可 乘	無 障 礙	無 際	無 需	無 需 多 說	
無 領	無 價	無 價 之 寶	無 價 值	無 價 寶	無 層 次	無 彈 力	無 彈 性	
無 影	無 影 無 形	無 影 無 蹤	無 慮	無 慮 無 思	無 慮 無 憂	無 憂	無 憂 無 慮	
無 慾	無 敵	無 敵 於 天 下	無 數	無 數 字	無 標 頭	無 熱 光	無 稽	
無 稽 之 言	無 稽 之 談	無 窮	無 窮 大	無 窮 小	無 窮 無 盡	無 窮 盡	無 緣	
無 緣 無 故	無 線	無 線 通 信	無 線 電	無 線 電 台	無 線 電 波	無 線 電 通 信	無 線 電 報	
無 線 電 視	無 線 電 話	無 線 電 廠	無 論	無 論 如 何	無 論 何	無 論 是	無 趣	
無 趣 味	無 適	無 適 無 莫	無 遮 蓋	無 遮 蔽	無 靠	無 靠 無 依	無 鞍	
無 養 主	無 餘	無 駕	無 魅 力	無 學 問	無 憾	無 懈 可 擊	無 擔 保	
無 機	無 機 化 學	無 機 性	無 機 物	無 機 肥 料	無 機 鹽	無 獨 有 偶	無 興 趣	
無 親 托	無 親 戚	無 親 無 故	無 諱	無 謀	無 謂	無 賴	無 賴 漢	
無 選 擇	無 遺	無 遺 漏	無 錯	無 錯 誤	無 錢	無 錫	無 隨 伴	
無 靜 電	無 頭	無 頭 腦	無 償	無 償 援 助	無 儲	無 壓 力	無 幫 助	
無 擊	無 濟 於 事	無 營 養	無 牆 壁	無 療 效	無 縫	無 縫 鋼 管	無 翼	
無 翼 而 飛	無 翼 鳥	無 聲	無 聲 無 息	無 聯 繫	無 臂	無 膽 量	無 謊 不 成 媒	
無 隱 飾	無 霜	無 霜 期	無 歸	無 禮	無 禮 下 流	無 禮 取 鬧	無 禮 貌	
無 職 務	無 蹤	無 蹤 無 影	無 雙	無 顏	無 題	無 懷 疑	無 疆	
無 疆 之 休	無 礙	無 繩	無 繩 電 話	無 證	無 證 據	無 邊	無 邊 苦 海	
無 邊 風 月	無 邊 帽	無 邊 無 際	無 關	無 關 大 局	無 關 宏 旨	無 關 係	無 關 痛 癢	
無 關 緊 要	無 韻 律	無 癥 狀	無 繼	無 議	無 黨	無 黨 派	無 黨 派 人 士	
無 黨 派 民 主 人 士	無 黨 派 愛 國 人 士	無 黨 無 偏	無 辯	無 辯 護	無 顧 忌	無 權	無 權 無 勢	
無 權 過 問	無 髒 污	無 變 化	無 厘 頭	無 脛 而 行	無 ��	然 也	然 而	
然 則	然 後	然 糠 照 薪	煮 干	煮 出	煮 好	煮 成	煮 肉	
煮 豆 燃 萁	煮 沸	煮 得	煮 掉	煮 蛋	煮 粥 焚 須	煮 菜	煮 開	
煮 飯	煮 過	煮 滾	煮 熟	煮 熱	煮 鍋	煮 爛	煮 鶴 焚 琴	
牌 子	牌 名	牌 位	牌 坊	牌 局	牌 品	牌 桌	牌 匾	
牌 照	牌 照 稅	牌 號	牌 種	牌 價	牌 樓	牌 戲	犄 角	
犄 角 之 勢	犀 牛	犀 牛 望 月	犀 皮	犀 利	犀 角	猶 太	猶 太 人	
猶 太 史	猶 太 教	猶 太 復 國 主 義	猶 太 曆	猶 斗	猶 可	猶 在	猶 如	
猶 存	猶 自	猶 若	猶 魚 得 水	猶 猶 豫 豫	猶 新	猶 疑	猶 豫	
猶 豫 不 決	猶 豫 不 定	猶 豫 不 前	猶 豫 未 決	猥 瑣	猥 褻	猥 褻 行 為	猴 子	
猴 王	猴 年	猴 年 馬 月	猴 兒	猴 急	猴 精	猴 頭	猴 類	
猩 紅	猩 紅 熱	猩 猩	琺 琅	琪 花 瑤 草	琳 琅	琳 琅 滿 目	琢 玉 成 器	
琢 石	琢 磨	琢 磨 不 透	琥 珀	琥 珀 色	琥 珀 金	琵 琶	琵 琶 別 抱	
琴 弓	琴 之 若	琴 心 相 挑	琴 心 劍 膽	琴 手	琴 弦	琴 房	琴 者	
琴 架	琴 家	琴 師	琴 座	琴 馬	琴 棋 書 畫	琴 瑟	琴 瑟 不 調	
琴 瑟 失 調	琴 瑟 和 同	琴 瑟 和 諧	琴 瑟 相 調	琴 瑟 調 和	琴 劍 飄 零	琴 調	琴 聲	
琴 鍵	琴 斷 朱 弦	琨 詰	琨 詰 科 技	甥 女	甦 醒	甦 醒 劑	畫 了	
畫 下	畫 上	畫 工	畫 中 有 詩	畫 尺	畫 片	畫 冊	畫 出	
畫 刊	畫 史	畫 外	畫 外 音	畫 布	畫 本	畫 皮	畫 匠	
畫 地 成 圖	畫 地 而 趨	畫 地 為 牢	畫 地 為 獄	畫 成	畫 行	畫 兒	畫 具	
畫 到	畫 卷	畫 店	畫 押	畫 於	畫 板	畫 法	畫 的	
畫 虎 不 成 反 類 犬	畫 虎 不 成 反 類 狗	畫 虎 成 狗	畫 虎 類 犬	畫 品	畫 室	畫 架	畫 派	
畫 為	畫 界 線	畫 眉	畫 眉 張 敞	畫 眉 鳥	畫 眉 舉 案	畫 面	畫 頁	
畫 個 圓	畫 家	畫 展	畫 師	畫 框	畫 紙	畫 脂 鏤 冰	畫 舫	
畫 院	畫 圈	畫 得	畫 梁 雕 棟	畫 符	畫 蛇 添 足	畫 蛇 著 足	畫 陰 影	
畫 報	畫 幅	畫 廊	畫 棟 雕 梁	畫 畫	畫 策 設 謀	畫 筆	畫 著	
畫 開	畫 間	畫 意 詩 情	畫 像	畫 圖	畫 幕	畫 閣 朱 樓	畫 餅	
畫 餅 充 饑	畫 影 圖 形	畫 稿	畫 線	畫 線 器	畫 輪 廓	畫 壇	畫 瓢	
畫 龍 不 成 反 為 狗	畫 龍 點 睛	畫 謎	畫 譜	番 人	番 天 覆 地	番 木	番 瓜	
番 石 榴	番 邦	番 來 復 去	番 禺	番 茄	番 茄 湯	番 茄 醬	番 號	
番 薯	番 屬	痢 特 靈	痢 疾	痛 入 骨 髓	痛 不 欲 生	痛 不 堪 忍	痛 中	
痛 之 入 骨	痛 切	痛 切 心 骨	痛 心	痛 心 入 骨	痛 心 切 齒	痛 心 刻 骨	痛 心 泣 血	
痛 心 疾 首	痛 失	痛 失 良 機	痛 打	痛 斥	痛 成	痛 自	痛 快	
痛 快 淋 漓	痛 改 前 非	痛 定 思 痛	痛 抱 西 河	痛 恨	痛 苦	痛 風	痛 風 石	
痛 哭	痛 哭 失 聲	痛 哭 流 涕	痛 悔	痛 惜	痛 悼	痛 處	痛 責	
痛 惡	痛 痛 快 快	痛 飲	痛 飲 黃 龍	痛 感	痛 楚	痛 楚 徹 骨	痛 毀 前 非	
痛 毀 極 詆	痛 經	痛 話	痛 徹 心 肺	痛 徹 心 腑	痛 徹 骨 髓	痛 滌 前 非	痛 樣	
痛 毆	痛 罵	痛 擊	痛 懲	痛 癢	痛 癢 相 關	痛 覺	痙 攣	
痘 苗	痘 瘡	痘 瘢	痞 子	登 上	登 山	登 山 小 魯	登 山 杖	
登 山 家	登 山 涉 水	登 山 越 嶺	登 山 隊	登 山 運 動	登 山 臨 水	登 山 驀 嶺	登 天	
登 月	登 月 艙	登 出	登 台 拜 將	登 台 獻 藝	登 在	登 位	登 岸	
登 門	登 門 拜 訪	登 封	登 科	登 革 熱	登 乘	登 峰	登 峰 造 極	
登 級	登 記	登 記 冊	登 記 者	登 記 表	登 記 員	登 記 處	登 記 簿	
登 高	登 高 一 呼	登 高 自 卑	登 高 能 賦	登 基	登 堂 入 室	登 帳	登 船	
登 陸	登 陸 場	登 陸 艇	登 陸 艦	登 場	登 報	登 登	登 程	
登 載	登 廣	登 廣 告	登 樓	登 賬	登 壇 拜 將	登 機	登 機 口	
登 錄	登 錄 項	登 錄 檔	登 臨	登 攀	發 人 深 思	發 人 深 省	發 人 深 醒	
發 凡 舉 例	發 工 資	發 之	發 文	發 毛	發 水	發 火	發 令	
發 出	發 出 通 知	發 刊	發 刊 詞	發 包	發 卡	發 生	發 生 了	
發 生 中	發 生 去	發 生 地	發 生 於	發 生 率	發 生 器	發 白	發 光	
發 光 性	發 光 物	發 光 度	發 光 體	發 回	發 奸 摘 隱	發 尖	發 式	
發 成	發 汗	發 汗 室	發 自	發 自 內 心	發 至	發 行	發 行 人	
發 行 工 作	發 行 者	發 行 部	發 行 量	發 作	發 作 性	發 低	發 佈	
發 佈 者	發 佈 會	發 兵	發 冷	發 冷 光	發 否	發 呆	發 形	
發 抖	發 牢 騷	發 狂	發 狂 言	發 育	發 育 不 良	發 見	發 言	
發 言 人	發 言 者	發 言 稿	發 言 權	發 乳	發 事	發 來	發 函	
發 往	發 怔	發 怵	發 放	發 放 貸 款	發 明	發 明 人	發 明 物	
發 明 者	發 明 家	發 明 創 造	發 明 權	發 昏	發 昏 章 十 一	發 油	發 泡 劑	
發 炎	發 芽	發 表	發 表 文 章	發 表 意 見	發 表 談 話	發 表 聲 明	發 青	
發 亮	發 信	發 信 人	發 信 號	發 威	發 屋 求 狸	發 怒	發 急	
發 指	發 指 眥 裂	發 政 施 仁	發 柔	發 洩	發 洩 對 像	發 炮	發 狠	
發 紅	發 胖	發 面	發 音	發 音 法	發 套	發 家	發 家 致 富	
發 射	發 射 中	發 射 出	發 射 光 譜	發 射 成 功	發 射 物	發 射 者	發 射 場	
發 射 極	發 射 器	發 射 學	發 射 機	發 射 點	發 射 體	發 展	發 展 中	
發 展 中 國 家	發 展 史	發 展 商	發 料	發 案	發 案 率	發 病	發 病 率	
發 笑	發 脆	發 臭	發 財	發 財 了	發 起	發 起 人	發 起 書	
發 送	發 送 者	發 送 機	發 配	發 乾	發 偽 誓	發 動	發 動 攻 勢	
發 動 群 眾	發 動 機	發 問	發 問 者	發 售	發 情	發 情 期	發 悸	
發 掘	發 掉	發 條	發 球	發 球 者	發 現	發 現 物	發 現 者	
發 現 問 題	發 硎 新 試	發 祥	發 祥 地	發 票	發 貨	發 貨 人	發 軟	
發 野	發 麻	發 喊 連 天	發 喘	發 喪	發 報	發 報 人	發 報 機	
發 惡 臭	發 悶	發 愣	發 惱	發 揮	發 揚	發 揚 民 主	發 揚 光 大	
發 揚 成 績	發 揚 蹈 厲	發 揚 踔 厲	發 散	發 散 出	發 款 員	發 牌	發 牌 者	
發 短 心 長	發 硬	發 窘	發 策 決 科	發 紫	發 給	發 脹	發 脾 氣	
發 菜	發 黃	發 黑	發 愁	發 慌	發 楞	發 源	發 源 地	
發 煙	發 罩	發 落	發 號 出 令	發 號 布 令	發 號 施 令	發 解	發 話	
發 話 筒	發 跡	發 運	發 達	發 達 地 區	發 達 國 家	發 過 誓	發 電	
發 電 技 術	發 電 室	發 電 站	發 電 能 力	發 電 報	發 電 量	發 電 廠	發 電 機	
發 嘔	發 榜	發 槍	發 瘋	發 福	發 福 □	發 端	發 蒙	
發 蒙 振 落	發 蒙 振 聵	發 誓	發 酵	發 酵 了	發 酵 性	發 酵 法	發 酵 物	
發 酵 粉	發 酵 劑	發 酵 學	發 酸	發 餉	發 噓	發 嘶	發 憤	
發 憤 圖 強	發 熱	發 熱 量	發 熱 器	發 獎	發 獎 儀 式	發 稿	發 膠	
發 霉	發 奮	發 奮 忘 食	發 奮 圖 強	發 濁 音	發 燒	發 糕	發 膩	
發 踴 衝 冠	發 磷 光	發 縱 指 示	發 聲	發 聲 法	發 薪	發 薪 日	發 薪 水	
發 還	發 隱 摘 伏	發 藍	發 蹤 指 示	發 懵	發 癡	發 證	發 難	
發 願	發 癢	發 辮	發 覺	發 警 報	發 蠟	發 露	發 聾 振 聵	
發 顫	發 粘	發 痧	皖 北	皖 南	皖 南 事 變	皓 月	皓 首	
皓 首 蒼 顏	皓 首 窮 經	皓 齒	皓 齒 朱 唇	皓 齒 明 眸	皓 齒 星 眸	皓 齒 蛾 眉	皴 裂	
盜 犯	盜 用	盜 亦 有 道	盜 伐	盜 印	盜 名 欺 世	盜 汗	盜 劫	
盜 走	盜 取	盜 版	盜 屍	盜 屍 者	盜 怨 主 人	盜 匪	盜 案	
盜 馬	盜 掘	盜 船	盜 賊	盜 鈴	盜 鈴 掩 耳	盜 墓	盜 領	
盜 墳	盜 憎 主 人	盜 賣	盜 癖	盜 鐘 掩 耳	盜 竊	盜 竊 犯	盜 竊 案	
盜 竊 癖	睏 倦	短 了	短 刀	短 上 衣	短 大 衣	短 小	短 小 精 悍	
短 工	短 內 褲	短 少	短 文	短 斤 少 兩	短 欠	短 毛	短 片	
短 句	短 外 套	短 平 快	短 打	短 白 衣	短 收	短 衣	短 兵 相 接	
短 兵 接 戰	短 吻	短 局	短 尾 巴	短 尾 猴	短 尾 猿	短 杖	短 見	
短 角 牛	短 卷 髮	短 命	短 波	短 波 天 線	短 的	短 長	短 信	
短 促	短 垣 自 逾	短 柄	短 衫	短 音	短 音 符	短 音 階	短 時 間	
短 缺	短 缺 商 品	短 訊	短 訓 班	短 帷 幔	短 梗 飄 萍	短 梗 飄 蓬	短 淺	
短 笛	短 粗	短 統 靴	短 處	短 袖	短 途	短 途 運 輸	短 期	
短 期 內	短 期 行 為	短 期 計 劃	短 期 培 訓	短 棍	短 款	短 短	短 短 的	
短 短 幾 天	短 程	短 視	短 評	短 距 離	短 跑	短 傳	短 會	
短 煙 斗	短 矮	短 腮	短 腳	短 號	短 裙	短 裝	短 詩	
短 路	短 靴	短 壽 促 命	短 歌	短 腿	短 語	短 語 錄	短 說	
短 劇	短 劍	短 暫	短 樁	短 歎 長 吁	短 碼	短 篇	短 篇 小 說	
短 線	短 線 產 品	短 褐 不 全	短 褐 不 完	短 論	短 髮	短 褲	短 鋸	
短 簡	短 繩	短 羹 吹 齏	短 襪	短 纖 布	短 綆 汲 深	硝 化	硝 化 甘 油	
硝 石	硝 基	硝 基 苯	硝 煙	硝 煙 滾 滾	硝 煙 彈 雨	硝 煙 瀰 漫	硝 酸	
硝 酸 鈣	硝 酸 鈉	硝 酸 鉀	硝 酸 銨	硝 酸 鹽	硝 磺	硝 鹼	硝 鹽	
硝 胺	硬 了	硬 化	硬 化 症	硬 木	硬 毛	硬 水	硬 仗	
硬 功 夫	硬 卡	硬 皮	硬 件	硬 而	硬 扯	硬 邦 邦	硬 來	
硬 取	硬 性	硬 性 規 定	硬 性 攤 派	硬 拚	硬 拖	硬 的	硬 直	
硬 臥	硬 花	硬 度	硬 度 計	硬 拷 貝	硬 是	硬 派	硬 背	
硬 要	硬 面	硬 席	硬 挺	硬 朗	硬 氣	硬 紙	硬 紙 板	
硬 脂	硬 記	硬 骨	硬 骨 頭	硬 推	硬 掙	硬 梆 梆	硬 通 貨	
硬 頂	硬 棒	硬 殼	硬 殼 子	硬 硬	硬 筆	硬 結	硬 給	
硬 著	硬 著 陸	硬 著 頭 皮	硬 塊	硬 幹	硬 碰	硬 碰 硬	硬 逼	
硬 實	硬 幣	硬 幣 形	硬 漢	硬 漢 子	硬 碟	硬 碟 片	硬 碟 機	
硬 語 盤 空	硬 說	硬 領	硬 餅	硬 撐	硬 盤	硬 衝	硬 調	
硬 質	硬 質 合 金	硬 橡 皮	硬 橡 膠	硬 擠	硬 闖	硬 驅	硬 體	
硯 山	硯 台	稍 大	稍 小	稍 干	稍 不	稍 加	稍 可	
稍 平	稍 白	稍 多	稍 好	稍 尖	稍 早	稍 有	稍 老	
稍 作	稍 低	稍 快	稍 事	稍 知	稍 長	稍 後	稍 為	
稍 個 信	稍 候	稍 差	稍 息	稍 高	稍 帶	稍 許	稍 頃	
稍 勝 一 籌	稍 減	稍 短	稍 稍	稍 等	稍 嫌	稍 微	稍 暗	
稍 歇	稍 慢	稍 睡	稍 遜	稍 遜 一 籌	稍 寬	稍 緩	稍 懈	
稍 遲	稍 縱 即 逝	稍 舊	稈 莖	程 小 東	程 式	程 有 威	程 序	
程 序 上	程 序 表	程 序 員	程 序 控 制	程 序 設 計	程 序 語 言	程 門 立 雪	程 度	
程 度 不 同	程 建 人	程 控	程 控 交 換 機	程 控 電 話	程 控 機	程 潛	稅 人	
稅 戶	稅 目	稅 名	稅 式	稅 收	稅 收 收 入	稅 收 制 度	稅 收 政 策	
稅 收 理 論	稅 收 管 理	稅 利	稅 局	稅 改	稅 制	稅 官	稅 所	
稅 法	稅 盲	稅 金	稅 前	稅 則	稅 契	稅 後	稅 後 還 貸	
稅 政	稅 負	稅 員	稅 捐	稅 校	稅 務	稅 務 局	稅 務 所	
稅 務 員	稅 區	稅 基	稅 率	稅 票	稅 單	稅 款	稅 費	
稅 源	稅 號	稅 種	稅 管	稅 賦	稅 錢	稅 額	稅 類	
稅 警	稅 權	稀 土	稀 土 元 素	稀 土 金 屬	稀 少	稀 巴 爛	稀 世 之 寶	
稀 世 珍 寶	稀 有	稀 有 元 素	稀 有 金 屬	稀 罕	稀 奇	稀 奇 古 怪	稀 泥	
稀 客	稀 哩 嘩 啦	稀 缺	稀 疏	稀 稀	稀 稀 拉 拉	稀 稀 落 落	稀 粥	
稀 飯	稀 落	稀 裡 糊 塗	稀 薄	稀 鬆	稀 釋	稀 爛	稀 鹽 酸	
稀 粘 液	窘 地	窘 色	窘 住	窘 困	窘 促	窘 迫	窘 窈 蠊 テ	
窘 境	窘 態	窗 口	窗 子	窗 戶	窗 台	窗 外	窗 明	
窗 明 几 淨	窗 板	窗 花	窗 前	窗 洞	窗 玻 璃	窗 閂	窗 扇	
窗 旁	窗 框	窗 格	窗 紗	窗 側	窗 間 過 馬	窗 飾	窗 幔	
窗 蓋	窗 簾	窗 體	窗 欞	窖 子	窖 肥	窖 藏	童 女	
童 子	童 工	童 心	童 心 未 泯	童 牛 角 馬	童 生	童 年	童 年 期	
童 床	童 男	童 言 無 忌	童 車	童 服	童 玩 藝 術 節	童 星	童 貞	
童 軍	童 音	童 叟 無 欺	童 席	童 真	童 帽	童 稚	童 裝	
童 話	童 僕	童 語	童 鞋	童 養 媳	童 褲	童 聲	童 謠	
童 顏	童 顏 鶴 髮	童 難 童 女	童 襪	竣 工	等 一 等	等 一 會	等 一 會 兒	
等 了	等 人	等 力	等 上	等 中	等 之	等 分	等 日	
等 比	等 比 級 數	等 比 數	等 比 數 列	等 他	等 右	等 外	等 外 品	
等 用	等 份	等 同	等 同 性	等 地	等 在	等 式	等 次	
等 死	等 米 下 鍋	等 而 下 之	等 而 視 之	等 你	等 我	等 把	等 角	
等 車	等 到	等 於	等 於 零	等 侯	等 品	等 度	等 待	
等 面	等 倍	等 倍 數	等 值	等 候	等 差	等 差 數 列	等 效	
等 效 電 路	等 時	等 級	等 級 低	等 級 制	等 級 森 嚴	等 高	等 高 線	
等 國	等 得	等 貨	等 速	等 幅	等 幅 上 漲	等 等	等 著	
等 距	等 距 離	等 量	等 量 齊 觀	等 閒	等 閒 之 輩	等 閒 視 之	等 閒 觀 之	
等 勢	等 溫	等 溫 線	等 腰	等 腰 三 角 形	等 號	等 補	等 電 位	
等 價	等 價 交 換	等 價 物	等 寬	等 獎	等 機	等 壓	等 壓 線	
等 離 子	等 離 子 體	等 額	等 邊	等 邊 三 角 形	等 類	策 反	策 杖	
策 勉	策 馬	策 動	策 略	策 略 上	策 略 性	策 略 聯 盟	策 源 地	
策 劃	策 劃 了	策 劃 者	策 謀	策 應	筆 刀	筆 力	筆 下	
筆 下 超 生	筆 勾	筆 友	筆 心	筆 札	筆 伐	筆 名	筆 尖	
筆 式	筆 舌	筆 夾	筆 形	筆 走 龍 蛇	筆 供	筆 具	筆 底	
筆 法	筆 直	筆 者	筆 芯	筆 架	筆 風	筆 套	筆 挺	
筆 耕	筆 耕 不 輟	筆 記	筆 記 小 說	筆 記 本	筆 記 型 電 腦	筆 掃 千 軍	筆 桿	
筆 桿 子	筆 插	筆 畫	筆 筒	筆 答	筆 順	筆 勢	筆 意	
筆 會	筆 試	筆 資	筆 跡	筆 路	筆 劃	筆 端	筆 管	
筆 算	筆 誤	筆 寫	筆 談	筆 調	筆 鋒	筆 墨	筆 墨 官 司	
筆 戰	筆 翰 如 流	筆 錄	筆 頭	筆 觸	筆 譯	筐 子	筐 篋 中 物	
筒 子	筒 子 樓	筒 瓦	筒 似	筒 形	筒 紙	筒 褲	筒 襪	
答 中	答 允	答 出	答 式	答 兒	答 卷	答 非 所 問	答 拜	
答 案	答 記 者 問	答 問	答 理	答 訪	答 答	答 腔	答 詞	
答 話	答 詢	答 對	答 語	答 數	答 辨	答 錄	答 應	
答 聲	答 謝	答 謝 宴 會	答 禮	答 覆	答 題	答 辭	答 辯	
答 辯 狀	答 辯 者	答 讀 者 問	答 茬	筍 子	筍 瓜	筍 狀	筍 乾	
筍 雞	筋 肉	筋 疲 力 盡	筋 疲 力 竭	筋 脈	筋 骨	筋 圈	筋 絡	
筋 腱	筏 道	粟 米	粟 谷	粟 紅 貫 朽	粟 陳 貫 朽	粟 類	粥 少 僧 多	
粥 似	粥 狀	粥 粥 無 能	粥 樣	粥 麵	絞 人	絞 刀	絞 刑	
絞 刑 具	絞 刑 架	絞 合	絞 死	絞 肉	絞 衣 機	絞 扭	絞 車	
絞 架	絞 首	絞 索	絞 起	絞 接	絞 殺	絞 殺 者	絞 痛	
絞 絲	絞 碎	絞 盡 腦 汁	絞 盤	絞 縊	絞 鍊	絞 繩	絞 纏	
結 了	結 了 婚	結 下	結 子	結 仇	結 巴	結 欠	結 止	
結 水	結 付	結 出	結 平	結 石	結 石 病	結 交	結 冰	
結 合	結 合 力	結 合 水	結 合 者	結 合 律	結 合 能	結 合 實 際	結 合 體	
結 存	結 成	結 有	結 舌	結 舌 杜 口	結 伴	結 伴 而 行	結 余	
結 余 歸 己	結 局	結 尾	結 尾 辭	結 束	結 束 語	結 牢	結 果	
結 果 枝	結 果 是	結 物	結 社	結 怨	結 拜	結 為	結 界	
結 疤	結 凍	結 核	結 核 性	結 核 病	結 核 桿 菌	結 案	結 痂	
結 脈	結 草 懸 環	結 婚	結 婚 前	結 婚 後	結 婚 期	結 婚 登 記	結 婚 禮	
結 婚 證	結 帶	結 帳	結 彩	結 清	結 紮	結 紮 帶	結 紮 線	
結 單	結 喉	結 晶	結 晶 水	結 晶 狀	結 晶 學	結 晶 體	結 殼	
結 結	結 結 巴 巴	結 結 實 實	結 隊	結 集	結 匯	結 塊	結 業	
結 業 證 書	結 盟	結 節	結 義	結 腸	結 腸 炎	結 過	結 過 婚	
結 實	結 實 粗 壯	結 構	結 構 力 學	結 構 上	結 構 主 義	結 構 式	結 構 性	
結 構 物	結 構 蛋 白	結 構 設 計	結 構 圖	結 構 模 式	結 構 調 整	結 構 鋼	結 滿	
結 算	結 網	結 語	結 締 組 織	結 緣	結 膜	結 膜 炎	結 論	
結 論 性	結 賬	結 鄰	結 駟 聯 騎	結 髮	結 髮 夫 妻	結 親	結 環	
結 霜	結 點	結 轉	結 繩	結 繩 而 治	結 識	結 黨	結 黨 聚 群	
結 黨 營 私	結 黨 聯 群	結 露	絨 毛	絨 毛 似	絨 毛 狀	絨 毛 膜	絨 布	
絨 衣	絨 似	絨 狀	絨 的	絨 花	絨 面	絨 被	絨 鳥	
絨 帽	絨 毯	絨 絨	絨 絲 帶	絨 領	絨 線	絨 褲	絨 繡	
絨 類	絕 了	絕 人	絕 口	絕 口 不 提	絕 口 不 道	絕 大	絕 大 多 數	
絕 大 多 數 人	絕 大 部 分	絕 子 絕 孫	絕 才	絕 不	絕 不 止 於 此	絕 不 食 言	絕 不 會	
絕 仁 棄 義	絕 少 分 甘	絕 戶	絕 世	絕 世 出 塵	絕 世 佳 人	絕 世 無 倫	絕 世 無 雙	
絕 世 超 倫	絕 世 獨 立	絕 代	絕 代 佳 人	絕 句	絕 甘 分 少	絕 交	絕 地	
絕 色	絕 色 佳 人	絕 作	絕 妙	絕 妙 好 辭	絕 技	絕 育	絕 佳	
絕 命	絕 命 書	絕 念	絕 招	絕 法	絕 版	絕 的	絕 長 補 短	
絕 長 繼 短	絕 長 續 短	絕 非	絕 非 易 事	絕 俗 離 世	絕 品	絕 後	絕 後 光 前	
絕 活	絕 活 兒	絕 食	絕 倒	絕 倫	絕 徑	絕 氣	絕 症	
絕 配	絕 唱	絕 國 殊 俗	絕 域	絕 域 殊 方	絕 域 異 方	絕 密	絕 密 文 件	
絕 密 件	絕 情	絕 望	絕 粒	絕 處 逢 生	絕 頂	絕 景	絕 渡 逢 舟	
絕 無	絕 無 可 疑	絕 無 僅 有	絕 等	絕 筆	絕 嗣	絕 滅	絕 經 期	
絕 聖 棄 智	絕 詩	絕 跡	絕 路	絕 塵 拔 俗	絕 境	絕 對	絕 對 化	
絕 對 平 均 主 義	絕 對 民 主	絕 對 性	絕 對 值	絕 對 真 理	絕 對 溫 度	絕 對 溫 標	絕 對 零 度	
絕 對 誤 差	絕 對 數	絕 對 濕 度	絕 種	絕 熱	絕 緣	絕 緣 子	絕 緣 材 料	
絕 緣 紙	絕 緣 漆	絕 緣 體	絕 壁	絕 學	絕 糧	絕 藝	絕 響	
絕 裾 而 去	紫 丁 香	紫 水 晶	紫 外 線	紫 光	紫 色	紫 杉	紫 芝 眉 宇	
紫 花	紫 金	紫 金 山	紫 紅	紫 紅 色	紫 陌 紅 塵	紫 氣 東 來	紫 荊	
紫 袍 玉 帶	紫 雪 糕	紫 斑	紫 景 天	紫 菜	紫 貂	紫 雲	紫 雲 英	
紫 禁 城	紫 電 清 霜	紫 翠 玉	紫 銅	紫 緩 金 章	紫 檀	紫 穗 槐	紫 薇	
紫 藍	紫 羅	紫 羅 蘭	紫 藥 水	紫 籐	絮 叨	絮 狀	絮 球	
絮 棉	絮 絮	絮 絮 叨 叨	絮 語	絲 一 般	絲 工	絲 巾	絲 布	
絲 瓜	絲 光	絲 竹	絲 竹 管 弦	絲 竹 樂	絲 米	絲 束	絲 來 線 去	
絲 兒	絲 弦	絲 板	絲 狀	絲 狀 蟲	絲 恩 發 怨	絲 料	絲 紡	
絲 帶	絲 毫	絲 毫 不 懈	絲 球 體	絲 棉	絲 發 之 功	絲 絨	絲 絲	
絲 絲 入 扣	絲 稠	絲 路	絲 槓	絲 網	絲 綢	絲 綢 之 路	絲 綿	
絲 綿 似	絲 製 品	絲 線	絲 膠	絲 質	絲 糕	絲 錐	絲 聲	
絲 織	絲 織 品	絲 繡	絲 蟲	絲 蟲 病	絲 繩	絲 邊	絲 襪	
絡 合	絡 合 物	絡 狀	絡 絲	絡 腮	絡 腮 鬍 子	絡 酸 鹽	絡 線	
絡 繹	絡 繹 不 絕	給 了	給 予	給 水	給 水 保 障	給 水 器 材	給 以	
給 付	給 他	給 出	給 用 戶	給 吃	給 好	給 我	給 足	
給 定	給 於	給 物	給 的	給 穿	給 做	給 買	給 量	
給 話	給 與	給 與 者	給 誰	給 養	給 藥	絢 麗	絢 麗 多 姿	
絢 麗 多 彩	絢 爛	善 人	善 刀 而 藏	善 才	善 心	善 文	善 本	
善 用	善 任	善 有 善 報	善 自 為 謀	善 行	善 忘	善 男 信 女	善 良	
善 言	善 事	善 始 令 終	善 始 善 終	善 性	善 於	善 者	善 者 不 來	
善 長	善 門 難 開	善 哉	善 待	善 後	善 後 工 作	善 後 處 理	善 美	
善 書	善 氣 迎 人	善 理	善 終	善 報	善 惡	善 惡 不 辨	善 善 者 不 來	
善 善 從 長	善 善 惡 惡	善 意	善 感	善 解	善 解 人 意	善 賈 而 沽	善 道	
善 頌 善 禱	善 與 人 交	善 說	善 誘	善 寫	善 罷	善 罷 甘 休	善 談	
善 論	善 戰	善 舉	善 類	善 辯	善 辯 者	善 辯 家	善 變	
善 變 人	善 體	善 體 人 意	翔 實	翕 動	聒 噪	肅 反	肅 立	
肅 坐	肅 殺	肅 清	肅 然	肅 然 起 敬	肅 敬	肅 穆	肅 靜	
腕 力	腕 子	腕 足	腕 套	腕 骨	腕 帶	腕 部	腕 奪	
腕 錶	腕 關 節	腕 鐲	腔 調	腔 壁	腋 下	腋 內	腋 毛	
腋 芽	腋 臭	腋 窩	腑 版	腑 臟	腎 上	腎 上 腺	腎 炎	
腎 病	腎 結 石	腎 虛	腎 虧	腎 囊	腎 臟	腎 臟 病	脹 力	
脹 大	脹 氣	脹 破	脹 起	脹 脹	脹 裂	脹 滿	腆 然	
腆 著	腆 顏	脾 肉 之 歎	脾 性	脾 炎	脾 胃	脾 胃 相 投	脾 氣	
脾 氣 大	脾 氣 好	脾 氣 倔	脾 氣 暴 燥	脾 氣 壞	脾 病	脾 寒	脾 虛	
脾 腫 大	脾 臟	舒 心	舒 同	舒 坦	舒 服	舒 城	舒 展	
舒 泰	舒 張	舒 捲	舒 淇	舒 通	舒 筋 活 血	舒 舒 服 服	舒 暢	
舒 緩	舒 適	舒 懷	舒 蘭	舜 日 堯 天	舜 日 堯 年	菩 提	菩 提 樹	
菩 薩	菩 薩 心 腸	菩 薩 低 眉	萃 取	菸 草	萍 水	萍 水 相 逢	萍 水 相 遇	
萍 水 相 遭	萍 鄉	萍 蹤	萍 蹤 浪 跡	萍 蹤 浪 影	萍 蹤 梗 跡	萍 飄 蓬 轉	菠 菜	
菠 蘿	萋 風 冷 雨	萋 風 苦 雨	萋 斐 貝 錦	萋 萋	菁 英	華 人	華 山	
華 工	華 中	華 中 地 區	華 升 電 子	華 文	華 氏 囊	華 氏 囊 病	華 北	
華 北 地 區	華 立	華 宇 電 腦	華 成	華 池	華 而 不 實	華 西	華 佗	
華 沙	華 邦 電 子	華 固 建 設	華 坪	華 府	華 昕	華 昕 電 子	華 東	
華 東 地 區	華 東 軍 區	華 東 師 大	華 社	華 表	華 亭	華 信 銀 行	華 冑	
華 南	華 南 地 區	華 南 產 物	華 南 銀 行	華 城 電 機	華 封 三 祝	華 屋 丘 墟	華 約	
華 美	華 夏	華 夏 租 賃	華 夏 塑 膠	華 容	華 校	華 泰 電 子	華 泰 銀 行	
華 海	華 特 電 子	華 商	華 國 飯 店	華 埠	華 彩	華 教	華 族	
華 盛 頓	華 通 電 腦	華 陰	華 發	華 視	華 貴	華 隆	華 隆 公 司	
華 園 飯 店	華 廈	華 新 科	華 新 科 技	華 新 電 纜	華 經 資 訊	華 裔	華 裡	
華 達 呢	華 僑	華 僑 委 員 會	華 僑 狀 況	華 僑 銀 行	華 榮 電 纜	華 爾 茲	華 爾 茲 舞	
華 爾 滋	華 爾 街	華 碩 電 腦	華 蓋	華 語	華 豪 鶴 唳	華 誕	華 燈	
華 縣	華 豐 橡 膠	華 辭	華 麗	菱 生 精 密	菱 形	菱 形 窗	菱 角	
菱 面	菱 面 體	菱 鎂 礦	菱 鐵 礦	著 了 魔	著 力	著 手	著 手 成 春	
著 手 做	著 文	著 火	著 火 了	著 火 點	著 名	著 名 人 士	著 地	
著 帆	著 忙	著 有	著 有 成 效	著 色	著 色 於	著 色 液	著 色 劑	
著 衣	著 作	著 作 者	著 作 等 身	著 作 權	著 走	著 使	著 兒	
著 於	著 者	著 者 索 引	著 急	著 眉	著 看	著 述	著 述 等 身	
著 重	著 重 於	著 重 指	著 重 點	著 書	著 書 立 說	著 氣	著 迷	
著 涼	著 眼	著 眼 於	著 眼 點	著 陸	著 陸 器	著 棋	著 筆	
著 意	著 想	著 慌	著 落	著 裝	著 實	著 睡	著 稱	
著 談	著 墨	著 辦	著 錄	著 糞 佛 頭	著 臉	著 謎	著 魔	
萊 比 錫	萊 因 河	萊 州	萊 里	萊 茵 河	萌 生	萌 芽	萌 芽 林	
萌 動	萌 發	菌 力	菌 肥	菌 苗	菌 核	菌 株	菌 液	
菌 絲	菌 絲 體	菌 落	菌 種	菌 類	菌 體	菽 水 之 歡	菽 水 承 歡	
菲 才 寡 學	菲 衣 惡 食	菲 利 浦	菲 律 賓	菲 律 賓 人	菲 律 賓 首 都 銀 行	菲 律 賓 國	菲 食 卑 宮	
菲 食 薄 衣	菲 菲	菲 傭	菲 薄	菊 老 荷 枯	菊 花	菊 科	萎 黃 病	
萎 縮	萎 謝	萎 靡	萎 靡 不 振	萎 蔫	菜 刀	菜 子	菜 子 油	
菜 心	菜 牛	菜 市	菜 市 場	菜 瓜	菜 田	菜 地	菜 羊	
菜 色	菜 豆	菜 板	菜 芽	菜 花	菜 盆	菜 籽	菜 苔	
菜 圃	菜 根	菜 梗	菜 盒	菜 票	菜 販	菜 單	菜 單 項	
菜 場	菜 湯	菜 窖	菜 筐	菜 絲	菜 蛙	菜 園	菜 農	
菜 種	菜 價	菜 蔬	菜 館	菜 餚	菜 幫	菜 鍋	菜 藍	
菜 譜	菜 類	菜 籃	菜 籃 子	菜 攤	萇 弘 化 碧	虛 己 受 人	虛 予 委 蛇	
虛 化	虛 幻	虛 幻 飄 渺	虛 心	虛 文	虛 火	虛 付	虛 左 以 待	
虛 生 浪 死	虛 列	虛 名	虛 妄	虛 收	虛 有 其 表	虛 汗	虛 舟 飄 瓦	
虛 位	虛 位 以 待	虛 言	虛 往 實 歸	虛 空	虛 度	虛 度 年 華	虛 盈	
虛 胖	虛 席	虛 弱	虛 晃	虛 框	虛 浮	虛 症	虛 耗	
虛 偽	虛 假	虛 假 設	虛 張	虛 張 聲 勢	虛 情	虛 情 假 意	虛 掩	
虛 脫	虛 設	虛 報	虛 報 冒 領	虛 寒	虛 提	虛 減	虛 無	
虛 無 主 義	虛 無 縹 渺	虛 無 縹 緲	虛 無 飄 渺	虛 發	虛 虛 實 實	虛 詞	虛 象	
虛 損	虛 歲	虛 義	虛 腫	虛 誇	虛 話	虛 飾	虛 像	
虛 實	虛 榮	虛 榮 心	虛 構	虛 與 委 蛇	虛 價	虛 增	虛 數	
虛 線	虛 談 高 論	虛 論 高 議	虛 學	虛 應	虛 應 故 事	虛 擬	虛 擬 幻 覺	
虛 擬 世 界	虛 擬 實 境	虛 擬 網 路	虛 禮	虛 轉	虛 懷 若 谷	虛 辭	虛 驚	
蛟 河	蛟 龍	蛟 龍 得 水	蛙 人	蛙 泳	蛙 鼓	蛙 鳴	蛙 鞋	
蛙 類	蛔 蟲	蛛 形	蛛 絲	蛛 絲 馬 跡	蛛 絲 鼠 跡	蛛 絲 蟲 跡	蛛 網	
蛛 網 似	蛛 網 狀	蛛 網 塵 封	蛛 網 膜 下 腔 出 血	蛤 蟆	蛤 蟆 鏡	蛤 類	街 上	
街 心	街 市	街 名	街 坊	街 角	街 車	街 事	街 沿	
街 門	街 亭	街 巷 阡 陌	街 段	街 面	街 動	街 區	街 商	
街 部	街 場	街 景	街 號 巷 哭	街 道	街 道 辦 事 處	街 談	街 談 巷 說	
街 談 巷 議	街 燈	街 燈 柱	街 頭	街 頭 市 尾	街 頭 巷 尾	街 頭 巷 語	街 頭 標 貼	
街 戲	街 壘	街 邊	裁 人	裁 刀	裁 下	裁 成	裁 衣	
裁 兵	裁 判	裁 判 上	裁 判 工 作	裁 判 長	裁 判 員	裁 判 權	裁 決	
裁 決 人	裁 併	裁 定	裁 軍	裁 員	裁 紙	裁 剪	裁 剪 好	
裁 培	裁 掉	裁 處	裁 減	裁 開	裁 奪	裁 製	裁 縫	
裁 縫 師	裁 斷	裂 口	裂 化	裂 孔	裂 片	裂 成	裂 谷	
裂 紋	裂 痕	裂 開	裂 開 性	裂 傷	裂 溝	裂 煉	裂 解	
裂 圖 分 茅	裂 裳 裹 足	裂 裳 裹 膝	裂 隙	裂 齒 症	裂 縫	裂 聲	裂 變	
裂 眥 嚼 齒	視 人	視 人 如 子	視 人 如 傷	視 力	視 力 表	視 力 計	視 丹 如 綠	
視 之	視 之 不 見 聽 之 不 聞	視 孔	視 民 如 子	視 民 如 傷	視 同	視 同 兒 戲	視 同 若 歸	
視 同 秦 越	視 同 路 人	視 在 功 率	視 如	視 如 土 芥	視 如 草 芥	視 如 寇 仇	視 如 敝 履	
視 如 敝 屣	視 如 糞 土	視 死	視 死 如 生	視 死 如 飴	視 死 如 歸	視 而 不 見	視 而 弗 見 聽 而 弗 聞	
視 作	視 角	視 事	視 其	視 屏	視 為	視 為 畏 途	視 界	
視 若 兒 戲	視 若 無 睹	視 若 路 人	視 准 儀	視 哨	視 差	視 神 經	視 訊	
視 唱	視 域	視 情 況 而 定	視 野	視 場	視 景	視 程	視 窗	
視 象	視 距	視 距 儀	視 塔	視 微 知 著	視 感	視 圖	視 察	
視 察 工 作	視 察 員	視 網 膜	視 網 膜 剝 離	視 需 要 而 定	視 盤	視 線	視 導	
視 險 如 夷	視 險 若 夷	視 頻	視 檢	視 點	視 鏡	視 覺	視 覺 上	
視 覺 型	視 覺 器 官	視 聽	視 聽 覺	註 冊	註 明	註 腳	註 銷	
註 釋	詠 唱	詠 唱 調	詠 敘 唱	詠 雪 之 慧	詠 詩	詠 歌	詠 歎	
詠 贊	評 工	評 介	評 分	評 分 數	評 比	評 出	評 功	
評 估	評 估 器	評 判	評 判 人	評 判 員	評 委	評 委 會	評 定	
評 析	評 注	評 法	評 為	評 述	評 書	評 核	評 級	
評 脈	評 記	評 理	評 測	評 等	評 量	評 傳	評 聘	
評 解	評 話	評 語	評 說	評 價	評 價 人	評 價 者	評 價 高	
評 劇	評 審	評 審 員	評 彈	評 模	評 獎	評 論	評 論 文	
評 論 員	評 論 員 文 章	評 論 家	評 閱	評 選	評 選 活 動	評 頭 品 足	評 頭 論 足	
評 優	評 戲	評 點	評 斷	評 議	評 議 員	評 鑑	評 鑒	
詞 人	詞 干	詞 不 達 意	詞 中	詞 中 選 字	詞 化	詞 文	詞 令	
詞 句	詞 曲	詞 作	詞 尾	詞 序	詞 形	詞 兒	詞 典	
詞 性	詞 法	詞 表	詞 律	詞 派	詞 首	詞 庫	詞 書	
詞 根	詞 海	詞 素	詞 條	詞 清 訟 簡	詞 組	詞 章	詞 無 枝 葉	
詞 牌	詞 華 典 瞻	詞 集	詞 彙	詞 彙 表	詞 彙 學	詞 意	詞 源	
詞 義	詞 話	詞 態	詞 綴	詞 語	詞 窮 理 屈	詞 窮 理 絕	詞 窮 理 盡	
詞 調	詞 賦	詞 鋒	詞 學	詞 選	詞 頻	詞 頭	詞 譜	
詞 韻	詞 類	詞 嚴 義 正	詞 嚴 義 密	詞 藻	詞 讓	詔 令	詔 示	
詔 安	詔 書	詔 諭	詛 咒	詐 死	詐 取	詐 取 者	詐 取 豪 奪	
詐 降	詐 財	詐 啞 佯 聾	詐 唬	詐 婚	詐 敗 佯 輸	詐 術	詐 欺	
詐 欺 者	詐 欺 案	詐 稱	詐 語	詐 賭	詐 謀 奇 計	詐 騙	詐 騙 犯	
詐 騙 者	詐 騙 集 團	詆 毀	訴 人	訴 不 盡	訴 之 於	訴 求	訴 狀	
訴 苦	訴 冤	訴 訟	訴 訟 人	訴 訟 中	訴 訟 法	訴 訟 權	訴 說	
訴 諸	訴 諸 於	訴 諸 武 力	訴 願 人	診 心 之 論	診 所	診 治	診 室	
診 病	診 脈	診 療	診 療 所	診 斷	診 斷 書	診 斷 試 劑	訶 子	
象 小	象 山	象 不	象 之	象 牙	象 牙 之 塔	象 牙 制	象 牙 海 岸	
象 牙 質	象 只	象 年	象 形	象 形 文 字	象 形 字	象 活	象 看	
象 限	象 限 儀	象 紙	象 將	象 被	象 棋	象 箸 玉 杯	象 鼻	
象 鼻 蟲	象 徵	象 徵 化	象 徵 性	象 徵 派	象 徵 學	象 蝸 牛	象 齒 焚 身	
象 學	象 頭	象 聲 詞	象 蟲	貂 不 足 狗 尾 續	貂 皮	貂 裘 換 酒	貂 鼠	
貂 蟬	貯 水	貯 水 池	貯 水 量	貯 水 器	貯 存	貯 液 器	貯 備	
貯 窖	貯 運	貯 藏	貯 藏 所	貯 藏 物	貯 藏 室	貯 藏 處	貯 藏 箱	
貯 藏 器	貼 了	貼 入	貼 上	貼 切	貼 心	貼 心 人	貼 出	
貼 用	貼 在	貼 好	貼 耳	貼 足	貼 身	貼 服	貼 花	
貼 近	貼 金	貼 附	貼 息	貼 息 貸 款	貼 紙	貼 接	貼 率	
貼 現	貼 現 率	貼 處	貼 換	貼 畫	貼 著	貼 補	貼 滿	
貼 廣 告	貼 標 籤	貼 靠	貼 錢	貼 縫	貼 題	貼 邊	貽 人	
貽 人 口 實	貽 貝	貽 范 古 今	貽 害	貽 害 無 窮	貽 笑 千 秋	貽 笑 大 方	貽 笑 萬 世	
貽 厥 孫 謀	貽 誤	貽 誤 軍 機	貽 誚 多 方	貽 燕 之 訓	賁 門	費 力	費 力 勞 心	
費 工	費 心	費 心 勞 力	費 加 羅	費 玉 清	費 用	費 里 尼	費 事	
費 勁	費 品 率	費 城	費 時	費 時 間	費 氣	費 神	費 財 勞 民	
費 掉	費 率	費 率 調 降	費 絲 希 爾	費 翔	費 解	費 電	費 盡	
費 盡 心 血	費 盡 心 機	費 縣	費 錢	賀 一 航	賀 片	賀 卡	賀 年	
賀 年 片	賀 年 卡	賀 函	賀 帖	賀 信	賀 客	賀 喜	賀 詞	
賀 歲	賀 誠	賀 電	賀 龍	賀 禮	賀 蘭	貴 乃 花	貴 人	
貴 人 多 忘	貴 人 多 事	貴 子	貴 不 可 言	貴 不 凌 賤	貴 公 司	貴 方	貴 刊	
貴 古 賤 今	貴 台	貴 地	貴 在	貴 妃	貴 州	貴 州 省	貴 池	
貴 耳 賤 目	貴 局	貴 姓	貴 定	貴 庚	貴 府	貴 所	貴 的	
貴 金 屬	貴 客	貴 為	貴 省	貴 重	貴 重 物 品	貴 校	貴 站	
貴 院	貴 鬥 力	貴 國	貴 婦	貴 婦 人	貴 戚	貴 族	貴 族 式	
貴 族 似	貴 族 般	貴 處	貴 單 位	貴 無 常 尊	貴 陽	貴 陽 市	貴 極 人 臣	
貴 賓	貴 賓 席	貴 遠 鄙 近	貴 遠 賤 近	貴 廠	貴 德	貴 賤	貴 賤 高 低	
貴 賤 無 二	貴 賤 無 常	貴 顯	貴 體	買 了	買 入	買 入 價	買 下	
買 方	買 方 市 場	買 牛 賣 劍	買 主	買 去	買 它	買 光	買 回	
買 好	買 成	買 臣 覆 水	買 走	買 些	買 來	買 到	買 定	
買 房	買 東 西	買 的	買 空	買 空 賣 空	買 者	買 面 子	買 個	
買 家	買 書	買 笑 追 歡	買 起	買 馬 招 軍	買 帳	買 張	買 得	
買 得 到	買 票	買 貨	買 通	買 單	買 給	買 菜 求 益	買 超	
買 超 排 行	買 進	買 價	買 盤	買 賬	買 賣	買 賣 人	買 賣 方	
買 賣 婚 姻	買 賣 雙 方	買 輛	買 辦	買 點	買 斷	買 櫝 還 珠	買 關 節	
貶 斥	貶 低	貶 抑	貶 值	貶 責	貶 逐	貶 詞	貶 損	
貶 義	貶 義 詞	貶 落	貶 黜	貶 職	貶 謫	貿 易	貿 易 口 岸	
貿 易 公 司	貿 易 市 場	貿 易 赤 字	貿 易 協 定	貿 易 法	貿 易 界	貿 易 逆 差	貿 易 商	
貿 易 量	貿 易 順 差	貿 易 談 判	貿 易 額	貿 易 關 係	貿 促 會	貿 然	貿 貿 然	
貸 入	貸 方	貸 放	貸 借	貸 記	貸 款	貸 款 人	貸 減	
貸 給	貸 資	貸 幣	貸 增	越 大	越 小	越 不	越 少	
越 冬	越 冬 作 物	越 出	越 加	越 古 超 今	越 共	越 多	越 好	
越 有	越 次 超 論	越 次 躐 等	越 位	越 快	越 快 越 好	越 來	越 來 越	
越 來 越 大	越 來 越 小	越 來 越 少	越 來 越 多	越 來 越 好	越 長	越 俎 代 庖	越 南	
越 南 人	越 南 語	越 是	越 洋	越 洋 電 話	越 界	越 看	越 要	
越 軌	越 重	越 差	越 海	越 級	越 高	越 淺	越 深	
越 累	越 野	越 野 吉 普 車	越 野 吉 普 車 賽	越 野 車	越 野 賽	越 野 賽 跑	越 陷 越 深	
越 鳥 南 棲	越 發	越 過	越 雷 池 一 步	越 境	越 境 者	越 慢	越 獄	
越 障	越 劇	越 線	越 戰	越 牆	越 權	越 鳧 楚 乙	超 人	
超 人 一 等	超 凡	超 凡 入 聖	超 凡 出 世	超 凡 脫 俗	超 大 國	超 大 規 模	超 小 型	
超 小 型 化	超 小 型 品	超 今 冠 古	超 今 絕 古	超 今 越 古	超 心 理 學	超 支	超 水 平	
超 世 之 才	超 世 拔 俗	超 世 絕 俗	超 世 絕 倫	超 乎	超 乎 尋 常	超 以 象 外	超 出	
超 外 差	超 市	超 生	超 再 生	超 合 金	超 收	超 自 我	超 自 然	
超 自 然 力	超 行	超 位	超 低 空	超 低 溫	超 技	超 車	超 卓 人 士	
超 物 質	超 俗	超 俗 絕 世	超 前	超 前 絕 後	超 度	超 流 體	超 負 荷	
超 重	超 限	超 音	超 音 波	超 音 波 學	超 音 速	超 音 速 飛 機	超 音 速 隊	
超 值	超 員	超 庫	超 時	超 時 間	超 消 費	超 特 快	超 級	
超 級 大 國	超 級 公 路	超 級 文 本	超 級 市 場	超 級 男 孩	超 級 客 機	超 級 終 端	超 級 電 腦	
超 級 鍊 接	超 高	超 高 溫	超 高 頻	超 高 壓	超 假	超 假 不 歸	超 商	
超 常	超 強	超 敏 性	超 現 代	超 現 代 化	超 產	超 產 獎 勵	超 脫	
超 速	超 速 行 駛	超 速 駕 駛	超 循 環 論	超 期	超 期 服 役	超 然	超 然 不 群	
超 然 自 引	超 然 自 得	超 然 物 外	超 然 絕 俗	超 然 像 外	超 然 遠 引	超 然 遠 舉	超 然 獨 立	
超 然 邁 倫	超 短	超 短 波	超 短 裙	超 短 篇	超 等	超 絕	超 視	
超 貸	超 越	超 越 函 數	超 超 玄 著	超 軸	超 軼 絕 塵	超 逸 絕 塵	超 量	
超 階 級	超 階 越 次	超 集	超 塑 性	超 微	超 微 結 構	超 感	超 感 覺	
超 想	超 群	超 群 出 眾	超 群 拔 類	超 群 越 輩	超 群 軼 類	超 載	超 過	
超 塵 出 俗	超 塵 拔 俗	超 標	超 標 準	超 編	超 導	超 導 體	超 儲	
超 壓	超 聲	超 聲 波	超 聲 波 學	超 聲 速	超 薄	超 薄 型	超 購	
超 邁 絕 倫	超 濾 體	超 豐 電 子	超 額	超 額 利 潤	超 額 完 成	超 繳	超 類 絕 倫	
超 齡	超 顯 微 術	超 顯 微 鏡	超 靈	趁 心 如 意	趁 火 打 劫	趁 火 搶 劫	趁 他	
趁 早	趁 此 機 會	趁 我	趁 波 逐 浪	趁 空	趁 便	趁 時	趁 浪 逐 波	
趁 著	趁 虛	趁 虛 而 入	趁 勢	趁 勢 落 篷	趁 熱	趁 熱 打 鐵	趁 機	
距 今	距 離	距 離 差	跋 山 涉 川	跋 山 涉 水	跋 文	跋 來 報 往	跋 前 躓 後	
跋 涉	跋 涉 山 川	跋 涉 長 途	跋 扈	跋 扈 自 恣	跋 扈 飛 揚	跋 語	跑 了	
跑 下	跑 反	跑 出	跑 去	跑 外	跑 向	跑 回	跑 在	
跑 完	跑 快	跑 步	跑 步 者	跑 走	跑 車	跑 來	跑 來 跑 去	
跑 到	跑 表	跑 面	跑 差	跑 氣	跑 馬	跑 馬 場	跑 馬 觀 花	
跑 動	跑 啦	跑 堂	跑 得	跑 掉	跑 單 幫	跑 場	跑 著	
跑 街	跑 跑	跑 進	跑 開	跑 開 者	跑 圓 場	跑 源 建 設	跑 路	
跑 道	跑 過	跑 遍	跑 腿	跑 鞋	跑 龍 套	跑 題	跌 入	
跌 下	跌 打	跌 交	跌 死	跌 到	跌 狗 吠 堯	跌 倒	跌 破	
跌 幅	跌 跌 撞 撞	跌 進	跌 傷	跌 勢	跌 碎	跌 腳 捶 胸	跌 落	
跌 跤	跌 價	跌 蕩 不 羈	跌 鱉 千 里	跌 宕 不 羈	跌 宕 昭 彰	跌 宕 遒 麗	跛 子	
跛 行	跛 行 症	跛 足	跛 腳	跛 腿	跛 鱉 千 里	跆 拳	跆 拳 道	
跆 拳 道 錦 標 賽	軸 上	軸 孔	軸 心	軸 心 國	軸 瓦	軸 形	軸 承	
軸 狀	軸 架	軸 流 泵	軸 套	軸 距	軸 對 稱	軸 箱	軸 線	
軸 擋	軸 襯	軸 轤 千 里	軼 事	軼 群 絕 類	軼 話	軼 聞	軼 類 超 群	
辜 成 允	辜 負	辜 恩 背 義	辜 恩 負 義	辜 振 甫	辜 濂 松	逮 住	逮 到	
逮 捕	逮 捕 法 辦	逮 捕 者	逮 捕 證	週 刊	週 末	週 年	週 而 復 始	
週 身	週 報	週 期	週 期 函 數	週 期 性	週 期 律	週 歲	週 遭	
週 轉 率	逸 世 超 群	逸 以 待 勞	逸 出	逸 史	逸 民	逸 事	逸 居	
逸 游 自 恣	逸 群 之 才	逸 群 絕 倫	逸 態 橫 生	逸 聞	逸 聞 軼 事	逸 樂	逸 興 遄 飛	
逸 離	進 一 步	進 一 步 說	進 一 層	進 了	進 入	進 入 者	進 刀	
進 口	進 口 商	進 口 商 品	進 口 國	進 口 貨	進 口 稅	進 口 量	進 口 額	
進 士	進 寸 退 尺	進 山	進 不 去	進 中	進 化	進 化 論	進 午 餐	
進 尺	進 水	進 出	進 出 口	進 出 口 公 司	進 出 境	進 去	進 可 替 不	
進 可 替 否	進 犯	進 早 餐	進 而	進 而 言 之	進 而 講	進 行	進 行 中	
進 行 曲	進 行 批 評	進 行 改 革	進 行 到 底	進 行 研 究	進 行 教 育	進 行 著	進 行 談 判	
進 行 檢 查	進 位	進 佔	進 兵	進 攻	進 攻 性	進 攻 者	進 步	
進 步 人 士	進 步 力 量	進 步 事 業	進 見	進 言	進 身	進 身 之 階	進 京	
進 來	進 來 者	進 到	進 制	進 取	進 取 心	進 取 性	進 取 精 神	
進 抵	進 法	進 者	進 門	進 城	進 屋	進 度	進 度 表	
進 洞	進 軍	進 軍 西 藏	進 軍 號	進 食	進 香	進 香 客	進 香 團	
進 修	進 修 生	進 修 班	進 宮	進 展	進 料	進 氣 口	進 站	
進 紙	進 貢	進 退	進 退 存 亡	進 退 有 常	進 退 兩 難	進 退 首 鼠	進 退 無 門	
進 退 無 路	進 退 無 據	進 退 維 谷	進 酒	進 帳	進 得 去	進 深	進 貨	
進 場	進 款	進 港	進 發	進 程	進 給	進 給 量	進 進 出 出	
進 階	進 項	進 逼	進 價	進 廠	進 德 修 業	進 線	進 賬	
進 賢	進 賢 任 能	進 銷	進 銳 退 速	進 駐	進 餐	進 擊	逶 迤	
鄂 西	郵 冊	郵 出	郵 包	郵 市	郵 本	郵 件	郵 局	
郵 車	郵 亭	郵 政	郵 政 史	郵 政 局	郵 政 劃 撥	郵 政 編 碼	郵 展	
郵 差	郵 區	郵 寄	郵 寄 者	郵 票	郵 船	郵 袋	郵 報	
郵 筒	郵 費	郵 集	郵 匯	郵 匯 局	郵 資	郵 資 已 付	郵 路	
郵 運	郵 電	郵 電 局	郵 電 通 信	郵 電 部	郵 電 業	郵 遞	郵 遞 員	
郵 戮	郵 碼	郵 箱	郵 箱 名	郵 編	郵 輪	郵 儲 基 金	郵 購	
郵 戳	郵 癖	郵 簡	鄉 下	鄉 下 人	鄉 下 佬	鄉 土	鄉 土 氣	
鄉 土 氣 息	鄉 土 觀 念	鄉 公 所	鄉 友	鄉 巴 佬	鄉 代 表	鄉 代 會	鄉 民	
鄉 地	鄉 曲	鄉 曲 之 譽	鄉 村	鄉 村 式	鄉 村 音 樂	鄉 里	鄉 長	
鄉 俗	鄉 勇	鄉 城	鄉 思	鄉 政 府	鄉 音	鄉 風 慕 義	鄉 級	
鄉 區	鄉 紳	鄉 規 民 約	鄉 野	鄉 郵	鄉 鄉	鄉 間	鄉 幹 部	
鄉 愁	鄉 團	鄉 誼	鄉 賢	鄉 鄰	鄉 親	鄉 親 們	鄉 辦	
鄉 鎮	鄉 鎮 代 表 會	鄉 鎮 市 代 表	鄉 鎮 企 業	鄉 鎮 企 業 局	鄉 鎮 社 區	鄉 鎮 經 濟	酣 形	
酣 眠	酣 絮	酣 夢	酣 態	酣 暢	酣 暢 淋 漓	酣 歌 恆 舞	酣 睡	
酣 嬉 淋 漓	酣 醉	酣 戰	酣 興	酥 松	酥 油	酥 脆	酥 胸	
酥 軟	酥 麻	酥 餅	酥 糖	量 人	量 入 為 出	量 力	量 力 而 行	
量 力 而 為	量 大	量 子	量 子 力 學	量 小	量 小 力 微	量 才 錄 用	量 化	
量 尺	量 比	量 出	量 出 制 入	量 刑	量 多	量 好	量 如 江 海	
量 角 規	量 角 器	量 身	量 具	量 性	量 杯	量 法	量 油 計	
量 表	量 度	量 計	量 重	量 限	量 值	量 差	量 時 度 力	
量 氣 計	量 級	量 控	量 深 度	量 瓶	量 規	量 販 店	量 販 倉 儲	
量 程	量 等	量 筒	量 詞	量 過	量 綱	量 熱 器	量 器	
量 衡	量 變	量 體 裁 衣	鈔 票	鈕 扣	鈕 扣 孔	鈕 扣 狀	鈕 承 澤	
鈣 化	鈣 片	鈣 質	鈣 鎂 磷 肥	鈣 巖	鈉 鹽	鈞 啟	鈞 鑒	
鈍 化	鈍 形	鈍 角	鈍 音	鈍 傷	鈍 態	鈍 齒	鈍 器	
鈍 頭 劍	閏 日	閏 月	閏 年	閏 音	開 了	開 二 次	開 入	
開 刀	開 上	開 刃	開 口	開 口 子	開 大	開 小	開 小 差	
開 山	開 山 老 祖	開 山 祖 師	開 工	開 工 典 禮	開 工 率	開 弓	開 元	
開 化	開 天 窗	開 天 闢 地	開 孔	開 心	開 心 見 誠	開 戶	開 戶 行	
開 戶 銀 行	開 支	開 方	開 水	開 火	開 仗	開 出	開 去	
開 外	開 市	開 平	開 打	開 本	開 白 條	開 立	開 伙	
開 伐	開 列	開 向	開 合 鑼 鼓	開 年	開 年 以 來	開 局	開 快	
開 快 車	開 戒	開 汽 車	開 走	開 足	開 足 馬 力	開 車	開 來	
開 到	開 卷	開 卷 有 益	開 卷 有 得	開 卷 考 試	開 味	開 夜 車	開 始	
開 始 時	開 始 實 行	開 宗 明 義	開 店	開 往	開 房	開 拓	開 拓 者	
開 拓 型	開 拓 創 新	開 拓 精 神	開 拔	開 拍	開 放	開 放 市 場	開 放 地 區	
開 放 地 帶	開 放 系 統	開 放 城 市	開 於	開 明	開 明 人 士	開 河	開 物 成 務	
開 玩 笑	開 花	開 花 期	開 花 結 果	開 花 結 實	開 初	開 金	開 金 礦	
開 門	開 門 見 山	開 門 見 喜	開 門 紅	開 門 揖 盜	開 門 辦 學	開 亮 了	開 信	
開 城	開 封	開 屏	開 後 門	開 挖	開 春	開 架	開 洋	
開 洋 葷	開 洞	開 炮	開 胃	開 胃 菜	開 赴	開 革	開 倒 車	
開 個	開 原	開 展	開 席	開 庭	開 恩	開 朗	開 班	
開 缺	開 航	開 荒	開 起	開 除	開 除 黨 籍	開 動	開 區	
開 國	開 國 大 典	開 國 元 勳	開 埠	開 帳	開 張	開 掘	開 採	
開 採 權	開 啟	開 球	開 眼	開 票	開 票 人	開 脫	開 脫 罪 責	
開 船	開 處	開 處 方	開 設	開 通	開 閉	開 傘	開 創	
開 創 局 面	開 創 性	開 創 者	開 創 新 局 面	開 場	開 場 白	開 場 鑼 鼓	開 敞	
開 普 敦	開 渠	開 發	開 發 中 心	開 發 公 司	開 發 利 用	開 發 者	開 發 區	
開 發 部	開 發 費	開 發 資 源	開 窗	開 窗 口	開 窗 法	開 給	開 腔	
開 著	開 裂	開 進	開 開	開 雲 見 日	開 飯	開 飲 機	開 會	
開 會 討 論	開 業	開 業 典 禮	開 業 者	開 歲	開 源	開 源 節 流	開 溝	
開 溜	開 禁	開 罪	開 葷	開 誠	開 誠 佈 公	開 誠 相 見	開 路	
開 路 人	開 路 先 鋒	開 路 機	開 運 河	開 道	開 過	開 遍	開 閘	
開 閘 放 水	開 電	開 幕	開 幕 式	開 幕 典 禮	開 幕 詞	開 慢	開 槍	
開 演	開 端	開 端 者	開 綻	開 綠 燈	開 蓋	開 價	開 徵	
開 播	開 標	開 槽	開 獎	開 盤	開 篇	開 篇 伊 始	開 膛	
開 課	開 銷	開 墾	開 學	開 導	開 戰	開 機	開 燈	
開 辦	開 頭	開 館	開 縫	開 講	開 賽	開 鍋	開 闊	
開 闊 地	開 闊 眼 界	開 齋	開 齋 節	開 擴	開 竅	開 鎖	開 顏	
開 懷	開 懷 大 笑	開 懷 暢 飲	開 疆	開 羅	開 藥	開 襟	開 證	
開 邊	開 關	開 爐	開 礦	開 釋	開 鐮	開 闢	開 闢 通 路	
開 罐	開 罐 器	開 鑽	開 鑼	開 鑿	開 鑿 者	開 坯	間 不 容 息	
間 不 容 髮	間 中	間 內	間 日	間 有	間 而	間 作	間 低	
間 或	間 的	間 奏	間 柱	間 架	間 苗	間 時	間 做	
間 接	間 接 稅	間 接 調 控	間 發 性	間 距	間 歇	間 腦	間 裡	
間 道	間 隔	間 隔 性	間 種	間 隙	間 層	間 數	間 質	
間 壁	間 諜	間 諜 活 動	間 諜 罪	間 諜 衛 星	間 諜 戰	間 斷	間 雜	
間 續	閒 人	閒 工	閒 不 住	閒 心	閒 日	閒 民	閒 地	
閒 坐	閒 扯	閒 言	閒 言 碎 語	閒 邪 存 誠	閒 事	閒 來	閒 來 無 事	
閒 官	閒 居	閒 空	閒 花 野 草	閒 差	閒 差 事	閒 庭	閒 時	
閒 書	閒 神 野 鬼	閒 常	閒 得	閒 情	閒 情 逸 緻	閒 情 逸 趣	閒 棄	
閒 混	閒 聊	閒 聊 天	閒 逛	閒 散	閒 著	閒 雲 孤 鶴	閒 雲 野 鶴	
閒 愁	閒 暇	閒 置	閒 置 不 用	閒 話	閒 遊	閒 遐	閒 漢	
閒 語	閒 誑	閒 篇	閒 談	閒 談 者	閒 適	閒 蕩	閒 錢	
閒 職	閒 雜	閒 雜 人 員	閒 雜 人 等	閎 中 肆 外	隊 中	隊 友	隊 日	
隊 伍	隊 列	隊 列 訓 練	隊 名	隊 式	隊 別	隊 形	隊 花	
隊 長	隊 員	隊 部	隊 隊	隊 裡	隊 旗	隊 歌	隊 徽	
隊 禮	隊 醫	階 下	階 下 囚	階 石	階 段	階 段 性	階 段 劃 分	
階 乘	階 級	階 級 性	階 級 鬥 爭	階 梯	階 梯 式	階 梯 狀	階 層	
階 數	隋 代	隋 唐	隋 朝	陽 九 之 會	陽 文	陽 台	陽 台 雲 雨	
陽 布	陽 光	陽 光 明 媚	陽 光 計 劃	陽 光 普 照	陽 具	陽 奉 陰 違	陽 性	
陽 明 海 運	陽 板	陽 物	陽 物 像	陽 信 商 銀	陽 城	陽 春	陽 春 白 雪	
陽 春 有 腳	陽 面	陽 氣	陽 起 石	陽 傘	陽 萎	陽 虛	陽 間	
陽 極	陽 痿	陽 痿 藥	陽 電	陽 電 子	陽 壽	陽 儒 陰 釋	陽 歷	
陽 離 子	陽 關	陽 關 大 道	陽 關 道	隅 石	隆 大 營 造	隆 化	隆 冬	
隆 古 賤 今	隆 刑 峻 法	隆 回	隆 乳	隆 林	隆 重	隆 重 推 出	隆 重 慶 祝	
隆 准	隆 恩	隆 恩 曠 典	隆 起	隆 盛	隆 隆	隆 隆 聲	隆 隆 響	
隆 鼻	隆 聲	隆 響	雁 北	雁 去 魚 來	雁 叫 聲	雁 行	雁 杳 魚 沉	
雁 塔	雁 塔 題 名	雁 過 拔 毛	雁 鳴	雁 影 分 飛	雅 人	雅 人 深 致	雅 士	
雅 片	雅 加 達	雅 地	雅 江	雅 而 不 俗	雅 言	雅 典	雅 典 娜	
雅 虎	雅 俗 共 賞	雅 座	雅 教	雅 量	雅 新 實 業	雅 號	雅 詩 蘭 黛	
雅 馴	雅 爾 塔	雅 稱	雅 語	雅 緻	雅 趣	雅 興	雅 鑒	
雅 觀	雄 才	雄 才 大 略	雄 才 偉 略	雄 心	雄 心 壯 志	雄 心 勃 勃	雄 火 雞	
雄 兵	雄 壯	雄 材 大 略	雄 居	雄 性	雄 性 不 育	雄 性 化	雄 的	
雄 糾 糾	雄 花	雄 勁	雄 厚	雄 姿	雄 姿 英 發	雄 威	雄 赳 赳	
雄 風	雄 飛 突 進	雄 師	雄 師 百 萬	雄 偉	雄 健	雄 略	雄 鹿	
雄 渾	雄 視 一 世	雄 黃	雄 蜂	雄 圖	雄 雌	雄 器	雄 據	
雄 蕊	雄 辨	雄 雞	雄 雞 斷 尾	雄 獸	雄 關	雄 辯	雄 辯 家	
雄 辯 高 談	雄 辯 術	雄 霸	雄 鷹	集 上	集 大 成	集 子	集 中	
集 中 力 量	集 中 化	集 中 市 場	集 中 地	集 中 兵 力	集 中 性	集 中 於	集 中 精 力	
集 中 營	集 日	集 市	集 市 貿 易	集 合	集 合 詞	集 合 點	集 合 體	
集 在	集 安	集 成	集 成 度	集 成 電 路	集 束	集 束 式	集 材	
集 居	集 注	集 思	集 思 廣 益	集 約	集 約 化	集 約 經 營	集 苑 集 枯	
集 納	集 訓	集 訓 隊	集 盛 實 業	集 場	集 散	集 散 地	集 結	
集 結 待 命	集 腋 成 裘	集 貿 市 場	集 郵	集 郵 本	集 郵 家	集 郵 癖	集 集	
集 會	集 會 結 社	集 會 遊 行	集 群	集 裝	集 裝 箱	集 資	集 電 極	
集 團	集 團 公 司	集 團 作 業	集 團 股	集 團 軍	集 寧	集 聚	集 數	
集 線 器	集 賢	集 螢 映 雪	集 錄	集 錦	集 鎮	集 攏	集 權	
集 體	集 體 化	集 體 主 義	集 體 所 有 制	集 體 舞	雇 人	雇 工	雇 役	
雇 車	雇 來	雇 農	雇 請	雲 一 樣	雲 山	雲 山 霧 罩	雲 中	
雲 天	雲 天 高 義	雲 外	雲 母	雲 合 霧 集	雲 朵	雲 行 雨 施	雲 杉	
雲 車 風 馬	雲 林	雲 林 縣 長	雲 泥 異 路	雲 狀	雲 狀 物	雲 的	雲 雨	
雲 雨 巫 山	雲 雨 高 唐	雲 南	雲 南 省	雲 英	雲 氣	雲 消 霧 散	雲 海	
雲 浮	雲 豹	雲 起 龍 驤	雲 高 計	雲 彩	雲 梯	雲 淡 風 輕	雲 雀	
雲 散	雲 散 了	雲 散 風 流	雲 斯 頓 賽 車	雲 程 發 軔	雲 程 萬 里	雲 貴	雲 開 見 日	
雲 階 月 地	雲 集	雲 塊	雲 煙	雲 煙 過 眼	雲 遊	雲 遊 四 方	雲 團	
雲 圖	雲 夢	雲 端	雲 蒸 霞 蔚	雲 隙	雲 層	雲 遮 霧 障	雲 霄	
雲 興 霞 蔚	雲 錦	雲 龍 風 虎	雲 霞	雲 譎 波 詭	雲 霧	雲 靄	雲 觀	
韌 皮	韌 性	韌 度	韌 帶	項 下	項 內	項 目	項 目 表	
項 羽	項 背	項 背 相 望	項 級	項 圈	項 莊 舞 劍 意 在 沛 公	項 飾	項 數	
項 鍊	順 人 者 昌 逆 人 者 亡	順 人 應 天	順 口	順 口 開 河	順 口 溜	順 口 談 天	順 大 裕	
順 之 者 成 逆 之 者 敗	順 之 者 昌 逆 之 者 亡	順 化	順 天	順 天 者 存 逆 天 者 亡	順 天 者 昌 逆 天 者 亡	順 天 者 逸 逆 天 者 勞	順 天 建 設	
順 天 恤 民	順 天 應 人	順 天 應 命	順 天 應 時	順 心	順 手	順 手 推 舟	順 手 牽 羊	
順 水	順 水 人 情	順 水 行 舟	順 水 推 舟	順 水 推 船	順 乎	順 乎 民 心	順 乎 自 然	
順 民	順 列	順 向	順 旨	順 次	順 耳	順 串	順 利	
順 利 完 成	順 利 性	順 利 發 展	順 利 進 行	順 利 實 現	順 序	順 我 者 生 逆 我 者 死	順 我 者 吉 逆 我 者 衰	
順 我 者 昌	順 我 者 昌 逆 我 者 亡	順 其 自 然	順 命	順 延	順 性	順 承	順 治	
順 便	順 流	順 流 而 下	順 風	順 風 耳	順 風 吹 火	順 風 扯 旗	順 風 駛 帆	
順 風 駛 船	順 風 轉 舵	順 差	順 息 萬 變	順 時	順 時 針	順 帶	順 從	
順 理 成 章	順 產	順 眼	順 著	順 順 噹 噹	順 勢	順 溜	順 當	
順 腳	順 路	順 道	順 道 者 昌 逆 德 者 亡	順 遂	順 境	順 暢	順 嘴	
順 德	順 德 工 業	順 德 者 吉 逆 天 者 兇	順 德 者 昌 逆 德 者 亡	順 適	順 駛	順 導	順 應	
順 應 性	順 應 潮 流	順 豐	順 轉	順 籐 摸 瓜	順 籐 模 瓜	須 公	須 毛	
須 用	須 由	須 申 報	須 向	須 在	須 有	須 作	須 到	
須 知	須 臾	須 按	須 持	須 要	須 送	須 將	須 得	
須 報	須 經	須 彌	飯 勺	飯 合	飯 坑 酒 囊	飯 局	飯 來	
飯 來 開 口	飯 店	飯 前	飯 後	飯 後 酒	飯 食	飯 島 直 子	飯 時	
飯 桌	飯 匙	飯 桶	飯 盒	飯 票	飯 粒	飯 莊	飯 袋	
飯 菜	飯 費	飯 量	飯 碗	飯 團	飯 蔬 飲 水	飯 錢	飯 館	
飯 鍋	飯 鏟	飯 囊	飯 囊 衣 架	飯 囊 酒 甕	飯 廳	飯 舖	飯 糗 茹 草	
飲 下	飲 水	飲 水 曲 肱	飲 水 知 源	飲 水 思 源	飲 水 食 菽	飲 水 啜 菽	飲 用	
飲 用 水	飲 冰 食 檗	飲 冰 茹 檗	飲 灰 洗 胃	飲 血	飲 血 茹 毛	飲 泣	飲 河 滿 腹	
飲 者	飲 品	飲 恨	飲 恨 而 終	飲 恨 吞 聲	飲 流 懷 源	飲 風 餐 露	飲 食	
飲 食 男 女	飲 食 店	飲 食 起 居	飲 食 業	飲 宴	飲 料	飲 氣 吞 聲	飲 茶	
飲 酒	飲 酒 癖	飲 馬	飲 馬 投 錢	飲 淚	飲 湯	飲 過 量	飲 鳩 止 渴	
飲 彈	飲 醇 自 醉	飲 鴆 止 渴	飲 露 餐 風	飭 令	馮 恩	黃 乙 玲	黃 了	
黃 口 小 兒	黃 口 孺 子	黃 土	黃 土 地	黃 土 高 原	黃 大 煒	黃 小 楨	黃 山	
黃 文 豪	黃 毛	黃 毛 丫 頭	黃 水	黃 水 仙	黃 水 晶	黃 牛	黃 冊	
黃 包 車	黃 平 洋	黃 玉	黃 瓜	黃 白	黃 皮 書	黃 石	黃 任 中	
黃 州	黃 曲 霉	黃 江	黃 灰 色	黃 羊	黃 色	黃 色 人 種	黃 色 書 刊	
黃 沙	黃 豆	黃 卷 青 燈	黃 宗 宏	黃 岡	黃 昆 輝	黃 明 川	黃 昏	
黃 昏 時	黃 泥	黃 河	黃 河 故 道	黃 河 流 域	黃 油	黃 的	黃 花	
黃 花 晚 節	黃 花 魚	黃 金	黃 金 市 場	黃 金 季 節	黃 金 時 代	黃 金 價 格	黃 信 介	
黃 俊 中	黃 帝	黃 春 明	黃 枯	黃 柏	黃 泉	黃 秋 生	黃 頁	
黃 原 菌	黃 埔	黃 埔 同 學 會	黃 埔 江	黃 浦	黃 浦 江	黃 海	黃 疸	
黃 疸 病	黃 紙	黃 酒	黃 教	黃 梁 一 夢	黃 梁 夢	黃 梅	黃 梅 戲	
黃 淮	黃 袍	黃 袍 加 身	黃 袍 加 體	黃 連	黃 連 素	黃 陵	黃 雀	
黃 雀 伺 蟬	黃 雀 銜 環	黃 魚	黃 麻	黃 斑	黃 湯	黃 牌	黃 牌 警 告	
黃 發 鮐 背	黃 童 白 叟	黃 童 皓 首	黃 菊	黃 萎 病	黃 菜	黃 黃	黃 楊	
黃 楊 厄 閏	黃 粱	黃 葉	黃 蜂	黃 蜂 隊	黃 道	黃 道 吉 日	黃 鼠	
黃 鼠 狼	黃 旗	黃 禍	黃 種	黃 種 人	黃 綠	黃 綠 色	黃 酸 鹽	
黃 銅	黃 銅 礦	黃 澄 澄	黃 褐	黃 褐 色	黃 歷	黃 興	黃 龍	
黃 檀	黃 磷	黃 膽	黃 醬	黃 雛	黃 韻 玲	黃 壤	黃 鐘 大 呂	
黃 鐘 毀 棄	黃 鐵 礦	黃 鶯	黃 鶴	黃 鶴 樓	黃 鱔	黃 鸝	黍 粉	
黍 粥	黍 離 麥 秀	黑 了	黑 人	黑 人 住	黑 人 似	黑 下	黑 土	
黑 子	黑 山	黑 內 障	黑 天	黑 心	黑 戶	黑 手	黑 手 黨	
黑 木 耳	黑 木 瞳	黑 毛	黑 水	黑 火	黑 乎 乎	黑 奴	黑 市	
黑 布	黑 白	黑 白 分 明	黑 白 片	黑 白 混 淆	黑 白 電 視	黑 白 電 視 機	黑 白 膠 片	
黑 皮 膚	黑 石	黑 光	黑 名 單	黑 地	黑 字	黑 灰	黑 色	
黑 色 火 藥	黑 色 金 屬	黑 色 恐 怖	黑 色 素	黑 衣	黑 沉 沉	黑 角	黑 豆	
黑 呢	黑 夜	黑 帖	黑 店	黑 板	黑 板 架	黑 板 報	黑 板 擦	
黑 松	黑 松 公 司	黑 河	黑 狗	黑 的	黑 社 會	黑 花	黑 金	
黑 亮	黑 客	黑 屏	黑 洞	黑 洞 洞	黑 炭	黑 面	黑 時	
黑 框	黑 格	黑 格 爾	黑 桃	黑 海	黑 紗	黑 紋	黑 豹	
黑 馬	黑 帶	黑 盒 子	黑 眼 珠	黑 眼 圈	黑 貨	黑 陶	黑 麥	
黑 斑	黑 斑 病	黑 棗	黑 猩 猩	黑 痣	黑 著	黑 著 臉	黑 貂	
黑 雲	黑 雲 壓 城 城 欲 摧	黑 黑	黑 暗	黑 暗 面	黑 煙	黑 話	黑 路	
黑 道	黑 鼠	黑 幕	黑 漆	黑 漆 一 團	黑 漆 皮 燈	黑 漆 漆	黑 熊	
黑 種	黑 種 人	黑 窩	黑 管	黑 領 結	黑 影	黑 潮	黑 熱 病	
黑 瘦	黑 箱	黑 糊 糊	黑 線	黑 豬	黑 醋	黑 髮	黑 墨 水	
黑 燈 瞎 火	黑 錢	黑 龍 江	黑 龍 江 省	黑 壓 壓	黑 幫	黑 穗 病	黑 臉 色	
黑 鍵	黑 鍋	黑 駿 駿	黑 點	黑 黝 黝	黑 顏 料	黑 藻	黑 麵 包	
黑 體	黑 鷹	黑 箍	亂 七 八 糟	亂 了	亂 子	亂 支	亂 世	
亂 世 兇 年	亂 加	亂 加 干 涉	亂 占 耕 地	亂 叫	亂 打	亂 扔	亂 民	
亂 用	亂 石	亂 丟	亂 交	亂 成	亂 扣	亂 扣 帽 子	亂 收	
亂 收 費	亂 臣	亂 臣 逆 子	亂 臣 賊 子	亂 串	亂 作 一 團	亂 兵	亂 弄	
亂 扯	亂 事	亂 來	亂 刺	亂 性	亂 放	亂 物	亂 花	
亂 俗 傷 風	亂 咬	亂 哄 哄	亂 奏	亂 流	亂 砍	亂 砍 濫 伐	亂 紀	
亂 要	亂 飛	亂 首 垢 面	亂 倫	亂 倫 罪	亂 套	亂 射	亂 拿	
亂 烘 烘	亂 真	亂 紛	亂 紛 紛	亂 記	亂 鬥	亂 動	亂 國	
亂 堆	亂 推	亂 殺	亂 麻	亂 割	亂 喊	亂 提	亂 湊	
亂 畫	亂 結	亂 視 眼	亂 跑	亂 開	亂 亂	亂 塞	亂 塗	
亂 塗 亂 畫	亂 想	亂 搞	亂 葬	亂 跳	亂 劃	亂 摸	亂 滾	
亂 漲	亂 漲 價	亂 罰 款	亂 舞	亂 語	亂 說	亂 說 亂 動	亂 墳	
亂 墜 天 花	亂 寫	亂 彈	亂 彈 琴	亂 撞	亂 箭 攢 心	亂 罵	亂 蓬	
亂 蓬 蓬	亂 衝	亂 髮	亂 頭 粗 服	亂 擠	亂 糟 糟	亂 講	亂 點 鴛 鴦	
亂 竄	亂 翻	亂 蹦	亂 轉	亂 闖	亂 離	亂 雜	亂 黨	
亂 攤 派	傭 人	傭 工	傭 兵	傭 錢	債 戶	債 主	債 台	
債 台 高 築	債 市	債 券	債 券 發 行	債 物 人	債 息	債 務	債 務 人	
債 務 國	債 款	債 額	債 權	債 權 人	債 權 國	傲 世	傲 斥	
傲 岸 不 群	傲 物	傲 氣	傲 骨	傲 雪 凌 霜	傲 雪 欺 霜	傲 然	傲 視	
傲 睨 一 世	傲 睨 自 若	傲 慢	傲 慢 與 偏 見	傲 賢 慢 士	傲 霜	傳 人	傳 入	
傳 下	傳 子	傳 不	傳 戶	傳 世	傳 代	傳 令	傳 令 兵	
傳 令 官	傳 出	傳 打	傳 回	傳 旨	傳 位	傳 佈	傳 佈 者	
傳 戒	傳 抄	傳 技	傳 見	傳 言	傳 來	傳 到	傳 呼	
傳 奇	傳 奇 人 物	傳 奇 小 說	傳 奇 中	傳 奇 文 學	傳 奇 式	傳 奇 似	傳 奇 性	
傳 宗 接 代	傳 承	傳 杯 弄 盞	傳 信	傳 染	傳 染 性	傳 染 疾 病	傳 染 病	
傳 為 佳 話	傳 為 美 談	傳 看	傳 述	傳 家	傳 家 寶	傳 書	傳 病	
傳 真	傳 真 機	傳 神	傳 神 阿 堵	傳 粉	傳 記	傳 記 小 說	傳 記 文 學	
傳 記 體	傳 訊	傳 送	傳 送 者	傳 送 帶	傳 動	傳 動 比	傳 動 帶	
傳 動 軸	傳 動 器	傳 唱	傳 問	傳 情	傳 控	傳 授	傳 教	
傳 教 士	傳 教 師	傳 球	傳 略	傳 票	傳 統	傳 統 上	傳 統 文 化	
傳 統 主 義	傳 統 市 場	傳 統 基 金 會	傳 統 產 業	傳 統 產 業 股	傳 統 醫 療	傳 統 觀	傳 習	
傳 單	傳 喚	傳 喚 者	傳 報	傳 媒	傳 媒 界	傳 換	傳 揚	
傳 答	傳 給	傳 視	傳 開	傳 感	傳 感 技 術	傳 感 器	傳 經	
傳 經 送 寶	傳 號	傳 話	傳 道	傳 道 士	傳 道 者	傳 道 書	傳 達	
傳 達 性	傳 達 者	傳 達 室	傳 達 員	傳 過	傳 遍	傳 遍 全 身	傳 遍 全 國	
傳 頌	傳 福 音	傳 種	傳 聞	傳 聞 失 實	傳 誦	傳 說	傳 說 人 物	
傳 說 上	傳 說 中	傳 說 集	傳 遞	傳 遞 性	傳 播	傳 播 者	傳 播 媒 體	
傳 播 學	傳 標	傳 熱	傳 熱 性	傳 閱	傳 導	傳 導 力	傳 導 性	
傳 導 率	傳 諭	傳 輸	傳 輸 器	傳 幫	傳 幫 帶	傳 檄	傳 檄 而 定	
傳 聲	傳 聲 筒	傳 聲 器	傳 謠	傳 題	傳 藝	僅 及	僅 以	
僅 以 身 免	僅 占	僅 可	僅 只	僅 用	僅 在	僅 存	僅 有	
僅 次	僅 次 於	僅 此	僅 此 而 已	僅 把	僅 見	僅 供	僅 供 參 考	
僅 於	僅 指	僅 是	僅 為	僅 穿	僅 限	僅 值	僅 能	
僅 就	僅 僅	僅 僅 如 此	僅 僅 是	僅 對	僅 靠	僅 憑	僅 據	
僅 懂	傾 力	傾 心	傾 心 吐 膽	傾 心 盡 力	傾 出	傾 吐	傾 向	
傾 向 性	傾 向 於	傾 耳	傾 耳 而 聽	傾 耳 注 目	傾 耳 拭 目	傾 角	傾 佩	
傾 刻	傾 刻 間	傾 卸	傾 注	傾 軋	傾 城	傾 城 傾 國	傾 洩	
傾 盆	傾 盆 大 雨	傾 倒	傾 家	傾 家 盡 產	傾 家 竭 產	傾 家 蕩 產	傾 側	
傾 動	傾 國	傾 國 傾 城	傾 巢	傾 巢 出 動	傾 巢 而 出	傾 斜	傾 斜 角	
傾 斜 度	傾 斜 政 策	傾 斜 面	傾 斜 著	傾 斜 儀	傾 船	傾 筐 倒 庋	傾 訴	
傾 腸 倒 腹	傾 蓋	傾 慕	傾 樁	傾 箱 倒 篋	傾 談	傾 銷	傾 瀉	
傾 覆	傾 囊	傾 聽	催 人 淚 下	催 人 奮 進	催 化	催 化 作 用	催 化 重 整	
催 化 裂 化	催 化 劑	催 反	催 奶	催 打	催 生	催 交	催 吐 物	
催 吐 劑	催 收	催 汗	催 告 信	催 折	催 乳	催 函	催 征	
催 肥	催 芽	催 青	催 促	催 促 者	催 眠	催 眠 士	催 眠 曲	
催 眠 術	催 眠 劑	催 眠 學	催 眠 藥	催 租	催 討	催 淚	催 淚 瓦 斯	
催 淚 物	催 淚 彈	催 產	催 單	催 稅	催 逼	催 趕	催 請	
催 辦	傷 了 腳	傷 人	傷 亡	傷 亡 人 數	傷 亡 事 故	傷 口	傷 弓 之 鳥	
傷 化 敗 俗	傷 天	傷 天 害 命	傷 天 害 理	傷 心	傷 心 事	傷 心 落 淚	傷 心 慘 目	
傷 失	傷 生	傷 兵	傷 身	傷 者	傷 疤	傷 風	傷 風 敗 俗	
傷 員	傷 害	傷 害 案	傷 害 罪	傷 氣	傷 病	傷 病 員	傷 神	
傷 財	傷 悼	傷 痕	傷 痕 纍 纍	傷 處	傷 逝	傷 寒	傷 悲	
傷 殘	傷 殘 人	傷 痛	傷 筋 動 骨	傷 著	傷 勢	傷 感	傷 毀	
傷 腦 筋	傷 號	傷 熱	傷 懷	傷 藥	傻 了	傻 大	傻 子	
傻 干	傻 乎 乎	傻 瓜	傻 呀	傻 事	傻 的	傻 勁	傻 孩	
傻 氣	傻 笑	傻 眼	傻 話	傻 樂	傻 頭 傻 腦	剿 共	剿 匪	
剿 除	剿 滅	剿 襲	剷 平	剷 除	剽 取	剽 原	剽 悍	
剽 竊	剽 竊 者	募 化	募 兵	募 倚	募 捐	募 捐 者	募 得	
募 款	募 集	募 集 者	勤 于 思 考	勤 工 助 學	勤 工 儉 學	勤 王	勤 加 練 習	
勤 快	勤 於	勤 前 教 育	勤 勉	勤 政	勤 美	勤 美 公 司	勤 苦	
勤 益 紡 織	勤 耕	勤 能 補 拙	勤 務	勤 務 兵	勤 務 員	勤 務 訓 練	勤 勞	
勤 勞 致 富	勤 勤 懇 懇	勤 儉	勤 儉 建 國	勤 儉 持 家	勤 儉 節 約	勤 練	勤 奮	
勤 學	勤 學 苦 練	勤 樸	勤 龍 實 業	勤 懇	勤 懇 懇	勤 謹	勤 雜	
勤 雜 工	勢 力	勢 力 範 圍	勢 不 力 敵	勢 不 可 當	勢 不 可 擋	勢 不 兩 立	勢 不 兩 存	
勢 必	勢 合 形 離	勢 在	勢 在 必 行	勢 如 破 竹	勢 利	勢 利 小 人	勢 利 言 行	
勢 利 鬼	勢 利 眼	勢 均	勢 均 力 敵	勢 所 必 然	勢 派	勢 要	勢 面	
勢 能	勢 將	勢 眾	勢 無 反 顧	勢 傾 朝 野	勢 劃	勢 圖	勢 態	
勢 窮 力 極	勢 窮 力 竭	勢 頭	勢 難 兩 全	匯 了	匯 入	匯 付	匯 出	
匯 合	匯 成	匯 兌	匯 到	匯 往	匯 表	匯 泉	匯 流	
匯 為	匯 寄	匯 率	匯 票	匯 通 銀 行	匯 報	匯 報 人	匯 報 會	
匯 報 演 出	匯 款	匯 款 人	匯 款 單	匯 給	匯 費	匯 量	匯 落	
匯 路	匯 僑 工 業	匯 僑 貿 易	匯 演	匯 算	匯 聚	匯 價	匯 撥	
匯 整	匯 積	匯 總	匯 豐	匯 豐 券	匯 豐 銀 行	匯 繳	匯 爐	
嗟 來 之 食	嗟 悔 無 及	嗓 子	嗓 子 眼	嗓 門	嗓 門 兒	嗓 音	嗦 嗦	
嗎 啡	嗎 啡 精	嗜 好	嗜 好 成 癖	嗜 血	嗜 貝	嗜 毒	嗜 食	
嗜 痂 之 癖	嗜 痂 成 癖	嗜 眠	嗜 酒	嗜 欲	嗜 殺	嗜 殺 成 性	嗜 愛	
嗑 牙	嗣 子	嗣 後	嗣 業	嗤 之	嗤 之 以 鼻	嗤 笑	嗤 嗤	
嗯 哼	嗚 乎 哀 哉	嗚 呼	嗚 呼 哀 哉	嗚 咽	嗚 冤 叫 屈	嗚 嗚	嗚 聲	
嗚 辭	嗡 叫	嗡 嗡	嗡 嗡 叫	嗡 嗡 聲	嗡 嗡 響	嗡 聲	嗅 中 毒	
嗅 出	嗅 到	嗅 探	嗅 探 者	嗅 著	嗅 聞	嗅 銀 礦	嗅 覺	
嗆 人	嗆 到	嗆 鼻	嗥 叫	嗉 囊	園 丁	園 口	園 子	
園 內	園 木	園 主	園 外	園 田	園 地	園 形	園 弧	
園 林	園 長	園 圃	園 桌	園 區	園 圈	園 寂	園 桶	
園 規	園 凳	園 數	園 鋼	園 藝	園 藝 家	園 藝 學	園 籠	
圓 心	圓 心 角	圓 月	圓 木	圓 木 材	圓 片	圓 丘 般	圓 台	
圓 白 菜	圓 石 子	圓 形	圓 形 物	圓 形 罩	圓 材	圓 角	圓 周	
圓 周 角	圓 周 率	圓 弧	圓 弧 規	圓 房	圓 明 園	圓 狀	圓 的	
圓 型	圓 屋 頂	圓 度	圓 拱	圓 括 弧	圓 括 號	圓 柱	圓 柱 形	
圓 柱 狀	圓 柱 面	圓 柱 體	圓 盾 形	圓 胖	圓 首 方 足	圓 剛	圓 剛 科 技	
圓 徑	圓 桌	圓 桌 會 議	圓 珠	圓 珠 筆	圓 起	圓 圈	圓 寂	
圓 桶	圓 球	圓 規	圓 通	圓 頂	圓 頂 閣	圓 場	圓 堡	
圓 窗	圓 筒	圓 筒 形	圓 圓	圓 滑	圓 溜 溜	圓 睜	圓 夢	
圓 滿	圓 滿 成 功	圓 滿 完 成	圓 滿 完 成 任 務	圓 滿 解 決	圓 舞 曲	圓 蓋	圓 領	
圓 領 衫	圓 餅	圓 潤	圓 熟	圓 盤	圓 鋸	圓 鋼	圓 錐	
圓 錐 曲 線	圓 錐 形	圓 錐 體	圓 頭 棒	圓 燭 台	圓 環	圓 環 面	圓 環 圖	
圓 臉	圓 謊	圓 點	圓 鐵	圓 顱 方 趾	圓 鑿 方 枘	塞 入	塞 上	
塞 子	塞 內 加 爾	塞 孔	塞 尺	塞 北	塞 外	塞 在	塞 有	
塞 耳 盜 鈴	塞 舌 爾	塞 住	塞 車	塞 具	塞 尚	塞 拉 耶 佛	塞 浦 路 斯	
塞 納 河	塞 翁 失 馬	塞 得	塞 責	塞 著	塞 進	塞 飽	塞 滿	
塞 滿 了	塞 爾 提 克	塞 爾 維 亞	塞 緊	塑 化	塑 化 產 業	塑 木	塑 成	
塑 性	塑 型	塑 封	塑 料	塑 料 工 業	塑 料 布	塑 料 紙	塑 料 製 品	
塑 料 廠	塑 料 薄 膜	塑 條	塑 造	塑 像	塑 褂	塑 膜	塑 膠	
塑 膠 股	塑 膠 袋	塘 泥	塘 沽	塘 沽 協 定	塘 堰	塘 壩	塗 了	
塗 上	塗 水	塗 片	塗 以	塗 加	塗 去	塗 地	塗 在	
塗 成	塗 有	塗 污	塗 色	塗 色 於	塗 改	塗 抹	塗 抹 者	
塗 抹 劑	塗 油	塗 油 式	塗 油 漆	塗 油 膏	塗 金	塗 附	塗 染	
塗 炭	塗 炭 生 民	塗 炭 生 靈	塗 紅	塗 料	塗 粉	塗 脂 抹 粉	塗 畫	
塗 著	塗 黑	塗 過	塗 飾	塗 漆	塗 寫	塗 層	塗 潤	
塗 鴉	塗 劑	塗 擦	塗 覆	塚 中 枯 骨	塔 什 干	塔 什 庫 爾 干	塔 夫 塔 布	
塔 台	塔 吉 克	塔 吉 克 人	塔 吉 克 語	塔 吊	塔 尖	塔 式	塔 形	
塔 身	塔 底	塔 底 油	塔 拉	塔 林	塔 狀	塔 門	塔 城	
塔 高	塔 頂	塔 斯 社	塔 斯 曼	塔 裡 木	塔 裡 班	塔 樓	塔 輪	
填 入	填 上	填 土	填 方	填 充	填 平	填 平 補 齊	填 用	
填 交	填 列	填 好	填 字	填 成	填 成 平	填 具	填 制	
填 房	填 物	填 空	填 空 補 缺	填 表	填 倉	填 息	填 料	
填 海	填 記	填 送	填 高	填 報	填 發	填 絮	填 詞	
填 塞	填 塞 物	填 塞 料	填 塞 器	填 填	填 補	填 補 空 白	填 補 國 內 空 白	
填 飽	填 墊	填 滿	填 寫	填 錯	填 鴨	塌 了	塌 下	
塌 心	塌 方	塌 台	塌 車	塌 倒	塌 陷	塌 鼻	塌 鼻 子	
塌 樓	塊 冰	塊 兒	塊 狀	塊 狀 物	塊 根	塊 莖	塊 莖 狀	
塊 結	塊 間	塊 塊	塊 煤	塊 錢	塊 頭	奧 地 利	奧 地 利 人	
奧 克 蘭	奧 妙	奧 委 會	奧 林 匹 克	奧 林 匹 克 運 動 會	奧 秒	奧 迪	奧 涅 金	
奧 秘	奧 勒 岡 州	奧 斯 卡	奧 斯 汀	奧 斯 陸	奧 運	奧 運 會	奧 爾 良	
奧 賽 羅	嫁 人	嫁 出	嫁 妝	嫁 妝 箱	嫁 狗 隨 狗	嫁 娶	嫁 接	
嫁 給	嫁 禍	嫁 禍 於	嫁 禍 於 人	嫁 雞 逐 雞	嫁 雞 隨 雞	嫉 妒	嫉 妒 者	
嫉 恨	嫉 惡 好 善	嫉 惡 如 仇	嫉 賢 妒 能	嫌 犯	嫌 怨	嫌 棄	嫌 貧 愛 富	
嫌 惡	嫌 厭	嫌 疑	嫌 疑 犯	嫌 隙	媾 和	媽 也	媽 子	
媽 的	媽 咪	媽 祖	媽 媽	媳 婦	媳 婦 兒	嫂 子	嫂 夫 人	
嫂 嫂	媲 美	嵩 山	嵩 縣	幌 子	幹 一 番 事 業	幹 什 麼	幹 完	
幹 事	幹 勁	幹 勁 十 足	幹 勁 沖 天	幹 活	幹 面 杖	幹 起	幹 起 來	
幹 得	幹 得 出	幹 得 好	幹 掉	幹 部	幹 著	幹 嗎	幹 道	
幹 過	幹 嘛	幹 練	幹 線	廉 正	廉 宜	廉 明	廉 政	
廉 政 建 設	廉 泉 讓 水	廉 恥	廉 售	廉 頑 立 懦	廉 遠 堂 高	廉 頗	廉 價	
廉 價 物	廉 潔	廉 潔 公 道	廉 潔 自 律	廉 潔 奉 公	廉 爛 羊 頭	廈 門	廈 門 市	
弒 父	弒 父 母	弒 母	弒 君	彙 集	彙 集 者	彙 編	彙 編 程 序	
彙 編 語 言	微 子	微 小	微 山	微 不 足 道	微 不 足 錄	微 中 子	微 分	
微 分 方 程	微 分 電 路	微 化 石	微 升	微 孔	微 少	微 文 深 詆	微 乎 其 微	
微 凹	微 末	微 生	微 生 物	微 生 物 學	微 白	微 伏	微 光	
微 光 技 術	微 光 夜 視 儀	微 光 電 視	微 光 瞄 準 具	微 光 觀 察 儀	微 安	微 米	微 臣	
微 血 管	微 行	微 克	微 冷	微 利	微 妙	微 宏	微 言	
微 言 大 指	微 言 大 義	微 言 精 義	微 居 裡	微 明	微 服	微 服 私 行	微 服 私 訪	
微 波	微 波 爐	微 雨	微 型	微 型 化	微 型 計 算 機	微 型 電 腦	微 型 機	
微 怒	微 故 細 過	微 星 科 技	微 秒	微 紅	微 計	微 音	微 風	
微 差	微 弱	微 氣	微 氣 象	微 笑	微 笑 服 務	微 粉 化	微 動	
微 帶	微 控	微 現	微 粒	微 粒 子	微 粒 體	微 細	微 細 絲	
微 處	微 處 理 器	微 處 理 機	微 軟	微 軟 件	微 循 環	微 晶 質	微 減	
微 程 序	微 結 構	微 詞	微 進	微 進 化	微 量	微 量 元 素	微 開	
微 黃	微 黃 色	微 黑	微 微	微 微 米	微 暗	微 溫	微 電 子	
微 電 子 技 術	微 電 子 學	微 電 腦	微 電 機	微 塵	微 塵 學	微 熱	微 調	
微 賤	微 醉	微 震	微 震 計	微 導 管	微 機	微 積	微 積 分	
微 雕	微 壓	微 壓 計	微 縮	微 縮 卡	微 縮 點	微 薄	微 辭	
微 觀	微 觀 世 界	微 觀 粒 子	微 觀 經 濟	愚 人	愚 不 可 及	愚 公	愚 公 移 山	
愚 公 精 神	愚 化	愚 兄	愚 民	愚 民 政 策	愚 妄	愚 行	愚 弄	
愚 弄 者	愚 弟	愚 見	愚 言	愚 事	愚 拙	愚 者	愚 者 千 慮 必 有 一 得	
愚 者 千 慮 亦 有 一 得	愚 者 千 慮 或 有 一 得	愚 附 愚 婦	愚 勇	愚 昧	愚 昧 無 知	愚 昧 落 後	愚 眉 肉 眼	
愚 陋	愚 笨	愚 策	愚 鈍	愚 頑	愚 蒙	愚 魯	愚 懦	
愚 蠢	意 下	意 下 如 何	意 上	意 大 利	意 大 利 人	意 大 利 式	意 大 利 語	
意 中	意 中 人	意 切 言 盡	意 切 辭 盡	意 文	意 外	意 外 事	意 外 事 件	
意 外 事 故	意 外 傷 害	意 外 險	意 亦 為	意 向	意 向 性	意 向 書	意 合 情 投	
意 在	意 在 言 外	意 在 筆 先	意 存 筆 先	意 旨	意 即	意 志	意 志 力	
意 志 薄 弱	意 見	意 見 不 合	意 見 書	意 見 溝 通	意 見 箱	意 見 簿	意 到	
意 味	意 味 深 長	意 味 著	意 往 神 馳	意 念	意 於	意 者	意 表	
意 思	意 思 是	意 思 為	意 急 心 忙	意 指	意 為	意 料	意 料 之 中	
意 料 之 外	意 氣	意 氣 用 事	意 氣 自 若	意 氣 自 得	意 氣 洋 洋	意 氣 相 合	意 氣 相 投	
意 氣 相 傾	意 氣 風 發	意 氣 軒 昂	意 氣 揚 揚	意 病	意 馬 心 猿	意 馬 心 轅	意 做	
意 得 志 滿	意 欲	意 涵	意 淫	意 猶 未 盡	意 象	意 亂	意 亂 心 慌	
意 想	意 想 不 到	意 惹 情 牽	意 會	意 義	意 義 上	意 義 深 長	意 像	
意 圖	意 境	意 態	意 慵 心 懶	意 滿 志 得	意 語	意 說	意 廣 才 疏	
意 趣	意 興 索 然	意 興 闌 珊	意 謂	意 擾 心 煩	意 斷 恩 絕	意 簡	意 轉 心 回	
意 懶 心 恢	意 懶 心 慵	意 識	意 識 形 態	意 識 形 態 領 域	意 識 到	意 識 流	意 願	
意 攘 心 勞	意 譯	慈 心	慈 父	慈 母	慈 母 心	慈 竹	慈 利	
慈 眉 善 目	慈 孫 孝 子	慈 烏 反 哺	慈 烏 返 哺	慈 祥	慈 悲	慈 悲 為 本	慈 善	
慈 善 事 業	慈 善 家	慈 愛	慈 濟	慈 濟 功 德 會	慈 濟 基 金 會	慈 禧	慈 顏	
感 人	感 人 心 脾	感 人 肺 肝	感 人 肺 腑	感 今 懷 昔	感 化	感 化 所	感 化 院	
感 天 動 地	感 召	感 召 力	感 生	感 生 電 流	感 光	感 光 片	感 光 材 料	
感 光 性	感 光 度	感 光 計	感 光 紙	感 光 劑	感 同 身 受	感 抗	感 言	
感 到	感 到 遺 憾	感 受	感 受 力	感 受 性	感 受 器	感 和	感 官	
感 念	感 性	感 性 認 識	感 泣	感 知	感 知 覺	感 冒	感 染	
感 染 力	感 染 性	感 恩	感 恩 荷 德	感 恩 圖 報	感 恩 戴 義	感 恩 戴 德	感 悟	
感 動	感 動 性	感 情	感 情 上	感 情 用 事	感 情 甚 篤	感 情 脆 弱	感 慨	
感 慨 系 之	感 慨 萬 千	感 慨 萬 端	感 傷	感 想	感 電	感 歎	感 歎 詞	
感 奮	感 激	感 激 不 盡	感 激 流 涕	感 激 涕 泗	感 激 涕 零	感 興 趣	感 應	
感 應 電 流	感 應 器	感 謝	感 謝 狀	感 謝 信	感 懷	感 覺	感 覺 力	
感 覺 上	感 覺 毛	感 覺 到	感 覺 性	感 觸	想 了	想 入 非 非	想 上	
想 不 到	想 不 起	想 不 通	想 不 開	想 方 設 法	想 方 設 計	想 以	想 他	
想 出	想 去	想 必	想 用	想 吐	想 吃	想 吃 天 鵝 肉	想 在	
想 好	想 而	想 我	想 把	想 見	想 來	想 來 想 去	想 到	
想 到 此	想 定	想 念	想 法	想 法 子	想 知	想 知 道	想 前 顧 後	
想 後	想 要	想 家	想 起	想 做	想 問	想 得	想 得 到	
想 得 開	想 從	想 望	想 望 風 采	想 通	想 等	想 著	想 買	
想 開	想 想	想 當 年	想 當 初	想 當 然	想 過	想 像	想 像 力	
想 像 上	想 像 畫	想 盡	想 睡	想 說	想 辦 法	想 錯	想 頭	
想 聽	愛	愛 丁 堡	愛 人	愛 人 民	愛 人 好 士	愛 上	愛 女	
愛 子	愛 小	愛 才	愛 才 好 士	愛 才 如 命	愛 才 若 渴	愛 不 忍 釋	愛 不 釋 手	
愛 之 味	愛 幻 想	愛 心	愛 日 惜 力	愛 毛 反 裘	愛 犬	愛 他	愛 民	
愛 民 如 子	愛 民 模 範	愛 用	愛 交	愛 吃	愛 因 斯 坦	愛 在	愛 好	
愛 好 和 平	愛 好 者	愛 快 羅 密 歐	愛 把	愛 沙 尼 亞	愛 到	愛 妾	愛 妻	
愛 河	愛 物	愛 狗	愛 玩	愛 的	愛 知	愛 侶	愛 屋 及 烏	
愛 恨	愛 染	愛 看	愛 科 學	愛 美	愛 耍	愛 迪 生	愛 倫	
愛 卿	愛 哭	愛 悅	愛 書	愛 畜	愛 祖 國	愛 神	愛 笑	
愛 財 如 命	愛 起	愛 假	愛 偷	愛 動	愛 國	愛 國 心	愛 國 主 義	
愛 國 如 家	愛 國 者	愛 國 者 飛 彈	愛 國 活 動	愛 國 精 神	愛 巢	愛 得	愛 情	
愛 惜	愛 惜 羽 毛	愛 莫 之 助	愛 莫 能 助	愛 荷 華	愛 鳥	愛 勞 動	愛 喝	
愛 富 嫌 貧	愛 提	愛 滋	愛 滋 病	愛 琴 海	愛 答 不 理	愛 意	愛 搞	
愛 搭	愛 達 荷	愛 達 荷 州	愛 爾 蘭	愛 爾 蘭 人	愛 睡	愛 稱	愛 管	
愛 管 閒 事	愛 與	愛 說 愛 笑	愛 遠 惡 近	愛 寫	愛 廠 如 家	愛 慕	愛 憐	
愛 憎	愛 憎 分 明	愛 撫	愛 暱	愛 樂	愛 談	愛 學 習	愛 錢 如 命	
愛 戴	愛 講	愛 寵	愛 麗 絲 夢 遊 仙 境 症	愛 麵 族	愛 護	愛 護 公 共 財 物	愛 鶴 失 眾	
愛 聽	愛 讀	愛 戀	惹 人	惹 人 注 目	惹 人 厭	惹 下	惹 火	
惹 火 燒 身	惹 出	惹 災 招 禍	惹 事	惹 事 生 非	惹 事 招 非	惹 來	惹 怒	
惹 是 生 非	惹 是 招 非	惹 是 非	惹 氣	惹 草 拈 花	惹 草 沾 花	惹 草 沾 風	惹 草 粘 花	
惹 起	惹 得	惹 眼	惹 麻 煩	惹 惱	惹 罪 招 愆	惹 禍	惹 禍 招 災	
惹 禍 招 殃	惹 禍 招 愆	惹 說	愁 山 悶 海	愁 思	愁 眉	愁 眉 不 展	愁 眉 苦 目	
愁 眉 苦 眼	愁 眉 苦 臉	愁 眉 淚 眼	愁 眉 鎖 眼	愁 紅 慘 綠	愁 苦	愁 容	愁 容 滿 面	
愁 悶	愁 雲	愁 雲 慚 霧	愁 腸	愁 腸 九 轉	愁 腸 寸 斷	愁 腸 百 結	愁 緒	
愁 緒 如 麻	愁 顏	愁 顏 不 展	愁 霧	愈 大	愈 小	愈 加	愈 好	
愈 來	愈 來 愈	愈 來 愈 少	愈 來 愈 多	愈 來 愈 熱	愈 易	愈 長	愈 是	
愈 甚	愈 差	愈 益	愈 能	愈 發	愈 演 愈 烈	愈 顯	慎 小 謹 微	
慎 之 又 慎	慎 用	慎 行	慎 言	慎 防 杜 漸	慎 於	慎 思	慎 思 熟 慮	
慎 重	慎 重 考 慮	慎 重 從 事	慎 密	慎 終 如 始	慎 終 思 遠	慎 終 若 始	慎 終 追 遠	
慎 微	慎 獨	慎 謀	慎 選	慌 了	慌 不 擇 路	慌 手 忙 腳	慌 手 慌 腳	
慌 如 隔 世	慌 忙	慌 作 一 團	慌 恐	慌 神	慌 張	慌 張 張	慌 淫 無 度	
慌 淫 無 恥	慌 淫 無 道	慌 渺 不 驚	慌 亂	慌 慌	慌 慌 不 安	慌 裡 慌 張	慌 謬 絕 倫	
慄 慄 危 懼	慍 色	慍 怒	慍 容	愴 天 呼 地	愴 地 呼 天	愴 然	愧 色	
愧 作	愧 咎	愧 疚	愧 恨	愧 痛	愧 對	愧 歉	愷 悌 君 子	
愷 撒	戡 定	戡 亂	戢 鱗 潛 翼	搓 手	搓 手 跺 腳	搓 手 頓 足	搓 手 頓 腳	
搓 合	搓 成	搓 板	搓 洗	搓 粉 團 朱	搓 粉 摶 朱	搓 動	搓 捻	
搓 揉	搓 澡	搾 干	搾 出	搾 汁	搾 汁 機	搾 取	搾 油	
搾 油 機	搾 菜	搾 葡 萄	搾 機	搞 了	搞 不 清	搞 出	搞 好	
搞 成	搞 到	搞 到 手	搞 垮	搞 活	搞 特 殊 化	搞 笑	搞 臭	
搞 起	搞 鬼	搞 得	搞 清	搞 混	搞 細	搞 通	搞 亂	
搞 錯	搞 糟	搞 壞	搪 瓷	搪 瓷 器	搪 塞	搭 上	搭 出	
搭 伙	搭 好	搭 成	搭 扣	搭 伴	搭 作	搭 牢	搭 車	
搭 拉	搭 便	搭 便 車	搭 客	搭 建	搭 柏 油	搭 乘	搭 訕	
搭 起	搭 配	搭 接	搭 救	搭 理	搭 船	搭 連	搭 造	
搭 棚	搭 腔	搭 搭	搭 話	搭 載	搭 蓋	搭 賣	搭 擋	
搭 橋	搭 機	搭 頭	搭 幫	搭 檔	搭 聲	搭 舖	搽 去	
搽 粉	搽 脂 抹 粉	搽 掉	搬 了	搬 入	搬 上	搬 口 弄 舌	搬 斤 播 兩	
搬 出	搬 去	搬 用	搬 光	搬 兵	搬 弄	搬 弄 是 非	搬 走	
搬 來	搬 到	搬 空	搬 唇 弄 舌	搬 唇 遞 舌	搬 家	搬 動	搬 掉	
搬 移	搬 進	搬 開	搬 運	搬 運 工	搬 演	搬 遷	搬 遷 戶	
搏 手	搏 手 無 策	搏 鬥	搏 動	搏 戰	搏 擊	搜 出	搜 求	
搜 身	搜 刮	搜 取	搜 奇 抉 怪	搜 奇 訪 古	搜 奇 選 妙	搜 括	搜 查	
搜 捕	搜 根 剔 牙	搜 根 問 底	搜 索	搜 索 枯 腸	搜 索 論	搜 尋	搜 尋 出	
搜 尋 者	搜 尋 器	搜 揚 仄 陋	搜 揚 側 陋	搜 集	搜 集 品	搜 集 詳 盡	搜 腸 刮 肚	
搜 檢	搜 藏	搜 羅	搔 耳 捶 胸	搔 首	搔 首 踟 躕	搔 著 癢 處	搔 膚 器	
搔 頭	搔 頭 弄 姿	搔 頭 抓 耳	搔 頭 摸 耳	搔 癢	搔 癢 症	損 人	損 人 不 利 己	
損 人 安 己	損 人 利 己	損 人 肥 己	損 人 害 己	損 人 益 己	損 上 益 下	損 己 利 物	損 公 肥 私	
損 友	損 失	損 本 逐 末	損 兵 折 將	損 軍 折 將	損 害	損 益	損 耗	
損 耗 量	損 量	損 傷	損 毀	損 壞	搶 人	搶 手	搶 手 貨	
搶 去	搶 白	搶 光	搶 先	搶 先 一 步	搶 地 呼 天	搶 在	搶 收	
搶 佔	搶 劫	搶 劫 犯	搶 完	搶 走	搶 到	搶 修	搶 時 間	
搶 案	搶 婚	搶 得	搶 掠	搶 救	搶 救 無 效	搶 眼	搶 渡	
搶 著	搶 運	搶 過	搶 奪	搶 奪 犯 罪	搶 種	搶 嘴	搶 親	
搶 險	搶 險 救 災	搶 戲	搶 購	搶 購 一 空	搶 購 風	搶 灘	搖 了	
搖 下	搖 勻	搖 手	搖 手 觸 禁	搖 出	搖 曳	搖 低	搖 尾 乞 憐	
搖 床	搖 把	搖 身	搖 身 一 變	搖 車	搖 到	搖 首 頓 足	搖 唇	
搖 唇 鼓 舌	搖 扇	搖 晃	搖 晃 聲	搖 動	搖 得	搖 控	搖 桿	
搖 船	搖 椅	搖 著	搖 軸	搖 幌	搖 搖	搖 搖 晃 晃	搖 搖 欲 墜	
搖 搖 頭	搖 落	搖 鈴	搖 鈴 打 鼓	搖 旗	搖 旗 吶 喊	搖 滾	搖 滾 小 子	
搖 滾 舞	搖 滾 樂	搖 槳	搖 獎	搖 憾	搖 撼	搖 蕩	搖 醒	
搖 錢 樹	搖 頭	搖 頭 晃 腦	搖 頭 擺 尾	搖 頭 擺 腦	搖 臂	搖 臂 鑽	搖 擺	
搖 擺 人	搖 擺 著	搖 擺 舞	搖 鵝 毛 扇	搖 籃	搖 籃 曲	搖 籃 車	搖 響	
搗 枕 捶 床	搗 鬼	搗 蛋	搗 虛 批 吭	搗 亂	搗 亂 者	搗 毀	搗 碎	
搗 鼓	搗 蒜	搗 壞	搗 爛	敬 上	敬 上 接 下	敬 上 愛 下	敬 小 慎 微	
敬 天 愛 民	敬 仰	敬 老	敬 老 恤 貧	敬 老 院	敬 老 尊 賢	敬 老 慈 少	敬 老 慈 幼	
敬 老 慈 稚	敬 老 愛 幼	敬 而 遠 之	敬 呈	敬 告	敬 事 不 暇	敬 佩	敬 受 人 時	
敬 受 民 時	敬 受 桑 梓	敬 奉	敬 姜 猶 績	敬 拜	敬 畏	敬 若 神 明	敬 重	
敬 香	敬 候	敬 挽	敬 時 愛 日	敬 神	敬 祝	敬 茶	敬 送	
敬 酒	敬 啟	敬 啟 者	敬 賀	敬 意	敬 愛	敬 業	敬 業 樂 群	
敬 稱	敬 語	敬 慕	敬 慕 者	敬 請	敬 請 光 臨	敬 請 批 評 指 正	敬 賢 重 士	
敬 賢 愛 士	敬 賢 禮 士	敬 謝	敬 謝 不 敏	敬 禮	敬 贈	敬 辭	敬 鵬 工 業	
敬 獻	斟 上	斟 茶	斟 酒	斟 酌	斟 滿	新 一 代	新 人	
新 人 新 事	新 入	新 力	新 大 陸	新 工 藝	新 干	新 中 國	新 仇	
新 仇 舊 恨	新 仇 舊 憾	新 化	新 天 地	新 戶	新 手	新 文 化 運 動	新 方 法	
新 月	新 月 形	新 月 狀	新 欠	新 水 手	新 水 平	新 片	新 牙	
新 世	新 世 界	新 出 生	新 出 現	新 刊	新 加 坡	新 加 坡 人	新 加 坡 股 市	
新 包	新 台 幣	新 四 軍	新 巨 企 業	新 巧	新 市	新 民	新 民 主 主 義	
新 生	新 生 力 量	新 生 代	新 生 事 物	新 生 兒	新 生 活	新 交	新 任	
新 任 務	新 企 工 程	新 光 人 壽	新 光 三 越	新 光 合 纖	新 光 保 全	新 光 保 險 公 司	新 光 紡 織	
新 光 產 物	新 光 產 險	新 光 鋼 鐵	新 名	新 名 詞	新 地	新 好 男 孩	新 安 江	
新 年	新 式	新 成 員	新 收	新 曲	新 竹	新 竹 市	新 竹 玻 璃	
新 竹 科 學 園 區	新 竹 商 銀	新 竹 縣	新 米	新 老	新 老 用 戶	新 老 交 替	新 自 由 主 義	
新 衣	新 西 蘭	新 作	新 兵	新 址	新 妝	新 局 面	新 形 式	
新 形 勢	新 形 勢 下	新 技 術	新 技 術 革 命	新 技 術 開 發 區	新 改	新 材 料	新 村	
新 秀	新 事	新 事 物	新 事 新 辦	新 亞	新 亞 建 設	新 來	新 來 乍 到	
新 來 的	新 來 者	新 到	新 制	新 制 度	新 命 名	新 奇	新 官	
新 官 上 任 三 把 火	新 居	新 店	新 房	新 招	新 昕 纖 維	新 朋 友	新 東	
新 枝	新 武 器	新 河	新 法	新 版	新 版 本	新 玩 藝	新 的	
新 知	新 社 區	新 社 鄉	新 社 會	新 芽	新 花 樣	新 近	新 長 征	
新 亭 對 泣	新 信 徒	新 品	新 品 上 市	新 品 種	新 型	新 城	新 城 鄉	
新 屋	新 建	新 思 想	新 春	新 春 佳 節	新 星	新 洲	新 流	
新 派	新 界	新 科 技	新 紀 元	新 紀 錄	新 約	新 苗	新 要 求	
新 軍	新 郎	新 風	新 風 尚	新 倚 天 屠 龍 記	新 埔	新 埔 鎮	新 娘	
新 拳	新 時 代	新 時 期	新 書	新 氣 象	新 泰	新 泰 伸 銅	新 浪 網	
新 消 息	新 海 瓦 斯	新 秩 序	新 能 源	新 院	新 馬	新 高 度	新 高 峰	
新 動 向	新 區	新 問 題	新 埤	新 埤 鄉	新 婦	新 婚	新 婚 夫 婦	
新 婚 燕 爾	新 教	新 產 品	新 產 品 試 銷	新 異	新 硎 初 試	新 莊	新 設	
新 設 施	新 貨	新 造	新 途 徑	新 都	新 陳	新 陳 代 謝	新 創	
新 殖 民 主 義	新 港	新 發 明	新 發 展	新 發 現	新 稅	新 絕 代 雙 嬌	新 華	
新 華 社	新 華 社 訊	新 華 書 店	新 華 通 訊 社	新 著	新 詞	新 貴	新 買	
新 貸	新 進	新 進 者	新 鄉	新 開	新 開 拓	新 開 業	新 階 段	
新 園	新 塘	新 幹 線	新 意	新 愁	新 歲	新 源	新 經	
新 義	新 裝	新 裝 置	新 詩	新 路	新 路 子	新 道	新 歌	
新 綠	新 聞	新 聞 公 報	新 聞 分 析	新 聞 片	新 聞 出 版 署	新 聞 史	新 聞 局	
新 聞 社	新 聞 界	新 聞 紙	新 聞 記 者	新 聞 組	新 聞 評 論	新 聞 業	新 聞 稿	
新 聞 學	新 語	新 語 義	新 領 域	新 劇	新 增	新 廠	新 德 里	
新 德 裡	新 樂	新 潮	新 熱 帶	新 篇 章	新 編	新 墾	新 學 小 生	
新 學 科	新 學 說	新 戰 士	新 澤 西	新 燕 實 業	新 穎	新 穎 性	新 興	
新 興 航 運	新 興 產 業	新 辦	新 選	新 鋼 工 業	新 營	新 禧	新 購	
新 鮮	新 鮮 人	新 鮮 事	新 鮮 空 氣	新 鮮 感	新 舊	新 舊 交 替	新 舊 體 制	
新 豐 鄉	新 疆	新 疆 自 治 區	新 疆 省	新 疆 維 吾 爾 自 治 區	新 疆 維 吾 爾 族	新 藝 纖 維	新 藥	
新 辭	新 寶 證 券	新 黨	新 體 制	新 觀 念	新 舖	暗 下 決 心	暗 中	
暗 中 活 動	暗 中 破 壞	暗 中 參 與	暗 中 摸 索	暗 中 操 縱	暗 示	暗 光	暗 地	
暗 地 裡	暗 自	暗 自 思 量	暗 自 歡 喜	暗 色	暗 含	暗 防	暗 取	
暗 房	暗 泣	暗 河	暗 的	暗 花	暗 室	暗 室 私 心	暗 室 逢 燈	
暗 室 虧 心	暗 度	暗 度 陳 倉	暗 指	暗 昧	暗 流	暗 紅	暗 計	
暗 降	暗 香	暗 香 疏 影	暗 害	暗 疾	暗 笑	暗 記	暗 記 於 心	
暗 送	暗 送 秋 波	暗 鬥	暗 娼	暗 帳	暗 探	暗 殺	暗 殺 活 動	
暗 淡	暗 盒	暗 處	暗 訪	暗 喜	暗 喻	暗 堡	暗 渡 陳 倉	
暗 渠	暗 無 天 日	暗 然 失 色	暗 結	暗 視	暗 間	暗 傷	暗 想	
暗 暗	暗 溝	暗 號	暗 補	暗 道	暗 墓	暗 算	暗 語	
暗 影	暗 敷	暗 潮	暗 碼	暗 箭	暗 箭 中 人	暗 箭 明 槍	暗 箭 傷 人	
暗 箭 罪 難 防	暗 箭 難 防	暗 箱	暗 線	暗 褐 色	暗 銷	暗 器	暗 諷	
暗 礁	暗 虧	暗 點	暗 藏	暗 藍	暗 轉	暗 鎖	暗 戀	
暉 映	暇 日	暇 時	暇 疵	暈 了	暈 色	暈 車	暈 呼 呼	
暈 倒	暈 眩	暈 船	暈 厥	暈 機	暈 頭 轉 向	暖 人	暖 人 心 房	
暖 人 肺 腑	暖 手	暖 水 瓶	暖 色	暖 衣	暖 衣 飽 食	暖 身	暖 和	
暖 房	暖 室	暖 洋 洋	暖 流	暖 風	暖 風 機	暖 氣	暖 氣 爐	
暖 烘	暖 烘 烘	暖 酒	暖 瓶	暖 壺	暖 熱	暖 融 融	暖 簾	
暖 爐	暄 鬧	會 了	會 上	會 上 會 下	會 子	會 不 會	會 友	
會 少 離 多	會 心	會 日	會 刊	會 生 枝 節	會 用	會 同	會 合	
會 合 點	會 在	會 好	會 有	會 死	會 老	會 考	會 址	
會 把	會 攻	會 見	會 見 者	會 車	會 使	會 兒	會 典	
會 呢	會 所	會 東	會 法	會 的	會 社	會 長	會 門	
會 前	會 客	會 客 室	會 客 廳	會 後	會 派	會 為	會 要	
會 計	會 計 人 員	會 計 工 作	會 計 制 度	會 計 室	會 計 科	會 計 員	會 計 師	
會 計 帳	會 計 學	會 面	會 風	會 飛	會 首	會 員	會 員 國	
會 員 證	會 家 不 忙	會 師	會 徒	會 破	會 務	會 區	會 商	
會 唱	會 堂	會 帳	會 晤	會 理	會 眾	會 被	會 逢 其 適	
會 陰	會 場	會 期	會 萃	會 診	會 費	會 集	會 意	
會 想	會 會	會 當	會 試	會 話	會 道 能 說	會 像	會 歌	
會 演	會 聚	會 齊	會 審	會 稽	會 談	會 談 者	會 談 紀 要	
會 戰	會 操	會 澤	會 辦	會 錯	會 餐	會 館	會 徽	
會 講	會 籍	會 議	會 議 上	會 議 決 定	會 議 所	會 議 室	會 議 紀 要	
會 議 桌	會 議 期 間	會 議 資 料	會 議 認 為	會 議 錄	會 黨	會 變	榔 頭	
業 大	業 已	業 戶	業 主	業 於	業 者	業 後	業 界	
業 務	業 務 人 員	業 務 上	業 務 水 平	業 務 科	業 務 員	業 務 素 質	業 務 學 習	
業 務 聯 繫	業 業	業 經	業 精 於 勤	業 餘	業 餘 者	業 餘 時 間	業 餘 教 育	
業 餘 愛 好	業 餘 愛 好 者	業 績	業 績 發 表 會	業 績 說 明 會	業 擴	楚 人	楚 弓 楚 得	
楚 王	楚 囚 相 對	楚 地	楚 尾 吳 頭	楚 材 晉 用	楚 國	楚 雄	楚 楚	
楚 楚 不 凡	楚 楚 可 憐	楚 楚 動 人	楚 歌	楚 暴 誅 亂	楚 暴 靜 亂	楚 館 秦 樓	楚 辭	
楷 字	楷 書	楷 模	楷 體	楠 木	楠 竹	楠 梓 區	楠 梓 電 子	
楔 子	楔 形	楔 狀	極 了	極 力	極 口	極 大	極 大 量	
極 小	極 小 量	極 不	極 不 相 稱	極 不 愉 快	極 化	極 少	極 少 量	
極 少 數	極 少 數 人	極 出 色	極 右	極 左	極 正 確	極 目	極 光	
極 刑	極 地	極 地 氣 象	極 在	極 多	極 好	極 忙	極 早	
極 有	極 有 力	極 低	極 冷	極 困 難	極 坐 標	極 妙	極 快	
極 快 速	極 佳	極 其	極 其 重 要	極 受	極 性	極 性 鍵	極 抽 像	
極 易	極 板	極 肥 胖	極 近	極 亮	極 厚	極 品	極 度	
極 為	極 為 重 要	極 相 似	極 美	極 致	極 重	極 重 要	極 限	
極 值	極 差	極 弱	極 神 聖	極 討 厭	極 高	極 圈	極 域	
極 帶	極 強	極 欲	極 深	極 深 研 幾	極 盛	極 累 人	極 惡	
極 惡 劣	極 渴	極 痛	極 短	極 硬	極 貴 重	極 量	極 間 電 容	
極 微	極 微 小	極 想	極 想 念	極 像	極 漂 亮	極 盡	極 端	
極 輕	極 遠	極 需	極 寬	極 廣	極 樂	極 樂 世 界	極 樂 鳥	
極 瘦	極 機 密	極 燙	極 薄	極 點	極 簡 單	極 壞	極 難	
極 蠢	極 權	椰 子	椰 子 酒	椰 子 樹	椰 奶	椰 汁	椰 漿	
椰 揄	概 入	概 不	概 不 例 外	概 予	概 生	概 而	概 見 一 般	
概 念	概 念 上	概 念 化	概 念 性	概 念 股	概 念 論	概 況	概 則	
概 括	概 括 性	概 要	概 述	概 敘	概 率	概 率 論	概 略	
概 莫 能 外	概 圖	概 稱	概 算	概 說	概 貌	概 數	概 歎	
概 論	概 覽	概 觀	楊 乃 文	楊 千 嬅	楊 小 萍	楊 木	楊 佩 佩	
楊 牧	楊 花 水 性	楊 思 敏	楊 柳	楊 柳 青	楊 恭 如	楊 桃	楊 浦	
楊 梵	楊 梅	楊 梅 消 防 隊	楊 梅 鎮	楊 惠 姍	楊 景 天	楊 朝 祥	楊 貴 媚	
楊 傳 廣	楊 德 昌	楊 樹	楊 鐵 工 廠	楞 了	楞 住	楞 楞	楞 腦	
楞 頭	楓 木	楓 楊	楓 葉	楓 樹	楹 聯	榆 中	榆 木	
榆 林	榆 暝 豆 重	榆 樹	楣 梁	歇 下	歇 手	歇 火	歇 肩	
歇 後	歇 後 語	歇 息	歇 晌	歇 氣	歇 宿	歇 涼	歇 斯 底 裡	
歇 著	歇 業	歇 腳	歇 蔭	歲 了	歲 入	歲 不 我 與	歲 月	
歲 月 不 居	歲 月 如 流	歲 月 待 人	歲 月 崢 嶸	歲 月 蹉 跎	歲 比 不 登	歲 以 上	歲 出	
歲 末	歲 末 年 初	歲 在 龍 蛇	歲 序	歲 秒	歲 首	歲 修	歲 差	
歲 時	歲 時 伏 臘	歲 除	歲 晚	歲 寒 三 友	歲 寒 松 柏	歲 間	歲 歲	
歲 稔 年 豐	歲 緒	歲 數	歲 暮	歲 豐 年 稔	毀 了	毀 不 滅 性	毀 方 瓦 合	
毀 方 投 圓	毀 瓦 畫 墁	毀 形	毀 形 滅 性	毀 言	毀 車 殺 馬	毀 宗 夷 族	毀 於	
毀 於 一 旦	毀 林	毀 冠 裂 裳	毀 約	毀 風 敗 俗	毀 家 紓 國	毀 家 紓 難	毀 容	
毀 掉	毀 棄	毀 詆	毀 傷	毀 廉 滅 恥	毀 損	毀 滅	毀 滅 性	
毀 滅 性 打 擊	毀 跡	毀 誓	毀 謗	毀 壞	毀 鐘 為 鐸	毀 譽	殿 下	
殿 式	殿 後	殿 堂	毓 子 孕 孫	毽 子	毽 球	溢 出	溢 血	
溢 余	溢 於	溢 於 言 表	溢 洪 道	溢 流	溢 流 道	溢 美	溢 值	
溢 量	溢 過	溢 滿	溢 價	溢 潑	溯 力	溯 江	溯 流	
溯 流 求 源	溯 流 從 源	溯 流 徂 源	溯 源	溯 源 窮 流	溶 入	溶 化	溶 水	
溶 合	溶 血	溶 性	溶 於	溶 度	溶 洞	溶 為	溶 茶	
溶 液	溶 溶	溶 解	溶 解 力	溶 解 性	溶 解 物	溶 解 度	溶 蝕	
溶 膠	溶 質	溶 劑	溶 點	溶 巖	溶 體	滂 沱	源 出	
源 由	源 自	源 自 於	源 於	源 恆 工 業	源 泉	源 流	源 殊 派 異	
源 益 農 畜	源 清 流 清	源 清 流 淨	源 清 流 潔	源 深 流 長	源 程 序	源 源	源 源 不 絕	
源 源 不 斷	源 源 本 本	源 源 而 來	源 遠 流 長	源 盤	源 興 科 技	源 頭	源 點	
溝 中	溝 內	溝 外	溝 床	溝 谷	溝 底	溝 沿	溝 門	
溝 區	溝 淺	溝 通	溝 通 管 道	溝 渠	溝 槽	溝 橋	溝 壕	
溝 壑	溝 灌	滇 池	滇 緬	滅 亡	滅 口	滅 火	滅 火 筒	
滅 火 器	滅 此	滅 此 朝 食	滅 私 奉 公	滅 門	滅 門 之 禍	滅 門 絕 戶	滅 屍	
滅 音 器	滅 掉	滅 教	滅 族	滅 頂	滅 頂 之 災	滅 絕	滅 絕 人 性	
滅 菌	滅 跡	滅 鼠	滅 鼠 藥	滅 種	滅 敵	滅 親	滅 蟲	
溥 天 同 慶	溘 逝	溘 然	溺 水	溺 水 案	溺 死	溺 於	溺 愛	
溺 嬰	溺 斃	溺 寵	溫 文	溫 文 有 禮	溫 文 而 雅	溫 文 爾 雅	溫 文 儒 雅	
溫 水	溫 布 頓	溫 存	溫 州	溫 床	溫 良 恭 儉	溫 良 儉 讓	溫 和	
溫 性	溫 厚	溫 室	溫 室 效 應	溫 度	溫 度 計	溫 故	溫 故 而 知 新	
溫 故 知 新	溫 柔	溫 柔 敦 厚	溫 泉	溫 食	溫 香 軟 玉	溫 香 艷 玉	溫 哥 華	
溫 差	溫 書	溫 浴	溫 病	溫 酒	溫 帶	溫 情	溫 情 定 省	
溫 情 脈 脈	溫 習	溫 湯	溫 順	溫 暖	溫 暖 如 春	溫 過	溫 飽	
溫 飽 工 程	溫 馴	溫 瘧	溫 層	溫 標	溫 潤	溫 熱	溫 課	
溫 濕 布	溫 濕 度	溫 濕 圖	溫 馨	滑 了	滑 入	滑 下	滑 水	
滑 水 板	滑 出	滑 石	滑 石 粉	滑 冰	滑 冰 者	滑 向	滑 回	
滑 舌	滑 行	滑 行 道	滑 步	滑 步 走	滑 走	滑 車	滑 到	
滑 坡	滑 板	滑 板 車	滑 的	滑 流	滑 竿	滑 降	滑 面	
滑 音	滑 倒	滑 粉	滑 脈	滑 動	滑 動 摩 擦	滑 梯	滑 桿	
滑 移	滑 脫	滑 雪	滑 雪 板	滑 雪 者	滑 雪 衫	滑 翔	滑 翔 者	
滑 翔 術	滑 翔 機	滑 翔 翼	滑 開	滑 滑	滑 溜	滑 溜 溜	滑 落	
滑 跤	滑 道	滑 過	滑 鼠	滑 精	滑 閥	滑 標	滑 槽	
滑 潤	滑 稽	滑 稽 人	滑 稽 化	滑 稽 可 笑	滑 稽 劇	滑 膛	滑 輪	
滑 膩	滑 頭	滑 離	滑 麵 粉	滑 鐵 盧	準 決 賽	準 沒	準 兒	
準 則	準 是	準 時	準 備	準 備 工 作	準 備 好	準 備 金	準 備 就 緒	
準 會	準 準	準 確	準 確 性	準 確 度	準 確 率	準 確 無 誤	準 繩	
溜 了	溜 子	溜 之	溜 之 大 吉	溜 出	溜 光	溜 冰	溜 冰 者	
溜 冰 場	溜 肉	溜 走	溜 肩	溜 長	溜 馬	溜 馬 隊	溜 掉	
溜 脫	溜 進	溜 開	溜 須 拍 馬	溜 圓	溜 滑	溜 溜	溜 煙	
溜 號	溜 轉	溜 躂	溜 噠	滄 州	滄 江	滄 桑	滄 桑 之 變	
滄 浪	滄 海	滄 海 一 粟	滄 海 桑 田	滄 海 橫 流	滄 海 遺 珠	滄 源	滔 天	
滔 天 大 罪	滔 天 之 罪	滔 天 罪 行	滔 滔	滔 滔 不 絕	滔 滔 不 盡	滔 滔 不 竭	滔 滔 不 斷	
溪 口 鄉	溪 水	溪 州	溪 州 鄉	溪 谷	溪 流	溪 湖	溪 間	
溪 澗	溪 壑 無 厭	溧 水	溧 陽	溴 化 物	溴 化 鉀	溴 化 銀	溴 水	
溴 甲 烷	溴 酸	溴 酸 鹽	煎 水 作 冰	煎 成	煎 作	煎 炒	煎 炸	
煎 蛋	煎 蛋 卷	煎 蛋 餅	煎 魚	煎 煮	煎 膏 炊 骨	煎 餅	煎 熬	
煎 鍋	煎 藥	煎 鏟	煙 土	煙 子	煙 孔	煙 斗	煙 斗 柄	
煙 火	煙 火 器 材	煙 台	煙 多	煙 灰	煙 灰 缸	煙 色	煙 囪	
煙 具	煙 卷	煙 卷 兒	煙 味	煙 波	煙 波 浩 渺	煙 波 釣 徒	煙 花	
煙 花 風 月	煙 雨	煙 垢	煙 毒 犯	煙 毒 案	煙 毒 案 件	煙 洞	煙 突	
煙 缸	煙 飛 星 散	煙 飛 露 結	煙 氣	煙 消 火 散	煙 消 雲 散	煙 消 霧 散	煙 海	
煙 草	煙 草 商	煙 酒	煙 酒 稅	煙 鬼	煙 盒	煙 袋	煙 販	
煙 嵐 雲 岫	煙 筒	煙 絲	煙 視 媚 行	煙 雲 供 養	煙 雲 過 眼	煙 感	煙 煤	
煙 蒂	煙 葉	煙 農	煙 道	煙 塵	煙 幕	煙 幕 彈	煙 槍	
煙 管	煙 蓑 雨 笠	煙 價	煙 嘴	煙 廠	煙 樹	煙 霏 霧 集	煙 頭	
煙 鍋	煙 霞	煙 霞 痼 疾	煙 燼	煙 薰	煙 霧	煙 霧 質	煙 霧 瀰 漫	
煙 類	煙 癮	煙 霾	煙 靄	煙 鹼	煙 熏	煙 熏 火 烤	煙 熏 火 燎	
煙 熏 著	煩 了	煩 人	煩 冗	煩 天 惱 地	煩 心	煩 文	煩 言	
煩 言 碎 語	煩 言 碎 辭	煩 事	煩 累	煩 勞	煩 悶	煩 惱	煩 亂	
煩 碎	煩 瑣	煩 瑣 哲 學	煩 憂	煩 請	煩 燥	煩 擾	煩 雜	
煩 難	煩 躁	煩 囂	煤	煤 井	煤 夫	煤 斗	煤 火	
煤 田	煤 灰	煤 坑	煤 系	煤 車	煤 油	煤 炭	煤 炭 工 業	
煤 倉	煤 屑	煤 庫	煤 核	煤 氣	煤 氣 化	煤 氣 灶	煤 氣 表	
煤 氣 燈	煤 氣 爐	煤 氣 罐	煤 耗	煤 區	煤 堆	煤 球	煤 船	
煤 都	煤 渣	煤 焦 油	煤 量 名	煤 黑	煤 塊	煤 煙	煤 塵	
煤 餅	煤 價	煤 層	煤 廠	煤 窯	煤 質	煤 爐	煤 礦	
煤 礦 工 人	煤 礦 內	煤 礦 主	煉 丹	煉 乳	煉 油	煉 油 廠	煉 金	
煉 金 術	煉 焦	煉 焦 爐	煉 獄	煉 製	煉 製 廠	煉 鋼	煉 鐵	
煉 鐵 廠	煉 鐵 爐	照 人	照 公 理	照 片	照 付	照 出	照 功 行 賞	
照 本 宣 科	照 用	照 光	照 收	照 此	照 老	照 妖 鏡	照 抄	
照 材	照 見	照 例	照 到	照 征	照 拂	照 明	照 明 者	
照 明 彈	照 明 燈	照 物	照 直	照 亮	照 度	照 度 計	照 相	
照 相 師	照 相 紙	照 相 偵 察	照 相 機	照 相 館	照 相 簿	照 看	照 面	
照 准	照 射	照 料	照 納	照 記	照 做	照 常	照 理	
照 章	照 章 辦 事	照 提	照 登	照 發	照 著	照 搬	照 會	
照 照	照 葫 蘆 畫 瓢	照 像	照 像 機	照 實	照 慣 例	照 管	照 說	
照 領	照 價	照 數	照 樣	照 壁	照 燈	照 螢 映 雪	照 貓 畫 虎	
照 辦	照 錄	照 應	照 舊	照 繳	照 鏡	照 鏡 子	照 耀	
照 顧	煦 日	煌 煌	煌 煌 巨 著	煥 若 冰 釋	煥 然 一 新	煥 然 冰 釋	煥 發	
煞 白	煞 有 介 事	煞 住	煞 尾	煞 沒	煞 車	煞 是	煞 星	
煞 氣	煞 氣 騰 騰	煞 神	煞 筆	煞 費	煞 費 心 機	煞 費 苦 心	煞 廢 心 機	
煨 干 就 濕	煨 干 避 濕	爺 子	爺 兒	爺 門	爺 們	爺 孫	爺 飯 娘 羹	
爺 爺	爺 羹 娘 飯	獅 子	獅 子 山 共 和 國	獅 子 狗	獅 子 座	獅 子 般	獅 子 鄉	
獅 子 搏 兔 亦 用 全 力	獅 子 鼻	獅 子 頭	獅 王	獅 位 素 餐	獅 吼	獅 身	獅 城	
獅 祿 素 餐	獅 潭 鄉	猿 人	猿 猴	猿 聲	猿 類	猿 鶴 蟲 沙	瑚 璉 之 器	
瑕 不 掩 玉	瑕 不 掩 瑜	瑕 疵	瑕 瑜	瑕 瑜 互 見	瑟 弄 琴 調	瑟 瑟	瑟 調 琴 弄	
瑟 縮	瑞 士	瑞 士 人	瑞 兆	瑞 利 企 業	瑞 典	瑞 典 人	瑞 典 語	
瑞 奇 馬 汀	瑞 芳	瑞 芳 鎮	瑞 金	瑞 昱	瑞 昱 半 導	瑞 香	瑞 氣 祥 雲	
瑞 軒 科 技	瑞 雪	瑞 圓 纖 維	瑞 穗	瑞 麗	瑙 魯	瑜 不 掩 瑕	瑜 伽	
瑜 珈	當 了	當 人	當 十	當 下	當 上	當 口	當 子	
當 中	當 之	當 之 無 愧	當 仁 不 讓	當 今	當 今 世 界	當 今 社 會	當 今 無 輩	
當 天	當 心	當 日	當 月	當 世	當 世 才 度	當 世 無 雙	當 他	
當 代	當 令	當 它	當 先	當 地	當 地 人	當 地 時 間	當 好	
當 她	當 年	當 成	當 耳 邊 風	當 行 出 色	當 作	當 你	當 兵	
當 即	當 局	當 局 者	當 局 者 迷	當 事	當 事 人	當 事 者 迷	當 事 國	
當 兒	當 夜	當 季	當 官	當 於	當 板	當 空	當 初	
當 門 對 戶	當 前	當 前 工 作	當 前 任 務	當 前 狀 況	當 政	當 是	當 某	
當 查	當 面	當 面 鼓 對 面 鑼	當 風 秉 燭	當 值	當 個	當 哭	當 家	
當 家 人	當 家 作 主	當 家 的	當 家 理 財	當 差	當 時	當 時 的	當 班	
當 真	當 做	當 務	當 務 之 急	當 掉	當 晚	當 眾	當 眾 出 醜	
當 眾 受 辱	當 票	當 場	當 場 出 醜	當 場 現 丑	當 然	當 然 可 以	當 著	
當 街	當 軸 處 中	當 量	當 量 濃 度	當 道	當 過	當 奪	當 緊	
當 學 徒	當 機	當 機 立 斷	當 選	當 頭	當 頭 一 棒	當 頭 棒 喝	當 獲	
當 聲	當 斷 不 斷	當 歸	當 證 明	當 權	當 權 者	當 權 派	當 舖	
畸 形	畸 形 發 展	畸 形 學	畸 性	畸 型	畸 型 物	畸 型 體	畸 胎	
畸 態	畸 輕 畸 重	畸 戀	畸 變	瘀 血	瘀 泥	瘀 傷	瘀 積	
痰 盂	痰 氣	痰 迷 心 竅	痰 桶	痰 喘	痰 筒	痱 子	盞 燈	
盟 山 誓 海	盟 友	盟 主	盟 主 權	盟 立 自 動	盟 邦	盟 約	盟 軍	
盟 員	盟 國	盟 誓	睫 毛	睫 毛 油	睫 毛 膏	睫 狀	睦 相	
睦 鄰	督 工	督 府	督 促	督 促 者	督 促 檢 查	督 軍	督 師	
督 察	督 察 長	督 撫	督 學	督 導	督 導 員	督 戰	督 辦	
睹 物 思 人	睹 物 傷 情	睹 物 興 情	睹 物 興 悲	睹 物 懷 人	睹 景 傷 情	睹 微 知 著	睪 丸	
睪 丸 炎	睪 丸 酮	睜 一 隻 眼 閉 一 隻 眼	睜 大	睜 大 眼 睛	睜 目	睜 起	睜 眼	
睜 著	睜 視	睜 開	睜 開 眼 睛	睜 睜	睥 睨 物 表	矮 人	矮 子	
矮 子 看 場	矮 子 看 戲	矮 子 觀 場	矮 小	矮 床	矮 房	矮 林	矮 松	
矮 的	矮 屋	矮 胖	矮 個	矮 個 子	矮 短	矮 稈 作 物	矮 矮	
矮 凳	矮 種	矮 墩	矮 樹	矮 牆	矮 叢	矮 叢 林	碎 了	
碎 片	碎 片 性	碎 布	碎 末	碎 皮	碎 石	碎 石 堆	碎 石 路	
碎 冰	碎 冰 船	碎 成	碎 肉	碎 肉 器	碎 杏 仁	碎 步	碎 身 粉 骨	
碎 物	碎 屍	碎 首 糜 身	碎 屑	碎 料	碎 粉 狀	碎 紙	碎 骨 粉 身	
碎 掉	碎 裂	碎 塊	碎 嘴 子	碎 聲	碎 瓊 亂 玉	碰 一 鼻 子 灰	碰 了	
碰 上	碰 巧	碰 見	碰 車	碰 到	碰 杯	碰 面	碰 倒	
碰 釘 子	碰 著	碰 傷	碰 碰	碰 碰 車	碰 運	碰 過	碰 撞	
碰 壁	碰 頭	碰 頭 會	碰 擊	碰 擊 聲	碰 聲	碰 翻	碰 鎖	
碰 壞	碰 觸	碗 豆	碗 兒	碗 盆	碗 筷	碗 裡	碗 碟	
碗 碟 櫥	碗 盤	碗 櫃	碗 櫥	碗 邊	碘 中 毒	碘 化 物	碘 化 鉀	
碘 化 銀	碘 酒	碘 酸	碘 酸 鹽	碘 鎢 燈	碌 碌	碌 碌 庸 才	碌 碌 庸 流	
碌 碌 無 為	碌 碌 無 能	碌 碌 無 聞	碉 堡	硼 化 物	硼 砂	硼 酸	硼 酸 鹽	
硼 鐵	碑 文	碑 石	碑 刻	碑 林	碑 匾	碑 碣	碑 銘	
祿 無 常 家 福 無 定 門	禁 不 住	禁 不 起	禁 止	禁 止 令	禁 止 性	禁 止 者	禁 止 通 行	
禁 止 諠 譁	禁 令	禁 用	禁 地	禁 奸 除 猾	禁 忌	禁 例	禁 制	
禁 受	禁 放	禁 果	禁 品	禁 城	禁 建 限 建	禁 毒	禁 約	
禁 軍	禁 飛	禁 食	禁 捕	禁 書	禁 核	禁 酒	禁 酒 法	
禁 區	禁 售	禁 得 住	禁 得 起	禁 條	禁 造	禁 閉	禁 期	
禁 絕	禁 煙	禁 煙 運 動	禁 運	禁 演	禁 網 疏 闊	禁 慾	禁 慾 主 義	
禁 衛	禁 賭	禁 錮	禁 購	禁 獵	禁 藥	萬 一	萬 人	
萬 人 之 上	萬 人 之 敵	萬 人 空 巷	萬 丈	萬 丈 深 淵	萬 千	萬 山	萬 不 失 一	
萬 不 得 已	萬 元	萬 分	萬 分 之	萬 夫	萬 夫 不 當	萬 夫 莫 當	萬 戶	
萬 戶 千 門	萬 斤	萬 水 千 山	萬 世	萬 世 一 時	萬 世 流 芳	萬 代	萬 代 一 時	
萬 代 千 秋	萬 古	萬 古 千 秋	萬 古 長 存	萬 古 長 青	萬 古 長 春	萬 古 流 芳	萬 民	
萬 用	萬 用 刀	萬 用 表	萬 用 電 表	萬 目 睽 睽	萬 伏	萬 件	萬 全	
萬 全 之 計	萬 全 之 策	萬 向	萬 向 節	萬 名	萬 字	萬 安	萬 年	
萬 年 青	萬 有 引 力	萬 死 一 生	萬 死 不 辭	萬 別 千 差	萬 劫 不 復	萬 言	萬 里	
萬 里 長 征	萬 里 長 城	萬 里 鵬 程	萬 事	萬 事 大 吉	萬 事 如 意	萬 事 亨 通	萬 事 具 備	
萬 事 俱 備	萬 事 俱 備 只 欠 東 風	萬 事 通	萬 事 開 頭 難	萬 事 萬 物	萬 事 達 卡	萬 岸	萬 幸	
萬 念 俱 灰	萬 物	萬 狀	萬 花	萬 花 筒	萬 金	萬 金 油	萬 客 隆	
萬 春	萬 段	萬 流 景 仰	萬 紅 千 紫	萬 苦 千 辛	萬 軍	萬 倍	萬 個	
萬 家	萬 家 生 佛	萬 家 燈 火	萬 泰 電 線	萬 泰 銀 行	萬 海 航 運	萬 畝	萬 能	
萬 般	萬 般 無 奈	萬 馬 千 軍	萬 馬 奔 騰	萬 馬 皆 喑	萬 馬 齊 喑	萬 國	萬 條	
萬 眾	萬 眾 一 心	萬 處	萬 貫	萬 貫 家 財	萬 通	萬 通 銀 行	萬 頃	
萬 場	萬 惡	萬 惡 之 源	萬 無	萬 無 一 失	萬 紫 千 紅	萬 華 企 業	萬 華 區	
萬 象	萬 象 包 羅	萬 象 更 新	萬 象 森 羅	萬 隆	萬 塊	萬 歲	萬 歲 千 秋	
萬 萬	萬 萬 千 千	萬 萬 沒 有 想 到	萬 聖 節	萬 載	萬 載 千 秋	萬 壽 無 疆	萬 寧	
萬 榮	萬 榮 鄉	萬 福	萬 端	萬 緒 千 端	萬 緒 千 頭	萬 語 千 言	萬 赫	
萬 億	萬 慮	萬 確	萬 箭 穿 心	萬 箭 攢 心	萬 輛	萬 餘	萬 噸	
萬 機	萬 歷	萬 縣	萬 頭	萬 應	萬 應 藥	萬 獰 年 交	萬 縷 千 絲	
萬 雙	萬 難	萬 寶 路	萬 巒	萬 籟 俱 寂	萬 籟 無 聲	萬 變	萬 變 不 離 其 宗	
萬 靈 藥	萬 剮 千 刀	禽 肉	禽 困 覆 車	禽 奔 獸 遁	禽 息 鳥 視	禽 捨	禽 蛋	
禽 販	禽 鳥	禽 獸	禽 類	稜 角	稜 柱	稜 紋	稜 線	
稜 錐	稜 鏡	稚 女	稚 拙	稚 氣	稚 嫩	稠 人 廣 座	稠 人 廣 眾	
稠 油	稠 度	稠 密	稔 惡 不 悛	稟 告	稟 性	稟 承	稟 明	
稟 陳	稟 報	稟 賦	稞 麥	窟 穴	窟 窿	窠 臼	筷 子	
節 上 生 枝	節 子	節 支	節 日	節 水	節 水 型	節 片	節 令	
節 外 生 枝	節 本	節 用	節 用 厚 生	節 用 愛 人	節 用 裕 民	節 目	節 目 主 持 人	
節 目 單	節 多	節 衣 縮 食	節 余	節 育	節 制	節 制 生 育	節 制 資 本	
節 拍	節 拍 器	節 油	節 肢	節 肢 動 物	節 前	節 哀	節 哀 順 變	
節 奏	節 奏 性	節 奏 感	節 度	節 度 使	節 律	節 後	節 流	
節 流 閥	節 疤	節 省	節 省 時 間	節 約	節 約 者	節 述	節 食	
節 食 縮 衣	節 時	節 氣	節 烈	節 能	節 能 型	節 能 降 耗	節 骨 眼	
節 骨 眼 兒	節 假 日	節 欲	節 理	節 略	節 棍	節 減	節 距	
節 間	節 會	節 煤	節 煤 型	節 節	節 節 下 挫	節 節 敗 退	節 節 勝 利	
節 節 潰 退	節 電	節 團	節 閥	節 儉	節 儉 人	節 儉 力 行	節 儉 躬 行	
節 慶	節 操	節 選	節 錄	節 頭	節 點	節 蟲	粳 米	
粳 稻	粵 犬 吠 雪	粵 東	粵 若 稽 古	粵 海	粵 港	粵 歌	粵 語	
粵 劇	經 一 事 長 一 智	經 人 介 紹	經 上 級 批 准	經 久	經 久 不 息	經 久 不 衰	經 久 耐 用	
經 已	經 不 起	經 互 會	經 天 緯 地	經 心	經 手	經 文	經 文 歌	
經 文 緯 武	經 世 之 才	經 史	經 用	經 由	經 年	經 年 累 月	經 而	
經 血	經 行	經 匣	經 邦 論 道	經 典	經 典 著 作	經 卦	經 卷	
經 受	經 受 住	經 委	經 官 動 府	經 明 行 修	經 武 緯 文	經 表	經 度	
經 建 會	經 查	經 洗	經 看	經 研 究 決 定	經 紀	經 紀 人	經 紀 業	
經 風 雨 見 世 面	經 書	經 紗	經 脈	經 院	經 院 哲 學	經 商	經 售	
經 國 之 才	經 堂	經 密	經 常	經 常 化	經 常 性	經 得 住	經 得 起	
經 理	經 理 部	經 略	經 處	經 許 可	經 閉	經 援	經 期	
經 絡	經 費	經 費 支 出	經 貿	經 貿 公 司	經 貿 合 作	經 貿 部	經 軸	
經 傳	經 意	經 過	經 管	經 綸	經 綸 滿 腹	經 綸 濟 世	經 熱	
經 緯	經 緯 天 下	經 緯 度	經 緯 網	經 緯 儀	經 線	經 論	經 銷	
經 銷 商	經 銷 部	經 銷 權	經 學	經 歷	經 辦	經 辦 人	經 濟	
經 濟 上	經 濟 日 報	經 濟 犯 罪	經 濟 共 同 體	經 濟 危 機	經 濟 成 長	經 濟 作 物	經 濟 林	
經 濟 法	經 濟 倉	經 濟 效 益	經 濟 核 算	經 濟 特 區	經 濟 區	經 濟 基 礎	經 濟 部	
經 濟 援 助	經 濟 管 理	經 濟 學	經 營	經 營 之 道	經 營 方 式	經 營 有 術	經 營 自 主 權	
經 營 承 包	經 營 承 包 制	經 營 承 包 責 任 制	經 營 者	經 營 型	經 營 思 想	經 營 效 果	經 營 部	
經 營 策 略	經 營 管 理	經 營 管 理 權	經 營 機 制	經 營 擘 劃	經 營 權	經 籍	經 驗	
經 驗 之 談	經 驗 主 義	經 驗 交 流	經 驗 交 流 會	經 驗 性	經 驗 教 訓	經 驗 論	經 驗 總 結	
經 驗 豐 富	絹 人	絹 布	絹 印	絹 花	絹 紡	絹 絲	絹 綢	
綁 上	綁 在	綁 好	綁 住	綁 牢	綁 走	綁 架	綁 赴	
綁 匪	綁 起	綁 帶	綁 票	綁 紮	綁 緊	綁 腿	綁 樁	
綁 縛	綏 化	綏 江	綏 靖	綏 寧	綏 遠	絛 蟲	置 入	
置 中	置 之	置 之 不 理	置 之 不 顧	置 之 死 地	置 之 死 地 而 後 生	置 之 死 地 而 後 快	置 之 度 外	
置 之 高 閣	置 之 腦 後	置 水 之 情	置 水 之 清	置 外	置 地	置 在	置 有 關 法 規 於 不 顧	
置 死 地 而 後 快	置 而 不 問	置 身	置 身 事 外	置 身 於	置 放	置 放 者	置 於	
置 於 死 地 而 後 快	置 信	置 信 域	置 後	置 若 罔 聞	置 浮 標	置 備	置 換	
置 換 者	置 評	置 疑	置 辦	置 錐 之 地	置 辯	罩 入	罩 上	
罩 子	罩 以	罩 光 漆	罩 成	罩 衣	罩 住	罩 兒	罩 杯	
罩 衫	罩 面	罩 紗	罩 袖	罩 袍	罩 蓋	罩 頭	罪 人	
罪 人 不 孥	罪 上 加 罪	罪 大 惡 極	罪 不 容 誅	罪 以 功 除	罪 加 一 等	罪 犯	罪 名	
罪 有 攸 歸	罪 有 應 得	罪 行	罪 行 纍 纍	罪 狀	罪 案	罪 逆 深 重	罪 深	
罪 莫 大 焉	罪 責	罪 責 難 逃	罪 惡	罪 惡 如 山	罪 惡 行 徑	罪 惡 昭 著	罪 惡 昭 彰	
罪 惡 深 重	罪 惡 滔 天	罪 業 深 重	罪 當 萬 死	罪 該	罪 該 萬 死	罪 過	罪 漢	
罪 種	罪 魁	罪 魁 禍 首	罪 錯	罪 證	罪 孽	罪 孽 深 重	署 名	
署 於	署 者	署 長	署 期	義 人	義 上	義 士	義 大 利	
義 女	義 子	義 山 恩 海	義 工	義 不 生 財	義 不 取 容	義 不 容 辭	義 不 辭 難	
義 夫 節 婦	義 方 之 訓	義 父	義 正 詞 嚴	義 正 辭 嚴	義 母	義 刑 義 殺	義 竹 鄉	
義 作	義 兵	義 形 於 色	義 勇	義 勇 兵	義 勇 軍	義 重 恩 山	義 師	
義 氣	義 氣 相 投	義 務	義 務 人	義 務 上	義 務 兵	義 務 教 育	義 務 勞 動	
義 務 論	義 款	義 無 反 顧	義 無 返 顧	義 診	義 隆 電 子	義 旗	義 演	
義 盡	義 憤	義 憤 填 胸	義 憤 填 膺	義 賣	義 賣 會	義 舉	義 薄	
義 斷 恩 絕	義 警	羨 慕	群 力	群 口 鑠 金	群 山	群 件	群 光 電 子	
群 而 不 黨	群 臣	群 系	群 育	群 言	群 言 堂	群 居	群 居 穴 處	
群 居 和 一	群 居 性	群 居 終 日 言 不 及 義	群 芳	群 芳 爭 妍	群 星	群 架	群 英	
群 英 會	群 射	群 峰	群 島	群 益 證 券	群 起	群 起 而 攻 之	群 婚	
群 情	群 情 振 奮	群 眾	群 眾 性	群 眾 路 線	群 眾 觀 點	群 組	群 鳥	
群 棲	群 策	群 策 群 力	群 雄	群 集	群 落	群 像	群 輕 折 軸	
群 雌 粥 粥	群 毆	群 賢	群 賢 畢 至	群 謀	群 龍 無 首	群 蟻 潰 堤	群 魔	
群 魔 般	群 魔 亂 舞	群 襲	群 體	群 體 管 理	聖 人	聖 上	聖 女	
聖 水	聖 水 盆	聖 火	聖 主	聖 代	聖 本	聖 母	聖 母 峰	
聖 休 聖 緒	聖 地	聖 地 牙 哥	聖 旨	聖 曲	聖 衣	聖 役	聖 事	
聖 典	聖 彼 得 堡	聖 明	聖 物	聖 者	聖 約	聖 俸	聖 哲	
聖 徒	聖 徒 般	聖 徒 傳	聖 恩	聖 馬 利 亞	聖 骨	聖 骨 匣	聖 骨 箱	
聖 堂	聖 教	聖 荷 西	聖 荷 西 網 賽	聖 雄	聖 傳	聖 殿	聖 經	
聖 經 卦	聖 經 神 學	聖 經 賢 轉	聖 詩	聖 像	聖 墓	聖 歌	聖 廟	
聖 樂	聖 潔	聖 誕	聖 誕 節	聖 賢	聖 器 室	聖 壇	聖 壇 所	
聖 戰	聖 諭	聖 餐	聖 禮	聖 職	聖 職 者	聖 體	聖 靈	
聘 召	聘 用	聘 用 制	聘 任	聘 任 制	聘 金	聘 為	聘 約	
聘 書	聘 期	聘 請	聘 選	聘 禮	肆 行	肆 行 無 忌	肆 行 無 憚	
肆 言 如 狂	肆 言 植 黨	肆 言 無 忌	肆 言 無 憚	肆 言 詈 辱	肆 虐	肆 無 忌 憚	肆 意	
肆 意 妄 為	肆 意 攻 擊	肆 業	肆 擾	肄 業	腱 鞘	腰 刀	腰 力	
腰 下	腰 子	腰 巾	腰 包	腰 布	腰 肉	腰 肌 勞 損	腰 身	
腰 果	腰 板	腰 肢	腰 花	腰 金 衣 紫	腰 金 拖 紫	腰 背	腰 骨	
腰 帶	腰 斬	腰 桿	腰 桿 子	腰 眼	腰 部	腰 圍	腰 椎	
腰 痛	腰 間	腰 傷	腰 裡	腰 飾	腰 鼓	腰 鼓 兄 弟	腰 墊	
腰 窩	腰 腿	腰 酸	腰 際	腰 牆	腰 纏 萬 貫	腸 子	腸 內	
腸 內 臟	腸 衣	腸 系 膜	腸 肚	腸 炎	腸 肥 腦 滿	腸 胃	腸 胃 炎	
腸 胃 病	腸 胃 病 學	腸 病 毒	腸 梗 阻	腸 絞 痛	腸 菌	腸 管	腸 潰 瘍	
腸 癌	腸 蟲	腸 鏡	腥 味	腥 風 血 雨	腥 氣	腥 臭	腥 腥	
腥 臊	腮 紅	腮 須	腮 腺	腮 腺 炎	腮 頰	腮 幫 子	腳 力	
腳 下	腳 上	腳 丫	腳 不 點 地	腳 夫	腳 心	腳 手 架	腳 爪	
腳 本	腳 印	腳 尖	腳 忙 手 亂	腳 位	腳 形	腳 步	腳 步 快	
腳 步 輕 盈	腳 步 聲	腳 底	腳 板	腳 注	腳 後 跟	腳 指	腳 指 甲	
腳 架	腳 盆	腳 背	腳 面	腳 料	腳 氣	腳 氣 病	腳 病	
腳 帶	腳 脖 子	腳 趾	腳 趾 尖	腳 掌	腳 痛	腳 痛 醫 腳	腳 腕	
腳 腕 子	腳 跟	腳 跟 穩	腳 墊	腳 標	腳 踏	腳 踏 車	腳 踏 兩 只 船	
腳 踏 板	腳 踏 實 地	腳 輪	腳 燈	腳 蹼	腳 蹬	腳 鏈	腳 爐	
腳 鐲	腳 癬	腳 鐐	腳 鐐 手 銬	腫 大	腫 物	腫 起	腫 痛	
腫 脹	腫 傷	腫 塊	腫 瘤	腹 上 部	腹 中	腹 心	腹 心 之 疾	
腹 心 之 患	腹 水	腹 水 腫	腹 地	腹 有 鱗 甲	腹 板	腹 洩	腹 背	
腹 背 之 毛	腹 背 受 敵	腹 面	腹 疾	腹 側	腹 帶	腹 部	腹 痛	
腹 腔	腹 脹	腹 話 術	腹 語	腹 鳴	腹 層	腹 稿	腹 膜	
腹 膜 炎	腹 誹 心 謗	腹 壁	腹 瀉	腹 鰭	腺 狀	腺 瘤	腺 體	
腦 力	腦 力 勞 動	腦 力 勞 動 者	腦 下	腦 下 垂 體	腦 下 腺	腦 子	腦 中	
腦 中 風	腦 水 腫	腦 出 血	腦 汁	腦 瓜	腦 血 栓	腦 血 管 破 裂	腦 兒	
腦 性 麻 痺	腦 性 痳 痺 協 會	腦 波	腦 炎	腦 狀	腦 門	腦 門 子	腦 垂 體	
腦 室	腦 後	腦 海	腦 病	腦 神 經	腦 脊 髓	腦 液	腦 袋	
腦 部	腦 殼	腦 筋	腦 筋 好	腦 脹	腦 量	腦 溢 血	腦 葉	
腦 電 圖	腦 滿	腦 滿 腸 肥	腦 際	腦 漿	腦 膜	腦 膜 炎	腦 橋	
腦 變	腦 髓	腦 體 倒 掛	腦 顱	舅 子	舅 公	舅 父	舅 母	
舅 媽	舅 爺	舅 舅	艇 長	蒂 固	葷 油	葷 菜	葷 腥	
落 入	落 入 法 網	落 下	落 井	落 井 下 石	落 戶	落 日	落 月	
落 月 屋 樑	落 水	落 水 狗	落 石	落 伍	落 伍 者	落 回	落 地	
落 在	落 成	落 色	落 到	落 到 實 處	落 拓	落 拓 不 羈	落 於	
落 枕	落 果	落 泊	落 炕	落 空	落 花	落 花 生	落 花 有 意 流 水 無 情	
落 花 流 水	落 雨	落 度	落 後	落 後 地 區	落 後 狀 況	落 後 面 貌	落 差	
落 座	落 紗	落 荒	落 荒 而 逃	落 草	落 馬	落 得	落 敗	
落 淚	落 第	落 款	落 湯 雞	落 筆	落 筆 審 慎	落 雁 沉 魚	落 暉	
落 腮 胡	落 腳	落 腳 點	落 落	落 落 大 方	落 落 寡 合	落 落 難 合	落 葉	
落 葉 性	落 葉 松	落 葉 知 秋	落 葉 層	落 葉 歸 根	落 塵	落 寞	落 實	
落 實 到 人	落 實 到 戶	落 實 政 策	落 幕	落 榜	落 網	落 價	落 彈	
落 標	落 槽	落 潮	落 膘	落 魄	落 魄 不 羈	落 墨	落 選	
落 膽	落 錘	落 霞	落 點	落 難	落 體	萱 花 椿 樹	葵 花	
葵 花 油	葵 科	葦 子	葦 席	葦 塘	葫 蘆	葫 蘆 科	葉 子	
葉 公	葉 公 好 龍	葉 月 里 緒 菜	葉 片	葉 全 真	葉 肉	葉 形	葉 兒	
葉 狀	葉 狀 體	葉 芽	葉 門	葉 柄	葉 紅 素	葉 茂	葉 茂 盛	
葉 面	葉 脈	葉 草	葉 偉 志	葉 莖	葉 嵌 紋	葉 窗	葉 菊	
葉 落 知 秋	葉 落 歸 秋	葉 落 歸 根	葉 綠	葉 綠 素	葉 綠 粒	葉 綠 體	葉 酸	
葉 儀 皓	葉 輪	葉 鞘	葉 叢	葉 蟬	葉 蟲	葉 蘭	葬 人	
葬 地	葬 身	葬 身 魚 腹	葬 者	葬 送	葬 費	葬 歌	葬 儀	
葬 儀 車	葬 禮	葛 妮 絲 派 特 洛	葛 拉 芙	葛 林	葛 林 史 班	葛 林 斯 潘	葛 洲 壩	
葛 洛 夫	葛 斯 布 魯 克 斯	萼 片	萼 狀	萵 苣	萵 筍	葡 萄	葡 萄 牙	
葡 萄 牙 人	葡 萄 牙 語	葡 萄 王	葡 萄 汁	葡 萄 核	葡 萄 酒	葡 萄 乾	葡 萄 球 菌	
葡 萄 園	葡 萄 彈	葡 萄 樹	葡 萄 糖	葡 萄 籐	董 至 成	董 事	董 事 長	
董 事 會	董 卓	董 監 改 選	葭 莩 之 親	虞 侯	虜 獲	號 子	號 天 叩 地	
號 手	號 令	號 令 如 山	號 召	號 召 力	號 叫	號 外	號 衣	
號 角	號 兒	號 房	號 的	號 為	號 哭	號 脈	號 啕	
號 寒 啼 饑	號 筒	號 旗	號 稱	號 誌 故 障	號 數	號 樓	號 碼	
號 碼 盤	號 聲	蛹 幼 蟲	蛹 期	蜈 蚣	蜀 犬 吠 日	蜀 國	蜀 黍	
蜀 道	蜀 漢	蜀 錦	蜀 繡	蜀 魏	蛾 子	蛾 眉 皓 齒	蛾 眉 螓 首	
蛾 蟲	蛻 化	蛻 化 變 質	蛻 皮	蛻 殼	蛻 變	蜂 屯 蟻 聚	蜂 王	
蜂 王 精	蜂 王 漿	蜂 目 豺 聲	蜂 乳	蜂 房	蜂 毒	蜂 皇	蜂 皇 精	
蜂 起	蜂 巢	蜂 鳥	蜂 場	蜂 群	蜂 窩	蜂 窩 狀	蜂 窩 煤	
蜂 蜜	蜂 蜜 酒	蜂 鳴	蜂 鳴 器	蜂 鳴 聲	蜂 箱	蜂 擁	蜂 擁 而 上	
蜂 擁 而 至	蜂 擁 而 來	蜂 類	蜂 蠟	蜂 蠆 有 毒	蜃 樓 海 市	衙 內	衙 役	
衙 官 屈 宋	衙 門	衙 運	裔 人	裙 子	裙 布 荊 釵	裙 布 釵 荊	裙 屐 少 年	
裙 料	裙 帶	裙 帶 風	裙 帶 關 係	裙 裝	裙 舞	裙 褲	裙 褶	
裙 襯	補 一 次	補 一 補	補 丁	補 入	補 上	補 上 這 一 課	補 天	
補 天 浴 日	補 片	補 牙	補 付	補 充	補 充 人 員	補 充 法	補 充 物	
補 充 規 定	補 充 語	補 正	補 白	補 交	補 休	補 成	補 收	
補 考	補 色	補 血	補 血 劑	補 衣	補 助	補 助 金	補 助 費	
補 足	補 征	補 注	補 法	補 物	補 品	補 洞	補 派	
補 胎	補 苗	補 計	補 訂	補 述	補 修	補 差	補 挽	
補 校	補 氣	補 益	補 納	補 缺	補 記	補 退	補 釘	
補 假	補 救	補 票	補 習	補 習 班	補 貨	補 報	補 提	
補 替	補 殘 守 缺	補 牌	補 發	補 短	補 稅	補 給	補 給 站	
補 貼	補 貼 費	補 塊	補 嫁	補 腦 強 身	補 補	補 過	補 漏	
補 種	補 綴	補 語	補 說	補 齊	補 寫	補 撥	補 數	
補 碼	補 編	補 請	補 課	補 賞	補 賞 金	補 鞋	補 養	
補 劑	補 辦	補 選	補 遺	補 償	補 償 性	補 償 者	補 償 費	
補 償 貿 易	補 還	補 闕 拾 遺	補 題	補 簽	補 藥	補 體	補 苴 罅 漏	
裘 皮	裘 馬 輕 肥	裝 了	裝 人	裝 入	裝 下	裝 上	裝 小	
裝 天	裝 水	裝 以	裝 出	裝 本	裝 甲	裝 甲 兵	裝 甲 車	
裝 甲 部 隊	裝 皮 帶	裝 在	裝 好	裝 成	裝 有	裝 死	裝 作	
裝 冷	裝 扮	裝 束	裝 車	裝 佯	裝 具	裝 到	裝 卸	
裝 卸 隊	裝 於	裝 法	裝 的	裝 門 面	裝 為	裝 玻 璃	裝 相	
裝 訂	裝 訂 所	裝 訂 商	裝 訂 線	裝 修	裝 套 布	裝 料	裝 書	
裝 氣	裝 病	裝 破	裝 神 作 鬼	裝 神 弄 鬼	裝 神 扮 鬼	裝 起	裝 配	
裝 配 工	裝 配 線	裝 釘	裝 馬 具	裝 假	裝 做	裝 啞	裝 得	
裝 得 下	裝 異	裝 船	裝 設	裝 貨	裝 貨 者	裝 備	裝 備 工 作	
裝 備 定 型	裝 備 的	裝 備 管 理	裝 備 維 修	裝 腔	裝 腔 作 勢	裝 腔 作 態	裝 著	
裝 進	裝 傻	裝 傻 充 愣	裝 填	裝 填 物	裝 煤	裝 置	裝 置 物	
裝 載	裝 載 物	裝 載 處	裝 載 量	裝 載 機	裝 運	裝 飾	裝 飾 布	
裝 飾 用	裝 飾 物	裝 飾 者	裝 飾 品	裝 飾 音	裝 飾 機	裝 滿	裝 瘋	
裝 瘋 賣 傻	裝 睡	裝 緊	裝 蒜	裝 樣	裝 模	裝 模 作 樣	裝 模 做 樣	
裝 盤	裝 箱	裝 機	裝 機 容 量	裝 璜	裝 龍 裝 啞	裝 懂	裝 殮	
裝 聰	裝 聰 明	裝 闊 佬	裝 點	裝 藥	裝 邊	裝 聾	裝 聾 作 啞	
裝 聾 做 啞	裝 裱	裝 潢	裡 子	裡 外	裡 外 不 是 人	裡 外 裡	裡 色	
裡 弄	裡 來	裡 弦	裡 屋	裡 面	裡 島	裡 海	裡 脊	
裡 通 外 國	裡 間	裡 裡	裡 裡 外 外	裡 層	裡 談 巷 議	裡 頭	裡 應	
裡 應 外 合	裡 邊	裊 裊	裊 裊 娉 娉	裊 裊 婷 婷	裊 繞	裕 民	裕 民 航 運	
裕 國	裕 國 冷 凍	裕 隆	裕 隆 汽 車	裕 融 企 業	裕 豐 國 際	裒 多 益 寡	解 了	
解 人	解 入	解 下	解 手	解 文	解 乏	解 付	解 出	
解 包	解 去	解 甲	解 甲 休 士	解 甲 休 兵	解 甲 投 戈	解 甲 倒 戈	解 甲 歸 田	
解 甲 釋 兵	解 交	解 扣	解 池	解 衣	解 衣 卸 甲	解 作	解 困	
解 決	解 決 問 題	解 往	解 放	解 放 以 來	解 放 生 產 力	解 放 事 業	解 放 者	
解 放 初 期	解 放 前	解 放 後	解 放 思 想	解 放 軍	解 放 軍 報	解 放 區	解 放 運 動	
解 放 戰 爭	解 析	解 析 性	解 析 者	解 析 度	解 析 幾 何	解 法	解 者	
解 表	解 封	解 恨	解 毒	解 毒 劑	解 約	解 凍	解 剖	
解 剖 者	解 剖 學	解 庫	解 書	解 氣	解 送	解 酒	解 除	
解 除 武 裝	解 密	解 密 碼	解 帶	解 得	解 救	解 教	解 組	
解 脫	解 圍	解 場	解 惑	解 悶	解 散	解 散 國 會	解 期	
解 款	解 渴	解 痛	解 發 佯 狂	解 答	解 答 者	解 開	解 集	
解 雇	解 雇 期	解 禁	解 聘	解 解	解 運	解 鈴 須 用 繫 鈴 人	解 鈴 還 需 繫 鈴 人	
解 飽	解 像	解 夢	解 對	解 說	解 說 員	解 說 詞	解 嘲	
解 憂	解 槽	解 熱	解 碼	解 調	解 調 器	解 餓	解 凝 劑	
解 縛	解 謎	解 糧	解 職	解 題	解 藥	解 難	解 勸	
解 譯	解 釋	解 釋 性	解 釋 者	解 釋 器	解 囊	解 囊 相 助	解 讀	
解 體	解 饞	解 驂 推 食	詫 異	該 人	該 反 對	該 戶	該 文	
該 月	該 片	該 市	該 打	該 吃	該 地	該 州	該 年	
該 有	該 死	該 局	該 改	該 沒 收	該 到	該 受	該 咒	
該 咒 詛	該 季	該 所	該 社	該 城	該 是	該 省	該 書	
該 記 住	該 院	該 區	該 國	該 埠	該 將	該 帳	該 得	
該 接 受	該 教	該 處 罰	該 責 備	該 報	該 期	該 稅	該 絕	
該 給	該 著	該 項	該 當	該 當 何 罪	該 過	該 團	該 種	
該 罰	該 價	該 嘲 笑	該 廠	該 數	該 歎	該 類	詳 加	
詳 列	詳 見	詳 明	詳 知	詳 查	詳 述	詳 密	詳 悉	
詳 情	詳 敘	詳 略	詳 細	詳 細 信 息	詳 細 情 況	詳 細 資 料	詳 備	
詳 瑞	詳 解	詳 詳 細 細	詳 載	詳 圖	詳 夢	詳 實	詳 察	
詳 盡	詳 說	詳 審	詳 慮	詳 談	詳 論	詳 閱	詳 錄	
詳 講	詳 讀	試 一 試	試 人	試 之	試 手	試 水 器	試 以	
試 刊	試 生 產	試 用	試 用 期	試 件	試 吃	試 行	試 衣	
試 作	試 車	試 制	試 卷	試 征	試 析	試 金	試 金 石	
試 金 者	試 映	試 看	試 穿	試 述	試 飛	試 射	試 紙	
試 航	試 做	試 問	試 婚	試 將	試 探	試 探 性	試 探 者	
試 產	試 場	試 著	試 想	試 試	試 試 看	試 運 行	試 過	
試 電	試 電 筆	試 嘗	試 圖	試 演	試 種	試 管	試 算	
試 算 表	試 製 品	試 樣	試 編	試 論	試 銷	試 銷 品	試 養	
試 劑	試 壇	試 辦	試 戴	試 點	試 點 單 位	試 題	試 藥	
試 鏡	試 聽	試 讀	試 驗	試 驗 中	試 驗 田	試 驗 性	試 驗 者	
試 驗 區	試 驗 設 備	試 驗 報 告	試 驗 裝 置	詩	詩 人	詩 才	詩 中	
詩 中 有 畫	詩 友	詩 文	詩 以 言 志	詩 仙	詩 句	詩 名	詩 字	
詩 行	詩 作	詩 抄	詩 朋 酒 友	詩 朋 酒 侶	詩 法	詩 社	詩 品	
詩 律	詩 派	詩 頁	詩 風	詩 書	詩 書 禮 樂	詩 酒 朋 儕	詩 情	
詩 情 畫 意	詩 章	詩 詞	詩 詞 歌 賦	詩 集	詩 雲	詩 雲 子 曰	詩 意	
詩 會	詩 經	詩 聖	詩 腸 鼓 吹	詩 話	詩 歌	詩 歌 史	詩 歌 評 論	
詩 篇	詩 調	詩 論	詩 賦	詩 趣	詩 壇	詩 學	詩 興	
詩 選	詩 謎	詩 禮 人 家	詩 禮 傳 家	詩 韻	詩 韻 學	詩 體	詰 屈 聱 牙	
詰 問	詰 難	誇 口	誇 大	誇 大 狂	誇 大 其 詞	誇 父 追 日	誇 父 逐 日	
誇 示	誇 多 斗 靡	誇 她	誇 特	誇 能 鬥 志	誇 張	誇 張 者	誇 強 道 會	
誇 強 說 會	誇 誇	誇 誇 而 談	誇 誇 其 談	誇 飾	誇 獎	誇 耀	誇 讚	
詼 諧	詼 諧 曲	誠 心	誠 心 正 意	誠 心 敬 意	誠 心 誠 意	誠 如	誠 有	
誠 至	誠 招	誠 信	誠 洲 電 子	誠 恐	誠 恐 誠 惶	誠 泰 商 銀	誠 泰 銀 行	
誠 惶 誠 恐	誠 惶 誠 懼	誠 然	誠 意	誠 誠 懇 懇	誠 實	誠 實 可 靠	誠 徵	
誠 摯	誠 樸	誠 篤	誠 懇	誠 懇 待 人	誠 屬	話 人	話 又 說 回 來	
話 不 投 機	話 不 虛 傳	話 中	話 中 有 話	話 中 帶 刺	話 少	話 外 音	話 本	
話 多	話 別	話 匣	話 匣 子	話 把	話 使	話 來	話 兒	
話 者	話 後	話 是	話 柄	話 音	話 音 未 落	話 音 剛 落	話 風	
話 務	話 務 員	話 接	話 梅	話 筒	話 間	話 號	話 裡	
話 裡 有 話	話 過	話 語	話 說	話 說 回 來	話 劇	話 鋒	話 鋒 一 轉	
話 機	話 頭	話 舊	話 題	話 簿	話 茬	話 茬 兒	話 碴	
誅 一 警 百	誅 不 避 貴	誅 心 之 論	誅 兇 討 逆	誅 兇 殄 逆	誅 求 無 已	誅 求 無 厭	誅 殺	
誅 弒	誅 滅	誅 盡 殺 絕	誅 戮	誅 暴 討 逆	誅 鋤 異 己	詭 形 怪 狀	詭 怪	
詭 狀 殊 形	詭 計	詭 計 多 端	詭 秘	詭 異	詭 詐	詭 稱	詭 銜 竊 轡	
詭 論	詭 謀	詭 譎	詭 譎 怪 誕	詭 譎 無 行	詭 辭	詭 辯	詭 辯 法	
詭 辯 者	詭 辯 家	詭 辯 術	詭 辯 論	詭 變 多 端	詢 事 考 言	詢 於 芻 蕘	詢 者	
詢 問	詢 問 者	詢 價 圈 購	詮 注	詮 釋	詬 病	詹 仁 雄	詹 姆 斯	
豢 養	賊 人 心 虛	賊 人 膽 虛	賊 子 亂 臣	賊 心	賊 心 不 死	賊 去 關 門	賊 皮 賊 骨	
賊 臣 逆 子	賊 臣 亂 子	賊 眉 鼠 眼	賊 船	賊 喊 捉 賊	賊 腦	賊 窩	賊 頭 賊 腦	
賊 頭 鼠 腦	賊 黨	賊 贓	賊 鷗	資 力	資 已 付	資 中	資 方	
資 本	資 本 化	資 本 主 義	資 本 有 機 構 成	資 本 原 始 積 累	資 本 家	資 本 循 環	資 本 增 殖	
資 本 論	資 本 積 累	資 本 輸 出	資 助	資 助 人	資 治 通 鑒	資 金	資 金 借 貸	
資 金 募 集	資 信	資 怨 助 禍	資 政	資 修	資 料	資 料 ；	資 料 室	
資 料 庫	資 料 館	資 格	資 訊	資 訊 工 業	資 訊 月	資 訊 展	資 訊 專 欄	
資 訊 傳 真	資 訊 業	資 訊 電 子	資 訊 網	資 財	資 淺	資 淺 望 輕	資 淺 齒 少	
資 深	資 深 望 重	資 產	資 產 者	資 產 股	資 產 階 級	資 通 電 腦	資 策 會	
資 源	資 源 回 收	資 質	資 歷	資 歷 深	賈 永 婕	賈 西 亞	賈 奈 特	
賈 欣 惠	賈 靜 雯	賄 貨 公 行	賄 絡	賄 賂	賄 賂 公 行	賄 賂 並 行	賄 賂 物	
賄 選	跡 象	跡 線	跟 上	跟 手	跟 斗	跟 他	跟 在	
跟 你	跟 我	跟 我 讀	跟 車	跟 來	跟 前	跟 風	跟 班	
跟 您	跟 部	跟 單	跟 著	跟 進	跟 群	跟 腳	跟 緊	
跟 鞋	跟 錯	跟 隨	跟 隨 者	跟 頭	跟 蹤	跟 穩	跨 了	
跨 入	跨 刀 相 助	跨 上	跨 月	跨 世 紀	跨 出	跨 地 區	跨 州 連 郡	
跨 州 越 郡	跨 年	跨 年 度	跨 行	跨 行 業	跨 坐	跨 步	跨 姿	
跨 度	跨 洋	跨 省	跨 軌	跨 海	跨 院	跨 馬	跨 區	
跨 國	跨 國 公 司	跨 接	跨 部 門	跨 期	跨 著	跨 越	跨 超 出	
跨 距	跨 進	跨 鄉	跨 過	跨 境	跨 鳳 乘 龍	跨 鳳 乘 鸞	跨 線	
跨 學 科	跨 欄	路 人	路 人 皆 知	路 上	路 口	路 子	路 工	
路 不 拾 遺	路 引	路 北	路 由 器	路 竹 鄉	路 西	路 劫	路 局	
路 見	路 見 不 平	路 見 不 平 拔 刀 相 助	路 見 不 平 拔 劍 相 助	路 見 不 平 拔 劍 相 為	路 易 士	路 易 斯	路 東	
路 林	路 虎	路 南	路 柳 牆 花	路 段	路 軌	路 面	路 風	
路 徑	路 旁	路 窄	路 基	路 條	路 祭	路 透 社	路 逢 窄 道	
路 途	路 途 遙 遠	路 單	路 堤	路 無 拾 遺	路 牌	路 程	路 絕 人 稀	
路 費	路 跑	路 經	路 裡	路 路	路 道	路 遇	路 過	
路 塹	路 端 電 壓	路 遙	路 遙 知 馬 力	路 障	路 寬	路 撒	路 數	
路 標	路 碼 表	路 線	路 線 教 育	路 燈	路 轉	路 邊	路 礦	
路 警	路 霸	路 彎	路 攤	跳 入	跳 入 者	跳 下	跳 上	
跳 子 棋	跳 水	跳 水 者	跳 出	跳 去	跳 台	跳 回	跳 行	
跳 車	跳 來 跳 去	跳 到	跳 板	跳 河	跳 的	跳 空	跳 背	
跳 頁	跳 飛	跳 格	跳 海	跳 神	跳 級	跳 蚤	跳 蚤 市 場	
跳 起	跳 針	跳 馬	跳 高	跳 動	跳 探	跳 接	跳 梁	
跳 梁 小 丑	跳 票	跳 傘	跳 傘 人	跳 傘 者	跳 棋	跳 著	跳 蛙	
跳 越	跳 進	跳 開	跳 間	跳 腳	跳 過	跳 鼠	跳 舞	
跳 舞 者	跳 舞 病	跳 舞 會	跳 舞 機	跳 舞 廳	跳 遠	跳 彈	跳 槽	
跳 樓	跳 箱	跳 線	跳 踢	跳 橋	跳 蕩	跳 牆	跳 蟲	
跳 繩	跳 欄	跳 躍	跳 躍 者	跳 讀	跺 腳	跪 下	跪 台	
跪 地 求 饒	跪 在	跪 到	跪 拜	跪 拜 台	跪 拜 者	跪 倒	跪 著	
跪 墊	躲 入	躲 向	躲 在	躲 雨	躲 起	躲 逃	躲 閃	
躲 閃 者	躲 得 和 尚 躲 不 得 寺	躲 進	躲 開	躲 債	躲 躲	躲 躲 閃 閃	躲 過	
躲 蔽	躲 避	躲 避 球	躲 藏	躲 藏 者	躲 藏 處	較 久	較 大	
較 小	較 不	較 之	較 少	較 比	較 劣	較 好	較 如 畫 一	
較 年 輕	較 早	較 有	較 次	較 老	較 低	較 低 級	較 低 脂	
較 冷	較 妥	較 快	較 受	較 易	較 松	較 武 論 文	較 肥	
較 近	較 長	較 前	較 勁	較 厚	較 為	較 美 麗	較 若 畫 一	
較 重	較 差	較 弱	較 時 量 力	較 真	較 窄	較 高	較 強	
較 晚	較 淺	較 深	較 粗	較 喜 愛	較 場	較 短	較 貴	
較 經 久	較 慢	較 緊	較 輕	較 遠	較 寬	較 廣	較 優	
較 繁	較 壞	較 難	較 嚴	載 人	載 入	載 入 史 冊	載 入 器	
載 文	載 火	載 去	載 在	載 有	載 舟	載 舟 覆 舟	載 沉 載 浮	
載 於	載 明	載 波	載 物	載 客	載 流 子	載 重	載 重 汽 車	
載 重 車	載 重 量	載 乘	載 笑 載 言	載 記	載 送	載 酒 問 字	載 率	
載 荷	載 貨	載 貨 物	載 量	載 運	載 道	載 道 怨 生	載 馳 載 驅	
載 歌 且 舞	載 歌 載 舞	載 滿	載 機	載 頻	載 譽	載 譽 歸 來	載 體	
辟 啪	辟 惡 除 患	辟 辟 啪 啪	農 人	農 口	農 大	農 工	農 工 商	
農 工 黨	農 中	農 友	農 夫	農 夫 們	農 戶	農 奴	農 奴 主	
農 奴 制	農 民	農 民 日 報	農 民 企 業 家	農 民 技 術 員	農 民 運 動 會	農 民 銀 行	農 民 戰 爭	
農 用	農 用 物 資	農 田	農 田 水 利	農 田 基 本 建 設	農 田 灌 溉	農 宅	農 安	
農 忙	農 行	農 作	農 作 物	農 技	農 村	農 村 政 策	農 村 幹 部	
農 村 經 濟	農 村 調 查	農 車	農 事	農 具	農 協	農 委	農 委 會	
農 林	農 林 公 司	農 林 牧 副	農 林 牧 副 漁	農 牧	農 牧 民	農 牧 區	農 牧 場	
農 牧 業	農 牧 漁	農 牧 漁 業	農 舍	農 保	農 活	農 科 院	農 家	
農 家 肥 料	農 時	農 校	農 畜	農 畜 產 品	農 耕	農 院	農 副	
農 副 產 品	農 副 業	農 區	農 婦	農 械	農 產	農 產 品	農 產 品 期 貨	
農 產 量	農 莊	農 場	農 場 主	農 場 管 理	農 貿	農 貿 市 場	農 貸	
農 閒	農 園	農 會	農 業	農 業 人 口	農 業 大 學	農 業 工 人	農 業 生 產	
農 業 生 產 資 料	農 業 用 地	農 業 再 上 新 臺 階	農 業 合 作 化	農 業 地 理	農 業 技 術	農 業 投 入	農 業 改 革	
農 業 委 員 會	農 業 社	農 業 政 策	農 業 科 技	農 業 家	農 業 院 校	農 業 區 劃	農 業 國	
農 業 現 代 化	農 業 部	農 業 部 門	農 業 稅	農 業 貸 款	農 業 集 體 化	農 業 經 濟	農 業 試 驗 所	
農 業 銀 行	農 業 機 械	農 業 機 械 化	農 業 總 產 值	農 資	農 運	農 電	農 漁 畜 牧 業	
農 漁 會	農 隙	農 膜	農 墾	農 墾 工 作	農 墾 經 濟	農 學	農 學 家	
農 學 院	農 曆	農 機	農 機 具	農 機 廠	農 諺	農 轉 非	農 藝	
農 藝 師	農 藝 學	農 藥	運 人	運 入	運 力	運 斤 成 風	運 水	
運 以	運 出	運 用	運 用 之 妙 在 於 一 心	運 用 之 妙 存 乎 一 心	運 用 自 如	運 用 於	運 回	
運 至	運 行	運 行 時	運 行 著	運 行 機 制	運 作	運 兵 車	運 走	
運 乖 時 蹇	運 來	運 到	運 往	運 拙 時 乖	運 拙 時 艱	運 抵	運 河	
運 油	運 計 舖 謀	運 氣	運 氣 不 佳	運 送	運 送 者	運 馬 車	運 動	
運 動 中	運 動 用 品	運 動 衣	運 動 性	運 動 明 星	運 動 服	運 動 者	運 動 衫	
運 動 員	運 動 家	運 動 健 將	運 動 商 品	運 動 組 織	運 動 場	運 動 量	運 動 隊	
運 動 項 目	運 動 傷 害	運 動 會	運 動 資 訊	運 動 鞋	運 動 器 材	運 動 學	運 掉 自 如	
運 球	運 貨	運 貨 單	運 智 舖 謀	運 筆	運 費	運 進	運 量	
運 搬	運 煤	運 煤 船	運 載	運 載 火 箭	運 道	運 達	運 算	
運 算 上	運 算 符	運 算 器	運 價	運 銷	運 輸	運 輸 工 具	運 輸 者	
運 輸 統 計	運 輸 量	運 輸 勤 務	運 輸 業	運 輸 網	運 輸 線	運 輸 機	運 輸 艦	
運 輸 體 制	運 營	運 糧	運 轉	運 籌	運 籌 千 里	運 籌 決 勝	運 籌 帷 幄	
運 籌 學	運 蹇 時 乖	遊 人	遊 子	遊 山	遊 山 玩 水	遊 民	遊 行	
遊 行 示 威	遊 行 者	遊 伴	遊 牧	遊 牧 民	遊 牧 民 族	遊 牧 區	遊 玩	
遊 俠	遊 客	遊 記	遊 船	遊 逛	遊 廊	遊 街	遊 園	
遊 園 會	遊 艇	遊 說	遊 說 者	遊 魂	遊 樂	遊 樂 設 施	遊 樂 場	
遊 樂 園	遊 學	遊 憩	遊 憩 場	遊 歷	遊 歷 者	遊 興	遊 蕩	
遊 蕩 者	遊 戲	遊 戲 人 間	遊 戲 三 昧	遊 戲 者	遊 戲 軟 體	遊 戲 裝	遊 戲 塵 寰	
遊 蹤	遊 藝	遊 藝 機	遊 覽	遊 覽 圖	道 人	道 三 不 著 兩	道 上	
道 口	道 士	道 子	道 山	道 山 學 海	道 工	道 不 同 不 相 為 謀	道 不 拾 遺	
道 不 相 謀	道 出	道 白	道 光	道 同 志 合	道 合 志 同	道 地	道 在	
道 在 屎 溺	道 次 顛 沛	道 而 不 徑	道 西 說 東	道 別	道 坎	道 岔	道 來	
道 具	道 奇	道 奇 隊	道 姑	道 明	道 門	道 若 三 寸 舌	道 員	
道 家	道 班	道 真	道 破	道 釘	道 院	道 骨 仙 風	道 高 一 尺 魔 高 一 丈	
道 情	道 教	道 清	道 理	道 袍	道 喜	道 場	道 短	
道 賀	道 間	道 會	道 經	道 義	道 義 上	道 路	道 路 以 目	
道 路 側 目	道 道	道 道 地 地	道 寡 稱 孤	道 歉	道 盡 途 彈	道 盡 塗 窮	道 管	
道 貌 岸 然	道 遠	道 遠 日 暮	道 遠 任 重	道 遠 知 驥	道 厲 奮 發	道 德	道 德 上	
道 德 風 尚	道 德 家	道 德 敗 壞	道 德 觀	道 學	道 頭 會 尾	道 謝	道 藏	
道 瓊 工 業 指 數	道 邊	道 聽 途 說	道 聽 塗 說	道 觀	遂 川	遂 心	遂 在	
遂 其	遂 定	遂 於	遂 為	遂 意	遂 願	達 人 立 人	達 人 知 命	
達 士 通 人	達 不 到	達 仁 鄉	達 文 西	達 日	達 令	達 卡	達 旦	
達 永 興	達 因	達 成	達 成 協 議	達 孜	達 沃 斯 城	達 到	達 到 一 個 新 的 水 平	
達 到 目 的	達 到 目 標	達 到 高 潮	達 到 頂 點	達 姆 彈	達 官	達 官 貴 人	達 官 顯 宦	
達 官 顯 貴	達 於 極 點	達 欣 工 程	達 芬 奇	達 威 光 電	達 美	達 致	達 陣	
達 喀 爾	達 貿	達 意	達 新 工 業	達 爾 文	達 標	達 縣	達 賴	
達 權 知 變	達 權 通 變	達 觀	達 �� 科 技	逼 人	逼 人 太 甚	逼 入	逼 上 梁 山	
逼 上 粱 山	逼 出	逼 死	逼 死 英 雄 漢	逼 至	逼 住	逼 良 為 娼	逼 走	
逼 使	逼 供	逼 供 信	逼 供 訊	逼 和	逼 近	逼 迫	逼 真	
逼 真 性	逼 真 度	逼 問	逼 著	逼 視	逼 進	逼 債	逼 瘋	
違 反	違 反 者	違 反 商 標 法	違 天 害 理	違 天 悖 理	違 天 逆 理	違 心	違 心 之 言	
違 心 之 論	違 令	違 犯	違 犯 者	違 利 赴 名	違 抗	違 例	違 法	
違 法 必 究	違 法 犯 罪	違 法 行 為	違 法 者	違 法 活 動	違 法 亂 紀	違 者	違 者 必 究	
違 者 罰 款	違 信 背 約	違 紀	違 紀 行 為	違 約	違 約 交 割	違 背	違 背 者	
違 害 就 利	違 恩 負 義	違 時 絕 俗	違 強 凌 弱	違 理	違 規	違 規 拖 吊	違 章	
違 章 者	違 章 建 築	違 禁	違 禁 物 品	違 禁 品	違 憲	遐 方 絕 域	遐 方 絕 壤	
遐 思	遐 想	遐 爾 聞 名	遐 邇	遐 邇 一 體	遐 邇 著 聞	遐 邇 聞 名	遇 人 不 淑	
遇 上	遇 之	遇 有	遇 見	遇 事	遇 事 生 風	遇 刺	遇 到	
遇 物 持 平	遇 害	遇 救	遇 著	遇 敵	遇 險	遇 難	遇 難 者	
遇 襲	遏 止	遏 抑	遏 制	遏 惡 揚 善	遏 漸 防 萌	過 了	過 了 片 刻	
過 了 頭	過 人	過 入	過 久	過 大	過 小	過 不 去	過 不 多 久	
過 不 多 時	過 不 慣	過 五 關 斬 六 將	過 分	過 化 存 神	過 天	過 少	過 戶	
過 手	過 日 子	過 火	過 世	過 冬	過 半	過 半 數	過 去	
過 去 了	過 去 式	過 去 事	過 去 時	過 去 幾 天	過 右	過 失	過 生 日	
過 生 活	過 目	過 目 不 忘	過 目 成 誦	過 份	過 共 析 鋼	過 多	過 好	
過 年	過 早	過 死	過 江 之 鯽	過 而 能 改	過 耳 秋 風	過 低	過 冷	
過 快	過 來	過 來 人	過 夜	過 往	過 往 行 人	過 房	過 於	
過 旺	過 松	過 河	過 河 拆 橋	過 肩	過 長	過 門	過 門 不 入	
過 亮	過 客	過 度	過 後	過 急	過 活	過 甚	過 甚 其 詞	
過 重	過 食	過 庭	過 庭 之 訓	過 時	過 時 不 候	過 氣	過 氧 化 物	
過 氧 化 氫	過 海	過 秤	過 秤 員	過 窄	過 高	過 問	過 埠	
過 堂	過 密	過 屠 門 而 大 嚼	過 帳	過 強	過 得	過 得 去	過 得 硬	
過 得 慣	過 從	過 從 甚 密	過 敏	過 敏 性	過 敏 原	過 敏 症	過 晚	
過 望	過 深	過 猛	過 盛 必 衰	過 眼	過 眼 煙 雲	過 細	過 訪	
過 速	過 剩	過 勞	過 勞 死	過 場	過 期	過 期 作 廢	過 渡	
過 渡 形 式	過 渡 到	過 渡 政 府	過 猶 不 及	過 短	過 硬	過 程	過 程 中	
過 稅	過 稀	過 著	過 街	過 貴	過 亂	過 意	過 意 不 去	
過 當	過 節	過 路	過 路 人	過 載	過 道	過 過	過 電 壓	
過 飽	過 飽 和	過 境	過 慢	過 慣	過 緊	過 輕	過 隙 白 駒	
過 價	過 寬	過 慮	過 數	過 熟	過 熱	過 熱 化	過 獎	
過 磅	過 磅 員	過 磅 處	過 線	過 膝	過 橋	過 橋 抽 板	過 橋 拆 橋	
過 激	過 激 派	過 激 論	過 篩	過 遲	過 錯	過 頭	過 頭 話	
過 檔	過 濫	過 磷 酸 鈣	過 繁	過 謙	過 濾	過 濾 器	過 關	
過 關 斬 將	過 嚴	過 繼	過 譽	過 癮	過 廳	遍 及	遍 及 全 球	
遍 地	遍 地 開 花	遍 在	遍 佈	遍 佈 全 國	遍 身	遍 於	遍 處	
遍 訪	遍 野	遍 尋	遍 歷	遍 覽	遍 體 鱗 傷	逾 出	逾 放 比	
逾 放 比 率	逾 重	逾 限	逾 時	逾 假 未 歸	逾 期	逾 期 放 款	逾 期 費	
逾 越	逾 越 節	逾 閒 蕩 檢	逾 樹	逾 牆 越 捨	逾 牆 鑽 穴	逾 額	逾 齡	
遁 入	遁 入 空 門	遁 世	遁 世 離 群	遁 名 匿 跡	遁 形	遁 走	遁 走 曲	
遁 身	遁 逃	遁 跡	遁 跡 潛 形	遁 道	鄒 魯 遺 風	鄒 纓 齊 紫	酬 金	
酬 勞	酬 勞 者	酬 勞 金	酬 報	酬 答	酬 對	酬 賓	酬 應	
酬 謝	酪 農	酪 酸	酪 餅	酩 酊	酩 酊 大 醉	釉 彩	釉 術	
釉 陶	釉 質	釉 燒	鈷 礦	鉗 口	鉗 口 吞 舌	鉗 口 結 舌	鉗 口 撟 舌	
鉗 子	鉗 工	鉗 住	鉗 制	鉗 狀	鉗 馬 銜 枚	鉀 肥	鉀 礦	
鉀 鹽	鈾 礦	鉛 刀 一 割	鉛 丸	鉛 山	鉛 中 毒	鉛 印	鉛 字	
鉛 色	鉛 制	鉛 板	鉛 版	鉛 直	鉛 芯	鉛 垂 線	鉛 封	
鉛 毒	鉛 粉	鉛 針	鉛 條	鉛 球	鉛 筆	鉛 筆 盒	鉛 絲	
鉛 管	鉛 彈	鉛 質	鉛 鋅	鉛 鋼	鉛 錘	鉛 礦	鉤 刀	
鉤 上	鉤 子	鉤 元 提 要	鉤 心 鬥 角	鉤 爪	鉤 爪 鋸 牙	鉤 玄 提 要	鉤 住	
鉤 形	鉤 身 致 遠	鉤 刺	鉤 狀	鉤 狀 物	鉤 竿	鉤 破	鉤 針	
鉤 章 棘 句	鉤 號	鉤 槍	鉤 緊	鉤 線	鉤 隱 抉 微	鉤 蟲	鉤 邊	
鈴 木	鈴 木 一 朗	鈴 羊	鈴 聲	鈴 蟲	鈴 蘭	鈴 鐺	鈴 響	
鈴 響 了	鉅 祥 企 業	鉅 細	鉅 野 戰 役	鉚 勁	鉚 釘	鉚 接	鉚 焊	
鉚 眼	閘 刀	閘 口	閘 北	閘 瓦	閘 板	閘 門	閘 盒	
閘 溝	閘 電	閘 閥	閘 壩	隘 口	隘 路	隔 三 差 五	隔 山	
隔 天	隔 日	隔 月	隔 水	隔 片	隔 世	隔 代	隔 皮 斷 貨	
隔 年	隔 成	隔 行	隔 周	隔 夜	隔 岸	隔 岸 觀 火	隔 板	
隔 屋 攛 椽	隔 界	隔 音	隔 海	隔 窗 有 耳	隔 絕	隔 著	隔 開	
隔 間	隔 靴 搔 癢	隔 閡	隔 層	隔 熱	隔 熱 紙	隔 膜	隔 鄰	
隔 壁	隔 艙	隔 牆	隔 牆 有 耳	隔 聲	隔 斷	隔 離	隔 離 者	
隔 離 室	隕 石	隕 星	隕 星 學	隕 滅	隕 落	雍 正	雍 容	
雍 容 不 迫	雍 容 文 雅	雍 容 華 貴	雍 容 閒 雅	雍 容 雅 步	雍 容 爾 雅	雋 永	雋 語	
雉 雞	雷 公	雷 公 隊	雷 打 不 動	雷 光	雷 同	雷 池	雷 波	
雷 雨	雷 雨 雲	雷 射	雷 峰	雷 陣 雨	雷 動	雷 帽	雷 達	
雷 達 干 擾	雷 達 反 干 擾	雷 達 兵 訓 練	雷 達 技 術	雷 達 員	雷 達 圖	雷 達 對 抗	雷 電	
雷 管	雷 管 線	雷 鳴	雷 鳴 瓦 釜	雷 劈	雷 厲 風 行	雷 厲 風 飛	雷 暴	
雷 鋒	雷 鋒 精 神	雷 霆	雷 霆 之 怒	雷 霆 萬 鈞	雷 諾 瓦	雷 諾 數	雷 擊	
雷 聲	雷 轟 電 掣	雷 霹	雷 響	電 刀	電 力	電 力 局	電 力 供 應	
電 力 電 纜	電 力 網	電 力 線	電 力 學	電 力 機 車	電 大	電 子	電 子 工 業 部	
電 子 元 件	電 子 伏 特	電 子 束	電 子 券 商	電 子 所	電 子 股	電 子 流	電 子 計 算 機	
電 子 振 興 辦 公 室	電 子 商 務	電 子 通 訊	電 子 琴	電 子 郵 件	電 子 雲	電 子 新 貴	電 子 遊 藝 場	
電 子 電 路	電 子 對	電 子 槍	電 子 管	電 子 銀 行	電 子 價	電 子 線	電 子 學	
電 子 戰	電 子 錶	電 子 鍋	電 子 寵 物	電 子 鐘	電 子 顯 微 鏡	電 工	電 工 學	
電 介 質	電 介 體	電 化	電 化 教 育	電 化 教 學	電 化 學	電 文	電 木	
電 火 花	電 令	電 加 工	電 功 率	電 台	電 平	電 白	電 石	
電 石 氣	電 石 燈	電 示	電 光	電 光 石 火	電 冰 箱	電 刑	電 死	
電 池	電 老 虎	電 位	電 位 計	電 位 差	電 位 器	電 刨	電 告	
電 抗	電 灶	電 育	電 車	電 函	電 刷	電 卷 星 飛	電 卷 風 馳	
電 弧	電 性	電 板	電 泳	電 波	電 玩	電 玩 世 界	電 玩 店	
電 表	電 門	電 阻	電 阻 表	電 阻 率	電 阻 箱	電 阻 器	電 信	
電 信 工 作	電 信 局	電 信 術	電 信 號	電 信 總 局	電 度 表	電 度 計	電 流	
電 流 表	電 流 計	電 流 強 度	電 洽	電 音	電 風 扇	電 唁	電 容	
電 容 量	電 容 器	電 扇	電 料	電 氣	電 氣 化	電 烙 鐵	電 珠	
電 站	電 紐	電 能	電 訊	電 訊 術	電 閃	電 偶	電 動	
電 動 工 具	電 動 玩 具	電 動 勢	電 動 機	電 唱 機	電 控	電 教	電 梯	
電 桿	電 焊	電 焊 機	電 瓶	電 眼	電 荷	電 單 車	電 場	
電 報	電 報 掛 號	電 報 機	電 壺	電 掣 星 馳	電 掣 風 馳	電 椅	電 棒	
電 渣 爐	電 牌	電 筒	電 筒 光	電 視	電 視 片	電 視 台	電 視 圈	
電 視 接 收 機	電 視 連 續 劇	電 視 塔	電 視 遊 樂 器	電 視 網	電 視 劇	電 視 機	電 費	
電 賀	電 郵	電 量	電 量 計	電 鈕	電 飯 鍋	電 飯 煲	電 傳	
電 傳 機	電 勢	電 匯	電 感	電 感 器	電 暈	電 暖 器	電 業	
電 業 局	電 極	電 源	電 源 供 應 器	電 腦	電 腦 化	電 腦 犯 罪	電 腦 展	
電 腦 病 毒	電 腦 部	電 腦 當 機	電 腦 機 殼	電 腦 駭 客	電 解	電 解 法	電 解 液	
電 解 電 容 器	電 解 槽	電 解 質	電 話	電 話 卡	電 話 交 換 機	電 話 局	電 話 亭	
電 話 恐 嚇	電 話 接 線 生	電 話 採 訪	電 話 間	電 話 會 議	電 話 號 碼	電 話 網	電 話 線	
電 話 機	電 詢	電 路	電 路 分 析	電 路 板	電 路 圖	電 鈴	電 閘	
電 滲 析	電 磁	電 磁 波	電 磁 振 蕩	電 磁 場	電 磁 感 應	電 磁 說	電 磁 學	
電 磁 爐	電 磁 鐵	電 算	電 網	電 價	電 廠	電 影	電 影 工 作 者	
電 影 周	電 影 欣 賞	電 影 界	電 影 院	電 影 圈	電 影 晚 會	電 影 票	電 影 節	
電 影 演 員	電 影 製 作	電 影 劇	電 影 劇 本	電 影 機	電 樞	電 熱	電 熱 毯	
電 熱 器	電 熨 斗	電 碼	電 線	電 線 匣	電 線 電 纜	電 線 電 纜 股	電 震	
電 器	電 器 化	電 器 設 備	電 器 電 纜 股	電 學	電 導	電 橋	電 機	
電 機 師	電 燈	電 燈 泡	電 燈 柱	電 燈 架	電 燈 等	電 燙	電 磨	
電 鋸	電 壓	電 壓 互 感 器	電 壓 表	電 擊	電 檢	電 療	電 療 法	
電 聲	電 謝	電 邀	電 鍍	電 鍍 品	電 鍵	電 鍋	電 櫃	
電 離	電 離 能	電 離 層	電 鏟	電 鬍 刀	電 爐	電 鐘	電 纜	
電 鑽	雹 子	雹 災	雹 狀	雹 暴	零 丁	零 丁 孤 苦	零 七 八 碎	
零 下	零 分	零 比	零 打 碎 敲	零 用	零 用 錢	零 件	零 存	
零 存 整 取	零 位	零 沽 批 發	零 的 突 破	零 花	零 花 錢	零 度	零 星	
零 活	零 食	零 值	零 修	零 時	零 時 區	零 訊	零 配 件	
零 售	零 售 物 價	零 售 商	零 售 業	零 售 價	零 售 價 格	零 售 總 額	零 售 額	
零 基	零 組 件	零 蛋	零 部 件	零 陵	零 壹	零 壹 科 技	零 散	
零 買	零 亂	零 碎	零 落	零 落 山 丘	零 號	零 零	零 零 星 星	
零 零 碎 碎	零 敲 碎 打	零 嘴	零 數	零 篇	零 線	零 賣	零 錢	
零 頭	零 點	零 雜	零 雜 工	靖 安	靖 州	靖 江	靖 康	
靖 遠	靖 邊	靴 子	靴 底	靶 子	靶 心	靶 船	靶 場	
靶 機	預 入	預 卜	預 分	預 支	預 付	預 付 卡	預 付 款	
預 加	預 示	預 示 性	預 交	預 兆	預 先	預 扣	預 收	
預 收 款	預 有	預 考	預 估	預 作	預 冷	預 冷 器	預 告	
預 見	預 見 性	預 言	預 言 性	預 言 者	預 言 家	預 防	預 防 犯 罪	
預 防 性	預 防 法	預 防 為 主	預 防 劑	預 防 藥	預 制	預 制 板	預 定	
預 征	預 知	預 後	預 映	預 為	預 科	預 約	預 計	
預 訂	預 述	預 風	預 借	預 展	預 料	預 料 之 外	預 留	
預 祝	預 售	預 售 屋	預 產 期	預 習	預 處 理	預 設	預 造	
預 備	預 備 工 作	預 備 生	預 備 好	預 備 役	預 備 役 部 隊	預 備 隊	預 備 會 議	
預 備 黨 員	預 報	預 提	預 期	預 期 者	預 測	預 測 器	預 測 學	
預 發	預 貸	預 感	預 想	預 搔 待 癢	預 置	預 解	預 試	
預 嘗	預 演	預 算	預 算 內	預 算 內 資 金	預 算 外	預 算 外 資 金	預 算 赤 字	
預 算 審 查	預 審	預 撥	預 熱	預 熱 器	預 熱 機	預 燒	預 謀	
預 選	預 選 賽	預 壓 力	預 檢	預 賽	預 購	預 斷	預 繳	
預 覺	預 警	預 警 系 統	預 覽	頑 民	頑 皮	頑 石	頑 石 點 頭	
頑 抗	頑 抗 到 底	頑 固	頑 固 不 化	頑 固 者	頑 固 派	頑 症	頑 逆	
頑 迷	頑 強	頑 強 拚 搏	頑 童	頑 鈍	頑 廉 懦 立	頑 敵	頓 口 無 言	
頓 丟	頓 成	頓 足	頓 足 捶 胸	頓 服 量	頓 河	頓 降	頓 音	
頓 首	頓 悟	頓 悟 力	頓 挫	頓 時	頓 起	頓 措 抑 揚	頓 然	
頓 絕 法	頓 開 茅 塞	頓 感	頓 號	頓 頓	頓 語	頒 布	頒 布 實 施	
頒 行	頒 授	頒 發	頒 給	頒 獎	頒 賜	頒 贈	頌 古 非 今	
頌 揚	頌 揚 性	頌 詞	頌 經 台	頌 詩	頌 歌	頌 德	頌 贊	
頌 辭	飼 育 者	飼 狗	飼 料	飼 草	飼 喂	飼 養	飼 養 者	
飼 養 員	飼 養 場	飴 糖	飽 含	飽 肚	飽 足	飽 享	飽 受	
飽 和	飽 和 狀 態	飽 和 度	飽 和 溶 液	飽 和 電 流	飽 和 劑	飽 和 點	飽 食	
飽 食 思 淫 慾	飽 食 終 日	飽 食 終 日 無 所 用 心	飽 食 暖 衣	飽 眼 福	飽 脹	飽 暖	飽 暖 生 淫 慾	
飽 暖 思 淫 慾	飽 經	飽 經 風 霜	飽 經 憂 患	飽 經 霜 雪	飽 腹	飽 飽	飽 嘗	
飽 滿	飽 學	飽 學 之 士	飽 餐	飽 嗝	飽 嗝 兒	飾 以	飾 有	
飾 板	飾 物	飾 者	飾 非 文 過	飾 非 拒 諫	飾 非 遂 過	飾 品	飾 詞	
飾 過	飾 演	飾 頭 巾	飾 邊	馳 名	馳 名 中 外	馳 名 世 界	馳 援	
馳 騁	馱 馬	馱 絨	馱 著	馱 運	馱 轎	馴 化	馴 良	
馴 服	馴 服 手	馴 服 者	馴 狗	馴 虎	馴 馬	馴 馬 師	馴 鹿	
馴 順	馴 熟	馴 養	鳩 佔 鵲 巢	麂 皮	鼎 力	鼎 力 支 助	鼎 元 光 電	
鼎 立	鼎 助	鼎 足	鼎 足 三 分	鼎 足 之 勢	鼎 沸	鼎 食 鐘 鳴	鼎 盛	
鼎 新 革 故	鼎 鼎	鼎 鼎 大 名	鼎 營 企 業	鼎 鼐 調 和	鼎 鑊 刀 鋸	鼓 手	鼓 出	
鼓 舌	鼓 舌 搖 唇	鼓 作	鼓 吹	鼓 吹 者	鼓 角	鼓 足	鼓 足 勇 氣	
鼓 足 幹 勁	鼓 勁	鼓 盆 之 戚	鼓 面	鼓 風	鼓 風 口	鼓 風 機	鼓 風 爐	
鼓 唇 搖 舌	鼓 書	鼓 浪 嶼	鼓 起	鼓 起 勇 氣	鼓 動	鼓 動 者	鼓 眼	
鼓 掌	鼓 脹	鼓 著	鼓 搗	鼓 腹 含 哺	鼓 號	鼓 裡	鼓 鼓	
鼓 槌	鼓 舞	鼓 樓	鼓 樂	鼓 膜	鼓 噪	鼓 勵	鼓 翼	
鼓 聲	鼓 點	鼠 牙 雀 角	鼠 目	鼠 目 寸 光	鼠 目 獐 頭	鼠 穴	鼠 多	
鼠 年	鼠 肝 蟲 臂	鼠 肚 雞 腸	鼠 洞	鼠 疫	鼠 害	鼠 腹 雞 腸	鼠 窩	
鼠 標	鼠 標 器	鼠 膠	鼠 輩	鼠 膽	鼠 竄	鼠 藥	鼠 類	
鼠 竊	鼠 竊 狗 偷	鼠 竊 狗 盜	僧 人	僧 尼	僧 多 粥 少	僧 寺	僧 衣	
僧 伽	僧 服	僧 侶	僧 俗	僧 面	僧 徒	僧 院	僧 眾	
僧 袍	僧 帽	僧 職	僥 倖	僚 佐	僚 機	僚 屬	僕 人	
僕 役	僕 後	僕 婦	僕 從	僕 僕	僕 僕 風 塵	像 一	像 人	
像 上	像 乞 丐	像 大 人	像 女 王	像 天	像 片	像 王 子	像 他	
像 冊	像 奶 油	像 打 雷	像 用	像 皮	像 在	像 她	像 形	
像 形 字	像 我	像 男 人	像 底	像 征	像 征 性	像 泥	像 爬 蟲	
像 狗	像 是	像 要	像 個	像 座	像 神	像 素	像 紙	
像 鬼	像 處 女	像 術	像 這 樣	像 章	像 畫	像 發 瘋	像 煞 有 介 事	
像 話	像 圖	像 貌	像 樣	像 機	像 戲 劇	像 謎 般	僑 民	
僑 生	僑 委 會	僑 居	僑 居 國	僑 界	僑 胞	僑 務	僑 務 工 作	
僑 務 辦 公 室	僑 區	僑 商	僑 教	僑 眷	僑 鄉	僑 匯	僑 資	
僑 團	僑 領	僑 辦	僑 聯	僑 屬	僱 主	僱 用	僱 員	
僱 傭	僱 傭 軍	兢 兢	兢 兢 業 業	兢 兢 翼 翼	凳 上	凳 子	劃 一	
劃 一 不 二	劃 入	劃 上	劃 分	劃 手	劃 片	劃 出	劃 去	
劃 回	劃 地 為 牢	劃 成	劃 定	劃 底 線	劃 拉	劃 抵	劃 板	
劃 法	劃 為	劃 界	劃 界 限	劃 時 代	劃 框 框	劃 格 線	劃 破	
劃 粉	劃 記 號	劃 帳	劃 得	劃 掉	劃 清	劃 清 界 限	劃 痕	
劃 款	劃 渡	劃 等 號	劃 策	劃 給	劃 著	劃 進	劃 開	
劃 傷	劃 解	劃 劃	劃 價	劃 撥	劃 線	劃 線 人	劃 銷	
劃 橫 線	劃 燃	劃 獨	劃 選	劃 點	劃 歸	劃 轉	匱 乏	
匱 竭	厭 世	厭 世 觀	厭 恨	厭 食	厭 倦	厭 氧	厭 氧 性	
厭 棄	厭 惡	厭 新	厭 煩	厭 學	厭 戰	厭 膩	厭 舊	
厭 難 折 沖	嗾 使	嘀 咕	嘀 嘀	嘀 嘀 咕 咕	嘀 嘀 聲	嘀 嗒	嘗 了	
嘗 出	嘗 到	嘗 受	嘗 味	嘗 新	嘗 試	嘗 試 性	嘗 過	
嘗 鼎 一 臠	嘗 嘗	嘗 盡	嘗 膽	嘗 膽 臥 薪	嘗 鮮	嗽 口	嗽 嗽 聲	
嘔 心	嘔 心 吐 膽	嘔 心 瀝 血	嘔 吐	嘔 吐 物	嘔 吐 者	嘔 血	嘔 氣	
嘉 山	嘉 禾	嘉 年 華 會	嘉 言 善 行	嘉 言 懿 行	嘉 定	嘉 勉	嘉 食 化	
嘉 峪 關	嘉 益 工 業	嘉 祥	嘉 許	嘉 陵 江	嘉 魚	嘉 善	嘉 新 水 泥	
嘉 新 畜 產	嘉 義	嘉 裕	嘉 賓	嘉 劇	嘉 獎	嘉 興	嘉 謀 善 功	
嘉 禮	嘍 囉	嘎 子	嘎 扎	嘎 吱	嘎 登	嘎 嘎	嘎 嘎 響	
嘎 聲	嘎 嗒	嗷 吠	嗷 嗷	嗷 嗷 待 哺	嘖 有 煩 言	嘖 嘖	嘟 嘟	
嘟 嘟 囔 囔	嘟 噥	嘟 聲	嘟 嚕	嘟 囔	嘈 雜	嘈 雜 一 群	嘈 雜 聲	
嘈 嚷	嗶 嗶	嗶 嘰	嗶 聲	團 中 央	團 支 部	團 日	團 代 會	
團 市 委	團 伙	團 似	團 委	團 服	團 長	團 契	團 拜	
團 音	團 員	團 扇	團 校	團 粉	團 級	團 務 工 作	團 粒	
團 組 織	團 部	團 章	團 結	團 結 一 致	團 結 互 助	團 結 合 作	團 評	
團 費	團 隊	團 隊 精 神	團 圓	團 塊	團 團	團 團 圍 住	團 團 轉	
團 旗	團 聚	團 練	團 課	團 徽	團 職	團 籍	團 藻	
團 體	團 體 冠 軍	團 體 操	團 體 賽	圖 二	圖 三	圖 上	圖 上 作 業	
圖 中	圖 元	圖 文	圖 文 並 茂	圖 文 框	圖 文 集	圖 片	圖 片 展 覽	
圖 冊	圖 示	圖 列	圖 式	圖 西	圖 利	圖 形	圖 快	
圖 例	圖 制	圖 板	圖 法	圖 版	圖 表	圖 為	圖 為 不 軌	
圖 面	圖 們	圖 庫	圖 書	圖 書 工 作	圖 書 分 類	圖 書 目 錄	圖 書 事 業	
圖 書 典 藏	圖 書 室	圖 書 採 購	圖 書 發 行	圖 書 評 介	圖 書 裝 修	圖 書 資 料	圖 書 資 料 館	
圖 書 管 理	圖 書 編 目	圖 書 學	圖 書 館	圖 書 館 管 理	圖 書 館 學	圖 書 鑒 定	圖 案	
圖 紙	圖 財 致 命	圖 財 害 命	圖 釘	圖 符	圖 章	圖 報	圖 景	
圖 畫	圖 畫 書	圖 畫 釘	圖 象	圖 集	圖 塊	圖 解	圖 解 者	
圖 飾	圖 像	圖 說	圖 樣	圖 標	圖 窮 匕 見	圖 窮 匕 首 見	圖 論	
圖 學	圖 謀	圖 謀 不 軌	圖 檔	圖 譜	圖 騰	圖 鑒	塵 凡	
塵 土	塵 土 飛 揚	塵 世	塵 事	塵 肺	塵 芥	塵 俗	塵 垢	
塵 垢 秕 糠	塵 封	塵 埃	塵 粒	塵 菌	塵 飯 塗 羹	塵 緣	塵 寰	
塵 霧	塵 囂	境 內	境 內 外	境 外	境 地	境 況	境 界	
境 域	境 遇	墓 人	墓 中	墓 石	墓 穴	墓 地	墓 址	
墓 門	墓 室	墓 窖	墓 園	墓 碑	墓 葬	墓 道	墓 誌	
墓 誌 文	墓 誌 銘	墊 上	墊 子	墊 支	墊 木	墊 片	墊 付	
墊 充	墊 布	墊 平	墊 用	墊 底	墊 板	墊 物	墊 肩	
墊 架	墊 背	墊 借	墊 座	墊 料	墊 起	墊 高	墊 圈	
墊 被	墊 款	墊 著	墊 腳 石	墊 補	墊 層	墊 盤	墊 褥	
墊 錢	墊 襯	塹 壕	壽 山 福 海	壽 木	壽 比 南 山	壽 司	壽 穴	
壽 衣	壽 材	壽 辰	壽 命	壽 星	壽 桃	壽 終	壽 終 正 寢	
壽 陵 失 步	壽 陵 匍 匐	壽 斑	壽 滿 天 年	壽 數	壽 誕	壽 縣	壽 聯	
壽 禮	壽 豐	壽 豐 鄉	壽 麵	壽 衾	夥 同	夥 伴	夥 伴 兒	
夥 伴 們	夢 中	夢 中 人	夢 中 說 夢	夢 幻	夢 幻 奇 緣	夢 幻 泡 影	夢 幻 般	
夢 幻 組 合	夢 兆	夢 兆 熊 羆	夢 行 者	夢 行 症	夢 似	夢 見	夢 到	
夢 神	夢 勞 魂 想	夢 寐	夢 寐 以 求	夢 游	夢 游 者	夢 游 症	夢 筆 生 花	
夢 鄉	夢 想	夢 想 不 到	夢 裡	夢 裡 南 柯	夢 裡 蝴 蝶	夢 話	夢 境	
夢 夢	夢 熊 之 喜	夢 語	夢 魂 顛 倒	夢 熟 黃 梁	夢 遺	夢 斷 魂 消	夢 斷 魂 勞	
夢 覺 黃 梁	夢 魔	夢 囈	夢 囈 者	夢 魘	夤 緣 攀 附	奪 了	奪 人	
奪 占	奪 去	奪 目	奪 回	奪 在	奪 走	奪 取	奪 命	
奪 冠	奪 美	奪 胎 換 骨	奪 席 談 經	奪 得	奪 掉	奪 眶 而 出	奪 愛	
奪 過	奪 魁	奪 魂	奪 標	奪 權	嫡 母	嫡 系	嫡 派	
嫡 傳	嫡 裔	嫡 親	嫦 娥	嫩 白	嫩 皮	嫩 江	嫩 肉	
嫩 枝	嫩 的	嫩 芽	嫩 苗	嫩 煮	嫩 黃	嫩 葉	嫩 綠	
嫖 妓	嫖 客	嫖 娼	嫖 宿	嫘 縈 棉	嫣 然	嫣 然 一 笑	孵 小 雞	
孵 化	孵 化 場	孵 出	孵 成	孵 卵	孵 卵 器	孵 蛋	寞 然	
寧 日	寧 可	寧 安	寧 有	寧 死	寧 死 不 屈	寧 武	寧 波	
寧 肯	寧 為	寧 為 玉 碎 不 為 瓦 全	寧 為 雞 口 不 為 牛 後	寧 要	寧 夏	寧 夏 回 族 自 治 區	寧 夏 自 治 區	
寧 夏 省	寧 海	寧 神 劑	寧 缺	寧 缺 勿 濫	寧 缺 毋 濫	寧 國	寧 都	
寧 酸	寧 德	寧 靜	寧 濫 毋 缺	寧 謐	寧 願	寡 二 少 雙	寡 人	
寡 女	寡 不 敵 眾	寡 母	寡 見	寡 見 鮮 見	寡 見 鮮 聞	寡 言	寡 味	
寡 居	寡 居 期	寡 恩 少 義	寡 婦	寡 情	寡 情 少 義	寡 眾	寡 廉	
寡 廉 鮮 恥	寡 聞	寡 聞 少 見	寡 敵	寡 頭	寡 頭 政 治	寡 斷	寡 歡	
寥 若 晨 星	寥 落	寥 寥	寥 寥 可 數	寥 寥 無 幾	寥 寥 數 語	實 力	實 力 政 策	
實 力 派	實 力 統 計	實 力 雄 厚	實 干	實 干 家	實 才	實 心	實 心 球	
實 付	實 出 無 耐	實 可	實 打 實	實 用	實 用 主 義	實 用 技 術	實 用 性	
實 用 型	實 用 階 段	實 交	實 名	實 地	實 地 考 察	實 在	實 在 性	
實 在 物	實 存	實 收	實 有	實 至 名 歸	實 行	實 行 改 革	實 行 者	
實 行 家	實 利	實 言 相 告	實 足	實 事	實 事 求 是	實 例	實 性	
實 況	實 況 錄 像	實 況 轉 播	實 物	實 股	實 則	實 型	實 施	
實 施 者	實 施 細 則	實 施 辦 法	實 是	實 派	實 為	實 效	實 時	
實 根	實 益	實 納	實 缺	實 耗	實 務	實 得	實 情	
實 現	實 習	實 習 生	實 習 期	實 處	實 報 實 銷	實 惠	實 測	
實 無	實 發	實 詞	實 意	實 感	實 業	實 業 界	實 業 家	
實 話	實 像	實 境	實 實	實 實 在 在	實 與 有 力	實 說	實 際	
實 際 上	實 際 工 作	實 際 工 資	實 際 水 平	實 際 生 活	實 際 收 入	實 際 行 動	實 際 困 難	
實 際 性	實 際 問 題	實 際 情 況	實 際 意 義	實 際 需 要	實 際 增 長	實 價	實 層	
實 彈	實 數	實 線	實 質	實 質 上	實 質 性	實 質 問 題	實 踐	
實 踐 中	實 踐 經 驗	實 踐 論	實 踐 證 明	實 銷	實 學	實 戰	實 據	
實 蕃 有 徒	實 錄	實 績	實 繁 有 徒	實 購	實 職	實 證	實 證 主 義	
實 難	實 覺	實 屬	實 權	實 驗	實 驗 上	實 驗 心 理 學	實 驗 性	
實 驗 者	實 驗 室	實 驗 員	實 體	實 體 化	實 體 圖	實 觀	寨 子	
寨 主	寨 外	寢 不 安 席	寢 不 遑 安	寢 皮 食 肉	寢 車	寢 具	寢 具 業	
寢 室	寢 食	寢 食 不 安	寢 食 俱 廢	寢 宮	寢 陵	寢 苫 枕 塊	察 三 訪 四	
察 布 查 爾	察 見 淵 魚	察 言 觀 色	察 哈 爾	察 看	察 訪	察 隅	察 察 而 明	
察 察 為 明	察 覺	察 覺 到	對 了	對 二 甲 苯	對 人	對 下	對 上	
對 口	對 口 相 聲	對 大 家 來 說	對 子	對 不	對 不 住	對 不 起	對 不 對	
對 之	對 內	對 內 搞 活	對 公	對 分	對 手	對 方	對 比	
對 比 法	對 比 度	對 比 研 究	對 牛 彈 琴	對 付	對 仗	對 半	對 台 貿 易	
對 台 戲	對 台 關 係	對 句	對 外	對 外 貿 易	對 外 開 放	對 外 經 濟 貿 易 部	對 打	
對 本	對 正	對 白	對 立	對 立 面	對 立 統 一	對 光	對 列	
對 地	對 在	對 此	對 耳	對 位	對 位 法	對 呀	對 局	
對 床 夜 雨	對 床 風 雨	對 我 來 說	對 我 們 來 說	對 抗	對 抗 性	對 抗 賽	對 折	
對 攻	對 每 個 人 來 說	對 私	對 角	對 角 線	對 那	對 使	對 兒	
對 其	對 味	對 岸	對 於	對 法	對 的	對 空	對 門	
對 勁	對 峙	對 弈	對 待	對 恃	對 持	對 流	對 流 層	
對 穿	對 背	對 苯 二 甲 酸	對 苯 二 酚	對 面	對 座	對 案	對 氣 候 的 影 響	
對 消	對 症	對 症 下 藥	對 笑	對 酒 當 歌	對 陣	對 偶	對 唱	
對 帳	對 得 起	對 接	對 現	對 眼	對 硫 磷	對 頂	對 頂 角	
對 換	對 景 傷 情	對 焦	對 等	對 策	對 答	對 答 如 流	對 著	
對 視	對 開	對 嗎	對 極	對 準	對 照	對 照 法	對 照 者	
對 號	對 號 入 座	對 話	對 話 者	對 話 框	對 話 體	對 路	對 過	
對 像	對 像 性	對 對	對 歌	對 稱	對 稱 中 心	對 稱 軸	對 稱 點	
對 舞	對 語	對 說	對 齊	對 嘴	對 敵	對 數	對 數 方 程	
對 數 函 數	對 蝦	對 談	對 調	對 賬	對 質	對 錯	對 頭	
對 應	對 聯	對 講	對 講 機	對 壘	對 轉	對 題	對 簿	
對 襟	對 證	對 邊	屢 有	屢 次	屢 次 三 番	屢 見	屢 見 不 鮮	
屢 受	屢 建 奇 功	屢 教	屢 教 不 改	屢 敗	屢 催	屢 禁	屢 禁 不 止	
屢 禁 不 絕	屢 試	屢 試 不 爽	屢 屢	屢 屢 得 手	屢 增	屢 戰	屢 戰 屢 北	
屢 戰 屢 勝	屢 勸 不 改	嶄 新	嶄 露 頭 角	幣 名	幣 別	幣 制	幣 重 言 甘	
幣 值	幣 種	幣 銖	幕 上	幕 友	幕 天	幕 天 席 地	幕 布	
幕 府	幕 府 將 軍	幕 前	幕 後	幕 後 操 縱	幕 降	幕 帷	幕 間	
幕 僚	幕 幕	幕 賓	幕 劇	幕 燈	幕 燕 鼎 魚	廖 永 來	廖 偉 凡	
廖 慧 珍	弊 多 利 少	弊 衣 疏 食	弊 衣 簞 食	弊 車 駑 馬	弊 車 羸 馬	弊 政	弊 害	
弊 病	弊 習	弊 惡	弊 絕 風 清	弊 端	彆 扭	彰 化	彰 化 銀 行	
彰 往 考 來	彰 往 察 來	彰 明 較 著	彰 善 癉 惡	彰 源 企 業	徹 上 徹 下	徹 尾	徹 夜	
徹 夜 未 眠	徹 底	徹 底 改 變	徹 底 粉 碎	徹 底 清 除	徹 底 解 決	徹 底 澄 清	徹 查	
徹 首 徹 尾	徹 悟	徹 骨	徹 頭 徹 尾	態 度	態 度 生 硬	態 度 端 正	態 勢	
慷 他 人 之 慨	慷 慨	慷 慨 赴 義	慷 慨 捐 生	慷 慨 陳 詞	慷 慨 就 義	慷 慨 悲 歌	慷 慨 解 囊	
慷 慨 激 昂	慷 慨 激 烈	慷 慨 激 揚	慢 一 點	慢 了	慢 下 來	慢 中 子	慢 化 劑	
慢 手	慢 火	慢 件	慢 吃	慢 地	慢 曲	慢 吞 吞	慢 步	
慢 走	慢 車	慢 性	慢 性 子	慢 性 疾 病	慢 性 病	慢 性 精 神 病	慢 板	
慢 待	慢 動 作	慢 悠 悠	慢 條 斯 理	慢 條 斯 禮	慢 條 絲 禮	慢 條 廝 禮	慢 速	
慢 煮	慢 著	慢 跑	慢 跑 者	慢 腳	慢 慢	慢 慢 吞 吞	慢 慢 來	
慢 慢 兒	慢 慢 悠 悠	慢 慢 騰 騰	慢 說	慢 麼	慢 檔	慢 壘	慢 藏 誨 盜	
慢 鏡 頭	慢 騰 騰	慣 了	慣 升	慣 手	慣 犯	慣 用	慣 用 法	
慣 技	慣 例	慣 性	慣 性 力	慣 性 定 律	慣 於	慣 法	慣 匪	
慣 挺	慣 偷	慣 常	慣 常 於	慣 深	慣 盜	慣 養	慣 壞	
慣 竊	慟 哭	慚 色	慚 愧	慘 不 忍 睹	慘 不 忍 聞	慘 兮 兮	慘 叫	
慘 白	慘 死	慘 事	慘 狀	慘 的	慘 毒	慘 相	慘 重	
慘 案	慘 烈	慘 笑	慘 敗	慘 殺	慘 淡	慘 淡 經 營	慘 無 人 道	
慘 然	慘 然 不 樂	慘 痛	慘 絕 人 寰	慘 像	慘 境	慘 慘	慘 禍	
慘 綠 少 年	慘 綠 愁 紅	慘 劇	慘 遭	慘 遭 毒 手	慵 懶	截 口	截 止	
截 出	截 去	截 成	截 收	截 至	截 住	截 尾	截 取	
截 肢	截 肢 術	截 長 補 短	截 流	截 限	截 面	截 留	截 掉	
截 趾 適 履	截 然	截 然 不 同	截 發 留 賓	截 短	截 距	截 開	截 盤	
截 稿	截 線	截 頭	截 擊	截 擊 機	截 獲	截 斷	截 斷 器	
截 攔	截 聽	截 癱	截 鐙 留 鞭	撇 下	撇 子	撇 去	撇 取	
撇 掉	撇 棄	撇 開	撇 號	撇 嘴	摘 下	摘 山 煮 海	摘 引	
摘 心	摘 出	摘 去	摘 句	摘 句 尋 章	摘 由	摘 伏 發 隱	摘 奸 發 伏	
摘 自	摘 抄	摘 走	摘 取	摘 取 桂 冠	摘 花	摘 要	摘 述	
摘 借	摘 記	摘 除	摘 掉	摘 報	摘 發	摘 編	摘 錄	
摘 錄 者	摘 膽 剜 心	摘 蘋 果	摘 譯	摔 下	摔 打	摔 交	摔 在	
摔 死	摔 角	摔 到	摔 倒	摔 破	摔 得	摔 掉	摔 開	
摔 傷	摔 毀	摔 碎	摔 跟 頭	摔 跤	摔 壞	撤 了	撤 出	
撤 去	撤 回	撤 守	撤 免	撤 兵	撤 完	撤 走	撤 防	
撤 空	撤 架	撤 軍	撤 席	撤 消	撤 退	撤 除	撤 掉	
撤 換	撤 訴	撤 資	撤 銷	撤 銷 職 務	撤 營	撤 職	撤 職 查 辦	
撤 離	摸 不 著 頭 腦	摸 出	摸 去	摸 有	摸 弄	摸 來	摸 到	
摸 底	摸 爬 滾 打	摸 門 不 著	摸 門 兒	摸 看	摸 索	摸 索 著	摸 彩	
摸 彩 箱	摸 清	摸 袋 子	摸 透	摸 魚	摸 著	摸 黑	摸 準	
摸 稜 兩 可	摸 過	摸 摸	摸 頭 不 著	摸 雞 偷 狗	摟 在	摟 住	摟 抱	
摟 梯	摟 著	摟 摟	摟 頸	摺 合	摺 痕	摺 椅	摺 縫	
摺 疊	摧 山 攪 海	摧 志 屈 道	摧 身 碎 首	摧 花	摧 花 斫 柳	摧 枯 折 腐	摧 枯 拉 朽	
摧 枯 拉 腐	摧 眉 折 腰	摧 胸 剖 肝	摧 胸 破 肝	摧 堅 陷 陣	摧 堅 獲 丑	摧 堅 殪 敵	摧 殘	
摧 毀	摧 鋒 陷 陣	摧 蘭 折 玉	搴 旗 取 將	搴 旗 斬 馘	搴 旗 虜 將	摭 華 損 實	摻 入	
摻 水	摻 合	摻 有	摻 兌	摻 沙 子	摻 制	摻 和	摻 假	
摻 混	摻 進	摻 雜	敲 入	敲 下	敲 山 震 虎	敲 牛 宰 馬	敲 出	
敲 平	敲 打	敲 竹 槓	敲 定	敲 金 戛 玉	敲 金 擊 玉	敲 金 擊 石	敲 門	
敲 門 者	敲 門 磚	敲 破	敲 釘	敲 釘 子	敲 骨 吸 髓	敲 骨 剝 髓	敲 掉	
敲 喪 鐘	敲 詐	敲 詐 者	敲 詐 勒 索	敲 進	敲 開	敲 搾	敲 碎	
敲 鼓 聲	敲 敲 打 打	敲 擊	敲 擊 者	敲 聲	敲 邊	敲 邊 鼓	敲 鐘	
敲 響	敲 彎	敲 鑼	敲 鑼 打 鼓	斡 旋	旗 人	旗 下	旗 子	
旗 山	旗 手	旗 兒	旗 官	旗 竿	旗 桿	旗 袍	旗 魚	
旗 開 取 勝	旗 開 馬 到	旗 開 得 勝	旗 艇	旗 號	旗 鼓 相 望	旗 鼓 相 當	旗 語	
旗 幟	旗 幟 鮮 明	旗 繩	旗 艦	旗 艦 店	旖 旎	旖 旎 風 光	暢 心	
暢 行	暢 行 無 阻	暢 快	暢 所 欲 言	暢 流	暢 書	暢 敘	暢 通	
暢 通 無 阻	暢 飲	暢 想	暢 遊	暢 達	暢 談	暢 銷	暢 銷 品	
暢 銷 書	暢 銷 貨	暢 懷	榜 上 有 名	榜 上 無 名	榜 首	榜 樣	榨 汁 機	
榕 樹	槁 木 死 灰	槁 項 黃 馘	榮 化	榮 立	榮 任	榮 成 紙 業	榮 典	
榮 宗 耀 祖	榮 幸	榮 星 電 線	榮 美	榮 美 開 發	榮 軍	榮 剛 材 料	榮 辱	
榮 辱 與 共	榮 登	榮 登 榜 首	榮 華	榮 華 富 貴	榮 祿	榮 獲	榮 膺	
榮 歸	榮 耀	榮 譽	榮 譽 軍 人	榮 譽 章	榮 譽 感	榮 譽 稱 號	榮 譽 獎	
榮 譽 權	槓 上 開 花	槓 子	槓 夫	槓 竹	槓 桿	槓 桿 作 用	槓 鈴	
構 上	構 化	構 台	構 件	構 地	構 成	構 成 者	構 型	
構 建	構 思	構 怨 連 兵	構 架	構 造	構 造 上	構 造 學	構 陷	
構 詞	構 塊	構 想	構 圖	構 築	構 築 物	榛 子	榻 米	
榻 榻 米	榫 子	榫 接	榫 眼	榫 頭	榴 彈	榴 彈 炮	榴 蓮	
榴 蓮 果	槐 花	槐 樹	槍 口	槍 手	槍 支	槍 矛	槍 匠	
槍 尖	槍 尖 形	槍 托	槍 把	槍 決	槍 身	槍 刺	槍 林	
槍 林 彈 雨	槍 法	槍 柄	槍 炮	槍 炮 齊 鳴	槍 閂	槍 套	槍 桿	
槍 桿 子	槍 械	槍 殺	槍 眼	槍 術	槍 筒	槍 傷	槍 靶	
槍 槍	槍 種	槍 管	槍 彈	槍 膛	槍 戰	槍 機	槍 擊	
槍 斃	槍 聲	槍 響 了	槌 子	槌 狀	槌 骨 瀝 髓	槌 球	槌 球 錦 標 賽	
槌 棒	歉 年	歉 收	歉 疚	歉 虛	歉 意	歌 女	歌 手	
歌 王	歌 仔 戲	歌 功 頌 德	歌 台 舞 榭	歌 本	歌 曲	歌 曲 集	歌 妓	
歌 兒	歌 林	歌 林 公 司	歌 者	歌 星	歌 唱	歌 唱 家	歌 唱 隊	
歌 唱 演 員	歌 組	歌 訣	歌 喉	歌 詠	歌 詞	歌 集	歌 會	
歌 頌	歌 舞	歌 舞 升 平	歌 舞 太 平	歌 舞 妓	歌 舞 會	歌 舞 團	歌 舞 劇	
歌 舞 廳	歌 舞 伎	歌 劇	歌 劇 院	歌 劇 團	歌 德	歌 樓 舞 管	歌 調	
歌 壇	歌 聲	歌 聲 繞 樑	歌 謠	歌 譜	歌 鶯 舞 燕	歌 廳	漳 州	
演 人	演 化	演 出	演 出 團	演 古 勸 今	演 示	演 回	演 成	
演 有	演 完	演 技	演 技 術	演 到	演 武 修 文	演 法	演 者	
演 奏	演 奏 台	演 奏 者	演 奏 員	演 奏 家	演 奏 會	演 員	演 唱	
演 唱 會	演 得	演 習	演 進	演 義	演 算	演 算 出	演 算 法	
演 說	演 說 台	演 說 者	演 說 家	演 說 術	演 說 等	演 劇	演 播	
演 練	演 壇	演 戲	演 戲 似	演 戲 船	演 講	演 講 者	演 講 座 談	
演 講 術	演 講 詞	演 講 集	演 講 會	演 講 學	演 繹	演 繹 出	演 繹 式	
演 繹 法	演 藝	演 藝 圈	演 變	滾 刀	滾 上	滾 子	滾 木	
滾 水	滾 打	滾 瓜 溜 圓	滾 瓜 爛 熟	滾 石	滾 回	滾 作	滾 利	
滾 沸	滾 屏	滾 柱 軸 承	滾 倒	滾 珠	滾 珠 軸 承	滾 針	滾 動	
滾 動 軸 承	滾 動 摩 擦	滾 得	滾 球	滾 蛋	滾 雪 球	滾 湯	滾 筒	
滾 著	滾 軸	滾 進	滾 開	滾 圓	滾 滑	滾 落	滾 過	
滾 滾	滾 滾 向 前	滾 滾 而 來	滾 銑	滾 熱	滾 輪	滾 燙	滾 翻	
滾 轉	滾 邊	漓 江	滴 下	滴 下 物	滴 水	滴 水 不 漏	滴 水 石	
滴 水 石 穿	滴 水 成 冰	滴 水 成 凍	滴 水 穿 石	滴 出	滴 血	滴 定	滴 定 管	
滴 注	滴 流	滴 乾	滴 答	滴 答 聲	滴 量	滴 量 計	滴 溜	
滴 落	滴 滴	滴 滴 涕	滴 管	滴 蟲	滴 蟲 類	滴 灌	漩 風	
漩 渦	漾 奶	漠 不 關 心	漠 然	漠 然 置 之	漠 視	漠 漠	漏 勺	
漏 子	漏 斗	漏 斗 形	漏 水	漏 出	漏 出 量	漏 加	漏 失	
漏 光	漏 列	漏 字	漏 扣	漏 收	漏 池	漏 夜	漏 底	
漏 征	漏 雨	漏 屋	漏 查	漏 洞	漏 洞 百 出	漏 洩 天 機	漏 洩 春 光	
漏 計	漏 風	漏 氣	漏 納	漏 記	漏 做	漏 兜	漏 接 球	
漏 掉	漏 脯 充 饑	漏 報	漏 壺	漏 稅	漏 填	漏 損	漏 電	
漏 劃	漏 盡	漏 盡 更 闌	漏 網	漏 網 之 魚	漏 網 游 魚	漏 誤	漏 隙	
漏 嘴	漏 辦	漏 縫	漏 鍋	漏 甕 沃 焦 釜	漏 轉	漏 繳	漏 讀	
漂 了	漂 去	漂 母 進 飯	漂 白	漂 白 粉	漂 白 劑	漂 向	漂 行	
漂 來 物	漂 泊	漂 亮	漂 亮 話	漂 染	漂 洋 過 海	漂 流	漂 流 物	
漂 流 者	漂 洗	漂 海	漂 浮	漂 浮 物	漂 浮 者	漂 起	漂 淨	
漂 移	漂 散	漂 游	漂 渺	漂 著	漂 進	漂 落	漂 零	
漂 零 蓬 斷	漂 漂	漂 漂 亮 亮	漂 蕩	漢 人	漢 口	漢 子	漢 川	
漢 中	漢 化	漢 文	漢 水	漢 代	漢 卡	漢 平 電 子	漢 民	
漢 白 玉	漢 奸	漢 字	漢 字 編 碼	漢 克 阿 倫	漢 官 威 儀	漢 沽	漢 城	
漢 英	漢 唐	漢 唐 訊 聯	漢 宮	漢 書	漢 密 爾 敦	漢 族	漢 陰	
漢 堡	漢 堡 包	漢 普 頓	漢 朝	漢 翔 公 司	漢 翔 航 太 公 司	漢 翔 航 空	漢 陽	
漢 源	漢 賊 不 兩 立	漢 墓	漢 壽	漢 語	漢 語 拼 音	漢 劇	漢 磊	
漢 磊 科 技	漢 學	漢 學 家	漢 諾 威	漢 醫	漢 譯	漢 顯	滿 了	
滿 人	滿 也	滿 口	滿 口 袋	滿 口 答 應	滿 山 遍 野	滿 不	滿 不 在 乎	
滿 分	滿 天	滿 天 星	滿 天 飛	滿 心	滿 心 歡 喜	滿 手	滿 文	
滿 月	滿 出	滿 打 滿 算	滿 目	滿 目 荊 榛	滿 目 瘡 痍	滿 地	滿 州	
滿 州 人	滿 州 裡	滿 有	滿 而 不 溢	滿 舌 生 花	滿 位	滿 佈	滿 含 熱 淚	
滿 坑 滿 谷	滿 足	滿 足 於	滿 足 要 求	滿 身	滿 招	滿 招 損 謙 受 益	滿 於	
滿 杯	滿 的	滿 門	滿 城	滿 城 風 雨	滿 屏	滿 屋	滿 是	
滿 洲	滿 洲 問 題	滿 洲 國	滿 盈	滿 盆	滿 負 荷	滿 面	滿 面 春 風	
滿 面 紅 光	滿 員	滿 師	滿 座	滿 座 風 生	滿 兜	滿 堂	滿 堂 紅	
滿 族	滿 族 人	滿 桶	滿 條	滿 清	滿 眼	滿 處	滿 袖 春 風	
滿 袋	滿 貫	滿 都	滿 場	滿 期	滿 腔	滿 腔 熱 血	滿 腔 熱 忱	
滿 腔 熱 情	滿 街	滿 園 春 色	滿 意	滿 歲	滿 溢	滿 碗	滿 腹	
滿 腹 文 章	滿 腹 牢 騷	滿 腹 狐 疑	滿 腹 經 綸	滿 腦	滿 載	滿 載 而 歸	滿 旗	
滿 漢	滿 滿	滿 滿 的	滿 滿 噹 噹	滿 語	滿 嘴	滿 盤	滿 盤 皆 輸	
滿 箱	滿 錢 袋	滿 頭	滿 頭 大 汗	滿 臉	滿 臉 通 紅	滿 額	滿 懷	
滿 懷 信 心	滿 籃	滯 水	滯 後	滯 留	滯 留 費	滯 納	滯 納 金	
滯 脹	滯 銷	滯 銷 品	滯 銷 貨	滯 積	滯 礙	漆 上	漆 工	
漆 木 紋	漆 片	漆 包 線	漆 皮	漆 匠	漆 成	漆 身 吞 炭	漆 桶	
漆 畫	漆 黑	漆 黑 一 團	漆 槍	漆 漆	漆 彈 遊 戲	漆 器	漆 樹	
漱 口	漱 口 劑	漱 流 枕 石	漱 洗	漱 喉	漸 入 佳 境	漸 少	漸 欠	
漸 多	漸 成	漸 有	漸 次	漸 老	漸 至 佳 境	漸 伸	漸 沒	
漸 使	漸 屈 線	漸 明	漸 近	漸 近 線	漸 降 法	漸 凍 人	漸 弱	
漸 強	漸 淡	漸 混	漸 現	漸 被	漸 減	漸 短	漸 進	
漸 黑	漸 慢	漸 滿	漸 漸	漸 熄	漸 增	漸 濃	漸 趨	
漸 隱	漸 露 端 倪	漸 變	漸 顯	漲 大	漲 升	漲 水	漲 出	
漲 到	漲 紅	漲 風	漲 幅	漲 跌	漲 勢	漲 落	漲 滿	
漲 價	漲 潮	漲 潮 點	漣 水	漣 源	漣 漣	漣 漪	漕 運	
漫 山	漫 山 遍 野	漫 不 經 心	漫 反 射	漫 天	漫 天 匝 地	漫 天 塞 地	漫 天 遍 野	
漫 天 徹 地	漫 天 漫 地	漫 天 蓋 地	漫 地 滿 天	漫 步	漫 步 者	漫 卷	漫 延	
漫 長	漫 長 的	漫 長 歲 月	漫 射	漫 散	漫 無	漫 無 止 境	漫 無 邊 際	
漫 畫	漫 畫 屋	漫 畫 家	漫 筆	漫 話	漫 遊	漫 過	漫 漫	
漫 說	漫 罵	漫 談	漫 誕 不 稽	澈 底	滬 市	滬 杭	滬 劇	
漁 人	漁 人 之 利	漁 人 得 利	漁 夫	漁 火	漁 市	漁 民	漁 池	
漁 汛	漁 舟	漁 利	漁 村	漁 事 糾 紛	漁 具	漁 政	漁 家	
漁 翁	漁 翁 之 利	漁 翁 得 利	漁 區	漁 產	漁 船	漁 場	漁 期	
漁 港	漁 陽 鼙 鼓	漁 會	漁 業	漁 業 署	漁 經 獵 史	漁 歌	漁 網	
漁 輪	漁 獵	漁 霸	滲 入	滲 井	滲 化	滲 水	滲 出	
滲 出 液	滲 出 量	滲 性	滲 析	滲 流	滲 透	滲 透 性	滲 透 物	
滲 透 者	滲 透 壓	滲 進	滲 漏	滲 濾	滲 濾 器	滲 變	滌 故 更 新	
滌 除	滌 瑕 蕩 垢	滌 瑕 蕩 穢	滌 綸	滌 綸 線	滌 槽	滌 蕩	滌 穢 蕩 瑕	
滷 水	滷 肉	滷 味	滷 菜	熔 化	熔 合	熔 為	熔 接	
熔 焊	熔 渣	熔 絲	熔 煉	熔 解	熔 膠 鍋	熔 劑	熔 融	
熔 點	熔 斷	熔 爐	熔 鑄	熔 巖	熔 巖 流	熙 來 攘 往	熙 春 茶	
熙 熙	熙 熙 融 融	熙 熙 攘 攘	熙 攘	煽 火	煽 風	煽 風 點 火	煽 扇 人	
煽 起	煽 動	煽 動 性	煽 動 者	煽 情	煽 惑	煽 誘	熊 一 樣	
熊 天 平	熊 心 豹 膽	熊 市	熊 本 市	熊 皮	熊 虎 之 士	熊 掌	熊 經 鳥 申	
熊 經 鴟 頸	熊 腰 虎 背	熊 熊	熊 熊 大 火	熊 熊 燃 燒	熊 罷 之 祥	熊 貓	熊 膽	
熊 類	熊 羆 之 士	熄 火	熄 滅	熄 滅 了	熄 燈	熒 火	熒 火 蟲	
熒 石	熒 光	熒 光 性	熒 光 屏	熒 光 粉	熒 光 學	熒 光 燈	熒 屏	
熒 幕	熒 熒	爾 人	爾 式	爾 汝 之 交	爾 自	爾 非	爾 後	
爾 省	爾 格	爾 族	爾 等	爾 詐 我 虞	爾 雅	爾 雅 溫 文	爾 虞 我 詐	
爾 歌	爾 爾	爾 語	犒 勞	犒 賞	獄 中	獄 吏	獄 卒	
獄 官	獄 長	獄 門	獄 室	獄 政	獐 頭 鼠 目	獐 頭 鼠 腦	瑤 台 銀 闕	
瑤 台 瓊 室	瑤 池	瑤 池 玉 液	瑤 池 閬 苑	瑤 林 瓊 樹	瑤 草 琪 花	瑤 族	瑤 環 瑜 珥	
瑣 吶	瑣 尾 流 離	瑣 言	瑣 事	瑣 物	瑣 屑	瑣 務	瑣 細	
瑣 碎	瑣 瑣 碎 碎	瑣 緊	瑣 聞	瑪 丹 娜	瑪 家 鄉	瑪 雅	瑪 雅 人	
瑪 瑙	瑪 瑙 貝	瑰 偉	瑰 異	瑰 意 琦 行	瑰 麗	瑰 寶	甄 才 品 能	
甄 別	甄 奇 錄 異	甄 妮	甄 煩 就 簡	甄 試	甄 選	疑 人 勿 使 使 人 勿 疑	疑 人 疑 鬼	
疑 心	疑 心 生 鬼	疑 心 生 暗 鬼	疑 心 病	疑 犯	疑 兇	疑 行 無 名 疑 事 無 功	疑 行 無 成 疑 事 無 功	
疑 似	疑 忌	疑 事 無 功	疑 事 無 功 疑 行 無 名	疑 者	疑 信 參 半	疑 為	疑 案	
疑 神 見 鬼	疑 神 疑 鬼	疑 鬼 疑 神	疑 問	疑 惑	疑 雲	疑 義	疑 團	
疑 慮	疑 點	疑 難	疑 難 問 題	疑 難 解 答	疑 難 雜 症	疑 竇	疑 懼	
瘧 原 蟲	瘧 疾	瘧 蚊	瘧 蟲	瘋 了	瘋 人	瘋 人 院	瘋 女	
瘋 子	瘋 去	瘋 似	瘋 狂	瘋 狂 似	瘋 狂 般	瘋 狗	瘋 長	
瘋 病	瘋 症	瘋 話	瘋 瘋 癲 癲	瘋 魔	瘋 癱	瘋 癲	盡 人 皆 知	
盡 入 彀 中	盡 力	盡 力 而 為	盡 力 盡 責	盡 上	盡 心	盡 心 圖 極	盡 心 盡 力	
盡 心 盡 意	盡 心 盡 職	盡 心 竭 力	盡 心 竭 誠	盡 日 窮 夜	盡 可	盡 可 能	盡 失	
盡 伏 東 流	盡 全	盡 全 力	盡 在	盡 在 其 中	盡 如	盡 如 人 意	盡 收	
盡 收 眼 底	盡 早	盡 自	盡 孝	盡 快	盡 言	盡 其	盡 其 在 我	
盡 其 所 有	盡 到	盡 到 責 任	盡 忠	盡 忠 報 國	盡 忠 盡 職	盡 忠 竭 力	盡 性	
盡 知	盡 是	盡 美 盡 善	盡 致	盡 情	盡 情 盡 理	盡 棄	盡 責	
盡 責 盡 力	盡 速	盡 最	盡 最 大 努 力	盡 期	盡 然	盡 善 盡 美	盡 量	
盡 意	盡 瘁	盡 瘁 事 國	盡 瘁 鞠 躬	盡 節 竭 誠	盡 義 務	盡 誠 竭 節	盡 態 極 妍	
盡 數	盡 盤 將 軍	盡 興	盡 興 而 歸	盡 頭	盡 職	盡 職 盡 責	盡 歡	
盡 讓	監 工	監 主 自 盜	監 犯	監 生	監 用	監 交	監 印	
監 守	監 守 自 盜	監 守 官	監 收	監 考	監 考 人	監 考 官	監 牢	
監 事	監 委	監 房	監 門 之 養	監 查	監 控	監 控 器	監 捨	
監 理	監 理 所	監 理 站	監 票	監 場	監 測	監 測 站	監 視	
監 視 人	監 視 者	監 視 員	監 視 雷 達	監 視 器	監 督	監 督 官	監 督 者	
監 督 哨	監 督 員	監 督 站	監 禁	監 察	監 察 局	監 察 委 員	監 察 員	
監 察 院	監 察 部	監 獄	監 管	監 製	監 賣	監 銷	監 臨 自 盜	
監 繳	監 護	監 護 人	監 聽	監 聽 器	瞄 出	瞄 著	瞄 準	
瞄 準 具	瞄 準 洞	瞄 準 儀	瞄 準 器	睽 情 度 理	睽 睽	睿 智	睿 達	
睡 一 覺	睡 了	睡 下	睡 不 著	睡 午 覺	睡 去	睡 在	睡 好	
睡 衣	睡 衣 褲	睡 床	睡 足	睡 服	睡 者	睡 臥 不 安	睡 臥 不 寧	
睡 前	睡 思	睡 相	睡 病 蟲	睡 眠	睡 眠 中	睡 眠 者	睡 眠 症	
睡 神	睡 起	睡 得	睡 眼	睡 眼 惺 忪	睡 袍	睡 袋	睡 帽	
睡 椅	睡 游 病	睡 著	睡 著 了	睡 鄉	睡 意	睡 意 正 濃	睡 獅	
睡 過	睡 過 頭	睡 像	睡 夢	睡 態	睡 睡	睡 熟	睡 蓮	
睡 褲	睡 醒	睡 覺	睡 魔	磁 力	磁 力 計	磁 力 線	磁 化	
磁 化 器	磁 心	磁 片	磁 卡	磁 石	磁 束	磁 性	磁 波	
磁 泡	磁 芯	磁 流	磁 流 體	磁 軌	磁 效 應	磁 珠	磁 矩	
磁 粉	磁 能	磁 針	磁 動	磁 帶	磁 條	磁 球	磁 瓶	
磁 通	磁 通 量	磁 場	磁 棒	磁 塊	磁 感 應	磁 極	磁 路	
磁 道	磁 電	磁 電 管	磁 電 學	磁 電 機	磁 鼓	磁 碟	磁 碟 片	
磁 碟 機	磁 管	磁 暴	磁 盤	磁 盤 片	磁 線	磁 膜	磁 質	
磁 器	磁 學	磁 學 家	磁 導	磁 磚	磁 縣	磁 選	磁 鋼	
磁 頭	磁 療	磁 療 器	磁 鐵	磁 鐵 礦	磁 體	碟 子	碟 片	
碟 形	碟 盆 類	碧 土	碧 水	碧 玉	碧 瓦	碧 瓦 朱 甍	碧 色	
碧 血	碧 血 丹 心	碧 波	碧 空	碧 桃	碧 海	碧 海 青 天	碧 草	
碧 悠 電 子	碧 眼	碧 雲	碧 落 黃 泉	碧 瑤	碧 綠	碧 綠 色	碧 螺 春	
碧 藍	碳 化	碳 化 物	碳 化 氫	碳 化 鈣	碳 化 硅	碳 水	碳 水 化 合 物	
碳 粉	碳 素	碳 素 鋼	碳 氫 化 合 物	碳 棒	碳 黑	碳 煙	碳 精	
碳 酸	碳 酸 氫 鈉	碳 酸 氫 銨	碳 酸 鈣	碳 酸 鈉	碳 酸 鉀	碳 酸 銨	碳 酸 鎂	
碳 酸 鹽	碳 鋼	碩 士	碩 士 生	碩 士 研 究 生	碩 士 學 位	碩 大	碩 大 無 比	
碩 大 無 朋	碩 果	碩 果 僅 存	碩 果 纍 纍	福 大 棉 業	福 山 雅 治	福 不 重 至 禍 必 重 來	福 不 徒 來	
福 中	福 兮 禍 所 伏	福 兮 禍 所 倚	福 分	福 生 於 微	福 份	福 地	福 地 洞 天	
福 如 山 嶽	福 如 東 海	福 如 海 淵	福 州	福 州 市	福 至 心 靈	福 佑	福 利	
福 利 主 義	福 利 事 業	福 利 社	福 利 待 遇	福 利 政 策	福 利 院	福 利 費	福 利 廠	
福 來	福 岡	福 於 天 齊	福 物	福 建	福 建 省	福 星	福 為 禍 先	
福 為 禍 始	福 相	福 祉	福 音	福 音 書	福 氣	福 海	福 特	
福 益 紡 織	福 神	福 貢	福 惠 雙 修	福 無 十 全	福 無 雙 至 禍 不 單 行	福 善 禍 淫	福 業 相 牽	
福 煦	福 祿 雙 全	福 裕 事 業	福 過 災 生	福 鼎	福 壽	福 壽 天 成	福 壽 年 高	
福 壽 康 寧	福 壽 實 業	福 壽 綿 長	福 壽 綿 綿	福 壽 齊 天	福 壽 雙 全	福 爾 馬 林	福 爾 摩 斯	
福 禍	福 聚	福 聚 公 司	福 齊 南 山	福 澤	福 澤 諭 吉	福 興	福 興 鄉	
福 懋 油 脂	福 懋 興 業	福 禮	福 纖 實 業	禍 不 反 踵	禍 不 妄 至	禍 不 旋 踵	禍 不 單 行	
禍 中 有 福	禍 及	禍 心	禍 水	禍 出 不 測	禍 生 不 測	禍 生 肘 腋	禍 生 於 忽	
禍 生 蕭 牆	禍 因 惡 積	禍 在 旦 夕	禍 在 朝 夕	禍 至 神 昧	禍 色	禍 作 福 階	禍 事	
禍 於	禍 於 福 鄰	禍 殃	禍 為 福 先	禍 盈 惡 稔	禍 首	禍 首 罪 魁	禍 害	
禍 根	禍 起 飛 語	禍 起 蕭 牆	禍 起 隱 微	禍 國	禍 國 殃 民	禍 從 口 出	禍 從 天 降	
禍 患	禍 棗 災 梨	禍 發 齒 牙	禍 發 蕭 牆	禍 結 兵 連	禍 結 釁 深	禍 絕 福 連	禍 亂	
禍 亂 交 興	禍 亂 滔 天	禍 稔 惡 盈	禍 稔 蕭 牆	禍 福	禍 福 由 人	禍 福 同 門	禍 福 有 命	
禍 福 相 生	禍 福 相 倚	禍 福 惟 人	禍 福 無 門	禍 福 無 偏	禍 福 無 常	禍 福 靡 常	禍 種	
禍 端	禍 興 蕭 牆	種 了	種 下	種 上	種 子	種 子 選 手	種 牛 痘	
種 瓜	種 瓜 得 瓜	種 瓜 得 瓜 種 豆 得 豆	種 田	種 皮	種 地	種 在	種 別	
種 形 成	種 豆	種 姓	種 的	種 肥	種 花	種 花 人	種 籽	
種 苗	種 差	種 畜	種 草	種 族	種 族 主 義	種 族 歧 視	種 族 政 策	
種 族 間	種 族 隔 離	種 族 學	種 麥 得 麥	種 麻	種 植	種 植 者	種 植 場	
種 植 園	種 植 業	種 痘	種 菜	種 禽	種 群	種 種	種 種 跡 像 表 明	
種 數	種 稻	種 豬	種 養	種 樹	種 糧	種 類	稱 上	
稱 之	稱 之 為	稱 引	稱 心	稱 心 如 意	稱 心 滿 意	稱 斤 注 兩	稱 曰	
稱 王	稱 王 稱 霸	稱 兄 道 弟	稱 出	稱 多	稱 臣	稱 臣 納 貢	稱 作	
稱 快	稱 身	稱 呼	稱 奇	稱 孤 道 寡	稱 便	稱 為	稱 重	
稱 重 量	稱 家 有 無	稱 病	稱 做	稱 得	稱 得 上	稱 許	稱 善	
稱 量	稱 雄	稱 意	稱 羨	稱 號	稱 道	稱 頌	稱 說	
稱 歎	稱 賞	稱 賢 薦 能	稱 謂	稱 謝	稱 錘 落 井	稱 職	稱 願	
稱 譽	稱 霸	稱 霸 世 界	稱 讚	窪 地	窪 陷	窪 窪	窩 上	
窩 工	窩 心	窩 火	窩 主	窩 瓜	窩 兒	窩 停 主 人	窩 巢	
窩 棚	窩 蜂	窩 裡	窩 窩	窩 窩 頭	窩 頭	窩 藏	窩 邊 草	
窩 贓	窩 囊	窩 囊 氣	窩 囊 廢	竭 力	竭 智 盡 力	竭 智 盡 忠	竭 誠	
竭 誠 服 務	竭 誠 盡 節	竭 盡	竭 盡 全 力	竭 慮	竭 澤 而 漁	端 人 正 士	端 上	
端 口	端 子	端 子 線	端 午	端 午 節	端 方	端 木	端 水	
端 出	端 本 正 源	端 本 清 源	端 正	端 正 黨 風	端 由	端 向	端 行	
端 坐	端 來	端 柱	端 相	端 面	端 倪	端 納	端 茶	
端 接	端 莊	端 硯	端 著	端 菜	端 視	端 陽	端 詳	
端 電 壓	端 端 正 正	端 緒	端 線	端 整	端 機	端 點	管 了	
管 人	管 口	管 子	管 子 工	管 中	管 中 窺 天	管 中 窺 豹	管 井	
管 戶	管 片	管 他	管 卡	管 用	管 仲	管 件	管 吃	
管 好	管 死	管 自	管 住	管 形	管 我	管 束	管 材	
管 見	管 見 所 及	管 事	管 兒	管 制	管 制 區	管 委 會	管 店	
管 弦	管 弦 樂	管 弦 樂 隊	管 押	管 狀	管 芯	管 保	管 城 毛 穎	
管 待	管 查	管 界	管 家	管 座	管 紗	管 訓	管 區	
管 帶	管 帳	管 教	管 教 好	管 理	管 理 人	管 理 局	管 理 所	
管 理 者	管 理 股 票	管 理 員	管 理 站	管 理 處	管 理 費	管 理 器	管 理 學	
管 絃 樂	管 絃 樂 團	管 處	管 殼	管 窖 人	管 閒 事	管 隊	管 飯	
管 腳	管 路	管 道	管 道 工	管 過	管 鉗	管 寧 割 席	管 網	
管 樂	管 樂 器	管 線	管 誰	管 賬	管 壁	管 機	管 窺	
管 窺 之 見	管 窺 筐 舉	管 窺 蠡 測	管 鮑 之 交	管 鮑 分 金	管 轄	管 轄 權	管 嚴	
管 護	箕 山 之 志	箕 山 之 節	箕 帚 之 使	箕 風 畢 雨	箕 裘 相 繼	箋 本	箋 言	
箋 注	箋 紙	箋 薄	筵 宴	筵 席	筵 謦	算 了	算 人	
算 入	算 上	算 子	算 不 了	算 尺	算 方	算 出	算 出 來	
算 去	算 在	算 式	算 作	算 來	算 卦	算 命	算 命 者	
算 定	算 法	算 法 語 言	算 是	算 計	算 起	算 做	算 啦	
算 帳	算 得	算 得 了	算 清	算 術	算 術 化	算 術 家	算 術 級 數	
算 術 題	算 無 遺 策	算 進	算 數	算 盤	算 賬	算 錯	算 題	
箝 口 結 舌	箝 制	箔 片	箔 匠	箔 材	箔 紙	箔 條	箸 長 碗 短	
粽 子	精 力	精 力 充 沛	精 子	精 工	精 工 錶	精 元 電 腦	精 心	
精 心 勵 志	精 包	精 巧	精 打	精 打 細 算	精 光	精 肉	精 兵	
精 兵 猛 將	精 兵 簡 政	精 壯	精 妙	精 妙 入 神	精 妙 絕 倫	精 技 電 腦	精 良	
精 到	精 奇 古 怪	精 忠	精 忠 報 國	精 怪	精 於	精 明	精 明 能 幹	
精 明 強 幹	精 河	精 油	精 表	精 采	精 金 百 煉	精 金 良 玉	精 金 美 玉	
精 品	精 度	精 挑	精 省	精 美	精 英	精 英 電 腦	精 英 獎	
精 英 賽	精 悍	精 悍 短 小	精 梳	精 氣	精 氣 神	精 疲 力 盡	精 疲 力 竭	
精 益 求 精	精 神	精 神 上	精 神 分 裂 症	精 神 文 明	精 神 世 界	精 神 好	精 神 抖 擻	
精 神 所 加 金 石 為 開	精 神 病	精 神 煥 發	精 神 滿 腹	精 神 論	精 紡	精 索	精 純	
精 耕	精 耕 細 作	精 國	精 密	精 密 度	精 密 儀 器	精 巢	精 彩	
精 彩 逼 人	精 液	精 深	精 深 博 大	精 細	精 細 管	精 貫 白 日	精 通	
精 減	精 湛	精 萃	精 華	精 幹	精 微	精 業	精 業 公 司	
精 煉	精 煉 廠	精 義 入 神	精 裝	精 裝 本	精 裝 書	精 誠	精 誠 所 加 金 石 為 開	
精 誠 貫 日	精 誠 團 結	精 飼 料	精 圖	精 碟 科 技	精 算	精 粹	精 製	
精 確	精 確 性	精 確 度	精 練	精 緻	精 衛	精 衛 添 海	精 銳	
精 銳 部 隊	精 整	精 選	精 選 者	精 雕	精 雕 細 刻	精 雕 細 鏤	精 講 多 練	
精 簡	精 簡 了	精 簡 人 員	精 簡 整 編	精 簡 機 構	精 蟲	精 餾	精 餾 塔	
精 礦	精 闢	精 囊	精 讀	精 髓	精 靈	精 鹽	綻 放	
綻 裂	綻 開	綻 線	綰 帶	綜 上	綜 上 所 述	綜 合	綜 合 大 學	
綜 合 分 析	綜 合 平 衡	綜 合 利 用	綜 合 防 治	綜 合 性	綜 合 者	綜 合 研 究	綜 合 症	
綜 合 商 店	綜 合 國 力	綜 合 開 發	綜 合 經 營	綜 合 獎	綜 合 類 股	綜 合 體	綜 括	
綜 述	綜 絲	綜 藝	綜 藝 大 觀	綜 覽	綜 觀	綽 有 餘 裕	綽 約	
綽 約 多 姿	綽 敬	綽 號	綽 綽	綽 綽 有 裕	綽 綽 有 餘	綾 絹	綾 羅	
綠 女 紅 男	綠 內 障	綠 化	綠 化 活 動	綠 化 祖 國	綠 水	綠 水 青 山	綠 卡	
綠 皮	綠 地	綠 灰 色	綠 竹	綠 色	綠 色 工 程	綠 色 和 平 組 織	綠 色 革 命	
綠 色 食 品	綠 色 植 物	綠 衣 使 者	綠 衣 黃 裡	綠 豆	綠 林	綠 林 好 漢	綠 林 豪 客	
綠 松	綠 油 油	綠 的	綠 肥	綠 肥 紅 瘦	綠 芽	綠 青	綠 春	
綠 柱 玉	綠 洲	綠 島	綠 島 蘭 嶼	綠 草	綠 茵	綠 茵 茵	綠 茶	
綠 閃 石	綠 帶 區	綠 眼	綠 野	綠 帽	綠 意	綠 暗 紅 稀	綠 葉	
綠 葉 成 蔭	綠 慘 紅 愁	綠 綠	綠 瑩 瑩	綠 蔭	綠 樹	綠 燈	綠 頭	
綠 營	綠 薔 薇	綠 藍	綠 寶 石	綠 礬	綠 藻	綠 黨	綠 黴 素	
綠 鬢 朱 顏	綠 ��	緊 了	緊 巴	緊 巴 巴	緊 日	緊 日 子	緊 扣	
緊 抓	緊 盯	緊 身	緊 身 衣	緊 固	緊 抱	緊 附	緊 俏	
緊 俏 商 品	緊 俏 貨	緊 促	緊 急	緊 急 狀 態	緊 急 措 施	緊 急 通 知	緊 急 會 議	
緊 急 關 頭	緊 要	緊 迫	緊 迫 性	緊 迫 感	緊 挨	緊 缺	緊 胸	
緊 追	緊 密	緊 密 配 合	緊 密 結 合	緊 密 團 結	緊 密 聯 繫	緊 帶	緊 張	
緊 張 局 勢	緊 張 狀 況	緊 張 狀 態	緊 接	緊 接 著	緊 排	緊 閉	緊 握	
緊 湊	緊 著	緊 貼	緊 塞	緊 綁	緊 腰 衣	緊 跟	緊 跟 形 勢	
緊 逼	緊 緊	緊 緊 張 張	緊 裹	緊 鄰	緊 靠	緊 隨	緊 縮	
緊 繃	緊 鑼 密 鼓	緊 箍 咒	綴 文 之 士	綴 合	網 人	網 上	網 子	
網 巾	網 中	網 內	網 友	網 孔	網 卡	網 布	網 皮	
網 名	網 住	網 址	網 兒	網 制	網 底	網 板	網 狀	
網 狀 物	網 屏	網 頁	網 員	網 套	網 捕	網 格	網 格 線	
網 站 旅 行 社	網 紋	網 兜	網 區	網 族	網 球	網 球 公 開 賽	網 球 賽	
網 眼	網 袋	網 景	網 絡	網 絡 化	網 絡 理 論	網 絡 資 源	網 開 一 面	
網 開 三 面	網 路	網 路 卡	網 路 服 務	網 路 股	網 路 產 品	網 路 通 訊	網 路 連 結 盒	
網 路 費	網 路 監 控	網 漏 吞 舟	網 網	網 綱	網 聚	網 際	網 際 網 路	
網 撈	網 箱	網 線	網 膜	網 膜 狀	網 橋	網 賽	網 點	
網 蟲	網 羅	網 關	網 籃	網 蘭	綱 目	綱 目 不 疏	綱 目 體	
綱 紀	綱 紀 廢 弛	綱 要	綱 索	綱 常	綱 常 掃 地	綱 領	綱 領 性	
綱 領 性 文 件	綱 舉 目 張	綺 想	綺 羅 粉 黛	綺 麗	綺 襦 紈 胯	綢 子	綢 布	
綢 傘	綢 絲	綢 緞	綢 繆	綢 鍛	綿 力 薄 材	綿 白 糖	綿 亙	
綿 竹	綿 羊	綿 延	綿 延 不 絕	綿 延 起 伏	綿 長	綿 紙	綿 密	
綿 軟	綿 陽	綿 裡 藏 針	綿 綢	綿 綿	綿 綿 不 息	綿 綿 瓜 瓞	綿 裹 秤 錘	
綿 薄	綵 衣	綵 帶	綵 排	綵 球	維 也 納	維 文	維 他 命	
維 它 命	維 尼 熊	維 尼 綸	維 生 素	維 多 利 亞	維 吾 爾	維 吾 爾 族	維 妙 維 肖	
維 谷	維 京 人	維 和	維 持	維 持 秩 序	維 迪	維 面	維 修	
維 修 服 務	維 修 保 養	維 修 部	維 特	維 納 斯	維 族	維 傑 辛	維 新	
維 綸	維 艱	維 繫	維 護	維 護 世 界 和 平	維 護 和 平	維 護 者	緒 上	
緒 言	緒 語	緒 論	綬 帶	罰 一 勸 百	罰 了 不	罰 不 當 罪	罰 沒	
罰 金	罰 則	罰 站	罰 酒	罰 球	罰 單	罰 款	罰 落	
罰 跪	罰 錢	罰 薪	翠 巧	翠 玉	翠 竹	翠 柏	翠 英	
翠 崗	翠 淆 紅 減	翠 鳥	翠 微	翠 綠	翠 綠 色	翠 蓮	翡 翠	
聞 一 知 十	聞 出	聞 名	聞 名 不 如 見 面	聞 名 中 外	聞 名 全 國	聞 名 於 世	聞 名 遐 爾	
聞 見	聞 到	聞 所 未 聞	聞 知	聞 風	聞 風 而 至	聞 風 而 起	聞 風 而 逃	
聞 風 而 動	聞 風 喪 膽	聞 風 遠 揚	聞 訊	聞 得	聞 悉	聞 喜	聞 過 則 喜	
聞 雷 失 箸	聞 聞	聞 聲	聞 雞 起 舞	聞 馨	聞 聽	聚 乙 烯	聚 乙 烯 醇	
聚 丁 二 烯	聚 丙 烯	聚 四 氟 乙 烯	聚 光	聚 光 燈	聚 光 鏡	聚 合	聚 合 物	
聚 合 體	聚 在 一 起	聚 米 為 山	聚 亨 企 業	聚 沙 之 年	聚 沙 成 塔	聚 居	聚 性	
聚 苯 乙 烯	聚 首	聚 氨 酯	聚 財	聚 眾	聚 眾 鬥 毆	聚 眾 賭 博	聚 眾 鬧 事	
聚 散	聚 氯 乙 烯	聚 焦	聚 結	聚 結 劑	聚 隆 纖 維	聚 集	聚 飲	
聚 會	聚 精 會 神	聚 聚	聚 齊	聚 賭	聚 燈	聚 積	聚 螢 映 雪	
聚 螢 積 雪	聚 餐	聚 斂	聚 攏	聚 蟻 成 雷	聚 寶	聚 寶 盆	聚 殲	
聚 變	聚 �� 胺	聚 酯	聚 酯 紗	聚 酯 粒	聚 酯 棉	聚 酯 絲	肇 事	
肇 事 人	肇 事 者	肇 源	肇 禍	肇 端	肇 慶	腐 干	腐 化	
腐 化 墮 落	腐 生	腐 生 物	腐 皮	腐 朽	腐 朽 思 想	腐 竹	腐 肉	
腐 乳	腐 肥	腐 屍	腐 氣	腐 臭	腐 敗	腐 敗 分 子	腐 敗 性	
腐 敗 現 象	腐 敗 無 能	腐 植	腐 植 質	腐 蝕	腐 蝕 性	腐 蝕 掉	腐 蝕 劑	
腐 蝕 藥	腐 熟	腐 儒	腐 舊	腐 爛	腐 爛 變 質	膀 大 腰 圓	膀 子	
膀 胱	膀 胱 炎	膀 胱 結 石	膀 胱 癌	膀 胱 鏡	膏 火 自 煎	膏 血	膏 肓 之 疾	
膏 油	膏 狀 物	膏 唇 拭 舌	膏 腴	膏 粱 子 弟	膏 粱 文 繡	膏 粱 錦 繡	膏 藥	
膈 膜	腿 力	腿 上	腿 子	腿 疼	腿 骨	腿 部	腿 筋	
腿 腳	腿 樣	腿 彎 部	膂 力	臧 否 人 物	臺 階	臺 灣 企 銀	臺 灣 紙 業	
與 人	與 人 方 便	與 人 為 善	與 之	與 之 無 關	與 日 俱 增	與 月	與 水	
與 世	與 世 沉 浮	與 世 長 辭	與 世 俯 仰	與 世 浮 沉	與 世 偃 仰	與 世 無 爭	與 世 隔 絕	
與 世 靡 爭	與 去 年 相 比	與 外	與 民	與 民 休 息	與 民 同 憂	與 民 同 樂	與 民 更 始	
與 民 偕 樂	與 生	與 生 俱 來	與 共	與 她	與 此	與 此 同 時	與 此 有 關	
與 此 相 反	與 此 相 關	與 此 無 關	與 你	與 否	與 其	與 其 說	與 虎 添 翼	
與 虎 謀 皮	與 前 同	與 時 消 息	與 時 浮 沉	與 眾	與 眾 不 同	與 會	與 會 代 表	
與 會 同 志	與 會 者	與 會 國	舔 去	舔 食	舔 糠 及 米	舔 犢 之 私	舔 犢 之 念	
舔 犢 之 愛	舔 犢 情 深	舞 刀	舞 刀 躍 馬	舞 女	舞 手	舞 文 巧 法	舞 文 巧 詆	
舞 文 弄 法	舞 文 弄 墨	舞 文 枉 法	舞 爪 張 牙	舞 牙 弄 爪	舞 台	舞 台 劇	舞 台 藝 術	
舞 曲	舞 池	舞 伴	舞 妓	舞 弄	舞 技	舞 步	舞 男	
舞 者	舞 姿	舞 客	舞 衫 歌 扇	舞 師	舞 迷	舞 動	舞 票	
舞 場	舞 景	舞 著	舞 會	舞 獅	舞 弊	舞 態	舞 態 生 風	
舞 榭 歌 台	舞 榭 歌 樓	舞 種	舞 劇	舞 劍	舞 鞋	舞 燕 歌 鶯	舞 龍	
舞 蹈	舞 蹈 家	舞 蹈 病	舞 蹈 症	舞 蹈 術	舞 孃	舞 廳	舞 鸞 歌 鳳	
舞 伎	蓉 樹	蒿 目 時 艱	蓄 力 器	蓄 心	蓄 水	蓄 水 池	蓄 念	
蓄 洪	蓄 能	蓄 財	蓄 財 者	蓄 勢	蓄 勢 以 待	蓄 意	蓄 電	
蓄 電 池	蓄 銳 養 威	蓄 養	蓄 積	蓄 謀	蓄 謀 已 久	蒙 人	蒙 上	
蒙 大 納 州	蒙 太 奇	蒙 古	蒙 古 人	蒙 古 包	蒙 古 地 區	蒙 古 時 代	蒙 古 族	
蒙 古 語	蒙 皮	蒙 地 卡 羅	蒙 在	蒙 在 鼓 裡	蒙 自	蒙 住	蒙 受	
蒙 委 會	蒙 城	蒙 昧	蒙 冤	蒙 哥 馬 利	蒙 娜 麗 莎	蒙 席	蒙 恩	
蒙 族	蒙 羞	蒙 著	蒙 損	蒙 塵	蒙 蔽	蒙 頭	蒙 頭 轉 向	
蒙 難	蒞 臨	蒲 公 英	蒲 包	蒲 式 耳	蒲 江	蒲 柳	蒲 柳 之 姿	
蒲 扇	蒲 桃	蒲 草	蒲 團	蒲 鞭 之 政	蒜 皮	蒜 泥	蒜 苗	
蒜 黃	蒜 頭	蒜 瓣	蓋 了	蓋 上	蓋 子	蓋 世	蓋 世 無 雙	
蓋 以	蓋 瓦	蓋 印	蓋 在	蓋 好	蓋 有	蓋 住	蓋 沒	
蓋 房 子	蓋 板	蓋 法	蓋 物	蓋 屋	蓋 洛 普	蓋 起	蓋 被	
蓋 章	蓋 棺	蓋 棺 論 定	蓋 然 論	蓋 著	蓋 郵 戳	蓋 碗	蓋 過	
蓋 滿	蓋 層	蓋 戮	蓋 樓	蓋 頭	蓋 戳	蓋 騎	蒸 化	
蒸 去	蒸 肉 丸	蒸 沙 成 飯	蒸 汽	蒸 汽 似	蒸 汽 狀	蒸 汽 計	蒸 汽 機	
蒸 汽 機 車	蒸 氣	蒸 氣 浴	蒸 掉	蒸 魚	蒸 發	蒸 發 皿	蒸 發 性	
蒸 發 計	蒸 發 掉	蒸 發 量	蒸 溜	蒸 溜 所	蒸 溜 者	蒸 溜 液	蒸 溜 器	
蒸 蒸 日 上	蒸 餃	蒸 熟	蒸 燒	蒸 鍋	蒸 餾	蒸 餾 水	蒸 餾 法	
蒸 餾 物	蒸 餾 室	蒸 餾 液	蒸 餾 器	蒸 騰	蒸 籠	蓓 蕾	蒐 集	
蒼 天	蒼 民	蒼 生	蒼 生 塗 炭	蒼 白	蒼 老	蒼 松	蒼 松 翠 柏	
蒼 穹	蒼 勁	蒼 郁	蒼 冥	蒼 桑	蒼 海	蒼 茫	蒼 梧	
蒼 涼	蒼 莽	蒼 黃 翻 覆	蒼 翠	蒼 翠 繁 茂	蒼 蒼	蒼 龍	蒼 顏	
蒼 蠅	蒼 蠅 見 血	蒼 蠅 拍	蒼 鷹	蒼 鷺	蓑 衣	蜿 蜒	蜿 蜒 而 行	
蜜 月	蜜 汁	蜜 瓜	蜜 拉 喬 娃 維 琪	蜜 柑	蜜 洞	蜜 般	蜜 酒	
蜜 棗	蜜 源	蜜 蜂	蜜 裡 調 油	蜜 語	蜜 糖	蜜 餞	蜜 櫻 桃	
蜜 露	蜻 蛉	蜻 蜓	蜻 蜓 點 水	蜥 蜴	蜥 蜴 類	蜘 蛛	蜘 蛛 般	
蝕 本	蝕 刻	蝕 刻 法	蝕 刻 師	蝕 船 蟲	蝕 損	蜷 毛	蜷 伏	
蜷 曲	蜷 發	蜷 著	蜷 縮	蜩 螗 沸 羹	褂 子	裴 頓	裹 上	
裹 以	裹 在	裹 住	裹 足	裹 足 不 前	裹 足 不 進	裹 屍	裹 屍 馬 革	
裹 面	裹 挾	裹 脅	裹 起	裹 得	裹 著	裹 腳	裹 過	
裹 緊	裹 腿	裸 子 植 物	裸 身	裸 奔	裸 胸	裸 袖 揎 衣	裸 麥 酒	
裸 銅 線	裸 露	裸 體	裸 體 畫	製 片	製 片 人	製 冰	製 成	
製 成 皮	製 成 品	製 衣	製 作	製 作 人	製 作 所	製 作 者	製 冷	
製 冷 劑	製 冷 器	製 法	製 版	製 表	製 表 符	製 表 業	製 表 鍵	
製 品	製 造	製 造 所	製 造 者	製 造 品	製 造 商	製 造 業	製 造 廠	
製 造 學	製 程	製 圖	製 圖 人	製 圖 法	製 圖 員	製 圖 學	製 藥	
製 藥 者	製 藥 廠	製 罐	裨 益	誦 揚	誦 經	誦 詩	誦 讀	
語 不 投 機	語 不 擇 人	語 不 驚 人	語 文	語 文 學	語 句	語 四 言 三	語 用 論	
語 用 學	語 式	語 妙 絕 倫	語 尾	語 序	語 形 論	語 形 學	語 系	
語 言	語 言 上	語 言 文 字	語 言 規 範 化	語 言 無 味	語 言 學	語 言 學 家	語 言 藝 術	
語 典	語 委	語 法	語 法 書	語 法 結 構	語 法 學	語 法 樹	語 型	
語 重 心 長	語 音	語 音 郵 件	語 音 學	語 風	語 原 論	語 料	語 根	
語 氣	語 氣 詞	語 病	語 笑 喧 呼	語 笑 喧 闐	語 笑 諠 譁	語 素	語 焉 不 詳	
語 無 倫 次	語 腔	語 詞	語 詞 定 義	語 勢	語 匯	語 塞	語 意	
語 意 學	語 感	語 源	語 義	語 義 上	語 義 學	語 裡	語 境	
語 態	語 種	語 標	語 調	語 調 強	語 錄	語 鏡	語 譯	
語 聾 症	語 驚 四 座	語 體	誣 告	誣 告 陷 害	誣 害	誣 控	誣 陷	
誣 稱	誣 蔑	誣 賴	認 了	認 人	認 出	認 可	認 可 者	
認 生	認 同	認 字	認 作	認 命	認 定	認 明	認 知	
認 股	認 股 權 證	認 屍	認 為	認 值	認 捐	認 真	認 真 吸 取	
認 真 思 考	認 真 負 責	認 做	認 帳	認 得	認 得 出	認 清	認 理	
認 許	認 罪	認 罪 服 罪	認 賊 作 父	認 賊 為 子	認 罰	認 認	認 領	
認 賬	認 親	認 輸	認 錯	認 購	認 購 權 證	認 繳	認 識	
認 識 力	認 識 水 平	認 識 到	認 識 論	認 證	誡 者	誡 律	誓 山 盟 海	
誓 不	誓 不 兩 立	誓 不 兩 詞	誓 不 罷 休	誓 必	誓 由	誓 同 生 死	誓 死	
誓 死 不 二	誓 死 不 屈	誓 言	誓 者	誓 約	誓 師	誓 師 大 會	誓 書	
誓 海 盟 山	誓 無 二 心	誓 無 二 志	誓 詞	誓 願	誤 人	誤 人 子 弟	誤 入	
誤 入 歧 途	誤 工	誤 引 用	誤 叫	誤 失	誤 打	誤 犯	誤 用	
誤 字	誤 字 率	誤 收	誤 判	誤 車	誤 事	誤 取	誤 征	
誤 信	誤 派	誤 述	誤 食	誤 差	誤 時	誤 納	誤 記	
誤 送	誤 區	誤 國	誤 國 殃 民	誤 國 害 民	誤 國 殄 民	誤 將	誤 掉	
誤 殺	誤 場	誤 報	誤 期	誤 給	誤 傳	誤 傷	誤 會	
誤 解	誤 過	誤 稱	誤 算	誤 認	誤 認 為	誤 寫	誤 撞	
誤 碼	誤 碼 率	誤 導	誤 餐	誤 點	誤 闖	誤 譯	誤 聽	
說 一 不 二	說 一 是 一 說 二 是 二	說 了	說 人	說 人 情	說 三 道 四	說 上	說 上 幾 句	
說 也	說 大 話	說 大 話 使 小 錢	說 不	說 不 上	說 不 出	說 不 出 的	說 不 完	
說 不 來	說 不 定	說 不 准	說 不 清	說 不 過 去	說 不 盡	說 中	說 今	
說 今 道 古	說 及	說 心 裡 話	說 文	說 文 解 字	說 出	說 去	說 古	
說 古 談 今	說 句	說 用	說 白	說 白 話	說 白 道 黑	說 白 道 綠	說 合	
說 地 談 天	說 好	說 成	說 死	說 老 實 話	說 西	說 似	說 呀	
說 妥	說 完	說 來	說 來 話 長	說 來 道 去	說 到	說 到 底	說 到 做 到	
說 和	說 定	說 明	說 明 了	說 明 文	說 明 式	說 明 性	說 明 者	
說 明 書	說 明 符	說 服	說 服 力	說 服 者	說 服 教 育	說 東	說 東 道 西	
說 東 談 西	說 法	說 法 不 一	說 的	說 的 說	說 知	說 者	說 長 道 短	
說 長 論 短	說 客	說 故	說 故 事	說 是	說 是 談 非	說 穿	說 英 語	
說 哪	說 家	說 書	說 真 的	說 真 話	說 破	說 笑	說 笑 話	
說 起	說 起 來	說 假 話	說 動	說 唱	說 唱 藝 術	說 唱 藝 術 團	說 得	
說 得 過 去	說 情	說 情 風	說 教	說 教 性	說 教 術	說 曹 操	說 梅 止 渴	
說 理	說 通	說 媒	說 幾 句	說 短 道 長	說 短 論 長	說 給	說 著	
說 詞	說 開	說 閒 話	說 項	說 黃 道 黑	說 黑 道 白	說 慌 者	說 話	
說 話 法	說 話 者	說 話 算 話	說 話 算 數	說 話 聲	說 道	說 過	說 夢	
說 夢 話	說 實 在 的	說 實 話	說 漏	說 語	說 說	說 說 笑 笑	說 廢 話	
說 親	說 錯	說 謊	說 謊 者	說 壞	說 壞 話	說 辭	說 鹹 道 淡	
說 聽	說 髒 話	說 啥	誨 人	誨 人 不 倦	誨 而 不 倦	誨 師	誨 淫	
誨 淫 誨 盜	誨 爾 諄 諄 聽 我 藐 藐	誘 人	誘 入	誘 之	誘 引	誘 出	誘 因	
誘 使	誘 供	誘 拐	誘 拐 者	誘 物	誘 哄	誘 姦	誘 降	
誘 捕	誘 脅	誘 掖 後 進	誘 殺	誘 陷	誘 惑	誘 惑 人	誘 惑 力	
誘 惑 物	誘 惑 者	誘 發	誘 逼	誘 餌	誘 敵	誘 敵 深 入	誘 導	
誘 導 性	誘 導 劑	誘 騙	誘 騙 物	誘 殲	誘 變	誑 玩	誑 騙	
豪 士	豪 大 雨	豪 毛	豪 右	豪 壯	豪 言	豪 言 壯 語	豪 放	
豪 放 不 羈	豪 門	豪 門 貴 冑	豪 雨	豪 俠	豪 客	豪 氣	豪 商	
豪 奢 放 逸	豪 強	豪 情	豪 情 壯 志	豪 情 逸 致	豪 情 滿 懷	豪 爽	豪 紳	
豪 傑	豪 勝	豪 富	豪 華	豪 華 型	豪 飲	豪 奪	豪 奪 巧 取	
豪 語	豪 豬	豪 賭	豪 橫 跋 扈	豪 興	豪 舉	豪 邁	豪 邁 不 群	
貌 兇	貌 合 神 離	貌 合 情 離	貌 似	貌 取	貌 和 心 離	貌 和 行 離	貌 是 情 非	
貌 相	貌 美	賓 川	賓 主	賓 主 雙 方	賓 州 大 學	賓 至	賓 至 如 歸	
賓 果	賓 室	賓 客	賓 客 如 雲	賓 客 盈 門	賓 格	賓 詞	賓 語	
賓 縣	賓 館	賓 禮	賑 災	賑 災 基 金	賑 災 義 演	賑 所	賑 救	
賑 款	賑 窮 濟 乏	賑 濟	賑 糧	賑 饑	賒 欠	賒 借	賒 帳	
賒 給	賒 買	賒 債	賒 賬	賒 賣	賒 銷	賒 購	赫 南 德 茲	
赫 茲	赫 斯 之 威	赫 斯 之 怒	赫 然	赫 然 有 聲	赫 爾 辛 基	赫 赫	赫 赫 之 功	
赫 赫 之 光	赫 赫 之 名	赫 赫 有 名	赫 赫 炎 炎	赫 赫 揚 揚	赫 德	趙 士 強	趙 文 卓	
趙 自 強	趙 怡	趙 豐 邦	趕 了	趕 入	趕 上	趕 工	趕 不	
趕 不 上	趕 不 及	趕 出	趕 去	趕 巧	趕 先 進	趕 印	趕 向	
趕 回	趕 在	趕 忙	趕 早	趕 考	趕 完	趕 快	趕 走	
趕 車	趕 車 人	趕 來	趕 到	趕 往	趕 明 兒	趕 急	趕 活	
趕 牲	趕 赴	趕 時 髦	趕 送	趕 做	趕 得	趕 得 上	趕 得 及	
趕 晚	趕 場	趕 著 鴨 子 上 架	趕 超	趕 跑	趕 開	趕 集	趕 路	
趕 過	趕 盡 殺 絕	趕 緊	趕 製	趕 寫	趕 趟	趕 趟 兒	趕 辦	
趕 鴨 子 上 架	趕 幫	趕 攏	趕 騾	輔 □	輔 以	輔 佐	輔 助	
輔 助 性	輔 助 物	輔 助 說 明	輔 助 線	輔 車 相 依	輔 車 唇 齒	輔 政	輔 音	
輔 修	輔 射	輔 料	輔 條	輔 弼 之 勳	輔 幣	輔 導	輔 導 員	
輔 導 班	輔 導 站	輔 機	輔 選	輕 口 薄 舌	輕 工	輕 工 局	輕 工 產 品	
輕 工 部	輕 工 業	輕 工 業 部	輕 元 素	輕 手	輕 手 輕 腳	輕 文	輕 世 傲 物	
輕 叩	輕 巧	輕 打	輕 生	輕 生 重 義	輕 印 刷	輕 如	輕 如 鴻 毛	
輕 帆 船	輕 而 易 舉	輕 舟	輕 兵	輕 吞 慢 吐	輕 吹	輕 吟	輕 快	
輕 狂	輕 言	輕 言 細 語	輕 言 寡 信	輕 身 重 義	輕 車	輕 車 介 士	輕 車 熟 路	
輕 車 簡 從	輕 事 重 報	輕 佻	輕 卒 銳 兵	輕 取	輕 拉	輕 拂	輕 拍	
輕 放	輕 於	輕 於 鴻 毛	輕 易	輕 武	輕 武 器	輕 油	輕 者	
輕 金 屬	輕 信	輕 便	輕 便 式	輕 侮	輕 則	輕 咬	輕 型	
輕 度	輕 待	輕 按	輕 柔	輕 活	輕 盈	輕 看	輕 若 鴻 毛	
輕 軌	輕 重	輕 重 失 宜	輕 重 倒 置	輕 重 緩 急	輕 音	輕 音 樂	輕 風	
輕 哼	輕 捏	輕 效	輕 浪 浮 薄	輕 浮	輕 症	輕 笑	輕 紡	
輕 紡 產 品	輕 紗	輕 脆	輕 航	輕 財 任 俠	輕 財 好 施	輕 財 好 義	輕 財 重 士	
輕 財 重 義	輕 財 貴 義	輕 財 敬 士	輕 偎 低 傍	輕 動 遠 舉	輕 唱	輕 捷	輕 推	
輕 率	輕 軟	輕 描 淡 寫	輕 揚	輕 稅	輕 視	輕 跑	輕 量	
輕 量 級	輕 閒	輕 傷	輕 微	輕 搖	輕 煙	輕 罪	輕 裘 肥 馬	
輕 裘 環 帶	輕 裝	輕 裝 上 陣	輕 裝 前 進	輕 慢	輕 敲	輕 歌	輕 歌 曼 舞	
輕 歌 慢 舞	輕 歌 舞	輕 罰	輕 輕	輕 輕 吹	輕 劍	輕 嘴 薄 舌	輕 彈	
輕 慮 淺 謀	輕 撞	輕 撫	輕 敵	輕 蔑	輕 賤	輕 質	輕 踏	
輕 諾	輕 諾 寡 信	輕 鋼	輕 擊	輕 擊 聲	輕 擦	輕 聲	輕 聲 細 語	
輕 舉	輕 舉 妄 動	輕 薄	輕 薄 無 行	輕 薄 無 知	輕 點	輕 瀉	輕 瀉 劑	
輕 鞭	輕 騎	輕 騎 兵	輕 騎 簡 從	輕 鬆	輕 觸	輕 飄	輕 飄 飄	
輕 徭 薄 稅	輕 徭 薄 賦	輓 歌	輓 聯	辣 子	辣 手	辣 味	辣 的	
辣 椒	辣 椒 油	辣 椒 醬	辣 湯	辣 菜	辣 辣	辣 醃 菜	辣 醬	
遠 了	遠 大	遠 山	遠 不 及	遠 不 可 及	遠 不 間 親	遠 升	遠 及	
遠 引 曲 喻	遠 引 深 潛	遠 心 點	遠 方	遠 日 點	遠 月 點	遠 比	遠 水 不 救 近 火	
遠 水 不 解 近 渴	遠 水 救 不 了 近 火	遠 水 救 不 得 近 渴	遠 水 難 救 近 火	遠 火	遠 去	遠 古	遠 古 文 化	
遠 未	遠 交 近 攻	遠 因	遠 地	遠 地 點	遠 在	遠 在 千 里 近 在 眼 前	遠 在 天 邊	
遠 百 愛 買	遠 至	遠 行	遠 別	遠 投	遠 見	遠 見 卓 識	遠 見 雜 誌	
遠 走	遠 走 高 飛	遠 足	遠 足 者	遠 到	遠 征	遠 征 軍	遠 房	
遠 東	遠 東 地 區	遠 東 百 貨	遠 東 倉 儲	遠 東 紡 織	遠 東 航 空	遠 東 銀 行	遠 的	
遠 者	遠 近	遠 門	遠 非	遠 客	遠 洋	遠 洋 航 行	遠 洋 貨 輪	
遠 洋 運 輸	遠 洋 漁 業	遠 洋 輪 船	遠 流	遠 為	遠 看	遠 郊	遠 郊 區	
遠 害 全 身	遠 射	遠 涉 重 洋	遠 祖	遠 航	遠 側	遠 望	遠 略	
遠 眺	遠 處	遠 途	遠 勝	遠 勝 於	遠 勝 過	遠 揚	遠 景	
遠 景 規 劃	遠 期	遠 渡 重 洋	遠 程	遠 程 行 軍	遠 翔	遠 翔 空 運	遠 視	
遠 視 者	遠 視 眼	遠 距	遠 距 離	遠 嫁	遠 愁 近 慮	遠 溯	遠 照	
遠 路	遠 遊	遠 道	遠 道 而 來	遠 達	遠 遁	遠 隔	遠 隔 重 洋	
遠 圖 長 慮	遠 端	遠 遠	遠 遠 望 去	遠 慮	遠 慮 深 思	遠 慮 深 計	遠 鄰	
遠 銷	遠 親	遠 親 不 如 近 鄰	遠 謀	遠 舉 高 飛	遠 避	遠 點	遠 離	
遠 識	遜 人	遜 色	遜 位	遜 志 時 敏	遜 於	遜 的	遣 兵 調 將	
遣 使	遣 返	遣 俘	遣 送	遣 將	遣 責	遣 悶	遣 散	
遣 詞	遣 詞 立 意	遣 興 陶 情	遣 辭 措 意	遙 自	遙 見	遙 相	遙 相 呼 應	
遙 相 應 和	遙 祝	遙 寄	遙 控	遙 望	遙 祭	遙 測	遙 測 術	
遙 感	遙 感 技 術	遙 想	遙 遠	遙 遙	遙 遙 相 對	遙 遙 無 期	遙 遙 華 冑	
遙 遙 領 先	遞 上	遞 升	遞 加	遞 交	遞 交 國 書	遞 回	遞 呈	
遞 延	遞 信	遞 降	遞 送	遞 送 人	遞 推	遞 減	遞 給	
遞 進	遞 補	遞 解	遞 增	遞 舉	遞 歸	遛 彎	遛 彎 兒	
鄙 人	鄙 夫	鄙 夷	鄙 吝 復 萌	鄙 見	鄙 俗	鄙 陋	鄙 棄	
鄙 視	鄙 意	鄙 薄	酵 母	酵 母 菌	酵 法	酵 食	酵 粉	
酵 素	酵 素 基 因	酵 菌	酸 化	酸 心	酸 文 假 醋	酸 水	酸 牛 奶	
酸 奶	酸 奶 酪	酸 式 鹽	酸 辛	酸 乳	酸 味	酸 定	酸 性	
酸 果 汁	酸 雨	酸 度	酸 毒 症	酸 洗	酸 苦	酸 根	酸 疼	
酸 臭	酸 梅	酸 梅 湯	酸 液	酸 甜	酸 甜 苦 辣	酸 處 理	酸 軟	
酸 麻	酸 棗	酸 痛	酸 菌	酸 菜	酸 量	酸 鈣	酸 鈉	
酸 楚	酸 溜 溜	酸 過 多	酸 辣	酸 辣 湯	酸 酸	酸 鼻	酸 鋇	
酸 澀	酸 懶	酸 類	酸 鹼	酸 鹼 度	酸 鹽	酸 酐	酸 酯	
酷 人	酷 必 得 網 站	酷 刑	酷 吏	酷 似	酷 冷	酷 肖	酷 到	
酷 待	酷 政	酷 虐	酷 烈	酷 寒	酷 暑	酷 評	酷 象	
酷 愛	酷 極 了	酷 像	酷 熱	酷 斃	鉸 刀	鉸 孔	鉸 接	
鉸 鍊	銀 子	銀 山	銀 川	銀 川 市	銀 中 毒	銀 元	銀 白	
銀 白 色	銀 光	銀 匠	銀 帆	銀 灰	銀 灰 色	銀 耳	銀 色	
銀 行	銀 行 公 會	銀 行 戶 頭	銀 行 存 款	銀 行 家	銀 行 帳 號	銀 行 業	銀 行 團	
銀 杏	銀 角	銀 兩	銀 杯	銀 河	銀 河 系	銀 狐	銀 屏	
銀 洋	銀 根	銀 海	銀 粉	銀 針	銀 婚	銀 條	銀 票	
銀 貨 兩 訖	銀 魚	銀 牌	銀 貸	銀 圓	銀 塊	銀 溪	銀 號	
銀 鉤 鐵 畫	銀 鼠	銀 團	銀 幣	銀 幕	銀 製	銀 價	銀 樓	
銀 獎	銀 盤	銀 蓬 花	銀 質	銀 質 獎	銀 質 獎 章	銀 器	銀 樺	
銀 錠	銀 錢	銀 礦	銅 子 兒	銅 山	銅 山 西 崩 洛 鐘 東 應	銅 川	銅 仁	
銅 元	銅 片	銅 瓦	銅 匠	銅 色	銅 材	銅 板	銅 版	
銅 肥	銅 柱	銅 活	銅 屑	銅 臭	銅 梁	銅 條	銅 陵	
銅 斑	銅 棒	銅 牌	銅 琶 鐵 板	銅 筋	銅 筋 鐵 肋	銅 筋 鐵 骨	銅 絲	
銅 軸	銅 鼓	銅 像	銅 幣	銅 管	銅 箔	銅 箔 基 板	銅 綠	
銅 綠 色	銅 製	銅 製 品	銅 模	銅 樂	銅 線	銅 駝 荊 棘	銅 器	
銅 導 電	銅 錢	銅 頭 鐵 額	銅 牆	銅 牆 鐵 壁	銅 錘	銅 鏡	銅 礦	
銅 鑼	銅 鑼 鄉	銅 鑼 灣	銅 ��	銘 心	銘 心 刻 骨	銘 心 鏤 骨	銘 文	
銘 刻	銘 刻 在 心	銘 記	銘 記 在 心	銘 牌	銘 辭	銘 饑 鏤 骨	銖 兩	
銖 兩 悉 稱	銖 銖 較 量	銖 積 寸 累	鉻 絲	鉻 鋼	鉻 鐵	銓 敘	銓 敘 部	
銜 尾 相 隨	銜 尾 相 屬	銜 兒	銜 恨	銜 恨 蒙 枉	銜 冤	銜 冤 負 屈	銜 接	
銜 悲 茹 恨	銜 等	銜 華 佩 實	銜 環 結 草	銜 鐵	銨 水	銨 鹽	銑 刀	
銑 切	銑 床	閨 女	閨 秀	閨 房	閨 門	閨 怨	閨 閣	
閩 中	閩 北	閩 江	閩 侯	閩 南	閩 清	閩 劇	閩 籍	
閣 下	閣 老	閣 室	閣 員	閣 僚	閣 摟	閣 樓	閥 瓦	
閥 門	隙 大 牆 壞	隙 地	隙 縫	障 目	障 於	障 眼	障 眼 法	
障 礙	障 礙 物	際 會 風 雲	際 遇	雌 伏	雌 性	雌 性 激 素	雌 花	
雌 紅	雌 素	雌 胭	雌 鳥	雌 雄	雌 雄 未 決	雌 黃	雌 禽	
雌 蜂	雌 激 素	雌 蕊	雌 獸	需 方	需 用	需 求	需 求 量	
需 知	需 按	需 要	需 要 坐	需 要 量	需 將	需 設	韶 山	
韶 光	韶 光 似 箭	韶 光 荏 苒	韶 光 淑 氣	韶 華	韶 華 如 駛	韶 顏 稚 齒	頗 久	
頗 大	頗 多	頗 好	頗 有	頗 有 同 感	頗 似	頗 孚 眾 望	頗 佳	
頗 具	頗 受	頗 受 歡 迎	頗 知	頗 肥	頗 為	頗 能	頗 高	
頗 得	頗 費 周 折	頗 感 興 趣	頗 愛	頗 豐	頗 覺	領 了	領 入	
領 口	領 土	領 土 完 整	領 土 問 題	領 子	領 工 資	領 巾	領 巾 夾	
領 巾 類	領 勾	領 水	領 主	領 主 權	領 他	領 出	領 司	
領 外	領 用	領 先	領 先 水 平	領 先 地 位	領 回	領 地	領 存	
領 扣	領 收	領 有	領 兵	領 走	領 事	領 事 裁 判 權	領 事 館	
領 到	領 取	領 受	領 受 人	領 受 者	領 空	領 柩	領 悟	
領 料	領 書	領 海	領 班	領 航	領 航 員	領 航 學	領 針	
領 唱	領 唱 人	領 域	領 執 照	領 帶	領 帶 夾	領 得	領 情	
領 教	領 略	領 袖	領 袖 人 物	領 章	領 報	領 款	領 款 人	
領 港	領 港 員	領 發	領 結	領 著	領 跑 人	領 進	領 隊	
領 會	領 照	領 路	領 道	領 銜	領 餉	領 撥	領 獎	
領 獎 台	領 養	領 導	領 導 人	領 導 力	領 導 者	領 導 班 子	領 導 部 門	
領 導 幹 部	領 導 層	領 導 權	領 頭	領 薪 水	領 購	領 還	領 證	
領 屬	颯 爽	颯 爽 英 姿	颯 然	颯 颯	颯 颯 聲	颱 風	餃 子	
餃 肉	餅 子	餅 狀	餅 肥	餅 乾	餅 湯	餅 圖	餅 餌	
餌 食	餌 料	餌 誘	餉 銀	駁 不 倒	駁 斥	駁 回	駁 回 上 訴	
駁 岸	駁 面 子	駁 倒	駁 得	駁 接	駁 船	駁 殼	駁 運	
駁 運 費	駁 擊	駁 雜	駁 議	骯 髒	骰 子	骰 子 盒	魁 北 克	
魁 皇	魁 首	魁 偉	魁 梧	魂 不 守 舍	魂 不 附 體	魂 飛	魂 飛 魄 散	
魂 牽 夢 系	魂 牽 夢 縈	魂 夢	魂 魄	魂 斷	魂 靈	鳴 不 平	鳴 乎 哀 哉	
鳴 叫	鳴 叫 物	鳴 曲	鳴 放	鳴 金	鳴 咽	鳴 炮	鳴 冤	
鳴 冤 叫 屈	鳴 哭 聲	鳴 唱	鳴 笛	鳴 鳥	鳴 禽	鳴 禽 類	鳴 鼓	
鳴 鼓 而 攻	鳴 槍	鳴 聲	鳴 謝	鳴 鐘	鳴 鐘 列 鼎	鳴 鐘 者	鳴 響	
鳴 鑼 開 道	鳶 飛 魚 躍	鳳 山	鳳 友 鸞 交	鳳 毛 濟 美	鳳 毛 麟 角	鳳 爪	鳳 尾 魚	
鳳 林	鳳 泊 鸞 飄	鳳 冠	鳳 城	鳳 害	鳳 凰	鳳 凰 于 飛	鳳 凰 木	
鳳 凰 來 儀	鳳 凰 於 蜚	鳳 梨	鳳 眼	鳳 翔	鳳 陽	鳳 舞 龍 飛	鳳 鳴 朝 陽	
鳳 蝶	鳳 頭 麥 雞	鳳 雛 麟 子	鳳 髓 龍 肝	麼 些	麼 樣	鼻 口	鼻 子	
鼻 中	鼻 孔	鼻 毛	鼻 水	鼻 尖	鼻 血	鼻 兒	鼻 炎	
鼻 青 臉 腫	鼻 咽 炎	鼻 後	鼻 科	鼻 科 學	鼻 音	鼻 息	鼻 涕	
鼻 疽 病	鼻 祖	鼻 部	鼻 腔	鼻 塞	鼻 煙	鼻 煙 盒	鼻 飼	
鼻 管	鼻 酸	鼻 樑	鼻 樑 兒	鼻 頭	鼻 聲	鼻 臉	鼻 竇	
鼻 竇 炎	鼻 觀	齊 人 攫 金	齊 力	齊 大 非 偶	齊 大 非 耦	齊 天 大 聖	齊 天 洪 福	
齊 心	齊 心 一 力	齊 心 同 力	齊 心 合 力	齊 心 並 力	齊 心 協 力	齊 心 滌 慮	齊 心 戮 力	
齊 手	齊 牙	齊 平	齊 全	齊 列	齊 名	齊 名 並 價	齊 州 九 點	
齊 抓 共 管	齊 步	齊 步 走	齊 足 並 馳	齊 足 並 驅	齊 足 跳	齊 放	齊 東 野 語	
齊 肩	齊 奏	齊 炸	齊 眉 舉 案	齊 美	齊 家 治 國	齊 射	齊 秦	
齊 高	齊 動	齊 唱	齊 國	齊 備	齊 發	齊 集	齊 煙 九 點	
齊 綁	齊 腰 身	齊 腰 深	齊 鳴	齊 齊	齊 齊 哈 爾	齊 齒	齊 整	
齊 整 如 一	齊 豫	齊 頭 並 進	齊 聲	齊 聲 叫 好	齊 趨 並 駕	齊 驅 並 駕	齊 驅 並 驟	
齊 觀	齊 紈 魯 縞	億 元	億 分 之 一	億 斤	億 光 電 子	億 兆	億 秒	
億 泰 電 線	億 畝	億 萬	億 萬 人 民	億 萬 斯 年	億 萬 群 眾	億 噸	億 豐 工 業	
儀 上	儀 仗	儀 仗 隊	儀 式	儀 行	儀 征	儀 表	儀 表 板	
儀 容	儀 座	儀 態	儀 態 萬 千	儀 態 萬 方	儀 器	儀 禮	儀 隴	
僻 地	僻 巷	僻 陋	僻 徑	僻 處	僻 道	僻 遠	僻 靜	
僻 壤	僵 化	僵 死	僵 住	僵 局	僵 直	僵 臥	僵 持	
僵 持 不 下	僵 痛	僵 硬	價 內	價 外	價 目	價 目 表	價 位	
價 低	價 金	價 值	價 值 尺 度	價 值 規 律	價 值 連 城	價 值 量	價 值 論	
價 值 觀	價 差	價 格	價 格 表	價 率	價 款	價 廉	價 廉 物 美	
價 電 子	價 標	價 碼	價 錢	價 額	儉 用	儉 明	儉 省	
儉 約	儉 學	儉 樸	凜 冽	凜 然	凜 凜	劇 中	劇 中 人	
劇 本	劇 本 稿	劇 目	劇 曲	劇 作	劇 作 家	劇 協	劇 的	
劇 社	劇 毒	劇 挫	劇 校	劇 烈	劇 院	劇 務	劇 情	
劇 組	劇 終	劇 場	劇 減	劇 痛	劇 評	劇 跌	劇 照	
劇 裡	劇 跳	劇 團	劇 種	劇 增	劇 變	劇 體	劈 刀	
劈 叉	劈 天 蓋 地	劈 死	劈 拍	劈 拍 聲	劈 波 斬 浪	劈 砍	劈 面	
劈 風 斬 浪	劈 柴	劈 胸	劈 得 開	劈 痕	劈 裂	劈 開	劈 裡 啪 啦	
劈 頭	劈 頭 蓋 臉	劉 玉 婷	劉 至 翰	劉 邦	劉 其 偉	劉 青 雲	劉 若 英	
劉 虹 嬅	劉 家 昌	劉 泰 英	劉 海	劉 海 兒	劉 雪 華	劉 備	劉 德 華	
劉 興 欽	劉 墉	劍 川	劍 手	劍 手 待 斃	劍 光	劍 形	劍 拔 弩 張	
劍 拔 駑 張	劍 法	劍 狀	劍 客	劍 怨 求 媚	劍 眉	劍 氣	劍 術	
劍 術 師	劍 麻	劍 湖 山 世	劍 道	劍 影 逃 形	劍 樹 刀 山	劍 橋	劍 橋 郡	
劍 鞘	劍 膽 琴 心	劍 蘭	劊 子 手	厲 色	厲 行	厲 行 節 約	厲 兵 秣 馬	
厲 兵 粟 馬	厲 害	厲 鬼	厲 精 更 始	厲 精 求 治	厲 精 圖 治	厲 聲	嘮 叨	
嘮 叨 不 已	嘮 叼	嘮 嘮	嘮 嘮 叨 叨	嘻 皮 笑 臉	嘻 笑	嘻 嘻	嘻 嘻 哈 哈	
嘻 戲	嘻 嗝	嘹 亮	嘹 望 員	嘲 弄	嘲 弄 者	嘲 風 弄 月	嘲 風 詠 月	
嘲 笑	嘲 笑 者	嘲 笑 著	嘲 熱	嘲 罵	嘲 諷	嘿 嘿	嘴 上	
嘴 中	嘴 巴	嘴 皮	嘴 尖	嘴 快	嘴 角	嘴 乖	嘴 兒	
嘴 直	嘴 唇	嘴 甜	嘴 笨	嘴 軟	嘴 硬	嘴 鈍	嘴 損	
嘴 裡	嘴 對 嘴	嘴 緊	嘴 臉	嘴 邊	嘴 饞	嘩 世 取 寵	嘩 地	
嘩 拉	嘩 笑	嘩 啦	嘩 然	嘩 嘩	嘩 變	噓 枯 吹 生	噓 唏	
噓 氣	噓 寒 問 暖	噓 噓	噓 聲	噎 住	噎 噎	噎 嗝	噗 通	
噗 跳	噗 哧	噴 口	噴 水	噴 水 孔	噴 水 池	噴 火	噴 火 分 隊	
噴 火 器	噴 出	噴 出 物	噴 打	噴 吐	噴 成	噴 注	噴 油 井	
噴 泉	噴 香	噴 射	噴 射 客 機	噴 射 器	噴 射 機	噴 氣	噴 氣 口	
噴 氣 式	噴 氣 發 動 機	噴 氣 機	噴 淋	噴 淋 浴	噴 焊	噴 湧	噴 發	
噴 著	噴 雲 吐 霧	噴 飯	噴 塗	噴 煙	噴 槍	噴 漆	噴 管	
噴 嘴	噴 撒	噴 澆	噴 墨	噴 燈	噴 頭	噴 嚏	噴 濕	
噴 薄	噴 薄 欲 出	噴 鍍	噴 濺	噴 濺 出	噴 霧	噴 霧 器	噴 灌	
噴 灑	噴 灑 車	嘶 叫	嘶 啞	嘶 喊	嘶 鳴	嘶 嘶	嘶 嘶 聲	
嘶 聲	嘯 聚	嘯 嘯	嘯 嘯 聲	嘯 聲	嘰 咕	嘰 哩 咕 嚕	嘰 喳	
嘰 嘎 聲	嘰 嘰	嘰 嘰 喳 喳	增 人	增 大	增 大 器	增 刊	增 加	
增 加 收 入	增 加 物	增 加 數	增 生	增 白	增 光	增 光 添 色	增 列	
增 印	增 多	增 收	增 收 節 支	增 有	增 至	增 色	增 你 強	
增 兵	增 利	增 刪	增 防	增 征	增 肥	增 長	增 長 率	
增 長 速 度	增 長 幅 度	增 建	增 派	增 為	增 盈	增 訂	增 值	
增 借	增 員	增 效	增 益	增 納	增 記	增 配	增 高	
增 強	增 強 活 力	增 強 團 結	增 強 黨 性	增 添	增 添 物	增 產	增 產 節 約	
增 產 增 收	增 設	增 幅	增 幅 器	增 援	增 殖	增 殖 者	增 減	
增 發	增 稅	增 貸	增 進	增 進 友 誼	增 量	增 塑 劑	增 損	
增 溫	增 聘	增 補	增 資	增 廣	增 撥	增 調	增 輝	
增 選	增 壓	增 壓 器	增 濕 器	增 薪	增 虧	增 繳	墳 地	
墳 場	墳 墓	墜 入	墜 下	墜 子	墜 地	墜 茵 落 溷	墜 馬	
墜 毀	墜 落	墜 飾	墜 樓	墜 機	墜 體	墮 入	墮 胎	
墮 胎 藥	墮 著	墮 落	墮 甑 不 顧	墩 子	墩 墩	嬉 水	嬉 皮	
嬉 皮 士	嬉 皮 笑 臉	嬉 弄	嬉 耍	嬉 笑	嬉 笑 怒 罵	嬉 裝	嬉 嬉	
嬉 樂	嬉 鬧	嬉 戲	嬉 戲 著	嫻 淑	嫻 雅	嫻 熟	嫻 靜	
嬋 娟	嫵 媚	嬌 小	嬌 小 玲 瓏	嬌 生 慣 養	嬌 妻	嬌 娃	嬌 柔	
嬌 美	嬌 弱	嬌 氣	嬌 氣 十 足	嬌 羞	嬌 媚	嬌 貴	嬌 嫩	
嬌 態	嬌 慣	嬌 滴 滴	嬌 嬈	嬌 養	嬌 縱	嬌 寵	嬌 艷	
嬌 憨	寮 共	寮 國	寬 大	寬 大 政 策	寬 大 為 懷	寬 大 處 理	寬 心	
寬 打	寬 打 窄 用	寬 行	寬 衣	寬 余	寬 免	寬 宏	寬 宏 大 度	
寬 宏 大 量	寬 角 度	寬 延	寬 於	寬 泛	寬 厚	寬 度	寬 待	
寬 洪 大 度	寬 洪 大 量	寬 洪 海 量	寬 軌	寬 限	寬 容	寬 恕	寬 窄	
寬 帶	寬 猛 相 濟	寬 袖	寬 規	寬 赦	寬 幅	寬 敞	寬 舒	
寬 愛	寬 腰	寬 裕	寬 路	寬 暢	寬 綽	寬 緊	寬 銀 幕	
寬 領	寬 廣	寬 慰	寬 線	寬 頻	寬 頻 網 路	寬 闊	寬 鬆	
寬 鬆 環 境	寬 曠	寬 邊	寬 邊 帽	寬 饒	寬 讓	審 己 度 人	審 干	
審 曲 面 勢	審 判	審 判 上	審 判 者	審 判 長	審 判 前	審 判 員	審 判 庭	
審 判 程 序	審 判 學	審 判 權	審 批	審 改	審 定	審 官	審 前	
審 度	審 查	審 查 委 員 會	審 查 者	審 查 員	審 查 核 准	審 美	審 美 者	
審 美 評 價	審 美 感 受	審 美 觀	審 美 觀 點	審 計	審 計 工 作	審 計 局	審 計 部	
審 計 署	審 計 學	審 訂	審 時 定 勢	審 時 度 勢	審 校	審 核	審 案	
審 訊	審 問	審 問 者	審 理	審 處	審 結	審 視	審 慎	
審 察	審 察 人	審 稿	審 閱	審 斷	審 議	審 讀	審 驗	
寫 了	寫 人	寫 入	寫 下	寫 上	寫 大 字	寫 大 綱	寫 文	
寫 他	寫 出	寫 本	寫 生	寫 生 簿	寫 全	寫 回	寫 在	
寫 好	寫 字	寫 字 間	寫 字 檯	寫 成	寫 有	寫 作	寫 作 文	
寫 作 方 法	寫 作 知 識	寫 作 家	寫 作 學	寫 完	寫 序 言	寫 事	寫 來	
寫 到	寫 明	寫 法	寫 的	寫 信	寫 信 給	寫 屏	寫 真	
寫 寄	寫 得	寫 清	寫 報 道	寫 景	寫 畫	寫 給	寫 著	
寫 詞	寫 進	寫 意	寫 照	寫 詩	寫 道	寫 實	寫 實 主 義	
寫 實 性	寫 滿	寫 寫	寫 稿	寫 錯	寫 讀	層 內	層 出 不 窮	
層 出 疊 見	層 外	層 次	層 次 分 明	層 見 疊 出	層 卷 雲	層 板	層 狀	
層 流	層 面	層 級	層 高	層 帶	層 報	層 間	層 層	
層 層 加 碼	層 層 迭 迭	層 層 落 實	層 數	層 樓	層 積 雲	層 壓 板	層 巒 迭 嶂	
層 巒 疊 嶂	層 疊	履 仁 道 義	履 任	履 行	履 行 合 同	履 行 義 務	履 行 諾 言	
履 約	履 帶	履 帶 式 拖 拉 機	履 帶 車	履 帶 機	履 湯 蹈 火	履 新	履 歷	
履 歷 表	履 險 如 夷	履 薄 臨 沈	履 霜 知 冰	履 霜 堅 冰	履 舄 交 錯	幢 幢	幡 然	
幡 然 悔 悟	廢 人	廢 止	廢 止 者	廢 水	廢 水 處 理	廢 污 水	廢 位	
廢 址	廢 林	廢 油	廢 物	廢 物 箱	廢 品	廢 品 收 購	廢 品 率	
廢 頁	廢 食 忘 寢	廢 料	廢 時	廢 書 而 歎	廢 氣	廢 站	廢 紙	
廢 紙 簍	廢 除	廢 掉	廢 棄	廢 棄 物	廢 棄 物 掩 埋 場	廢 液	廢 票	
廢 船	廢 渣	廢 然	廢 然 而 反	廢 置	廢 置 不 用	廢 話	廢 嫡	
廢 寢 忘 食	廢 寢 忘 餐	廢 語	廢 銅	廢 銅 爛 鐵	廢 墟	廢 膠	廢 鋼	
廢 黜	廢 舊	廢 舊 物 資	廢 礦	廢 鐵	廚 子	廚 手	廚 司	
廚 灶	廚 具	廚 房	廚 娘	廚 師	廚 餘	廚 櫃	廟 中	
廟 主	廟 宇	廟 寺	廟 堂	廟 會	廟 裡	廝 打	廝 守	
廝 殺	廝 混	廝 敬 廝 愛	廣 土 眾 民	廣 大	廣 大 人 民	廣 大 青 年	廣 大 幹 部	
廣 大 群 眾	廣 大 興 業	廣 大 黨 員	廣 大 讀 者	廣 加	廣 末 涼 子	廣 交	廣 交 朋 友	
廣 交 會	廣 地	廣 宇 科 技	廣 州	廣 州 市	廣 而 言 之	廣 西	廣 西 自 治 區	
廣 西 壯 族	廣 西 壯 族 自 治 區	廣 西 省	廣 西 軍 區	廣 佈	廣 告	廣 告 公 司	廣 告 促 銷	
廣 告 效 果	廣 告 商	廣 告 牌	廣 告 業	廣 角	廣 角 鏡	廣 東	廣 東 人	
廣 東 省	廣 東 音 樂	廣 泛	廣 泛 性	廣 泛 開 展	廣 度	廣 為	廣 夏 細 旃	
廣 島	廣 島 市	廣 庭 大 眾	廣 益	廣 域 網	廣 眾	廣 眾 大 庭	廣 袖 高 髻	
廣 設	廣 博	廣 場	廣 寒 仙 子	廣 敞	廣 結	廣 結 良 緣	廣 開	
廣 開 才 路	廣 開 言 路	廣 開 門 路	廣 開 學 路	廣 傳	廣 廈	廣 義	廣 義 地 說	
廣 義 性	廣 義 相 對 論	廣 達 電 腦	廣 電 基 金 會	廣 漠	廣 漢	廣 種 薄 收	廣 播	
廣 播 工 作	廣 播 界	廣 播 員	廣 播 電 台	廣 播 電 視	廣 播 電 視 部	廣 播 電 影 電 視 部	廣 播 網	
廣 播 劇	廣 播 稿	廣 播 操	廣 播 講 座	廣 播 講 話	廣 播 體 操	廣 積	廣 闊	
廣 闊 天 地	廣 闊 性	廣 豐 實 業	廣 識	廣 體	廣 袤	廣 袤 無 垠	廠 子	
廠 內	廠 方	廠 主	廠 史	廠 外	廠 休	廠 名	廠 地	
廠 址	廠 房	廠 房 擴 充	廠 長	廠 長 負 責 制	廠 家	廠 校 掛 鉤	廠 級	
廠 區	廠 商	廠 規	廠 部	廠 棚	廠 牌	廠 裝	廠 裡	
廠 辦	廠 礦	廠 礦 企 業	彈 力	彈 力 呢	彈 力 素	彈 力 襪	彈 丸	
彈 丸 之 地	彈 子	彈 弓	彈 斤 估 兩	彈 片	彈 出	彈 出 式	彈 去	
彈 吉 他	彈 回	彈 匣	彈 坑	彈 夾	彈 劾	彈 性	彈 性 化	
彈 性 體	彈 空 說 嘴	彈 雨	彈 冠 相 慶	彈 奏	彈 指	彈 指 如 飛	彈 射	
彈 射 器	彈 料	彈 珠	彈 起	彈 痕	彈 盒	彈 殼	彈 無 虛 發	
彈 琴	彈 筒	彈 絲 品 竹	彈 詞	彈 量	彈 開	彈 跳	彈 道	
彈 道 學	彈 道 導 彈	彈 盡 援 絕	彈 盡 糧 絕	彈 豎 琴	彈 頭	彈 壓	彈 簧	
彈 簧 秤	彈 簧 腿	彈 簧 鋼	彈 藥	彈 藥 庫	彈 藥 消 耗	彈 藥 筒	彈 藥 箱	
彈 藥 學	彈 體	彈 鋏 無 魚	影 人	影 子	影 片	影 印	影 印 本	
影 印 件	影 印 機	影 兒	影 城	影 星	影 射	影 展	影 迷	
影 院	影 圈	影 液	影 視	影 視 圈	影 評	影 集	影 業	
影 像	影 碟	影 劇 名 人	影 劇 院	影 影 綽 綽	影 線	影 調	影 劑	
影 壁	影 壇	影 戲	影 蹤	影 響	影 響 力	影 響 很 大	德 人	
德 才	德 才 兼 備	德 文	德 以 報 怨	德 州	德 州 儀 器	德 州 戰 役	德 式	
德 行	德 克 薩 斯	德 利 建 設	德 利 科 技	德 育	德 言 功 貌	德 言 容 功	德 性	
德 昌 營 造	德 厚 流 光	德 政	德 派	德 軍	德 音 莫 違	德 容 兼 備	德 記 洋 行	
德 高 望 重	德 國	德 國 人	德 國 化	德 基 水 庫	德 淺 行 薄	德 彪 西	德 尊 望 重	
德 智 體	德 隆 望 重	德 隆 望 尊	德 黑 蘭	德 意 志	德 意 志 銀 行	德 新 社	德 裡	
德 漢	德 語	德 薄 才 疏	德 薄 能 鮮	德 寶 營 造	徵 才	徵 文	徵 召	
徵 召 令	徵 召 員	徵 用	徵 兆	徵 名 責 實	徵 收	徵 兵	徵 兵 制	
徵 求	徵 求 意 見	徵 狀	徵 信 所	徵 信 社	徵 候	徵 候 學	徵 婚	
徵 得	徵 稅	徵 集	徵 募	徵 聘	徵 詢	徵 調	慶 父 不 死	
慶 父 不 死 魯 難 未 已	慶 功	慶 功 會	慶 事	慶 典	慶 典 活 動	慶 幸	慶 宴	
慶 祝	慶 祝 會	慶 賀	慶 壽	慶 豐 人 壽	慶 豐 商 銀	慶 豐 富 實	慶 豐 銀 行	
慧 心	慧 心 巧 思	慧 星	慧 根	慧 眼	慧 黠	慮 及	慕 尼 黑	
慕 名	慕 名 而 來	憂 公 如 家	憂 公 忘 私	憂 公 無 私	憂 心	憂 心 如 焚	憂 心 如 搗	
憂 心 如 醉	憂 心 如 酲	憂 心 若 醉	憂 心 悄 悄	憂 心 忡 忡	憂 民	憂 民 憂 國	憂 色	
憂 形 於 色	憂 抑	憂 沉	憂 思	憂 苦	憂 能 傷 人	憂 國	憂 國 如 家	
憂 國 忘 私	憂 國 忘 身	憂 國 忘 家	憂 國 哀 民	憂 國 恤 民	憂 國 愛 民	憂 國 憂 民	憂 患	
憂 深 思 遠	憂 悶	憂 傷	憂 愁	憂 慮	憂 憤	憂 懼	憂 鬱	
憂 鬱 不 樂	憂 鬱 症	慰 言	慰 使	慰 勉	慰 唁	慰 問	慰 問 信	
慰 問 品	慰 問 袋	慰 問 電	慰 問 團	慰 勞	慰 解	慰 撫	慰 撫 者	
慰 藉	慰 藉 物	慰 雞 之 力	慫 恿	慾 火	慾 念	慾 海	慾 望	
慾 壑 難 填	憧 憬	憐 才	憐 之	憐 孤 惜 寡	憐 恤	憐 香 惜 玉	憐 惜	
憐 貧 惜 老	憐 貧 敬 老	憐 愛	憐 新 棄 舊	憐 憫	憫 惜	憎 恨	憎 惡	
憎 厭	憤 不 顧 身	憤 世 嫉 邪	憤 世 嫉 俗	憤 怒	憤 恨	憤 氣 填 膺	憤 慨	
憤 然	憤 然 而 起	憤 發	憤 憤	憤 憤 不 平	憤 激	憤 懣	憔 悴	
戮 力 一 心	戮 力 同 心	戮 力 齊 心	戮 刺	戮 穿	戮 破	戮 記	戮 傷	
摩 下	摩 天	摩 天 大 廈	摩 天 大 樓	摩 天 樓	摩 托	摩 托 化	摩 托 車	
摩 托 羅 拉	摩 肩	摩 肩 如 雲	摩 肩 接 踵	摩 肩 擊 轂	摩 門 經	摩 洛 哥	摩 拳 擦 掌	
摩 根	摩 根 士 丹 利	摩 根 士 坦 利	摩 根 台 指	摩 納 哥	摩 崖	摩 頂 至 足	摩 頂 至 踵	
摩 頂 放 踵	摩 斯	摩 登	摩 瑞 絲 莫	摩 爾	摩 爾 多 瓦	摩 厲 以 須	摩 羯 座	
摩 擦	摩 擦 力	摩 擦 系 數	摩 擦 阻 力	摩 擦 計	摩 擦 音	摩 擦 電	摩 擦 學	
摩 擦 聲	摩 挲	摯 友	摯 愛	摹 古	摹 本	摹 仿	摹 刻	
摹 制	摹 狀	摹 描	摹 畫	摹 寫	摹 寫 品	摹 擬	摹 繪	
撞 了	撞 人	撞 入	撞 上	撞 打	撞 死	撞 見	撞 車	
撞 到	撞 府 沖 州	撞 府 穿 州	撞 性	撞 歪	撞 倒	撞 破	撞 針	
撞 陣 沖 軍	撞 球	撞 球 家	撞 球 賽	撞 著	撞 進	撞 開	撞 傷	
撞 毀	撞 碎	撞 撞	撞 擊	撞 擊 聲	撞 聲	撞 鎖	撞 壞	
撞 騙	撞 鐘	撲 火	撲 出	撲 去	撲 打	撲 向	撲 地	
撲 在	撲 住	撲 作 教 刑	撲 克	撲 克 牌	撲 克 臉	撲 到	撲 空	
撲 虎	撲 面	撲 面 而 來	撲 倒	撲 朔	撲 朔 迷 離	撲 粉	撲 動	
撲 救	撲 殺 此 獠	撲 通	撲 楞	撲 滅	撲 滅 者	撲 滿	撲 鼻	
撲 鼻 而 來	撲 簌	撲 簌 簌	撲 翼	撲 騰	撲 哧	撈 一 把	撈 月	
撈 出	撈 本	撈 到	撈 取	撈 捕	撈 起	撈 著	撈 網	
撈 稻 草	撈 錢	撐 天 拄 地	撐 住	撐 物	撐 門 面	撐 持	撐 柱	
撐 架	撐 眉 怒 眼	撐 竿	撐 竿 跳	撐 竿 跳 高	撐 起	撐 桿	撐 船	
撐 傘	撐 場 面	撐 著	撐 開	撐 腰	撐 腸 拄 肚	撐 腸 拄 腹	撐 緊	
撐 篙	撰 文	撰 文 者	撰 序	撰 者	撰 述	撰 書	撰 著	
撰 寫	撰 稿	撰 稿 人	撥 下	撥 子	撥 冗	撥 火	撥 付	
撥 出	撥 叫 式	撥 正	撥 交	撥 作	撥 弄	撥 快	撥 雨 撩 雲	
撥 准	撥 草 尋 蛇	撥 動	撥 通	撥 款	撥 給	撥 開	撥 雲 見 日	
撥 雲 睹 日	撥 雲 撩 雨	撥 亂 之 才	撥 亂 反 正	撥 亂 反 治	撥 亂 誅 暴	撥 亂 興 治	撥 亂 濟 危	
撥 亂 濟 時	撥 萬 輪 千	撥 號	撥 號 網 絡	撥 號 盤	撥 補	撥 電	撥 慢	
撥 撥	撥 繳	撓 曲	撓 直 為 曲	撓 度	撓 頭	撓 癢	撕 下	
撕 去	撕 打	撕 成	撕 扯	撕 咬	撕 破	撕 破 臉 皮	撕 得	
撕 掉	撕 殺	撕 票	撕 裂	撕 開	撕 毀	撕 碎	撕 碎 機	
撕 壞	撕 爛	撩 人	撩 起	撩 動	撩 望	撩 逗	撩 開	
撩 雲 撥 雨	撩 亂	撩 蜂 吃 蟄	撩 蜂 拔 刺	撩 蜂 剔 蠍	撩 撥	撒 丁 島	撒 刁	
撒 手	撒 手 不 管	撒 水	撒 布	撒 旦	撒 在	撒 克 遜 人	撒 尿	
撒 沙 子	撒 豆 成 兵	撒 拉	撒 拉 遜 人	撒 哈 拉	撒 科 打 諢	撒 胡 椒 面	撒 食	
撒 氣	撒 野	撒 詐 搗 虛	撒 開	撒 落	撒 遍	撒 滿	撒 種	
撒 網	撒 腿	撒 嬌	撒 嬌 撒 癡	撒 嬌 賣 俏	撒 播	撒 潑	撒 潑 打 滾	
撒 潑 放 刁	撒 營	撒 謊	撒 歡 兒	撮 合	撮 弄	撮 兒	撮 科 打 哄	
撮 要	撮 鹽 入 水	撮 鹽 入 火	播 下	播 出	播 弄	播 放	播 放 機	
播 映	播 音	播 音 室	播 音 員	播 送	播 送 者	播 報	播 報 者	
播 幅	播 惡 遺 臭	播 揚	播 散	播 發	播 過	播 種	播 種 者	
播 種 面	播 種 面 積	播 種 期	播 種 機	播 撒	播 糠 瞇 目	播 講	播 轉	
播 讀	撫 人	撫 今	撫 今 思 昔	撫 今 追 昔	撫 心 自 問	撫 古 思 今	撫 平	
撫 州	撫 弄	撫 育	撫 使	撫 孤 恤 寡	撫 拍	撫 抱	撫 松	
撫 恤	撫 恤 金	撫 背 扼 喉	撫 軍	撫 躬 自 問	撫 梁 易 柱	撫 掌	撫 掌 大 笑	
撫 順	撫 愛	撫 摸	撫 遠	撫 慰	撫 慰 性	撫 慰 者	撫 摩	
撫 養	撫 養 費	撬 走	撬 門	撬 起	撬 動	撬 棍	撬 開	
撬 槓	撬 鎖	撬 壞	撳 住	撳 紐	撳 鈕	敵 人	敵 工	
敵 中	敵 友	敵 手	敵 方	敵 占	敵 占 區	敵 台	敵 地	
敵 兵	敵 我	敵 我 矛 盾	敵 所	敵 者	敵 前	敵 後	敵 軍	
敵 害	敵 師	敵 特	敵 陣	敵 偽	敵 國	敵 寇	敵 得 過	
敵 情	敵 探	敵 眾 我 寡	敵 船	敵 視	敵 隊	敵 意	敵 愾 同 仇	
敵 群	敵 對	敵 對 者	敵 敵 畏	敵 樓	敵 機	敵 營	敷 上	
敷 以	敷 用	敷 衍	敷 衍 了 事	敷 衍 塞 責	敷 衍 搪 塞	敷 料	敷 粉	
敷 張 揚 厲	敷 設	敷 貼	敷 裹	敷 層	敷 敷	敷 藥	數 一 數 二	
數 九	數 九 寒 天	數 人	數 十	數 十 年	數 千	數 不 清	數 不 勝 數	
數 不 盡	數 天	數 尺	數 日	數 月	數 以 千 計	數 以 百 計	數 以 萬 計	
數 以 億 計	數 出	數 打	數 用	數 白 論 黃	數 目	數 目 字	數 伏	
數 列	數 多	數 字	數 字 上	數 字 化	數 字 式	數 字 通 信	數 字 模 型	
數 年	數 式	數 次	數 百	數 百 萬	數 米 而 炊	數 位	數 位 化	
數 位 相 機	數 位 聯 合	數 見 不 鮮	數 言	數 例	數 來 寶	數 典 忘 祖	數 奇 命 蹇	
數 往 知 來	數 易 其 稿	數 度	數 頁	數 倍	數 值	數 個	數 國	
數 得 著	數 控	數 理	數 理 化	數 理 哲 學	數 理 統 計	數 理 經 濟	數 理 經 濟 學	
數 理 邏 輯	數 組	數 發	數 詞	數 軸	數 量	數 量 指 標	數 量 級	
數 量 詞	數 量 經 濟 學	數 集	數 黃 道 白	數 黃 道 黑	數 黑 論 黃	數 萬	數 落	
數 過	數 種	數 說	數 億	數 數	數 模	數 碼	數 論	
數 學	數 學 上	數 學 公 式	數 學 方 法	數 學 家	數 據	數 據 表	數 據 庫	
數 據 區	數 據 處 理	數 據 通 信	數 據 通 訊	數 據 項	數 據 管 理	數 據 網	數 據 機	
數 錯	數 錢	數 斷 論 長	數 額	數 邏	暮 去 朝 來	暮 史 朝 經	暮 四 朝 三	
暮 生	暮 年	暮 死	暮 色	暮 更	暮 雨 朝 雲	暮 後	暮 思 朝 想	
暮 春	暮 氣	暮 景 桑 榆	暮 景 殘 光	暮 雲 親 捨	暮 歲	暮 鼓 晨 鐘	暮 暮 朝 朝	
暮 禮 晨 參	暮 齡	暮 靄	暮 虢 朝 虞	暫 不	暫 予	暫 欠	暫 且	
暫 付	暫 代	暫 用	暫 由	暫 存	暫 存 器	暫 扣	暫 收	
暫 行	暫 行 規 定	暫 行 辦 法	暫 住	暫 住 證	暫 作	暫 免	暫 別	
暫 告	暫 定	暫 居	暫 延	暫 於	暫 按	暫 借	暫 候	
暫 時	暫 時 性	暫 留	暫 缺	暫 停	暫 勞 永 逸	暫 減	暫 測	
暫 墊	暫 緩	暫 擱	暫 離	暴 力	暴 力 手 段	暴 力 主 義	暴 力 犯 罪	
暴 力 行 為	暴 力 行 動	暴 力 事 件	暴 內 陵 外	暴 牙	暴 民	暴 民 政 治	暴 吏	
暴 死	暴 行	暴 利	暴 君	暴 戾	暴 戾 恣 睢	暴 雨	暴 雨 成 災	
暴 怒	暴 政	暴 突	暴 虐	暴 虐 無 道	暴 風	暴 風 雨	暴 風 雨 般	
暴 風 雪	暴 風 驟 雨	暴 食	暴 食 暴 飲	暴 徒	暴 烈	暴 病	暴 笑	
暴 動	暴 眼	暴 富	暴 發	暴 發 戶	暴 裂	暴 跌	暴 飲	
暴 飲 暴 食	暴 亂	暴 跳	暴 跳 如 雷	暴 雷	暴 漢	暴 漲	暴 漲 暴 跌	
暴 增	暴 龍	暴 斂	暴 斃	暴 燥	暴 躁	暴 躁 如 雷	暴 露	
暴 露 目 標	暴 露 無 遺	暴 曬	暴 殄 天 物	暱 友	暱 愛	暱 稱	樣 子	
樣 子 好	樣 片	樣 冊	樣 本	樣 件	樣 多	樣 式	樣 兒	
樣 板	樣 板 戲	樣 品	樣 品 卡	樣 書	樣 帶	樣 張	樣 款	
樣 窗	樣 貌	樣 貌 端 正	樣 樣	樣 稿	樣 機	樟 木	樟 腦	
樟 腦 丸	樟 樹	樁 子	樁 基	樞 紐	樞 密 院	樞 軸	樞 機	
標 尺	標 引	標 出	標 本	標 用	標 目	標 示	標 示 符	
標 同 伐 異	標 名	標 有	標 兵	標 定	標 底	標 明	標 注	
標 金	標 度	標 竿	標 重	標 音	標 記	標 高	標 售	
標 桿	標 牌	標 量	標 新 立 異	標 新 取 異	標 新 領 導	標 會	標 準	
標 準 大 氣 壓	標 準 工 資	標 準 化	標 準 以 下	標 準 件	標 準 音	標 準 差	標 準 時	
標 準 時 間	標 準 框	標 準 唱 片	標 準 國 語	標 準 規	標 準 單 位	標 準 普 爾	標 準 溶 液	
標 準 像	標 準 檢 驗 局	標 號	標 圖	標 圖 器	標 榜	標 槍	標 稱	
標 誌	標 誌 符	標 誌 著	標 語	標 語 牌	標 價	標 箱	標 緻	
標 賣	標 器	標 燈	標 鋼	標 購	標 鍵	標 點	標 點 符 號	
標 題	標 題 之 下	標 題 字	標 題 為	標 題 音 樂	標 題 欄	標 識	標 識 符	
標 識 語	標 識 器	標 籤	槽 口	槽 子	槽 中	槽 內	槽 牙	
槽 車	槽 具	槽 輪	槽 鋼	模 子	模 本	模 仿	模 仿 者	
模 仿 鳥	模 件	模 式	模 式 化	模 里 西 斯	模 具	模 具 鋼	模 板	
模 版	模 版 工	模 型	模 型 飛 機	模 型 船	模 型 論	模 架	模 特	
模 特 兒	模 組	模 殼	模 塊	模 塊 化	模 稜	模 稜 兩 可	模 裡	
模 跡	模 態	模 數	模 樣	模 模 糊 糊	模 範	模 糊	模 糊 不 清	
模 糊 數 學	模 糊 論	模 糊 學	模 頭	模 壓	模 擬	模 擬 器	模 鍛	
樓 下	樓 上	樓 內	樓 去	樓 台	樓 台 亭 閣	樓 外	樓 宇	
樓 房	樓 板	樓 的	樓 門	樓 亭	樓 前	樓 面	樓 座	
樓 區	樓 基	樓 堂	樓 堂 館 所	樓 梯	樓 船	樓 頂	樓 群	
樓 號	樓 裡	樓 道	樓 蓋	樓 閣	樓 層	樓 盤	樓 學 賢	
樓 舉 百 捷	樊 亦 敏	樊 籠	槳 手	槳 形	槳 葉	樂 了	樂 人	
樂 土	樂 士 電 機	樂 山 樂 水	樂 不 可 支	樂 不 可 言	樂 不 可 極	樂 不 思 蜀	樂 不 開 支	
樂 天	樂 天 知 命	樂 天 派	樂 戶	樂 手	樂 以 忘 憂	樂 台	樂 句	
樂 交	樂 地	樂 在 其 中	樂 曲	樂 此	樂 此 不 倦	樂 此 不 疲	樂 死	
樂 池	樂 而 不 荒	樂 而 忘 返	樂 而 忘 歸	樂 見	樂 事	樂 兒	樂 呵 呵	
樂 府	樂 於	樂 於 助 人	樂 果	樂 法	樂 的	樂 律	樂 段	
樂 音	樂 師	樂 捐	樂 迷	樂 得	樂 理	樂 貧 甘 賤	樂 陶 陶	
樂 章	樂 滋 滋	樂 善 不 倦	樂 善 好 施	樂 善 好 義	樂 著	樂 隊	樂 園	
樂 意	樂 感	樂 極	樂 極 生 悲	樂 極 則 悲	樂 極 悲 生	樂 極 悲 來	樂 聖	
樂 號	樂 道	樂 道 安 貧	樂 團	樂 禍	樂 禍 幸 災	樂 窩	樂 舞	
樂 樂 陶 陶	樂 調	樂 趣	樂 器	樂 壇	樂 聲	樂 譜	樂 譜 架	
樂 譜 集	樂 鐘	樂 騰	樂 齡	樂 觀	樂 觀 主 義 者	樂 觀 者	樅 木	
樅 樹	樑 上	樑 上 君 子	樑 柱	歐 人	歐 化	歐 文	歐 尼 爾	
歐 布 萊 特	歐 正 明	歐 共 體	歐 安 會	歐 式	歐 米 茄	歐 亞	歐 亞 大 陸	
歐 亞 經 濟 共 同 體	歐 姆	歐 姆 計	歐 非	歐 洲	歐 洲 人	歐 洲 安 全 合 作 組 織	歐 洲 股 市	
歐 洲 國 家	歐 洲 產	歐 美	歐 美 同 學 會	歐 風 美 雨	歐 晉 德	歐 格 電 子	歐 陸	
歐 普	歐 普 拉	歐 陽	歐 盟	歐 語	歐 蕾	歐 體	歎 了 一 口 氣	
歎 老 嗟 卑	歎 服	歎 者	歎 為	歎 為 觀 止	歎 息	歎 氣	歎 惜	
歎 喟	歎 詞	歎 號	歎 語	歎 賞	歎 聲	毅 力	毅 然	
毅 然 決 然	毅 嘉 科 技	毆 打	毆 氣	毆 鬥	毆 偏 救 弊	毆 傷	漿 汁	
漿 衣	漿 果	漿 洗	漿 料	漿 紗	漿 酒 霍 肉	漿 酒 藿 肉	漿 液	
漿 粕	漿 糊	漿 膜	漿 巖	潼 關	澄 江	澄 思 寂 慮	澄 清	
澄 清 天 下	澄 清 事 實	澄 清 湖	澄 清 劑	澄 湛	澄 徹	澄 瑩	澄 邁	
潑 水	潑 水 節	潑 水 難 收	潑 以	潑 出	潑 皮	潑 冷 水	潑 性	
潑 悍	潑 婦	潑 掉	潑 辣	潑 墨	潑 濕	潑 濺	潑 灑	
潑 髒	潦 倒	潦 草	潦 亂	潦 寫	潦 潦 草 草	潔 己 奉 公	潔 己 愛 人	
潔 白	潔 白 無 瑕	潔 言 污 行	潔 身	潔 身 自 好	潔 身 自 愛	潔 具	潔 度	
潔 淨	潔 劑	潔 器	潔 癖	澆 下	澆 水	澆 瓜 之 惠	澆 地	
澆 在	澆 制	澆 花	澆 洗	澆 風 薄 俗	澆 透	澆 菜	澆 築	
澆 灌	澆 鑄	潭 子 鄉	潭 底	潛 入	潛 力	潛 下	潛 山	
潛 山 隱 市	潛 心	潛 心 於	潛 水	潛 水 人	潛 水 泵	潛 水 員	潛 水 球	
潛 水 鳥	潛 水 艇	潛 伏	潛 伏 性	潛 伏 所	潛 伏 期	潛 伏 著	潛 在	
潛 在 力 量	潛 在 性	潛 江	潛 行	潛 形 匿 跡	潛 沒	潛 身 遠 跡	潛 身 遠 禍	
潛 泳	潛 客	潛 流	潛 科 學	潛 神 默 思	潛 神 默 記	潛 能	潛 航	
潛 逃	潛 動	潛 匿	潛 望	潛 望 鏡	潛 移	潛 移 陰 奪	潛 移 暗 化	
潛 移 默 化	潛 移 默 運	潛 移 默 奪	潛 游	潛 滋 暗 長	潛 蛟 困 鳳	潛 勢	潛 意 識	
潛 艇	潛 圖 問 鼎	潛 熱	潛 隨	潛 骸 竄 影	潛 龍 勿 用	潛 龍 伏 虎	潛 虧	
潛 藏	潛 蹤	潸 然	潮 力	潮 水	潮 州	潮 州 鎮	潮 汐	
潮 汕	潮 汛	潮 位	潮 流	潮 紅	潮 差	潮 氣	潮 訊	
潮 起	潮 退	潮 退 了	潮 湧	潮 陽	潮 落	潮 解	潮 漲 潮 落	
潮 濕	潮 聲	澎 恰 恰	澎 湖	澎 湖 灣	澎 湃	潺 潺	潺 潺 聲	
潺 聲	潰 不 成 軍	潰 兵	潰 決	潰 退	潰 逃	潰 敗	潰 處	
潰 堤	潰 散	潰 裂	潰 亂	潰 滅	潰 瘍	潰 瘍 性	潰 敵	
潰 爛	潤 色	潤 肺	潤 金	潤 格	潤 泰 建 設	潤 泰 紡 織	潤 喉	
潤 發	潤 筆	潤 絲	潤 嗓	潤 滑	潤 滑 性	潤 滑 油	潤 滑 物	
潤 滑 脂	潤 滑 劑	潤 腸	潤 資	潤 飾	潤 膚	潤 澤	潤 濕	
澗 流	潘 江 陸 海	潘 陸 江 海	潘 楊 之 睦	潘 鬢 成 霜	潘 鬢 沈 腰	潘 燊 昌	滕 州	
熟 了	熟 人	熟 化	熟 友	熟 手	熟 石 灰	熟 石 膏	熟 地	
熟 字	熟 成	熟 肉	熟 制	熟 念	熟 知	熟 門 熟 路	熟 客	
熟 思	熟 食	熟 食 店	熟 料	熟 能 生 巧	熟 荒	熟 記	熟 悉	
熟 習	熟 透	熟 菜	熟 視	熟 視 無 睹	熟 飯	熟 落	熟 路	
熟 路 輕 車	熟 路 輕 轍	熟 睡	熟 語	熟 銅	熟 慮	熟 練	熟 練 工 人	
熟 練 者	熟 請	熟 諳	熟 識	熟 爛	熟 鐵	熟 讀	熬 心	
熬 出	熬 汁	熬 成	熬 到	熬 夜	熬 湯	熬 煮	熬 粥	
熬 煎	熬 煉	熬 過	熬 藥	熱 力	熱 力 學	熱 中	熱 中 子	
熱 中 者	熱 分 解	熱 切	熱 化	熱 化 學	熱 天	熱 心	熱 心 人	
熱 心 者	熱 心 家	熱 心 腸	熱 水	熱 水 瓶	熱 火	熱 火 朝 天	熱 火 隊	
熱 乎	熱 乎 乎	熱 乎 勁	熱 加 工	熱 功 當 量	熱 可 塑 性 橡 膠	熱 打	熱 交 換	
熱 光	熱 地 蚰 蜓	熱 血	熱 血 沸 騰	熱 吻	熱 忱	熱 材 料	熱 汽	
熱 身	熱 身 賽	熱 制	熱 制 導	熱 呼 呼	熱 和	熱 季	熱 念	
熱 河	熱 法	熱 炒	熱 狗	熱 軋	熱 門	熱 門 貨	熱 勁	
熱 度	熱 流	熱 風	熱 食	熱 值	熱 核	熱 氣	熱 氣 騰 騰	
熱 浪	熱 浴	熱 烈	熱 病	熱 脆	熱 脆 性	熱 能	熱 茶	
熱 衷	熱 衷 於	熱 衷 者	熱 帶	熱 帶 病	熱 得	熱 情	熱 情 周 到	
熱 情 洋 溢	熱 情 接 待	熱 情 關 注	熱 敏 電 阻	熱 望	熱 淚	熱 淚 盈 眶	熱 處 理	
熱 被	熱 毯	熱 湯	熱 脹	熱 量	熱 量 計	熱 飲	熱 傳 導	
熱 意	熱 感	熱 愛	熱 愛 者	熱 源	熱 腸	熱 誠	熱 載 體	
熱 過	熱 電	熱 電 子	熱 電 站	熱 電 偶	熱 電 堆	熱 電 廠	熱 漲	
熱 磁	熱 管	熱 舞 2000	熱 認	熱 辣 辣	熱 障	熱 敷	熱 潮	
熱 熬 翻 餅	熱 熱 鬧 鬧	熱 線	熱 線 電 話	熱 銷	熱 鬧	熱 學	熱 導	
熱 戰	熱 機	熱 膨 脹	熱 諷	熱 輻 射	熱 鋼	熱 壓	熱 薄 餅	
熱 鍍	熱 鍵	熱 鍋 上 的 螞 蟻	熱 鍋 上 螞 蟻	熱 點	熱 離	熱 離 子	熱 爐	
熱 騰 騰	熱 戀	熨 斗	熨 平	熨 衣	熨 帖	熨 袖 架	牖 中 窺 日	
獎 券	獎 拔 公 心	獎 狀	獎 的	獎 金	獎 金 稅	獎 勉	獎 品	
獎 盃	獎 限	獎 售	獎 章	獎 牌	獎 給	獎 項	獎 勤	
獎 勤 罰 懶	獎 旗	獎 罰	獎 賞	獎 學 金	獎 優 罰 劣	獎 勵	獎 勵 制 度	
獎 勵 金	獎 勵 品	獎 懲	獎 懲 制 度	瑩 瑩	瑩 寶 科 技	璀 燦	璀 璨	
畿 輔	瘠 人 肥 己	瘠 己 肥 人	瘠 牛 僨 豚	瘠 田	瘠 地	瘠 薄	瘟 疫	
瘟 病	瘟 疹	瘟 神	瘤 子	瘤 胃	瘤 病	瘤 塊	瘦 人	
瘦 子	瘦 小	瘦 肉	瘦 身	瘦 的	瘦 長	瘦 削	瘦 弱	
瘦 脊	瘦 馬	瘦 骨 如 柴	瘦 骨 伶 仃	瘦 骨 嶙 峋	瘦 商 百 富	瘦 得	瘦 瘦	
瘦 臉	瘦 癟	瘡 疤	瘡 痍	瘡 痍 滿 目	瘢 痕	瘢 點	皚 皚	
皺 折	皺 眉	皺 眉 肌	皺 眉 頭	皺 眉 蹙 眼	皺 紋	皺 起	皺 痕	
皺 縮	皺 褶	皺 褶 多	皺 額	皺 襞	皺 邊	盤 子	盤 山	
盤 中	盤 元	盤 水 加 劍	盤 片	盤 古	盤 尼 西 林	盤 石 之 安	盤 石 之 固	
盤 石 犬 牙	盤 石 桑 苞	盤 亙	盤 存	盤 住	盤 估	盤 坐	盤 弄	
盤 沙 簡 金	盤 定	盤 狀 物	盤 查	盤 香	盤 剝	盤 庫	盤 桓	
盤 根	盤 根 究 底	盤 根 問 底	盤 根 錯 節	盤 馬 彎 弓	盤 商	盤 問	盤 帳	
盤 旋	盤 旋 物	盤 梯	盤 條	盤 貨	盤 場	盤 結	盤 著 腿	
盤 費	盤 號	盤 算	盤 腿	盤 標	盤 膝	盤 賬	盤 賭	
盤 踞	盤 整	盤 錦	盤 頭	盤 點	盤 繞	盤 繩 栓	盤 纏	
瞎 了	瞎 子	瞎 子 摸 魚	瞎 忙	瞎 自 誇	瞎 吹	瞎 弄	瞎 扯	
瞎 扯 淡	瞎 抓	瞎 指 揮	瞎 猜	瞎 眼	瞎 聊	瞎 搞	瞎 碰	
瞎 話	瞎 說	瞎 編	瞎 談	瞎 調	瞎 鬧	瞎 轉	瞎 闖	
瞎 掰	瞎 謅	瞇 眼	瞇 著	瞇 過	瞇 瞇	瞇 縫	瞌 睡	
瞑 目	磋 商	磋 商 者	磋 商 會	磋 跎	磅 值	磅 秤	磅 達	
磅 盤	磅 礡	確 已	確 切	確 切 性	確 切 無 疑	確 立	確 因	
確 守	確 有	確 有 其 事	確 告	確 系	確 定	確 定 不 移	確 定 性	
確 知	確 非	確 非 易 事	確 信	確 信 無 疑	確 保	確 是	確 無	
確 然	確 診	確 當	確 實	確 實 有	確 實 性	確 認	確 確	
確 確 實 實	確 應	確 證	確 證 者	確 屬	確 權	確 鑿	確 鑿 不 移	
磊 落	磊 落 不 凡	磊 落 不 羈	磊 磊 軼 蕩	磊 磊 落 落	碾 子	碾 平	碾 米	
碾 碎	碾 過	碾 盤	碾 磨	碾 壓	磕 牙	磕 牙 料 嘴	磕 打	
磕 碰	磕 睡	磕 磕 絆 絆	磕 磕 碰 碰	磕 頭	磕 頭 如 搗	碼 子	碼 元	
碼 尺	碼 位	碼 表	碼 數	碼 頭	磐 石	磐 石 之 安	磐 英 科 技	
稿 人	稿 子	稿 本	稿 件	稿 底	稿 約	稿 員	稿 紙	
稿 費	稿 酬	稼 穡 艱 難	穀 殼	稽 查	稽 核	稽 留	稽 管	
稽 徵	稽 徵 機 關	稻 子	稻 田	稻 米	稻 城	稻 苗	稻 香	
稻 秧	稻 草	稻 草 人	稻 堆	稻 場	稻 殼	稻 種	稻 瘟	
稻 瘟 病	稻 穀	稻 穗	稻 糠	窯 子	窯 工	窯 內	窯 洞	
窯 爐	窮 人	窮 大 失 居	窮 山	窮 山 惡 水	窮 山 僻 壤	窮 工 極 巧	窮 不 失 義	
窮 天 極 地	窮 心 劇 力	窮 文 人	窮 日 子	窮 日 落 月	窮 且 益 堅	窮 乏	窮 本 極 源	
窮 光 蛋	窮 兇 極 虐	窮 兇 極 惡	窮 年 累 月	窮 年 累 世	窮 年 累 歲	窮 忙	窮 池 之 魚	
窮 而 後 工	窮 兵	窮 兵 極 武	窮 兵 黷 武	窮 困	窮 困 戶	窮 坑 難 滿	窮 妙 極 巧	
窮 形 極 狀	窮 形 極 相	窮 形 盡 相	窮 的	窮 則 思 變	窮 幽 極 微	窮 相	窮 苦	
窮 原 竟 委	窮 家 富 路	窮 根 究 底	窮 根 尋 葉	窮 病 人	窮 神 知 化	窮 神 觀 化	窮 追	
窮 追 不 捨	窮 鬼	窮 國	窮 奢 極 侈	窮 奢 極 欲	窮 寇	窮 寇 勿 追	窮 得	
窮 理	窮 理 盡 性	窮 通 皆 命	窮 途	窮 途 之 哭	窮 途 日 暮	窮 途 末 路	窮 途 落 魄	
窮 途 潦 倒	窮 鳥 入 懷	窮 富 極 貴	窮 期	窮 棒 子	窮 貴 極 富	窮 鄉	窮 鄉 僻 壤	
窮 隊	窮 極 其 妙	窮 極 則 變	窮 極 要 妙	窮 極 無 聊	窮 源 推 本	窮 源 竟 委	窮 猿 失 木	
窮 猿 投 林	窮 猿 奔 林	窮 當 益 堅	窮 達 有 命	窮 鼠 嚙 狸	窮 境	窮 盡	窮 酸	
窮 酸 氣	窮 酸 餓 醋	窮 閻 漏 屋	窮 擺	窮 纖 入 微	箭 矢	箭 在 弦 上	箭 尾	
箭 步	箭 桿	箭 術	箭 牌	箭 筒	箭 樓	箭 頭	箱 子	
箱 內	箱 包	箱 底	箱 門	箱 檢	箱 櫃	箱 體	範 文	
範 本	範 式	範 例	範 圍	範 圍 內	範 圍 是	範 圍 廣	範 疇	
範 疇 索 引	箴 言	箴 言 式	篆 文	篆 字	篆 刻	篆 刻 家	篆 書	
篆 體	篇 子	篇 目	篇 名	篇 章	篇 幅	篇 集	糊 口	
糊 弄	糊 里 糊 塗	糊 刷	糊 狀	糊 狀 物	糊 的	糊 封	糊 紙	
糊 塗	糊 塗 蟲	糊 話	糊 精	糊 糊	糊 牆	締 交	締 約	
締 約 國	締 造	締 造 者	締 結	締 構	締 緣	練 了	練 人	
練 功	練 打	練 字	練 成	練 兵	練 兵 場	練 武	練 金	
練 拳	練 球	練 習	練 習 本	練 習 生	練 習 曲	練 習 題	練 習 簿	
練 就	練 達	練 達 老 成	練 廠	練 練	練 齒	練 聲	緯 地 經 天	
緯 武 經 文	緯 城 實 業	緯 度	緯 紗	緯 密	緯 線	緻 密	緘 口	
緘 口 不 言	緘 口 如 瓶	緘 口 結 舌	緘 舌 封 口	緘 舌 閉 口	緘 舌 結 口	緘 言	緘 封	
緘 默	緬 因 州	緬 甸	緬 甸 人	緬 甸 幣	緬 甸 語	緬 語	緬 懷	
緝 私	緝 毒	緝 拿	緝 捕	緝 盜	緝 獲	編 了	編 入	
編 上	編 內	編 史	編 外	編 外 人 員	編 本	編 目	編 列	
編 列 預 算	編 印	編 年	編 年 史	編 成	編 曲	編 余	編 址	
編 委	編 委 會	編 注	編 法	編 者	編 者 按	編 後 記	編 派	
編 為	編 訂	編 訂 者	編 席	編 書	編 索	編 得	編 排	
編 組	編 組 站	編 造	編 造 謊 言	編 報	編 發	編 程	編 程 序	
編 結	編 著	編 進	編 隊	編 集	編 號	編 緊	編 網	
編 舞	編 製	編 劇	編 審	編 寫	編 寫 者	編 撰	編 碼	
編 碼 方 案	編 碼 器	編 練	編 緝	編 餘 人 員	編 導	編 整	編 篡	
編 篡 人	編 輯	編 輯 人 員	編 輯 工 作	編 輯 出 版	編 輯 台	編 輯 者	編 輯 室	
編 輯 按	編 輯 部	編 輯 器	編 選	編 錄	編 檔	編 織	編 織 物	
編 織 品	編 纂	編 纂 委 員 會	編 譯	編 譯 者	編 譯 程 序	編 譯 器	編 鐘	
緣 分	緣 文 生 義	緣 木 求 魚	緣 由	緣 份	緣 名 失 實	緣 故	緣 起	
緣 情 體 物	緣 說	緣 薄	緣 薄 分 淺	緣 鏗 命 蹇	線 下	線 上	線 卡	
線 外	線 民	線 式	線 西	線 形	線 材	線 性	線 性 元 件	
線 性 化	線 性 方 程	線 性 系 統	線 性 函 數	線 性 規 劃	線 性 變 換	線 抽 傀 儡	線 狀	
線 型	線 段	線 哨	線 索	線 般	線 圈	線 條	線 球	
線 粒 體	線 速 度	線 毯	線 程	線 軸	線 裝 書	線 路	線 團	
線 寬	線 槽	線 盤	線 膨 脹	線 頭	線 斷 風 箏	線 蟲	線 蟲 類	
線 繩	線 欄	線 襪	緞 子	緞 紋	緞 帶	緩 不 濟 急	緩 召	
緩 交	緩 刑	緩 存	緩 行	緩 兵	緩 兵 之 計	緩 步	緩 步 代 車	
緩 和	緩 和 劑	緩 和 器	緩 和 戰 略	緩 坡	緩 性	緩 建	緩 急	
緩 急 相 濟	緩 急 輕 重	緩 流	緩 洩 藥	緩 效	緩 氣	緩 期	緩 量	
緩 聘	緩 解	緩 慢	緩 徵	緩 緩	緩 緩 而 行	緩 衝	緩 衝 區	
緩 衝 劑	緩 衝 器	緩 辦	緩 醒	緩 議	緩 釋	罵 人	罵 天 罵	
罵 名	罵 她	罵 我	罵 走	罵 者	罵 架	罵 笑	罵 著	
罵 街	罵 罵 咧 咧	罵 聲	罵 題	罷 了	罷 工	罷 工 者	罷 手	
罷 市	罷 休	罷 免	罷 免 權	罷 兵	罷 官	罷 於 奔 命	罷 教	
罷 課	罷 黜	羯 鼓 催 花	翩 若 驚 鴻	翩 然	翩 翩	翩 翩 起 舞	翩 躚	
耦 合	耦 合 器	膛 內	膜 片	膜 拜	膜 質	膝 下	膝 上	
膝 上 型	膝 甲	膝 行	膝 行 肘 步	膝 狀	膝 部	膝 蓋	膝 蓋 骨	
膝 頭	膝 禮	膝 關 節	膝 癢 撓 背	膠 土	膠 化 體	膠 木	膠 水	
膠 水 般	膠 片	膠 布	膠 皮	膠 印	膠 合	膠 合 板	膠 合 劑	
膠 住	膠 乳	膠 卷	膠 卷 匣	膠 底	膠 東	膠 泥	膠 版	
膠 版 紙	膠 狀	膠 狀 物	膠 狀 體	膠 柱 鼓 瑟	膠 柱 調 瑟	膠 原 質	膠 粉	
膠 紙	膠 圈	膠 帶	膠 接	膠 條	膠 盒	膠 粒	膠 結	
膠 絲	膠 著	膠 軸	膠 塞	膠 塊	膠 靴	膠 墊	膠 漆	
膠 管	膠 膜	膠 質	膠 輥	膠 鞋	膠 囊	膠 體	膠 粘	
膚 皮	膚 皮 潦 草	膚 色	膚 淺	膚 覺	膘 肥	膘 肥 體 壯	膘 情	
蔗 渣	蔗 農	蔗 糖	蔽 之	蔽 天	蔽 日	蔽 帚 千 金	蔽 帚 自 珍	
蔽 物	蔽 塞	蔽 聰 塞 明	蔽 護	蔽 體	蔚 為	蔚 為 大 觀	蔚 然	
蔚 然 成 風	蔚 藍	蔚 蘭	蓮 子	蓮 心	蓮 池	蓮 花	蓮 花 步 步 生	
蓮 蓉	蓮 蓬	蓮 藕	蓮 霧	蔬 果 店	蔬 食 者	蔬 菜	蔬 菜 學	
蔭 子 封 妻	蔭 庇	蔭 涼	蔭 棚	蔭 道	蔭 蔽	蔓 生	蔓 延	
蔓 延 於	蔓 草	蔓 菁	蔓 籐	蔑 視	蔑 語	蔣 介 石	蔣 光 超	
蔣 家	蔡 仁 堅	蔡 兆 陽	蔡 安 蕎	蔡 志 忠	蔡 依 林	蔡 佳 宏	蔡 倫	
蔡 健 雅	蔡 鍔	蓬 戶 垢 牖	蓬 布	蓬 生 麻 中	蓬 江	蓬 車	蓬 門	
蓬 勃	蓬 勃 發 展	蓬 屋 生 輝	蓬 散	蓬 萊	蓬 亂	蓬 蓬	蓬 蓬 勃 勃	
蓬 閭 生 輝	蓬 頭 垢 面	蓬 頭 歷 齒	蓬 頭 跣 足	蓬 鬆	蓬 蓽 生 輝	蓬 蓽 增 輝	蓬 篳 生 光	
蓬 篳 生 輝	蓬 篳 增 輝	蔥 白	蔥 花	蔥 郁	蔥 綠	蔥 翠	蔥 蒜	
蔥 蔥	蔥 頭	蔥 顏 順 旨	蔥 蘢	蝴 蝶	蝴 蝶 斑	蝶 形	蝶 泳	
蝶 粉 蜂 黃	蝦 子	蝦 仁	蝦 片	蝦 皮	蝦 米	蝦 兵 蟹 將	蝦 面	
蝦 球	蝦 須	蝦 慌 蟹 亂	蝦 醬	蝦 類	蝸 牛	蝸 名 蠅 利	蝸 利 蠅 名	
蝸 角 虛 名	蝸 角 蠅 頭	蝸 居	蝸 桿	蝸 輪	蝙 蝠	蝙 蝠 俠	蝗 災	
蝗 蟲	蝌 蚪	衛 士	衛 生	衛 生 局	衛 生 局 所	衛 生 防 疫	衛 生 所	
衛 生 保 健	衛 生 員	衛 生 紙	衛 生 院	衛 生 動 員	衛 生 條 件	衛 生 球	衛 生 組 織	
衛 生 部	衛 生 棉	衛 生 間	衛 生 勤 務	衛 生 署	衛 生 學	衛 生 褲	衛 生 廳	
衛 戍	衛 戍 區	衛 戍 部 隊	衛 兵	衛 星	衛 星 地 面 站	衛 星 城	衛 星 偵 察	
衛 星 國	衛 星 通 信	衛 浴 設 備	衛 冕	衛 冕 者	衛 冕 冠 軍	衛 國	衛 視	
衛 隊	衛 道	衛 道 士	衛 道 科 技	衛 護	衝 入	衝 力	衝 下	
衝 上	衝 口 而 出	衝 口 而 發	衝 出	衝 去	衝 向	衝 刺	衝 到	
衝 昏	衝 昏 頭 腦	衝 冠 怒 發	衝 勁	衝 突	衝 突 地 區	衝 浪	衝 浪 板	
衝 浪 者	衝 破	衝 動	衝 殺	衝 散	衝 著	衝 進	衝 過	
衝 撞	衝 鋒	衝 鋒 陷 陣	衝 鋒 鎗	衝 擊	衝 擊 波	衝 擊 聲	褐 色	
褐 斑	褐 黑	褐 煤	褐 鐵 礦	複 句	複 印	複 印 件	複 印 機	
複 式	複 姓	複 查	複 述	複 眼	複 習	複 習 資 料	複 診	
複 試	複 製	複 製 本	複 製 品	複 製 器	複 寫	複 寫 紙	複 寫 簿	
複 數	複 閱	複 賽	複 雜	複 雜 化	複 雜 多 變	複 雜 性	複 雜 度	
複 雜 勞 動	褒 衣 博 帶	褒 忠 鄉	褒 揚	褒 善 貶 惡	褒 貶	褒 貶 不 一	褒 貶 與 奪	
褒 損	褒 義	褒 義 詞	褒 獎	褒 賞	褒 賢 遏 惡	褓 姆	諒 必	
諒 解	諒 察	談 了	談 上	談 不	談 不 上	談 今 論 古	談 及	
談 天	談 天 說 地	談 天 論 地	談 心	談 古 說 今	談 吐	談 吐 不 凡	談 吐 如 流	
談 吐 風 生	談 成	談 何	談 何 容 易	談 判	談 判 者	談 判 桌	談 妥	
談 言 微 中	談 些	談 到	談 的	談 虎 色 變	談 柄	談 家	談 笑	
談 笑 自 如	談 笑 自 若	談 笑 封 候	談 笑 風 生	談 起	談 得 上	談 情 說 愛	談 清	
談 逸 事	談 經 說 法	談 話	談 話 室	談 話 會	談 過	談 說	談 談	
談 論	談 論 風 生	談 鋒	談 攏	談 辭 如 雲	諄 諄	諄 諄 不 倦	諄 諄 告 誡	
諄 諄 善 誘	諄 醉	誕 生	誕 生 石	誕 生 地	誕 妄 不 經	誕 辰	請 人	
請 予	請 勿	請 勿 吸 煙	請 勿 諠 譁	請 他	請 功	請 功 受 賞	請 用	
請 示	請 示 報 告	請 向	請 在	請 安	請 自 隗 始	請 你	請 君 入 甕	
請 坐	請 批 示	請 批 評 指 正	請 求	請 求 者	請 見	請 走	請 使 用	
請 來	請 到	請 命	請 帖	請 於	請 注 意	請 者	請 便	
請 客	請 客 送 禮	請 柬	請 看	請 准	請 原 諒	請 拿	請 書	
請 假	請 做	請 參 閱	請 問	請 將	請 您	請 教	請 這	
請 喝 茶	請 喝 酒	請 單 擊	請 提 意 見	請 提 寶 貴 意 見	請 援	請 貼	請 進	
請 進 來	請 罪	請 電	請 與	請 說	請 諒 解	請 戰	請 講	
請 轉	請 轉 交	請 醫 生	請 辭	請 願	請 願 人	請 願 書	請 聽	
請 纓	諸 子	諸 子 百 家	諸 公	諸 多	諸 如	諸 如 此 類	諸 州	
諸 位	諸 君	諸 侯	諸 城	諸 候	諸 家	諸 島	諸 般	
諸 國	諸 稅	諸 項	諸 葛	諸 葛 亮	諸 暨	諸 種	課 上	
課 內	課 文	課 以	課 外	課 外 活 動	課 外 閱 讀	課 外 讀 物	課 本	
課 由	課 目	課 自	課 卷	課 取	課 的	課 表	課 長	
課 室	課 後	課 活	課 時	課 桌	課 堂	課 堂 教 學	課 處	
課 程	課 程 表	課 稅	課 間	課 間 操	課 業	課 經	課 徵	
課 餘	課 題	諉 罪	諂 上 抑 下	諂 上 傲 下	諂 笑	諂 媚	諂 媚 者	
諂 詞 令 色	諂 諛 取 容	調 了	調 人	調 入	調 三 斡 四	調 子	調 子 高	
調 勻	調 升	調 令	調 充	調 出	調 正	調 用	調 皮	
調 休	調 任	調 光	調 合	調 回	調 好	調 式	調 舌 弄 唇	
調 色	調 色 板	調 色 盤	調 色 劑	調 低	調 兵	調 兵 遣 將	調 弄	
調 走	調 車	調 車 場	調 防	調 侃	調 到	調 卷	調 味	
調 味 汁	調 味 品	調 味 料	調 味 瓶	調 和	調 和 化	調 和 主 義	調 和 鼎 鼐	
調 弦 弄 管	調 弦 品 竹	調 往	調 波	調 治	調 虎 離 山	調 虎 離 山 之 計	調 門	
調 門 兒	調 度	調 度 室	調 度 員	調 查	調 查 人	調 查 局	調 查 者	
調 查 表	調 查 研 究	調 查 員	調 查 組	調 查 部	調 派	調 相	調 研	
調 研 員	調 軌	調 音	調 頁	調 風 弄 月	調 風 變 俗	調 值	調 唆	
調 唇 弄 舌	調 料	調 笑	調 級	調 脂 弄 粉	調 酒	調 酒 員	調 配	
調 高	調 停	調 停 人	調 停 者	調 動	調 情	調 控	調 教	
調 理	調 理 素	調 速	調 幅	調 幅 器	調 換	調 焦	調 絲 弄 竹	
調 絲 品 竹	調 給	調 進	調 集	調 溫	調 節	調 節 作 用	調 節 板	
調 節 物	調 節 者	調 節 員	調 節 稅	調 節 閥	調 節 熱	調 節 劑	調 節 器	
調 經 劑	調 號	調 解	調 解 人	調 解 委 員 會	調 解 者	調 解 員	調 試	
調 資	調 運	調 察 員	調 演	調 製	調 製 解 調 器	調 製 器	調 遣	
調 價	調 嘴 弄 舌	調 嘴 調 舌	調 增	調 撥	調 調	調 適	調 遷	
調 閱	調 養	調 墨 弄 筆	調 劑	調 整	調 整 了	調 整 者	調 整 財 測	
調 整 結 構	調 整 器	調 諧	調 諧 器	調 頻	調 頭	調 壓	調 戲	
調 檔	調 薪	調 職	調 轉	調 離	調 羹	調 攝	誰 人	
誰 也	誰 也 不	誰 也 沒 有 想 到	誰 手	誰 先	誰 在	誰 有	誰 呀	
誰 的	誰 知	誰 是 誰 非	誰 個	誰 將	誰 都	誰 敢	誰 想	
誰 會 想 到	論 人	論 上	論 大	論 之	論 今 說 古	論 及	論 文	
論 文 索 引	論 文 集	論 斤 估 兩	論 曰	論 出	論 功 行 封	論 功 行 賞	論 功 封 賞	
論 史	論 正	論 件	論 列 是 非	論 事	論 定	論 法	論 爭	
論 者	論 持 久 戰	論 述	論 個	論 堆	論 從	論 理	論 理 學	
論 處	論 短	論 著	論 集	論 黃 數 白	論 黃 數 黑	論 罪	論 資 排 輩	
論 道 經 邦	論 稱	論 語	論 說	論 價	論 敵	論 談	論 調	
論 誰	論 壇	論 戰	論 據	論 點	論 叢	論 斷	論 題	
論 證	論 證 法	論 證 會	論 議 風 生	論 辯	諍 友	諍 言	誶 罵	
誹 聞	誹 謗	誹 謗 之 木	誹 謗 性	誹 謗 者	誹 謗 罪	諛 者	豌 豆	
豌 豆 莢	豎 子	豎 子 不 足 與 謀	豎 井	豎 目	豎 立	豎 在	豎 行	
豎 直	豎 眉	豎 框	豎 起	豎 起 脊 樑	豎 排	豎 眼	豎 笛	
豎 琴	豎 琴 似	豎 著	豎 領	豎 寫	豎 標	豎 線	豬	
豬 一 般	豬 一 樣	豬 八 戒	豬 仔	豬 叫	豬 扒	豬 皮	豬 年	
豬 耳	豬 肉	豬 肉 餅	豬 舌	豬 血	豬 似	豬 尾	豬 肝	
豬 肚	豬 兒	豬 油	豬 油 狀	豬 肺	豬 屎	豬 苗	豬 革	
豬 食	豬 倌	豬 般	豬 圈	豬 排	豬 捨	豬 場	豬 群	
豬 腰	豬 腳	豬 腿 肉	豬 鼻	豬 嘴	豬 瘟	豬 瘟 病 毒	豬 蹄	
豬 頭	豬 頭 皮	豬 環 狀 病 毒	豬 鬃	豬 類	豬 欄	豬 玀	豬 籠 草	
豬 崽	賠 了	賠 了 夫 人 又 折 兵	賠 人	賠 上	賠 小 心	賠 不 是	賠 付	
賠 本	賠 光	賠 者	賠 笑	賠 笑 臉	賠 帳	賠 得	賠 產	
賠 累	賠 款	賠 罪	賠 補	賠 話	賠 墊	賠 賞	賠 錢	
賠 償	賠 償 制 度	賠 償 者	賠 償 金	賠 償 費	賠 償 損 失	賠 還	賠 禮	
賠 禮 道 歉	賠 額	賞 一 勸 眾	賞 力	賞 不 當 功	賞 不 逾 日	賞 不 逾 時	賞 不 遺 賤	
賞 心	賞 心 悅 目	賞 心 樂 事	賞 月	賞 付	賞 功 罰 罪	賞 光	賞 同 罰 異	
賞 玩	賞 金	賞 封	賞 格	賞 鳥	賞 給	賞 善 罰 惡	賞 號	
賞 罰	賞 罰 不 明	賞 罰 不 信	賞 罰 不 當	賞 罰 分 明	賞 罰 無 章	賞 罰 黜 陟	賞 罰 嚴 明	
賞 與	賞 銀	賞 賜	賞 賜 無 度	賞 錢	賞 臉	賞 還	賞 識	
賞 鑒	賦 予	賦 以	賦 有	賦 役	賦 性	賦 於	賦 值	
賦 格	賦 稅	賦 閒	賦 閒 無 事	賦 詩	賦 與	賤 人	賤 內	
賤 民	賤 冰 履 炭	賤 骨 頭	賤 貨	賤 視	賤 買	賤 買 貴 賣	賤 價	
賤 賣	賤 斂 貴 出	賤 斂 貴 發	賬 戶	賬 冊	賬 本 兒	賬 目	賬 房	
賬 面	賬 務	賬 單	賬 號	賬 簿	賭 友	賭 本	賭 犯	
賭 光	賭 局	賭 具	賭 咒	賭 注	賭 法	賭 金	賭 客	
賭 風	賭 徒	賭 氣	賭 馬	賭 鬼	賭 帳	賭 博	賭 博 者	
賭 博 案	賭 博 場	賭 場	賭 棍	賭 牌	賭 債	賭 窟	賭 運 氣	
賭 窩	賭 賬	賭 輸	賭 錢	賭 館	賭 贏	賢 人	賢 才	
賢 才 君 子	賢 內	賢 內 助	賢 臣	賢 弟	賢 良	賢 良 方 正	賢 妻	
賢 妻 良 母	賢 妹	賢 明	賢 者	賢 相	賢 哲	賢 孫	賢 徒	
賢 能	賢 淑	賢 惠	賢 達	賢 德	賢 慧	賢 賢 易 色	賢 侄	
賣 了	賣 人	賣 人 情	賣 刀 買 犢	賣 力	賣 力 氣	賣 大 號	賣 不 掉	
賣 公 營 私	賣 友	賣 文	賣 方	賣 方 市 場	賣 主	賣 主 求 榮	賣 出	
賣 出 價	賣 功	賣 光	賣 冰 者	賣 好	賣 老	賣 完	賣 局	
賣 弄	賣 弄 玄 虛	賣 弄 風 情	賣 弄 風 騷	賣 身	賣 身 投 靠	賣 身 契	賣 乖	
賣 兒 鬻 女	賣 到	賣 命	賣 妻 鬻 子	賣 官 鬻 獄	賣 官 鬻 爵	賣 房	賣 狗 皮 膏 藥	
賣 狗 懸 羊	賣 的	賣 空	賣 者	賣 花	賣 俏	賣 俏 行 奸	賣 俏 迎 奸	
賣 俏 營 奸	賣 勁	賣 品	賣 契	賣 座	賣 書	賣 笑	賣 茶	
賣 唱	賣 國	賣 國 求 利	賣 國 求 榮	賣 國 賊	賣 得	賣 掉	賣 清	
賣 淫	賣 淫 嫖 娼	賣 票	賣 貨	賣 魚 婦	賣 場	賣 報	賣 給	
賣 買	賣 超	賣 超 過	賣 傻	賣 價	賣 劍 買 牛	賣 盤	賣 錢	
賣 頭 賣 腳	賣 壓	賣 爵 贅 子	賣 爵 鬻 子	賣 斷	賣 藝	賣 關 子	賣 關 節	
賜 予	賜 示	賜 姓	賜 官	賜 教	賜 給	賜 福	賜 與	
質 上	質 子	質 化	質 劣	質 因 數	質 地	質 地 薄	質 次 價 高	
質 而 不 俚	質 而 不 野	質 言	質 妻 鬻 子	質 的	質 直 渾 厚	質 架	質 料	
質 問	質 問 者	質 量	質 量 第 一	質 量 管 理	質 量 數	質 量 標 準	質 量 檢 查	
質 量 檢 驗	質 量 關	質 感	質 詢	質 疑	質 疑 問 難	質 層	質 數	
質 樸	質 優	質 檢	質 點	質 變	質 體	赭 土	赭 石	
赭 色	赭 衣 塞 路	赭 衣 滿 道	趟 水	趟 田	趣 地	趣 事	趣 味	
趣 味 休 閒	趣 味 性	趣 捨 有 時	趣 園	趣 話	趣 聞	趣 聞 軼 事	踐 約	
踐 價	踐 踏	踐 諾	踝 骨	踝 關 節	踢 天 弄 井	踢 出	踢 出 去	
踢 去	踢 皮 球	踢 回	踢 走	踢 足 球	踢 來	踢 到	踢 法	
踢 建	踢 倒	踢 起	踢 得	踢 掉	踢 球	踢 球 者	踢 開	
踢 腳	踢 踏	踢 蹬	踏 入	踏 入 社 會	踏 入 政 壇	踏 上	踏 月	
踏 木	踏 出	踏 平	踏 在	踏 步	踏 足	踏 足 板	踏 車	
踏 到	踏 板	踏 板 車	踏 青	踏 看	踏 破 鐵 靴 無 覓 處	踏 勘	踏 動	
踏 船	踏 雪	踏 尋	踏 進	踏 滅	踏 腳	踏 腳 石	踏 腳 處	
踏 過	踏 遍	踏 實	踏 舞	踏 踏	踏 踏 實 實	踏 錯	踩 入	
踩 水	踩 出	踩 在	踩 死	踩 住	踩 倒	踩 高 蹺	踩 動	
踩 著	踩 滅	踩 碎	踩 熄	踩 線	踩 踏	踩 踏 板	踩 壞	
踟 躇	踟 躕	躺 了	躺 下	躺 平	躺 在	躺 臥	躺 倒	
躺 椅	躺 著	躺 開	輝 光	輝 映	輝 煌	輝 煌 奪 目	輝 綠	
輛 車	輛 數	輟 食 吐 哺	輟 耕	輟 筆	輟 演	輟 學	輩 子	
輩 分	輩 出	輩 份	輩 數	輦 轂 之 下	輪 上	輪 子	輪 台	
輪 生	輪 伙	輪 休	輪 式	輪 作	輪 形	輪 到	輪 狀	
輪 空	輪 姦	輪 扁 斫 輪	輪 流	輪 胎	輪 胎 蓋	輪 胎 壁	輪 值	
輪 栽	輪 班	輪 訓	輪 退	輪 迴	輪 唱	輪 圈	輪 埠	
輪 帶	輪 旋 曲	輪 組	輪 船	輪 換	輪 替	輪 椅	輪 渡	
輪 番	輪 著	輪 距	輪 軸	輪 廓	輪 種	輪 駁	輪 盤	
輪 賭	輪 齒	輪 戰	輪 機	輪 機 手	輪 機 長	輪 輻	輪 壓 機	
輪 轂	輪 轉	輪 轉 計	輪 轉 機	輪 箍	輜 重	輥 子	輥 軸	
適 口	適 才	適 中	適 切	適 以 相 成	適 可	適 可 而 止	適 用	
適 用 技 術	適 用 性	適 用 於	適 用 範 圍	適 任	適 合	適 合 於	適 足	
適 宜	適 宜 性	適 宜 於	適 於	適 者 生 存	適 度	適 食 性	適 值	
適 時	適 航	適 航 性	適 配	適 配 器	適 婚	適 得	適 得 其 反	
適 從	適 逢	適 逢 其 會	適 量	適 意	適 感	適 當	適 當 性	
適 銷	適 銷 對 路	適 衡	適 應	適 應 力	適 應 性	適 應 者	適 應 症	
適 應 能 力	適 齡	適 體	遮 人 耳 目	遮 天	遮 天 映 日	遮 天 蓋 地	遮 天 蔽 日	
遮 日	遮 日 篷	遮 以	遮 光	遮 光 物	遮 住	遮 沒	遮 泥 板	
遮 門	遮 雨	遮 前 掩 後	遮 面	遮 風	遮 胸	遮 掩	遮 掉	
遮 眼	遮 羞	遮 羞 布	遮 閉	遮 陰	遮 陽	遮 陽 傘	遮 陽 帽	
遮 暗	遮 蓋	遮 障	遮 蔽	遮 蔽 所	遮 蔭	遮 遮	遮 擋	
遮 篷	遮 臉	遮 避	遮 醜	遮 斷	遮 斷 者	遮 藏	遮 簷	
遮 攔	遨 遊	遭 人	遭 以	遭 以 為	遭 劫	遭 災	遭 到	
遭 受	遭 侵 蝕	遭 殃	遭 致	遭 逢	遭 罪	遭 遇	遭 遇 到	
遭 遇 戰	遭 蹋	遭 難	遭 難 船	遷 入	遷 出	遷 地	遷 安	
遷 至	遷 西	遷 走	遷 到	遷 居	遷 延	遷 往	遷 客 騷 人	
遷 怒	遷 思 回 慮	遷 徙	遷 移	遷 移 者	遷 都	遷 喬 之 望	遷 就	
遷 棲	遷 善 改 過	遷 善 遠 罪	遷 離	鄰 人	鄰 水	鄰 村	鄰 角	
鄰 邦	鄰 里	鄰 里 鄉 黨	鄰 居	鄰 舍	鄰 近	鄰 省	鄰 家	
鄰 座	鄰 海	鄰 國	鄰 域	鄰 接	鄰 境	鄰 縣	鄰 邊	
鄭 人 爭 年	鄭 人 買 履	鄭 中 基	鄭 太 吉	鄭 伊 健	鄭 州	鄭 州 市	鄭 志 龍	
鄭 秀 文	鄭 邦 鎮	鄭 和	鄭 重	鄭 重 其 事	鄭 重 其 辭	鄭 景 益	鄭 進 一	
鄭 衛 之 曲	鄭 衛 之 音	鄭 衛 之 聲	鄭 衛 桑 間	鄧 小 平	鄧 安 寧	鄧 肯	鄧 麗 君	
鄧 婕	鄱 陽	醇 化	醇 和	醇 厚	醇 香	醇 酒	醇 酒 婦 人	
醇 酸	醇 類	醇 釀	醇 胺	醉 了	醉 人	醉 心	醉 生 夢 死	
醉 臥	醉 品	醉 後	醉 倒	醉 翁	醉 翁 之 意 不 在 酒	醉 酒	醉 酒 飽 德	
醉 鬼	醉 眼	醉 意	醉 感	醉 態	醉 漢	醉 舞 狂 歌	醉 醉	
醉 醺 醺	醋 化	醋 勁	醋 栗	醋 液	醋 瓶	醋 意	醋 精	
醋 酸	醋 酸 纖 維	醋 酸 鹽	醃 肉	醃 制	醃 泡 汁	醃 浸	醃 蛋	
醃 貨 商	醃 魚	醃 菜	醃 漬	醃 漬 品	醃 豬	醃 豬 肉	鋅 片	
鋅 白	鋅 皮	鋅 板	鋅 版	鋅 版 術	鋅 版 畫	鋅 肥	鋅 塊	
鋅 極	鋅 錠	鋅 鍍 鋅	鋅 礦	銻 化 物	銷 子	銷 出	銷 地	
銷 住	銷 往	銷 案	銷 釘	銷 假	銷 區	銷 售	銷 售 一 空	
銷 售 市 場	銷 售 者	銷 售 通 路	銷 售 部	銷 售 量	銷 售 價 格	銷 售 總 額	銷 售 額	
銷 帳	銷 貨	銷 給	銷 量	銷 毀	銷 號	銷 路	銷 路 好	
銷 蝕	銷 魂	銷 魂 奪 魄	銷 價	銷 賬	銷 聲 匿 跡	銷 聲 匿 影	銷 聲 斂 跡	
銷 贓	銬 子	銬 手 銬	銬 住	鋤 仔	鋤 田	鋤 奸	鋤 草	
鋤 強 扶 弱	鋤 掘	鋤 頭	鋁 土	鋁 土 礦	鋁 合 金	鋁 合 金 錠	鋁 冶 術	
鋁 材	鋁 制	鋁 板	鋁 盆	鋁 屑	鋁 粉	鋁 帶	鋁 處 理	
鋁 壺	鋁 棒	鋁 絲	鋁 管	鋁 箔	鋁 熱 劑	鋁 錠	鋁 鍋	
鋁 礦	鋁 礬 土	銳 不 可 當	銳 升	銳 未 可 當	銳 利	銳 志	銳 角	
銳 氣	銳 敏	銳 眼	銳 減	銳 勢	銳 意	銳 意 進 取	銳 增	
銳 齒	銳 器	銳 聲	銳 變	鋒 刃	鋒 口	鋒 利	鋒 芒	
鋒 芒 所 向	鋒 芒 畢 露	鋒 芒 逼 人	鋒 面	鋒 發 韻 流	鋒 鏑 餘 生	鋇 餐	鋇 礦	
閭 巷 草 野	閱 世	閱 本	閱 兵	閱 兵 式	閱 兵 場	閱 完	閱 卷	
閱 知	閱 書 架	閱 悉	閱 報	閱 歷	閱 覽	閱 覽 室	閱 覽 架	
閱 讀	閱 讀 教 學	閱 讀 輔 導	霄 漢	霄 壤 之 別	霄 壤 之 殊	震 中	震 天	
震 天 動 地	震 天 駭 地	震 古 鑠 今	震 旦 行	震 耳	震 耳 欲 聾	震 住	震 波	
震 波 圈	震 波 圖	震 垮	震 怒	震 音	震 級	震 動	震 動 性	
震 動 計	震 動 器	震 裂	震 搖	震 源	震 落	震 憾	震 撼	
震 撼 人 心	震 盪	震 懾	震 攝	震 聾	震 顫	震 驚	震 驚 中 外	
霉 天	霉 味	霉 雨	霉 香	霉 原	霉 氣	霉 病	霉 臭	
霉 乾 菜	霉 斑	霉 運	霉 頭	霉 爛	霉 變	靠 了	靠 人	
靠 山	靠 山 吃 山	靠 不 住	靠 天	靠 手	靠 水 吃 水	靠 右	靠 外	
靠 外 力	靠 左	靠 向	靠 吃	靠 在	靠 住	靠 你	靠 岸	
靠 的	靠 近	靠 後	靠 背	靠 哪	靠 海	靠 得 住	靠 處	
靠 椅	靠 著	靠 墊	靠 牆	靠 攏	靠 邊	靠 邊 兒 站	靠 邊 站	
鞍 上	鞍 子	鞍 山	鞍 形	鞍 那 勞 頓	鞍 狀	鞍 座	鞍 馬	
鞍 馬 勞 倦	鞍 馬 勞 神	鞍 部	鞍 鋼	鞍 鋼 憲 法	鞋 口	鞋 子	鞋 內	
鞋 內 底	鞋 匠	鞋 扣	鞋 刷	鞋 店	鞋 底	鞋 底 釘	鞋 拔	
鞋 油	鞋 後 跟	鞋 架	鞋 面	鞋 料	鞋 根	鞋 粉	鞋 釘	
鞋 帶	鞋 盒	鞋 帽	鞋 業	鞋 跟	鞋 墊	鞋 廠	鞋 樣	
鞋 幫	鞋 擦	鞋 類	鞋 襪	鞏 固	鞏 俐	鞏 留	鞏 義	
鞏 膜	鞏 縣	頜 骨	颳 風	颳 風 下 雨	養 人	養 上	養 大	
養 女	養 子	養 子 防 老 積 穀 防 饑	養 小 防 老 積 穀 防 饑	養 工 處	養 分	養 父	養 父 母	
養 牛	養 母	養 生	養 生 送 終	養 好	養 成	養 羊	養 老	
養 老 金	養 老 送 終	養 老 院	養 作	養 兵	養 兵 千 日 用 兵 一 時	養 兵 千 日 用 兵 一 朝	養 志	
養 育	養 育 者	養 育 院	養 身	養 身 之 道	養 兔 場	養 兒	養 兒 代 老 積 穀 防 饑	
養 兒 防 老	養 兒 防 老 積 穀 防 饑	養 兒 待 老 積 穀 防 饑	養 兒 備 老	養 法	養 肥	養 花	養 虎 自 嚙	
養 虎 留 患	養 虎 貽 患	養 虎 傷 身	養 虎 遺 患	養 威 蓄 銳	養 活	養 軍	養 軍 千 日 用 在 一 時	
養 軍 千 日 用 兵 一 時	養 家	養 家 糊 口	養 料	養 病	養 神	養 魚	養 魚 池	
養 魚 場	養 魚 塘	養 鳥	養 場	養 尊 處 優	養 殖	養 殖 面 積	養 殖 場	
養 殖 業	養 傷	養 媳	養 蜂	養 蜂 人	養 蜂 家	養 蜂 場	養 路	
養 路 工	養 路 費	養 馴	養 精 畜 銳	養 精 蓄 銳	養 豬	養 豬 人	養 豬 場	
養 豬 業	養 銳 蓄 威	養 養	養 憲 納 士	養 親	養 鴨	養 蟲 室	養 雞	
養 雞 場	養 護	養 蠶	養 蠶 所	養 鷹 者	養 癰 成 患	養 癰 自 患	養 癰 自 禍	
養 癰 致 患	養 癰 貽 害	養 癰 貽 患	養 癰 蓄 疽	養 癰 遺 患	餓 了	餓 死	餓 死 了	
餓 死 事 小 失 節 事 大	餓 虎 吞 羊	餓 虎 撲 食	餓 虎 擒 羊	餓 倒	餓 狼 之 口	餓 病	餓 鬼	
餓 得	餓 著	餓 極	餓 漢	餓 瘦	餓 壞	餓 殍	餓 殍 枕 藉	
餓 殍 相 望	餓 殍 載 道	餓 莩 載 道	餘 力	餘 下	餘 生	餘 光	餘 地	
餘 年	餘 利	餘 味	餘 波	餘 勇 可 賈	餘 威	餘 毒	餘 音	
餘 音 裊 裊	餘 音 繞 樑	餘 香	餘 悸	餘 款	餘 暉	餘 暇	餘 數	
餘 輝	餘 震	餘 興	餘 燼	餘 燼 復 燃	餘 糧	餘 額	餘 韻	
餘 韻 流 風	餘 孽	餘 黨	駝 毛	駝 色	駝 背	駝 背 人	駝 背 者	
駝 峰	駝 鳥	駝 絨	駐 屯	駐 外	駐 外 使 館	駐 地	駐 在	
駐 在 國	駐 守	駐 有	駐 兵	駐 足	駐 足 不 前	駐 防	駐 京	
駐 波	駐 軍	駐 留	駐 馬 店	駐 紮	駐 場	駐 華	駐 華 大 使	
駐 華 大 使 館	駐 華 使 節	駐 廠	駐 顏	駟 不 及 舌	駟 之 過 隙	駟 馬 高 車	駟 馬 難 追	
駛 入	駛 出	駛 去	駛 向	駛 回	駛 來	駛 往	駛 抵	
駛 近	駛 進	駛 過	駛 離	駑 馬 十 捨	駑 馬 十 駕	駑 馬 鉛 刀	駑 馬 戀 豆	
駑 馬 戀 棧	駕 車	駕 車 者	駕 到	駕 於	駕 凌	駕 崩	駕 御	
駕 船	駕 進	駕 馭	駕 照	駕 輕 就 熟	駕 駁	駕 駛	駕 駛 者	
駕 駛 室	駕 駛 員	駕 駛 盤	駕 駛 艙	駕 機	駕 臨	駕 霧 騰 雲	駒 齒 未 落	
駙 馬	骷 髏	髮 夾	髮 型	髮 香	髮 根	髮 廊	髮 結	
髮 絲	髮 飾 品	髮 髻	髮 簪	鬧 了	鬧 了 歸 齊	鬧 出	鬧 市	
鬧 市 區	鬧 成	鬧 災	鬧 事	鬧 事 者	鬧 房	鬧 玩	鬧 者	
鬧 個	鬧 宴	鬧 病	鬧 笑 話	鬧 荒	鬧 酒	鬧 鬼	鬧 區	
鬧 得	鬧 情 緒	鬧 脾 氣	鬧 著	鬧 飲	鬧 亂	鬧 亂 子	鬧 意 見	
鬧 鈴	鬧 彆 扭	鬧 劇	鬧 熱	鬧 鬧	鬧 噶	鬧 獨 立 性	鬧 聲	
鬧 翻	鬧 鐘	鬧 騰	魅 力	魅 惑	魅 惑 者	魄 力	魄 散	
魄 散 魂 飛	魷 魚	魯 人	魯 迅	魯 迅 研 究	魯 班	魯 國	魯 莽	
魯 莽 滅 裂	魯 魚 亥 豕	魯 魚 帝 虎	魯 鈍	魯 鈍 者	魯 殿 靈 光	魯 道 夫	魯 語	
魯 濱 孫	鴉 片	鴉 片 劑	鴉 片 戰 爭	鴉 飛 雀 亂	鴉 飛 鵲 亂	鴉 雀	鴉 雀 無 聞	
鴉 雀 無 聲	鴉 默 雀 靜	麩 子	麩 皮	麩 質 狀	麾 下	黎 川	黎 巴 嫩	
黎 民	黎 民 百 姓	黎 明	黎 明 前	黎 族	墨 子	墨 斗	墨 斗 魚	
墨 水	墨 水 台	墨 水 池	墨 水 瓶	墨 水 壺	墨 台	墨 汁	墨 汁 未 干	
墨 玉	墨 石	墨 守	墨 守 成 規	墨 守 陳 規	墨 竹 工 卡	墨 色	墨 西 哥	
墨 西 哥 城	墨 具	墨 客	墨 家	墨 海	墨 粉	墨 盒	墨 脫	
墨 魚	墨 晶	墨 畫	墨 筆	墨 菊	墨 黑	墨 跡	墨 跡 未 乾	
墨 漬	墨 爾 本	墨 綠	墨 綠 色	墨 線	墨 鏡	墨 寶	齒 亡 舌 存	
齒 孔	齒 牙 余 論	齒 牙 為 猾	齒 牙 為 禍	齒 列	齒 印	齒 危 發 秀	齒 如 含 貝	
齒 如 齊 貝	齒 式	齒 形	齒 板	齒 狀	齒 狀 物	齒 科 學	齒 若 編 貝	
齒 音	齒 根	齒 敝 舌 存	齒 條	齒 痕	齒 腔	齒 軸	齒 槽	
齒 質	齒 輪	齒 豁 頭 童	齒 邊	齒 類	齒 齦	齒 髓	齒 齲 炎	
儒 生	儒 林	儒 者	儒 家	儒 家 思 想	儒 將	儒 教	儒 術	
儒 雅	儒 道	儒 墨	儒 學	儒 醫	儘 先	儘 夠	儘 管	
儘 管 如 此	冀 中	冀 求	冀 東	冀 南	冀 望	冀 縣	冪 值	
凝 成	凝 成 塊	凝 灰 巖	凝 血	凝 血 素	凝 乳	凝 固	凝 固 點	
凝 思	凝 為	凝 重	凝 凍	凝 神	凝 脂	凝 望	凝 眸	
凝 結	凝 結 水	凝 結 物	凝 結 劑	凝 結 器	凝 視	凝 視 者	凝 集	
凝 集 素	凝 塊	凝 想	凝 滯	凝 聚	凝 聚 力	凝 聚 劑	凝 練	
凝 膠	凝 膠 化	凝 膠 物	凝 膠 狀	凝 膠 體	凝 縮	凝 縮 器	劑 型	
劑 量	劑 量 監 督	劑 量 學	勳 位	勳 章	勳 爵	勳 績	噹 噹	
噹 啷	噩 耗	噩 夢	噩 噩	噤 若 寒 蟬	噸 公 里	噸 位	噸 級	
噸 數	噪 音	噪 聲	器 小 易 盈	器 皿	器 件	器 宇 軒 昂	器 材	
器 具	器 官	器 物	器 重	器 械	器 量 小	器 鼠 難 投	器 樂	
器 質 性	噱 頭	噬 咬	噬 食	噬 細 胞	噬 菌	噬 菌 體	噬 臍 何 及	
噬 臍 莫 及	噬 臍 無 及	壁 上	壁 上 觀	壁 立	壁 立 千 仞	壁 板	壁 虎	
壁 柱	壁 扇	壁 紙	壁 掛	壁 報	壁 毯	壁 畫	壁 燈	
壁 磚	壁 壘	壁 壘 森 嚴	壁 櫃	壁 櫥	壁 爐	壁 龕	墾 利	
墾 拓	墾 荒	墾 區	墾 復	墾 殖	壇 木	壇 而 不 化	壇 壇 罐 罐	
奮 力	奮 力 拚 搏	奮 力 衝 刺	奮 不 顧 生	奮 不 顧 身	奮 身	奮 身 獨 步	奮 迅	
奮 武 揚 威	奮 勇	奮 勇 當 先	奮 勉	奮 袂 而 起	奮 袂 攘 襟	奮 起	奮 起 反 抗	
奮 起 自 衛	奮 起 抗 爭	奮 起 直 追	奮 鬥	奮 鬥 不 息	奮 鬥 目 標	奮 鬥 到 底	奮 鬥 者	
奮 發	奮 發 向 上	奮 發 有 為	奮 發 圖 強	奮 發 蹈 厲	奮 筆	奮 筆 疾 書	奮 進	
奮 戰	學 了	學 人	學 力	學 士	學 子	學 工	學 之	
學 分	學 分 制	學 友	學 以 致 用	學 史	學 生	學 生 界	學 生 族	
學 生 組 織	學 生 會	學 生 運 動	學 生 證	學 用	學 用 一 致	學 甲 鎮	學 先 進	
學 名	學 好	學 年	學 成	學 成 回 國	學 成 歸 國	學 有	學 有 所 用	
學 有 所 成	學 有 所 長	學 而	學 而 不 厭	學 而 優 則 仕	學 自	學 舌	學 位	
學 作	學 呀	學 步	學 步 邯 鄲	學 究	學 究 天 人	學 究 式	學 究 氣	
學 走	學 車	學 來	學 到	學 制	學 府	學 所	學 法	
學 的	學 社	學 者	學 長	學 非 所 用	學 前	學 前 教 育	學 派	
學 界	學 科	學 科 分 類	學 科 知 識	學 苑	學 軍	學 風	學 修	
學 員	學 家	學 徒	學 徒 工	學 時	學 校	學 校 行 政	學 校 教 育	
學 校 間	學 校 裡	學 氣	學 海	學 起	學 院	學 院 派	學 院 間	
學 區	學 問	學 堂	學 得	學 捨	學 淺 才 疏	學 理	學 理 上	
學 疏 才 淺	學 習	學 習 方 法	學 習 材 料	學 習 者	學 習 計 劃	學 習 班	學 習 體 會	
學 術	學 術 上	學 術 交 流	學 術 年 會	學 術 性	學 術 思 想	學 術 界	學 術 研 究	
學 術 研 討 會	學 術 討 論 會	學 術 報 告	學 術 會 議	學 術 團 體	學 術 網 路	學 術 論 文	學 術 觀 點	
學 貫 天 人	學 部	學 部 委 員	學 報	學 富 五 車	學 期	學 無 止 境	學 無 常 師	
學 童	學 著	學 費	學 會	學 業	學 業 有 成	學 號	學 話	
學 運	學 過	學 雷 鋒	學 監	學 語	學 說	學 銜	學 閥	
學 際 天 人	學 潮	學 學	學 歷	學 優 才 贍	學 優 而 仕	學 聯	學 藉	
學 雜	學 雜 費	學 壞	學 藝	學 識	學 識 上	學 籍	學 齡	
學 齡 兒 童	學 齡 前	學 齡 前 兒 童	寰 宇	寰 球	導 入	導 引	導 水 管	
導 火	導 火 索	導 火 線	導 出	導 向	導 尿	導 尿 管	導 言	
導 板	導 流	導 致	導 軌	導 師	導 納	導 航	導 航 雷 達	
導 通	導 報	導 揚	導 源	導 溝	導 遊	導 電	導 電 性	
導 演	導 磁	導 磁 率	導 管	導 管 素	導 彈	導 彈 旅	導 彈 艇	
導 彈 戰	導 德 齊 禮	導 播	導 數	導 標	導 熱	導 線	導 線 架	
導 論	導 輪	導 醫	導 體	憲 兵	憲 制	憲 法	憲 法 規 定	
憲 法 學	憲 政	憲 章	憲 綱	憑 之	憑 手 畫	憑 以	憑 仗	
憑 白	憑 吊	憑 此	憑 依	憑 券	憑 河 暴 虎	憑 空	憑 空 捏 造	
憑 信	憑 恃	憑 柬	憑 借	憑 原	憑 記 憶	憑 眺	憑 票	
憑 票 供 應	憑 陵	憑 單	憑 著	憑 照	憑 經 驗	憑 靠	憑 據	
憑 險	憑 藉	憑 證	憑 欄	憩 兒	憩 息	憩 場	憶 及	
憶 法	憶 苦 思 甜	憶 述	憶 起	憶 聲 電 子	憶 舊	憾 事	憾 恨	
懊 恨	懊 悔	懊 喪	懊 惱	懈 怠	戰 刀	戰 士	戰 不 旋 踵	
戰 友	戰 天 斗 地	戰 火	戰 功	戰 史	戰 台	戰 犯	戰 列 艦	
戰 地	戰 死	戰 利 品	戰 局	戰 役	戰 抖	戰 車	戰 事	
戰 例	戰 斧	戰 果	戰 法	戰 況	戰 爭	戰 爭 年 代	戰 爭 狀 態	
戰 爭 初 期	戰 爭 追 賠	戰 爭 販 子	戰 爭 罪 犯	戰 爭 賠 償	戰 者	戰 表	戰 門 性	
戰 門 機	戰 俘	戰 前	戰 後	戰 時	戰 書	戰 神	戰 訊	
戰 馬	戰 鬥	戰 鬥 力	戰 鬥 分 隊	戰 鬥 化	戰 鬥 支 援	戰 鬥 出 動	戰 鬥 任 務	
戰 鬥 序 列	戰 鬥 性	戰 鬥 性 能	戰 鬥 者	戰 鬥 保 障	戰 鬥 指 揮	戰 鬥 活 動	戰 鬥 英 雄	
戰 鬥 原 則	戰 鬥 偵 察	戰 鬥 教 令	戰 鬥 條 令	戰 鬥 部 隊	戰 鬥 隊 形	戰 鬥 概 則	戰 鬥 準 備	
戰 鬥 詳 報	戰 鬥 運 用	戰 鬥 機	戰 鬥 艦 艇	戰 區	戰 國	戰 國 時 代	戰 將	
戰 敗	戰 略	戰 略 上	戰 略 方 針	戰 略 目 標	戰 略 地 位	戰 略 決 策	戰 略 性	
戰 略 武 器	戰 略 物 資	戰 略 要 地	戰 略 重 點	戰 略 家	戰 略 部 署	戰 略 戰 術	戰 略 轉 移	
戰 船	戰 術	戰 術 上	戰 術 家	戰 術 導 彈	戰 袍	戰 備	戰 備 值 班	
戰 備 訓 練	戰 備 動 員	戰 備 等 級	戰 勝	戰 勝 者	戰 場	戰 場 形 勢	戰 報	
戰 無 不 克	戰 無 不 勝	戰 評	戰 雲	戰 亂	戰 慄	戰 鼓	戰 幕	
戰 旗	戰 歌	戰 禍	戰 線	戰 戰 慄 栗	戰 戰 兢 兢	戰 機	戰 壕	
戰 績	戰 艦	擅 入	擅 用	擅 自	擅 作	擅 作 威 福	擅 改	
擅 取	擅 定	擅 於	擅 長	擅 離	擅 權	擁 入	擁 王	
擁 立	擁 有	擁 兵	擁 兵 自 固	擁 兵 玩 寇	擁 吻	擁 抱	擁 抱 者	
擁 政 愛 民	擁 政 愛 民 運 動	擁 軍	擁 軍 愛 民	擁 軍 優 屬	擁 彗 先 驅	擁 彗 迎 門	擁 彗 清 道	
擁 登	擁 著	擁 塞	擁 戴	擁 擠	擁 擠 不 堪	擁 霧 翻 波	擁 護	
擁 護 者	擋 水	擋 在	擋 住	擋 車	擋 板	擋 泥	擋 泥 板	
擋 雨	擋 風	擋 風 板	擋 案 庫	擋 眼	擋 開	擋 路	擋 道	
擋 層	擋 箭 牌	擋 駕	擋 擋	擋 錢	擋 牆	撻 伐	撼 人	
撼 山 拔 樹	撼 天 動 地	撼 天 震 地	撼 地 搖 天	撼 動	撼 樹 蚍 蚨	據 不 完 全 統 計	據 介 紹	
據 分 析	據 外 電 報 道	據 守	據 有	據 有 關 人 士 透 露	據 有 關 部 門 統 計	據 此	據 估	
據 估 計	據 我 所 知	據 典	據 知	據 初 步 統 計	據 信	據 查	據 為	
據 為 己 有	據 從	據 悉	據 理	據 理 力 爭	據 統 計	據 報	據 報 道	
據 報 導	據 測	據 測 定	據 傳	據 傳 聞	據 義 履 方	據 載	據 道	
據 預 測	據 實	據 稱	據 聞	據 說	據 調 查	據 瞭 解	據 點	
擄 人	擄 人 勒 贖	擄 掠	擄 袖 揎 拳	擄 奪	擄 獲	擇 一	擇 人 而 事	
擇 友	擇 引	擇 日	擇 木 而 處	擇 主 而 事	擇 交	擇 交 而 友	擇 向	
擇 地 而 蹈	擇 言	擇 性	擇 物	擇 肥 而 噬	擇 度	擇 要	擇 偶	
擇 善	擇 善 而 行	擇 善 而 從	擇 菜	擇 福 宜 重	擇 優	擇 優 上 崗	擇 優 選 用	
擇 優 錄 用	擇 優 錄 取	擇 譯	擂 天 倒 地	擂 台	擂 台 賽	擂 缽	擂 鼓	
擂 鼓 鳴 金	擂 鼓 篩 鑼	操 刀	操 之	操 之 過 急	操 切	操 心	操 戈	
操 戈 入 室	操 守	操 守 無 暇	操 行	操 作	操 作 上	操 作 台	操 作 步 驟	
操 作 系 統	操 作 性	操 作 者	操 作 員	操 作 規 程	操 作 說 明	操 作 器	操 斧 伐 柯	
操 持	操 神	操 控	操 勞	操 勞 過 度	操 場	操 游	操 琴	
操 隊	操 槍	操 演	操 練	操 翰 成 章	操 辦	操 縱	操 縱 自 如	
操 縱 者	操 縱 桿	操 縱 箱	操 觚 染 翰	撿 了	撿 來	撿 到	撿 的	
撿 拾	撿 破 爛	撿 起	撿 著	撿 開	擒 奸 討 暴	擒 住	擒 虎 拿 蛟	
擒 拿	擒 捉	擒 賊	擒 賊 先 擒 王	擒 賊 擒 王	擒 龍 縛 虎	擒 獲	擒 縱	
擔 子	擔 心	擔 水	擔 任	擔 承	擔 保	擔 保 人	擔 待	
擔 架	擔 架 式	擔 負	擔 風 險	擔 責 任	擔 雪 塞 井	擔 雪 填 井	擔 雪 填 河	
擔 著	擔 著 心	擔 當	擔 當 者	擔 運	擔 誤	擔 憂	擔 驚	
擔 驚 受 怕	擔 驚 受 恐	整 人	整 天	整 日	整 月	整 片	整 付	
整 出	整 句	整 件	整 份	整 列	整 合	整 地	整 字	
整 存	整 年	整 式	整 色 性	整 行	整 衣	整 衣 斂 容	整 形	
整 形 術	整 把	整 批	整 改	整 步	整 車	整 取	整 夜	
整 夜 間	整 枝	整 治	整 型	整 垮	整 段	整 流	整 流 子	
整 流 管	整 流 器	整 軍	整 軍 經 武	整 頁	整 風	整 風 運 動	整 個	
整 修	整 修 者	整 套	整 容	整 捆	整 躬 率 物	整 除	整 桶	
整 理	整 部	整 備	整 幅	整 肅	整 隊	整 飭	整 塊	
整 裝	整 裝 待 發	整 頓	整 頓 者	整 頓 秩 序	整 頓 經 濟 秩 序	整 團	整 齊	
整 齊 有 序	整 數	整 潔	整 盤	整 箱	整 篇	整 編	整 整	
整 整 一 年	整 整 齊 齊	整 機	整 舊 如 新	整 襟 威 坐	整 黨	整 黨 工 作	整 體	
整 體 防 護	整 體 效 益	整 體 優 勢	整 體 觀 念	整 摞	曆 法	曉 之 以 理	曉 以 大 義	
曉 示	曉 色	曉 行 夜 宿	曉 事	曉 英	曉 風 殘 月	曉 得	曉 暢	
曉 諭	曉 霧	曇 花	曇 花 一 現	樸 拙	樸 直	樸 厚	樸 陋	
樸 素	樸 素 大 方	樸 素 唯 物 主 義	樸 素 無 華	樸 訥 誠 篤	樸 實	樸 實 無 華	樸 質	
樸 樹	樺 木	樺 林	樺 樹	橙 子	橙 汁	橙 色	橙 紅	
橙 紅 色	橙 帶	橙 黃	橙 樹	橙 蘭	橫 七 豎 八	橫 刀	橫 三 豎 四	
橫 山 鄉	橫 切 麵	橫 心	橫 木	橫 比	橫 加	橫 加 干 涉	橫 生	
橫 生 枝 節	橫 亙	橫 列	橫 向	橫 向 發 展	橫 向 經 濟 聯 合	橫 向 聯 合	橫 在	
橫 帆 船	橫 死	橫 肉	橫 行	橫 行 天 下	橫 行 直 撞	橫 行 無 忌	橫 行 霸 道	
橫 坐 標	橫 批	橫 步	橫 災 飛 禍	橫 系	橫 征 暴 斂	橫 披	橫 拖 倒 拽	
橫 放	橫 放 物	橫 波	橫 直	橫 空	橫 臥	橫 挑 鼻 子 豎 挑 眼	橫 是	
橫 殃 飛 禍	橫 流	橫 眉	橫 眉 冷 對	橫 眉 怒 目	橫 科 暴 斂	橫 穿	橫 面	
橫 飛	橫 倒 豎 歪	橫 剖	橫 剖 面	橫 峰	橫 座 標	橫 紋	橫 草 之 功	
橫 財	橫 側	橫 匾	橫 掃	橫 掃 千 軍	橫 排	橫 斜	橫 桿	
橫 條	橫 笛	橫 貫	橫 造	橫 幅	橫 渡	橫 渡 海 峽	橫 結	
橫 著	橫 街	橫 越	橫 軸	橫 隊	橫 須	橫 溢	橫 粱	
橫 跨	橫 道	橫 過	橫 隔 膜	橫 槓	橫 禍	橫 禍 非 災	橫 禍 飛 災	
橫 綱	橫 膈 膜	橫 寬	橫 寫	橫 樑	橫 線	橫 衝 直 撞	橫 豎	
橫 賦 暴 斂	橫 躺	橫 躺 豎 臥	橫 遭	橫 擊	橫 檔	橫 濱	橫 斷	
橫 斷 面	橫 檳	橫 欄	橫 體	橫 蠻	橫 槊 賦 詩	橘 子	橘 柑	
橘 紅	橘 紅 色	橘 黃	橘 黃 色	橘 園	橘 類	樹 人	樹 上	
樹 大 招 風	樹 大 根 深	樹 孔	樹 心	樹 木	樹 木 狀	樹 木 學	樹 汁	
樹 汁 多	樹 皮	樹 皮 布	樹 穴	樹 立	樹 枝	樹 林	樹 林 市	
樹 狀	樹 狀 物	樹 冠	樹 洞	樹 突	樹 苗	樹 倒	樹 倒 猢 猻 散	
樹 根	樹 脂	樹 脂 般	樹 脂 酚	樹 高 千 丈 落 葉 歸 根	樹 高 招 風	樹 帶	樹 掛	
樹 梢	樹 欲 息 而 風 不 停	樹 欲 靜 而 風 不 止	樹 欲 靜 而 風 不 寧	樹 液	樹 陰	樹 猶 如 此 人 何 以 堪	樹 稍	
樹 結	樹 幹	樹 碑	樹 碑 立 傳	樹 節	樹 節 點	樹 葉	樹 蜂	
樹 熊	樹 種	樹 墩	樹 影	樹 德 務 滋	樹 敵	樹 樁	樹 膠	
樹 膠 質	樹 蔭	樹 蔭 處	樹 輪	樹 薯 粉	樹 叢	樹 杈	橄 欖	
橄 欖 石	橄 欖 色	橄 欖 形	橄 欖 油	橄 欖 球	橄 欖 綠	橄 欖 樹	橢 球	
橢 園	橢 圓	橢 圓 形	橢 圓 體	橡 木	橡 木 製	橡 皮	橡 皮 泥	
橡 皮 船	橡 皮 筋	橡 皮 艇	橡 皮 圖 章	橡 皮 膏	橡 皮 糖	橡 皮 擦	橡 飯 菁 羹	
橡 漿	橡 膠	橡 膠 布	橡 膠 股	橡 膠 鞋	橡 膠 樹	橡 樹	橋 下	
橋 上	橋 孔	橋 台	橋 形	橋 身	橋 那 邊	橋 架	橋 洞	
橋 面	橋 接 器	橋 涵	橋 牌	橋 軸	橋 塔	橋 粱	橋 墩	
橋 樁	橋 樑	橋 頭	橋 頭 堡	橋 頭 鄉	橋 欄	橋 礅	橇 棍	
樵 夫	機 下	機 上	機 子	機 工	機 不 可 失	機 不 可 失 失 不 再 來	機 不 旋 踵	
機 中	機 井	機 內	機 台	機 件	機 名	機 帆 船	機 米	
機 床	機 身	機 車	機 事 不 密	機 具	機 制	機 坪	機 宜	
機 房	機 油	機 芯	機 長	機 前	機 型	機 架	機 要	
機 要 文 件	機 降	機 首	機 修	機 修 工	機 修 廠	機 倉	機 員	
機 師	機 庫	機 座	機 時	機 耕	機 耕 船	機 能	機 務	
機 務 段	機 動	機 動 力	機 動 化	機 動 式	機 動 車	機 動 車 輛	機 動 防 禦	
機 動 性	機 動 保 障	機 動 船	機 密	機 敏	機 械	機 械 士	機 械 工 程	
機 械 工 業	機 械 化	機 械 化 軍	機 械 手	機 械 性 能	機 械 油	機 械 師	機 械 能	
機 械 唯 物 主 義	機 械 設 備	機 械 傳 動	機 械 運 動	機 械 電 子 工 業 部	機 械 製 造	機 械 廠	機 械 論	
機 械 學	機 率	機 理	機 票	機 組	機 組 人 員	機 場	機 智	
機 殼	機 會	機 會 主 義	機 會 均 等	機 罩	機 群	機 腹	機 載	
機 載 設 備	機 載 雷 達	機 遇	機 電	機 電 股	機 電 部	機 電 業	機 構	
機 構 改 革	機 構 調 整	機 槍	機 槍 手	機 種	機 箱	機 緣	機 輪	
機 器	機 器 人	機 器 制	機 器 般	機 器 翻 譯	機 艙	機 謀	機 頭	
機 翼	機 櫃	機 織	機 繡	機 關	機 關 作 風	機 關 炮	機 關 報	
機 關 幹 部	機 關 福 利 社	機 關 鎗	機 關 黨 委	機 警	機 譯	機 灌	機 變 如 神	
機 體	機 靈	機 埸	歙 人	歙 漆 阿 膠	歷 久	歷 日 曠 久	歷 代	
歷 史	歷 史 上	歷 史 文 物	歷 史 性	歷 史 家	歷 史 唯 心 主 義	歷 史 唯 物 主 義	歷 史 條 件 下	
歷 史 學	歷 史 觀	歷 任	歷 年	歷 次	歷 來	歷 屆	歷 時	
歷 書	歷 朝	歷 程	歷 象	歷 經	歷 經 滄 桑	歷 經 磨 難	歷 盡	
歷 數	歷 練 老 成	歷 歷	歷 歷 可 見	歷 歷 可 數	歷 歷 可 辨	歷 歷 在 目	歷 歷 如 繪	
歷 歷 落 落	歷 險	氅 衣	澱 粉	澱 粉 □	澱 粉 質	澱 積	澡 池	
澡 身 浴 德	澡 房	澡 盆	澡 堂	澡 堂 子	澡 票	澡 塘	澡 類 學	
濃 汁	濃 妝	濃 妝 淡 抹	濃 妝 艷 抹	濃 妝 艷 服	濃 妝 艷 裹	濃 妝 艷 質	濃 抹 淡 妝	
濃 的	濃 厚	濃 厚 興 趣	濃 度	濃 眉	濃 郁	濃 重	濃 香	
濃 桃 艷 李	濃 烈	濃 茶	濃 酒	濃 密	濃 情	濃 液	濃 淡	
濃 湯	濃 粥	濃 粥 狀	濃 雲	濃 煙	濃 裝	濃 綠	濃 蔭	
濃 墨	濃 濃	濃 積 雲	濃 縮	濃 縮 物	濃 縮 鈾	濃 霧	濃 艷	
澤 及 枯 骨	澤 地	澤 面	澤 國	澤 深 恩 重	濁 世	濁 度	濁 流	
濁 音	濁 氣	濁 浪	濁 涇 清 渭	濁 酒	濁 骨 凡 胎	濁 液	濁 質 凡 姿	
澳 大 利 亞	澳 門	澳 門 特 區	澳 門 幣	澳 洲	澳 洲 人	澳 洲 公 開 賽	澳 紐	
激 切	激 化	激 打	激 光	激 光 印 字 機	激 光 照 排	激 光 器	激 忿 填 膺	
激 性	激 昂	激 昂 慷 慨	激 波	激 怒	激 流	激 流 勇 退	激 活	
激 射	激 浪	激 烈	激 烈 化	激 素	激 起	激 動	激 動 人 心	
激 動 不 安	激 將	激 將 法	激 情	激 貪 厲 俗	激 惱	激 揚	激 發	
激 發 態	激 越	激 進	激 進 分 子	激 進 派	激 進 論	激 磁	激 增	
激 憤	激 論	激 奮	激 戰	激 濁 揚 清	激 勵	激 勵 機 制	激 盪	
激 辯	激 變	澹 泊 明 志	澹 泊 寡 慾	熾 烈	熾 盛	熾 熱	燉 肉	
燉 魚	燉 湯	燉 煮	燉 菜	燉 熟	燉 鍋	燉 爛	燒 叉 肉	
燒 干	燒 不 盡	燒 毛	燒 水	燒 水 壺	燒 火	燒 用	燒 光	
燒 成	燒 成 灰	燒 成 炭	燒 死	燒 肉	燒 完	燒 灼	燒 制	
燒 杯	燒 油	燒 屋	燒 炭	燒 眉 之 急	燒 香	燒 烤	燒 紙	
燒 茶	燒 起 來	燒 酒	燒 得	燒 掉	燒 瓶	燒 瓷	燒 魚	
燒 焦	燒 煮	燒 結	燒 著	燒 菜	燒 進	燒 開	燒 開 水	
燒 飯	燒 黑	燒 傷	燒 煤	燒 過	燒 盡	燒 蝕	燒 蝕 體	
燒 餅	燒 熟	燒 熱	燒 窯	燒 豬	燒 賣	燒 燒	燒 磚	
燒 燬	燒 鍋	燒 斷	燒 雞	燒 壞	燒 臘	燒 爐	燒 鹼	
燈 中	燈 夫	燈 心	燈 心 絨	燈 火	燈 火 通 明	燈 火 萬 家	燈 火 輝 煌	
燈 片	燈 台	燈 台 不 自 照	燈 市	燈 光	燈 灰	燈 具	燈 油	
燈 泡	燈 芯	燈 柱	燈 架	燈 紅 酒 綠	燈 座	燈 桿	燈 絲	
燈 塔	燈 會	燈 盞	燈 節	燈 罩	燈 蛾	燈 蛾 撲 火	燈 管	
燈 墜	燈 影	燈 標	燈 蕊	燈 頭	燈 謎	燈 籠	燈 籠 庫	
燈 籠 褲	燕 子	燕 山	燕 北	燕 安 鴆 毒	燕 妒 鶯 慚	燕 尾	燕 尾 狀	
燕 尾 旗	燕 足 系 詩	燕 京	燕 兒	燕 侶 鶯 儔	燕 約 鶯 期	燕 啄 皇 孫	燕 婉 之 歡	
燕 巢	燕 巢 於 幕	燕 雀	燕 雀 相 賀	燕 雀 處 屋	燕 雀 處 堂	燕 麥	燕 麥 片	
燕 粥	燕 雁 代 飛	燕 爾 新 婚	燕 窩	燕 舞	燕 舞 鶯 啼	燕 語	燕 語 鶯 呼	
燕 語 鶯 啼	燕 語 鶯 聲	燕 瘦 環 肥	燕 儔 鶯 侶	燕 頷 虎 頸	燕 頷 虎 頭	燕 頷 虎 鬚	燎 原	
燎 原 之 火	燙 了	燙 手	燙 平	燙 死	燙 衣	燙 衣 服	燙 金	
燙 洗	燙 面	燙 酒	燙 得	燙 傷	燙 髮	燜 飯	燜 燒	
燃 木	燃 用 價 值	燃 放	燃 松 讀 書	燃 油	燃 物	燃 眉	燃 眉 之 急	
燃 料	燃 料 使 用 費	燃 料 庫	燃 料 稅	燃 料 艙	燃 氣 輪 機	燃 素	燃 起	
燃 犀 溫 嶠	燃 著	燃 煤	燃 膏 繼 晷	燃 燒	燃 燒 武 器	燃 燒 室	燃 燒 著	
燃 燒 彈	燃 燒 器	燃 糠 自 照	燃 點	獨 一 無 二	獨 力	獨 子	獨 山	
獨 夫	獨 夫 民 賊	獨 木 不 成 林	獨 木 不 林	獨 木 舟	獨 木 橋	獨 木 難 支	獨 出 心 裁	
獨 生 女	獨 生 子	獨 生 子 女	獨 白	獨 白 者	獨 立	獨 立 不 群	獨 立 王 國	
獨 立 市	獨 立 自 主	獨 立 性	獨 立 者	獨 立 核 算	獨 立 國	獨 守 空 房	獨 有	
獨 此 一 家 別 無 分 號	獨 自	獨 自 一 人	獨 行	獨 行 其 是	獨 行 其 道	獨 行 俠	獨 行 獨 斷	
獨 佔	獨 佔 者	獨 佔 鰲 頭	獨 吞	獨 坐	獨 步	獨 角 戲	獨 身	
獨 身 主 義	獨 身 者	獨 享	獨 來 獨 往	獨 具	獨 具 一 格	獨 具 匠 心	獨 到	
獨 到 之 處	獨 居	獨 往	獨 往 獨 來	獨 門 獨 戶	獨 奏	獨 奏 曲	獨 奏 者	
獨 奏 會	獨 苗	獨 個	獨 個 兒	獨 家	獨 家 生 產	獨 家 經 營	獨 桅	
獨 桅 艇	獨 特	獨 缺	獨 唱	獨 唱 會	獨 得	獨 眼	獨 處	
獨 創	獨 創 力	獨 創 性	獨 善 其 身	獨 裁	獨 裁 官	獨 裁 者	獨 裁 政 府	
獨 裁 政 治	獨 裁 統 治	獨 裁 權	獨 飲	獨 塊	獨 當 一 面	獨 腳	獨 腳 架	
獨 腳 戲	獨 資	獨 資 企 業	獨 幕	獨 幕 劇	獨 腿	獨 語 者	獨 領 風 騷	
獨 輪	獨 輪 車	獨 學 寡 聞	獨 擅 勝 場	獨 樹 一 幟	獨 獨	獨 龍	獨 聯 體	
獨 斷	獨 斷 家	獨 斷 專 行	獨 斷 獨 行	獨 贏	獨 闢 蹊 徑	獨 霸	獨 霸 一 方	
獨 攬	璞 玉 渾 金	瓢 兒	瓢 葫 蘋	瓢 潑 大 雨	瓢 潑 瓦 灌	瓢 蟲	瘴 氣	
瘸 子	瘸 行	瘸 腿	盧 比	盧 布	盧 安 達	盧 貝 松	盧 旺 達	
盧 浮 宮	盧 梭	盧 森 堡	盧 森 堡 人	盧 森 堡 市	盧 溝 橋	盧 詩 清	盧 灣	
盥 耳 山 棲	盥 洗	盥 洗 台	盥 洗 用 具	盥 洗 室	盥 漱	盥 踵 滅 頂	瞠 目	
瞠 目 而 視	瞠 目 結 舌	瞠 呼 其 後	瞞 人	瞞 上 不 瞞 下	瞞 上 欺 下	瞞 天 昧 地	瞞 天 席 地	
瞞 天 過 海	瞞 心 昧 己	瞞 哄	瞞 神 唬 鬼	瞞 神 嚇 鬼	瞞 混	瞞 報	瞞 著	
瞞 過	瞞 騙	瞟 一 眼	瞟 見	瞥 見	瞥 然	瞥 視	磨 人	
磨 刀	磨 刀 石	磨 刀 霍 霍	磨 子	磨 工	磨 片	磨 牙	磨 出	
磨 去	磨 平	磨 石	磨 光	磨 光 器	磨 合	磨 成	磨 成 粉	
磨 而 不 磷	磨 舌 頭	磨 坊	磨 坊 主	磨 床	磨 快	磨 谷 物	磨 豆 腐	
磨 具	磨 性	磨 杵 成 針	磨 亮	磨 削	磨 洋 工	磨 盾 之 暇	磨 研	
磨 穿	磨 穿 鐵 硯	磨 拳 擦 掌	磨 料	磨 破	磨 粉	磨 粉 廠	磨 粉 機	
磨 耗	磨 掉	磨 細	磨 頂 至 踵	磨 揉 遷 革	磨 傷	磨 損	磨 損 了	
磨 損 性	磨 滅	磨 煉	磨 碎	磨 碎 機	磨 過	磨 槍	磨 厲 以 須	
磨 嘴 皮	磨 盤	磨 練	磨 磨 蹭 蹭	磨 磚 對 縫	磨 擦	磨 擦 聲	磨 難	
磨 礪	磨 礪 以 須	磨 蹭	磨 礱 砥 礪	磚 工	磚 瓦	磚 石	磚 石 工	
磚 匠	磚 色	磚 房	磚 面	磚 茶	磚 窖	磚 塊	磚 廠	
磚 模	磚 窯	磚 壁	磚 頭	磚 牆	磚 坯	禦 侮	禦 敵	
積 久	積 土 成 山	積 小 成 大	積 不 相 能	積 分	積 分 電 路	積 分 榜	積 少 成 多	
積 木	積 欠	積 水	積 水 成 淵	積 玉 堆 金	積 甲 山 齊	積 冰	積 存	
積 年	積 年 累 月	積 灰	積 羽 成 舟	積 羽 沉 舟	積 卷 雲	積 肥	積 金 累 玉	
積 雨 雲	積 非 成 是	積 厚 流 廣	積 垢	積 怨	積 重 難 返	積 案	積 草 屯 糧	
積 衰 新 造	積 累	積 習	積 習 生 常	積 習 成 俗	積 習 成 常	積 習 難 改	積 處	
積 雪	積 雪 場	積 勞 成 疾	積 惡 余 殃	積 善	積 善 之 家 必 有 餘 慶	積 善 餘 慶	積 著	
積 雲	積 雲 狀	積 微 成 著	積 極	積 極 分 子	積 極 性	積 毀 銷 骨	積 溫	
積 弊	積 滿	積 福	積 聚	積 聚 物	積 聚 者	積 蓄	積 銖 累 寸	
積 德	積 德 累 仁	積 德 累 功	積 憂 成 疾	積 數	積 穀 防 饑	積 壓	積 壓 物 資	
積 壓 品	積 薪 厝 火	積 薪 量 水	積 糧	積 體 電 路	積 攢	穎 性	穎 悟	
穎 悟 絕 人	穎 脫 而 出	穎 慧	穆 如 清 風	穆 罕	穆 罕 默 德	穆 斯 林	穆 然	
窺 孔	窺 全 豹	窺 伺	窺 求	窺 見	窺 知	窺 看	窺 豹	
窺 豹 一 斑	窺 探	窺 探 者	窺 測	窺 視	窺 視 孔	窺 察	窺 牖 小 兒	
窺 鏡	築 成	築 城	築 室 反 耕	築 室 道 謀	築 起	築 基	築 巢	
築 造	築 造 學	築 堤	築 溝	築 路	築 壇 拜 將	築 牆	築 壩	
篤 志 好 學	篤 志 愛 古	篤 信	篤 學 好 古	篡 位	篡 改	篡 奪	篡 奪 者	
篡 黨	篡 權	篡 竊	篩 子	篩 分	篩 去	篩 板	篩 狀	
篩 眼	篩 過	篩 篩	篩 選	篩 糠	篦 麻	糕 餅	糕 點	
糖 □	糖 元	糖 分	糖 化	糖 化 物	糖 心	糖 水	糖 份	
糖 合 物	糖 舌 蜜 口	糖 衣	糖 衣 宣 傳	糖 衣 炮 彈	糖 尿 病	糖 果	糖 果 店	
糖 狀	糖 食	糖 料	糖 紙	糖 盒	糖 蛋 白	糖 量 計	糖 塊	
糖 業	糖 葫 蘆	糖 精	糖 蜜	糖 酸	糖 酸 鹽	糖 廠	糖 彈	
糖 漿	糖 質	糖 醋	糖 醋 魚 片	糖 類	縊 死	縈 迴	縈 繞	
縛 上	縛 住	縛 束	縛 牢	縛 帶	縛 緊	縛 雞	縣 上	
縣 內	縣 令	縣 史 館	縣 外	縣 市	縣 立	縣 丞	縣 份	
縣 吊	縣 名	縣 行	縣 局	縣 志	縣 委	縣 委 書 記	縣 委 會	
縣 官	縣 府	縣 河	縣 治	縣 直	縣 直 機 關	縣 長	縣 城	
縣 政 府	縣 界	縣 級	縣 區	縣 鄉	縣 裡	縣 團 級	縣 辦	
縣 鎮	縣 議 員	縣 議 會	縣 屬	縝 密	縉 紳	縉 雲	縐 紗	
縐 紋	縐 起	縐 痕	縐 褶	縐 邊	罹 災	罹 病	罹 患	
罹 禍	罹 難	羲 皇 上 人	翰 林	翰 墨	翱 翔	膳 房	膳 食	
膳 務 員	膳 宿	膳 寫 者	膩 了	膩 子	膩 味	膩 胃	膩 煩	
膩 膩	膨 大	膨 出	膨 脹	膨 脹 性	膨 脹 計	膨 漲	膨 鬆	
膨 體	臻 沉 滄 海	興 亡	興 亡 繼 絕	興 之 所 至	興 文	興 安	興 安 嶺	
興 兵	興 兵 動 眾	興 利 除 害	興 利 除 弊	興 妖 作 怪	興 妖 作 孽	興 沖 沖	興 邦	
興 味	興 旺	興 旺 發 達	興 門	興 建	興 革	興 風	興 風 作 浪	
興 修	興 修 水 利	興 家 立 業	興 師	興 師 見 罪	興 師 動 眾	興 師 問 罪	興 泰 實 業	
興 衰	興 衰 成 敗	興 衰 榮 辱	興 起	興 高	興 高 采 烈	興 高 彩 烈	興 國	
興 敗	興 產	興 盛	興 許	興 復 不 淺	興 無 滅 資	興 猶 未 盡	興 隆	
興 雲 布 雨	興 雲 吐 霧	興 雲 作 雨	興 雲 作 霧	興 勤 電 子	興 微 繼 絕	興 會 淋 漓	興 業	
興 滅 舉 廢	興 滅 繼 絕	興 農	興 農 人 壽	興 達	興 達 公 司	興 盡 悲 來	興 盡 意 闌	
興 廢	興 廢 存 亡	興 廢 繼 絕	興 歎	興 緻	興 緻 好	興 緻 勃 勃	興 緻 勃 發	
興 緻 索 然	興 趣	興 奮	興 奮 性	興 奮 劑	興 奮 藥	興 學	興 辦	
興 頭	艙 口	艙 位	艙 身	艙 底	艙 房	艙 門	艙 室	
艙 面	艙 裡	艙 蓋	蕊 葉	蕙 心 蘭 質	蕙 心 紈 質	蕙 質 蘭 心	蕩 平	
蕩 來 蕩 去	蕩 性	蕩 析 離 居	蕩 肥	蕩 氣	蕩 氣 迴 腸	蕩 起	蕩 婦	
蕩 寇	蕩 產	蕩 產 傾 家	蕩 船	蕩 然	蕩 然 無 存	蕩 漾	蕩 滌	
蕩 盡	蕩 蕩	蕩 檢 逾 閒	蕩 鞦 韆	蕃 人	蕃 主	蕃 茄	蕃 茄 色	
蕃 薯	蕃 薯 藤	蕉 麻	蕭 行 范 篆	蕭 邦	蕭 亞 軒	蕭 美 琴	蕭 條	
蕭 規 曹 隨	蕭 瑟	蕭 萬 長	蕭 蕭	蕭 牆	蕭 牆 禍 起	蕭 薔	蕪 湖	
蕪 菁	蕪 雜	螃 蟹	螟 害	螟 蟲	螞 蚱	螞 蟻	螞 蟻 啃 骨 頭	
螞 蟥	螢 火	螢 火 蟲	螢 石	螢 光	螢 光 素	螢 光 幕	螢 光 鏡	
螢 窗 雪 案	螢 幕	融 入	融 化	融 水	融 合	融 合 性	融 券	
融 和	融 洽	融 為	融 為 一 體	融 掉	融 貫	融 通	融 雪	
融 匯	融 會	融 會 貫 通	融 解	融 資	融 資 融 券	融 融	融 體	
衡 力	衡 山	衡 水	衡 平 法	衡 制	衡 定	衡 東	衡 門 深 巷	
衡 量	衡 陽	衡 器	衡 學	褪 去	褪 色	褪 前 擦 後	褲 子	
褲 內	褲 勾	褲 衫	褲 料	褲 兜	褲 帶	褲 帶 扣	褲 袋	
褲 腰	褲 腳	褲 裙	褲 管	褲 腿	褲 襠	褲 襪	褲 衩	
褥 子	褥 面	褥 套	褥 草	褥 單	褥 墊	褥 瘡	褫 奪	
褡 褳	親 了	親 人	親 上 加 親	親 上 成 親	親 上 做 親	親 口	親 子	
親 子 教 育	親 子 樂 園	親 子 關 係	親 公	親 切	親 切 友 好	親 切 服 務	親 友	
親 夫	親 手	親 日	親 父	親 王	親 兄 弟	親 本	親 母	
親 民 黨	親 生	親 生 子 女	親 生 父 母	親 生 骨 肉	親 目	親 交	親 任	
親 合 力	親 多	親 如 一 家	親 如 手 足	親 如 骨 肉	親 耳	親 自	親 自 出 馬	
親 伴	親 兵	親 吻	親 身	親 事	親 使	親 函	親 取	
親 和	親 和 力	親 姐 妹	親 征	親 朋	親 朋 好 友	親 知	親 者	
親 迎	親 近	親 信	親 俄	親 政	親 洽	親 英	親 赴	
親 娘	親 家	親 爹	親 骨	親 骨 肉	親 密	親 密 無 間	親 從	
親 戚	親 授	親 啟	親 族	親 率	親 疏	親 疏 貴 賤	親 眷	
親 眼	親 痛 仇 快	親 筆	親 筆 信	親 筆 寫	親 善	親 華	親 愛	
親 愛 人	親 愛 的	親 當 矢 石	親 睦	親 嘴	親 德	親 暱	親 熱	
親 緣	親 操 井 臼	親 歷	親 親	親 親 熱 熱	親 隨	親 臉	親 臨	
親 職	親 離	親 屬	親 屬 制 度	親 屬 稱 謂	親 屬 關 係	親 權	親 驗	
諦 聽	諺 語	諫 言	諫 爭 如 流	諫 書	諫 補	諫 諍	諱 名	
諱 言	諱 疾 忌 醫	諱 敗 推 過	諱 莫 如 深	諱 惡 不 悛	謀 士	謀 反	謀 夫 孔 多	
謀 生	謀 如 湧 泉	謀 而 後 動	謀 臣	謀 臣 如 雨	謀 臣 武 將	謀 臣 猛 將	謀 利	
謀 求	謀 私	謀 事	謀 事 在 人	謀 刺	謀 取	謀 取 私 利	謀 定	
謀 者	謀 叛	謀 為 不 軌	謀 面	謀 害	謀 財 害 命	謀 逆 不 軌	謀 得	
謀 殺	謀 殺 犯	謀 殺 案	謀 略	謀 略 思 想	謀 略 家	謀 略 學	謀 無 遺 策	
謀 善	謀 劃	謀 劃 者	謀 圖 不 軌	謀 奪	謀 遠	謀 慮	謀 慮 深 遠	
謀 獲	謀 職	謀 謨 帷 幄	諜 報	諜 報 史	諧 函 數	諧 和	諧 波	
諧 星	諧 美	諧 音	諧 振	諧 振 動	諧 振 器	諧 劇	諧 調	
諧 趣	諧 聲	諧 謔	諮 文	諮 師 訪 友	諾 言	諾 貝 爾	諾 貝 爾 獎	
諾 曼 底	諾 曼 第	諾 基 亞	諾 魯	諾 魯 共 和 國	諾 諾	諾 諾 而 退	謁 見	
謁 者	謂 之	謂 詞	謂 語	諷 一 勸 百	諷 今	諷 古	諷 刺	
諷 刺 文	諷 刺 文 學	諷 刺 性	諷 刺 家	諷 刺 畫	諷 刺 詩	諷 刺 話	諷 刺 劇	
諷 剌	諷 喻	諷 語	諭 旨	諳 練	諳 曉	豫 劇	貓	
貓 爪	貓 叫	貓 叫 聲	貓 皮	貓 耳	貓 耳 洞	貓 兒	貓 咪	
貓 科	貓 眼	貓 眼 石	貓 鼠 同 眠	貓 熊	貓 膩	貓 頭 鷹	貓 聲	
貓 聲 鳥	貓 屬	賴 士 葆	賴 夫 特	賴 比 瑞 亞	賴 以	賴 皮	賴 床	
賴 氨 酸	賴 索 托 王 國	賴 婚	賴 掉	賴 著	賴 詞	賴 債	賴 補	
賴 賬	賴 聲 川	蹄 子	蹄 形	蹄 狀 體	蹄 掌	蹄 筋	蹄 間 三 尋	
蹄 聲	蹄 鐵	踱 步	踴 躍	踴 躍 報 名	蹂 躪	踵 決 肘 見	踵 事 增 華	
踵 接 肩 摩	輻 合	輻 射	輻 射 防 護	輻 射 性	輻 射 狀	輻 射 計	輻 射 能	
輻 射 偵 察	輻 射 率	輻 射 塵	輻 射 儀	輻 射 熱	輻 射 體	輻 條	輻 散	
輻 軸	輻 照	輯 要	輯 錄	輸 入	輸 入 法	輸 入 品	輸 入 速 度	
輸 入 項	輸 入 端	輸 水	輸 出	輸 出 品	輸 去	輸 光	輸 血	
輸 卵	輸 卵 管	輸 址	輸 尿 管	輸 肝 剖 膽	輸 肝 瀝 膽	輸 往	輸 油	
輸 油 管	輸 油 管 線	輸 者	輸 家	輸 氧	輸 送	輸 送 帶	輸 掉	
輸 液	輸 理	輸 給	輸 電	輸 電 線	輸 精 管	輸 錢	輸 贏	
辨 出	辨 正	辨 白	辨 色	辨 別	辨 別 方 向	辨 別 真 假	辨 明	
辨 明 是 非	辨 析	辨 音	辨 家	辨 清	辨 認	辨 認 出	辨 識	
辨 證	辨 證 法	辨 讀	辦 不 成	辦 不 到	辦 公	辦 公 大 樓	辦 公 用 品	
辦 公 自 動 化	辦 公 室	辦 公 桌	辦 公 處	辦 公 設 備	辦 公 費	辦 公 會 議	辦 公 樓	
辦 公 廳	辦 文	辦 好	辦 成	辦 妥	辦 完	辦 事	辦 事 員	
辦 事 效 率	辦 事 處	辦 事 機 構	辦 到	辦 法	辦 案	辦 班	辦 起	
辦 得 成	辦 得 到	辦 理	辦 貨	辦 報	辦 幾 件 實 事	辦 稅	辦 實 事	
辦 廠	辦 學	辦 學 條 件	辦 錯	辦 錯 事	辦 證	辦 礦	遵 令	
遵 守	遵 守 紀 律	遵 旨	遵 而 不 失	遵 行	遵 命	遵 奉	遵 奉 者	
遵 紀	遵 紀 守 法	遵 時 養 晦	遵 從	遵 循	遵 照	遵 照 執 行	遵 義	
遵 養 待 時	遵 養 時 晦	遵 辦	遴 選	選 人	選 入	選 上	選 士 厲 兵	
選 中	選 手	選 文	選 出	選 刊	選 本	選 民	選 民 證	
選 用	選 任	選 好	選 字	選 年	選 收	選 曲	選 自	
選 兵 秣 馬	選 址	選 投	選 材	選 育	選 言 判 斷	選 取	選 取 框	
選 委	選 委 會	選 定	選 居	選 拔	選 拔 賽	選 法	選 物	
選 者	選 型	選 派	選 為	選 美	選 修	選 修 課	選 准	
選 徒	選 料	選 送	選 配	選 區	選 得	選 情 分 析	選 情 調 查	
選 票	選 票 數	選 單	選 場	選 揀	選 殖	選 萃	選 詞	
選 集	選 項	選 項 板	選 煤	選 聘	選 號	選 路	選 種	
選 粹	選 粹 本	選 播	選 樣	選 編	選 課	選 調	選 賢 任 能	
選 學	選 擇	選 擇 性	選 擇 者	選 擇 器	選 擇 權	選 篩	選 輯	
選 錄	選 舉	選 舉 人	選 舉 民 調	選 舉 制	選 舉 制 度	選 舉 法	選 舉 前	
選 舉 造 勢	選 舉 暴 力	選 舉 辯 論	選 舉 權	選 賽	選 購	選 題	選 礦	
選 譯	選 讀	遲 了	遲 交	遲 回	遲 回 觀 望	遲 早	遲 到	
遲 到 者	遲 延	遲 延 物	遲 於	遲 效	遲 做	遲 產	遲 報	
遲 鈍	遲 鈍 人	遲 鈍 化	遲 頓	遲 滯	遲 疑	遲 疑 不 決	遲 疑 未 決	
遲 睡	遲 誤	遲 暮	遲 緩	遲 遲	遼 中	遼 代	遼 西	
遼 東	遼 東 半 島	遼 河	遼 國	遼 陽	遼 源	遼 寧	遼 寧 省	
遼 闊	遺 下	遺 大 投 艱	遺 少	遺 文	遺 世 絕 俗	遺 世 獨 立	遺 失	
遺 民	遺 老	遺 臣	遺 作	遺 址	遺 尿	遺 尿 症	遺 忘	
遺 忘 河	遺 忘 症	遺 志	遺 言	遺 事	遺 孤	遺 念	遺 物	
遺 物 箱	遺 芳 餘 烈	遺 俗	遺 恨	遺 恨 千 古	遺 毒	遺 風	遺 風 餘 思	
遺 風 餘 烈	遺 風 遺 澤	遺 容	遺 書	遺 珠 棄 璧	遺 留	遺 缺	遺 臭	
遺 臭 千 年	遺 臭 萬 年	遺 臭 萬 載	遺 訓	遺 骨	遺 教	遺 族	遺 棄	
遺 棄 物	遺 棄 者	遺 產	遺 產 稅	遺 痕	遺 著	遺 詔	遺 傳	
遺 傳 上	遺 傳 工 程	遺 傳 性	遺 傳 型	遺 傳 學	遺 愛	遺 照	遺 腹	
遺 腹 子	遺 詩	遺 跡	遺 像	遺 境	遺 漏	遺 禍	遺 精	
遺 誤	遺 稿	遺 編 絕 簡	遺 墨	遺 憾	遺 憾 的 是	遺 骸	遺 簪 墜 屨	
遺 簪 墮 屨	遺 贈	遺 贈 人	遺 贈 者	遺 難 成 祥	遺 願	遺 孀	遺 屬	
遺 體	遺 囑	遺 囑 等	醒 了	醒 世	醒 目	醒 來	醒 來 吧	
醒 的	醒 者	醒 悟	醒 酒	醒 眼	醒 著	醒 獅	醒 過 來	
醒 醒	醒 覺	錠 子	錠 子 油	錶 鏈	鋸 子	鋸 切 痕	鋸 木	
鋸 木 匠	鋸 木 場	鋸 木 廠	鋸 片	鋸 牙 鉤 瓜	鋸 末	鋸 成	鋸 床	
鋸 材	鋸 狀	鋸 屑	鋸 掉	鋸 條	鋸 短	鋸 開	鋸 齒	
鋸 齒 形	鋸 齒 狀	鋸 斷	錳 土	錳 肥	錳 粉	錳 鋼	錳 礦	
錳 鐵	錯 了	錯 失	錯 失 良 機	錯 交	錯 列	錯 印	錯 在	
錯 字	錯 式	錯 扣	錯 收	錯 位	錯 估	錯 別 字	錯 車	
錯 事	錯 兒	錯 征	錯 怪	錯 法	錯 的	錯 者	錯 看	
錯 案	錯 記	錯 退	錯 彩 鏤 金	錯 處	錯 報	錯 牌	錯 發	
錯 開	錯 亂	錯 填	錯 愛	錯 節 盤 根	錯 落	錯 落 不 齊	錯 落 有 致	
錯 號	錯 話	錯 路	錯 過	錯 漏	錯 疑	錯 算	錯 綜	
錯 綜 複 雜	錯 認	錯 誤	錯 誤 思 想	錯 誤 傾 向	錯 誤 觀 點	錯 寫	錯 轉	
錯 雜	錯 覺	錯 譯	錢 包	錢 可 通 神	錢 多	錢 串 子	錢 夾	
錢 其 琛	錢 物	錢 庫	錢 財	錢 票	錢 莊	錢 袋	錢 款	
錢 筒	錢 鈔	錢 鼠	錢 幣	錢 箱	錢 樹	錢 櫃	錢 糧	
錢 舖	鋼 刀	鋼 丸	鋼 化	鋼 尺	鋼 水	鋼 片	鋼 印	
鋼 扣	鋼 材	鋼 板	鋼 花	鋼 炮	鋼 砂	鋼 胚	鋼 軌	
鋼 珠	鋼 索	鋼 針	鋼 骨 結 構	鋼 圈	鋼 帶	鋼 捲	鋼 瓶	
鋼 產	鋼 產 量	鋼 盔	鋼 粒	鋼 渣	鋼 琴	鋼 琴 家	鋼 筆	
鋼 筆 尖	鋼 筆 畫	鋼 筋	鋼 筋 水 泥	鋼 筋 混 凝 土	鋼 結 構	鋼 絲	鋼 絲 繩	
鋼 軸	鋼 塊	鋼 構	鋼 種	鋼 管	鋼 精	鋼 製	鋼 廠	
鋼 樑	鋼 碼	鋼 箱	鋼 線	鋼 錠	鋼 鋸	鋼 爐	鋼 鐵	
鋼 鐵 公 司	鋼 鐵 股	鋼 鐵 業	鋼 鐵 廠	鋼 纜	鋼 坯	鋼 釬	鋼 筘	
鋼 箍	錫 匠	錫 制	錫 金	錫 紙	錫 鼓	錫 箔	錫 箔 紙	
錫 酸 鹽	錫 劇	錫 器	錫 錠	錫 礦	錫 礦 山	錫 礦 工	錫 蘭	
錫 鐵 匠	錄 入	錄 下	錄 打	錄 用	錄 好	錄 作	錄 事	
錄 供	錄 取	錄 放	錄 相	錄 相 機	錄 音	錄 音 員	錄 音 帶	
錄 音 磁 帶	錄 音 機	錄 像	錄 像 片	錄 像 帶	錄 像 碟	錄 像 盤	錄 像 機	
錄 製	錄 影	錄 影 唱 片	錄 影 帶	錄 影 碟	錄 影 機	錚 錚	錚 錚 鐵 骨	
錐 刀 之 末	錐 刀 之 用	錐 刀 之 利	錐 子	錐 形	錐 形 物	錐 狀	錐 度	
錐 面	錐 骨	錐 處 囊 中	錐 體	錦 上 添 花	錦 心 繡 口	錦 心 繡 腹	錦 片 前 程	
錦 生	錦 州	錦 衣	錦 衣 玉 食	錦 秀	錦 言	錦 帛	錦 屏	
錦 春	錦 盒	錦 菜	錦 瑟 年 華	錦 瑟 華 年	錦 旗	錦 綸	錦 標	
錦 標 主 義	錦 標 賽	錦 緞	錦 繡	錦 繡 二 重 唱	錦 繡 山 河	錦 繡 心 腸	錦 繡 江 山	
錦 繡 河 山	錦 繡 前 程	錦 雞	錦 囊	錦 囊 妙 計	錦 囊 佳 句	錦 囊 佳 制	錙 銖 必 較	
錙 銖 較 量	閻 王	閻 羅	閻 羅 王	隧 洞	隧 道	隨 口	隨 口 而 出	
隨 大 流	隨 干	隨 之	隨 之 而 來	隨 心	隨 心 所 欲	隨 手	隨 文	
隨 世 沉 浮	隨 他	隨 叫 隨 到	隨 它 去	隨 同	隨 地	隨 有	隨 而	
隨 行	隨 行 人 員	隨 行 就 市	隨 伴	隨 你	隨 即	隨 身	隨 身 攜 帶	
隨 車	隨 侍	隨 其	隨 到	隨 和	隨 波 逐 流	隨 波 逐 浪	隨 波 逐 塵	
隨 波 漂 流	隨 物	隨 附	隨 便	隨 便 說 說	隨 俗	隨 俗 沉 浮	隨 俗 浮 沉	
隨 後	隨 洗	隨 要	隨 軍	隨 風	隨 風 倒	隨 風 倒 舵	隨 風 轉 舵	
隨 候 之 珠	隨 員	隨 時	隨 時 制 宜	隨 時 度 勢	隨 時 隨 地	隨 書	隨 珠 彈 雀	
隨 帶	隨 從	隨 處	隨 處 可 見	隨 訪	隨 寓 而 安	隨 筆	隨 著	
隨 鄉 入 俗	隨 鄉 入 鄉	隨 隊	隨 傳	隨 意	隨 意 性	隨 想	隨 群	
隨 道	隨 遇	隨 遇 而 安	隨 團	隨 緣	隨 緣 樂 助	隨 機	隨 機 化	
隨 機 而 變	隨 機 性	隨 機 數	隨 機 應 變	隨 踵 而 至	隨 隨 便 便	隨 聲	隨 聲 附 和	
隨 聲 是 非	隨 禮	險 地	險 坑	險 些	險 性	險 阻	險 阻 艱 難	
險 段	險 毒	險 要	險 家	險 峻	險 峰	險 時	險 陡	
險 情	險 球	險 被	險 勝	險 惡	險 詐	險 象	險 象 環 生	
險 隘	險 像	險 境	險 遭	險 灘	雕 工	雕 作	雕 肝 琢 腎	
雕 肝 琢 膂	雕 肝 鏤 腎	雕 刻	雕 刻 了	雕 刻 品	雕 刻 家	雕 刻 師	雕 刻 般	
雕 花	雕 品	雕 梁 畫 棟	雕 章 鏤 句	雕 章 繢 句	雕 琢	雕 塑	雕 塑 品	
雕 塑 家	雕 像	雕 像 座	雕 龍	雕 鑄 像	霎 那	霎 時	霎 時 間	
霎 眼	霍 山	霍 地	霍 克	霍 邱	霍 金 斯	霍 然	霍 亂	
霍 爾	霍 霍	霓 虹	霓 虹 燈	霏 霏	靛 藍	靜 力	靜 力 學	
靜 下 來	靜 中 帶 旺	靜 心	靜 止	靜 水	靜 水 壓	靜 地	靜 如 處 女 動 如 脫 兔	
靜 安	靜 坐	靜 夜	靜 宜	靜 物	靜 的	靜 臥	靜 待	
靜 音	靜 風	靜 候	靜 座	靜 悄 悄	靜 氣	靜 海	靜 脈	
靜 脈 內	靜 脈 曲 張	靜 脈 血	靜 脈 瘤	靜 寂	靜 肅	靜 象	靜 電	
靜 電 力	靜 電 屏 蔽	靜 電 計	靜 電 感 應	靜 電 學	靜 像	靜 寧	靜 態	
靜 態 型	靜 摩 擦 力	靜 熱	靜 養	靜 穆	靜 靜	靜 默	靜 壓	
靜 聲	靜 謐	靜 聽	靜 觀	靦 腆	鞘 中	鞘 翅	鞘 擄	
頰 上	頰 面	頰 骨	頸 子	頸 狀	頸 後	頸 背	頸 骨	
頸 動 脈	頸 部	頸 椎	頸 項	頸 靜 脈	頻 仍	頻 生	頻 尿	
頻 抗	頻 度	頻 段	頻 密	頻 帶	頻 率	頻 率 計	頻 傳	
頻 催	頻 道	頻 寬	頻 數	頻 頻	頻 頻 點 頭	頻 繁	頻 譜	
頷 下	頭 一 回	頭 一 年	頭 一 次	頭 人	頭 上	頭 上 安 頭	頭 大	
頭 子	頭 寸	頭 小	頭 巾	頭 中	頭 天	頭 手 枷	頭 水	
頭 功 起 釁	頭 皮	頭 皮 屑	頭 目	頭 伙	頭 伏	頭 份	頭 向 前	
頭 字 語	頭 年	頭 羊	頭 尾	頭 角	頭 角 崢 嶸	頭 角 嶄 然	頭 足 異 所	
頭 足 異 處	頭 兒	頭 刷	頭 昏	頭 昏 目 眩	頭 昏 眼 花	頭 昏 眼 暗	頭 昏 眼 暈	
頭 昏 腦 悶	頭 昏 腦 脹	頭 油	頭 版	頭 版 頭 條	頭 狀	頭 城	頭 屋	
頭 屋 鄉	頭 胎	頭 重 足 輕	頭 重 腳 輕	頭 面	頭 面 人 物	頭 套	頭 家	
頭 屑	頭 疼	頭 疼 腦 熱	頭 眩 眼 花	頭 破 血 出	頭 破 血 流	頭 陣	頭 骨	
頭 骨 學	頭 帶	頭 彩	頭 梢 自 領	頭 條	頭 異	頭 盔	頭 票	
頭 部	頭 頂	頭 朝 下	頭 牌	頭 痛	頭 痛 灸 頭 腳 痛 醫 腳	頭 痛 治 頭 足 痛 治 足	頭 痛 醫 頭	
頭 短	頭 童 齒 豁	頭 等	頭 等 大 事	頭 菜	頭 暈	頭 暈 目 眩	頭 暈 眼 昏	
頭 暈 眼 花	頭 會 箕 賦	頭 會 箕 斂	頭 罩	頭 腦	頭 腦 好	頭 腦 清 醒	頭 腦 發 熱	
頭 號	頭 裡	頭 路	頭 飾	頭 像	頭 槌	頭 端	頭 緒	
頭 蓋	頭 蓋 骨	頭 蓋 帽	頭 銜	頭 領	頭 數	頭 獎	頭 髮	
頭 髮 油	頭 艙	頭 頸	頭 頭	頭 頭 是 道	頭 戴	頭 臉	頭 額	
頭 繩	頭 韻	頭 癢 搔 跟	頭 籌	頭 癬	頭 顱	頭 茬	頭 箍	
頹 局	頹 風	頹 唐	頹 敗	頹 喪	頹 然	頹 勢	頹 廢	
頹 廢 者	頹 靡	頤 和 園	頤 性 養 壽	頤 指 如 意	頤 指 氣 使	頤 指 進 退	頤 神 養 氣	
頤 神 養 壽	頤 精 養 性	頤 精 養 神	頤 養	頤 養 天 年	頤 養 精 神	餐 刀	餐 叉	
餐 巾	餐 布	餐 用	餐 車	餐 具	餐 具 室	餐 具 架	餐 具 櫃	
餐 具 櫥	餐 券	餐 杯	餐 松 啖 柏	餐 松 飲 澗	餐 物	餐 者	餐 前	
餐 室	餐 後	餐 風 吸 露	餐 風 沐 雨	餐 風 宿 水	餐 風 宿 雨	餐 風 宿 露	餐 食	
餐 料	餐 桌	餐 椅 墊	餐 費	餐 飯	餐 飲	餐 飲 業	餐 器	
餐 館	餐 點	餐 禮	餐 廳	館 子	館 內	館 外	館 舍	
館 長	館 員	館 站	館 區	館 陶	館 藏	館 藏 管 理	餞 行	
餞 別	餞 亭 玉 立	餛 飩	餡 餅	餡 餅 皮	駭 人	駭 人 聽 聞	駭 目	
駭 怕	駭 客	駭 浪	駭 浪 驚 濤	駭 異	駭 術	駭 愕	駭 然	
駭 聞	駢 文	駢 四 儷 六	駢 拇 枝 指	駢 肩 累 足	駢 肩 累 跡	駢 肩 累 踵	駱 駝	
駱 駝 夫	駱 驛 不 絕	骸 骨	骼 肌	鮑 魚	鴕 鳥	鴕 鳥 皮	鴨	
鴨 子	鴨 毛	鴨 肉	鴨 行 鵝 步	鴨 步 鵝 行	鴨 蛋	鴨 掌	鴨 絨	
鴨 飯	鴨 黃	鴨 腳	鴨 綠 江	鴨 嘴	鴛 儔 鳳 侶	鴛 鴦	默 不 作 聲	
默 坐	默 求	默 念	默 哀	默 契	默 思	默 背	默 祝	
默 記	默 問	默 從	默 許	默 然	默 視	默 想	默 算	
默 誦	默 認	默 認 值	默 劇	默 寫	默 默	默 默 無 言	默 默 無 聞	
默 默 無 語	默 讀	黔 江	黔 西	黔 西 南	黔 東 南	黔 南	黔 首	
黔 陽	黔 驢	黔 驢 之 技	黔 驢 技 窮	龍 口	龍 女	龍 井	龍 井 茶	
龍 井 鄉	龍 公	龍 王	龍 生 九 子	龍 田	龍 田 建 設	龍 年	龍 舌	
龍 舟	龍 行 虎 步	龍 似	龍 吟	龍 吟 虎 嘯	龍 床	龍 肝 豹 胎	龍 肝 鳳 髓	
龍 邦 建 設	龍 爭 虎 鬥	龍 芽 草	龍 虎	龍 門	龍 門 石 窟	龍 門 架	龍 洞	
龍 眉 皓 髮	龍 眉 鳳 目	龍 飛 鳳 舞	龍 首	龍 套	龍 宮	龍 庭	龍 脈	
龍 馬	龍 馬 精 神	龍 骨	龍 骨 台	龍 崎 鄉	龍 捲 風	龍 眼	龍 船	
龍 蛇	龍 蛇 飛 動	龍 蛇 混 雜	龍 袍	龍 章 鳳 姿	龍 華 乳 鴿	龍 腦	龍 葵	
龍 舞	龍 鳳	龍 潭	龍 潭 虎 穴	龍 潭 虎 窟	龍 潭 鄉	龍 盤 虎 踞	龍 蝦	
龍 駒	龍 駒 鳳 雛	龍 戰 虎 爭	龍 燈	龍 頭	龍 頭 蛇 尾	龍 膽	龍 膽 根	
龍 蟠	龍 蟠 虎 踞	龍 蟠 鳳 逸	龍 顏	龍 鐘	龍 騰 虎 躍	龍 躍 鳳 鳴	龍 體	
龍 劭 華	龍 驤 虎 步	龍 驤 虎 視	龜 山	龜 文 鳥 跡	龜 毛 兔 角	龜 王	龜 甲	
龜 甲 狀	龜 年 鶴 壽	龜 殼	龜 裂	龜 頭	龜 龍 麟 鳳	龜 龜 瑣 瑣	龜 縮	
龜 類	龜 齡 鶴 算	龜 鱉	優 化	優 化 組 合	優 生	優 生 法	優 生 學	
優 生 學 家	優 生 優 育	優 先	優 先 化	優 先 於	優 先 股	優 先 級	優 先 發 展	
優 先 照 顧	優 先 權	優 劣	優 存 劣 汰	優 秀	優 秀 人 才	優 秀 分 子	優 秀 成 果	
優 秀 作 品	優 秀 兒 女	優 秀 品 質	優 秀 教 師	優 秀 幹 部	優 秀 獎	優 秀 黨 員	優 育	
優 良	優 良 作 風	優 良 品 種	優 良 傳 統	優 孟 衣 冠	優 於	優 者	優 厚	
優 哉 游 哉	優 待	優 恤	優 柔	優 柔 寡 斷	優 美	優 美 公 司	優 容	
優 缺 點	優 異	優 異 成 績	優 勝	優 勝 劣 汰	優 勝 者	優 勝 旗	優 惠	
優 惠 待 遇	優 惠 政 策	優 惠 價	優 等	優 越	優 越 性	優 越 感	優 雅	
優 勢	優 勢 互 補	優 裕	優 種	優 撫	優 撫 工 作	優 質	優 質 服 務	
優 質 產 品	優 質 優 價	優 選	優 選 法	優 點	優 霸 盃	償 欠	償 付	
償 本	償 命	償 金	償 清	償 債	償 還	償 願	儲 入	
儲 戶	儲 水	儲 水 塔	儲 存	儲 存 處	儲 存 媒 體	儲 位	儲 油	
儲 油 罐	儲 金	儲 金 會	儲 氣	儲 處	儲 備	儲 備 物	儲 備 金	
儲 備 基 金	儲 備 量	儲 備 糧	儲 量	儲 運	儲 電 量	儲 蓄	儲 蓄 所	
儲 蓄 金	儲 蓄 庫	儲 蓄 銀 行	儲 蓄 額	儲 蓄 罐	儲 積	儲 藏	儲 藏 所	
儲 藏 室	儲 藏 箱	勵 行	勵 志	勵 志 小 品	勵 精 求 治	勵 精 圖 治	嚎 叫	
嚎 啕	嚎 著	嚇 一 跳	嚇 了	嚇 人	嚇 不 倒	嚇 死	嚇 住	
嚇 呆	嚇 走	嚇 阻	嚇 倒	嚇 唬	嚇 得	嚇 著	嚇 跑	
嚇 傻	嚇 噓	嚇 聲	嚇 壞	嚏 聲	壕 溝	壓 力	壓 力 表	
壓 力 計	壓 力 機	壓 力 鍋	壓 下	壓 上	壓 不 碎	壓 出	壓 平	
壓 仰	壓 光	壓 光 機	壓 印	壓 在	壓 在 心 底	壓 成	壓 而 不 服	
壓 住	壓 低	壓 抑	壓 抑 感	壓 制	壓 制 性	壓 卷	壓 延	
壓 服	壓 板	壓 花	壓 垮	壓 後	壓 扁	壓 迫	壓 迫 者	
壓 倒	壓 倒 一 切	壓 倒 元 白	壓 倒 多 數	壓 倒 性	壓 差	壓 根	壓 根 兒	
壓 氣	壓 破	壓 紋	壓 陣	壓 圈	壓 帳	壓 強	壓 條	
壓 痕	壓 頂	壓 頂 石	壓 著	壓 軸 戲	壓 搾	壓 搾 器	壓 搾 機	
壓 歲	壓 歲 錢	壓 碎	壓 腳	壓 路	壓 逼	壓 電	壓 境	
壓 寨	壓 緊	壓 價	壓 皺	壓 線	壓 擔 子	壓 機	壓 壓	
壓 擠	壓 縮	壓 縮 空 氣	壓 縮 機	壓 壞	壓 韻	壓 寶	壓 爛	
壓 彎	壓 鑄	壓 驚	嬰 幼 兒	嬰 兒	嬰 兒 車	嬰 兒 期	嬰 兒 鞋	
嬰 孩	嬪 妃	嬪 相	嬤 嬤	孺 子	孺 子 牛	孺 子 可 教	尷 尬	
屨 及 劍 及	屨 賤 踴 貴	嶺 石	嶺 南	嶺 高	嶺 撥	幫 人	幫 子	
幫 工	幫 內	幫 手	幫 他	幫 伙	幫 兇	幫 忙	幫 你	
幫 助	幫 助 某 人	幫 助 索 引	幫 我	幫 派	幫 派 份 子	幫 派 體 系	幫 倒 忙	
幫 員	幫 帶	幫 教	幫 腔	幫 著	幫 訴	幫 閒	幫 閒 鑽 懶	
幫 會	幫 補	幫 廚	幫 辦	幫 幫	幫 襯	彌 久	彌 山 遍 野	
彌 天	彌 天 大 罪	彌 天 大 謊	彌 天 蓋 地	彌 月	彌 合	彌 留	彌 勒	
彌 望	彌 渡	彌 補	彌 彰	彌 撒	徽 州	徽 章	徽 牌	
徽 標	徽 調	徽 墨	徽 縣	應 力	應 予	應 予 以	應 允	
應 分	應 天 受 命	應 天 承 運	應 天 從 人	應 天 從 民	應 天 從 物	應 天 授 命	應 天 順 人	
應 天 順 民	應 天 順 時	應 支	應 以	應 付	應 付 自 如	應 付 款	應 付 裕 如	
應 充	應 加	應 召	應 召 入 伍	應 市	應 斥 責	應 生	應 用	
應 用 心 理 學	應 用 文	應 用 技 術	應 用 於	應 用 科 學	應 用 程 式	應 用 題	應 用 邏 輯	
應 由	應 立 即	應 交	應 列	應 向	應 在	應 扣	應 收	
應 有	應 有 盡 有	應 考	應 作	應 兌	應 免	應 即	應 否	
應 把	應 具	應 到	應 到 達	應 制	應 取	應 受	應 和	
應 屆	應 屆 畢 業 生	應 承	應 於	應 注 意	應 急	應 按	應 按 照	
應 是	應 為	應 穿	應 約	應 計	應 負	應 負 責	應 時	
應 時 而 生	應 根 據	應 留	應 納	應 納 稅	應 能	應 記	應 起 訴	
應 退	應 做	應 將	應 得	應 從	應 接 不 暇	應 接 如 響	應 被	
應 規 蹈 矩	應 許	應 設	應 責 備	應 報	應 報 備	應 尊 敬	應 提	
應 景	應 發	應 答	應 答 如 響	應 訴	應 診	應 貸	應 募	
應 當	應 聘	應 補	應 該	應 該 說	應 試	應 試 者	應 運	
應 運 而 生	應 運 而 起	應 酬	應 酬 話	應 對	應 對 不 窮	應 對 如 流	應 盡	
應 罰 款	應 說	應 際 而 生	應 領	應 增	應 徵	應 徵 收	應 徵 稅	
應 撥	應 敵	應 課 稅	應 適 當	應 銷	應 戰	應 機 立 斷	應 機 權 變	
應 激 性	應 諾	應 辦	應 選	應 聲	應 聲 蟲	應 還	應 邀	
應 邀 出 席	應 邀 而 來	應 邀 前 來	應 轉	應 懲 罰	應 屬	應 攤	應 權 通 變	
應 變	應 變 力	應 變 計	應 變 能 力	應 變 無 方	應 變 隨 機	應 驗	懂 行	
懂 事	懂 的	懂 得	懇 切	懇 求	懇 求 似	懇 求 者	懇 摯	
懇 談	懇 談 會	懇 請	懇 請 似	懇 親 會	懇 辭	懦 夫	懦 怯	
懦 弱	戲 子	戲 中	戲 文	戲 水	戲 水 者	戲 台	戲 本	
戲 目	戲 曲	戲 衣	戲 弄	戲 弄 者	戲 言	戲 法	戲 的	
戲 是	戲 耍	戲 校	戲 班	戲 迷	戲 院	戲 票	戲 單	
戲 場	戲 評	戲 詞	戲 園	戲 照	戲 裝	戲 路	戲 團	
戲 種	戲 說	戲 劇	戲 劇 化	戲 劇 性	戲 劇 家	戲 劇 般	戲 劇 等	
戲 嘻	戲 談	戲 鬧	戲 據 性	戲 謔	戴 了	戴 上	戴 天	
戴 天 履 地	戴 手 鐲	戴 月	戴 月 披 星	戴 以	戴 在	戴 好	戴 孝	
戴 牢	戴 佩 妮	戴 芬 波 特	戴 冠	戴 盆 望 天	戴 面 具	戴 桂 冠	戴 高 帽 子	
戴 高 帽 兒	戴 高 樂	戴 假 髮	戴 眼	戴 眼 鏡	戴 帽	戴 發 含 齒	戴 著	
戴 圓 履 方	戴 罪 立 功	戴 罪 圖 功	戴 爾	戴 綠 帽	戴 緊	戴 頭	戴 頭 巾	
戴 頭 識 臉	戴 雞 配 豚	擎 天	擎 天 之 柱	擎 天 玉 柱	擎 天 架 海	擎 著	擎 蒼 牽 黃	
擊 入	擊 中	擊 中 要 害	擊 水	擊 打	擊 玉 敲 金	擊 向	擊 沉	
擊 昏	擊 垮	擊 穿	擊 倒	擊 破	擊 退	擊 敗	擊 球	
擊 掌	擊 傷	擊 楫 中 流	擊 毀	擊 碎	擊 碎 唾 壺	擊 節 稱 賞	擊 節 歎 賞	
擊 落	擊 鼓	擊 劍	擊 撞	擊 潰	擊 斃	擊 聲	擊 鍵	
擊 壤 鼓 腹	擊 鐘	擊 鐘 陳 鼎	擊 鐘 鼎 食	擘 肌 分 理	擠 人	擠 入	擠 上	
擠 干	擠 牙 膏	擠 牛 奶	擠 出	擠 占	擠 去	擠 奶	擠 奶 人	
擠 奶 員	擠 向	擠 在	擠 成	擠 作	擠 兌	擠 走	擠 車	
擠 乳	擠 來	擠 到	擠 垮	擠 眉 弄 眼	擠 眉 溜 眼	擠 迫	擠 時 間	
擠 得	擠 掉	擠 著	擠 進	擠 進 去	擠 搾	擠 逼	擠 過	
擠 滿	擠 撞	擠 壓	擠 壓 出	擠 擠	擰 成	擰 成 一 股 繩	擰 松	
擰 乾	擰 開	擰 態 病	擰 緊	擰 斷	擰 轉	擦 了	擦 上	
擦 子	擦 不 掉	擦 去	擦 皮 鞋	擦 光 油	擦 光 劑	擦 汗	擦 屁 股	
擦 把	擦 身 而 過	擦 或 壓	擦 於	擦 油	擦 肩	擦 肩 而 過	擦 亮	
擦 亮 石	擦 亮 眼 睛	擦 拭	擦 洗	擦 拳 抹 掌	擦 拳 磨 掌	擦 桌	擦 破	
擦 粉	擦 脂 抹 粉	擦 除	擦 乾	擦 乾 淨	擦 掉	擦 淨	擦 痕	
擦 眼 淚	擦 掌 磨 拳	擦 著	擦 傷	擦 碎	擦 過	擦 撞 而 過	擦 熱	
擦 鞋	擦 鞋 者	擦 鞋 墊	擦 劑	擦 澡	擦 磨	擦 擦	擦 聲	
擦 藥	擦 邊	擬 人	擬 人 法	擬 上	擬 文	擬 出	擬 古	
擬 古 體	擬 任	擬 向	擬 有	擬 作	擬 妥	擬 制	擬 定	
擬 於	擬 訂	擬 音	擬 娩	擬 就	擬 圓	擬 像	擬 態	
擬 價	擬 寫	擬 稿	擬 請	擬 請 照 准	擬 調	擬 辦	擬 聲	
擬 議	擬 議 調 停	擱 下	擱 在	擱 到	擱 延	擱 板	擱 架	
擱 起	擱 淺	擱 筆	擱 著	擱 置	擢 發 抽 腸	擢 發 難 數	斂 衣	
斂 性	斂 財	斂 跡	斃 了	斃 而 後 已	斃 命	斃 後	斃 掉	
斃 傷	斃 敵	曙 目	曙 光	曙 色	曙 後 孤 星	曙 後 星 孤	曖 昧	
檀 木	檀 色	檀 郎 謝 女	檀 香	檀 香 山	檀 香 樹	檀 樹	檔 冊	
檔 次	檔 兒	檔 卷	檔 板	檔 案	檔 案 夾	檔 案 局	檔 案 室	
檔 案 資 料	檔 案 學	檔 案 館	檔 期	檔 距	檄 文	檢 出	檢 印	
檢 字	檢 具	檢 定	檢 波	檢 波 器	檢 附	檢 查	檢 查 人	
檢 查 人 員	檢 查 官	檢 查 者	檢 查 表	檢 查 員	檢 查 站	檢 查 組	檢 查 團	
檢 查 點	檢 流 計	檢 疫	檢 疫 所	檢 音 計	檢 音 器	檢 修	檢 索	
檢 索 語 言	檢 討	檢 控	檢 眼 鏡	檢 票	檢 票 員	檢 場	檢 測	
檢 測 器	檢 發	檢 視	檢 視 鏡	檢 電	檢 像 鏡	檢 塵	檢 察	
檢 察 官	檢 察 長	檢 察 員	檢 察 院	檢 察 監 督	檢 察 學	檢 察 機 關	檢 審	
檢 調 單 位	檢 閱	檢 閱 台	檢 閱 使	檢 閱 官	檢 錯	檢 錄	檢 舉	
檢 舉 人	檢 點	檢 驗	檢 驗 人	檢 驗 法	檢 驗 員	櫛 比 鱗 次	櫛 比 鱗 差	
櫛 風 沐 雨	檣 頭	檠 天 架 海	氈 子	氈 衣	氈 呢	氈 笠	氈 帽	
氈 毯	氈 靴	濱 州	濱 海	濱 崎 步	濱 湖	濱 臨	濟 人	
濟 人 利 物	濟 世	濟 世 之 才	濟 世 匡 時	濟 世 安 人	濟 世 安 民	濟 世 安 邦	濟 世 救 人	
濟 世 愛 民	濟 世 經 邦	濟 困 扶 危	濟 河 焚 舟	濟 南	濟 南 市	濟 苦 憐 貧	濟 弱 扶 危	
濟 弱 除 強	濟 時 行 道	濟 時 拯 世	濟 貧	濟 貧 拔 苦	濟 貧 院	濟 勝 之 具	濟 寒 賑 貧	
濟 陽	濟 源	濟 寧	濟 濟	濟 濟 一 堂	濟 濟 彬 彬	濠 溝	濛 濛	
濛 濛 雨	濛 濛 亮	濛 濛 細 雨	濤 聲	濫 占	濫 用	濫 用 職 權	濫 交	
濫 伐	濫 印	濫 吏 贓 官	濫 成	濫 污	濫 官 污 吏	濫 服	濫 施	
濫 砍	濫 砍 濫 伐	濫 竽	濫 竽 充 數	濫 捕	濫 殺	濫 造	濫 減	
濫 發	濫 貼	濫 增	濫 寫	濫 罵	濫 調	濫 墾	濫 攤	
濯 污 揚 清	濯 纓 洗 耳	濯 纓 滄 浪	濯 纓 彈 冠	濯 纓 濯 足	澀 味	澀 的	濡 沫 涸 轍	
濡 濕	濕 布	濕 地	濕 地 中	濕 冷	濕 季	濕 的	濕 度	
濕 度 表	濕 度 計	濕 度 器	濕 度 學	濕 氣	濕 症	濕 疹	濕 淋 淋	
濕 球 溫 度	濕 貨	濕 軟	濕 透	濕 透 了	濕 潤	濕 潤 劑	濕 熱	
濕 漉 漉	濮 上 之 音	濮 上 桑 間	濰 坊	燧 石	燧 石 質	燧 發	營 工	
營 火	營 生	營 田	營 地	營 收	營 利	營 利 事 業 所 得 稅	營 私	
營 私 作 弊	營 私 舞 弊	營 房	營 房 保 障	營 長	營 建	營 建 股	營 建 署	
營 區	營 區 規 劃	營 帳	營 救	營 造	營 造 司	營 造 商	營 部	
營 隊	營 業	營 業 人 員	營 業 收 入	營 業 所	營 業 室	營 業 員	營 業 執 照	
營 業 部	營 業 稅	營 業 額	營 號	營 運	營 寨	營 管	營 盤	
營 銷	營 養	營 養 不 良	營 養 物	營 養 品	營 養 素	營 養 衛 生	營 養 學	
營 壘	燮 和 之 任	燮 理 陰 陽	燦 坤	燦 坤 實 業	燦 然	燦 然 一 新	燦 爛	
燥 者	燥 熱	燭 心	燭 火	燭 台	燭 光	燭 架	燭 淚	
燭 照 數 計	燭 蕊	爵 士	爵 士 音 樂	爵 士 隊	爵 士 舞	爵 士 樂	爵 位	
爵 祿	牆 下	牆 上	牆 上 泥 皮	牆 內	牆 外	牆 有 縫 壁 有 耳	牆 角	
牆 板	牆 泥	牆 花	牆 花 路 柳	牆 花 路 草	牆 前	牆 垣	牆 洞	
牆 面	牆 面 而 立	牆 風 畢 耳	牆 倒 眾 人 推	牆 根	牆 紙	牆 高 基 下	牆 基	
牆 報	牆 腳	牆 裙	牆 裡 開 花 牆 外 香	牆 裡 牆 外	牆 跟	牆 壁	牆 頭	
牆 頭 草	牆 頭 馬 上	牆 體	牆 籬	獰 笑	獰 猛 性	獲 好 評	獲 至	
獲 利	獲 利 者	獲 利 頗 巨	獲 到	獲 取	獲 知	獲 准	獲 益	
獲 益 匪 淺	獲 得	獲 得 者	獲 悉	獲 救	獲 許	獲 赦	獲 鹿	
獲 勝	獲 勝 者	獲 評	獲 頒	獲 獎	獲 獎 人	獲 獎 作 品	獲 獎 者	
獲 選	獲 購	獲 贈	獲 釋	環 山	環 比	環 水	環 式	
環 扣	環 行	環 行 線	環 伺	環 形	環 往	環 抱	環 狀	
環 狀 病 毒	環 肥 燕 瘦	環 保	環 保 局	環 保 部	環 保 署	環 城	環 城 公 路	
環 流	環 面	環 食	環 島	環 氧 乙 烷	環 氧 樹 脂	環 海	環 索	
環 航	環 區	環 堵 蕭 然	環 帶	環 球	環 球 水 泥	環 球 電 視 台	環 視	
環 隆 科 技	環 隆 電 氣	環 節	環 節 動 物	環 路	環 遊	環 道	環 境	
環 境 污 染	環 境 法	環 境 保 護	環 境 品 質 文 教 基 金 會	環 境 衛 生	環 線	環 衛	環 縣	
環 環	環 環 緊 扣	環 礁	環 鍊	環 繞	環 鏡 學	環 顧	環 襯	
環 孢 靈	環 烷	環 烷 烴	璨 然	癆 病	療 方	療 法	療 毒	
療 效	療 程	療 傷	療 傷 止 痛	療 瘡 剜 肉	療 養	療 養 院	癌 狀	
癌 的	癌 病	癌 症	癌 細 胞	癌 腫	癌 瘤	癌 學	癌 變	
盪 舟	瞳 仁	瞳 孔	瞪 了	瞪 大	瞪 眼	瞪 著	瞪 著 眼	
瞪 視	瞪 頭 轉 向	瞰 圖	瞬 息	瞬 息 千 變	瞬 息 萬 變	瞬 時	瞬 時 計	
瞬 間	瞬 間 即 逝	瞧 人	瞧 不 起	瞧 出	瞧 你	瞧 見	瞧 得 起	
瞧 這	瞧 著	瞧 瞧	瞭 如 指 掌	瞭 望 塔	瞭 望 臺	瞭 解	瞭 解 到	
瞭 解 情 況	矯 世 勵 俗	矯 世 變 俗	矯 正	矯 形	矯 言 偽 行	矯 邪 歸 正	矯 枉 過 中	
矯 枉 過 正	矯 枉 過 直	矯 直	矯 柔	矯 矜	矯 若 驚 龍	矯 健	矯 健 敏 捷	
矯 情	矯 情 干 譽	矯 情 自 飾	矯 情 針 物	矯 情 飾 行	矯 情 飾 詐	矯 情 飾 貌	矯 捷	
矯 揉 做 作	矯 揉 造 作	矯 頑 性	矯 飾 者	矯 飾 偽 行	矯 激 奇 詭	矯 寵	磷 化	
磷 化 氫	磷 火	磷 光	磷 灰 石	磷 肥	磷 脂	磷 酸	磷 酸 鈣	
磷 酸 鈉	磷 酸 銨	磷 酸 質	磷 酸 鹽	磷 銨	磷 蝦	磷 磷	磷 礦	
磷 礦 粉	磺 化	磺 酸	磺 胺	磺 胺 類	磯 釣	礁 石	礁 湖	
礁 溪	礁 巖	禪 功	禪 寺	禪 宗	禪 房	禪 林	禪 思	
禪 師	禪 堂	禪 理	禪 學	禪 機	穗 子	穗 狀	穗 帶	
穗 期	穗 軸	穗 選	簇 生	簇 狀	簇 魚 之 禍	簇 魚 堂 燕	簇 新	
簇 葉	簇 擁	簍 子	簍 筐	篾 匠	篾 條	篷 子	篷 形	
篷 車	篷 首 垢 面	篷 馬 車	篷 船	簌 簌	糠 皮	糠 麩	糠 醛	
糜 子	糜 鹿	糜 費	糜 爛	糞 土	糞 池	糞 坑	糞 尿	
糞 車	糞 肥	糞 便	糞 便 學	糞 堆	糞 桶	糞 蛆	糞 蛋	
糟 了	糟 粕	糟 透	糟 塌	糟 踐	糟 踏	糟 糕	糟 糠	
糟 糠 之 妻	糟 糠 之 妻 不 下 堂	糟 蹋	糙 米	縮 力	縮 小	縮 孔	縮 尺	
縮 手 旁 觀	縮 手 縮 腳	縮 支	縮 比	縮 水	縮 印	縮 印 本	縮 合	
縮 回	縮 地 補 天	縮 在	縮 成	縮 肌	縮 衣 節 口	縮 衣 節 食	縮 尾	
縮 到	縮 性	縮 放	縮 放 儀	縮 狀	縮 屋 稱 貞	縮 為	縮 時	
縮 起	縮 排	縮 略	縮 略 詞	縮 略 語	縮 減	縮 減 者	縮 短	
縮 著	縮 進	縮 微	縮 微 工 作	縮 微 本	縮 微 圖 書	縮 圖	縮 緊	
縮 聚	縮 聚 反 應	縮 寫	縮 寫 式	縮 影	縮 編	縮 頭	縮 頭 縮 腳	
縮 頭 縮 腦	縮 瞳 症	縮 縮	縮 簡	績 效	績 效 不 彰	績 溪	繆 以 千 里	
繆 司	繆 托 知 己	繆 采 虛 聲	繆 悠 之 說	縷 花 鋸	縷 縷	繃 住	繃 直	
繃 帶	繃 得	繃 著 臉	繃 開	繃 緊	繃 臉	縫 上	縫 口	
縫 合	縫 合 線	縫 好	縫 成	縫 牢	縫 紉	縫 紉 台	縫 紉 箱	
縫 紉 機	縫 紐 機	縫 起	縫 針	縫 做	縫 得	縫 補	縫 製	
縫 隙	縫 線	縫 縫 補 補	縫 邊	縫 邊 者	總 人 口	總 人 數	總 工	
總 工 程 師	總 工 會	總 不	總 之	總 公 司	總 分	總 支	總 支 出	
總 方 針	總 主 教	總 令	總 冊	總 加	總 可	總 司 令	總 目	
總 目 標	總 目 錄	總 任 務	總 共	總 合	總 成	總 成 本	總 成 績	
總 收 入	總 有	總 而 言 之	總 行	總 兵	總 局	總 攻	總 攻 擊	
總 角 之 交	總 角 之 好	總 供 給	總 協 定	總 和	總 店	總 怪	總 的	
總 的 形 勢	總 的 來 看	總 的 來 說	總 的 說 來	總 社	總 表	總 長	總 則	
總 後	總 後 勤 部	總 按	總 指 揮	總 指 揮 部	總 括	總 政	總 政 治 部	
總 政 策	總 是	總 流 量	總 要	總 計	總 重	總 重 量	總 面 積	
總 值	總 庫	總 書 記	總 站	總 耗	總 能	總 起 來 說	總 院	
總 務	總 動 員	總 參	總 參 謀 長	總 參 謀 部	總 將	總 崩 潰	總 帳	
總 得	總 控	總 教 堂	總 教 練	總 理	總 產	總 產 值	總 產 量	
總 統	總 統 制	總 統 府	總 規 模	總 部	總 章	總 備	總 結	
總 結 工 作	總 結 性	總 結 報 告	總 結 會	總 結 經 驗	總 裁	總 評	總 量	
總 開 銷	總 開 關	總 隊	總 匯	總 幹 事	總 想	總 愛	總 會	
總 會 計 師	總 督	總 經	總 經 理	總 經 濟 師	總 署	總 裝	總 路 線	
總 預 算	總 圖	總 監	總 稱	總 管	總 管 子	總 管 道	總 算	
總 綱	總 罰	總 說	總 閥	總 需 求	總 領 事	總 領 事 館	總 價	
總 價 值	總 廠	總 數	總 數 達	總 編	總 編 輯	總 線	總 罷 工	
總 論	總 賬	總 噸	總 噸 位	總 噸 數	總 機	總 機 構	總 辦	
總 館	總 儲 量	總 營 業 額	總 總	總 趨 勢	總 轄	總 還	總 歸	
總 醫 院	總 額	總 譜	總 纂	總 覽	總 體	總 體 上	總 體 方 案	
總 體 水 平	總 體 佈 局	總 體 規 劃	總 攬	總 攬 全 局	總 鑰 匙	縱 切 麵	縱 火	
縱 火 者	縱 令	縱 任	縱 列	縱 向	縱 帆	縱 曲 枉 直	縱 坐 標	
縱 身	縱 使	縱 波	縱 虎 歸 山	縱 長	縱 風 止 燎	縱 剖 面	縱 容	
縱 座 標	縱 酒	縱 馬 橫 刀	縱 情	縱 情 恣 欲	縱 情 酒 色	縱 情 遂 欲	縱 排	
縱 桿	縱 欲	縱 深	縱 貫	縱 然	縱 軸	縱 隊	縱 隔	
縱 談	縱 論	縱 橫	縱 橫 天 下	縱 橫 交 貫	縱 橫 交 錯	縱 橫 字	縱 橫 馳 騁	
縱 橫 捭 闔	縱 斷 面	縱 覽	縱 觀	繅 絲	繁 文	繁 文 末 節	繁 文 褥 節	
繁 文 縟 節	繁 文 縟 禮	繁 刑 重 賦	繁 刑 重 斂	繁 多	繁 忙	繁 育	繁 弦 急 管	
繁 花 似 錦	繁 星	繁 茂	繁 衍	繁 重	繁 密	繁 盛	繁 殖	
繁 殖 力	繁 殖 者	繁 殖 率	繁 華	繁 華 損 枝	繁 亂	繁 葉 飾	繁 榮	
繁 榮 市 場	繁 榮 昌 盛	繁 榮 富 強	繁 榮 經 濟	繁 瑣	繁 複	繁 蕪	繁 簡	
繁 雜	繁 難	繁 體	繁 體 字	繁 縟	縴 夫	縹 緲	罄 竹 難 書	
翼 形	翼 狀	翼 狀 物	翼 展	翼 側	翼 間 架	翼 龍	翼 翼 小 心	
聲 卡	聲 叫	聲 母	聲 光	聲 名	聲 名 大 振	聲 名 狼 藉	聲 名 狼 籍	
聲 名 鵲 起	聲 色	聲 色 犬 馬	聲 色 狗 馬	聲 色 俱 厲	聲 吞 氣 忍	聲 形	聲 求 氣 應	
聲 言	聲 明	聲 明 者	聲 東 擊 西	聲 波	聲 波 紋	聲 門	聲 威	
聲 威 大 震	聲 律	聲 急	聲 音	聲 音 大	聲 音 笑 貌	聲 息	聲 振 林 大	
聲 效	聲 旁	聲 氣	聲 氣 相 投	聲 氣 相 求	聲 浪	聲 納	聲 能	
聲 能 學	聲 討	聲 區	聲 帶	聲 張	聲 情 並 茂	聲 控	聲 望	
聲 淚 俱 下	聲 速	聲 部	聲 援	聲 揚	聲 腔	聲 象	聲 量	
聲 勢	聲 勢 洶 洶	聲 勢 浩 大	聲 源	聲 跡	聲 電	聲 稱	聲 聞	
聲 聞 過 情	聲 聞 遠 播	聲 語	聲 價 十 倍	聲 嘶 力 竭	聲 樂	聲 樂 家	聲 調	
聲 學	聲 學 家	聲 磬 同 音	聲 頻	聲 壓	聲 應 氣 求	聲 聲	聲 韻	
聲 寶	聲 寶 公 司	聲 覺	聲 譽	聲 譽 好	聲 譽 壞	聲 辯	聲 霸 卡	
聲 響	聰 明	聰 明 人	聰 明 才 智	聰 明 伶 俐	聰 明 能 幹	聰 敏	聰 慧	
聰 慧 過 人	聰 穎	聰 穎 過 人	聯 力	聯 大	聯 友 光 電	聯 戶	聯 手	
聯 句	聯 立 方 程	聯 共	聯 同	聯 名	聯 合	聯 合 公 報	聯 合 王 國	
聯 合 收 割 機	聯 合 行 動	聯 合 作 戰	聯 合 制	聯 合 社	聯 合 者	聯 合 宣 言	聯 合 政 府	
聯 合 國	聯 合 晚 報	聯 合 組 織	聯 合 新 聞 網	聯 合 會	聯 合 演 習	聯 合 機	聯 合 聲 明	
聯 合 勸 募	聯 合 體	聯 在	聯 成	聯 成 一 片	聯 成 一 體	聯 成 石 化	聯 成 食 品	
聯 次	聯 考	聯 行	聯 邦	聯 邦 化	聯 邦 制	聯 邦 政 府	聯 邦 銀 行	
聯 邦 德 國	聯 防	聯 防 區	聯 防 隊	聯 昌	聯 昌 電 子	聯 明 紡 織	聯 社	
聯 信 商 銀	聯 保	聯 姻	聯 建	聯 苯	聯 苯 基	聯 軍	聯 音	
聯 展	聯 展 聯 銷	聯 席	聯 席 會 議	聯 袂	聯 動	聯 婚	聯 強 國 際	
聯 接	聯 產	聯 產 承 包	聯 票	聯 組	聯 貫	聯 發 紡 織	聯 結	
聯 結 車	聯 結 器	聯 絡	聯 絡 小 組	聯 絡 性	聯 絡 員	聯 絡 站	聯 絡 處	
聯 絡 部	聯 華	聯 華 食 品	聯 華 電 子	聯 華 實 業	聯 軸 節	聯 軸 器	聯 隊	
聯 想	聯 會	聯 盟	聯 署	聯 運	聯 網	聯 綿	聯 綿 不 斷	
聯 播	聯 數	聯 翩	聯 誼	聯 誼 會	聯 銷	聯 機	聯 機 服 務	
聯 機 幫 助	聯 辦	聯 營	聯 營 公 司	聯 營 公 車	聯 營 企 業	聯 賽	聯 鎖	
聯 鎖 店	聯 繫	聯 繫 人	聯 繫 著	聯 繫 業 務	聯 繫 群 眾	聯 繫 實 際	聯 繫 點	
聯 歡	聯 歡 性	聯 歡 晚 會	聯 歡 會	聯 歡 節	聳 人 聽 聞	聳 入	聳 入 雲 霄	
聳 出	聳 立	聳 肩	聳 起	聳 動	聳 現	聳 壑 昂 霄	臆 造	
臆 測	臆 想	臆 想 病	臆 斷	臃 腫	膺 任	膺 品	膺 造	
臂 力	臂 章	臂 膀	臂 環	臂 鐲	臀 尖	臀 肌	臀 部	
臀 鰭	膿 口	膿 水	膿 包	膿 汁	膿 血 症	膿 毒 病	膿 疹	
膿 液	膿 痰	膿 腫	膿 瘡	膽 力	膽 力 過 人	膽 大	膽 大 心 細	
膽 大 包 天	膽 大 妄 為	膽 大 如 斗	膽 大 無 敵	膽 子	膽 小	膽 小 如 鼠	膽 小 怕 事	
膽 小 者	膽 小 鬼	膽 汁	膽 石	膽 壯	膽 固 醇	膽 怯	膽 紅 素	
膽 破 心 驚	膽 略	膽 寒	膽 敢	膽 結 石	膽 虛	膽 量	膽 管	
膽 戰 心 寒	膽 戰 心 驚	膽 識	膽 識 過 人	膽 礬	膽 囊	膽 囊 炎	膽 顫 心 寒	
膽 顫 心 驚	膽 驚 心 寒	膽 驚 心 戰	臉 上	臉 子	臉 孔	臉 白	臉 皮	
臉 皮 厚	臉 色	臉 形	臉 兒	臉 的	臉 青 色	臉 型	臉 盆	
臉 盆 架	臉 紅	臉 紅 脖 子 粗	臉 面	臉 蛋	臉 蛋 兒	臉 部	臉 盤	
臉 膛	臉 頰	臉 額	臉 龐	臉 譜	膾 不 厭 細	膾 炙 人 口	臨 了	
臨 下	臨 亡	臨 川	臨 川 羨 魚	臨 文 不 諱	臨 水 登 山	臨 去	臨 去 秋 波	
臨 刑	臨 危	臨 危 下 石	臨 危 不 撓	臨 危 不 懼	臨 危 不 顧	臨 危 自 省	臨 危 自 計	
臨 危 自 悔	臨 危 致 命	臨 危 效 命	臨 危 授 命	臨 危 履 冰	臨 安	臨 死	臨 死 不 怯	
臨 死 不 恐	臨 死 不 懼	臨 死 前	臨 江	臨 老	臨 行	臨 別	臨 別 贈 言	
臨 床	臨 床 試 驗	臨 床 醫 學	臨 村	臨 汾	臨 沂	臨 走	臨 事 而 懼	
臨 到	臨 周	臨 帖	臨 河	臨 河 羨 魚	臨 近	臨 門	臨 城	
臨 為	臨 界	臨 界 角	臨 界 狀 態	臨 界 值	臨 界 溫 度	臨 界 壓	臨 界 點	
臨 盆	臨 軍 對 陣	臨 軍 對 壘	臨 風	臨 風 對 月	臨 食 廢 箸	臨 夏	臨 時	
臨 時 工	臨 時 代 辦	臨 時 性	臨 時 抱 佛 腳	臨 時 政 府	臨 時 動 議	臨 桂	臨 海	
臨 財 不 苟	臨 財 苟 得	臨 陣	臨 陣 脫 逃	臨 陣 磨 槍	臨 高	臨 崖 勒 馬	臨 接	
臨 淵 結 網	臨 淵 羨 魚	臨 深 履 冰	臨 深 履 薄	臨 產	臨 終	臨 場	臨 場 經 驗	
臨 期 失 誤	臨 渴 穿 井	臨 渴 掘 井	臨 街	臨 睡	臨 噎 掘 井	臨 摹	臨 敵 賣 陣	
臨 潼 斗 寶	臨 戰	臨 戰 狀 態	臨 機 制 勝	臨 機 制 變	臨 機 應 變	臨 頭	臨 檢	
臨 難 不 屈	臨 難 不 恐	臨 難 不 避	臨 難 不 懼	臨 難 不 懾	臨 難 鑄 兵	臨 沭	舉 一 反 三	
舉 一 廢 百	舉 人	舉 十 知 九	舉 凡	舉 子	舉 不 勝 舉	舉 反 證	舉 手	
舉 手 加 額	舉 手 可 采	舉 手 扣 額	舉 手 投 足	舉 手 贊 成	舉 止	舉 止 大 方	舉 止 不 凡	
舉 止 失 措	舉 火	舉 世	舉 世 罕 見	舉 世 混 濁	舉 世 莫 比	舉 世 無 比	舉 世 無 倫	
舉 世 無 雙	舉 世 聞 名	舉 世 矚 目	舉 出	舉 目	舉 目 千 里	舉 目 無 親	舉 行	
舉 行 會 談	舉 行 儀 式	舉 兵	舉 步	舉 步 生 風	舉 步 如 飛	舉 步 走	舉 足 輕 重	
舉 事	舉 例	舉 例 發 凡	舉 例 說 明	舉 杯	舉 法	舉 直 措 枉	舉 哀	
舉 要 刪 蕪	舉 要 治 繁	舉 重	舉 重 若 輕	舉 借	舉 個	舉 家	舉 案 齊 眉	
舉 起	舉 酒	舉 酒 作 樂	舉 高	舉 動	舉 國	舉 國 上 下	舉 國 歡 騰	
舉 措	舉 措 失 當	舉 眼 無 親	舉 報	舉 報 人	舉 報 信	舉 棋	舉 棋 不 定	
舉 著	舉 債	舉 鼎 拔 山	舉 鼎 絕 臏	舉 旗	舉 槍	舉 賢 使 能	舉 辦	
舉 辦 者	舉 頭	舉 薦	舉 觴 稱 慶	舉 證	艱 巨	艱 巨 性	艱 危	
艱 困	艱 辛	艱 苦	艱 苦 卓 絕	艱 苦 創 業	艱 苦 奮 鬥	艱 苦 樸 素	艱 深	
艱 險	艱 澀	艱 難	艱 難 曲 折	艱 難 困 苦	艱 難 竭 蹶	艱 難 險 阻	薪 水	
薪 水 冊	薪 金	薪 金 製	薪 津	薪 炭 林	薪 俸	薪 晌	薪 桂 米 珠	
薪 給	薪 資	薪 酬	薪 盡 火 傳	薪 餉	薪 優	薪 優 傭 厚	薄 木 片	
薄 木 板	薄 毛 呢	薄 片	薄 片 形	薄 片 狀	薄 布	薄 皮	薄 冰	
薄 地	薄 收	薄 而 脆	薄 而 透 明	薄 肉 片	薄 舌	薄 衣	薄 利	
薄 利 多 銷	薄 尾 乞 憐	薄 技	薄 命	薄 板	薄 版	薄 物 細 故	薄 的	
薄 厚	薄 待	薄 面	薄 弱	薄 弱 環 節	薄 祚 寒 門	薄 紗	薄 紗 羅	
薄 紙	薄 脆	薄 記 員	薄 情	薄 產	薄 細	薄 荷	薄 荷 油	
薄 荷 腦	薄 荷 醇	薄 軟	薄 雪	薄 棉	薄 棉 布	薄 殼	薄 雲	
薄 煎 餅	薄 義	薄 隔 板	薄 綢	薄 餅	薄 層	薄 暮	薄 膜	
薄 壁	薄 親	薄 鋼	薄 檔	薄 薄	薄 禮	薄 織	薄 霧	
蕾 鈴	薑 片	薑 末	薑 汁	薑 湯	薑 糖	薔 薇	薔 薇 色	
薔 薇 似	薔 薇 園	薯 片	薯 粉	薯 條	薯 類	薊 北	薊 門	
虧 了	虧 心	虧 心 短 行	虧 欠	虧 本	虧 折	虧 空	虧 待	
虧 盈	虧 缺	虧 耗	虧 得	虧 理	虧 短	虧 損	虧 損 面	
虧 損 率	虧 損 額	虧 蝕	虧 錢	蟑 螂	螳 螂	螳 螂 捕 蟬	螳 螂 捕 蟬 黃 雀 在 後	
螳 臂 當 車	蟒 蛇	螫 毒	螻 蛄	螻 蟻	螺 孔	螺 母	螺 攻	
螺 栓	螺 紋	螺 釘	螺 旋	螺 旋 形	螺 旋 性	螺 旋 狀	螺 旋 面	
螺 旋 梯	螺 旋 測 微 器	螺 旋 菌	螺 旋 槳	螺 旋 線	螺 旋 體	螺 旋 鑽	螺 桿	
螺 帽	螺 絲	螺 絲 刀	螺 絲 母	螺 絲 扣	螺 絲 釘	螺 絲 帽	螺 絲 鉗	
螺 絲 錐	螺 絲 鑽	螺 菌	螺 距	螺 號	螺 槍	螺 線	螺 線 管	
螺 螄	蟈 蟈	蟋 蟀	褻 玩	褻 瀆	褻 瀆 者	褶 子	褶 多	
褶 皺	褶 邊	襄 汾	襄 陽	襄 樊	襄 辦	覬 覦	覬 覦 之 心	
覬 覦 之 志	謎 一 般	謎 你 型	謎 你 裝	謎 兒	謎 底	謎 面	謎 宮	
謎 惑	謎 惑 人	謎 團	謎 語	謎 嬉 裝	謎 樣	謎 題	謎 戀	
謙 以 下 士	謙 卑	謙 受 益 滿 招 損	謙 和	謙 恭	謙 恭 下 士	謙 虛	謙 虛 謹 慎	
謙 詞	謙 稱	謙 遜	謙 遜 下 士	謙 謙	謙 謙 下 士	謙 謙 君 子	謙 辭	
謙 讓	講 了	講 人	講 上	講 不 通	講 文 明	講 出	講 出 來	
講 去	講 古 論 今	講 史	講 台	講 成	講 吧	講 完	講 求	
講 求 實 效	講 究	講 究 衛 生	講 來	講 到	講 和	講 明	講 法	
講 的	講 看	講 述	講 述 者	講 個	講 席	講 師	講 座	
講 時	講 書	講 桌	講 笑	講 起	講 唱	講 堂	講 得	
講 情	講 授	講 授 提 綱	講 排 場	講 清	講 清 楚	講 理	講 習	
講 習 所	講 習 班	講 習 會	講 援 提 綱	講 給	講 著	講 評	講 評 官	
講 詞	講 經 說 法	講 義	講 解	講 解 者	講 話	講 話 著	講 道	
講 道 理	講 道 義	講 道 德	講 過	講 實 話	講 演	講 演 者	講 演 會	
講 價	講 價 錢	講 稿	講 衛 生	講 談	講 課	講 課 後	講 壇	
講 學	講 機	講 講	講 禮 貌	講 題	講 讀	謊 言	謊 者	
謊 報	謊 話	謊 稱	謊 說	謊 價	謊 癖	謊 騙	謠 曲	
謠 言	謠 傳	謝 了	謝 天 謝 地	謝 世	謝 你	謝 佳 賢	謝 函	
謝 定	謝 帖	謝 長 廷	謝 卻	謝 客	謝 恩	謝 媒	謝 絕	
謝 詞	謝 意	謝 罪	謝 過	謝 雷	謝 電	謝 幕	謝 霆 鋒	
謝 蕾 絲	謝 謝	謝 謝 你	謝 禮	謝 辭	謄 本	謄 印	謄 書	
謄 清	謄 寫	謄 稿	謄 錄	豁 口	豁 出	豁 出 去	豁 免	
豁 免 權	豁 亮	豁 朗	豁 然	豁 然 大 悟	豁 然 省 悟	豁 然 貫 通	豁 然 開 悟	
豁 然 開 朗	豁 裂	豁 開	豁 達	豁 達 大 度	豁 嘴	賺 了	賺 人	
賺 到	賺 取	賺 得	賺 養 費	賺 錢	賺 頭	賽 力 散	賽 中	
賽 外	賽 似	賽 局	賽 車	賽 事	賽 季	賽 的	賽 前	
賽 後	賽 馬	賽 馬 迷	賽 馬 場	賽 區	賽 情	賽 船	賽 場	
賽 普 勒 斯	賽 程	賽 跑	賽 跑 馬	賽 跑 場	賽 艇	賽 過	賽 過 諸 葛 亮	
賽 點	購 入	購 方	購 用	購 取	購 房	購 物	購 物 中 心	
購 物 者	購 物 單	購 屋	購 建	購 料	購 得	購 票	購 貨	
購 貨 人	購 貨 單	購 買	購 買 力	購 買 方 法	購 進	購 置	購 領	
購 價	購 樓	購 銷	購 銷 兩 旺	購 銷 差 價	購 銷 調 存	購 糧	賸 餘	
賸 餘 物	賸 餘 勞 力	賸 餘 勞 動	賸 餘 勞 動 力	賸 餘 價 值	趨 之	趨 之 若 鶩	趨 光	
趨 光 性	趨 吉 逃 兇	趨 吉 避 兇	趨 同	趨 向	趨 向 於	趨 好	趨 利 避 害	
趨 於	趨 炎 奉 勢	趨 炎 附 勢	趨 炎 附 熱	趨 近	趨 附	趨 附 於	趨 前 退 後	
趨 時	趨 捨 異 路	趨 勢	趨 勢 線	趨 緩	趨 權 附 勢	蹉 跎	蹉 跎 歲 月	
蹈 赴 湯 火	蹈 矩 循 規	蹈 常 襲 故	蹈 規 循 矩	蹈 厲 之 志	蹈 襲	蹊 田 奪 牛	蹊 徑	
蹊 部	蹊 蹺	轄 下	轄 地	轄 制	轄 區	轄 管	輾 軋 聲	
輾 轉	輾 轉 反 側	輾 轉 相 傳	轂 殼	轂 擊 肩 摩	轅 門	轅 馬	輿 論	
輿 論 工 具	輿 論 界	輿 論 監 督	輿 論 導 向	避 人	避 之 惟 恐 不 及	避 世	避 世 離 俗	
避 孕	避 孕 藥	避 兇 趨 吉	避 而 不 談	避 免	避 坑 落 井	避 忌	避 邪	
避 其 銳 氣 擊 其 惰 歸	避 雨	避 重	避 重 就 輕	避 風	避 風 港	避 寒	避 暑	
避 暑 山 莊	避 暑 勝 地	避 稅	避 開	避 亂	避 債	避 嫌	避 碰 規 則	
避 過	避 雷	避 雷 針	避 塵	避 實	避 實 就 虛	避 實 擊 虛	避 禍	
避 禍 就 福	避 彈	避 諱	避 難	避 難 所	避 難 者	避 難 就 易	避 難 港	
遽 然	還 口	還 不	還 元 返 本	還 少	還 手	還 包 括	還 去	
還 可	還 可 以	還 可 能	還 可 與	還 本	還 本 付 息	還 未	還 用	
還 休	還 向	還 回	還 在	還 多	還 好	還 年 輕	還 有	
還 行	還 我	還 把	還 沒	還 沒 有	還 到	還 和	還 押	
還 治 其 人 之 身	還 治 其 身	還 玩	還 長	還 俗	還 很	還 政	還 是	
還 為	還 要	還 借 款	還 原	還 原 劑	還 家	還 席	還 師	
還 書	還 珠 合 浦	還 珠 返 壁	還 笑	還 能	還 將	還 帳	還 得	
還 情	還 淳 反 樸	還 淳 返 樸	還 清	還 都	還 報	還 款	還 童	
還 給	還 貸	還 鄉	還 鄉 團	還 陽	還 債	還 會	還 對	
還 算	還 算 好	還 說	還 魂	還 價	還 嘴	還 賬	還 錢	
還 償	還 應	還 擊	還 禮	還 願	邁 入	邁 出	邁 向	
邁 步	邁 往	邁 阿 密	邁 著	邁 越 常 流	邁 進	邁 開	邁 過	
邂 逅	邂 逅 相 逢	邂 逅 相 遇	邀 功	邀 功 求 賞	邀 功 請 賞	邀 名 射 利	邀 約	
邀 游	邀 集	邀 聘	邀 請	邀 請 者	邀 請 信	邀 請 賽	邀 擊	
醞 釀	醜 八 怪	醜 小 鴨	醜 化	醜 名	醜 老	醜 行	醜 行 邪 事	
醜 事	醜 怪	醜 的	醜 陋	醜 惡	醜 態	醜 態 百 出	醜 聞	
鍍 上	鍍 金	鍍 金 於	鍍 品	鍍 液	鍍 銀	鍍 銅	鍍 鉻	
鍍 層	鍍 鋅	鍍 錫	鎂 光	鎂 光 燈	鎂 合 金	鎂 鋁	鎂 鋁 石	
鎂 礦	錨 爪	錨 固	錨 索	錨 鉤	錨 鍊 孔	鍵 入	鍵 名	
鍵 位	鍵 值	鍵 區	鍵 控	鍵 槽	鍵 盤	鍵 碼	鍵 擊	
鍊 孔	鍊 式	鍊 式 反 應	鍊 住	鍊 形	鍊 板	鍊 軌	鍊 帶	
鍊 接	鍊 條	鍊 球	鍊 球 菌	鍊 傳 動	鍊 路	鍊 輪	鍊 環	
鍊 黴 素	鍥 而 不 捨	鍋 上	鍋 子	鍋 中	鍋 巴	鍋 台	鍋 匠	
鍋 灶	鍋 底	鍋 垢	鍋 圈	鍋 盔	鍋 頂	鍋 貼	鍋 裡	
鍋 蓋	鍋 頭	鍋 鏟	鍋 爐	鍋 爐 室	鍋 粑	錘 子	錘 打	
錘 骨	錘 煉	錘 練	鍾 真	鍾 情	鍾 愛	鍾 榮 吉	鍾 瓊 明	
鍾 瓊 亮	鍾 馗	鍛 工	鍛 工 術	鍛 件	鍛 冶	鍛 材	鍛 制	
鍛 接	鍛 造	鍛 煉	鍛 煉 身 體	鍛 模	鍛 練	鍛 燒	鍛 壓	
鍛 鍊	鍛 錘	鍛 爐	鍛 鐵	鍛 鐵 爐	鍛 鑄	闊 人	闊 少	
闊 地	闊 老	闊 別	闊 步	闊 步 前 進	闊 步 高 談	闊 佬	闊 性	
闊 斧	闊 肩	闊 氣	闊 幅	闊 葉	闊 葉 林	闊 葉 樹	闊 達	
闊 綽	闊 論	闊 論 高 談	闊 邊 帽	闌 尾	闌 尾 炎	闌 珊	隱 士	
隱 世	隱 去	隱 伏	隱 名	隱 式	隱 位	隱 含	隱 形	
隱 形 眼 鏡	隱 忍	隱 沒	隱 私	隱 身	隱 身 技 術	隱 身 飛 機	隱 身 術	
隱 姓 埋 名	隱 居	隱 居 人	隱 居 性	隱 居 者	隱 性	隱 性 埋 名	隱 的	
隱 花	隱 約	隱 約 其 辭	隱 疾	隱 秘	隱 衷	隱 退	隱 退 處	
隱 匿	隱 匿 處	隱 密	隱 患	隱 情	隱 晦	隱 晦 曲 折	隱 現	
隱 處	隱 喻	隱 喻 性	隱 惡 揚 善	隱 痛	隱 暗	隱 跡 埋 名	隱 跡 藏 名	
隱 遁	隱 遁 者	隱 語	隱 慝	隱 憂	隱 蔽	隱 蔽 所	隱 蔽 處	
隱 蔽 著	隱 瞞	隱 諱	隱 檢	隱 避 處	隱 隱	隱 隱 約 約	隱 藏	
隱 藏 所	隱 藏 物	隱 藏 處	隸 書	隸 農	隸 農 制	隸 屬	隸 屬 於	
雖 小	雖 已	雖 之	雖 未	雖 休 勿 休	雖 有	雖 死 猶 生	雖 則	
雖 是	雖 能 用	雖 然	雖 經	雖 對	雖 說	雖 覆 能 復	霜 天	
霜 白	霜 狀	霜 花	霜 降	霜 凍	霜 害	霜 晨	霜 雪	
霜 期	霜 葉	霜 露 之 思	霜 鬢	霞 石	霞 光	霞 雲	霞 蔚	
霞 輝	鞠 躬	鞠 躬 盡 瘁	鞠 躬 盡 瘁 死 而 後 已	韓 文	韓 非	韓 信	韓 城	
韓 海 蘇 潮	韓 曼	韓 國	韓 國 人	韓 康 賣 藥	韓 朝 蘇 海	韓 愈	韓 壽 分 香	
韓 壽 偷 香	韓 戰	韓 盧 逐 塊	韓 盧 逐 逡	顆 粒	顆 粒 狀	颶 風	餵 奶	
餵 食	餵 給	餵 飽	餵 養	騁 用	駿 馬	鮮 奶	鮮 有	
鮮 肉	鮮 血	鮮 衣 美 食	鮮 見	鮮 味	鮮 明	鮮 果	鮮 花	
鮮 亮	鮮 活	鮮 為 人 知	鮮 紅	鮮 紅 色	鮮 美	鮮 食	鮮 爽	
鮮 蛋	鮮 貨	鮮 魚	鮮 菜	鮮 嫩	鮮 綠	鮮 綠 色	鮮 聞	
鮮 蝦	鮮 麗	鮮 艷	鮮 艷 奪 目	鮭 魚	鴻 友 科 技	鴻 毛	鴻 毛 泰 山	
鴻 志	鴻 恩	鴻 書	鴻 案 鹿 車	鴻 海 精 密	鴻 稀 鱗 絕	鴻 雁	鴻 業	
鴻 溝	鴻 運	鴻 運 電 子	鴻 圖	鴻 福	鴻 篇 巨 製	鴻 篇 巨 帙	鴻 儒	
鴻 鵠	鴻 鵠 之 志	鴿 子	鴿 派	鴿 群	鴿 籠	麋 至 沓 來	麋 沸 蟻 動	
麋 沸 蟻 聚	麋 鹿	黏 土	黏 合 劑	黏 米	黏 性	黏 附	黏 度	
黏 液	黏 結	黏 著 物	黏 膜	黏 膠	黏 蟲	點 了	點 人	
點 人 數	點 上	點 子	點 化	點 心	點 心 坊	點 火	點 火 孔	
點 火 器	點 出	點 半	點 卯	點 石 成 金	點 穴	點 交	點 名	
點 名 簿	點 在	點 好	點 收	點 兒	點 到 為 止	點 定	點 明	
點 金 成 鐵	點 亮	點 穿	點 面 結 合	點 射	點 破	點 陣	點 陣 式	
點 唱	點 將	點 清	點 焊	點 球	點 眼	點 描 法	點 畫	
點 發	點 著	點 菜	點 評	點 煙	點 煙 斗	點 號	點 電 荷	
點 歌	點 滴	點 種	點 綴	點 綴 著	點 撥	點 播	點 數	
點 閱	點 燈	點 燃	點 錢	點 頭	點 頭 哈 腰	點 戲	點 擊	
點 檢	點 點	點 點 滴 滴	點 題	點 鐘	點 鐵 成 金	點 驗	黜 免	
黜 陟 幽 明	黝 黑	黝 暗	黝 黝	黛 綠	鼾 睡	鼾 聲	齋 心 滌 慮	
齋 月	齋 戒	齋 居 蔬 食	齋 期	齋 飯	叢 山	叢 中	叢 木	
叢 毛	叢 刊	叢 生	叢 林	叢 林 戰	叢 狀	叢 書	叢 密	
叢 莽	叢 集	叢 樹	嚕 嗦	嚕 聲	嚮 往	嚮 導	壘 球	
壘 障	嬸 子	嬸 母	嬸 兒	嬸 娘	嬸 婆	嬸 嬸	彝 族	
戳 子	戳 印	戳 穿	戳 破	戳 記	戳 進	戳 傷	擴 大	
擴 大 化	擴 大 出 口	擴 大 生 產	擴 大 再 生 產	擴 大 其 詞	擴 大 會	擴 大 會 議	擴 大 器	
擴 及	擴 充	擴 充 產 能	擴 用	擴 印	擴 延	擴 征	擴 股	
擴 建	擴 建 工 程	擴 為	擴 界	擴 軍	擴 軍 計 劃	擴 軍 備 戰	擴 音	
擴 音 器	擴 音 機	擴 容	擴 展	擴 展 名	擴 展 到	擴 展 性	擴 張	
擴 張 主 義 者	擴 張 政 策	擴 散	擴 編	擴 頻	擴 頻 通 信	擲 下	擲 出	
擲 回	擲 地 之 材	擲 地 有 聲	擲 地 作 金 玉 聲	擲 至	擲 拋	擲 果 盈 車	擲 棒	
擲 鼠 忌 器	擲 骰 子	擲 彈 筒	擲 環	擾 民	擾 動	擾 亂	擾 亂 性	
擾 頻	擾 擾	擾 嚷	攆 走	攆 跑	攆 開	擺 了	擺 上	
擺 子	擺 手	擺 出	擺 平	擺 正	擺 列	擺 在	擺 在 面 前	
擺 在 首 位	擺 好	擺 成	擺 佈	擺 尾 搖 頭	擺 弄	擺 到 桌 面 上 來	擺 放	
擺 明	擺 的	擺 空 架 子	擺 姿 勢	擺 架 子	擺 個	擺 宴	擺 臭	
擺 臭 架 子	擺 酒	擺 動	擺 掉	擺 脫	擺 脫 困 境	擺 設	擺 渡	
擺 著	擺 開	擺 飾	擺 滿	擺 舞	擺 齊	擺 樣 子	擺 線	
擺 輪	擺 蕩	擺 闊	擺 闊 氣	擺 擺	擺 譜	擺 鐘	擺 攤	
擺 攤 設 點	擷 取	斷 了	斷 了 奶	斷 力	斷 口	斷 子 絕 孫	斷 井 頹 垣	
斷 水	斷 片	斷 牙	斷 代	斷 代 史	斷 句	斷 奶	斷 交	
斷 尾 雄 雞	斷 決 如 流	斷 言	斷 言 者	斷 乳	斷 定	斷 弦	斷 念	
斷 怪 除 妖	斷 枝	斷 炊	斷 肢	斷 長 補 短	斷 長 續 短	斷 垣 殘 壁	斷 後	
斷 流	斷 面	斷 面 圖	斷 音	斷 食	斷 案	斷 根	斷 根 絕 種	
斷 氣	斷 紙 餘 墨	斷 航	斷 送	斷 骨	斷 崖	斷 從	斷 掉	
斷 梗 流 萍	斷 梗 飛 蓬	斷 袖 之 寵	斷 袖 分 桃	斷 釵 重 合	斷 章 取 義	斷 章 截 句	斷 章 摘 句	
斷 幅 殘 紙	斷 然	斷 然 拒 絕	斷 絕	斷 絕 關 係	斷 裂	斷 裂 帶	斷 裂 強 度	
斷 開	斷 雁 孤 鴻	斷 煙	斷 腸	斷 路	斷 路 器	斷 電	斷 種	
斷 語	斷 魂	斷 劍	斷 層	斷 層 帶	斷 編 殘 簡	斷 線	斷 線 風 箏	
斷 線 鷂 子	斷 髮 文 身	斷 壁 殘 垣	斷 壁 頹 垣	斷 頭	斷 頭 台	斷 頭 將 軍	斷 檔	
斷 點	斷 斷	斷 斷 續 續	斷 簡 殘 編	斷 糧	斷 離	斷 爛 朝 報	斷 續	
斷 續 性	斷 鶴 續 鳧	斷 齏 畫 粥	朦 的	朦 朦	朦 朧	檳 榔	檳 榔 島	
檳 榔 膏	檳 榔 樹	檳 榔 嶼	檬 樹	櫃 上	櫃 子	櫃 台	櫃 房	
櫃 架	櫃 組	櫃 船	櫃 買 中 心	櫃 檯 中 心	櫃 檯 買 賣 中 心	櫃 櫥	檻 猿 籠 鳥	
檸 檬	檸 檬 水	檸 檬 色	檸 檬 酸	檸 檬 樹	檯 子	歸 一	歸 入	
歸 口	歸 己	歸 仁	歸 仁 鄉	歸 公	歸 化	歸 天	歸 心	
歸 心 如 箭	歸 心 似 箭	歸 功	歸 功 於	歸 去	歸 去 來 兮	歸 正 反 本	歸 正 反 當	
歸 正 首 丘	歸 田	歸 由	歸 全 反 真	歸 向	歸 因	歸 因 於	歸 老 菟 裘	
歸 西	歸 位	歸 邪 反 正	歸 邪 轉 曜	歸 並	歸 依	歸 來	歸 到	
歸 咎	歸 咎 於	歸 奇 顧 怪	歸 於	歸 返	歸 附	歸 為	歸 降	
歸 家	歸 案	歸 根	歸 根 到 底	歸 根 結 底	歸 根 結 蒂	歸 真 反 璞	歸 真 返 璞	
歸 納	歸 納 法	歸 納 推 理	歸 納 邏 輯	歸 航	歸 馬 放 牛	歸 國	歸 國 者	
歸 宿	歸 巢	歸 教 育	歸 途	歸 期	歸 程	歸 結	歸 結 於	
歸 隊	歸 集	歸 順	歸 置	歸 罪	歸 罪 於	歸 路	歸 僑	
歸 墊	歸 誰	歸 檔	歸 總	歸 還	歸 隱	歸 攏	歸 類	
歸 類 於	歸 屬	殯 葬	殯 葬 業	殯 儀	殯 儀 館	殯 殮	瀉 出	
瀉 肚	瀉 密	瀉 漏	瀉 憤	瀉 藥	瀉 鹽	瀋 陽	瀋 陽 市	
瀋 陽 軍 區	濾 斗	濾 去	濾 光	濾 池	濾 色 鏡	濾 取	濾 波	
濾 波 器	濾 毒	濾 紙	濾 除	濾 掉	濾 液	濾 清	濾 過	
濾 嘴	濾 膜	濾 器	瀆 者	瀆 神	瀆 職	瀆 職 罪	濺 水	
濺 出	濺 污	濺 射	濺 起 來	濺 迸	濺 酒	濺 散	濺 開	
濺 溢	濺 落	濺 潑	濺 濕	瀑 布	瀏 覽	瀏 覽 者	瀏 覽 器	
燻 黑	燻 黑 了	獷 悍	獵 人	獵 刀	獵 戶	獵 手	獵 犬	
獵 兔	獵 兔 狗	獵 到	獵 取	獵 奇	獵 物	獵 狗	獵 食	
獵 捕	獵 區	獵 殺	獵 鳥	獵 鳥 者	獵 鹿	獵 場	獵 裝	
獵 獲	獵 鎗	獵 鷹	璧 合 珠 連	甕 中 之 鱉	甕 中 捉 鱉	甕 天 蠡 海	甕 裡 醯 雞	
甕 盡 杯 乾	甕 牖 繩 樞	甕 聲 甕 氣	癖 好	癖 性	癒 合	瞽 言 妄 舉	瞻 天 戀 闕	
瞻 仰	瞻 前 忽 後	瞻 前 顧 後	瞻 望	瞻 養	禮 士 親 賢	禮 不 親 授	禮 之 用 和 為 貴	
禮 多 人 不 怪	禮 成	禮 券	禮 尚 往 來	禮 服	禮 法	禮 物	禮 花	
禮 金	禮 俗	禮 冠	禮 品	禮 拜	禮 拜 一	禮 拜 二	禮 拜 三	
禮 拜 五	禮 拜 六	禮 拜 天	禮 拜 日	禮 拜 四	禮 拜 式	禮 拜 室	禮 拜 堂	
禮 炮	禮 堂	禮 奢 寧 儉	禮 崩 樂 壞	禮 帶	禮 教	禮 盒	禮 部	
禮 單	禮 帽	禮 無 不 答	禮 順 人 情	禮 節	禮 節 性	禮 義 廉 恥	禮 聘	
禮 遇	禮 貌	禮 貌 待 客	禮 賓	禮 賓 司	禮 輕	禮 輕 人 意 重	禮 輕 情 義 重	
禮 餅	禮 儀	禮 廢 樂 崩	禮 數	禮 樂	禮 樂 崩 壞	禮 盤	禮 賢	
禮 賢 下 士	禮 賢 接 士	禮 賢 遠 佞	禮 壞 樂 缺	禮 壞 樂 崩	禮 讓	禮 讓 為 國	禮 讚	
穢 名	穢 行	穢 物	穢 淫	穢 跡	穢 聞	穢 語	竄 入	
竄 出	竄 犯	竄 改	竄 逃	竄 匿	竄 進	竄 擾	竅 門	
簫 韶 九 成	簧 片	簧 舌	簧 秤	簪 纓 世 冑	簪 纓 門 第	簞 食 壺 漿	簞 食 瓢 飲	
簞 瓢 陋 巷	簞 瓢 屢 空	簡 介	簡 分	簡 化	簡 化 字	簡 化 漢 字	簡 令	
簡 冊	簡 史	簡 本	簡 札	簡 在 帝 心	簡 字	簡 而 言 之	簡 作	
簡 扼	簡 言 之	簡 並	簡 易	簡 明	簡 明 扼 要	簡 況	簡 直	
簡 直 不	簡 表	簡 便	簡 則	簡 拼	簡 括	簡 政	簡 約	
簡 要	簡 述	簡 陋	簡 納	簡 記	簡 訊	簡 除	簡 捷	
簡 略	簡 章	簡 單	簡 單 化	簡 單 生 產	簡 單 再 生 產	簡 單 多 數	簡 單 扼 要	
簡 單 易 學	簡 單 勞 動	簡 單 機 械	簡 報	簡 復	簡 短	簡 陽	簡 愛	
簡 煉	簡 義	簡 裝	簡 劃	簡 圖	簡 慢	簡 截 了 當	簡 稱	
簡 儀	簡 寫	簡 潔	簡 碼	簡 練	簡 編	簡 論	簡 樸	
簡 歷	簡 諧	簡 縮	簡 繁	簡 簡 單 單	簡 牘	簡 譜	簡 體	
簡 體 字	糧 人	糧 戶	糧 本	糧 田	糧 多 草 廣	糧 行	糧 谷	
糧 店	糧 油	糧 食	糧 食 局	糧 倉	糧 庫	糧 秣	糧 站	
糧 荒	糧 草	糧 票	糧 船	糧 袋	糧 棧	糧 棉	糧 款	
糧 農	糧 農 組 織	糧 道	糧 盡 援 絕	糧 管 所	糧 餉	糧 價	織 了	
織 入	織 女	織 女 星	織 工	織 出	織 布	織 布 機	織 田 裕 二	
織 合	織 在	織 式	織 成	織 法	織 物	織 品	織 染	
織 為	織 造	織 著	織 補	織 補 物	織 網	織 廠	織 機	
織 錦	織 錦 回 文	織 錦 畫	織 錦 緞	織 邊	織 襪	繕 甲 治 兵	繕 甲 厲 兵	
繞 一 週	繞 口	繞 口 令	繞 以	繞 回	繞 地 球	繞 成	繞 舌	
繞 行	繞 行 者	繞 來 繞 去	繞 物	繞 指 柔 腸	繞 射	繞 航	繞 圈	
繞 圈 子	繞 組	繞 脖	繞 脖 子	繞 著	繞 開	繞 毓	繞 路	
繞 道	繞 道 而 行	繞 過	繞 遠	繞 嘴	繞 樑 之 音	繞 蟲	繞 彎	
繚 亂	繚 繞	繡 口 錦 心	繡 衣	繡 法	繡 花	繡 花 枕 頭	繡 虎 雕 龍	
繡 品	繡 球	繡 鞋	繡 邊	罈 子	翹 企	翹 曲	翹 尾	
翹 尾 巴	翹 足 引 領	翹 拇 指	翹 首	翹 首 引 源	翹 首 引 領	翹 首 以 待	翹 首 企 足	
翹 起	翹 望	翹 著	翹 楚	翹 嘴	翹 辮	翹 辮 子	翻 一 番	
翻 了	翻 了 一 番	翻 入	翻 土	翻 山	翻 山 越 嶺	翻 天	翻 天 復 地	
翻 天 覆 地	翻 手 為 雲	翻 手 為 雲 覆 手 雨	翻 出	翻 去	翻 本	翻 印	翻 地	
翻 成	翻 江 倒 海	翻 作	翻 弄	翻 把	翻 找	翻 折	翻 沙 覆 地	
翻 身	翻 車	翻 供	翻 來	翻 來 覆 去	翻 兩 番	翻 到	翻 拌	
翻 拍	翻 炒	翻 版	翻 花	翻 建	翻 查	翻 看	翻 砂	
翻 胃	翻 觔 斗	翻 頁	翻 飛	翻 倒	翻 修	翻 唇 弄 舌	翻 悔	
翻 書	翻 案	翻 起	翻 動	翻 掘	翻 掉	翻 船	翻 造	
翻 造 品	翻 尋	翻 揀	翻 椅	翻 然 改 圖	翻 然 悔 悟	翻 牌	翻 番	
翻 著	翻 越	翻 開	翻 雲 覆 雨	翻 黃	翻 黃 倒 皂	翻 新	翻 路	
翻 跳	翻 過	翻 過 來	翻 滾	翻 蓋	翻 領	翻 箱 倒 櫃	翻 箱 倒 籠	
翻 箱 倒 篋	翻 閱	翻 錄	翻 檢	翻 臉	翻 翻	翻 覆	翻 覆 無 常	
翻 轉	翻 譯	翻 譯 人 員	翻 譯 者	翻 譯 員	翻 譯 家	翻 譯 理 論	翻 譯 學	
翻 譯 機	翻 騰	翻 曬	翻 茬	職 大	職 工	職 工 代 表	職 工 代 表 大 會	
職 工 收 入	職 工 食 堂	職 工 隊 伍	職 工 福 利 待 遇	職 代 會	職 司	職 守	職 位	
職 位 高	職 別	職 官	職 前 教 育	職 員	職 校	職 能	職 能 部 門	
職 務	職 務 上	職 務 工 資	職 務 考 核	職 務 津 貼	職 責	職 掌	職 棒	
職 業	職 業 上	職 業 工 會	職 業 化	職 業 足 球	職 業 性	職 業 咨 詢	職 業 病	
職 業 高 中	職 業 高 爾 夫 球	職 業 培 訓	職 業 教 育	職 業 階 級	職 業 傷 害	職 業 運 動	職 業 道 德	
職 業 摔 角	職 業 網 球	職 業 輔 導	職 業 撞 球	職 業 學 校	職 稱	職 稱 改 革	職 稱 評 定	
職 銜	職 數	職 籃	職 權	職 權 範 圍	聶 耳	聶 聶	臍 狀	
臍 帶	舊 了	舊 中 國	舊 仇	舊 仇 新 恨	舊 友	舊 日	舊 欠	
舊 民 主 主 義 革 命	舊 石 器	舊 交	舊 名	舊 地	舊 地 重 遊	舊 好	舊 年	
舊 式	舊 有	舊 衣	舊 作	舊 址	舊 車	舊 事	舊 例	
舊 制	舊 姓	舊 居	舊 念 復 萌	舊 性	舊 法	舊 版	舊 物	
舊 的	舊 社 會	舊 者	舊 金	舊 金 山	舊 雨 今 雨	舊 俗	舊 品	
舊 城	舊 思 想	舊 恨	舊 恨 新 仇	舊 是	舊 約	舊 家 行 徑	舊 料	
舊 時	舊 時 代	舊 時 風 味	舊 書	舊 案	舊 框 框	舊 疾	舊 病	
舊 病 復 發	舊 病 難 醫	舊 國	舊 帳	舊 情	舊 教	舊 瓶 裝 新 酒	舊 習	
舊 習 慣	舊 船	舊 貨	舊 貨 商	舊 部	舊 都	舊 惡	舊 費	
舊 債	舊 愛 宿 恩	舊 詩	舊 話	舊 跡	舊 夢	舊 幣	舊 態 復 萌	
舊 稱	舊 聞	舊 貌	舊 劇	舊 調	舊 調 重 彈	舊 賬	舊 學	
舊 歷	舊 燕 歸 巢	舊 識 新 交	舊 觀	藏 人	藏 刀	藏 之 名 山	藏 文	
藏 民	藏 在	藏 好	藏 形 匿 影	藏 身	藏 所	藏 物	藏 者	
藏 青	藏 品	藏 垢	藏 垢 納 污	藏 室	藏 屍	藏 胞	藏 香	
藏 書	藏 書 家	藏 書 癖	藏 起	藏 酒	藏 骨 堂	藏 匿	藏 族	
藏 處	藏 富	藏 著	藏 間	藏 經	藏 躲	藏 語	藏 嬌	
藏 諸 名 山	藏 鋒 斂 鍔	藏 器 待 時	藏 學	藏 歷	藏 頭 亢 腦	藏 頭 露 尾	藏 龍 臥 虎	
藏 戲	藏 藍	藏 蹤	藏 醫	藏 藥	藏 寶	薩 伊	薩 克 斯	
薩 拉 熱 窩	薩 哈 林 島	薩 特	薩 爾 瓦 多	薩 爾 瓦 多 共 和 國	薩 摩 亞 群 島	藍 天	藍 天 電 腦	
藍 心 湄	藍 布	藍 本	藍 田 出 玉	藍 田 生 玉	藍 皮	藍 皮 書	藍 字	
藍 色	藍 波	藍 的	藍 花	藍 青	藍 鳥	藍 晶 石	藍 黑	
藍 圖	藍 綠	藍 銅 礦	藍 領	藍 調	藍 橋	藍 靛	藍 點	
藍 藍	藍 鯨	藍 寶 石	藍 藻	藐 小	藐 視	藉 口	藉 以	
藉 由	藉 此	藉 其	藉 故	藉 著	藉 詞	藉 機	藉 機 報 復	
薰 上	薰 以	薰 制	薰 香	薦 引	薦 任	薦 者	薦 賢	
薦 舉	蟯 蟲	蟬 紗	蟬 鳴	蟬 翼	蟬 翼 紗	蟬 聯	蟲 子	
蟲 孔	蟲 牙	蟲 卵	蟲 沙 猿 鶴	蟲 災	蟲 兒	蟲 狀	蟲 害	
蟲 病	蟲 草	蟲 情	蟲 眼	蟲 蛀	蟲 魚	蟲 鳴	蟲 膠	
蟲 聲	蟲 臂 鼠 肝	蟲 藥	蟲 類	蟠 桃	覆 上	覆 亡	覆 水 不 收	
覆 水 難 收	覆 以	覆 去 番 來	覆 去 翻 來	覆 地 翻 天	覆 有	覆 舟	覆 舟 之 戒	
覆 舟 載 舟	覆 沒	覆 車 之 戒	覆 車 之 軌	覆 車 之 轍	覆 車 之 鑒	覆 車 繼 軌	覆 命	
覆 宗 絕 嗣	覆 宗 滅 祀	覆 盂 之 安	覆 盂 之 固	覆 雨 翻 雲	覆 信	覆 查	覆 盆	
覆 盆 之 冤	覆 盆 難 照	覆 軍 殺 將	覆 面	覆 面 物	覆 核	覆 海 移 山	覆 巢 破 卵	
覆 巢 無 完 卵	覆 巢 傾 卵	覆 巢 毀 卵	覆 鹿 尋 蕉	覆 鹿 遺 蕉	覆 著	覆 滅	覆 蓋	
覆 蓋 物	覆 蓋 面	覆 蓋 率	覆 蓋 圖	覆 審	覆 蕉 尋 鹿	覆 轍	覆 議	
覆 護	覆 疊	謹 上	謹 小 慎 微	謹 向	謹 守	謹 此	謹 呈	
謹 言 慎 行	謹 防	謹 啟	謹 終 追 遠	謹 訪	謹 慎	謹 慎 從 事	謹 嚴	
謬 見	謬 種	謬 種 流 傳	謬 誤	謬 說	謬 獎	謬 論	謫 居	
豐 功	豐 功 厚 利	豐 功 偉 業	豐 功 偉 績	豐 功 盛 烈	豐 功 懋 烈	豐 台 區	豐 田	
豐 年	豐 年 祭	豐 年 稔 歲	豐 收	豐 收 在 望	豐 收 年	豐 衣	豐 衣 足 食	
豐 亨 豫 大	豐 沛	豐 足	豐 取 刻 與	豐 厚	豐 城	豐 為 圭 臬	豐 盈	
豐 美	豐 茂	豐 原	豐 泰	豐 泰 企 業	豐 產	豐 產 田	豐 盛	
豐 都	豐 富	豐 富 多 采	豐 富 多 彩	豐 腴	豐 匯	豐 碑	豐 裕	
豐 滿	豐 碩	豐 碩 成 果	豐 潤	豐 縣	豐 興 鋼 鐵	豐 餐	豐 濱 鄉	
豐 議	豐 贍	豐 饒	贅 生	贅 生 物	贅 言	贅 物	贅 述	
贅 筆	贅 詞	贅 語	贅 瘤	蹙 眉	蹙 國 喪 師	蹙 額	蹣 跚	
蹣 跚 而 行	蹦 跳	蹦 蹦	蹦 蹦 跳 跳	蹤 跡	蹤 跡 詭 秘	蹤 影	軀 殼	
軀 幹	軀 骸	軀 體	轉 入	轉 口	轉 子	轉 干	轉 化	
轉 手	轉 手 倒 賣	轉 文	轉 斗 千 里	轉 日 回 天	轉 世	轉 付	轉 出	
轉 包	轉 包 人	轉 去	轉 正	轉 民	轉 用	轉 由	轉 交	
轉 任	轉 印	轉 危 為 安	轉 向	轉 向 下	轉 向 器	轉 回	轉 好	
轉 存	轉 守	轉 成	轉 托	轉 收	轉 死 溝 渠	轉 死 溝 壑	轉 而	
轉 至	轉 行	轉 位	轉 位 期	轉 位 器	轉 作	轉 呈	轉 告	
轉 抄	轉 折	轉 折 點	轉 折 關 頭	轉 投 資	轉 攻	轉 災 為 福	轉 角	
轉 身	轉 車	轉 供	轉 來	轉 兒	轉 到	轉 受 讓 方	轉 往	
轉 念	轉 門	轉 亮	轉 型	轉 為	轉 科	轉 軌	轉 軌 變 型	
轉 述	轉 借	轉 借 人	轉 借 者	轉 差 率	轉 庫	轉 恣 跋 扈	轉 校	
轉 矩	轉 租	轉 租 人	轉 送	轉 動	轉 動 慣 量	轉 售	轉 圈	
轉 寄	轉 帳	轉 強	轉 悠	轉 接	轉 接 器	轉 捩 點	轉 敗 為 功	
轉 敗 為 成	轉 敗 為 勝	轉 桿	轉 欲 難 成	轉 率	轉 產	轉 眼	轉 眼 之 間	
轉 移	轉 移 性	轉 舵	轉 船	轉 速	轉 速 計	轉 勝	轉 喻	
轉 場	轉 報	轉 悲 為 喜	轉 換	轉 換 公 司 債	轉 換 器	轉 晴	轉 椅	
轉 款	轉 殖	轉 游	轉 發	轉 發 器	轉 結	轉 給	轉 著	
轉 貸	轉 軸	轉 進	轉 開	轉 嫁	轉 愁 為 喜	轉 業	轉 業 軍 人	
轉 業 幹 部	轉 義	轉 載	轉 運	轉 道	轉 達	轉 過	轉 過 來	
轉 禍 為 福	轉 精 覃 思	轉 遞	轉 憂 為 喜	轉 撥	轉 播	轉 播 站	轉 數	
轉 盤	轉 蓬	轉 請	轉 調	轉 賣	轉 賣 給	轉 輪	轉 學	
轉 戰	轉 戰 千 里	轉 機	轉 辦	轉 錄	轉 頭	轉 儲	轉 環	
轉 瞬	轉 瞬 之 間	轉 瞬 間	轉 臉	轉 歸	轉 轉	轉 轉 相 因	轉 贈	
轉 韻	轉 爐	轉 譯	轉 彎	轉 彎 子	轉 彎 抹 角	轉 彎 處	轉 變	
轉 變 期	轉 體	轉 讓	轍 痕	轍 亂 旗 靡	轍 環 天 下	轍 鮒 之 急	邈 若 山 河	
醫 士	醫 大	醫 不 好	醫 方	醫 生	醫 用	醫 好	醫 治	
醫 治 者	醫 治 無 效	醫 者	醫 科	醫 師	醫 時 救 弊	醫 書	醫 案	
醫 病	醫 神	醫 院	醫 務	醫 務 人 員	醫 務 工 作 者	醫 務 室	醫 專	
醫 術	醫 傷 用	醫 道	醫 德	醫 學	醫 學 上	醫 學 士	醫 學 心 理 學	
醫 學 界	醫 學 家	醫 學 院	醫 療	醫 療 事 故	醫 療 糾 紛	醫 療 保 險	醫 療 美 容	
醫 療 費	醫 療 隊	醫 療 資 訊	醫 療 衛 生	醫 療 器 材	醫 療 藥 品	醫 醫	醫 藥	
醫 藥 費	醫 藥 衛 生	醫 藥 學	醫 護	醫 護 人 員	醫 囑	醬 汁	醬 瓜	
醬 肉	醬 色	醬 豆	醬 油	醬 缸	醬 料	醬 紫	醬 菜	
醬 園	釐 金	鎖 人	鎖 上	鎖 孔	鎖 匠	鎖 好	鎖 扣	
鎖 住	鎖 具	鎖 定	鎖 店	鎖 門	鎖 骨	鎖 匙	鎖 國	
鎖 眼	鎖 著	鎖 緊	鎖 線	鎖 頻	鎖 頭	鎖 縫	鎖 鍊	
鎖 櫃	鎖 簧	鎢 砂	鎢 粉	鎢 絲	鎢 絲 燈	鎢 燈	鎢 錳	
鎢 鋼	鎢 礦	鎢 鉬	鎳 材	鎳 氫 電 池	鎳 鈷	鎳 幣	鎳 箔	
鎳 鉻	鎳 鉻 絲	鎳 鋼	鎳 礦	鎮 上	鎮 子	鎮 公 所	鎮 反	
鎮 代 表	鎮 民	鎮 企	鎮 守	鎮 江	鎮 住	鎮 定	鎮 定 自 若	
鎮 定 物	鎮 定 劑	鎮 長	鎮 流 器	鎮 區	鎮 痛	鎮 痛 物	鎮 痛 劑	
鎮 痛 藥	鎮 裡	鎮 寧	鎮 暴	鎮 靜	鎮 靜 自 若	鎮 靜 劑	鎮 壓	
鎮 壓 者	鎬 頭	闖 入	闖 入 者	闖 出	闖 事	闖 勁	闖 紅 燈	
闖 將	闖 進	闖 過	闖 禍	闖 蕩	闖 關	闕 文	闕 事	
離 了	離 土 不 離 鄉	離 子	離 子 化	離 子 交 換 樹 脂	離 不	離 不 開	離 不 遠	
離 心	離 心 力	離 心 率	離 心 機	離 心 離 德	離 手	離 世	離 去	
離 石	離 休	離 休 幹 部	離 任	離 合	離 合 詩	離 合 器	離 地	
離 你	離 別	離 身	離 京	離 奇	離 岸	離 弦	離 弦 之 箭	
離 性	離 析	離 法	離 者	離 恨	離 軌	離 家	離 家 出 走	
離 島	離 差	離 席	離 座	離 校	離 格	離 退 休	離 婁 之 明	
離 婚	離 婚 者	離 婚 證	離 崗	離 得	離 得 開	離 您	離 情	
離 棄	離 異	離 散	離 散 化	離 著	離 鄉	離 鄉 背 井	離 開	
離 間	離 隊	離 愁	離 經	離 經 叛 道	離 群	離 群 索 居	離 解	
離 境	離 遠	離 層	離 輻	離 職	離 題	離 題 萬 里	離 譜	
離 騷	離 鸞 別 鳳	雜 七 雜 八	雜 工	雜 文	雜 木	雜 木 林	雜 史	
雜 用	雜 交	雜 交 牛	雜 交 育 種	雜 交 種	雜 多	雜 曲	雜 色	
雜 役	雜 技	雜 技 場	雜 技 團	雜 言	雜 事	雜 居	雜 店	
雜 念	雜 拌	雜 物	雜 物 室	雜 肥	雜 品	雜 活	雜 耍	
雜 耍 劇	雜 音	雜 食	雜 食 性	雜 家	雜 差	雜 症	雜 草	
雜 草 多	雜 草 似	雜 記	雜 院	雜 院 兒	雜 務	雜 務 工	雜 婚	
雜 情	雜 貨	雜 貨 店	雜 貨 商	雜 陳	雜 款	雜 湊	雜 牌	
雜 牌 軍	雜 稅	雜 絮	雜 菜	雜 評	雜 費	雜 集	雜 項	
雜 亂	雜 亂 物	雜 亂 無 章	雜 感	雜 碎	雜 種	雜 種 性	雜 種 狗	
雜 種 優 勢	雜 誌	雜 誌 社	雜 說	雜 劇	雜 談	雜 質	雜 樹 林	
雜 錄	雜 燴	雜 聲	雜 膾	雜 糧	雙 一	雙 人	雙 人 用	
雙 人 床	雙 十	雙 亡	雙 刃	雙 子	雙 子 座	雙 子 葉	雙 工	
雙 工 器	雙 手	雙 手 拉	雙 方	雙 方 面	雙 日	雙 月	雙 月 刊	
雙 凸 面	雙 打	雙 生	雙 目	雙 目 失 明	雙 立 人	雙 休	雙 休 日	
雙 份	雙 全	雙 向	雙 向 交 流	雙 向 選 擇	雙 名	雙 名 法	雙 安	
雙 曲	雙 曲 面	雙 曲 線	雙 百 方 針	雙 耳	雙 色	雙 行	雙 行 道	
雙 行 線	雙 折 射	雙 角	雙 足	雙 周	雙 季 稻	雙 拐	雙 股	
雙 肩	雙 金 屬	雙 拼	雙 柵 極	雙 柑 鬥 酒	雙 氟	雙 流	雙 缸	
雙 胎	雙 胞	雙 胞 胎	雙 軌	雙 軌 制	雙 重	雙 重 目	雙 重 身 份	
雙 重 性	雙 重 領 導	雙 面	雙 音	雙 音 頻	雙 飛	雙 倍	雙 唇	
雙 唇 音	雙 峰	雙 料	雙 桅 船	雙 氧	雙 氧 水	雙 翅 類	雙 側	
雙 宿 雙 飛	雙 排	雙 敘 法	雙 球 菌	雙 眼	雙 速	雙 魚 座	雙 鳥 在 林 一 鳥 在 手	
雙 喜	雙 喜 營 造	雙 喜 臨 門	雙 棲	雙 棲 雙 宿	雙 焦 點	雙 牌	雙 程 票	
雙 筒	雙 絞 線	雙 週 刊	雙 陽 極	雙 極	雙 義	雙 腳	雙 號	
雙 解	雙 態	雙 槓	雙 端	雙 管 齊 下	雙 腿	雙 語	雙 增 雙 節	
雙 層	雙 數	雙 槳	雙 線	雙 線 性	雙 膝	雙 調 和	雙 擁	
雙 擋	雙 糖	雙 親	雙 頰	雙 頭 肌	雙 擊	雙 瞳 剪 水	雙 翼	
雙 聲	雙 臂	雙 鍵	雙 簧	雙 簧 管	雙 職	雙 職 工	雙 豐 收	
雙 雙	雙 穩 態	雙 邊	雙 邊 合 作	雙 邊 條 約	雙 邊 貿 易	雙 邊 會 談	雙 邊 關 係	
雙 關	雙 關 語	雙 鬢	雙 舖	雛 水 鴨	雛 妓	雛 妓 問 題	雛 形	
雛 兒	雛 型	雛 鳥	雛 菊	雛 鳳	雛 雞	雛 鷹	雞	
雞 口 牛 後	雞 子	雞 不 及 鳳	雞 巴	雞 心	雞 毛	雞 毛 蒜 皮	雞 爪	
雞 犬 不 留	雞 犬 不 寧	雞 犬 不 驚	雞 犬 升 天	雞 犬 桑 麻	雞 叫	雞 皮	雞 皮 疙 瘩	
雞 皮 鶴 法	雞 皮 鶴 發	雞 年	雞 肉	雞 肋	雞 血	雞 尾	雞 尾 酒	
雞 冠	雞 冠 石	雞 冠 花	雞 姦	雞 姦 者	雞 屍 牛 從	雞 飛	雞 飛 狗 走	
雞 飛 蛋 打	雞 首	雞 翅	雞 胸	雞 骨 支 床	雞 捨	雞 眼	雞 蛋	
雞 場	雞 廄	雞 棚	雞 湯	雞 粥	雞 絲	雞 塊	雞 腸 鼠 肚	
雞 腳	雞 零 狗 碎	雞 窩	雞 精	雞 腿	雞 鳴	雞 鳴 而 起	雞 鳴 狗 盜	
雞 瘟	雞 膚 鶴 發	雞 頭	雞 頭 牛 後	雞 鴨 魚 肉	雞 蟲 得 失	雞 雞	雞 類	
雞 欄	雞 籠	雞 鶩 爭 食	雞 鶩 相 爭	鞣 皮 匠	鞣 制 革	鞣 酸	鞣 質	
鞦 韆	鞭 上	鞭 子	鞭 不 及 腹	鞭 毛	鞭 打	鞭 刑	鞭 狀	
鞭 長 莫 及	鞭 屍	鞭 炮	鞭 炮 聲	鞭 苔	鞭 索	鞭 痕	鞭 笞	
鞭 笞 天 下	鞭 策	鞭 辟 入 裡	鞭 辟 近 裡	鞭 撻	鞭 繩	鞭 韃	額 上	
額 手 之 禮	額 手 稱 慶	額 外	額 外 負 擔	額 角	額 定	額 定 值	額 前	
額 度	額 面	額 首 稱 頌	額 首 稱 慶	額 骨	額 發	額 達	額 滿 為 止	
額 數	額 親	額 頭	顏 正 國	顏 色	顏 面	顏 料	顏 骨 柳 筋	
顏 清 標	顏 筋 柳 骨	顏 貌	顏 體	題 中	題 外	題 外 話	題 目	
題 目 為	題 名	題 字	題 材	題 注	題 的	題 為	題 頁	
題 庫	題 記	題 款	題 畫	題 詞	題 跋	題 意	題 解	
題 詩	題 寫	題 辭	題 欄	顎 足	顎 音	顎 骨	餿 水	
餮 者	馥 郁	騎 了	騎 上	騎 上 馬	騎 士	騎 士 隊	騎 士 道	
騎 士 團	騎 手	騎 牛 覓 牛	騎 用	騎 用 馬	騎 在	騎 兵	騎 兵 連	
騎 兵 隊	騎 車	騎 者	騎 者 善 墮	騎 虎	騎 虎 難 下	騎 乘	騎 射	
騎 師	騎 馬	騎 馬 人	騎 馬 找 馬	騎 馬 者	騎 馬 褲	騎 得	騎 從	
騎 術	騎 單 車	騎 著	騎 槍 兵	騎 樓	騎 牆	騎 牆 者	騎 縫	
騎 騎	騎 警	騎 驢	騎 驢 覓 驢	鬃 毛	鬃 刷	鬆 了	鬆 口 氣	
鬆 手	鬆 弛	鬆 快	鬆 脆	鬆 動	鬆 掉	鬆 軟	鬆 散	
鬆 開	鬆 綁	鬆 緊	鬆 緊 帶	鬆 懈	鬆 鬆	鬆 鬆 垮 垮	鬆 鬆 散 散	
魏 京 生	魏 書	魏 國	魏 紫 姚 黃	魏 碑	魍 魅	魍 魎	鯊 皮	
鯊 魚	鯊 魚 皮	鯊 魚 裝	鯉 魚	鯽 魚	鵝 毛	鵝 肉	鵝 行 鴨 步	
鵝 卵 石	鵝 蛋	鵝 掌	鵝 筆	鵝 絨	鵝 黃	鵝 群	鵝 頸	
鵠 形 鳩 面	鼬 鼠	嚥 了	嚥 下	嚥 氣	壞 了	壞 人	壞 人 壞 事	
壞 分 子	壞 心	壞 心 眼	壞 心 腸	壞 水	壞 名 聲	壞 死	壞 血	
壞 血 病	壞 君	壞 事	壞 事 變 好 事	壞 性	壞 東 西	壞 的	壞 書	
壞 疽	壞 啦	壞 帳	壞 掉	壞 處	壞 蛋	壞 透	壞 透 了	
壞 脾 氣	壞 話	壞 運 氣	壞 種	壞 壞	壟 統	壟 溝	壟 斷	
壟 斷 利 潤	壟 斷 者	壟 斷 資 本	壟 斷 價 格	寵 臣	寵 兒	寵 物	寵 物 店	
寵 信	寵 恩	寵 辱 不 驚	寵 辱 若 驚	寵 辱 無 驚	寵 愛	寵 壞	龐 大	
龐 眉 白 髮	龐 眉 皓 首	龐 然	龐 然 大 物	龐 雜	廬 山	廬 山 面 目	廬 山 真 面 目	
廬 州	廬 江	廬 捨	懲 一 戒 百	懲 一 警 百	懲 一 儆 百	懲 一 儆 眾	懲 戒	
懲 忿 窒 慾	懲 治	懲 治 腐 敗	懲 前 毖 後	懲 處	懲 惡	懲 惡 勸 善	懲 罰	
懲 罰 性	懲 誡	懲 獎	懲 辦	懲 斂	懷 才 不 遇	懷 才 抱 德	懷 中	
懷 仁 堂	懷 化	懷 古	懷 孕	懷 孕 中	懷 安	懷 有	懷 材 抱 德	
懷 刺 漫 滅	懷 念	懷 抱	懷 抱 不 平	懷 表	懷 金 拖 紫	懷 金 垂 紫	懷 恨	
懷 恨 在 心	懷 恨 者	懷 春	懷 柔	懷 胎	懷 冤 抱 屈	懷 珠 抱 玉	懷 真 抱 素	
懷 偏 見	懷 惡	懷 惡 不 悛	懷 惡 意	懷 著	懷 鄉	懷 黃 佩 紫	懷 想	
懷 裡	懷 道 迷 邦	懷 鉛 提 槧	懷 鉛 握 素	懷 鉛 握 槧	懷 疑	懷 疑 一 切	懷 疑 性	
懷 疑 者	懷 疑 論	懷 緒	懷 遠	懷 德 畏 威	懷 敵 意	懷 瑾 握 瑜	懷 質 抱 真	
懷 璧 其 罪	懷 舊	懷 寶 迷 邦	懷 戀	懶 人	懶 作	懶 於	懶 怠	
懶 洋 洋	懶 骨 頭	懶 鬼	懶 做	懶 婦	懶 得	懶 惰	懶 惰 成 性	
懶 惰 者	懶 惰 蟲	懶 散	懶 腰	懶 漢	懶 蟲	懶 覺	懵 然	
懵 懂	懵 懵	攀 上	攀 今 比 昔	攀 今 覽 古	攀 今 攬 古	攀 升	攀 木 魚	
攀 比	攀 扯	攀 折	攀 車 臥 轍	攀 岩	攀 枝	攀 爬	攀 花 折 柳	
攀 附	攀 高 接 貴	攀 援	攀 登	攀 登 者	攀 著	攀 越	攀 緣	
攀 談	攀 親	攀 親 托 熟	攀 龍 托 鳳	攀 龍 附 鳳	攀 龍 附 驥	攀 轅 臥 轍	攀 蟾 折 桂	
攀 籐 附 葛	攀 籐 攬 葛	攀 鱗 附 翼	攏 子	攏 共	攏 在	攏 總	曠 工	
曠 夫 怨 女	曠 日	曠 日 引 久	曠 日 引 月	曠 日 持 久	曠 日 經 久	曠 日 彌 久	曠 世	
曠 世 奇 才	曠 世 無 匹	曠 世 逸 才	曠 古	曠 古 一 人	曠 古 未 有	曠 古 未 聞	曠 古 絕 倫	
曠 地	曠 若 發 蒙	曠 時	曠 野	曠 達	曠 廢	曠 課	曠 職	
曠 職 僨 事	曝 光	曝 氣	曝 鰓 龍 門	曝 露	曝 曬	櫥 子	櫥 師	
櫥 窗	櫥 燈	櫥 櫃	櫚 樹	瀛 台	瀟 湘	瀟 瀟	瀟 瀝	
瀟 灑	瀟 灑 風 流	瀨 魚	瀚 海	瀝 血	瀝 血 叩 心	瀝 青	瀝 膽 披 肝	
瀝 膽 抽 腸	瀝 膽 墮 肝	瀝 瀝	瀕 危	瀕 危 動 物	瀕 死	瀕 於	瀕 於 倒 閉	
瀕 臨	瀕 臨 破 產	瀕 臨 絕 境	瀕 臨 滅 絕	瀘 水	瀘 州	瀘 西	爆 了	
爆 內 幕	爆 出	爆 竹	爆 米 花	爆 冷 門	爆 炒	爆 炸	爆 炸 力	
爆 炸 事 件	爆 炸 性	爆 炸 物	爆 炸 動 力 學	爆 炸 聲	爆 氣	爆 破	爆 破 手	
爆 破 作 業	爆 破 器 材	爆 笑	爆 發	爆 發 力	爆 發 戶	爆 發 性	爆 裂	
爆 裂 聲	爆 開	爆 雷	爆 滿	爆 鳴	爆 機	爆 燃	爆 燥 如 雷	
爆 聲	爆 響	爍 石 流 金	爍 爍	犢 牛	獸 化	獸 心	獸 心 人 面	
獸 皮	獸 穴	獸 奸	獸 行	獸 性	獸 性 化	獸 屍	獸 害	
獸 般	獸 骨	獸 群	獸 窩	獸 聚 鳥 散	獸 慾	獸 敵	獸 醫	
獸 醫 院	獸 藥	獸 類	獸 欄	獸 籠	獺 皮	瓊 山	瓊 台 玉 宇	
瓊 台 玉 閣	瓊 枝 玉 葉	瓊 枝 玉 樹	瓊 林 玉 質	瓊 林 玉 樹	瓊 海	瓊 脂	瓊 堆 玉 砌	
瓊 崖	瓊 斯 盃	瓊 華	瓊 閣	瓊 廚 金 穴	瓊 樓	瓊 樓 玉 宇	瓊 漿	
瓊 漿 玉 液	瓊 漿 金 液	瓣 形	瓣 狀	瓣 的	瓣 花	瓣 胃	瓣 膜	
疇 曲	疇 咨 之 憂	疆 土	疆 吏	疆 界	疆 域	疆 場	癟 三	
癟 嘴	癡 人	癡 人 說 夢	癡 人 癡 福	癡 心	癡 心 女 子 負 心 漢	癡 心 妄 想	癡 心 婦 人 負 心 漢	
癡 心 夢 想	癡 呆	癡 呆 症	癡 呆 懵 懂	癡 男 怨 女	癡 肥	癡 長	癡 笑	
癡 迷	癡 迷 不 悟	癡 情	癡 傻	癡 想	癡 癡	癡 戀	矇 混	
矇 混 過 關	矇 騙	礙 口	礙 手	礙 手 礙 腳	礙 事	礙 物	礙 眼	
礙 腳	禱 文	禱 告	禱 室	禱 詞	禱 辭	穩 中 有 降	穩 扎 穩 打	
穩 打	穩 如 泰 山	穩 住	穩 住 陣 腳	穩 坐	穩 坐 釣 魚 台	穩 妥	穩 步	
穩 步 前 進	穩 步 發 展	穩 步 增 長	穩 固	穩 定	穩 定 收 入	穩 定 局 勢	穩 定 性	
穩 定 物 價	穩 定 情 緒	穩 定 增 長	穩 便	穩 流	穩 重	穩 准 狠	穩 健	
穩 健 派	穩 產	穩 產 高 產	穩 當	穩 態	穩 價	穩 練	穩 操	
穩 操 左 券	穩 操 勝 券	穩 操 勝 算	穩 壓	穩 壓 器	穩 擬	穩 賺	穩 穩	
穩 穩 當 當	簾 子	簾 子 線	簾 布	簾 帶	簾 帳	簾 幕	簿 上	
簿 子	簿 冊	簿 本	簿 記	簿 記 員	簿 籍	簸 箕	簽 了	
簽 子	簽 出	簽 印	簽 名	簽 名 人	簽 名 簿	簽 字	簽 字 者	
簽 收	簽 有	簽 完	簽 批	簽 到	簽 定	簽 押	簽 於	
簽 注	簽 封	簽 約	簽 約 者	簽 約 國	簽 訂	簽 准	簽 退	
簽 帳 卡	簽 章	簽 單	簽 報	簽 牌	簽 發	簽 署	簽 署 者	
簽 過	簽 認	簽 領	簽 寫	簽 證	簷 口	簷 溝	繫 上	
繫 在	繫 住	繫 於	繫 著	繫 鈴	繫 鈴 解 鈴	繫 緊	繭 子	
繭 衣	繭 兒	繭 絲	繭 絲 牛 毛	繹 出	繹 克 一 物	繹 性	繹 法	
繩 子	繩 之 以 法	繩 床	繩 床 瓦 灶	繩 兒	繩 其 祖 武	繩 栓	繩 索	
繩 帶	繩 梯	繩 桿	繩 厥 祖 武	繩 結	繩 愆 糾 繆	繩 愆 糾 謬	繩 綁	
繩 網	繩 樞 之 士	繩 樞 之 子	繩 線	繩 墨	繩 墨 之 言	繩 鋸 木 斷	繩 環	
繩 趨 尺 步	繪 出	繪 成	繪 色	繪 事 後 素	繪 具 箱	繪 畫	繪 畫 般	
繪 圖	繪 圖 技 術	繪 圖 板	繪 圖 法	繪 圖 儀	繪 圖 機	繪 製	繪 影 繪 聲	
繪 聲 繪 色	繪 聲 繪 影	羅 卜	羅 丹	羅 文 嘉	羅 比 威 廉 斯	羅 世 幸	羅 布	
羅 列	羅 伯 特	羅 甸	羅 東	羅 致	羅 浮 宮	羅 紋	羅 素	
羅 馬	羅 馬 人	羅 馬 化	羅 馬 尼 亞	羅 馬 磁 磚	羅 曼 史	羅 圈	羅 密 歐	
羅 掘	羅 掘 一 空	羅 望	羅 雀	羅 雀 掘 鼠	羅 傑 斯	羅 斯 曼	羅 斯 福	
羅 鉗 吉 網	羅 漢	羅 漢 果	羅 福 全	羅 網	羅 綢	羅 說	羅 賓	
羅 賓 森	羅 德 里 格 斯	羅 德 曼	羅 德 隊	羅 慧 夫	羅 慧 娟	羅 盤	羅 緞	
羅 興 樑	羅 鍋	羅 織	羅 蘭	繳 入	繳 公	繳 付	繳 出	
繳 交	繳 回	繳 存	繳 卷	繳 卸	繳 租	繳 納	繳 售	
繳 掉	繳 械	繳 械 投 降	繳 清	繳 款	繳 稅	繳 給	繳 費	
繳 毀	繳 過	繳 槍	繳 滿	繳 齊	繳 銷	繳 獲	繳 屬	
羹 匙	羹 湯	臘 八	臘 日	臘 月	臘 肉	臘 制	臘 味	
臘 染 法	臘 紙	臘 梅	臘 雪	臘 筆	臘 象	臘 腸	臘 鴨	
臘 燭	藩 主	藩 國	藩 鎮	藩 屬	藩 籬	藝 人	藝 文 界	
藝 匠	藝 名	藝 妓	藝 林	藝 品	藝 界	藝 美	藝 苑	
藝 苑 奇 葩	藝 員	藝 徒	藝 校	藝 能	藝 高	藝 術	藝 術 大 師	
藝 術 中 心	藝 術 水 平	藝 術 交 流	藝 術 作 品	藝 術 形 式	藝 術 形 象	藝 術 享 受	藝 術 性	
藝 術 表 演	藝 術 品	藝 術 流 派	藝 術 界	藝 術 風 格	藝 術 修 養	藝 術 家	藝 術 創 作	
藝 術 感 染	藝 術 節	藝 術 團	藝 術 境 界	藝 術 價 值	藝 術 館	藝 場	藝 廊	
藝 壇	藝 瀆	藝 齡	藕 合	藕 色	藕 花	藕 粉	藕 荷	
藕 絲	藕 節	藕 斷 絲 連	藤 原 紀 香	藤 製	藥 力	藥 丸	藥 方	
藥 水	藥 水 瓶	藥 片	藥 包	藥 用	藥 石	藥 石 之 言	藥 名	
藥 行	藥 局	藥 材	藥 皂	藥 具	藥 典	藥 到 病 除	藥 味	
藥 店	藥 店 飛 龍	藥 性	藥 房	藥 物	藥 物 學	藥 品	藥 害	
藥 害 救 濟	藥 師	藥 庫	藥 效	藥 料	藥 浴	藥 疹	藥 粉	
藥 草	藥 酒	藥 商	藥 械	藥 液	藥 理	藥 理 學	藥 瓶	
藥 盒	藥 單	藥 棉	藥 費	藥 量	藥 種	藥 膏	藥 餌	
藥 廠	藥 箱	藥 劑	藥 劑 師	藥 器	藥 學	藥 膳	藥 療 法	
藥 囊	藥 籠 中 物	藥 罐	藥 舖	蟻 丘	蟻 穴	蟻 塚	蟻 窩	
蟻 聚 蜂 屯	蟻 酸	蟻 酸 鹽	蟻 蠶	蠅 名 蝸 利	蠅 利 蝸 名	蠅 卵	蠅 拍	
蠅 頭	蠅 頭 小 利	蠅 頭 微 利	蠅 頭 蝸 角	蠅 營 狗 苟	蠅 糞	蠅 糞 點 玉	蠍 子	
蟹 人	蟹 肉	蟹 殼	蟹 黃	蟹 慌 蟹 亂	蟾 宮 折 桂	蟾 除	蟾 蜍	
蟾 蜍 石	襟 衫	襟 裡	襟 翼	襟 懷	襟 懷 坦 白	襟 裾 馬 牛	襞 褶	
譁 眾 取 寵	譜 子	譜 分	譜 出	譜 成	譜 曲	譜 系	譜 兒	
譜 盲	譜 表	譜 號	譜 圖	譜 寫	譜 線	識 丁	識 大 體	
識 才 尊 賢	識 文 談 字	識 文 斷 字	識 多	識 多 才 廣	識 字	識 別	識 別 卡	
識 形	識 到	識 相	識 時 務 者	識 時 務 者 為 俊 傑	識 時 通 變	識 時 達 務	識 時 達 變	
識 破	識 記	識 得	識 羞	識 貨	識 透	識 途 老 馬	識 圖	
識 趣	識 禮 知 書	證 人	證 人 席	證 交 所	證 交 稅	證 件	證 見	
證 言	證 券	證 券 公 司	證 券 市 場	證 券 交 易 所	證 券 交 易 稅	證 券 法 規	證 券 股	
證 券 期 貨 交 易 委 員 會	證 券 管 理 委 員 會	證 所 稅	證 明	證 明 了	證 明 人	證 明 者	證 明 是	
證 明 書	證 物	證 金 公 司	證 書	證 婚	證 婚 人	證 章	證 期 會	
證 給	證 詞	證 照	證 照 核 發	證 實	證 據	證 據 確 鑿	證 嚴 法 師	
譚 天 說 地	譎 而 不 正	譎 怪 之 談	譏 刺	譏 笑	譏 評	譏 誚	譏 嘲	
譏 諷	譏 諷 語	贈 人	贈 予	贈 本	贈 別	贈 言	贈 券	
贈 物	贈 者	贈 品	贈 送	贈 送 物	贈 款	贈 答	贈 給	
贈 與	贈 與 者	贈 與 稅	贈 閱	贈 禮	贊 口 不 絕	贊 不 容 口	贊 比 亞	
贊 比 亞 人	贊 同	贊 成	贊 成 票	贊 助	贊 助 人	贊 者	贊 詞	
贊 語	贊 禮	蹼 足	蹲 下	蹲 伏	蹲 在	蹲 坐	蹲 著	
蹲 點	躇 子	蹬 了	蹬 著	蹬 腿	蹬 蹬	蹺 足 而 待	蹺 板	
蹺 蹊 作 怪	蹺 蹺	蹺 蹺 板	蹴 而	轎 子	轎 夫	轎 車	轎 門	
轎 椅	轎 短 量 長	辭 上	辭 不 意 逮	辭 不 達 意	辭 不 獲 命	辭 世	辭 令	
辭 去	辭 句	辭 巧 理 拙	辭 多 受 少	辭 色	辭 行	辭 別	辭 呈	
辭 典	辭 卸	辭 官	辭 法	辭 書	辭 書 學	辭 格	辭 海	
辭 退	辭 章	辭 喻 橫 生	辭 尊 居 卑	辭 彙	辭 彙 學	辭 微 旨 遠	辭 歲	
辭 源	辭 聘	辭 賦	辭 鋒	辭 學	辭 謝	辭 簡 意 足	辭 職	
辭 職 書	辭 舊 迎 新	辭 豐 意 雄	辭 嚴 氣 正	辭 嚴 義 正	辭 藻	辭 讓	邊 上	
邊 干	邊 干 邊 學	邊 卡	邊 民	邊 式	邊 行	邊 形	邊 材	
邊 角	邊 角 料	邊 角 廢 料	邊 走	邊 防	邊 防 前 線	邊 防 軍	邊 防 哨 所	
邊 防 部 隊	邊 防 戰 士	邊 兒	邊 沿	邊 狀	邊 門	邊 界	邊 界 層	
邊 界 線	邊 界 衝 突	邊 看	邊 音	邊 哭	邊 料	邊 旁	邊 框	
邊 站	邊 區	邊 帶	邊 幅	邊 貿	邊 距	邊 陲	邊 塞	
邊 想	邊 飾	邊 鼓	邊 境	邊 境 貿 易	邊 境 線	邊 寨	邊 說	
邊 遠	邊 遠 地 區	邊 際	邊 緣	邊 緣 科 學	邊 緣 學 科	邊 線	邊 鋒	
邊 整 邊 改	邊 疆	邊 疆 地 區	邊 疆 政 策	邊 鏡	邊 關	邋 塌	邋 裡	
邋 遢	鏡 子	鏡 中	鏡 片	鏡 式	鏡 花 水 月	鏡 架	鏡 面	
鏡 框	鏡 破 釵 分	鏡 般	鏡 象	鏡 像	鏡 頭	鏡 鑒	鏟 土	
鏟 子	鏟 斗	鏟 出	鏟 車	鏟 起	鏟 掉	鏟 鑿	鏈 子	
鏈 球	鏜 孔	鏜 床	鏖 兵	鏖 戰	鏢 局	鏢 師	鏢 槍	
鏘 聲	鏘 鏘	鏤 心 刻 骨	鏤 月 栽 雲	鏤 月 裁 雲	鏤 冰 雕 朽	鏤 刻	鏤 空	
鏤 骨 銘 心	鏤 骨 銘 肌	鏤 塵 吹 影	鏤 蝕	鏗 然	鏗 聲	鏗 鏘	鏗 鏘 聲	
鏗 鏗 聲	鏨 子	關 了	關 入	關 上	關 口	關 子 嶺	關 山 鎮	
關 中	關 內	關 公	關 切	關 心	關 心 事	關 心 國 家 大 事	關 心 集 體	
關 心 群 眾	關 卡	關 外	關 在	關 羽	關 西	關 住	關 車	
關 防	關 店	關 押	關 於	關 於 此	關 東	關 東 糖	關 注	
關 門	關 門 大 吉	關 門 主 義	關 門 打 狗	關 門 閉 戶	關 係	關 係 戶	關 係 史	
關 係 正 常 化	關 係 好	關 係 到	關 係 者	關 係 甚 鉅	關 係 詞	關 係 網	關 帝 廟	
關 島	關 站	關 起	關 起 門 來	關 停	關 停 並 轉	關 健	關 張	
關 掉	關 連	關 閉	關 閉 者	關 渡	關 稅	關 稅 局	關 稅 表	
關 稅 率	關 稅 壁 壘	關 窗	關 著	關 貿	關 貿 網 路	關 貿 總 協 定	關 進	
關 愛	關 照	關 節	關 節 炎	關 隘	關 境	關 緊	關 餉	
關 廟	關 廠	關 機	關 燈	關 錦 鵬	關 頭	關 嶺	關 聯	
關 鍵	關 鍵 字	關 鍵 性	關 懷	關 懷 備 至	關 關	隴 南	隴 海	
隴 華 電 子	隴 間	難 人	難 下	難 上 加 難	難 上 難	難 分	難 分 高 下	
難 分 難 解	難 匹 敵	難 友	難 反 對	難 乎 為 繼	難 以	難 以 自 拔	難 以 克 服	
難 以 完 成	難 以 忘 懷	難 以 忍 受	難 以 為 繼	難 以 相 信	難 以 捉 摸	難 以 想 像	難 以 置 信	
難 以 解 決	難 以 達 到	難 以 避 免	難 兄 難 弟	難 句	難 民	難 民 營	難 犯	
難 吃	難 字	難 收	難 色	難 行	難 住	難 免	難 局	
難 忘	難 忍	難 忍 受	難 找	難 抑	難 改	難 攻 取	難 言	
難 言 之 隱	難 言 的 苦 衷	難 事	難 使	難 到	難 制	難 制 服	難 取	
難 受	難 和 解	難 念	難 怪	難 承 認	難 抵 抗	難 於	難 易	
難 治	難 治 療	難 返	難 信	難 保	難 冠 楚 囚	難 卻	難 度	
難 為	難 為 情	難 相 處	難 看	難 耐	難 胞	難 苦	難 飛	
難 倒	難 容	難 捉 摸	難 消 化	難 能	難 能 可 貴	難 逃	難 追 蹤	
難 做	難 得	難 得 到	難 得 糊 塗	難 控	難 控 制	難 接 近	難 捨 難 分	
難 教	難 望	難 混 合	難 理 解	難 產	難 統 治	難 船	難 處	
難 處 理	難 被	難 割 難 捨	難 堪	難 尋	難 測	難 童	難 評	
難 買	難 當	難 解	難 解 難 分	難 道	難 道 說	難 達 到	難 過	
難 預 料	難 馴 服	難 僑	難 對 付	難 對 會	難 熔 化	難 熄 滅	難 盡	
難 管	難 管 制	難 管 理	難 箕 北 斗	難 聞	難 語 症	難 說	難 鳴	
難 寬 恕	難 敵	難 數	難 熬	難 調	難 駕	難 駕 御	難 駕 馭	
難 學	難 憑	難 戰 勝	難 操 縱	難 辨	難 辨 認	難 辦	難 壓 制	
難 應 付	難 懂	難 懂 話	難 獲 得	難 瞭 解	難 點	難 醫	難 題	
難 識	難 識 別	難 關	難 難	難 纏	難 聽	難 讀	難 讀 解	
霧 中	霧 化	霧 水	霧 台 鄉	霧 狀	霧 重	霧 峰	霧 峰 鄉	
霧 氣	霧 散	霧 裡 看 花	霧 幕	霧 滴	霧 濃	霧 靄	霧 鬢 風 鬟	
靡 不 有 初 鮮 克 有 終	靡 有 孑 遺	靡 衣 玉 食	靡 衣 偷 食	靡 知 所 措	靡 然 向 風	靡 然 從 風	靡 然 鄉 風	
靡 靡	靡 靡 之 音	靡 靡 之 樂	韜 戈 卷 甲	韜 戈 偃 武	韜 光 俟 奮	韜 光 晦 跡	韜 光 滅 跡	
韜 光 養 晦	韜 光 隱 跡	韜 光 韞 玉	韜 神 晦 跡	韜 晦 之 計	韜 晦 待 時	韜 略	韜 跡 匿 光	
韜 聲 匿 跡	韻 文	韻 母	韻 尾	韻 步	韻 事	韻 味	韻 律	
韻 律 學	韻 腳	韻 詩	韻 語	韻 樂	韻 體	類 人	類 人 猿	
類 化	類 比	類 目	類 同	類 有	類 次	類 此	類 似	
類 似 於	類 似 物	類 似 問 題	類 別	類 固 醇	類 於	類 金 屬	類 型	
類 星 體	類 毒 素	類 胡 蘿 蔔 素	類 書	類 脂 醇	類 推	類 推 者	類 項	
類 義	類 義 字	類 群	類 聚	類 質 同 像	類 屬	願 人	願 付	
願 去	願 受	願 服 從	願 者	願 者 上 鉤	願 為	願 留	願 能	
願 望	願 給	願 意	願 聞	願 聽	顛 三 倒 四	顛 沛 流 離	顛 狂	
顛 來 倒 去	顛 倒	顛 倒 反 轉	顛 倒 衣 裳	顛 倒 是 非	顛 倒 陰 陽	顛 倒 黑 白	顛 唇 簸 嘴	
顛 乾 倒 坤	顛 動	顛 搖	顛 撲 不 破	顛 撲 不 碎	顛 撲 不 磨	顛 頭 顛 腦	顛 覆	
顛 覆 性	顛 覆 者	顛 簸	顛 簸 不 破	顛 簸 而 行	顛 顛 倒 倒	顛 鸞 倒 鳳	颼 聲	
颼 颼	颼 颼 聲	饅 頭	騙 人	騙 入	騙 子	騙 用	騙 吃	
騙 她	騙 色	騙 你	騙 局	騙 走	騙 取	騙 者	騙 案	
騙 財	騙 鬼	騙 售	騙 術	騙 喝	騙 稅	騙 買 騙 賣	騙 過	
騙 錢	鬍 子	鬍 子 眉 毛 一 把 抓	鬍 鬚	鯨 吞	鯨 吞 虎 噬	鯨 油	鯨 背	
鯨 脂	鯨 骨	鯨 魚	鯨 須	鯨 類	鯧 魚	鶉 衣 百 結	鵲 起	
鵲 巢 鳩 佔	鵲 橋	鵪 鶉	鵬 程	鵬 程 萬 里	麒 麟	麗 人	麗 水	
麗 正	麗 正 電 子	麗 江	麗 色	麗 星 郵 輪	麗 都	麗 臺 科 技	麗 質	
麗 嬰 房	勸 人	勸 止	勸 百 諷 一	勸 住	勸 告	勸 告 者	勸 戒	
勸 和	勸 阻	勸 勉	勸 架	勸 降	勸 退	勸 酒	勸 得	
勸 善	勸 善 戒 惡	勸 善 黜 惡	勸 善 懲 惡	勸 募	勸 解	勸 解 者	勸 誡	
勸 說	勸 說 者	勸 誘	勸 慰	勸 導	勸 諫	嚷 叫	嚷 著	
嚷 鬧	嚷 聲	嚷 嚷	嚶 鳴 求 友	嚶 嚶	嚴 父	嚴 以 律 己	嚴 令	
嚴 冬	嚴 加	嚴 加 懲 處	嚴 打	嚴 斥	嚴 正	嚴 刑	嚴 刑 峻 法	
嚴 守	嚴 守 紀 律	嚴 而 律 己	嚴 防	嚴 命	嚴 拒	嚴 於	嚴 明	
嚴 治	嚴 苛	嚴 重	嚴 重 危 害	嚴 重 性	嚴 重 後 果	嚴 重 破 壞	嚴 重 影 響	
嚴 重 積 水	嚴 修	嚴 峻	嚴 峻 考 驗	嚴 師	嚴 格	嚴 格 地	嚴 格 紀 律	
嚴 格 要 求	嚴 格 控 制	嚴 格 管 理	嚴 格 遵 守	嚴 陣 以 待	嚴 密	嚴 處	嚴 責	
嚴 寒	嚴 寒 期	嚴 復	嚴 策	嚴 肅	嚴 肅 性	嚴 肅 查 處	嚴 肅 處 理	
嚴 肅 認 真	嚴 詞	嚴 詞 拒 絕	嚴 禁	嚴 實	嚴 管	嚴 緊	嚴 罰	
嚴 酷	嚴 酷 性	嚴 厲	嚴 厲 打 擊	嚴 厲 批 評	嚴 整	嚴 辦	嚴 霜	
嚴 謹	嚴 醫	嚴 懲	嚴 懲 不 怠	嚴 懲 不 貸	嚴 辭	嚴 嚴 實 實	嚼 字	
嚼 舌	嚼 碎	嚼 墨 噴 紙	嚼 爛	嚼 蠟	壤 土	孀 居	孽 子	
孽 種	孽 障	寶 刀	寶 刀 不 老	寶 山	寶 山 空 回	寶 山 鄉	寶 中 之 寶	
寶 玉	寶 石	寶 石 匠	寶 石 商	寶 石 藍	寶 地	寶 成 工 業	寶 成 建 設	
寶 位	寶 貝	寶 貝 兒	寶 來 證 券	寶 典	寶 物	寶 剎	寶 盆	
寶 島	寶 島 科 技	寶 島 銀	寶 島 銀 行	寶 庫	寶 座	寶 書	寶 珠	
寶 馬	寶 馬 香 車	寶 盒	寶 祥 實 業	寶 貴	寶 貴 財 富	寶 貴 意 見	寶 隆 國 際	
寶 塔	寶 殿	寶 獅	寶 號	寶 劍	寶 箱	寶 器	寶 鋼	
寶 聯 電 腦	寶 藏	寶 雞	寶 寶	寶 鑒	懸 心 吊 膽	懸 木	懸 乎	
懸 吊	懸 在	懸 羊 頭 賣 狗 肉	懸 而 未 決	懸 車 之 年	懸 車 告 老	懸 車 致 仕	懸 弧 之 慶	
懸 念	懸 於	懸 河	懸 河 注 水	懸 河 注 火	懸 河 瀉 水	懸 空	懸 垂	
懸 垂 肌	懸 垂 物	懸 若 日 月	懸 案	懸 殊	懸 浮	懸 浮 液	懸 起	
懸 停	懸 崖	懸 崖 峭 壁	懸 崖 勒 馬	懸 崖 絕 壁	懸 掛	懸 掛 式	懸 掛 物	
懸 梯	懸 壺 濟 世	懸 腕	懸 著	懸 置	懸 腸 掛 肚	懸 鉤 子	懸 旗	
懸 疑	懸 劍	懸 慮	懸 樑	懸 樑 自 盡	懸 樑 刺 骨	懸 賞	懸 濁 液	
懸 燈 結 彩	懸 頭 刺 骨	懸 臂	懸 瀑	懸 鶉 百 結	懸 懸 而 望	懺 悔	懺 悔 式	
攘 人 之 美	攘 外 安 內	攘 袂 切 齒	攘 袂 扼 腕	攘 臂 一 呼	攘 臂 而 起	攘 攘	攔 水	
攔 水 堰	攔 住	攔 劫	攔 車	攔 河	攔 河 壩	攔 阻	攔 洪	
攔 腰	攔 路	攔 路 虎	攔 路 搶 劫	攔 路 賊	攔 截	攔 截 者	攔 截 機	
攔 網	攔 蓄	攔 擋	攔 擊	攔 檢	攙 入	攙 水	攙 以	
攙 合	攙 有	攙 行 奪 市	攙 住	攙 兌	攙 扶	攙 和	攙 起	
攙 酒	攙 假	攙 進	攙 雜	攙 雜 用	朧 的	瀾 滄	瀾 滄 江	
瀰 散	瀰 漫	爐 上	爐 口	爐 子	爐 工	爐 火	爐 火 純 青	
爐 台	爐 灰	爐 灶	爐 具	爐 底	爐 門	爐 前	爐 架	
爐 料	爐 條	爐 頂	爐 渣	爐 絲	爐 溫	爐 盤	爐 窯	
爐 膛	爐 邊	爐 齡	爐 襯	獻 上	獻 出	獻 可 替 不	獻 可 替 否	
獻 血	獻 血 者	獻 佛	獻 呈	獻 技	獻 言	獻 身	獻 身 四 化	
獻 身 者	獻 身 精 神	獻 於	獻 者	獻 花	獻 金	獻 金 醜 聞	獻 計	
獻 計 獻 策	獻 捐	獻 殷 勤	獻 納	獻 酒	獻 祭	獻 媚	獻 智	
獻 替 可 否	獻 策	獻 給	獻 詞	獻 詩	獻 歌	獻 縣	獻 醜	
獻 禮	獻 藝	獻 辭	獻 寶	癢 的 很	癢 症	癢 疹	癢 癢	
癥 狀	癥 結	礦 上	礦 山	礦 工	礦 井	礦 井 口	礦 內	
礦 水	礦 石	礦 穴	礦 坑	礦 局	礦 床	礦 車	礦 房	
礦 泥	礦 物	礦 物 油	礦 物 質	礦 物 學	礦 長	礦 柱	礦 泉	
礦 泉 水	礦 洞	礦 砂	礦 粉	礦 脈	礦 務	礦 務 局	礦 區	
礦 帶	礦 產	礦 產 品	礦 產 資 源	礦 部	礦 場	礦 棉	礦 渣	
礦 渣 堆	礦 業	礦 業 經 濟	礦 種	礦 層	礦 廠	礦 漿	礦 質	
礦 燈	礦 藏	礦 類	礦 體	礦 鹽	礪 山 帶 河	礪 戈 秣 馬	礪 兵 秣 馬	
礬 土	礬 石	礫 石	礫 層	礫 巖	竇 狀	競 技	競 技 狀 態	
競 技 場	競 走	競 板	競 爭	競 爭 力	競 爭 性	競 爭 者	競 爭 能 力	
競 爭 機 制	競 金 疏 古	競 相	競 得	競 速 滑 冰	競 逐	競 渡	競 短 爭 長	
競 買	競 買 人	競 奪	競 態	競 價	競 標	競 選	競 賽	
競 賽 活 動	競 購	籌 委 會	籌 建	籌 借	籌 商	籌 得	籌 措	
籌 措 資 金	籌 略	籌 組	籌 設	籌 備	籌 備 會	籌 款	籌 畫	
籌 集	籌 集 者	籌 集 資 金	籌 募	籌 資	籌 劃	籌 算	籌 賑	
籌 撥	籌 碼	籌 謀	籌 辦	籌 錢	籌 議	籃 子	籃 協	
籃 板	籃 板 球	籃 狀	籃 框	籃 球	籃 球 隊	籃 球 賽	籃 細 工	
籃 網 隊	籃 壇	籃 賽	籍 口	籍 冊	籍 貫	籍 籍 無 名	糯 米	
糯 稻	糰 子	辮 子	辮 兒	繽 紛	繼 女	繼 子	繼 之	
繼 天 立 極	繼 父	繼 父 母	繼 母	繼 任	繼 任 者	繼 而	繼 位	
繼 志 述 事	繼 往	繼 往 開 來	繼 承	繼 承 人	繼 承 性	繼 承 法	繼 承 物	
繼 承 者	繼 承 權	繼 起	繼 晷 焚 膏	繼 發	繼 發 性	繼 絕 存 亡	繼 絕 扶 傾	
繼 絕 興 亡	繼 嗣	繼 業	繼 電 器	繼 踵 而 至	繼 續	繼 續 走	繼 續 性	
繼 續 革 命	纂 修	罌 粟	罌 粟 科	耀 文 電 子	耀 目	耀 光	耀 武	
耀 武 揚 威	耀 祖	耀 祖 榮 宗	耀 眼	艦 上	艦 地	艦 空 導 彈	艦 長	
艦 炮	艦 首	艦 員	艦 隻	艦 船	艦 隊	艦 塔	艦 群	
艦 艇	艦 載	艦 旗	艦 寬	艦 齡	藻 土	藻 類	藻 類 學	
藹 然	藹 藹	蘑 菇	蘆 木	蘆 竹	蘆 花	蘆 柑	蘆 洲	
蘆 洲 市	蘆 席	蘆 根	蘆 柴	蘆 笛	蘆 笙	蘆 筍	蘆 溝 橋	
蘆 葦	蘆 葦 狀	蘆 管	蘋 果	蘋 果 汁	蘋 果 渣	蘋 果 電 腦	蘋 果 餅	
蘋 果 醬	蘋 果 類	蘇 力 菌	蘇 中	蘇 丹	蘇 丹 人	蘇 方	蘇 日	
蘇 木	蘇 北	蘇 打	蘇 打 水	蘇 永 康	蘇 伊 士	蘇 共	蘇 共 中 央	
蘇 州	蘇 利 南	蘇 志 誠	蘇 沙	蘇 杭	蘇 東 坡	蘇 武	蘇 門 答 臘	
蘇 俄	蘇 南 成	蘇 美	蘇 貞 昌	蘇 軍	蘇 格 拉 底	蘇 格 蘭	蘇 格 蘭 人	
蘇 格 蘭 皇 家 銀 行	蘇 海 韓 潮	蘇 起	蘇 區	蘇 堤	蘇 菲 瑪 索	蘇 軾	蘇 維 埃	
蘇 黎 士	蘇 黎 世	蘇 澳	蘇 澳 港	蘇 聯	蘇 聯 人	蘇 聯 盧 布	蘇 繡	
蘇 鐵	蘊 含	蘊 育	蘊 和	蘊 奇 待 價	蘊 涵	蘊 蓄	蘊 積	
蘊 藏	蘊 藏 量	蘊 藉	蘊 釀	蠕 行	蠕 形	蠕 動	蠕 蟲	
蠕 蟲 狀	蠕 蠕	襤 褸	覺 世	覺 出	覺 有	覺 到	覺 悟	
覺 得	覺 著	覺 察	覺 醒	觸 及	觸 手	觸 犯	觸 目	
觸 目 如 故	觸 目 成 誦	觸 目 皆 是	觸 目 傷 心	觸 目 慟 心	觸 目 駭 心	觸 目 警 心	觸 目 驚 心	
觸 地	觸 即	觸 角	觸 事 面 牆	觸 到	觸 底	觸 法	觸 知	
觸 怒	觸 面	觸 動	觸 控 式	觸 殺	觸 媒	觸 景	觸 景 生 情	
觸 景 生 懷	觸 景 傷 情	觸 痛	觸 發	觸 發 器	觸 感	觸 碰	觸 禁 犯 忌	
觸 雷	觸 電	觸 摸	觸 摸 者	觸 網	觸 機 落 阱	觸 頭	觸 壓	
觸 擊	觸 礁	觸 點	觸 類 而 長	觸 類 旁 通	觸 覺	觸 鬚	議 不 反 顧	
議 付	議 多	議 好	議 而 不 決	議 決	議 事	議 事 日 程	議 事 單	
議 事 槌	議 和	議 定	議 定 書	議 者	議 長	議 員	議 席	
議 案	議 院	議 程	議 會	議 會 制	議 會 質 詢	議 會 黨 團	議 價	
議 請	議 論	議 論 文	議 論 風 生	議 論 紛 紛	議 辦	議 購	議 題	
譬 如	譬 喻	警 力	警 心 滌 慮	警 方	警 犬	警 世	警 句	
警 民	警 示	警 告	警 告 者	警 局	警 戒	警 戒 室	警 戒 哨	
警 戒 線	警 言	警 車	警 具	警 官	警 所	警 服	警 長	
警 亭	警 政	警 政 署	警 界	警 匪	警 員	警 訊	警 務	
警 崗	警 惕	警 惕 性	警 探	警 笛	警 備	警 備 司 令 部	警 備 區	
警 備 條 令	警 備 部 隊	警 備 勤 務	警 報	警 報 球	警 報 器	警 棒	警 棍	
警 署	警 號	警 鈴	警 察	警 察 史	警 察 局	警 察 制 度	警 察 們	
警 察 部 隊	警 語	警 衛	警 衛 室	警 衛 員	警 衛 勤 務	警 燈	警 醒	
警 徽	警 覺	警 鐘	警 鐘 長 鳴	警 鐘 聲	警 護	譯 文	譯 文 集	
譯 出	譯 本	譯 名	譯 成	譯 自	譯 制	譯 林	譯 注	
譯 者	譯 為	譯 述	譯 音	譯 員	譯 著	譯 意	譯 解	
譯 電	譯 電 員	譯 審	譯 碼	譯 碼 器	譯 錯	譯 叢	贏 了	
贏 余	贏 利	贏 取	贏 家	贏 得	贏 錢	贍 望	贍 養	
贍 養 費	躉 售 物 價 指 數	躉 船	躁 狂	躁 狂 症	躁 動	躁 鬱 病	醴 陵	
釋 人	釋 文	釋 出	釋 免	釋 言	釋 典	釋 放	釋 放 者	
釋 明	釋 法	釋 者	釋 股 案	釋 金	釋 度	釋 後	釋 迦	
釋 迦 牟 尼	釋 重	釋 教	釋 然	釋 義	釋 道	釋 夢	釋 疑	
釋 疑 解 惑	釋 學	釋 錯	釋 藏	鐘 山	鐘 匠	鐘 形	鐘 形 蟲	
鐘 乳 石	鐘 表	鐘 表 匠	鐘 表 店	鐘 表 學	鐘 面	鐘 塔	鐘 鼎	
鐘 鼓	鐘 鳴 鼎 食	鐘 鳴 漏 盡	鐘 樓	鐘 錶 市 場	鐘 錶 眼 鏡	鐘 頭	鐘 聲	
鐘 點	鐘 擺	鐘 靈 毓 秀	闡 明	闡 述	闡 揚	闡 發	闡 釋	
飄 出	飄 失	飄 來	飄 忽	飄 拂	飄 泊	飄 洋	飄 洋 過 海	
飄 流	飄 風 急 雨	飄 風 暴 雨	飄 風 驟 雨	飄 飛	飄 香	飄 晃	飄 浮	
飄 起	飄 動	飄 帶	飄 逝	飄 雪	飄 揚	飄 散	飄 渺	
飄 然	飄 絮	飄 著	飄 逸	飄 搖	飄 溢	飄 落	飄 遊	
飄 零	飄 舞	飄 蓬 斷 梗	飄 蕩	飄 飄	飄 飄 欲 出	飄 飄 然	飄 灑	
饒 有	饒 有 風 趣	饒 有 興 趣	饒 舌	饒 舌 者	饒 舌 家	饒 舌 調 唇	饒 命	
饒 恕	饒 彎	饑 不 擇 食	饑 火 燒 腸	饑 民	饑 色	饑 虎 撲 食	饑 附 飽 揚	
饑 凍 交 切	饑 荒	饑 寒	饑 寒 交 切	饑 寒 交 迫	饑 渴	饑 渴 交 攻	饑 渴 交 迫	
饑 腸 轆 轆	饑 飽	饑 餓	饑 餓 線	饑 餐 渴 飲	饑 謹	饑 饉	饑 饉 薦 臻	
馨 心	馨 花	馨 香	馨 香 禱 祝	騰 出	騰 地	騰 空	騰 空 而 起	
騰 虎	騰 飛	騰 挪	騰 起	騰 蛟 起 鳳	騰 越	騰 開	騰 雲	
騰 雲 駕 霧	騰 黃	騰 達	騰 騰	騰 躍	騰 讓	騷 人	騷 人 墨 客	
騷 客	騷 動	騷 貨	騷 亂	騷 亂 性	騷 擾	騷 體	鰓 如 朝 露	
鰓 若 崇 寄	鰓 若 崇 夢	鰓 若 朝 露	鹹 水 湖	鹹 肉	鹹 味	鹹 的	鹹 淡	
鹹 蛋	鹹 魚	鹹 湖	鹹 菜	麵 包	麵 包 心	麵 包 片	麵 包 車	
麵 包 店	麵 包 房	麵 包 師	麵 包 廠	麵 食	麵 粉	麵 條	麵 條 兒	
麵 湯	麵 筋	麵 團	麵 餅	麵 糊	麵 點	黨 人	黨 小 組	
黨 中 央	黨 內	黨 內 外	黨 心	黨 支 部	黨 支 部 書 記	黨 主 席	黨 主 席 改 選	
黨 代 表	黨 代 表 制	黨 代 會	黨 史	黨 外	黨 外 人 士	黨 民	黨 同 伐 異	
黨 在	黨 羽	黨 改	黨 制	黨 委	黨 委 制	黨 委 書 記	黨 委 會	
黨 性	黨 爭	黨 社	黨 建	黨 政	黨 政 軍	黨 政 機 關	黨 派	
黨 派 性	黨 紀	黨 紀 國 法	黨 紀 處 分	黨 風	黨 風 不 正	黨 風 好 轉	黨 風 建 設	
黨 員	黨 員 大 會	黨 徒	黨 校	黨 務	黨 務 工 作	黨 參	黨 國	
黨 票	黨 組	黨 組 書 記	黨 組 織	黨 部	黨 章	黨 報	黨 棍	
黨 費	黨 禁	黨 群	黨 群 關 係	黨 團	黨 團 員	黨 團 組	黨 旗	
黨 歌	黨 綱	黨 閥	黨 魁	黨 課	黨 辦	黨 徽	黨 總 支	
黨 藉	黨 證	黨 籍	黨 齡	鼯 鼠	齟 齬	齟 齬 不 合	囁 嚅	
囂 叫	囂 張	囂 張 一 時	夔 龍 禮 樂	屬 下	屬 之	屬 毛 離 裡	屬 吏	
屬 名	屬 地	屬 有	屬 次 比 事	屬 性	屬 於	屬 於 她	屬 於 我	
屬 垣 有 耳	屬 相	屬 員	屬 馬	屬 國	屬 意	屬 實	巍 山	
巍 峨	巍 然	巍 然 屹 立	巍 巍	懼 內	懼 外	懼 色	懼 怕	
懾 服	懾 物	攝 入	攝 氏	攝 氏 表	攝 氏 零 度	攝 去	攝 生	
攝 生 法	攝 在	攝 成	攝 行	攝 位	攝 制	攝 制 組	攝 取	
攝 威 擅 勢	攝 政	攝 政 王	攝 食	攝 象	攝 像	攝 像 機	攝 影	
攝 影 公 司	攝 影 者	攝 影 家	攝 影 展	攝 影 師	攝 影 場	攝 影 學	攝 影 學 會	
攝 影 機	攝 影 聯 展	攝 魄 鉤 魂	攝 譜 儀	攝 護 腺 肥 大	攜 手	攜 手 並 肩	攜 手 並 進	
攜 手 前 進	攜 幼	攜 幼 扶 老	攜 式	攜 老 扶 幼	攜 老 挈 幼	攜 伴	攜 男 挈 女	
攜 物	攜 首 接 武	攜 帶	攜 帶 者	攜 帶 型	攜 眷	攜 備	攜 款	
攜 雲 挈 雨	攜 雲 握 雨	攜 槍	攜 領	攜 彈	櫻 花	櫻 花 建 設	櫻 花 鉤 吻 鮭	
櫻 桃	櫻 桃 色	櫻 桃 酒	櫻 草	欄 干	欄 中	欄 內	欄 外	
欄 目	欄 式	欄 次	欄 位	欄 把	欄 杆	欄 板	欄 柵	
欄 圈	欄 塊	欄 數	殲 一 警 百	殲 滅	殲 滅 戰	殲 敵	殲 擊	
殲 擊 機	灌 了	灌 入	灌 下	灌 上	灌 夫 罵 坐	灌 木	灌 木 叢	
灌 水	灌 瓜 之 義	灌 制	灌 於	灌 注	灌 注 法	灌 法	灌 南	
灌 洗	灌 酒	灌 區	灌 溉	灌 溉 者	灌 進	灌 陽	灌 雲	
灌 腸	灌 腸 劑	灌 裝	灌 滿	灌 漿	灌 醉	灌 縣	灌 輸	
灌 錄	灌 藥	爛 成	爛 死	爛 泥	爛 泥 漿	爛 炸	爛 帳	
爛 掉	爛 貨	爛 漫	爛 熟	爛 糊	爛 調	爛 賬	爛 醉	
爛 醉 如 泥	爛 額 焦 頭	爛 爛	爛 鐵	爛 攤	爛 攤 子	犧 牲	犧 牲 者	
犧 牲 品	癩 子	癩 病	癩 蛤 蟆	癩 蛤 蟆 想 吃 天 鵝 肉	癩 瘡	癩 癬	籐 本	
籐 床	籐 杖	籐 架	籐 條	籐 椅	籐 黃	籐 箱	籐 蔓	
籐 器	籐 叢	籐 鞭	籐 蘿	纏 上	纏 手	纏 打	纏 在	
纏 好	纏 住	纏 吻	纏 足	纏 身	纏 鬥	纏 結	纏 著	
纏 腳	纏 綿	纏 綿 悱 惻	纏 裹	纏 擾	纏 擾 不 休	纏 繞	纏 繞 器	
纏 悱	續 文	續 加	續 任	續 存	續 行	續 完	續 局	
續 和	續 弦	續 版	續 表	續 前	續 建	續 後	續 流	
續 約	續 訂	續 革	續 音	續 借	續 租	續 航	續 航 力	
續 假	續 娶	續 教	續 報	續 期	續 集	續 聘	續 篇	
續 編	續 斷	續 簽	蘭 心 蕙 性	蘭 因 絮 果	蘭 州	蘭 州 市	蘭 考	
蘭 色	蘭 艾 同 焚	蘭 坪	蘭 板	蘭 花	蘭 芷 之 室	蘭 亭	蘭 桂 坊	
蘭 桂 齊 芳	蘭 草	蘭 崔 玉 折	蘭 領	蘭 領 工 人	蘭 嶼	蘭 譜	蘭 寶 石	
蠣 殼	蠢 人	蠢 才	蠢 材	蠢 事	蠢 物	蠢 者	蠢 若 木 雞	
蠢 動	蠢 笨	蠢 蛋	蠢 貨	蠢 話	蠢 豬	蠢 蠢	蠢 蠢 欲 動	
蠢 驢	蠟 人	蠟 台	蠟 地	蠟 色	蠟 刻	蠟 制	蠟 板	
蠟 版	蠟 芯	蠟 染	蠟 紙	蠟 畫	蠟 筆	蠟 筆 小 嵐	蠟 筆 夾	
蠟 黃	蠟 塑 術	蠟 塗	蠟 像	蠟 槍	蠟 管	蠟 樣	蠟 質	
蠟 燭	襪 上	襪 子	襪 底	襪 套	襪 筒	襪 業	襪 廠	
覽 表	譴 責	譴 散	護 士	護 士 長	護 民	護 民 官	護 田 林	
護 甲	護 目 鏡	護 耳	護 佑	護 肘	護 身	護 身 法	護 身 符	
護 岸	護 岸 林	護 林	護 林 防 火	護 林 員	護 板	護 法	護 法 運 動	
護 肩	護 花	護 城	護 城 河	護 柩 者	護 套	護 校	護 海 商 法	
護 神	護 胸	護 航	護 送	護 送 者	護 國	護 國 佑 民	護 國 運 動	
護 國 戰 爭	護 帶	護 理	護 理 人 員	護 符	護 堤	護 短	護 稅	
護 著	護 照	護 路	護 路 林	護 運	護 過 飾 非	護 旗	護 腿	
護 蓋 物	護 鼻	護 層	護 膝	護 膚	護 膚 品	護 膚 膏	護 衛	
護 衛 隊	護 衛 艦	護 養	護 駕	護 髮	護 壁	護 壁 板	護 牆	
護 牆 板	護 欄	譽 上	譽 為	譽 寒 天 下	譽 過 其 實	譽 滿 天 下	譽 滿 全 球	
譽 滿 寰 中	贓 字	贓 污 狼 籍	贓 官	贓 物	贓 款	躊 躇	躊 躇 不 決	
躊 躇 不 定	躊 躇 不 前	躊 躇 未 決	躊 躇 滿 志	躍 入	躍 上	躍 升	躍 立	
躍 至	躍 身	躍 居	躍 居 首 位	躍 居 第 一	躍 起	躍 馬 揚 鞭	躍 動	
躍 然	躍 然 紙 上	躍 著	躍 進	躍 過	躍 遷	躍 騰	躍 躍	
躍 躍 欲 試	躋 身	躋 身 於	轟 走	轟 炸	轟 炸 員	轟 炸 機	轟 倒	
轟 動	轟 動 一 時	轟 動 效 應	轟 然	轟 隆	轟 隆 聲	轟 雷 貫 耳	轟 趕	
轟 鳴	轟 擊	轟 聲	轟 轟	轟 轟 烈 烈	轟 轟 隆 隆	轟 響	辯 口 利 舌	
辯 口 利 辭	辯 子	辯 才	辯 才 無 礙	辯 白	辯 別	辯 別 力	辯 明	
辯 法	辯 狀	辯 個	辯 家	辯 詞	辯 解	辯 解 文	辯 解 者	
辯 解 書	辯 稱	辯 駁	辯 論	辯 論 家	辯 論 術	辯 論 會	辯 題	
辯 證	辯 證 法	辯 證 家	辯 證 唯 物 主 義	辯 證 唯 物 論	辯 證 統 一	辯 證 關 係	辯 證 邏 輯	
辯 護	辯 護 人	辯 護 者	辯 護 律 師	辯 護 權	醺 醺	鐮 刀	鐳 射	
鐳 療 法	鐵 人	鐵 人 三 項	鐵 勺	鐵 叉	鐵 工 廠	鐵 中 錚 錚	鐵 公 雞	
鐵 尺	鐵 心	鐵 心 人	鐵 心 石 腸	鐵 水	鐵 片	鐵 牛	鐵 打	
鐵 打 心 腸	鐵 甲	鐵 甲 車	鐵 皮	鐵 皮 出 羽	鐵 石 心 腸	鐵 穴 逾 垣	鐵 穴 逾 牆	
鐵 匠	鐵 匠 店	鐵 合 金	鐵 扣	鐵 兵 求 火	鐵 兵 求 酥	鐵 床	鐵 形	
鐵 板	鐵 板 一 塊	鐵 板 釘 釘	鐵 杵 成 針	鐵 杵 磨 成 針	鐵 法	鐵 的	鐵 芯	
鐵 門	鐵 青	鐵 架	鐵 柵	鐵 流	鐵 炭	鐵 軍	鐵 軌	
鐵 面 御 史	鐵 面 無 私	鐵 屑	鐵 扇	鐵 拳	鐵 案	鐵 案 如 山	鐵 格 架	
鐵 栓	鐵 氧 體	鐵 砧	鐵 粉	鐵 索	鐵 釘	鐵 馬	鐵 馬 金 戈	
鐵 骨 錚 錚	鐵 圈 球	鐵 堅 仰 高	鐵 桿	鐵 桶	鐵 球	鐵 盒	鐵 棒	
鐵 棒 磨 成 針	鐵 棍	鐵 殼	鐵 渣	鐵 渣 子	鐵 畫	鐵 畫 銀 鉤	鐵 硯 磨 穿	
鐵 窗	鐵 筆	鐵 絲	鐵 絲 狀	鐵 絲 網	鐵 腕	鐵 軸	鐵 飯 碗	
鐵 黑	鐵 塔	鐵 塊	鐵 腸 石 心	鐵 路	鐵 路 分 局	鐵 路 局	鐵 路 幹 線	
鐵 路 運 輸	鐵 路 線	鐵 路 橋 樑	鐵 道	鐵 道 兵	鐵 道 部	鐵 鉗	鐵 鉤	
鐵 幕	鐵 槌	鐵 漢	鐵 管	鐵 網	鐵 網 珊 瑚	鐵 蓋	鐵 製	
鐵 製 品	鐵 隙 逾 牆	鐵 餅	鐵 餅 狀	鐵 嘴 鋼 牙	鐵 廠	鐵 撬	鐵 箱	
鐵 線	鐵 質	鐵 輪	鐵 鋅	鐵 器	鐵 壁	鐵 樹	鐵 樹 花 開	
鐵 樹 開 花	鐵 橋	鐵 橇	鐵 蹄	鐵 頭	鐵 嶺	鐵 牆 銅 壁	鐵 環	
鐵 臂	鐵 錨	鐵 鍋	鐵 錘	鐵 鍬	鐵 櫃	鐵 騎	鐵 證	
鐵 證 如 山	鐵 鏟	鐵 鏈	鐵 爐	鐵 礦	鐵 礦 石	鐵 礬 土	鐵 籠	
鐵 鹽	鐵 觀 音	鐵 釽	鐵 箍	鐵 ��	鐺 鐺	鐲 子	鐫 心 銘 骨	
鐫 刻	闢 地 開 天	闢 作	闢 為	闢 謠	霸 王	霸 王 風 月	霸 主	
霸 佔	霸 佔 地 盤	霸 氣	霸 業	霸 道	霸 據	霸 權	霸 權 主 義	
霹 靂	霹 靂 英 雄 榜	霹 靂 麻 將	露 一 手	露 才	露 才 揚 己	露 天	露 天 煤 礦	
露 天 礦	露 水	露 牙	露 出	露 白	露 尾 藏 頭	露 乳	露 底	
露 怯	露 肩	露 屍	露 相	露 背	露 面	露 面 拋 頭	露 珠	
露 酒	露 馬 腳	露 骨	露 宿	露 宿 風 餐	露 現	露 齒	露 頭	
露 頭 角	露 餡	露 濕	露 營	露 營 者	露 縫	露 膽 披 肝	露 臉	
露 點	響 了	響 水	響 石	響 地	響 尾 蛇	響 板	響 的	
響 亮	響 音	響 個	響 個 不 停	響 起	響 馬	響 動	響 笛	
響 答 影 隨	響 著	響 葫 蘆	響 遏 行 雲	響 遍	響 鈴	響 徹	響 徹 雲 際	
響 徹 雲 霄	響 鳴	響 噹 噹	響 應	響 聲	響 鞭	響 巖	顧 三 不 顧 四	
顧 大 局	顧 小 失 大	顧 不 上	顧 不 得	顧 及	顧 主	顧 左 右 而 言 他	顧 全	
顧 全 大 局	顧 全 補 牢	顧 名	顧 名 思 義	顧 曲 周 郎	顧 此 失 彼	顧 忌	顧 念	
顧 者	顧 前	顧 前 不 顧 後	顧 客	顧 後 瞻 前	顧 盼	顧 盼 生 姿	顧 盼 生 輝	
顧 盼 自 雄	顧 盼 自 豪	顧 盼 神 飛	顧 問	顧 問 公 司	顧 得 上	顧 惜	顧 復 之 恩	
顧 意	顧 影 自 憐	顧 影 弄 姿	顧 慮	顧 慮 重 重	顧 頭 不 顧 尾	饗 宴	驅 干	
驅 出	驅 去	驅 車	驅 邪	驅 邪 避 惡	驅 使	驅 迫	驅 風 劑	
驅 病	驅 除	驅 馬	驅 鬼	驅 動	驅 動 程 式	驅 動 器	驅 逐	
驅 逐 令	驅 逐 者	驅 逐 機	驅 逐 艦	驅 惡	驅 散	驅 策	驅 開	
驅 馳	驅 趕	驅 遣	驅 潛 艇	驅 駛	驅 蟲	驅 蟲 劑	驅 霧	
驅 體	驃 悍	驀 地	驀 然	騾 子	騾 夫	騾 馬	魔 力	
魔 女	魔 幻	魔 手	魔 方	魔 爪	魔 王	魔 似	魔 杖	
魔 怪	魔 法	魔 法 師	魔 界	魔 鬼	魔 鬼 般	魔 鬼 魚	魔 符	
魔 術	魔 術 師	魔 術 隊	魔 術 箱	魔 掌	魔 窟	魔 道	魔 影	
魔 盤	魔 頭	魑 魅	魑 魅 魍 魎	鰭 足	鰭 狀 肢	鰭 類	鰭 鯨	
鰥 夫	鰥 居	鰥 寡	鰥 寡 孤 獨	鶯 啼 燕 語	鶯 歌	鶯 歌 燕 舞	鶯 歌 鎮	
鶯 儔 燕 侶	鶯 類	鶴 山	鶴 立	鶴 立 雞 群	鶴 長 鳧 短	鶴 唳 風 聲	鶴 崗	
鶴 發 雞 皮	鶴 算 龜 齡	鶴 髮 童 顏	鶴 壁	麝 香	黯 淡	黯 然	黯 然 失 色	
黯 然 銷 魂	齜 牙	齜 牙 咧 嘴	儼 如	儼 然	儻 來 之 物	囈 語	囊 中	
囊 中 羞 澀	囊 內	囊 炎	囊 狀	囊 空 如 洗	囊 括	囊 胚	囊 腫	
囊 層	囊 螢 積 雪	囉 唆	囉 哩 囉 嗦	囉 嗦	孿 生	孿 生 兄 弟	孿 生 姐 妹	
巔 峰	彎 了	彎 刀	彎 下	彎 弓	彎 月	彎 回	彎 如 弓	
彎 成	彎 曲	彎 曲 處	彎 作	彎 扭	彎 角	彎 身	彎 兒	
彎 度	彎 矩	彎 著	彎 進	彎 腰	彎 路	彎 道	彎 腿	
彎 膝 禮	彎 頭	彎 彎	彎 彎 曲 曲	攤 入	攤 子	攤 分	攤 主	
攤 付	攤 位	攤 車	攤 兒	攤 店	攤 派	攤 配	攤 售	
攤 販	攤 提	攤 牌	攤 費	攤 進	攤 開	攤 銷	攤 還	
攤 點	攤 雞 蛋	攤 攤	權 力	權 力 下 放	權 力 機 關	權 且	權 外	
權 臣	權 位	權 作	權 利	權 利 人	權 杖	權 宜	權 宜 之 計	
權 威	權 威 人 士	權 威 性	權 柄	權 要	權 限	權 值	權 益	
權 能	權 能 區 分	權 欲 熏 心	權 略	權 術	權 責	權 詐	權 貴	
權 鈞 力 齊	權 傾 中 外	權 傾 天 下	權 勢	權 豪 勢 要	權 數	權 衡	權 衡 利 弊	
權 衡 者	權 衡 輕 重	權 謀	權 錢 交 易	權 職	權 證	權 屬	權 變 鋒 出	
歡 天	歡 天 喜 地	歡 心	歡 心 若 狂	歡 快	歡 呼	歡 呼 雀 躍	歡 呼 雷 動	
歡 呼 聲	歡 欣	歡 欣 鼓 舞	歡 欣 踴 躍	歡 迎	歡 迎 光 臨	歡 迎 垂 詢	歡 迎 宴 會	
歡 迎 惠 顧	歡 迎 詞	歡 迎 會	歡 迎 儀 式	歡 度	歡 眉 喜 眼	歡 若 平 生	歡 苗 愛 葉	
歡 娛	歡 娛 嫌 夜 短	歡 宴	歡 悅	歡 笑	歡 送	歡 送 會	歡 迸 亂 跳	
歡 酒	歡 唱	歡 喜	歡 場	歡 愉	歡 然	歡 跳	歡 暢	
歡 歌 笑 語	歡 聚	歡 聚 一 堂	歡 慶	歡 樂	歡 樂 歌	歡 鬧	歡 聲	
歡 聲 笑 語	歡 聲 雷 動	歡 蹦 亂 跳	歡 顏	歡 騰	歡 躍	歡 歡 喜 喜	歡 忻 鼓 舞	
歡 忻 踴 躍	灑 了	灑 上	灑 水	灑 水 器	灑 出	灑 地	灑 掃	
灑 淚	灑 脫	灑 透	灑 落	灑 遍	灑 滿	灑 潑	灑 藥	
灑 灑	灘 上	灘 地	灘 塗	灘 裝	灘 頭	灘 頭 陣	灘 頭 堡	
疊 加	疊 句	疊 平	疊 印	疊 合	疊 好	疊 字	疊 式	
疊 床 架 屋	疊 矩 重 規	疊 起	疊 接	疊 詞	疊 蓋	疊 層	疊 羅 漢	
疊 韻	疊 嶂	癮 君 子	癬 疥	癬 疥 之 疾	禳 補	籠 子	籠 中	
籠 中 之 鳥	籠 中 窮 鳥	籠 內	籠 火	籠 式	籠 咚	籠 屜	籠 統	
籠 絡	籠 絡 人 心	籠 街 喝 道	籠 罩	籠 頭	聾 了	聾 人	聾 子	
聾 盲	聾 啞	聾 啞 人	聾 啞 者	聾 得	聽 了	聽 人	聽 人 穿 鼻	
聽 人 擺 佈	聽 力	聽 力 表	聽 力 計	聽 不	聽 不 見	聽 不 到	聽 不 進	
聽 不 懂	聽 之	聽 之 任 之	聽 天 由 命	聽 天 任 命	聽 他	聽 出	聽 任	
聽 而 不 聞	聽 而 無 聞 視 而 不 見	聽 完	聽 我	聽 見	聽 事	聽 使	聽 來	
聽 其 自 然	聽 其 言 而 觀 其 行	聽 到	聽 取	聽 取 批 評	聽 取 匯 報	聽 取 意 見	聽 命	
聽 者	聽 信	聽 便	聽 度 計	聽 後	聽 政	聽 風	聽 風 是 雨	
聽 風 聽 水	聽 候	聽 候 處 理	聽 差	聽 書	聽 起	聽 起 來	聽 骨	
聽 做	聽 得	聽 得 見	聽 從	聽 清	聽 眾	聽 眾 席	聽 筒	
聽 著	聽 診	聽 診 器	聽 想	聽 裝	聽 話	聽 過	聽 厭	
聽 慣	聽 聞	聽 說	聽 說 讀 寫	聽 審	聽 寫	聽 課	聽 憑	
聽 膩	聽 錯	聽 頭	聽 懂	聽 戲	聽 講	聽 證	聽 覺	
聽 覺 型	聽 覺 學	聽 聽	聽 觀	臟 腑	臟 器	襲 以 成 俗	襲 占	
襲 用	襲 來	襲 取	襲 者	襲 擊	襲 擊 者	襲 擊 戰	襲 擾	
襯 出	襯 布	襯 托	襯 衣	襯 底	襯 映	襯 衫	襯 面	
襯 頁	襯 料	襯 紙	襯 裙	襯 裡	襯 墊	襯 領	襯 褲	
襯 邊	讀 一 遍	讀 入	讀 下	讀 不 捨 手	讀 友	讀 曰	讀 出	
讀 卡	讀 卡 機	讀 它	讀 本	讀 字	讀 成	讀 串	讀 作	
讀 完	讀 來	讀 到	讀 取	讀 性	讀 法	讀 物	讀 者	
讀 後	讀 後 感	讀 為	讀 秒	讀 重 音	讀 音	讀 唇 法	讀 唇 術	
讀 書	讀 書 人	讀 得	讀 報	讀 著	讀 進	讀 經 者	讀 過	
讀 圖	讀 寫	讀 數	讀 熟	讀 盤	讀 罷	讀 賣	讀 閱	
讀 錯	讀 懂	贖 回	贖 身	贖 取	贖 命	贖 金	贖 款	
贖 買	贖 當	贖 罪	贖 職	贗 本	贗 品	贗 幣	躑 地	
躑 躅	酈 寄 賣 友	鑄 山 煮 海	鑄 工	鑄 件	鑄 成	鑄 版	鑄 金	
鑄 型	鑄 術	鑄 造	鑄 造 物	鑄 造 品	鑄 造 廠	鑄 塊	鑄 鼎 象 物	
鑄 像	鑄 幣	鑄 模	鑄 錠	鑄 鋼	鑄 鐘	鑄 鐵	鑑 別	
鑑 定	鑒 毛 辨 色	鑒 別	鑒 別 力	鑒 戒	鑒 定	鑒 定 人	鑒 定 委 員 會	
鑒 定 者	鑒 定 家	鑒 定 會	鑒 定 證 書	鑒 往	鑒 往 知 來	鑒 於	鑒 於 此 　	
鑒 明	鑒 貌 辨 色	鑒 賞	鑒 賞 力	鑒 賞 家	鑒 賞 能 力	鑒 識	霽 月 光 風	
韃 子	韃 靼	韃 靼 人	韁 繩	顫 抖	顫 抖 著	顫 音	顫 動	
顫 悠	顫 悸	顫 慄	顫 鳴	顫 鳴 聲	顫 聲	顫 巍 巍	顫 顫 巍 巍	
饕 口 貪 舌	饕 餮	饕 餮 者	驕 兵 必 敗	驕 兵 自 敗	驕 狂	驕 兒	驕 者	
驕 矜	驕 氣	驕 奢	驕 奢 淫 佚	驕 奢 淫 逸	驕 陽	驕 傲	驕 傲 自 滿	
驕 慢	驕 嬌 二 氣	驕 敵	驕 橫	驕 縱	驍 勇	驍 悍	驍 將	
髒 了	髒 兮 兮	髒 手	髒 水	髒 字	髒 污	髒 污 著	髒 物	
髒 亂	髒 亂 差	髒 話	髒 錢	鬚 子	鬚 眉	鬚 眉 交 白	鬚 眉 男 子	
鬚 根	鬚 髮	鱉 魚	鱉 類	鰱 魚	鰻 草	鰻 魚	鰻 鱺	
鷓 鴣	鷗 類	鼴 鼠	龔 行 天 罰	巖 心	巖 石	巖 石 圈	巖 石 學	
巖 穴	巖 穴 之 士	巖 床	巖 居 穴 處	巖 居 谷 飲	巖 狀	巖 流	巖 洞	
巖 脈	巖 茶	巖 棉	巖 渣	巖 畫	巖 溶	巖 溶 地 貌	巖 葬	
巖 層	巖 漿	巖 漿 巖	巖 質	巖 壁	巖 礁	巖 類	巖 鹽	
戀 人	戀 女	戀 父	戀 母	戀 生 惡 死	戀 曲	戀 狂	戀 物	
戀 家	戀 酒 迷 花	戀 酒 貪 色	戀 酒 貪 杯	戀 酒 貪 花	戀 情	戀 貧 恤 老	戀 貧 恤 苦	
戀 棧	戀 著	戀 愛	戀 新 忘 舊	戀 詩	戀 歌	戀 慕	戀 癖	
戀 舊	戀 戀	戀 戀 不 捨	戀 戀 難 捨	攣 縮	攫 住	攫 取	攫 戾 執 猛	
攫 奪	攪 勻	攪 合	攪 局	攪 和	攪 拌	攪 拌 棒	攪 拌 器	
攪 海 翻 江	攪 動	攪 混	攪 蛋 器	攪 散	攪 渾	攪 亂	攪 亂 器	
攪 碎	攪 過	攪 濁	攪 擾	攪 翻	曬 太 陽	曬 台	曬 成	
曬 衣 用	曬 衣 夾	曬 衣 柱	曬 衣 架	曬 衣 繩	曬 架	曬 乾	曬 得	
曬 場	曬 斑	曬 黑	曬 煙	曬 圖	曬 圖 紙	曬 網	曬 曬	
曬 鹽	竊 犯	竊 玉 偷 香	竊 用	竊 名	竊 位	竊 位 素 餐	竊 弄 威 權	
竊 走	竊 取	竊 幸 乘 寵	竊 物	竊 案	竊 笑	竊 國	竊 密	
竊 喜	竊 盜	竊 盜 犯	竊 盜 犯 罪	竊 盜 案	竊 盜 罪	竊 盜 癖	竊 賊	
竊 鉤 竊 國	竊 據	竊 謂	竊 癖	竊 簪 之 臣	竊 鐘 掩 耳	竊 聽	竊 聽 器	
竊 竊	竊 竊 私 語	竊 竊 細 語	籤 條	纓 花	纓 絡	纖 小	纖 手	
纖 毛	纖 巧	纖 芥	纖 指	纖 弱	纖 悉 不 遺	纖 細	纖 腰	
纖 道	纖 塵	纖 塵 不 染	纖 維	纖 維 性	纖 維 板	纖 維 狀	纖 維 症	
纖 維 素	纖 維 瘤	纖 維 鏡	纖 繩	纖 纖	蘸 上	蘸 火	蘸 筆	
蘸 濕	蘿 倫 希 爾	蘿 蔔	蘿 蔔 糕	蠱 惑	蠱 惑 人 心	變 了	變 了 色	
變 大	變 小	變 干	變 化	變 化 不 測	變 化 多 端	變 化 性	變 化 莫 測	
變 化 無 方	變 化 無 常	變 化 無 窮	變 化 萬 端	變 天	變 少	變 幻	變 幻 不 測	
變 幻 風 雲	變 幻 莫 測	變 幻 無 常	變 心	變 出	變 去	變 古 亂 常	變 平	
變 本	變 本 加 厲	變 生 肘 腋	變 白	變 危 為 安	變 名 易 姓	變 好	變 成	
變 灰	變 老	變 色	變 色 蜥	變 色 龍	變 色 鏡	變 位	變 低	
變 冷	變 址	變 址 數	變 局	變 弄	變 形	變 形 蟲	變 更	
變 更 部 署	變 身	變 來	變 來 變 去	變 其	變 卦	變 味	變 性	
變 易	變 松	變 法	變 的	變 直	變 空	變 者	變 長	
變 阻	變 阻 器	變 亮	變 厚	變 奏	變 奏 曲	變 度	變 故	
變 故 易 常	變 流 器	變 為	變 相	變 相 剝 削	變 相 漲 價	變 紅	變 美	
變 苦	變 革	變 革 時 代	變 音	變 風 改 俗	變 風 易 俗	變 倍	變 值	
變 容	變 差	變 弱	變 格	變 狹	變 窄	變 脆	變 起 蕭 牆	
變 乾	變 做	變 動	變 參	變 強	變 得	變 得 不 同	變 得 微 弱	
變 得 複 雜	變 淡	變 淺	變 清	變 深	變 現	變 甜	變 產	
變 異	變 異 性	變 異 株	變 粗	變 細	變 被 動 為 主 動	變 軟	變 通	
變 速	變 速 運 動	變 速 箱	變 速 器	變 換	變 換 式	變 換 器	變 焦	
變 焦 距	變 短	變 硬	變 硬 了	變 量	變 黃	變 黑	變 亂	
變 感 器	變 新	變 暗	變 暖	變 溫	變 矮	變 節	變 節 者	
變 跡 埋 名	變 電	變 電 所	變 電 站	變 態	變 態 反 應	變 態 心 理 學	變 態 性	
變 慢	變 種	變 緊	變 說	變 輕	變 酸	變 價	變 寬	
變 廢 為 寶	變 徵 之 聲	變 數	變 樣	變 熱	變 瘦	變 瞎	變 調	
變 賣	變 質	變 遷	變 遷 興 衰	變 濃	變 頻	變 頻 管	變 優 美	
變 壓	變 壓 器	變 戲 法	變 濕	變 聲	變 臉	變 薄	變 醜	
變 舊	變 藍	變 顏 色	變 壞	變 壞 事 為 好 事	變 鹹	變 髒	變 體	
邏 輯	邏 輯 上	邏 輯 和	邏 輯 性	邏 輯 型	邏 輯 思 維	邏 輯 推 理	邏 輯 設 計	
邏 輯 學	鑠 石 流 金	顯 出	顯 目	顯 示	顯 示 卡	顯 示 器	顯 光 管	
顯 名	顯 而	顯 而 易 見	顯 色	顯 位	顯 形	顯 見	顯 身	
顯 身 手	顯 來	顯 姓 揚 名	顯 性	顯 明	顯 型	顯 要	顯 要 位 置	
顯 祖 揚 宗	顯 祖 榮 宗	顯 神	顯 得	顯 液	顯 現	顯 現 日	顯 眼	
顯 揚	顯 然	顯 著	顯 著 成 績	顯 著 面	顯 著 特 點	顯 貴	顯 微	
顯 微 圖	顯 微 學	顯 微 鏡	顯 聖	顯 達	顯 像	顯 像 管	顯 像 劑	
顯 赫	顯 赫 一 時	顯 影	顯 影 劑	顯 學	顯 親 揚 名	顯 擺	顯 職	
顯 證	顯 耀	顯 露	顯 靈	顯 觀	驚 人	驚 弓 之 鳥	驚 才 絕 艷	
驚 天	驚 天 動 地	驚 心	驚 心 動 魄	驚 世 駭 俗	驚 叫	驚 呆	驚 走	
驚 呼	驚 奇	驚 弦 之 鳥	驚 怕	驚 采 絕 艷	驚 為	驚 風	驚 風 駭 浪	
驚 飛	驚 倒	驚 恐	驚 恐 萬 狀	驚 起	驚 退	驚 動	驚 動 人	
驚 得	驚 悉	驚 悸	驚 異	驚 蛇 入 草	驚 訝	驚 厥	驚 喜	
驚 愕	驚 惶	驚 惶 失 色	驚 惶 失 措	驚 惶 無 措	驚 視	驚 跑	驚 慌	
驚 慌 失 措	驚 羨	驚 蜇	驚 詫	驚 跳	驚 疑	驚 魂	驚 魂 未 定	
驚 歎	驚 歎 不 已	驚 醒	驚 險	驚 駭	驚 嚇	驚 濤	驚 濤 駭 浪	
驚 避	驚 鴻	驚 擾	驚 覺	驚 懼	驚 諤	驚 蟄	驛 書	
驛 站	驛 馬	驛 捨	驛 道	驗 上	驗 中	驗 方	驗 光	
驗 光 師	驗 收	驗 收 報 告	驗 血	驗 尿	驗 迄	驗 乳 計	驗 性	
驗 放	驗 明	驗 物	驗 者	驗 屍	驗 查	驗 看	驗 訖	
驗 教	驗 票	驗 貨	驗 發	驗 傷	驗 資	驗 過	驗 電	
驗 電 筆	驗 電 器	驗 算	驗 說	驗 戮	驗 線	驗 歷	驗 聲	
驗 證	驗 證 人	驗 關	驗 驗	髓 膜	髓 質	體 力	體 力 不 支	
體 力 勞 動	體 大	體 大 思 精	體 工 隊	體 中	體 內	體 火	體 外	
體 式	體 形	體 改	體 改 委	體 系	體 系 化	體 育	體 育 人 物	
體 育 用 品	體 育 用 品 業	體 育 事 業	體 育 委 員 會	體 育 活 動	體 育 界	體 育 健 兒	體 育 組	
體 育 部	體 育 場	體 育 愛 好 者	體 育 新 聞	體 育 會	體 育 運 動	體 育 道 德	體 育 館	
體 育 鍛 煉	體 育 競 賽	體 例	體 制	體 制 改 革	體 協	體 味	體 委	
體 委 會	體 征	體 念	體 狀	體 虱	體 表	體 型	體 恤	
體 毒	體 胖	體 重	體 面	體 弱	體 弱 多 病	體 悟	體 校	
體 格	體 能	體 臭	體 院	體 高	體 國 經 野	體 液	體 現	
體 統	體 細 胞	體 無 完 膚	體 腔	體 裁	體 視	體 貼	體 貼 入 微	
體 感	體 會	體 溫	體 溫 計	體 節	體 圖	體 察	體 態	
體 罰	體 貌	體 諒	體 質	體 魄	體 壇	體 操	體 操 家	
體 操 隊	體 操 賽	體 撿	體 積	體 積 計	體 檢	體 總	體 蟲	
體 驗	體 驗 生 活	鱔 魚	鱗 爪	鱗 片	鱗 甲	鱗 次	鱗 次 櫛 比	
鱗 狀	鱗 翅	鱗 翅 類	鱗 莖	鱗 傷	鱗 點	鱗 癬	鱖 魚	
麟 子 鳳 雛	麟 肝 鳳 髓	麟 角 鳳 毛	麟 角 鳳 距	麟 角 鳳 嘴	麟 洛 鄉	麟 趾 呈 祥	麟 鳳 龜 龍	
黴 素	黴 菌	黴 菌 病	黴 漿 菌	囑 人	囑 目	囑 托	囑 咐	
壩 子	壩 址	壩 身	壩 基	攬 子	攬 在	攬 活	攬 貨	
攬 勝	攬 權	攬 權 納 賄	攬 轡 澄 清	癱 子	癱 坐	癱 軟	癱 瘓	
癲 狂	癲 狀	癲 風	癲 間	癲 癇	矗 立	罐 子	罐 車	
罐 兒	罐 裝	罐 蓋	罐 頭	罐 頭 食 品	罐 頭 裝	罐 頭 類	罐 籠	
罐 罐	羈 押	羈 留	羈 絆	蠶 卵	蠶 豆	蠶 食	蠶 食 鯨 吞	
蠶 桑	蠶 絲	蠶 絲 被	蠶 絲 業	蠶 蛹	蠶 蛾	蠶 種	蠶 繭	
蠶 蟻	蠶 屬	蠹 居 棋 處	蠹 國 殃 民	蠹 國 害 民	衢 州	衢 縣	讓 人	
讓 予	讓 他	讓 出	讓 先	讓 位	讓 你	讓 利	讓 我	
讓 步	讓 走	讓 事 實 說 話	讓 受	讓 座	讓 售	讓 棗 推 梨	讓 給	
讓 開	讓 路	讓 與	讓 與 人	讓 與 物	讓 價	讓 賢	讓 禮 一 寸 得 禮 一 尺	
讒 言	讒 害	讒 涎	讒 誕 欲 滴	讖 緯	艷 史	艷 如 桃 李	艷 曲 淫 詞	
艷 色 絕 世	艷 色 耀 目	艷 美 無 敵	艷 情	艷 絕 一 時	艷 陽	艷 羨	艷 詩	
艷 遇	艷 福	艷 麗	艷 麗 奪 目	贛 州	贛 江	釀 中	釀 成	
釀 成 大 禍	釀 酒	釀 酒 人	釀 酒 人 隊	釀 造	釀 造 所	釀 造 者	釀 造 酒	
釀 造 學	釀 禍	釀 蜜	釀 製	靂 聲	靈 山	靈 川	靈 丹	
靈 丹 妙 藥	靈 丹 聖 藥	靈 牙 俐 齒	靈 台	靈 巧	靈 石	靈 光	靈 曲	
靈 肉	靈 位	靈 車	靈 怪	靈 性	靈 武	靈 物	靈 知	
靈 芝	靈 長 類	靈 便	靈 前	靈 柩	靈 柩 台	靈 柩 車	靈 活	
靈 活 多 樣	靈 活 性	靈 活 經 營	靈 活 機 動	靈 家	靈 效	靈 氣	靈 堂	
靈 敏	靈 敏 性	靈 敏 度	靈 符	靈 蛇 之 珠	靈 通	靈 鳥	靈 傑	
靈 塔	靈 感	靈 寢	靈 魂	靈 機	靈 機 一 動	靈 璧	靈 糧 堂	
靈 藥	靈 寶	靈 驗	顰 眉	驟 至	驟 雨	驟 雨 狂 風	驟 降	
驟 起	驟 減	驟 然	驟 落	驟 增	驟 燃	驟 變	鬢 毛	
鬢 角	鬢 髮	鬢 髮 斑 白	鷹 爪	鷹 犬	鷹 派	鷹 般	鷹 巢	
鷹 揚 虎 視	鷹 鉤	鷹 鉤 鼻	鷹 鼻 鷂 眼	鷹 嘴	鷹 潭	鷹 類	鷹 瞵 鶚 視	
鷺 類	鷺 鷥	鹼 土	鹼 土 金 屬	鹼 化	鹼 水	鹼 水 湖	鹼 地	
鹼 式	鹼 性	鹼 性 化	鹼 金 屬	鹼 度	鹼 洗	鹼 基	鹼 液	
鹼 場	鹼 熔	鹼 酸	鹼 質	鹼 類	鹽 土	鹽 工	鹽 井	
鹽 分	鹽 巴	鹽 水	鹽 水 湖	鹽 水 鎮	鹽 田	鹽 份	鹽 味	
鹽 性	鹽 析	鹽 花	鹽 城	鹽 區	鹽 商	鹽 鹵	鹽 場	
鹽 湖	鹽 量 計	鹽 業	鹽 酸	鹽 價	鹽 層	鹽 霜	鹽 類	
鹽 灘	鹽 鹼	鹽 鹼 地	鹽 鹼 灘	鹽 埕 區	齷 齪	齲 齒	廳 局	
廳 局 長	廳 局 級	廳 房	廳 長	廳 堂	廳 裡	灣 內	灣 仔	
籬 牢 犬 不 入	籬 柵	籬 笆	籬 壁 間 物	籬 牆	籮 筐	蠻 人	蠻 力	
蠻 不 講 理	蠻 化	蠻 地	蠻 夷	蠻 好	蠻 行	蠻 勁	蠻 荒	
蠻 幹	蠻 像	蠻 橫	蠻 橫 無 理	觀 上	觀 天	觀 日	觀 止	
觀 火	觀 台	觀 光	觀 光 百 貨	觀 光 局	觀 光 事 業	觀 光 協 會	觀 光 夜 市	
觀 光 股	觀 光 客	觀 光 旅 遊	觀 光 茶 園	觀 色	觀 形 察 色	觀 念	觀 念 更 新	
觀 念 學	觀 者	觀 者 如 市	觀 者 如 堵	觀 者 如 雲	觀 者 如 織	觀 者 雲 集	觀 花	
觀 花 賞 景	觀 後	觀 看	觀 看 者	觀 致	觀 音	觀 音 洞	觀 音 鄉	
觀 風	觀 海	觀 望	觀 眾	觀 眾 席	觀 掌	觀 景	觀 測	
觀 測 所	觀 測 者	觀 測 站	觀 象	觀 象 台	觀 象 儀	觀 感	觀 過 知 仁	
觀 察	觀 察 力	觀 察 所	觀 察 者	觀 察 員	觀 察 家	觀 察 家 報	觀 察 站	
觀 察 儀 器	觀 說	觀 貌 察 色	觀 摩	觀 摩 教 學	觀 摩 會	觀 摩 演 出	觀 摹	
觀 潮 派	觀 賞	觀 賞 植 物	觀 賞 價 值	觀 戰	觀 機 而 動	觀 濤	觀 點	
觀 禮	觀 禮 台	觀 釁 伺 隙	躡 手 躡 腳	躡 足	躡 足 潛 蹤	躡 影 追 風	釁 起 蕭 牆	
釁 發 蕭 牆	鑲 入	鑲 上	鑲 木	鑲 牙	鑲 牙 學	鑲 以	鑲 石	
鑲 在	鑲 金	鑲 嵌	鑲 嵌 物	鑲 嵌 著	鑲 補	鑲 邊	鑲 邊 石	
鑲 寶 石	鑰 孔	鑰 匙	鑰 匙 孔	鑰 匙 圈	顱 內	顱 骨	顱 腔	
饞 言 佞 語	饞 嘴	饞 慝 之 口	饞 誕 欲 垂	饞 獠 生 誕	髖 骨	髖 部	矚 目	
讚 不 絕 口	讚 佩	讚 美	讚 美 詩	讚 美 歌	讚 許	讚 揚	讚 頌	
讚 頌 者	讚 歌	讚 歎	讚 歎 著	讚 賞	讚 聲 不 絕	讚 辭	讚 譽	
鑷 子	驢 子	驢 心 狗 肺	驢 叫	驢 生 戟 角	驢 生 笄 角	驢 車	驢 前 馬 後	
驢 唇 不 對 馬 嘴	驢 唇 馬 嘴	驢 鳴 狗 吠	驢 頭 不 對 馬 嘴	驢 糞	驢 騾	驥 子 龍 文	驥 服 鹽 車	
纜 車	纜 索	纜 索 道	纜 道	纜 線	纜 繩	讜 言 直 聲	讜 言 嘉 論	
讜 論 侃 侃	鑽 入	鑽 子	鑽 井	鑽 井 人	鑽 井 隊	鑽 天 打 洞	鑽 孔	
鑽 孔 器	鑽 孔 錐	鑽 心	鑽 心 蟲	鑽 火 得 冰	鑽 牛 角 尖	鑽 出	鑽 石	
鑽 全 實 業	鑽 床	鑽 戒	鑽 求	鑽 具	鑽 到	鑽 空 子	鑽 洞	
鑽 研	鑽 探	鑽 桿	鑽 通	鑽 進	鑽 開	鑽 塔	鑽 緊	
鑽 機	鑽 頭	鑽 頭 就 鎖	鑽 營	鑽 鑽	鑽 剉	鑼 鼓	鑼 鼓 喧 天	
鑼 聲	鱷 魚	鱷 魚 皮	鱷 魚 眼 淚	鱸 魚	黷 武	黷 武 窮 兵	鑿 子	
鑿 山	鑿 孔	鑿 石	鑿 石 場	鑿 成	鑿 刻	鑿 空	鑿 空 指 鹿	
鑿 洞	鑿 穿	鑿 船 蟲	鑿 通	鑿 開	鑿 圓 枘 方	鑿 溝	鑿 壁 偷 光	
鑿 壁 懸 樑	鑿 隧 道	鑿 鑿	鑿 鑿 可 據	鑿 鑿 有 據	鸚 鵡	鸚 鵡 病	鸚 鵡 學 舌	
鬱 金 香	鬱 閉	鬱 悶	鬱 結	鬱 積	鬱 鬱	鬱 鬱 不 樂	鬱 鬱 寡 歡	
鬱 鬱 蔥 蔥	鬱 悒	鸞 翔 鳳 集	鸞 翔 鳳 翥	鸞 鳳	鸞 鳳 和 鳴	鸞 飄 鳳 泊	鸞 飄 鳳 翥	
籲 請	�B 食 粗 衣	�B 食 粗 餐	�� 子	�� 胺	囗 渴	夯 雀 先 飛	夯 實	
尻 輪 神 馬	尻 輿 神 馬	伎 倆	伢 子	囡 囡	奼 紫 嫣 紅	扦 插	旮 旯	
氘 核	汜 濫	佤 族	坌 鳥 先 飛	夆 典 工 程	忐 忑	忐 忑 不 安	忐 忑 不 定	
忡 忡	忤 逆 不 孝	忻 忻 得 意	旰 食 之 勞	旰 食 宵 衣	沏 茶	汩 聲	汩 汩	
疔 瘡	芎 林 鄉	芊 芊	佼 佼	佶 屈 聱 牙	佶 優	侄 女	侄 子	
侄 外	侄 兒	侄 孫	侄 甥	侄 媳	侄 媳 婦	侗 族	侔 色 揣 稱	
冼 手	咂 嘴	咂 嘴 弄 舌	呤 唱	呤 呤	囹 圄	坯 子	坯 布	
坯 砌	坯 料	孢 子	孢 子 囊	孢 囊	怦 然	怦 怦	怙 惡 不 改	
怙 惡 不 悛	昃 食 宵 衣	枘 圓 鑿 方	沓 沓	泫 然	泔 水	炔 烴	狒 狒	
矸 石	邯 鄲	邯 鄲 學 步	邰 智 源	剉 刀	剉 切	剉 去	厘 升	
厘 米	厘 米 波	哆 嗦	哆 哆 嗦 嗦	呲 牙	垛 上	垛 口	峇 里 島	
恂 恂 善 誘	挎 包	挎 著	昶 和 纖 維	枷 鎖	枵 腸 轆 轆	枵 腹 重 趼	枵 腹 從 公	
洄 游	洄 瀾	炷 香	砒 霜	紈 胯 子 弟	紈 胯 弟 子	耷 拉	苫 布	
苫 眼 舖 眉	倜 儻	倜 儻 不 群	倜 儻 不 羈	悒 悒 不 樂	悒 悒 不 歡	捅 了	捅 穿	
捅 破	捅 馬 蜂 窩	捅 婁 子	挹 彼 注 此	挹 彼 注 茲	挹 淚 揉 眵	捋 袖	捋 袖 揎 拳	
捋 臂 揎 拳	桉 樹	桎 梏	浣 熊	珥 金 拖 紫	祛 風	祛 病	祛 除	
祛 鬼	祛 暑	祛 痰	祛 蠹 除 奸	秭 歸	笊 籬	茭 白	茜 素	
茯 苓	茬 口	蚍 蜉	蚍 蜉 撼 大 樹	蚍 蜉 撼 樹	蚍 蜉 戴 盆	蚝 油	衾 寒 枕 冷	
衾 影 無 慚	豇 豆	陟 岵 瞻 望	啐 了	啐 聲	啥 子	啥 受	啥 病	
埴 土	庹 宗 華	悱 惻	掂 斤 估 兩	掂 斤 抹 兩	掂 斤 播 兩	掂 量	掂 掂	
掂 掇	掎 裳 連 袂	掇 乖 弄 俏	掇 青 拾 紫	掇 拾	掐 尖 落 鈔	掐 死	掐 住	
掐 指	掐 掉	掐 滅	掐 算	掐 緊	掐 頭 去 尾	掐 斷	捭 闔	
捭 闔 縱 橫	桴 鼓 相 應	烷 基	烷 烴	烴 類	猝 倒	猝 病	猝 然	
猞 猁	硌 牙	硌 破	硅 土	硅 片	硅 石	硅 油	硅 酸	
硅 酸 鈉	硅 酸 鉛	硅 酸 鹽	硅 膠	硅 質	硅 橡 膠	硅 鋼	硅 鋼 片	
硅 藻	硅 藻 土	硅 鐵	秸 桿	秸 稈	笤 帚	笸 籮	粘 上	
粘 土	粘 牙	粘 皮 帶 骨	粘 合	粘 合 性	粘 合 劑	粘 在	粘 有	
粘 住	粘 牢	粘 固	粘 帖	粘 性	粘 板	粘 花 惹 草	粘 花 惹 絮	
粘 附	粘 附 力	粘 度	粘 染	粘 液	粘 液 素	粘 液 質	粘 連	
粘 結	粘 絲 體	粘 著	粘 著 性	粘 著 劑	粘 貼	粘 貼 處	粘 塊	
粘 稠	粘 滯	粘 滯 度	粘 緊	粘 彈 性	粘 膜	粘 膜 炎	粘 膠	
粘 膠 布	粘 質	粘 質 物	粘 劑	粘 蟲	粘 粘	羝 羊 觸 藩	脛 骨	
舳 艫 千 里	舳 艫 相 接	舳 艫 相 繼	趿 拉	逋 逃 之 臣	逋 慢 之 罪	郴 州	酚 □	
酚 醛	酚 醛 塑 料	酚 醛 樹 脂	釬 子	釬 頭	傣 族	喑 嗚 叱 吒	婺 源	
婺 劇	崽 子	掰 開	掰 掰	揎 拳 捋 袖	揠 苗 助 長	揶 揄	氰 化	
氰 化 物	氰 化 氫	氰 化 鉀	氰 氨	氰 基	氰 酸	氰 銨	氰 胺	
猢 猻	痧 子	痤 瘡	硭 硝	菏 澤	莿 桐	莿 桐 鄉	菖 蒲	
詘 寸 伸 尺	詘 寸 信 尺	詒 厥 之 謀	詒 厥 孫 謀	鈦 合 金	僂 病	嗝 兒	嗔 怪	
嗔 怒	嗄 吱	嗩 吶	嗒 聲	嗖 地	嗖 聲	嗖 嗖	嵊 泗	
嵬 然 不 動	徭 役	搠 筆 巡 街	搦 管 操 斛	摁 扣	摁 釘	摀 住	椿 材	
椿 萱 開 貌	椿 樹	椽 子	椴 木	椴 樹	歃 血 而 盟	歃 血 為 盟	歃 血 為 誓	
滁 州	滁 縣	煢 煢 孑 立	煢 煢 孤 立	煸 炒	痼 疾	痼 習	痼 癖	
睚 眥 之 私	睚 眥 之 怨	睚 眥 之 嫌	睚 眥 之 隙	睚 眥 必 報	稗 子	稗 史	稗 官 小 說	
稗 官 野 史	筱 麥	粲 然 可 觀	綆 短 汲 深	羥 基	羧 基	羧 酸	艄 公	
葑 菲 之 采	觥 籌 交 錯	誆 言 詐 語	誆 騙	趑 趄 不 前	趑 趄 卻 顧	趔 趄	跬 步 千 里	
跬 步 不 離	跣 足 科 頭	跫 然 足 音	遒 文 壯 節	遒 勁	酯 化	鈺 創 科 技	鉬 肥	
鉬 鋼	鳧 水	鳧 趨 雀 躍	僳 族	嘧 啶	嘁 嘁 喳 喳	嫠 不 恤 緯	嫠 緯 之 憂	
慪 氣	摶 沙 作 飯	摶 沙 嚼 蠟	摶 砂 弄 汞	摶 香 弄 粉	摳 心 挖 肚	摳 心 挖 膽	摳 出	
摳 門	摳 破	撂 下	撂 手	撂 交	撂 在	撂 挑 子	槙 原 敬 之	
殞 身 碎 首	殞 命	漉 漉	漚 肥	漚 糞	漭 漭	熏 天 嚇 地	熏 心	
熏 肉	熏 制	熏 制 者	熏 制 廠	熏 染	熏 烤	熏 得	熏 陶	
熏 著	熏 腐 之 餘	熏 蒸	瘊 子	皸 裂	皸 腫	瞅 見	瞅 著	
碲 化 物	碴 土	碴 子	碴 兒	碭 山	箍 咒	箅 子	粼 粼	
緋 色 新 聞	緋 紅	緋 聞	蒺 藜	蒹 葭 倚 玉	蓖 麻	蜚 言	蜚 英 騰 茂	
蜚 短 流 長	蜚 聲	裱 好	裱 畫	裱 糊	裱 糊 匠	裾 馬 襟 牛	踉 踉 蹌 蹌	
踉 蹌	銥 金	銥 金 筆	儆 百	儆 猴	噁 心	噘 嘴	嶗 山	
憋 了	憋 氣	憋 悶	憋 著	憋 腳	撅 起	撅 嘴	撣 子	
撣 去	撣 灰	撣 帚	樗 櫟 庸 才	澇 災	澇 害	潢 池 弄 兵	潢 潦 可 薦	
熠 熠	熵 值	獠 牙	瘞 玉 埋 香	瘙 癢	糌 粑	羰 基	舖 下	
舖 上	舖 子	舖 天 蓋 地	舖 戶	舖 以	舖 平	舖 平 道 路	舖 瓦	
舖 石	舖 地	舖 地 石	舖 地 板	舖 地 毯	舖 在	舖 好	舖 成	
舖 有	舖 行	舖 位	舖 床	舖 沙	舖 底	舖 板	舖 眉 苫 眼	
舖 砌	舖 軌	舖 面	舖 面 於	舖 席	舖 席 子	舖 草	舖 草 坪	
舖 張	舖 張 浪 費	舖 張 揚 厲	舖 排	舖 敘	舖 瓷 磚	舖 設	舖 陳	
舖 開	舖 路	舖 路 工	舖 路 石	舖 道	舖 墊	舖 滿	舖 磁	
舖 管	舖 網	舖 蓋	舖 蓋 卷	舖 橋 面	舖 築	舖 謀 定 計	舖 錦 列 繡	
舖 鐵 軌	舖 舖	蔻 丹	蓽 門 圭 竇	蓽 露 藍 縷	蓽 露 藍 蔞	踮 著 腳	踮 腳	
踔 厲 風 發	鋃 鐺	鋃 鐺 入 獄	鋌 而 走 險	靚 女	靚 仔	餑 約	餑 餑	
鴇 母	噠 噠	憨 子	憨 直	憨 厚	憨 笑	憨 腦	憨 態	
憨 態 可 掬	憨 頭	擗 踴 拊 心	殫 心 竭 慮	殫 見 洽 聞	殫 思 極 慮	殫 智 竭 力	殫 誠 畢 慮	
殫 精 畢 力	殫 精 畢 思	殫 精 極 思	殫 精 竭 力	殫 精 竭 慮	殫 謀 戮 力	燁 隆 企 業	燁 輝 企 業	
燁 興 企 業	燔 書 坑 儒	篝 火	篝 火 狐 鳴	蕁 麻	蕁 麻 疹	蕎 麥	蕎 麥 皮	
螓 首 蛾 眉	諠 譁	諢 名	諢 號	謔 稱	諤 諤 以 昌	踽 踽	踽 踽 涼 涼	
踽 踽 獨 行	蹁 躚	醍 醐 灌 頂	鍺 石	錸 德 科 技	錩 新 金 屬	閾 值	閹 人	
閹 割	閹 割 者	鴟 目 虎 吻	幪 面	幪 眼	懨 懨	擯 斥	擯 除	
擯 棄	檁 條	殭 屍	璐 珞	甑 塵 釜 魚	癉 惡 彰 善	篳 路 藍 縷	膻 味	
膻 腥	薏 仁	薏 苡 之 謗	薏 苡 明 珠	薈 萃	蟄 伏	蟄 居	蟊 賊	
襁 褓	觳 觫 伏 罪	謇 諤 之 風	謇 諤 自 負	蹇 諤 之 風	醚 麻 醉	醚 類	醛 基	
醛 酸	醛 醣	鍘 刀	鍘 草	闇 弱	黿 鳴 鱉 應	嚙 合	嚙 雪 吞 氈	
嚙 雪 餐 氈	攄 忠 報 國	燿 華 電 子	癤 子	癤 瘡	簦 過	蟣 子	謳 歌	
謾 上 不 謾 下	謾 天 昧 地	謾 罵	謾 罵 者	蹩 腳	轆 轆	轆 轤	鎧 甲	
隳 肝 瀝 膽	隳 節 敗 名	騏 驥 一 毛	騍 馬	髀 肉 復 生	鬈 曲	嚦 嚦	韞 櫝 未 酤	
韞 櫝 待 價	饃 糊	饃 饃	鯪 魚	鯤 鵬	鯰 魚	獼 猴	獼 猴 桃	
獼 猴 騎 土 牛	獼 猻 入 布 袋	矍 爍	矍 鑠	蘄 春	蠑 螈	蠖 屈 求 伸	鐐 銬	
饌 玉 炊 金	饋 送	饋 給	饋 電	饋 贈	齠 年 稚 齒	齙 牙	巋 然	
巋 然 不 動	巋 然 獨 存	攛 弄	攛 哄 鳥 亂	攛 拳 攏 袖	攛 掇	纈 草	纍 纍	
飆 車	飆 信	飆 發 電 舉	飆 舉 電 至	鰣 魚	孌 儔 鳳 侶	攢 三 聚 五	攢 成	
攢 眉	攢 眉 苦 臉	攢 錢	饔 飧 不 給	饔 飧 不 飽	鬻 兒 賣 女	鬻 官 賣 爵	鰲 頭	
鰲 頭 獨 佔	龕 著	攥 著	鱒 魚	鷸 蚌 相 爭	讕 言	囔 著	囔 囔	
躥 房 越 脊	顴 骨	鸝 鳥	�� 了	�� 色	�� 病	�� 斑	�� 跡	
�� 蝕	�� 鋼	�� 壞	

