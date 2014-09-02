/**
 * Map vetoing functions
 */
public void CreateMapVeto() {
    GetMapList();
    GiveVetoMenu(g_capt1);
}

public void GiveVetoMenu(int client) {
    Handle menu = CreateMenu(VetoHandler);
    SetMenuExitButton(menu, false);
    SetMenuTitle(menu, "Select a map to veto");
    for (int i = 0; i < GetArraySize(g_MapNames); i++) {
        if (!GetArrayCell(g_MapVetoed, i)) {
            decl String:map[PLATFORM_MAX_PATH];
            GetArrayString(g_MapNames, i, map, sizeof(map));
            AddMenuInt(menu, i, map);
        }
    }
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

static int GetNumMapsLeft() {
    int count = 0;
    for (int i = 0; i < GetArraySize(g_MapNames); i++) {
        if (!GetArrayCell(g_MapVetoed, i))
            count++;
    }
    return count;
}

static int GetFirstMapLeft() {
    for (int i = 0; i < GetArraySize(g_MapNames); i++) {
        if (!GetArrayCell(g_MapVetoed, i))
            return i;
    }
    return -1;
}

public VetoHandler(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        new index = GetMenuInt(menu, param2);
        decl String:map[PLATFORM_MAX_PATH];
        GetArrayString(g_MapNames, index, map, PLATFORM_MAX_PATH);


        if (client == g_capt1)
            PugSetupMessageToAll("{PINK}%N {NORMAL}vetoed {LIGHT_RED}%s", client, map);
        else
            PugSetupMessageToAll("{LIGHT_GREEN}%N {NORMAL}vetoed {LIGHT_RED}%s", client, map);

        SetArrayCell(g_MapVetoed, index, true);
        if (GetNumMapsLeft() == 1) {
            g_ChosenMap = GetFirstMapLeft();
            ChangeMap();
        } else {
            int other = OtherCaptain(client);
            GiveVetoMenu(other);
            for (int i = 1; i <= MaxClients; i++) {
                if (IsValidClient(i) && !IsFakeClient(i) && i != other) {
                    VetoStatusDisplay(i);
                }
            }
        }

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

static VetoStatusDisplay(int client) {
    Handle menu = CreateMenu(VetoStatusHandler);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "Maps left");
    for (int i = 0; i < GetArraySize(g_MapNames); i++) {
        if (!GetArrayCell(g_MapVetoed, i)) {
            decl String:map[PLATFORM_MAX_PATH];
            GetArrayString(g_MapNames, i, map, sizeof(map));
            AddMenuInt(menu, i, map);
        }
    }
    DisplayMenu(menu, client, 30);

}

public VetoStatusHandler(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        PugSetupMessage(client, "You aren't a captain, your menu is just for display/information purposes!");
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}
