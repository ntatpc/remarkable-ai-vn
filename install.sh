#!/bin/bash
# =============================================================================
# KỊCH BẢN CÀI ĐẶT TRỢ LÝ AI & UNIKEY TELEX CHO REMARKABLE (macOS / LINUX)
# Kiến trúc: Single-Session SSH (Chống 100% lỗi Connection reset của Dropbear)
# =============================================================================
set -e

GITHUB_RAW_BASE="https://raw.githubusercontent.com/ntatpc/remarkable-ai-vn/main"
RM_IP="10.11.99.1"

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m'

SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519"
SSH_FLAGS="-i $KEY_FILE -o IdentitiesOnly=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

WORK_TMP="$(mktemp -d 2>/dev/null || mktemp -d -t 'rm_ai_install')"
trap 'rm -rf "$WORK_TMP"' EXIT

clear
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}   CAI DAT TRO LY AI & UNIKEY TELEX CHO REMARKABLE (macOS/LINUX)${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "${GRAY}   Luu y: Hay dong phan mem reManager (neu dang mo) truoc khi chay!${NC}"
echo ""

# =============================================================================
# BƯỚC 1/4: KIỂM TRA KẾT NỐI USB & KHÓA SSH (PHÂN BIỆT RÕ LỖI RESET VÀ THIẾU KEY)
# =============================================================================
echo -e "${YELLOW}[1/4] Kiem tra ket noi USB & Khoa SSH ($RM_IP)...${NC}"
if ! ping -c 1 -W 2 "$RM_IP" >/dev/null 2>&1; then
    echo -e "${RED}[!] LOI: Khong the ket noi toi $RM_IP.${NC}"
    echo -e "${YELLOW}    -> Hay cam cap USB va bat 'USB web interface' trong Settings -> Storage.${NC}"
    exit 1
fi

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
ssh-keygen -R "$RM_IP" >/dev/null 2>&1 || true

if [ ! -f "${KEY_FILE}.pub" ]; then
    echo -e "${GRAY}      -> Dang tao cap khoa SSH ed25519 moi tren may tinh...${NC}"
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -q
fi
PUB_KEY="$(tr -d '\r\n' < "${KEY_FILE}.pub")"

# Thử kết nối bằng Key tối đa 5 lần nếu gặp lỗi Connection reset do Dropbear đang bận
HAS_KEY=0
NEED_PASSWORD=0
RAW_HW=""
for try_i in 1 2 3 4 5; do
    PROBE_OUT="$(ssh $SSH_FLAGS -o BatchMode=yes "root@$RM_IP" "echo OK_AUTH ; cat /sys/devices/soc0/machine /proc/device-tree/model 2>/dev/null | tr -d '\0\r\n'" 2>&1 || true)"
    if echo "$PROBE_OUT" | grep -q "OK_AUTH"; then
        HAS_KEY=1
        RAW_HW="$(echo "$PROBE_OUT" | sed -n 's/.*OK_AUTH[[:space:]]*//p' | tr -d '\r\n')"
        if [ -z "$RAW_HW" ]; then
            RAW_HW="$(echo "$PROBE_OUT" | sed -n '/OK_AUTH/{n;p;}' | tr -d '\r\n')"
        fi
        break
    elif echo "$PROBE_OUT" | grep -qi "Permission denied"; then
        NEED_PASSWORD=1
        break
    else
        echo -e "${GRAY}      -> Cong SSH tren reMarkable dang ban (Connection reset), dang doi 3 giay ($try_i/5)...${NC}"
        sleep 3
    fi
done

if [ "$HAS_KEY" -ne 1 ]; then
    echo ""
    echo -e "${YELLOW}      ==========================================================${NC}"
    echo -e "${YELLOW}      THIET BI CHUA CO KHOA SSH! VUI LONG NHAP MAT KHAU SSH:${NC}"
    echo -e "${CYAN}      (Xem tai: Settings -> Help -> Copyrights and licenses)${NC}"
    echo -e "${GRAY}      Luu y: Khi go mat khau tren man hinh se khong hien ky tu.${NC}"
    echo -e "${YELLOW}      ==========================================================${NC}"

    SETUP_KEY_CMD="chmod 755 /home/root ; mkdir -p /home/root/.ssh ; chmod 700 /home/root/.ssh ; touch /home/root/.ssh/authorized_keys ; grep -qF '$PUB_KEY' /home/root/.ssh/authorized_keys || echo '$PUB_KEY' >> /home/root/.ssh/authorized_keys ; chmod 600 /home/root/.ssh/authorized_keys"

    KEY_INSTALLED=0
    for k_try in 1 2 3 4; do
        sleep 3
        if ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password -o ConnectTimeout=15 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "root@$RM_IP" "$SETUP_KEY_CMD"; then
            KEY_INSTALLED=1
            break
        fi
        echo -e "${GRAY}      -> Ket noi SSH bi ngat hoac sai mat khau, thu lai sau 3 giay ($k_try/4)...${NC}"
    done

    if [ "$KEY_INSTALLED" -ne 1 ]; then
        echo -e "${RED}[!] LOI: Khong the nap khoa SSH. Hay dong reManager (neu dang mo) hoac khoi dong lai reMarkable roi chay lai!${NC}"
        exit 1
    fi
    sleep 3
fi
echo -e "${GREEN}      ✓ Ket noi USB va Khoa SSH da san sang!${NC}"

# Kiểm tra xem máy đã có Vellum chưa và đã kết nối Wi-Fi (Internet) chưa
ENV_CHECK="$(ssh $SSH_FLAGS -o LogLevel=ERROR "root@$RM_IP" "if [ -d /home/root/.vellum ]; then echo 'HAS_VELLUM'; else echo 'NO_VELLUM'; fi; if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 3 github.com >/dev/null 2>&1; then echo 'NET_OK'; else echo 'NO_NET'; fi" 2>/dev/null || true)"

if echo "$ENV_CHECK" | grep -q "NO_VELLUM"; then
    echo -e "${CYAN}      [!] Phat hien thiet bi chua cai dat Vellum -> Script se tu dong cai dat Vellum!${NC}"
fi

while echo "$ENV_CHECK" | grep -q "NO_NET"; do
    echo ""
    echo -e "${RED}      [!] CANH BAO: reMarkable chua co ket noi Internet (Wi-Fi)!${NC}"
    echo -e "${YELLOW}          Vui long mo Settings -> Wi-Fi tren reMarkable va ket noi mang.${NC}"
    printf "          Sau khi da bat Wi-Fi tren may doc sach, nhan [Enter] de kiem tra lai: "
    read -r _ < /dev/tty || true

    ENV_CHECK="$(ssh $SSH_FLAGS -o LogLevel=ERROR "root@$RM_IP" "if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 3 github.com >/dev/null 2>&1; then echo 'NET_OK'; else echo 'NO_NET'; fi" 2>/dev/null || true)"
done
echo -e "${GREEN}      ✓ Ket noi Internet (Wi-Fi) tren reMarkable da san sang!${NC}"

# =============================================================================
# BƯỚC 2/4: CHỌN DÒNG MÁY & NHẬP API KEY (KHÔNG MỞ THÊM PHIÊN SSH NÀO)
# =============================================================================
echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}   CHON THIET BI REMARKABLE & CAU HINH API KEY                  ${NC}"
echo -e "${CYAN}================================================================${NC}"

