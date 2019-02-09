#!/usr/bin/perl -s
# Convert DOS's text files into Mac's text files or vice versa

# perl -s dos2mac.pl -s=dos -t=mac InDir OutDir
if (@ARGV < 2) {
    print <<EndOfUsage;
Convert text files between DOS and Mac (Unix) by stripping off or adding back '\\r'.
Usage:
  perl dos2mac.pl -s=dos -t=mac [-NoSubDir] Source_Folder Target_Folder
or
  perl dos2mac.pl -s=mac -t=dos [-NoSubDir] Source_File Target_File
If -NoSubDir is specified, then files in sub-folders will not be processed.

EndOfUsage
    exit;
}

# Set global variables: $SrcEnc and $TgtEnc with default values
if ($s ne '') { $SrcEnc = $s; } else { $SrcEnc = 'dos'; }
if ($t ne '') { $TgtEnc = $t; } else { $TgtEnc = 'mac'; }
if ($SrcEnc eq 'dos') { $substitute = 's/\r//g'; } else { $substitute = 's/\n/\r\n/g'; }
print "Source folder: '$ARGV[0]'\nTarget folder: '$ARGV[1]'\n",
			"Converting $SrcEnc to $TgtEnc by '$substitute'...\n\n";
$NumFiles = 0;
&SrcDir2TgtDir(@ARGV);
print "$NumFiles files have been converted.\n";
exit();

sub SrcDir2TgtDir {
	my($SrcDir, $TgtDir) = @_; 
	my(@Files, $f, $infile, $outfile, @Path, $path);
	if (-d $SrcDir) { @Files = sort glob("$SrcDir/*"); }
	elsif (-f $SrcDir) { @Files = ($SrcDir); }
#print "Files (subfolders) in $SrcDir:\n", join(', ', @Files), "\n";
	for $f (@Files) {
		$outfile = $infile = $f;
		$outfile =~ s/\Q$SrcDir/$TgtDir/;
#print "\$infile=$infile\n\$outfile=$outfile\n";
		if (-d $infile) { 
			next if $NoSubDir;
			&SrcDir2TgtDir($infile, $outfile); 
		}
		if (not -f $infile) { next; }
		@Path = split /[\/\\]/, $outfile;
		$path = join('/', @Path[0..($#Path - 1)]);
		&CreateDir($path);
		next unless $f =~ /\.(txt|htm|html|pl|pm|py|php)$/;
		if ($^O =~ /MS/) { $infile =~ s|/|\\|g; $outfile =~ s|/|\\|g; }
		print "$infile ($SrcEnc)->($TgtEnc) $outfile\n";
		&Read_Convert_Write($infile, $outfile);
#		print "perl -p -e '$substitute' < \"$infile\" > \"$outfile\"";
#		system("perl -p -e '$substitute' < \"$infile\" > \"$outfile\"");
		$NumFiles++;
	}
}


sub Read_Convert_Write {
    my($infile, $outfile) = @_; my($all);
    open(INPUT,  "< :raw", $infile)
        or die "Can't open < '$infile' for reading: $!";
    open(OUTPUT, "> :raw",  $outfile)
        or die "Can't open > '$outfile' for writing: $!";
		local($/); undef $/; $all = <INPUT>; # get all content in one read
		if ($SrcEnc eq 'dos') {  
    	$all =~ s/\r//g;
    } else { 
    	$all =~ s/\n/\r\n/g;
    }
    print OUTPUT $all; 
    close(INPUT)  or die "can't close '$infile': $!";
    close(OUTPUT) or die "can't close '$outfile': $!";
}

sub CreateDir {
	my($OutDir) = @_; my(@Path, $path, $i);
	@Path = split /[\/\\]/, $OutDir;
	for($i=0; $i<@Path; $i++) {
		next if $Path[$i] eq '';
		$path = join('/', @Path[0..$i]);
		if (not -d $path) {
			print STDERR "Creating the folder:'$path'\n"; #, \$OutDir='$OutDir'\n\@Path='@Path'\n";
			mkdir($path, 0755) or die "Cannot mkdir: '$path', $!";
		}
	}
}
