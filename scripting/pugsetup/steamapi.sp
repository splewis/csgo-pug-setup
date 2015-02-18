/**
 * Much of the logic here is taken from Nefarius's
 * Workshop map loader (https://github.com/nefarius/WorkshopMapLoader),
 * and adapted to work for the maplists used by pugsetup.
 */

#define MAX_ID_LEN          64
#define MAX_URL_LEN         256
#define MAX_POST_LEN        256
#define WAPI_USERAGENT      "Valve/Steam HTTP Client 1.0"
#define WORKSHOP_ID_LENGTH 64

// Feature checks
#define SYSTEM2_AVAILABLE()        (GetFeatureStatus(FeatureType_Native, "System2_GetPage") == FeatureStatus_Available)

/*
 * Sends an API call for steam to fetch the maps inside a collection.
 */
stock void UpdateWorkshopCache(int collectionID) {
    // Build URL
    char request[MAX_URL_LEN];
    char data[MAX_POST_LEN];

    Format(request, MAX_URL_LEN, "%s",
        "http://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/");
    Format(data, MAX_POST_LEN, "collectioncount=1&publishedfileids%%5B0%%5D=%d&format=vdf", collectionID);

    if (SYSTEM2_AVAILABLE()) {
        System2_GetPage(OnGetPageComplete, request, data, WAPI_USERAGENT, collectionID);
    } else {
        LogError("You have the system2 extension installed to use workshop collections.");
    }
}

/*
 * Gets called when response is received.
 */
public int OnGetPageComplete(const char[] output, const int size, CMDReturn status, int collectionID) {
    // Handle error condition
    if (status == CMD_ERROR) {
        PrintToServer("Steam API error: couldn't fetch data for collection ID %d", collectionID);
        AddWorkshopMapsToList(collectionID);
        return;
    }


    // Interpret response status
    switch (status) {
        case CMD_SUCCESS:
        {
            PrintToServer("Successfully received file details for ID %d", collectionID);
            KeyValues kv = new KeyValues("response");
            if (kv.ImportFromString(output)) {
                WriteCollectionInfo(kv, collectionID);
            } else {
                LogError("failed import kv response:\n%s", output);
            }
            delete kv;
        }
    }

    AddWorkshopMapsToList(collectionID);
}

stock void WriteCollectionInfo(KeyValues kv, int collectionID) {
    if (kv.JumpToKey("collectiondetails") && kv.JumpToKey("0") && kv.JumpToKey("children")) {
        kv.GotoFirstSubKey();

        char buffer[64];
        do {
            kv.GetSectionName(buffer, sizeof(buffer));
            char mapId[WORKSHOP_ID_LENGTH];
            kv.GetString("publishedfileid", mapId, sizeof(mapId));

            char strID[WORKSHOP_ID_LENGTH];
            IntToString(collectionID, strID, sizeof(strID));

            if (!StrEqual(mapId, "")) {
                g_WorkshopCache.Rewind();
                g_WorkshopCache.JumpToKey("collections", true);
                g_WorkshopCache.JumpToKey(strID, true);
                g_WorkshopCache.SetString(mapId, "x"); // appearently empty string values don't work
                g_WorkshopCache.Rewind();
                AddMapByID(mapId);

            } else {
                LogError("Failed to add map %d to collection %d inside the workshop cache", mapId, collectionID);
            }

        } while (kv.GotoNextKey());
    } else {
        LogError("Recieved improperly formatted respone in response kv");
    }
}

/** Adds a map id to the workshop collection **/
static void AddMapByID(const char[] mapId) {
    char dirPath[PLATFORM_MAX_PATH];
    Format(dirPath, sizeof(dirPath), "maps/workshop/%s", mapId);
    if (!DirExists(dirPath)) {
        return;
    }

    DirectoryListing listing = OpenDirectory(dirPath);

    if (listing == INVALID_HANDLE) {
        return;
    }

    // Find the most recent (by timestamp) .bsp file in the directory
    char mapName[PLATFORM_MAX_PATH];
    int newestTimestamp = 0;

    char buffer[PLATFORM_MAX_PATH];
    FileType fileType;

    while (listing.GetNext(buffer, sizeof(buffer), fileType)) {
        if (fileType != FileType_File || StrContains(buffer, ".bsp") == -1)
            continue;

        char fullPath[PLATFORM_MAX_PATH];
        Format(fullPath, sizeof(fullPath), "%s/%s", dirPath, buffer);
        int t = GetFileTime(fullPath, FileTime_LastChange);

        if (t > newestTimestamp) {
            newestTimestamp = t;
            strcopy(mapName, sizeof(mapName), buffer);
        }
    }
    CloseHandle(listing);

    if (newestTimestamp > 0) {
        g_WorkshopCache.Rewind();
        ReplaceString(mapName, sizeof(mapName), ".bsp", ""); // remove the .bsp extension
        g_WorkshopCache.JumpToKey("maps", true);
        char value[PLATFORM_MAX_PATH];
        Format(value, sizeof(value), "workshop/%s/%s", mapId, mapName);
        g_WorkshopCache.SetString(mapId, value);
        g_WorkshopCache.Rewind();
    }
}

static void AddWorkshopMapsToList(int collectionID) {
    // first get all the map ids for this colelction into a list
    ArrayList mapIds = CreateArray(WORKSHOP_ID_LENGTH);

    char strID[WORKSHOP_ID_LENGTH];
    IntToString(collectionID, strID, sizeof(strID));

    g_WorkshopCache.Rewind();
    g_WorkshopCache.JumpToKey("collections", true);
    g_WorkshopCache.JumpToKey(strID, true);
    g_WorkshopCache.GotoFirstSubKey(false);

    char mapId[WORKSHOP_ID_LENGTH];
    do {
        g_WorkshopCache.GetSectionName(mapId, sizeof(mapId));
        mapIds.PushString(mapId);
    } while (g_WorkshopCache.GotoNextKey(false));


    g_WorkshopCache.Rewind();

    // next traverse the map list within the cache to get the actual map names
    char mapName[PLATFORM_MAX_PATH];
    g_WorkshopCache.JumpToKey("maps", true);

    g_MapList.Clear();
    for (int i = 0; i < mapIds.Length; i++) {
        mapIds.GetString(i, mapId, sizeof(mapId));
        g_WorkshopCache.GetString(mapId, mapName, sizeof(mapName));
        AddMap(mapName);
    }

    g_WorkshopCache.Rewind();

    Call_StartForward(g_hOnMapListRead);
    Call_PushString(strID);
    Call_PushCell(g_MapList);
    Call_PushCell(true);
    Call_Finish();

    delete mapIds;
}
