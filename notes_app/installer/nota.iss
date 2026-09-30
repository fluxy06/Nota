; Inno Setup script для Nota — собирает установщик под Windows.
; Как пользоваться:
;   1) flutter build windows --release
;   2) установить Inno Setup (jrsoftware.org)
;   3) открыть этот файл в Inno Setup и нажать Compile (Build → Compile)
;   4) готовый установщик появится в installer\dist\Nota-Setup-1.0.0.exe

#define MyAppName "Nota"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Nota"
#define MyAppExeName "notes_app.exe"

[Setup]
AppId={{7C9E6A2B-3D4F-4A1B-9E8C-1A2B3C4D5E6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=Nota-Setup-{#MyAppVersion}
OutputDir=.\dist
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; Установка без прав администратора (в профиль пользователя) — удобно для раздачи коллегам.
PrivilegesRequired=lowest

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительно:"; Flags: unchecked

[Files]
; Берём всю release-сборку Flutter.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Запустить {#MyAppName}"; Flags: nowait postinstall skipifsilent
