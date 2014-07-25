/**
 * Executes a config file named by a convar.
 */
public ExecCfg(Handle:ConVarName) {
    new String:cfg[PLATFORM_MAX_PATH];
    GetConVarString(ConVarName, cfg, sizeof(cfg));
    ServerCommand("exec %s", cfg);
}

/**
 * Adds an integer to a menu as a string choice.
 */
public AddMenuInt(Handle:menu, any:value, String:display[]) {
    decl String:buffer[8];
    IntToString(value, buffer, sizeof(buffer));
    AddMenuItem(menu, buffer, display);
}

/**
 * Adds an integer to a menu, named by the integer itself.
 */
public AddMenuInt2(Handle:menu, any:value) {
    decl String:buffer[8];
    IntToString(value, buffer, sizeof(buffer));
    AddMenuItem(menu, buffer, buffer);
}

/**
 * Gets an integer to a menu from a string choice.
 */
public GetMenuInt(Handle:menu, any:param2) {
    decl String:choice[8];
    GetMenuItem(menu, param2, choice, sizeof(choice));
    return StringToInt(choice);
}

/**
 * Adds a boolean to a menu as a string choice.
 */
public AddMenuBool(Handle:menu, bool:value, String:display[]) {
    new convertedInt = value ? 1 : 0;
    AddMenuInt(menu, convertedInt, display);
}

/**
 * Gets a boolean to a menu from a string choice.
 */
public bool:GetMenuBool(Handle:menu, any:param2) {
    return GetMenuInt(menu, param2) != 0;
}

/**
 * Returns the number of human clients on a team.
 */
public GetNumHumansOnTeam(team) {
    new count = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsFakeClient(i))
            count++;
    }
    return count;
}

/**
 * Returns a random player client on the server.
 */
public RandomPlayer() {
    new client = -1;
    while (!IsValidClient(client) || IsFakeClient(client)) {
        if (GetRealClientCount() < 1)
            return -1;

        client = GetRandomInt(1, MaxClients);
    }
    return client;
}

/**
 * Switches and respawns a player onto a new team.
 */
public SwitchPlayerTeam(client, team) {
    if (team > CS_TEAM_SPECTATOR) {
        CS_SwitchTeam(client, team);
        CS_UpdateClientModel(client);
        CS_RespawnPlayer(client);
    } else {
        ChangeClientTeam(client, team);
    }
}

/**
 * Returns if a client is valid.
 */
public bool:IsValidClient(client) {
    if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
        return true;
    return false;
}

/**
 * Returns the number of clients that are actual players in the game.
 */
public GetRealClientCount() {
    new clients = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            clients++;
        }
    }
    return clients;
}

/**
 * Returns a random index from an array.
 */
public any:GetArrayRandomIndex(Handle:array) {
    new len = GetArraySize(array);
    if (len == 0)
        ThrowError("Can't get random index from empty array");
    return GetRandomInt(0, len - 1);
}

/**
 * Returns a random element from an array.
 */
public any:GetArrayCellRandom(Handle:array) {
    return GetArrayCell(array, GetArrayRandomIndex(array));
}

public PluginMessageToClient(client, const String:msg[], any:...) {
    new String:formattedMsg[1024] = MESSAGE_PREFIX;
    decl String:tmp[1024];
    VFormat(tmp, sizeof(tmp), msg, 3);
    StrCat(formattedMsg, sizeof(formattedMsg), tmp);
    PrintToChat(client, formattedMsg);
}

public PluginMessage(const String:msg[], any:...) {
    new String:formattedMsg[1024] = MESSAGE_PREFIX;
    decl String:tmp[1024];
    VFormat(tmp, sizeof(tmp), msg, 2);
    StrCat(formattedMsg, sizeof(formattedMsg), tmp);
    PrintToChatAll(formattedMsg);
}
