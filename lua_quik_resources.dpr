{$include lua_quik_resources_defs.pas}

library lua_quik_resources;

uses  sysutils,
      LuaLib,
      lua_quik_resources_main;

{$R *.res}

function luaopen_quik_resources(ALuaInstance: Lua_State): longint; cdecl;
begin result:= initialize_quik_resources(ALuaInstance); end;

exports  luaopen_quik_resources;

begin
  IsMultiThread:= true;
  {$ifdef FPC}
  DefaultFormatSettings.DecimalSeparator:= '.';
  {$else}
  DecimalSeparator:= '.';
  {$endif}
end.
