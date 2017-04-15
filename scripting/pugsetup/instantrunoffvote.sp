bool g_IRVActive = false;
const int kNumMapsToPick = 3;
ArrayList g_MapAliveInVote;

// Contains the votes (by map index) for each client, in the order selected.
int g_ClientMapPicks[MAXPLAYERS + 1][kNumMapsToPick];
int g_ClientMapPosition[MAXPLAYERS + 1];

// Histogram of votes where map index -> current votes for that map.
// ArrayList g_CurrentVoteTallies;

public void StartInstantRunoffMapVote() {
  for (int i = 1; i <= MaxClients; i++) {
    g_ClientMapPosition[i] = -1;
    if (IsPlayer(i)) {
      for (int j = 0; j < kNumMapsToPick; j++) {
        g_ClientMapPicks[i][j] = -1;
      }
      g_ClientMapPosition[i] = 0;
      ShowInstantRunoffMapVote(i, 0);
    }
  }

  g_IRVActive = true;
  CreateTimer(g_MapVoteTimeCvar.FloatValue, Timer_CollectIRVResults);
}

static bool HasClientPickedMap(int client, int mapIndex) {
  for (int i = 0; i < kNumMapsToPick; i++) {
    if (g_ClientMapPicks[client][i] == mapIndex) {
      return true;
    }
  }
  return false;
}

public void ShowInstantRunoffMapVote(int client, int round) {
  ArrayList mapList = GetCurrentMapList();

  Menu menu = new Menu(MapSelectionHandler);
  SetMenuTitle(menu, "Select your #%d choice", round + 1);
  SetMenuExitButton(menu, false);

  for (int i = 0; i < mapList.Length; i++) {
    if (!HasClientPickedMap(client, i)) {
      AddMapIndexToMenu(menu, mapList, i);
    }
  }

  menu.Display(client, g_MapVoteTimeCvar.IntValue);
}

public int MapSelectionHandler(Menu menu, MenuAction action, int param1, int param2) {
  ArrayList mapList = GetCurrentMapList();

  if (action == MenuAction_Select) {
    if (!g_IRVActive) {
      return 0;
    }

    int client = param1;
    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));

    int mapIndex = GetMenuInt(menu, param2);
    char mapName[255];
    FormatMapName(mapList, mapIndex, mapName, sizeof(mapName));
    PugSetup_Message(client, "You picked {GREEN}%s {NORMAL}as your {GREEN}#%d {NORMAL}choice.",
                     mapName, g_ClientMapPosition[client] + 1);

    g_ClientMapPicks[client][g_ClientMapPosition[client]] = mapIndex;
    g_ClientMapPosition[client]++;

    if (g_ClientMapPosition[client] < kNumMapsToPick) {
      ShowInstantRunoffMapVote(client, g_ClientMapPosition[client]);
    }

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

static int FindLeastVotedMap() {
  ArrayList voteCounts = new ArrayList();
  for (int i = 0; i < g_MapList.Length; i++) {
    voteCounts.Push(0);
  }

  for (int i = 1; i <= MaxClients; i++) {
    int pos = g_ClientMapPosition[i];
    if (pos >= 0 && pos < kNumMapsToPick) {
      int mapIndex = g_ClientMapPicks[i][pos];
      if (mapIndex >= 0) {
        voteCounts.Set(mapIndex, voteCounts.Get(mapIndex) + 1);

        char mapName[64];
        g_MapList.GetString(mapIndex, mapName, sizeof(mapName));
        LogDebug("%L has active vote for %d (%s) -> %d votes now", i, mapIndex, mapName,
                 voteCounts.Get(mapIndex));
      }
    }
  }

  // TODO: break ties randomly instead of always picking the earlier entry as the loser.
  int loserIndex = 0;
  int loserVotes = -1;
  for (int i = 0; i < voteCounts.Length; i++) {
    if (!g_MapAliveInVote.Get(i)) {
      continue;
    }

    if (voteCounts.Get(i) < loserVotes || loserVotes == -1) {
      loserVotes = voteCounts.Get(i);
      loserIndex = i;
    }
  }

  delete voteCounts;
  return loserIndex;
}

static int CountMapsAlive(int& winner) {
  int count = 0;
  for (int i = 0; i < g_MapAliveInVote.Length; i++) {
    if (g_MapAliveInVote.Get(i)) {
      count++;
      winner = i;
    }
  }
  return count;
}

public Action Timer_CollectIRVResults(Handle timer) {
  g_IRVActive = false;

  if (g_MapAliveInVote == null) {
    g_MapAliveInVote = new ArrayList();
  } else {
    g_MapAliveInVote.Clear();
  }
  for (int i = 0; i < g_MapList.Length; i++) {
    g_MapAliveInVote.Push(true);
  }

  for (int i = 1; i <= MaxClients; i++) {
    // Reset client ballots to slot 0 (first choice).
    if (g_ClientMapPosition[i] > 0) {
      g_ClientMapPosition[i] = 0;
      for (int j = 0; j < kNumMapsToPick; j++) {
        if (g_ClientMapPicks[i][j] >= 0) {
          char mapName[64];
          g_MapList.GetString(g_ClientMapPicks[i][j], mapName, sizeof(mapName));
          LogDebug("Client %L choice %d = %d (%s)", i, j, g_ClientMapPicks[j], mapName);
        }
      }
    }
  }

  int mapLoser = -1;
  int winner = 0;
  while (CountMapsAlive(winner) > 1) {  // Should be while(true), but don't want the warning :)
    mapLoser = FindLeastVotedMap();
    char loserName[64];
    g_MapList.GetString(mapLoser, loserName, sizeof(loserName));
    LogDebug("Map %d (%s) is the least voted map, eliminating", mapLoser, loserName);

    g_MapAliveInVote.Set(mapLoser, false);
    for (int i = 1; i <= MaxClients; i++) {
      int pos = g_ClientMapPosition[i];
      if (pos >= 0 && pos < kNumMapsToPick) {
        if (g_ClientMapPicks[i][pos] == mapLoser) {
          g_ClientMapPosition[i]++;
        }
      }
    }
  }

  char mapName[64];
  FormatMapName(g_MapList, winner, mapName, sizeof(mapName));
  PugSetup_MessageToAll("Vote over... {GREEN}%s {NORMAL}won!", mapName);
}
