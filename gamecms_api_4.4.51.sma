#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <gamecms>

#define PLUGIN "GameCMS_API"
#define VERSION "4.4.5"
#define AUTHOR "zhorzh78"

//#define PL_GAMETIME				//записывать в БД время, проведенное игроком на сервере
//#define PL_PREFIX				//использовать префиксы в чате из БД сайта. требуется обновление БД и редактирование плагина чата
//#define HLTV_IMMUNITY	"ab"	//выдать флаги HLTV серверу. Закомментировать, если HLTV не используется или не нужны флаги
//#define AMXBANS //Раскомментировать, если используется ЛЮБОЙ AMX Bans
//#define AMXBANS_RBS //Раскомментировать, если используется amxbans_rbs.amxx

#if defined AMXBANS
	#if defined AMXBANS_RBS
		#include <amxbans_rbs>
	#else
		#include <amxbans_core>
	#endif
#endif

#if !defined AMXX_VERSION_RELEASE
#define client_disconnected client_disconnect
#endif

enum _:g_Cvars
{
	Host,
	User,
	Pass,
	Db,
	Url
}

enum _:MFHandle_Type 
{
	#if defined AMXBANS
		Amxbans_Sql_Initialized = 0,
		Admin_Disconnect,
	#endif
	Admin_Connect,
	DB_Init,
	Birthday_Boy,
	Registered_User,
	API_Error,
	#if defined PL_PREFIX
		Set_User_Prefix,
	#endif
	Load_Data
}

enum _:user_DataID
{
	u_login[33],
	u_name[65],
	u_birth[12],
	u_info_pass[33],
	u_new_messages,
	u_group[65],
	#if defined PL_GAMETIME
		u_gametime,
	#endif
	#if defined PL_PREFIX
		u_prefix[33],
	#endif
	Float:u_shilings,
	Float:u_old_shilings,
	f_thanks,
	f_answers,
	f_reit
}

#if defined AMXBANS
	new g_dbPrefix[32];
	new pcvarprefix;
	new Handle:info;
#endif

new Data[AdminInfo], Cvars[g_Cvars], MFHandle[MFHandle_Type];
new Forum_Data[MAX_PLAYERS + 1][user_DataID];
new g_ServerAddr[2][24], configsDir[32], configsFile[55], passfield[33], g_defFlags;
new amx_password_field, amx_default_access, AdminCount, PurchasedCount;
new Array:g_AllAdmins_Info, Array:g_AllPurch_Services, Array:g_User_Services;
new Trie:g_OnlineAdminsInfo, Trie:g_AdminInfo;
new Handle:g_DbTuple, g_server_id;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	amx_password_field = register_cvar("amx_password_field", "_pw");
	amx_default_access = register_cvar("amx_default_access", "z");

	register_cvar("amx_vote_ratio", "0.04");
	register_cvar("amx_vote_time", "10");
	register_cvar("amx_vote_answers", "1");
	register_cvar("amx_vote_delay", "60");
	register_cvar("amx_last_voting", "0");
	register_cvar("amx_show_activity", "2");
	register_cvar("amx_votekick_ratio", "0.40");
	register_cvar("amx_voteban_ratio", "0.40");
	register_cvar("amx_votemap_ratio", "0.40");

	#if defined AMXBANS
		register_cvar("amx_sql_host", "127.0.0.1");
		register_cvar("amx_sql_user", "root");
		register_cvar("amx_sql_pass", "");
		register_cvar("amx_sql_db", "amx");
		register_cvar("amx_sql_type", "mysql");
		pcvarprefix = register_cvar("amx_sql_prefix", "amx");
	#endif
	
	//Квары GameCMS
	register_cvar("gamecms_api", VERSION, FCVAR_SERVER);
	Cvars[Host]	= register_cvar("cms_hostname", "127.0.0.1");
	Cvars[User]	= register_cvar("cms_username", "root");
	Cvars[Pass]	= register_cvar("cms_password", "password", FCVAR_PROTECTED);
	Cvars[Db]	= register_cvar("cms_dbname", "cmsbase");
	Cvars[Url]	= register_cvar("cms_url", "http://site.ru");
	
	register_concmd("amx_reloadadmins", "cmdReload", ADMIN_RCON);

	forwards_create();
	
	get_configsdir(configsDir, charsmax(configsDir));
	formatex(configsFile, charsmax(configsFile), "%s/gamecms/gamecms.cfg", configsDir);

	if(!file_exists(configsFile))
	{
		log_amx("Plugin paused. Config file is not found!");
		SendDbResult(0, Empty_Handle, Empty_Handle);
		return;
	}
	
	server_cmd("exec %s", configsFile);
	server_cmd("exec %s/amxx.cfg", configsDir);
	
	#if defined AMXBANS
		server_cmd("exec %s/sql.cfg", configsDir);
	#endif
	
	server_exec();
}

