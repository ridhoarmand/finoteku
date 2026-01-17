; Inno Setup Script for Finoteku
#define MyAppName "Finoteku"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Ridho Armand"
#define MyAppURL "https://github.com/ridhoarmand/finoteku"
#define MyAppExeName "finoteku.exe"

[Setup]
AppId={{YOUR-UNIQUE-GUID-HERE}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Output settings
OutputDir=~\Downloads
OutputBaseFilename=Finoteku_Setup_{#MyAppVersion}
; Compression
Compression=lzma
SolidCompression=yes
; Installer appearance
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
; Privileges
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main executable and all files from build output
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
