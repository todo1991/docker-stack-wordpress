# docker-stack-wordpress

Bộ docker compose này sẽ hoạt động với tất cả thành phần bao gồm:
- Nginx
- Fhp-Fpm (wordrepss)
- Mariadb
- Redis
- SSL cerbot
  
Để tránh việc vô ý tác  động vào dữ liệu nên  dữ liệu sẽ được lưu trữ và quản lý bởi docker volume và  sẽ phải tạo trước khi khởi động compose này,  để có thể sử dụng stack này cần thực hiện chính xác các  bước sau.

Step 1: Trỏ DNS tên miền về  IP docker host, đảm bảo record @ và WWW phải trỏ hoàn tất và  có thể phân giải được trên các DNS puclic của googole(8.8.8.8) hoặc cloudflare (1.1.1.1). Nếu chưa phân giải được về IP máy host vui lòng không  thực hiện các bước tiếp sau để hạn chế việc chạm limit đăng ký ssl Lets encrypt. 

Step 2: Khởi tạo các volume docker cần thiết cho stack
```
docker volume create mariadb
docker volume create public_html
docker volume create certbot-ssl
```

step 3: chạy file init.sh để thay đổi các file conf
```
chmod +x init.sh
./init.sh
```

Step 4: khởi động compose và kiểm tra hoạt động
```
docker compose up -d
```

---

Cài đặt plugin quản lý cache và redis
```
docker compose run -ti --rm --no-deps --quiet-pull wpcli plugin install redis-cache --activate
docker compose run -ti --rm --no-deps --quiet-pull wpcli plugin install nginx-helper --activate
docker compose run -ti --rm --no-deps --quiet-pull wpcli plugin install flying-fonts --activate
docker compose run -ti --rm --no-deps --quiet-pull wpcli plugin install flying-scripts --activate
docker compose run -ti --rm --no-deps --quiet-pull wpcli plugin install flying-pages --activate
```

# Hướng dẫn backup database của webiste
```
source .env && docker compose  exec mariadb mariadb-dump --databases ${MARIADB_DATABASE} -u${MARIADB_USER} -p${MARIADB_PASSWORD} > mariadb-dump-$(date +%F_%H-%M-%S).sql
```

# Hướng dẫn backup mã nguồn của website
```
docker run --rm --volumes-from wordpress_instance -v $(pwd):/backup alpine tar cvf /backup/backupcode-$(date +%F_%H-%M-%S).tar /var/www/html
```
# Thêm cron gia hạn SSL mỗi ngày vào 2h sáng
```
0 2 * * * bash /pathtofile/ssl_renew.sh >/dev/null 2>&1
```
