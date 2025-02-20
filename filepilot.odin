package window

import win32 "core:sys/windows"
import "base:runtime"
import "core:os"
import "core:fmt"
import "core:log"
import "core:thread"
import "core:time"
import "core:c/libc"

MOD_ALT			:: 0x0001
MOD_CONTROL		:: 0x0002
MOD_NOREPEAT	:: 0x4000
MOD_SHIFT		:: 0x0004
MOD_WIN			:: 0x0008

/* ShellExecute() and ShellExecuteEx() error codes */

/* regular WinExec() codes */
SE_ERR_FNF :: 2       // file not found
SE_ERR_PNF :: 3       // path not found
SE_ERR_ACCESSDENIED :: 5       // access denied
SE_ERR_OOM :: 8       // out of memory
SE_ERR_DLLNOTFOUND :: 2

/* error values for ShellExecute() beyond the regular WinExec() codes */
SE_ERR_SHARE :: 6
SE_ERR_ASSOCINCOMPLETE :: 7
SE_ERR_DDETIMEOUT :: 8
SE_ERR_DDEFAIL :: 9
SE_ERR_DDEBUSY :: 0
SE_ERR_NOASSOC :: 1

NIS_HIDDEN :: 0x00000001
NIS_SHAREDICON :: 0x00000002

// Notify Icon Infotip flags
NIIF_NONE :: 0x00000000
// icon flags are mutually exclusive
// and take only the lowest 2 bits
NIIF_INFO :: 0x00000001
NIIF_WARNING :: 0x00000002
NIIF_ERROR :: 0x00000003
NIIF_USER :: 0x00000004
NIIF_ICON_MASK :: 0x0000000F
NIIF_NOSOUND :: 0x00000010
NIIF_LARGE_ICON :: 0x00000020
NIIF_RESPECT_QUIET_TIME :: 0x00000080

NOTIFYICON_VERSION_4 :: 4
// NOTE:
// Use RegisterWindowMessage when more than one application must
// process the same message. For sending private messages within
// a window class, an application can use any integer in the
// range WM_USER through 0x7FFF. (Messages in this range are
// private to a window class, not to an application. For example,
// predefined control classes such as BUTTON, EDIT, LISTBOX,
// and COMBOBOX may use values in this range.)
// 0 through WM_USER –1		|	Messages reserved for use by the system.
// WM_USER through 0x7FFF	|	Integer messages for use by private window classes.
// WM_APP through 0xBFFF	|	Messages available for use by applications.
// 0xC000 through 0xFFFF	|	String messages for use by applications.
// Greater than 0xFFFF		|	Reserved by the system.
WM_NOTIFYICON :: win32.WM_USER + 0x0420
WM_TASKBARCREATED : u32
POPUP_MENU : win32.HMENU
QUIT_ID :: 70
DEBUG_ID :: 71
DISABLE_ID :: 72
DEBUG_CHECKMARK : u32 = win32.MFS_UNCHECKED
DISABLE_CHECKMARK : u32 = win32.MFS_UNCHECKED

FILE_PILOT_DEBUG : string = "FPilot-debug"
FILE_PILOT_RELEASE : string = "FPilot"
FILE_PILOT_EXTRACT_ICON : string = "FPilot.exe"
FILE_PILOT_PATH_STRING : string
WORKING_DIRECTORY_STRING : string
FILE_PILOT_PARAMETERS : [512]u16
PARAMETERS_LENGTH : u32
RELEASE : bool = true
DISABLED : bool = false

WINDOW_SHOULD_CLOSE : bool
WINDOW : win32.HWND
INSTANCE : win32.HINSTANCE
HOOK_HANDLE : win32.HHOOK
WIN_KEY_ID : i32 = 1
WIN_KEY_DOWN : bool
WIN_E_KEY_DOWN : bool

