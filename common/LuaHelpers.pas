unit LuaHelpers;

interface

uses 
  Classes, SysUtils,
  LuaLib;

type
  TLuaState     = LuaLib.lua_State;

  TLuaContext   = class;
  TLuaTable     = class;

  TLuaField     = class(tObject)
  private
    fContext    : TLuaContext;
    fFieldType  : integer;
    fNumber     : double;
    fBool       : boolean;
    fString     : ansistring;
    fTable      : TLuaTable;
    fIndex      : integer;

    function    getabsindex(AIndex: integer): integer;
    function    fExtractField(AIndex: integer): TLuaField;
    function    fGetField(AIndex: integer; const AName: ansistring): TLuaField;
  public
    constructor create(AContext: TLuaContext);
    destructor  destroy; override;
    function    AsBoolean(adefault: boolean = false): boolean;
    function    AsInteger(adefault: integer = 0): integer;
    function    AsNumber(adefault: double = 0.0): double;
    function    AsString(const adefault: ansistring = ''): ansistring;
    function    AsTable: TLuaTable;

    function    IsFunction: boolean;
    function    IsTable: boolean;

    property    FieldType: integer read fFieldType;
    property    FieldByName[AIndex: integer; const AName: ansistring]: TLuaField read fGetField; default;
  end;

  TLuaTable     = class(tObject)
  private
    fContext    : TLuaContext;
    fField      : TLuaField;
    fIndex      : integer;
    fPopSize    : integer;
    fCurField   : TLuaField;
    fStackAlloc : boolean;

    function    getabsindex(AIndex: integer): integer;
    procedure   fSetIndex(AIndex: integer);
    function    fGetFieldByName(const AName: ansistring): TLuaField;
    function    fGetField: TLuaField;
    function    fGetSelf: TLuaTable;
  protected
    property    Field: TLuaField read fGetField;
  public
    constructor create(AContext: TLuaContext); overload;
    constructor create(AContext: TLuaContext; AIndex: integer); overload;
    constructor create(AContext: TLuaContext; ALuaTable: TLuaTable; const AName: ansistring); overload;
    constructor create(AContext: TLuaContext; const AGlobalName: ansistring); overload;
    destructor  destroy; override;

    function    FindFirst: boolean;
    function    FindNext: boolean;
    procedure   FindClose;

    function    FindField(const AName: ansistring): boolean;

    function    CallMethodSafe(const AName: ansistring; const AArgs: array of const; AResCount: integer; var error: ansistring; AResType: integer = LUA_TNONE): boolean;

    property    CurrentTable: TLuaTable read fGetSelf;
    property    Index: integer read fIndex write fSetIndex;
    property    FieldByName[const AName: ansistring]: TLuaField read fGetFieldByName; default;
    property    CurrentField: TLuaField read fCurField;
    property    Context: TLuaContext read fContext;
  end;

  TLuaContext   = class(tObject)
  private
    fLuaState   : TLuaState;
    fField      : TLuaField;
    function    fGetStackByIndex(AIndex: integer): TLuaField;
    function    fGetGlobalByName(const AName: ansistring): TLuaField;
    function    fGetSelf: TLuaContext;
  public
    constructor create(ALuaState: TLuaState);
    destructor  destroy; override;

    function    PushArgs(const aargs: array of const; avalueslist: boolean = true): integer;

    function    PushTable(aKVTable: tStringList; avalueslist: boolean = true): integer; overload;
    function    PushTable(const aargs: array of const): integer; overload;  // aargs must look like: ['name1', value1, 'name2', value2]

    function    Call(const AName: ansistring; const AArgs: array of const; AResCount: integer; AResType: integer = LUA_TNONE): boolean;
    function    CallSafe(const AName: ansistring; const AArgs: array of const; AResCount: integer; var error: ansistring; AResType: integer = LUA_TNONE): boolean;

    function    ExecuteSafe(const AScript: ansistring; AResCount: integer; var error: ansistring): boolean;

    procedure   CleanUp(ACount: integer);

    procedure   SetGlobal(AIndex: integer; const AName: ansistring);
    procedure   ResetGlobal(const AName: ansistring);

    property    CurrentContext: TLuaContext read fGetSelf;
    property    CurrentState: TLuaState read fLuaState;
    property    Stack[AIndex: integer]: TLuaField read fGetStackByIndex; default;
    property    Globals[const AName: ansistring]: TLuaField read fGetGlobalByName;
  end;

  TOnTableItemEx = function(ATable: TLuaTable): boolean of object;

