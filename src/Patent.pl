#!/usr/bin/perl -s
# https://stackoverflow.com/questions/728597/how-can-my-perl-script-find-its-module-in-the-same-directory
use File::Basename;
use lib dirname (__FILE__);
    use SamOpt qw(SamOpt);  &SamOpt();
sub Usage {
    print <<HELP;
Synopsis:
    This program is to fetch UPSTO patent documents. Given a patent number
    or a query string, it fetches patents from USPTO website and then
    parse the patent into some fields that are more easy to handle.
    
    Note : You may need to run: 
    C:\>SET HTTP_proxy=http://proxy.edu.tw:3128/
    at DOS command line to download the desired patent.

Syntax:
  1. Given a patent number and a directory, fetch the patent and save in the
     directory.
   Syntax: perl -s $0 [-Odebug] -Ogroup=NSC -Odb -Opatnum OutDir patnum1 patnum2 ...
   options:
    -Ogroup=NSC : indicate to use the settings of the NSC group in Patent.ini
    -Odb : indicate to use the PatentDB.pm instead of Patent.pm.
    These two options can be used together with other options.

  2. Given a query and a directory, fetch all (at most 200) patents and save
     them in the specified directory.
   Syntax: perl -s $0 [-Odebug] -Ogroup=NSC -Oall directory query_string
   Ex : perl -s $0 -Oall tm_dir "text mining" 
   
  3. Given a query string (phrase), a page number, and a record number, 
     print out the patent indicated by the record number. This is an 
     imtermediate step of the above process.
   Syntax: perl -s $0 [-Odebug] -Ogroup=TM -Oget1 query_string page_number record_number
   Ex : perl -s $0 -Oget1 -Ogroup=TM "text mining" 2 2
   
  4. Given a patent file (in original HTML) and an output directory,
     parse the patent and save into the output directory
   Syntax: perl -s $0 [-Odebug] -Ogroup=NSC -Ofile outdir patent.htm

  5. Given a input directory and an output directory, extract only titles 
     and abstracts from the patents in the input directory and save the 
     the condensed patents in the output directory.
     This is to test if clustering by abstract is better than clustering
     by the whole document.
   Syntax: perl -s $0 [-Odebug] -Oti_ab InDir OutDir
   Ex: perl -s $0 -Oti_ab tm_dir tm_abs_dir
   
   
Author:
    Yuen-Hsien Tseng.  All rights reserved.
Date:
    2003/04/28, 2007/11/11, 2009/07/11, 2018/04/03
    
HELP
    exit;
}

    my $stime = time(); # 2009/07/21
    &Usage() if $help or $h;
    use Patent;
    use PatentDB;
    use SAMtool::Progress;
    $Ogroup = 'USPTO' if not defined $Ogroup;
  if (not $Odb){
    $uspto = Patent->new( { 'Patent_INI'=>'Patent.ini' }, 'USPTO', $Ogroup);
  } else {
    $uspto = PatentDB->new( { 'Patent_INI'=>'Patent.ini' }, 'USPTO', $Ogroup );
print STDERR "uspto->{DSN}=$uspto->{DSN}\n" if $Odebug;
#    print $uspto->Has_Patent_Existed(@ARGV);
  } 
