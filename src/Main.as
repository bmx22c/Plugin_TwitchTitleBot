// Thanks to PHLARX for the CP counter (https://openplanet.nl/files/79)
// Thanks to tooInfinite for the help on the Trackmania API
// Thanks to Miss for the server informations (YOINKED it from the Discord script)

enum FormattingType
{
	Fixed,
	Custom
}

// bool Setting_Enabled = false;

FormattingType Setting_Formatting;

string Setting_StringCurrentPersonnalBest;
string Setting_StringNoCurrentPersonnalBest;


string mapName = "";
string mapAuthor = "";
string mapAuthorTime = "";

string serverName = "";
int serverNbrPlayer = -1;
int serverMaxPlayer = 0;

string pb = "";

string tmxURL = "";
string tmioURL = "";

int CPcrt = 0;
int CPnbr = 0;

string mapId = "";
string serverLogin = "";
int nbrPlayers = -1;

bool inMenu = true;
bool mapFound = false;
bool checkedInMenu = false;
bool bypass = false;
bool oldStatus = false;
bool previousInMenu = true;

string activeColor = "$F30";
string colorRed = "$F30";
string colorGreen = "$3C3";

string previousContentCP = "";
string previousContentPB = "";

CTrackMania@ g_app;
CTrackManiaNetwork@ network;
CGameCtnChallenge@ GetCurrentMap()
{
#if MP41 || TMNEXT
	return g_app.RootMap;
#else
	return g_app.Challenge;
#endif
}

void UpdateStreamTitle()
{
	if(Setting_Enabled){
		sleep(Setting_StreamDelay*1000);
		
		string title = Setting_StreamTitle;
		title = (title == "" ? "My awesome stream" : title);

		title = Regex::Replace(title, "\\{map_name\\}", mapName);
		title = Regex::Replace(title, "\\{map_author\\}", mapAuthor);
		title = Regex::Replace(title, "\\{map_author_time\\}", mapAuthorTime);

		title = Regex::Replace(title, "\\{server_name\\}", serverName);
		title = Regex::Replace(title, "\\{server_nbr_player\\}", ""+serverNbrPlayer);
		title = Regex::Replace(title, "\\{server_max_player\\}", ""+serverMaxPlayer);

		title = Regex::Replace(title, "\\{pb\\}", pb);

		title = Regex::Replace(title, "\\{TMX_URL\\}", tmxURL);
		title = Regex::Replace(title, "\\{TMIO_URL\\}", tmioURL);

		title = Regex::Replace(title, "\\{cp_crt\\}", ""+CPcrt);
		title = Regex::Replace(title, "\\{cp_nbr\\}", ""+CPnbr);

		// 140 chars max
		title = title.SubStr(0, 139);

		Net::HttpRequest req;
		req.Method = Net::HttpMethod::Patch;
		req.Headers["Content-Type"] = "application/json";
		req.Headers["Client-ID"] = (Setting_AdvancedMode ? Setting_ClientID : "q6batx0epp608isickayubi39itsckt");
		req.Headers["Authorization"] = "Bearer " + Regex::Replace(Setting_AccessToken, "oauth:", "");
		req.Url = "https://api.twitch.tv/helix/channels?broadcaster_id=" + Setting_BroadcasterId;
		req.Body = '{"title":"'+title+'"}';
		req.Start();
		while (!req.Finished()) {
			yield();
		}

		// print("Title changed: "+title);
	}
}

