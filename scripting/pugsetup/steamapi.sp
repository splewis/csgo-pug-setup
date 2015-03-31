#define MAX_URL_LEN 512
#define WORKSHOP_ID_LENGTH 64

// Feature checks
#define STEAMWORKS_AVALIABLE()        (GetFeatureStatus(FeatureType_Native, "SteamWorks_CreateHTTPRequest") == FeatureStatus_Available)

/*
 * Sends an API call for steam to fetch the maps inside a collection.
 */
public void UpdateWorkshopCache(const char[] collectionId, ArrayList list) {
    char requestUrl[MAX_URL_LEN];
    Format(requestUrl, MAX_URL_LEN, "http://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/");

    if (STEAMWORKS_AVALIABLE()) {
        Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, requestUrl);
        if (request == INVALID_HANDLE) {
            LogError("Failed to create HTTP POST request using url: %s", requestUrl);
            return;
        }

        DataPack pack = new DataPack();
        pack.WriteString(collectionId);
        pack.WriteCell(list);

        SteamWorks_SetHTTPRequestGetOrPostParameter(request, "collectioncount", "1");
        SteamWorks_SetHTTPRequestGetOrPostParameter(request, "publishedfileids[0]", collectionId);
        SteamWorks_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
        SteamWorks_SetHTTPCallbacks(request, OnWorkshopInfoReceived);
        SteamWorks_SetHTTPRequestContextValue(request, pack);
        SteamWorks_SendHTTPRequest(request);

    } else {
        LogError("You have the SteamWorks extension installed to use workshop collections.");
    }
}

// SteamWorks HTTP callback
public int OnWorkshopInfoReceived(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, Handle data) {
    char collectionId[WORKSHOP_ID_LENGTH];

    DataPack pack = view_as<DataPack>(data);
    pack.Reset();
    pack.ReadString(collectionId, sizeof(collectionId));
    ArrayList list = view_as<ArrayList>(pack.ReadCell());

    LogDebug("OnWorkshopInfoReceived(collection=%s)", collectionId);

    if (failure || !requestSuccessful) {
        LogError("Steamworks collection request failed, HTTP status code = %d", statusCode);
        AddWorkshopMapsToList(collectionId, list); // add backup maps that might already be cached
        delete pack;
        return;
    }

    int len = 0;
    SteamWorks_GetHTTPResponseBodySize(request, len);
    char[] response = new char[len];
    SteamWorks_GetHTTPResponseBodyData(request, response, len);

    KeyValues kv = new KeyValues("response");
    if (kv.ImportFromString(response)) {
        WriteCollectionInfo(kv, collectionId, list);
    } else {
        LogError("Couldn't import keyvalue response:\n%s", response);
    }

    AddWorkshopMapsToList(collectionId, list);
    delete pack;
    delete kv;
}

stock void WriteCollectionInfo(KeyValues kv, const char[] collectionId, ArrayList mapList) {
    if (kv.JumpToKey("collectiondetails") && kv.JumpToKey("0") && kv.JumpToKey("children")) {
        kv.GotoFirstSubKey();

        // delete current workshop stuff in this collection
        g_WorkshopCache.Rewind();
        g_WorkshopCache.JumpToKey("collections", true);
        g_WorkshopCache.DeleteKey(collectionId);
        g_WorkshopCache.Rewind();

        // write out maps currently in the collection
        char buffer[64];
        do {
            kv.GetSectionName(buffer, sizeof(buffer));
            char mapId[WORKSHOP_ID_LENGTH];
            kv.GetString("publishedfileid", mapId, sizeof(mapId));

            if (!StrEqual(mapId, "")) {
                g_WorkshopCache.Rewind();
                g_WorkshopCache.JumpToKey("collections", true);
                g_WorkshopCache.JumpToKey(collectionId, true);
                g_WorkshopCache.SetString(mapId, "x"); // apparently empty string values don't work
                g_WorkshopCache.Rewind();
                UpdateMapInfo(collectionId, mapId, mapList);
            } else {
                LogError("Failed to add map %s to collection %s inside the workshop cache", mapId, collectionId);
            }

        } while (kv.GotoNextKey());
    } else {
        LogError("Recieved improperly formatted respone in response kv");
    }
}

