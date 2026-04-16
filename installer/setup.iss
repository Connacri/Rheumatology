; installer/setup.iss
; Inno Setup 6 — Installeur Windows pour Congrès Rhumatologie Oran
; Généré pour Flutter Windows Desktop build

#define AppName      "Congrès Rhumatologie Oran"
#define AppVersion   "1.0.0"
#define AppPublisher "AAMRO"
#define AppExeName   "congres_oran.exe"
#define BuildDir     "..\build\windows\x64\runner\Release"

[Setup]
AppId={{B3F2A1C4-9D7E-4F2A-B8C1-1234567890AB}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisherURL=https://congres.rhumato-oran.dz
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=..\installer\output
OutputBaseFilename=CongressOran_Setup_{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer une icône sur le Bureau"; GroupDescription: "Icônes supplémentaires"

[Files]
; Executable principal
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; DLLs Flutter obligatoires
Source: "{#BuildDir}\flutter_windows.dll";      DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\msvcp140.dll";             DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildDir}\vcruntime140.dll";         DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildDir}\vcruntime140_1.dll";       DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Dossier data (assets Flutter)
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}";           Filename: "{app}\{#AppExeName}"
Name: "{group}\Désinstaller {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";     Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Lancer {#AppName}"; Flags: nowait postinstall skipifsilent
