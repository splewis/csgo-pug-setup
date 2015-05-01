#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include "include/logdebug.inc"
#include "include/pugsetup.inc"
#include "include/pugsetup_practicemode.inc"
#include "include/restorecvars.inc"
#include "pugsetup/generic.sp"

#pragma semicolon 1
#pragma newdecls required

bool g_InPracticeMode = false;

// These data structures maintain a list of settings for a toggle-able option:
// the name, the cvar/value for the enabled option, and the cvar/value for the disabled option.
// Note: the first set of values for these data structures is the overall-practice mode cvars,
// which aren't toggle-able or named.
ArrayList g_BinaryOptionIds;
ArrayList g_BinaryOptionNames;
ArrayList g_BinaryOptionEnabled;
ArrayList g_BinaryOptionChangeable;
ArrayList g_BinaryOptionEnabledCvars;
ArrayList g_BinaryOptionEnabledValues;
ArrayList g_BinaryOptionCvarRestore;

// Infinite money data
ConVar g_InfiniteMoneyCvar;
bool g_InfiniteMoney = false;

// Grenade trajectory fix data
int g_BeamSprite = -1;
int g_ClientColors[MAXPLAYERS+1][4];
ConVar g_GrenadeTrajectoryClientColorCvar;
bool g_GrenadeTrajectoryClientColor = true;

ConVar g_AllowNoclipCvar;
bool g_AllowNoclip = false;

ConVar g_GrenadeTrajectoryCvar;
ConVar g_GrenadeThicknessCvar;
ConVar g_GrenadeTimeCvar;
ConVar g_GrenadeSpecTimeCvar;
bool g_GrenadeTrajectory = false;
float g_GrenadeThickness = 0.2;
float g_GrenadeTime = 20.0;
float g_GrenadeSpecTime = 4.0;

// Saved grenade locations data
#define GRENADE_DESCRIPTION_LENGTH 256
#define GRENADE_NAME_LENGTH 64
#define GRENADE_ID_LENGTH MAX_INTEGER_STRING_LENGTH
#define AUTH_LENGTH 64
char g_GrenadeLocationsFile[PLATFORM_MAX_PATH];
KeyValues g_GrenadeLocationsKv;
int g_CurrentSavedGrenadeId[MAXPLAYERS+1];
bool g_UpdatedGrenadeKv = false; // whether there has been any changed the kv structure this map

// Grenade history data
int g_GrenadeHistoryIndex[MAXPLAYERS+1];
ArrayList g_GrenadeHistoryPositions[MAXPLAYERS+1];
ArrayList g_GrenadeHistoryAngles[MAXPLAYERS+1];

// These must match the values used by cl_color.
enum ClientColor {
    ClientColor_Yellow = 0,
    ClientColor_Purple = 1,
    ClientColor_Green = 2,
    ClientColor_Blue = 3,
    ClientColor_Orange = 4,
};

// Forwards
Handle g_OnPracticeModeDisabled = INVALID_HANDLE;
Handle g_OnPracticeModeEnabled = INVALID_HANDLE;
Handle g_OnPracticeModeSettingChanged = INVALID_HANDLE;
Handle g_OnPracticeModeSettingsRead = INVALID_HANDLE;

#include "pugsetup/practicemode_helpers.sp"


