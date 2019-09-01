#!/usr/bin/perl -s
package Cluster;
# This program is copied from d:\dem\SAM\cluster\DocCluster.pm 
	use strict;  use vars;
	use SAMtool::Stem;
	use SAMtool::SegWord;
	use SAMtool::Stopword;
	use SAMtool::Progress;
	use Encode::TW; # this line must exist, despite we have the next line
	use Encode qw/encode decode from_to/;
	use Encode::Detect::Detector;
  #require "InitDBH.pl"; # added on 2017/08/28, remove comment on 2019/01/23
  use InitDBH qw(InitDBH); # added on 2019/01/24
# File names saved in the 'IndexPath'
	my $InvFile = 'Inv.txt';
	my $TitleFile = 'Title.txt';
	my $DocPathFile = 'DocPath.txt';
	my $SortedPairsFile = 'SortedPairs.txt';
	my $TreeFile = 'Tree.txt';
	my $DocVecFile = 'DocVec.txt';
	my $TermIdFile = 'TermId.txt';
	my $RelatedTermsFile = 'RelatedTerms.txt';

# Next is a comment segment in POD format. Comment ends until '=cut'

=head1 NAME

 DocCluster - Cluster a set of documents (normally the retrieved result set), 
		or a set of related terms by using WebGenie`s indices or the 
		indices built dynamically by this program.
		利用 WebGenie 的索引或及時動態建立的索引，來進行文件或詞彙
		的歸類動作。歸類方法有 Complete-Link、Single-Link，未來將增加
		Self-Organization Map，以及 Cluto 的歸類方法。

=head1 SYNOPSIS

# To be finished ...
#   要能允許加入中英文詞彙做斷詞
#   
	use Cluster;
	$rDC = Cluster->new( { 'debug'=>1 } );

	$rDC->SetValue('DocType', 'doc'); # 'doc' or 'term' (clustering)
	$value = $rDC->GetValue('DocType'); # get attribute's value
	$rDC->SetValue('IndexBy', 'me'); # or by 'WG' or 'me' (this program)
	$rDC->SetValue('Save2File', 1); # default is 0
	# if you want to save the results to files for fast later re-use, 
	# set 'Save2File' to 1 (0 otherwise), and set the next 2 attributes.
	$rDC->SetValue('IndexName', $IndexName);
	$rDC->SetValue('IndexPath', 'c:/' .$IndexName);# needed if 'IndexBy' is 'me'

# if 'IndexBy' is 'me' and not yet built the index, insert docs for later use
#   foreach $term (@Term) { $rDC->AddIndexTerm( $term );#if extra terms needed
	open F, "$FileList" || die "Cannot read file:'$FileList'";
	$/ = "\n"; @FileList = <F>; chomp @FileList; close(F);
	foreach $DocPath (@FileList) {
		open F, "$DocPath" || warn "Cannot read file:'$DocPath'";
		undef $/; $text = <F>; $/ = "\n"; # get all content in one read
		close(F); # get the Title from the HTML text
		if ($text=~m#<title>([^<]+)</title>#i){$title = $1;}else{$title='';}
		$text =~ s/<[^>]*>//g; # delete all HTML tags
		$rDC->AddDoc($DocPath, $title, $text); # insert those to be clustered
	}
	$NumDoc = $rDC->SaveDocIndex() if $rDC->GetValue('Save2File');

	$rDC->SetValue("low_df", 2); # do not use term whose df <= 2
	$rDC->SetValue("low_tf", 0); # do not use those term whose tf in doc is<=0
	$root = $rDC->DocSimilarity(); # compute each pair of document similarity
	$rDC->SaveSimilarity() if $rDC->GetValue('Save2File');

	$rDC->CompleteLink(); # use complete link for clustering
	$rDC->SaveTree() if $rDC->GetValue('Save2File');

# to show the full text content of the document in a CGI environment, set ...
	$rDC->SetValue("ShowDoc", "http://localhost/cgi-ig/ShowDoc4.pl");
	$rDC->SetValue('NumCatTitleTerms', 4); # set 4 title terms for each cluster
	$rDC->SetValue("ct_low_tf", 1); # do not use term whose tf <= 1
	$htmlstr = $rDC->CutTree(0.14); # use threshold 0.14 to cluster documents
	$htmlstr = "<html><head></head><body bgcolor=white>" 
			. $htmlstr . "\n<br></body></html>";
	print $htmlstr; # print out to the browser in CGI environment
	exit;

# If you have already saved the computed data, just read them back for
# another ways of clustering using different thresholds.
	use Cluster;
	$rDC = Cluster->new( { 'debug'=>1 } );
	$rDC->SetValue('DocType', 'doc'); # 'doc' or 'term' (clustering)
	$rDC->SetValue('IndexName', $IndexName);
	$rDC->SetValue('IndexPath', 'c:\'.$IndexName);# needed if 'IndexBy' is 'me'

	$NumDoc = $rDC->ReadDocIndex(); # for computing clusters' title terms
	$rDC->ReadTree();
# set the URL to show the full content of the inserted file
	$rDC->SetValue("ShowDoc", "http://localhost/cgi-ig/ShowDoc4.pl");
	$rDC->SetValue('NumCatTitleTerms', 5);
	$rDC->SetValue("ct_low_tf", 1); # do not use term whose tf <= 1
	$htmlstr = $rDC->CutTree(0.25);
	$htmlstr = "<html><head></head><body bgcolor=white>" 
			. $htmlstr . "\n<br></body></html>";
	print $htmlstr; # print out to the browser in CGI environment
	exit;


# If you have created the index and find some stopwords there,
#   you may read them back, delete the stopwords and save the index back.
	use Cluster;
	$rDC = Cluster->new( { 'debug'=>1 } );
	$rDC->SetValue('IndexName', $IndexName);
	$rDC->SetValue('IndexPath', $IndexPath);# needed if 'IndexBy' is 'me'
	$NumDoc = $rDC->ReadDocIndex(); # for computing clusters' title terms
	$rDC->DeleteStopword();
	$rDC->SaveDocIndex();
	exit;

=head1 DESCRIPTION


	To generate the comments surrounded by =head and =cut, run
	pod2html Cluster.pm > Cluster.html
	under MS-DOS.


Author:
	Yuen-Hsien Tseng.  All rights reserved.
	
Date:
	2001/06/13

=cut


# ------------------- Begin of functions for initialization -----------

=head1 Methods

=head2 new() : the construtor

  $rDC = Cluster->new( {'Attribute_Name'=>'Attribute_Value',...} );

  Attributes in an object in Perl is often saved in a referece to a hash.
  A reference to a no-name hash is donated as '{ }', as shown in 
	Cluster->new( { 'Attribute_Name'=>'Attribute_Value' }  );

  The attributes in the object can be directly given in the constructor`s 
  argumnets in a key=>value format. 
  The attribute names and values are:
	WordDir(path in a file system),
	UseDic(1 or 0)

  Omitted attribute pairs will be given default values.

=cut
sub new {
	my($class, $rpara) = @_; 
	$class = ref($class) || $class;
#	my $me = $class->SUPER::new( $rpara );
	my $me = bless( {}, $class );
	if (ref($rpara)) {	while (my($k, $v) = each %$rpara) { $me->{$k} = $v; }  }
	$me->{'Seg'} = SegWord->new( { 'WordDir'=>'SAM/word' } );
#	$me->{'Progress'}=Progress->new({'OUT'=>*STDERR{IO},'Format'=>'percent'});
	$me->{'Progress'}=Progress->new({'OUT'=>*STDERR{IO},'Format'=>'line'});
	$me->{'NumDoc'} = 0; # DocId begins from 0
	$me->{'NumTerm'} = 0; # TermId begins from 0
	$me->{'low_tf'} = 0;
	$me->{'Sim'} = 'Cosine';
	return $me;
}

sub DESTROY {
    my($this) = @_;
    $this->{DBH}->Close(); # only for Win32::ODBC
    $this->{DBH}->disconnect;

}

=head2 SetValue() : A generic Set method for all scalar attributes.

  Examples:
	  $rDC->SetValue("Method", "Cor"); # Set Method to correlation coef.
	  $rDC->SetValue("low_tf", 0); 
	  $rDC->SetValue("low_df", 2);
  Returns old value of the given attribute.

=cut
sub SetValue {
	my($this, $attribute, $value) = @_;   my($t, @T);
	my $old = $this->{$attribute};
	my $encoding_name = Encode::Detect::Detector::detect($value);
	if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#		$value = encode("big5", $value); # from utf-8 to big5
#	if ($encoding_name !~ /big5/i) { # if utf8-encoded
		from_to($value, $encoding_name, 'big5'); 
	}
	$this->{$attribute} = $value;
	if ($attribute eq 'Eng_Seg_Phrase') {
		# to tell SegWord.pm to use only manual-selected terms for indexing
	$this->{'Seg'}->{'Eng_Seg_Phrase'} = $value;
print STDERR "\$this->{'Seg'}->{'Eng_Seg_Phrase'}=$this->{'Seg'}->{'Eng_Seg_Phrase'}\n";
	}
	return $old;
}

=head2 GetValue() : A generic Get method for all scalar attributes.

  Examples:
	  $method = $rDC->GetValue("Method"); # get Method

=cut
# To get the value in a hash-typed attribute, a 2nd attribute should be given.
#  Example: to get the computed abstracts of a patent, use
#	 $TopStr = $wgct->GetValue('rPatentAbs', 'Topics');
  # terms in the above are in the format: "t1:df1; t2:df2; ..."
sub GetValue {
	my($this, $attribute, $attr2) = @_;
	my $encoding_name = Encode::Detect::Detector::detect($attribute);
	if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#		$attribute = encode("big5", $attribute); # from utf-8 to big5
#	if ($encoding_name !~ /big5/i) { # if utf8-encoded
		from_to($attribute, $encoding_name, 'big5'); 
	}
	$encoding_name = Encode::Detect::Detector::detect($attr2);
	if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#		$attr2 = encode("big5", $attr2); # from utf-8 to big5
#	if ($encoding_name !~ /big5/i) { # if utf8-encoded
		from_to($attr2, $encoding_name, 'big5'); 
	}
	if ($attr2 eq '') {
		return $this->{$attribute}
	}
	return $this->{$attribute}{$attr2};
}

use DBI;
use DBI ':sql_types';
#	$DBH = &InitDBH($DSN, $DBpath, $user, $pass);

sub InitDBMS {
	my($me, $DSN, $DB_Path) = @_;   my($DBH);
	$DSN = $me->{DSN} if $DSN eq '';
	$DB_Path = $me->{DB_Path} if $DB_Path eq ''; #"C:\\perl\\rssnewsdb\\rss.mdb";
#	$DSN = "driver=Microsoft Access Driver (*.mdb, *.accdb);dbq=$DB_Path" if $DB_Path ne '';
print STDERR "DSN=$DSN\n" if $me->{'debug'}>=1;
#	$DBH = DBI->connect("DBI:ODBC:$DSN",,, {
#	   RaiseError => 1, AutoCommit => 0
#	 } ) or die "Can't make database connect: $DBI::errstr\n";
#	$DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
#	$DBH->{LongTruncOk} = 1;

    # $DBH = $me->InitDBH($DSN, $DB_Path);
    # The above line is replaced with the next line:
    $DBH = &InitDBH($DSN, $DB_Path, $me->{'user'}, $me->{'password'});

	$me->{DBH}->disconnect() if ref($me->{DBH}); # release previous DBH
	return $me->{'DBH'} = $DBH;
}

=head2 InitDocSrc() : Initialize docuemnt source.

  $NumDoc = $rDC->InitDocSrc( $Src, $FileList, $sql );

  Specify the source of documents. 
  When $Src='Dir', $FileList contains the document paths
  When $Src='DB', $FileList is the DSN, $sql is the SQL command to fetch 
  all documents.
  return number of documents

