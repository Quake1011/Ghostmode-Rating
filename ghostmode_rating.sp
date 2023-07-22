#define PLUGIN_NAME 	"GHOSTMODE RATING"
#define PLUGIN_VERSION 	"0.0.3"

public Plugin myinfo = 
{ 
	name = PLUGIN_NAME, 
	author = "Quake1011",
	description = "Ghostmode rating plugin for CS:GO", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/Quake1011" 
};

Database db;
ArrayList Rating, Scores;
int iMenuPos[MAXPLAYERS+1], iMax = 100, currenttype[MAXPLAYERS+1];
char buffer[256], sQuery[256];

public void OnPluginStart()
{
	Database.Connect(SQLConnectCB, "ghostmode");
	LoadTranslations("ghostmode_rating.phrases.txt");
	
	Rating = Scores = CreateArray(256);
	
	HookEvent("player_death", EventPlayerDeath, EventHookMode_Post);
	
	RegConsoleCmd("sm_stat", CMDRating);
}

public void SQLConnectCB(Database hdb, const char[] error, any data)
{
	if(!error[0] && hdb) 
	{
		db = hdb;
		
		LogMessage("Ghost rating successfully connected");
		
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ghostmode_rating` (\
														`id`     AUTO_INCREMENT,\
														`steam`  VARCHAR (22)   PRIMARY KEY,\
														`nick`   VARCHAR (256),\
														`ghosts` INTEGER (10),\
														`cts`    INTEGER (10))");
		db.Query(SQLCreateTable, sQuery, _, DBPrio_High);
	}
	else 
		LogMessage("Connecting rating: %s", error);
}

public void SQLCreateTable(Database hdb, DBResultSet results, const char[] error, any data)
{
	if(!error[0] && hdb) 
		LogMessage("Table successfully created or already exists");
	else 
		LogMessage("Rating tables: %s", error);
}

public Action CMDRating(int client, int args)
{
	if(0 < client <= MaxClients && IsClientInGame(client)) 
		OpenRatingMenu(client);
	return Plugin_Handled;
}

void OpenRatingMenu(int client)
{
	Menu hMenu = CreateMenu(RatingHandler);
	Format(buffer, sizeof(buffer), "%t", "RatingTitle");
	hMenu.SetTitle(buffer);
	Format(buffer, sizeof(buffer), "%t", "GhostTOP");
	hMenu.AddItem("gh", buffer);
	Format(buffer, sizeof(buffer), "%t", "CtsTOP");
	hMenu.AddItem("ct", buffer);
	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(client, 0);
}

public int RatingHandler(Menu menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select: 
		{
			if(item == 1) 
				OutputTop(2, client);
			else if(item == 2) 
				OutputTop(3, client);
		}
	}
	return 0;
}

void OutputTop(int type, int client)
{
	DataPack dp = CreateDataPack();
	dp.WriteCell(type);
	dp.WriteCell(client);
	
	if(type == 2) 		
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "SELECT `nick`, `ghosts` FROM `ghostmode_rating` ORDER BY `ghosts` DESC LIMIT 100");
	else if(type == 3) 	
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "SELECT `nick`, `cts` FROM `ghostmode_rating` ORDER BY `cts` DESC LIMIT 100");

	db.Query(SQLGetTOPToArray, sQuery, dp, DBPrio_High);
}

public void SQLGetTOPToArray(Database hdb, DBResultSet results, const char[] error, DataPack hdp)
{
	hdp.Reset();
	int type = hdp.ReadCell();
	int client = hdp.ReadCell();
	delete hdp;
	
	if(!error[0] && results)
	{
		if(results.HasResults && results.RowCount && results.FetchRow())
		{
			Rating.Clear();
			Scores.Clear();
			
			char temp[256];
			do
			{
				results.FetchString(0, temp, sizeof(temp));
				Rating.PushString(temp);
				Scores.Push(results.FetchInt(1));
			} while(results.FetchRow());
			
			OpenTopToMenu(client, type);
			iMenuPos[client] = 1;
		}
	}
	else 
		LogMessage("Error SELECTOR: %s", error);
}

public void OnClientPutInServer(int client)
{
	iMenuPos[client] = 0;
}

void OpenTopToMenu(int client, int type)
{
	char[][] aadata = new char[iMax][MAX_NAME_LENGTH+32];
	for(int i = 0; i < Rating.Length && i < iMax; i++)
	{
		Rating.GetString(i, buffer, sizeof(buffer));
		Format(aadata[i], MAX_NAME_LENGTH+32, "#%d. %s [%i]", i+1, buffer, Scores.Get(i));
	}
	
	if(type == 2) 
		Format(buffer, sizeof(buffer), "%t", "GhostTOP");	
	else if(type == 3) 
		Format(buffer, sizeof(buffer), "%t", "CtsTOP");
	
	Panel hPanel = CreatePanel();
	hPanel.SetTitle(buffer);
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	hPanel.DrawText("-----------------------------");
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	int i = iMenuPos[client] * 10;
	int start = i;
	int end = i + 9;
	
	if(end > iMax) 
		end = iMax;
	
	for(int k = i; k <= end; k++) 
		hPanel.DrawText(aadata[k]);
	
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	hPanel.DrawText("-----------------------------");
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

	if(iMenuPos[client])
	{
		hPanel.CurrentKey = 6;
		FormatEx(buffer, sizeof(buffer), "<== (%d - %d)", start - 9, start);
		hPanel.DrawItem(buffer);
	}
	
	if(end < iMax-1)
	{
		i = end + 11;
		if(i > iMax) 
			i = iMax;
		hPanel.CurrentKey = 7;
		FormatEx(buffer, sizeof(buffer), "==> (%d - %d)", end + 2, i);
		hPanel.DrawItem(buffer);
	}
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);	
	hPanel.CurrentKey = 8;
	hPanel.DrawItem("Назад");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem("Выход");
	hPanel.Send(client, PanelHandler, 0);
	delete hPanel;
	
	currenttype[client] = type;
}

public int PanelHandler(Menu menu, MenuAction action, int client, int item)
{
	switch(item)
	{
		case 6:
		{
			iMenuPos[client]--;
			OpenTopToMenu(client, currenttype[client]);
		}
		case 7:
		{
			iMenuPos[client]++;
			OpenTopToMenu(client, currenttype[client]);
		}
		case 8:
		{
			iMenuPos[client] = 0;
			OpenRatingMenu(client);
		}
		case 9: 
			iMenuPos[client] = 0;
	}
	return 0;
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsFakeClient(client))
	{
		char auth[22];
		GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "INSERT INTO `ghostmode_rating` (`steam`, `nick`, `ghosts`, `cts`) VALUES ('%s', '%N', 0, 0)", auth, client);
		SQL_FastQuery(db, sQuery);		
	}
}

public void EventPlayerDeath(Event hEvent, const char[] sEvent, bool bdb)
{
	int client = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		int team = GetClientTeam(client);
		if(team == 2) 
			AddKillToDb(client, 2);
		else if(team == 3) 
			AddKillToDb(client, 3);
	}
}

void AddKillToDb(int client, int team)
{
	char auth[22];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	if(team == 2) 		
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "UPDATE `ghostmode_rating` SET `ghosts` = `ghosts`+1 WHERE `steam` = '%s'", auth);
	else if(team == 3) 	
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "UPDATE `ghostmode_rating` SET `cts` = `cts`+1 WHERE `steam` = '%s'", auth);
	SQL_FastQuery(db, sQuery);
}
