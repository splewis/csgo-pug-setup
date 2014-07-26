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


        if (client == g_capt1)
            PluginMessage("\x03%N \x01vetoed \x07%s", client, map);
        else
            PluginMessage("\x06%N \x01vetoed \x07%s", client, map);

        SetArrayCell(g_MapVetoed, index, true);
        if (GetNumMapsLeft() == 1) {
            g_ChosenMap = GetFirstMapLeft();
            ChangeMap();
        } else {
            new other = OtherCaptain(client);
            GiveVetoMenu(other);
            for (new i = 1; i <= MaxClients; i++) {
                if (IsValidClient(i) && !IsFakeClient(i) && i != other) {
                    VetoStatusDisplay(i);
                }
            }
        }

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

static VetoStatusDisplay(client) {
    new Handle:menu = CreateMenu(VetoStatusHandler);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "Maps left");
    for (new i = 0; i < GetArraySize(g_MapNames); i++) {
        if (!GetArrayCell(g_MapVetoed, i)) {
            decl String:map[PLATFORM_MAX_PATH];
            GetArrayString(g_MapNames, i, map, sizeof(map));
            AddMenuInt(menu, i, map);
        }
    }
    DisplayMenu(menu, client, 30);

}

public VetoStatusHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        PluginMessageToClient(client, "You aren't a captain, your menu is just for display/information purposes!");
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}