public plugin_cfg()
{
	new HostName[24], UserName[33], Password[33], DbName[33];
	get_pcvar_string(Cvars[Host], HostName, charsmax(HostName));
	get_pcvar_string(Cvars[User], UserName, charsmax(UserName));
	get_pcvar_string(Cvars[Pass], Password, charsmax(Password));
	get_pcvar_string(Cvars[Db], DbName, charsmax(DbName));
	get_pcvar_string(Cvars[Url], SiteUrl, charsmax(SiteUrl));

	g_DbTuple = SQL_MakeDbTuple(HostName, UserName, Password, DbName, 20);
	
	#if defined AMXBANS
		get_pcvar_string(pcvarprefix, g_dbPrefix, 31);
		info = SQL_MakeStdTuple(15);
		new ret_AmxDB;
		ExecuteForward(MFHandle[Amxbans_Sql_Initialized], ret_AmxDB, info, g_dbPrefix);
	#endif

	new err, error[128];
	new Handle:SQL_Connection = SQL_Connect(g_DbTuple, err, error, charsmax(error)); // Проверка доступности БД
	
	if(SQL_Connection == Empty_Handle)
	{
		log_amx("%s",error);
		SendDbResult(0, SQL_Connection, Empty_Handle);
		return;
	}

	static ServerAddr[24];
	get_user_ip(0, ServerAddr, charsmax(ServerAddr));
	strtok(ServerAddr, g_ServerAddr[0], charsmax(g_ServerAddr[]), g_ServerAddr[1], charsmax(g_ServerAddr[]), ':');
	new Handle:getSrvId = SQL_PrepareQuery(SQL_Connection, "SELECT `id` FROM `servers` WHERE `servers`.`ip` = '%s' AND `servers`.`port` = '%s';",
		g_ServerAddr[0], g_ServerAddr[1]);
		
	if(SQL_Execute(getSrvId) && SQL_NumResults(getSrvId))
	{
		g_server_id = SQL_ReadResult(getSrvId, SQL_FieldNameToNum(getSrvId, "id"))
		SendDbResult(1, SQL_Connection, getSrvId);
	}
	else
	{
		log_amx("Server is not found on Database");
		SendDbResult(0, SQL_Connection, getSrvId);
		return;
	}

	new szRestPlugins[][] = {"admin.amxx", "admin_sql.amxx", "amxbans_core.amxx", "admin_loader.amxx"};
	for(new i; i < sizeof szRestPlugins; i++)
	{
		if(find_plugin_byfile(szRestPlugins[i]) != INVALID_PLUGIN_ID)
		{
			log_amx("WARNING: %s plugin running! Stopped.", szRestPlugins[i]);
			pause("acd", szRestPlugins[i]);
		}
	}
	
	new ret_DB; ExecuteForward(MFHandle[DB_Init], ret_DB, g_DbTuple);
	log_amx("Соединение с БД GameCMS установлено");
	
	g_AllAdmins_Info = ArrayCreate(AdminInfo);
	g_AllPurch_Services = ArrayCreate(AdminInfo);
	g_OnlineAdminsInfo = TrieCreate();
	g_User_Services = ArrayCreate(AdminInfo);
	g_AdminInfo = TrieCreate();
	
	set_cvar_float("amx_last_voting", 0.0);
	get_pcvar_string(amx_password_field, passfield, charsmax(passfield));
	
	static defaccess[2];
	get_pcvar_string(amx_default_access, defaccess, charsmax(defaccess));
	g_defFlags = read_flags(strlen(defaccess)? defaccess : "z");
	set_task(4.0, "maps_configs_load");

	load_admins();
}

