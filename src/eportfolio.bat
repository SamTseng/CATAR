Rem This file show how analyze data from http://etds.ncl.edu.tw/ by CATAR.


Rem Step 0: Change working directory to disk C: and C:\CATAR\src
Rem         This step assumes that you install CATAR under C:\CATAR
C:
cd C:\CATAR\src

Rem Step 1: For overview analysis, run:
perl -s automc.pl -OOA -Odb eport
Rem The above command analyze the data already in the database.
Rem The database must be this: ..\Source_Data\eport\eport.db

Rem Step 2: For break down analysis based on bibliographic coupling, run:
perl -s automc.pl -OBC -Omin=0 eport ..\Source_Data\eport\eport.db

Rem Step 3: For break down analysis based on co-word (word co-occurrence), run:
perl -s automc.pl -OCW -Omin=0 eport ..\Source_Data\eport\eport.db
