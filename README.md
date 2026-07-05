# docker-stack-wordpress

Bộ docker compose này sẽ hoạt động với tất cả thành phần bao gồm:
- Nginx
- PHP-FPM (WordPress)
- Mariadb
- Redis
- SSL certbot

## Yêu cầu hệ thống
Khuyến nghị máy chủ có **RAM tối thiểu 4GB** (MariaDB buffer pool 1G + PHP-FPM tối đa 15 worker × 512M memory_limit + Redis 256M). Nếu máy ít RAM hơn, hãy giảm `innodb_buffer_pool_size` trong `conf/mariadb/mariadbcustom.cnf` và `pm.max_children` trong `dockerfile/Dockerfile.wp`.

Để tránh việc vô ý tác  động vào dữ liệu nên  dữ liệu sẽ được lưu trữ và quản lý bởi docker volume và  sẽ phải tạo trước khi khởi động compose này,  để có thể sử dụng stack này cần thực hiện chính xác các  bước sau.

Step 1: Trỏ DNS tên miền về  IP docker host, đảm bảo record @ và WWW phải trỏ hoàn tất và  có thể phân giải được trên các DNS puclic của googole(8.8.8.8) hoặc cloudflare (1.1.1.1). Nếu chưa phân giải được về IP máy host vui lòng không  thực hiện các bước tiếp sau để hạn chế việc chạm limit đăng ký ssl Lets encrypt.

Step 2: Tạo file `.env` cho stack
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
Lưu ý: service tiện ích `certbot` nằm trong profile `tools` nên sẽ **không** khởi động cùng `docker compose up -d`; nó chỉ chạy khi được gọi trực tiếp bằng `docker compose run --rm certbot ...`. Còn wp-cli được cài sẵn trong container `wordpress_instance`, gọi qua `docker exec` (xem phần dưới).

## Giải thích các biến trong `.env`

- `MARIADB_ROOT_PASSWORD`: mật khẩu cho tài khoản root của MariaDB.
- `MARIADB_DATABASE`: tên cơ sở dữ liệu mặc định được tạo.
- `MARIADB_USER`: tài khoản người dùng cho WordPress.
- `MARIADB_PASSWORD`: mật khẩu của `MARIADB_USER`.
- `DOMAIN`: tên miền website dùng để cấu hình nginx và SSL.
- `EMAIL`: địa chỉ email đăng ký chứng chỉ Let's Encrypt.
- `WORDPRESS_TABLE_PREFIX`: tiền tố bảng của WordPress (mặc định `wpstack_`). **Quan trọng khi import site có sẵn**: phải đặt đúng tiền tố của database cũ (thường là `wp_`), nếu không WordPress sẽ không thấy bảng và hiện màn hình cài đặt mới.

---

# Cài đặt plugin quản lý cache và redis
Mặc định thì init.sh đã thêm aliases wp-cli để rút ngắn câu lệnh, nhưng nếu không có thể  chay lệnh sau(chú ý thoát ssh và login lại để load biến môi trường mới hoặc dùng lệnh soucre để áp dụng biến môi trường lập tức)
```
echo 'alias wpcli="docker exec -ti -u www-data wordpress_instance wp"' >> ~/.bash_aliases
```
Sau đó có thể gọi lệnh wpcli từ bất kỳ đâu, chạy tức thì (docker exec vào container đang chạy, không tạo container mới)
```
# các plugin nên cài
wpcli plugin install redis-cache --activate
wpcli plugin install flying-fonts --activate
wpcli plugin install flying-scripts --activate
wpcli plugin install flying-pages --activate
# QUAN TRỌNG với theme có đếm view (ví dụ Newspaper): phải bật chế độ đếm qua
# AJAX để số view vẫn tăng khi trang nằm trong cache 30 phút:
wpcli eval 'td_util::update_option("tds_ajax_post_view_count", "enabled");'
# BẮT BUỘC cài nginx-helper: nginx cache trang 30 phút (fastcgi_cache_valid 30m),
# plugin này sẽ purge cache tự động ngay khi nội dung thay đổi:
wpcli plugin install nginx-helper --activate
# Bật purge trong nginx-helper (mặc định plugin tắt purge):
wpcli option update rt_wp_nginx_helper_options '{"enable_purge":1,"cache_method":"enable_fastcgi","purge_method":"get_request","purge_homepage_on_edit":1,"purge_homepage_on_del":1,"purge_archive_on_edit":1,"purge_archive_on_del":1,"purge_archive_on_new_comment":0,"purge_archive_on_deleted_comment":0,"purge_page_on_mod":1,"purge_page_on_new_comment":1,"purge_page_on_deleted_comment":1,"enable_map":0,"enable_log":0,"enable_stamp":0,"purge_url":"","redis_hostname":"127.0.0.1","redis_port":"6379","redis_prefix":"nginx-cache:"}' --format=json
```

