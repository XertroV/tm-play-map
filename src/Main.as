bool UserHasPermissions = false;

void Main() {
    UserHasPermissions = Permissions::PlayLocalMap();
    startnew(MainCoro);
    startnew(CheckIfCustomModeExists);
}

void MainCoro() {
    while (true) {
        yield();
    }
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
bool m_UseTmxMirror = false;


// todo: better rendering rules
// interface on + in map
// interface on + not in map
// interface off outside map?

/** Render function called every frame.
*/
void Render() {
    if (!ShowWindow || (S_HideInMap && (CurrentlyInMap || GetApp().Editor !is null))) return;
    vec2 size = vec2(450, 300);
    vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
    UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
    UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
    UI::PushStyleColor(UI::Col::FrameBg, vec4(.2, .2, .2, .5));
    if (UI::Begin(MenuTitle, ShowWindow)) {
        UI::Columns(2, "title-settings", false);
        UI::AlignTextToFramePadding();
        UI::Text(selectedTab != Tab::Editor ? "Play a Map" : "Open in Editor");
        UI::NextColumn();
        S_HideInMap = UI::Checkbox("Hide window when in-map?", S_HideInMap);
        UI::Columns(1);
        UI::Separator();
        if (UserHasPermissions) {
            DrawMapInputTypes();
            UI::Separator();
            DrawMapLog();
        } else {
            UI::TextWrapped("\\$fe1Sorry, you don't appear to have permissions to play local maps.");
        }
    }
    UI::End();
    UI::PopStyleColor();
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
    CustomGameModeLabel
    // "TrackMania/asdf"
};

[Setting hidden]
string selectedMode = allModes[0];

void DrawMapInputTypes() {
    UI::BeginTabBar("map input types");

    if (UI::BeginTabItem("URL")) {
        selectedTab = Tab::URL;
        UI::AlignTextToFramePadding();
        UI::Text("URL:");
        UI::SameLine();
        bool pressedEnter = false;
        m_URL = UI::InputText("##map-url", m_URL, pressedEnter, UI::InputTextFlags::EnterReturnsTrue);
        UI::SameLine();
        if (UI::Button("Play Map##main-btn") || pressedEnter) {
            if (m_URL.Contains("https://trackmania.exchange/tracks/view")) {
                m_URL = Regex::Search(m_URL, "[0-9]{5,6}")[0];
            }
            if (Regex::IsMatch(m_URL, "[0-9]{5,6}")) {
                m_URL = tmxIdToUrl(m_URL);
            }
            startnew(OnLoadMapNow);
        }
        UI::EndTabItem();
    }

    if (UI::BeginTabItem("TMX")) {
        selectedTab = Tab::TMX;
        UI::AlignTextToFramePadding();
        UI::Text("Track ID:");
        UI::SameLine();
        bool pressedEnter = false;
        UI::SetNextItemWidth(100);
        m_TMX = UI::InputText("##tmx-id", m_TMX, pressedEnter, UI::InputTextFlags::EnterReturnsTrue);
        UI::SameLine();
        if (UI::Button("Play Map##main-btn") || pressedEnter) {
            m_URL = tmxIdToUrl(m_TMX);
            if (m_TMX.StartsWith("http")) {
                m_URL = m_TMX;
            }
            startnew(OnLoadMapNow);
        }
        UI::SameLine();
        m_UseTmxMirror = UI::Checkbox("Use Mirror?", m_UseTmxMirror);
        AddSimpleTooltip("Instead of downloading maps from TMX,\ndownload them from the CGF mirror.");
        UI::EndTabItem();
    }

    if (UI::BeginTabItem("Game Mode Settings")) {
        selectedTab = Tab::URL;
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
        UI::EndTabItem();
    }

    if (UI::BeginTabItem("Editor")) {
        selectedTab = Tab::Editor;
        UI::AlignTextToFramePadding();
        UI::Text("URL:");
        UI::SameLine();
        bool pressedEnter = false;
        m_URL = UI::InputText("##map-url", m_URL, pressedEnter, UI::InputTextFlags::EnterReturnsTrue);
        UI::SameLine();
        if (UI::Button("Edit Map##main-btn") || pressedEnter) {
            startnew(OnEditMapNow);
        }
        UI::EndTabItem();
    }
    UI::EndTabBar();
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
    Notify("checked " + Time::Now);
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

void OnLoadMapNow() {
    string url = m_URL;
    m_URL = "";
    mapLog.InsertLast(url);
    bool isCustom = selectedMode == CustomGameModeLabel;
    LoadMapNow(url, !isCustom ? selectedMode : S_CustomGameMode + ".Script.txt");
}

void OnEditMapNow() {
    string url = m_URL;
    m_URL = "";
    mapLog.InsertLast(url);
    EditMapNow(url);
}

string[] mapLog;

void DrawMapLog() {
    UI::AlignTextToFramePadding();
    UI::Text("History:");
    if (UI::BeginTable("play map log", 2, UI::TableFlags::SizingStretchProp)) {
        UI::TableSetupColumn("URL", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed);
        for (int i = int(mapLog.Length) - 1; i >= 0; i--) {
            UI::TableNextRow();
            UI::TableNextColumn();
            UI::AlignTextToFramePadding();
            UI::Text(mapLog[i]);
            UI::TableNextColumn();
            if (UI::Button("Copy##"+i)) {
                IO::SetClipboard(mapLog[i]);
            }
        }
        UI::EndTable();
    }
}



void AddSimpleTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::Text(msg);
        UI::EndTooltip();
    }
}
