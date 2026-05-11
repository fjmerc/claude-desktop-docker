#!/bin/bash
# Customize noVNC defaults so the X display auto-resizes to the browser
# viewport. Without this, the iframe shows the X display at 1:1 against a
# fixed 1920x1080 geometry, producing scrollbars or dead-space depending
# on viewport size — and users have to remember `?resize=remote` in the URL.

NOVNC_DIR=/usr/share/novnc
NOVNC_APP_UI="${NOVNC_DIR}/app/ui.js"

# Bare http://host:6080/ should land on a usable page. Upstream noVNC ships
# vnc.html as the main client; the bundled index.html (if any) is a generic
# landing page. Overwrite with a redirect to vnc.html with autoconnect +
# server-side resize so the desktop sizes to the viewport.
cat > /usr/share/novnc/index.html << 'EOF'
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Claude Desktop VNC</title>
<meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&resize=remote&reconnect=true">
</head><body>Redirecting to <a href="vnc.html?autoconnect=true&resize=remote&reconnect=true">vnc.html</a>...</body></html>
EOF
echo "wrote /usr/share/novnc/index.html (redirect to vnc.html with autoconnect + resize=remote)"

if [ ! -f "$NOVNC_APP_UI" ]; then
  echo "Warning: $NOVNC_APP_UI does not exist, skipping noVNC customization"
else
  # vnc.html uses ui.js's settings system. Match BOTH single- and double-
  # quoted forms — Ubuntu 22.04 noVNC ships single quotes, older script
  # assumed double.
  if grep -qE "initSetting\(['\"]resize['\"], ['\"]off['\"]" "$NOVNC_APP_UI"; then
    sed -i -E "s/(initSetting\(['\"]resize['\"], ['\"])off(['\"])/\1remote\2/g" "$NOVNC_APP_UI"
    echo "ui.js: resize default set to 'remote'"
  fi
fi

# vnc_auto.html and vnc_lite.html have their own inline config and don't
# load ui.js. Patch the defaults of getConfigVar('resize', false) ->
# getConfigVar('resize', true) so they also auto-resize without URL params.
for f in /usr/share/novnc/vnc_auto.html /usr/share/novnc/vnc_lite.html; do
  if [ -f "$f" ] && grep -qE "getConfigVar\(['\"]resize['\"], false\)" "$f"; then
    sed -i -E "s/(getConfigVar\(['\"]resize['\"]), false\)/\1, true)/" "$f"
    echo "$(basename "$f"): resizeSession default set to true"
  fi
done

# Both vnc_auto.html and vnc_lite.html ship without a <style> block, so the
# default browser margin on <body> (typically 8px) pushes the canvas past
# the viewport edge — scrollbars appear even when the X session is sized
# correctly. Inject a tiny stylesheet that zeros the margin and hides
# overflow. Idempotent via the comment marker.
NOVNC_BODY_CSS='<style id="claude-docker-novnc-fix">html,body{margin:0;padding:0;overflow:hidden;height:100%}</style>'
for f in /usr/share/novnc/vnc_auto.html /usr/share/novnc/vnc_lite.html; do
  if [ -f "$f" ] && ! grep -q 'claude-docker-novnc-fix' "$f"; then
    sed -i "s|</head>|${NOVNC_BODY_CSS}</head>|" "$f"
    echo "$(basename "$f"): injected body-margin/overflow fix"
  fi
done