public Plugin myinfo = {
    name = "CS:GO PugSetup: practice mode",
    author = "splewis",
    description = "A practice mode that can be launched through the .setup menu",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    InitDebugLog(DEBUG_CVAR, "practice");
    LoadTranslations("pugsetup.phrases");
    g_InPracticeMode = false;
    AddCommandListener(Command_TeamJoin, "jointeam");

    // Forwards
    g_OnPracticeModeDisabled = CreateGlobalForward("OnPracticeModeDisabled", ET_Ignore);
    g_OnPracticeModeEnabled = CreateGlobalForward("OnPracticeModeEnabled", ET_Ignore);
    g_OnPracticeModeSettingChanged = CreateGlobalForward("OnPracticeModeSettingChanged", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
    g_OnPracticeModeSettingsRead = CreateGlobalForward("OnPracticeModeSettingsRead", ET_Ignore);

    // Init data structures to be read from the config file
    g_BinaryOptionIds = new ArrayList(OPTION_NAME_LENGTH);
    g_BinaryOptionNames = new ArrayList(OPTION_NAME_LENGTH);
    g_BinaryOptionEnabled = new ArrayList();
    g_BinaryOptionChangeable = new ArrayList();
    g_BinaryOptionEnabledCvars = new ArrayList();
    g_BinaryOptionEnabledValues = new ArrayList();
    g_BinaryOptionCvarRestore = new ArrayList();
    ReadPracticeSettings();

    // Setup stuff for grenade history
    HookEvent("weapon_fire", Event_WeaponFired);
    for (int i = 0; i <= MAXPLAYERS; i++) {
        g_GrenadeHistoryPositions[i] = new ArrayList(3);
        g_GrenadeHistoryAngles[i] = new ArrayList(3);
    }

    // Grenade history commands
    RegConsoleCmd("sm_grenadeback", Command_GrenadeBack);
    RegConsoleCmd("sm_grenadeforward", Command_GrenadeForward);
    RegConsoleCmd("sm_clearnades", Command_ClearNades);
    RegConsoleCmd("sm_gotogrenade", Command_GotoNade);
    AddChatAlias(".back", "sm_grenadeback");
    AddChatAlias(".forward", "sm_grenadeforward");
    AddChatAlias(".clearnades", "sm_clearnades");
    AddChatAlias(".goto", "sm_gotogrenade");

    // Saved grenade location commands
    RegConsoleCmd("sm_grenades", Command_Grenades);
    RegConsoleCmd("sm_savegrenade", Command_SaveGrenade);
    RegConsoleCmd("sm_adddescription", Command_GrenadeDescription);
    RegConsoleCmd("sm_deletegrenade", Command_DeleteGrenade);
    AddChatAlias(".nades", "sm_grenades");
    AddChatAlias(".grenades", "sm_grenades");
    AddChatAlias(".addnade", "sm_savegrenade");
    AddChatAlias(".savenade", "sm_savegrenade");
    AddChatAlias(".save", "sm_savegrenade");
    AddChatAlias(".desc", "sm_adddescription");
    AddChatAlias(".delete", "sm_deletegrenade");

    // New cvars
    g_InfiniteMoneyCvar = CreateConVar("sm_infinite_money", "0", "Whether clients recieve infinite money");
    g_InfiniteMoneyCvar.AddChangeHook(OnInfiniteMoneyChanged);
    g_AllowNoclipCvar = CreateConVar("sm_allow_noclip", "0", "Whether players may use .noclip in chat to toggle noclip");
    g_AllowNoclipCvar.AddChangeHook(OnAllowNoclipChanged);

    g_GrenadeTrajectoryClientColorCvar = CreateConVar("sm_grenade_trajectory_use_player_color", "0", "Whether to use client colors when drawing grenade trajectories");
    g_GrenadeTrajectoryClientColorCvar.AddChangeHook(OnGrenadeTrajectoryClientColorChanged);

    // Patched builtin cvars
    g_GrenadeTrajectoryCvar = GetCvar("sv_grenade_trajectory");
    g_GrenadeThicknessCvar = GetCvar("sv_grenade_trajectory_thickness");
    g_GrenadeTimeCvar = GetCvar("sv_grenade_trajectory_time");
    g_GrenadeSpecTimeCvar = GetCvar("sv_grenade_trajectory_time_spectator");
    g_GrenadeTrajectoryCvar.AddChangeHook(OnGrenadeTrajectoryChanged);
    g_GrenadeThicknessCvar.AddChangeHook(OnGrenadeThicknessChanged);
    g_GrenadeTimeCvar.AddChangeHook(OnGrenadeTimeChanged);
    g_GrenadeSpecTimeCvar.AddChangeHook(OnGrenadeSpecTimeChanged);

    // set default colors to green
    for (int i = 0; i <= MAXPLAYERS; i++) {
        g_ClientColors[0][0] = 0;
        g_ClientColors[0][1] = 255;
        g_ClientColors[0][2] = 0;
        g_ClientColors[0][3] = 255;
    }

    // Remove cheats so sv_cheats isn't required for this:
    RemoveCvarFlag(g_GrenadeTrajectoryCvar, FCVAR_CHEAT);

    HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
}

public int OnInfiniteMoneyChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    bool previousValue = g_InfiniteMoney;
    g_InfiniteMoney = !StrEqual(newValue, "0");
    if (!previousValue && g_InfiniteMoney) {
        CreateTimer(1.0, Timer_GivePlayersMoney, _, TIMER_REPEAT);
    }
}

public int OnGrenadeTrajectoryChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeTrajectory = !StrEqual(newValue, "0");
}

public int OnGrenadeTrajectoryClientColorChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeTrajectoryClientColor = !StrEqual(newValue, "0");
}

public int OnGrenadeThicknessChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeThickness = StringToFloat(newValue);
}

public int OnGrenadeTimeChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeTime = StringToFloat(newValue);
}

public int OnGrenadeSpecTimeChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_GrenadeSpecTime = StringToFloat(newValue);
}

public int OnAllowNoclipChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    g_AllowNoclip = !StrEqual(newValue, "0");
}

/**
 * Silences all cvar changes in practice mode.
 */
public Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
    if (g_InPracticeMode) {
        event.BroadcastDisabled = true;
    }
    return Plugin_Continue;
}

public void OnClientConnected(int client) {
    g_GrenadeHistoryIndex[client] = -1;
    g_CurrentSavedGrenadeId[client] = -1;
    ClearArray(g_GrenadeHistoryPositions[client]);
    ClearArray(g_GrenadeHistoryAngles[client]);
}

public void OnMapStart() {
    ReadPracticeSettings();
    g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");

    // Init map-based saved grenade spots
    char dir[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, dir, sizeof(dir), "configs/pugsetup/practicemode_grenades");
    if (!DirExists(dir)) {
        CreateDirectory(dir, 511);
    }

    char map[PLATFORM_MAX_PATH];
    GetCleanMapName(map, sizeof(map));
    Format(g_GrenadeLocationsFile, sizeof(g_GrenadeLocationsFile), "%s/%s.cfg", dir, map);
    g_GrenadeLocationsKv = new KeyValues("Grenades");
    g_GrenadeLocationsKv.ImportFromFile(g_GrenadeLocationsFile);
    g_UpdatedGrenadeKv = false;
}

public void OnClientDisconnect(int client) {
    // always update the grenades file so user's saved grenades are never lost
    if (g_UpdatedGrenadeKv) {
        g_GrenadeLocationsKv.ExportToFile(g_GrenadeLocationsFile);
        g_UpdatedGrenadeKv = false;
    }
}

public void OnMapEnd() {
    if (g_UpdatedGrenadeKv) {
        g_GrenadeLocationsKv.ExportToFile(g_GrenadeLocationsFile);
        g_UpdatedGrenadeKv = false;
    }

    if (g_InPracticeMode)
        DisablePracticeMode();

    delete g_GrenadeLocationsKv;
}

public void OnClientPutInServer(int client) {
    UpdatePlayerColor(client);
}

public Action Command_TeamJoin(int client, const char[] command, int argc) {
    if (!IsValidClient(client) || argc < 1)
        return Plugin_Handled;

    if (g_InPracticeMode) {
        char arg[4];
        GetCmdArg(1, arg, sizeof(arg));
        int team = StringToInt(arg);
        ChangeClientTeam(client, team);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] text) {
    if (g_AllowNoclip && StrEqual(text, ".noclip") && IsPlayer(client)) {
        MoveType t = GetEntityMoveType(client);
        MoveType next = (t == MOVETYPE_WALK) ? MOVETYPE_NOCLIP : MOVETYPE_WALK;
        SetEntityMoveType(client, next);
    }
}

