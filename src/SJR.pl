#!/usr/bin/perl -s
# On 2012/07/12 written by Sam Tseng for the paper:
#	A Scientometric Analysis of the Effectiveness of Taiwan's Educational Research Projects
# This program is to fetech the country ranking in the Education field from 
# http://www.scimagojr.com/countryrank.php
# where the parameter after the above URL are:
#  ?area=3300&category=3304&region=all&year=2010&order=it&min=0&min_type=it
# Note: on 2013/07/29, there are 573 journals in the Education field in the SCImago journal ranking website.

	use vars; use strict;
	use LWP;
	my $dir ; $dir = $main::Odir . '/' if $main::Odir;
	
# On 2013/07/29, replace 2010 with 2011 in SJR.pl and run:
#~/Documents/papers/2012/Edu_Clustering/SJR$ mkdir 201307
#~/Documents/papers/2012/Edu_Clustering/SJR$ perl -s SJR.pl -Ofetch -Odir=201307
	&GetSRJ() if $main::Ofetch; # may use additional option Odir=201307
=head2
 perl -s SJR.pl -Oreport -Odir=201307 40 2 > 201307/Documents.txt
 perl -s SJR.pl -Oreport -Odir=201307 40 4 > 201307/Citations.txt
 perl -s SJR.pl -Oreport -Odir=201307 40 5 > 201307/Self_cite.txt
 perl -s SJR.pl -Oreport -Odir=201307 40 6 > 201307/CitePerDoc.txt
 perl -s SJR.pl -Oreport -Odir=201307 40 7 > 201307/H_index.txt
=cut
	&Generate_Report(@ARGV) if $main::Oreport;
# After running the above commands, import/copy the above txt files to Excel: SJR_Edu_1996-2011.xlsx
# Edit every 5-year	results and then copy them to C1_PY_5.txt and C1_PY_TC_5.txt.
# Then run: (on 2013/07/29)
# C:\CATAR_src\src>perl -s ISI.pl -OPYCPP 201307\C1_PY_5.txt 201307\C1_PY_TC_5.txt > 201307\C1_PY_CPP_5.txt
	
sub GetSRJ {
	my($URL, $URL_Template, $year, $ua, $page, $rTable);
	$URL_Template = 'http://www.scimagojr.com/countryrank.php?area=3300&category=3304&region=all&year=$Year&order=it&min=0&min_type=it';
	$ua = &InitUserAgent();
	for $year (1996..2011) {
		warn "Fetching data from year $year ...\n";
		$URL = $URL_Template;
		$URL =~ s/\$Year/$year/;
		$page = &Fetch_Web_Page($ua, $URL);
		$rTable = &Parse_Web_Page($page);
		&Save_Table($rTable, $year);
	}
}


# Now make the search
sub Fetch_Web_Page {
	my($ua, $URL) = @_; my($response, $content, $c);
	$response = $ua->get($URL);
	if (not $response->is_success) { 
		warn "User Agent get() error!\t$URL";
	}
	$content = $response->content;
#	$c = encode("big5", decode("utf8", $content)); # This work!!!
	return $content;
}

=head2 InitUserAgent() : Initialize User Agent.

  $flag = $oUR->InitUA( $timeout, $agent );

  return a ref pointing to the UA object

=cut
sub InitUserAgent {
    my($me, $timeout, $agent) = @_;
    $timeout = 10 if not defined $timeout;
    $agent = 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.11) Gecko/20050728' if not defined $agent;
    my $ua = LWP::UserAgent->new;
    $ua->timeout($timeout);
    $ua->env_proxy;
    $ua->agent($agent);
    return $ua;
}

sub Parse_Web_Page {
	my($page) = @_; my($head, $row, @Rows, $col, @Cols, $data, $i, $j, $rTable);
# The table is after '<table class="tabla_datos">'
# The field names are in the <thead><tr><th>Field Name</th>
# The table data is in the <tbody><tr><td>data</td>
	($head, $page) = split /<table class="tabla_datos">/, $page;
	@Rows = split /<\/tr>/, $page;
	pop @Rows; # remove last row because it is not the data row
	$i = -1;
	foreach $row (@Rows) {
		$i++; $j = -1;
		@Cols = split /<\/t[dh]>/, $row;
		foreach $col (@Cols) {
			$col =~ s/<[^>]+>//g;
			$col =~ s/^\s+|\s+$//g; # delete leading and trailing white spaces
			$col =~ s/.+>//; # delete left-over unwanted string
#			print "$col\t";
			next if $col eq '' and $j==0;
			if ($col =~ /\d+\.\d+/) { $col =~ s/\.//g; } # delete '.' like '1.124'
			if ($col =~ /\d+\,\d+/) { $col =~ s/,/\./; } # replace ',' with '.' like '0,46'
			$rTable->[$i][++$j] = $col;
		}
#		print "\n";
	}
	return $rTable;
}

sub Save_Table {
	my($rTable, $year) = @_; my($file, $i, $j);
	$file = $dir . "$year\.txt";
	open F, ">$file" or die "Cannot write to file: '$file'";
	for ($i=0; $i<@$rTable; $i++) {
		for ($j=0; $j<@{$rTable->[$i]}; $j++) {
			print F $rTable->[$i][$j], "\t";
		}
		print F "\n";
	}
	close(F);
}


sub Generate_Report {
	my($n, $field) = @_; # $n = 12 is suitable
	# $n: number of top n countries in 2010 from which we like to generate report
	# $field: which field to generate report, e.g. H index ($field=7), Citations ($field=4)
# "	Country	Documents	Citable documents	Citations	Self-Citations	Citations per Document	H index"
# read the top $n countries from 2010.txt
	my($file, $i, $line, $country, @Country, %Country, $rTable, $idx, $year);
	$rTable = &Read_Table($dir .  '2011.txt');
	for ($i=1; $i<=$n; $i++) {
		push @Country, $rTable->[$i][1]; # index of Country is 1
	}
#print STDERR join ", ", @Country, "\n";
	foreach $i (@Country) { $Country{$i} = 1; } # set %Country for fast look up
# Now we have @Country and %Country to generate report for these countries
	print "\t", join("\t", @Country), "\n"; # field names in report
	for $year (1996..2011) { # rows in report
		$rTable = &Read_Table($dir . $year . '.txt');
		print $year ;
		foreach $country (@Country) { # columns in report
			$idx = &Find_Index($rTable, $country);
			# Now the data is at $rTable->[$idx][$field]
			print "\t", $rTable->[$idx][$field];
		}
		print "\n";
	}
}

sub Read_Table {
	my($file) = @_; my($i, $j, @Fields, $rTable);
	open F, $file or die "Cannot read file from: '$file'";
	$i = -1;
	while (<F>) {
		@Fields = split /\t/, $_;
		$i++;
		for ($j=0; $j<@Fields; $j++) {
			last if $Fields[$j] =~ /^\s*\n/; # skip if last empty field 
			$rTable->[$i][$j] = $Fields[$j];
		}
	}
	close(F);
	return $rTable;
}

sub Find_Index {
	my($rTable, $country) = @_;
	my $idx = -1; # if not found
	for(my $i=0; $i<@$rTable; $i++) {
		if ($rTable->[$i][1] eq $country) { $idx = $i; last; }
	}
	return $idx;
}