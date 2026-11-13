import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: guideExtensionRoot
    anchors.fill: parent

    // =========================================================================
    // 1. KHAI BÁO GIAO THỨC TÍCH HỢP CHUẨN (EXTENSION MANIFEST API)
    // =========================================================================
    property string extensionId: "guide_extension"
    property string extensionName: "Hướng dẫn"
    property string extensionDescription: "Xem tài liệu hướng dẫn khai báo và viết extension mẫu."

    property var extensionActions: [
        { "actionId": "view_guide", "label": "Xem hướng dẫn" }
    ]

    property bool guidePageVisible: false

    // =========================================================================
    // 2. HÀM THỰC THI HÀNH ĐỘNG (EXECUTE ACTION)
    // =========================================================================
    function executeAction(actionId, chatContextData) {
        if (actionId === "view_guide") {
            guidePageVisible = true;
        }
    }

    // =========================================================================
    // 3. GIAO DIỆN TRANG HƯỚNG DẪN KHAI BÁO EXTENSION MẪU
    // =========================================================================
    Rectangle {
        id: guideModalContainer
        visible: guideExtensionRoot.guidePageVisible
        anchors.fill: parent
        anchors.margins: 18
        color: "white"
        border.color: "black"
        border.width: 4
        radius: 12
        z: 98

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Thanh tiêu đề trang Hướng dẫn
        Rectangle {
            id: guideHeader
            width: parent.width; height: 74
            color: "black"
            anchors.top: parent.top

            Text {
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "📖 HƯỚNG DẪN TÍCH HỢP & VIẾT EXTENSION MẪU"
                font.pixelSize: 20; font.bold: true; color: "white"
            }

            Rectangle {
                width: 125; height: 48; radius: 6; color: "white"
                anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "✕ Đóng"
                    font.pixelSize: 18; font.bold: true; color: "black"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: guideExtensionRoot.guidePageVisible = false
                }
            }
        }

        // Nội dung hướng dẫn có thể cuộn
        Flickable {
            anchors.top: guideHeader.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 20
            contentWidth: width
            contentHeight: guideCol.implicitHeight + 30
            clip: true

            Column {
                id: guideCol
                width: parent.width
                spacing: 14

                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "1. Cơ chế nạp động và Bật / Tắt Extension"
                    font.pixelSize: 20; font.bold: true; color: "black"
                }

                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "• Toàn bộ các tệp tiện ích mở rộng (.qml) được đặt tại thư mục:\n" +
                          "  /home/root/AI_Notes/extensions/\n" +
                          "• Khi mở ứng dụng hoặc bấm vào nút [Tiện ích ▾] trên thanh Header, hệ thống sẽ tự động quét thư mục này và hiển thị danh sách các tiện ích.\n" +
                          "• Bạn có thể chạm vào nút [✓ BẬT] / [  TẮT] ngay cạnh tên tiện ích trong menu [Tiện ích ▾] để kích hoạt hoặc vô hiệu hóa tiện ích đó bất kỳ lúc nào."
                    font.pixelSize: 18; color: "#222222"
                }

                Rectangle { width: parent.width; height: 2; color: "black" }

                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "2. Giao thức chuẩn khai báo Extension (Extension Manifest API)"
                    font.pixelSize: 20; font.bold: true; color: "black"
                }

                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "Mỗi tệp .qml trong thư mục /extensions/ chỉ cần tuân thủ cấu trúc mẫu dưới đây:"
                    font.pixelSize: 18; color: "#222222"
                }

                Rectangle {
                    width: parent.width
                    height: sampleCodeBox.implicitHeight + 28
                    color: "#F4F4F4"
                    border.color: "black"; border.width: 2; radius: 8

                    Text {
                        id: sampleCodeBox
                        anchors.fill: parent; anchors.margins: 14
                        font.family: "monospace"
                        font.pixelSize: 17
                        wrapMode: Text.WordWrap
                        color: "black"
                        text: "import QtQuick 2.15\n\n" +
                              "Item {\n" +
                              "    property string extensionId: \"unique_id\"\n" +
                              "    property string extensionName: \"Tên hiển thị trên menu\"\n" +
                              "    property string extensionDescription: \"Mô tả ngắn gọn\"\n\n" +
                              "    property var extensionActions: [\n" +
                              "        { \"actionId\": \"do_something\", \"label\": \"Tên nút bấm\" }\n" +
                              "    ]\n\n" +
                              "    function executeAction(actionId, chatContextData) {\n" +
                              "        if (actionId === \"do_something\") {\n" +
                              "            // Xử lý logic nghiệp vụ với dữ liệu chatContextData\n" +
                              "        }\n" +
                              "    }\n" +
                              "}"
                    }
                }

                Rectangle { width: parent.width; height: 2; color: "black" }

                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "3. Dữ liệu nhận được qua tham số chatContextData"
                    font.pixelSize: 20; font.bold: true; color: "black"
                }

                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "• chatContextData.title: Tiêu đề phiên ghi chú hiện tại.\n" +
                          "• chatContextData.activeModel: Tên mô hình AI đang hoạt động.\n" +
                          "• chatContextData.deviceModel: Tên dòng máy reMarkable.\n" +
                          "• chatContextData.transcriptText: Toàn bộ nội dung hội thoại dạng văn bản.\n" +
                          "• chatContextData.currentSession: Mảng danh sách các tin nhắn [{ sender, senderLabel, text, timestamp }]."
                    font.pixelSize: 18; color: "#222222"
                }

                Rectangle { width: parent.width; height: 2; color: "black" }

                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "4. Nguyên tắc kỹ thuật bắt buộc (Guardrails)"
                    font.pixelSize: 20; font.bold: true; color: "black"
                }

                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "• Tuyệt đối KHÔNG dùng Biểu thức chính quy (Regex).\n" +
                          "• Tuyệt đối KHÔNG dùng toán tử nhân trong tệp .qmd để tránh lỗi qmldiff.\n" +
                          "• Không phụ thuộc các gói cài đặt ngoài (Zero-Dependency)."
                    font.pixelSize: 18; color: "#222222"
                }
            }
        }
    }
}
