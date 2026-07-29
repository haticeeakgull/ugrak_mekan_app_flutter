@echo off
echo ==========================================
echo SHA-1 Fingerprint Alma Komutu
echo ==========================================
echo.
echo DEBUG SHA-1 (Development icin):
echo ----------------------------------------
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr SHA1
echo.
echo.
echo RELEASE SHA-1 (Production icin):
echo ----------------------------------------
echo Bu komutu calistirin (key.properties dosyanizdaki keystore yolu ile):
echo.
echo keytool -list -v -keystore [KEYSTORE_YOLU] -alias [ALIAS] -storepass [STOREPASS] -keypass [KEYPASS]
echo.
echo Ornek:
echo keytool -list -v -keystore C:\Users\hakgl\upload-keystore.jks -alias upload
echo.
echo ==========================================
echo.
echo Bu SHA-1 degerlerini Google Cloud Console'a eklemelisiniz:
echo https://console.cloud.google.com/apis/credentials
echo.
pause
