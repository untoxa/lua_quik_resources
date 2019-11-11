unit multilist;

interface

uses  Windows, Messages, Classes, SysUtils, math;

const WM_GET_ML_CELL          = WM_USER + $2400;

type  pHelperCellRequest      = ^tHelperCellRequest;
      tHelperCellRequest      = record
        coords                : tPoint;
        result_len            : integer;
        result_text           : pAnsiChar;
      end;

type  pMultiListParams        = ^tMultiListParams;
      tMultiListParams        = record
        unknown0              : longint;
        hWindow               : HWND;
        unknown2              : longint;
        unknown3              : longint;
        unknown4              : longint;
        YSelection            : longint;
        unknown6              : longint;
        RowCount              : longint;
        ColCount              : longint;
        NFixedRows            : longint;
        NFixedCols            : longint;
        YCurPos               : longint;
        XRestPix              : longint;
        YRestPix              : longint;
        XScrollPosPix         : longint;
        YScrollPosPix         : longint;
        XTotalPix             : longint;
        YTotalPix             : longint;
        // dummy data if multilist version changes
        dummy                 : array[0..31] of longint;
      end;

const ML_SetFixed             = $7E8; // wparam = count, lparam = direction (0 == horizontal, 1 == vertical)
      ML_AddColumn            = $7E9; // wparam, lparam
      ML_SetDataPos           = $7EA; // wparam = col, lparam = row
      ML_SetData              = $7EB; // wparam = flags (1 == SetDataShift; 2 == noInvalidate), lparam = pAnsiChar data
      ML_InsLine              = $7EC; // wparam
      ML_DelLine              = $7ED; // wparam
      ML_SetStyle             = $7EE;
      ML_GetPropMask          = $7F3; // wparam, lparam
      ML_GetProperty          = $7F5; // unknown
      ML_SetSelection         = $7F6; // wparam, lparam
      ML_GetSelection         = $7F7; // none
      ML_GetTableParams       = $7FA; // lparam = buffer
      ML_GetLineHeight        = $7FC;
      ML_GetColumnWidth       = $7FE; // wparam
      ML_SetColumnWidth       = $7FF; //
      ML_SetProperty          = $7F0; // wparam = flags, lparam = property
      ML_SetRowDataCallBack   = $802; // wparam, lparam = CallBackAddress
      ML_DelLines             = $803; // wparam = index, lparam = count
      ML_InsLines             = $805; // wparam = index, lparam = count
      ML_GetNumColumnsPerPage = $808; // wparam
      ML_UpdateColumnWidth    = $80C;
      ML_GetColumnByPoint     = $80D;

function  ml_findgrid(aparent: HWND; aparentcaption: pAnsiChar): HWND;
function  ml_gettext(hgrid: HWND; const acoords: tPoint): ansistring;
function  ml_getrowcount(hgrid: HWND): longint;
function  ml_getcolcount(hgrid: HWND): longint;

function  ml_helper_gettext(hmain, hgrid: HWND; const acoords: tPoint): ansistring;

function  get_main_window: HWND;

implementation

function ml_gettext(hgrid: HWND; const acoords: tPoint): ansistring;
begin
  SendMessage(hgrid, ML_SetDataPos, acoords.y, acoords.x);
  setlength(result, 4096);
  setstring(result, pAnsiChar(@result[1]), max(0, GetWindowTextA(hgrid, @result[1], length(result)) - 1));
end;

function ml_helper_gettext(hmain, hgrid: HWND; const acoords: tPoint): ansistring;
var req_msg : tHelperCellRequest;
begin
  setlength(result, 4096);
  req_msg.coords:= acoords;
  req_msg.result_len:= length(result);
  req_msg.result_text:= @result[1];
  setlength(result, max(0, SendMessage(hmain, WM_GET_ML_CELL, WPARAM(hgrid), LPARAM(@req_msg)) - 1));
end;

function ml_gettextcolumn(hgrid: HWND; const acolname: ansistring; arow: longint): ansistring;
var prm     : tMultiListParams;
    i, pcol : longint;
begin
  setlength(result, 0);
  if (arow >= 0) then begin
    fillchar(prm, sizeof(prm), 0);
    SendMessage(hgrid, ML_GetTableParams, 0, LPARAM(@prm));
    pcol:= -1; i:= 0;
    while (i < prm.ColCount) and (pcol < 0) do
      if (ansicomparetext(ml_gettext(hgrid, point(i, 0)), acolname) = 0) then pcol:= i else inc(i);
    if (pcol >= 0) then result:= ml_gettext(hgrid, point(pcol, arow));
  end;
end;

function ml_getrowcount(hgrid: HWND): longint;
var prm     : tMultiListParams;
begin
  fillchar(prm, sizeof(prm), 0);
  SendMessage(hgrid, ML_GetTableParams, 0, LPARAM(@prm));
  result:= prm.RowCount;
end;

function ml_getcolcount(hgrid: HWND): longint;
var prm     : tMultiListParams;
begin
  fillchar(prm, sizeof(prm), 0);
  SendMessage(hgrid, ML_GetTableParams, 0, LPARAM(@prm));
  result:= prm.ColCount;
end;

const multilistclassname = 'MultiList';
      infoclassname      = 'InfoClass';

type pEnumParams         = ^tEnumParams;
     tEnumParams         = record
       pid               : THandle;
       caption           : ansistring;
       result            : HWND;
     end;

function GetWindowTextStr(hWnd: HWND): ansistring;
begin setlength(result, 4096); setlength(result, GetWindowTextA(hWnd, @result[1], length(result))); end;

function GetWindowClassNameStr(hWnd: HWND): ansistring;
begin setlength(result, 4096); setlength(result, GetClassNameA(hWnd, @result[1], length(result))); end;

function EnumGrids(hWindow: HWND; lParam: LPARAM): bool; stdcall;
begin
  result:= true;
  if (lParam <> 0) then begin
    if (CompareText(GetWindowClassNameStr(hWindow), multilistclassname) = 0) then begin
       pEnumParams(lParam)^.result:= hWindow;
      result:= false;
    end;
  end else result:= false;
end;

function EnumChildren(hWindow: HWND; lParam: LPARAM): bool; stdcall;
begin
  result:= true;
  if (lParam <> 0) then begin
    if (AnsiCompareText(GetWindowTextStr(hWindow), pEnumParams(lParam)^.caption) = 0) then begin
      EnumChildWindows(hWindow, @EnumGrids, lParam);
      result:= false;
    end;
  end else result:= false;
end;

function  ml_findgrid(aparent: HWND; aparentcaption: pAnsiChar): HWND;
var res : tEnumParams;
begin
  res.result:= 0;
  if assigned(aparentcaption) then begin
    res.caption:= aparentcaption;
    EnumChildWindows(aparent, @EnumChildren, LPARAM(@res));
  end;
  result:= res.result;
end;

function EnumQUIKWindows(hWindow: HWND; lParam: LPARAM): bool; stdcall;
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

function get_main_window: HWND;
var search_data : tEnumParams;
begin
  search_data.pid:= GetCurrentProcessId;
  search_data.result:= 0;
  EnumChildWindows(HWND_DESKTOP, @EnumQUIKWindows, LPARAM(@search_data));
  result:= search_data.result;
end;

end.