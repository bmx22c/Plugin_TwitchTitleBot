// TODO
// ✅ 140 char max title
// Twitch Chat Bot integration: Automatically add enabled commands at the end of the title
// ✅ Collapse on variable list
// ✅ Remove "oauth:" from access token
// ✅ Stream delay
// Add default values if in menu or no PB or else

// BUG: PB not correct on RPG Downfall
// BUG: When you are out in TOTD it says that you are not on a map

[Setting hidden]
bool Setting_Enabled = true;

[Setting hidden]
string Setting_StreamTitle = "";
string PreviousStreamTitle = "";
// 140 length max

int StreamTitleCursorPos = 0;
string ForceUpdateLoadingStatus = "";

[Setting hidden]
float Setting_StreamDelay = 0.;

#if DEPENDENCY_CHECKPOINTCOUNTER
bool hasCPCounter = true;
#else
bool hasCPCounter = false;
#endif

// [var][explanation][type]
string[][] VariableList;
void PopulateVarList() {
    VariableList.InsertLast({"{map_name}", "Name of the map", "map"});
    VariableList.InsertLast({"{map_author}", "Author of the map", "map"});
    VariableList.InsertLast({"{map_author_time}", "Author time of the map", "map"});
    VariableList.InsertLast({"{server_name}", "Name of the server", "server"});
    VariableList.InsertLast({"{server_nbr_player}", "Number of players on the server", "server"});
    VariableList.InsertLast({"{server_max_player}", "Maximum number of players on the server", "server"});
    VariableList.InsertLast({"{pb}", "Personal best time on the map", "pb"});
    VariableList.InsertLast({"{TMX_URL}", "trackmania.exchange URL of the map", "url"});
    VariableList.InsertLast({"{TMIO_URL}", "trackmania.io URL of the map", "url"});
    VariableList.InsertLast({"{cp_crt}", "Current checkpoint number", "cp"});
    VariableList.InsertLast({"{cp_nbr}", "Number of checkpoints on the map", "cp"});
}

[Setting hidden]
string Setting_ClientID = "";

[Setting hidden]
string Setting_AccessToken = "";

[Setting hidden]
string Setting_BroadcasterId = "";

[Setting hidden]
bool Setting_AdvancedMode = false;

[Setting hidden]
string Setting_Save1 = "";
[Setting hidden]
string Setting_Save2 = "";
[Setting hidden]
string Setting_Save3 = "";
[Setting hidden]
string Setting_Save4 = "";
[Setting hidden]
string Setting_Save5 = "";

void StreamTitleCallback(UI::InputTextCallbackData@ d)
{
    StreamTitleCursorPos = d.CursorPos;
}

void StreamTitleInsertVariable(const string &in var){
    string p1 = Setting_StreamTitle.SubStr(0, StreamTitleCursorPos);
    string p2 = Setting_StreamTitle.SubStr(StreamTitleCursorPos, Setting_StreamTitle.Length);
    Setting_StreamTitle = p1 + var + p2;
}

