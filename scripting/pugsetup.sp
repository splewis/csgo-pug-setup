#pragma semicolon 1
#include <cstrike>
#include <sourcemod>
#include <sdktools>
#include "include/pugsetup.inc"



/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/** Initial menu data (where captain 1 picks between side pick or 1st player pick) **/
enum InitialPick {
    InitialPick_Side,
    InitialPick_Player
};

/** ConVar handles **/
Handle g_hAdminFlag = INVALID_HANDLE;
Handle g_hAlways5v5 = INVALID_HANDLE;
Handle g_hAnyCanPause = INVALID_HANDLE;
Handle g_hAutoRandomizeCaptains = INVALID_HANDLE;
Handle g_hAutorecord = INVALID_HANDLE;
Handle g_hCvarVersion = INVALID_HANDLE;
Handle g_hDemoNameFormat = INVALID_HANDLE;
Handle g_hDemoTimeFormat = INVALID_HANDLE;
Handle g_hExcludeSpectators = INVALID_HANDLE;
Handle g_hExecDefaultConfig = INVALID_HANDLE;
Handle g_hMapVoteTime = INVALID_HANDLE;
Handle g_hMessagePrefix = INVALID_HANDLE;
Handle g_hMutualUnpause = INVALID_HANDLE;
Handle g_hNeverAutoLO3 = INVALID_HANDLE;
Handle g_hQuickRestarts = INVALID_HANDLE;
Handle g_hRandomizeMapOrder = INVALID_HANDLE;
Handle g_hRequireAdminToSetup = INVALID_HANDLE;
Handle g_hSnakeCaptains = INVALID_HANDLE;
Handle g_hWarmupCfg = INVALID_HANDLE;

/** Setup info **/
int g_Leader = -1;

// Specific choices made when setting up
int g_GameTypeIndex = 0;
int g_PlayersPerTeam = 5;
bool g_AutoLO3 = false;
TeamType g_TeamType;
MapType g_MapType;

// Other important variables about the state of the game
bool g_Setup = false;
bool g_mapSet = false;
bool g_Recording = true;
char g_DemoFileName[256];
bool g_LiveTimerRunning = false;

// Pause information
bool g_ctUnpaused = false;
bool g_tUnpaused = false;

#define CONFIG_STRING_LENGTH 256
Handle g_GameConfigFiles = INVALID_HANDLE;
Handle g_GameMapFiles = INVALID_HANDLE;
Handle g_GameTypes = INVALID_HANDLE;
Handle g_GameTypeHidden = INVALID_HANDLE;
Handle g_GameTypeTeamSize = INVALID_HANDLE;

/** Map-voting variables **/
Handle g_MapNames = INVALID_HANDLE;
Handle g_MapVetoed = INVALID_HANDLE;
int g_ChosenMap = -1;

/** Data about team selections **/
int g_capt1 = -1;
int g_capt2 = -1;
int g_Teams[MAXPLAYERS+1];
bool g_Ready[MAXPLAYERS+1];
bool g_PlayerAtStart[MAXPLAYERS+1];
bool g_PickingPlayers = false;
bool g_MatchLive = false;

/** Forwards **/
Handle g_hOnGoingLive = INVALID_HANDLE;
Handle g_hOnLive = INVALID_HANDLE;
Handle g_hOnMatchOver = INVALID_HANDLE;
Handle g_hOnNotPicked = INVALID_HANDLE;
Handle g_hOnReady = INVALID_HANDLE;
Handle g_hOnSetup = INVALID_HANDLE;
Handle g_hOnUnready = INVALID_HANDLE;

#include "pugsetup/captainpickmenus.sp"
#include "pugsetup/configreader.sp"
#include "pugsetup/generic.sp"
#include "pugsetup/leadermenus.sp"
#include "pugsetup/liveon3.sp"
#include "pugsetup/maps.sp"
#include "pugsetup/mapveto.sp"
#include "pugsetup/mapvote.sp"
#include "pugsetup/natives.sp"
#include "pugsetup/setupmenus.sp"



