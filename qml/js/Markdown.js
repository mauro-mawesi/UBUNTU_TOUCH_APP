.pragma library

function escapeHtml(s) {
    return s.replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
}

function escapeInline(s) {
    return s.replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
}

// Private-use Unicode marker — won't collide with anything in user input
// and survives escapeInline() (which only touches &, <, >).
var _CODE_MARK = "";

function renderInline(text, theme) {
    var codeBg = (theme && theme.codeBg) || "#0d1117";
    var linkColor = (theme && theme.linkColor) || "#a5b4fc";

    var codeSlots = [];
    text = text.replace(/`([^`\n]+)`/g, function(_, c) {
        codeSlots.push('<code style="background-color:' + codeBg + '; padding:1px 4px; border-radius:3px; font-family:monospace;">' + escapeInline(c) + '</code>');
        return _CODE_MARK + (codeSlots.length - 1) + _CODE_MARK;
    });

    text = escapeInline(text);

    text = text.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function(_, label, url) {
        return '<a href="' + url + '" style="color:' + linkColor + '">' + label + '</a>';
    });

    text = text.replace(/\*\*([^\*]+)\*\*/g, '<b>$1</b>');
    text = text.replace(/(^|[^\*])\*([^\*\n]+)\*(?!\*)/g, '$1<i>$2</i>');
    text = text.replace(/~~([^~]+)~~/g, '<s>$1</s>');

    text = text.replace(new RegExp(_CODE_MARK + "(\\d+)" + _CODE_MARK, "g"), function(_, idx) {
        return codeSlots[parseInt(idx)];
    });

    return text;
}

function render(md, theme) {
    if (!md) return "";
    var codeBg = (theme && theme.codeBg) || "#0d1117";
    var borderColor = (theme && theme.border) || "#2a3140";
    var linkColor = (theme && theme.linkColor) || "#a5b4fc";

    var lines = md.replace(/\r\n/g, "\n").split("\n");
    var out = [];
    var i = 0;
    var inUl = false, inOl = false;

    function closeLists() {
        if (inUl) { out.push("</ul>"); inUl = false; }
        if (inOl) { out.push("</ol>"); inOl = false; }
    }

    while (i < lines.length) {
        var line = lines[i];

        var fence = line.match(/^```(\w*)/);
        if (fence) {
            closeLists();
            i++;
            var code = [];
            while (i < lines.length && !/^```/.test(lines[i])) {
                code.push(lines[i]);
                i++;
            }
            i++;
            out.push('<pre style="background-color:' + codeBg + '; padding:8px; border-radius:6px; font-family:monospace; white-space:pre-wrap;">' + escapeHtml(code.join("\n")) + '</pre>');
            continue;
        }

        var h = line.match(/^(#{1,6})\s+(.+)$/);
        if (h) {
            closeLists();
            var level = h[1].length;
            out.push('<h' + level + ' style="margin:6px 0">' + renderInline(h[2], theme) + '</h' + level + '>');
            i++;
            continue;
        }

        if (/^(\*\*\*|---|___)\s*$/.test(line)) {
            closeLists();
            out.push('<hr style="border:0; border-top:1px solid ' + borderColor + '; margin:6px 0">');
            i++;
            continue;
        }

        if (/^>\s?/.test(line)) {
            closeLists();
            var quote = [];
            while (i < lines.length && /^>\s?/.test(lines[i])) {
                quote.push(lines[i].replace(/^>\s?/, ""));
                i++;
            }
            out.push('<blockquote style="border-left:3px solid ' + linkColor + '; padding-left:8px; color:' + linkColor + '; margin:4px 0">' + renderInline(quote.join(" "), theme) + '</blockquote>');
            continue;
        }

        var ulMatch = line.match(/^[\-\*\+]\s+(.+)$/);
        if (ulMatch) {
            if (!inUl) { closeLists(); out.push("<ul style='margin:4px 0; padding-left:18px'>"); inUl = true; }
            out.push("<li>" + renderInline(ulMatch[1], theme) + "</li>");
            i++;
            continue;
        }

        var olMatch = line.match(/^\d+\.\s+(.+)$/);
        if (olMatch) {
            if (!inOl) { closeLists(); out.push("<ol style='margin:4px 0; padding-left:20px'>"); inOl = true; }
            out.push("<li>" + renderInline(olMatch[1], theme) + "</li>");
            i++;
            continue;
        }

        if (/^\s*$/.test(line)) {
            closeLists();
            out.push("");
            i++;
            continue;
        }

        closeLists();
        var para = [line];
        i++;
        while (i < lines.length && !/^\s*$/.test(lines[i])
               && !/^(#{1,6}\s|[\-\*\+]\s|\d+\.\s|>\s?|```)/.test(lines[i])) {
            para.push(lines[i]);
            i++;
        }
        out.push("<p style='margin:4px 0'>" + renderInline(para.join(" "), theme) + "</p>");
    }

    closeLists();
    return out.join("\n");
}
