#pragma semicolon 1
#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

bool g_InPracticeMode = false;

/**
 * TODO:
 * if possible, I'd like each of these settings below to be
 * set by a keyvalue file. Something like this:
 * "respawning"
 * {
 *     "enabled"
 *     {
 *          "mp_respawn_on_death_ct" "1"
 *          "mp_respawn_on_death_t" "1"
 *     }
 *     "disabled"
 *     {
 *          "mp_respawn_on_death_ct" "0"
 *          "mp_respawn_on_death_t" "0"
 *     }
 * }
 */

bool g_Respawning = false;
bool g_InfiniteAmmo = false;
bool g_BlockRoundEnd = false;
bool g_BuyAnywhere = false;
bool g_ShowImpacts = false;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: practice mode",
    author = "splewis",
    description = "A relatively simple practice mode that can be laucnehd through the setup menu",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    g_InPracticeMode = false;
}

public bool OnSetupMenuOpen(int client, Menu menu) {
    if (g_InPracticeMode) {
        GivePracticeMenu(client);
        return false;
    } else {
        AddMenuItem(menu, "launch_practice", "Launch practice mode");
        return true;
    }
}

public void OnReadyToStart() {
    DisablePracticeMode();
}

public void OnSetupMenuSelect(Menu menu, MenuAction action, int param1, int param2) {
    int client = param1;
    char buffer[64];
    menu.GetItem(param2, buffer, sizeof(buffer));
    if (StrEqual(buffer, "launch_practice")) {
        g_InPracticeMode = !g_InPracticeMode;
        if (g_InPracticeMode) {
            // TODO: I'm not sure if it's possible to force
            // set cheat-protected cvars without this,
            // it'd be nice if it was so this isn't needed.
            SetCvar("sv_cheats", 1);

            if (g_Respawning)
                EnableRespawns();
            if (g_InfiniteAmmo)
                EnableInfAmmo();
            if (g_BlockRoundEnd)
                EnableRoundEndBlock();
            if (g_BuyAnywhere)
                EnableBuyAnywhere();
            if (g_ShowImpacts)
                EnableShowImpacts();

            ExecPracticeConfig();
            GivePracticeMenu(client);
        }
    }
}

static void ExecPracticeConfig() {
    ServerCommand("exec sourcemod/pugsetup/practice.cfg");
}

static void ADD_TOGGLE(Handle menu, const char[] name, bool value) {
    char enabled[32] = "enabled";
    if (!value)
        enabled = "disabled";

    char buffer[64];
    Format(buffer, sizeof(buffer), "%s: %s", name, enabled);
    AddMenuItem(menu, name, buffer);
}

public void GivePracticeMenu(int client) {
    Menu menu = new Menu(PracticeMenuHandler);
    SetMenuTitle(menu, "Practice Settings");
    SetMenuExitButton(menu, true);
    ADD_TOGGLE(menu, "Respawning", g_Respawning);
    ADD_TOGGLE(menu, "Infinite ammo", g_InfiniteAmmo);
    ADD_TOGGLE(menu, "Block round endings", g_BlockRoundEnd);
    ADD_TOGGLE(menu, "Buy anywhere/full money", g_BuyAnywhere);
    ADD_TOGGLE(menu, "Show bullet impacts", g_ShowImpacts);
    AddMenuItem(menu, "end_menu", "Exit practice mode");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

#define APPLY_TOGGLE(%1,%2,%3,%4) \
if (StrEqual(buffer, %1)) { \
    %2 = !%2; \
    if (%2) %3(); \
    else %4(); \
    GivePracticeMenu(client); \
    return 0; \
}

public int PracticeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[64];
        menu.GetItem(param2, buffer, sizeof(buffer));

        APPLY_TOGGLE("Respawning", g_Respawning, EnableRespawns, DisableRespawns)
        APPLY_TOGGLE("Infinite ammo", g_InfiniteAmmo, EnableInfAmmo, DisableInfAmmo)
        APPLY_TOGGLE("Block round endings", g_BlockRoundEnd, EnableRoundEndBlock, DisableRoundEndBlock)
        APPLY_TOGGLE("Buy anywhere/full money", g_BuyAnywhere, EnableBuyAnywhere, DisableBuyAnywhere)
        APPLY_TOGGLE("Show bullet impacts", g_ShowImpacts, EnableShowImpacts, DisableShowImpacts)

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
    DisableRespawns();
    DisableInfAmmo();
    DisableRoundEndBlock();
    DisableBuyAnywhere();
    DisableShowImpacts();
    SetCvar("sv_cheats", 0);
    g_InPracticeMode = false;
}

static void SetCvar(const char[] name, int value) {
    Handle cvar = FindConVar(name);
    if (cvar == INVALID_HANDLE) {
        LogError("cvar \"%s\" could not be found", name);
    } else {
        SetConVarInt(cvar, value);
    }
}


static void EnableRespawns() {
    SetCvar("mp_respawn_on_death_t", 1);
    SetCvar("mp_respawn_on_death_ct", 1);
}
static void DisableRespawns() {
    SetCvar("mp_respawn_on_death_t", 0);
    SetCvar("mp_respawn_on_death_ct", 0);
}

static void EnableInfAmmo() {
    SetCvar("sv_infinite_ammo", 2);

}
static void DisableInfAmmo() {
    SetCvar("sv_infinite_ammo", 0);
}

static void EnableRoundEndBlock() {
    SetCvar("mp_ignore_round_win_conditions", 1);

}
static void DisableRoundEndBlock() {
    SetCvar("mp_ignore_round_win_conditions", 0);
}

static void EnableBuyAnywhere() {
    SetCvar("mp_buy_anywhere", 1);
    SetCvar("mp_buytime", 99999999);
}
static void DisableBuyAnywhere() {
    SetCvar("mp_buy_anywhere", 0);
    SetCvar("mp_buytime", 20);
}

static void EnableShowImpacts() {
    SetCvar("sv_showimpacts", 1);
}
static void DisableShowImpacts() {
    SetCvar("sv_showimpacts", 0);
}
