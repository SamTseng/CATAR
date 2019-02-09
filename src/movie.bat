Rem This file show you how to run CATAR by use of the movie news as an example.


Rem Step 0: Change working directory to disk C: and C:\CATAR\src
Rem         This step assumes that you install CATAR under C:\CATAR
C:
cd C:\CATAR\src

Rem Step 1: For overview analysis, run :
perl -s automc.pl -OOA -Odb movie
Rem The above command analyze the data already in the database.
Rem The database must be this: ..\Source_Data\movie\movie.db

Rem Step 2: For break down analysis based on bibliographic coupling, run:
Rem perl -s automc.pl -OBC movie ..\Source_Data\movie\movie.db
Rem the movie news do not have Cited References for bibliographic coupling analysis

Rem Step 3: For break down analysis based on co-word (word co-occurrence), run:
perl -s automc.pl -OCW movie ..\Source_Data\movie\movie.db
