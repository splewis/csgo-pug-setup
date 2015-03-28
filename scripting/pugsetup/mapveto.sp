/**
 * Map vetoing functions
 */
public void CreateMapVeto() {
    ArrayList mapList = GetCurrentMapList();

    if (GetConVarInt(g_hRandomizeMapOrder) != 0)
        RandomizeArray(mapList);

    ClearArray(g_MapVetoed);
    for (int i = 0; i < mapList.Length; i++)
        g_MapVetoed.Push(false);

    GiveVetoMenu(g_capt1);
}

public void GiveVetoMenu(int client) {
    ArrayList mapList = GetCurrentMapList();

    Menu menu = new Menu(VetoHandler);
    menu.ExitButton = false;
    menu.SetTitle("%T", "VetoMenuTitle", client);

    for (int i = 0; i < mapList.Length; i++) {
        if (!g_MapVetoed.Get(i)) {
            AddMapIndexToMenu(menu, mapList, i);
        }
    }
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

static int GetNumMapsLeft() {
    ArrayList mapList = GetCurrentMapList();

    int count = 0;
    for (int i = 0; i < mapList.Length; i++) {
        if (!g_MapVetoed.Get(i))
            count++;
    }
    return count;
}

static int GetFirstMapLeft() {
    ArrayList mapList = GetCurrentMapList();

    for (int i = 0; i < mapList.Length; i++) {
        if (!g_MapVetoed.Get(i))
            return i;
    }
    return -1;
}

public int VetoHandler(Menu menu, MenuAction action, int param1, int param2) {
    ArrayList mapList = GetCurrentMapList();

    if (action == MenuAction_Select) {
        int client = param1;
        int index = GetMenuInt(menu, param2);
        char map[PLATFORM_MAX_PATH];
        mapList.GetString(index, map, sizeof(map));

        char captString[64];
        FormatPlayerName(client, client, captString);
        PugSetupMessageToAll("%t", "PlayerVetoed", captString, map);

        g_MapVetoed.Set(index, true);
        if (GetNumMapsLeft() == 1) {
            ChangeMap(g_MapList, GetFirstMapLeft());
        } else {
            int other = OtherCaptain(client);
            GiveVetoMenu(other);
            for (int i = 1; i <= MaxClients; i++) {
                if (IsPlayer(i) && i != other) {
                    VetoStatusDisplay(i);
                }
            }
        }

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

static void VetoStatusDisplay(int client) {
    ArrayList mapList = GetCurrentMapList();

    Menu menu = new Menu(VetoStatusHandler);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "%T", "MapsLeft", client);
    for (int i = 0; i < mapList.Length; i++) {
        if (!g_MapVetoed.Get(i)) {
            char map[PLATFORM_MAX_PATH];
            mapList.GetString(i, map, sizeof(map));
            AddMenuItem(menu, "", map, ITEMDRAW_DISABLED);
        }
    }
    DisplayMenu(menu, client, 30);
}

public int VetoStatusHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}