if [ -z "$RAW_HW" ]; then RAW_HW="Auto-Detect"; fi

echo -e "${GRAY}   Phan cung phat hien: $RAW_HW${NC}"
echo "   [1] reMarkable 1"
echo "   [2] reMarkable 2"
echo "   [3] reMarkable Paper Pro"
echo "   [4] reMarkable Paper Pure"
echo "   [5] reMarkable Paper Move"
printf "Chon dong may cua ban [1-5 hoac nhan Enter de tu dong]: "
read -r DEV_CHOICE < /dev/tty || DEV_CHOICE=""

DEVICE_MODEL_NAME="reMarkable Paper Pro"
CUSTOM_WIN_WIDTH="1320"
CUSTOM_WIN_HEIGHT="1880"

if [ "$DEV_CHOICE" = "1" ] || { [ -z "$DEV_CHOICE" ] && echo "$RAW_HW" | grep -Eq "1\.0"; }; then
    DEVICE_MODEL_NAME="reMarkable 1"; CUSTOM_WIN_WIDTH="1080"; CUSTOM_WIN_HEIGHT="1580"
elif [ "$DEV_CHOICE" = "2" ] || { [ -z "$DEV_CHOICE" ] && echo "$RAW_HW" | grep -Eq "2\.0"; }; then
    DEVICE_MODEL_NAME="reMarkable 2"; CUSTOM_WIN_WIDTH="1100"; CUSTOM_WIN_HEIGHT="1620"
