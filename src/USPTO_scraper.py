#USPTO爬蟲網頁的範例
#本程式碼由楊德倫、林榆真共同於2020/11/25編寫完成

# 引入模組
#!pip install requests
#!pip install beautifulsoup4
#!pip install xlrd

import requests
import time
from bs4 import BeautifulSoup
import xlwt

wb = xlwt.Workbook()
sht = wb.add_sheet("sheet")
number_list = []
title_list=[]
# 自訂標頭
my_headers = {'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36'}

for i in range(1,4):
  # 使用 GET 方式下載專利網頁
  response = requests.get('http://patft.uspto.gov/netacgi/nph-Parser?Sect1=PTO2&Sect2=HITOFF&u=%2Fnetahtml%2FPTO%2Fsearch-adv.htm&r=0&p={}&f=S&l=50&Query=ICL%2FG06F40%2F20&d=PTXT'.format(i), headers = my_headers)
  
  
  # 指定 lxml 作為解析器，使用 html parser
  soup = BeautifulSoup(response.text, "lxml")
  # 取得表格資訊
  TRs = soup.select('body > table:nth-of-type(1) tr')
  #print("長度:",len(TRs)-1)
  time.sleep(3) #休息3秒
  for index, tr in enumerate(TRs):
    if index == 0:
        continue
    
    #可輸出內容
    #print("流水號: {}".format(tr.select('td')[0].text)) #網頁流水號
    #print("PAT. NO.: {}".format(tr.select('td')[1].text)) #專利號碼
    #tr.select('td')[2].text) 輸出為text。沒有意義
    #print("Title: {}".format(tr.select('td')[3].text))  #專利名稱
    #print("Hyperlink: {}".format('http://patft.uspto.gov' + tr.select('td:nth-of-type(4) a')[0]['href'])) #專利的超連結

    number=tr.select('td')[1].text #專利號碼
    number_list.append(number)
    
    titl=tr.select('td')[3].text  #專利名稱
    title=titl.strip()
    title_list.append(title)
  
for x in range(len(number_list)): #使用迴圈寫入excel檔
      sht.write(x, 0, number_list[x])
      sht.write(x, 1, title_list[x])

wb.save('PatFT_IPC.xls')   