implementation

function  StrToFloatDef(const astr: ansistring; adef: extended): extended;
begin if not TextToFloat(pAnsiChar(astr), result, fvExtended) then result:= adef; end;

{ TLuaField }

constructor TLuaField.create(AContext: TLuaContext);
begin
  inherited create;
  fContext:= AContext;
  fTable:= nil;
  fFieldType:= LUA_TNONE;
  fNumber:= 0;
  fBool:= false;
  setlength(fString, 0);
end;

destructor TLuaField.destroy;
begin
  if assigned(fTable) then freeandnil(fTable);
  inherited destroy;
end;

function TLuaField.getabsindex(AIndex: integer): integer;
begin
  if ((AIndex = LUA_GLOBALSINDEX) or (AIndex = LUA_REGISTRYINDEX)) then result := AIndex
  else if (AIndex < 0) then result := AIndex + lua_gettop(fContext.CurrentState) + 1
  else result := AIndex;
end;

function TLuaField.fExtractField(AIndex: integer): TLuaField;
var len : cardinal;
begin
  fFieldType:= lua_type(fContext.CurrentState, AIndex);
  case fFieldType of
    LUA_TNUMBER   : fNumber := lua_tonumber(fContext.CurrentState, AIndex);
    LUA_TBOOLEAN  : fBool := lua_toboolean(fContext.CurrentState, AIndex);
    LUA_TSTRING   : begin
                      len:= 0;
                      SetString(fString, lua_tolstring(fContext.CurrentState, AIndex, len), len);
                    end;
    LUA_TTABLE    : begin
                      if not assigned(fTable) then fTable:= TLuaTable.create(fContext, AIndex)
                                              else fTable.Index:= AIndex;
                    end;
    LUA_TFUNCTION : fIndex:= getabsindex(aindex);
    else            fFieldType:= LUA_TNONE;
  end;
  result:= Self;
end;

function TLuaField.fGetField(AIndex: integer; const AName: ansistring): TLuaField;
begin
  result:= Self;
  lua_pushstring(fContext.CurrentState, pAnsiChar(AName));
  lua_gettable(fContext.CurrentState, AIndex);
  try
    case lua_type(fContext.CurrentState, -1) of
      LUA_TTABLE : fFieldType:= LUA_TNONE;
      else         result:= fExtractField(-1) // only simple types allowed
    end;
  finally lua_pop(fContext.CurrentState, 1); end;
end;

function TLuaField.AsBoolean(adefault: boolean): boolean;
begin
  case fFieldType of
    LUA_TBOOLEAN : result:= fBool;
    LUA_TNUMBER  : result:= (fNumber <> 0);
    LUA_TSTRING  : result:= (AnsiCompareText(fString, 'TRUE') = 0);
    else           result:= adefault;
  end;
end;

function TLuaField.AsInteger(adefault: integer): integer;
begin result:= round(AsNumber(adefault)); end;

function TLuaField.AsNumber(adefault: double): double;
begin
  case fFieldType of
    LUA_TBOOLEAN : result:= integer(fBool);
    LUA_TNUMBER  : result:= fNumber;
    LUA_TSTRING  : result:= StrToFloatDef(fString, adefault);
    else           result:= adefault;
  end;
end;

function TLuaField.AsString(const adefault: ansistring): ansistring;
const boolval : array[boolean] of ansistring = ('FALSE', 'TRUE');
begin
  case fFieldType of
    LUA_TBOOLEAN : result:= boolval[fBool];
    LUA_TNUMBER  : result:= FloatToStr(fNumber);
    LUA_TSTRING  : result:= fString;
    else           result:= adefault;
  end;
end;

function TLuaField.AsTable: TLuaTable;
begin
  if (fFieldType = LUA_TTABLE) then result:= fTable
                               else result:= nil;
