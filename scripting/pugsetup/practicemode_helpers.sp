public ConVar GetCvar(const char[] name) {
    ConVar cvar = FindConVar(name);
    if (cvar == null) {
        SetFailState("Failed to find cvar: \"%s\"", name);
    }
    return cvar;
}

public bool IsGrenadeProjectile(const char[] className) {
    static char projectileTypes[][] = {
        "hegrenade_projectile",
        "smokegrenade_projectile",
        "decoy_projectile",
        "flashbang_projectile",
        "molotov_projectile",
    };

    return FindStringInArray2(projectileTypes, sizeof(projectileTypes), className) >= 0;
}

public bool IsGrenadeWeapon(const char[] weapon) {
    static char grenades[][] = {
        "incgrenade",
        "molotov",
        "hegrenade",
        "decoy",
        "flashbang",
        "smokegrenade",
    };

    return FindStringInArray2(grenades, sizeof(grenades), weapon) >= 0;
}

public void TeleportToGrenadeHistoryPosition(int client, int index) {
    float origin[3];
    float angles[3];
    float velocity[3];
    g_GrenadeHistoryPositions[client].GetArray(index, origin, sizeof(origin));
    g_GrenadeHistoryAngles[client].GetArray(index, angles, sizeof(angles));
    TeleportEntity(client, origin, angles, velocity);
}

public void UpdatePlayerColor(int client) {
    QueryClientConVar(client, "cl_color", QueryClientColor, client);
}

public void QueryClientColor(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue) {
    int color = StringToInt(cvarValue);
    GetColor(view_as<ClientColor>(color), g_ClientColors[client]);
}

public void GetColor(ClientColor c, int array[4]) {
    int r, g, b;
    switch(c) {
        case ClientColor_Green:  { r = 0;   g = 255; b = 0; }
        case ClientColor_Purple: { r = 128; g = 0;   b = 128; }
        case ClientColor_Blue:   { r = 0;   g = 0;   b = 255; }
        case ClientColor_Orange: { r = 255; g = 128; b = 0; }
        case ClientColor_Yellow: { r = 255; g = 255; b = 0; }
    }
    array[0] = r;
    array[1] = g;
    array[2] = b;
    array[3] = 255;
}

public void TeleportToSavedGrenadePosition(int client, const char[] auth, const char[] index) {
    float origin[3];
    float angles[3];
    float velocity[3];
    char description[GRENADE_DESCRIPTION_LENGTH];

    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.JumpToKey(index)) {
            g_GrenadeLocationsKv.GetVector("origin", origin);
            g_GrenadeLocationsKv.GetVector("angles", angles);
            g_GrenadeLocationsKv.GetString("description", description, sizeof(description));
            TeleportEntity(client, origin, angles, velocity);

            if (!StrEqual(description, ""))
                PugSetupMessage(client, "Description: %s", description);
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
}

public int SaveGrenadeToKv(int client, const float origin[3], const float angles[3], const char[] name) {
    char auth[AUTH_LENGTH];
    char clientName[MAX_NAME_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    GetClientName(client, clientName, sizeof(clientName));
    g_GrenadeLocationsKv.JumpToKey(auth, true);
    g_GrenadeLocationsKv.SetString("name", clientName);
    int numGrenades = g_GrenadeLocationsKv.GetNum("numgrenades");
    g_GrenadeLocationsKv.SetNum("numgrenades", numGrenades + 1);

    char indexStr[32];
    IntToString(numGrenades, indexStr, sizeof(indexStr));
    g_GrenadeLocationsKv.JumpToKey(indexStr, true);

    g_GrenadeLocationsKv.SetString("name", name);
    g_GrenadeLocationsKv.SetVector("origin", origin);
    g_GrenadeLocationsKv.SetVector("angles", angles);

    g_GrenadeLocationsKv.GoBack();
    g_GrenadeLocationsKv.GoBack();
    return numGrenades;
}

public int AttemptFindTarget(const char[] target) {
    char target_name[MAX_TARGET_LENGTH];
    int target_list[1];
    bool tn_is_ml;
    int flags = COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_IMMUNITY;

    if (ProcessTargetString(
            target,
            0,
            target_list,
            1,
            flags,
            target_name,
            sizeof(target_name),
            tn_is_ml) > 0) {
        return target_list[0];
    } else {
        return -1;
    }
}

public bool FindTargetInGrenadesKvByName(const char[] inputName, char[] name, int nameLen, char[] auth, int authLen) {
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
            g_GrenadeLocationsKv.GetSectionName(auth, authLen);
            g_GrenadeLocationsKv.GetString("name", name, nameLen);

            if (StrContains(name, inputName) != -1) {
                g_GrenadeLocationsKv.GoBack();
                return true;
            }

        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
    }
    return false;
}

public void UpdateGrenadeDescription(int client, int index, const char[] description) {
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    char indexStr[32];
    IntToString(index, indexStr, sizeof(indexStr));

    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.JumpToKey(indexStr)) {
            g_GrenadeLocationsKv.SetString("desc", description);
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
}