NOTIFY_EVENT :: enum u16
{
	NIN_SELECT				= win32.WM_USER + 0,
	NINF_KEY				= 0x1,
	NIN_KEYSELECT			= NIN_SELECT | NINF_KEY,
	NIN_BALLOONSHOW			= win32.WM_USER + 2,
	NIN_BALLOONHIDE			= win32.WM_USER + 3,
	NIN_BALLOONTIMEOUT		= win32.WM_USER + 4,
	NIN_BALLOONUSERCLICK	= win32.WM_USER + 5,
	NIN_POPUPOPEN			= win32.WM_USER + 6,
	NIN_POPUPCLOSE			= win32.WM_USER + 7,
	WM_CONTEXTMENU			= 0x007b,
	WM_MOUSEFIRST			= 0x0200,
	WM_MOUSEMOVE			= 0x0200,
	WM_LBUTTONDOWN			= 0x0201,
	WM_LBUTTONUP			= 0x0202,
	WM_LBUTTONDBLCLK		= 0x0203,
	WM_RBUTTONDOWN			= 0x0204,
	WM_RBUTTONUP			= 0x0205,
	WM_RBUTTONDBLCLK		= 0x0206,
	WM_MBUTTONDOWN			= 0x0207,
	WM_MBUTTONUP			= 0x0208,
	WM_MBUTTONDBLCLK		= 0x0209,
	WM_MOUSELAST			= 0x0209,
}

// NOTE:
// Notification area icons should be high-DPI aware. An application
// should provide both a 16x16 pixel icon and a 32x32 icon in its
// resource file, and then use LoadIconMetric to ensure that the correct
// icon is loaded and scaled appropriately.

// NOTE:
// The placement of a popup window or dialog box that results from the
// click should be placed near the coordinate of the click in the
// notification area. Use the CalculatePopupWindowPosition to determine
// its location.
// NOTE: I tried this and it did not have the expected behavior

// NOTE:
// Debug hooks cannot track this type of low level keyboard hooks. If the
// application must use low level hooks, it should run the hooks on a
// dedicated thread that passes the work off to a worker thread and then
// immediately returns. In most cases where the application needs to use
// low level hooks, it should monitor raw input instead. This is because
// raw input can asynchronously monitor mouse and keyboard messages that
// are targeted for other threads more effectively than low level hooks
// can. For more information on raw input, see Raw Input.
keyboard_proc :: proc "stdcall" (code : i32, wparam : uintptr, lparam : int) -> int
{
	// NOTE: If task manager is running and it is the top window
	// this callback will be ineffective unless it has
	// administrator permissions
	using win32
	if DISABLED
	{
		return CallNextHookEx(nil, code, wparam , lparam)
	}
	
	key : ^KBDLLHOOKSTRUCT = transmute(^KBDLLHOOKSTRUCT)lparam
	key_is_down : bool = ((key.flags >> 7) & 1) != 1
	
	if key_is_down
	{
		if (key.vkCode == VK_LWIN ||
			key.vkCode == VK_RWIN)
		{
			WIN_KEY_DOWN = true
		}
		
		if (WIN_KEY_DOWN && key.vkCode == 0x45)
		{
			// Open file pilot
			if (!WIN_E_KEY_DOWN)
			{
				WIN_E_KEY_DOWN = true
				context = runtime.default_context()
				thread.create_and_start(open_file_pilot, context, .High, self_cleanup = true)
			}
		}
	}
	else
	{
		// WIN_KEY_UP
		if (key.vkCode == VK_LWIN ||
			key.vkCode == VK_RWIN)
		{
			WIN_KEY_DOWN = false
			WIN_E_KEY_DOWN = false
		}
		
		// E_KEY_UP
		if (key.vkCode == 0x45)
		{
			WIN_E_KEY_DOWN = false
		}
	}
	
	return CallNextHookEx(nil, code, wparam , lparam)
}

