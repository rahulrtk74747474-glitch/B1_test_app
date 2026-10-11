# Police B1 Test — Google Play launch checklist

## Status
- App feature branch: `feature/playstore-admob-release`, kept separate from `main`.
- Release package ID: `com.rahulrtk.policeb1test`. **Choose this identity carefully before your first upload; Play package IDs cannot be changed for the same listing.**
- Play required target: Android 16 / API 36.
- Signed AAB workflow: Actions > **Police B1 Test — Signed Google Play AAB** > Run workflow. It **will fail safely** until signing and production AdMob values are configured.
- Debug builds use **Google's official test ads only**. Production AAB requires real AdMob values.
- The existing question bank contains **12,488 supplied MCQs**, not independently audited for correctness, copyright or current law.

## Step 1 — Accounts
1. Create or use Google Play Console (developer registration/verification/fees are handled by Google).
2. Create or use Google AdMob (identity, payments, taxes, app review and ad serving approval are handled by Google).
3. In AdMob add an Android application matching the Play package ID, create **Banner** and **Interstitial** ad units, and set up Privacy & messaging consent forms.
4. Register your `app-ads.txt` domain/site with AdMob where required; this cannot be completed from GitHub without ownership of the corresponding publisher domain.

## Step 2 — Add GitHub Actions variables (Settings > Secrets and variables > Actions > Variables)
- `ADMOB_APP_ID` — your Android AdMob app ID, format `ca-app-pub-################~##########`.
- `ADMOB_BANNER_ID` — banner ID, format `ca-app-pub-################/##########`.
- `ADMOB_INTERSTITIAL_ID` — interstitial ID, same slash format.

These IDs are public configuration values, not passwords; no production IDs are included in the repository.

## Step 3 — Signing secrets (Settings > Secrets and variables > Actions > Secrets)
Generate your **upload keystore** locally, retain a secure backup, and never commit it:
```sh
keytool -genkeypair -v -keystore police-b1-upload.jks -alias policeb1upload -keyalg RSA -keysize 3072 -validity 10000
base64 -w0 police-b1-upload.jks
```
Add the resulting Base64 as secret `KEYSTORE_BASE64`, plus `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD` as separate secrets. The repository contains no upload key. Enroll in **Play App Signing** in Play Console. Preserve your upload-key backup and the Play signing account.

## Step 4 — Brand, privacy and listing
- Replace the placeholder publisher name, region and monitored support email in **docs/privacy.html** and **assets/privacy_policy.txt**.
- Host `docs/privacy.html` as a publicly reachable, readable permanent web page (for example enable GitHub Pages for this branch's `/docs` folder in repository settings). Verify public URL from an incognito browser before providing it to Play Console.
- Publish an in-app and public privacy policy; current in-app Settings includes privacy text and UMP privacy choices.
- Complete the **Data safety** questionnaire using current Google Mobile Ads SDK disclosure, including data that third-party SDKs collect/share; declare ad presence; review the target-audience, advertising-ID, content rating, permissions and government-affiliation questions honestly.
- Do NOT describe this as an official Haryana Police app. Add clear independent/unofficial disclaimer on the listing and in description; avoid unlicensed government insignia.
- Verify rights/licenses to republish every question and source image. Check outdated answer keys, legacy fonts, missing images and legal sections before commercial release.
- Capture genuine phone screenshots, supply a high-resolution icon and feature graphic; avoid mocked-up screenshots purporting to be actual app UI.

## Step 5 — Release
1. Run **Police B1 Test — Signed Google Play AAB** on this branch and download artifact `police-b1-test-google-play-signed-aab`.
2. Upload it to Play Console **Internal testing** first; check launch and ad/UMP behavior on Android 16/API 36 and other devices, verify offline access and question rendering.
3. New personal Play developer accounts created after 13 Nov 2023 normally require a closed test with at least **12 opted-in testers continuously for 14 days** before applying for production access.
4. Address Pre-launch report, app content & policy declarations, Play Console account verification, billing/tax info, and production review.
5. After testing and approval, submit production rollout from Play Console. No workflow auto-publishes to Play without verified account permissions.

## Ad presentation
- Small anchored adaptive banners above question content in original and balanced exam screens; banner on start/subject selection screens.
- Optional interstitial after the result screen has been reviewed; **not** immediately before the first question, and not at every navigation step. It is limited to no more than one per two completed tests, with a four-minute cooldown, and skipped when unloaded or privacy checks do not permit ads.
- AdMob requests need network; studying and local progress continue offline.
- Never tap your own live ads or ask testers to click them. Debug builds use official Google sample IDs.

## Suggested store metadata (edit as necessary)
**Name:** Police B1 Test: Exam Prep

**Short description:** Offline B1 exam MCQs, subject practice, mock tests and progress tracking.

**Full description:**
Prepare for police B1 promotion assessments with subject-wise revision, random balanced practice exams, optional timed mocks, detailed answer review and saved test history. Choose the number of questions in a test and identify topics that require more revision with progress statistics. The question bank is bundled for offline study; optional advertisements require an internet connection.

**Disclaimer:** This is an independent educational preparation application, not an official Haryana Police or government app. Study questions and answers originate from previously supplied PDF sets and may contain errors or outdated material. Verify legal information against current official sources.