public void ReadPracticeSettings() {
    ClearArray(g_BinaryOptionNames);
    ClearArray(g_BinaryOptionEnabled);
    ClearArray(g_BinaryOptionChangeable);
    ClearNestedArray(g_BinaryOptionEnabledCvars);
    ClearNestedArray(g_BinaryOptionEnabledValues);
    ClearArray(g_BinaryOptionCvarRestore);

    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, sizeof(filePath), "configs/pugsetup/practicemode.cfg");

    KeyValues kv = new KeyValues("practice_settings");
    if (!kv.ImportFromFile(filePath)) {
        LogError("Failed to import keyvalue from practice config file \"%s\"", filePath);
        delete kv;
        return;
    }

    // Read in the binary options
    if (kv.JumpToKey("binary_options")) {
        if (kv.GotoFirstSubKey()) {
            // read each option
            do {
                char id[128];
                kv.GetSectionName(id, sizeof(id));

                char name[OPTION_NAME_LENGTH];
                kv.GetString("name", name, sizeof(name));

                char enabledString[64];
                kv.GetString("default", enabledString, sizeof(enabledString), "enabled");
                bool enabled = StrEqual(enabledString, "enabled", false);

                bool changeable = (kv.GetNum("changeable", 1) != 0);

                char cvarName[CVAR_NAME_LENGTH];
                char cvarValue[CVAR_VALUE_LENGTH];

                // read the enabled cvar list
                ArrayList enabledCvars = new ArrayList(CVAR_NAME_LENGTH);
                ArrayList enabledValues = new ArrayList(CVAR_VALUE_LENGTH);
                if (kv.JumpToKey("enabled")) {
                    if (kv.GotoFirstSubKey(false)) {
                        do {
                            kv.GetSectionName(cvarName, sizeof(cvarName));
                            enabledCvars.PushString(cvarName);
                            kv.GetString(NULL_STRING, cvarValue, sizeof(cvarValue));
                            enabledValues.PushString(cvarValue);
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }
                    kv.GoBack();
                }

                AddPracticeModeSetting(id, name, enabledCvars, enabledValues, enabled, changeable);

            } while (kv.GotoNextKey());
        }
    }
    kv.Rewind();

    Call_StartForward(g_OnPracticeModeSettingsRead);
    Call_Finish();

    delete kv;
}

public void OnHelpCommand(int client, ArrayList replyMessages, int maxMessageSize, bool& block) {
    if (g_InPracticeMode) {
        block = true;
        PugSetupMessage(client, "{LIGHT_GREEN}.setup {NORMAL}to change/view practicemode settings");
        if (g_AllowNoclip)
            PugSetupMessage(client, "{LIGHT_GREEN}.noclip {NORMAL}to enter/exit noclip mode");
        PugSetupMessage(client, "{LIGHT_GREEN}.back {NORMAL}to go to your last grenade position");
        PugSetupMessage(client, "{LIGHT_GREEN}.forward {NORMAL}to go to your next grenade position");
        PugSetupMessage(client, "{LIGHT_GREEN}.save <name> {NORMAL}to save a grenade position");
        PugSetupMessage(client, "{LIGHT_GREEN}.nades [player] {NORMAL}to view all saved grenades");
        PugSetupMessage(client, "{LIGHT_GREEN}.desc <description> {NORMAL}to add a nade description");
        PugSetupMessage(client, "{LIGHT_GREEN}.delete {NORMAL}to delete your current grenade position");
        PugSetupMessage(client, "{LIGHT_GREEN}.goto [player] <id> {NORMAL}to go to a grenadeid");
    }
}

public bool OnSetupMenuOpen(int client, Menu menu, bool displayOnly) {
    int leader = GetLeader();
    if (!IsPlayer(leader)) {
        SetLeader(client);
    }

    int style = ITEMDRAW_DEFAULT;
    if (!HasPermissions(client, Permission_Leader) || displayOnly) {
        style = ITEMDRAW_DISABLED;
    }

    if (g_InPracticeMode) {
        GivePracticeMenu(client, style);
        return false;
    } else {
        AddMenuItem(menu, "launch_practice", "Launch practice mode", style);
        return true;
    }
}