[SettingsTab name="General" icon="Cogs" order="1"]
    void GeneralSettings() {
        // Reset
        if (UI::Button("Reset to default")) {
            Setting_StreamTitle = "";
            Setting_StreamDelay = 0;
        }

        if(!hasCPCounter){
            UI::Markdown(Icons::ExclamationTriangle + " You don't have the [Checkpoint Counter](https://openplanet.dev/plugin/checkpointcounter) plugin. All checkpoint related variables will be disabled!");
            UI::Separator();
        }

        Setting_Enabled = UI::Checkbox("Plugin enabled", Setting_Enabled);
        if(!Setting_Enabled) UI::BeginDisabled();

        // UI::SetKeyboardFocusHere(StreamTitleCursorPos);
        Setting_StreamTitle = UI::InputText("Stream title"+"##inputstreamtitle", Setting_StreamTitle, UI::InputTextFlags::CallbackAlways, UI::InputTextCallback(StreamTitleCallback));
        UI::SameLine();
        UI::PushStyleColor(UI::Col::Text, vec4(0.4f, 0.4f, 0.4f, 1.0f));
        UI::Text(Icons::QuestionCircle);
        UI::PopStyleColor();
        if(UI::IsItemHovered())
        {
            UI::BeginTooltip();
            UI::Text("The stream title will be trimmed at 140 characters (Twitch limit) automatically.");
            UI::EndTooltip();
        }

        if(UI::Button("Get current stream title")) {
            // GetStreamTitle();
            startnew(CoroutineFunc(GetStreamTitle));
        }
        // UI::SameLine();
        // UI::PushStyleColor(UI::Col::Text, vec4(0.4f, 0.4f, 0.4f, 1.0f));
        // UI::Text(Icons::QuestionCircle);
        // UI::PopStyleColor();
        if (UI::IsItemHovered())
        {
            UI::BeginTooltip();
            UI::Text(Icons::ExclamationTriangle + " Will override all your variables!");
            UI::EndTooltip();
        }

        UI::SameLine();
        if(UI::Button("Force update the stream title"+ForceUpdateLoadingStatus)) {
            startnew(CoroutineFunc(UpdateStreamTitle));
        }

        // UI::SetNextItemWidth(100.);
        Setting_StreamDelay = UI::SliderFloat("Stream delay"+"##slider_delay", Setting_StreamDelay, 0, 30, "%1.f second(s)");
        // Setting_StreamDelay = Math::Floor(Setting_StreamDelay * 2) / 2;
        // Round up to nearest .5
        
        UI::SameLine();
        UI::PushStyleColor(UI::Col::Text, vec4(0.4f, 0.4f, 0.4f, 1.0f));
        UI::Text(Icons::QuestionCircle);
        UI::PopStyleColor();
        if(UI::IsItemHovered())
        {
            UI::BeginTooltip();
            UI::Text("In seconds");
            UI::EndTooltip();
        }

        UI::NewLine();
        UI::Separator();
        UI::NewLine();

        // UI::Markdown("# Variable list");
        if (UI::CollapsingHeader("Variable list")) {
            UI::Text(Icons::InfoCircle + ' Click anywhere to insert the text at the cursor position.');
            // UI::NewLine();

            UI::SelectableFlags selectableFlag = UI::SelectableFlags::SpanAllColumns;
            if(UI::BeginTable("tableVariableList", 3)){
                UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::TableHeader("Variable");
                    UI::TableNextColumn();
                    UI::TableHeader("Explanation");
                    UI::TableNextColumn();
                    UI::TableHeader("Option");

                for(uint i = 0; i < VariableList.Length; i++){
                    UI::SelectableFlags selectableflag = (VariableList[i][2] == "cp" && !hasCPCounter ? UI::SelectableFlags::Disabled : UI::SelectableFlags::None);

                    UI::TableNextRow();
                        UI::TableNextColumn();
                        UI::AlignTextToFramePadding();
                        UI::Selectable(VariableList[i][0]+"##selectable1"+i, false, selectableflag);
                        if(UI::IsItemClicked())
                        {
                            // IO::SetClipboard(VariableList[i][0]);
                            // print(StreamTitleCursorPos);
                            // string tmp = Setting_StreamTitle;
                            StreamTitleInsertVariable(VariableList[i][0]);
                            // UI::SetKeyboardFocusHere(-5);
                        }
                        // if (UI::IsItemHovered())
                        // {
                        //     UI::BeginTooltip();
                        //     UI::Text(VariableList[i][1]+". (click to copy)");
                        //     UI::EndTooltip();
                        // }
                        UI::TableNextColumn();
                        UI::Selectable(VariableList[i][1]+"##selectable2"+i, false, selectableflag);
                        if(UI::IsItemClicked())
                        {
                            StreamTitleInsertVariable(VariableList[i][0]);
                        }
                        UI::TableNextColumn();

                        if(VariableList[i][2] == "cp" && !hasCPCounter) UI::BeginDisabled();

                        UI::Button("Copy to clipboard"+"##button"+i);
                        if(UI::IsItemHovered()){
                        {
                            UI::BeginTooltip();
                            UI::Text(VariableList[i][0]);
                            UI::EndTooltip();
                        }
                        }
                        if(UI::IsItemClicked())
                        {
                            IO::SetClipboard(VariableList[i][0]);
                            UI::ShowNotification("Copied!");
                        }
                        // if (UI::IsItemHovered())
                        // {
                        //     UI::BeginTooltip();
                        //     UI::Text(VariableList[i][0]);
                        //     UI::EndTooltip();
                        // }
                        if(VariableList[i][2] == "cp" && !hasCPCounter) UI::EndDisabled();
                }
                UI::EndTable();
            }
        }

        if(!Setting_Enabled) UI::EndDisabled();
    }

