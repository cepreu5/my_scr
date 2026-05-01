del "C:\dev\Projects\Androd\my_scr\android\app\build\outputs\flutter-apk\app-debug.apk"        
flutter build apk --debug
adb install "C:\dev\Projects\Androd\my_scr\android\app\build\outputs\flutter-apk\app-debug.apk"
adb logcat *:S flutter:V