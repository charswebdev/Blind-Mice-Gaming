#define MyAppName "Blind Mice Gaming Updater"
#define MyAppVersion "1.1.2"
#define MyAppPublisher "Blind Mice Gaming"
#define MyAppURL "https://github.com/charswebdev/Blind-Mice-Gaming"
#define MyAppExeName "BMG-Updater.exe"

[Setup]
AppId={{8F3C2A91-6B14-4E55-9D7A-1C8E4B0F6A22}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={commonpf32}\Blind Mice Gaming
DefaultGroupName=Blind Mice Gaming
DisableProgramGroupPage=yes
DisableDirPage=no
OutputDir=dist
OutputBaseFilename=BMG-Updater-Setup
SetupIconFile=assets\logo.ico
WizardImageFile=assets\wizard-side.png
WizardSmallImageFile=assets\wizard-small.png
WizardImageBackColor=clBlack
WizardSmallImageBackColor=clBlack
WizardImageStretch=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
PrivilegesRequired=admin
Compression=lzma
SolidCompression=yes
WizardStyle=classic
WizardSizePercent=120
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
SetupAppTitle=Blind Mice Gaming Updater
SetupWindowTitle=Blind Mice Gaming Updater Setup
ButtonBack=< Back
ButtonNext=Next >
ButtonInstall=Install
ButtonFinish=Finish
ButtonCancel=Cancel
ClickNext=Use Next, Back, or Cancel. High-contrast text is yellow on black.
SelectDirBrowseLabel=Click Browse to choose a different folder.
WizardReady=Ready to install
ReadyLabel1=Setup is ready to install Blind Mice Gaming Updater on this PC.
FinishedHeadingLabel=Setup finished
FinishedLabel=Blind Mice Gaming Updater is installed. You can open it from the Start Menu.
ClickFinish=Click Finish to close setup.

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Blind Mice Gaming\BMG Updater"; Filename: "{app}\{#MyAppExeName}"; Comment: "Install and update Blind Mice Gaming addons"
Name: "{autoprograms}\Blind Mice Gaming\Uninstall BMG Updater"; Filename: "{uninstallexe}"; Comment: "Remove Blind Mice Gaming Updater from this PC"
Name: "{autodesktop}\BMG Updater"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "Install and update Blind Mice Gaming addons"

[Registry]
Root: HKLM; Subkey: "Software\Classes\*\shell\UninstallBMGUpdater"; ValueType: string; ValueName: "MUIVerb"; ValueData: "Uninstall Blind Mice Gaming Updater"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Classes\*\shell\UninstallBMGUpdater"; ValueType: string; ValueName: "AppliesTo"; ValueData: "System.FileName:=""BMG-Updater.exe"""
Root: HKLM; Subkey: "Software\Classes\*\shell\UninstallBMGUpdater"; ValueType: string; ValueName: "Position"; ValueData: "Top"
Root: HKLM; Subkey: "Software\Classes\*\shell\UninstallBMGUpdater"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName}"
Root: HKLM; Subkey: "Software\Classes\*\shell\UninstallBMGUpdater\command"; ValueType: string; ValueName: ""; ValueData: """{uninstallexe}"""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Blind Mice Gaming Updater"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\BlindMiceUpdater"

[Code]
const
  ColorBg = $000000;
  ColorPanel = $111111;
  ColorBtn = $1A1A1A;
  ColorYellow = $00E6FF;
  ColorWhite = $FFFFFF;
  ColorMuted = $CCCCCC;

var
  ThemeNext, ThemeBack, ThemeCancel, ThemeBrowse: TPanel;
  ThemeNextText, ThemeBackText, ThemeCancelText, ThemeBrowseText: TNewStaticText;

procedure ColorText(LabelCtrl: TNewStaticText; Color: TColor; Bold: Boolean);
begin
  LabelCtrl.Font.Name := 'Segoe UI';
  LabelCtrl.Font.Color := Color;
  if Bold then
    LabelCtrl.Font.Style := [fsBold]
  else
    LabelCtrl.Font.Style := [];
end;

procedure ColorSurfaces(Win: TWinControl);
var
  I: Integer;
  Child: TControl;
begin
  if Win is TPanel then
  begin
    if (Win = ThemeNext) or (Win = ThemeBack) or (Win = ThemeCancel) or (Win = ThemeBrowse) then
      Exit;
    TPanel(Win).Color := ColorBg;
    TPanel(Win).ParentBackground := False;
    TPanel(Win).ParentColor := False;
  end;
  if Win is TNewNotebookPage then
    TNewNotebookPage(Win).Color := ColorBg;

  for I := 0 to Win.ControlCount - 1 do
  begin
    Child := Win.Controls[I];
    if Child is TNewStaticText then
      ColorText(TNewStaticText(Child), ColorWhite, False)
    else if Child is TLabel then
      TLabel(Child).Font.Color := ColorWhite
    else if Child is TNewEdit then
    begin
      TNewEdit(Child).Color := ColorPanel;
      TNewEdit(Child).Font.Color := ColorWhite;
    end
    else if Child is TNewMemo then
    begin
      TNewMemo(Child).Color := ColorPanel;
      TNewMemo(Child).Font.Color := ColorWhite;
    end
    else if Child is TNewCheckListBox then
    begin
      TNewCheckListBox(Child).Color := ColorPanel;
      TNewCheckListBox(Child).Font.Color := ColorWhite;
    end
    else if Child is TBevel then
      TBevel(Child).Visible := False
    else if Child is TWinControl then
      ColorSurfaces(TWinControl(Child));
  end;
end;

procedure ClickStock(Button: TNewButton);
begin
  if Button.Enabled then
    Button.OnClick(Button);
end;

procedure OnThemeNext(Sender: TObject);
begin
  ClickStock(WizardForm.NextButton);
end;

procedure OnThemeBack(Sender: TObject);
begin
  ClickStock(WizardForm.BackButton);
end;

procedure OnThemeCancel(Sender: TObject);
begin
  ClickStock(WizardForm.CancelButton);
end;

procedure OnThemeBrowse(Sender: TObject);
begin
  ClickStock(WizardForm.DirBrowseButton);
end;

function MakeThemeButton(Parent: TWinControl; Stock: TNewButton; Handler: TNotifyEvent; var TextCtrl: TNewStaticText): TPanel;
var
  Inner: TPanel;
begin
  Result := TPanel.Create(WizardForm);
  Result.Parent := Parent;
  Result.Left := Stock.Left;
  Result.Top := Stock.Top;
  Result.Width := Stock.Width;
  Result.Height := Stock.Height;
  Result.Color := ColorYellow;
  Result.ParentBackground := False;
  Result.BevelOuter := bvNone;
  Result.Caption := '';
  Result.OnClick := Handler;

  Inner := TPanel.Create(WizardForm);
  Inner.Parent := Result;
  Inner.Left := 2;
  Inner.Top := 2;
  Inner.Width := Result.Width - 4;
  Inner.Height := Result.Height - 4;
  Inner.Color := ColorBtn;
  Inner.ParentBackground := False;
  Inner.BevelOuter := bvNone;
  Inner.Caption := '';
  Inner.OnClick := Handler;

  TextCtrl := TNewStaticText.Create(WizardForm);
  TextCtrl.Parent := Inner;
  TextCtrl.Caption := Stock.Caption;
  TextCtrl.Font.Name := 'Segoe UI';
  TextCtrl.Font.Size := 10;
  TextCtrl.Font.Style := [fsBold];
  TextCtrl.Font.Color := ColorYellow;
  TextCtrl.AutoSize := True;
  TextCtrl.Left := (Inner.Width - TextCtrl.Width) div 2;
  TextCtrl.Top := (Inner.Height - TextCtrl.Height) div 2;
  TextCtrl.OnClick := Handler;

  Stock.Visible := False;
end;

procedure SyncThemeButton(Wrap: TPanel; TextCtrl: TNewStaticText; Stock: TNewButton);
begin
  if (Wrap = nil) or (TextCtrl = nil) then
    Exit;
  Wrap.Visible := Stock.Enabled;
  TextCtrl.Caption := Stock.Caption;
  TextCtrl.Left := (TextCtrl.Parent.Width - TextCtrl.Width) div 2;
  TextCtrl.Top := (TextCtrl.Parent.Height - TextCtrl.Height) div 2;
end;

procedure FixDestinationLayout;
begin
  WizardForm.SelectDirLabel.Left := WizardForm.SelectDirBitmapImage.Left + WizardForm.SelectDirBitmapImage.Width + ScaleX(12);
  WizardForm.SelectDirLabel.Width := WizardForm.InnerNotebook.Width - WizardForm.SelectDirLabel.Left - ScaleX(8);
  WizardForm.SelectDirLabel.WordWrap := True;
  WizardForm.SelectDirLabel.AutoSize := True;
  WizardForm.DiskSpaceLabel.Top := WizardForm.InnerNotebook.Height - WizardForm.DiskSpaceLabel.Height - ScaleY(12);
  WizardForm.SelectDirBrowseLabel.Top := WizardForm.DiskSpaceLabel.Top - WizardForm.SelectDirBrowseLabel.Height - ScaleY(8);
end;

procedure ApplyTheme;
begin
  WizardForm.Color := ColorBg;
  WizardForm.Font.Name := 'Segoe UI';
  WizardForm.Font.Color := ColorWhite;
  ColorSurfaces(WizardForm);

  WizardForm.MainPanel.Color := ColorBg;
  WizardForm.MainPanel.ParentBackground := False;
  ColorText(WizardForm.PageNameLabel, ColorYellow, True);
  ColorText(WizardForm.PageDescriptionLabel, ColorMuted, False);
  ColorText(WizardForm.WelcomeLabel1, ColorYellow, True);
  ColorText(WizardForm.WelcomeLabel2, ColorWhite, False);
  ColorText(WizardForm.FinishedHeadingLabel, ColorYellow, True);
  ColorText(WizardForm.FinishedLabel, ColorWhite, False);

  WizardForm.DirEdit.Color := ColorPanel;
  WizardForm.DirEdit.Font.Color := ColorWhite;
  WizardForm.ReadyMemo.Color := ColorPanel;
  WizardForm.ReadyMemo.Font.Color := ColorWhite;
  WizardForm.TasksList.Color := ColorPanel;
  WizardForm.TasksList.Font.Color := ColorWhite;
  WizardForm.RunList.Color := ColorPanel;
  WizardForm.RunList.Font.Color := ColorWhite;
end;

procedure InitializeWizard;
begin
  ApplyTheme;
  FixDestinationLayout;
  ThemeNext := MakeThemeButton(WizardForm, WizardForm.NextButton, @OnThemeNext, ThemeNextText);
  ThemeBack := MakeThemeButton(WizardForm, WizardForm.BackButton, @OnThemeBack, ThemeBackText);
  ThemeCancel := MakeThemeButton(WizardForm, WizardForm.CancelButton, @OnThemeCancel, ThemeCancelText);
  ThemeBrowse := MakeThemeButton(WizardForm.SelectDirPage, WizardForm.DirBrowseButton, @OnThemeBrowse, ThemeBrowseText);
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  ApplyTheme;
  FixDestinationLayout;
  SyncThemeButton(ThemeNext, ThemeNextText, WizardForm.NextButton);
  SyncThemeButton(ThemeBack, ThemeBackText, WizardForm.BackButton);
  SyncThemeButton(ThemeCancel, ThemeCancelText, WizardForm.CancelButton);
  if CurPageID = wpSelectDir then
  begin
    ThemeBrowse.Visible := True;
    ThemeBrowseText.Caption := WizardForm.DirBrowseButton.Caption;
  end
  else
    ThemeBrowse.Visible := False;
end;

procedure InitializeUninstallProgressForm;
begin
  UninstallProgressForm.Color := ColorBg;
  UninstallProgressForm.Font.Color := ColorWhite;
  ColorSurfaces(UninstallProgressForm);
  UninstallProgressForm.MainPanel.Color := ColorBg;
  UninstallProgressForm.MainPanel.ParentBackground := False;
  ColorText(UninstallProgressForm.PageNameLabel, ColorYellow, True);
  ColorText(UninstallProgressForm.PageDescriptionLabel, ColorMuted, False);
end;
