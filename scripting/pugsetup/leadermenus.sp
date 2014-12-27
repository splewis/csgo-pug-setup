/**
 * Displays a menu to select the captains for the game.
 */
public void Captain1Menu(int client) {
    Menu menu = new Menu(Captain1MenuHandler);
    SetMenuTitle(menu, "Chose captain 1:");
    if (AddPotentialCaptains(menu, g_capt2) >= 1)
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    else
        CloseHandle(menu);
}

public int Captain1MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int choice = GetMenuInt(menu, param2);
        SetCaptain(1, choice);
        Captain2Menu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public void Captain2Menu(int client) {
    Menu menu = new Menu(Captain2MenuHandler);
    SetMenuTitle(menu, "Chose captain 2:");
    if (AddPotentialCaptains(menu, g_capt1) >= 1)
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    else
        CloseHandle(menu);
}

public int Captain2MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int choice = GetMenuInt(menu, param2);
        SetCaptain(2, choice);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

static int AddPotentialCaptains(Menu menu, int otherCaptain) {
    int count = 0;
    for (int client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client) && !IsFakeClient(client) && otherCaptain != client) {
            char name[MAX_NAME_LENGTH];
            GetClientName(client, name, sizeof(name));
            AddMenuInt(menu, client, name);
            count++;
        }
    }
    return count;
}

/**
 * Extra menu for selecting the leader of the game.
 */
 public void LeaderMenu(int client) {
    Menu menu = new Menu(LeaderMenuHandler);
    SetMenuTitle(menu, "Chose the game leader:");
    if (AddAllPlayers(menu) >= 1)
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    else
        CloseHandle(menu);
}

public int LeaderMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int choice = GetMenuInt(menu, param2);
        SetLeader(choice);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

static int AddAllPlayers(Menu menu) {
    return AddPotentialCaptains(menu, -1); // adds everyone (excludes client -1)
}
