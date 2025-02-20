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
	-start-debug			: [optional] On startup WinKey + E will launch in debug
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
