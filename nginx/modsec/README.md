cập nhật  modsec theo hướng dẫn này:  
https://www.linode.com/docs/guides/securing-nginx-with-modsecurity/#testing-modsecurity    
Cấu trúc thư mục này chính xác như sau:
```
├── coreruleset
├── main.conf
├── modsecurity.conf
├── README.md
└── unicode.mapping  
```
File unicode.mapping được lấy từ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/unicode.mapping  
Thư mục coreruleset được  lấý từ git: git clone https://github.com/coreruleset/coreruleset.git  
Sau đó truy cập vào coreruleset, đổi tên   2 file sau:  
```
# PWD:  /root/dockerlab/docker-nginx-reverse-proxy/nginx/modsec/coreruleset
cp crs-setup.conf.example crs-setup.conf
cp rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
``` 
