# docker-stack-wordpress

Bộ docker compose này sẽ hoạt động với tất cả thành phần bao gồm:
- Nginx
- Fhp-Fpm (wordrepss)
- Mariadb
- Redis
- SSL cerbot
Để tránh việc vô ý tác  động vào dữ liệu nên  dữ liệu sẽ được lưu trữ và qủa lý bởi docker volume và  sẽ phải tạo trước khi khởi động compose này,  để có thể sử dụng stack này cần thực hiện chính xác các  bước sau.

Step 1: Trỏ DNS tên miền về  IP docker host, đảm bảo record @ và WWW phải trỏ hoàn tất và  có thể phân giải được trên các DNS puclic của googole(8.8.8.8) hoặc cloudflare (1.1.1.1). Nếu chưa phân giải được về IP máy host vui lòng không  thực hiện các bước tiếp sau để hạn chế việc chạm limit đăng ký ssl Lets encrypt. 

Step 2: Khởi tạo các volume docker cần thiết cho stack
```
docker volume create mariadb
docker volume create public_html
docker volume create certbot-ssl
```

Step 3: Đăng ký chứng chỉ SSL cho tên miền để stack có thể hoạt động  
```
docker run -it --rm --name certbotssl -v "certbot-ssl:/etc/letsencrypt" -p 80:80 certbot/certbot certonly --standalone --email exampleuser@gmail.com --agree-tos --no-eff-email --force-renewal -d example.com -d www.example.com
```
Chú ý thay thế `example.com` bằng tên miền  sẽ hoạt động trên stack này.  

Step 4: Download stack về máy host
```
git clone git@github.com:todo1991/docker-stack-wordpress.git
```
Step 5: đổi tên file `env-example` thành `.env` và điều chỉnh các biến sẽ sử dụng trong stack.  

Step 6: di chuyển đến thư mục `/docker-stack-wordpress/nginx/modsec` và tải về `coreruleset` để modsec trên nginx có thể hoạt động.  
```
git clone  https://github.com/coreruleset/coreruleset.git
cd coreruleset
cp crs-setup.conf.example crs-setup.conf
cp rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
```

Step 7: Thay đổi tên miền  trong file `/docker-stack-wordpress/nginx/conf.d/example.com.conf`
```
sed -i 's/example.com/domain.com/g' nginx/conf.d/example.com.conf
```
Chú ý thay thế `domain.com` bằng tên miền muốn sử dụng . 


Step 8: Đổi tên file cấu hình theo tên miền (tùy chọn)
```
mv nginx/conf.d/example.com.conf nginx/conf.d/domain.com.conf
```
Chú ý thay thế domain.com bằng tên miền muốn sử dụng.  

Step 9: khởi đông compose và kiểm tra hoạt động
```
docker compose up -d
```