# Purge cache trang (fastcgi cache)
Bốn cách, từ tự động đến thủ công:
1. **Tự động** — nginx-helper purge ngay khi có thay đổi nội dung (sửa/đăng/xoá bài, bình luận mới). Đã cấu hình ở phần cài plugin phía trên, không cần làm gì thêm.
2. **Từ trang admin** — nginx-helper thêm nút **Purge Cache** trên thanh admin bar của WordPress (purge toàn bộ).
3. **Purge 1 URL từ terminal** — cú pháp `/purge/<đường-dẫn-trang>`, mỗi lần xoá đúng một URL (`/purge/` không có gì phía sau chỉ xoá cache trang chủ, KHÔNG phải xoá toàn bộ):
```
docker exec wordpress_instance curl -sk "https://<domain>/purge/<duong-dan-trang>/"
```
Lưu ý phải gọi **qua container** như trên. Endpoint `/purge/` chỉ cho phép IP nội bộ — curl thẳng từ host ra domain sẽ bị `403 Forbidden` vì hairpin NAT của Docker làm nginx thấy IP nguồn là IP public của host, bị coi như client ngoài internet (đây là chủ đích, để người ngoài không phá được cache).
4. **Purge toàn bộ từ terminal** — xoá thẳng file cache trong tmpfs, hiệu lực tức thì, không cần reload nginx:
```
docker exec nginx find /run/nginx-cache -type f -delete
```
Cache nằm trên tmpfs (RAM) nên restart container nginx (ví dụ sau mỗi lần `update.sh` recreate) cũng đồng nghĩa purge toàn bộ.

# Backup & Restore
Backup tự động đã được init.sh thêm vào cron: **01:30 hằng ngày** (database + config per-VM) và **03:00 Chủ nhật** (`full`: thêm mã nguồn/uploads). File lưu tại `backups/` (gitignored), tự xoá bản cũ (mặc định giữ 7 ngày với db/config, 28 ngày với html — đổi qua biến `BACKUP_KEEP_DAYS`, `BACKUP_KEEP_DAYS_FULL`).

Chạy tay khi cần (ví dụ trước khi update lớn):
```
./backup.sh        # database + config
./backup.sh full   # thêm mã nguồn/uploads
```
Dump database dùng `--single-transaction` nên không lock site đang chạy.

Restore — truyền file backup, loại được nhận diện theo tên, mỗi bước hỏi xác nhận, riêng restore db sẽ tự dump bản hiện tại ra `db-prerestore-*` trước khi ghi đè:
```
./restore.sh backups/db-2026-07-05_01-30-00.sql.gz
./restore.sh backups/html-....tar.gz backups/config-....tar.gz
```
Sau restore db, script tự flush Redis object cache và purge page cache (bắt buộc, nếu không site sẽ đọc dữ liệu cũ từ cache). Lưu ý `WORDPRESS_TABLE_PREFIX` trong `.env` phải khớp prefix trong file dump.

**Cảnh báo:** backup đang nằm cùng máy — nên đồng bộ thư mục `backups/` ra ngoài (rclone lên S3/B2/Drive hoặc rsync sang máy khác) để sống sót khi mất VM.

# Thêm cron gia hạn SSL mỗi ngày vào 2h sáng
Mặc định init.sh đã thêm cron gia hạn ssl tự động, nếu vì lý do gì đó bị mất  thì có thể thiết lập lại cron như sau:
```
0 2 * * * bash /pathtofile/ssl_renew.sh >/dev/null 2>&1
```
Script gia hạn dùng `nginx -s reload` (không phải restart) nên không gây downtime.