public void OnReadyToStart() {
    if (g_InPracticeMode)
        DisablePracticeMode();
}

public void OnSetupMenuSelect(Menu menu, MenuAction action, int param1, int param2) {
    int client = param1;
    char buffer[64];
    menu.GetItem(param2, buffer, sizeof(buffer));
    if (StrEqual(buffer, "launch_practice")) {
        g_InPracticeMode = !g_InPracticeMode;
        if (g_InPracticeMode) {
            for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
                ChangeSetting(i, IsPracticeModeSettingEnabled(i), false);
            }

            ServerCommand("exec sourcemod/pugsetup/practice_start.cfg");
            GivePracticeMenu(client, ITEMDRAW_DEFAULT);
            PugSetupMessageToAll("Practice mode is now enabled.");

            Call_StartForward(g_OnPracticeModeEnabled);
            Call_Finish();
        }
    }
}

static void ChangeSetting(int index, bool enabled, bool print=true) {
    if (enabled) {
        ArrayList cvars = g_BinaryOptionEnabledCvars.Get(index);
        ArrayList values = g_BinaryOptionEnabledValues.Get(index);
        g_BinaryOptionCvarRestore.Set(index, SaveCvars(cvars));

        char cvar[CVAR_NAME_LENGTH];
        char value[CVAR_VALUE_LENGTH];

        for (int i = 0; i < cvars.Length; i++) {
            cvars.GetString(i, cvar, sizeof(cvar));
            values.GetString(i, value, sizeof(value));
            ServerCommand("%s %s", cvar, value);
        }

    } else {
        Handle cvarRestore = g_BinaryOptionCvarRestore.Get(index);
        if (cvarRestore != INVALID_HANDLE) {
            RestoreCvars(cvarRestore, true);
            g_BinaryOptionCvarRestore.Set(index, INVALID_HANDLE);
        }
    }

    char id[OPTION_NAME_LENGTH];
    char name[OPTION_NAME_LENGTH];
    g_BinaryOptionIds.GetString(index, id, sizeof(id));
    g_BinaryOptionNames.GetString(index, name, sizeof(name));

    if (print) {
        char enabledString[32];
        GetEnabledString(enabledString, sizeof(enabledString), enabled);

        // don't display empty names
        if (!StrEqual(name, ""))
            PugSetupMessageToAll("%s is now %s.", name, enabledString);
    }

    Call_StartForward(g_OnPracticeModeSettingChanged);
    Call_PushCell(index);
    Call_PushString(id);
    Call_PushString(name);
    Call_PushCell(enabled);
    Call_Finish();
}

static void GivePracticeMenu(int client, int style, int pos=-1) {
    Menu menu = new Menu(PracticeMenuHandler);
    SetMenuTitle(menu, "Practice Settings");
    SetMenuExitButton(menu, true);

    AddMenuItem(menu, "end_menu", "Exit practice mode", style);

    for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
        if (!g_BinaryOptionChangeable.Get(i))
            continue;

        char name[OPTION_NAME_LENGTH];
        g_BinaryOptionNames.GetString(i, name, sizeof(name));

        char enabled[32];
        GetEnabledString(enabled, sizeof(enabled), g_BinaryOptionEnabled.Get(i), client);

        char buffer[128];
        Format(buffer, sizeof(buffer), "%s: %s", name, enabled);
        AddMenuItem(menu, name, buffer, style);
    }

    if (pos == -1)
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    else
        DisplayMenuAtItem(menu, client, pos, MENU_TIME_FOREVER);
}

public int PracticeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[OPTION_NAME_LENGTH];
        int pos = GetMenuSelectionPosition();
        menu.GetItem(param2, buffer, sizeof(buffer));

        for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
            char name[OPTION_NAME_LENGTH];
            g_BinaryOptionNames.GetString(i, name, sizeof(name));
            if (StrEqual(name, buffer)) {
                bool setting = !g_BinaryOptionEnabled.Get(i);
                g_BinaryOptionEnabled.Set(i, setting);
                ChangeSetting(i, setting);
                GivePracticeMenu(client, ITEMDRAW_DEFAULT, pos);
                return 0;
            }
        }

        if (StrEqual(buffer, "end_menu")) {
            DisablePracticeMode();
            GiveSetupMenu(client);
        }

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }

    return 0;
}