window_proc :: proc "stdcall" (window : win32.HWND, message : u32, wparam : uintptr, lparam : int) -> int
{
	using win32
	
	switch message
	{
		case WM_DESTROY: fallthrough
		case WM_CLOSE: fallthrough
		case WM_QUIT:
			WINDOW_SHOULD_CLOSE = true
		case WM_CREATE:
			return 0
		case WM_TASKBARCREATED:
			context = runtime.default_context()
			fmt.println("Creating system tray icon")
			create_system_tray_icon()
			return 0
		case WM_NOTIFYICON:
			notification_events : NOTIFY_EVENT = cast(NOTIFY_EVENT)(lparam & 0xFFFF)
			// anchor coordinate for NIN_POPUPOPEN, NIN_SELECT, NIN_KEYSELECT,
			// and all mouse messages between WM_MOUSEFIRST and WM_MOUSELAST
			// If any of those messages are generated by the keyboard, wParam
			// is set to the upper-left corner of the target icon.

			switch notification_events
			{
				case .NIN_SELECT:
				case .NINF_KEY:
				case .NIN_KEYSELECT:
				case .NIN_BALLOONSHOW:
				case .NIN_BALLOONHIDE:
				case .NIN_BALLOONTIMEOUT:
				case .NIN_BALLOONUSERCLICK:
				case .NIN_POPUPOPEN:
				case .NIN_POPUPCLOSE:
				case .WM_CONTEXTMENU:
				case .WM_MOUSEMOVE:
				case .WM_LBUTTONDOWN:
				case .WM_LBUTTONUP:
				case .WM_LBUTTONDBLCLK:
				case .WM_RBUTTONDOWN:
					// NOTE:
					// To display a context menu for a notification icon, the
					// current window must be the foreground window before the
					// application calls TrackPopupMenu or TrackPopupMenuEx.
					// Otherwise, the menu will not disappear when the user
					// clicks outside of the menu or the window that created the
					// menu (if it is visible). If the current window is a child
					// window, you must set the (top-level) parent window as the
					// foreground window.
					SetForegroundWindow(window)
					
					cursor_position : POINT
					GetCursorPos(&cursor_position)
					TrackPopupMenu(POPUP_MENU, 0,
						cursor_position.x, cursor_position.y,
						0, window,
						nil)
					
					// NOTE:
					// However, when the current window is the foreground window,
					// the second time this menu is displayed, it appears and then
					// immediately disappears. To correct this, you must force a
					// task switch to the application that called TrackPopupMenu.
					// This is done by posting a benign message to the window or
					// thread, as shown in the following code
					PostMessageW(window, WM_NULL, 0, 0)
				case .WM_RBUTTONUP:
				case .WM_RBUTTONDBLCLK:
				case .WM_MBUTTONDOWN:
				case .WM_MBUTTONUP:
				case .WM_MBUTTONDBLCLK:
			}
			
			return 0
		case WM_COMMAND:
			menu_id : u16 = cast(u16)(wparam & 0xFFFF)
			type : u16 = cast(u16)((wparam >> 16) & 0xFFFF)
			Menu : u16 = 0
			if type == Menu
			{
				switch menu_id
				{
					case QUIT_ID:
						WINDOW_SHOULD_CLOSE = true
					case DEBUG_ID:
						DEBUG_CHECKMARK ~= MFS_CHECKED
						debug_menu_item : MENUITEMINFOW = {
							size_of(MENUITEMINFOW),
							MIIM_STATE,
							0, // used if MIIM_TYPE (4.0) or MIIM_FTYPE (>4.0)
							DEBUG_CHECKMARK, // used if MIIM_STATE
							0, // used if MIIM_ID
							nil, // used if MIIM_SUBMENU
							nil, // used if MIIM_CHECKMARKS
							nil, // used if MIIM_CHECKMARKS
							0, // used if MIIM_DATA
							nil, // used if MIIM_TYPE (4.0) or MIIM_STRING (>4.0)
							0, // used if MIIM_TYPE (4.0) or MIIM_STRING (>4.0)
							nil}
						SetMenuItemInfoW(POPUP_MENU, DEBUG_ID, false, &debug_menu_item)
						
						if DEBUG_CHECKMARK == MFS_CHECKED
						{
							FILE_PILOT_PATH_STRING = FILE_PILOT_DEBUG
						}
						else
						{
							FILE_PILOT_PATH_STRING = FILE_PILOT_RELEASE
						}
					case DISABLE_ID:
						DISABLE_CHECKMARK ~= MFS_CHECKED
						disable_menu_item : MENUITEMINFOW = {
							size_of(MENUITEMINFOW),
							MIIM_STATE,
							0, // used if MIIM_TYPE (4.0) or MIIM_FTYPE (>4.0)
							DISABLE_CHECKMARK, // used if MIIM_STATE
							0, // used if MIIM_ID
							nil, // used if MIIM_SUBMENU
							nil, // used if MIIM_CHECKMARKS
							nil, // used if MIIM_CHECKMARKS
							0, // used if MIIM_DATA
							nil, // used if MIIM_TYPE (4.0) or MIIM_STRING (>4.0)
							0, // used if MIIM_TYPE (4.0) or MIIM_STRING (>4.0)
							nil}
						SetMenuItemInfoW(POPUP_MENU, DISABLE_ID, false, &disable_menu_item)
						
						context = runtime.default_context()
						if DISABLE_CHECKMARK == MFS_CHECKED
						{
							disable_windows_hook()
							unregister_win_key_hotkey()
							DISABLED = true
						}
						else
						{
							enable_windows_hook()
							register_win_key_hotkey()
							DISABLED = false
						}
				}
			}
			
		case:
	}
	
	return DefWindowProcW (window, message, wparam, lparam)
}

