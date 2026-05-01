cls
# Изтриваме стария APK, ако съществува
if (Test-Path "android\app\build\outputs\flutter-apk\app-debug.apk") {
    Remove-Item "android\app\build\outputs\flutter-apk\app-debug.apk"
}

# Стартираме Flutter билд
flutter build apk --debug

# Инсталираме през adb (автоматично намира пътя, ако си в папката на проекта)
adb install "android\app\build\outputs\flutter-apk\app-debug.apk"