[SettingsTab name="Strings" icon="Pencil" order="2"]
    void StringsSettings() {

    }
[SettingsTab name="Tokens" icon="Lock" order="3"]
    void TokensSettings() {
        // Reset
        if (UI::Button("Reset to default")) {
            Setting_AdvancedMode = false;
            Setting_ClientID = "q6batx0epp608isickayubi39itsckt";
            Setting_AccessToken = "";
            Setting_BroadcasterId = "";
        }

        Setting_AdvancedMode = UI::Checkbox("Advanced mode", Setting_AdvancedMode);
        UI::SameLine();
        UI::PushStyleColor(UI::Col::Text, vec4(0.4f, 0.4f, 0.4f, 1.0f));
        UI::Text(Icons::QuestionCircle);
        UI::PopStyleColor();
        if (UI::IsItemHovered())
        {
            UI::BeginTooltip();
            UI::Text("Will use Twitch Chat Password Generator ClientID if disabled.");
            UI::EndTooltip();
        }

        if(Setting_AdvancedMode){
            UI::InputText("Client ID", Setting_ClientID);
            UI::SameLine();
            UI::PushStyleColor(UI::Col::Text, vec4(0.4f, 0.4f, 0.4f, 1.0f));
            UI::Text(Icons::QuestionCircle);
            UI::PopStyleColor();
            if (UI::IsItemHovered())
            {
                UI::BeginTooltip();
                UI::Text("You can find a tutorial on how to get one by going on the plugin page.");
                UI::EndTooltip();
            }
        }else{
            if(UI::Button("Get OAuth token")) {
                OpenBrowserURL("https://twitchapps.com/tmi/");
            }
        }

        Setting_AccessToken = UI::InputText("OAuth token", Setting_AccessToken, UI::InputTextFlags::Password);
        UI::SameLine();
        UI::PushStyleColor(UI::Col::Text, vec4(0.4f, 0.4f, 0.4f, 1.0f));
        UI::Text(Icons::QuestionCircle);
        UI::PopStyleColor();
        if (UI::IsItemHovered())
        {
            UI::BeginTooltip();
            UI::Text("Please include the \"oauth:\" part.");
            UI::EndTooltip();
        }

        Setting_BroadcasterId = UI::InputText("Twitch channel name", Setting_BroadcasterId);

        // General
        // Setting_ClientID = UI::InputText("Sound Volume", Setting_ClientID);
        
    }

[SettingsTab name="Saves" icon="Kenney::Save" order="4"]
    void SavesSettings() {
        UI::Text("Save your recurring templates here.");
        UI::NewLine();
        Setting_Save1 = UI::InputText("Save 1", Setting_Save1);
        Setting_Save2 = UI::InputText("Save 2", Setting_Save2);
        Setting_Save3 = UI::InputText("Save 3", Setting_Save3);
        Setting_Save4 = UI::InputText("Save 4", Setting_Save4);
        Setting_Save5 = UI::InputText("Save 5", Setting_Save5);
    }