main :: proc()
{
	// Make sure the process is not already running
	if process_name_in_process_list() { return }

	using win32
	instance : HANDLE = HINSTANCE(GetModuleHandleW(nil))
	assert(instance != nil)
	INSTANCE = instance
  	
	// Window creation
	window_class_name := utf8_to_wstring("Winkey FilePilot")
	window_class : WNDCLASSW =
	{
		lpfnWndProc = window_proc,
		hInstance = instance,
		lpszClassName = window_class_name,
	}
	
	RegisterClassW(&window_class)
	
	window_handle : HWND = CreateWindowW(
		lpClassName = window_class_name,
		lpWindowName = window_class_name,
		dwStyle = 0,
		X = CW_USEDEFAULT,
		Y = CW_USEDEFAULT,
		nWidth = CW_USEDEFAULT,
		nHeight = CW_USEDEFAULT,
		hWndParent = nil,
		hMenu = nil,
		hInstance = instance,
		lpParam = nil,
	)
	
	if window_handle == nil
	{
		print_win32_error("Failed to CreateWindowW")
		return
	}
	
	ShowWindow(window_handle, SW_HIDE)
	WINDOW = window_handle
	
	// Register taskbar creation
	// NOTE:
	// When we start explorer.exe this message gets triggered. This
	// will also be the moment when we create the systems tray icon
	taskbar_created := utf8_to_wstring("TaskbarCreated")
	WM_TASKBARCREATED = RegisterWindowMessageW(taskbar_created)
	
	DISABLE_CHECKMARK = win32.MFS_CHECKED
	if !DISABLED
	{
		DISABLE_CHECKMARK = win32.MFS_UNCHECKED
		enable_windows_hook()
		register_win_key_hotkey()
	}
	else
	{
		create_system_tray_icon()
	}
	
	DEBUG_CHECKMARK = MFS_CHECKED
	FILE_PILOT_PATH_STRING = FILE_PILOT_DEBUG
	if RELEASE
	{
		DEBUG_CHECKMARK = MFS_UNCHECKED
		FILE_PILOT_PATH_STRING = FILE_PILOT_RELEASE
	}
	
	// Dispatch loop
	message : MSG
	for GetMessageW(&message, window_handle, 0, 0) > 0 &&
		!WINDOW_SHOULD_CLOSE
	{
		TranslateMessage(&message)
		DispatchMessageW(&message)
	}
	
	DestroyMenu(POPUP_MENU)
	disable_windows_hook()
	unregister_win_key_hotkey()
}

disable_windows_hook :: proc()
{
	using win32
	result := UnhookWindowsHookEx(HOOK_HANDLE)
	HOOK_HANDLE = nil
	if result == true
	{
		print_win32_error("Error creating lowlevel keyboard hook")
		return
	}
	
	// NOTE:
	// You can release a global hook procedure by using UnhookWindowsHookEx,
	// but this function does not free the DLL containing the hook
	// procedure. This is because global hook procedures are called in the
	// process context of every application in the desktop, causing an
	// implicit call to the LoadLibrary function for all of those processes.
	// Because a call to the FreeLibrary function cannot be made for another
	// process, there is then no way to free the DLL. The system eventually
	// frees the DLL after all processes explicitly linked to the DLL have
	// either terminated or called FreeLibrary and all processes that called
	// the hook procedure have resumed processing outside the DLL.
}

