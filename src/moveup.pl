#!/usr/bin/env perl -s
# Written on 2020/02/14 by Yuen-Hsien Tseng
# This program is to reorganize the files for VOSviewer.
#   The folder structure is created by NodeJs_WoS_downloader.
# Given a folder with sub-folder named as 1_500, 501_1000, etc,
#   in which only one file exists, move the file out of
#   the sub-folder and rename the file with the name of the sub-folder.
# Syntax: perl moveup.pl folder_name
# Ex: $ perl -s ../moveup.pl Asia10_19/2
#       mv Asia10_19/2 Asia10_19/data
# perl -s ../moveup.pl HiEdu90_19/11
#       mv HiEdu90_19/11 HiEdu90_19/data
# perl -s ../moveup.pl MedEdu10_19/5
#       mv MedEdu10_19/5 MedEdu10_19/data
# perl -s ../moveup.pl SciEdu10_19/1
#       mv SciEdu10_19/1 SciEdu10_19/data
# perl -s ../moveup.pl eLearn10_19/0
#       mv eLearn10_19/0 eLearn10_19/data

#use Tie::File;
use File::Copy;
$dir = shift @ARGV;
opendir DIR, $dir || die "Cannot open dir:'$dir' for reading\n";
@Files = readdir(DIR);	close(DIR);	@Files = sort @Files;
foreach $f (@Files) {
    $newd = "$dir/$f";
    next if ($newd =~ /^\./o);
    next if (not -d $newd);
    $old = "$newd/1-500.txt";
    $old = "$newd/savedrecs.txt" if not (-r $old);
    if (not (-r $old)) {
        warn("'$dir/$f' has no desired txt file.");
        next;
    }
    $newf = "$dir/$f" . '.txt';
    move($old, $newf); # move file from $old to $new
    print("  move $old to $newf\n");
    print("remove $newd\n");
    rmdir($newd) or warn("Cannot remove dir: '$newd'")
}
