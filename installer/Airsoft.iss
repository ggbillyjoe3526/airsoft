; Windows installer for Airsoft (Inno Setup 6), from the owner's katanashotgun project.
; Built by .github/workflows/release.yml, with the forms tools/version.sh gives:
;   ISCC.exe "/DAppVersion=0.1 Dev 1" /DAppTag=0.1-dev.1 /DAppNumber=0.1.0.1 installer\Airsoft.iss
; AppVersion is the name players see; AppTag goes in the file name; AppNumber is the four-number version Windows needs
; in the setup exe's properties. Saves live in %APPDATA%\Airsoft, never in the install folder, so uninstalling or
; upgrading never touches progress.

#ifndef AppVersion
  #define AppVersion "0.0"
#endif
#ifndef AppTag
  #define AppTag "0.0"
#endif
#ifndef AppNumber
  #define AppNumber "0.0.0.0"
#endif
#ifndef AppPublisher
  #define AppPublisher "ggbillyjoe3526"
#endif

[Setup]
; AppId identifies the game for upgrades and uninstall. NEVER change it.
AppId={{CA6DA48A-21BA-4781-B1BA-71FA63D7CCC8}
AppName=Airsoft
AppVerName=Airsoft {#AppVersion}
AppVersion={#AppVersion}
VersionInfoVersion={#AppNumber}
VersionInfoProductVersion={#AppNumber}
VersionInfoTextVersion={#AppVersion}
VersionInfoProductTextVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/ggbillyjoe3526/airsoft
AppSupportURL=https://github.com/ggbillyjoe3526/airsoft/issues
AppUpdatesURL=https://github.com/ggbillyjoe3526/airsoft/releases
DefaultDirName={autopf}\Airsoft
DefaultGroupName=Airsoft
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=Airsoft-{#AppTag}-Windows-Setup
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\Airsoft.ico
UninstallDisplayName=Airsoft
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\Airsoft.exe"; DestDir: "{app}"; Flags: ignoreversion
; The exe carries this icon itself since BP7 (the export writes it in); the shortcuts still name this copy.
Source: "icon.ico"; DestDir: "{app}"; DestName: "Airsoft.ico"; Flags: ignoreversion
; Licences for the engine and everything third-party, shipped next to the game.
Source: "..\THIRD_PARTY_NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Airsoft"; Filename: "{app}\Airsoft.exe"; IconFilename: "{app}\Airsoft.ico"
; The safe graphics shortcut: the simpler renderer for this run, for a card or driver the normal one won't start on.
Name: "{group}\Airsoft (safe graphics)"; Filename: "{app}\Airsoft.exe"; Parameters: "--rendering-method gl_compatibility"; IconFilename: "{app}\Airsoft.ico"; Comment: "Starts Airsoft on the simpler renderer"
Name: "{group}\Uninstall Airsoft"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Airsoft"; Filename: "{app}\Airsoft.exe"; IconFilename: "{app}\Airsoft.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\Airsoft.exe"; Description: "{cm:LaunchProgram,Airsoft}"; Flags: nowait postinstall skipifsilent