enable_windows_hook :: proc()
{
	using win32
	// Set Windows hook for low level keyboard
	HOOK_HANDLE : HHOOK = SetWindowsHookExW(WH_KEYBOARD_LL, keyboard_proc, nil, 0)
	
	if HOOK_HANDLE == nil
	{
		print_win32_error("Error creating lowlevel keyboard hook")
		return
	}
}

register_win_key_hotkey :: proc()
{
	using win32
	log.assert(WM_TASKBARCREATED != 0,
		"No taskbar creation was not registered")
	// Register Win + E Hotkey
	libc.system("taskkill /IM explorer.exe /F")
	// NOTE:
	// The F12 key is reserved for use by the debugger at all times,
	// so it should not be registered as a hot key. Even when you
	// are not debugging an application, F12 is reserved in case a
	// kernel-mode debugger or a just-in-time debugger is resident.
	
	// An application must specify an id value in the range 0x0000
	// through 0xBFFF. A shared DLL must specify a value in the
	// range 0xC000 through 0xFFFF (the range returned by the
	// GlobalAddAtom function). To avoid conflicts with hot-key
	// identifiers defined by other shared DLLs, a DLL should use
	// the GlobalAddAtom function to obtain the hot-key identifier.
	
	// **Windows Server 2003:  **If a hot key already exists with
	// the same hWnd and id parameters, it is replaced by the new
	// hot key.
	
	// NOTE:
	// Explorer is running with Windows + E as a registered hotkey
	// So we kill it and register the hotkey before explorer.exe
	E_KEY : u32 = 0x45
	result := RegisterHotKey(WINDOW, WIN_KEY_ID, MOD_WIN | MOD_NOREPEAT, E_KEY)
	libc.system("start explorer.exe")
	if result != true
	{
		print_win32_error("Failed to RegisterHotKey")
		log.assert(result == true)
	}
}

unregister_win_key_hotkey :: proc()
{
	win32.UnregisterHotKey(WINDOW, WIN_KEY_ID)
	libc.system("taskkill /IM explorer.exe /F")
	libc.system("start explorer.exe")
}

