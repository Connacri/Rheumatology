#define AppName      "Congrès Rhumatologie Oran"
#define AppVersion   "1.0.2.55"
#define AppPublisher "AAMRO"
#define BuildDir     "..\build\windows\x64\runner\Release"

[Setup]
AppId={{B3F2A1C4-9D7E-4F2A-B8C1-1234567890AB}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
OutputDir=..\installer\output
OutputBaseFilename=CongressOran_Setup_{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\congres.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\congres.exe"

[Run]
Filename: "{app}\congres.exe"; Flags: nowait postinstall skipifsilent