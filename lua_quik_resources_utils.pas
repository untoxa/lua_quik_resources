unit  lua_quik_resources_utils;

interface

uses  windows, messages, sysutils;

function GetModuleName(Module: HMODULE): ansistring;

function GetWindowClassNameStr(hWnd: HWND): ansistring;
function GetWindowTextStr(hWnd: longint): ansistring;

function GetDialogTitleFromResource(aMod: hModule; aParent: HWND; aResId: longint): ansistring;
function GetMenuItemState(hWindow: HWND; idItem: longint): longint;

function get_quik_main_window: HWND;
function get_quik_child_window(hParentWnd: HWND; const acaption: ansistring): HWND;

implementation

const infoclassname = 'InfoClass';

const WM_ENDDUMMYDIALOG = WM_USER + $1000;

type  pEnumParams         = ^tEnumParams;
      tEnumParams         = record
        pid               : THandle;
        caption           : ansistring;
        result            : HWND;
      end;

function GetModuleName(Module: HMODULE): ansistring;
var ModName: array[0..MAX_PATH] of char;
begin
  fillchar(ModName, sizeof(ModName), 0);
  SetString(Result, ModName, GetModuleFileName(Module, ModName, SizeOf(ModName)));
end;

function GetWindowClassNameStr(hWnd: HWND): ansistring;
begin setlength(result, 4096); setlength(result, GetClassNameA(hWnd, @result[1], length(result))); end;

function GetWindowTextStr(hWnd: longint): ansistring;
begin setlength(result, 4096); setlength(result, GetWindowTextA(hWnd, @result[1], length(result))); end;

function DummyDlgWindowProc (hWindow: HWND; Msg, wParam: WPARAM; lParam: LPARAM): HRESULT; stdcall;
begin
  result:= 0;
  if (Msg = WM_INITDIALOG) then EndDialog(hWindow, 0);
end;

function GetDialogTitleFromResource(aMod: HModule; aParent: HWND; aResId: longint): ansistring;
var hDialog: HWND;
begin
  hDialog:= CreateDialogParamA(aMod, pAnsiChar(LPARAM(aResId)), aParent, @DummyDlgWindowProc, 0);
  if (hDialog <> 0) then begin
    result:= GetWindowTextStr(hDialog);
    DestroyWindow(hDialog);
  end else setlength(result, 0);
end;

function GetMenuItemState(hWindow: HWND; idItem: longint): longint;
var hMnu     : HMENU;
    i        : longint;
begin
  result:= -1;
  hMnu:= GetMenu(hWindow);
  i:= 0;
  while (hMnu <> 0) and (result = -1) do begin
    hMnu:= GetSubMenu(hMnu, i);
    if (hMnu <> 0) then result:= GetMenuState(hMnu, idItem, MF_BYCOMMAND);
    inc(i);
  end;
end;


function EnumQUIKWindowsCB(hWindow: HWND; lParam: LPARAM): bool; stdcall;
var wnd_pid : THandle;
begin
  result:= true;
  if (CompareText(infoclassname, GetWindowClassNameStr(hWindow)) = 0) then begin
    wnd_pid:= 0;
    GetWindowThreadProcessId(hWindow, @wnd_pid);
    result:= not ((wnd_pid = pEnumParams(lParam)^.pid) and IsWindowVisible(hWindow));
    if not result then pEnumParams(lParam)^.result:= hWindow;
  end;
end;

function get_quik_main_window: HWND;
var search_data : tEnumParams;
begin
  search_data.pid:= GetCurrentProcessId;
  search_data.result:= 0;
  EnumChildWindows(HWND_DESKTOP, @EnumQUIKWindowsCB, LPARAM(@search_data));
  result:= search_data.result;
end;

function EnumChildWindowsCB(hWindow: HWND; lParam: LPARAM): bool; stdcall;
var wnd_pid : THandle;
begin
  if (lParam <> 0) then begin
    if (AnsiCompareText(GetWindowTextStr(hWindow), pEnumParams(lParam)^.caption) = 0) then begin
      wnd_pid:= 0;
      GetWindowThreadProcessId(hWindow, @wnd_pid);
      if (wnd_pid = pEnumParams(lParam)^.pid) then begin
        pEnumParams(lParam)^.result:= hWindow;
        result:= false;
      end else result:= true;
    end else result:= true;
  end else result:= false;
end;

function get_quik_child_window(hParentWnd: HWND; const acaption: ansistring): HWND;
var search_data : tEnumParams;
begin
  search_data.pid:= GetCurrentProcessId;
  search_data.caption:= acaption;
  search_data.result:= 0;
  EnumChildWindows(hParentWnd, @EnumChildWindowsCB, LPARAM(@search_data));
  result:= search_data.result;
end;

end.