void GetStreamTitle()
{
	Net::HttpRequest req;
	req.Method = Net::HttpMethod::Get;
	req.Headers["Accept"] = "application/json";
	req.Headers["Content-Type"] = "application/json";
	req.Headers["Client-ID"] = (Setting_AdvancedMode ? Setting_ClientID : "q6batx0epp608isickayubi39itsckt");
	req.Headers["Authorization"] = "Bearer " + Regex::Replace(Setting_AccessToken, "oauth:", "");
	req.Url = "https://api.twitch.tv/helix/channels?broadcaster_id=" + Setting_BroadcasterId;
	req.Start();
	while (!req.Finished()) {
		yield();
	}

	auto json = Json::Parse(req.String());
	if(json["error"].GetType() == Json::Type::String){
		print('Error connecting to the API');
		return;
	}

	Setting_StreamTitle = json["data"][0]["title"];

	// print("Title changed: "+title);

	// Net::HttpRequest req;
	// req.Method = Net::HttpMethod::Get;
	// req.Headers["Accept"] = "application/json";
	// req.Headers["Content-Type"] = "application/json";
	// req.Headers["Client-ID"] = Setting_ClientId;
	// req.Headers["Authorization"] = "Bearer " + Setting_Bearer;
	// req.Url = "https://api.twitch.tv/helix/channels?broadcaster_id=" + Setting_BroadcasterId;
	// req.Start();
	// while (!req.Finished()) {
	// 	yield();
	// }
	// // TODO - Handle bad request/fails
	// // print(req.String());

	// auto json = Json::Parse(req.String());
	// if(json["error"].GetType() == Json::Type::String){
	// 	print('Error connecting to the API');
	// 	return;
	// }

	// Setting_LiveTitle = json["data"][0]["title"];
}

void Main() {
	@g_app = cast<CTrackMania>(GetApp());
	@network = cast<CTrackManiaNetwork>(GetApp().Network);

	PopulateVarList();

	while (true) {
		if(Setting_Enabled)
		{
			CheckMap();
			ServerInfo();
			PbInfo();
			Url();
			CPCounter();
		}
		yield();
	}
}

void OnDestroyed()
{
	Setting_Enabled = false;
}

void RenderMenu()
{
	if (!UI::BeginMenu("\\$60f" + Icons::Brands::Twitch + "\\$9cf\\$z Twitch Title Bot")) {
		return;
	}
		if (UI::MenuItem("\\$z" + Icons::PowerOff + "\\$z Active", "", Setting_Enabled)) {
			Setting_Enabled = !Setting_Enabled;
			activeColor = (Setting_Enabled ? colorGreen : colorRed);

		}
	UI::EndMenu();
}

void OnSettingsChanged()
{
	bypass = true;

	if(Setting_Enabled)
	{
		startnew(CoroutineFunc(SendSettings));
		startnew(CoroutineFunc(CheckMap));
		startnew(CoroutineFunc(ServerInfo));
		startnew(CoroutineFunc(PbInfo));
		startnew(CoroutineFunc(Url));
		startnew(CoroutineFunc(CPCounter));
		startnew(CoroutineFunc(SendStatus));
	}else{
		startnew(CoroutineFunc(SendStatus));
	}
}

string Replace(const string &in search, const string &in  replace, const string &in  subject)
{
	return Regex::Replace(subject, search, replace);
}

void ResetServerInfo()
{
	serverLogin = '';
	nbrPlayers = -1;

}

void Url()
{
	auto currentMap = GetCurrentMap();
	if (currentMap !is null) {
		string UIDMap = currentMap.MapInfo.MapUid;

		string urlSearch = "https://trackmania.exchange/api/maps/get_map_info/multi/" + UIDMap;

		Net::HttpRequest req;
		req.Method = Net::HttpMethod::Get;
		req.Url = urlSearch;
		req.Start();
		while (!req.Finished()) {
			yield();
		}
		string response = req.String();

		// Evaluate reqest result
		Json::Value returnedObject = Json::Parse(response);
		try {
			if (returnedObject.Length > 0) {
				if(mapFound == false){
					mapFound = true;

					int g_MXId = returnedObject[0]["TrackID"];
				}
			} else {
				if(mapFound == true){
					mapFound = false;
				}
			}
		} catch {
			if(mapFound == true){
				mapFound = false;
			}
		}
	} else {
		if(checkedInMenu == false){
			checkedInMenu = true;

		}
	}
}

