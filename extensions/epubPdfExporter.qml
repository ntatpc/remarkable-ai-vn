import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: exporterExtensionRoot
    anchors.fill: parent

    property string extensionId: "builtin_exporter"
    property string extensionName: "Kết xuất EPUB / PDF"
    property string extensionDescription: "Đóng gói lịch sử trò chuyện sang sách EPUB (UTF-8 Tiếng Việt) hoặc PDF và đẩy trực tiếp vào My Files."

    property var extensionActions: [
        { "actionId": "export_epub", "label": "Xuất sách EPUB" },
        { "actionId": "export_pdf",  "label": "Xuất tài liệu PDF" }
    ]

    property string popupMessage: ""
    property bool popupVisible: false

    property var cachedCrcTable: []
    property string pendingActionId: ""
    property var pendingContextData: null

    property string activeRequestId: ""
    property int statusPollCount: 0

    Timer {
        id: asyncExportWorker
        interval: 60
        repeat: false
        onTriggered: {
            try {
                if (exporterExtensionRoot.pendingActionId === "export_epub") {
                    exporterExtensionRoot.exportConversationToEpub(exporterExtensionRoot.pendingContextData);
                } else if (exporterExtensionRoot.pendingActionId === "export_pdf") {
                    exporterExtensionRoot.exportConversationToPdf(exporterExtensionRoot.pendingContextData);
                }
            } catch (err) {
                exporterExtensionRoot.notifyStatus("⚠ Lỗi đóng gói: " + err);
            }
            exporterExtensionRoot.pendingActionId = "";
            exporterExtensionRoot.pendingContextData = null;
        }
    }

    Timer {
        id: statusFilePollTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            exporterExtensionRoot.pollExportStatusFile();
        }
    }

    function findRootOverlay() {
        var p = exporterExtensionRoot.parent;
        var depth = 0;
        while (p && depth < 10) {
            if (typeof p.showToast === "function" || typeof p.saveCurrentChatToQMLNotebook === "function") {
                return p;
            }
            p = p.parent;
            depth = depth + 1;
        }
        return null;
    }

    function notifyStatus(msg) {
        popupMessage = msg;
        var rootObj = findRootOverlay();
        if (rootObj && typeof rootObj.showToast === "function") {
            rootObj.showToast(msg);
            return;
        }
        popupVisible = true;
    }

    function executeAction(actionId, chatContextData) {
        try {
            var sessionList = (chatContextData && chatContextData.currentSession) ? chatContextData.currentSession : [];
            var rawTranscript = (chatContextData && chatContextData.transcriptText) ? chatContextData.transcriptText : "";

            if (sessionList.length === 0 && (!rawTranscript || rawTranscript.trim() === "")) {
                notifyStatus("⚠ Chưa có nội dung trò chuyện nào để kết xuất!");
                return;
            }

            var rootObj = findRootOverlay();
            if (rootObj && typeof rootObj.saveCurrentChatToQMLNotebook === "function") {
                rootObj.saveCurrentChatToQMLNotebook(true);
            }

            if (actionId === "export_epub") {
                notifyStatus("⏳ Đang chuẩn bị sách EPUB chuẩn UTF-8...");
                pendingActionId = "export_epub";
                pendingContextData = chatContextData;
                asyncExportWorker.restart();
            } else if (actionId === "export_pdf") {
                notifyStatus("⏳ Đang chuẩn bị tài liệu PDF 1.4...");
                pendingActionId = "export_pdf";
                pendingContextData = chatContextData;
                asyncExportWorker.restart();
            }
        } catch (e) {
            notifyStatus("⚠ Lỗi khởi tạo tiến trình xuất: " + e);
        }
    }

    function escapeXmlChars(str) {
        if (!str) return "";
        var out = "";
        for (var i = 0; i < str.length; i = i + 1) {
            var ch = str.charAt(i);
            if (ch === "&") out = out + "&amp;";
            else if (ch === "<") out = out + "&lt;";
            else if (ch === ">") out = out + "&gt;";
            else if (ch === "\"") out = out + "&quot;";
            else if (ch === "'") out = out + "&#39;";
            else out = out + ch;
        }
        return out;
    }

    function formatInlineBold(lineText) {
        var boldDelim = "\x2A\x2A";
        var parts = lineText.split(boldDelim);
        if (parts.length < 3) return lineText;
        var res = "";
        for (var i = 0; i < parts.length; i = i + 1) {
            if (i % 2 === 1 && i < parts.length - 1) {
                res = res + "<b>" + parts[i] + "</b>";
            } else {
                res = res + parts[i];
            }
        }
        return res;
    }

    function markdownToXhtmlBlocks(rawMarkdown) {
        var safeStr = escapeXmlChars(rawMarkdown);
        var lines = safeStr.split("\n");
        var html = "";
        var inCode = false;
        var inUl = false;
        var bulletStar = "\x2A ";

        for (var i = 0; i < lines.length; i = i + 1) {
            var line = lines[i];
            if (line.length > 0 && line.charAt(line.length - 1) === "\r") {
                line = line.substring(0, line.length - 1);
            }

            if (line.indexOf("```") === 0) {
                if (inUl) { html = html + "</ul>\n"; inUl = false; }
                if (!inCode) {
                    html = html + "<pre><code>";
                    inCode = true;
                } else {
                    html = html + "</code></pre>\n";
                    inCode = false;
                }
                continue;
            }

            if (inCode) {
                html = html + line + "\n";
                continue;
            }

            if (line.indexOf("### ") === 0) {
                if (inUl) { html = html + "</ul>\n"; inUl = false; }
                html = html + "<h3>" + formatInlineBold(line.substring(4)) + "</h3>\n";
            } else if (line.indexOf("## ") === 0) {
                if (inUl) { html = html + "</ul>\n"; inUl = false; }
                html = html + "<h2>" + formatInlineBold(line.substring(3)) + "</h2>\n";
            } else if (line.indexOf("# ") === 0) {
                if (inUl) { html = html + "</ul>\n"; inUl = false; }
                html = html + "<h2>" + formatInlineBold(line.substring(2)) + "</h2>\n";
            } else if (line.indexOf("- ") === 0 || line.indexOf(bulletStar) === 0) {
                if (!inUl) { html = html + "<ul>\n"; inUl = true; }
                html = html + "  <li>" + formatInlineBold(line.substring(2)) + "</li>\n";
            } else if (line.trim() === "") {
                if (inUl) { html = html + "</ul>\n"; inUl = false; }
            } else {
                if (inUl) { html = html + "</ul>\n"; inUl = false; }
                html = html + "<p>" + formatInlineBold(line) + "</p>\n";
            }
        }

        if (inUl) html = html + "</ul>\n";
        if (inCode) html = html + "</code></pre>\n";
        return html;
    }

    function getCrc32LookupTable() {
        if (cachedCrcTable && cachedCrcTable.length === 256) {
            return cachedCrcTable;
        }
        var tbl = [];
        for (var n = 0; n < 256; n = n + 1) {
            var c = n;
            for (var k = 0; k < 8; k = k + 1) {
                if (c & 1) {
                    c = 0xEDB88320 ^ (c >>> 1);
                } else {
                    c = c >>> 1;
                }
            }
            tbl.push(c);
        }
        cachedCrcTable = tbl;
        return tbl;
    }

    function computeCrc32Value(byteList, crcTable) {
        var crc = 0 ^ (-1);
        for (var i = 0; i < byteList.length; i = i + 1) {
            crc = (crc >>> 8) ^ crcTable[(crc ^ byteList[i]) & 0xFF];
        }
        return (crc ^ (-1)) >>> 0;
    }

    function stringToUtf8ByteArray(str) {
        var bytes = [];
        if (!str) return bytes;
        for (var i = 0; i < str.length; i = i + 1) {
            var code = str.charCodeAt(i);
            if (code < 0x80) {
                bytes.push(code);
            } else if (code < 0x800) {
                bytes.push(0xc0 | (code >> 6));
                bytes.push(0x80 | (code & 0x3f));
            } else if (code < 0xd800 || code >= 0xe000) {
                bytes.push(0xe0 | (code >> 12));
                bytes.push(0x80 | ((code >> 6) & 0x3f));
                bytes.push(0x80 | (code & 0x3f));
            } else {
                i = i + 1;
                code = 0x10000 + (((code & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff));
                bytes.push(0xf0 | (code >> 18));
                bytes.push(0x80 | ((code >> 12) & 0x3f));
                bytes.push(0x80 | ((code >> 6) & 0x3f));
                bytes.push(0x80 | (code & 0x3f));
            }
        }
        return bytes;
    }

    function encodeByteArrayToBase64(bytes) {
        var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        var outParts = [];
        var chunk = "";
        var len = bytes.length;
        var i = 0;

        while (i < len) {
            var b0 = bytes[i] & 0xff;
            i = i + 1;
            var hasB1 = (i < len);
            var b1 = hasB1 ? (bytes[i] & 0xff) : 0;
            i = i + 1;
            var hasB2 = (i < len);
            var b2 = hasB2 ? (bytes[i] & 0xff) : 0;
            i = i + 1;

            var triplet = (b0 << 16) | (b1 << 8) | b2;

            var c0 = chars.charAt((triplet >> 18) & 0x3f);
            var c1 = chars.charAt((triplet >> 12) & 0x3f);
            var c2 = hasB1 ? chars.charAt((triplet >> 6) & 0x3f) : "=";
            var c3 = hasB2 ? chars.charAt(triplet & 0x3f) : "=";

            chunk = chunk + c0 + c1 + c2 + c3;
            if (chunk.length >= 4096) {
                outParts.push(chunk);
                chunk = "";
            }
        }
        if (chunk.length > 0) {
            outParts.push(chunk);
        }
        return outParts.join("");
    }

    function sanitizeFileNameAscii(rawTitle, suffixExt) {
        var allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-";
        var asciiBase = transliterateToAsciiPdfSafe(rawTitle || "Ghi_chu_AI");
        var clean = "";
        for (var i = 0; i < asciiBase.length; i = i + 1) {
            var ch = asciiBase.charAt(i);
            if (allowed.indexOf(ch) !== -1) {
                clean = clean + ch;
            } else if (ch === " " || ch === "." || ch === ":" || ch === "/") {
                clean = clean + "_";
            }
        }
        if (clean.length === 0) clean = "Ghi_chu_AI";
        if (clean.length > 45) clean = clean.substring(0, 45);
        return clean + suffixExt;
    }

    function exportConversationToEpub(chatContextData) {
        var crcTable = getCrc32LookupTable();
        var rawTitle = (chatContextData && chatContextData.title) ? chatContextData.title : ("Ghi_chu_AI_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmm"));
        var safeTitle = escapeXmlChars(rawTitle);
        var exportTimeStr = Qt.formatDateTime(new Date(), "dd/MM/yyyy hh:mm");
        var modelLabel = (chatContextData && chatContextData.activeModel) ? escapeXmlChars(chatContextData.activeModel) : "reMarkable AI";
        var sessionMsgs = (chatContextData && chatContextData.currentSession) ? chatContextData.currentSession : [];
        var proto = "http" + "://";

        var cssStyles = "body { font-family: sans-serif; line-height: 1.55; color: #000000; margin: 14px; }\n" +
                        "h1 { font-size: 1.35em; border-bottom: 2px solid #000000; padding-bottom: 6px; margin-bottom: 6px; }\n" +
                        "h2 { font-size: 1.18em; margin-top: 14px; margin-bottom: 6px; }\n" +
                        "h3 { font-size: 1.05em; margin-top: 10px; margin-bottom: 4px; }\n" +
                        ".meta { font-size: 0.85em; color: #444444; margin-bottom: 18px; }\n" +
                        ".user-box { border-left: 3px solid #000000; padding-left: 12px; margin: 16px 0 8px 0; }\n" +
                        ".ai-box { margin: 8px 0 20px 0; }\n" +
                        ".sender { font-weight: bold; text-decoration: underline; margin-bottom: 6px; }\n" +
                        "pre { border: 1px solid #000000; padding: 8px; font-family: monospace; white-space: pre-wrap; }\n" +
                        "ul { margin-top: 4px; margin-bottom: 8px; padding-left: 20px; }\n" +
                        "li { margin-bottom: 4px; }\n" +
                        "hr { border: 0; border-top: 1px dashed #666666; margin: 18px 0; }";

        var xhtmlDoc = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
                       "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"" + proto + "www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n" +
                       "<html xmlns=\"" + proto + "www.w3.org/1999/xhtml\" xml:lang=\"vi\">\n" +
                       "<head>\n  <title>" + safeTitle + "</title>\n" +
                       "  <style type=\"text/css\">\n" + cssStyles + "\n  </style>\n</head>\n<body>\n" +
                       "  <h1>" + safeTitle + "</h1>\n" +
                       "  <p class=\"meta\">Thời gian xuất: " + exportTimeStr + " | Mô hình: " + modelLabel + "</p>\n";

        if (sessionMsgs.length > 0) {
            for (var i = 0; i < sessionMsgs.length; i = i + 1) {
                var m = sessionMsgs[i];
                var sName = escapeXmlChars(m.senderLabel || (m.sender === "user" ? "Bạn" : "Trợ lý AI"));
                if (m.sender === "user") {
                    xhtmlDoc = xhtmlDoc + "  <div class=\"user-box\">\n" +
                                          "    <div class=\"sender\">" + sName + ":</div>\n" +
                                          markdownToXhtmlBlocks(m.text) +
                                          "  </div>\n";
                } else {
                    xhtmlDoc = xhtmlDoc + "  <div class=\"ai-box\">\n" +
                                          "    <div class=\"sender\">" + sName + ":</div>\n" +
                                          markdownToXhtmlBlocks(m.text) +
                                          "  </div>\n  <hr/>\n";
                }
            }
        } else {
            xhtmlDoc = xhtmlDoc + "  <div class=\"ai-box\">\n" +
                                  markdownToXhtmlBlocks(chatContextData.transcriptText || "") +
                                  "  </div>\n";
        }
        xhtmlDoc = xhtmlDoc + "</body>\n</html>";

        var containerXml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
                           "<container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\">\n" +
                           "  <rootfiles>\n" +
                           "    <rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/>\n" +
                           "  </rootfiles>\n" +
                           "</container>";

        var bookUuid = "rm-ai-" + new Date().getTime();
        var contentOpf = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
                         "<package xmlns=\"" + proto + "www.idpf.org/2007/opf\" version=\"2.0\" unique-identifier=\"BookId\">\n" +
                         "  <metadata xmlns:dc=\"" + proto + "purl.org/dc/elements/1.1/\">\n" +
                         "    <dc:title>" + safeTitle + "</dc:title>\n" +
                         "    <dc:creator>reMarkable AI Assistant</dc:creator>\n" +
                         "    <dc:language>vi</dc:language>\n" +
                         "    <dc:identifier id=\"BookId\">urn:uuid:" + bookUuid + "</dc:identifier>\n" +
                         "  </metadata>\n" +
                         "  <manifest>\n" +
                         "    <item id=\"ncx\" href=\"toc.ncx\" media-type=\"application/x-dtbncx+xml\"/>\n" +
                         "    <item id=\"chat\" href=\"chat.xhtml\" media-type=\"application/xhtml+xml\"/>\n" +
                         "  </manifest>\n" +
                         "  <spine toc=\"ncx\">\n" +
                         "    <itemref idref=\"chat\"/>\n" +
                         "  </spine>\n" +
                         "</package>";

        var tocNcx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
                     "<ncx xmlns=\"" + proto + "www.daisy.org/z3986/2005/ncx/\" version=\"2005-1\">\n" +
                     "  <head><meta name=\"dtb:uid\" content=\"urn:uuid:" + bookUuid + "\"/></head>\n" +
                     "  <docTitle><text>" + safeTitle + "</text></docTitle>\n" +
                     "  <navMap>\n" +
                     "    <navPoint id=\"nav-1\" playOrder=\"1\">\n" +
                     "      <navLabel><text>Nội dung cuộc trò chuyện</text></navLabel>\n" +
                     "      <content src=\"chat.xhtml\"/>\n" +
                     "    </navPoint>\n" +
                     "  </navMap>\n" +
                     "</ncx>";

        var entries = [
            { name: "mimetype",               data: stringToUtf8ByteArray("application/epub+zip") },
            { name: "META-INF/container.xml", data: stringToUtf8ByteArray(containerXml) },
            { name: "OEBPS/content.opf",      data: stringToUtf8ByteArray(contentOpf) },
            { name: "OEBPS/toc.ncx",          data: stringToUtf8ByteArray(tocNcx) },
            { name: "OEBPS/chat.xhtml",       data: stringToUtf8ByteArray(xhtmlDoc) }
        ];

        var zipBytes = [];
        var centralDirBytes = [];
        var currentOffset = 0;

        for (var eIdx = 0; eIdx < entries.length; eIdx = eIdx + 1) {
            var entry = entries[eIdx];
            var pathBytes = stringToUtf8ByteArray(entry.name);
            var contentBytes = entry.data;
            var crc = computeCrc32Value(contentBytes, crcTable);
            var size = contentBytes.length;

            var localHeader = [
                0x50, 0x4b, 0x03, 0x04,
                20, 0,
                0, 0,
                0, 0,
                0, 0x40, 0x21, 0x54,
                crc & 0xff, (crc >>> 8) & 0xff, (crc >>> 16) & 0xff, (crc >>> 24) & 0xff,
                size & 0xff, (size >>> 8) & 0xff, (size >>> 16) & 0xff, (size >>> 24) & 0xff,
                size & 0xff, (size >>> 8) & 0xff, (size >>> 16) & 0xff, (size >>> 24) & 0xff,
                pathBytes.length & 0xff, (pathBytes.length >>> 8) & 0xff,
                0, 0
            ];

            for (var lh = 0; lh < localHeader.length; lh = lh + 1) zipBytes.push(localHeader[lh]);
            for (var pb = 0; pb < pathBytes.length; pb = pb + 1) zipBytes.push(pathBytes[pb]);
            for (var cb = 0; cb < contentBytes.length; cb = cb + 1) zipBytes.push(contentBytes[cb]);

            var cdHeader = [
                0x50, 0x4b, 0x01, 0x02,
                20, 0, 20, 0,
                0, 0,
                0, 0,
                0, 0x40, 0x21, 0x54,
                crc & 0xff, (crc >>> 8) & 0xff, (crc >>> 16) & 0xff, (crc >>> 24) & 0xff,
                size & 0xff, (size >>> 8) & 0xff, (size >>> 16) & 0xff, (size >>> 24) & 0xff,
                size & 0xff, (size >>> 8) & 0xff, (size >>> 16) & 0xff, (size >>> 24) & 0xff,
                pathBytes.length & 0xff, (pathBytes.length >>> 8) & 0xff,
                0, 0,
                0, 0,
                0, 0,
                0, 0,
                0, 0, 0, 0,
                currentOffset & 0xff, (currentOffset >>> 8) & 0xff, (currentOffset >>> 16) & 0xff, (currentOffset >>> 24) & 0xff
            ];

            for (var cd = 0; cd < cdHeader.length; cd = cd + 1) centralDirBytes.push(cdHeader[cd]);
            for (var cpb = 0; cpb < pathBytes.length; cpb = cpb + 1) centralDirBytes.push(pathBytes[cpb]);

            currentOffset = currentOffset + localHeader.length + pathBytes.length + size;
        }

        var cdStartOffset = zipBytes.length;
        for (var k = 0; k < centralDirBytes.length; k = k + 1) zipBytes.push(centralDirBytes[k]);

        var eocd = [
            0x50, 0x4b, 0x05, 0x06,
            0, 0, 0, 0,
            entries.length & 0xff, (entries.length >>> 8) & 0xff,
            entries.length & 0xff, (entries.length >>> 8) & 0xff,
            centralDirBytes.length & 0xff, (centralDirBytes.length >>> 8) & 0xff, (centralDirBytes.length >>> 16) & 0xff, (centralDirBytes.length >>> 24) & 0xff,
            cdStartOffset & 0xff, (cdStartOffset >>> 8) & 0xff, (cdStartOffset >>> 16) & 0xff, (cdStartOffset >>> 24) & 0xff,
            0, 0
        ];
        for (var eo = 0; eo < eocd.length; eo = eo + 1) zipBytes.push(eocd[eo]);

        var cleanFileName = sanitizeFileNameAscii(rawTitle, ".epub");
        flushExportViaDynamicSettings(zipBytes, cleanFileName, "application/epub+zip");
    }

    function transliterateToAsciiPdfSafe(str) {
        if (!str) return "";
        var srcMap = "àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ";
        var dstMap = "aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD";
        var out = "";
        for (var i = 0; i < str.length; i = i + 1) {
            var ch = str.charAt(i);
            var pos = srcMap.indexOf(ch);
            if (pos !== -1) {
                out = out + dstMap.charAt(pos);
            } else if (str.charCodeAt(i) >= 32 && str.charCodeAt(i) <= 126) {
                if (ch === "(" || ch === ")" || ch === "\\") {
                    out = out + "\\" + ch;
                } else {
                    out = out + ch;
                }
            } else if (ch === "\n") {
                out = out + "\n";
            } else {
                out = out + " ";
            }
        }
        return out;
    }

    function padOffset10(num) {
        var s = "" + num;
        while (s.length < 10) {
            s = "0" + s;
        }
        return s;
    }

    function exportConversationToPdf(chatContextData) {
        var rawTitle = (chatContextData && chatContextData.title) ? chatContextData.title : ("Ghi_chu_AI_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmm"));
        var sessionMsgs = (chatContextData && chatContextData.currentSession) ? chatContextData.currentSession : [];

        var streamLines = [];
        streamLines.push("BT");
        streamLines.push("/F1 14 Tf");
        streamLines.push("45 755 Td");
        streamLines.push("(" + transliterateToAsciiPdfSafe(rawTitle) + ") Tj");
        streamLines.push("/F1 10 Tf");
        streamLines.push("0 -22 Td");

        var yCursor = 733;
        if (sessionMsgs.length > 0) {
            for (var i = 0; i < sessionMsgs.length; i = i + 1) {
                var item = sessionMsgs[i];
                var prefix = item.sender === "user" ? "[Ban]: " : "[AI]: ";
                var cleanBlock = transliterateToAsciiPdfSafe(prefix + item.text);
                var paragraphs = cleanBlock.split("\n");

                for (var p = 0; p < paragraphs.length; p = p + 1) {
                    var lineStr = paragraphs[p];
                    while (lineStr.length > 0 && yCursor > 55) {
                        var chunk = lineStr.substring(0, 78);
                        lineStr = lineStr.substring(78);
                        streamLines.push("(" + chunk + ") Tj");
                        streamLines.push("0 -15 Td");
                        yCursor = yCursor - 15;
                    }
                }
                streamLines.push("0 -8 Td");
                yCursor = yCursor - 8;
            }
        } else {
            var rawLines = transliterateToAsciiPdfSafe(chatContextData.transcriptText || "").split("\n");
            for (var r = 0; r < rawLines.length; r = r + 1) {
                var rStr = rawLines[r];
                while (rStr.length > 0 && yCursor > 55) {
                    var rChunk = rStr.substring(0, 78);
                    rStr = rStr.substring(78);
                    streamLines.push("(" + rChunk + ") Tj");
                    streamLines.push("0 -15 Td");
                    yCursor = yCursor - 15;
                }
            }
        }
        streamLines.push("ET");
        var streamData = streamLines.join("\n");

        var pdfHeader = "%PDF-1.4\n";
        var obj1 = "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n";
        var obj2 = "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n";
        var obj3 = "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n";
        var obj4 = "4 0 obj\n<< /Length " + streamData.length + " >>\nstream\n" + streamData + "\nendstream\nendobj\n";
        var obj5 = "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n";

        var off1 = pdfHeader.length;
        var off2 = off1 + obj1.length;
        var off3 = off2 + obj2.length;
        var off4 = off3 + obj3.length;
        var off5 = off4 + obj4.length;
        var xrefStart = off5 + obj5.length;

        var xrefTable = "xref\n0 6\n" +
                        "0000000000 65535 f \n" +
                        padOffset10(off1) + " 00000 n \n" +
                        padOffset10(off2) + " 00000 n \n" +
                        padOffset10(off3) + " 00000 n \n" +
                        padOffset10(off4) + " 00000 n \n" +
                        padOffset10(off5) + " 00000 n \n" +
                        "trailer\n<< /Size 6 /Root 1 0 R >>\n" +
                        "startxref\n" + xrefStart + "\n%%EOF\n";

        var bodyPdf = pdfHeader + obj1 + obj2 + obj3 + obj4 + obj5 + xrefTable;
        var pdfBytes = stringToUtf8ByteArray(bodyPdf);
        var cleanFileName = sanitizeFileNameAscii(rawTitle, ".pdf");
        flushExportViaDynamicSettings(pdfBytes, cleanFileName, "application/pdf");
    }

    function flushExportViaDynamicSettings(fileByteArray, fileName, mimeType) {
        var reqId = "req_" + new Date().getTime();
        var b64Str = encodeByteArrayToBase64(fileByteArray);

        try {
            var qmlString = "import QtQuick 2.15\n" +
                            "import Qt.labs.settings 1.0\n" +
                            "Settings {\n" +
                            "    fileName: \"/home/root/AI_Notes/export_trigger.conf\"\n" +
                            "    property string exportReqId: \"\"\n" +
                            "    property string exportFileName: \"\"\n" +
                            "    property string exportMimeType: \"\"\n" +
                            "    property string exportBase64: \"\"\n" +
                            "}\n";

            var tempSettingsObj = Qt.createQmlObject(qmlString, exporterExtensionRoot, "dynamicExportSettings");
            tempSettingsObj.exportFileName = fileName;
            tempSettingsObj.exportMimeType = mimeType;
            tempSettingsObj.exportBase64 = b64Str;
            tempSettingsObj.exportReqId = reqId;

            tempSettingsObj.destroy(50);

            activeRequestId = reqId;
            statusPollCount = 0;
            notifyStatus("⏳ Đang đẩy [" + fileName + "] vào My Files (Hãy bấm Accept nếu hiện bảng hỏi)...");
            statusFilePollTimer.restart();
        } catch (settingsErr) {
            notifyStatus("⚠ Lỗi ghi tệp cầu nối: " + settingsErr);
        }
    }

    function pollExportStatusFile() {
        statusPollCount = statusPollCount + 1;
        if (statusPollCount > 35) {
            statusFilePollTimer.stop();
            notifyStatus("⚠ Quá thời gian chờ phản hồi từ tiến trình xuất tệp!");
            return;
        }

        // Mỗi request đọc 1 file /tmp/ai_status_<reqId>.txt riêng biệt để không bao giờ bị QML cache!
        var statusUrl = "file:///tmp/ai_status_" + activeRequestId + ".txt";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", statusUrl, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var raw = (xhr.responseText || "").trim();
                if (raw === "") return;

                var sepIdx = raw.indexOf("|");
                if (sepIdx === -1) return;

                var stateCode = raw.substring(0, sepIdx);
                var msgText = raw.substring(sepIdx + 1);

                if (stateCode === "SUCCESS") {
                    statusFilePollTimer.stop();
                    notifyStatus(msgText);
                } else if (stateCode === "ERROR") {
                    statusFilePollTimer.stop();
                    notifyStatus("⚠ " + msgText);
                }
            }
        };
        xhr.send();
    }

    Rectangle {
        visible: exporterExtensionRoot.popupVisible
        anchors.centerIn: parent
        width: 520; height: 210; radius: 10
        color: "white"; border.color: "black"; border.width: 3; z: 95

        Column {
            anchors.fill: parent; anchors.margins: 18; spacing: 14
            Text {
                text: "THÔNG BÁO KẾT XUẤT TÀI LIỆU"
                font.bold: true; font.pixelSize: 19; color: "black"
            }
            Rectangle { width: parent.width; height: 2; color: "black" }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: exporterExtensionRoot.popupMessage
                font.pixelSize: 18; color: "black"
            }
            Rectangle {
                width: 120; height: 44; radius: 6; color: "black"
                anchors.horizontalCenter: parent.horizontalCenter
                Text { anchors.centerIn: parent; text: "Đóng"; color: "white"; font.pixelSize: 17; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: exporterExtensionRoot.popupVisible = false }
            }
        }
    }
}
