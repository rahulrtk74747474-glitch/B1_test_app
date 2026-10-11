#!/usr/bin/env python3
"""Configure Flutter-generated Android scaffold for Police B1 Test builds.

No real AdMob IDs or signing passwords are stored in the repository.
"""
import argparse
import os
import re
from pathlib import Path

PACKAGE = 'com.rahulrtk.policeb1test'
TEST_ADMOB_APP_ID = 'ca-app-pub-3940256099942544~3347511713'

parser = argparse.ArgumentParser()
parser.add_argument('--release', action='store_true')
args = parser.parse_args()

project = Path('android/app')
gradle = project / 'build.gradle.kts'
manifest = project / 'src/main/AndroidManifest.xml'
if not gradle.exists() or not manifest.exists():
    raise SystemExit('First run: flutter create --empty --platforms=android --project-name b1_test_app .')

app_id = os.environ.get('ADMOB_APP_ID', '').strip() if args.release else TEST_ADMOB_APP_ID
if not re.fullmatch(r'ca-app-pub-\d{16}~\d{10}', app_id):
    raise SystemExit('Missing/invalid ADMOB_APP_ID (ca-app-pub-################~##########)')

if args.release:
    for key in ('KEYSTORE_FILE', 'KEYSTORE_PASSWORD', 'KEY_ALIAS', 'KEY_PASSWORD'):
        if not os.environ.get(key):
            raise SystemExit(f'Release signing variable missing: {key}')
    if not Path(os.environ['KEYSTORE_FILE']).is_file():
        raise SystemExit('Upload keystore file is missing')
    for key in ('ADMOB_BANNER_ID', 'ADMOB_INTERSTITIAL_ID'):
        if not re.fullmatch(r'ca-app-pub-\d{16}/\d{10}', os.environ.get(key, '')):
            raise SystemExit(f'Invalid production ad unit: {key}')

xml = manifest.read_text()
xml = xml.replace('android:label="b1_test_app"', 'android:label="Police B1 Test"')
if 'com.google.android.gms.ads.APPLICATION_ID' not in xml:
    xml = xml.replace('<application', '''<application
        ''', 1)
    xml = xml.replace('>', f'''>
        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
                   android:value="{app_id}" />''', 1) if False else xml
    # Insert inside the application element, not the XML declaration.
    xml = re.sub(r'(<application\b[^>]*>)',
                 lambda m: m.group(1) + '\n        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="' + app_id + '" />',
                 xml, count=1)
if 'android.permission.INTERNET' not in xml:
    xml = xml.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />\n    <application', 1)
manifest.write_text(xml)

text = gradle.read_text()
text = re.sub(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{PACKAGE}"', text)
text = re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion', 'targetSdk = 36', text)
text = re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 36', text)
text = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', text)
if args.release:
    # Replace Flutter's starter debug signing in release builds.
    text = text.replace('signingConfig = signingConfigs.getByName("debug")',
                        'signingConfig = signingConfigs.getByName("policeB1Upload")')
    config = '''
    signingConfigs {
        create("policeB1Upload") {
            storeFile = file(System.getenv("KEYSTORE_FILE"))
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
'''
    text = re.sub(r'(\n\s*buildTypes\s*\{)', '\n' + config + r'\1', text, count=1)
    if 'signingConfig = signingConfigs.getByName("policeB1Upload")' not in text:
        raise SystemExit('Release signing config was not applied; check generated build.gradle.kts')
gradle.write_text(text)

print(f'Configured Android: package={PACKAGE}, targetSdk=36, signing={"upload-key" if args.release else "debug"}, testAds={not args.release}')
