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
; NPCAP N'EST PAS FOURNI, ET NE PEUT PAS L'ETRE. Sa licence est explicite :
; « it is not open source software and may not be redistributed or used in
; other software without special permission from the Nmap Project ». La
; licence gratuite couvre cinq installations chez l'utilisateur final, pas la
; redistribution ; l'installation silencieuse est reservee a la licence OEM,
; payante. Le texte recommande lui-meme ce que fait cet installateur :
; « we normally recommend that such authors instead ask your users to
; download and install Npcap themselves ».
;
; L'installateur le cherche, dit ce qui manque, et renvoie au site
; officiel. Rien n'est telecharge ni redistribue : le pilote se prend
; a la source, ou il est tenu a jour et signe.
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
{ Deux choses manquent peut-etre a la machine, et elles ne se remplacent pas
  l'une l'autre :

    npcap     le pilote. Sans lui, aucun programme ne peut lire le trafic —
              c'est une affaire de noyau, aucun langage n'y change rien.

    dumpcap   le moteur de capture, livre avec Wireshark. C'est lui que la
              diffusion appelle.

  Ni l'un ni l'autre n'est fourni ici : voir l'en-tete. On les cherche, on le
  dit, et on propose ce qu'il faut telecharger — sans jamais bloquer, car on
  peut tres bien installer l'outil aujourd'hui et le reste demain. }

const
  NpcapUrl = 'https://npcap.com/#download';
  WiresharkUrl = 'https://www.wireshark.org/download.html';

{ Trois marqueurs, dont un seul suffit : le pilote peut etre installe sans
  que le service tourne au moment ou l'on regarde. }
function NpcapPresent(): Boolean;
begin
  Result := FileExists(ExpandConstant('{sys}\Npcap\wpcap.dll'))
         or FileExists(ExpandConstant('{sys}\wpcap.dll'))
         or RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\WOW6432Node\Npcap')
         or RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\Npcap');
end;

function DumpcapPresent(): Boolean;
begin
  Result := FileExists(ExpandConstant('{commonpf}\Wireshark\dumpcap.exe'))
         or FileExists(ExpandConstant('{commonpf32}\Wireshark\dumpcap.exe'));
end;

procedure Ouvrir(Adresse: String);
var
  Code: Integer;
begin
  ShellExec('open', Adresse, '', '', SW_SHOW, ewNoWait, Code);
end;

function InitializeSetup(): Boolean;
var
  Manquants: String;
begin
  Result := True;

  Manquants := '';
  if not NpcapPresent() then
    Manquants := Manquants + '  -  npcap, le pilote de capture' + #13#10;
  if not DumpcapPresent() then
    Manquants := Manquants + '  -  Wireshark, dont DTracker utilise dumpcap'
                 + #13#10;
  if Manquants = '' then
    Exit;

  { On informe, on n'empeche pas : quelqu'un peut tres bien installer l'outil
    aujourd'hui et le reste demain. }
  if MsgBox('DTracker a besoin de deux choses qui ne sont pas fournies avec '
            + 'lui,' + #13#10 + 'et qui manquent sur cette machine :'
            + #13#10 + #13#10 + Manquants + #13#10
            + 'Le plus simple est d''installer Wireshark : il propose npcap '
            + 'au passage,' + #13#10 + 'et vous aurez les deux d''un coup.'
            + #13#10 + #13#10
            + 'Ouvrir la page de telechargement maintenant ?' + #13#10
            + '(l''installation de DTracker se poursuit dans tous les cas)',
            mbConfirmation, MB_YESNO) = IDYES then
  begin
    if not DumpcapPresent() then
      Ouvrir(WiresharkUrl)
    else
      Ouvrir(NpcapUrl);
  end;
end;