elif [ "$DEV_CHOICE" = "3" ] || { [ -z "$DEV_CHOICE" ] && echo "$RAW_HW" | grep -Eqi "Ferrari|Pro|tatsu|imx93"; }; then
    DEVICE_MODEL_NAME="reMarkable Paper Pro"; CUSTOM_WIN_WIDTH="1320"; CUSTOM_WIN_HEIGHT="1880"
elif [ "$DEV_CHOICE" = "4" ]; then
    DEVICE_MODEL_NAME="reMarkable Paper Pure"; CUSTOM_WIN_WIDTH="1100"; CUSTOM_WIN_HEIGHT="1620"
elif [ "$DEV_CHOICE" = "5" ] || { [ -z "$DEV_CHOICE" ] && echo "$RAW_HW" | grep -Eqi "Move"; }; then
    DEVICE_MODEL_NAME="reMarkable Paper Move"; CUSTOM_WIN_WIDTH="960"; CUSTOM_WIN_HEIGHT="1420"
fi
echo -e "${GREEN}      ✓ Da chon: $DEVICE_MODEL_NAME (Khung chat: ${CUSTOM_WIN_WIDTH}x${CUSTOM_WIN_HEIGHT})${NC}"
echo ""

printf "1. Tich hop Google Gemini API? [Dan ma hoac 'n' de bo qua]: "
read -r INPUT_GEMINI < /dev/tty || INPUT_GEMINI=""
INPUT_GEMINI="$(echo "$INPUT_GEMINI" | tr -d '\r\n ')"
if [ "$INPUT_GEMINI" = "n" ] || [ "$INPUT_GEMINI" = "N" ]; then INPUT_GEMINI=""; fi

printf "2. Tich hop Anthropic Claude API? [Dan ma hoac 'n' de bo qua]: "
read -r INPUT_CLAUDE < /dev/tty || INPUT_CLAUDE=""
INPUT_CLAUDE="$(echo "$INPUT_CLAUDE" | tr -d '\r\n ')"
if [ "$INPUT_CLAUDE" = "n" ] || [ "$INPUT_CLAUDE" = "N" ]; then INPUT_CLAUDE=""; fi

printf "3. Tich hop OpenAI API? [Dan ma hoac 'n' de bo qua]: "
read -r INPUT_OPENAI < /dev/tty || INPUT_OPENAI=""
INPUT_OPENAI="$(echo "$INPUT_OPENAI" | tr -d '\r\n ')"
if [ "$INPUT_OPENAI" = "n" ] || [ "$INPUT_OPENAI" = "N" ]; then INPUT_OPENAI=""; fi

# =============================================================================
# BƯỚC 3/4: TẢI TRƯỚC TOÀN BỘ 7 TỆP DỰ ÁN & FONT TỪ GITHUB VỀ MÁY TÍNH
# =============================================================================
echo ""
echo -e "${YELLOW}[2/4] Dang tai Font Tieng Viet va 7 tep ma nguon tu GitHub ve may tinh...${NC}"

FONT_URL="https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf"
LOCAL_FONT="/tmp/NotoSans-Regular.ttf"
if [ ! -f "$LOCAL_FONT" ]; then
    echo -e "${GRAY}      -> Dang tai Font Tieng Viet (NotoSans-Regular.ttf)...${NC}"
    curl -fsSL "$FONT_URL" -o "$LOCAL_FONT"
fi
FONT_BASE64="$(base64 < "$LOCAL_FONT" | tr -d '\r\n')"

fetch_github_file() {
    local rel_path="$1"
    echo -e "${GRAY}      -> Dang tai: $rel_path${NC}" >&2
    local out_file="$WORK_TMP/$(echo "$rel_path" | tr '/' '_')"
    curl -fsSL "$GITHUB_RAW_BASE/$rel_path" | tr -d '\r' > "$out_file"
    cat "$out_file"
}

