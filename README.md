# 📖 Trợ lý AI & Bộ gõ UniKey Telex cho reMarkable

Bộ công cụ mã nguồn mở giúp tích hợp **Trợ lý AI đa mô hình** (Anthropic Claude, Google Gemini, OpenAI ChatGPT) cùng **Bộ gõ tiếng Việt UniKey Telex** trực tiếp trên màn hình máy đọc sách reMarkable.

* Hoạt động độc lập, không cần duy trì kết nối cáp USB khi đọc sách.
* Không yêu cầu cài đặt Python hay mở cổng mạng phức tạp trên thiết bị.
* Tự động nhận diện và tối ưu kích thước cửa sổ giao diện (Adaptive UI) cho mọi dòng máy: *reMarkable 1, reMarkable 2, reMarkable Paper Pro, Paper Pure và Paper Move*.
* Tích hợp đồng thời Sổ tay đọc lại lịch sử chat tức thì và khả năng đóng gói sách **EPUB / PDF** thật vào danh mục *My Files*.

---

## ✨ Tính năng nổi bật

### 1. Trợ lý AI đa nền tảng
* **Tương thích toàn diện:** Hỗ trợ đầy đủ các dòng mô hình tiên tiến như Claude (Sonnet 4, 3.7 Sonnet, 3.5 Haiku), Google Gemini (2.5 Pro, 2.5 Flash, 2.0 Flash) và OpenAI (GPT-4o, GPT-4o Mini).
* **Quét tự động:** Cập nhật danh sách mô hình trực tuyến tức thời từ API của các nhà cung cấp.
* **Tự động chuyển đổi dự phòng (Auto-Fallback):** Tự động chuyển sang mô hình miễn phí khi tài khoản hết hạn mức hoặc token.
* **Bộ lọc và Hộp kiểm linh hoạt:** Cho phép tìm kiếm theo từ khóa, lọc theo nhà cung cấp và bật/tắt từng mô hình xuất hiện ở cửa sổ chat chính thông qua hộp kiểm `[✓]`.

### 2. Bộ gõ UniKey Telex thông minh
* **Chuẩn hóa đặt dấu tiếng Việt:** Tự động định vị vị trí dấu thanh theo quy tắc chuẩn (*toans ➔ toán, duwowngj ➔ dượng, tw ➔ tư*).
* **Gõ lặp 2 lần hủy dấu về tiếng Anh:** Hoàn tác ký tự về nguyên bản tiếng Anh khi gõ lặp phím dấu (*toans + s ➔ toans, is + s ➔ is, aa + a ➔ aa, tw + w ➔ tw*).
* **Bàn phím ảo trực quan:** Bổ sung hàng phím số 0-9 và trang ký tự đặc biệt `#+=`.

### 3. Lưu trữ & Xuất tài liệu (Cơ chế kép)
* **Sổ tay QML nội bộ:** Lưu trữ lịch sử hỏi đáp vào cơ sở dữ liệu SQLite ngay trên máy; mở đọc lại toàn màn hình bất kỳ lúc nào mà không cần thoát cuốn sách đang đọc.
* **Kết xuất EPUB & PDF vào My Files:** Đóng gói phiên trò chuyện thành tệp tài liệu `.epub` hoặc `.pdf` hoàn chỉnh trong mục *My Files* để đọc và viết tay ghi chú bằng bút Marker.

---

## 🔑 Hướng dẫn lấy mã API Key

Bạn chỉ cần chuẩn bị **ít nhất 1 trong 3** mã API Key dưới đây (khuyến nghị dùng **Google Gemini** nếu muốn sử dụng gói miễn phí tốc độ cao):

