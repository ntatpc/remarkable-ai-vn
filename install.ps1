# =============================================================================
# KỊCH BẢN CÀI ĐẶT TRỢ LÝ AI & UNIKEY TELEX CHO REMARKABLE (WINDOWS)
# Kiến trúc: Single-Session SSH (Chống 100% lỗi Connection reset của Dropbear)
# =============================================================================
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$GITHUB_RAW_BASE = "https://raw.githubusercontent.com/ntatpc/remarkable-ai-vn/main"
$RM_IP = "10.11.99.1"

Clear-Host
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   CAI DAT TRO LY AI & UNIKEY TELEX CHO REMARKABLE (WINDOWS)    " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   Luu y: Hay dong phan mem reManager (neu dang mo) truoc khi chay!" -ForegroundColor DarkGray
Write-Host ""

$sshDir = "$HOME\.ssh"
$keyFile = "$sshDir\id_ed25519"

# =============================================================================
# BƯỚC 1/4: KIỂM TRA KẾT NỐI USB & KHÓA SSH (PHÂN BIỆT RÕ LỖI RESET VÀ THIẾU KEY)
# =============================================================================
Write-Host "[1/4] Kiem tra ket noi USB & Khoa SSH ($RM_IP)..." -ForegroundColor Yellow
if (!(Test-Connection -ComputerName $RM_IP -Count 1 -Quiet)) {
    Write-Host "[!] LOI: Khong the ket noi toi $RM_IP." -ForegroundColor Red
    Write-Host "    -> Hay cam cap USB va bat 'USB web interface' trong Settings -> Storage." -ForegroundColor Yellow
    return
}