public void DisablePracticeMode() {
    Call_StartForward(g_OnPracticeModeDisabled);
    Call_Finish();

    for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
        ChangeSetting(i, false, false);
    }

    g_InPracticeMode = false;

    // force turn noclip off for everyone
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i))
            SetEntityMoveType(i, MOVETYPE_WALK);
    }

    ServerCommand("exec sourcemod/pugsetup/practice_end.cfg");
    PugSetupMessageToAll("Practice mode is now disabled.");
}

public void SetCvar(const char[] name, int value) {
    Handle cvar = FindConVar(name);
    if (cvar == INVALID_HANDLE) {
        LogError("cvar \"%s\" could not be found", name);
    } else {
        SetConVarInt(cvar, value);
    }
}

public Action Timer_GivePlayersMoney(Handle timer) {
    if (!g_InfiniteMoney) {
        return Plugin_Handled;
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsFakeClient(i)) {
            SetEntProp(i, Prop_Send, "m_iAccount", 16000);
        }
    }

    return Plugin_Continue;
}

public int OnEntityCreated(int entity, const char[] className) {
    if (!g_GrenadeTrajectory || !IsValidEntity(entity) || !IsGrenadeProjectile(className))
        return;

    SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}

public int OnEntitySpawned(int entity) {
    if (!g_GrenadeTrajectory || !IsValidEdict(entity))
        return;

    char className[64];
    GetEdictClassname(entity, className, sizeof(className));

    if (!IsGrenadeProjectile(className))
        return;

    int client = 0; // will use the default color (green)
    if (g_GrenadeTrajectoryClientColor) {
        int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
        if (IsPlayer(owner)) {
            client = owner;
            UpdatePlayerColor(client);
        }
    }

    if (IsValidEntity(entity)) {
        for (int i = 1; i <= MaxClients; i++) {

            if (!IsClientConnected(i) || !IsClientInGame(i))
                continue;

            // Note: the technique using temporary entities is taken from InternetBully's NadeTails plugin
            // which you can find at https://forums.alliedmods.net/showthread.php?t=240668
            float time = (GetClientTeam(i) == CS_TEAM_SPECTATOR) ? g_GrenadeSpecTime : g_GrenadeTime;
            TE_SetupBeamFollow(entity, g_BeamSprite, 0, time, g_GrenadeThickness * 5, g_GrenadeThickness * 5, 1, g_ClientColors[client]);
            TE_SendToClient(i);
        }
    }
}

public Action Event_WeaponFired(Event event, const char[] name, bool dontBroadcast) {
    if (!g_InPracticeMode) {
        return;
    }

    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));

    if (IsGrenadeWeapon(weapon) && IsPlayer(client)) {
        float position[3];
        float angles[3];
        GetClientAbsOrigin(client, position);
        GetClientEyeAngles(client, angles);
        PushArrayArray(g_GrenadeHistoryPositions[client], position, sizeof(position));
        PushArrayArray(g_GrenadeHistoryAngles[client], angles, sizeof(angles));
        g_GrenadeHistoryIndex[client] = g_GrenadeHistoryPositions[client].Length;
    }
}

public Action Command_GrenadeBack(int client, int args) {
    if (g_InPracticeMode && g_GrenadeHistoryPositions[client].Length > 0) {
        g_GrenadeHistoryIndex[client]--;
        if (g_GrenadeHistoryIndex[client] < 0)
            g_GrenadeHistoryIndex[client] = 0;

        TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
        PugSetupMessage(client, "Teleporting back to %d position in grenade history.", g_GrenadeHistoryIndex[client] + 1);
    }

    return Plugin_Handled;
}