open_file_pilot :: proc()
{
	using win32
	
	fmt.printfln("Opening file pilot from: %s", FILE_PILOT_PATH_STRING)
	open_string : string = "open"
	open : [^]u16 = utf8_to_wstring(open_string)
	file_pilot_path : [^]u16 = utf8_to_wstring(FILE_PILOT_PATH_STRING)
	working_directory : [^]u16 = utf8_to_wstring(WORKING_DIRECTORY_STRING)
	parameters : [^]u16
	
	if FILE_PILOT_PARAMETERS[0] == 0
	{
		parameters = utf8_to_wstring(WORKING_DIRECTORY_STRING)
	}
	else
	{
		parameters = raw_data(FILE_PILOT_PARAMETERS[:])
	}
	
	last_focus : HWND = GetForegroundWindow()
	active_monitor : HMONITOR
	mask_monitor : u32
	if last_focus != nil
	{
		active_monitor = MonitorFromWindow(last_focus, .MONITOR_DEFAULTTONEAREST)
		mask_monitor = SEE_MASK_HMONITOR
	}
	
	shell_execute_info_w : SHELLEXECUTEINFOW =
	{
  		cbSize = size_of(SHELLEXECUTEINFOW),
  		fMask = SEE_MASK_NOCLOSEPROCESS | mask_monitor,
		hwnd = nil,
		lpVerb = open,
		lpFile = file_pilot_path,
		lpParameters = parameters,
		lpDirectory = working_directory,
		nShow = SW_SHOW,
		hInstApp = nil,
		lpIDList = nil,
		lpClass = nil,
		hkeyClass = nil,
		dwHotKey = 0,
		DUMMYUNIONNAME = { hMonitor=cast(HANDLE)active_monitor },
		hProcess = nil,
	}
	
	// NOTE:
	// Because ShellExecute can delegate execution to Shell extensions
	// (data sources, context menu handlers, verb implementations) that
	// are activated using Component Object Model (COM), COM should be
	// initialized before ShellExecute is called.
	CoInitializeEx(nil, COINIT.MULTITHREADED | COINIT.DISABLE_OLE1DDE)
	ShellExecuteExW(&shell_execute_info_w)
	CoUninitialize()
	
	file_pilot_handle := shell_execute_info_w.hInstApp
	if (uintptr(file_pilot_handle) <= 32)
	{
		switch u32(uintptr(file_pilot_handle))
		{
			case 0:
				fmt.println("The operating system is out of memory or resources.")
			case ERROR_FILE_NOT_FOUND:
				fmt.println("The specified file was not found.")
			case ERROR_PATH_NOT_FOUND:
				fmt.println("The specified path was not found.")
			case ERROR_BAD_FORMAT:
				fmt.println("The .exe file is invalid (non-Win32 .exe or error in .exe image).")
			case SE_ERR_ACCESSDENIED:
				fmt.println("The operating system denied access to the specified file.")
			case SE_ERR_ASSOCINCOMPLETE:
				fmt.println("The file name association is incomplete or invalid.")
			case SE_ERR_DDEFAIL:
				fmt.println("The DDE transaction failed.")
			case SE_ERR_NOASSOC:
				fmt.println("There is no application associated with the given file name extension. This error will also be returned if you attempt to print a file that is not printable.")
			case SE_ERR_OOM:
				fmt.println("There was not enough memory to complete the operation.")
			case SE_ERR_SHARE:
				fmt.println("A sharing violation occurred. ")
		}
		error_description : string = fmt.tprintfln("Error opening file pilot in path: %s with working directory: %s", FILE_PILOT_PATH_STRING, WORKING_DIRECTORY_STRING)
		print_win32_error(error_description)
		
		return
	}
	
	// NOTE:
	// Should probably be handle by FilePilot itself
	bring_process_window_to_top(shell_execute_info_w.hProcess)
}

FILE_PILOT_WINDOW_HANDLE : win32.HWND
find_file_pilot_window :: proc "stdcall" (window : win32.HWND, file_pilot_id : win32.LPARAM) -> win32.BOOL
{
	window_process_id : u32
	context = runtime.default_context()
	win32.GetWindowThreadProcessId(window, &window_process_id)
	if(window_process_id == cast(u32)file_pilot_id)
    {
		FILE_PILOT_WINDOW_HANDLE = window
		return false
    }
    
	return true
}

bring_process_window_to_top :: proc(file_pilot_process : win32.HANDLE)
{
	process_id : u32 = win32.GetProcessId(file_pilot_process)
	// NOTE:
	// EnumWindows prevents infinite loops and guarantees the
	// window has not been destroyed yet, as opposed to GetWindow
	// file pilot might be slow to launch so we will loop for 1
	// second to find it
	begin_time := time.now()
	retry_duration_in_seconds : f64 = 1.0
	for win32.EnumWindows(find_file_pilot_window, cast(int)(cast(uintptr)process_id)) != false
	{
		time_passed : f64 = time.duration_seconds(time.diff(begin_time, time.now()))
		if retry_duration_in_seconds < time_passed
		{
			fmt.println("Foregrounding timed out")
			break
		}
	}
	
	if FILE_PILOT_WINDOW_HANDLE != nil
	{
		if win32.BringWindowToTop(FILE_PILOT_WINDOW_HANDLE) == false
		{
			fmt.println("Failed to BringWindowToTop")
		}
	}
}

