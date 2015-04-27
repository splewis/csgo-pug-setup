/**
 * Natives.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("AddPracticeModeSetting", Native_AddPracticeModeSetting);
    CreateNative("IsPracticeModeEnabled", Native_IsPracticeModeEnabled);
    CreateNative("IsPracticeModeSettingEnabled", Native_IsPracticeModeSettingEnabled);
}

public int Native_AddPracticeModeSetting(Handle plugin, int numParams) {
    char settingId[OPTION_NAME_LENGTH];
    char name[OPTION_NAME_LENGTH];

    GetNativeString(1, settingId, sizeof(settingId));
    GetNativeString(2, name, sizeof(name));
    ArrayList enabledCvars = view_as<ArrayList>(GetNativeCell(3));
    ArrayList enabledValues = view_as<ArrayList>(GetNativeCell(4));
    bool enabled = GetNativeCell(5);
    bool changeable = GetNativeCell(6);

    if (enabledCvars.Length != enabledValues.Length) {
        ThrowNativeError(SP_ERROR_PARAM,
                         "Cvar name list size (%d) mismatch with cvar value list (%d)",
                         enabledCvars.Length, enabledValues.Length);
    }

    g_BinaryOptionIds.PushString(settingId);
    g_BinaryOptionNames.PushString(name);
    g_BinaryOptionEnabled.Push(enabled);
    g_BinaryOptionChangeable.Push(changeable);
    g_BinaryOptionEnabledCvars.Push(enabledCvars);
    g_BinaryOptionEnabledValues.Push(enabledValues);
    g_BinaryOptionCvarRestore.Push(INVALID_HANDLE);

    return g_BinaryOptionIds.Length - 1;
}

public int Native_IsPracticeModeEnabled(Handle plugin, int numParams) {
    return g_InPracticeMode;
}

public int Native_IsPracticeModeSettingEnabled(Handle plugin, int numParams) {
    int index = GetNativeCell(1);
    if (index < 0 || index >= g_BinaryOptionIds.Length) {
        ThrowNativeError(SP_ERROR_PARAM, "Setting %d is not valid", index);
    }
    return g_BinaryOptionEnabled.Get(index);
}


/**
 * Some generic helpers functions.
 */

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
    SetEntityMoveType(client, MOVETYPE_WALK);
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

public bool TeleportToSavedGrenadePosition(int client, const char[] targetAuth, const char[] id) {
    float origin[3];
    float angles[3];
    float velocity[3];
    char description[GRENADE_DESCRIPTION_LENGTH];
    bool success = false;

    // update the client's current grenade id, if it was their grenade
    bool myGrenade;
    char clientAuth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));
    if (StrEqual(clientAuth, targetAuth)) {
        g_CurrentSavedGrenadeId[client] = StringToInt(id);
        myGrenade = true;
    } else {
        g_CurrentSavedGrenadeId[client] = -1;
        myGrenade = false;
    }

    if (g_GrenadeLocationsKv.JumpToKey(targetAuth)) {
        char targetName[MAX_NAME_LENGTH];
        g_GrenadeLocationsKv.GetString("name", targetName, sizeof(targetName));

        if (g_GrenadeLocationsKv.JumpToKey(id)) {
            success = true;
            g_GrenadeLocationsKv.GetVector("origin", origin);
            g_GrenadeLocationsKv.GetVector("angles", angles);
            g_GrenadeLocationsKv.GetString("description", description, sizeof(description));
            TeleportEntity(client, origin, angles, velocity);
            SetEntityMoveType(client, MOVETYPE_WALK);

            if (myGrenade) {
                PugSetupMessage(client, "Teleporting to your grenade id %s", id);
            } else {
                PugSetupMessage(client, "Teleporting to %s's grenade id %s", targetName, id);
            }

            if (!StrEqual(description, "")) {
                PugSetupMessage(client, "Description: %s", description);
            }

            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }

    return success;
}

public int SaveGrenadeToKv(int client, const float origin[3], const float angles[3], const char[] name) {
    g_UpdatedGrenadeKv = true;
    char auth[AUTH_LENGTH];
    char clientName[MAX_NAME_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    GetClientName(client, clientName, sizeof(clientName));
    g_GrenadeLocationsKv.JumpToKey(auth, true);
    g_GrenadeLocationsKv.SetString("name", clientName);
    int nadeId = g_GrenadeLocationsKv.GetNum("nextid", 1);
    g_GrenadeLocationsKv.SetNum("nextid", nadeId + 1);

    char idStr[32];
    IntToString(nadeId, idStr, sizeof(idStr));
    g_GrenadeLocationsKv.JumpToKey(idStr, true);

    g_GrenadeLocationsKv.SetString("name", name);
    g_GrenadeLocationsKv.SetVector("origin", origin);
    g_GrenadeLocationsKv.SetVector("angles", angles);

    g_GrenadeLocationsKv.GoBack();
    g_GrenadeLocationsKv.GoBack();
    return nadeId;
}

public bool DeleteGrenadeFromKv(int client, const char[] nadeIdStr) {
    g_UpdatedGrenadeKv = true;
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    bool deleted = false;
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        char name[GRENADE_NAME_LENGTH];
        if (g_GrenadeLocationsKv.JumpToKey(nadeIdStr)) {
            g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
            g_GrenadeLocationsKv.GoBack();
        }

        deleted = g_GrenadeLocationsKv.DeleteKey(nadeIdStr);
        g_GrenadeLocationsKv.GoBack();
        PugSetupMessage(client, "Deleted grenade id %s, \"%s\".", nadeIdStr, name);
    }
    return deleted;
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
    g_UpdatedGrenadeKv = true;
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    char nadeId[32];
    IntToString(index, nadeId, sizeof(nadeId));

    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
        if (g_GrenadeLocationsKv.JumpToKey(nadeId)) {
            g_GrenadeLocationsKv.SetString("description", description);
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }
}

public bool FindGrenadeTarget(const char[] nameInput, char[] name, int nameLen, char[] auth, int authLen) {
    int target = AttemptFindTarget(nameInput);
    if (IsPlayer(target) && GetClientAuthId(target, AuthId_Steam2, auth, authLen) && GetClientName(target, name, nameLen)) {
        return true;
    } else {
        return FindTargetInGrenadesKvByName(nameInput, name, nameLen, auth, authLen);
    }
}