void ServerInfo()
{
	auto serverInfo = cast<CGameCtnNetServerInfo>(g_app.Network.ServerInfo);
	if (serverInfo.ServerLogin != "") {
		serverLogin = serverInfo.ServerLogin;
		serverName = StripFormatCodes(serverInfo.ServerName);

		int numPlayers = g_app.Network.PlayerInfos.Length - 1;
		int maxPlayers = serverInfo.MaxPlayerCount;

		if(nbrPlayers != numPlayers){
			previousInMenu = false;
			nbrPlayers = numPlayers;

			serverNbrPlayer = numPlayers;
			serverMaxPlayer = maxPlayers;
		}
	}else{
		if(previousInMenu == false){
			previousInMenu = true;

			ResetServerInfo();
		}
	}
}

void PbInfo()
{
	auto currentMap = GetCurrentMap();
	if (currentMap !is null) {
		checkedInMenu = false;
		auto network = cast<CTrackManiaNetwork>(@g_app.Network);
		string UIDMap = currentMap.MapInfo.MapUid;

		// Thanks Phlarx for this
		if(network.ClientManiaAppPlayground != null){
			auto userInfo = network.ClientManiaAppPlayground.UserMgr;
			MwId userId;
			if (userInfo.Users.Length > 0) {
				userId = userInfo.Users[0].Id;
			} else {
				userId.Value = uint(-1);
			}
			
			auto temps = network.ClientManiaAppPlayground.ScoreMgr.Map_GetRecord_v2(userId, UIDMap, "PersonalBest", "", "TimeAttack", "");
			// print(temps);

			if(temps != 4294967295 && temps != 0){
				string tmp = Setting_StringCurrentPersonnalBest;
				tmp = Replace("\\{pb\\}", StripFormatCodes(Time::Format(temps)), tmp);

				string json = '{"inMap":"true", "played":true, "pb":"'+Time::Format(temps)+'", "custom_formatting":"", "custom_formatting_false": ""}';
				if(previousContentPB != json){
					previousContentPB = json;
				}
			} else {
				string tmp = Setting_StringNoCurrentPersonnalBest;

				string json = '{"inMap":"true", "played":false, "pb":"'+Time::Format(temps)+'", "custom_formatting":"", "custom_formatting_false": ""}';
				if(previousContentPB != json){
					previousContentPB = json;
				}
			}
		}else{
			string json = '{"inMap":"false", "custom_formatting":"", "custom_formatting_false": ""}';
			if(previousContentPB != json){
				previousContentPB = json;
			}
		}
	} else {
		if(checkedInMenu == false){
			checkedInMenu = true;

			string json = '{"inMap":"false", "custom_formatting":"", "custom_formatting_false": ""}';
			if(previousContentPB != json){
				previousContentPB = json;
			}
		}
	}
}

void Authenticate()
{
	Net::HttpRequest req;
	req.Method = Net::HttpMethod::Get;
	req.Url = "https://password.markei.nl/randomsave.txt?count=1&min/max=16";
	req.Start();
	while (!req.Finished()) {
		yield();
	}
	string uniqueCode = req.String();


	OpenBrowserURL('https://api.trackmania.com/oauth/authorize?response_type=code&client_id=915a708930788b5ecd10&scope=&redirect_uri=https://tm-info.digit-egifts.fr/redirect.php&state='+uniqueCode);
}

void SendStatus()
{
	if(oldStatus != Setting_Enabled){
		oldStatus = Setting_Enabled;

	}
}

void SendSettings()
{
	string formattingType = "";
	switch (Setting_Formatting) {
		case FormattingType::Fixed: formattingType = "Fixed"; break;
		case FormattingType::Custom: formattingType = "Custom"; break;
	}
	
}