stock SendDbResult(result, Handle:hndlConn, Handle:hndlQuery)
{
	if(hndlConn != Empty_Handle)
		SQL_FreeHandle(hndlConn);
	if(hndlQuery != Empty_Handle)
		SQL_FreeHandle(hndlQuery);
	if(!result)
	{
		new ret_pause; ExecuteForward(MFHandle[API_Error], ret_pause);
		pause("a");
	}
}

public maps_configs_load()
{
	static mapConfig[48], curMap[24], mapPrefix[8], mapName[24];
	get_mapname(curMap, charsmax(curMap));

	formatex(mapConfig, charsmax(mapConfig), "%s/maps/%s.cfg", configsDir, curMap);
	if (!file_exists(mapConfig))
	{
		strtok(curMap, mapPrefix, charsmax(mapPrefix), mapName, charsmax(mapName), '_');
		formatex(mapConfig, charsmax(mapConfig), "%s/maps/prefix_%s.cfg", configsDir, mapPrefix);
	}

	if (file_exists(mapConfig))
		server_cmd("exec %s", mapConfig);
}

public load_admins()
{
	new pquery[633], len;
	len+= formatex(pquery[len], charsmax(pquery)- len, 	
	"SELECT `a`.`id`,cast(convert(`a`.`name` using utf8)as binary) as `auth`,`pass`,\
	COALESCE(REPLACE(`ad`.`rights_und`,'none',`s`.`rights`),`ad`.`rights_und`) AS `flags`,`a`.`type`,\
	`ending_date` as `expired`,`ad`.`service`,`service_time`,`a`.`active`,\
	cast(convert(`s`.`name` using utf8)as binary) as `service_name`,");
	len+= formatex(pquery[len], charsmax(pquery)- len, 	
	"cast(convert(`cause` using utf8) as binary) as `cause`\
	FROM `admins` a LEFT JOIN `admins_services` ad ON `ad`.`admin_id`=`a`.`id`\
	LEFT JOIN `servers` sr ON `server`=`sr`.`id`\
	LEFT JOIN `services` s ON `ad`.`service`=`s`.`id`\
	WHERE `sr`.`id` = '%d'", g_server_id);

	SQL_ThreadQuery(g_DbTuple, "load_admins_post", pquery);
}

public load_admins_post(failstate, Handle:query, const error[], errornum)
{
	if(SQL_Error(error, errornum, failstate))
		return;
	
	ArrayClear(g_AllAdmins_Info);
	ArrayClear(g_AllPurch_Services);
	TrieClear(g_OnlineAdminsInfo);
	AdminCount = 0;
	PurchasedCount = 0;
	
	if(SQL_NumResults(query)) 
	{	
		while(SQL_MoreResults(query))
		{
			Data[AdminId] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "auth"), Data[AdminAuthId], charsmax(Data[AdminAuthId]));
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "pass"), Data[AdminPassword], charsmax(Data[AdminPassword]));
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "flags"), Data[AdminServiceFlags], charsmax(Data[AdminServiceFlags]));
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "type"), Data[AdminType], charsmax(Data[AdminType]));
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "expired"), Data[AdminExpired], charsmax(Data[AdminExpired]));
			Data[AdminServiceId] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "service"));
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "service_name"), Data[AdminServiceName], charsmax(Data[AdminServiceName]));
			Data[AdminServiceTime] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "service_time"));
			Data[AdminActive] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "active"));
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "cause"), Data[AdminReason], charsmax(Data[AdminReason]));

			mysql_escape_string(Data[AdminAuthId], charsmax(Data[AdminAuthId]));
			mysql_escape_string(Data[AdminServiceName], charsmax(Data[AdminServiceName]));
			mysql_escape_string(Data[AdminReason], charsmax(Data[AdminReason]));
			
			if(containi(Data[AdminServiceFlags], "_") != -1)
			{
				ArrayPushArray(g_AllPurch_Services, Data);
				PurchasedCount++;
			}
			else
			{
				ArrayPushArray(g_AllAdmins_Info, Data);
				AdminCount++;
			}
				
			SQL_NextRow(query);
		}
	}

	log_amx("Загружено из базы данных: аккаунтов %d шт. / других услуг: %d шт.", AdminCount, PurchasedCount);
	
	if (AdminCount > 0)
	{
		for(new i = 1; i <= MAX_PLAYERS; i++)
		{
			if(!is_user_connected(i) && !is_user_connecting(i))
				continue;

			accessUser(i);
		}
	}
	
	new ret_load_data;
	ExecuteForward(MFHandle[Load_Data], ret_load_data);
}

