REM The following DOS commands will install modules for CATAR
cd \CATAR\src
cpanm install Encode::Detect::Detector
cpanm install Statistics::Regression
cpanm install Math::MatrixReal
cpanm install Win32::ODBC

mkdir C:\Strawberry\perl\site\lib\SAMtool
copy Perl_Module\SAMtool\* C:\Strawberry\perl\site\lib\SAMtool
