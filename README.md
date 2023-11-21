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

step 4: chạy file init.sh để thay đổi các file conf
```
chmod +x init.sh
./init.sh
```

Step 5: khởi động compose và kiểm tra hoạt động
```
docker compose up -d
```

---

Stack  đã có sẵn redis server để kết nối hãy sửa file wp-config.php thêm nội dung sau:
```
define('WP_REDIS_HOST', 'redis_server');
define('WP_REDIS_PORT', 6379);
```