QMD_CONTENT="$(fetch_github_file "aiAssistantChat.qmd")"
RUN_EXPORT_CONTENT="$(fetch_github_file "run_export.sh")"
SERVICE_CONTENT="$(fetch_github_file "ai-exporter.service")"
PATH_CONTENT="$(fetch_github_file "ai-exporter.path")"
INIT_HOOK_CONTENT="$(fetch_github_file "99-ai-exporter.sh")"
EXPORTER_QML_CONTENT="$(fetch_github_file "extensions/epubPdfExporter.qml")"
GUIDE_QML_CONTENT="$(fetch_github_file "extensions/guideExtension.qml")"
echo -e "${GREEN}      ✓ Da tai xong toan bo tep du an!${NC}"

# =============================================================================
# BƯỚC 4/4: THỰC THI TOÀN BỘ TRONG DUY NHẤT 1 PHIÊN SSH (KHÔNG BAO GIỜ BỊ RESET)
# =============================================================================
echo ""
echo -e "${YELLOW}[3/4] Dang trien khai toan bo len reMarkable trong 1 phien SSH duy nhat...${NC}"

ALL_IN_ONE_SH="$WORK_TMP/rm_all_in_one.sh"
cat << EOF_ALL > "$ALL_IN_ONE_SH"
export PATH=/home/root/.vellum/bin:/home/root/.vellum/usr/bin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo "================================================================"
echo ">>> [CHANG 1/4] KIEM TRA VELLUM & CAI DAT 5 GOI PHU THUOC..."
echo "================================================================"

if [ ! -d /home/root/.vellum ] || [ ! -x /home/root/.vellum/bin/vellum ]; then
    echo "      -> Thiet bi chua co Vellum. Dang tai va cai dat Vellum Bootstrap..."
    cd /home/root
    rm -f bootstrap.sh
    wget --no-check-certificate -O bootstrap.sh https://github.com/vellum-dev/vellum-cli/releases/latest/download/bootstrap.sh
    echo "7b0deebc81b28a7d74d95c85e99a4a0a0f6ecaa5b9edb6b858ac61405978ebb9  bootstrap.sh" | sha256sum -c && bash bootstrap.sh
    if [ \$? -ne 0 ] || [ ! -d /home/root/.vellum ]; then
        echo "[!] LOI: Cai dat Vellum that bai (Kiem tra lai Wi-Fi hoac ma SHA256)!"
        rm -f bootstrap.sh
        exit 1
    fi
    rm -f bootstrap.sh
    export PATH=/home/root/.vellum/bin:/home/root/.vellum/usr/bin:/opt/bin:\$PATH
    echo "      ✓ Da cai dat Vellum thanh cong!"
fi

if command -v vellum >/dev/null 2>&1; then
    vellum add curl xovi webserver-remote qt-resource-rebuilder tripletap || vellum install curl xovi webserver-remote qt-resource-rebuilder tripletap || true
elif command -v opkg >/dev/null 2>&1; then
    opkg update && opkg install curl xovi webserver-remote qt-resource-rebuilder tripletap
elif command -v apk >/dev/null 2>&1; then
    apk update && apk add curl xovi webserver-remote qt-resource-rebuilder tripletap
else
    echo "[!] LOI: Khong tim thay trinh quan ly goi Vellum!"
    exit 2
fi

mkdir -p /home/root/xovi/extensions.d
for ext_so in qt-resource-rebuilder.so webserver-remote.so; do
    if [ ! -f "/home/root/xovi/extensions.d/\$ext_so" ]; then
        FOUND_SO=\$(find /home/root /opt /usr -name "\$ext_so" 2>/dev/null | head -n 1)
        if [ -n "\$FOUND_SO" ]; then
            cp -f "\$FOUND_SO" "/home/root/xovi/extensions.d/\$ext_so"
            echo "      ✓ Da kich hoat extension: \$ext_so"
        fi
    fi
done

echo ""
echo "================================================================"
echo ">>> [CHANG 2/4] CAI DAT 7 TEP DU AN, FONT TIENG VIET & SYSTEMD..."
echo "================================================================"
mkdir -p /home/root/AI_Notes/extensions
mkdir -p /home/root/xovi/exthome/qt-resource-rebuilder
mkdir -p /home/root/xovi/init.d

rm -rf /home/root/AI_Notes/cgi-bin
killall busybox_ai_httpd 2>/dev/null || true

if [ ! -f /home/root/AI_Notes/NotoSans-Regular.ttf ]; then
cat << 'EOF_FONT_B64' | base64 -d > /home/root/AI_Notes/NotoSans-Regular.ttf
$FONT_BASE64
EOF_FONT_B64
fi

