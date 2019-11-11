{$include lua_quik_resources_defs.pas}

unit lua_quik_resources_main;

interface

uses  windows, classes, sysutils, math,
      Lua, LuaLib, LuaHelpers,
      lua_quik_resources_utils;

const package_name       = 'quik_resources';

const lua_supported_libs : array[0..1] of ansistring = ('Lua5.1.dll', 'qlua.dll');

type  tLuaQuikResources      = class;

      tLuaQuikResources      = class(TLuaClass)
      private
        fQUIKWnd             : HWND;
        fResHndl             : HModule;
        
        function    fGetQuikHandle: HWND;
      protected
        function    GetQUIKResources(LuaState: TLuaState): THandle;
      public
        constructor create;

        // LUA functions
        function    get_quik_handle(LuaState: TLuaState): integer;
        function    get_menu_state(LuaState: TLuaState): integer;

        function    get_dlg_title(LuaState: TLuaState): integer;
        function    set_dlg_item_text(LuaState: TLuaState): integer;

        function    post_message(LuaState: TLuaState): integer;
        function    send_message(LuaState: TLuaState): integer;

        function    get_child_handle(LuaState: TLuaState): integer;

        property    QUIKHandle: HWND read fGetQuikHandle;
      end;

function initialize_quik_resources(ALuaInstance: Lua_State): integer;

implementation

const quik_resources_instance: tLuaQuikResources = nil;

{ tLuaQuikResources }

constructor tLuaQuikResources.create;
begin
  inherited create;
  fQUIKWnd:= 0;
  fResHndl:= 0;
end;

function tLuaQuikResources.fGetQuikHandle: HWND;
begin
  if (fQUIKWnd = 0) then fQUIKWnd:= get_quik_main_window();
  result:= fQUIKWnd;
end;

function tLuaQuikResources.GetQUIKResources(LuaState: TLuaState): THandle;
const resources_library_name = 'lang_res.dll';
var   res_lib_name : ansistring;
begin
  if (fResHndl = 0) then
    with TLuaContext.create(LuaState) do try
      res_lib_name:= Globals['quik_resources_lib'].AsString(resources_library_name);
      fResHndl:= GetModuleHandleA(pAnsiChar(res_lib_name));
    finally free; end;
  result:= fResHndl;
end;

function tLuaQuikResources.get_quik_handle(LuaState: TLuaState): integer;
begin
  with TLuaContext.create(LuaState) do try
    PushArgs([int64(QUIKHandle)]);
    result:= 1;
  finally free; end;
end;

function tLuaQuikResources.get_menu_state(LuaState: TLuaState): integer;
begin
  with TLuaContext.create(LuaState) do try
    PushArgs([GetMenuItemState(Stack[1].AsInteger, Stack[2].AsInteger)]);
    result:= 1;
  finally free; end;
end;

function tLuaQuikResources.get_dlg_title(LuaState: TLuaState): integer;
begin
  with TLuaContext.create(LuaState) do try
    PushArgs([GetDialogTitleFromResource(GetQUIKResources(LuaState), QUIKHandle, WORD(Stack[1].AsInteger))]);
    result:= 1;
  finally free; end;
end;

function tLuaQuikResources.set_dlg_item_text(LuaState: TLuaState): integer;
var wnd : HWND;
begin
  with TLuaContext.create(LuaState) do try
    wnd:= HWND(Stack[1].AsInteger);
    if (wnd <> 0) then SetDlgItemTextA(wnd, Stack[2].AsInteger, pAnsiChar(Stack[3].AsString));
    result:= 0;
  finally free; end;
end;

function tLuaQuikResources.post_message(LuaState: TLuaState): integer;
begin
  with TLuaContext.create(LuaState) do try
    PostMessageA(HWND(Stack[1].AsInteger), WPARAM(Stack[2].AsInteger), WPARAM(Stack[3].AsInteger), LPARAM(Stack[4].AsInteger));
    result:= 0;
  finally free; end;
end;

function tLuaQuikResources.send_message(LuaState: TLuaState): integer;
begin
  with TLuaContext.create(LuaState) do try
    PushArgs([SendMessageA(HWND(Stack[1].AsInteger), WPARAM(Stack[2].AsInteger), WPARAM(Stack[3].AsInteger), LPARAM(Stack[4].AsInteger))]);
    result:= 1;
  finally free; end;
end;

function tLuaQuikResources.get_child_handle(LuaState: TLuaState): integer;
begin
  with TLuaContext.create(LuaState) do try
    PushArgs([int64(get_quik_child_window(HWND(Stack[1].AsInteger), Stack[2].AsString))]);
    result:= 1;
  finally free; end;
end;

{ initialization functions }

function initialize_lua_library: boolean;
var path : ansistring;
    i    : integer;
begin
  result:= false;
  path := IncludeTrailingBackslash(extractfilepath(GetModuleName(0)));
  i:= low(lua_supported_libs);
  while not result and (i <= high(lua_supported_libs)) do begin
    result:= FileExists(path + lua_supported_libs[i]);
    if result then SetLuaLibFileName(path + lua_supported_libs[i]);
    inc(i);
  end;
end;

function initialize_quik_resources(ALuaInstance: Lua_State): integer;
begin
  result:= 0;
  if not assigned(quik_resources_instance) and initialize_lua_library() then begin
    quik_resources_instance:= tLuaQuikResources.Create;
    with quik_resources_instance do begin
      StartRegister(ALuaInstance);
      // register adapter functions
      RegisterMethod('get_quik_handle', get_quik_handle);
      RegisterMethod('get_menu_state', get_menu_state);
      RegisterMethod('get_dlg_title', get_dlg_title);
      RegisterMethod('set_dlg_item_text', set_dlg_item_text);
      RegisterMethod('post_message', post_message);
      RegisterMethod('send_message', send_message);
      RegisterMethod('get_child_handle', get_child_handle);
      result:= StopRegister(package_name);
    end;
  end else messagebox(0, pAnsiChar(format('ERROR: failed to find LUA library: %s', [lua_supported_libs[0]])), 'Error', 0);
  result:= min(result, 1);
end;

initialization

finalization
  if assigned(quik_resources_instance) then freeandnil(quik_resources_instance);

end.
