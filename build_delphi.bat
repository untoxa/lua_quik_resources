@echo off
@echo Delphi compiling disabled
@goto :eof

IF NOT DEFINED PROJECT_ROOT (set PROJECT_ROOT=%~dp0.\)

@del /Q /F %PROJECT_ROOT%\units\*.* >nul
@mkdir %PROJECT_ROOT%\exe >nul
@mkdir %PROJECT_ROOT%\units >nul
@dcc32 lua_quik_resources.dpr
@del /Q /F %PROJECT_ROOT%\units\*.* >nul

@copy /b lua\test_quik_resources.lua %PROJECT_ROOT%\exe\test_quik_resources.lua