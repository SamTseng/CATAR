Rem This file show you how to run CATAR by use of the lkcgmh's publications as an example.


Rem Step 0: Change working directory to disk C: and C:\CATAR\src
Rem         This step assumes that you install CATAR under C:\CATAR
C:
cd C:\CATAR\src

Rem Step 1: For overview analysis, run :
perl -s automc.pl -OOA lkcgmh ..\Source_Data\lkcgmh\data
Rem The above command create the databased needed for the following two commands.

Rem Step 2: For break down analysis based on bibliographic coupling, run:
perl -s automc.pl -OBC lkcgmh ..\Source_Data\lkcgmh\lkcgmh.db

Rem Step 3: For break down analysis based on co-word (word co-occurrence), run:
perl -s automc.pl -OCW lkcgmh ..\Source_Data\lkcgmh\lkcgmh.db