#    $uspto->PrintAttributes(); # for debugging

  $uspto->{debug} = $Odebug if $Odebug;
  if (@ARGV > 0) {
# perl -s $0 -Ofile led 6359392.htm
    &GetByFile($uspto, @ARGV) if $Ofile;

# Test if the generic Set and Get method works.
#    print "MaxDocNum=", $uspto->Value('MaxDocNum'), 
#    ", DefaultGroup=", $uspto->Value('DefaultGroup'), "\n"; exit;

# D:\demo\lwp>perl -s Patent.pl -Oall  tm_dir "text mining"
    &GetWebPage($uspto, @ARGV) if $Oall;
# uspto.pl -Oget1 "text mining" 1 1 > tm-p1.txt
    print $uspto->GetPatentPage(@ARGV) if $Oget1;
# $0 -Oti_ab InDir OutDir
    &GetTitleAbs(@ARGV) if ($Oti_ab); 
    
# D:\demo\lwp>perl -s Patent.pl -Opatnum tmp 6211205 6359392
    &GetByPatNumber($uspto, @ARGV) if $Opatnum;
# perl -s Patent.pl -OPatNumList $ODir=MXIC_Pat MXIC\PatNumList.txt
    &GetByPatNumber_in_File($uspto, $ODir, @ARGV) if ($OPatNumList);
# perl -s Patent.pl -Odl $ODir=MXIC_Pat MXIC\PatNumList.txt
    &DownloadPatentByPatNumber($uspto, $ODir, @ARGV) if ($Odl);
# perl -s Patent.pl -Oref_pats Pat_list.txt > output.txt
# Patent.pl -Oref_pats D:\Sam\papers\2005\IACIS\data\doccatlist1.txt > nanoSciRefs.txt
# Patent.pl -Oref_pats NSC\NSC_PatentNo.txt > NSC\NSC_SciRefs.txt
    &GetRef_from_Patents($uspto, @ARGV) if $Oref_pats;
# Patent.pl -Ogroup=Nano -Odb -OPat2DB D:\Sam\papers\2005\IACIS\data\doccatlist1.txt
# Patent.pl -Ogroup=NSC -Odb -OPat2DB NSC\NSC_PatentNo.txt
    &GetPatent2DB($uspto, @ARGV) if $OPat2DB;
# Patent.pl -Ogroup=Gov -Odb -ODir2DB Gov\PatentDir
    &InsertPatentFromDir2DB($uspto, @ARGV) if $ODir2DB;

# 2019/01/10:
# Patent.pl -ODir2WoS ..\Source_Data\DL_DNN\patents > ..\Source_Data\DL_DNN\data\WoS.txt
    &Dir2WoSFormat($uspto, @ARGV) if $ODir2WoS;

  } else { # below work in CGI environment
    print "Content-type: text/html\n\n" if @ARGV == 0; # to browser
    require "../../lwp/sam.lib/parseCGI2.pl" || print "require error!<br>\n"; 
    &CGIParseInit();
    &GetInput(); # Set and other global variables
    if ($PatNum ne '') {
    	use SegWordPat;
    	$seg=SegWordPat->new({'WordDir'=>'SAM/word', 'MaxRT'=>0, 'UseDic'=>0});
    	&PatAbs($uspto, 'tmp', $PatNum, $MaxAbsSen, $OPatApp);
    }
  }
    print STDERR "It takes ", time()-$stime, " seconds.\n"; # 2009/07/21
    exit;

sub GetInput {
    my($Root); # not used here
    &parse_form_data($Root, *F);
    ($PatNum, $MaxAbsSen, $OPatApp) = 
	@F{'PatNum', 'MaxAbsSen', 'OPatApp'};
    $PatNum    =~ s/^\s+|\s+$//g;
    $MaxAbsSen =~ s/^\s+|\s+$//g;
    
    if ($PatNum eq "") {  
	&ParseCGI::return_error(400, "Patent Number should not be empty");
    }
} # End of &GetInput();


sub MakeDir() {
    my($outdir) = @_;
    if (not -d $outdir) {
    	mkdir $outdir, 0755 or print "Cannot mkdir:'$outdir'" and die;
    }
    if (not -d "$outdir/pat") {
    	mkdir ("$outdir/pat", 0755) if not -d "$outdir/pat";
    }
    if (not -d "$outdir/abs") {
    	mkdir ("$outdir/abs", 0755) if not -d "$outdir/abs";
    }
}

# Given a query string and an output directory,
#   download the searched patent into the output directory
sub GetWebPage {
    my($me, $outdir, $query) = @_;
    &MakeDir($outdir);
    my($NumReturn, $i, $file, $rPatent);
    $NumReturn = $me->SearchPatent($query);
    if ($NumReturn == 0) { 
    	print STDERR "Query: '$query' not found, or connection fails!"; 
    	return; 
    }
    print "There are $NumReturn documents ...\n";
    for($i=1; $i<=$NumReturn and $i<=$me->Value('MaxDocNum'); $i++) {
    	print STDERR "$i,";
    	$rPatent = $me->GetPatentPage($query, (1+$i/50), $i);
    	$me->WriteOut($rPatent, "$outdir/pat/$rPatent->{PatNum}\.htm");
    }
}