OLD_GEMINI=""
OLD_CLAUDE=""
OLD_OPENAI=""
if [ -f /home/root/AI_Notes/api_keys.txt ]; then
    OLD_GEMINI=\$(grep '^GEMINI_KEY=' /home/root/AI_Notes/api_keys.txt | cut -d'=' -f2-)
    OLD_CLAUDE=\$(grep '^CLAUDE_KEY=' /home/root/AI_Notes/api_keys.txt | cut -d'=' -f2-)
    OLD_OPENAI=\$(grep '^OPENAI_KEY=' /home/root/AI_Notes/api_keys.txt | cut -d'=' -f2-)
fi

FINAL_GEMINI="$INPUT_GEMINI"
FINAL_CLAUDE="$INPUT_CLAUDE"
FINAL_OPENAI="$INPUT_OPENAI"
[ -z "\$FINAL_GEMINI" ] && FINAL_GEMINI="\$OLD_GEMINI"
[ -z "\$FINAL_CLAUDE" ] && FINAL_CLAUDE="\$OLD_CLAUDE"
[ -z "\$FINAL_OPENAI" ] && FINAL_OPENAI="\$OLD_OPENAI"

cat << EOF_KEYS > /home/root/AI_Notes/api_keys.txt
GEMINI_KEY=\$FINAL_GEMINI
CLAUDE_KEY=\$FINAL_CLAUDE
OPENAI_KEY=\$FINAL_OPENAI
EOF_KEYS

if [ ! -f /home/root/AI_Notes/notebook_data.conf ]; then
cat << EOF_CONF > /home/root/AI_Notes/notebook_data.conf
[General]
deviceModelName=$DEVICE_MODEL_NAME
customWinWidth=$CUSTOM_WIN_WIDTH
customWinHeight=$CUSTOM_WIN_HEIGHT
thinkingLevel=low
EOF_CONF
else
    sed -i '/^deviceModelName=/d; /^customWinWidth=/d; /^customWinHeight=/d' /home/root/AI_Notes/notebook_data.conf
    printf "\ndeviceModelName=%s\ncustomWinWidth=%s\ncustomWinHeight=%s\n" "$DEVICE_MODEL_NAME" "$CUSTOM_WIN_WIDTH" "$CUSTOM_WIN_HEIGHT" >> /home/root/AI_Notes/notebook_data.conf
fi

cat << 'EOF_QMD' > /home/root/xovi/exthome/qt-resource-rebuilder/aiAssistantChat.qmd
$QMD_CONTENT
EOF_QMD

cat << 'EOF_EXT_EXPORTER' > /home/root/AI_Notes/extensions/epubPdfExporter.qml
$EXPORTER_QML_CONTENT
EOF_EXT_EXPORTER

cat << 'EOF_EXT_GUIDE' > /home/root/AI_Notes/extensions/guideExtension.qml
$GUIDE_QML_CONTENT
EOF_EXT_GUIDE

