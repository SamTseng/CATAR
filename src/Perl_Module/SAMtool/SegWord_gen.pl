#!/usr/bin/perl -s

# C:\Perl\site\lib\SAMtool>perl -s SegWord_gen.pl ..\SAM\word\wordlist.txt >SetWLhash.txt
#
# On 2006/06/21, run:
# D:\demo\STPIWG\src>perl -s c:\perl\lib\SAMtool\SegWord_gen.pl 
#    ..\Source_Data\1_3_keyterm.txt > ..\Source_Data\SetWLhash.txt
    use SAMtool::Stem;
    &SegWord::CreateDicDBM(@ARGV);
    exit;

package SegWord;

=head1 NAME

  SegWord - Segment a given text, produce some good terms.

=head1 SYNOPSIS

    Next are for creaing some auxiliary files for segmenting Chinese words.
    
    use SAMtool::SegWord;
    &SegWord::InsertSpace('stopword-chi.txt', 'new-stopword-chi.txt');
    &SegWord::CreateTPS($TermPosFile, $TPSDBfile);
    &SegWord::CreateDicDBM('word/wordlist.txt');
    
Author:
    Yuen-Hsien Tseng.  All rights reserved.
    
Date:
    2003/11/09

=cut

  use strict;  use vars;
  my %DIC = ();
  my %WLen = ();

# ------------------- Begin of functions for initialization -----------

=head2 CreateDicDBM() : Create dictionary for Perl from a lexicon in text

  use SegWord; &SegWord::CreateDicDBM( $WordList );

  Given a Chinese word list (e.g., wordlist.txt), create a dictionary file
  for later fast segmentation used in a Perl program.

=cut
sub CreateDicDBM { # public tool
    my($WordListFile) = @_;  
    my(%DIC, %WLen, $rW, $w, $wlen, %WLenTMP, %W, @W, $i);
    my $stime = time();
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
print STDERR "w=$w, 1st c $rW->[0]=$WLenTMP{$rW->[0]}, wlen=$wlen \n" if $rW->[0] eq'atomic';
    }
    close(WRDS);
    while (($w, $wlen) = each %WLenTMP) {
	%W = ();
	foreach $rW (split ' ', $wlen) {  $W{$rW} = 1;  }
	$WLen{$w} = join ' ', sort { $b <=> $a } keys %W;
    }
    
# Now we have %DIC and %WLen for output
    my $str ='
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
';
    print $str;

    foreach $w (sort keys %WLen) {
    	print "$w : $WLen{$w}\n";
    }
    print "__END_OF_WLen__\n";
    foreach $w (sort keys %DIC) {
    	$i++; print "$w\t";
    	print "\n" if $i%8==0;
    }
    my $etime = time();
    warn "It takes ", $etime - $stime, " seconds to create the dictionary\n";
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
	    push @terms1, $c if $c !~ /\s/; # 2004/01/26
	    next; # push '.', '?', or '!' for sentence delimiter
	}
# Now it begins with an English letter
	    for ($k=$j+1; $k<$len; $k++) {
		next if substr($t, $k, 1) eq '-'; # allow terms like 'Yu-Lung'
# The next 2 lines are added on Feb. 18, 2000 to allow terms like '0.18·L¦Ì'
# They should be best controlled by options (users' decision)
#		if (substr($t, $k, 3) =~ /\'s\W/o) { $k++; next ; }#2003/01/24
		if (substr($t, $k, 2) =~ /[.]\d/ ) { $k++; next ; }
#		if (substr($t, $k, 2) =~ /[,.]\d/ ) { $k++; next; }
# To allow '40%' as a term
		if (substr($t, $k-1, 2)=~/\d\%/) { $k++; last; }
## Next line is changed into next next 2 lines for this package in old version
		last if (substr($t, $k, 1) =~ /\W/o);
#		last if (substr($t, $k, 1) =~ /\s/o);
#		last if (ord(substr($t, $k, 1)) > 127);
	    }
# Next line is changed into next next line for this package
#	    push @terms1, &STEMER::stem(lc substr($t, $j, $k-$j));
#	    push @terms1, lc substr($t, $j, $k-$j) if $k-$j < 30;
	    push @terms1, Stem::stem(lc substr($t, $j, $k-$j), 0) if $k-$j < 30;
#	    push @terms1, substr($t, $j, $k-$j) if $k-$j < 100;
		# $k-$j<100 is to assure a term so as not too long
	    $j = $k - 1;
	} # end of for($j=0;
# @terms1 has all 1-token in input order
#print "terms1=@terms1 ";
    return \@terms1;
} # End of &Tokenize()


1;