# Xoay vòng log nginx
init.sh đã cài cấu hình logrotate tại `/etc/logrotate.d/nginx-docker` để log trong thư mục `logs/` không phình vô hạn (giữ 14 ngày, nén lại). Nếu cần cài lại thủ công, xem mẫu tại `conf/logrotate/nginx-docker`.

---

# Cập nhật stack khi repo có phiên bản mới
Chạy script có sẵn:
```
./update.sh                 # pull image dựng sẵn từ GHCR (nhanh, khuyến nghị)
UPDATE_BUILD=1 ./update.sh  # hoặc build image ngay trên máy
```
Script sẽ: `git pull` → render lại file cấu hình site từ template (`conf/nginx/site.conf.template` → `conf.d/<domain>.conf`) → pull/build image → `docker compose up -d` (chỉ recreate container có thay đổi) → dọn image cũ.

Image được CI build và push lên `ghcr.io/todo1991/*` **chỉ khi** đã qua đủ lint + build + `nginx -t`. Lần đầu dùng cần vào GitHub → Packages → đặt visibility của 2 package thành **Public** (hoặc `docker login ghcr.io` trên VM bằng PAT có quyền `read:packages`).

# Tuỳ chỉnh riêng cho từng máy (không bị ghi đè khi update)
Mọi tuỳ chỉnh per-VM đặt ở các file **ngoài git** — `git pull`/`update.sh` không bao giờ đụng tới:

| Lớp | File trên máy | Cơ chế |
|---|---|---|
| Compose (port, RAM, env...) | `docker-compose.override.yml` | Docker Compose tự merge đè — xem mẫu `docker-compose.override.yml.example` |
| MariaDB | `conf/mariadb/zz-local.cnf` | Load sau `mariadbcustom.cnf` theo alphabet, giá trị sau đè giá trị trước |
| Nginx (trong server block) | `conf/nginx/conf.d/local/*.conf` | Template include `conf.d/local/*.conf` ở cuối server block |
| Nginx (mức http) | `conf/nginx/conf.d/*.conf` | `nginx.conf` include sẵn toàn bộ thư mục |
| Secret testcookie | `conf/nginx/conf.d/local/00-testcookie-secret.conf` | init.sh tự sinh, mỗi máy một secret riêng |

Ví dụ giảm buffer pool cho máy ít RAM — tạo `conf/mariadb/zz-local.cnf`:
```ini
[mariadb]
innodb_buffer_pool_size=512M
```
rồi `docker compose up -d` (mariadb sẽ tự recreate).

---

# Hướng dẫn trường hợp đã có mã nguồn và muốn dùng bộ compose này
***Thực hiện các bước 1, 2 như site mới, KHÔNG thực hiện bước 3.***

**Quan trọng nhất — trước khi tiếp tục, sửa `.env`:** đặt `WORDPRESS_TABLE_PREFIX` đúng với tiền tố bảng trong file dump của bạn (site cũ thường là `wp_`). Sai bước này WordPress sẽ không thấy dữ liệu và hiện màn hình cài đặt mới.

Sau đó đưa dữ liệu cũ về định dạng backup chuẩn rồi dùng `restore.sh` (cùng công cụ với backup/restore thường ngày — có safety dump, tự flush Redis và purge cache):
```
# loại wp-config.php cũ (mang credentials của server cũ);
# container sẽ tự sinh bản mới từ .env
rm -f your_code/wp-config.php

mkdir -p backups
gzip -c database.sql > backups/db-migrate.sql.gz
tar czf backups/html-migrate.tar.gz -C ./your_code .

# restore cả hai (db cần mariadb đang chạy)
docker compose up -d mariadb
./restore.sh backups/db-migrate.sql.gz backups/html-migrate.tar.gz

# khởi động toàn bộ và kiểm tra
docker compose up -d
```

Nếu domain mới **khác** domain cũ — bắt buộc thay URL trong database, nếu không site sẽ redirect về domain cũ:
```
wpcli search-replace 'https://domain-cu.com' 'https://domain-moi.com' --all-tables
wpcli cache flush
wpcli option get siteurl   # phải ra domain mới
```

## License
This project is licensed under the [MIT License](LICENSE).

