// Counter for tracking whose turn it is to pick based on the # of players picked.
// Tracking the "number of picks left" for the current captain.
int g_PickCounter = 0;

public void InitialChoiceMenu(int client) {
    g_PickingPlayers = true;
    Handle menu = CreateMenu(InitialChoiceHandler);
    SetMenuTitle(menu, "%t", "InitialPickTitle");
    SetMenuExitButton(menu, false);
    AddMenuInt(menu, _:InitialPick_Side, "%t", "InitialPickSides");
    AddMenuInt(menu, _:InitialPick_Player, "%t", "InitialPickPlayer");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public InitialChoiceHandler(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        if (client != g_capt1)
            LogError("[InitialChoiceHandler] only the first captain should have gotten the intial menu!");

        InitialPick choice = InitialPick:GetMenuInt(menu, param2);
        char captString[64];
        FormatPlayerName(g_capt1, g_capt1, captString);

        if (choice == InitialPick_Player) {
            PugSetupMessageToAll("%t", "InitialPickPlayerChoice", captString);
            SideMenu(g_capt2);
        } else if (choice == InitialPick_Side) {
            PugSetupMessageToAll("%t", "InitialPickSideChoice", captString);
            SideMenu(g_capt1);
        } else {
            LogError("[InitialChoiceHandler] unknown intial choice=%d", choice);
        }
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public void SideMenu(int client) {
    Handle menu = CreateMenu(SideMenuHandler);
    SetMenuTitle(menu, "%t", "SideChoiceTitle");
    SetMenuExitButton(menu, false);
    AddMenuInt(menu, CS_TEAM_CT, "CT");
    AddMenuInt(menu, CS_TEAM_T, "T");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public SideMenuHandler(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int teamPick = GetMenuInt(menu, param2);

        char captString[64];
        FormatPlayerName(client, client, captString);

        char teamString[8];
        if (teamPick == CS_TEAM_CT)
            Format(teamString, sizeof(teamString), "CT");
        else
            Format(teamString, sizeof(teamString), "T");

        PugSetupMessageToAll("%t", "SideChoiceSelected", captString, teamString);

        int otherTeam = (teamPick == CS_TEAM_CT) ? CS_TEAM_T : CS_TEAM_CT;

        g_Teams[client] = teamPick;
        SwitchPlayerTeam(client, teamPick);

        int otherCaptain = OtherCaptain(client);
        g_Teams[otherCaptain] = otherTeam;
        SwitchPlayerTeam(otherCaptain, otherTeam);
        g_PickCounter = 0;

        ServerCommand("mp_restartgame 1");
        CreateTimer(1.0, GivePlayerSelectionMenu, GetClientSerial(otherCaptain));
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Player selection menus.
 */
public Action GivePlayerSelectionMenu(Handle timer, int serial) {
    int client = GetClientFromSerial(serial);
    if (IsPickingFinished()) {
        CreateTimer(1.0, FinishPicking);
    } else {
        if (IsValidClient(client)) {
            Handle menu = CreateMenu(PlayerMenuHandler);
            SetMenuTitle(menu, "%t", "PlayerPickTitle");
            SetMenuExitButton(menu, false);
            if (AddPlayersToMenu(menu) > 0) {
                DisplayMenu(menu, client, MENU_TIME_FOREVER);
            } else {
                CloseHandle(menu);
                PugSetupMessageToAll("Not enough players for picking, aborting the game.");
                EndMatch(false);
            }
        } else {
            PugSetupMessageToAll("A captain is missing, aborting the game.");
            EndMatch(false);
        }
    }
}

public PlayerMenuHandler(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int selected = GetMenuInt(menu, param2);

        if (selected > 0) {
            g_Teams[selected] = g_Teams[client];
            SwitchPlayerTeam(selected, g_Teams[client]);

            char captName[64];
            char selectedName[64];
            FormatPlayerName(client, client, captName);
            FormatPlayerName(client, selected, selectedName);
            PugSetupMessageToAll("%t", "PlayerPickChoice", captName, selectedName);

            if (!IsPickingFinished()) {
                MoreMenuPicks(GetNextCaptain(client));
            } else {
                CreateTimer(1.0, FinishPicking);
            }
        } else {
            MoreMenuPicks(client);
        }

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

static void MoreMenuPicks(client) {
    if (IsPickingFinished() || !IsValidClient(client) || !IsClientInGame(client)) {
        CreateTimer(5.0, FinishPicking);
        return;
    }
    CreateTimer(1.0, GivePlayerSelectionMenu, GetClientSerial(client));
}

/**
 * Helper functions for the player menus.
 */
static bool IsPickingFinished() {
    int numSelected = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayerPicked(i))
            numSelected++;
    }

    return numSelected >= 2 * g_PlayersPerTeam;
}

static bool IsPlayerPicked(int client) {
    int team = g_Teams[client];
    return team == CS_TEAM_T || team == CS_TEAM_CT;
}

static int GetNextCaptain(int captain) {
    if (GetConVarInt(g_hSnakeCaptains) == 0) {
        return OtherCaptain(captain);
    } else {
        if (g_PickCounter == 0) {
            g_PickCounter = 1;
            return OtherCaptain(captain);
        } else {
            g_PickCounter--;
            return captain;
        }
    }
}

public int OtherCaptain(int captain) {
    if (captain == g_capt1)
        return g_capt2;
    else
        return g_capt1;
}

static int AddPlayersToMenu(Handle menu) {
    char name[MAX_NAME_LENGTH];
    int count = 0;
    for (int client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client) && !IsFakeClient(client) && g_Teams[client] == CS_TEAM_SPECTATOR && g_Ready[client]) {
            GetClientName(client, name, sizeof(name));
            AddMenuInt(menu, client, name);
            count++;
        }
    }
    return count;
}

public FormatPlayerName(int capt, int client, char buffer[64]) {
    if (capt == g_capt1) {
        Format(buffer, sizeof(buffer), "{PINK}%N{NORMAL}", client);
    } else {
        Format(buffer, sizeof(buffer), "{LIGHT_GREEN}%N{NORMAL}", client);
    }
}