/***********************
 *                     *
 * Sourcemod overrides *
 *                     *
 ***********************/

public Plugin:myinfo = {
    name = "CS:GO PugSetup",
    author = "splewis",
    description = "Tools for setting up pugs/10mans",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");
    LoadTranslations("pugsetup.phrases");

    /** ConVars **/
    g_hAdminFlag = CreateConVar("sm_pugsetup_admin_flag", "b", "Admin flag to mark players as having elevated permissions - e.g. can always pause,setup,end the game, etc.");
    g_hAlways5v5 = CreateConVar("sm_pugsetup_always_5v5", "0", "Set to 1 to make the team sizes always 5v5 and not give a .setup option to set team sizes.");
    g_hAnyCanPause = CreateConVar("sm_pugsetup_any_can_pause", "0", "Whether everyone can pause, or just captains/leader");
    g_hAutoRandomizeCaptains = CreateConVar("sm_pugsetup_auto_randomize_captains", "0", "When games are using captains, should they be automatically randomized once? Note you can still manually set them or use .rand/!rand to redo the randomization.");
    g_hAutorecord = CreateConVar("sm_pugsetup_autorecord", "0", "Should the plugin attempt to record a gotv demo each game, requries tv_enable 1 to work");
    g_hDemoNameFormat = CreateConVar("sm_pugsetup_demo_name_format", "pug_{MAP}_{TIME}", "Naming scheme for demos. You may use {MAP}, {TIME}, and {TEAMSIZE}. Make sure there are no spaces or colons in this.");
    g_hDemoTimeFormat = CreateConVar("sm_pugsetup_time_format", "%Y-%m-%d_%H", "Time format to use when creating demo file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");
    g_hExcludeSpectators = CreateConVar("sm_pugsetup_exclude_spectators", "0", "Whether to exclude spectators in the ready-up counts. Setting this to 1 will exclude specators from being selected by captains, as well.");
    g_hExecDefaultConfig = CreateConVar("sm_pugsetup_exec_default_game_config", "1", "Whether gamemode_competitive (the matchmaking config) should be executed before the live config.");
    g_hMapVoteTime = CreateConVar("sm_pugsetup_mapvote_time", "20", "How long the map vote should last if using map-votes", _, true, 10.0);
    g_hMessagePrefix = CreateConVar("sm_pugsetup_message_prefix", "[{YELLOW}PugSetup{NORMAL}]", "The tag applied before plugin messages. If you want no tag, you should use an single space \" \" to ensure colors work correctly");
    g_hMutualUnpause = CreateConVar("sm_pugsetup_mutual_unpausing", "0", "Whether an unpause command requires someone from both teams to fully unpause the match. Note that this cvar will let anybody use the !unpause command.");
    g_hNeverAutoLO3 = CreateConVar("sm_pugsetup_never_autolo3", "0", "Set to 1 to always use auto-lo3=disabled, otherwise it is an option in the setup menu.");
    g_hQuickRestarts = CreateConVar("sm_pugsetup_quick_restarts", "0", "If set to 1, going live won't restart 3 times and will just do a single restart.");
    g_hRandomizeMapOrder = CreateConVar("sm_pugsetup_randomize_maps", "1", "When maps are shown in the map vote/veto, should their order be randomized?");
    g_hRequireAdminToSetup = CreateConVar("sm_pugsetup_requireadmin", "0", "If a client needs the sm_pugsetup_admin_flag flag to use the .setup command.");
    g_hSnakeCaptains = CreateConVar("sm_pugsetup_snake_captain_picks", "0", "Whether captains will pick players in a \"snaked\" fashion rather than alternating, e.g. ABBAABBA rather than ABABABAB.");
    g_hWarmupCfg = CreateConVar("sm_pugsetup_warmup_cfg", "sourcemod/pugsetup/warmup.cfg", "Config file to run before/after games; should be in the csgo/cfg directory.");

    /** Create and exec plugin's configuration file **/
    AutoExecConfig(true, "pugsetup", "sourcemod/pugsetup");

    g_hCvarVersion = CreateConVar("sm_pugsetup_version", PLUGIN_VERSION, "Current pugsetup version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    SetConVarString(g_hCvarVersion, PLUGIN_VERSION);

    /** Commands **/
    RegConsoleCmd("sm_ready", Command_Ready, "Marks the client as ready");
    RegConsoleCmd("sm_notready", Command_Unready, "Marks the client as not ready");
    RegConsoleCmd("sm_unready", Command_Unready, "Marks the client as not ready");
    RegConsoleCmd("sm_setup", Command_Setup, "Starts pug setup (.ready, .capt commands become avaliable)");
    RegConsoleCmd("sm_10man", Command_10man, "Starts 10man setup (alias for .setup with 10 man/gather settings)");
    RegConsoleCmd("sm_lo3", Command_LO3, "Restarts the game with a lo3 (generally this command is not neeeded!)");
    RegConsoleCmd("sm_start", Command_Start, "Starts the game if auto-lo3 is disabled");
    RegConsoleCmd("sm_rand", Command_Rand, "Sets random captains");
    RegConsoleCmd("sm_pause", Command_Pause, "Pauses the game");
    RegConsoleCmd("sm_unpause", Command_Unpause, "Unpauses the game");
    RegConsoleCmd("sm_endgame", Command_EndGame, "Pre-emptively ends the match");
    RegConsoleCmd("sm_endmatch", Command_EndGame, "Pre-emptively ends the match");
    RegConsoleCmd("sm_forceend", Command_ForceEnd, "Pre-emptively ends the match, without any confirmation menu");
    RegConsoleCmd("sm_leader", Command_Leader, "Sets the pug leader");
    RegConsoleCmd("sm_capt", Command_Capt, "Gives the client a menu to pick captains");
    RegConsoleCmd("sm_captain", Command_Capt, "Gives the client a menu to pick captains");
    RegConsoleCmd("sm_pugmaps", Command_ListPugMaps, "Lists maps for the current gametype");

    /** Hooks **/
    HookEvent("cs_win_panel_match", Event_MatchOver);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);

    g_hOnGoingLive = CreateGlobalForward("OnGoingLive", ET_Ignore);
    g_hOnLive = CreateGlobalForward("OnLive", ET_Ignore);
    g_hOnMatchOver = CreateGlobalForward("OnMatchOver", ET_Ignore, Param_Cell, Param_String);
    g_hOnNotPicked = CreateGlobalForward("OnNotPicked", ET_Ignore, Param_Cell);
    g_hOnReady = CreateGlobalForward("OnReady", ET_Ignore, Param_Cell);
    g_hOnSetup = CreateGlobalForward("OnSetup", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOnUnready = CreateGlobalForward("OnUnready", ET_Ignore, Param_Cell);

    g_LiveTimerRunning = false;
}


public bool OnClientConnect(int client, char rejectmsg[], int maxlen) {
    g_Teams[client] = CS_TEAM_NONE;
    g_Ready[client] = false;
    g_PlayerAtStart[client] = false;
    return true;
}

public OnClientDisconnect(int client) {
    g_Teams[client] = CS_TEAM_NONE;
    g_Ready[client] = false;
    g_PlayerAtStart[client] = false;
    int numPlayers = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsPlayer(i))
            numPlayers++;

    if (numPlayers == 0 && (g_MapType != MapType_Vote || g_MapType != MapType_Veto || !g_mapSet || g_MatchLive)) {
        EndMatch(true);
    }
}

