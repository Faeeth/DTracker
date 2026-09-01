; Installateur de DTracker, pour Inno Setup 6.
;
; A construire depuis la racine du depot :
;
;   iscc installateur\dtracker.iss /DVersion=1.0.0
;
; Il attend deux dossiers deja construits :
;
;   build\windows\x64\runner\Release   l'application
;   ..\capture\dist\capture        la diffusion de capture gelee
;
; CE QU'IL NE TOUCHE JAMAIS : les reglages, le cache et les sessions. Ils
; vivent dans %APPDATA%\DTracker et n'apparaissent nulle part ci-dessous — ni
; dans [Files], ni dans [UninstallDelete]. Une mise a jour les laisse en
; place ; une desinstallation aussi, pour qu'une reinstallation retrouve
; l'historique. C'est le sens de PrivilegesRequired=lowest : le programme
; s'installe pour l'utilisateur courant, sans jamais avoir besoin d'ecrire
; ailleurs que chez lui.

#ifndef Version
  #define Version "0.0.0"
#endif

#define Nom "DTracker"
#define Editeur "DTracker"
#define Executable "dofus_tracker.exe"

[Setup]
AppId={{8F3A6C21-4E7B-4A93-9C0D-2B5E7A1D6F84}
AppName={#Nom}
AppVersion={#Version}
AppVerName={#Nom} {#Version}
AppPublisher={#Editeur}
VersionInfoVersion={#Version}

; Par utilisateur, et non pour toute la machine : pas d'invite
; d'administrateur, pas d'ecriture dans Program Files, et l'outil s'installe
; sur un poste ou l'on n'est pas administrateur — ce qui est le cas de
; beaucoup de machines familiales.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#Nom}
DefaultGroupName={#Nom}
DisableProgramGroupPage=yes
; Le dossier est propose, mais modifiable : certains tiennent a ranger leurs
; outils ailleurs qu'ou Windows le suggere.
DisableDirPage=no
AllowNoIcons=yes
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
OutputDir=..\dist
OutputBaseFilename={#Nom}-{#Version}-installateur
; L'application est 64 bits, comme le jeu.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#Nom} {#Version}
UninstallDisplayIcon={app}\{#Executable}

[Languages]
Name: "francais"; MessagesFile: "compiler:Languages\French.isl"
Name: "anglais"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "bureau"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; L'application. `recursesubdirs` emporte `data\`, ou Flutter place ses
; ressources et ses polices.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "settings.json,cache.json,sessions"
; La diffusion de capture, gelee : c'est elle qui evite d'exiger Python.
Source: "..\..\capture\dist\capture\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#Nom}"; Filename: "{app}\{#Executable}"
Name: "{group}\{cm:UninstallProgram,{#Nom}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#Nom}"; Filename: "{app}\{#Executable}"; Tasks: bureau

[Run]
Filename: "{app}\{#Executable}"; Description: "{cm:LaunchProgram,{#Nom}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Ce que le programme ecrit a cote de lui et qui n'est pas a lui : les
; journaux de la diffusion. Rien de ce que l'utilisateur a produit.
Type: filesandordirs; Name: "{app}\logs"

[Code]
{ Wireshark fournit dumpcap et le pilote npcap, sans lesquels aucune capture
  n'est possible. On ne peut pas les embarquer : npcap installe un pilote
  reseau et exige son propre consentement. On previent donc, sans bloquer —
  quelqu'un peut tres bien installer l'outil aujourd'hui et Wireshark demain. }
function DumpcapPresent(): Boolean;
begin
  Result := FileExists(ExpandConstant('{pf}\Wireshark\dumpcap.exe'))
         or FileExists(ExpandConstant('{pf32}\Wireshark\dumpcap.exe'));
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  if not DumpcapPresent() then
  begin
    if MsgBox('Wireshark ne semble pas installe sur cette machine.' + #13#10 +
              #13#10 +
              'DTracker s''en sert pour ecouter le trafic du jeu : sans lui, ' +
              'aucune donnee ne remontera. Il est gratuit, et son ' +
              'installation propose le pilote npcap dont l''ecoute a besoin.' +
              #13#10 + #13#10 +
              'Poursuivre l''installation quand meme ?',
              mbConfirmation, MB_YESNO) = IDNO then
      Result := False;
  end;
end;
