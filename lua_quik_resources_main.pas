{$include lua_quik_resources_defs.pas}

unit lua_quik_resources_main;

interface

uses  windows, classes, sysutils, math,
      LuaLib, LuaHelpers,
      lua_quik_resources_utils;

const package_name       = 'quik_resources';

const lua_supported_libs : array[0..1] of pAnsiChar = ('Lua5.1.dll', 'qlua.dll');

type  tLuaQuikResources      = class;

      tLuaQuikResources      = class(TLuaClass)
      private
        fQUIKWnd             : HWND;
        fResHndl             : HModule;
        
        function    fGetQuikHandle: HWND;
      protected
        function    GetQUIKResources(AContext: TLuaContext): THandle;
      public
        constructor create(hLib: HMODULE);

        // LUA functions
        function    get_quik_handle(AContext: TLuaContext): integer;
        function    get_menu_state(AContext: TLuaContext): integer;

        function    get_dlg_title(AContext: TLuaContext): integer;
        function    set_dlg_item_text(AContext: TLuaContext): integer;

        function    post_message(AContext: TLuaContext): integer;
        function    send_message(AContext: TLuaContext): integer;

        function    get_child_handle(AContext: TLuaContext): integer;

        property    QUIKHandle: HWND read fGetQuikHandle;
      end;

function initialize_quik_resources(ALuaInstance: Lua_State): integer;

implementation

const quik_resources_instance: tLuaQuikResources = nil;

{ tLuaQuikResources }

constructor tLuaQuikResources.create(hLib: HMODULE);
begin
  inherited create(hLib);
  fQUIKWnd:= 0;
  fResHndl:= 0;
end;

function tLuaQuikResources.fGetQuikHandle: HWND;
begin
  if (fQUIKWnd = 0) then fQUIKWnd:= get_quik_main_window();
  result:= fQUIKWnd;
end;

function tLuaQuikResources.GetQUIKResources(AContext: TLuaContext): THandle;
const resources_library_name = 'lang_res.dll';
var   res_lib_name : ansistring;
begin
  if (fResHndl = 0) then begin
    with AContext do res_lib_name:= Globals['quik_resources_lib'].AsString(resources_library_name);
    fResHndl:= GetModuleHandleA(pAnsiChar(res_lib_name));
  end;
  result:= fResHndl;
end;

function tLuaQuikResources.get_quik_handle(AContext: TLuaContext): integer;
begin
  with AContext do
    result:= PushArgs([int64(QUIKHandle)]);
end;

function tLuaQuikResources.get_menu_state(AContext: TLuaContext): integer;
begin
  with AContext do
    result:= PushArgs([GetMenuItemState(Stack[1].AsInteger, Stack[2].AsInteger)]);
end;

function tLuaQuikResources.get_dlg_title(AContext: TLuaContext): integer;
begin
  with AContext do
    result:= PushArgs([GetDialogTitleFromResource(GetQUIKResources(AContext), QUIKHandle, WORD(Stack[1].AsInteger))]);
end;

function tLuaQuikResources.set_dlg_item_text(AContext: TLuaContext): integer;
var wnd : HWND;
begin
  with AContext do begin
    wnd:= HWND(Stack[1].AsInteger);
    if (wnd <> 0) then SetDlgItemTextA(wnd, Stack[2].AsInteger, pAnsiChar(Stack[3].AsString));
  end;
  result:= 0;
end;

function tLuaQuikResources.post_message(AContext: TLuaContext): integer;
begin
  with AContext do
    PostMessageA(HWND(Stack[1].AsInteger), WPARAM(Stack[2].AsInteger), WPARAM(Stack[3].AsInteger), LPARAM(Stack[4].AsInteger));
  result:= 0;
end;

function tLuaQuikResources.send_message(AContext: TLuaContext): integer;
begin
  with AContext do
    result:= PushArgs([SendMessageA(HWND(Stack[1].AsInteger), WPARAM(Stack[2].AsInteger), WPARAM(Stack[3].AsInteger), LPARAM(Stack[4].AsInteger))]);
end;

function tLuaQuikResources.get_child_handle(AContext: TLuaContext): integer;
begin
  with AContext do
    result:= PushArgs([int64(get_quik_child_window(HWND(Stack[1].AsInteger), Stack[2].AsString))]);
end;

{ initialization functions }

function initialize_lua_library: HMODULE;
var i    : integer;
begin
  result:= 0;
  i:= low(lua_supported_libs);
  while (i <= high(lua_supported_libs)) do begin
    result:= GetModuleHandle(lua_supported_libs[i]);
    if (result <> 0) then i:= high(lua_supported_libs) + 1
                     else inc(i);
  end;
end;

function initialize_quik_resources(ALuaInstance: Lua_State): integer;
var hLib : HMODULE;
begin
  result:= 0;
  if not assigned(quik_resources_instance) then begin
    hLib:= initialize_lua_library;
    if (hLib <> 0) then quik_resources_instance:= tLuaQuikResources.Create(hLib)
                   else messagebox(0, pAnsiChar(format('ERROR: failed to find LUA library: %s', [lua_supported_libs[0]])), 'Error', 0);
  end;
  if assigned(quik_resources_instance) then
    with quik_resources_instance do begin
      StartRegister;
      // register adapter functions
      RegisterMethod('get_quik_handle', get_quik_handle);
      RegisterMethod('get_menu_state', get_menu_state);
      RegisterMethod('get_dlg_title', get_dlg_title);
      RegisterMethod('set_dlg_item_text', set_dlg_item_text);
      RegisterMethod('post_message', post_message);
      RegisterMethod('send_message', send_message);
      RegisterMethod('get_child_handle', get_child_handle);
      result:= StopRegister(ALuaInstance, package_name);
    end;
  result:= min(result, 1);
end;

initialization

finalization
  if assigned(quik_resources_instance) then freeandnil(quik_resources_instance);

end.
