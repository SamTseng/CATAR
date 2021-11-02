# On 2021/09/15 written by Yuen-Hsien Tseng
# Give a folder with subfolers having WoS downloaded files with the filenames:
#    C:\CATAR\Source_Data\ChildEdu\data\IYC 的目錄
#   2021/07/17  下午 02:29         2,378,147 savedrecs.txt
#    C:\CATAR\Source_Data\ChildEdu\data\JEI 的目錄
#   2021/07/17  下午 02:18           327,215 savedrecs (1).txt
#   2021/07/17  下午 02:18         2,371,020 savedrecs.txt
# This program try to move the files to a subfolder with all the files under this subfolder
#   so that the VOSviewer can analyze them conveniently
# That is, we want to move those files to a, say, subfolder: allfiles
#   C:\CATAR\Source_Data\ChildEdu\allfiles\IYC_savedrecs.txt
#   C:\CATAR\Source_Data\ChildEdu\allfiles\JEI_savedrecs (1).txt
#   C:\CATAR\Source_Data\ChildEdu\allfiles\JEI_savedrecs.txt
# See: https://www.ewdna.com/2012/04/pythonoswalk.html for examples
# See: https://blog.gtwang.org/programming/python-howto-check-whether-file-folder-exists/
# See: https://stackoverflow.com/questions/123198/how-do-i-copy-a-file-in-python
# Usage:
#  C:\CATAR\src> python move_up_files.py C:\CATAR\Source_Data\ChildEdu\data_org C:\CATAR\Source_Data\ChildEdu\data
import os, sys
from pathlib import Path
import shutil

SrcDir, TgtDir = sys.argv[1:3]
sys.stderr.write("Source Dir: %s, Target Dir: %s\n" % (SrcDir, TgtDir))
if not os.path.isdir(TgtDir):
    os.mkdir(TgtDir)
    sys.stderr.write("'%s' has been created.\n" % TgtDir)

for (root, dirs, files) in os.walk(SrcDir, topdown=True):
#    print(root, dirs)
    for f in files:
        srcName = os.path.join(root, f)
        PathList = Path(srcName).parts
        tgtName = os.path.join(TgtDir, PathList[-2] + '_' + PathList[-1])
        if not os.path.exists(tgtName):
            shutil.copy2(srcName, tgtName)
            print(srcName, tgtName)
    print("-" * 40)


# See: https://stackoverflow.com/questions/3167154/how-to-split-a-dos-path-into-its-components-in-python
# >>> Path('C:/path/to/file.txt').parts
# ('C:\\', 'path', 'to', 'file.txt')
# See: https://www.ewdna.com/2012/04/pythonoswalk.html
# for response in os.walk("/python/demo/"):
#     print response
# ('/python/demo/', ['root'], ['walk.py', 'os_walk.py'])
# ('/python/demo/root', ['3subDir', '2subDir'], ['1file', '3file'])
# ('/python/demo/root/3subDir', [], ['31file'])