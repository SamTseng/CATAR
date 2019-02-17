#!/usr/bin/perl -s
#=======================================================================
#   This segmentation system is developed by Yuen-Hsien Tseng
#   (Email:tseng@blue.lins.fju.edu.tw) on Oct 27, 2000
#   last modified Oct. 27, 2000. All rights reserved!
#=======================================================================
sub Help {
	print <<USAGE;
    perl -s SegWord.pl Text_File.txt > result.html
    
    SegWord.pl read a text file from a give file or from a browser (need
    SegWord.html as its interface) and output the result in HTML
    to standard output (or back to the browser).
    
    You need to install some programs and data in the SAM directory. To intall
    SAM, just copy SAM to C:\Perl\site\lib\ if Perl is installed at c:\Perl.

USAGE
    exit;
}
    &Help() if $h or $help;
    $ivURL = 'http://localhost/demo/ir/iv';
    print "Content-type: text/html\n\n";
    print "<html><head><META content='text/html; charset=big5'></head>"
	. "<body bgcolor=white>";
    require "d:/demo/ig/sam.lib/parseCGI2.pl"; &CGIParseInit();
    $start = time();  # Start timing

    my $t = &GetInput(); # Set global vars
    $t =~ s#<[^<>]*>#,#g;

    $start = time();

# Now $t contain the input text 
    my ($rWL, $rFL, $rSeg, $w, $WordList, $c, $wc, $str);
    use SAMtool::SegWord;
    use SAMtool::Stem;
  if (1) { # either way will work
    $seg = SegWord->new( { 'WordDir'=>'SAM/word', 'UseDic'=>$dic} );
#    $seg = SegWord->new( { 'WordDir'=>'SAM/word', 'UseDic'=>$dic , 'WantRT'=>0} );
  } else {
    $seg = SegWord->new( );
    $seg->Init( { 'WordDir'=>'SAM/word', 'UseDic'=>$dic } );
  }

#    print "Before DelESW(), IsESW(table)=", $seg->IsESW('table'),"<p>\n";
#    $seg->DelESW('table'); # 2009/10/19
#    $seg->AddESW('relational'); # 2009/10/19
#    print "After  DelESW(), IsESW(table)=",$seg->IsESW('table'),"<p>\n";

    $seg->Value('MaxRT', 30); # set 'MaxRT' to 30
    $seg->Value('ShowAllKT', $ShowAllKT); # 2009/10/11
    $seg->Value('Stemming', $Stemming);   # 2009/10/11
    if ($DelSpace) {
	$t =~ s/\s+//; $t = lc join ' ', split //, $t; # 2009/10/11
    }
    ($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
    $rLinkValue, $rSenList, $rCoSenIdx) = $seg->ExtractKeyPhrase($t); 

=noname 2008/05/20
    $c=0;     $WordList .= "\n<HR>人名：<p>\n";
    $wc = scalar keys %$rName; $WordList .= "<table border=0 width=100%><tr>\n";
    foreach $w (keys %$rName) { 
    	$c++; 
    	$WordList .="<td start=$c valigh=top width=33%>\n" if ($c%int($wc/3+0.67)==1);
    	$WordList .= "$c : $w : $rName->{$w}<br>\n";
    }
    $WordList .= "</tr></table>\n";
=cut

    $c=0;     $WordList .= "\n<HR>關鍵詞：<p>\n";  
    $wc = @$rWL; $WordList .= "<table border=0 width=100%><tr>\n";
    foreach $w (@$rWL) {
    	$c++;
    	$WordList .="<td start=$c valigh=top width=33%>\n" if ($c%int($wc/3+0.67)==1);
    	$color = 'black';
    	if ($rFL->{$w} and $rSFL->{$w}) {  #$color = "red";
	} elsif ($rFL->{$w}) {  $color = "blue";  
	} elsif ($rSFL->{$w}) { $color = "green"; 
	}
	$WordList .= "<font color=$color>" .
		"$c : $w : $rFL->{$w}</font><br>\n";  
    }
    $WordList .= "</tr></table>\n";

    $WordList .= &OrganizeWords($rWL, $rFL);

    my $rLV = $seg->TrimLink($rLinkValue, $rFL);
    my $SBS = join ",", sort {$rLV->{$b} <=>$rLV->{$a}} keys %$rLV;
    $SBS =~ s/ (\W)/$1/g; # 2009/10/18
    $WordList .= "\n<hr>關聯圖（部分關聯詞對）：<p>\n" . &TwoD($SBS);

    my($rSenRank) = $seg->RankSenList($rWL, $rFL, $rSN, $rSenList);
    $WordList .= "\n<hr>摘要：<p>\n" . &ShowAbs($rSenRank, $rSenList);