end;

function TLuaField.IsFunction: boolean;
begin result:= (fFieldType = LUA_TFUNCTION); end;

function TLuaField.IsTable: boolean;
begin result:= (fFieldType = LUA_TTABLE); end;

{ TLuaTable }

constructor TLuaTable.create(AContext: TLuaContext);
begin
  inherited create;
  fContext:= AContext;
  fField:= nil;
  fCurField:= nil;
  fIndex:= 0;
  fStackAlloc:= false;
  fPopSize:= 0;
end;

constructor TLuaTable.create(AContext: TLuaContext; AIndex: integer);
begin
  inherited create;
  fContext:= AContext;
  fField:= nil;
  fCurField:= nil;
  fIndex:= getabsindex(AIndex);
  fStackAlloc:= false;
  fPopSize:= 0;
end;

constructor TLuaTable.create(AContext: TLuaContext; ALuaTable: TLuaTable; const AName: ansistring);
begin
  inherited create;
  fContext:= AContext;
  fField:= nil;
  fCurField:= nil;
  fIndex:= 0;
  fStackAlloc:= false;
  fPopSize:= 0;

  lua_pushstring(fContext.CurrentState, pAnsiChar(AName));
  lua_gettable(fContext.CurrentState, ALuaTable.Index);
  if lua_istable(fContext.CurrentState, -1) then begin
    fIndex:= getabsindex(-1);
    fStackAlloc:= true;
  end else begin
    lua_pop(fContext.CurrentState, 1);
    raise Exception.CreateFmt('Field %s is not a table', [AName]);
  end;
end;

constructor TLuaTable.create(AContext: TLuaContext; const AGlobalName: ansistring);
begin
  inherited create;
  fContext:= AContext;
  fField:= nil;
  fCurField:= nil;
  fIndex:= 0;
  fStackAlloc:= false;
  fPopSize:= 0;

  lua_getglobal(fContext.CurrentState, pAnsiChar(AGlobalName));
  if lua_istable(fContext.CurrentState, -1) then begin
    fIndex:= getabsindex(-1);
    fStackAlloc:= true;
  end else begin
    lua_pop(fContext.CurrentState, 1);
    raise Exception.CreateFmt('Global %s is not a table', [AGlobalName]);
  end;
end;

destructor TLuaTable.destroy;
begin
  if fStackAlloc then lua_pop(fContext.CurrentState, 1);
  fCurField:= nil;
  if assigned(fField) then freeandnil(fField);
  inherited destroy;
end;

function TLuaTable.getabsindex(AIndex: integer): integer;
begin
  if ((AIndex = LUA_GLOBALSINDEX) or (AIndex = LUA_REGISTRYINDEX)) then result := AIndex
  else if (AIndex < 0) then result := AIndex + lua_gettop(fContext.CurrentState) + 1
  else result := AIndex;
end;

procedure TLuaTable.fSetIndex(AIndex: integer);
begin fIndex:= getabsindex(AIndex); end;

function TLuaTable.fGetField: TLuaField;
begin
  if not assigned(fField) then fField:= TLuaField.create(fContext);
  result:= fField;
end;

function TLuaTable.fGetFieldByName(const AName: ansistring): TLuaField;
begin result:= Field.FieldByName[fIndex, AName]; end;

function TLuaTable.fGetSelf: TLuaTable;
begin result:= Self; end;

function TLuaTable.FindFirst: boolean;
begin
  FindClose;
  lua_pushnil(fContext.CurrentState);
  lua_pushnil(fContext.CurrentState);  // imitate "value"
  result:= FindNext;
end;

function TLuaTable.FindNext: boolean;
begin
  lua_pop(fContext.CurrentState, 1);   // pop previous "value"
  result:= (lua_next(fContext.CurrentState, Index) <> 0);
  if result then begin
    fCurField:= Field.fExtractField(-1);
    fPopSize:= 2;                      // leave "key" on stack, need to cleanup if findclose()
  end else begin
    fCurField:= nil;
    fPopSize:= 0;                      // no need to cleanup, stack is empty
  end;
end;