# perl -s Patent.pl -Odl -ODir=MXIC_Pat d:\data\MXIC\train-patlist.txt
sub DownloadPatentByPatNumber {
    my($me, $outdir, $file) = @_;  
    my($i, $patnum, $pat_url, $outfile, $orgPatent);
    @ARGV = ($file);
    print "Begin to fetch patents ...";
    while (<>) { 
    	chomp; next if /^\s*$/; 
    	$i++; print "$i,$_  ";
    	$patnum = $_;
    	$patnum =~ s/,//g; # delete ',' between digits
    	$pat_url = $me->{PatentNo_URL};
    	$pat_url =~ s/\$patnum/$patnum/g;
    	$orgPatent = $me->ua_get($pat_url);
    	$outfile = $outdir . "/$patnum\.htm";
    	open F, ">$outfile" or die "cannot write to file:'$outfile'";
    	print F $orgPatent; close(F);
    }
    print " ... End.\n";
}

# perl -s Patent.pl -OPatNumList -ODir=MXIC_Pat d:\data\MXIC\train-patlist.txt
sub GetByPatNumber_in_File {
    my($me, $outdir, $file) = @_;  my($i);
    @ARGV = ($file);
    print "Begin to fetch patents ...";
    while (<>) { 
    	chomp; next if /^\s*$/; 
    	$i++; print "$i,$_  ";
    	&GetByPatNumber($uspto, $outdir, $_); 
    }
    print " ... End.\n";
}

# Given a patent number and an output directory, download the patent full text in html 
#   into PatentDir and parse the patent into into the subfolders: 
#      pat and abs of the output directory.
# Use option $OPatApp
# perl -s Patent.pl -Opatnum OutDir 6,778,995  6532469 ...
# or use the option -OPatApp
# perl -s Patent.pl -Opatnum -OPatApp OutDir 20040163035 20040059736 ...
sub GetByPatNumber {
    my($me, $outdir, @PatNum) = @_; my($pat_url, $rPatent, $patnum);
    &MakeDir($outdir);
#    $pat_url = "http://patft.uspto.gov/netacgi/nph-Parser?Sect1=PTO1&" .
#        "Sect2=HITOFF&d=PALL&p=1&u=/netahtml/srchnum.htm&r=1&f=G&l=50&s1=" .
#        "$patnum.WKU.&OS=PN/$patnum&RS=PN/$patnum";
    foreach $patnum (@PatNum) {
    	$patnum =~ s/,//g; # delete ',' between digits
    	$pat_url = $me->{PatentNo_URL};
    	$pat_url = $me->{PatentAppNo_URL} if $OPatApp;
    	$pat_url =~ s/\$patnum/$patnum/g;
    	$rPatent = $me->Get_Patent_By_Number($patnum, $pat_url);
#foreach $k (keys %$rPatent) { print "$k, "; } print "\n";
    	$me->WriteOut($rPatent, "$outdir/pat/$rPatent->{PatNum}\.htm");
    	$rPatentAbs = $me->GetPatentAbstract( $rPatent );
    	$me->WritePatentAbs($rPatent, $rPatentAbs, 
    	   "$outdir/abs/$rPatent->{PatNum}" . '-abs.htm');
    }
}


# Given a patent file (in original HTML) and an output directory,
#   parse the patent and save into the output directory
# perl -s $0 -Ofile led 6359392.htm
sub GetByFile {
    my($me, $outdir, $file) = @_; my($pat_url, $rPatent, $patnum);
    &MakeDir($outdir);
    open F, $file or die "Cannot read file:'$file'";
    undef($/); $r = <F>; close(F); $/ = "\n";
    $rPatent = $me->Parse_Patent($r);
    $me->WriteOut($rPatent, "$outdir/pat/$rPatent->{PatNum}\.htm");
    $rPatentAbs = $me->GetPatentAbstract( $rPatent );
    $me->WritePatentAbs($rPatent, $rPatentAbs, 
    	"$outdir/abs/$rPatent->{PatNum}" . '-abs.htm');
}


# Given a query string (phrase) and a page number,
#	get the search result page indicated by the page number
# print &GetNextSearchResult($query, 1);
# Currently this method is not used, since USPTO needs no 'turn to the next page'
sub GetNextSearchResult { # use $USPTO_SURL
    my($query, $page) = @_;
#   The next page of datamining594-2.txt is from
    my $next_page = $USPTO_SURL .
    	"p=$page&r=0&f=S&l=50&co1=AND&d=ptxt&" .
    	"s1=\"$query\"&OS=\"$query\"&RS=\"$query\"&Page=Next";
#print "$next_page\n"; exit;
    return get($next_page);
}