public OnMapStart() {
    Config_MapStart();
    g_MapNames = CreateArray(PLATFORM_MAX_PATH);
    g_MapVetoed = CreateArray();
    g_Recording = false;

    for (int i = 1; i <= MaxClients; i++) {
        g_Ready[i] = false;
        g_Teams[i] = -1;
    }

    if (g_mapSet) {
        ExecCfg(g_hWarmupCfg);
        g_Setup = true;
        if (!g_LiveTimerRunning) {
            CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            g_LiveTimerRunning = true;
        }
    } else {
        g_capt1 = -1;
        g_capt2 = -1;
        g_Leader = -1;
    }
}

public OnMapEnd() {
    Config_MapEnd();
    CloseHandle(g_MapNames);
    CloseHandle(g_MapVetoed);
}

public Action Timer_CheckReady(Handle timer) {
    if (!g_Setup || g_MatchLive || !g_LiveTimerRunning) {
        g_LiveTimerRunning = false;
        return Plugin_Stop;
    }

    int readyPlayers = 0;
    int totalPlayers = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            int team = GetClientTeam(i);
            if (GetConVarInt(g_hExcludeSpectators) == 0 || team == CS_TEAM_CT || team == CS_TEAM_T) {
                totalPlayers++;
                if (g_Ready[i]) {
                    CS_SetClientClanTag(i, "[Ready]");
                    readyPlayers++;
                } else {
                    CS_SetClientClanTag(i, "[Not ready]");
                }
            }
        }
    }

    // beware: scary spaghetti code ahead
    if (readyPlayers == totalPlayers && readyPlayers >= 2 * g_PlayersPerTeam) {
        if (g_mapSet) {
            if (g_TeamType == TeamType_Captains) {
                if (IsPlayer(g_capt1) && IsPlayer(g_capt2) && g_capt1 != g_capt2) {
                    CreateTimer(1.0, StartPicking, _, TIMER_FLAG_NO_MAPCHANGE);
                    g_LiveTimerRunning = false;
                    return Plugin_Stop;
                } else {
                    StatusHint(readyPlayers, totalPlayers);
                }
            } else {
                g_LiveTimerRunning = false;
                ReadyToStart();
                return Plugin_Stop;
            }

        } else {
            if (g_MapType == MapType_Veto) {
                if (IsPlayer(g_capt1) && IsPlayer(g_capt2) && g_capt1 != g_capt2) {
                    PugSetupMessageToAll("%t", "VetoMessage");
                    CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
                    g_LiveTimerRunning = false;
                    return Plugin_Stop;
                } else {
                    StatusHint(readyPlayers, totalPlayers);
                }

            } else {
                PugSetupMessageToAll("%t", "VoteMessage");
                CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
                g_LiveTimerRunning = false;
                return Plugin_Stop;
            }
        }

    } else {
        StatusHint(readyPlayers, totalPlayers);
    }

    return Plugin_Continue;
}