procedure TLuaTable.FindClose;
begin
  if (fPopSize > 0) then lua_pop(fContext.CurrentState, fPopSize);
  fPopSize:= 0;
end;

function TLuaTable.FindField(const AName: ansistring): boolean;
begin
  lua_pushstring(fContext.CurrentState, pAnsiChar(AName));
  lua_gettable(fContext.CurrentState, Index);
  fCurField:= Field.fExtractField(-1);
  fPopSize:= 1;
  result:= true;
end;

function TLuaTable.CallMethodSafe(const AName: ansistring; const AArgs: array of const; AResCount: integer; var error: ansistring; AResType: integer): boolean;
var len: cardinal;
begin
  if (AResCount < 0) then AResCount:= LUA_MULTRET;
  lua_pushstring(fContext.CurrentState, pAnsiChar(AName));
  lua_rawget(fContext.CurrentState, Index);
  lua_pushvalue(fContext.CurrentState, Index);
  fContext.PushArgs(AArgs);
  if (lua_pcall(fContext.CurrentState, length(aargs) + 1, AResCount, 0) = 0) then begin
    if (AResType <> LUA_TNONE) then begin
      result:= (lua_type(fContext.CurrentState, -1) = AResType);
      if not result and (AResCount > 0) then lua_pop(fContext.CurrentState, AResCount);
    end else result:= true;
  end else begin
    len:= 0;
    SetString(error, lua_tolstring(fContext.CurrentState, -1, len), len);
    lua_pop(fContext.CurrentState, 1);
    result:= false;
  end;
end;

{ TLuaContext }

constructor TLuaContext.create(ALuaState: TLuaState);
begin
  inherited create;
  fLuaState:= ALuaState;
  fField:= nil;
end;

destructor TLuaContext.destroy;
begin
  if assigned(fField) then freeandnil(fField);
  inherited destroy;
end;

function TLuaContext.fGetStackByIndex(AIndex: integer): TLuaField;
begin
  if not assigned(fField) then fField:= TLuaField.create(Self);
  result:= fField.fExtractField(AIndex);
end;

function TLuaContext.fGetGlobalByName(const AName: ansistring): TLuaField;
begin
  if not assigned(fField) then fField:= TLuaField.create(Self);
  lua_getglobal(fLuaState, pAnsiChar(AName));
  result:= fField.fExtractField(-1);  // may be problems with tables?
  lua_pop(fLuaState, 1);
end;

function TLuaContext.fGetSelf: TLuaContext;
begin result:= Self; end;

function TLuaContext.PushArgs(const aargs: array of const; avalueslist: boolean): integer;
var i : integer;
begin
  for i:= 0 to length(aargs) - 1 do begin
    with aargs[i] do begin
      case vType of
        vtInteger    : lua_pushinteger(fLuaState, vInteger);
        vtInt64      : lua_pushnumber(fLuaState, vInt64^);
        vtPChar      : lua_pushstring(fLuaState, pAnsiChar(vPChar));
        vtAnsiString : lua_pushstring(fLuaState, pAnsiChar(vAnsiString));
        vtExtended   : lua_pushnumber(fLuaState, vExtended^);
        vtBoolean    : lua_pushboolean(fLuaState, vBoolean);
        vtObject     : if assigned(vObject) then begin
                         if (vObject is tStringList) then PushTable(tStringList(vObject), avalueslist)
                                                     else lua_pushnil(fLuaState);
                       end else lua_pushnil(fLuaState);
        else           lua_pushnil(fLuaState);
      end;
    end;
  end;
  result:= length(aargs);
end;

function TLuaContext.PushTable(aKVTable: tStringList; avalueslist: boolean): integer;
var tmp : ansistring;
    p   : pAnsiChar;
    i   : integer;
begin
  result:= 0;
  if assigned(aKVTable) then with aKVTable do begin
    lua_createtable(fLuaState, Count, 0);
    for i := 0 to count - 1 do begin
      if avalueslist then begin
        tmp:= Names[i];
        lua_pushstring(fLuaState, pAnsiChar(tmp));
        tmp:= Values[tmp];
        if (length(tmp) > 0) and (tmp[1]='"') then begin
          p:= pAnsiChar(tmp);
          tmp:= AnsiExtractQuotedStr(p, '"');
        end;
        lua_pushstring(fLuaState, pAnsiChar(tmp));
      end else begin
        lua_pushinteger(fLuaState, i);
        lua_pushstring(fLuaState, pAnsiChar(strings[i]));
      end;
      lua_settable(fLuaState, -3);
    end;
    result:= 1;
  end;