public client_authorized(id)
{
	#if defined HLTV_IMMUNITY
	if(is_user_hltv(id))
		return set_user_flags(id, read_flags(HLTV_IMMUNITY));
	#endif
	
	return AdminCount > 0 ? accessUser(id):  PLUGIN_CONTINUE;
}

public client_putinserver(id)
	load_ForumData(id);

public client_disconnected(id)
{
	TrieDeleteKey(g_OnlineAdminsInfo, get_id_key(id));
	if(Forum_Data[id][u_login][0])
		Update_Data(id, "disconnect", "0");
	
	#if defined AMXBANS
		new ret_admin_disconnect;
		ExecuteForward(MFHandle[Admin_Disconnect], ret_admin_disconnect, id);
	#endif
	
	arrayset(Forum_Data[id], 0, user_DataID);
}

public cmdReload(id, level, cid)
{
	if(cmd_access(id, level, cid, 1))
		load_admins();
	
	return PLUGIN_HANDLED;
}

accessUser(id, const newname[] = "", const newpassword[] = "")
{
	#if defined HLTV_IMMUNITY
	if(is_user_hltv(id))
		return PLUGIN_CONTINUE;
	#endif
	
	static userip[24], userauthid[24], password[33], username[33];

	strlen(newname)?
		copy(username, charsmax(username), newname):
			get_user_name(id, username, charsmax(username));

	strlen(newpassword)?
		copy(password, charsmax(password), newpassword):
			get_user_info(id, passfield, password, charsmax(password));

	get_user_ip(id, userip, charsmax(userip), 1);
	get_user_authid(id, userauthid, charsmax(userauthid));
	copy(Forum_Data[id][u_info_pass], charsmax(Forum_Data[][u_info_pass]), password);
	
	getAccess(id, username, userauthid, userip, password);
	
	return PLUGIN_CONTINUE;
}

getAccess(id, name[], authid[], ip[], password[])
{
	remove_user_flags(id);
	TrieDeleteKey(g_OnlineAdminsInfo, get_id_key(id));
	
	for (new index = 0; index < ArraySize(g_AllAdmins_Info); ++index)
	{
		ArrayGetArray(g_AllAdmins_Info, index, Data);

		if(Data[AdminActive] != 1)
			continue;
		
		new Type = read_flags(Data[AdminType]);
		
		if (((Type & FLAG_AUTHID && equal(authid, Data[AdminAuthId])) || Type & FLAG_IP && equal(ip, Data[AdminAuthId])) ||
		((Type & FLAG_TAG && containi(name, Data[AdminAuthId]) != -1) || equali(name, Data[AdminAuthId])))
		{
			new setAccess = check_access(password, Data[AdminPassword], Type);

			if(!setAccess)
				continue;

			switch(setAccess)
			{
				case 1:
				{
					if(TrieKeyExists(g_OnlineAdminsInfo, get_id_key(id)))
					{
						new tempData[AdminInfo];
						TrieGetArray(g_OnlineAdminsInfo, get_id_key(id), tempData, sizeof tempData);

						if(equal(tempData[AdminType], Data[AdminType]) 
							&& equal(tempData[AdminPassword], Data[AdminPassword]))
						{
							log_amx("Проверка доп. флагов ^"<%s><%s>^" (аккаунт ^"%s^") (флаги ^"%s^") (IP ^"%s^") (истекает ^"%s^")", 
								name, authid, Data[AdminAuthId], Data[AdminServiceFlags], ip, Data[AdminExpired]);
							add(Data[AdminServiceFlags], charsmax(Data[AdminServiceFlags]), tempData[AdminServiceFlags]);
							TrieSetArray(g_OnlineAdminsInfo, get_id_key(id), Data, sizeof Data);
						}
					}
					else
						TrieSetArray(g_OnlineAdminsInfo, get_id_key(id), Data, sizeof Data);
				}
				case 2:
				{
					log_amx("Логин: ^"<%s><%s>^" использовал неправильный пароль (логин ^"%s^") (IP ^"%s^")", 
						name, authid, Data[AdminAuthId], ip);
					client_cmd(id, "echo ^"* Неверный пароль!^"");
					return server_cmd("kick #%d Доступ запрещен! Проверьте пароль или обратитесь к администратору", get_user_userid(id));
				}
			}
		}
	}

	if(TrieGetArray(g_OnlineAdminsInfo, get_id_key(id), Data, sizeof Data))
	{
		client_cmd(id, "echo ^"* Права доступа предоставлены!^"");
		log_amx("Логин ^"<%s><%s>^" (аккаунт ^"%s^" / id= %d) (флаги ^"%s^") (IP ^"%s^") (истекает ^"%s^")", 
		name, authid, Data[AdminAuthId], Data[AdminId], Data[AdminServiceFlags], ip, Data[AdminExpired]);
		
		new ret_admin_connect;
		#if defined AMXBANS
			ExecuteForward(MFHandle[Admin_Connect], ret_admin_connect, id);
		#else
			ExecuteForward(MFHandle[Admin_Connect], ret_admin_connect, id, name, Data[AdminId], read_flags(Data[AdminServiceFlags]));
		#endif
		return set_user_flags(id, read_flags(Data[AdminServiceFlags]));
	}

	return set_user_flags(id, g_defFlags);
}

