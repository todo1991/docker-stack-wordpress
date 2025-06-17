# docker-stack-wordpress

Bộ docker compose này sẽ hoạt động với tất cả thành phần bao gồm:
- Nginx
- PHP-FPM (WordPress)
- Mariadb
- Redis
- SSL certbot

Để tránh việc vô ý tác  động vào dữ liệu nên  dữ liệu sẽ được lưu trữ và quản lý bởi docker volume và  sẽ phải tạo trước khi khởi động compose này,  để có thể sử dụng stack này cần thực hiện chính xác các  bước sau.

Step 1: Trỏ DNS tên miền về  IP docker host, đảm bảo record @ và WWW phải trỏ hoàn tất và  có thể phân giải được trên các DNS puclic của googole(8.8.8.8) hoặc cloudflare (1.1.1.1). Nếu chưa phân giải được về IP máy host vui lòng không  thực hiện các bước tiếp sau để hạn chế việc chạm limit đăng ký ssl Lets encrypt.

Step 2: tạo file `.env` cho stack
Bạn có thể chạy script `init.sh` để tạo file này và cập nhật các cấu hình cần thiết.
Hoặc tự tạo thủ công bằng cách sao chép mẫu sau và chỉnh sửa lại giá trị:
```
cp .env.example .env
```
Sau đó nếu muốn có thể chạy `init.sh` để cập nhật thêm các tệp cấu hình.

Step 3: khởi động compose và kiểm tra hoạt động
```
docker compose up -d
```

## Giải thích các biến trong `.env`

- `MARIADB_ROOT_PASSWORD`: mật khẩu cho tài khoản root của MariaDB.
- `MARIADB_DATABASE`: tên cơ sở dữ liệu mặc định được tạo.
- `MARIADB_USER`: tài khoản người dùng cho WordPress.
- `MARIADB_PASSWORD`: mật khẩu của `MARIADB_USER`.
- `DOMAIN`: tên miền website dùng để cấu hình nginx và SSL.
- `EMAIL`: địa chỉ email đăng ký chứng chỉ Let's Encrypt.
- `IPHOST`: địa chỉ IP của máy chạy Docker.

---

# Cài đặt plugin quản lý cache và redis
Mặc định thì init.sh đã thêm aliases wp-cli để rút ngắn câu lệnh, nhưng nếu không có thể  chay lệnh sau(chú ý thoát ssh và login lại để load biến môi trường mới hoặc dùng lệnh soucre để áp dụng biến môi trường lập tức)
```
echo 'alias wpcli="docker compose run -ti --rm --no-deps --quiet-pull wpcli"' >> ~/.bash_aliases
```
Sau đó có thể gọi lệnh wpcli từ thư mục compose gọn gàng
```
# các plugin nên cài
wpcli plugin install redis-cache --activate
wpcli plugin install flying-fonts --activate
wpcli plugin install flying-scripts --activate
wpcli plugin install flying-pages --activate
# Không cần cài plugin bên dưới, nguyên nhân là do nginx đang cấu hình fastcgi_cache_valid 1s, nếu cần thết lập lưu cache lâu hơn thì có thể  cài thêm plugin này để update cache tự động khi có thay đổi  nội dung  website.
wpcli plugin install nginx-helper --activate
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
Mặc định init.sh đã thêm cron gia hạn ssl tự động, nếu vì lý do gì đó bị mất  thì có thể thiết lập lại cron như sau:
```
0 2 * * * bash /pathtofile/ssl_renew.sh >/dev/null 2>&1
```

## License
This project is licensed under the [MIT License](LICENSE).