=comment until next =cut
    $c=0; $WordList .= "\n<HR>索引詞：<p>\n";
    foreach $w (@$rIWL) { 
    	$c++; 
    	$color = 'black';
    	if ($rFL->{$w} and $rSFL->{$w}) {  #$color = "red";
	} elsif ($rFL->{$w}) {  $color = "blue";  
	} elsif ($rSFL->{$w}) { $color = "green"; 
	}
	$WordList .= "<font color=$color>" .
		"$c : $w : $rSFL->{$w} : $rFL->{$w}</font><br>\n";  
    }
=cut

    if ($ShowAllRT) { # ShowAllRT is set in &GetInput()
    	$str = join "<br>\n",
    	  map{"$_ : " . sprintf("%3.5f", $rLinkValue->{$_})}
	  sort{$rLinkValue->{$b}<=>$rLinkValue->{$a}} keys %$rLinkValue;
	$str =~ s/ (\W)/$1/g; # 2009/10/18
	$str =~ s/\-\?/ : /g;
	$str = "\n<hr>所有關聯詞對：<p>\n" . $str;
#$x=join"<br>\n",map{"$_:$LinkValue{$_}"}sort keys%LinkValue;
#print"\n<hr>",$x,"<hr>\n";
	$WordList .= $str
    }
    
    $end = time();
    print "<center><table border=10 width=90%><tr><td>\n$t\n</table>\n";
    print "<hr><table border=10 width=90%><tr><td>\n$WordList\n</table>\n";
    print "<p><hr>It takes ",  $end-$start, 
    " seconds to segment the text<br><br></center></body></html>";

# Set global vars: 
#	$infile, $url, $dic, $text, $lang, $upfile
#	$ShowAllRT, $ShowAllKT, $Stemming
sub GetInput {
    my ($t, $infile);
    $infile = $ARGV[0];     $infile =~ s/^\s+|\s+$//g;
    if ($infile eq "" ) {
        &parse_form_data ($Root, *F);
        ($infile, $url, $dic, $text, $lang, $upfile) = 
	    @F{'infile', 'url', 'dic', 'text','lang', 'upfile'};
	if ($upfile) { $infile = $upfile; } else { $infile = $url; }
	($ShowAllRT, $ShowAllKT, $Stemming, $DelSpace) = 
	    @F{'ShowAllRT', 'ShowAllKT', 'Stemming', 'DelSpace'};
    }

    if ($infile eq "" && $text eq "") {  
	print "No file for extracting keywords\n"; exit(0); 
    }
    $URL = $infile;
#unless ($URL =~ s#^$document_root/(.*)#/$1#g)
#{   $URL =~ s#^(.*)/([^/]*)/$public_html/(.*)#/~$2/$3#g; }

$startget = time();  # End of timing
    if ($infile =~ /^http/) {
	use LWP::Simple;
        $t = get($infile);
        if ($t eq "") {
	    $t = $text;  $t =~ s/^\s+|\s+$//;
	    if ($t eq "") { 
		print "<h1>Error</h1>",
	      	"<h2>Document <a href='$URL'>$URL</a> contains no data!</h2>"; 
		exit(0);
	    }
	}
    } else {
	open(IN, "$infile") || return_error(500, "cannot open file: $infile");
	undef $/; $t = <IN>; 
	close(IN);
    }
$endget = time();  # End of timing
#print "Input:<br>$t<hr>\n";
    return $t;
} # End of &GetInput();

sub TwoD {
   my($SBS) = @_;
   my $str = <<TwoDTerm;
   <center>
   <applet code="Graph.class"  archive="Graph.jar" 
    codebase="$ivURL" width=470 height=400>
        <param name=edges value="$SBS">
        <param name=action value="http://127.0.0.1/cgi-ir/crystal79.pl">
        <param name=qc value="i">
        <param name=Idx value="ccnews">
        <param name=At value="0">
        <param name=tAt value="0">
        <param name=Item value="20">
        <param name=uid value="1027113929">
        <param name=lang value="c">
        <param name=dfmt value="s">
        alt="Your browser understands the &lt;APPLET&gt; tag but isn't running the applet, for some reason."
        Your browser is completely ignoring the &lt;APPLET&gt; tag!
    </applet>
    </center>
TwoDTerm
    return $str;
}