check_access(password[], Passwd[], Type)
{
	return Type & FLAG_NOPASS ? 1 :
		equal(password, Passwd) ? 1 :
			Type & FLAG_KICK ? 2 :
				0;
}

public client_infochanged(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
 
	new newname[33], oldname[33], newpassword[33];
    
	get_user_name(id, oldname, charsmax(oldname));
	get_user_info(id, "name", newname, charsmax(newname));
	get_user_info(id, passfield, newpassword, charsmax(newpassword));
	
	if (!strcmp(newname, oldname))
		if(!strcmp(newpassword, Forum_Data[id][u_info_pass]))
			return PLUGIN_CONTINUE;

	return accessUser(id, newname, newpassword);
}

//--------------   Форум  ------------------------------//

public load_ForumData(id)
{
	new szSteamId[24], szId[2], szQuery[670], len;
	get_user_authid(id, szSteamId, charsmax(szSteamId));
	szId[0] = id;
	
	new db_pl_gametime[15] = "", db_pl_prefix[68] = "";
	#if defined PL_GAMETIME
		db_pl_gametime = ", `game_time`";
	#endif
	#if defined PL_PREFIX
		db_pl_prefix = ", cast(convert(`users`.`prefix` using utf8) as binary) as `prefix`";
	#endif
	len += formatex(szQuery[len], charsmax(szQuery)-len, 
	"SELECT cast(convert(`users`.`login` using utf8) as binary) as `login`,	cast(convert(`users`.`name` using utf8) as binary)\
	as `name`, `users`.`birth`, `users`.`thanks`, `users`.`answers`,`users`.`reit` %s,(SELECT COUNT(*) FROM `dialogs`\
	WHERE `dialogs`.`user_id2` = `users`.`id` AND `dialogs`.`new` > '0') AS `new_messages`,`users`.`shilings`", db_pl_gametime);
	len += formatex(szQuery[len], charsmax(szQuery)-len,
	",cast(convert(`users_groups`.`name` using utf8) as binary) as `group_name`	%s\
	FROM `users` LEFT JOIN `users_groups` ON `users`.`rights`=`users_groups`.`id`\
	WHERE `users`.`steam_id` = '%s';", db_pl_prefix, szSteamId);
	
	SQL_ThreadQuery(g_DbTuple, "ForumData_Handler", szQuery, szId, sizeof szId);
}

