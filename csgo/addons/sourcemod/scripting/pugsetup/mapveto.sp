/**
 * Map vetoing functions
 */
public CreateMapVeto() {
    GetMapList();
    GiveVetoMenu(g_capt1);
}

public GiveVetoMenu(client) {
    new Handle:menu = CreateMenu(VetoHandler);
    SetMenuExitButton(menu, false);
    SetMenuTitle(menu, "Select a map to veto");
    for (new i = 0; i < GetArraySize(g_MapNames); i++) {
        if (!GetArrayCell(g_MapVetoed, i)) {
            decl String:map[PLATFORM_MAX_PATH];
            GetArrayString(g_MapNames, i, map, sizeof(map));
            AddMenuInt(menu, i, map);
        }
    }
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

static GetNumMapsLeft() {
    new count = 0;
    for (new i = 0; i < GetArraySize(g_MapNames); i++) {
        if (!GetArrayCell(g_MapVetoed, i))
            count++;
    }
    return count;
}

static GetFirstMapLeft() {
    for (new i = 0; i < GetArraySize(g_MapNames); i++) {
        if (!GetArrayCell(g_MapVetoed, i))
            return i;
    }
    return -1;
}

public VetoHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new any:client = param1;
        new index = GetMenuInt(menu, param2);
        decl String:map[PLATFORM_MAX_PATH];
        GetArrayString(g_MapNames, index, map, PLATFORM_MAX_PATH);
        PrintToChatAll(" \x04%N \x01vetoed \x07%s", client, map);
        SetArrayCell(g_MapVetoed, index, true);

        if (GetNumMapsLeft() == 1) {
            g_ChosenMap = GetFirstMapLeft();
            ChangeMap();
        } else {
            GiveVetoMenu(OtherCaptain(client));
        }

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}