=cut
#  Set attributes: 'Src', 'DocIndex', 'FileList' or 'PrimaryKey'
sub InitDocSrc {
	my($me, $Src, $FileList, $sql, $DB_Path) = @_; my(@FileList);
	$me->{'Src'} = $Src; 
	$me->{'DocIndex'} = 0;
	if ($Src eq 'Dir') {
		open F, "$FileList" or die "Cannot read file:'$FileList'";
		local $/ = "\n"; @FileList = <F>; chomp @FileList; close(F);
		pop @FileList if $FileList[$#FileList] =~ /^#|^\s*$/g;
		$me->{'FileList'} = \@FileList;
			return scalar @FileList;
	}
# Now documents are from DB
	my($DSN, $DBH, $STH, @PrimaryKey, @Key);
	$DSN = $FileList;
	$DBH = $me->InitDBMS($DSN, $DB_Path);
	
	$STH = $DBH->prepare($sql)
			 or die "Can't prepare SQL statement: $DBI::errstr\n";
	$STH->execute();
	while (@Key = $STH->fetchrow_array) { push @PrimaryKey, $Key[0]; }
	$STH->finish;
	$me->{'DBH'} = $DBH;
	$me->{'PrimaryKey'} = \@PrimaryKey;
	return scalar @PrimaryKey;
}

=head2 NextDoc() : fetch the next document

  ($DocPath, $title, $text) = $rDC->NextDoc();
  return $DocPath ($DocPath is primary key when documents are in DB)
		 document title, and document`s full texts including title.

=cut
sub NextDoc {
	my($me, $sql) = @_;
	my($DocPath, $title, $text, $txt, $encoding_name);
	if ($me->{'Src'} eq 'Dir') {
		if ($me->{'DocIndex'} >= @{$me->{'FileList'}}) {
			return (""); # if try to fetch more documents than already known
		}
		$DocPath = $me->{'FileList'}[$me->{'DocIndex'}];
		$me->{'DocIndex'} ++;
		open F, "$DocPath" || warn "Cannot read file:'$DocPath'";
		undef $/; $text = <F>; $/ = "\n"; # get all content in one read
		close(F);
		if ($text=~m|<title>([^<]+)</title>|i){$title = $1;}else{$title='';}
		$text =~ s/<[^>]*>//g; # delete all HTML tags
		return ($DocPath, $title, $text);
	}
# Now documents are in DB
	if ($me->{'DocIndex'} >= @{$me->{'PrimaryKey'}}) { 
		return (""); # if try to fetch more documents than already known
	}
	my($DBH, $STH, $key, @Key);
	$DBH = $me->{'DBH'};
#print STDERR "sql=$sql\n" if $me->{'debug'}>=1;
# $sql = "select ID, SNo, Fname, Dname, Dscpt from $rDC->{Table} where ID = ?";
	$DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
	$DBH->{LongTruncOk} = 0;
	$STH = $DBH->prepare($sql)
			 or die "Can't prepare SQL statement: $DBI::errstr\n";
	$STH->execute( $me->{'PrimaryKey'}[$me->{'DocIndex'}] )
		;# or die "Cannot execute SQL statement sql='$sql' for id=$me->{'PrimaryKey'}[$me->{'DocIndex'}]: $DBI::errstr\n";
	$me->{'DocIndex'} ++;
	($key, $title, @Key) = $STH->fetchrow_array;
	$STH->finish;
	foreach $txt ($title, @Key) { # 2010/11/20
		$encoding_name = Encode::Detect::Detector::detect($txt);
#		print "title encoding: $encoding_name\n";
		if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#			print "$encoding_name, Before: $txt\n";
#			$txt = encode("big5", $txt);
#		if ($encoding_name !~ /big5/i) { # if utf8-encoded
			from_to($txt, $encoding_name, 'big5'); 
#			$encoding_name = Encode::Detect::Detector::detect($txt);
#			print "$encoding_name, After: $txt\n";
#			exit;			
		}
	}
	$Key[$#Key] =~ s/&COPY;\s*\d+.*//; # 刪除資料庫出版商的著作宣告; only valid for STPI's data
#print "SQL=$sql\n", join("\n", $key, $title, @Key), "\n"; exit;
	$title = $title . " : " . $Key[1]; # format "Sno : Dname"
#	return ($key, $title, join(' . ', $title, @Key));
	return ($key, $title, join(' . ', @Key)); # 2005/06/26
}


=head2 AddDoc() : insert documents which are to be clustered

  $NumIndexedTerm = $rDC->AddDoc( $text );

  Create an inverted structure for each term to doc1, doc2, ... for later use.

=cut
#  Set attributes: 'Inv', 'Title', 'DocPath', 'NumDoc', 'DocTermNum'
sub AddDoc {
	my($me, $DocPath, $Title, $text) = @_;  
	my($w, $iw, $DocId, @WL, %FL, @A, %NP);
	my($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
		$rLinkValue, $rTitleSen, $rt, $wt);
	my $Seg = $me->{'Seg'};
#	$Seg->Value('WantRT', 0); # no related terms, no abstract
	$Seg->Value('WantRT', $me->{'OutputRelatedTerms'}); # 2009/11/24
	my $Stop = Stopword->new();
	$w = ($me->{'TextOnly'})?$text:($Title.' . '.$text); # 2009/11/29
	($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
#	$rLinkValue, $rTitleSen)=$Seg->ExtractKeyPhrase( $Title.' . '.$text); # 2007/02/27
		$rLinkValue, $rTitleSen)=$Seg->ExtractKeyPhrase( $w ); # 2009/11/29

	if ($me->{'OutputRelatedTerms'}) { # 2009/11/23
		while (($rt, $wt) = each %$rLinkValue) {
#			$me->{'RT'}{$rt} += $wt;
			$me->{'RT'}{$rt} .= sprintf("%1.2f", $wt) . "\t";
		}
	}

# Additionally, consider short phrases as phrases, # 2006/04/16
	@A = split /\s*[\.,;]\s*/, $text; # if any obvious phrases separated by [.,;]
	foreach $w (@A) { # assume $w is an english phrases
		next if $w =~ /^\s*$/;
		next if $w =~ /^\W/; # skip non-English terms 2006/06/09
		next if $w =~ /^\d/; # skip if start with a digit, 2007/10/15
		next if ($w =~ tr/ / /) > 2; # skip long phrases of length more than 3
		next if $rIFL->{$w}; # skip already detected phrases
		next if $rIFL->{lc $w}; # skip already detected phrases, 2009/11/29
		next if $w =~ /[\)\>]/; # skip if there is any non-alphabet letter
		$NP{$w} ++; 
	}
	foreach $w (keys %NP) { $rIFL->{$w} = $NP{$w}; }
#		push @$rIWL, keys %NP; 
	if ($me->{'Eng_Seg_Phrase'}) { # if using manual-selected terms for indexing
		$rIWL = $rSWL; # use the segmented terms only
	} else {
		push @$rIWL, keys %NP;
	}
# now back to our original procedure ...
#print STDERR "\$SegWord::DIC{'atomic force'}=$Seg->{DIC}{'atomic force'}\n"; exit;
	foreach $w (@$rIWL) { # for each index term
#print STDERR "for each index term: $w\n" if $w eq 'usa';
		next if $me->{'Eng_Seg_Phrase'} and not defined $Seg->{DIC}{$w};
#		next if $Stop->IsESW(substr($w, 0, index($w, ' '))); # 2005/06/19
#		next if $Stop->IsESW(substr($w, rindex($w, ' ')+1, length($w)));
		if ($me->{'IdxTnoStem'}) {
			@A = map {($_=~/^\w/)?lc $_:$_} split ' ', $w;
		} else {		
			@A = map {($_=~/^\w/)?Stem::stem(lc $_):$_} split ' ', $w;
		}
		$iw = join ' ', @A; # index term may repeat after stemming
		next if $iw =~ /__/; # 2005/06/26
		next if $iw =~ /\d$/; # end with a digit, 2005/08/20
#print STDERR "Before English Stopword test: $w\n" if $w eq 'usa';
# Next line is a bug found on 2009/11/25
#		next if $Stop->IsESW(substr($iw, 0, index($iw, ' '))); # 2005/06/19
		next if index($iw, ' ')>-1 and $Stop->IsESW(substr($iw, 0, index($iw, ' '))); # 2005/06/19
#print STDERR "Before final English Stopword test: $w\n" if $w eq 'usa';
		next if $Stop->IsESW(substr($iw, rindex($iw, ' ')+1, length($iw))); 
#print STDERR "After English Stopword test: $w\n" if $w eq 'usa';
		$FL{$iw} += $rIFL->{$w};
	}
	$DocId = $me->{'NumDoc'}; $me->{'NumDoc'}++; # DocId begins from 0
	@WL = keys %FL;
	foreach $w (@WL) { # it's better not to change $w below
#		$me->{'Inv'}{$w} .= pack("VV", $DocId, $FL{$w});
		$me->{'Inv'}{$w} .= "$DocId,$FL{$w},";
	}
#print "Total number of sentence:", scalar @$rTitleSen, "\n";
#my $i; print join("\n", map{++$i . ":$_"}@$rTitleSen), "\n";
#my $i; print join("\n", map{++$i . ":'$_':$rFL->{$_}"}@$rWL), "\n";
	if ($Title eq '') {
		$Title = $rTitleSen->[0]; # use the first sentence as title
	}
	$Title =~ s/\n+//g; # delete all line breaks
	$me->{'Title'}[$DocId] = $Title;
	$me->{'DocPath'}[$DocId] = $DocPath;
#	$me->{'DocTermNum'}[$DocId] = scalar @WL; # Number of Indexed Term
	return scalar @WL; # Number of Indexed Term
}


=head2 CreateIndexPath() : create the "IndexPath" folder if it does not exist.

  $rDC->CreateIndexPath(); # if there is any error, check attribute 'error'
  if ($rDC->{'error'}) { die $rDC->{'error'}; }

=cut
sub CreateIndexPath {
	my($me) = @_;  my(@Path, $dir, $i);
	@Path = split /[\/\\]/, $me->{"IndexPath"};
	for($i=0; $i<@Path; $i++) {
		$dir = join "/", @Path[0..$i];
		if (not -d $dir) { 
			mkdir($dir, 0755) || 
				($me->{'error'} = "Cannot create directory:'$dir'");
print STDERR "Directory $dir created\n" if $me->{debug} >= 1;
		}
	}
}


=head2 SaveDocIndex() : Save document index and title to files for later use

=cut
sub SaveDocIndex {
	my($me) = @_;  my($InvF, $TiF, $DPF, $RTF, $term, $i, $ptg, $TP, $weight);
	return if not $me->{'Save2File'};
	$me->CreateIndexPath();
	$InvF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $InvFile;
	$TiF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $TitleFile;
	$DPF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $DocPathFile;
	$RTF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $RelatedTermsFile;

	open INV, ">$InvF" || ($me->{'error'} = "Cannot write to file:'$InvF'");
	while (($term, $ptg) = each %{ $me->{'Inv'} }) {
		print INV "$term\t$ptg\n";
	}
	close(INV);
	open TI, ">$TiF" || ($me->{'error'} = "Cannot write to file:'$TiF'");
	for($i=0; $i<$me->{'NumDoc'}; $i++) {
		print TI $me->{'Title'}[$i], "\n";
	}
	close(TI);
	open DP, ">$DPF" || ($me->{'error'} = "Cannot write to file:'$DPF'");
	for($i=0; $i<$me->{'NumDoc'}; $i++) {
		print DP $me->{'DocPath'}[$i], "\n";
	}
	close(DP);
	return $i if not $me->{'OutputRelatedTerms'};
	open RT, ">$RTF" || ($me->{'error'} = "Cannot write to file:'$RTF'");
	while (($TP, $weight) = each %{ $me->{'RT'} }) {
		$TP =~ s/\-\?/\t/;
#		print RT "$TP\t", sprintf("%.4f", $weight), "\n";
		print RT "$TP\t$weight\n";
	}
	close(RT);
	return $i; # return number of documents
}


=head2 ReadDocIndex() : read document index and titles for later use

=cut
sub ReadDocIndex {
	my($me) = @_;   my($InvF, $TiF, $DPF, $term, $i, $ptg, $DVF, $TidF);
	my($NumTerm, $NumTitle, $NumDocPath, $did, $tid) = (0, 0, 0, 0, 0);
	$InvF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m|[/\\]$|)?"":'/') . $InvFile;
	$TiF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m|[/\\]$|)?"":'/') . $TitleFile;
	$DPF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m|[/\\]$|)?"":'/') . $DocPathFile;
	$DVF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m|[/\\]$|)?"":'/') . $DocVecFile;
	$TidF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m|[/\\]$|)?"":'/') . $TermIdFile;
	open INV, "$InvF" || ($me->{'error'} = "Cannot read file:'$InvF'");
	while (<INV>) {
		chomp; ($term, $ptg) = split /\t/, $_;
		$me->{'Inv'}{$term} = $ptg;
		$NumTerm++;
	}
	close(INV);
	$NumTitle = 0;
	open TI, "$TiF" || ($me->{'error'} = "Cannot read file:'$TiF'");
	while (<TI>) {  chomp; $me->{'Title'}[$NumTitle] = $_; $NumTitle++;  }
	close(TI);
	$NumDocPath = 0;
	open DP, "$DPF" || ($me->{'error'} = "Cannot read file:'$DPF'");
	while (<DP>) {  chomp; $me->{'DocPath'}[$NumDocPath] = $_; $NumDocPath++; }
	close(DP);
	if (-f $DVF) { # if file exists
		open DVF, "$DVF" || ($me->{'error'} = "Cannot read file:'$DVF'");
		while (<DVF>) { chomp; $me->{'DocVec'}[$did] = $_; $did++; }
		close(DVF);
	}
	if (-f $TidF) { # if file exists
		open TidF, "$TidF" || ($me->{'error'} = "Cannot read file:'$TidF'");
		while (<TidF>) { chomp; $me->{'TermId'}[$tid] = $_; $tid++; }
		close(TidF);
	}
print STDERR "There are $NumTerm terms, $NumTitle titles and $NumDocPath Docs in '$me->{'IndexPath'}'\n"
if $me->{debug}>=1;
	return $me->{'NumDoc'} = $NumDocPath; # return number of documents
}

=head2 ConvertIndex() : convert inverted file to doc. vector and termid

=cut
sub ConvertIndex {
	my($me) = @_;
	my($t, $ptg, $ti, $stime, $df, @Term, @Doc, $i, $InvF, $NumTerm);
	if (not defined $me->{'Inv'}) {
	$InvF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $InvFile;
	open INV, "$InvF" || ($me->{'error'} = "Cannot read file:'$InvF'");
	while (<INV>) {
		chomp; ($t, $ptg) = split /\t/, $_;
		$me->{'Inv'}{$t} = $ptg;
		$NumTerm++;
	}
	close(INV);
	}
	my($NTi, $NT, $percent, $d, $f, %PTG);
	my $Progress = $me->{'Progress'};
#	return if $me->{'NumDoc'} <= 0;
# @DocTermNum : record number of used terms in a document
print STDERR "\nConvert Inverted file into document vector file.\n" if $me->{debug}>=1;
	$NT = scalar keys %{ $me->{'Inv'} }; # number of total indexed terms
print STDERR "There are $NT distinct terms.\n" if $me->{debug}>=1;
	$stime = time();
	$ti = 0; # TermId begins from 0
	while(($t, $ptg) = each %{ $me->{'Inv'} }) {
		$NTi++; # to know how much we have processed
		$percent = $Progress->ShowProgress($NTi/$NT, $percent) if $me->{debug}>=1;
		%PTG = split /,/, $ptg; # get (document_id, tf) pairs
		$df = 0;
		while (($d, $f) = each %PTG) { # for each document_id and tf
			$df++;
			$Doc[$d] .= "$ti,$f,"; # format: did=>"tid1,$tf1,$tid2,$tf2,..."
		}
		$Term[$ti] = "$t\t$df"; $ti++; # format: tid=>"term	df"
	}
# Now write results to the file
	my $DVF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $DocVecFile;
	my $TidF = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $TermIdFile;
	open DVF, ">$DVF" || ($me->{'error'} = "Cannot write to file:'$DVF'");
	for($i=0; $i<@Doc; $i++) {	print DVF $Doc[$i] . "\n";  }
	close(DVF);
	open TidF, ">$TidF" || ($me->{'error'} = "Cannot write to file:'$TidF'");
	for($i=0; $i<@Term; $i++) {	print TidF $Term[$i] . "\n";  }
	close(TidF);
	$percent = $Progress->ShowProgress($NTi/$NT, $percent) if $NT>0 and $me->{debug}>=1;
print STDERR "  It takes ", time()-$stime, " seconds\n" if $me->{debug} >= 1;
}


=head2 DeleteStopword() : delete the stopwords in the index

=cut
sub DeleteStopword {
	my($me) = @_;  my(@Term, $w, $Stop, $c);
	$Stop = Stopword->new();
	@Term = keys %{ $me->{'Inv'} };
	foreach $w (@Term) {
		if ($w =~ /__/) { delete $me->{'Inv'}{$w}; next; }
		if ($Stop->IsESW($w)) { delete $me->{'Inv'}{$w}; next; } # 2005/06/26
		if ($Stop->IsESW(substr($w, 0, index($w, ' ')))){ delete $me->{'Inv'}{$w}; next; } 
		if ($Stop->IsESW(substr($w, rindex($w, ' ')+1, length($w)))) { delete $me->{'Inv'}{$w}; next; }
#print "w=$w, ", $Stop->IsCSW($w),"\n" if $w eq '本 發 明';
		if ($Stop->IsCSW($w)) { delete $me->{'Inv'}{$w}; next; } # 2006/04/18
#print "w=$w, ", substr($w, 0, 5)," , ",$Stop->IsCSW(substr($w, 0, index($w, ' ')+2)), "\n" if substr($w, 0, 5) eq '如 申';
		if ($Stop->IsCSW(substr($w, 0, 5))) { delete $me->{'Inv'}{$w}; next; }
#		if ($Stop->IsCSW(substr($w, 0, 7))) { delete $me->{'Inv'}{$w}; next; }
#		if ($Stop->IsCSW(substr($w, rindex($w, ' ')-2, length($w)))) { delete $me->{'Inv'}{$w}; next; }
	}
	if ($me->{debug} >= 1) {
		$c = keys %{ $me->{'Inv'} }; $w = @Term; $c = $w - $c;
		print STDERR "$c stopwords were deleted from $w index terms.\n";
	}
}

=head2 StartDocCluster() : cluster the inserted documents

  $tree_root = $rDC->StartDocCluster( );

	Step 1: Given a inverted file, accumulate number of common terms between 
	  document pairs, then calculate Dice coefficients between document pairs, 
	  and then sort the document pairs by similarities.
	Step 2: Cluster documents based on the similarities between documents 
	  perl -s cluster.pm -Complete 0 3 SortedPairs.txt Infoa5600maxtf.txt \
   	../infoa5/File /cgi-ig/ShowDoc4.pl > out.html
	Step 3: Given a threshold and a file containing the roots and tree 
	information, parse the tree to get those subtree whose node 
	similarities are equal or larger than the threshold. 
	Output the resulting trees in HTML.
	  perl -s cluster.pm -Threshold threshold > clusters.html
	  ex:perl -s cluster.pm -Threshold 0.14 > testmax0.14.html
	 where
	threshold : omit those subtree whose node has a similarity <= threshold
	 There is automatic option -Auto that wraps the above 3 steps in one step.

=cut
sub StartDocCluster {
	my($me, $threshold) = @_;
	$me->DocSimilarity();
	$me->CompleteLink();
	$me->CutTree( $threshold );
}


=head2 DocSimilarity() : calculate document similarity

  $NumPairs = $rDC->DocSimilarity();

Given a inverted structure, accumulate number of common terms between 
document pairs, then calculate Dice coefficients between document pairs, 
and then sort the document pairs by similarities.

=cut
# Use attributes : 'Inv', 'NumDoc', 'low_tf', 'low_df', 'high_df'
# Set attributes : 'SortedPairs'
sub DocSimilarity {
	my($me) = @_;
	my($NT, $NTi, $t, $tlen, $ptg, $d, $df, $idf, $f, $i, $j, $percent);
	my(%Sim, @Data, @Docs, %PTG, @DocTermNum, $stime, $etime);
	my $Progress = $me->{'Progress'};
#	return if $me->{'NumDoc'} <= 0;
# @DocTermNum : record number of used terms in a document
print STDERR "\nCompute document similarities between document pairs.\n" if $me->{debug}>=1;
print STDERR "Step 1: accumulate number of common terms between document pairs.\n" 
if $me->{debug}>=1;
	$NT = scalar keys %{ $me->{'Inv'} }; # number of total indexed terms
print STDERR "There are $NT distinct terms.\n" if $me->{debug}>=1;
	$stime = time();
	while(($t, $ptg) = each %{ $me->{'Inv'} }) {
		$tlen = ($t =~ tr/ / /)+1; # Number of token in $t
		if ($t =~ /^\w/) { $tlen = 2*$tlen+1; } else { $tlen = 2*$tlen - 1; }
	# if English word, use 2*tokens+1. If Chinese term, use 2*tokens-1
		$NTi++; # to know how much we have processed
# omit Chinese single-character terms, but preserve them if $me->{low_tf}==0
# If low_tf is set to 0, that means the documents are very short. 
# So every indexed term should be used.
		next if $t=~/^\W/ and $me->{low_tf}>0 and $tlen < 2;
#		%PTG = unpack("V*", $ptg); # get (document_id, tf) pairs
		%PTG = split /,/, $ptg; # get (document_id, tf) pairs
		undef @Docs; # to hold the target documents
		while (($d, $f) = each %PTG) { # for each document_id and tf
			next if $f <= $me->{'low_tf'}; # omit the document whose tf too low
			push @Docs, $d # hold those in the range
			; # if ($d >= $DocIdFrom and $d <= $DocIdTo);
		}
		$df = scalar @Docs; 
# omit those terms whose df is too large, or too low
#		next if $df <= $me->{'low_df'} or $df >= 0.75 * $me->{'NumDoc'}; # 2007/02/09
		next if $df <= $me->{'low_df'} or ($me->{'NumDoc'}>100 and $df >= 0.75 * $me->{'NumDoc'}); # 2007/02/09
		next if defined $me->{'high_df'} and $df >= $me->{'high_df'}; # 2008/04/28
print STDERR "NumDoc=$df, t=$t, D=@Docs.\n" if $me->{debug}>=2;
		$idf = log( ($me->{'NumDoc'}+1) / $df); 

# accumulate weigted number of terms in a document
# next line is for Dice coefficient
		if ($me->{'Sim'} eq 'PureDice') {
			foreach $d (@Docs) { 
				$DocTermNum[$d]++; 
#print STDERR "\n\$DocTermNum[$d]=$DocTermNum[$d], ptg=$ptg\n" if $d == 32 or $d == 35;
			}
		} elsif ($me->{'Sim'} eq 'Dice') {
			foreach $d (@Docs) { $DocTermNum[$d] += $PTG{$d} * $tlen * $idf; }
		} else { # $me->{'Sim'} eq 'Cosine'
# next line is added on 2005/08/15 for Cosine similarity
			foreach $d (@Docs) { 
				$DocTermNum[$d] += (log(1+$PTG{$d})*$tlen*$idf)**2; 
			}
		}
#print STDERR '\n@Docs=', join(',', @Docs), '@DocTermNum=', 
#		join(',', @DocTermNum[@Docs]),"\n" if $ptg =~ /\D(32|35)\D/;

		for ($i=0; $i<$df; $i++) {
			for($j=$i+1; $j<$df; $j++) {
				$f = ($Docs[$i] lt $Docs[$j])? # 2008/06/17
#					"$Docs[$i]:$Docs[$j]":"$Docs[$j]:$Docs[$i]";
					"$Docs[$i]\t$Docs[$j]":"$Docs[$j]\t$Docs[$i]";
				if ($me->{'Sim'} eq 'PureDice') {
# next line is for Dice coefficient
					$Sim{$f} ++; # 2009/11/27 
				} elsif ($me->{'Sim'} eq 'Dice') {
#   calculate average tf weighted by idf and tlen as the similarity
					$Sim{$f} += $idf * $tlen * 
					int( ($PTG{$Docs[$i]} + $PTG{$Docs[$j]}) / 2 + 0.5);
				} else { # $me->{'Sim'} eq 'Cosine'
# next line is added on 2005/08/15 for Cosine similarity
					$Sim{$f} += ($idf * $tlen)**2 * 
					log(1+$PTG{$Docs[$i]}) * log(1+$PTG{$Docs[$j]});
				}
print STDERR "\$Sim{$f}=",$me->ts($Sim{$f}),
	" : tlen=$tlen, $PTG{$Docs[$i]}+$PTG{$Docs[$j]}, ",
	"df=$df, NumDoc=$me->{NumDoc}, t=$t.\n" if $me->{debug} >= 2;
				}
		}
		$percent = $Progress->ShowProgress($NTi/$NT, $percent) if $me->{debug}>=1;
	}
	$percent = $Progress->ShowProgress($NTi/$NT, $percent) if $NT>0 and $me->{debug}>=1;
print STDERR "  It takes ", time()-$stime, " seconds\n" if $me->{debug} >= 1;
#print STDERR '@DocTermNum[32, 35]=', join(',',@DocTermNum[32, 35]), "\n";

	$stime = time();
# Now we have %Sim and @DocTermNum, we can compute Cosine(or Dice) coefficient
print STDERR "Step 2: Calculate $me->{Sim} coefficients between document pairs.\n"if $me->{debug} >= 1;
	$NTi = $percent  = 0; $NT = scalar keys %Sim;
print STDERR "There are $NT document pairs\n" if $me->{debug} >= 1;
	while (($d, $f) = each %Sim) {
		$NTi++;
#		($i, $j) = split /:/, $d;
		($i, $j) = split /\t/, $d; # 2008/05/09
# Next line is for Dice coefficient:
		if ($me->{'Sim'} =~ /Dice/) { # 'Dice' or 'PureDice'
#print STDERR "(\$DocTermNum[$i]=$DocTermNum[$i] + \$DocTermNum[$j]=$DocTermNum[$j])\n" if ($DocTermNum[$i] + $DocTermNum[$j])==0;
			$Sim{$d} = 2*$f /($DocTermNum[$i] + $DocTermNum[$j]);
		} else {  # $me->{'Sim'} eq 'Cosine'
# next line is added on 2005/08/15 for Cosine similarity
			$Sim{$d} = $f /(sqrt($DocTermNum[$i]) * sqrt($DocTermNum[$j]));
		}
print STDERR "\$Sim{$d}=",$me->ts($Sim{$d})," : f=",$me->ts($f),
#	", $DocTermNum[$i] + $DocTermNum[$j].\n" if $d=~/32|35/;
	", $DocTermNum[$i] + $DocTermNum[$j].\n" if $me->{debug} >= 2;
		$percent = $Progress->ShowProgress($NTi/$NT, $percent) if $me->{debug}>=1;
	}
	$percent = $Progress->ShowProgress($NTi/$NT, $percent) if $NT>0 and $me->{debug}>=1;
print STDERR "  It takes ", time()-$stime, " seconds\n" if $me->{debug} >= 1;
	$stime = time();

print STDERR "Step 3: Sort the document pairs by similarities\n" if $me->{debug} >= 1;
	$NT = @Docs = sort {$Sim{$b} <=> $Sim{$a}} keys %Sim;
#	$NTi = $percent  = 0; 
	undef $me->{SortedPairs};
	foreach $d (@Docs) {
#		($i, $j) = split /:/, $d;
		$f = sprintf("%.4f", $Sim{$d}); # 2007/08/08, change 1.6f into 1.4f
#		$me->{SortedPairs} .= "$i\t$j\t$f\n";#format:"Doc1\tDoc2\tsimilarity\n"
#		push @{$me->{SortedPairs}},"$i\t$j\t$f";#format:"Doc1\tDoc2\tsimilarity"
		push @{$me->{SortedPairs}},"$d\t$f";#format:"Doc1\tDoc2\tsimilarity"
	}
print STDERR "  It takes ", time()-$stime, " seconds\n" if $me->{debug} >= 1;
	return $NT; # number of document pairs
} # End of &DocSimilarity()


# Use attributes : $DigitNum
sub ts { 
	my($me, $x, $n) = @_; 
	$n=4 if not $n; return sprintf("%.".$n."f", $x); # 2007/08/08 change $n=5 into $n=4
#	return sprintf("%.". ($n>0?$n:$me->{"DigitNum"}) ."f", $x); 
}


=head2 SaveSimilarity() : save similarity computed previously

=cut
# Use attribute : 'SortedPairs'
sub SaveSimilarity {
	my($me) = @_; my( $pair, $SPFile );
	$me->CreateIndexPath();
	$SPFile = $me->{"IndexPath"} . # for saving the results
		(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $SortedPairsFile;
	open F, ">$SPFile" || ($me->{'error'} = "Cannot write to file:'$SPFile'");
	foreach $pair ( @{$me->{SortedPairs}} ) {
		print F "$pair\n";
	}
	close(F);
}


=head2 ReadSimilarity() : read back similarity computed previously

=cut
# Set attribute : 'SortedPairs'
sub ReadSimilarity {
	my($me) = @_; my( $SPFile, @SortedPairs );
	$SPFile = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $SortedPairsFile;
	open F, "$SPFile" || ($me->{'error'} = "Cannot read file:'$SPFile'");
	while (<F>) {
		chomp; next if /^#|^\s*$/g;
		push @SortedPairs, $_; #format:"Doc1\tDoc2\tsimilarity"
	}
	close(F);
	print STDERR "There are ",scalar@SortedPairs," pairs\n" if $me->{debug}>=1;
	$me->{'SortedPairs'} = \@SortedPairs;
}


=head2 CompleteLink() : cluster the documents by complete link algorithm

  $tree_root = $rDC->CompleteLink();

Cluster documents based on the similarities between documents 
by complete link method.

=cut
# Use attributes: 'SortedPairs'
# 	format in the SortedPairs:"Doc1\tDoc2\tsimilarity"
# Set attributes: 'Tree', 'Papa'
sub CompleteLink {
	my($me) = @_;
	my($t1, $t2, $mi, $df1, $df2, $cnum, $t1new, $t2new, $node, $rcnum, $rmi);
	my($tmp, $rCatMember, $rCatMember2, $root, $t, $root2, $rcnum2, $rmi2);
	my(%Check, %Papa, %Tree, %Element, %Root, $papa, $stime, $pair);
	my($NT, $NTi, $percent);
	my $Progress = $me->{'Progress'};

print STDERR "\nCluster documents by complete link\n" if $me->{debug}>=1;

	$cnum = $NTi = $percent = 0; $NT = scalar@{$me->{SortedPairs}};
	$stime = time();
print STDERR "There are $NT pairs.\n"if $me->{debug}>=1;
NextTerm: foreach $pair (@{$me->{SortedPairs}}) {
		($t1, $t2, $mi) = split /\t/, $pair;
		$NTi++; # %Check will be used in &HasAllChecked()
#	$Check{join "\t", sort ($t1, $t2)} = 1; # remember the examined pairs
		$tmp = ($t1 lt $t2)?"$t1\t$t2":"$t2\t$t1";
		$Check{$tmp} = 1; # remember the examined pairs
		$Element{$t1} = 1; $Element{$t2} = 1; # to know all the elements
		$cnum++; # cluster node number, start from 1
		$node = "$cnum:$mi";
		$t1new = ($Papa{$t1})?0:1; # 0 : not belonging to any cluster
		$t2new = ($Papa{$t2})?0:1; # 1 : already in some cluster
#print "node='$node', t1='$t1'($t1new), t2='$t2'($t2new).\n";
#foreach $df1 (sort keys %Check) { print "$df1, "; } print ".\n";
		if ($t1new and $t2new) { # both are not in any existing clusters
			$Tree{$node} = "$t1\t$t2"; # form a new cluster, downward link
			$Papa{$t1} = $Papa{$t2} = $node; # upward link
		} elsif ($t1new or $t2new) { # only $t1 not in any clusters
			if ($t2new) { # swap ($t1, $t2), and ($df1, $df2) if necessary
				$tmp = $t2; $t2 = $t1; $t1 = $tmp; 
			}
# now we only have to deal with the case that only $t1 is not in any clusers
			$root = &FindRoot($t2, \%Papa); # get the root of this cluster
			$rCatMember = &AllLeaves($root, \%Tree); # get all leaves
			if (&HasAllChecked($rCatMember, $t1, \%Check)) { 
# if all pairs have been seen, we can merge the new term into the cluster
				($rcnum, $rmi) = split /:/, $root;
#print "root=$root, t1=$t1, t2=$t2, rmi=$rmi, mi=$mi, $Tree{$root}.\n"if $cnum==197;
				if ($rmi == $mi) {
					$Tree{$root} .= "\t$t1";
					$Papa{$t1} = $root;
				} else { # merge $t1 with &FindRoot($t2) under node $node
					$Tree{$node} = "$root\t$t1";
					$Papa{$root} = $Papa{$t1} = $node;
				}
			} # otherwise do nothing
		} else { # otherwise both are already in some clusters
			$root = &FindRoot($t1, \%Papa);
			$root2 = &FindRoot($t2, \%Papa);
			next if $root eq $root2;  # alread in the same cluster
			$rCatMember = &AllLeaves($root, \%Tree); # get all leaves
			$rCatMember2 = &AllLeaves($root2, \%Tree); # get all leaves
			foreach $t (@$rCatMember2) {
				next NextTerm if not &HasAllChecked($rCatMember, $t, \%Check);
			}
			($rcnum, $rmi) = split /:/, $root;
			($rcnum2, $rmi2) = split /:/, $root2;
			if ($rmi == $rmi2) { 
				$Tree{$root} .= "\t$Tree{$root2}";
				foreach $t (split /\t/, $Tree{$root2}) {
					$Papa{$t} = $root; # will it have the t1\tt2\tt2\tt3 case?
				}
			} else {
				$Tree{$node} = "$root\t$root2";
				$Papa{$root} = $Papa{$root2} = $node;
			}
		}
		$percent = $Progress->ShowProgress($NTi/$NT, $percent) if $me->{debug}>=1;
		die "\nError! Total=$NT, i=$NTi, pair='$pair'\n" if $percent > 100;
	} # foreach $pair
	$percent = $Progress->ShowProgress($NTi/$NT, $percent) if $NT>0 and $me->{debug}>=1;
# For those that are not clustered with others, make them individual clusters
	while (($t, $tmp) = each %Element) { # here $tmp is 1 for all $t
		next if defined $Papa{$t}; # skip if already in some cluster
		$cnum++; $node = "$cnum:0"; $Tree{$node} = $t; $Papa{$t} = $node;
	}
# Now we %Papa, %Tree, we can count the leaves in each the cluster
	while (($node, $papa) = each %Papa) {
		next if $Tree{$node}; # skip internal node
		$Root{ &FindRoot($papa, \%Papa) } ++; # accumulate number of leaves
	}
print STDERR "  It takes ", time()-$stime, 
	" seconds for CompleteLink clustering.\n" if $me->{debug} >= 1;
#	$me->{'Papa'} = \%Papa; # no longer need %Papa
	$me->{'Tree'} = \%Tree;  # return ref to the tree
	$me->{'Root'} = \%Root;  # return all the roots
#	&OutputCluster(\%Papa, \%Tree);
} # End of &CompleteLink()


# Find the root of current node. If the current is the root, then return itself
sub FindRoot {
	my($node, $rPapa) = @_;
	while(defined $rPapa->{$node}) {  $node = $rPapa->{$node}; }
	return $node;
}


# Given a cluster (tree) root, gather all the leaves node in an array.
# Return the reference of the array
sub AllLeaves {
	my($node, $rTree) = @_; my(@Leaves, @Sons, $n);
	@Sons = split /\t/, $rTree->{$node};
	if (@Sons == 0) {
		push @Leaves, $node;
	} else {
		foreach $n (@Sons) {
			push @Leaves, @{&AllLeaves($n, $rTree)}; # de-reference the array
		}
	}
	return \@Leaves;
}


# Given an array of leaf nodes (terms) and a term, check if each of the 
# term pairs between the leaf nodes and the given term has already examined.
sub HasAllChecked {
	my($rCatMember, $term, $rCheck) = @_; my($tmp);
	foreach my $t (@$rCatMember) {
#		next if $t eq $term;  # equal to itself 2004/01/17
		$tmp = ($t lt $term)?"$t\t$term":"$term\t$t";
#		if (not $rCheck->{ join ("\t", sort($t, $term)) }) { return 0; }
		if (not $rCheck->{$tmp}) { return 0; }
	}
	return 1; # if already checked
}

=head2 SaveTree() : Save the Tree information to a file

=cut
# use attributes : 'Tree', 'Root'
sub SaveTree {
	my($me) = @_; my($i, $node, $k, $v, @Root, $file, $rRoot, $rTree);
	$rRoot = $me->{'Root'};
	$rTree = $me->{'Tree'};
	$file = $me->{"IndexPath"} . # for saving the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $TreeFile;
	open F, ">$file" || ($me->{'error'} = "Cannot write to file:'$file'");
	print F "\nRoots:\n";
	@Root = sort {$b <=> $a} keys %$rRoot; 
	# sort the roots from large clusters to small ones
	foreach $node (@Root) {
		print F "$node($rRoot->{$node}), "; print F "\n" if (++$i%4 == 0);
		# node (number of leaves in this node)
	}
	print F "\nTree:\n";
	while (($k, $v) = each %$rTree) { print F "$k : $v\n"; }
	close(F);
}

=head2 ReadTree() : read the tree information back for later use

=cut
# Set attributes : 'Tree', 'Root'
sub ReadTree {
	my($me) = @_;  my($ReadTree, $node, $k, $v, @Root, %Root, %Tree, $file);
	my($NumRoot, $NumNode) = (0, 1); # (No. of internal node) + 1, 2008/05/08
	$file = $me->{"IndexPath"} . # for reading the results
	(($me->{"IndexPath"}=~m#[/\\]$#)?"":'/') . $TreeFile;
	open F, "$file" || ($me->{'error'} = "Cannot read file:'$file'");
	while (<F>) {
		chomp; next if /^\s*$/; # next if empty line
		if (/Root/) { $ReadTree = 0; next; }
		if (/Tree/) { $ReadTree = 1; next; }
		if ($ReadTree) {
			($k, $v) = split / : /, $_;
			$Tree{$k} = $v;
			$NumNode++;
#print "$k : $v\n" if $k == 8605;
			next;
		}# read roots
		@Root = split /, /, $_; # format:"4:0.539541(2), 5732:0.090409(2),"
		foreach $node (@Root) { 
			if ($node =~ /(.+)\(([^\)]+)\)$/) { # match:"4:0.539541(2)"
#				$Root{$1} = ($2)?$2:1;
				$Root{$1} = $2;
			} else {
				$Root{$node} = 1;
			}
			$NumRoot++;
		}
	} # end of while (<F>) {
	close(F);
	print STDERR "There are $NumRoot roots and $NumNode nodes\n" if $me->{debug}>=1;
#	$me->{'Papa'} = \%Papa; # no longer need %Papa
	$me->{'Tree'} = \%Tree;  # return ref to the tree
	$me->{'Root'} = \%Root;  # return all the roots
}


=head2 Sons() : return the sons of a node

  $Sons = $rDC->Sons();
  
  The format of $Sons is : "node1\tnode2\tnode3\t..."
  A node is either a "leaf node" or an "internal node". 
  A "leaf node" is either a "document number" (for document clustering)
	or a "term" (for term clustering)
  An "internal node" is composed of a node number (system-generated ID number)
	and a similarity of its sons. The format is : "Node_Number:Similarity".
	Examples: "36:0.359806", "9", "225".

=cut
sub Sons {
	my($me) = @_;
}

=head2 Papa() : cluster the inserted documents

  $papa_node = $rDC->Papa();

=cut
sub Papa {
	my($me) = @_;
}

=head2 CutTree() : cluster the inserted documents with a threshold

  $rDC->CutTree( $threshold );

=cut
# Set 'CutTree', 'CutPapa'
# By calling CutTree() with a second argument, the documents 
#   in the same cluster are saved to the same file under folder:$OutDir
sub CutTree {
	my($me, $Threshold, $OutDir) = @_; 
	my($root, @NewRoot, %NewRoot, $rTree, $rRoot, $stime, $htmlstr);
print STDERR "\nCut the clustered tree with threshold: '$Threshold'.\n" if $me->{debug}>=1;
	$stime = time();
	$rRoot = $me->{'Root'};
	$rTree = $me->{'Tree'};
	foreach $root (keys %$rRoot) {
		push @NewRoot, $me->ParseTree($root, $rTree, $Threshold);
	}
	foreach $root (@NewRoot) { # get each new root's number of leaves
		$NewRoot{$root} = $me->GetLeaveNumber($root, $rTree);
#print "$root ($NewRoot{$root})<br>\n";
	}
	$me->{'Cid2Terms'} = $me->GenCid2Terms(\@NewRoot);
	if ($OutDir) {
		$htmlstr = $me->CreateBigDoc(\%NewRoot, $OutDir);
	} else {
		$htmlstr = $me->CreateTreeHTML(\%NewRoot); # return tree structures in HTML
	}
print STDERR "It takes ", time()-$stime, " seconds to cut the tree.\n" if $me->{debug} >= 1;
	return $htmlstr;
}


=head2 CutCollection();

=cut
# Given a threshold, cut the tree to know which document belongs to which
#   sub-tree, return this information.
#   This method can be used for MDS.pm to map different document clusters
#   using different colors. This function is called at Term_Trend.pl
sub CutCollection {
	my($me, $Threshold, $rWanted, $rUnWanted) = @_; 
	my($root, @NewRoot, %NewRoot, $rTree, $rRoot, %CatId2DocIds, %DocId2CatIds);
	my(@DocList, $did, $cid, %Cid2Cno, @Root, $i);
print STDERR "\nPartition documents with threshold: '$Threshold'.\n" if $me->{debug}>=1;
	$rRoot = $me->{'Root'};
	$rTree = $me->{'Tree'};
	foreach $root (keys %$rRoot) {
		push @NewRoot, $me->ParseTree($root, $rTree, $Threshold);
	}
	foreach $root (@NewRoot) {
#		$NewRoot{$root} = $me->GetLeaveNumber($root, $rTree); # 2011/04/25
		$CatId2DocIds{(split/:/,$root)[0]} = &GetCat2Docs($root, $rTree, \%CatId2DocIds);
#my $n=(split/:/,$root)[0]; print "\$CatId2DocIds{$n}=$CatId2DocIds{$n}\t<br>\n";# if $n==14;
	}
	foreach $root (@NewRoot) { # get each new root's number of leaves
		@DocList = split ' ', $CatId2DocIds{(split/:/,$root)[0]};
		next if @DocList == 0;
		foreach $did (@DocList) {
#			$DocId2CatIds{$did} .= "$root\t";
			$DocId2CatIds{$did} = (split/:/,$root)[0]; 
			# over-write previous if the doc is belong to multiple categories
		}
	}
#while (my($k, $v)=each %DocId2CatIds) { print "Did=$k, Cid=$v\n"; }
#while (my($k, $v)=each %CatId2DocIds) { print "Cid=$k, Did=$v\n"; }
#while (my($k, $v)=each %Cid2Cno) { print "Cid=$k, Cno=$v\n"; }
	return (\%DocId2CatIds, \%CatId2DocIds);
#	@Root = sort { $NewRoot{$b} <=> $NewRoot{$a} } keys %NewRoot; # 2011/04/25
#	for($i=0; $i<@Root; $i++) { $Cid2Cno{(split/:/,$Root[$i])[0]}=$i+1; } # 2011/04/25
	# The sorted result should be the same as &CreateTreeHTML(). 
	# Otherwise, %Cid2Cno would contain incorrect information
	# But we cannot guarantee the sorted order due to tie numbers.
#	return (\%DocId2CatIds, \%CatId2DocIds, \%Cid2Cno);  # 2011/04/25
	# Thus, the attempt to label each circle in the topic map with 
	#  Cluster Number (Cno) failed using the concept of %Cid2Cno.
}


# Given a (an internal) node (maybe a root), the tree, and the threshold, 
# return the given node as a new root if its similarity is >= threshold.
# Otherwise, return all its subtrees whose similarities are >= threshold.
# If none of its subtrees have similarities >= threshold, return empty array.
sub ParseTree {
	my($me, $node, $rTree, $Threshold) = @_; my($cnum, $mi, @Sons, @Root);
#print "node=$node, sons=$rTree->{$node}\n";
#	$node =~ s/\(\d+\)//; # delete cluster size in parenthesis, 2003/02/14
#	if ($node =~ /^\d/) { # if an internal node
# The above line seems a bug, use next line instead
	 if ($node =~ /\d:/) { # if an internal node, 2003/02/14
		($cnum, $mi) = split /:/, $node;
		if ($mi >= $Threshold) { 
			push @Root, $node;
		} else {
			@Sons = split /\t/, $rTree->{$node};
			foreach $node (@Sons) {
				push @Root, $me->ParseTree($node, $rTree, $Threshold)
				if $node =~ /\d:/; # if an internal node, 2003/02/14
			}
		}
	}
	return @Root;
}

# Given a root, the tree, return number of leaves.
sub GetLeaveNumber {
	my($me, $node, $rTree) = @_; my($leaves, @Sons);
	@Sons = split /\t/, $rTree->{$node};
	return 1 if @Sons == 0;
	foreach $node (@Sons) {
		$leaves += $me->GetLeaveNumber($node, $rTree);
	}
	return $leaves;
}


=head2 CreateTreeHTML() : 

=cut
# Given the roots, Cid2Terms, return the tree in HTML string ready for 
# output to a browser
# Use attributes: 'Title', 'Cid2Terms', 'FileList'
# Use methods : Traverse()
sub CreateTreeHTML {
	my($me, $rRoot) = @_;  
	my($root, $i, $si, $msg, $c, @Root, $htmlstr, %Freq, $NumRecords, $str);

#	$htmlstr = "<html><head></head><body bgcolor=white>";
# output tree statistics
	%Freq = (); # (key, value) = (number_of_leaves, number_of_clusters)
	@Root = sort { $rRoot->{$b} <=> $rRoot->{$a} } keys %$rRoot;
#print "<p>", join("<br>\n", map{"$_:$rRoot->{$_}"}@Root), "<p>\n";
	# %$rRoot : (key, value) = (cluster_id:similarity, number_of_leaves)
	foreach $i (@Root) { $Freq{$rRoot->{$i}}++; } 
	$msg = ''; $si = 0;
	foreach $i (sort {$Freq{$b} <=> $Freq{$a}} keys %Freq) {
		$msg .= "$Freq{$i} clusters contain $i items<br>\n"; 
		$si += $i * $Freq{$i};
	}
	$htmlstr .= "There are ". scalar @Root. " clusters, $si items<p>\n". $msg;
# output tree structures
	foreach $root (@Root) {
		$c++;  $i = 0;  
		($str, $NumRecords) = $me->Traverse($root, "", ++$i);
		$htmlstr .= "\n<p>$c(" . $rRoot->{$root} . "):<UL>\n" 
			 . $str . "\n</UL>\n";
	}
#	$htmlstr .= "\n<br></body></html>";
	return $htmlstr;
}

=head2 Traverse() : 

=cut
# Use attributes: 'Title', 'Cid2Terms', 'DocPath', 'ShowDoc'
sub Traverse {
	my($me, $node, $level, $i) = @_;  #(node, level_string, itemNo)
	my($n, $j, $t, $title, $cid, @T, @Sons, $patnum, $ctt, $htmlstr, $h);
	my($rDocPath, $rCid2Terms, @TV, %TermV, $rTree, $str, $NumRecords);
	$rTree = $me->{'Tree'};
	$rCid2Terms = $me->{'Cid2Terms'};
	$rDocPath = $me->{'DocPath'};
	$ctt = $me->{'NumCatTitleTerms'}-1;
		
#	$htmlstr .= "<li>$level$i. $node\n";
	@Sons = split /\t/, $rTree->{$node};
	if (@Sons == 0) { # if leaf node, format is "document number"
		$title = $me->{'Title'}[$node];
		$title = $me->Top2Lines($title, 100) if length($title)>100;
		$htmlstr .= "<li><a href='$me->{ShowDoc}?f=$rDocPath->[$node]";
		$htmlstr .= "&st=html'>$node : $title</a>\n";
		$htmlstr .= "<br>\n"; 
#		if ($title =~ /(\d+)筆/) { $NumRecords = $1; } 
		if ($title =~ /(\d+) Docs./) { $NumRecords = $1; } 
		else { $NumRecords = 1; }
	} else { # if internal node, format is "Node_Number:Similarity"
		$h .= "\n<UL>\n" if @Sons > 1;
		for ($j=0; $j<@Sons; $j++) {
			($str, $n) = $me->Traverse($Sons[$j], "  $level$i.", $j+1);
			$h .= $str; $NumRecords += $n;
		}
		$h .= "</UL>\n" if @Sons > 1;
		$htmlstr .= $me->ClusterTitleString($node, $rCid2Terms, $ctt, $NumRecords) . $h;
	}
	return ($htmlstr, $NumRecords);
} # End of &Traverse()


sub ClusterTitleString {
	my($me, $node, $rCid2Terms, $ctt, $NumRecords) = @_;
	my($htmlstr, $cid, @T, %TermV, $n, $t, $j, @TV, $nn);
	$nn = $node;
#	$nn =~ s#:(.+)# : $NumRecords筆 : <font color=green>$1</font>#;
	$nn =~ s#:(.+)# : $NumRecords Docs. : <font color=green>$1</font>#;
	$htmlstr .= "<li>$nn\n";
	if ($node =~ /(\d+):/) { $cid = $1;
		@T = split("\t", $rCid2Terms->{$cid});
#=head sort the term by the value
		%TermV = (); # clear the hash
		for ($n=0; $n<@T; $n++) {
			($t, $j) = split /:/, $T[$n];
#			last if $j<1 and $n>=3; 
			$TermV{$t} = $j;
		} # get at most $ctt+1 terms or more terms if their values are 1s
#		print "(", join(", ", @T[0..$n]), ")\n";
		@TV = sort {$TermV{$b} <=> $TermV{$a}} keys %TermV;
		$n = (@TV-1<$ctt)?@TV-1:$ctt;
		$htmlstr .= "(".join(", ",map{"$_:$TermV{$_}"}@TV[0..$n]).")\n";
#=cut
#		print "(", join(", ", @T[0..(@T>$ctt?$ctt:@T)]), ")\n";
#		print "(", join(", ", @T[0..($#T)]), ")\n";
	}
	return $htmlstr;
}

# Given a string, return the 1st 2 line ($MaxLength) words
sub Top2Lines { 
	my($me, $str, $NoWords) = @_;  my($q, $p, $c);
	$NoWords = 60 if $NoWords < 1; # if $NoWords not given
	$q = 0;
	for ($p=0; $p<length($str); $p++) {
		$c = substr($str, $p, 1); $q++;
		if (ord($c)>127) { # if Chinese
			$p++; $q++; if ($q>=$NoWords) { $p++; last; }
		} else { 
			$q-- if $c =~ /\s/o; 
			$c = 'nw' if ($c=~/\W/o);
		}
		last if ($q>=$NoWords && $c eq 'nw');
	}
	$c = substr($str, 0, $p);  $c .= ' ... ' if $p < length($str);
#	$c =~ s/<[^>]>//go;
#	$c =~ s/\s\s+/\s/g; # delete consecutive white spaces, added Nov. 14, 2000
	return  $c;
} # End of &Top2Lines()


# C:\CATAR_src\src>perl -s Term_Trend.pl -Ocolor -Ocut=0.01 -Omap -Oscale=2.5 -ONoOL -OhtmlTree=..\Result\SC_Edu_JBC_S2\0_0.01.html ..\Result\SC_Edu_JBC_S3
sub GetCid2Cno { # 2011/04/25
	my($me, $HtmlFile) = @_; my($HTML, %Cid2Cno);
	open F, $HtmlFile or die "Cannot read file:'$HtmlFile'";
	undef $/; $HTML = <F>; close(F); $/ = "\n"; # get all content in one read
	close(F); # format of cluster ID: '1(62):<UL>\n<li>235 : 25 Docs.'
	while ($HTML =~ /<p>(\d+)\(\d+\):<UL>\s+<li>(\d+) :/img) { 
		$Cid2Cno{$2} = $1;  #print "$1 => $2\n";
	}
	return \%Cid2Cno;
}


=head2 CreateBigDoc() : 

=cut
# Given the roots, Cid2Terms, retrieve each document's content
#   and append the content together under the same cluster.
# Use attributes: 'Title', 'Cid2Terms', 'FileList'
sub CreateBigDoc {
	my($me, $rRoot, $OutDir) = @_;  
	my($root, $i, $file, $c, @Root, @DocList, $rCatId2DocIds, $title);
	my($rCid2Terms, $ctt, $str, $NumRecords, $DBH);
	$DBH = $me->InitDBMS($me->{DSN}, $me->{DB_Path}) if $me->{DSN};
	$rCatId2DocIds = $me->{'CatId2DocIds'}; # have doc list in each cluster
	# before using the above line, you should call &GenCid2Terms();
	$rCid2Terms = $me->{'Cid2Terms'};
	$ctt = $me->{'NumCatTitleTerms'}-1;
	$i = 0;
	@Root = sort { $rRoot->{$b} <=> $rRoot->{$a} } keys %$rRoot;
	foreach $root (@Root) { # get each new root's number of leaves
		@DocList = split ' ', $rCatId2DocIds->{(split/:/,$root)[0]};
		next if @DocList == 0;
		next if @DocList <= $me->{'MinCluSize'}; # added on 2006/07/19
		# skip if the cluster contains too few documents
		$i++;
		$file = "$OutDir/${i}_" . $rRoot->{$root} . ".htm";
		($str, $NumRecords) = $me->Traverse($root, "", $i);
		$title = $me->ClusterTitleString($root, $rCid2Terms, $ctt, $NumRecords);
		$title =~ s#<[^>]+>|\n+##g;
		$str = $me->DumpContent($file, $DBH, @DocList);
		open F, ">$file" or die "Cannot write to file:'$file', $!";
		print F "<html><head><title>". $title . "</title></head>\n<body>\n"
			. $str . 
			"\n</body></html>\n";
		close(F);
	}
}

# Given a list of documents, read all their contents into a string
#   return this string
sub DumpContent {
	my($me, $file, $DBH, @DocList) = @_;
	return $me->DumpContentFromDBMS($file, $DBH, @DocList) if $me->{DSN};
	my($str, $rDocPath, $docid, $doc);
	$rDocPath = $me->{'DocPath'};
	local $/; undef $/; # to get all content in one read
	foreach $docid (@DocList) {
		$file = $rDocPath->[$docid];
		open F, $file or die "Cannot read file:'$file', $!";
		$doc = <F>; # get all content in one read
		close(F);
		$doc =~ s/\n+/\n/g;
		$str .= $doc . "\n\n\n"; # refer to &DocList() in tool.pl for format
	}
	return $str;
}

# added on 2006/10/22 for fetch paper's content
# Refer to &FromFile2BigDoc() in Cluster.pl for DSN and SQL
# Refer to &DocList() in tool.pl
# 對付：如果歸類後的結果在 Result\ 中，但文件在 DBMS 裡
sub DumpContentFromDBMS {
	my($me, $file, $DBH, @DocList) = @_;  
	my($sql, $STH, $id, $title, $content, $str, $did, $txt, $encoding_name);
	my $rDocPath = $me->{'DocPath'};
	$sql = $me->{SQL};
#print STDERR "dumping $file, DocList=@DocList =>",map({$rDocPath->[$_].","}@DocList),"\n";
	$STH = $DBH->prepare($sql)
		or die "Can't prepare SQL statement: $DBI::errstr\n";
	foreach $did (@DocList) {
		$STH->execute($rDocPath->[$did]);
		while (($id, $title, $content) = $STH->fetchrow_array) {
			foreach $txt ($title, $content) { # 2010/12/04
				$encoding_name = Encode::Detect::Detector::detect($txt);
				if ($encoding_name =~ /UTF-8/i) { # if utf8-encoded
#					$txt = encode("big5", $txt); # from utf-8 to big5
#				if ($encoding_name !~ /big5/i) { # if utf8-encoded
					from_to($txt, $encoding_name, 'big5'); 
				}
			}
			$content =~ s/\n+/ /g; # 2010/12/04
#			$str .= "$title : $id : $content. \n"; # title, $id, $content
			$str .= "$title\t:\t$id\t:\t$content. \n"; # title, $id, $content
		}
	}
	$STH->finish;
	return $str
}


=head2 GenCid2Terms

=cut
# Given all the roots and the tree, generate and return a Node2Cat hash
# This is to be used for generating category names for each cluster.
sub GenCid2Terms {
	my($me, $rRoot) = @_; my(%CatId2DocIds, $root, $rTree);
	$rTree = $me->{'Tree'};

	foreach $root (@$rRoot) {
		$CatId2DocIds{(split/:/,$root)[0]} = &GetCat2Docs($root, $rTree, \%CatId2DocIds);
#my $n=(split/:/,$root)[0]; print "\$CatId2DocIds{$n}=$CatId2DocIds{$n}<br>\n";# if $n==14;
	}
	# Next line is added on 2005/08/12
	$me->{'CatId2DocIds'} = \%CatId2DocIds; # saved for &CreateBigDoc();
# Now  compute %TP(t,c), %DF(t), %DFcat(c)
#print STDERR "\$me->{ClusterTitle}='", $me->{'ClusterTitle'}, "' eq 'TFC'=", ($me->{'ClusterTitle'} eq 'TFC'), ", 'TFC' eq 'TFC'=", ('TFC' eq 'TFC'), "\n"; exit;
	if ($me->{'ClusterTitle'} eq 'TFC') {
		$me->ComputeTermFreqInClass(\%CatId2DocIds); # set and reutrn %Cid2Terms
	} else {
		$me->GetTP(\%CatId2DocIds); # set %TP(t,c), %DF(t), %DFcat(c)
		$me->ComputeCHI(); # Given %TP(t,c), %DF(t), %DFcat(c), Set %TP(t,c)
		$me->ComputeMaxCHI(); # Given %TP, set and reutrn %Cid2Terms
	}
}

# Given a node, return its docs (at the leaves) seperated by tab
#  Also for all the sons of the node, we also record their doc list.
sub GetCat2Docs {
	my($node, $rTree, $rCatId2DocIds) = @_;  my($son, @D, @Sons);
	@Sons = split /\t/, $rTree->{$node};
	if (@Sons == 0) {
		return ((split /:/, $node)[0]); # return doc_id
	}
	foreach $son (@Sons) {
		push @D, &GetCat2Docs($son, $rTree, $rCatId2DocIds);
	}
# For each level of internal nodes, we need to know its CatId2DocIds
	$rCatId2DocIds->{(split/:/,$node)[0]} = join "\t", @D;
#my $n=(split/:/,$node)[0]; print "called:\$rCatId2DocIds->{$n}=$rCatId2DocIds->{$n}<br>\n";# if $n==14;
	return join "\t", @D;
}


=head2 GetTP()

=cut
# compute %TP(t,c), %DF(t), %DFcat(c)
sub GetTP{
	my($me, $rCatId2DocIds) = @_; 
	my(%DFcat, %DF, %TP, %Did2Cid, $rInv, @D, $percent, $tn, $ti, %TFC);
	my($t, $v, %PTR, $df, $did, $dids, $tf, @Cat, $c, $nkon, $cid, $stime);
	my $OphraseOnly = $me->{'OphraseOnly'};
	my $Progress = $me->{'Progress'};
	my $Stop = Stopword->new();
	$rInv = $me->{'Inv'};
	$stime = time();
	
# Compute %DFcat, %Did2Cid
	while (($cid, $dids) = each %$rCatId2DocIds) { 
		@D = split ' ', $dids; # split by white spaces
#print "$cid=>@D<br>\n";# if $cid==14;
		$DFcat{$cid} = scalar @D;
		foreach $did (@D) {  $Did2Cid{$did} .= "$cid\t"; }
	}
	$me->{'NumDocClass'} = scalar keys %Did2Cid;
# Set %TP and %DF
	$c = keys %DFcat;
	$tn = keys %$rInv;
	print STDERR "Compute TP(t,c) for $tn terms and $c classes...\n" if $me->{debug} >= 1;
	$percent = $ti = 0;
	while (($t, $v) = each %$rInv) {
		$ti++;	$percent = $Progress->ShowProgress($ti/$tn, $percent) if $me->{debug} >= 1;
		next if $t =~ /\d+\.?\d*/; # escape numbers
		next if length($t)<3; # term length too short
		next if $t =~ /一|二|三|\Q四\E|五|六|七|八|九|十/; # escape numbers
#print STDERR "$t=>'", $Stop->IsESW($t), "', Stopword::ESW{$t}='", $Stopword::ESW{$t} ,"'\n" if $t =~ /^produc\w?$/;
#		next if $Stop->IsESW($t);
#		next if $Stop->IsESW(substr($t, 0, index($t, ' '))); # 2005/08/08
#		next if $Stop->IsESW(substr($t, rindex($t, ' ')+1, length($t)));		
#next if $OnoPhrase and $t =~ /\w\s\w/; # escape English multi-word phrase
#		$nkon = $t =~ tr/ / /; # next if $nkon>3; # 2003/01/24
		next if $OphraseOnly and ($t =~ tr/ / /)<1; # 2006/05/01, skip if not phrase
		%PTR  = split /,/, $v;
#print "$t : ", (map {"$_:$PTR{$_}, "} keys %PTR), "\n" if $t eq 'island' or $t eq 'telephon';
#		$df = keys %PTR; $DF{$t} = $df;
		while (($did, $tf) = each %PTR) {
			next if $tf <= $me->{'ct_low_tf'}; # 2003/04/16
			@Cat = split ' ', $Did2Cid{$did};
#print "\$Did2Cid->{$did}=$Did2Cid->{$did}\n" if @Cat ==0;
			next if @Cat == 0; # next if the did is not in any cluster
			$DF{$t}++; # only those dids having cats are counted
			foreach $c (@Cat) {  
				$TP{"$t\t$c"}++;  
				$TFC{"$t\t$c"}+=$tf;
			}
		}
	}
	$percent = $Progress->ShowProgress($ti/$tn, $percent) if $tn>0 and $me->{debug} >= 1;
	print STDERR "  It takes ", time() - $stime
		, " seconds to compute TP(t,c)\n"if $me->{debug} >= 1;
	$me->{'TP'} = \%TP;
	$me->{'DF'} = \%DF;
	$me->{'DFcat'} = \%DFcat;
	$me->{'TFC'} = \%TFC;
}

=head2 ComputeCHI() 

=cut
# Use %TP, %DF, %DFcat, $NumDocClass, 
# Set %Chi
# calculate one-sided chi-sqaure for each (t, c) and save in %Chi
sub ComputeCHI {
	my($me) = @_;  my($rTP, $rDF, $rDFcat, $NumDocClass, %Chi, $rTFC, $stime);
	my($k, $t, $c, $tp, $fp, $fn, $tn, $chi, $tdf, $cdf, $tk, $ti, $percent);
	$stime = time();
	my $Progress = $me->{'Progress'};
	$rTP = $me->{'TP'};
	$rDF = $me->{'DF'};
	$rDFcat = $me->{'DFcat'};
	$rTFC = $me->{'TFC'};
	$NumDocClass = $me->{'NumDocClass'};
	$tk = keys %$rTP; $ti = $percent = 0;
print STDERR "Computing Correlation(t, c) for $tk pairs...\n" if $me->{debug} >= 1;
	while (($k, $tp) = each %$rTP) {
		$ti++;	
		$percent = $Progress->ShowProgress($ti/$tk, $percent) if $me->{debug} >= 1;
		($t, $c) = split /\t/, $k;
		$fp = $rDF->{$t} - $tp;
		$fn = $rDFcat->{$c} - $tp;
		$tn = $NumDocClass - $tp - $fp - $fn;
		if (($tp+$fn)==0 or ($fp+$tn)==0 or ($tp+$fp)==0 or ($fn+$tn)==0) {
			$chi = 0; 
		} else {
			$chi = ($tp*$tn - $fp*$fn)/sqrt(($tp+$fn)*($fp+$tn)*($tp+$fp)*($fn+$tn));
		}
		if ($me->{'ClusterTitle'} eq '' or $me->{'ClusterTitle'} eq 'ChixTFC') {
			$Chi{$k} = $chi * $rTFC->{$k}; # 2005/08/15	3
#			$Chi{$k} = $chi * log(1+$rTFC->{$k}) * $me->{NumDoc}/$rDF->{$t}; # 2008/11/17
		} elsif ($me->{'ClusterTitle'} eq 'Chi') {
			$Chi{$k} = $chi; # Correlation Coefficient,	1
		} elsif ($me->{'ClusterTitle'} eq 'TFC') {
			$Chi{$k} = $rTFC->{$k}; # 2005/08/15	2
		}
#print "Chi{$k}=$Chi{$k}, tp=$tp, fp=$fp, fn=$fn, tn=$tn<br>\n";# if $t eq '工 程';
	}
	$percent = $Progress->ShowProgress($ti/$tk, $percent) if $tk>0 and $me->{debug} >= 1;
print STDERR "It takes ", time() - $stime, " seconds to compute correlation.\n" if $me->{debug} >= 1;
	$me->{'Chi'} = \%Chi;
}

# Given %Chi, %DF, $DocNum, set %Cid2Terms
sub ComputeMaxCHI {
	my($me) = @_; my($rTP, $rDF, $rDFcat, $NumDocClass, $rChi);
	my($k, $t, $cat, @Chi, @tn, $v, $vdf, %Cid2Terms);
	$rChi = $me->{'Chi'};
	$rTP = $me->{'TP'};
	$rDF = $me->{'DF'};
	$rDFcat = $me->{'DFcat'};
	$NumDocClass = $me->{'NumDocClass'};
	@Chi = sort {$rChi->{$b} <=> $rChi->{$a} } keys %$rChi;
	foreach $k (@Chi) {
		($t, $cat) = split /\t/, $k;
#		next if $rDF->{$t} <= $Odf;
#		$tn[$cat]++;	next if $tn[$cat] > 9;
		$v = sprintf("%.4f", $rChi->{$k}); 
#		$v = 1 if $v >= 1;
# above 2 lines is replaced by the next 2 lines on 2003/12/22, but no better
#		$vdf = $rChi->{$k} * log($rDF->{$t})/log($NumDocClass);
#		$v = sprintf("%.4f", $vdf); 
    	
		$Cid2Terms{$cat} .= "<b>$t</b>:$v\t" 
#		$Cid2Terms{$cat} .= "<b>$t</b>\t" 
		if $v > 0 
		and $rTP->{$k} >= $rDFcat->{$cat} * 0.5
		and index($Cid2Terms{$cat}, "$t")<0; # should not include substring
#		if $v > 0 and index($Cid2Terms{$cat}, ">$t<")<0;
#print "\$Cid2Terms{$cat}=$Cid2Terms{$cat}, '$t':$v, TP=$rTP->{$k}, DFcat=$rDFcat->{$cat}<br>\n";
	}
#print join("<p>\n", map{"$_:$Cid2Terms{$_}"}keys%Cid2Terms), "<p>\n";
	$me->{'Cid2Terms'} = \%Cid2Terms;
}


=head2 ComputeTermFreqInClass()

Set:
	%DFcat($cid) : 某一類別的文件篇數
	%DF($t) : 某一詞彙的出現篇數
	%TFC($t, $cid) ：詞彙在某類別內的出現總次數 = Sum_over_D_in_C(TF)
	%CoF(t)：詞彙在文件集內的出現總次數 = Sum_over_C(TFC)
	%CF(t)：詞彙出現的類別個數（在幾個類別中出現該詞）

=cut
sub ComputeTermFreqInClass{
	my($me, $rCatId2DocIds) = @_; 
	my(%DFcat, %DF, %TP, %Did2Cid, $rInv, @D, $percent, $tn, $ti);
	my($t, $v, %PTR, $df, $did, $dids, $tf, @Cat, $c, $nkon, $cid, $stime);
	my(%CoF, %CF, %TFC, @TFC, $k, %Cid2Terms);
	my $Progress = $me->{'Progress'};
	my $Stop = Stopword->new();
	$rInv = $me->{'Inv'};
	$stime = time();
	
# Compute %DFcat, %Did2Cid
	while (($cid, $dids) = each %$rCatId2DocIds) { 
		@D = split ' ', $dids; # split by white spaces
#print "$cid=>@D<br>\n";# if $cid==14;
		$DFcat{$cid} = scalar @D;
		foreach $did (@D) {  $Did2Cid{$did} .= "$cid\t"; }
	}
#	$me->{'NumDocClass'} = scalar keys %Did2Cid;
# Set %TP and %DF
	$c = keys %$rCatId2DocIds;
	$tn = keys %$rInv;
	print STDERR "Compute TP(t,c) for $tn terms and $c classes...\n" if $me->{debug} >= 1;
	$percent = $ti = 0;
	while (($t, $v) = each %$rInv) {
		$ti++;	$percent = $Progress->ShowProgress($ti/$tn, $percent) if $me->{debug} >= 1;
		next if $t =~ /\d+\.?\d*/; # escape numbers
		next if length($t)<3; # term length too short
		next if $t =~ /一|二|三|\Q四\E|五|六|七|八|九|十/; # escape numbers
#print STDERR "$t=>'", $Stop->IsESW($t), "', Stopword::ESW{$t}='", $Stopword::ESW{$t} ,"'\n" if $t =~ /^produc\w?$/;
#		next if $Stop->IsESW($t);
#		next if $Stop->IsESW(substr($t, 0, index($t, ' '))); # 2005/08/08
#		next if $Stop->IsESW(substr($t, rindex($t, ' ')+1, length($t)));		
#next if $OnoPhrase and $t =~ /\w\s\w/; # escape English multi-word phrase
#		$nkon = $t =~ tr/ / /; # next if $nkon>3; # 2003/01/24
		%PTR  = split /,/, $v;
#print "$t : ", (map {"$_:$PTR{$_}, "} keys %PTR), "\n" if $t eq 'island' or $t eq 'telephon';
#		$df = keys %PTR; $DF{$t} = $df;
		while (($did, $tf) = each %PTR) {
			next if $tf <= $me->{'ct_low_tf'}; # 2003/04/16
			@Cat = split ' ', $Did2Cid{$did};
#print "\$Did2Cid->{$did}=$Did2Cid->{$did}\n" if @Cat ==0;
			next if @Cat == 0; # next if the did is not in any cluster
			$DF{$t}++; # only those dids having cats are counted
			$CoF{$t} += $tf;
			$CF{$t} = scalar @Cat;
			foreach $c (@Cat) {  $TFC{"$t\t$c"}+=$tf;  }
		}
	}
	$percent = $Progress->ShowProgress($ti/$tn, $percent) if $tn>0 and $me->{debug} >= 1;
	print STDERR "  It takes ", time() - $stime
	, " seconds to compute TFC(t,c)\n"if $me->{debug} >= 1;
=commnet
	while (($k, $tf) = each %TFC) {
		($t, $cid) = split /\t/, $k;
		if ($CoF{$t}) {
#			$TFC{$k} = $me->ts($TFC{$k}/$CoF{$t}*$TFC{$k}, 4);
#			$TFC{$k} = $me->ts($TFC{$k}*1/$CF{$t}, 4);
			$TFC{$k} = $me->ts(log($TFC{$k}+1)*1/$CF{$t}, 4); # 2008/11/17
		}
	}
=cut
	@TFC = sort {$TFC{$b} <=> $TFC{$a} } keys %TFC;
	foreach $k (@TFC) {
		($t, $cid) = split /\t/, $k;
		$Cid2Terms{$cid} .= "<b>$t</b>:$TFC{$k}\t";
	}
#print join("<p>\n", map{"$_:$Cid2Terms{$_}"}keys%Cid2Terms), "<p>\n";
	$percent = $Progress->ShowProgress($ti/$tn, $percent) if $tn>0 and $me->{debug} >= 1;
	print STDERR "  It takes ", time() - $stime
		, " seconds to compute and sort TFC(t,c)\n" if $me->{debug} >= 1;
	$me->{'Cid2Terms'} = \%Cid2Terms;
}


=head2 Silhouette() : compute Silhouette index for a clustering result

Silhouette values are used as a metric-independent measure that describes the 
ratio between cluster coherence and cluster separation for each point:

	s(k,i) = (b(i)-a(i))/max(a(i),b(i))

where 
  a(i)is the average distance of member i to all other members of cluster k
  b(i) the average distance of i to the points in the nearest cluster
See 
  Jain, A., & Dubes, R. (1988). Algorithms for clustering data. Prentice Hall.
  P. Glenisson et al. Information Processing and Management 41(2005) 1548–1572

We can summarize the silhouette values for all points in a cluster 
by taking an average:

	s(k) = Sum(s(i,k) for all i in k)/(number of item in k)
	
Likewise we can compute a score for an entire solution by 
subsequently averaging out over all clusters.
	
	C = Sum(s(k) for all k in clustering C)/(number of clusters in C)

=cut
sub Silhouette {
	my($me, $Threshold) = @_; 
	my($root, @NewRoot, %NewRoot, $rTree, $rRoot, $stime);
	my($si, @si_k, @si_k_i, @a_k_i, @b_k_i, $did, $cid, $c);
	my($rDid2Cids, $rCid2Dids, %CatId2DocIds, @AllDid, @AllCid, %AllCid);
	my(%SimPair, $pair, $d1, $d2, $sim, @Did, $sum, $t);
print STDERR "\nCompute Silhouette index with threshold: '$Threshold'.\n" if $me->{debug}>=1;
	$stime = time();
	$rRoot = $me->{'Root'};
	$rTree = $me->{'Tree'};
	foreach $pair (@{$me->{'SortedPairs'}}) {
		($d1, $d2, $sim) = split ' ', $pair;
		$t = ($d1 lt $d2)?"$d1\t$d2":"$d2\t$d1";
		$SimPair{$t} = $sim; # It should be $d1 < $d2
	} # get the similarity between all pairs of documents
	foreach $root (keys %$rRoot) { # get all the doc ids in old clustering
		push @AllDid, split ' ', &GetCat2Docs($root, $rTree, \%CatId2DocIds);
		# do not use %CatId2DocIds. It is for the old clustering.
	} # Now we have all the document IDs in @AllDid
	# Cut the clustering with the threshold to get a new clustering
	($rDid2Cids, $rCid2Dids) = $me->CutCollection($Threshold);
# If a $did does not belong to any cluster, then $rDid2Cids->{$did} eq ''
# So we need to label each $did with a new cid
# Note: %rCid2Dids contains all the sub-clusters in its keys
#   Therefore, next line will have bugs.
#	@AllCid = sort {$a<=>$b} keys %$rCid2Dids; # sort cid ascendingly
	foreach (values %$rDid2Cids) { $AllCid{$_}++; }
	@AllCid = sort {$a<=>$b} keys %AllCid;
#print "\@AllCid=", join(',', @AllCid), "\n";
	foreach $did (@AllDid) {
		$cid = $rDid2Cids->{$did};
		if ($cid eq '') { 
# if this $did belongs to a singleton cluster (having only one did)
# label the singleton cluster by (1 + the cid of the last one cluster)
			$cid = $AllCid[$#AllCid]+1; # get the last one cid
			push @AllCid, $cid;
			$rDid2Cids->{$did} = $cid;
			$rCid2Dids->{$cid} = $did;
		}
	}
# We can compute a(k, i), b(k, i), and si(k, i) for each data point
	foreach $did (@AllDid) {
		$cid = $rDid2Cids->{$did};
		@Did = split ' ', $rCid2Dids->{$cid}; # all doc ids in cluster $cid
#print "cid=$cid, did=$did, Did=", join(",",@Did), "\n";
		if (@Did == 0) { $si_k_i[$cid][$did] = 0; warn "error!\n"; next; }
		$a_k_i[$cid][$did] = &AvgDist($did, \@Did, \%SimPair);
		$b_k_i[$cid][$did] = &NearestCluster($did, $cid, \@Did, 
			\%SimPair, $rDid2Cids, $rCid2Dids);
		$si_k_i[$cid][$did] = ($b_k_i[$cid][$did] - $a_k_i[$cid][$did])
			/ (($a_k_i[$cid][$did]>$b_k_i[$cid][$did])?
				$a_k_i[$cid][$did]:$b_k_i[$cid][$did]);
#print "a_k_i[$cid][$did]=",$me->ts($a_k_i[$cid][$did]),", b_k_i[$cid][$did]=", $me->ts($b_k_i[$cid][$did]), ", si_k_i[$cid][$did]=", $me->ts($si_k_i[$cid][$did]), "\n";
	}
# Now compute the Silhouette value for each cluster
	foreach $cid (@AllCid) {
		@Did = split ' ', $rCid2Dids->{$cid}; # all doc ids in cluster $cid
		$sum = 0; foreach $did (@Did) { $sum += $si_k_i[$cid][$did]; }
		$si_k[$cid] = $sum/@Did;
#print "cid=$cid, Did=", join(",",@Did), ", si_k[$cid]=", $me->ts($si_k[$cid]),"\n";
	}
# Compute Silhouette value for the clustering
	$sum = 0;  foreach $cid (@AllCid) { $sum += $si_k[$cid];  }
	$si = $sum / @AllCid;
print STDERR "It takes ", time()-$stime, " seconds to compute ",
	(scalar @AllCid), " clusters having a total of ", (scalar @AllDid),
	" documents\n with the Silhouette value=", $me->ts($si),".\n" if $me->{debug} >= 1;
	return ($si, \@si_k, \@si_k_i, $rDid2Cids, $rCid2Dids, 
			(scalar @AllCid), (scalar @AllDid));
}


# Compute the sum of distances of member i to all other members in the same cluster
sub AvgDist {
	my($did, $rDids, $rSimPair) = @_;
	my($d, $sum, $key, $dist, $n); $n = 0; $sum = 0;
	foreach $d (@$rDids) {
		next if $d eq $did; 
		$n++; # count number of items for distance calculation
#		$key = join("\t", sort{$a<=>$b}($d, $did));
		$key = ($d lt $did)?"$d\t$did":"$did\t$d";
	#	warn "AvgDist: Cannot get similarity: \$rSimPair->{$key}\n" if not defined $rSimPair->{$key};
		$sum += $dist = (1 - $rSimPair->{$key});
		die "Distance is negative: 1-\$rSimPair->{$key}=$dist\n" if $dist < 0;
	}
	return 1 if $n == 0;
#	return $sum if $n == 0;
	return $sum/$n;
}

# Compute b(i) the average distance of i to the points in the nearest cluster
# Given the $did, its $cid, and its @DocList under the same $cid
sub NearestCluster {
	my($did, $cid, $rDid, $rSimPair, $rDid2Cids, $rCid2Dids) = @_;
	my($NearestCid, @Did);
	$NearestCid = &NearestCid($did, $cid, $rDid, $rSimPair, $rDid2Cids);
	@Did = split ' ', $rCid2Dids->{$NearestCid}; # all doc ids in cluster $cid
	return &AvgDist($did, \@Did, $rSimPair);
}

# Given the did and its cid, find a nearest cluster from $rSimPair and $rDid2Cids
sub NearestCid {
	my($did, $cid, $rDid, $rSimPair, $rDid2Cids) = @_;
	my($d, $max, $maxd, @AllDid, %Did, $key);
	foreach $d (@$rDid) { $Did{$d} = 1; }
	@AllDid = sort {$a <=> $b} keys %$rDid2Cids;
# for the boundary case where there is only one did and only one cid
	$max = 0; $maxd = $did; 
	foreach $d (@AllDid) {
		next if $Did{$d}; # skip if in the same cluster
#		$key = join("\t", sort{$a<=>$b}($d, $did));
		$key = ($d lt $did)?"$d\t$did":"$did\t$d";
#print "did=$did, d=$d, Did{$d}=$Did{$d}\n";
	#	warn "NearestCid: Cannot get similarity: \$rSimPair->{$key}\n" if not defined $rSimPair->{$key};
		if ($max < $rSimPair->{$key}) {
			$max = $rSimPair->{$key}; $maxd = $d;
		}
	}
# Now we have found the nearest (most similar) document in another cluster
	return $rDid2Cids->{$maxd};
}

1;
