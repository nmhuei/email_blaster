# 📧 Email Blaster

Script Bash gửi email tự động hàng loạt qua **SendGrid API** — hỗ trợ HTML email, đính kèm file, cá nhân hóa theo tên/công ty, và ghi log đầy đủ.

```
  ███████╗███╗   ███╗ █████╗ ██╗██╗
  ██╔════╝████╗ ████║██╔══██╗██║██║
  █████╗  ██╔████╔██║███████║██║██║
  ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  BLASTER
```

---

## 📋 Yêu cầu hệ thống

| Công cụ | Phiên bản | Cài đặt |
|---------|-----------|---------|
| `bash` | 4.0+ | Có sẵn trên Linux/macOS |
| `curl` | bất kỳ | `sudo apt install curl` |
| `python3` | 3.x | `sudo apt install python3` |

---

## 🔑 Cấu hình SendGrid API Key

### Bước 1 — Tạo tài khoản SendGrid
Đăng ký miễn phí tại [sendgrid.com](https://sendgrid.com) (100 email/ngày free).

### Bước 2 — Lấy API Key
1. Đăng nhập → vào **Settings** → **API Keys**
2. Nhấn **Create API Key**
3. Chọn quyền **Restricted Access** → bật **Mail Send**
4. Copy key (dạng `SG.xxxxxxxx...`)

### Bước 3 — Verify email người gửi
1. Vào **Settings** → **Sender Authentication**
2. Chọn **Single Sender Verification** → điền email của bạn
3. Xác nhận qua email đó

### Bước 4 — Điền vào script

Mở file `send_email.sh` và chỉnh 3 dòng đầu:

```bash
SENDGRID_API_KEY="SG.your_actual_key_here"   # ← API key từ bước 2
SENDER_EMAIL="you@yourdomain.com"             # ← Email đã verify bước 3
SENDER_NAME="Nguyễn Văn A"                   # ← Tên hiển thị
```

> ⚠️ **Không bao giờ** commit API key lên Git — xem phần `.gitignore` bên dưới.

---

## 📄 Cấu hình `recipients.txt`

### Định dạng

```
TenNguoiNhan|email@example.com|TenCongTy
```

Mỗi dòng là **một người nhận**, các trường phân cách bằng dấu `|`.

### Ví dụ

```
# Đây là dòng comment, sẽ bị bỏ qua
# Định dạng: Ten|Email|CongTy

Nguyen Van A|nguyenvana@gmail.com|Cong ty ABC
Tran Thi B|tranthib@company.vn|Startup XYZ
Le Van C|levanc@outlook.com|Freelancer
```

### Quy tắc

| Quy tắc | Mô tả |
|---------|-------|
| Dòng bắt đầu bằng `#` | Bị bỏ qua (comment) |
| Dòng trống | Bị bỏ qua tự động |
| Trường `CongTy` | Có thể để trống, mặc định là `N/A` |
| Khoảng trắng thừa | Được tự động trim |

### Placeholder trong email

Trong phần `build_html_body()` của script, bạn có thể dùng các biến sau để cá nhân hóa:

| Biến | Nội dung |
|------|----------|
| `${name}` | Tên người nhận |
| `${email}` | Địa chỉ email |
| `${company}` | Tên công ty |
| `${SENDER_NAME}` | Tên người gửi |

---

## 📎 Đính kèm file (tuỳ chọn)

Điền đường dẫn file vào biến `ATTACHMENT_FILE`:

```bash
ATTACHMENT_FILE="/path/to/tailieu.pdf"
```

Để trống nếu không cần đính kèm:

```bash
ATTACHMENT_FILE=""
```

> Script hỗ trợ mọi định dạng file: PDF, DOCX, XLSX, ZIP, PNG...

---

## 🚀 Cách chạy

```bash
# Cấp quyền thực thi (chỉ cần làm 1 lần)
chmod +x send_email.sh

# Chạy script
./send_email.sh
```

### Output mẫu

```
  ███████╗███╗   ███╗ █████╗ ██╗██╗
  ...

  ◆ Kiểm tra môi trường
  ────────────────────────────────
    ✔ OK  curl 8.5.0
    ✔ OK  python3 3.11.4
    ✔ OK  Danh sách: recipients.txt (3 người nhận)
    ✔ OK  SendGrid API Key SG.abc123...

  ◆ Bắt đầu gửi — 3 người nhận
  ────────────────────────────────
  [██████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  33% (1/3)
  ▶  Nguyen Van A  nguyenvana@gmail.com  [Cong ty ABC]
    ✔ OK  Gửi thành công → nguyenvana@gmail.com
```

---

## 📁 Cấu trúc thư mục

```
email-blaster/
├── send_email.sh        # Script chính
├── recipients.txt       # Danh sách người nhận
├── .env.example         # Mẫu biến môi trường
├── .gitignore           # Bảo vệ thông tin nhạy cảm
├── README.md            # Tài liệu này
└── email_log_*.txt      # Log tự động sinh ra (không commit)
```

---

## 📊 File log

Sau mỗi lần chạy, script tự tạo file log tên `email_log_YYYYMMDD_HHMMSS.txt`:

```
2025-01-15 09:30:01  [INFO]  Danh sách: recipients.txt (3 người nhận)
2025-01-15 09:30:02  [OK]    Gửi thành công → nguyenvana@gmail.com
2025-01-15 09:30:04  [OK]    Gửi thành công → tranthib@company.vn
2025-01-15 09:30:05  [FAIL]  Gửi thất bại  → levanc@outlook.com
════════════════════════════════════
KẾT QUẢ: Tổng=3 | OK=2 | Lỗi=1 | 6s
════════════════════════════════════
```

---

## ⚙️ Tuỳ chỉnh nâng cao

### Thay đổi tiêu đề email

```bash
EMAIL_SUBJECT="Thông báo tháng 1/2025 từ Công ty ABC"
```

### Thay đổi delay giữa các lần gửi

```bash
DELAY_SECONDS=2   # Tăng lên nếu bị giới hạn rate limit
```

### Chỉnh nội dung HTML

Tìm dòng comment trong `build_html_body()`:

```bash
# ✏️  CHỈNH SỬA NỘI DUNG EMAIL TẠI ĐÂY
```

Và sửa HTML bên dưới theo ý muốn.

---

## 🔒 Bảo mật

- **Không commit** file `recipients.txt` nếu chứa email thật
- **Không commit** API key — dùng biến môi trường hoặc file `.env`
- Xem thêm cấu hình `.gitignore` bên dưới

---

## 📄 License

MIT — Tự do sử dụng và chỉnh sửa.
