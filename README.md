# Content Analysis Toolkit for Academic Research (CATAR)
To analyze patents from USPTO, please look at the details below.

To analyze other types of text data, please refer to: 
http://web.ntnu.edu.tw/~samtseng/CATAR/.

Notes:
1. If you are clustering 1) very short texts or 2) only a few documents (for verification), co-word clustering would be very sensitive to the choice of the parameters (such as minimum thresholds of term occurrence) and the stop words.
2. The examples in the tutorials ([CATAR_Tutorial.ppt](http://web.ntnu.edu.tw/~samtseng/CATAR/CATAR_Tutorial.ppt) or [CATAR_Tutorial_en.ppt](http://web.ntnu.edu.tw/~samtseng/CATAR/CATAR_Tutorial_en.ppt)) use very low threshold values (e.g., 0.0) to get the results. After installation of CATAR on your computer, you should run sam.bat (under src sub-folder) to see if your results are almost the same as those in the tutorials.

## Introduction
The steps described below are for analyzing U.S.A. patent documents from the PatentsView's PatentSearch API (https://search.patentsview.org/docs/docs/Search%20API/SearchAPIReference/#query-string-q). For a set of US patents, CATAR can help you to:

1. Automatically download each patent document information, if you provided a set of patent numbers in a text file.
2. Save various patent information of the downloaded patents into a Database Management System (DBMS). Currently, the used DBMS is Microsoft Access (.mdb).
3. Do some analyses in the MS Access file using the queries already prepared in the Access file.
4. Do more patent analyses using the CATAR functions like those (overview or break-down analyses) described at: http://web.ntnu.edu.tw/~samtseng/CATAR/.

**Some knowledge about SQL (Structure Query Language) and DBMS (Database Management System) is preferred**.


## Steps to analyze the USPTO patents

1. **Apply a PatentSearch API Key**

   CATAR uses PatentSearch's APIs (https://patentsview.org/) to fetch USA patent information. To do that, you need to have an API key. Please go to https://patentsview-support.atlassian.net/servicedesk/customer/portal/1/group/1/create/18 to request a PatentSearch API Key.
   Getting approved and having a key may take one or two days.

   Once you have an API key (it looks like: gvtLdGV0.wFGvmAerzgmApv9G5tZc23cy8Djnwy6n),
   edit the text file with filename: `myAPI_KEY.txt` under CATAR\src directory. That is, this file is: `C:\CATAR\src\myAPI_KEY.txt` and should have the content as follows:
   ```
   API_KEY=gvtLdGV0.wFGvmAerzgmApv9G5tZc23cy8Djnwy6n
   ```

   Note: You only have to apply the API Key and edit the `myAPI_KEY.txt` file for the first time when using CATAR for patent analysis.
   
2. **Download and Install Microsoft Access Database Engine 2016**

    Browse to https://www.microsoft.com/zh-tw/download/details.aspx?id=54920&irgwc=1 and click on the "Download" button to save `accessdatabaseengine_X64.exe` or `accessdatabaseengine.exe` to your local disk, depending on the Perl version you are using.

    To know which Perl version you are using, under the DOS command terminal, run:
    ```
    C:\CATAR\src>perl -v

    This is perl 5, version 32, subversion 1 (v5.32.1) built for MSWin32-x86-multi-thread-64int

    Copyright 1987-2021, Larry Wall
    ```
    In the above example output, the Perl version is 64 bits, so you should download `accessdatabaseengine_X64.exe`. Otherwise, the Perl is 32 bits and you should download `accessdatabaseengine.exe`.

    Double click on the downloaded `.exe` file to install the required MS Access driver program for later use.

   Note: you only have to do this for the first time for patent analysis.
   
3. **Prepare the patent set**:

    Prepare a pure text file having a set of patent numbers, with each line containing a single US patent number (patent id). 

    Normally you would query US patents at: https://www.uspto.gov/patents/search/patent-public-search to collect a set of patents for analysis. After searching the required patents, you should collect the patent number (patent id) from the search results page into a text file with each patent number in a line.

    **Note: This is a crucial step**, because it affects any statistics you get in later steps. 

    You should place this text file under CATAR\Source_Data\ sub-folder, like the one already in the CATAR folder: CATAR\Source_Data\DL_DNN\DL_DNN_1636.txt.

4. **Edit Patent.ini**:

    Edit CATAR\src\Patent.ini to add a new group. As an example:
    ```
    [DL_DNN]
    PatentDir=..\Source_Data\DL_DNN\patents
    DSN=DL_DNN
    SaveDescription=1
    ```

5. **Copy an empty MS Access file to the specified folder**

    Under the CATAR\src folder in the DOS command terminal, run the copy file command, e.g.:
    ```
    copy Patent_org.mdb ..\Source_Data\DL_DNN\DL_DNN.mdb
    ```

6. **Start to run CATAR**:

    Now you can run CATAR to download and parse the patent set under the CATAR\src folder, by running a command like this:
    ```
    perl -s patent.pl -Odb=..\Source_Data\DL_DNN\DL_DNN.mdb -Ogroup=DL_DNN -OPat2DB ..\Source_Data\DL_DNN\DL_DNN_1636.txt
    ```
    The MS Access file (DL_DNN.mdb) in -Odb will store all the patent information fetching using PatentsView's API based on the patent number (patent id) in the DL_DNN_1636.txt.

    When this command is running, it will tell you the progress. 

    Ignore any abnormal messages during the above patent fetching process and **watch out for the failure messages which tell that some patents can not be downloaded**. The failure may be due to network traffic or network latency.

    Do not worry about these failures. 

    **Just re-run the above command**. Those that have been downloaded will not be fetched again. Only those failed will be downloaded. You could run the same command as many times as you want, until no failure is reported.

7. **Open the MS Access file**:

    Open the MS Access file from Step 5. You can check the tables to know what information has been downloaded and parsed. Also, check the queries to have some statistics about your patent set.


For further analysis, please check: http://web.ntnu.edu.tw/~samtseng/CATAR or send me an email: samtseng@ntnu.edu.tw for clarity.

Or, you may do your own analyses (and feedback to me for future development).
