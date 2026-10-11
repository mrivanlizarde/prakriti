#!/bin/zsh
# Regenerates every source and preview in docs/v2/icons from tools/make_icons.py.
#
#   cd ~/Code/prakriti/docs/v2/icons && zsh tools/render_previews.sh
#
# Needs: Xcode 27 (for Icon Composer's ictool and actool), Swift, Python 3, Google Chrome (sheets only).
# Then LOOK at previews/sheet-app-icon.png and previews/sheet-menubar.png. Reading the SVG is not checking it.
set -euo pipefail
cd "${0:A:h}/.."
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

python3 tools/make_icons.py .
swiftc -O tools/render.swift -o "$TMP/render" 2>/dev/null
mkdir -p previews/app-icon previews/appearances previews/flat previews/menubar previews/context

# 1. The layered icon through Apple's own renderer (the same one Icon Composer uses).
for px in 1024 256 64 32 16; do
  "$ICTOOL" source/Prakriti.icon --export-image --output-file previews/app-icon/app-icon-$px.png \
    --platform macOS --rendition Default --width $px --height $px --scale 1 >/dev/null
  "$ICTOOL" source/Prakriti.icon --export-image --output-file previews/app-icon/app-icon-dark-$px.png \
    --platform macOS --rendition Dark --width $px --height $px --scale 1 >/dev/null
done
for r in Default Dark ClearLight ClearDark TintedLight TintedDark; do
  "$ICTOOL" source/Prakriti.icon --export-image --output-file previews/appearances/$r-256.png \
    --platform macOS --rendition $r --width 256 --height 256 --scale 1 >/dev/null
done

# 2. The flat fallback, drawn by AppKit.
for px in 1024 256 64 32; do
  "$TMP/render" svg source/prakriti-icon-flat.svg previews/flat/flat-$px.png $px
done

# 3. The menu bar glyphs, drawn as template images are drawn: black on a light bar, white on a dark one.
for st in "" -working-1 -working-2 -waiting -problem -paused -not-watching; do
  for pt in 16 18 22; do
    for sc in 1 2; do
      "$TMP/render" svg source/menubar/prakriti-menubar$st.svg previews/menubar/menubar$st-${pt}pt@${sc}x-light.png $((pt*sc)) "#ECECEC" "#000000"
      "$TMP/render" svg source/menubar/prakriti-menubar$st.svg previews/menubar/menubar$st-${pt}pt@${sc}x-dark.png $((pt*sc)) "#2A2A2C" "#FFFFFF"
    done
  done
done
"$TMP/render" bar source/menubar/prakriti-menubar{,-working-1,-working-2,-waiting,-problem,-paused,-not-watching}.svg previews/menubar/menubar-in-context.png

# 4. The real thing: compile the .icon with actool exactly as Xcode does, wrap it in a throwaway app
#    bundle, and ask the system for its icon (what Finder and the Dock will show).
mkdir -p "$TMP/in" "$TMP/out" "$TMP/IconCheck.app/Contents/Resources" "$TMP/IconCheck.app/Contents/MacOS"
cp -R source/Prakriti.icon "$TMP/in/AppIcon.icon"
xcrun actool "$TMP/in/AppIcon.icon" --compile "$TMP/out" --platform macosx --minimum-deployment-target 27.0 \
  --app-icon AppIcon --output-partial-info-plist "$TMP/out/partial.plist" >/dev/null
cp "$TMP/out/Assets.car" "$TMP/out/AppIcon.icns" "$TMP/IconCheck.app/Contents/Resources/"
cat > "$TMP/IconCheck.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>studio.therowan.prakriti.iconcheck</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>IconCheck</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIconName</key><string>AppIcon</string>
</dict></plist>
PLIST
# A bundle without an executable gets the system's "cannot open" badge drawn over its icon.
print '#!/bin/sh\nexit 0' > "$TMP/IconCheck.app/Contents/MacOS/IconCheck"; chmod +x "$TMP/IconCheck.app/Contents/MacOS/IconCheck"
"$TMP/render" app "$TMP/IconCheck.app" previews/context/finder-render-512.png 512
[[ -d "$HOME/Applications/Prakriti.app" ]] && "$TMP/render" app "$HOME/Applications/Prakriti.app" "$TMP/v1.png" 512