public ForumData_Handler(failstate, Handle:query, error[], errornum, data[], datasize)
{
	if(SQL_Error(error, errornum, failstate) || !SQL_NumResults(query))
		return;

	new id = data[0];
	SQL_ReadResult(query, SQL_FieldNameToNum(query, "login"), Forum_Data[id][u_login], charsmax(Forum_Data[][u_login]));
	SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), Forum_Data[id][u_name], charsmax(Forum_Data[][u_name]));
	SQL_ReadResult(query, SQL_FieldNameToNum(query, "birth"), Forum_Data[id][u_birth], charsmax(Forum_Data[][u_birth]));
	SQL_ReadResult(query, SQL_FieldNameToNum(query, "shilings"), Forum_Data[id][u_shilings]);
	SQL_ReadResult(query, SQL_FieldNameToNum(query, "group_name"), Forum_Data[id][u_group], charsmax(Forum_Data[][u_group]));
	#if defined PL_PREFIX
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "prefix"), Forum_Data[id][u_prefix], charsmax(Forum_Data[][u_prefix]));
		mysql_escape_string(Forum_Data[id][u_prefix], charsmax(Forum_Data[][u_prefix]));
		if(strlen(Forum_Data[id][u_prefix]))
		{
			new ret_set_prefix;	
			ExecuteForward(MFHandle[Set_User_Prefix], ret_set_prefix, id, Forum_Data[id][u_prefix], 1);
		}	
	#endif
	Forum_Data[id][f_thanks] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "thanks"));
	Forum_Data[id][f_answers] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "answers"));
	Forum_Data[id][f_reit] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "reit"));
	Forum_Data[id][u_new_messages] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "new_messages"));
	#if defined PL_GAMETIME
		Forum_Data[id][u_gametime] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "game_time"));
	#endif
	Forum_Data[id][u_old_shilings] = _:Forum_Data[id][u_shilings];
	
	mysql_escape_string(Forum_Data[id][u_login], charsmax(Forum_Data[][u_login]));
	mysql_escape_string(Forum_Data[id][u_name], charsmax(Forum_Data[][u_name]));
	mysql_escape_string(Forum_Data[id][u_group], charsmax(Forum_Data[][u_group]));

	new ret_reg_user;
	ExecuteForward(MFHandle[Registered_User], ret_reg_user, id);
	
	#if defined PL_PREFIX
	if(strlen(Forum_Data[id][u_group]))
	{
		new ret_grp_prefix;	
		ExecuteForward(MFHandle[Set_User_Prefix], ret_grp_prefix, id, Forum_Data[id][u_group], 2);
	}
	#endif
	
	static CurrentTime[6], sz_birth[2][6];
	get_time("%m-%d", CurrentTime, charsmax(CurrentTime)) ;

	strtok(Forum_Data[id][u_birth], sz_birth[0], charsmax(sz_birth[]), sz_birth[1], charsmax(sz_birth[]), '-');

	if(!strcmp(CurrentTime, sz_birth[1]) && strcmp("1900", sz_birth[0]))
	{
		new ret_BB;
		ExecuteForward(MFHandle[Birthday_Boy], ret_BB, id, Forum_Data[id][u_name], SiteUrl);
	}
}

public Update_Data(const id, const param[], const value[])
{	
	new save_usertime[32] = "";
	new Float:balans = str_to_float(value);
	
	if(equali(param, "shilings"))
	{
		if(balans == 0)
			return;

		Forum_Data[id][u_shilings] += balans;
		Forum_Data[id][u_old_shilings] +=balans;
	}

	else if (equali(param, "disconnect"))
	{
		balans = Forum_Data[id][u_shilings]- Forum_Data[id][u_old_shilings];
		#if defined PL_GAMETIME
			formatex(save_usertime, charsmax(save_usertime), ", game_time=game_time+'%d'", get_user_time(id));
		#endif
	}

	#if !defined PL_GAMETIME
		if(balans == 0)
			return;
	#endif
	
	new szSteamId[24], szId[2], szSaveQuery[128];
	get_user_authid(id, szSteamId, charsmax(szSteamId));
	
	formatex(szSaveQuery, charsmax(szSaveQuery), 
	"UPDATE users SET shilings = shilings+'%.2f'%s WHERE steam_id = '%s';", balans, save_usertime, szSteamId);

	SQL_ThreadQuery(g_DbTuple, "Free_Handler", szSaveQuery, szId, sizeof szId);
}

public Free_Handler(failstate, Handle:query, error[], errornum, data[], datasize)
{
	return SQL_Error(error, errornum, failstate);
}

//--------------  не Форум )  ------------------------------//

public plugin_end() 
{
	if(g_DbTuple != Empty_Handle) 
		SQL_FreeHandle(g_DbTuple);

	ArrayDestroy(g_AllAdmins_Info);
	ArrayDestroy(g_AllPurch_Services);
	ArrayDestroy(g_User_Services);
}

//------------------ Стоки  и нативы --------------------------------//

