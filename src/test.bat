
perl -s ClusterDB.pl -Oall -Ouid=20 -Odebug=1 -Ogrp=test_A 1
rem ==>此動作會產生5個新檔案（全部為資料檔，使用者無須理會）：

rem 2. 檢視文件歸類結果
rem (1)利用上述5個歸類資料檔案，以門檻切割出類別來，執行
perl -s Cluster.pl -Ocut=0.1 -Odebug=1 test_A ..\Result\test_A > ..\Result\test_A\0.1.html

rem (2)製圖，執行Term_Trend.pl
perl -s Term_Trend.pl -Ocolor -Ocut=0.1 -Omap ..\Result\test_A

rem 3. 將上述結果歸成較大類（資料從資料庫中讀出），執行auto.pl（需要資料庫選項：Odsn與Otable）
perl -s auto.pl -Ocut=0.0 -Oold_cut=0.1 -Ouid=20 -Otfc=ChixTFC -Odsn=test_A -Otable=Seg_Abs6 -Oold_ct_low_tf=1 -Olow_tf=2 -Oct_low_tf=2 test_A test_A_S2
