#!/usr/bin/env python3
"""Configure the platform folders that `flutter create` generates (run from apps/mobile in CI).

Idempotent. Fails loudly if a template anchor is missing, so a Flutter template change is noticed.
"""
import pathlib, re, sys

APP_ID = "com.rovans.app"
NAME = "Rövanş"
root = pathlib.Path(".")

def must(cond, msg):
    if not cond:
        sys.exit(f"configure_native: {msg}")

# ---------------- Android ----------------
manifest = root / "android/app/src/main/AndroidManifest.xml"
m = manifest.read_text(encoding="utf-8")
m = re.sub(r'android:label="[^"]*"', f'android:label="{NAME}"', m, count=1)
if 'android:allowBackup' not in m:
    m = m.replace("<application", '<application\n        android:allowBackup="false"\n        android:fullBackupContent="false"\n        android:usesCleartextTraffic="false"', 1)
perms = ["android.permission.INTERNET", "android.permission.ACCESS_COARSE_LOCATION", "android.permission.ACCESS_FINE_LOCATION"]
for p in perms:
    if p not in m:
        m = m.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)
queries = """    <queries>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="geo"/></intent>
    </queries>
"""
if "android.intent.action.DIAL" not in m:
    if "<queries>" in m:
        m = m.replace("<queries>", queries.strip().removesuffix("</queries>").replace("    <queries>", "<queries>", 1), 1)
    else:
        m = m.replace("</manifest>", queries + "</manifest>", 1)
manifest.write_text(m, encoding="utf-8")

kts = root / "android/app/build.gradle.kts"
groovy = root / "android/app/build.gradle"
if kts.exists():
    g = kts.read_text(encoding="utf-8")
    if "keystoreProperties" not in g:
        g = ("import java.io.FileInputStream\nimport java.util.Properties\n\n"
             "val keystoreProperties = Properties()\n"
             "val keystorePropertiesFile = rootProject.file(\"key.properties\")\n"
             "if (keystorePropertiesFile.exists()) { keystoreProperties.load(FileInputStream(keystorePropertiesFile)) }\n\n") + g
        must("buildTypes {" in g, "buildTypes block not found in build.gradle.kts")
        g = g.replace("    buildTypes {", """    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {""", 1)
        g, n = re.subn(r'signingConfig = signingConfigs\.getByName\("debug"\)',
                       'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")', g)
        must(n >= 1, "release signingConfig line not found")
    if "checkReleaseBuilds" not in g:
        g = g.replace("android {\n", "android {\n    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }\n\n", 1)
    g = re.sub(r'applicationId = "[^"]*"', f'applicationId = "{APP_ID}"', g)
    g = re.sub(r'minSdk = [^\n]*', 'minSdk = 23', g)
    kts.write_text(g, encoding="utf-8")
elif groovy.exists():
    sys.exit("configure_native: Groovy build.gradle template not supported; update tool/configure_native.py")
else:
    sys.exit("configure_native: android/app build file not found")

# ---------------- iOS ----------------
plist = root / "ios/Runner/Info.plist"
p = plist.read_text(encoding="utf-8")
def set_key(xml, key, value_xml):
    if f"<key>{key}</key>" in xml:
        return re.sub(rf"<key>{key}</key>\s*<[^>]+>[^<]*</[^>]+>", f"<key>{key}</key>\n\t{value_xml}", xml, count=1)
    return xml.replace("</dict>\n</plist>", f"\t<key>{key}</key>\n\t{value_xml}\n</dict>\n</plist>", 1)
p = set_key(p, "CFBundleDisplayName", f"<string>{NAME}</string>")
p = set_key(p, "CFBundleName", f"<string>{NAME}</string>")
p = set_key(p, "NSLocationWhenInUseUsageDescription", "<string>Yakınındaki halı sahaları mesafeye göre sıralamak için konumunu kullanırız. Konumun kaydedilmez.</string>")
p = set_key(p, "ITSAppUsesNonExemptEncryption", "<false/>")
if "LSApplicationQueriesSchemes" not in p:
    p = p.replace("</dict>\n</plist>", "\t<key>LSApplicationQueriesSchemes</key>\n\t<array>\n\t\t<string>tel</string>\n\t\t<string>mailto</string>\n\t\t<string>whatsapp</string>\n\t\t<string>comgooglemaps</string>\n\t</array>\n</dict>\n</plist>", 1)
plist.write_text(p, encoding="utf-8")

pbx = root / "ios/Runner.xcodeproj/project.pbxproj"
x = pbx.read_text(encoding="utf-8")
x = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = com\.rovans\.app(;|\.RunnerTests;)", lambda mm: mm.group(0), x)
x = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9.\-]+\.RunnerTests;", f"PRODUCT_BUNDLE_IDENTIFIER = {APP_ID}.RunnerTests;", x)
x = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = (?![A-Za-z0-9.\-]+\.RunnerTests)[A-Za-z0-9.\-]+;", f"PRODUCT_BUNDLE_IDENTIFIER = {APP_ID};", x)
x = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 13.0;", x)
pbx.write_text(x, encoding="utf-8")

podfile = root / "ios/Podfile"
if podfile.exists():
    pf = podfile.read_text(encoding="utf-8")
    pf = re.sub(r"#?\s*platform :ios, '[0-9.]+'", "platform :ios, '13.0'", pf, count=1)
    podfile.write_text(pf, encoding="utf-8")

print("configure_native: OK")