process_name_in_process_list :: proc() -> bool
{
	using win32
	process_snapshot_handle : HANDLE =  CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
	if (process_snapshot_handle == INVALID_HANDLE_VALUE)
	{
		print_win32_error("Failed to CreateToolhelp32Snapshot")
	}
	else
	{
		process_entry : PROCESSENTRY32W
		process_entry.dwSize = size_of(PROCESSENTRY32W)
		
		current_process_name : [win32.MAX_PATH]u16
		name_length : u32 = GetModuleFileNameW(nil, raw_data(current_process_name[:]),
			len(current_process_name))
		
		last_index : u32
		for wide_char, index in current_process_name
		{
			if wide_char == '\\'
			{
				last_index = cast(u32)index + 1
			}
		}
		
		if name_length == 0 || last_index == 0
		{
			print_win32_error("Failed to GetModuleFileNameW")
		}
		else
		{
			winkey_exe_count : int = 0
			result := Process32FirstW(process_snapshot_handle, &process_entry)

			for result
			{
				match : u32
				entry_name := process_entry.szExeFile[:name_length-last_index]
				current_name := current_process_name[last_index:name_length]
				for index in 0..<name_length-last_index
				{
					if (entry_name[index] == current_name[index])
					{
						match += 1
					}
				}
				
				if match == name_length-last_index
				{
					winkey_exe_count += 1
					if winkey_exe_count == 2
					{
						return true
					}
				}

				result = Process32NextW(process_snapshot_handle, &process_entry)
			}
		}
	}
	CloseHandle(process_snapshot_handle)
	
	return false
}

create_system_tray_icon :: proc()
{
	using win32
	DestroyMenu(POPUP_MENU)
	// Create systems tray icon
	tip_string : []u8 = transmute([]u8)string("FilePilot Winkey + E")
	tip : [128]u16
	MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
	raw_data(tip_string), cast(i32)len(tip_string),
	raw_data(tip[:]), len(tip))
	info : [256]u16
	info_title : [64]u16
	
	icon : HICON = ExtractIconW(INSTANCE, utf8_to_wstring(FILE_PILOT_EXTRACT_ICON), 0)
	log.assert(icon != nil,
		"Failed to ExtractIconW")
	
	guid : GUID
	win32.CoCreateGuid(&guid)
	notify_icon_data_w : NOTIFYICONDATAW =
	{
		cbSize = size_of(NOTIFYICONDATAW),
		hWnd = WINDOW,
		uID = 0, // uID Windows Vista and earlier
		uFlags = NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP | NIF_GUID | NIF_ICON,
		uCallbackMessage = WM_NOTIFYICON,
		hIcon = icon,
		szTip = tip,
		dwState = NIS_HIDDEN,
		dwStateMask = NIS_HIDDEN,
		szInfo = info,
		uVersion = NOTIFYICON_VERSION_4,
		szInfoTitle = info_title,
		dwInfoFlags = NIIF_RESPECT_QUIET_TIME,
		guidItem = guid, // guid Windows 7 and later
		hBalloonIcon = nil,
	}
	
	success := Shell_NotifyIconW(NIM_ADD, &notify_icon_data_w)
	log.assert(success == true,
		"Failed to Shell_NotifyIconW")
	
	// Create systems tray menu
	POPUP_MENU = CreatePopupMenu()
	debug_string : string = "Debug"
	debug : [^]u16 = utf8_to_wstring(debug_string)
	AppendMenuW(POPUP_MENU, MF_ENABLED | MF_STRING | DEBUG_CHECKMARK, DEBUG_ID, debug)
	
	disable_string : string = "Disable"
	disable : [^]u16 = utf8_to_wstring(disable_string)
	AppendMenuW(POPUP_MENU, MF_ENABLED | MF_STRING | DISABLE_CHECKMARK, DISABLE_ID, disable)
	
	AppendMenuW(POPUP_MENU, MF_SEPARATOR, 0, nil)
	
	quit_string : string = "Quit"
	quit : [^]u16 = utf8_to_wstring(quit_string)
	AppendMenuW(POPUP_MENU, MF_ENABLED | MF_STRING, QUIT_ID, quit)
}