if (!(Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }
$ErrorActionPreference = "Continue"
& ssh-keygen.exe -R $RM_IP 2>$null | Out-Null
if (!(Test-Path "$keyFile.pub")) {
    Write-Host "      -> Dang tao cap khoa SSH ed25519 moi tren may tinh..." -ForegroundColor DarkGray
    & ssh-keygen.exe -t ed25519 -f $keyFile -q -N "" 2>$null | Out-Null
}
$pubKey = (Get-Content "$keyFile.pub" -Raw).Trim()

# Thử kết nối bằng Key tối đa 5 lần nếu gặp lỗi Connection reset do Dropbear đang bận
$hasKey = $false
$needPassword = $false
for ($try = 1; $try -le 5; $try++) {
    $probeOut = & ssh.exe -i $keyFile -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "root@$RM_IP" "echo OK_AUTH ; cat /sys/devices/soc0/machine /proc/device-tree/model 2>/dev/null | tr -d '\0\r\n'" 2>&1 | Out-String
    if ($probeOut -match "OK_AUTH") {
        $hasKey = $true
        break
    } elseif ($probeOut -match "Permission denied") {
        $needPassword = $true
        break
    } else {
        Write-Host "      -> Cong SSH tren reMarkable dang ban (Connection reset), dang doi 3 giay ($try/5)..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
    }
}
$ErrorActionPreference = "Stop"

if (!$hasKey) {
    Write-Host ""
    Write-Host "      ==========================================================" -ForegroundColor Yellow
    Write-Host "      THIET BI CHUA CO KHOA SSH! VUI LONG NHAP MAT KHAU SSH:" -ForegroundColor Yellow
    Write-Host "      (Xem tai: Settings -> Help -> Copyrights and licenses)" -ForegroundColor Cyan
    Write-Host "      Luu y: Khi go mat khau tren man hinh se khong hien ky tu." -ForegroundColor DarkGray
    Write-Host "      ==========================================================" -ForegroundColor Yellow

    $setupKeyCmd = "chmod 755 /home/root ; mkdir -p /home/root/.ssh ; chmod 700 /home/root/.ssh ; touch /home/root/.ssh/authorized_keys ; grep -qF '$pubKey' /home/root/.ssh/authorized_keys || echo '$pubKey' >> /home/root/.ssh/authorized_keys ; chmod 600 /home/root/.ssh/authorized_keys"
    
    $keyInstalled = $false
    $ErrorActionPreference = "Continue"
    for ($kTry = 1; $kTry -le 4; $kTry++) {
        Start-Sleep -Seconds 3
        & ssh.exe -o PubkeyAuthentication=no -o PreferredAuthentications=password -o ConnectTimeout=15 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR "root@$RM_IP" $setupKeyCmd
        if ($LASTEXITCODE -eq 0) {
            $keyInstalled = $true
            break
        }
        Write-Host "      -> Ket noi SSH bi ngat hoac sai mat khau, thu lai sau 3 giay ($kTry/4)..." -ForegroundColor DarkGray
    }
    $ErrorActionPreference = "Stop"

    if (!$keyInstalled) {
        Write-Host "[!] LOI: Khong the nap khoa SSH. Hay dong reManager (neu dang mo) hoac khoi dong lai reMarkable roi chay lai!" -ForegroundColor Red
        return
    }
    Start-Sleep -Seconds 3
}
Write-Host "      ✓ Ket noi USB va Khoa SSH da san sang!" -ForegroundColor Green

# Kiểm tra xem máy đã có Vellum chưa và đã kết nối Wi-Fi (Internet) chưa
$ErrorActionPreference = "Continue"
$envCheck = & ssh.exe -i $keyFile -o IdentitiesOnly=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR "root@$RM_IP" "if [ -d /home/root/.vellum ]; then echo 'HAS_VELLUM'; else echo 'NO_VELLUM'; fi; if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 3 github.com >/dev/null 2>&1; then echo 'NET_OK'; else echo 'NO_NET'; fi" 2>$null | Out-String
$ErrorActionPreference = "Stop"

if ($envCheck -match "NO_VELLUM") {
    Write-Host "      [!] Phat hien thiet bi chua cai dat Vellum -> Script se tu dong cai dat Vellum!" -ForegroundColor Cyan
}

while ($envCheck -match "NO_NET") {
    Write-Host ""
    Write-Host "      [!] CANH BAO: reMarkable chua co ket noi Internet (Wi-Fi)!" -ForegroundColor Red
    Write-Host "          Vui long mo Settings -> Wi-Fi tren reMarkable va ket noi mang." -ForegroundColor Yellow
    $null = Read-Host "          Sau khi da bat Wi-Fi tren may doc sach, nhan [Enter] de kiem tra lai"
    
    $ErrorActionPreference = "Continue"
    $envCheck = & ssh.exe -i $keyFile -o IdentitiesOnly=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR "root@$RM_IP" "if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 3 github.com >/dev/null 2>&1; then echo 'NET_OK'; else echo 'NO_NET'; fi" 2>$null | Out-String
    $ErrorActionPreference = "Stop"
}
Write-Host "      ✓ Ket noi Internet (Wi-Fi) tren reMarkable da san sang!" -ForegroundColor Green

# =============================================================================
# BƯỚC 2/4: CHỌN DÒNG MÁY & NHẬP API KEY (KHÔNG MỞ THÊM PHIÊN SSH NÀO)
# =============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   CHON THIET BI REMARKABLE & CAU HINH API KEY                  " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

$rawHw = ""
if ($probeOut -match "OK_AUTH\s*(.*)") {
    $rawHw = $matches[1].Trim()
}
if ([string]::IsNullOrWhiteSpace($rawHw)) { $rawHw = "Auto-Detect" }

Write-Host "   Phan cung phat hien: $rawHw" -ForegroundColor DarkGray
Write-Host "   [1] reMarkable 1"
Write-Host "   [2] reMarkable 2"
Write-Host "   [3] reMarkable Paper Pro"
Write-Host "   [4] reMarkable Paper Pure"
Write-Host "   [5] reMarkable Paper Move"
$devChoice = Read-Host "Chon dong may cua ban [1-5 hoac nhan Enter de tu dong]"

$deviceModelName = "reMarkable Paper Pro"
$customWinWidth = "1320"
$customWinHeight = "1880"

if ($devChoice -eq "1" -or ($devChoice -eq "" -and $rawHw -match "1\.0")) {
    $deviceModelName = "reMarkable 1"; $customWinWidth = "1080"; $customWinHeight = "1580"
} elseif ($devChoice -eq "2" -or ($devChoice -eq "" -and $rawHw -match "2\.0")) {
    $deviceModelName = "reMarkable 2"; $customWinWidth = "1100"; $customWinHeight = "1620"
} elseif ($devChoice -eq "3" -or ($devChoice -eq "" -and $rawHw -match "Ferrari|Pro|tatsu|imx93")) {
    $deviceModelName = "reMarkable Paper Pro"; $customWinWidth = "1320"; $customWinHeight = "1880"
} elseif ($devChoice -eq "4") {
    $deviceModelName = "reMarkable Paper Pure"; $customWinWidth = "1100"; $customWinHeight = "1620"
} elseif ($devChoice -eq "5" -or ($devChoice -eq "" -and $rawHw -match "Move")) {
    $deviceModelName = "reMarkable Paper Move"; $customWinWidth = "960"; $customWinHeight = "1420"
}
Write-Host "      ✓ Da chon: $deviceModelName (Khung chat: ${customWinWidth}x${customWinHeight})" -ForegroundColor Green
Write-Host ""

$inputGemini = Read-Host "1. Tich hop Google Gemini API? [Dan ma hoac 'n' de bo qua]"
if ($inputGemini.Trim().ToLower() -eq "n") { $inputGemini = "" }

$inputClaude = Read-Host "2. Tich hop Anthropic Claude API? [Dan ma hoac 'n' de bo qua]"
if ($inputClaude.Trim().ToLower() -eq "n") { $inputClaude = "" }

$inputOpenAI = Read-Host "3. Tich hop OpenAI API? [Dan ma hoac 'n' de bo qua]"
if ($inputOpenAI.Trim().ToLower() -eq "n") { $inputOpenAI = "" }

# =============================================================================
# BƯỚC 3/4: TẢI TRƯỚC TOÀN BỘ 7 TỆP DỰ ÁN & FONT TỪ GITHUB VỀ MÁY TÍNH
# =============================================================================
Write-Host ""
Write-Host "[2/4] Dang tai Font Tieng Viet va 7 tep ma nguon tu GitHub ve may tinh..." -ForegroundColor Yellow

$fontUrl = "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf"
$localFont = "$env:TEMP\NotoSans-Regular.ttf"
if (!(Test-Path $localFont)) {
    Write-Host "      -> Dang tai Font Tieng Viet (NotoSans-Regular.ttf)..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $fontUrl -OutFile $localFont
}
$fontBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($localFont))