### 1. Google Gemini API *(Có gói Miễn phí)*
1. Truy cập trang [Google AI Studio](https://aistudio.google.com/app/apikey) và đăng nhập bằng tài khoản Google.
2. Nhấn nút **`Create API key`** ở góc trên bên phải.
3. Sao chép chuỗi mã bắt đầu bằng `AIzaSy...` để dùng trong bước cài đặt.

### 2. Anthropic Claude API *(Trả phí theo dung lượng)*
1. Truy cập [Anthropic Console](https://console.anthropic.com/settings/keys) và đăng nhập tài khoản.
2. Đảm bảo tài khoản đã nạp sẵn hạn mức tín dụng (Credits) tại mục **Billing**.
3. Nhấn **`Create Key`**, đặt tên bất kỳ và sao chép chuỗi mã bắt đầu bằng `sk-ant-...`.

### 3. OpenAI ChatGPT API *(Trả phí theo dung lượng)*
1. Truy cập [OpenAI Platform API Keys](https://platform.openai.com/api-keys) và đăng nhập.
2. Đảm bảo tài khoản đã nạp sẵn hạn mức tại mục **Settings ➔ Billing**.
3. Nhấn **`+ Create new secret key`** và sao chép chuỗi mã bắt đầu bằng `sk-proj-...` (hoặc `sk-...`).

---

## 🛠 Hướng dẫn cài đặt (Zero-Touch 1-Click)

Bộ cài đặt thế hệ mới sẽ **tự động kiểm tra và cài đặt nền tảng Vellum/XOVI**, tự động nạp các gói phụ thuộc, quét bảng băm (`Rebuild Hashtable`) và khởi chạy giao diện ngay trong một lần chạy duy nhất mà không cần dùng thêm phần mềm thứ ba.

### Bước 0: Chuẩn bị thiết bị (Chỉ mất 1 phút)

1. **Kết nối Wi-Fi cho reMarkable:** Mở máy, vào **Settings** ➔ **Wi-Fi** và kết nối mạng Internet *(để thiết bị có thể tự động tải gói Vellum và các thư viện phụ thuộc)*.
2. **Kết nối cáp USB** giữa reMarkable và máy tính.
3. **Bật USB Web Interface & Lấy mật khẩu SSH:**
   * Vào **Settings** ➔ **Storage** ➔ Bật **USB web interface**.
   * Vào **Settings** ➔ **Help** ➔ **Copyrights and licenses**.
   * Kéo xuống cuối trang để lấy thông tin **Password** SSH của máy *(Địa chỉ IP kết nối qua USB mặc định là `10.11.99.1`, tài khoản: `root`)*.
   * *Lưu ý: Nếu bạn đang mở phần mềm **reManager** trên máy tính, hãy đóng ứng dụng đó trước khi chạy lệnh cài đặt để tránh xung đột cổng SSH.*

---

### Bước 1: Thực thi lệnh cài đặt từ máy tính

Giữ kết nối cáp USB giữa máy tính và reMarkable, sau đó mở cửa sổ dòng lệnh tương ứng:

#### 🔹 Dành cho máy tính Windows (PowerShell):
1. Nhấn tổ hợp phím `Windows + X` và chọn **Terminal** (hoặc mở **PowerShell**).
2. Sao chép và dán lệnh sau rồi nhấn `Enter`:

```powershell
irm https://raw.githubusercontent.com/ntatpc/remarkable-ai-vn/main/install.ps1 | iex
```

3. Nhập mật khẩu SSH của máy (ở lần cài đặt đầu tiên), chọn dòng máy reMarkable của bạn (hoặc nhấn `Enter` để tự động nhận diện) và dán các mã **API Key** (hoặc nhập `n` để bỏ qua).

#### 🔹 Dành cho máy tính macOS & Linux (Terminal):
1. Nhấn `Command + Space`, gõ `Terminal` và nhấn `Enter`.
2. Sao chép và dán lệnh sau rồi nhấn `Enter`:

```bash
curl -fsSL https://raw.githubusercontent.com/ntatpc/remarkable-ai-vn/main/install.sh | bash
```

*(Hoặc trên macOS, bạn có thể tải tệp `install.command` về máy, cấp quyền `chmod +x install.command` và nhấp đúp chuột để chạy trực tiếp).*

3. Làm theo hướng dẫn tương tác trên màn hình để cấu hình dòng máy và các khóa API. Toàn bộ quá trình cài đặt Vellum, Rebuild Hashtable và nạp giao diện sẽ tự động hoàn tất 100%.

---

## 🚀 Hướng dẫn thao tác trên máy

* **Khởi động Trợ lý AI:** Chạm vào biểu tượng nút nổi **AI** ở góc dưới cùng bên phải màn hình khi đang đọc sách.
* **Tra cứu nhanh đoạn văn bản:** Bôi đen đoạn chữ bất kỳ trong tài liệu, thanh công cụ ngữ cảnh sẽ hiển thị các nút thao tác: *✦ Hỏi AI*, *Giải thích*, *Dịch TV*.
* **Tra cứu Sổ tay:** Nhấn nút **`📚 Sổ tay`** trên thanh tiêu đề để mở danh sách toàn bộ các phiên trò chuyện đã lưu.
* **Xuất sách EPUB / PDF:** Nhấn nút **`Lưu / Xuất ▾`** ➔ Chọn định dạng **`.EPUB`** hoặc **`.PDF`** để lưu trực tiếp vào *My Files*.
* **Tùy chỉnh mô hình & Bộ lọc:** Nhấn nút **`⚙ Cài đặt`** để tìm kiếm mô hình, lọc theo nhà cung cấp hoặc bật/tắt các mô hình theo nhu cầu.
* **Khôi phục nhanh sau khi khởi động lại máy:** Chạm 3 lần liên tiếp vào nút nguồn (Triple-Tap) hoặc kích hoạt lại XOVI, cả nút AI và dịch vụ xuất tài liệu sẽ tự động hoạt động trở lại.

---

## 📄 Giấy phép (License)

Dự án được phát hành mã nguồn mở theo các điều khoản của giấy phép [MIT License](LICENSE).
