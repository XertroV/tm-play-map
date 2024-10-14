bool UserHasPermissions = false;

void Main() {
    UserHasPermissions = Permissions::PlayLocalMap();
    startnew(CheckIfCustomModeExists);
    startnew(LoadMapLogFromFile);
}

void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 15000);
}

void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 15000);
}

const string PluginIcon = Icons::PlayCircle;
const string MenuTitle = "\\$3f3" + PluginIcon + "\\$z " + Meta::ExecutingPlugin().Name;

// show the window immediately upon installation
[Setting hidden]
bool ShowWindow = true;

/** Render function called every frame intended only for menu items in `UI`. */
void RenderMenu() {
    if (UI::MenuItem(MenuTitle, "", ShowWindow)) {
        ShowWindow = !ShowWindow;
    }
}

string m_URL;
string m_TMX;
string m_UID;
bool m_UseTmxMirror = false;

bool g_LoadingUID = false;

// todo: better rendering rules
// interface on + in map
// interface on + not in map
// interface off outside map?

enum LoadType {
    Play,
    NewFromBase,
    Edit,
}

/** Render function called every frame.
*/
void Render() {
    if (!ShowWindow || (S_HideInMap && (CurrentlyInMap || GetApp().Editor !is null))) return;
    vec2 size = vec2(450, 300);
    vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
    UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
    UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
    UI::PushStyleColor(UI::Col::FrameBg, vec4(.2, .2, .2, .5));
    UI::PushStyleColor(UI::Col::Border, vec4(.35, .35, .35, .5));
    if (UI::Begin(MenuTitle, ShowWindow)) {
        DrawRadioOptions();
        UI::Columns(2, "title-settings", false);
        UI::AlignTextToFramePadding();
        UI::Text(S_LoadType == LoadType::Play ? "Play a Map" : "Open in Editor");
        UI::NextColumn();
        S_HideInMap = UI::Checkbox("Hide window when in-map?", S_HideInMap);
        UI::Columns(1);
        UI::Separator();
        if (UserHasPermissions) {
            UI::BeginDisabled(g_LoadingUID);
            DrawMapInputTypes();
            UI::EndDisabled();

            UI::Separator();
            DrawMapLog();
        } else {
            UI::TextWrapped("\\$fe1Sorry, you don't appear to have permissions to play local maps.");
        }
    }
    UI::End();
    UI::PopStyleColor(2);
}

[Setting hidden]
LoadType S_LoadType = LoadType::Play;

void DrawRadioOptions() {
    // UI::AlignTextToFramePadding();
    // UI::Text("Load Type:");
    // UI::SameLine();
    if (UI::RadioButton("Play", S_LoadType == LoadType::Play)) {
        S_LoadType = LoadType::Play;
    }
    UI::SameLine();
    if (UI::RadioButton("Edit", S_LoadType == LoadType::Edit)) {
        S_LoadType = LoadType::Edit;
    }
#if DEV
    UI::SameLine();
    if (UI::RadioButton("New from Base", S_LoadType == LoadType::NewFromBase)) {
        S_LoadType = LoadType::NewFromBase;
    }
#endif
}

enum Tab {
    URL,
    TMX,
    Editor
}

Tab selectedTab = Tab::URL;

const string CustomGameModeLabel = "Custom Game Mode";

string[] allModes = {
    "TrackMania/TM_PlayMap_Local",
    "TrackMania/TM_Campaign_Local",
    "TrackMania/TM_StuntSolo_Local",
    "TrackMania/TM_Platform_Local",
    "Trackmania/TM_RoyalTimeAttack_Local",
    CustomGameModeLabel
    // "TrackMania/asdf"
};

[Setting hidden]
string selectedMode = allModes[0];

