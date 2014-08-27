public void InitialChoiceMenu(int client) {
    g_PickingPlayers = true;
    Handle menu = CreateMenu(InitialChoiceHandler);
    SetMenuTitle(menu, "Which would you prefer:");
    SetMenuExitButton(menu, false);
    AddMenuInt(menu, _:InitialPick_Side, "Pick the starting team");
    AddMenuInt(menu, _:InitialPick_Player, "Pick the first player");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public InitialChoiceHandler(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;  // should also equal g_capt1
        if (client != g_capt1)
            LogError("[InitialChoiceHandler] only the first captain should have gotten the intial menu!");

        InitialPick choice = InitialPick:GetMenuInt(menu, param2);
        if (choice == InitialPick_Player) {
            PugSetupMessageToAll("{PINK}%N {NORMAL}has elected to get the {GREEN}first player pick.", g_capt1);
            SideMenu(g_capt2);
        } else if (choice == InitialPick_Side) {
            PugSetupMessageToAll("{PINK}%N {NORMAL}has elected to pick the {GREEN}starting side.", g_capt1);
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
    SetMenuTitle(menu, "Which side do you want first");
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
        if (client == g_capt1) {
            Format(captString, sizeof(captString), "{PINK}%N{NORMAL}", g_capt1);
        } else {
            Format(captString, sizeof(captString), "{LIGHT_GREEN}%N{NORMAL}", g_capt2);
        }

        if (teamPick == CS_TEAM_CT) {
            PugSetupMessageToAll("%s has picked {GREEN}CT {NORMAL}first.", captString);
        } else if (teamPick == CS_TEAM_T) {
            PugSetupMessageToAll("%s has picked {GREEN}T {NORMAL}first.", captString);
        } else {
            LogError("[SideMenuHandler] Unknown side pick: %d", teamPick);
        }

        int otherTeam = (teamPick == CS_TEAM_CT) ? CS_TEAM_T : CS_TEAM_CT;

        g_Teams[client] = teamPick;
        SwitchPlayerTeam(client, teamPick);

        int otherCaptain = OtherCaptain(client);
        g_Teams[otherCaptain] = otherTeam;
        SwitchPlayerTeam(otherCaptain, otherTeam);

        ServerCommand("mp_restartgame 1");
        CreateTimer(1.0, GivePlayerSelectionMenu, _, otherCaptain);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Player selection menus.
 */
public Action GivePlayerSelectionMenu(Handle timer, int client) {
    if (IsPickingFinished()) {
        CreateTimer(1.0, FinishPicking);
    } else {
        if (IsValidClient(client)) {
            Handle menu = CreateMenu(PlayerMenuHandler);
            SetMenuTitle(menu, "Pick your players");
            SetMenuExitButton(menu, false);
            AddPlayersToMenu(menu);
            DisplayMenu(menu, client, MENU_TIME_FOREVER);
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
            if (client == g_capt1)
                PugSetupMessageToAll("{PINK}%N {NORMAL}has picked {PINK}%N", client, selected);
            else
                PugSetupMessageToAll("{LIGHT_GREEN}%N {NORMAL}has picked {LIGHT_GREEN}%N", client, selected);

            if (!IsPickingFinished()) {
                int nextCapt = OtherCaptain(client);
                MoreMenuPicks(nextCapt);
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

public void MoreMenuPicks(client) {
    if (IsPickingFinished() || !IsValidClient(client) || !IsClientInGame(client)) {
        CreateTimer(5.0, FinishPicking);
        return;
    }
    CreateTimer(1.0, GivePlayerSelectionMenu, client);
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

static bool IsPlayerPicked(client) {
    int team = g_Teams[client];
    return team == CS_TEAM_T || team == CS_TEAM_CT;
}

public int OtherCaptain(captain) {
    if (captain == g_capt1)
        return g_capt2;
    else
        return g_capt1;
}

static int AddPlayersToMenu(Handle menu) {
    char name[MAX_NAME_LENGTH];
    int count = 0;
    for (int client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client) && !IsFakeClient(client) && g_Teams[client] == CS_TEAM_SPECTATOR) {
            GetClientName(client, name, sizeof(name));
            AddMenuInt(menu, client, name);
            count++;
        }
    }
    return count;
}
