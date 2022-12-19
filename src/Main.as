bool UserHasPermissions = false;

void Main() {
    UserHasPermissions = Permissions::PlayLocalMap();
    startnew(MainCoro);
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

/** Render function called every frame.
*/
void Render() {
    if (!ShowWindow || CurrentlyInMap || GetApp().Editor !is null) return;
    vec2 size = vec2(450, 300);
    vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
    UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
    UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
    UI::PushStyleColor(UI::Col::FrameBg, vec4(.2, .2, .2, .5));
    if (UI::Begin(MenuTitle, ShowWindow)) {
        UI::AlignTextToFramePadding();
        UI::Text(selectedTab != Tab::Editor ? "Play a Map" : "Open in Editor");
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

string[] allModes = {
    "TrackMania/TM_PlayMap_Local",
    "TrackMania/TM_Campaign_Local"
};

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
    LoadMapNow(url, selectedMode);
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