void DrawMapInputTypes() {
    // UI::BeginTabBar("map input types");

    // if (UI::BeginTabItem("URL")) {
    //     selectedTab = Tab::URL;
    //     UI::EndTabItem();
    // }

    UI::AlignTextToFramePadding();
    UI::Text("URL:");
    UI::SameLine();
    bool pressedEnterUrl = false;
    UI::SetNextItemWidth(200);
    m_URL = UI::InputText("##map-url", m_URL, pressedEnterUrl, UI::InputTextFlags::EnterReturnsTrue);
    UI::SameLine();
    if (UI::Button("Load URL##url") || pressedEnterUrl) {
        m_URL = ExtractTmxIdFromURL(m_URL);
        if (m_URL.Length < 8 && Regex::IsMatch(m_URL, "[0-9]{1,7}")) {
            m_URL = tmxIdToUrl(m_URL);
        }
        startnew(OnLoadMapNow);
    }


    // UID
    UI::AlignTextToFramePadding();
    UI::Text("Map UID:");
    UI::SameLine();
    bool pressedEnterUID = false;
    UI::SetNextItemWidth(150);
    m_UID = UI::InputText("##map-uid", m_UID, pressedEnterUID, UI::InputTextFlags::EnterReturnsTrue);
    UI::SameLine();
    if (UI::Button("Load UID##uid") || pressedEnterUID) {
        startnew(OnLoadMapFromUid);
    }


    // if (UI::BeginTabItem("TMX")) {
    //     selectedTab = Tab::TMX;
    //     UI::EndTabItem();
    // }
    UI::AlignTextToFramePadding();
    UI::Text("Track ID:");
    UI::SameLine();
    bool pressedEnterTMX = false;
    UI::SetNextItemWidth(100);
    m_TMX = UI::InputText("##tmx-id", m_TMX, pressedEnterTMX, UI::InputTextFlags::EnterReturnsTrue);
    UI::SameLine();
    if (UI::Button("Load TMX ID##url") || pressedEnterTMX) {
        m_URL = tmxIdToUrl(m_TMX);
        if (m_TMX.StartsWith("http")) {
            m_URL = ExtractTmxIdFromURL(m_TMX);
            if (m_URL.Length < 8) {
                m_URL = tmxIdToUrl(m_URL);
            }
        }
        startnew(OnLoadMapNow);
    }
    UI::SameLine();
    m_UseTmxMirror = UI::Checkbox("Use Mirror?", m_UseTmxMirror);
    AddSimpleTooltip("Instead of downloading maps from TMX,\ndownload them from XertroV's mirror.");

    // if (UI::BeginTabItem("Game Mode Settings")) {
    //     selectedTab = Tab::URL;
    //     UI::EndTabItem();
    // }
    UI::BeginDisabled(S_LoadType != LoadType::Play);
    UI::AlignTextToFramePadding();
    UI::Text("Mode:");
    UI::SameLine();
    if (UI::BeginCombo("##game-mode-combo", selectedMode)) {
        for (uint i = 0; i < allModes.Length; i++) {
            if (UI::Selectable(allModes[i], selectedMode == allModes[i])) {
                selectedMode = allModes[i];
            }
        }
        UI::EndCombo();
    }
    if (selectedMode == CustomGameModeLabel) {
        UI::Separator();
        UI::TextWrapped("\\$bbbPath to script; relative to Documents\\Trackmania\\Scripts\\Modes.");
        bool changed;
        S_CustomGameMode = UI::InputText("Mode", S_CustomGameMode, changed);
        if (changed) startnew(CheckIfCustomModeExists);
        if (S_CustomGameMode.Length > 0) {
            if (_customModeExists) {
                UI::TextWrapped("\\$8b8Found \\$888Scripts\\Modes\\" + S_CustomGameMode + ".Script.txt");
            } else {
                UI::TextWrapped("\\$888No " + S_CustomGameMode + ".Script.txt found in Documents\\Trackmania\\Scripts\\Modes.");
            }
        }
    }
    UI::EndDisabled();

    // if (UI::BeginTabItem("Editor")) {
    //     selectedTab = Tab::Editor;
    //     UI::AlignTextToFramePadding();
    //     UI::Text("URL:");
    //     UI::SameLine();
    //     bool pressedEnter = false;
    //     m_URL = UI::InputText("##map-url", m_URL, pressedEnter, UI::InputTextFlags::EnterReturnsTrue);
    //     UI::SameLine();
    //     if (UI::Button("Edit Map##main-btn") || pressedEnter) {
    //         startnew(OnEditMapNow);
    //     }
    //     UI::EndTabItem();
    // }
    // UI::EndTabBar();
}


void OnLoadMapFromUid() {
    auto uid = m_UID;
    m_UID = "";
    g_LoadingUID = true;
    m_URL = UidToUrl(uid);
    if (m_URL.Length == 0) {
        NotifyError("Not found: UID: " + uid);
    } else {
        startnew(OnLoadMapNow);
    }
    g_LoadingUID = false;
}


bool _customModeExists = false;
void CheckIfCustomModeExists() {
    if (S_CustomGameMode.Length == 0) {
        _customModeExists = false;
        return;
    }
    if (S_CustomGameMode.ToLower().EndsWith(".script.txt")) {
        S_CustomGameMode = S_CustomGameMode.SubStr(0, S_CustomGameMode.Length - 11);
    }
    _customModeExists = IO::FileExists(CustomModePath());
}

string CustomModePath() {
    return IO::FromUserGameFolder("Scripts/Modes/" + S_CustomGameMode + ".Script.txt");
}


string tmxIdToUrl(const string &in id) {
    if (m_UseTmxMirror) {
        return "https://cgf.s3.nl-1.wasabisys.com/" + id + ".Map.Gbx";
    }
    return "https://trackmania.exchange/maps/download/" + id;
}


