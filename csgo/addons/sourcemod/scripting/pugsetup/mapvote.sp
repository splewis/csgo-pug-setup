/**
 * Map voting functions
 */
public CreateMapVote() {
    GetMapList();
    ShowMapVote();
}

static ShowMapVote() {
    new Handle:menu = CreateMenu(MapVoteHandler);
    SetMenuTitle(menu, "Vote for a map");
    SetMenuExitButton(menu, false);

    for (new i = 0; i < GetArraySize(g_MapNames); i++) {
        new String:mapName[PLATFORM_MAX_PATH];
        GetArrayString(g_MapNames, i, mapName, sizeof(mapName));
        AddMenuInt(menu, i, mapName);
    }

    VoteMenuToAll(menu, GetConVarInt(g_hMapVoteTime));
}

public MapVoteHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_VoteEnd) {
        g_ChosenMap = GetMenuInt(menu, param1);
        ChangeMap();
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}
