
perl -s ClusterDB.pl -Oall -Ouid=20 -Odebug=1 -Ogrp=test_A 1
rem ==>���ʧ@�|����5�ӷs�ɮס]����������ɡA�ϥΪ̵L���z�|�^�G

rem 2. �˵�����k�����G
rem (1)�Q�ΤW�z5���k������ɮסA�H���e���ΥX���O�ӡA����
perl -s Cluster.pl -Ocut=0.1 -Odebug=1 test_A ..\Result\test_A > ..\Result\test_A\0.1.html

rem (2)�s�ϡA����Term_Trend.pl
perl -s Term_Trend.pl -Ocolor -Ocut=0.1 -Omap ..\Result\test_A

rem 3. �N�W�z���G�k�����j���]��Ʊq��Ʈw��Ū�X�^�A����auto.pl�]�ݭn��Ʈw�ﶵ�GOdsn�POtable�^
perl -s auto.pl -Ocut=0.0 -Oold_cut=0.1 -Ouid=20 -Otfc=ChixTFC -Odsn=test_A -Otable=Seg_Abs6 -Oold_ct_low_tf=1 -Olow_tf=2 -Oct_low_tf=2 test_A test_A_S2
