Rem This file show you how to run CATAR by use of the SE's publications from 12 journals.
Rem SE denotes Science Education (a set of 2912 WoS records from 11 SE journals).

Rem Step 0: Change working directory to disk C: and C:\CATAR\src
Rem         This step assumes that you install CATAR under C:\CATAR
C:
cd C:\CATAR\src

Rem Step 1: For overview analysis, run :
perl -s automc.pl -OOA SE ..\Source_Data\SE\data
Rem The above command create the databased needed for the following two commands.

Rem Step 2: For break down analysis based on bibliographic coupling, run:
perl -s automc.pl -OBC SE ..\Source_Data\SE\SE.db

Rem Step 3: For break down analysis based on co-word (word co-occurrence), run:
perl -s automc.pl -OCW SE ..\Source_Data\SE\SE.db
