# 📧 Email Blaster

Bulk sender qua SendGrid bằng Bash, có hỗ trợ:
- `.env` config
- CLI options
- retry khi lỗi tạm thời
- dry-run
- đính kèm file
- log kết quả

## 1) Setup

```bash
cd email_blaster
cp .env.example .env
cp recipients.example.txt recipients.txt
# sửa .env + recipients.txt theo dữ liệu thật
chmod +x send_email.sh
```

## 2) Chạy nhanh

```bash
./send_email.sh
```

## 3) Tùy chọn CLI

```bash
./send_email.sh \
  --recipients recipients.txt \
  --subject "Thông báo tuần này" \
  --attachment ./docs/file.pdf \
  --delay 1 \
  --retries 3
```

Dry-run (không gửi thật):

```bash
./send_email.sh --dry-run
```

Dùng env file custom:

```bash
./send_email.sh --env .env.production
```

## 4) Định dạng recipients

Mỗi dòng:

```txt
Name|email@example.com|Company
```

- Dòng bắt đầu bằng `#` sẽ bị bỏ qua
- Dòng trống sẽ bị bỏ qua
- Company có thể để trống

## 5) Lưu ý bảo mật

- Không commit API key thật
- Không commit danh sách email thật
- Kiểm tra `.gitignore` trước khi push