sub ShowAbs {
    my($rSenRank, $rSenList) = @_;
    my($i, $n) = (0, scalar @$rSenRank);
    my($str, $j);
    foreach (@$rSenRank) {
	$i++; $j = $_ + 1;
# print "<p><b>",int($i/$n * 100), "%, $j=></b>@$rSenList[$_]\n";
	$str .= "<p><b><font color=red>". int($i/$n * 100). 
		"%, $j=></font></b>@$rSenList[$_]\n";
    }
    return $str;
} # End of &ShowAbs()


# Given $rWL, $rFL
sub OrganizeWords {
    my($rWL, $rFL) = @_;
    my($w, $wl, $maxl, $i, @SWL, @SortWL, @WLP, @a);
# 1. index words with their word length:Same-length words are put together
    foreach $w (@$rWL) {
# English word length is determined by number of spaces
	$wl =  $w =~ tr/ / / + 1; 
	$SWL[$wl] .= "$w \0 ";  # indexed by the same word length
	if ($maxl < $wl) { $maxl = $wl; }
    }
# 2. Sort words by word length DESC, record positions of each different length
    for ($i=$maxl; $i>0; $i--) {
#	@a = sort { $FL{$b} <=> $FL{$a} } split(/ \0 /, $SWL[$i]);
	@a = split(/ \0 /, $SWL[$i]);
	push(@SortWL, @a);
	$WLP[$i] = $WLP[$i+1] + @a; # Word Length Position for later use
    }
    undef %SWL; # no longer used
# Now we have @SortWL, @WLP 
#   For each keyword w, find those keywords contain w as substring
    my($t, %WStruct, %IsLined);
    foreach $w (@$rWL) {
	$wl =  $w =~ tr/ / / + 1; 
	for ($i=$WLP[$wl+1]-1; $i>=0; $i--) {
	    $t = $SortWL[$i];
# For single English word
#	    if &stem($w) is a substring of $x
	    if (!defined($IsLinked{$t}) && (index($t, &Stem::stem($w)) > -1)) {
#	    if (index($x, $w) > -1) {  # if $w is a substring of $x
		$WStruct{$w} .= "$t \0 "; 
		$IsLinked{$t} = 1;
	    }
	}
    }
    undef(@WLP); # no longer used
# Now we have @SortWL, %WStruct, %IsLined
#print "Sort by word length=@SortWL<br>\n";

# Output the result with HTML's <LI> tags
# Use: 
#   $check :  
# Set tmp:
#   $lnlt : current line limit
#   $lns  : current line number, base from 0
#   $clns : cumulative line number
#   $col : current column, base from 0
#   $mcol : max columns
# Set variables: 
#   $SBS : Sort By Structure
    my($SBS, $mcol, $lnlt, $clns, $lns, $col, $tn, $c, $ks, $d, %Stem, @C);
    $SBS = "<table border=1 width=100%><tr><td valign=top><OL start=1>\n";
    $mcol = 3;
    $lnlt = int(@$rWL / $mcol); $clns = $lns = $col = 0; $tn = 1;
    foreach $w (@$rWL) {
	if (not defined($IsLinked{$w})) { # if not linked
	    $tn++;
	    $c = $w; $c =~ s/ (\W)/\1/g;
	    if (defined($Stem{$c})) {
		$SBS .= "<LI>$c ($Stem{$c}):$rFL->{$w}\n";
	    } else {
		$SBS .= "<LI>$c : $rFL->{$w}\n";
	    }
	    @C = split(/ \0 /, $WStruct{$w});
	    undef($ks);
	    foreach $d (@C) { 
		$c = $d; $c =~ s/ (\W)/\1/g; 
		$ks .= "<LI>$c : $rFL->{$d}\n"; 
	    }
	    $SBS .= "<OL>$ks</OL>\n" if ($ks ne "");
	    $lns += 1 + @C;
	    if (($lns >= $lnlt) && ($col<($mcol-1))) {
		$col++; $clns += $lns; 
		$SBS .= "</OL><td valign=top><OL start=$tn>\n" if (@$rWL > $clns);
		$lnlt = int((@$rWL - $lns) / ($mcol-$col));
		$lns = 0; 
	    }
	}
    }
    $SBS .= "</OL></table>\n";
    return $SBS;
}