public Action Command_GrenadeForward(int client, int args) {
    if (g_InPracticeMode && g_GrenadeHistoryPositions[client].Length > 0) {
        int max = g_GrenadeHistoryPositions[client].Length;
        g_GrenadeHistoryIndex[client]++;
        if (g_GrenadeHistoryIndex[client] >= max)
            g_GrenadeHistoryIndex[client] = max - 1;
        TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
        PugSetupMessage(client, "Teleporting forward to %d position in grenade history.", g_GrenadeHistoryIndex[client] + 1);
    }

    return Plugin_Handled;
}

public Action Command_ClearNades(int client, int args) {
    if (g_InPracticeMode) {
        ClearArray(g_GrenadeHistoryPositions[client]);
        ClearArray(g_GrenadeHistoryAngles[client]);
        PugSetupMessage(client, "Grenade history cleared.");
    }

    return Plugin_Handled;
}

public Action Command_GotoNade(int client, int args) {
    if (g_InPracticeMode) {
        char arg1[32];
        char arg2[32];
        char name[MAX_NAME_LENGTH];
        char auth[AUTH_LENGTH];

        if (args >= 2 && GetCmdArg(1, arg1, sizeof(arg1)) && GetCmdArg(2, arg2, sizeof(arg2))) {
            if (!FindGrenadeTarget(arg1, name, sizeof(name), auth, sizeof(auth))) {
                PugSetupMessage(client, "Player not found.");
                return Plugin_Handled;
            }
            if (!TeleportToSavedGrenadePosition(client, auth, arg2)){
                PugSetupMessage(client, "Grenade id %s not found.", arg2);
                return Plugin_Handled;
            }

        } else if (args >= 1 && GetCmdArg(1, arg1, sizeof(arg1))) {
            GetClientName(client, name, sizeof(name));
            GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
            if (!TeleportToSavedGrenadePosition(client, auth, arg1)){
                PugSetupMessage(client, "Grenade id %s not found.", arg1);
                return Plugin_Handled;
            }

        } else {
            PugSetupMessage(client, "Usage: .goto [player] <grenadeid>");
        }
    }

    return Plugin_Handled;
}

public Action Command_Grenades(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    char arg[MAX_NAME_LENGTH];
    char auth[AUTH_LENGTH];
    char name[MAX_NAME_LENGTH];

    if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
        if (FindGrenadeTarget(arg, name, sizeof(name), auth, sizeof(auth))) {
            GiveGrenadesForPlayer(client, name, auth);
            return Plugin_Handled;
        }
    }

    int count = 0;
    Menu menu = new Menu(GrenadeHandler_PlayerSelection);
    menu.SetTitle("Select a player:");

    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
            int nadeCount = 0;
            if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
                do {
                    nadeCount++;
                } while (g_GrenadeLocationsKv.GotoNextKey());
                g_GrenadeLocationsKv.GoBack();
            }

            g_GrenadeLocationsKv.GetSectionName(auth, sizeof(auth));
            g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
            char info[256];
            Format(info, sizeof(info), "%s %s", auth, name);

            char display[256];
            Format(display, sizeof(display), "%s (%d saved)", name, nadeCount);

            if (nadeCount > 0) {
                menu.AddItem(info, display);
                count++;
            }

        } while (g_GrenadeLocationsKv.GotoNextKey());
    }
    g_GrenadeLocationsKv.Rewind();

    if (count == 0) {
        PugSetupMessage(client, "No players have grenade positions saved.");
        delete menu;
    } else {
        menu.Display(client, MENU_TIME_FOREVER);
    }

    return Plugin_Handled;
}