USAGE : string :
`Usage:
  winkey_filepilot will register WinKey + E and listen for
  WinKey + E events. Preventing File Explorer from opening
  and instead launching FilePilot. To close the application
  or edit its settings at runtime you can access them in
  the systems tray.
  
  -debug-path %DEBUG_PATH%		: [optional] Overrides debug path
  -release-path %RELEASE_PATH%	: [optional] Overrides release path
  -working-directory			: [optional] Overrides the working directory of the launched process
  -start-debug					: [optional] On startup WinKey + E will launch in debug
  -start-disabled				: [optional] On startup the winkey_filepilot will not launch filepilot on WinKey + E events
  -file-pilot-parameters		: [optional] Parameters to pass to FilePilot
  
  This application has NOT been tested on security.
  It does not need administrator privileges to function.
  If Task Manager is in focus, File Pilot will not open.
  This is because Task Manager runs with administrator
  priviliges. If winkey_filepilot is run as
  administrator, it will listen to WinKey + E even with
  Task Manager on top.
`
@(init)
os_args :: proc()
{
	if len(os.args) > 1
	{
		skip_next : bool
		parameters : bool
		setting_parameters : bool
		parse_argument: for argument, index in os.args[1:]
		{
			if skip_next
			{
				skip_next = false
				continue
			}
			
			parameters = false
			switch argument
			{
				case "-debug-path":
					if index + 1 < len(os.args[1:])
					{
						fmt.println("Setting debug path:")
						log.assertf(
							win32.PathFileExistsW(win32.utf8_to_wstring(os.args[index + 2])) == true,
							"Debug path is invalid: %s\n %s", os.args[index + 2], USAGE)
						FILE_PILOT_DEBUG = os.args[index + 2]
						fmt.printfln("Debug:\t\t%s", FILE_PILOT_DEBUG)
						
						skip_next = true
					}
				case "-release-path":
					if index + 1 < len(os.args[1:])
					{
						fmt.println("Setting release path:")
						log.assertf(
							win32.PathFileExistsW(win32.utf8_to_wstring(os.args[index + 2])) == true,
							"Release path is invalid: %s\n %s", os.args[index + 2], USAGE)
						FILE_PILOT_RELEASE = os.args[index + 2]
						fmt.printfln("Release:\t%s", FILE_PILOT_RELEASE)
						
						skip_next = true
					}
				case "-working-directory":
					if index + 1 < len(os.args[1:])
					{
						fmt.println("Setting working directory:")
						log.assertf(
							win32.PathFileExistsW(win32.utf8_to_wstring(os.args[index + 2])) == true,
							"Working directory is invalid: %s\n %s", os.args[index + 2], USAGE)
						WORKING_DIRECTORY_STRING = os.args[index + 2]
						fmt.printfln("Directory:\t%s", WORKING_DIRECTORY_STRING)
						
						skip_next = true
					}
				case "-file-pilot-parameters":
					parameters = true
				case "-start-debug":
					RELEASE = false
				case "-start-disabled":
					DISABLED = true
				case:
					if setting_parameters
					{
						parameters = true
						if PARAMETERS_LENGTH + cast(u32)len(os.args[index + 1]) < 512
						{
							for char in os.args[index + 1]
							{
								FILE_PILOT_PARAMETERS[PARAMETERS_LENGTH] = cast(u16)char
								PARAMETERS_LENGTH += 1
							}
							FILE_PILOT_PARAMETERS[PARAMETERS_LENGTH] = ' '
							PARAMETERS_LENGTH += 1
						}
					}
					else
					{
						fmt.printf("Invalid usage \"%s\"\n", argument)
						fmt.println(USAGE)
						os.exit(-1)
					}
			}
			
			setting_parameters = parameters
		}
		
		if PARAMETERS_LENGTH > 0
		{
			PARAMETERS_LENGTH -= 1
			FILE_PILOT_PARAMETERS[PARAMETERS_LENGTH] = 0
			params, _ := win32.utf16_to_utf8(FILE_PILOT_PARAMETERS[:PARAMETERS_LENGTH])
			fmt.printfln("FilePilot parameters: %s", params)
		}
	}
}

print_win32_error :: proc(error_description : string)
{
	fmt.println(error_description)
	error : u32 = win32.GetLastError()
	fmt.printf("Error code = %i\t%s\n", error, cast(win32.System_Error)error)
}
