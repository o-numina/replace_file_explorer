# replace_file_explorer
Replaces Windows key + E keybind to launch FilePilot

### Usage
winkey_filepilot will register WinKey + E and listen for
WinKey + E events. Preventing File Explorer from opening
and instead launching FilePilot. To close the application
or edit its settings at runtime you can access them in
the systems tray.
	
	-debug-path %DEBUG_PATH%	: [optional] Overrides debug path
	-release-path %RELEASE_PATH%	: [optional] Overrides release path
	-working-directory		: [optional] Overrides the working directory of the launched process
	-start-dev			: [optional] On startup FilePilot will run the dev build
	-start-disabled			: [optional] On startup the winkey_filepilot will not launch filepilot on WinKey + E events
	-file-pilot-parameters		: [optional] Parameters to pass to FilePilot
	
This application has NOT been tested on security.
It does not need administrator privileges to function.
If Task Manager is in focus, File Pilot will not open.
This is because Task Manager runs with administrator
priviliges. If winkey_filepilot is run as
administrator, it will listen to WinKey + E even with
Task Manager on top.

### Odin
[Compile code with Odin](https://odin-lang.org/docs/install/)

Code was compiled with

	odin build . -out:winkey_filepilot.exe -subsystem:windows -vet-unused -vet-unused-variables -vet-style -vet-semicolon -vet-cast -vet-tabs

Some windows functions might not be defined yet by win32:
#### user32.odin:

	UnregisterHotKey :: proc(hWnd: HWND, id: c.int) -> BOOL ---
	GetWindowThreadProcessId :: proc(hWnd: HWND, lpdwProcessId: LPDWORD) -> DWORD ---
#### shell32.odin:

	ExtractIconW :: proc(hInst: HINSTANCE, pszExeFileName: LPCWSTR, nIconIndex: UINT) -> HICON ---

#### ole32.odin:

	CoCreateGuid :: proc(pguid: ^GUID) -> HRESULT ---
