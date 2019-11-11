package.cpath = getScriptPath() .. "\\lua_quik_resources.dll"
qres = require "quik_resources"

function main()  
  quik_resources_lib = "lang_rus.dll"

  hQUIK = qres.get_quik_handle()
  if (hQUIK ~= 0) then
    message("QUIK main window handle: " .. tostring(hQUIK))

    conn_dlg_title = tostring(qres.get_dlg_title(10107))
    message("Connect dialog caption: " .. conn_dlg_title, 1)

    HWND_DESKTOP = 0
    WM_COMMAND = 273
    INFOMENU_CONNECT = 100
    INFOMENU_DISCONNECT = 101
    IDOK = 1
    MF_ENABLED = 0

    connect_menu_state = qres.get_menu_state(hQUIK, INFOMENU_CONNECT)
    message("Connect menu item state: " .. tostring(connect_menu_state))

    if (connect_menu_state == MF_ENABLED) then
      qres.post_message(hQUIK, WM_COMMAND, INFOMENU_CONNECT, 0)
      sleep(100)

      hConnDlg = qres.get_child_handle(HWND_DESKTOP, conn_dlg_title)
      if (hConnDlg ~= 0) then
        message("Connection dialog handle: " .. tostring(hConnDlg))

        qres.set_dlg_item_text(hConnDlg, 10101, "quik_login")
        qres.set_dlg_item_text(hConnDlg, 10102, "quik_password")
        qres.post_message(hConnDlg, WM_COMMAND, IDOK, 0)
      else
        message("Unable to get connection dialog handle", 2)
      end
    else
      message("Connect menu item is grayed or disabled", 2)
    end
  else
    message("Unable to get QUIK main window handle", 2)
  end
end
