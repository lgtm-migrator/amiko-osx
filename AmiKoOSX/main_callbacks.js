/*
 Copyright (c) 2017 Max Lungarella <cybrmx@gmail.com>
 Created on 28/04/2017.
 All main JS callbacks
 */

function displayFachinfo(ean, anchor) {
    try {
        if (anchor == 'undefined')
            anchor = '';
        var payload = ["main_cb", "display_fachinfo", ean, anchor];
        WebViewJavascriptBridge.send(payload);
    }
    catch (e) {
        // alert(e);
    }
}

/**
 * Identifies the anchor's id and scrolls to the first mark tag.
 * Javascript is brilliant :-)
 */
function moveToHighlight(anchor) {
    if (typeof anchor !== 'undefined') {
        var elem = document.getElementById(anchor);
        var marks = elem.getElementsByClassName('mark')
        if (marks.length > 0) {
            marks[0].scrollIntoView(true);
        }
    }
}