void SendPb()
{
	auto currentMap = GetCurrentMap();
	if (currentMap !is null) {
		checkedInMenu = false;
		auto network = cast<CTrackManiaNetwork>(@g_app.Network);
		string UIDMap = currentMap.MapInfo.MapUid;

		// Thanks Phlarx for this
		if(network.ClientManiaAppPlayground != null){
			auto userInfo = network.ClientManiaAppPlayground.UserMgr;
			MwId userId;
			if (userInfo.Users.Length > 0) {
				userId = userInfo.Users[0].Id;
			} else {
				userId.Value = uint(-1);
			}
			
			auto temps = network.ClientManiaAppPlayground.ScoreMgr.Map_GetRecord_v2(userId, UIDMap, "PersonalBest", "", "TimeAttack", "");
			print(temps);

			if(temps != 4294967295 && temps != 0){
				string tmp = Setting_StringCurrentPersonnalBest;
				tmp = Replace("\\{pb\\}", StripFormatCodes(Time::Format(temps)), tmp);

				string json = '{"inMap":"true", "played":true, "pb":"'+Time::Format(temps)+'", "custom_formatting":"", "custom_formatting_false": ""}';
				if(previousContentPB != json){
					previousContentPB = json;
					pb = Time::Format(temps);
				}
			} else {
				string json = '{"inMap":"true", "played":false, "pb":"'+Time::Format(temps)+'", "custom_formatting":"", "custom_formatting_false": ""}';
				if(previousContentPB != json){
					previousContentPB = json;
					pb = Time::Format(temps);
				}
			}
		}else{
			string json = '{"inMap":"false", "custom_formatting":"", "custom_formatting_false": ""}';
			if(previousContentPB != json){
				previousContentPB = json;
			}
		}
	} else {
		string json = '{"inMap":"false", "custom_formatting":"", "custom_formatting_false": ""}';
		if(previousContentPB != json){
			previousContentPB = json;
		}
	}
}

void SendUrl()
{
	auto currentMap = GetCurrentMap();
	if (currentMap !is null) {
		string UIDMap = currentMap.MapInfo.MapUid;
		tmioURL = "https://trackmania.io/#/leaderboard/"+UIDMap;

		string urlSearch = "https://trackmania.exchange/api/maps/get_map_info/multi/" + UIDMap;

		Net::HttpRequest req;
		req.Method = Net::HttpMethod::Get;
		req.Url = urlSearch;
		req.Start();
		while (!req.Finished()) {
			yield();
		}
		string response = req.String();

		// Evaluate reqest result
		Json::Value returnedObject = Json::Parse(response);
		try {
			if (returnedObject.Length > 0) {
				int g_MXId = returnedObject[0]["TrackID"];
				tmxURL = "https://trackmania.exchange/maps/"+g_MXId;
			}
		} catch {

		}
	}
}

void CheckMap()
{
	auto currentMap = GetCurrentMap();
	if (currentMap !is null) {
		if(bypass == true  || (mapId != currentMap.EdChallengeId || inMenu == true))
		{
			mapId = currentMap.EdChallengeId;

			mapName = StripFormatCodes(currentMap.MapName);
			mapAuthor = StripFormatCodes(currentMap.AuthorNickName);
			mapAuthorTime = Time::Format(currentMap.TMObjective_AuthorTime);
			UpdateStreamTitle();
			print(mapName);

			
			SendPb();
			SendUrl();
			ServerInfo();
			
			bypass = false;
		}

		inMenu = false;
		checkedInMenu = false;
	} else {
		inMenu = true;
		if(bypass == true || (inMenu == true && checkedInMenu == false)){
			checkedInMenu = true;
			mapName = "";
			UpdateStreamTitle();
			print(mapName);


			SendPb();
			SendUrl();
			ResetServerInfo();
			bypass = false;
		}
	}
}

void CPCounter()
{
#if DEPENDENCY_CHECKPOINTCOUNTER
	if(!CP::inGame){
		string json = '{"inMap":"false", "crt_cp": 0, "max_cp": 0, "custom_formatting":"", "custom_formatting_false": ""}';
		if(previousContentCP != json){
			previousContentCP = json;
			CPcrt = 0;
			CPnbr = 0;
			UpdateStreamTitle();
		}
	}else{
		string json = '{"inMap":"true", "crt_cp": '+CP::curCP+', "max_cp": '+CP::maxCP+', "custom_formatting":"", "custom_formatting_false": ""}';
		if(previousContentCP != json){
			previousContentCP = json;
			CPcrt = CP::curCP;
			CPnbr = CP::maxCP;
			UpdateStreamTitle();
		}
	}
#endif
}