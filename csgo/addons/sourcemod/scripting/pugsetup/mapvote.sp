/**
 * Map voting functions
 */
public CreateMapVote() {
    GetMapList();
    ShowMapVote();
}

static ShowMapVote() {
    g_VotesCasted = 0;
    for (new client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client) && !IsFakeClient(client)) {
            new Handle:menu = CreateMenu(MapVoteHandler);
            SetMenuTitle(menu, "Vote for a map");
            SetMenuExitButton(menu, false);

            for (new i = 0; i < GetArraySize(g_MapNames); i++) {
                new String:mapName[PLATFORM_MAX_PATH];
                GetArrayString(g_MapNames, i, mapName, sizeof(mapName));
                AddMenuInt(menu, i, mapName);
            }

            DisplayMenu(menu, client, RoundToNearest(GetConVarFloat(g_hMapVoteTime)));
        }
    }
    CreateTimer(GetConVarFloat(g_hMapVoteTime), MapVoteFinished);
}

public MapVoteHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        new index = GetMenuInt(menu, param2);
        decl String:mapName[PLATFORM_MAX_PATH];
        GetArrayString(g_MapNames, index, mapName, sizeof(mapName));
        new count = GetArrayCell(g_MapVotes, index);
        count++;
        g_VotesCasted++;
        PrintToChatAll(" \x01\x0B\x04%N \x01voted for \x03%s \x01(%d/%d)", client, mapName, count, g_VotesCasted);
        SetArrayCell(g_MapVotes, index, count);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public Action:MapVoteFinished(Handle:timer) {
    new bestIndex = -1;
    new bestVotes = 0;
    for (new i = 0; i < GetArraySize(g_MapVotes); i++) {
        new votes = GetArrayCell(g_MapVotes, i);
        if (bestIndex == -1 || votes > bestVotes) {
            bestIndex = i;
            bestVotes = votes;
        }
    }
    g_ChosenMap = bestIndex;
    ChangeMap();
    return Plugin_Handled;
}
