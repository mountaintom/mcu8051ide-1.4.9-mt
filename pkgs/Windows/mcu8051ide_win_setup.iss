[Setup]
AppId={{E0D2EFF2-AF92-403C-88F6-6188F369D6BB}
AppName=MCU 8051 IDE
AppVerName=MCU 8051 IDE 1.4.9
AppPublisher=Martin Osmera, Moravia Microsystems, s.r.o.
AppPublisherURL=http://www.moravia-microsystems.com/
AppSupportURL=http://www.moravia-microsystems.com/
AppUpdatesURL=http://www.moravia-microsystems.com/
DefaultDirName={pf}\MCU 8051 IDE
DefaultGroupName=MCU 8051 IDE
AllowNoIcons=yes
LicenseFile=W:\mcu8051ide\LICENSE
OutputDir=W:\mcu8051ide\pkgs
OutputBaseFilename=mcu8051ide-1.4.9-setup
Compression=lzma
SolidCompression=yes
SetupIconFile="W:\mcu8051ide\pkgs\Windows\mcu8051ide.ico"
WizardImageFile="W:\mcu8051ide\pkgs\Windows\setup_image.bmp"
WizardSmallImageFile="W:\mcu8051ide\pkgs\Windows\setup_small_image.bmp"

[Registry]
Root: HKCR; Subkey: ".mcu8051ide"; ValueType: string; ValueName: ""; ValueData: "MCU8051IDEProject"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "MCU8051IDEProject"; ValueType: string; ValueName: ""; ValueData: "MCU 8051 IDE project file"; Flags: uninsdeletekey
Root: HKCR; Subkey: "MCU8051IDEProject\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\mcu8051ide.ico"
Root: HKCR; Subkey: "MCU8051IDEProject\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\mcu8051ide.exe"" ""%1"""

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 0,6.1

[Files]
Source: "W:\mcu8051ide\pkgs\installation_sandbox\win_pkg_files\demo\*"; DestDir: "{app}\demo"; Flags: ignoreversion
Source: "W:\mcu8051ide\pkgs\installation_sandbox\win_pkg_files\data\tips.xml"; DestDir: "{app}\data"; Flags: ignoreversion
Source: "W:\mcu8051ide\pkgs\installation_sandbox\win_pkg_files\doc\handbook\*.pdf"; DestDir: "{app}\doc\handbook"; Flags: ignoreversion
Source: "W:\mcu8051ide\pkgs\installation_sandbox\win_pkg_files\translations\*"; DestDir: "{app}\translations"; Flags: ignoreversion
Source: "W:\mcu8051ide\pkgs\installation_sandbox\win_pkg_files\hwplugins\*"; DestDir: "{app}\hwplugins"; Flags: ignoreversion
Source: "W:\mcu8051ide\pkgs\installation_sandbox\win_pkg_files\*.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "W:\mcu8051ide\pkgs\Windows\mcu8051ide.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "W:\mcu8051ide\pkgs\Windows\*.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "W:\mcu8051ide\pkgs\Windows\readme.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\MCU 8051 IDE"; Filename: "{app}\mcu8051ide.exe"; IconFilename: "{app}\mcu8051ide.ico"
Name: "{commondesktop}\MCU 8051 IDE"; Filename: "{app}\mcu8051ide.exe"; Tasks: desktopicon; IconFilename: "{app}\mcu8051ide.ico"
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\MCU 8051 IDE"; Filename: "{app}\mcu8051ide.exe"; Tasks: quicklaunchicon; IconFilename: "{app}\mcu8051ide.ico"

[Run]
Filename: "{app}\mcu8051ide.exe"; Description: "{cm:LaunchProgram,MCU 8051 IDE}"; Flags: shellexec postinstall skipifsilent
Filename: "{app}\readme.txt"; Description: "View the README file"; Flags: postinstall shellexec skipifsilent
