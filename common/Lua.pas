unit Lua;

interface

uses
  Classes, SysUtils,
  LuaLib;

type
  TLuaState         = Lua_State;
  tLuaFunction      = function(astate: TLuaState): integer of object;

  TFuncProxyObject  = class(TObject)
  private
    FName            : ansistring;
    FMethod          : tLuaFunction;
  public
    constructor Create(const AName: ansistring; AMethod: tLuaFunction); reintroduce;
    function    Call(astate: TLuaState): integer;

    property    Name: ansistring read FName;
    property    Method: tLuaFunction read FMethod;
  end;

  TFuncList        = class(TList)
  protected
    procedure   Notify(Ptr: Pointer; Action: TListNotification); override;
    procedure   RegisterMethod(const AName: ansistring; AMethod: tLuaFunction);
  end;

  TLuaClass         = class(TObject)
  private
    fFuncs          : TFuncList;
    fStartCount     : integer;
    fRegisterState  : TLuaState;
  public
    constructor create;
    destructor  destroy; override;
    procedure   StartRegister(ALuaState: TLuaState);
    procedure   RegisterMethod(const AName: ansistring; AMethod: tLuaFunction);
    function    StopRegister(const ALibName: ansistring): integer;
  end;

implementation

{LuaProxyFunction}

function LuaProxyFunction(astate: Lua_State): Integer; cdecl;
var func: tLuaFunction;
begin
  TMethod(func).Data:= lua_topointer(astate, lua_upvalueindex(1));
  TMethod(func).Code:= lua_topointer(astate, lua_upvalueindex(2));
  if assigned(func) then result:= func(astate)
                    else result:= 0;
end;

{ TFuncProxyObject }

constructor TFuncProxyObject.Create(const AName: ansistring; AMethod: tLuaFunction);
begin
  inherited create;
  fname:= aname;
  fmethod:= amethod;
end;

function TFuncProxyObject.Call(astate: TLuaState): integer;
begin if assigned(FMethod) then result:= FMethod(astate) else result:= 0; end;

{ TFuncList }

procedure TFuncList.Notify(Ptr: Pointer; Action: TListNotification);
begin if (Action = lnDeleted) and assigned(Ptr) then TFuncProxyObject(Ptr).free; end;

procedure TFuncList.RegisterMethod(const AName: ansistring; AMethod: tLuaFunction);
begin add(TFuncProxyObject.Create(AName, AMethod)); end;

{ TLuaClass }

constructor TLuaClass.create;
begin
  inherited create;
  fStartCount:= 0;
  fRegisterState:= nil;
  fFuncs:= TFuncList.create;

  if (not LuaLibLoaded) then LoadLuaLib;
end;

destructor TLuaClass.destroy;
begin
  if assigned(fFuncs) then freeandnil(fFuncs);
  inherited;
end;

procedure TLuaClass.StartRegister(ALuaState: TLuaState);
begin
  fRegisterState:= ALuaState;
  fStartCount:= fFuncs.Count;
end;

procedure TLuaClass.RegisterMethod(const AName: ansistring; AMethod: tLuaFunction);
begin ffuncs.RegisterMethod(AName, AMethod); end;

function TLuaClass.StopRegister(const ALibName: ansistring): integer;
var i   : integer;
    obj : TFuncProxyObject;
begin
  result:= 0;
  with ffuncs do
    if count > fStartCount then begin
      lua_createtable(fRegisterState, count - fStartCount, 0);
      for i:= fStartCount to count - 1 do begin
        obj:= TFuncProxyObject(items[i]);
        lua_pushstring(fRegisterState, pAnsiChar(obj.Name));
        lua_pushlightuserdata(fRegisterState, TMethod(obj.Method).Data);
        lua_pushlightuserdata(fRegisterState, TMethod(obj.Method).Code);
        lua_pushcclosure(fRegisterState, LuaProxyFunction, 2);
        lua_settable(fRegisterState, -3);
        inc(result);
      end;
      lua_pushvalue(fRegisterState, -1);
      lua_setglobal(fRegisterState, pAnsiChar(ALibName));
    end;
end;

end.