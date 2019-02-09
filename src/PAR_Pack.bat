# 0. 使用 pp 的命令以前，請先安裝 PAR::Packer 模組，亦即在命令列下，輸入：
#    cpan install PAR::Packer
#    此安裝步驟大約需花費半小時
# Then run "copy C:\strawberry\perl\site\bin\parl.exe  C:\CATAR\bin" to
#  copy new parl.exe into C:\CATAR\bin

# 1. Add "use SamOpt;  &SamOpt();" to the Perl files which process options.
# 2. For those Perl scripts running "system($cmd)" (only automc.pl and auto.pl),
# change the "perl -s " into "parl CATAR.par "

# The following line run on 2014/06/15
C:\CATAR_src\src>pp -B -p -o CATAR.par auto.pl automc.pl CiteAna.pl Cluster.pl ClusterDB.pl filelist4.pl filterRT.pl ISI.pl ISI_CR.pl ParseSciRef.pl Patent.pl ShowDoc.pl StopWords.pl term_cluster.pl Term_Trend.pl tool.pl 
move CATAR.par c:\CATAR\bin\CATAR.zip
# Insert StopWords.pl into the lib folder of c:\CATAR\bin\CATAR.zip
cd c:\CATAR\bin
move CATAR.zip CATAR.par
# remove C:\CATAR\Result\*.*
# remove C:\CATAR\doc\*.*





# The following two lines are run on 2010/11/21 based on Strawberry Perl V5.12
# Note all the used and required Perl modules will be included automatically
#pp -B -p -N LegalCopyright="Authored by Yuen-Hsien Tseng (c) 2012" -o CATAR.par auto.pl automc.pl CiteAna.pl Cluster.pl ClusterDB.pl filelist4.pl filterRT.pl ISI.pl ISI_CR.pl ParseSciRef.pl Patent.pl ShowDoc.pl StopWords.pl term_cluster.pl Term_Trend.pl tool.pl 
# Note: change CATAR.par into CATAT.zip and compress StopWords.pl into lib/ of CATAR.zip
#		and then change CATAR.zip back to CATAT.par
#move CATAR.par CATAR.zip
#move CATAR.zip CATAR.par
move CATAR.par C:\CATAR\bin
del C:\CATAR_src\CATAR.zip
# Now zip C:\CATAR into C:\CATAR_src\CATAR.zip 
# (note you cannot zip C:\CATAR into C:\CATAR.zip, because C:\CATAR.zip is itself a folder)
# You may now upload CATAR.zip to the server for others to download.
# Note: Although options -B -p were used, tests on computers without installing Perl
#       are not successful.



# The following are run using an older Strawberry version (Perl V5.10)
# pp -B -p -o CATAR.zip automc.pl auto.pl ISI.pl CiteAna.pl Cluster.pl ClusterDB.pl term_cluster.pl Term_Trend.pl tool.pl filelist4.pl Patent.pl ParseSciRef.pl filterRT.pl
# 打包好之後，利用WinZip將C:\strawberry\perl\lib\unicore\Heavy.pl加到
# 壓縮檔的 lib\unicore\ 下（新版V5.12已經不用自己手動加入Heavy.pl了），然後執行：
# move CATAR.zip ..\bin\CATAR.par

# The following do not work
#pp -B -p --link=C:\strawberry\perl\lib\unicore\Heavy.pl -o CATAR.par automc.pl auto.pl ISI.pl CiteAna.pl Cluster.pl ClusterDB.pl term_cluster.pl Term_Trend.pl tool.pl filelist4.pl Patent.pl ParseSciRef.pl filterRT.pl

#pp -B -p -M C:\strawberry\perl\lib\unicore\Heavy.pl -o CATAR.par automc.pl auto.pl ISI.pl CiteAna.pl Cluster.pl ClusterDB.pl term_cluster.pl Term_Trend.pl tool.pl filelist4.pl Patent.pl ParseSciRef.pl filterRT.pl
#pp -M C:\strawberry\perl\lib\unicore\Heavy.pl CATAR.par

#pp -a "Paper_org.mdb;Patent_org.mdb;Patent.ini;Cluster.ini;mds.exe;ISI_SC2C.txt" CATAR.par 



# To create a PAR file that do not include Perl.exe, run:
#   D:\demo\SAM>pp -B -p -o CATAR.par testpm.pl test.pl stem.pl
# To run the Perl scripts in this PAR file:
#   D:\demo\SAM>parl CATAR.par stem.pl ladies cats dogs
#   D:\demo\SAM>parl CATAR.par test.pl
#   D:\demo\SAM>parl CATAR.par testpm.pl -OStem cats dogs
# Now we can ship parl.exe by itself, along with the .par file built
#   by "pp -B -p -o", and run the PAR file by associating them to parl.exe.



# The following message is from :
# http://stackoverflow.com/questions/444388/how-can-i-pass-command-line-arguments-via-file-association-in-vista-64
# 
# Question :
#     foo.pl:
# 	#!/usr/bin/perl -w
# 	use strict;
# 	my $num_args = $#ARGV + 1;
# 	print "${num_args} arguments read\n";
#     Running "foo.pl 1 2 3" undesirably yielded:
#     0 arguments read
# Answer:
#     Since the command line find the perl interpreter when you start a .pl file, 
# the association has to be somewhere. Search the registry for "perl.exe", 
# and see whether you can apply this information.
# 
#     It could be at: HKEY_CLASSES_ROOT\Perl\shell\Open\command. After searching
# perl.exe in the registry, it was found at:
# 	HKEY_CLASSES_ROOT\Applications\Perl\shell\Open\command
# Its value reads: "C:\strawberry\perl\bin\perl.exe" "%1"
# The %* was missing. Now update its value as:
# 	"C:\strawberry\perl\bin\perl.exe" "%1" %*
# 
# See also http://www.perlmonks.org/?node_id=816922
#     You can just add ;.pl to $ENV{PATHEXT}.
# This will allow you to run script when there is a scrip.pl
#     Also under DOS, run:
# 	help assoc
# 	help ftype
# to know the file association mechanism better.
# You will see that perl is used as an example.
#
# The above solution actually appears in the section of 
#    Fun with File Associations at 
#    http://win32.perl.org/wiki/index.php?title=Talk:Main_Page
