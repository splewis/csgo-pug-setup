/**
 * Initial menu data (where captain 1 picks between side pick or 1st player pick.)
 */
enum InitialPick {
    InitialPick_Side,
    InitialPick_Player
};

public InitialChoiceMenu(client) {
    new Handle:menu = CreateMenu(InitialChoiceHandler);
    SetMenuTitle(menu, "Which would you prefer:");
    SetMenuExitButton(menu, false);
    AddMenuInt(menu, InitialPick_Side, "Pick the starting team");
    AddMenuInt(menu, InitialPick_Player, "Pick the first player");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public InitialChoiceHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;  // should also equal g_capt1
        if (client != g_capt1)
            ERROR_FUNC("only the first captain should have gotten the intial menu!");

        new InitialPick:choice = InitialPick:GetMenuInt(menu, param2);
        if (choice == InitialPick_Player) {
            PrintToChatAll(" \x01\x0B\x07%N \x01has elected to get the \x03first player pick.", g_capt1);
            SideMenu(g_capt2);
        } else if (choice == InitialPick_Side) {
            PrintToChatAll(" \x01\x0B\x07%N \x01has elected to pick the \x03starting teams.", g_capt1);
            SideMenu(g_capt1);
        } else {
            ERROR_FUNC("unknown intial choice: %d", choice);
        }
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}



/**
 * Side selection. A captain chooses between CT or T side first.
 */
enum SideChoice {
    SideChoice_CT,
    SideChoice_T
}

public SideMenu(client) {
    new Handle:menu = CreateMenu(SideMenuHandler);
    SetMenuTitle(menu, "Which side do you want first");
    SetMenuExitButton(menu, false);
    AddMenuInt(menu, SideChoice_CT, "CT");
    AddMenuInt(menu, SideChoice_T, "T");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public SideMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        new SideChoice:choice = SideChoice:GetMenuInt(menu, param2);

        new teamPick = -1;
        if (choice == SideChoice_CT) {
            PrintToChatAll(" \x01\x0B\x07%N \x01has picked \x03CT \x01first.", g_capt2);
            teamPick = CS_TEAM_CT;
        } else if (choice == SideChoice_T) {
            PrintToChatAll(" \x01\x0B\x07%N \x01has picked \x02T \x01first.", g_capt2);
            teamPick = CS_TEAM_T;
        } else {
            ERROR_FUNC("Unknown side pick: %d", choice);
        }

        new otherTeam = (teamPick == CS_TEAM_CT) ? CS_TEAM_T : CS_TEAM_CT;

        g_Teams[client] = teamPick;
        SwitchPlayerTeam(client, teamPick);

        new otherCaptain = OtherCaptain(client);
        g_Teams[otherCaptain] = otherTeam;
        SwitchPlayerTeam(otherCaptain, otherTeam);

        ServerCommand("mp_restartgame 1");
        GivePlayerSelectionMenu(otherCaptain);

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}



/**
 * Player selection menus.
 */
public GivePlayerSelectionMenu(client) {
    new Handle:menu = CreateMenu(PlayerMenuHandler);
    SetMenuTitle(menu, "Pick your players");
    SetMenuExitButton(menu, false);
    AddPlayersToMenu(menu);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public PlayerMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        new selected = GetMenuInt(menu, param2);

        if (selected > 0) {
            g_Teams[selected] = g_Teams[client];
            SwitchPlayerTeam(selected, g_Teams[client]);
            if (client == g_capt1)
                PrintToChatAll(" \x01\x0B\x06%N \x01has picked \x05%N", client, selected);
            else
                PrintToChatAll(" \x01\x0B\x07%N \x01has picked \x02%N", client, selected);

            if (!IsPickingFinished()) {
                new nextCapt = OtherCaptain(client);
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

public MoreMenuPicks(client) {
    if (IsPickingFinished() || !IsValidClient(client) || !IsClientInGame(client)) {
        CreateTimer(5.0, FinishPicking);
        return;
    }
    GivePlayerSelectionMenu(client);
}

/**
 * Helper functions for the player menus.
 */
static bool:IsPickingFinished() {
    new numSelected = 0;
    for (new i = 1; i <= MaxClients; i++)
        if (IsPlayerPicked(i))
            numSelected++;

    return numSelected >= GetConVarInt(g_hLivePlayers);
}

static IsPlayerPicked(client) {
    new team = g_Teams[client];
    return team == CS_TEAM_T || team == CS_TEAM_CT;
}

static OtherCaptain(captain) {
    if (captain == g_capt1)
        return g_capt2;
    else
        return g_capt1;
}

static AddPlayersToMenu(Handle:menu) {
    new String:name[MAX_NAME_LENGTH];
    new count = 0;
    for (new client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client) && !IsPlayerPicked(client) && !IsFakeClient(client)) {
            GetClientName(client, name, sizeof(name));
            AddMenuInt(menu, client, name);
            count++;
        }
    }
}
