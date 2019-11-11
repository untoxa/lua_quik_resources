IF NOT DEFINED PROJECT_ROOT (set PROJECT_ROOT=%~dp0.\)

@del /Q /F %PROJECT_ROOT%\units\*.* >nul
@mkdir %PROJECT_ROOT%\exe >nul
@mkdir %PROJECT_ROOT%\exe\x86 >nul
@mkdir %PROJECT_ROOT%\units >nul
@ppc386.exe -B -Mdelphi -Ur -Xs -Fi%PROJECT_ROOT% -Fu%PROJECT_ROOT%\common\ -FE%PROJECT_ROOT%\exe\x86\ -FU%PROJECT_ROOT%\units\ lua_quik_resources.dpr
@del /Q /F %PROJECT_ROOT%\units\*.* >nul

@copy /b lua\test_quik_resources.lua %PROJECT_ROOT%\exe\x86\test_quik_resources.lua
