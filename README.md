name: Build Android APK

on:
  push:
    branches: [ main, master ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.10'

    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install flet buildozer
        if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

    - name: Build with Flet / Buildozer
      run: |
        # أضف هنا أمر البناء الخاص بمشروعك، مثال لمشاريع Flet:
        flet build apk
        
    - name: Upload APK Artifact
      uses: actions/upload-artifact@v4
      with:
        name: app-release-apk
        path: |
          build/sapk/*.apk
          bin/*.apk
          dist/*.apk
