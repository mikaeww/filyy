import QtQuick
import QtQuick.Pdf
import "Util.js" as Util

// PDF pages for quick look; loaded on demand like the media preview.
Item {
    id: root

    property string path: ""
    property int page: 0
    readonly property int pageCount: document.pageCount

    PdfDocument {
        id: document
        source: root.path ? Util.fileUrl(root.path) : ""
    }

    // Pages render without a background; paper sits exactly behind the painted page.
    Rectangle {
        visible: image.status === Image.Ready
        x: (root.width - image.paintedWidth) / 2
        y: (root.height - image.paintedHeight) / 2
        width: image.paintedWidth
        height: image.paintedHeight
        color: "white"
    }

    PdfPageImage {
        id: image
        anchors.fill: parent
        document: document
        currentFrame: Math.min(root.page, Math.max(0, root.pageCount - 1))
        // Only the height is fixed, so the page keeps its own aspect ratio.
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
    }
}