end;

function TLuaContext.PushTable(const aargs: array of const): integer;
var i, count : integer;
begin
  count:= (length(aargs) div 2) * 2;                   // must be even, if not - last pair is not pushed!
  lua_createtable(fLuaState, count div 2, 0);
  for i:= 0 to count - 1 do begin
    with aargs[i] do
      case vType of
        vtInteger    : lua_pushinteger(fLuaState, vInteger);
        vtInt64      : lua_pushnumber(fLuaState, vInt64^);
        vtPChar      : lua_pushstring(fLuaState, pAnsiChar(vPChar));
        vtAnsiString : lua_pushstring(fLuaState, pAnsiChar(vAnsiString));
        vtExtended   : lua_pushnumber(fLuaState, vExtended^);
        vtBoolean    : lua_pushboolean(fLuaState, vBoolean);
        else           lua_pushnil(fLuaState);
      end;
    if (i mod 2 = 1) then lua_settable(fLuaState, -3); // set on every odd i
  end;
  result:= 1;
end;

function TLuaContext.Call(const AName: ansistring; const AArgs: array of const; AResCount: integer; AResType: integer): boolean;
begin
  if (AResCount < 0) then AResCount:= LUA_MULTRET;
  lua_getglobal(fLuaState, pAnsiChar(AName));                              // get function index
  PushArgs(aargs);                                                         // push parameters
  lua_call(fLuaState, length(aargs), AResCount);                           // call function
  if (AResType <> LUA_TNONE) then begin
    result:= (lua_type(fLuaState, -1) = AResType);
    if not result and (AResCount > 0) then lua_pop(fLuaState, AResCount);  // cleanup stack if unexpected type returned
  end else result:= true;
end;

function TLuaContext.CallSafe(const AName: ansistring; const AArgs: array of const; AResCount: integer; var error: ansistring; AResType: integer): boolean;
var len: cardinal;
begin
  if (AResCount < 0) then AResCount:= LUA_MULTRET;
  lua_getglobal(fLuaState, pAnsiChar(AName));                              // get function index
  PushArgs(aargs);                                                         // push parameters
  if (lua_pcall(fLuaState, length(aargs), AResCount, 0) = 0) then begin    // call function in "protected mode"
    if (AResType <> LUA_TNONE) then begin
      result:= (lua_type(fLuaState, -1) = AResType);
      if not result and (AResCount > 0) then lua_pop(fLuaState, AResCount);// cleanup stack if unexpected type returned
    end else result:= true;
  end else begin
    len:= 0;
    SetString(error, lua_tolstring(fLuaState, -1, len), len);
    lua_pop(fLuaState, 1);
    result:= false;
  end;
end;

function TLuaContext.ExecuteSafe(const AScript: ansistring; AResCount: integer; var error: ansistring): boolean;
var len: cardinal;
begin
  result:= (luaL_loadstring(fLuaState, pAnsiChar(AScript)) = 0);
  if result then begin
    result:= (lua_pcall(fLuaState, 0, AResCount, 0) = 0);
    if not result then begin
      len:= 0;
      SetString(error, lua_tolstring(fLuaState, -1, len), len);
      lua_pop(fLuaState, 1);
      result:= false;
    end;
  end else error:= 'Script loading failed';
end;

procedure TLuaContext.CleanUp(ACount: integer);
begin lua_pop(fLuaState, ACount); end;

procedure TLuaContext.SetGlobal(AIndex: integer; const AName: ansistring);
begin
  lua_pushvalue(fLuaState, AIndex);
  lua_setglobal(fLuaState, pAnsiChar(AName));
end;

procedure TLuaContext.ResetGlobal(const AName: ansistring);
begin
  lua_pushnil(fLuaState);
  lua_setglobal(fLuaState, pAnsiChar(AName));
end;

end.