#include <cstrike>
#include <sourcemod>
#include <sdktools>
#include "include/logdebug.inc"
#include "include/pugsetup.inc"

#undef REQUIRE_EXTENSIONS
#include "include/system2.inc"

#undef REQUIRE_PLUGIN
#include "include/updater.inc"
#define UPDATE_URL "https://dl.dropboxusercontent.com/u/76035852/csgo-pug-setup/csgo-pug-setup.txt"

#define ALIAS_LENGTH 64
#define COMMAND_LENGTH 64

#pragma semicolon 1
#pragma newdecls required

/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/** ConVar handles **/
ConVar g_hAdminFlag;
ConVar g_hAnnounceCountdown;
ConVar g_hAnyCanPause;
ConVar g_hAutoRandomizeCaptains;
ConVar g_hAutoSetup;
ConVar g_hAutoUpdate;
ConVar g_hCvarVersion;
ConVar g_hDemoNameFormat;
ConVar g_hDemoTimeFormat;
ConVar g_hExcludeSpectators;
ConVar g_hExecDefaultConfig;
ConVar g_hForceDefaults;
ConVar g_hLiveCfg;
ConVar g_hMapList;
ConVar g_hMapVoteTime;
ConVar g_hMaxTeamSize;
ConVar g_hMessagePrefix;
ConVar g_hMutualUnpause;
ConVar g_hQuickRestarts;
ConVar g_hRandomizeMapOrder;
ConVar g_hRequireAdminToSetup;
ConVar g_hSnakeCaptains;
ConVar g_hStartDelay;
ConVar g_hWarmupCfg;

/** Setup menu options **/
bool g_DisplayMapType = true;
bool g_DisplayTeamType = true;
bool g_DisplayAutoLive = true;
bool g_DisplayKnifeRound = true;
bool g_DisplayTeamSize = true;
bool g_DisplayRecordDemo = true;
bool g_DisplayMapChange = false;

/** Setup info **/
int g_Leader = -1;
ArrayList g_MapList;
bool g_ForceEnded = false;

// Specific choices made when setting up
int g_PlayersPerTeam = 5;
TeamType g_TeamType = TeamType_Captains;
MapType g_MapType = MapType_Vote;
bool g_RecordGameOption = false;
bool g_DoKnifeRound = false;
bool g_AutoLive = true;

// Other important variables about the state of the game
bool g_Setup = false;
bool g_MapSet = false; // whether we're on the map that is going to be used
bool g_SwitchingMaps = false; // if we're in the middle of a map change
bool g_Recording = true;
char g_DemoFileName[PLATFORM_MAX_PATH];
bool g_LiveTimerRunning = false;
int g_CountDownTicks = 0;
bool g_ForceStartSignal = false;
bool g_WaitingForStartCommand = false;

#define CAPTAIN_COMMAND_HINT_TIME 15
#define START_COMMAND_HINT_TIME 15
int g_LastCaptainHintTime = 0;

// Pause information
bool g_ctUnpaused = false;
bool g_tUnpaused = false;

/** Stuff for workshop map/collection cache **/
char g_DataDir[PLATFORM_MAX_PATH]; // directory to leave cache files in
char g_CacheFile[PLATFORM_MAX_PATH]; // filename of the keyvalue cache file
KeyValues g_WorkshopCache; // keyvalue struct for the cache

/** Chat aliases loaded **/
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

/** Permissions **/
StringMap g_PermissionsMap;
ArrayList g_Commands; // just a list of all known pugsetup commands

/** Map-choosing variables **/
ArrayList g_MapVetoed;
int g_ChosenMap = -1;

/** Data about team selections **/
int g_capt1 = -1;
int g_capt2 = -1;
int g_Teams[MAXPLAYERS+1];
bool g_Ready[MAXPLAYERS+1];
bool g_PlayerAtStart[MAXPLAYERS+1];
bool g_PickingPlayers = false;
bool g_MatchLive = false;
bool g_InStartPhase = false;

/** Knife round data **/
bool g_WaitingForKnifeWinner = false;
bool g_WaitingForKnifeDecision = false;
int g_KnifeWinner = -1;

/** Forwards **/
Handle g_hOnForceEnd = INVALID_HANDLE;
Handle g_hOnGoingLive = INVALID_HANDLE;
Handle g_hOnLive = INVALID_HANDLE;
Handle g_hOnLiveCfg = INVALID_HANDLE;
Handle g_hOnLiveCheck = INVALID_HANDLE;
Handle g_hOnMapListRead = INVALID_HANDLE;
Handle g_hOnMatchOver = INVALID_HANDLE;
Handle g_hOnNotPicked = INVALID_HANDLE;
Handle g_hOnPermissionCheck = INVALID_HANDLE;
Handle g_hOnPlayerAddedToCaptainMenu = INVALID_HANDLE;
Handle g_hOnReady = INVALID_HANDLE;
Handle g_hOnReadyToStart = INVALID_HANDLE;
Handle g_hOnSetup = INVALID_HANDLE;
Handle g_hOnSetupMenuOpen = INVALID_HANDLE;
Handle g_hOnSetupMenuSelect = INVALID_HANDLE;
Handle g_hOnStartRecording = INVALID_HANDLE;
Handle g_hOnUnready = INVALID_HANDLE;
Handle g_hOnWarmupCfg = INVALID_HANDLE;

#include "pugsetup/captainpickmenus.sp"
#include "pugsetup/configs.sp"
#include "pugsetup/generic.sp"
#include "pugsetup/kniferounds.sp"
#include "pugsetup/leadermenus.sp"
#include "pugsetup/liveon3.sp"
#include "pugsetup/maps.sp"
#include "pugsetup/mapveto.sp"
#include "pugsetup/mapvote.sp"
#include "pugsetup/natives.sp"
#include "pugsetup/setupmenus.sp"
#include "pugsetup/steamapi.sp"



/***********************
 *                     *
 * Sourcemod forwards  *
 *                     *
 ***********************/