public void StatusHint(int readyPlayers, int totalPlayers) {
    if (!g_mapSet && g_MapType != MapType_Veto) {
        PrintHintTextToAll("%t", "ReadyStatus", readyPlayers, totalPlayers);
    } else {
        if (g_TeamType == TeamType_Captains || g_MapType == MapType_Veto) {
            char cap1[64];
            char cap2[64];
            if (IsPlayer(g_capt1))
                Format(cap1, sizeof(cap1), "%N", g_capt1);
            else
                Format(cap1, sizeof(cap1), "%t", "CaptainNotSelected");

            if (IsPlayer(g_capt2))
                Format(cap2, sizeof(cap2), "%N", g_capt2);
            else
                Format(cap2, sizeof(cap2), "%t", "CaptainNotSelected");

            PrintHintTextToAll("%t", "ReadyStatusCaptains", readyPlayers, totalPlayers, cap1, cap2);
        } else {
            PrintHintTextToAll("%t", "ReadyStatus", readyPlayers, totalPlayers);
        }

    }
}



/***********************
 *                     *
 *     Commands        *
 *                     *
 ***********************/

// PermissionCheck(Permissions:permissions)
#define PermissionCheck(%1) \
if (!HasPermissions(client, %1)) { \
    if (IsValidClient(client)) \
        PugSetupMessage(client, "%t", "NoPermission"); \
    return Plugin_Handled; \
}

