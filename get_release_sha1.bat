@echo off
echo ========================================
echo Release Keystore SHA-1 Fingerprint
echo ========================================
echo.
echo Bu komutu çalıştırın (key.properties dosyanızda belirtilen keystore ile):
echo.
echo keytool -list -v -keystore [KEYSTORE_PATH] -alias [KEY_ALIAS]
echo.
echo Örnek:
echo keytool -list -v -keystore C:\Users\hakgl\upload-keystore.jks -alias upload
echo.
echo Çıktıda "SHA1:" satırını Google Cloud Console'a ekleyin.
echo ========================================
pause