# perl -s $0 -Oti_ab InDir OutDir
sub GetTitleAbs {
    my($InDir, $OutDir) = @_;
    if (not -d $OutDir) {
    	mkdir $OutDir, 0755 or die "Cannot mkdir:'$OutDir'";
    }
    @Files = glob("$InDir/*.*");
    foreach $f (@Files) {
    	open F, $f; $/ = "\n\n\n\n\n"; $in=<F>; $in2=<F>; close(F); $/ = "\n";
    	if ($in2 =~ /^\s*Abstract/) { $in .= $in2; }
    	$ff = $f; $ff =~ s/$InDir/$OutDir/;
    	open FF, ">$ff"; print FF $in; close(FF);
print "$ff, ", length($in), "\n";
    }
}

# Given a file containing a list of patent numbers,
#   extracts the "other references" from each patent
#   and then print out to the standard output.
# By gethering all "other references", we can derive some rules manually
#   to parse the citations in the "other references"
# Patent.pl -Oref_pats D:\Sam\papers\2005\IACIS\data\doccatlist1.txt > nanoSciRefs.txt
# Patent.pl -Oref_pats NSC\NSC_PatentNo.txt > NSC\NSC_SciRefs.txt
sub GetRef_from_Patents {
    my($me, $file) = @_; my(%PatNum, @PatNum, $pn);
    @ARGV = ($file);
    while (<>) {
    	chomp; next if /^\s*$/; # skip if empty line
    	if (/^\s*(\d+)\s*/)  # get the patent number in the first field
    	{ $PatNum{$1} = 1; }
    }
    @PatNum = sort keys %PatNum; # to remove duplicate patent numbers
print STDERR scalar @PatNum, " patents in total\n";
    my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'} );
    my $i = 0; my $percent = 0;
    foreach $pn (@PatNum) {
    	&GetRefs($me, $i, $pn);
    	$i++; $percent = $pro->ShowProgress($i/@PatNum, $percent);
#    	last if $i > 2;
    }
    $percent = $pro->ShowProgress($i/@PatNum, $percent);
}

sub GetRefs {
    my($me, $i, $patnum) = @_;
    my $pat_url = $me->{PatentNo_URL};
    $pat_url = $me->{PatentAppNo_URL} if $OPatApp;
    $pat_url =~ s/\$patnum/$patnum/g;
    my $rPatent = $me->Get_Patent_By_Number($patnum, $pat_url);
    my ($rUSRefs, $rForRefs, $rSciRefs) = $me->GetOtherReference($rPatent);
    return if @$rSciRefs == 0;
# output format: "$patnum\tcitation1\n$patnum\tcitation2\n...";
#    print join("\n", map{"$i\t$patnum\t$_"}@$rSciRefs), "\n";
    print join("\n", map{"$patnum\t$_"}@$rSciRefs), "\n";
}


# Given a file containing a list of patent numbers,
#   download the patents into Patent_DB.mdb
# Patent.pl -Ogroup=Nano -Odb -OPat2DB D:\Sam\papers\2005\IACIS\data\doccatlist1.txt
# Patent.pl -Ogroup=NSC -Odb -OPat2DB NSC\NSC_PatentNo.txt
sub GetPatent2DB {
    my($me, $file) = @_; my(%PatNum, @PatNum, $pn, $pat_url, $rPatent);
    @ARGV = ($file);
    while (<>) {
    	chomp; next if /^\s*$/; # skip if empty line
    	next if /^#/; # skip if a comment line
    	if (/^\s*(\d+)\s*/)  # get the patent number in the first field
    	{ $PatNum{$1} = 1; }
    }
    @PatNum = sort keys %PatNum; # to remove duplicate patent numbers
print STDERR scalar @PatNum, " patents in total\n";
    my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'} );
    my $i = 0; my $percent = 0;
    foreach $pn (@PatNum) {
    	$pat_url = $me->{PatentNo_URL};
    	$pat_url = $me->{PatentAppNo_URL} if $OPatApp;
    	$pat_url =~ s/\$patnum/$pn/g;
    	$rPatent = $me->Get_Patent_By_Number($pn, $pat_url);
    	$i++; $percent = $pro->ShowProgress($i/@PatNum, $percent);
#    	last if $i > 2;
    }
    $percent = $pro->ShowProgress($i/@PatNum, $percent);
}