# 5. Beside Apple's creative apps, as installed on this Mac. INTERNAL ONLY: this picture contains
#    Apple's icons, for judging ours next to them. Do not publish it.
typeset -a apps
for p in "/Applications/Final Cut Pro Creator Studio.app" "/Applications/Motion Creator Studio.app" \
         "/Applications/Compressor Creator Studio.app" "/Applications/Pixelmator Pro Creator Studio.app" \
         "/Applications/Logic Pro Creator Studio.app" "/System/Applications/Photos.app"; do
  [[ -d "$p" ]] || continue
  n=${${p:t}%.app}; n=${n// /-}
  "$TMP/render" app "$p" "$TMP/$n.png" 256
  apps+=("$n.png")
done
cp previews/context/finder-render-512.png "$TMP/new.png"
{
  print '<html><head><style>body{margin:0;font:12px system-ui, -apple-system, Helvetica}.dock{display:flex;gap:6px;align-items:flex-end;padding:18px 22px 10px;margin:24px;border-radius:24px}'
  print '.light{background:linear-gradient(135deg,#dfe6ee,#efe6da)}.dark{background:linear-gradient(135deg,#1d2433,#2e2621)}'
  print '.dock div{display:flex;flex-direction:column;align-items:center;gap:4px}.light span{color:#333}.dark span{color:#ddd}'
  print 'img{width:64px;height:64px}.sep{width:1px;height:56px;background:rgba(128,128,128,.4);margin:0 6px 18px}</style></head><body>'
  for cls in light dark; do
    print -n "<div class='dock $cls'><div><img src='new.png'><span>Prakriti v2</span></div>"
    [[ -f "$TMP/v1.png" ]] && print -n "<div><img src='v1.png'><span>v1</span></div>"
    print -n "<div class=sep></div>"
    for a in $apps; do print -n "<div><img src='$a'><span>${${a%.png}//-Creator-Studio/}</span></div>"; done
    print "</div>"
  done
  print '</body></html>'
} > "$TMP/dock.html"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=2 \
  --window-size=760,300 --screenshot="$PWD/previews/context/dock-beside-apple-apps.png" "file://$TMP/dock.html" 2>/dev/null

# 6. Review sheets (small sizes shown at real size and magnified, pixel for pixel).
cp previews/app-icon/*.png previews/menubar/*.png "$TMP/"
{
  print '<html><head><style>body{margin:0;padding:16px;font:12px system-ui, -apple-system, Helvetica;background:#fff;color:#333}'
  print '.row{display:flex;gap:18px;align-items:flex-end;margin-bottom:14px}.px{image-rendering:pixelated}'
  print '.tile{padding:10px;border-radius:10px;display:flex;gap:12px;align-items:flex-end}.l{background:#f2f2f0}.d{background:#1f1f21}</style></head><body>'
  print '<div class=row><img src="app-icon-1024.png" width=256><img src="app-icon-dark-1024.png" width=256></div>'
  print '<div class=row><div class="tile l"><img src="app-icon-256.png" width=128><img src="app-icon-64.png" width=64><img src="app-icon-32.png" width=32><img src="app-icon-16.png" width=16></div>'
  print '<div class="tile d"><img src="app-icon-dark-256.png" width=128><img src="app-icon-dark-64.png" width=64><img src="app-icon-dark-32.png" width=32><img src="app-icon-dark-16.png" width=16></div></div>'
  print '<div class=row><img class=px src="app-icon-32.png" width=128><img class=px src="app-icon-16.png" width=128><img class=px src="app-icon-dark-32.png" width=128><img class=px src="app-icon-dark-16.png" width=128></div>'
  print '<p>Top: 1024 px, default and dark. Middle: 128, 64, 32 and 16 px at real size. Bottom: 32 and 16 px magnified 4x and 8x.</p></body></html>'
} > "$TMP/sheet-app.html"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=1 \
  --window-size=720,640 --screenshot="$PWD/previews/sheet-app-icon.png" "file://$TMP/sheet-app.html" 2>/dev/null
{
  print '<html><head><style>body{margin:0;padding:16px;font:12px system-ui, -apple-system, Helvetica;background:#fff;color:#333}'
  print '.row{display:flex;gap:10px;align-items:center;margin-bottom:8px}.px{image-rendering:pixelated}.lab{width:150px}</style></head><body>'
  for st in "" -working-1 -working-2 -waiting -problem -paused -not-watching; do
    for sc in 1 2; do
      print -n "<div class=row><span class=lab>${${st#-}:-idle} @${sc}x</span>"
      for th in light dark; do for pt in 16 18 22; do
        print -n "<img class=px src='menubar$st-${pt}pt@${sc}x-$th.png' width=$((pt*sc*(sc==1?4:2)))>"
      done; done
      print "</div>"
    done
  done
  print '<p>16, 18 and 22 pt, light then dark, at 1x (magnified 4x) and 2x (magnified 2x). Pixel for pixel.</p>'
  print '<img src="menubar-in-context.png" width=600></body></html>'
} > "$TMP/sheet-mb.html"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=1 \
  --window-size=760,1340 --screenshot="$PWD/previews/sheet-menubar.png" "file://$TMP/sheet-mb.html" 2>/dev/null
cp previews/appearances/*.png "$TMP/"
{
  print '<html><head><style>body{margin:0;padding:16px;font:12px system-ui, -apple-system, Helvetica;color:#fff;'
  print 'background:linear-gradient(135deg,#55657d,#b79a7c);display:grid;grid-template-columns:repeat(3,200px);gap:14px}'
  print 'figure{margin:0}figcaption{margin-top:4px}</style></head><body>'
  for r in Default Dark ClearLight ClearDark TintedLight TintedDark; do
    print "<figure><img src='$r-256.png' width=200><figcaption>$r</figcaption></figure>"
  done
  print '</body></html>'
} > "$TMP/sheet-appearances.html"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=1 \
  --window-size=660,480 --screenshot="$PWD/previews/sheet-appearances.png" "file://$TMP/sheet-appearances.html" 2>/dev/null
echo "Done. Now open previews/sheet-app-icon.png, previews/sheet-menubar.png and previews/context/ and look."
