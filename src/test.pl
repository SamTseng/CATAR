	$BC = 'BibCpl';
# /*--書目對分析----------------------------------------------------------------------*/
	if ($main::OBibCpl eq 'manual') { # 將待歸類文件，轉換放到 doc/ 目錄下
		$cmd = "$prog Cluster.pl -Odebug -ObigDoc=manual -ODB=$DB_Path $DSN "
. "\"select UT, TI, AB from TPaper where UT=?\" $InDir ../doc/${DSN}_BibCpl_S2";
		&myexec($cmd);
		$cut = &Clustering_BibCpl($DSN, $DB_Path, 2, $BC);
	} elsif ($main::OBibCpl =~ /^JBC$|^ABC$/i) { # 期刊書目對、作者書目對
		$BC = $main::OBibCpl; $BC = uc $BC;
# 依照期刊名稱將論文分類，使每一類包含一個期刊的論文
#   perl -s ISI.pl -OBigDoc SC_Edu_JBC ..\Source_Data\SC_Edu\SC_Edu.mdb Journal ..\doc\SC_Edu_JBC_S2
  # # It takes 304 seconds
		$cmd = "$prog ISI.pl -OBigDoc ${DSN}_$BC $DB_Path $BC ../doc/${DSN}_${BC}_S2";
		&myexec($cmd);
		$cut = &Clustering_BibCpl($DSN, $DB_Path, 2, $BC);		
	} else {
#goto Stage5;
		$cut = &Clustering_S1($DSN, $DB_Path);
Stage2:
		&PromptMsg1($DSN, 1, $cut);
		$cut = &Clustering_S1toS2($DSN, $DB_Path, 2, $cut, $BC);
	}

Stage3:
#$cut=0.05;
	&PromptMsg1($DSN, 2, $cut);
	$cut = &Clustering_S2toS3($DSN, $DB_Path, 3, $cut, $BC);