function Get-GitHubFileContent([string]$RelPath) {
    Write-Host "      -> Dang tai: $RelPath" -ForegroundColor Gray
    $outFile = "$env:TEMP\" + ($RelPath -replace "/", "_")
    Invoke-WebRequest -Uri "$GITHUB_RAW_BASE/$RelPath" -OutFile $outFile
    return ([IO.File]::ReadAllText($outFile, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n" -replace "`r", "")
}

$qmdContent         = Get-GitHubFileContent "aiAssistantChat.qmd"
$runExportContent   = Get-GitHubFileContent "run_export.sh"
$serviceContent     = Get-GitHubFileContent "ai-exporter.service"
$pathContent        = Get-GitHubFileContent "ai-exporter.path"
$initHookContent    = Get-GitHubFileContent "99-ai-exporter.sh"
$exporterQmlContent = Get-GitHubFileContent "extensions/epubPdfExporter.qml"
$guideQmlContent    = Get-GitHubFileContent "extensions/guideExtension.qml"
Write-Host "      ✓ Da tai xong toan bo tep du an!" -ForegroundColor Green

# =============================================================================
# BƯỚC 4/4: THỰC THI TOÀN BỘ TRONG DUY NHẤT 1 PHIÊN SSH (KHÔNG BAO GIỜ BỊ RESET)
# =============================================================================
Write-Host ""
Write-Host "[3/4] Dang trien khai toan bo len reMarkable trong 1 phien SSH duy nhat..." -ForegroundColor Yellow

$allInOneTemplate = @'
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
    if [ $? -ne 0 ] || [ ! -d /home/root/.vellum ]; then
        echo "[!] LOI: Cai dat Vellum that bai (Kiem tra lai Wi-Fi hoac ma SHA256)!"
        rm -f bootstrap.sh
        exit 1
    fi
    rm -f bootstrap.sh
    export PATH=/home/root/.vellum/bin:/home/root/.vellum/usr/bin:/opt/bin:$PATH
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
    if [ ! -f "/home/root/xovi/extensions.d/$ext_so" ]; then
        FOUND_SO=$(find /home/root /opt /usr -name "$ext_so" 2>/dev/null | head -n 1)
        if [ -n "$FOUND_SO" ]; then
            cp -f "$FOUND_SO" "/home/root/xovi/extensions.d/$ext_so"
            echo "      ✓ Da kich hoat extension: $ext_so"
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
__FONT_BASE64__
EOF_FONT_B64
fi

OLD_GEMINI=""
OLD_CLAUDE=""
OLD_OPENAI=""
if [ -f /home/root/AI_Notes/api_keys.txt ]; then
    OLD_GEMINI=$(grep '^GEMINI_KEY=' /home/root/AI_Notes/api_keys.txt | cut -d'=' -f2-)
    OLD_CLAUDE=$(grep '^CLAUDE_KEY=' /home/root/AI_Notes/api_keys.txt | cut -d'=' -f2-)
    OLD_OPENAI=$(grep '^OPENAI_KEY=' /home/root/AI_Notes/api_keys.txt | cut -d'=' -f2-)
fi

FINAL_GEMINI="__INPUT_GEMINI__"
FINAL_CLAUDE="__INPUT_CLAUDE__"
FINAL_OPENAI="__INPUT_OPENAI__"
[ -z "$FINAL_GEMINI" ] && FINAL_GEMINI="$OLD_GEMINI"
[ -z "$FINAL_CLAUDE" ] && FINAL_CLAUDE="$OLD_CLAUDE"
[ -z "$FINAL_OPENAI" ] && FINAL_OPENAI="$OLD_OPENAI"

cat << EOF_KEYS > /home/root/AI_Notes/api_keys.txt
GEMINI_KEY=$FINAL_GEMINI
CLAUDE_KEY=$FINAL_CLAUDE
OPENAI_KEY=$FINAL_OPENAI
EOF_KEYS

if [ ! -f /home/root/AI_Notes/notebook_data.conf ]; then
cat << 'EOF_CONF' > /home/root/AI_Notes/notebook_data.conf
[General]
deviceModelName=__DEVICE_MODEL_NAME__
customWinWidth=__CUSTOM_WIN_WIDTH__
customWinHeight=__CUSTOM_WIN_HEIGHT__
thinkingLevel=low
EOF_CONF
else
    sed -i '/^deviceModelName=/d; /^customWinWidth=/d; /^customWinHeight=/d' /home/root/AI_Notes/notebook_data.conf
    printf "\ndeviceModelName=%s\ncustomWinWidth=%s\ncustomWinHeight=%s\n" "__DEVICE_MODEL_NAME__" "__CUSTOM_WIN_WIDTH__" "__CUSTOM_WIN_HEIGHT__" >> /home/root/AI_Notes/notebook_data.conf
fi

cat << 'EOF_QMD' > /home/root/xovi/exthome/qt-resource-rebuilder/aiAssistantChat.qmd
__QMD_CONTENT__
EOF_QMD

cat << 'EOF_EXT_EXPORTER' > /home/root/AI_Notes/extensions/epubPdfExporter.qml
__EXPORTER_QML_CONTENT__
EOF_EXT_EXPORTER

cat << 'EOF_EXT_GUIDE' > /home/root/AI_Notes/extensions/guideExtension.qml
__GUIDE_QML_CONTENT__
EOF_EXT_GUIDE

chmod 644 /home/root/AI_Notes/extensions/*.qml

cat << 'EOF_RUN_EXPORT' > /home/root/AI_Notes/run_export.sh
__RUN_EXPORT_CONTENT__
EOF_RUN_EXPORT

if [ -x /home/root/.vellum/bin/curl ]; then
    sed -i 's#\bcurl\b#/home/root/.vellum/bin/curl#g' /home/root/AI_Notes/run_export.sh
    sed -i 's#/home/root/.vellum/bin//home/root/.vellum/bin/curl#/home/root/.vellum/bin/curl#g' /home/root/AI_Notes/run_export.sh
fi
chmod +x /home/root/AI_Notes/run_export.sh

cat << 'EOF_SERVICE' > /home/root/AI_Notes/ai-exporter.service
__SERVICE_CONTENT__
EOF_SERVICE

cat << 'EOF_PATH' > /home/root/AI_Notes/ai-exporter.path
__PATH_CONTENT__
EOF_PATH

cat << 'EOF_HOOK_99' > /home/root/AI_Notes/99-ai-exporter.sh
__INIT_HOOK_CONTENT__
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
HT_SIZE=$(wc -c < /home/root/xovi/exthome/qt-resource-rebuilder/hashtab)
echo "      ✓ Da tao thanh cong tep hashtab ($HT_SIZE bytes)!"

echo ""
echo "================================================================"
echo ">>> [CHANG 4/4] KHOI CHAY XOVI VOI MODS (/home/root/xovi/start)..."
echo "================================================================"
cd /home/root/xovi
/home/root/xovi/start
sleep 3
/home/root/AI_Notes/99-ai-exporter.sh

XPID=$(pidof xochitl | awk '{print $1}')
ACTIVE=$(systemctl is-active ai-exporter.path 2>/dev/null || echo "inactive")
echo "      ✓ Giao dien xochitl (PID: $XPID) da khoi chay | ai-exporter.path: $ACTIVE"
'@

$finalRemoteScript = $allInOneTemplate.
    Replace("__FONT_BASE64__", $fontBase64).
    Replace("__INPUT_GEMINI__", $inputGemini.Trim()).
    Replace("__INPUT_CLAUDE__", $inputClaude.Trim()).
    Replace("__INPUT_OPENAI__", $inputOpenAI.Trim()).
    Replace("__DEVICE_MODEL_NAME__", $deviceModelName).
    Replace("__CUSTOM_WIN_WIDTH__", $customWinWidth).
    Replace("__CUSTOM_WIN_HEIGHT__", $customWinHeight).
    Replace("__QMD_CONTENT__", $qmdContent).
    Replace("__EXPORTER_QML_CONTENT__", $exporterQmlContent).
    Replace("__GUIDE_QML_CONTENT__", $guideQmlContent).
    Replace("__RUN_EXPORT_CONTENT__", $runExportContent).
    Replace("__SERVICE_CONTENT__", $serviceContent).
    Replace("__PATH_CONTENT__", $pathContent).
    Replace("__INIT_HOOK_CONTENT__", $initHookContent)

$cleanScript = $finalRemoteScript -replace "`r`n", "`n" -replace "`r", ""
$tempFile = "$env:TEMP\rm_all_in_one.sh"
[IO.File]::WriteAllText($tempFile, $cleanScript, (New-Object System.Text.UTF8Encoding($false)))

# Vòng lặp tự động Retry nếu lúc bắt đầu mở phiên SSH duy nhất này Dropbear đang bận
$deployOk = $false
$ErrorActionPreference = "Continue"
for ($retry = 1; $retry -le 5; $retry++) {
    cmd.exe /c "ssh -i `"$keyFile`" -o IdentitiesOnly=yes -o ConnectTimeout=15 -o ServerAliveInterval=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR root@$RM_IP `"tr -d '\r' | bash -s`" < `"$tempFile`""
    if ($LASTEXITCODE -eq 0) {
        $deployOk = $true
        break
    }
    Write-Host "      -> Cong SSH dang ban, tu dong thu lai sau 4 giay ($retry/5)..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 4
}
$ErrorActionPreference = "Stop"

if (!$deployOk) {
    Write-Host "[!] LOI: Ket noi SSH bi gian doan. Vui long dong reManager va chay lai!" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "   ✓ [4/4] CAI DAT HOAN TAT 100% CHO: $deviceModelName" -ForegroundColor Green
Write-Host "   ✓ NUT AI DA HIEN TREN MAN HINH & DICH VU XUAT EPUB/PDF SAN SANG!" -ForegroundColor Green
Write-Host "   ✓ BAN CO THE RUT CAP USB VA SU DUNG NGAY!                    " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