# Clipboard sync shim. Mainline noVNC (incl. v1.6.0) only supports clipboard
# transfer via the manual sidebar panel — pressing Ctrl+V in the browser sends
# the keystroke but never pushes the host clipboard to the X CLIPBOARD, so the
# paste no-ops. This shim adds:
#   1) Outbound sync: when the guest copies, write to navigator.clipboard so
#      the host can paste with normal Ctrl+V outside the VNC tab.
#   2) Inbound paste: on Ctrl/Cmd+V in the browser, read the host clipboard,
#      push it to the VNC server via SetCutText, then synthesize the Ctrl+V
#      keystroke so the guest sees the fresh content.
# Requires a secure context (localhost or HTTPS) and a one-time browser
# permission grant for clipboard-read. Falls back silently to noVNC's sidebar
# workflow if readText() is denied (e.g. Firefox without grant).
SHIM_MARKER='claude-docker-clipboard-shim'
SHIM_SCRIPT=$(cat <<'JS'
<script type="module" id="claude-docker-clipboard-shim">
// noVNC v1.6 doesn't expose UI on window; it's an ES module default export.
// ES modules are singletons per URL, so importing app/ui.js here returns the
// same UI instance vnc.html bootstrapped — UI.rfb will be the live RFB once
// the user has connected.
import UI from "./app/ui.js";

function whenRfbReady(cb) {
  if (UI && UI.rfb) cb(UI.rfb);
  else setTimeout(() => whenRfbReady(cb), 200);
}

// Guest copy -> host clipboard
whenRfbReady((rfb) => {
  rfb.addEventListener('clipboard', async (e) => {
    if (!navigator.clipboard || !navigator.clipboard.writeText) return;
    try { await navigator.clipboard.writeText(e.detail.text); } catch (err) {}
  });
});

// Host Ctrl/Cmd+V -> push to guest clipboard, then synthesize paste keystroke.
// noVNC's keyboard listener lives on the canvas (bubble phase). Capture-phase
// stopPropagation here blocks descent to the canvas, so the raw V keystroke
// never reaches the guest; we re-issue it via rfb.sendKey AFTER the SetCutText
// has had a tick to land.
document.addEventListener('keydown', async (e) => {
  const isPaste = (e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey &&
                  (e.key === 'v' || e.key === 'V');
  if (!isPaste) return;
  if (!UI || !UI.rfb) return;
  if (!navigator.clipboard || !navigator.clipboard.readText) return;

  e.preventDefault();
  e.stopPropagation();

  const CTRL = 0xffe3, V = 0x76;
  const synthCtrlV = () => {
    UI.rfb.sendKey(CTRL, 'ControlLeft', true);
    UI.rfb.sendKey(V,    'KeyV',        true);
    UI.rfb.sendKey(V,    'KeyV',        false);
    UI.rfb.sendKey(CTRL, 'ControlLeft', false);
  };

  try {
    const text = await navigator.clipboard.readText();
    if (text) {
      UI.rfb.clipboardPasteFrom(text);
      await new Promise(r => setTimeout(r, 30));
    }
  } catch (err) {
    // Permission denied (e.g. Firefox, or user hasn't granted) — fall through
    // and still send Ctrl+V so anything previously pushed via the sidebar
    // clipboard still pastes.
  }
  synthCtrlV();
}, true);
</script>
JS
)
for f in /usr/share/novnc/vnc.html /usr/share/novnc/vnc_lite.html; do
  if [ -f "$f" ] && ! grep -q "$SHIM_MARKER" "$f"; then
    # Append the script just before </body>. Use a temp file to keep sed
    # syntax sane with the multi-line block.
    awk -v shim="$SHIM_SCRIPT" '
      /<\/body>/ && !done { print shim; done = 1 }
      { print }
    ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    echo "$(basename "$f"): injected clipboard sync shim"
  fi
done

# Create a directory to store our customizations
mkdir -p /tmp/novnc-custom

# Set up a custom page in the temporary directory
cat > /tmp/novnc-custom/resize.html << EOL
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude Desktop Dynamic Scaling</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            text-align: center;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: white;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
        }
        p {
            color: #666;
            line-height: 1.6;
        }
        .buttons {
            margin: 30px 0;
        }
        .btn {
            display: inline-block;
            margin: 0 10px;
            padding: 10px 20px;
            background-color: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
        }
        .description {
            text-align: left;
            margin: 20px 0;
            padding: 15px;
            background-color: #f9f9f9;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Claude Desktop Dynamic Scaling</h1>
        <p>Choose your preferred way to access Claude Desktop with dynamic scaling:</p>
        
        <div class="buttons">
            <a href="/vnc.html?autoconnect=true&resize=remote" class="btn">Auto-scaling Interface</a>
            <a href="/vnc.html?autoconnect=true&resize=scale" class="btn">Local Scaling</a>
            <a href="/vnc.html?autoconnect=true&resize=off" class="btn">Standard Interface</a>
        </div>
        
        <div class="description">
            <p><strong>Auto-scaling Interface:</strong> Automatically scales the desktop to fit your browser window. Best for most users.</p>
            <p><strong>Local Scaling:</strong> Scales locally in the browser. Better for high-DPI displays.</p>
            <p><strong>Standard Interface:</strong> No automatic scaling. Use this if you prefer to control scaling manually.</p>
        </div>
    </div>
</body>
</html>
EOL

echo "Custom scaling options page created at /tmp/novnc-custom/resize.html"

# Done
echo "noVNC customization completed"