public plugin_natives() 
{
	register_native("days_left_info", "native_days_left_info");
	register_native("get_forum_data", "native_get_forum_data");
	register_native("is_registered_user", "native_is_registered_user");
	register_native("get_user_shilings", "native_get_user_shilings");
	register_native("set_user_shilings", "native_set_user_shilings");
	register_native("get_alladmins_data", "native_get_alladmins_data");
	register_native("get_admin_data", "native_get_admin_data");
	register_native("get_purchased_services", "native_get_purchased_services");
	register_native("get_user_services", "native_get_user_services");
	register_native("check_admin_active", "native_check_admin_active");
	register_native("get_admin_info", "native_get_admin_info");
	register_native("get_serverID", "native_get_serverID");
	register_native("get_AdminID", "native_get_AdminID");

	#if defined PL_GAMETIME
		register_native("get_user_gametime", "native_get_user_gametime");
	#endif
	#if defined AMXBANS
	register_library("AMXBansCore");
	register_native("amxbans_get_db_prefix", "native_amxbans_get_prefix");
	register_native("amxbans_get_admin_nick", "native_amxbans_get_nick");
	register_native("amxbans_get_static_bantime", "native_amxbans_static_bantime");
		#if defined AMXBANS_RBS
		register_native("amxbans_get_expired", "native_amxbans_get_expired");
		#endif
	#endif
}

//передаем данные с форума
public native_get_forum_data()
{
	new id = get_param(1);
	new len = get_param(4);
	
	new pl_Array[4];
	pl_Array[0] = Forum_Data[id][f_thanks];
	pl_Array[1] = Forum_Data[id][f_answers];
	pl_Array[2] = Forum_Data[id][f_reit];
	pl_Array[3] = Forum_Data[id][u_new_messages];
	
	set_array(2, pl_Array, sizeof(pl_Array));
	set_string(3, Forum_Data[id][u_name], len);

	return 1;
}
//проверка игрока на регистрацию
public native_is_registered_user()
	return strlen(Forum_Data[get_param(1)][u_login])? 1:0;

//узнать баланс игрока
public Float:native_get_user_shilings()
	return Forum_Data[get_param(1)][u_shilings];

//установка баланса игрока
public native_set_user_shilings()
{
	new shilings = get_param(2);
	shilings >= 0.01 ? shilings + 0.005 : shilings - 0.005;
	
	Forum_Data[get_param(1)][u_shilings] = _:shilings;
	return 1;
}

//Общее время игры на всех серверах
#if defined PL_GAMETIME
public native_get_user_gametime()
	return Forum_Data[get_param(1)][u_gametime];

#endif
//Передаем срок окончания админки
public native_days_left_info ()
	return getAdminsData(get_param(1), Data[AdminExpired], get_param(3));

//Проверяем, не отключен ли админ в админ-центре
public native_check_admin_active ()
	return getAdminsData(get_param(1), Data[AdminReason], get_param(3));

//Получение данных всех загруженных админов
public native_get_alladmins_data()
{
	new nHandle[12];
	formatex(nHandle, charsmax(nHandle), "%d", g_AllAdmins_Info);
	
	return str_to_num(nHandle);
}

//Получение данных авторизовавшихся админов
public native_get_admin_data()
{
	new nHandle[12];
	formatex(nHandle, charsmax(nHandle), "%d", g_OnlineAdminsInfo);
	
	return str_to_num(nHandle);
}

//Получение данных о всех купленных доп. услугах на сервере
public native_get_purchased_services()
{
	new nHandle[12];
	formatex(nHandle, charsmax(nHandle), "%d", g_AllPurch_Services);
	
	return str_to_num(nHandle);
}

//Получение данных о купленных доп. услугах игрока по SteamID
public native_get_user_services()
{
	ArrayClear(g_User_Services);
	
	static userauthid[24];
	get_string(1, userauthid, get_param(2));
	
	for (new index = 0; index < ArraySize(g_AllPurch_Services); ++index)
	{
		ArrayGetArray(g_AllPurch_Services, index, Data);
		if (equal(userauthid, Data[AdminAuthId]))
			ArrayPushArray(g_User_Services, Data);
	}
	for (new index = 0; index < ArraySize(g_AllAdmins_Info); ++index)
	{
		ArrayGetArray(g_AllAdmins_Info, index, Data);
		if (equal(userauthid, Data[AdminAuthId]))
			ArrayPushArray(g_User_Services, Data);
	}

	new nHandle[12];
	formatex(nHandle, charsmax(nHandle), "%d", g_User_Services);
	
	return ArraySize(g_User_Services) ? str_to_num(nHandle) : 0;
}

