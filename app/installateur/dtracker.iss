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
; On telecharge donc depuis le site officiel, a la demande, et on lance leur
; installateur — l'utilisateur voit et accepte leur licence. Rien n'est
; redistribue.
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
  NpcapUrl = 'https://npcap.com/dist/npcap-1.88.exe';
  WiresharkUrl = 'https://www.wireshark.org/download.html';

var
  TelechargerNpcap: Boolean;

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

function InitializeSetup(): Boolean;
var
  Manquants: String;
begin
  Result := True;
  TelechargerNpcap := False;

  Manquants := '';
  if not NpcapPresent() then
    Manquants := Manquants + '  -  npcap, le pilote de capture' + #13#10;
  if not DumpcapPresent() then
    Manquants := Manquants + '  -  Wireshark, dont DTracker utilise dumpcap'
                 + #13#10;
  if Manquants = '' then
    Exit;

  MsgBox('DTracker a besoin de deux choses qui ne sont pas fournies avec lui,'
         + #13#10 + 'et qui manquent sur cette machine :' + #13#10 + #13#10
         + Manquants + #13#10
         + 'L''installation se poursuit : vous pourrez les ajouter apres '
         + 'coup.' + #13#10
         + 'Sans elles, DTracker s''ouvre mais reste muet.',
         mbInformation, MB_OK);

  if not NpcapPresent() then
  begin
    TelechargerNpcap :=
      MsgBox('Telecharger npcap maintenant depuis le site officiel ?'
             + #13#10 + #13#10
             + 'Il sera telecharge depuis npcap.com et son installateur '
             + 'sera lance a la fin.' + #13#10
             + 'Npcap est gratuit, et vous verrez sa propre licence.',
             mbConfirmation, MB_YESNO) = IDYES;
  end;
end;

{ Le telechargement se fait a la page de preparation, la ou Inno sait montrer
  une progression et laisser annuler. }
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Page: TDownloadWizardPage;
begin
  Result := '';
  if not TelechargerNpcap then
    Exit;
  Page := CreateDownloadPage('Telechargement de npcap',
                             'Depuis npcap.com', nil);
  Page.Clear;
  Page.Add(NpcapUrl, 'npcap-installateur.exe', '');
  Page.Show;
  try
    try
      Page.Download;
    except
      { Un telechargement qui echoue n'empeche pas d'installer DTracker : on
        le dit, et on continue. }
      MsgBox('Le telechargement de npcap a echoue.' + #13#10 + #13#10
             + 'Vous pourrez l''installer plus tard depuis npcap.com.',
             mbError, MB_OK);
      TelechargerNpcap := False;
    end;
  finally
    Page.Hide;
  end;
end;

{ Et on lance leur installateur une fois le notre fini : deux assistants a
  l'ecran en meme temps se marchent dessus. }
procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
begin
  if (CurStep = ssPostInstall) and TelechargerNpcap then
  begin
    if not Exec(ExpandConstant('{tmp}\npcap-installateur.exe'), '', '',
                SW_SHOW, ewWaitUntilTerminated, Code) then
      MsgBox('L''installateur de npcap n''a pas pu demarrer.' + #13#10
             + 'Vous le trouverez sur npcap.com.', mbError, MB_OK);
  end;
end;