chmod 644 /home/root/AI_Notes/extensions/*.qml

cat << 'EOF_RUN_EXPORT' > /home/root/AI_Notes/run_export.sh
$RUN_EXPORT_CONTENT
EOF_RUN_EXPORT

if [ -x /home/root/.vellum/bin/curl ]; then
    sed -i 's#\bcurl\b#/home/root/.vellum/bin/curl#g' /home/root/AI_Notes/run_export.sh
    sed -i 's#/home/root/.vellum/bin//home/root/.vellum/bin/curl#/home/root/.vellum/bin/curl#g' /home/root/AI_Notes/run_export.sh
fi
chmod +x /home/root/AI_Notes/run_export.sh

cat << 'EOF_SERVICE' > /home/root/AI_Notes/ai-exporter.service
$SERVICE_CONTENT
EOF_SERVICE

cat << 'EOF_PATH' > /home/root/AI_Notes/ai-exporter.path
$PATH_CONTENT
EOF_PATH

cat << 'EOF_HOOK_99' > /home/root/AI_Notes/99-ai-exporter.sh
$INIT_HOOK_CONTENT
EOF_HOOK_99
chmod +x /home/root/AI_Notes/99-ai-exporter.sh

cp -f /home/root/AI_Notes/99-ai-exporter.sh /home/root/AI_Notes/setup_systemd.sh
chmod +x /home/root/AI_Notes/setup_systemd.sh
ln -sf /home/root/AI_Notes/99-ai-exporter.sh /home/root/xovi/init.d/99-ai-exporter.sh

cat << 'EOF_INIT' > /home/root/xovi/init.d/01-qml-file-read.sh
#!/bin/sh
export QML_XHR_ALLOW_FILE_READ=1
EOF_INIT
chmod +x /home/root/xovi/init.d/01-qml-file-read.sh

if [ -f /home/root/xovi/start ]; then
    sed -i '/18765/d' /home/root/xovi/start
    if ! grep -q "99-ai-exporter.sh" /home/root/xovi/start && ! grep -q "setup_systemd.sh" /home/root/xovi/start; then
        sed -i '2i /home/root/AI_Notes/99-ai-exporter.sh &' /home/root/xovi/start
    fi
    if ! grep -q 'Environment="QML_XHR_ALLOW_FILE_READ=1"' /home/root/xovi/start; then
        sed -i 's|Environment="LD_PRELOAD=/home/root/xovi/xovi.so"|Environment="LD_PRELOAD=/home/root/xovi/xovi.so"\nEnvironment="QML_XHR_ALLOW_FILE_READ=1"|' /home/root/xovi/start
    fi
fi

find /home/root/AI_Notes /home/root/xovi -type f \( -name "*.sh" -o -name "*.qml" -o -name "*.qmd" -o -name "*.service" -o -name "*.path" \) -exec sed -i 's/\r$//' {} + 2>/dev/null

/home/root/AI_Notes/99-ai-exporter.sh
echo "      ✓ Da ghi xong 7 tep du an va kich hoat systemd ai-exporter.path!"

echo ""
echo "================================================================"
echo ">>> [CHANG 3/4] CHAY REBUILD HASHTABLE (QMLDIFF LIVE LOG)..."
echo "================================================================"
cd /home/root/xovi
yes '' | /home/root/xovi/rebuild_hashtable

if [ ! -s /home/root/xovi/exthome/qt-resource-rebuilder/hashtab ]; then
    echo "[!] LOI: Chua tao duoc tep /home/root/xovi/exthome/qt-resource-rebuilder/hashtab!"
    exit 3
fi
HT_SIZE=\$(wc -c < /home/root/xovi/exthome/qt-resource-rebuilder/hashtab)
echo "      ✓ Da tao thanh cong tep hashtab (\$HT_SIZE bytes)!"

echo ""
echo "================================================================"
echo ">>> [CHANG 4/4] KHOI CHAY XOVI VOI MODS (/home/root/xovi/start)..."
echo "================================================================"
cd /home/root/xovi
/home/root/xovi/start
sleep 3
/home/root/AI_Notes/99-ai-exporter.sh

XPID=\$(pidof xochitl | awk '{print \$1}')
ACTIVE=\$(systemctl is-active ai-exporter.path 2>/dev/null || echo "inactive")
echo "      ✓ Giao dien xochitl (PID: \$XPID) da khoi chay | ai-exporter.path: \$ACTIVE"
EOF_ALL

# Vòng lặp tự động Retry nếu lúc bắt đầu mở phiên SSH duy nhất này Dropbear đang bận
DEPLOY_OK=0
for retry in 1 2 3 4 5; do
    if tr -d '\r' < "$ALL_IN_ONE_SH" | ssh -i "$KEY_FILE" -o IdentitiesOnly=yes -o ConnectTimeout=15 -o ServerAliveInterval=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "root@$RM_IP" "tr -d '\r' | bash -s"; then
        DEPLOY_OK=1
        break
    fi
    echo -e "${GRAY}      -> Cong SSH dang ban, tu dong thu lai sau 4 giay ($retry/5)...${NC}"
    sleep 4
done

if [ "$DEPLOY_OK" -ne 1 ]; then
    echo -e "${RED}[!] LOI: Ket noi SSH bi gian doan. Vui long dong reManager va chay lai!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}   ✓ [4/4] CAI DAT HOAN TAT 100% CHO: $DEVICE_MODEL_NAME${NC}"
echo -e "${GREEN}   ✓ NUT AI DA HIEN TREN MAN HINH & DICH VU XUAT EPUB/PDF SAN SANG!${NC}"
echo -e "${GREEN}   ✓ BAN CO THE RUT CAP USB VA SU DUNG NGAY!                    ${NC}"
echo -e "${GREEN}================================================================${NC}"
