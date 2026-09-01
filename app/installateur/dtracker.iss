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
; NPCAP EST LA SEULE DEPENDANCE, ET IL N'EST PAS FOURNI. Sa licence est explicite :
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

; `VersionInfoVersion` n'accepte que des nombres : un tag `v1.0.0-beta`
; ferait echouer la compilation. On coupe donc au premier tiret pour la
; ressource de version, et on garde le libelle entier pour l'affichage.
#define VersionNumerique Copy(Version, 1, Pos("-", Version + "-") - 1)

#define Nom "DTracker"
#define Editeur "DTracker"
#define Executable "dofus_tracker.exe"

[Setup]
AppId={{8F3A6C21-4E7B-4A93-9C0D-2B5E7A1D6F84}
AppName={#Nom}
AppVersion={#Version}
AppVerName={#Nom} {#Version}
AppPublisher={#Editeur}
VersionInfoVersion={#VersionNumerique}

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
; Sans `skipifsilent` : une mise a jour lancee depuis l'outil se fait en
; silence, et doit rendre l'outil a qui l'utilisait. Il l'avait ferme pour
; laisser la place a l'installateur, pas pour en finir avec lui.
Filename: "{app}\{#Executable}"; Description: "{cm:LaunchProgram,{#Nom}}"; Flags: nowait postinstall

[UninstallDelete]
; Ce que le programme ecrit a cote de lui et qui n'est pas a lui : les
; journaux de la diffusion. Rien de ce que l'utilisateur a produit.
Type: filesandordirs; Name: "{app}\logs"

[Code]
{ Une seule chose manque peut-etre : npcap. Sans lui, aucun programme ne
  peut lire le trafic — c'est une affaire de noyau, et aucun langage n'y
  change rien.

  DTracker parle a `wpcap.dll`, que npcap installe. Wireshark n'est plus
  necessaire : il n'apportait que `dumpcap`, un programme qui se sert de la
  meme bibliotheque. Le chemin par dumpcap reste en place pour qui aurait
  Wireshark sans npcap seul, mais ce n'est plus ce qu'on demande.

  On cherche, on le dit, et on renvoie au site officiel — sans jamais
  bloquer, car on peut tres bien installer l'outil aujourd'hui et le pilote
  demain. }

const
  NpcapUrl = 'https://npcap.com/#download';

{ Trois marqueurs, dont un seul suffit : le pilote peut etre installe sans
  que le service tourne au moment ou l'on regarde. }
function NpcapPresent(): Boolean;
begin
  Result := FileExists(ExpandConstant('{sys}\Npcap\wpcap.dll'))
         or FileExists(ExpandConstant('{sys}\wpcap.dll'))
         or RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\WOW6432Node\Npcap')
         or RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\Npcap');
end;

procedure Ouvrir(Adresse: String);
var
  Code: Integer;
begin
  ShellExec('open', Adresse, '', '', SW_SHOW, ewNoWait, Code);
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  if NpcapPresent() then
    Exit;

  { Une installation silencieuse ne doit pas s'arreter sur une boite de
    dialogue que personne ne verra. }
  if WizardSilent() then
    Exit;

  { On informe, on n'empeche pas : quelqu'un peut tres bien installer l'outil
    aujourd'hui et le pilote demain. }
  if MsgBox('DTracker a besoin de npcap, le pilote qui donne acces au trafic '
            + 'reseau.' + #13#10 + 'Il ne semble pas installe sur cette '
            + 'machine.' + #13#10 + #13#10
            + 'Il est gratuit, pese environ un mega-octet, et ne se demande '
            + 'qu''une fois.' + #13#10
            + 'Sans lui, DTracker s''ouvre mais reste muet.' + #13#10 + #13#10
            + 'Ouvrir la page de telechargement maintenant ?' + #13#10
            + '(l''installation de DTracker se poursuit dans tous les cas)',
            mbConfirmation, MB_YESNO) = IDYES then
    Ouvrir(NpcapUrl);
end;