public Plugin myinfo = {
    name = "CS:GO PugSetup",
    author = "splewis",
    description = "Tools for setting up pugs/10mans",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    InitDebugLog(DEBUG_CVAR, "pugsetup");
    LoadTranslations("common.phrases");
    LoadTranslations("pugsetup.phrases");

    /** ConVars **/
    g_Commands = new ArrayList(COMMAND_LENGTH);
    g_hAdminFlag = CreateConVar("sm_pugsetup_admin_flag", "b", "Admin flag to mark players as having elevated permissions - e.g. can always pause,setup,end the game, etc.");
    g_hAnnounceCountdown = CreateConVar("sm_pugsetup_announce_countdown_timer", "1", "Whether to announce how long the countdown has left before the lo3 begins.");
    g_hAnyCanPause = CreateConVar("sm_pugsetup_any_can_pause", "1", "Whether everyone can pause, or just captains/leader. Note: if sm_pugsetup_mutual_unpausing is set to 1, this cvar is ignored");
    g_hAutoRandomizeCaptains = CreateConVar("sm_pugsetup_auto_randomize_captains", "0", "When games are using captains, should they be automatically randomized once? Note you can still manually set them or use .rand/!rand to redo the randomization.");
    g_hAutoSetup = CreateConVar("sm_pugsetup_autosetup", "0", "Whether a pug is automatically setup using the default setup options or not.");
    g_hAutoUpdate = CreateConVar("sm_pugsetup_autoupdate", "1", "Whether the plugin may (if the \"Updater\" plugin is loaded) automatically update.");
    g_hDemoNameFormat = CreateConVar("sm_pugsetup_demo_name_format", "pug_{MAP}_{TIME}", "Naming scheme for demos. You may use {MAP}, {TIME}, and {TEAMSIZE}. Make sure there are no spaces or colons in this.");
    g_hDemoTimeFormat = CreateConVar("sm_pugsetup_time_format", "%Y-%m-%d_%H", "Time format to use when creating demo file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");
    g_hExcludeSpectators = CreateConVar("sm_pugsetup_exclude_spectators", "0", "Whether to exclude spectators in the ready-up counts. Setting this to 1 will exclude specators from being selected by captains as well.");
    g_hExecDefaultConfig = CreateConVar("sm_pugsetup_exec_default_game_config", "1", "Whether gamemode_competitive (the matchmaking config) should be executed before the live config.");
    g_hForceDefaults = CreateConVar("sm_pugsetup_force_defaults", "0", "Whether the default setup options are forced as the setup options (note that admins can override them still).");
    g_hLiveCfg = CreateConVar("sm_pugsetup_live_cfg", "sourcemod/pugsetup/standard.cfg", "Config to execute when the game goes live");
    g_hMapList = CreateConVar("sm_pugsetup_maplist", "standard.txt", "Maplist file in addons/sourcemod/configs/pugsetup to use. You may also use a workshop collection ID instead of a maplist if you have the System2 extension installed.");
    g_hMapVoteTime = CreateConVar("sm_pugsetup_mapvote_time", "20", "How long the map vote should last if using map-votes", _, true, 10.0);
    g_hMaxTeamSize = CreateConVar("sm_pugsetup_max_team_size", "5", "Maximum size of a team when selecting team sizes", _, true, 2.0);
    g_hMessagePrefix = CreateConVar("sm_pugsetup_message_prefix", "[{YELLOW}PugSetup{NORMAL}]", "The tag applied before plugin messages. If you want no tag, you can set an empty string here.");
    g_hMutualUnpause = CreateConVar("sm_pugsetup_mutual_unpausing", "1", "Whether an unpause command requires someone from both teams to fully unpause the match. Note that this cvar will let anybody use the !unpause command.");
    g_hQuickRestarts = CreateConVar("sm_pugsetup_quick_restarts", "0", "If set to 1, going live won't restart 3 times and will just do a single restart.");
    g_hRandomizeMapOrder = CreateConVar("sm_pugsetup_randomize_maps", "1", "When maps are shown in the map vote/veto, whether their order ise randomized.");
    g_hRequireAdminToSetup = CreateConVar("sm_pugsetup_requireadmin", "0", "If a client needs the sm_pugsetup_admin_flag flag to use the .setup command.");
    g_hSnakeCaptains = CreateConVar("sm_pugsetup_snake_captain_picks", "0", "Whether captains will pick players in a \"snaked\" fashion rather than alternating, e.g. ABBAABBA rather than ABABABAB.");
    g_hStartDelay = CreateConVar("sm_pugsetup_start_delay", "10", "How many seconds before the lo3 process should being. You might want to make this longer if you want to move people into teamspeak/mumble channels or similar.", _, true, 0.0, true, 60.0);
    g_hWarmupCfg = CreateConVar("sm_pugsetup_warmup_cfg", "sourcemod/pugsetup/warmup.cfg", "Config file to run before/after games; should be in the csgo/cfg directory.");

    /** Cvars that require dynamic permission changes **/
    HookConVarChange(g_hAnyCanPause, OnCvarChanged);
    HookConVarChange(g_hMutualUnpause, OnCvarChanged);
    HookConVarChange(g_hRequireAdminToSetup, OnCvarChanged);

    /** Create and exec plugin's configuration file **/
    AutoExecConfig(true, "pugsetup", "sourcemod/pugsetup");

    g_hCvarVersion = CreateConVar("sm_pugsetup_version", PLUGIN_VERSION, "Current pugsetup version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    SetConVarString(g_hCvarVersion, PLUGIN_VERSION);

    /** Commands **/
    LoadTranslatedAliases();
    AddPugSetupCommand("ready", Command_Ready, "Marks the client as ready", Permission_All);
    AddPugSetupCommand("notready", Command_NotReady, "Marks the client as not ready", Permission_All);
    AddPugSetupCommand("setup", Command_Setup, "Starts pug setup (.ready, .capt commands become avaliable)", Permission_All);
    AddPugSetupCommand("10man", Command_10man, "Starts 10man setup (alias for .setup with 10 man/gather settings)", Permission_All);
    AddPugSetupCommand("rand", Command_Rand, "Sets random captains", Permission_Captains);
    AddPugSetupCommand("pause", Command_Pause, "Pauses the game", Permission_All);
    AddPugSetupCommand("unpause", Command_Unpause, "Unpauses the game", Permission_All);
    AddPugSetupCommand("endgame", Command_EndGame, "Pre-emptively ends the match", Permission_Leader);
    AddPugSetupCommand("forceend", Command_ForceEnd, "Pre-emptively ends the match, without any confirmation menu", Permission_Leader);
    AddPugSetupCommand("forceready", Command_ForceReady, "Force-readies a player", Permission_Admin);
    AddPugSetupCommand("leader", Command_Leader, "Sets the pug leader", Permission_Leader);
    AddPugSetupCommand("capt", Command_Capt, "Gives the client a menu to pick captains", Permission_Leader);
    AddPugSetupCommand("stay", Command_Stay, "Elects to stay on the current team after winning a knife round", Permission_All);
    AddPugSetupCommand("swap", Command_Swap, "Elects to swap the current teams after winning a knife round", Permission_All);
    AddPugSetupCommand("t", Command_T, "Elects to start on T side after winning a knife round", Permission_All);
    AddPugSetupCommand("ct", Command_Ct, "Elects to start on CT side after winning a knife round", Permission_All);
    AddPugSetupCommand("forcestart", Command_ForceStart, "Force starts the game", Permission_Admin);
    AddPugSetupCommand("addmap", Command_AddMap, "Adds a map to the current maplist", Permission_All);
    AddPugSetupCommand("removemap", Command_RemoveMap, "Removes a map to the current maplist", Permission_All);
    AddPugSetupCommand("listpugmaps", Command_ListPugMaps, "Lists the current maplist", Permission_All);
    AddPugSetupCommand("start", Command_Start, "Lists the current maplist", Permission_Leader);
    AddPugSetupCommand("addalias", Command_AddAlias, "Adds a pugsetup alias, and saves it to the chatalias.cfg file", Permission_Admin);
    AddPugSetupCommand("setdefault", Command_SetDefault, "Sets a default setup option", Permission_Admin);
    AddPugSetupCommand("setdisplay", Command_SetDisplay, "Sets whether a setup option will be displayed", Permission_Admin);

    LoadExtraAliases();

    /** Admin commands for editing configs **/
    /** Hooks **/
    HookEvent("cs_win_panel_match", Event_MatchOver);
    HookEvent("round_end", Event_RoundEnd);

    g_hOnForceEnd = CreateGlobalForward("OnForceEnd", ET_Ignore, Param_Cell);
    g_hOnGoingLive = CreateGlobalForward("OnGoingLive", ET_Ignore);
    g_hOnLive = CreateGlobalForward("OnLive", ET_Ignore);
    g_hOnLiveCfg = CreateGlobalForward("OnLiveCfgExecuted", ET_Ignore);
    g_hOnLiveCheck = CreateGlobalForward("OnReadyToStartCheck", ET_Ignore, Param_Cell, Param_Cell);
    g_hOnMapListRead = CreateGlobalForward("OnMapListRead", ET_Ignore, Param_String, Param_Cell, Param_Cell);
    g_hOnMatchOver = CreateGlobalForward("OnMatchOver", ET_Ignore, Param_Cell, Param_String);
    g_hOnNotPicked = CreateGlobalForward("OnNotPicked", ET_Ignore, Param_Cell);
    g_hOnPermissionCheck = CreateGlobalForward("OnPermissionCheck", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_CellByRef);
    g_hOnPlayerAddedToCaptainMenu = CreateGlobalForward("OnPlayerAddedToCaptainMenu", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
    g_hOnReady = CreateGlobalForward("OnReady", ET_Ignore, Param_Cell);
    g_hOnReadyToStart = CreateGlobalForward("OnReadyToStart", ET_Ignore);
    g_hOnSetup = CreateGlobalForward("OnSetup", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOnSetupMenuOpen = CreateGlobalForward("OnSetupMenuOpen", ET_Single, Param_Cell, Param_Cell, Param_Cell);
    g_hOnSetupMenuSelect = CreateGlobalForward("OnSetupMenuSelect", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOnStartRecording = CreateGlobalForward("OnStartRecording", ET_Ignore, Param_String);
    g_hOnUnready = CreateGlobalForward("OnUnready", ET_Ignore, Param_Cell);
    g_hOnWarmupCfg = CreateGlobalForward("OnWarmupCfgExecuted", ET_Ignore);

    g_LiveTimerRunning = false;
    ReadSetupOptions();

    /** Updater support **/
    if (GetConVarInt(g_hAutoUpdate) != 0) {
        if (LibraryExists("updater")) {
            Updater_AddPlugin(UPDATE_URL);
        }
    }
}

static void AddPugSetupCommand(const char[] command, ConCmd callback, const char[] description, Permissions p) {
    char smCommandBuffer[64];
    Format(smCommandBuffer, sizeof(smCommandBuffer), "sm_%s", command);
    g_Commands.PushString(smCommandBuffer);
    RegConsoleCmd(smCommandBuffer, callback, description);
    SetPermissions(smCommandBuffer, p);

    char dotCommandBuffer[64];
    Format(dotCommandBuffer, sizeof(dotCommandBuffer), ".%s", command);
    AddChatAlias(dotCommandBuffer, smCommandBuffer);
}

public int OnCvarChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    if (cvar == g_hRequireAdminToSetup) {
        bool enabled = g_hRequireAdminToSetup.IntValue != 0;
        Permissions p = enabled ? Permission_Admin : Permission_All;
        SetPermissions("sm_setup", p);
        SetPermissions("sm_10man", p);

    } else if (cvar == g_hAnyCanPause || cvar == g_hMutualUnpause) {
        bool enabled = g_hAnyCanPause.IntValue == 0 && g_hMutualUnpause.IntValue == 0;
        Permissions p = enabled ? Permission_Captains : Permission_All;
        SetPermissions("sm_pause", p);
        SetPermissions("sm_unpause", p);
    }
}

public void OnConfigsExecuted() {
    InitMapSettings();
}

public void OnLibraryAdded(const char[] name) {
    if (GetConVarInt(g_hAutoUpdate) != 0) {
        if (LibraryExists("updater")) {
            Updater_AddPlugin(UPDATE_URL);
        }
    }
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen) {
    g_Teams[client] = CS_TEAM_NONE;
    g_Ready[client] = false;
    g_PlayerAtStart[client] = false;
    CheckAutoSetup();
    return true;
}

public void OnClientDisconnect(int client) {
    g_Teams[client] = CS_TEAM_NONE;
    g_Ready[client] = false;
    g_PlayerAtStart[client] = false;
}

public void OnClientDisconnect_Post(int client) {
    int numPlayers = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsPlayer(i))
            numPlayers++;

    if (numPlayers == 0 && !g_SwitchingMaps) {
        EndMatch(true);
    }
}

public void OnMapStart() {
    if (g_SwitchingMaps) {
        g_MapSet = true;
    }
    g_SwitchingMaps = false;
    g_ForceEnded = false;
    g_MapVetoed = new ArrayList();
    g_Recording = false;
    g_MatchLive = false;
    g_LiveTimerRunning = false;
    g_WaitingForKnifeWinner = false;
    g_WaitingForKnifeDecision = false;
    g_InStartPhase = false;
    g_ForceStartSignal = false;
    g_WaitingForStartCommand = false;

    InitMapSettings();

    for (int i = 1; i <= MaxClients; i++) {
        g_Ready[i] = false;
        g_Teams[i] = CS_TEAM_NONE;
    }

    if (g_Setup) {
        ExecCfg(g_hWarmupCfg);
        g_Setup = true;
        if (!g_LiveTimerRunning) {
            CreateTimer(0.3, Timer_CheckReady, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            g_LiveTimerRunning = true;
        }
    } else {
        g_capt1 = -1;
        g_capt2 = -1;
        g_Leader = -1;
    }
}

public void OnMapEnd() {
    CloseHandle(g_MapVetoed);
}

public bool UsingCaptains() {
    return g_TeamType == TeamType_Captains || g_MapType == MapType_Veto;
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
            UpdateClanTag(i);
            int team = GetClientTeam(i);
            if (g_hExcludeSpectators.IntValue == 0 || team == CS_TEAM_CT || team == CS_TEAM_T) {
                totalPlayers++;
                if (g_Ready[i]) {
                    readyPlayers++;
                }
            }
        }
    }

    // beware: scary spaghetti code ahead
    if ((readyPlayers == totalPlayers && readyPlayers >= 2 * g_PlayersPerTeam) || g_ForceStartSignal)  {
        if (g_MapSet) {
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

    if (g_TeamType == TeamType_Captains && g_hAutoRandomizeCaptains.IntValue != 0 && totalPlayers >= GetPugMaxPlayers()) {
        // re-randomize captains if they aren't set yet
        if (!IsPlayer(g_capt1)) {
            g_capt1 = RandomPlayer();
        }

        while (!IsPlayer(g_capt2) && g_capt1 != g_capt2) {
            if (GetRealClientCount() < 2)
                break;
            g_capt2 = RandomPlayer();
        }

    }

    Call_StartForward(g_hOnLiveCheck);
    Call_PushCell(readyPlayers);
    Call_PushCell(totalPlayers);
    Call_Finish();

    return Plugin_Continue;
}

public void StatusHint(int readyPlayers, int totalPlayers) {
    char rdyCommand[ALIAS_LENGTH];
    FindChatCommand("sm_ready", rdyCommand);
    if (!g_MapSet && g_MapType != MapType_Veto) {
        PrintHintTextToAll("%t", "ReadyStatus", readyPlayers, totalPlayers, rdyCommand);
    } else {
        if (g_TeamType == TeamType_Captains || g_MapType == MapType_Veto) {
            for (int i = 1; i <= MaxClients; i++) {
                if (IsPlayer(i))
                    GiveCaptainHint(i, readyPlayers, totalPlayers);
            }
        } else {
            PrintHintTextToAll("%t", "ReadyStatus", readyPlayers, totalPlayers, rdyCommand);
        }
    }
}

static void GiveCaptainHint(int client, int readyPlayers, int totalPlayers) {
    char cap1[64];
    char cap2[64];
    if (IsPlayer(g_capt1))
        Format(cap1, sizeof(cap1), "%N", g_capt1);
    else
        Format(cap1, sizeof(cap1), "%T", "CaptainNotSelected", client);

    if (IsPlayer(g_capt2))
        Format(cap2, sizeof(cap2), "%N", g_capt2);
    else
        Format(cap2, sizeof(cap2), "%T", "CaptainNotSelected", client);

    PrintHintTextToAll("%t", "ReadyStatusCaptains", readyPlayers, totalPlayers, cap1, cap2);

    // if there aren't any captains and we full players, print the hint telling the leader how to set captains
    if (!IsPlayer(g_capt1) && !IsPlayer(g_capt2) && totalPlayers >= GetPugMaxPlayers()) {
        // but only do it at most every CAPTAIN_COMMAND_HINT_TIME seconds so it doesn't get spammed
        int time = GetTime();
        int dt = time - g_LastCaptainHintTime;
        if (dt >= CAPTAIN_COMMAND_HINT_TIME) {
            g_LastCaptainHintTime = time;
            char cmd[ALIAS_LENGTH];
            FindChatCommand("sm_capt", cmd);
            PugSetupMessageToAll("%t", "SetCaptainsHint", GetLeader(), cmd);
        }
    }
}


/***********************
 *                     *
 *     Commands        *
 *                     *
 ***********************/

// PermissionCheck(int client, const char[] command)
#define PermissionCheck(%1,%2) { \
    Permissions _p = GetPermissions(%2); \
    bool _perm = HasPermissions(%1, _p); \
    char _cmd[COMMAND_LENGTH]; \
    GetCmdArg(0, _cmd, sizeof(_cmd)); \
    Call_StartForward(g_hOnPermissionCheck); \
    Call_PushCell(%1); \
    Call_PushString(_cmd); \
    Call_PushCell(_p); \
    Call_PushCellRef(_perm); \
    Call_Finish(); \
    if (!_perm) { \
        if (IsValidClient(%1)) \
            PugSetupMessage(%1, "%t", "NoPermission"); \
        return Plugin_Handled; \
    } \
}

public Action Command_Setup(int client, int args) {
    if (g_MatchLive) {
        PugSetupMessage(client, "%t", "AlreadyLive");
        return Plugin_Handled;
    }

    if (g_Setup && client != GetLeader() && client != 0) {
        GiveSetupMenu(client, true);
        return Plugin_Handled;
    }

    PermissionCheck(client, "sm_setup")

    g_PickingPlayers = false;
    g_capt1 = -1;
    g_capt2 = -1;
    if (IsPlayer(client))
        g_Leader = GetSteamAccountID(client);

    for (int i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    if (client == 0) {
        // if we did the setup command from the console just use the default settings
        ReadSetupOptions();
        SetupGame(g_TeamType, g_MapType, g_PlayersPerTeam, g_RecordGameOption, g_DoKnifeRound, g_AutoLive);
    } else {
        GiveSetupMenu(client);
    }

    return Plugin_Handled;
}

public Action Command_10man(int client, int args) {
    if (g_MatchLive) {
        PugSetupMessage(client, "%t", "AlreadyLive");
        return Plugin_Handled;
    }

    if (g_Setup && client != GetLeader()) {
        GiveSetupMenu(client, true);
        return Plugin_Handled;
    }

    PermissionCheck(client, "sm_10man")

    g_PickingPlayers = false;
    g_capt1 = -1;
    g_capt2 = -1;
    if (IsPlayer(client))
        g_Leader = GetSteamAccountID(client);

    for (int i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    SetupGame(TeamType_Captains, MapType_Vote, 5);
    return Plugin_Handled;
}

public Action Command_Rand(int client, int args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    if (g_TeamType != TeamType_Captains && g_MapType != MapType_Veto) {
        PugSetupMessage(client, "%t", "NotUsingCaptains");
        return Plugin_Handled;
    }

    PermissionCheck(client, "sm_rand")
    SetRandomCaptains();
    return Plugin_Handled;
}

public Action Command_Capt(int client, int args) {
    if (!g_Setup || g_MatchLive || g_PickingPlayers)
        return Plugin_Handled;

    if (g_TeamType != TeamType_Captains && g_MapType != MapType_Veto) {
        PugSetupMessage(client, "%t", "NotUsingCaptains");
        return Plugin_Handled;
    }

    PermissionCheck(client, "sm_capt")

    char buffer[64];
    if (args != 0 && GetCmdArgs() >= 1) {

        GetCmdArg(1, buffer, sizeof(buffer));
        int target = FindTarget(client, buffer, true, false);
        if (IsPlayer(target))
            SetCaptain(1, target, true);

        if (GetCmdArgs() >= 2) {
            GetCmdArg(2, buffer, sizeof(buffer));
            target = FindTarget(client, buffer, true, false);

            if (IsPlayer(target))
                SetCaptain(2, target, true);

        } else {
            Captain2Menu(client);
        }

    } else {
        Captain1Menu(client);
    }
    return Plugin_Handled;
}

public Action Command_ForceStart(int client, int args) {
    if (!g_Setup || g_MatchLive || g_InStartPhase)
        return Plugin_Handled;

    PermissionCheck(client, "sm_forcestart")
    g_ForceStartSignal = true;
    return Plugin_Handled;
}

public Action Command_ListPugMaps(int client, int args) {
    int n = g_MapList.Length;
    if (n == 0) {
        ReplyToCommand(client, "No maps are in the maplist");
    } else {
        char buffer[PLATFORM_MAX_PATH];
        for (int i = 0; i < n; i++) {
            g_MapList.GetString(i, buffer, sizeof(buffer));
            ReplyToCommand(client, "Map %d: %s", i + 1, buffer);
        }
    }

    return Plugin_Handled;
}

public Action Command_Start(int client, int args) {
    if (!g_Setup || !g_WaitingForStartCommand || g_MatchLive)
        return Plugin_Handled;

    PermissionCheck(client, "sm_start")

    CreateCountDown();
    g_WaitingForStartCommand = false;
    return Plugin_Handled;
}

public void LoadTranslatedAliases() {
    // For each of these sm_x commands, we need the
    // translation phrase sm_x_alias to be present.
    AddTranslatedAlias("sm_capt");
    AddTranslatedAlias("sm_endgame");
    AddTranslatedAlias("sm_notready");
    AddTranslatedAlias("sm_pause");
    AddTranslatedAlias("sm_ready");
    AddTranslatedAlias("sm_setup");
    AddTranslatedAlias("sm_stay");
    AddTranslatedAlias("sm_swap");
    AddTranslatedAlias("sm_unpause");
    AddTranslatedAlias("sm_start");
}

public void LoadExtraAliases() {
    // Read custom user aliases
    ReadChatConfig();

    // Any extra chat aliases we want
    AddChatAlias(".captain", "sm_capt");
    AddChatAlias(".captains", "sm_capt");
    AddChatAlias(".endmatch", "sm_endgame");
    AddChatAlias(".cancel", "sm_endgame");
    AddChatAlias(".gaben", "sm_ready");
    AddChatAlias(".gs4lyfe", "sm_ready");
    AddChatAlias(".splewis", "sm_ready");
    AddChatAlias(".notready", "sm_unready");
    AddChatAlias(".paws", "sm_pause");
    AddChatAlias(".unpaws", "sm_unpause");
}

static void AddTranslatedAlias(const char[] command) {
    char translationName[64];
    Format(translationName, sizeof(translationName), "%s_alias", command);

    char alias[ALIAS_LENGTH];
    Format(alias, sizeof(alias), "%T", translationName, LANG_SERVER);

    AddChatAlias(alias, command);
}

public void FindChatCommand(const char[] command, char alias[ALIAS_LENGTH]) {
    int n = g_ChatAliases.Length;
    char tmpCommand[COMMAND_LENGTH];

    for (int i = 0; i < n; i++) {
        g_ChatAliasesCommands.GetString(i, tmpCommand, sizeof(tmpCommand));

        if (StrEqual(command, tmpCommand)) {
            g_ChatAliases.GetString(i, alias, sizeof(alias));
            return;
        }
    }

    // If we never found one, just use .<command> since it always gets added by AddPugSetupCommand
    Format(alias, sizeof(alias), ".%s", command);
}

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] chatCommand, const char[] chatArgs, int client) {
    if (StrEqual(chatCommand, alias, false)) {
        // This is so any ReplyToCommand logic goes into the chat area and stripts the sm_
        char fakeCommand[256];
        Format(fakeCommand, sizeof(fakeCommand), "%s %s", command, chatArgs);
        FakeClientCommand(client, fakeCommand);
        return true;
    }
    return false;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
    // splits to find the first word to do a chat alias command check
    char chatCommand[COMMAND_LENGTH];
    char chatArgs[255];
    int index = SplitString(sArgs, " ", chatCommand, sizeof(chatCommand));

    if (index == -1) {
        strcopy(chatCommand, sizeof(chatCommand), sArgs);
    } else if (index + 1 < strlen(sArgs)) {
        strcopy(chatArgs, sizeof(chatArgs), sArgs[index]);
    }

    if (chatCommand[0]) {
        char alias[ALIAS_LENGTH];
        char cmd[COMMAND_LENGTH];
        for (int i = 0; i < GetArraySize(g_ChatAliases); i++) {
            GetArrayString(g_ChatAliases, i, alias, sizeof(alias));
            GetArrayString(g_ChatAliasesCommands, i, cmd, sizeof(cmd));

            if (CheckChatAlias(alias, cmd, chatCommand, chatArgs, client)) {
                break;
            }
        }
    }

    if (StrEqual(sArgs[0], ".help")) {
        PugSetupMessage(client, "{GREEN}Useful commands:");
        PugSetupMessage(client, "  {LIGHT_GREEN}.setup {NORMAL}begins the setup phase");
        PugSetupMessage(client, "  {LIGHT_GREEN}.endgame {NORMAL}ends the match");
        PugSetupMessage(client, "  {LIGHT_GREEN}.leader {NORMAL}allows you to set the game leader");
        PugSetupMessage(client, "  {LIGHT_GREEN}.capt {NORMAL}allows you to set team captains");
        PugSetupMessage(client, "  {LIGHT_GREEN}.rand {NORMAL}selects random captains");
        PugSetupMessage(client, "  {LIGHT_GREEN}.ready/.notready {NORMAL}mark you as ready");
        PugSetupMessage(client, "  {LIGHT_GREEN}.pause/.unpause {NORMAL}pause the match");
    }
}

public Action Command_EndGame(int client, int args) {
    if (!g_Setup) {
        PugSetupMessage(client, "%t", "NotLiveYet");
    } else {
        PermissionCheck(client, "sm_endgame")

        // bypass the menu if console does it
        if (client == 0) {
            Call_StartForward(g_hOnForceEnd);
            Call_PushCell(client);
            Call_Finish();

            PugSetupMessageToAll("%t", "ForceEnd", client);
            EndMatch(true);
            g_ForceEnded = true;

        } else {
            Menu menu = new Menu(MatchEndHandler);
            SetMenuTitle(menu, "%T", "EndMatchMenuTitle", client);
            SetMenuExitButton(menu, true);
            AddMenuBool(menu, false, "%T", "ContinueMatch", client);
            AddMenuBool(menu, true, "%T", "EndMatch", client);
            DisplayMenu(menu, client, 20);

        }

    }
    return Plugin_Handled;
}

public int MatchEndHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        if (choice) {
            Call_StartForward(g_hOnForceEnd);
            Call_PushCell(client);
            Call_Finish();

            PugSetupMessageToAll("%t", "ForceEnd", client);
            EndMatch(true);
            g_ForceEnded = true;
        }
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public Action Command_ForceEnd(int client, int args) {
    PermissionCheck(client, "sm_forceend")

    Call_StartForward(g_hOnForceEnd);
    Call_PushCell(client);
    Call_Finish();

    PugSetupMessageToAll("%t", "ForceEnd", client);
    EndMatch(true);
    g_ForceEnded = true;
    return Plugin_Handled;
}

public Action Command_ForceReady(int client, int args) {
    PermissionCheck(client, "sm_forceready")

    char buffer[64];
    if (args >= 1 && GetCmdArg(1, buffer, sizeof(buffer))) {
        int target = FindTarget(client, buffer, true, false);
        if (IsPlayer(target))
            ReadyPlayer(target);
    }

    return Plugin_Handled;
}

static bool Pauseable() {
    if (!g_Setup)
        return false;

    if (!g_MatchLive && !g_WaitingForKnifeWinner && !g_InStartPhase)
        return false;

    return true;
}

public Action Command_Pause(int client, int args) {
    if (!Pauseable() || IsPaused())
        return Plugin_Handled;

    PermissionCheck(client, "sm_pause")

    g_ctUnpaused = false;
    g_tUnpaused = false;
    Pause();
    if (IsPlayer(client)) {
        PugSetupMessageToAll("%t", "Pause", client);
    }

    return Plugin_Handled;
}

public Action Command_Unpause(int client, int args) {
    if (!Pauseable() || !IsPaused())
        return Plugin_Handled;

    PermissionCheck(client, "sm_unpause")

    char unpauseCmd[ALIAS_LENGTH];
    FindChatCommand("sm_unpause", unpauseCmd);

    if (g_hMutualUnpause.IntValue == 0) {

        Unpause();
        if (IsPlayer(client)) {
            PugSetupMessageToAll("%t", "Unpause", client);
        }
    } else {
        // Let console force unpause
        if (!IsPlayer(client)) {
            Unpause();
        } else {
            int team = GetClientTeam(client);
            if (team == CS_TEAM_T)
                g_tUnpaused = true;
            else if (team == CS_TEAM_CT)
                g_ctUnpaused = true;

            if (g_tUnpaused && g_ctUnpaused)  {
                Unpause();
                if (IsPlayer(client)) {
                    PugSetupMessageToAll("%t", "Unpause", client);
                }
            } else if (g_tUnpaused && !g_ctUnpaused) {
                PugSetupMessageToAll("%t", "MutualUnpauseMessage", "T", "CT", unpauseCmd);
            } else if (!g_tUnpaused && g_ctUnpaused) {
                PugSetupMessageToAll("%t", "MutualUnpauseMessage", "CT", "T", unpauseCmd);
            }
        }
    }

    return Plugin_Handled;
}

public Action Command_Ready(int client, int args) {
    PermissionCheck(client, "sm_ready")
    ReadyPlayer(client);
    return Plugin_Handled;
}

public Action Command_NotReady(int client, int args) {
    PermissionCheck(client, "sm_notready")
    UnreadyPlayer(client);
    return Plugin_Handled;
}

public Action Command_Leader(int client, int args) {
    if (!g_Setup)
        return Plugin_Handled;

    PermissionCheck(client, "sm_leader")

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

public Action Event_MatchOver(Handle event, const char[] name, bool dontBroadcast) {
    if (g_MatchLive) {
        CreateTimer(15.0, Timer_EndMatch);
        ExecCfg(g_hWarmupCfg);
    }

    // Always make these false, in case the players didn't use the plugin's lo3/start functionality
    // and manually rcon'd the commands.
    g_MapSet = false;
    g_Setup = false;
    g_MatchLive = false;
    g_WaitingForKnifeDecision = false;
    g_WaitingForKnifeWinner = false;

    CreateTimer(15.0, Timer_CheckAutoSetup);
    return Plugin_Continue;
}

/** Helper timer to delay starting warmup period after match is over by a little bit **/
public Action Timer_EndMatch(Handle timer) {
    EndMatch(false);
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast) {
    int winner = GetEventInt(event, "winner");
    if (g_WaitingForKnifeWinner) {
        g_WaitingForKnifeWinner = false;
        g_WaitingForKnifeDecision = true;
        g_KnifeWinner = winner;

        char teamString[4];
        if (g_KnifeWinner == CS_TEAM_CT)
            teamString = "CT";
        else
            teamString = "T";

        char stayCmd[ALIAS_LENGTH];
        char swapCmd[ALIAS_LENGTH];
        FindChatCommand("sm_stay", stayCmd);
        FindChatCommand("sm_swap", swapCmd);

        PugSetupMessageToAll("%t", "KnifeRoundWinner", teamString, stayCmd, swapCmd);
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

    // print each setup option avaliable

    if (g_DisplayMapType) {
        char mapType[256];
        GetMapString(mapType, sizeof(mapType), g_MapType, client);
        PugSetupMessage(client, "%t: {GREEN}%s", "MapTypeOption", mapType);
    }

    if (g_DisplayTeamSize || g_DisplayTeamType) {
        char teamType[256];
        GetTeamString(teamType, sizeof(teamType), g_TeamType, client);
        PugSetupMessage(client, "%t: ({GREEN}%d vs %d{NORMAL}) {GREEN}%s",
                        "TeamTypeOption", g_PlayersPerTeam, g_PlayersPerTeam, teamType);
    }

    if (g_DisplayRecordDemo) {
        char demo[256];
        GetEnabledString(demo, sizeof(demo), g_RecordGameOption, client);
        PugSetupMessage(client, "%t: {GREEN}%s", "DemoOption", demo);
    }

    if (g_DisplayKnifeRound) {
        char knife[256];
        GetEnabledString(knife, sizeof(knife), g_DoKnifeRound, client);
        PugSetupMessage(client, "%t: {GREEN}%s", "KnifeRoundOption", knife);
    }

    if (g_DisplayAutoLive) {
        char autolive[256];
        GetEnabledString(autolive, sizeof(autolive), g_AutoLive, client);
        PugSetupMessage(client, "%t: {GREEN}%s", "AutoLiveOption", autolive);
    }
}

public void ReadyToStart() {
    g_InStartPhase = true;
    g_ForceStartSignal = false;
    Call_StartForward(g_hOnReadyToStart);
    Call_Finish();

    if (g_AutoLive) {
        CreateCountDown();
    } else {
        g_WaitingForStartCommand = true;
        CreateTimer(float(START_COMMAND_HINT_TIME), Timer_StartCommandHint);
        GiveStartCommandHint();
    }
}

static void GiveStartCommandHint() {
    char startCmd[ALIAS_LENGTH];
    FindChatCommand("sm_start", startCmd);
    PugSetupMessageToAll("%t", "WaitingForStart", GetLeader(), startCmd);
}

public Action Timer_StartCommandHint(Handle timer) {
    if (!g_Setup || !g_WaitingForStartCommand || g_MatchLive) {
        return Plugin_Handled;
    }
    GiveStartCommandHint();
    return Plugin_Continue;
}

static void CreateCountDown() {
    g_CountDownTicks = g_hStartDelay.IntValue;
    CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CountDown(Handle timer)  {
    if (!g_Setup) {
        // match cancelled
        PugSetupMessageToAll("%t", "CancelCountdownMessage");
        return Plugin_Stop;
    }

    if (g_CountDownTicks == 0) {
        StartGame();
        return Plugin_Stop;
    }

    if (g_hAnnounceCountdown.IntValue != 0 && (g_CountDownTicks < 5 || g_CountDownTicks % 5 == 0)) {
        PugSetupMessageToAll("%t", "Countdown", g_CountDownTicks);
    }

    g_CountDownTicks--;

    return Plugin_Continue;
}

public void StartGame() {
    if (g_RecordGameOption && !IsTVEnabled()) {
        LogError("GOTV demo could not be recorded since tv_enable is not set to 1");
    } else if (g_RecordGameOption && IsTVEnabled()) {
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
        g_hDemoTimeFormat.GetString(timeFormat, sizeof(timeFormat));
        int timeStamp = GetTime();
        char formattedTime[64];
        FormatTime(formattedTime, sizeof(formattedTime), timeFormat, timeStamp);

        // get the player count, this is {TEAMSIZE} in the format string
        char playerCount[8];
        IntToString(g_PlayersPerTeam, playerCount, sizeof(playerCount));

        // create the actual demo name to use
        char demoName[PLATFORM_MAX_PATH];
        g_hDemoNameFormat.GetString(demoName, sizeof(demoName));

        ReplaceString(demoName, sizeof(demoName), "{MAP}", mapName[last_slash], false);
        ReplaceString(demoName, sizeof(demoName), "{TEAMSIZE}", playerCount, false);
        ReplaceString(demoName, sizeof(demoName), "{TIME}", formattedTime, false);

        Call_StartForward(g_hOnStartRecording);
        Call_PushString(demoName);
        Call_Finish();

        if (Record(demoName)) {
            LogMessage("Recording to %s", demoName);
            Format(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
            g_Recording = true;
        }
    }

    for (int i = 1; i <= MaxClients; i++) {
        g_PlayerAtStart[i] = IsPlayer(i);
    }

    if (g_TeamType == TeamType_Random) {
        PugSetupMessageToAll("%t", "Scrambling");
        ScrambleTeams();
    }

    if (g_DoKnifeRound) {
        ExecGameConfigs();
        CreateTimer(3.0, StartKnifeRound, _, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        ExecGameConfigs();
        CreateTimer(3.0, BeginLO3, _, TIMER_FLAG_NO_MAPCHANGE);
    }

}

public void ScrambleTeams() {
    int tCount = 0;
    int ctCount = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && (g_hExcludeSpectators.IntValue == 0 || GetClientTeam(i) != CS_TEAM_SPECTATOR)) {
            if (tCount < g_PlayersPerTeam && ctCount < g_PlayersPerTeam) {
                bool ct = (GetRandomInt(0, 1) == 0);
                if (ct) {
                    SwitchPlayerTeam(i, CS_TEAM_CT);
                    ctCount++;
                } else {
                    SwitchPlayerTeam(i, CS_TEAM_T);
                    tCount++;
                }

            } else if (tCount < g_PlayersPerTeam && ctCount >= g_PlayersPerTeam) {
                // CT is full
                SwitchPlayerTeam(i, CS_TEAM_T);
                tCount++;

            } else if (ctCount < g_PlayersPerTeam && tCount >= g_PlayersPerTeam) {
                // T is full
                SwitchPlayerTeam(i, CS_TEAM_CT);
                ctCount++;

            } else {
                // both teams full
                SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
                Call_StartForward(g_hOnNotPicked);
                Call_PushCell(i);
                Call_Finish();
            }
        }
    }
}

public void ExecGameConfigs() {
    if (g_hExecDefaultConfig.IntValue != 0)
        ServerCommand("exec gamemode_competitive");

    ExecCfg(g_hLiveCfg);
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

    ServerCommand("mp_unpause_match");
    if (g_MatchLive && execConfigs)
        ExecCfg(g_hWarmupCfg);

    g_LiveTimerRunning = false;
    g_Leader = -1;
    g_capt1 = -1;
    g_capt2 = -1;
    g_MapSet = false;
    g_Setup = false;
    g_MatchLive = false;
    g_WaitingForKnifeWinner = false;
    g_InStartPhase = false;

    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i))
            UpdateClanTag(i);
    }
}

public ArrayList GetCurrentMapList() {
    if (g_MapList.Length == 0) {
        AddBackupMaps();
    }
    return g_MapList;
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
    g_InStartPhase = true;

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
    g_Teams[g_capt2] = CS_TEAM_CT;

    SwitchPlayerTeam(g_capt1, CS_TEAM_T);
    g_Teams[g_capt1] = CS_TEAM_T;

    InitialChoiceMenu(g_capt1);
    return Plugin_Handled;
}

public Action FinishPicking(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            if (g_Teams[i] == CS_TEAM_NONE || g_Teams[i] == CS_TEAM_SPECTATOR) {
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

public Action Timer_CheckAutoSetup(Handle timer) {
    CheckAutoSetup();
    return Plugin_Handled;
}

public void CheckAutoSetup() {
    if (g_hAutoSetup.IntValue != 0 && !g_Setup && !g_ForceEnded && !g_InStartPhase && !g_MatchLive) {
        // Re-fetch the defaults
        ReadSetupOptions();
        SetupFinished();
    }
}

public void ExecCfg(ConVar cvar) {
    char cfg[PLATFORM_MAX_PATH];
    cvar.GetString(cfg, sizeof(cfg));

    // for files that start with configs/pugsetup/* we just
    // read the file and execute each command individually,
    // otherwise we assume the file is in the cfg/ directory and
    // just use the game's exec command.
    if (StrContains(cfg, "configs/pugsetup") == 0) {
        char formattedPath[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, formattedPath, sizeof(formattedPath), cfg);
        ExecFromFile(formattedPath);
    } else {
        ServerCommand("exec \"%s\"", cfg);
    }

    if (cvar == g_hLiveCfg) {
        Call_StartForward(g_hOnLiveCfg);
        Call_Finish();
    } else if (cvar == g_hWarmupCfg) {
        Call_StartForward(g_hOnWarmupCfg);
        Call_Finish();
    }
}

public void ExecFromFile(const char[] path) {
    if (FileExists(path)) {
        File file = OpenFile(path, "r");
        if (file != null) {
            char buffer[256];
            while (!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer))) {
                ServerCommand(buffer);
            }
            delete file;
        } else {
            LogError("Failed to open config file for reading: %s", path);
        }
    } else {
        LogError("Config file does not exist: %s", path);
    }
}

stock void UpdateClanTag(int client, bool strip=false) {
    if (IsPlayer(client)) {

        // don't bother with crazy things when the plugin isn't active
        if (g_MatchLive || !g_Setup || strip) {
            CS_SetClientClanTag(client, "");
            return;
        }

        int team = GetClientTeam(client);
        if (g_hExcludeSpectators.IntValue == 0 || team == CS_TEAM_CT || team == CS_TEAM_T) {
            char tag[32];
            if (g_Ready[client]) {
                Format(tag, sizeof(tag), "%T", "Ready", LANG_SERVER);
            } else {
                Format(tag, sizeof(tag), "%T", "NotReady", LANG_SERVER);
            }
            CS_SetClientClanTag(client, tag);
        } else {
            CS_SetClientClanTag(client, "");
        }
    }
}
