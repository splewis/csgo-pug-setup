
/**
 * Map vetoing functions
 */
public void CreateMapVeto() {
    if (GetConVarInt(g_hRandomizeMapOrder) != 0)
        RandomizeArray(GetCurrentMapList());

    GiveVetoMenu(g_capt1);
}

public void GiveVetoMenu(int client) {
    Handle mapList = GetCurrentMapList();

    Handle menu = CreateMenu(VetoHandler);
    SetMenuExitButton(menu, false);
    SetMenuTitle(menu, "%t", "VetoMenuTitle");
    for (int i = 0; i < GetArraySize(mapList); i++) {
        if (!GetArrayCell(g_MapVetoed, i)) {
            char map[PLATFORM_MAX_PATH];
            GetArrayString(mapList, i, map, sizeof(map));
            AddMenuInt(menu, i, map);
        }
    }
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

static int GetNumMapsLeft() {
    Handle mapList = GetCurrentMapList();

    int count = 0;
    for (int i = 0; i < GetArraySize(mapList); i++) {
        if (!GetArrayCell(g_MapVetoed, i))
            count++;
    }
    return count;
}

static int GetFirstMapLeft() {
    Handle mapList = GetCurrentMapList();

    for (int i = 0; i < GetArraySize(mapList); i++) {
        if (!GetArrayCell(g_MapVetoed, i))
            return i;
    }
    return -1;
}

public VetoHandler(Handle menu, MenuAction action, param1, param2) {
    Handle mapList = GetCurrentMapList();

    if (action == MenuAction_Select) {
        int client = param1;
        new index = GetMenuInt(menu, param2);
        char map[PLATFORM_MAX_PATH];
        GetArrayString(mapList, index, map, sizeof(map));

        char captString[64];
        FormatPlayerName(client, client, captString);
        PugSetupMessageToAll("%t", "PlayerVetoed", captString, map);

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
    Handle mapList = GetCurrentMapList();

    Handle menu = CreateMenu(VetoStatusHandler);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "%t", "MapsLeft");
    for (int i = 0; i < GetArraySize(mapList); i++) {
        if (!GetArrayCell(g_MapVetoed, i)) {
            char map[PLATFORM_MAX_PATH];
            GetArrayString(mapList, i, map, sizeof(map));
            AddMenuItem(menu, "", map, ITEMDRAW_DISABLED);
        }
    }
    DisplayMenu(menu, client, 30);
}

public VetoStatusHandler(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}