static void AddWorkshopMapsToList(const char[] collectionId, ArrayList mapList) {
    // first get all the map ids for this colelction into a list
    ArrayList mapIds = CreateArray(WORKSHOP_ID_LENGTH);

    g_WorkshopCache.Rewind();
    g_WorkshopCache.JumpToKey("collections", true);
    g_WorkshopCache.JumpToKey(collectionId, true);
    g_WorkshopCache.GotoFirstSubKey(false);

    char mapId[WORKSHOP_ID_LENGTH];
    do {
        g_WorkshopCache.GetSectionName(mapId, sizeof(mapId));
        mapIds.PushString(mapId);
    } while (g_WorkshopCache.GotoNextKey(false));


    g_WorkshopCache.Rewind();

    // next traverse the map list within the cache to get the actual map names
    char mapName[PLATFORM_MAX_PATH];
    char fullMapPath[PLATFORM_MAX_PATH];
    g_WorkshopCache.JumpToKey("maps", true);

    mapList.Clear();
    for (int i = 0; i < mapIds.Length; i++) {
        mapIds.GetString(i, mapId, sizeof(mapId));
        g_WorkshopCache.GetString(mapId, mapName, sizeof(mapName));
        Format(fullMapPath, sizeof(fullMapPath), "workshop/%s/%s", mapId, mapName);
        AddMap(fullMapPath, mapList);
    }

    g_WorkshopCache.Rewind();

    delete mapIds;
}

/*
 * Sends an API call for steam to fetch the maps inside a collection.
 */
public void UpdateMapInfo(const char[] collectionId, const char[] mapId, ArrayList list) {
    char requestUrl[MAX_URL_LEN];
    Format(requestUrl, MAX_URL_LEN, "http://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/");

    if (STEAMWORKS_AVALIABLE()) {
        Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, requestUrl);
        if (request == INVALID_HANDLE) {
            LogError("Failed to create HTTP POST request using url: %s", requestUrl);
            return;
        }

        DataPack pack = new DataPack();
        pack.WriteString(collectionId);
        pack.WriteString(mapId);
        pack.WriteCell(list);

        SteamWorks_SetHTTPRequestGetOrPostParameter(request, "itemcount", "1");
        SteamWorks_SetHTTPRequestGetOrPostParameter(request, "publishedfileids[0]", mapId);
        SteamWorks_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
        SteamWorks_SetHTTPCallbacks(request, OnMapInfoReceived);
        SteamWorks_SetHTTPRequestContextValue(request, pack);
        SteamWorks_SendHTTPRequest(request);

    } else {
        LogError("You have the SteamWorks extension installed to use workshop collections.");
    }
}

// SteamWorks HTTP callback for a map id
public int OnMapInfoReceived(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, Handle data) {
    char collectionId[WORKSHOP_ID_LENGTH];
    char mapId[WORKSHOP_ID_LENGTH];

    DataPack pack = view_as<DataPack>(data);
    pack.Reset();

    pack.ReadString(collectionId, sizeof(collectionId));
    pack.ReadString(mapId, sizeof(mapId));
    ArrayList list = view_as<ArrayList>(pack.ReadCell());

    LogDebug("OnMapInfoReceived(map=%s, collection=%s)", mapId, collectionId);

    if (failure || !requestSuccessful) {
        LogError("Steamworks collection request failed, HTTP status code = %d", statusCode);
        AddWorkshopMapsToList(collectionId, list);
        delete pack;
        return;
    }

    int len = 0;
    SteamWorks_GetHTTPResponseBodySize(request, len);
    char[] response = new char[len];
    SteamWorks_GetHTTPResponseBodyData(request, response, len);

    KeyValues kv = new KeyValues("response");
    if (kv.ImportFromString(response)) {
        WriteMapInfo(kv, mapId);
    } else {
        LogError("Couldn't import keyvalue response:\n%s", response);
    }

    AddWorkshopMapsToList(collectionId, list);
    delete pack;
    delete kv;
}

public void WriteMapInfo(KeyValues kv, const char[] mapId) {
    g_WorkshopCache.JumpToKey("maps", true);

    if (kv.JumpToKey("publishedfiledetails") && kv.JumpToKey("0")) {
        char mapName[PLATFORM_MAX_PATH];
        kv.GetString("filename", mapName, sizeof(mapName));

        // The filename field looks like: "filename"  "mymaps/de_fire.bsp"
        // so the mymaps/ and .bsp need to get removed.
        ReplaceString(mapName, sizeof(mapName), "mymaps/", "");
        ReplaceString(mapName, sizeof(mapName), ".bsp", "");

        LogDebug("mapId = %s, mapName = %s", mapId, mapName);

        g_WorkshopCache.SetString(mapId, mapName);

    } else {
        LogError("Recieved improperly formatted respone in response kv");
    }

    g_WorkshopCache.Rewind();
}