# Given a file containing a list of patent numbers and a directory 
#   containing the downloaded patents,
#   insert the patents into Patent_DB.mdb
# Patent.pl -Ogroup=Gov -Odb -ODir2DB Gov\PatentDir
sub InsertPatentFromDir2DB {
    my($me, $dir) = @_; my(@Files, $orgPatent, $rPatent, $file);
    @Files = sort glob("$dir/*.htm");
print STDERR scalar @Files, " patents in total\n";
    my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'} );
    my $i = 0; my $percent = 0;
    foreach $file (@Files) {
        $i++; $percent = $pro->ShowProgress($i/@Files, $percent);
#       last if $i > 2;
        local($/); undef $/; # to get file content in one read
        open F, $file or die "Cannot read file:'$file', $!";
        $orgPatent = <F>; close(F);
        if (length($orgPatent) < 1000) {
            $me->ReportError(
            "Fail to get patent ('$file')\n" .
            "The fetched page is :\n<HR>'$orgPatent'<HR>\n");
        }
        $rPatent = $me->Parse_Patent( $orgPatent );
        if (keys%$rPatent<5) {# parsed patent does not yield correct structure
            $me->ReportError("Fail to get patent ('$file')," .
            "may be due to parse error (patent page may have changed)");
        }
        $me->SavePatent($rPatent, $orgPatent);
    }
    $percent = $pro->ShowProgress($i/@Files, $percent);
}


# On 2019/01/09 written by Yuen-Hsien Tseng
use File::Find;

=head2 $pat->Dir2WoSFormat(); 
  Gvein a database, convert the patent information into the format of 
  Web of Science
=cut
sub Dir2WoSFormat {
    my($me, $dir) = @_; my(@Files, $orgPatent, $rPatent, $file);
    # list all *.htm patent files in @Files
# See: https://stackoverflow.com/questions/9600395/how-to-traverse-all-the-files-in-a-directory-if-it-has-subdirectories-i-want-t
# See : http://perldoc.perl.org/File/Find.html
    find(sub { if (-f and /\.html?$/) { push @Files, $File::Find::name;} }, $dir);
print STDERR scalar @Files, " patents in total\n"; 
    my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'} );
    my $i = 0; my $percent = 0;
    print "FN ISI Export Format\nVR 1.0\n";
    foreach $file (@Files) {
        $i++; $percent = $pro->ShowProgress($i/@Files, $percent);
#last if $i >= 5;
        local($/); undef $/; # to get file content in one read
        open F, $file or die "Cannot read file:'$file', $!";
        $orgPatent = <F>; close(F);
        if (length($orgPatent) < 1000) {
            $me->ReportError(
            "Fail to get patent ('$file')\n" .
            "The fetched page is :\n<HR>'$orgPatent'<HR>\n");
        }
        $rPatent = $me->Parse_Patent( $orgPatent );
        if (keys%$rPatent<5) {# parsed patent does not yield correct structure
            $me->ReportError("Fail to get patent ('$file')," .
            "may be due to parse error (patent page may have changed)");
        }
        &Patent2WoSFormat($me, $rPatent); next;

        # next lines are just for debugging
        @t = sort keys %$rPatent; print(join(", ", @t), "<hr>\n");
        for $k (sort keys %$rPatent) {
        	next if $k =~ /Claims|Description|Drawings|Features|Task/;
        	print "$k: $rPatent->{$k}\n<hr>\n";
        	print "$k: @{$rPatent->{$k}}\n<hr>\n" if $k eq 'Cites';
        }
        exit();

    }
    $percent = $pro->ShowProgress($i/@Files, $percent);
}


