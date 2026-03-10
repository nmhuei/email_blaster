# 📧 Email Blaster

Script gửi email hàng loạt qua **SendGrid API** bằng Bash.

## Tính năng
- Cấu hình qua `.env`
- CLI options linh hoạt
- Retry khi gửi lỗi tạm thời
- `--dry-run` để test an toàn
- Hỗ trợ file đính kèm
- Hỗ trợ template ngoài:
  - HTML: `--template`
  - Text fallback: `--text-template` (tăng deliverability)
- Ghi log kết quả theo phiên chạy

---

## 1) Yêu cầu
- `bash`
- `curl`
- `python3`
- SendGrid API key + sender email đã verify

---

## 2) Setup nhanh

```bash
cd email_blaster
cp .env.example .env
cp recipients.example.txt recipients.txt
chmod +x send_email.sh
```

Sửa file `.env`:

```env
SENDGRID_API_KEY=SG.your_real_sendgrid_key
SENDER_EMAIL=you@yourdomain.com
SENDER_NAME=Your Name
```

Sửa file `recipients.txt` theo format:

```txt
Name|email@example.com|Company
```

---

## 3) Cách chạy

### Chạy cơ bản
```bash
./send_email.sh
```

### Chạy với option
```bash
./send_email.sh \
  --recipients recipients.txt \
  --subject "Thông báo tuần này" \
  --attachment ./docs/file.pdf \
  --delay 1 \
  --retries 3
```

### Dry-run (không gửi thật)
```bash
./send_email.sh --dry-run
```

### Dùng env file custom
```bash
./send_email.sh --env .env.production
```

---

## 4) Dùng template ngoài

### HTML template
```bash
./send_email.sh --template template.example.html
```

### HTML + text fallback (khuyến nghị)
```bash
./send_email.sh \
  --template template.example.html \
  --text-template template_text.example.txt
```

### Placeholders hỗ trợ
- `{{name}}`
- `{{email}}`
- `{{company}}`
- `{{sender_name}}`
- `{{year}}`

---

## 5) Bảo mật
- Không commit API key thật
- Không commit danh sách email thật
- Kiểm tra `.gitignore` trước khi push

---

## 6) Troubleshooting nhanh
- `Invalid SENDGRID_API_KEY` → kiểm tra key trong `.env`
- `Recipients file not found` → kiểm tra path `--recipients`
- Không gửi được → test trước bằng `--dry-run`, sau đó check log `email_log_*.txt`