string tmxView = "https://trackmania.exchange/tracks/view/";
string tmxViewShort = "https://trackmania.exchange/s/tr/";
// Note: check maps download first since tmxMaps is a prefix of it
string tmxMapsDownload = "https://trackmania.exchange/maps/download/";
string tmxMaps = "https://trackmania.exchange/maps/";

string GetIdFromUrl(const string &in prefix, const string &in url) {
    if (!prefix.EndsWith("/")) {
        throw('bad url prefix, needs trailing `/`: ' + prefix);
    }
    if (url.ToLower().StartsWith(prefix)) {
        trace('found url prefix: ' + prefix + ' in ' + url);
        return url.SubStr(prefix.Length).Split('/')[0];
    }
    return url;
}

string ExtractTmxIdFromURL(const string &in url) {
    return GetIdFromUrl(tmxView,
        GetIdFromUrl(tmxViewShort,
        GetIdFromUrl(tmxMaps,
        GetIdFromUrl(tmxMapsDownload, url.Trim())
    )));
}


void OnLoadMapNow() {
    string url = m_URL;
    m_URL = "";
    SaveMapToLog(url);

    if (S_LoadType == LoadType::Edit) {
        EditMapNow(url);
        return;
    }

    bool isCustom = selectedMode == CustomGameModeLabel;

    // todo: expand and add 'random from author' feature + keep meme mode
    if (S_CandywolfMeme) {
        url = "https://trackmania.exchange/maps/download/104255";
    }

    LoadMapNow(url, !isCustom ? selectedMode : S_CustomGameMode + ".Script.txt");
}

void OnEditMapNow() {
    string url = m_URL;
    m_URL = "";
    SaveMapToLog(url);
    EditMapNow(url);
}

void SaveMapToLog(const string &in url) {
    mapLog.InsertLast(url);
    mapLogTimes.InsertLast(Time::Stamp);
    IO::File f(MapLogFilePath, IO::FileMode::Append);
    f.Write(url + "|" + Time::Stamp + "\n");
    f.Close();
}

void LoadMapLogFromFile() {
    if (!IO::FileExists(MapLogFilePath)) {
        trace('no map log file');
        return;
    }
    trace('loading map log file...');
    mapLog.Resize(0);
    mapLogTimes.Resize(0);
    IO::File f(MapLogFilePath, IO::FileMode::Read);
    auto @mapLogLines = f.ReadToEnd().Split('\n');
    f.Close();
    trace('loaded map log file: ' + mapLogLines.Length + ' lines');
    for (uint i = 0; i < mapLogLines.Length; i++) {
        mapLogLines[i] = mapLogLines[i].Trim();
        if (mapLogLines[i].Length == 0) continue;
        auto @parts = mapLogLines[i].Split("|");
        print("parts: " + parts.Length + " :: " + mapLogLines[i]);
        if (parts.Length > 0) {
            mapLog.InsertLast(parts[0]);
        }
        if (parts.Length > 1) {
            int64 ts = -1;
            if (!Text::TryParseInt64(parts[1], ts)) {
                warn("error parsing timestamp: '"+parts[1]+"' | exception: " + getExceptionInfo());
            }
            mapLogTimes.InsertLast(ts);
        } else {
            mapLogTimes.InsertLast(-1);
        }
    }
    trace('loaded map log: ' + mapLog.Length + ' entries');
}

const string MapLogFilePath = IO::FromStorageFolder("map-log.txt");
string[] mapLog;
int64[] mapLogTimes;

void DrawMapLog() {
    UI::AlignTextToFramePadding();
    UI::Text("History ("+mapLog.Length+")");
    if (UI::BeginTable("play map log", 3, UI::TableFlags::SizingStretchProp)) {
        UI::TableSetupColumn("When", UI::TableColumnFlags::WidthFixed);
        UI::TableSetupColumn("URL", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed);
        auto stamp = Time::Stamp;
        for (int i = int(mapLog.Length) - 1; i >= 0; i--) {
            UI::TableNextRow();
            UI::TableNextColumn();
            UI::AlignTextToFramePadding();
            UI::Text(stamp < 0 ? "??" : HumanizeDuration(mapLogTimes[i] - stamp));
            UI::TableNextColumn();
            UI::AlignTextToFramePadding();
            UI::Text(mapLog[i]);
            UI::TableNextColumn();
            if (UI::Button("Copy##"+i)) {
                IO::SetClipboard(mapLog[i]);
                Notify("Copied: " + mapLog[i]);
            }
        }
        UI::EndTable();
    }
}

string HumanizeDuration(int64 secondsDelta) {
    auto abs = Math::Abs(secondsDelta);
    auto units = abs < 60 ? " s" : abs < 3600 ? " m" : " h";
    auto val = abs / (abs < 60 ? 1 : abs < 3600 ? 60 : 3600);
    auto dir = secondsDelta <= 0 ? " ago" : " away";
    return tostring(val) + units + dir;
}


void AddSimpleTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::Text(msg);
        UI::EndTooltip();
    }
}