sub Patent2WoSFormat {
	my($me, $rPatent) = @_;
	my %PF2WF = ('Assignee'=>'AU', 'Inventors'=>'AF', 'Title'=>'TI',
'IssuedDate'=>'PY', 'Current CPC Class'=>'SC', 'Intern Class'=>'SO',
'DE'=>'DE', 'ID'=>'ID', 'Abstract'=>'AB', 'C1'=>'C1',
'Cites'=>'CR', 'NR'=>'NR', 'TC'=>'TC', 'J9'=>'J9', 'VL'=>'VL', 'BP'=>'BP',
'PatNum'=>'UT');
  my %WF2PF = reverse %PF2WF;
	my @WF = qw(AU AF TI SO DE ID AB C1 CR NR TC J9 PY VL BP SC UT);
	print "PT J\n";
	my($w, $k, $v, $NR, $Owner);
	for $w (@WF) {
		$k = $WF2PF{$w};
		#print $k, ": ", $rPatent->{$k}, "\n";
		$v = $rPatent->{$k};
		if ($w eq 'AU') {
			$Owner = $v;
			$v =~ s/\)[^\n]/\)\n   /g;
			$v =~ s/\s*\([^)]+\)//mg; # remove content in the parentheses
		} elsif ($w eq 'AF') {
			$v =~ s/\),/\)\n  /g;
			$v =~ s/;/,/mg;
			$v =~ s/\s*\([^)]+\)//mg; # remove content in the parentheses
		} elsif ($w eq 'AB') { $v = '';
		} elsif ($w eq 'C1') {
			my $CSC = &ParseOwner($me, $Owner, $rPatent);
			$v = join("\n   ", @$CSC);
		} elsif ($w eq 'PY') {
			$v =~ s/^(\d\d\d\d).+/$1/;
		} elsif ($w =~ 'SO|SC'){
			$v =~ s/&nbsp//g;
		} elsif($w eq 'CR'){
			$v = &ParseCitations($me, $rPatent);
			$v = join("\n   ", @$v); # here $v is ref to an array
			$NR = @$v;
		} elsif ($w eq 'NR') {
			$v = $NR;
		} elsif ($w =~ /TC|VL|BP/) { 
			$v = 0; 
		}
		print "$w $v\n";
	}
	print "ER\n\n"
}

# The next codes are copied from &SaveOwner_Inv_Ass() in PatentDB.pm on 2019/01/13
sub ParseOwner {
	my($me, $Owner, $rPatent) = @_;
	my(@Owner, $p, $City, $State, $country, @CSC);
	# The format for $Owner are:
# Inventors: Smeltzer; Ronald K. (Dallas, TX), Bean; Kenneth E. (Richardson, TX)
# Assignee: Texas Instruments Incorporated (Dallas, TX)
# Assignee: Xometry, Inc. (Gaithersburg, MD)
#   @Owner = split /\)/, $Owner; # split by right parenthesis
    @Owner = split /\)[,\s]*/, $Owner; # 2007/11/10
    return \@CSC if @Owner == 0;
