#!/bin/sh
export PATH=/opt/bin:/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/root/.local/bin

if [ ! -f /home/root/AI_Notes/export_trigger.conf ]; then
    exit 0
fi

usleep 200000 2>/dev/null || sleep 1

mv -f /home/root/AI_Notes/export_trigger.conf /tmp/ai_work.conf 2>/dev/null || exit 0

grep -i "^exportReqId=" /tmp/ai_work.conf | head -n 1 | sed 's/^exportReqId=//i' | tr -d '\r\n" ' > /tmp/ai_req_id
grep -i "^exportFileName=" /tmp/ai_work.conf | head -n 1 | sed 's/^exportFileName=//i' | tr -d '\r\n" ' > /tmp/ai_file_name
grep -i "^exportMimeType=" /tmp/ai_work.conf | head -n 1 | sed 's/^exportMimeType=//i' | tr -d '\r\n" ' > /tmp/ai_mime_type
grep -i "^exportBase64=" /tmp/ai_work.conf | head -n 1 | sed 's/^exportBase64=//i' | tr -d '\r\n" ' | base64 -d > /tmp/ai_payload.bin

rm -f /tmp/ai_work.conf

if [ ! -s /tmp/ai_req_id ] || [ ! -s /tmp/ai_payload.bin ]; then
    exit 0
fi

sed 's|^|/tmp/ai_status_|; s|$|.txt|' /tmp/ai_req_id > /tmp/ai_status_path

for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    /home/root/.vellum/bin/curl -s --max-time 5 http://127.0.0.1/documents/ > /tmp/ai_doc_check.txt
    if grep -q "Please confirm" /tmp/ai_doc_check.txt; then
        sleep 2
    elif [ ! -s /tmp/ai_doc_check.txt ]; then
        echo "ERROR|Chưa bật USB web interface trong Settings > Storage!" > /tmp/ai_msg.txt
        xargs -I TARGET cp /tmp/ai_msg.txt TARGET < /tmp/ai_status_path
        exit 1
    else
        break
    fi
done

if grep -q "Please confirm" /tmp/ai_doc_check.txt; then
    echo "ERROR|Quá thời gian chờ bấm [Accept] trên màn hình!" > /tmp/ai_msg.txt
    xargs -I TARGET cp /tmp/ai_msg.txt TARGET < /tmp/ai_status_path
    exit 1
fi

# Ghép dòng cấu hình form-string chuẩn xác cho /home/root/.vellum/bin/curl -K mà không dùng biến $
sed 's|^|form = "file=@/tmp/ai_payload.bin;filename=|' /tmp/ai_file_name > /tmp/ai_part1.txt
sed 's|^|;type=|; s|$|"|' /tmp/ai_mime_type > /tmp/ai_part2.txt
cat /tmp/ai_part1.txt /tmp/ai_part2.txt | tr -d '\r\n' > /tmp/ai_curl.cfg
echo "" >> /tmp/ai_curl.cfg

/home/root/.vellum/bin/curl -s --max-time 20 \
    -H "Origin: http://127.0.0.1" \
    -H "Accept: */*" \
    -H "Referer: http://127.0.0.1/" \
    -K /tmp/ai_curl.cfg \
    http://127.0.0.1/upload > /tmp/ai_upload_resp.txt

rm -f /tmp/ai_payload.bin

if grep -q "Upload successful" /tmp/ai_upload_resp.txt; then
    echo "SUCCESS|✓ Đã xuất thành công tài liệu vào My Files!" > /tmp/ai_msg.txt
else
    echo "ERROR|Lỗi đẩy file vào My Files!" > /tmp/ai_msg.txt
fi

xargs -I TARGET cp /tmp/ai_msg.txt TARGET < /tmp/ai_status_path
