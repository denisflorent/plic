/*
 Help Viewer sidebar integration for Plic.

 Tells the native Help Viewer to show its Table of Contents button,
 which renders toc.html as a sidebar navigation panel.
*/

document.addEventListener("DOMContentLoaded", function () {
    var parts = window.location.href.split("/");
    var isSubpage = parts[parts.length - 2] === "pages";

    function goToTOC() {
        window.location = isSubpage ? "../toc.html" : "toc.html";
    }

    if ("HelpViewer" in window) {
        window.HelpViewer.showTOCButton(true, goToTOC, goToTOC);
    }
});