public Action Command_Setup(int client, args) {
    if (g_MatchLive) {
        PugSetupMessage(client, "%t", "AlreadyLive");
        return Plugin_Handled;
    }

    if (g_Setup && client != GetLeader()) {
        PrintSetupInfo(client);
        return Plugin_Handled;
    }

    if (GetConVarInt(g_hRequireAdminToSetup) != 0 && !IsPugAdmin(client)) {
        PugSetupMessage(client, "%t", "NoPermission");
        return Plugin_Handled;
    }

    g_PickingPlayers = false;
    g_capt1 = -1;
    g_capt2 = -1;
    g_Setup = true;
    if (IsPlayer(client))
        g_Leader = GetSteamAccountID(client);

    for (int i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    SetupMenu(client);
    return Plugin_Handled;
}

public Action Command_10man(int client, args) {
    if (g_MatchLive) {
        PugSetupMessage(client, "%t", "AlreadyLive");
        return Plugin_Handled;
    }

    if (g_Setup && client != GetLeader()) {
        PrintSetupInfo(client);
        return Plugin_Handled;
    }

    if (GetConVarInt(g_hRequireAdminToSetup) != 0 && !IsPugAdmin(client)) {
        PugSetupMessage(client, "%t", "NoPermission");
        return Plugin_Handled;
    }

    g_PickingPlayers = false;
    g_capt1 = -1;
    g_capt2 = -1;
    g_Setup = true;
    if (IsPlayer(client))
        g_Leader = GetSteamAccountID(client);

    for (int i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    SetupGame(0, TeamType_Captains, MapType_Vote, 5, false);
    return Plugin_Handled;
}

public Action Command_Rand(int client, args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    if (g_TeamType != TeamType_Captains && g_MapType != MapType_Veto) {
        PugSetupMessage(client, "%t", "NotUsingCaptains");
        return Plugin_Handled;
    }

    PermissionCheck(Permission_Captains)
    SetRandomCaptains();
    return Plugin_Handled;
}

public Action Command_Capt(int client, args) {
    if (!g_Setup || g_MatchLive || g_PickingPlayers)
        return Plugin_Handled;

    if (g_TeamType != TeamType_Captains && g_MapType != MapType_Veto) {
        PugSetupMessage(client, "%t", "NotUsingCaptains");
        return Plugin_Handled;
    }

    PermissionCheck(Permission_Leader)

    char buffer[64];
    if (args != 0 && GetCmdArgs() >= 1) {

        GetCmdArg(1, buffer, sizeof(buffer));
        int target = FindTarget(client, buffer, true, false);
        SetCaptain(1, target);

        if (GetCmdArgs() >= 2) {
            GetCmdArg(2, buffer, sizeof(buffer));
            target = FindTarget(client, buffer, true, false);
            SetCaptain(2, target);
        } else {
            Captain2Menu(client);
        }

    } else {
        Captain1Menu(client);
    }
    return Plugin_Handled;
}

public Action Command_LO3(int client, args) {
    if (!g_Setup || g_MatchLive || !g_mapSet || g_LiveTimerRunning)
            return Plugin_Handled;

    PermissionCheck(Permission_Leader)

    for (int i = 0; i < 5; i++)
        PugSetupMessageToAll("%t", "LO3Message");
    CreateTimer(2.0, BeginLO3, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Handled;
}

public Action Command_Start(int client, args) {
    if (!g_Setup || g_MatchLive || !g_mapSet || g_LiveTimerRunning)
            return Plugin_Handled;

    PermissionCheck(Permission_Leader)

    if (GetConVarInt(g_hAutorecord) != 0) {
        // get the map, with any workshop stuff before removed
        // this is {MAP} in the format string
        char mapName[128];
        GetCurrentMap(mapName, sizeof(mapName));
        int last_slash = 0;
        int len = strlen(mapName);
        for (int i = 0;  i < len; i++) {
            if (mapName[i] == '/' || mapName[i] == '\\')
                last_slash = i + 1;
        }

        // get the time, this is {TIME} in the format string
        char timeFormat[64];
        GetConVarString(g_hDemoTimeFormat, timeFormat, sizeof(timeFormat));
        int timeStamp = GetTime();
        char formattedTime[64];
        FormatTime(formattedTime, sizeof(formattedTime), timeFormat, timeStamp);

        // get the player count, this is {TEAMSIZE} in the format string
        char playerCount[8];
        IntToString(g_PlayersPerTeam, playerCount, sizeof(playerCount));

        // create the actual demo name to use
        char demoName[256];
        GetConVarString(g_hDemoNameFormat, demoName, sizeof(demoName));

        ReplaceString(demoName, sizeof(demoName), "{MAP}", mapName[last_slash], false);
        ReplaceString(demoName, sizeof(demoName), "{TEAMSIZE}", playerCount, false);
        ReplaceString(demoName, sizeof(demoName), "{TIME}", formattedTime, false);

        ServerCommand("tv_record \"%s\"", demoName);
        LogMessage("Recording to %s", demoName);
        Format(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
        g_Recording = true;
    }

    if (GetConVarInt(g_hExecDefaultConfig) != 0)
        ServerCommand("exec gamemode_competitive");

    char liveCfg[CONFIG_STRING_LENGTH];
    GetArrayString(g_GameConfigFiles, g_GameTypeIndex, liveCfg, sizeof(liveCfg));
    ServerCommand("exec %s", liveCfg);

    for (int i = 1; i <= MaxClients; i++) {
        g_PlayerAtStart[i] = IsPlayer(i);
    }


    g_MatchLive = true;
    if (g_TeamType == TeamType_Random) {
        PugSetupMessageToAll("%t", "Scrambling");
        ServerCommand("mp_scrambleteams");
    }

    for (int i = 0; i < 5; i++)
        PugSetupMessageToAll("%t", "LO3Message");
    CreateTimer(7.0, BeginLO3, _, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Handled;
}

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] sArgs, int client) {
    if (IsPrefix(sArgs, alias)) {
        char text[255];
        SplitStringRight(sArgs, alias, text, sizeof(text));
        FakeClientCommand(client, "%s %s", command, text);
        return true;
    }
    return false;
}

public Action OnClientSayCommand(client, const char command[], const char sArgs[]) {
    char aliases[][][] = {
        {".setup", "sm_setup"},
        {".10man", "sm_10man"},
        {".start", "sm_start"},
        {".endgame", "sm_endmatch"},
        {".endmatch", "sm_endmatch"},
        {".forceend", "sm_forceend"},
        {".cancel", "sm_endmatch"},
        {".capt", "sm_capt"},
        {".captain", "sm_capt"},
        {".leader", "sm_leader"},
        {".rand", "sm_rand"},
        {".gaben", "sm_ready"},
        {".ready", "sm_ready"},
        {".gs4lyfe", "sm_ready"},
        {".splewis", "sm_ready"},
        {".unready", "sm_unready"},
        {".notready", "sm_unready"},
        {".pause", "sm_pause"},
        {".unpause", "sm_unpause"}
    };

    for (int i = 0; i < sizeof(aliases); i++) {
        if (CheckChatAlias(aliases[i][0], aliases[i][1], sArgs, client))
            break;
    }

    // there is no sm_help command since we don't want override the built-in sm_help command
    if (StrEqual(sArgs[0], ".help")) {
        PugSetupMessage(client, "{GREEN}Useful commands:");
        PugSetupMessage(client, "  {LIGHT_GREEN}!setup {NORMAL}begins the setup phase");
        PugSetupMessage(client, "  {LIGHT_GREEN}!start {NORMAL}starts the match if needed");
        PugSetupMessage(client, "  {LIGHT_GREEN}!endgame {NORMAL}ends the match");
        PugSetupMessage(client, "  {LIGHT_GREEN}!leader {NORMAL}allows you to set the game leader");
        PugSetupMessage(client, "  {LIGHT_GREEN}!capt {NORMAL}allows you to set team captains");
        PugSetupMessage(client, "  {LIGHT_GREEN}!rand {NORMAL}selects random captains");
        PugSetupMessage(client, "  {LIGHT_GREEN}!ready/!unready {NORMAL}mark you as ready");
        PugSetupMessage(client, "  {LIGHT_GREEN}!pause/!unpause {NORMAL}pause the match");
    }

    // continue normally
    return Plugin_Continue;
}

public Action Command_EndGame(int client, args) {
    if (!g_Setup) {
        PugSetupMessage(client, "%t", "NotLiveYet");
    } else {
        PermissionCheck(Permission_Leader)

        Handle menu = CreateMenu(MatchEndHandler);
        SetMenuTitle(menu, "%t", "EndMatchMenuTitle");
        SetMenuExitButton(menu, true);
        AddMenuBool(menu, false, "%t", "ContinueMatch");
        AddMenuBool(menu, true, "%t", "EndMatch");
        DisplayMenu(menu, client, 20);
    }
    return Plugin_Handled;
}

public MatchEndHandler(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        if (choice) {
            PugSetupMessageToAll("%t", "ForceEnd", client);
            EndMatch(true);
        }
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public Action Command_ForceEnd(int client, args) {
    PermissionCheck(Permission_Leader)
    PugSetupMessageToAll("%t", "ForceEnd", client);
    EndMatch(true);
    return Plugin_Handled;
}

public Action Command_Pause(int client, args) {
    bool paused = bool:GameRules_GetProp("m_bMatchWaitingForResume");
    if (!g_Setup || !g_MatchLive || paused)
        return Plugin_Handled;

    if (GetConVarInt(g_hAnyCanPause) != 0)
        PermissionCheck(Permission_Captains)

    g_ctUnpaused = false;
    g_tUnpaused = false;
    ServerCommand("mp_pause_match");
    if (IsPlayer(client)) {
        PugSetupMessageToAll("%t", "Pause", client);
    }

    return Plugin_Handled;
}

public Action Command_Unpause(int client, args) {
    bool paused = bool:GameRules_GetProp("m_bMatchWaitingForResume");
    if (!g_Setup || !g_MatchLive || !paused)
        return Plugin_Handled;

    if (GetConVarInt(g_hMutualUnpause) == 0) {
        if (GetConVarInt(g_hAnyCanPause) != 0)
            PermissionCheck(Permission_Captains)

        ServerCommand("mp_unpause_match");
        if (IsPlayer(client)) {
            PugSetupMessageToAll("%t", "Unpause", client);
        }
    } else {
        // Let console force unpause
        if (!IsPlayer(client)) {
            ServerCommand("mp_unpause_match");
        } else {
            int team = GetClientTeam(client);
            if (team == CS_TEAM_T)
                g_tUnpaused = true;
            else if (team == CS_TEAM_CT)
                g_ctUnpaused = true;

            if (g_tUnpaused && g_ctUnpaused)  {
                ServerCommand("mp_unpause_match");
            } else if (g_tUnpaused && !g_ctUnpaused) {
                PugSetupMessageToAll("%t", "MutualUnpauseMessage", "T", "CT");
            } else if (!g_tUnpaused && g_ctUnpaused) {
                PugSetupMessageToAll("%t", "MutualUnpauseMessage", "CT", "T");
            }
        }
    }

    return Plugin_Handled;
}

public Action Command_Ready(int client, args) {
    ReadyPlayer(client);
    return Plugin_Handled;
}

public Action Command_Unready(int client, args) {
    UnreadyPlayer(client);
    return Plugin_Handled;
}

public Action Command_Leader(int client, args) {
    if (!g_Setup)
        return Plugin_Handled;

    PermissionCheck(Permission_Leader)

    char buffer[64];
    if (args != 0 && GetCmdArgs() >= 1) {
        GetCmdArg(1, buffer, sizeof(buffer));
        int target = FindTarget(client, buffer, true, false);
        if (IsPlayer(target))
            SetLeader(target);
    } else {
        LeaderMenu(client);
    }

    return Plugin_Handled;
}



/***********************
 *                     *
 *       Events        *
 *                     *
 ***********************/

public Action Event_MatchOver(Handle event, const char name[], bool dontBroadcast) {
    if (g_MatchLive) {
        CreateTimer(15.0, Timer_EndMatch);
        ExecCfg(g_hWarmupCfg);
    }
    return Plugin_Continue;
}

/** Helper timer to delay starting warmup period after match is over by a little bit **/
public Action Timer_EndMatch(Handle timer) {
    EndMatch(false);
}

/**
 * Called when a player joins a team, silences team join events during player selection.
 */
public Action Event_PlayerTeam(Handle event, const char name[], bool dontBroadcast)  {
    if (g_Setup && !g_MatchLive) {
        dontBroadcast = true;
        return Plugin_Changed;
    } else {
        return Plugin_Continue;
    }
}



/***********************
 *                     *
 *   Pugsetup logic    *
 *                     *
 ***********************/

public void PrintSetupInfo(int client) {
    if (IsPlayer(GetLeader()))
        PugSetupMessage(client, "%t", "SetupBy", GetLeader());

    char buffer[128];
    GetArrayString(g_GameTypes, g_GameTypeIndex, buffer, sizeof(buffer));
    PugSetupMessage(client, "%t", "GameType", buffer);

    GetTeamString(buffer, sizeof(buffer), g_TeamType);
    PugSetupMessage(client, "%t", "TeamType", g_PlayersPerTeam, g_PlayersPerTeam, buffer);

    GetMapString(buffer, sizeof(buffer), g_MapType);
    PugSetupMessage(client, "%t", "MapType", buffer);

    GetEnabledString(buffer, sizeof(buffer), g_AutoLO3);
    PugSetupMessage(client, "%t", "LO3Setting", buffer);
}

public void ReadyToStart() {
    if (g_AutoLO3) {
        Command_Start(0, 0);
    } else {
        PugSetupMessageToAll("%t", "ReadyToStart", GetLeader());
    }
}

public void EndMatch(bool execConfigs) {
    if (g_Recording) {
        CreateTimer(4.0, StopDemo, _, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        Call_StartForward(g_hOnMatchOver);
        Call_PushCell(false);
        Call_PushString("");
        Call_Finish();
    }

    for (new i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i))
            CS_SetClientClanTag(i, "");
    }

    ServerCommand("mp_unpause_match");
    if (g_MatchLive && execConfigs)
        ExecCfg(g_hWarmupCfg);

    g_LiveTimerRunning = false;
    g_Leader = -1;
    g_capt1 = -1;
    g_capt2 = -1;
    g_mapSet = false;
    g_Setup = false;
    g_MatchLive = false;
}

public Action MapSetup(Handle timer) {
    if (g_MapType == MapType_Vote) {
        CreateMapVote();
    } else if (g_MapType == MapType_Veto) {
        CreateMapVeto();
    } else {
        LogError("Unexpected map type in MapSetup=%d", g_MapType);
    }
    return Plugin_Handled;
}

public Action StartPicking(Handle timer) {
    ServerCommand("mp_pause_match");
    ServerCommand("mp_restartgame 1");

    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            g_Teams[i] = CS_TEAM_SPECTATOR;
            SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
        }
    }

    // temporary teams
    SwitchPlayerTeam(g_capt2, CS_TEAM_CT);
    SwitchPlayerTeam(g_capt1, CS_TEAM_T);
    InitialChoiceMenu(g_capt1);
    return Plugin_Handled;
}

public Action FinishPicking(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            if (g_Teams[i] == CS_TEAM_NONE) {
                SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
                Call_StartForward(g_hOnNotPicked);
                Call_PushCell(i);
                Call_Finish();
            } else {
                SwitchPlayerTeam(i, g_Teams[i]);
            }
        }
    }

    ServerCommand("mp_unpause_match");
    ReadyToStart();
    return Plugin_Handled;
}

public Action StopDemo(Handle timer) {
    ServerCommand("tv_stoprecord");
    g_Recording = false;
    Call_StartForward(g_hOnMatchOver);
    Call_PushCell(true);
    Call_PushString(g_DemoFileName);
    Call_Finish();
    return Plugin_Handled;
}