//Получение данных об администраторе (аккаунте) по ID (идентиф. номер в БД сайта) услуги
public native_get_admin_info()
{
	new	aID = get_param(1);
	if(!aID)
		return PLUGIN_HANDLED;

	new arrSize = ArraySize(g_AllAdmins_Info);
	for (new index = 0; index < arrSize; ++index)
	{
		ArrayGetArray(g_AllAdmins_Info, index, Data);
		if (aID == Data[AdminId])
		{
			TrieSetArray(g_AdminInfo, get_id_key(aID), Data, sizeof Data);
			
			new nHandle[12];
			formatex(nHandle, charsmax(nHandle), "%d", g_AdminInfo);

			return str_to_num(nHandle);
		}	
	}

	return 0
}

#if defined AMXBANS
public native_amxbans_get_prefix()
{
	new len= get_param(2);
	set_array(1, g_dbPrefix, len);
}

public native_amxbans_get_nick()
{
	new id = get_param(1);
	new len= get_param(3);
	new name[32]; get_user_name(id, name, len);
	
	set_array(2, name, len);
}

public native_amxbans_static_bantime()
{
	return 0;
}

	#if defined AMXBANS_RBS
	public native_amxbans_get_expired()
	{
		getAdminsData(get_param(1), Data[AdminExpired], get_param(3));
		new time = parse_time(Data[AdminExpired], "%Y-%m-%d %H:%M:%S");
		return time > 0 ? time : 0;
	}
	#endif
#endif

//получение ID сервера из таблицы серверов
public native_get_serverID()
	return g_server_id;

//ID авторизовавшегося админа
public native_get_AdminID()
{
	if(TrieGetArray(g_OnlineAdminsInfo, get_id_key(get_param(1)), Data, sizeof Data))
		return Data[AdminId]

	return PLUGIN_CONTINUE
}
	//return 
	
//данные авторизовавшегося админа
stock getAdminsData(id, Info[], len)
{
	if(TrieGetArray(g_OnlineAdminsInfo, get_id_key(id), Data, sizeof Data))
		set_string(2, Info, len);
	
	return PLUGIN_HANDLED;
}

stock forwards_create() 
{
	#if defined AMXBANS
		MFHandle[Amxbans_Sql_Initialized] = CreateMultiForward("amxbans_sql_initialized", ET_IGNORE, FP_CELL, FP_STRING);
		MFHandle[Admin_Connect]=CreateMultiForward("amxbans_admin_connect", ET_IGNORE, FP_CELL);
		MFHandle[Admin_Disconnect]=CreateMultiForward("amxbans_admin_disconnect", ET_IGNORE, FP_CELL);
	#else
		//Успешная авторизация админа
		MFHandle[Admin_Connect]=CreateMultiForward("admin_connect", ET_IGNORE, FP_CELL, FP_STRING, FP_CELL, FP_CELL);
	#endif
	//связь с БД в стороннем плагине
	MFHandle[DB_Init] = CreateMultiForward("init_database", ET_IGNORE, FP_CELL);
	//Подключение именинника (для плагина GameCMS Birthday)
	MFHandle[Birthday_Boy] = CreateMultiForward("birthday_boy_connect", ET_IGNORE, FP_CELL, FP_STRING, FP_STRING);
	//Подключение зарегистрированного пользователя
	MFHandle[Registered_User] = CreateMultiForward("registered_user_connected", ET_IGNORE, FP_CELL);
	//ошибка загрузки API
	MFHandle[API_Error] = CreateMultiForward("api_error", ET_IGNORE);
	//выполняется после успешной загрузки админов
	MFHandle[Load_Data] = CreateMultiForward("load_data", ET_IGNORE);
	#if defined PL_PREFIX
		//установка префикса в чат. требуется доработка плагина чата
		MFHandle[Set_User_Prefix] = CreateMultiForward("set_user_prefix", ET_IGNORE, FP_CELL, FP_STRING, FP_CELL);
	#endif
}