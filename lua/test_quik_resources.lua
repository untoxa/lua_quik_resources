package.cpath = getScriptPath() .. "/?.dll"
qres = require "lua_quik_resources"

quik_resources_lib = "lang_res.dll" -- "lang_rus.dll" for QUIK8!

qres.HWND_DESKTOP = 0
qres.WM_COMMAND = 273
qres.INFOMENU_CONNECT = 100
qres.INFOMENU_DISCONNECT = 101
qres.IDOK = 1
qres.MF_ENABLED = 0

QUIK_Handle = qres.get_quik_handle()
QUIK_conn_dlg_title = qres.get_dlg_title(10107); if QUIK_conn_dlg_title == nil then QUIK_conn_dlg_title = ""; end

function manage_quik_connection(connect, quik_login, quik_password)  
    if connect then 
        if (qres.get_menu_state(QUIK_Handle, qres.INFOMENU_CONNECT) == qres.MF_ENABLED) then
            qres.post_message(QUIK_Handle, qres.WM_COMMAND, qres.INFOMENU_CONNECT, 0)
            sleep(100)
            local hConnDlg = qres.get_child_handle(qres.HWND_DESKTOP, QUIK_conn_dlg_title)
            if (hConnDlg ~= 0) then
                qres.set_dlg_item_text(hConnDlg, 10101, quik_login)
                qres.set_dlg_item_text(hConnDlg, 10102, quik_password)
                qres.post_message(hConnDlg, qres.WM_COMMAND, qres.IDOK, 0)
                return "Login sent"
            end
        else
            return "Already connected or connecting"
        end
    else
        qres.post_message(QUIK_Handle, qres.WM_COMMAND, qres.INFOMENU_DISCONNECT, 0)
        return "Logout sent"
    end
    return "Internal error"
end
 
function main()
    if (QUIK_Handle ~= 0) then
       local result = manage_quik_connection(true, "login", "password")
       if result ~= nil then message(result, 1); end
    else
      message("Unable to find QUIK main window handle", 1)
    end
end