# ex: $Owner='Huang; Smile (Tainan, TW); Chen; Chia-Hsing (Hsinchu, TW)'
    foreach $p (@Owner) {
    	$City = $State = $country = ''; # 2007/11/10
#print STDERR "$rPatent->{PatentNum}, p=$p\n";
    	if ($p =~ /;?\s?(.+) \((.+), (.+)$/) { 
	    	$Owner = $1; $City = $2; $country = $3;
    	} elsif ($p =~ /;?\s?(.+) \((.+)$/) { # 不是美國
	    	$Owner = $1; $country = $2; $City = 'Null';
    	} else { next; } # do nothing if no match
    	$Owner =~ s/;/,/; # convert ';' into ',' between surname and name
    	$Owner =~ s/, / /; # 2019/01/13 # remove the ,
    	if ($rPatent->{$OwnerName.'_org'} =~ /<B>$country/i) { # 不是美國的州名
    	    # do nothing
    	} else { # 可能是美國的州名, 
    	    if ($me->{'US_StateName'}{$country}){$State=$country;$country='US';}
    	}
    	push @CSC, join(", ", $Owner, $State, $City, $country)
    }
	return \@CSC;
}

# The next codes are copied from &GetOtherReference() in Patent.pm 
#   and from &SaveCitePatent() and &SaveCitePaper() in PatentDB.pm on 2019/01/13
sub ParseCitations {
	my($me, $rPatent) = @_; my(@V);
	my($rUSRefs, $rForRefs, $rSciRefs) = $me->GetOtherReference($rPatent);
    my($cite, $country, $CountryNo, $CitePN, $Year, $Owner, $Class);
# "U.S. Patent Documents"
    foreach $cite (@$rUSRefs) {
    	next if $cite eq '';
		($CitePN, $Year, $Owner, $Class) = $me->ParsePatRef( $cite );
		$Year =~ s/^(\d\d\d\d).+/$1/;
		push @V, join(", ", $Owner, $Year, $CitePN);
#print "'$CitePN', Year='$Year', Owner='$Owner', class='$Class'\n";
    }
# "Foreign Patent Documents"
    foreach $cite (@$rForRefs) {
    	next if $cite eq '';
		($CitePN, $Year, $country, $Class) = $me->ParsePatRef( $cite );
		$Year =~ s/^(\d\d\d\d).+/$1/;
		push @V, join(", ", $country, $Year, $CitePN);
#print "'$CitePN', Year='$Year', country='$country', class='$Class'\n";
    }
# "Other References"
    my($Type, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    foreach $cite (@$rSciRefs) {
    	next if $cite eq '';
		($Type, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle)
    	  = @{ $me->ParseSciRef( $cite ) }; # de-reference into an array
		$Year =~ s/^(\d\d\d\d).+/$1/;
        push @V, join(", ", $Author, $Year, $JouTitle, $Vol, $StartPage);
#print "T=$Type, Y=$Year, V=$Vol, S=$StartPage, A=$Author, Ti=$PubTitle, J=$JouTitle\n";
    }
	return \@V;
}


# -------  Next functions are for CGI enviroments ---------------
# Given a patent number and an output directory,
#   download the patent into the output directory
sub PatAbs {
    my($me, $outdir, $patnum, $MaxAbsSen, $OPatApp) = @_; 
# The use of this fucntion is tricky, $me refer to Patent.pm of PatentDB.pm.
    my($pat_url, $rPatent, $rPatentAbs, $f);
    &MakeDir($outdir);
    $me->Value('MaxAbsSen', $MaxAbsSen); # Set MaxAbsSen to a new value
    $patnum =~ s/,//g; # delete ',' between digits
    $pat_url = $me->{PatentNo_URL};
    $pat_url = $me->{PatentAppNo_URL} if $OPatApp;
    $pat_url =~ s/\$patnum/$patnum/g;
print "Before Get_Patent_By_Number(): $PatNum, me=$me<br>\n";
    $rPatent = $me->Get_Patent_By_Number($patnum, $pat_url);
print "After Get_Patent_By_Number(): $PatNum<br>\n";
#foreach $k (keys %$rPatent) { print "$k, "; } print "\n";
print "Before WriteOut(): outdir=$outdir<br>\n";
    $me->WriteOut($rPatent, "$outdir/pat/$rPatent->{PatNum}\.htm");
print "After WriteOut(): and before GetPatentAbstract()<br>\n";
    $rPatentAbs = $me->GetPatentAbstract( $rPatent );
print "After GetPatentAbstract(): $PatNum<br>\n";
#	$me->WritePatentAbs($rPatent, $rPatentAbs, 
#    	   "$outdir/abs/$rPatent->{PatNum}" . '-abs.htm');
    print "<HTML><head><title>$rPatent->{Title}</title></head><body>\n";
    print "<center><h3>$rPatent->{PatNum} : $rPatent->{Title}</h3>\n";

    $URL = "/demo/STPIWG/src/$outdir/pat/$rPatent->{PatNum}\.htm";
    print "<b><a href='$URL'>The original patent</a>, ";
    $URL = "/demo/STPIWG/src/$outdir/abs/$rPatent->{PatNum}\.htm";
    print "<a href='$URL'>The parsed patent</a></b></center>\n";
#	$URL = "/demo/lwp/$outdir/abs/$rPatent->{PatNum}-abs\.htm";
#	print "<p><a href='$URL'>The patent abstract</a>\n";

#print "<p>Patent_Abs_Fields=@{$me->{Patent_Abs_Fields}}<p>\n";

    my($i, $n, $c, $cn, $h1, $h2);
    $me->ParseClaims( $rPatent->{'Claims'} );
    $n = $me->GetValue('Claims_NumItems');
    $cn = $me->GetValue('Claims_NumLeads');
    print "\n<HR><h3>There are $n claims and $cn of them are leading claims</h3>\n";

    $me->GetPatentTOC( $rPatent->{'Description'} );
    $n = $me->GetValue('PatentTOC_NumSections');
    print "\n<HR><h3>There are $n Sections</h3>\n";
    for($i=0; $i<$n; $i++) {
    	print "<h4>".$me->GetValue('PatentTOC_Title', $i)."</h4>";
#    	print $me->GetValue('PatentTOC', $i)."\n";
    }

#    foreach $f (@{$me->{Patent_Abs_Fields}}) {
    foreach $f ("Topics") {
    	print "\n<HR>\n<h3>$f (" . $rPatent->{ $f."_SecTitle"} . ")</h3>\n";
    	print $rPatentAbs->{$f};
    }

    print "<HR><center><h1>Abstracts in Context</h1></center>\n";
    foreach $f (@{$me->{Patent_Abs_Fields}}) {
    	print "\n<HR>\n<h3>$f (" . $rPatent->{ $f."_SecTitle"} . ")</h3>\n";
    	&HighLightAbs($f, $rPatent, $rPatentAbs);
    }

    print "\n<HR><h3>Claims:$n, leading claims:$cn</h3>\n";
    for($c=$i=0; $i<$n; $i++) {
    	if (($i+1) == $me->GetValue('Claims_Leads', $c)) {
	# test if $i-th item is a leading claim
    	    $h1 = "<font color=red>"; $c ++;
    	} else { $h1 = ''; }
    	$h2 = $h1 ? '</font>':'';
    	print $h1 . $me->GetValue('Claims_Items', $i) . $h2 . "<p>\n";
    }
    print "</body></html>\n";
}

sub HighLightAbs {
    my($field, $rPatent, $rPatentAbs) = @_;
    my($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, $rLinkValue, 
    $rSenList, $para, @Para, $Abs, @Abs, $i, $j, $match, $w, @W, $t,
    %KeyTerm, @KeyTerm);
    @Para = split /<BR><BR>/, $rPatent->{$field};
    @Abs = split /<BR><BR>/, $rPatentAbs->{ $field };
#print "<hr>Abs=@Abs<hr>\n";
    %KeyTerm = split /\t/, $rPatentAbs->{ "$field\tKeyTerm" };    @KeyTerm=keys%KeyTerm;
#    @KeyTerm = split /; /, $rPatentAbs->{ "Topics" }; # 2004/11/19
    @KeyTerm = sort{split(' ',$b) <=> split(' ',$a)}@KeyTerm; 
    foreach $i (@KeyTerm) { $KeyTerm{$i} = 2; }
#@W = sort {$KeyTerm{$b} <=> $KeyTerm{$a}} keys %KeyTerm;
#print "<p>KeyTerm: ", join(', ', map "$_:$KeyTerm{$_}", @W), "<p>\n";
#print "<p>Sentence Rank: $rPatentAbs->{ \"$field\tSenRank\" };<p>\n";
#print "<p>Sentence Wgt: $rPatentAbs->{ \"$field\tSenWgt\" };<p>\n";
    return 0 if @Abs == 0;
    $Abs = 0; # record the next matched abstract sentence
    foreach $para (@Para) {
    	($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, 
    	$rLinkValue, $rSenList) = $seg->ExtractKeyPhrase( $para ); 
    	foreach $sen (@$rSenList) { # delete leading paragraph number
    	    $sen =~ s/<pa=\-?\d+>//;
    	}
    
    	foreach $t (@$rWL) { 
    	    @W = split ' ', $t;
    	    foreach $w (@W) { $rFL->{$w} = ($rFL->{$w})?$rFL->{$w}:1; }
    	}
#print "<p>keywords: ", join(', ', map "$_:$rFL->{$_}", @$rWL), "<p>\n";
    	for ($i=0; $i<@$rSenList; $i++) {
    		$match = 0;
    		for($j=$Abs; $j<@Abs; $j++) {
#print "<hr width=80%>Abs[$j]=$Abs[$j]<p>\nSenList[$i]=$rSenList->[$i]<hr>\n";
	  			if ($Abs[$j] eq $rSenList->[$i]) {
	  				$match = 1; last;
    			}
	    	}
	    	if ($match) {
    			$Abs = $j+1; # record the next matched abstract sentence
    			print "<font color=red>";
	    	}
#	    	@W = map($KeyTerm{$_}>1?"<B>$_</B>":$_, split ' ', $rSenList->[$i]);
#	    	print "@W ";
	    	foreach $j (@KeyTerm) { $rSenList->[$i]=~s|\b($j)\b|<b>$1</b>|i; }
	    	print $rSenList->[$i], " ";
	    	print "</font> " if $match;
    	}
    	print "<BR><BR>\n";
    }
}
