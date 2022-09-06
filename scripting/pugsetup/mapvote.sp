#define RANDOM_MAP_VOTE "-1"  // must be in invalid index for array indexing

char mapGroups[][] = {
      "competitive.txt", "fun.txt", "maps.txt"
};

/**
 * Map voting functions
 */
public void CreateMapVote() {
          StartMappoolVote();
}
static void StartMappoolVote() {
  Menu menu = new Menu(MappoolVoteHandler);
  menu.SetTitle("%T", "VoteMenuTitle", LANG_SERVER);
  menu.ExitButton = false;
  for (int i = 0; i < sizeof(mapGroups); i++) {
        char text[64], id[4];
        Format(text, 64, mapGroups[i]);
        Format(id, 4, "%i", i);
        ReplaceString(text, 64, ".txt", "", false);
        AddMenuItem(menu, id, text);
  }
  VoteMenuToAll(menu, g_MapVoteTimeCvar.IntValue);
}
public int MappoolVoteHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_VoteEnd) {
        int winner = GetMenuInt(menu, param1);
    
        ServerCommand("sm_pugsetup_maplist %s", mapGroups[winner]);
        
        char text[PLATFORM_MAX_PATH];
        Format(text, 64, mapGroups[winner]);
        ReplaceString(text, 64, ".txt", "", false);
        
        PrintCenterTextAll("%t","MapVoteWinnerHintText", text);
        
        CreateTimer(0.5, Timer_Continue, _, TIMER_FLAG_NO_MAPCHANGE);
      
  } else if (action == MenuAction_End) {
    CloseHandle(menu);
  }
  return 0;
}
public Action Timer_Continue(Handle timer)
{
        CreateMappoolVote();
}
public void CreateMappoolVote() {
  if (g_ExcludedMaps.IntValue > 0 && g_MapList.Length > g_PastMaps.Length) {
    SetupMapVotePool(true);
  } else {
    SetupMapVotePool(false);
  }

  if (g_RandomizeMapOrderCvar.BoolValue) {
    RandomizeArray(g_MapVotePool);
  }

  if (!g_InstantRunoffVotingCvar.BoolValue || g_MapList.Length < kIRVNumMapsToPick) {
    StartMapVote();
  } else {
    StartInstantRunoffMapVote();
  }
}

static void StartMapVote() {
  FillMapList(g_MapListCvar, g_MapVotePool);
  Menu menu = new Menu(MapVoteHandler);
  menu.SetTitle("%T", "VoteMenuTitle", LANG_SERVER);
  menu.ExitButton = false;

  if (g_RandomOptionInMapVoteCvar.BoolValue) {
    char buffer[255];
    Format(buffer, sizeof(buffer), "%T", "Random", LANG_SERVER);
    AddMenuItem(menu, RANDOM_MAP_VOTE, buffer);
  }

  // Don't paginate the menu if we have 7 maps or less, as they will fit
  // on one page when we don't add the pagination options
  if (g_MapVotePool.Length <= 7) {
    menu.Pagination = MENU_NO_PAGINATION;
  }

  for (int i = 0; i < g_MapVotePool.Length; i++) {
    char mapName[64];
    g_MapVotePool.GetString(i, mapName, sizeof(mapName));
    AddMapIndexToMenu(menu, g_MapVotePool, i);
  }

  VoteMenuToAll(menu, g_MapVoteTimeCvar.IntValue);
}

public int MapVoteHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select && GetCvarIntSafe("sm_vote_progress_chat") == 0 &&
      g_DisplayMapVotesCvar.BoolValue) {
    // Only prints votes to chat if sourcemod isn't automatically printing votes in chat
    int client = param1;
    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));

    int mapIndex = GetMenuInt(menu, param2);
    char mapName[255];

    if (mapIndex >= 0) {
      FormatMapName(g_MapVotePool, mapIndex, mapName, sizeof(mapName));
    } else {
      Format(mapName, sizeof(mapName), "%T", "RandomMapVote", LANG_SERVER);
    }

    PugSetup_MessageToAll("%t", "Voted For", clientName, mapName);

  } else if (action == MenuAction_Display) {
    char buffer[255];
    Format(buffer, sizeof(buffer), "%T", "VoteMenuTitle", param1);
    SetPanelTitle(view_as<Handle>(param2), buffer);

  } else if (action == MenuAction_DisplayItem) {
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    char display[64];
    if (StrEqual(info, RANDOM_MAP_VOTE)) {
      Format(display, sizeof(display), "%T", "Random", param1);
      return RedrawMenuItem(display);
    }

  } else if (action == MenuAction_VoteEnd) {
    int winner = GetMenuInt(menu, param1);
    if (winner == StringToInt(RANDOM_MAP_VOTE)) {
      ChangeMap(g_MapVotePool, GetArrayRandomIndex(g_MapVotePool));
    } else {
      ChangeMap(g_MapVotePool, GetMenuInt(menu, param1));
    }

  } else if (action == MenuAction_End) {
    CloseHandle(menu);
  }

  return 0;
}