public int GrenadeHandler_PlayerSelection(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select && g_InPracticeMode) {
        int client = param1;
        char buffer[MAX_NAME_LENGTH+AUTH_LENGTH+1];
        menu.GetItem(param2, buffer, sizeof(buffer));

        // split buffer from "auth name" (seperated by whitespace)
        char ownerAuth[AUTH_LENGTH];
        char ownerName[MAX_NAME_LENGTH];
        SplitOnSpace(buffer, ownerAuth, sizeof(ownerAuth), ownerName, sizeof(ownerName));
        GiveGrenadesForPlayer(client, ownerName, ownerAuth);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public void GiveGrenadesForPlayer(int client, const char[] ownerName, const char[] ownerAuth) {
    float origin[3];
    float angles[3];
    char description[GRENADE_DESCRIPTION_LENGTH];
    char name[GRENADE_NAME_LENGTH];

    int userCount = 0;
    Menu menu = new Menu(GrenadeHandler_GrenadeSelection);
    menu.SetTitle("Grenades for %s", ownerName);

    if (g_GrenadeLocationsKv.JumpToKey(ownerAuth)) {
        if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
            do {
                char strId[32];
                g_GrenadeLocationsKv.GetSectionName(strId, sizeof(strId));
                g_GrenadeLocationsKv.GetVector("origin", origin);
                g_GrenadeLocationsKv.GetVector("angles", angles);
                g_GrenadeLocationsKv.GetString("description", description, sizeof(description));
                g_GrenadeLocationsKv.GetString("name", name, sizeof(name));

                char info[128];
                Format(info, sizeof(info), "%s %s", ownerAuth, strId);
                char display[128];
                Format(display, sizeof(display), "%s (id %s)", name, strId);

                menu.AddItem(info, display);
                userCount++;
            } while (g_GrenadeLocationsKv.GotoNextKey());
            g_GrenadeLocationsKv.GoBack();
        }
        g_GrenadeLocationsKv.GoBack();
    }

    if (userCount == 0) {
        PugSetupMessage(client, "No grenades found.");
        delete menu;
    } else {
        menu.Display(client, MENU_TIME_FOREVER);
    }
}

public int GrenadeHandler_GrenadeSelection(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select && g_InPracticeMode) {
        int client = param1;
        char buffer[128];
        menu.GetItem(param2, buffer, sizeof(buffer));
        char auth[AUTH_LENGTH];
        char idStr[MAX_INTEGER_STRING_LENGTH];
        // split buffer from form "<auth> <id>" (seperated by a space)
        SplitOnSpace(buffer, auth, sizeof(auth), idStr, sizeof(idStr));
        TeleportToSavedGrenadePosition(client, auth, idStr);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public Action Command_SaveGrenade(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    char name[GRENADE_NAME_LENGTH];
    GetCmdArgString(name, sizeof(name));
    TrimString(name);

    if (strlen(name) == 0)  {
        PugSetupMessage(client, "Usage: .save <name>");
        return Plugin_Handled;
    }

    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    char grenadeId[GRENADE_ID_LENGTH];
    if (FindGrenadeByName(auth, name, grenadeId)) {
        PugSetupMessage(client, "You have already used that name.");
        return Plugin_Handled;
    }

    float origin[3];
    float angles[3];
    GetClientAbsOrigin(client, origin);
    GetClientEyeAngles(client, angles);

    int nadeId = SaveGrenadeToKv(client, origin, angles, name);
    g_CurrentSavedGrenadeId[client] = nadeId;
    PugSetupMessage(client, "Saved grenade (id %d). Type .desc <description> to add a description or .delete to delete this position.", nadeId);
    return Plugin_Handled;
}

public Action Command_GrenadeDescription(int client, int args) {
    int nadeId = g_CurrentSavedGrenadeId[client];
    if (nadeId < 0 || !g_InPracticeMode) {
        return Plugin_Handled;
    }

    char description[GRENADE_DESCRIPTION_LENGTH];
    GetCmdArgString(description, sizeof(description));

    UpdateGrenadeDescription(client, nadeId, description);
    PugSetupMessage(client, "Added grenade description.");
    return Plugin_Handled;
}

public Action Command_DeleteGrenade(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }

    // get the grenade id first
    char grenadeIdStr[32];
    if (args < 1 || !GetCmdArg(1, grenadeIdStr, sizeof(grenadeIdStr))) {
        // if this fails, use the last grenade position
        IntToString(g_CurrentSavedGrenadeId[client], grenadeIdStr, sizeof(grenadeIdStr));
    }

    DeleteGrenadeFromKv(client, grenadeIdStr);
    return Plugin_Handled;
}
