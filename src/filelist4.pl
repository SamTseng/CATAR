#!/usr/bin/perl -s
# https://stackoverflow.com/questions/728597/how-can-my-perl-script-find-its-module-in-the-same-directory
use File::Basename;
use lib dirname (__FILE__);
	use SamOpt qw(SamOpt);  &SamOpt();
#=======================================================================
#   This information retrieval  system is developed by Yuen-Hsien Tseng
#   (Email:tseng@blue.lins.fju.edu.tw) on July, 1997.
#   This filelist program is developed on Dec. 20, 1997
#   All rights reserved!
#=======================================================================

sub usage() {
	print <<Usemsg;

Usage: 
(1) $0 [-h]
(2) $0 [-KeepDrive] filelist dir1 dir2 dir3 ... 
(4) $0 [-KeepDrive] -html filelist dir1 dir2 dir3 ...
(5) $0 [-KeepDrive] -pub_html="public_html" filelist dir1 dir2 dir3 ...
(6) $0 [-KeepDrive] [-Old=OldFileList] filelist dir1 dir2 dir3 ...
  $0 -h : Print this message.
  filelist : the file to contain the list of all files in the following dir

1. If -KeepDrive is specified, disk drive name will be kept when this program
   lists the files (to be indexed) in the filelist. Otherwise drive names such
   as c: or d: in MS Windows are deleted from the paths of the listed files. 
2. -Old=OldFileList : the file contain all files that have been existed (have
	been used, or indexed, for example) in directories dir1, dir2, dir3, ....
	If this option is used, the 'filelist' will contain only those new files
	not existed in OldFileList and OldFileList will then be appended these
	new files in 'filelist' for future use.
3. If -html or -pub_html is specified, then only *.html? and *.txt files
   are included, else all files are included.
   Note: if -pub_html is used, the 'public_html' mechanism must be specified.
   See Apache's Web server document for information about the use of 'public_html'
4. dir1, dir2, dir3, ... : the directories to find the files to be added 
   to the filelist; 
   Note: directories must in "absolute path", and no '/' in the last char
	
Examples:
1. $0 -pub_html="public_html" db1.lst "/httpd/htdocs" "/home"
   List all the html and txt files in /httpd/htdocs and /home directories.
   Note assume users' home directories are in /home, then only user's 
   public_html directories will be listed. All other personal files won't.
   Thus Web users can not find personal files through the search system.
2. $0 db1-idx.lst "/ir/txt/ocr-idx.dir"
   List all the files in the listed directory /ir/txt/ocr-idx.dir in db1-idx.lst
3. $0 db2.lst /home/user1 /home/user2 /txt/books
   List all the files (i.e., *.*) in the listed directories in file db2.lst

Usemsg
	exit(0);
}

	my $WinOS = 0; $WinOS = 1 if ($^O =~ /^MSWin/);
#	$startCPU = (times)[0];
	$start = time();  # Start timing
	&usage() if $h;
	$filelist = shift @ARGV;
	if ($htdocs) { @Dir = ($htdocs); }
	push @Dir, @ARGV;

	&usage() unless ($filelist || @Dir);

	open FL, ">$filelist" || die "Cannot open file:'$filelist' for writing\n";
	$fc = 0; $fs = 0;
	&makelist(@Dir);
	print FL "#size=$fs\n";
	close(FL);

# change contents of $Old and $filelist
	if ($Old) {
		$fc = &FindNewFiles($Old, $filelist);
		$end = time();
		printf "\nIt takes %d seconds to Construct %d NEW files to a list.\n",
		abs($end - $start), $fc;
	} else {
		$end = time();
		printf "\nIt takes %d seconds to Construct %d files to a list.\n",
		abs($end - $start), $fc;
	}
	exit(0);


sub makelist {
  my(@Dir) = @_;  my($dir, @Files, $f, $pf);
  foreach $dir (@Dir) {
#print "$dir\n";
	next if ($dir eq "");
	opendir DIR, $dir || die "Cannot open dir:'$dir' for reading\n";
	@Files = readdir(DIR);	close(DIR);	@Files = sort @Files;
	foreach $f (@Files) {
		next if ($f =~ /^\./o);
		last if (($htdocs || $pub_html) && $f eq ".htaccess");
		$pf = "$dir/$f";
#print "pf=$pf\n";
		if (-d $pf) {
			&makelist($pf);
			next;
		}
		if (-r $pf) {
			if ($html || $public_html) {
				next if ($f !~ /\.html?$/io) && ($f !~ /\.txt$/io);
			}
			if ($pub_html) {
				next if $pf !~ /$pub_html/o;
			}
			$fc++; $fs += -s $pf;
# Add next line on Oct. 19, 1999 to remove leading drive name at Win32 environment
			$pf =~ s/^\w:// if ! $KeepDrive;
#			if ($WinOS) { $pf =~ s#/#\\#g; } else { $pf =~ s#\\#/#g; }
			if ($WinOS) { $pf =~ tr#/#\\#; } else { $pf =~ tr#\\#/#; }
				print FL "$pf\n"; 
			} else { print "Warning: '$pf' cannot be read\n"; }
		}
	}
} # End of sub makelist


sub FindNewFiles {
	my($Old, $New) = @_;
	open F, "$Old" or die "Cannot read '$Old'. But '$New' has been created";
	while (<F>) { $Old{$_} = 1; } close(F);
	open G, "$New" or die "Cannot read '$New'";
	my(@A); while (<G>) { next if $Old{$_}; push @A, $_; } close(G);
	open F, ">$New" or die "Cannot write '$New'";
	print F @A; close(F);
	open G, ">>$Old" or die "Cannot append '$Old'";
	print G @A; close(G);
	return ((scalar @A) - 1); # The one is '#TotalByteSize' line
}

