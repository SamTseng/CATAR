# Content Analysis Toolkit for Academic Research (CATAR)
To analyze patents from USPTO, please look at the details below.
To analyze other types of text data, please refer to: 
http://web.ntnu.edu.tw/~samtseng/CATAR/.

Notes:
1. The code here would be updated more earlier than those at: http://web.ntnu.edu.tw/~samtseng/CATAR/ (should be a few days earlier).
2. If you are clustering very short texts, co-word clustering would be very sensitive to the choice of the parameters (such as minimum thresholds of term occurrence) and the stop words.
3. The examples in the tutorials (CATAR_Tutorial.ppt or CATAR_Tutorial_en.ppt) use very low threshold values (e.g., 0.0) to get the results. After installation of CATAR on your computer, you should run sam.bat (under src sub-folder) to see if your results are almost the same as those in the tutorials.

## Introduction
The steps described below are for analyzing patent documents (in HTML) from the United States Patent and Trademark Office (USPTO).

CATAR provides the following functions to analyze a set of patents:
1. Automatically download each patent document (in HTML) given a set of patent numbers in a text file.
2. After downloading each patent HTML file, parse the HTML file to get various information and save them into a Database Management System (DBMS). Currently, the used DBMS is Microsoft Access.
3. You could do some analyses in the MS Access file using the queries already prepared in the Access file.
4. You could do more patent analyses using the CATAR functions like those (overview or topic break-down analyses) described at: http://web.ntnu.edu.tw/~samtseng/CATAR/.


## Steps to analyze the USPTO patents
1. **Prepare the patent set**
Prepare a pure text file having a set of patent numbers, with each line containing only one patent number. 

Normally you would search USPTO with its advanced search: http://patft.uspto.gov/netahtml/PTO/search-adv.htm to collect a set of patents for analysis. 

**Note: This is a crucial step**, because it affects any statistics you get in later steps. 

You should place this file under a certain folder, like the one already in the CATAR folder: CATAR\Source_Data\DL_DNN\DL_DNN_1636.txt.


2. **Edit Patent.ini**
Edit CATAR\src\Patent.ini to add a new group, like:
    [DL_DNN]
    PatentDir=..\Source_Data\DL_DNN\patents
    DSN=DL_DNN
    SaveDescription=1

3. **Duplicate an empty MS Access file**
Under the CATAR\src folder in the DOS command line, run the copy file command, like:
    C:\CATAR\src> copy Patent_org.mdb ..\Source_Data\DL_DNN\DL_DNN.mdb


4. **Set the DSN (Data Source Name)**
Double click the file: C:/Windows/SysWOW64/odbcad32.exe to open the "ODBC Data Source Administrator".

Click on the "User DSN" Tab on the top and then click "Add" on the right. 

On the next page, choose "Microsoft Access Driver (*.mdb)" and then click on "Finish".

Assign a DSN name and select the appropriate source. You will see a list of available database files. Select the ones you want to associate with the DSN you just created. For example, you may set a DSN named: DL_DNN and associate it with the file: "C:\CATAR\Source_Data\DL_DNN\DL_DNN.mdb". Click "OK" to finish this step.

If you still have difficulty in this step, google the usage of "ODBC Data Source Administrator". You should use the 32 bits version, not the 64 bits version.

5. **Stat to run CATAR**:
Now you can run CATAR to download and parse the patent sets, by running a command like this:

    C:\CATAR\src>perl -s patent.pl -Odb -Ogroup=DL_DNN -OPat2DB ..\Source_Data\DL_DNN\DL_DNN_1636.txt

When this command is running, it will tell you the progress and something that may be abnormal, such as truncated information when saving information into the Access file. 

Ignore the abnormal messages and **watch out for the failure messages that tell some patents can not be downloaded**, due to network traffic or the USPTO server's latency. 

Do not worry for these failures. 

**Just re-run the above command**. Those that have been downloaded will not be downloaded again. Only those failed will be downloaded again. You could run the same command as many times as you want, until no failure is reported.


6. **Open the MS Access file**:
You can check the tables to know what information have been downloaded and parsed. Also check the queries to have some statistics about your patent set.

For further analysis, please check: http://web.ntnu.edu.tw/~samtseng/CATAR or send me an email: samtseng@ntnu.edu.tw for clarity.

Or, you may do your own analyses (and feedback to me for future development).
