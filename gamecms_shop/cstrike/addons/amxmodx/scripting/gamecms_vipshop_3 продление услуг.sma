#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <gamecms>

#define PLUGIN	"GameCMS_ShopMenu"
#define VERSION	"1.0"
#define AUTHOR	"zhorzh78"

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
#endif

enum _:ServiceInfo
{
	ServiceId,
	ServiceName[64],
	ServiceFlags[32],
	ServicePrice,
	ServiceTime
};
new Data[ServiceInfo], Array:g_ServiceInfo
new Trie:admins, adminData[AdminInfo]
new pl_Data[AdminInfo], Array:pl_ServiceInfo
new menu_Cmd[12], menu_Help[12]
new MainMenu, VIPShopMenu
new ServerID
new Handle:g_SqlX, gUpdate_Data, gRetData

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)	

	register_cvar("cms_shop_help", "refill_help.html")
	register_cvar("cms_shop_menu", "shop")
	
	static configsDir[32], file[64]
	get_configsdir(configsDir, charsmax(configsDir))
	formatex(file, charsmax(file), "%s/gamecms/vipshop.cfg", configsDir)
	if(!file_exists(file))
	{
		log_amx("File vipshop.cfg not found. Plugin paused")
		pause("a")
	}
	server_cmd("exec %s", file)
}

public init_database(Handle:sqlTuple) 
{
	if(g_SqlX == Empty_Handle) 
		return log_amx("Упс.. Что-то не так с БД")
	
	ServerID = get_serverID()
	
	g_SqlX = sqlTuple
	load_Service()
	
	return PLUGIN_CONTINUE
}

public plugin_cfg()
{
	get_cvar_string("cms_shop_help", menu_Help, charsmax(menu_Help))
	get_cvar_string("cms_shop_menu", menu_Cmd, charsmax(menu_Cmd))
	get_cvar_string("cms_url", SiteUrl, charsmax(SiteUrl))
	
	register_clcmd(menu_Cmd, "Main_Menu")
	
	gUpdate_Data = CreateMultiForward("Update_Data", ET_STOP, FP_CELL, FP_STRING, FP_STRING)
	
	g_ServiceInfo = ArrayCreate(ServiceInfo)
	//pl_ServiceInfo = ArrayCreate(AdminInfo)
}

public load_Service()
{
	static pquery[512]
	formatex(pquery, charsmax(pquery), 	"SELECT `services`.`id`, cast(convert(`services`.`name` using utf8) as binary) as `name`,\
	`services`.`server`, `services`.`rights` AS `flags`, `pirce`, `time` FROM `services` LEFT JOIN `servers` ON `servers`.`id` = \
	`services`.`server` LEFT JOIN `services_times` ON (`services`.`id` = `services_times`.`service` and `time` = '30') WHERE \
	`server` = '%d';", ServerID)

	new Data[2]; Data[0] = 1
	
	return SQL_ThreadQuery(g_SqlX, "Handler_post", pquery, Data, sizeof(Data))
}

public Handler_post(failstate, Handle:query, const error[], errornum, const postData[], postDataSize)
{
	if(SQL_Error(error, errornum, failstate))
		return SQL_FreeHandle(query)

	switch(postData[0])
	{
		case 1:
		{
			ArrayClear(g_ServiceInfo)
			new ServiceCount
			
			if(SQL_NumResults(query)) 
			{	
				while(SQL_MoreResults(query))
				{
					Data[ServiceId] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"))
					Data[ServicePrice] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "pirce"))
					Data[ServiceTime] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "time"))
					SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), Data[ServiceName], charsmax(Data[ServiceName]))
					SQL_ReadResult(query, SQL_FieldNameToNum(query, "flags"), Data[ServiceFlags], charsmax(Data[ServiceFlags]))
					
					mysql_escape_string(Data[ServiceName], charsmax(Data[ServiceName]))
					
					ArrayPushArray(g_ServiceInfo, Data)
					ServiceCount++
					SQL_NextRow(query)
				}
			}

			if (ServiceCount > 0)
				log_amx("Загружено услуг для магазина: %d шт.", ServiceCount)
			else 
				log_amx("На данном сервере нет платных услуг")
		}
		
		case 2:
		{
			if(failstate == TQUERY_SUCCESS) 
			{
				Add_Service(postData[1], postData[2], postData[3])
			}
		}
	}
	
	return	 SQL_FreeHandle(query)
}

Add_Service(id, index, type)
{
	ArrayGetArray(g_ServiceInfo, index, Data)
	new price[5]
	format(price, charsmax(price), "-%d", Data[ServicePrice])

	ExecuteForward(gUpdate_Data, gRetData, id, "shilings", price)
	
	if(gRetData != PLUGIN_CONTINUE)
	{
		return
	}

	server_cmd("amx_reloadadmins")
	
	switch(type)
	{
		case 1: client_print_color(id, 0, "^1[^4SHOP^1] ^1Вы приобрели услугу ^4%s ^1на ^4%d дн.", Data[ServiceName], Data[ServiceTime])
		case 2: client_print_color(id, 0, "^1[^4SHOP^1] ^1Ваша услуга ^4%s ^1 продлена на ^4%d дн.", Data[ServiceName], Data[ServiceTime])
	}
}

public Main_Menu(id)
{
	if(!is_registered_user(id))
		return client_print_color(id, 0, "^1[^4SHOP^1] ^1Магазин ^4недоступен^1! Зарегистрируйтесь на сайте ^4%s", SiteUrl)

	new Float:i_wallet = get_user_shilings(id)
	new s_Title[120]//, s_Informer[60]
	
	formatex(s_Title, charsmax(s_Title), "\yМагазин привилегий ^n\wНа вашем счету: [\y%d\w] руб.", floatround(i_wallet))		
	MainMenu = menu_create(s_Title, "Main_Menu_handler", 1)
	
	//formatex(s_Informer, charsmax(s_Informer), "Информер сайта [Вкл] : [Выкл]")			//================================
	//menu_additem(MainMenu, s_Informer, "1", 0)										//================================
	//menu_additem(MainMenu, "Как пополнить счёт?", "2", 0)
	menu_additem(MainMenu, "Купить VIP/Admin", "3", 0)

	menu_setprop(MainMenu, MPROP_EXITNAME, "\yВыход")
	return menu_display(id, MainMenu, 0)                                 
}

public Main_Menu_handler(id, menu, item)
{
	if(item == MENU_EXIT)
		return menu_destroy(menu)
	
	new cmd[3], access, callback
	menu_item_getinfo(menu, item, access, cmd, 2,_,_, callback)
	
	new i_Key = str_to_num(cmd)	
	switch (i_Key)
	{
		/*case 1:
		{
			//=================
		}
		case 2:
		{
			new motd[48]
			formatex(motd, charsmax(motd), "%s", menu_Help )
			show_motd(id, motd, "Как пополнить счёт?")
		}*/
		case 1:
			VIPShop_Menu(id)	
	}
	
	return menu_destroy(menu)
}    

public VIPShop_Menu(id)
{
	new arrSize = ArraySize(g_ServiceInfo)
	if(!arrSize)
		return client_print_color(id, 0, "^1[^4SHOP^1] ^1На данном сервере нет платных услуг")

	static steamID[32]
	get_user_authid(id, steamID,  charsmax(steamID))
	
	pl_ServiceInfo = get_user_services(steamID, charsmax(steamID))
	admins = get_admin_data()
	new Float:i_wallet = get_user_shilings(id)
	
	new s_Title[120]
	formatex(s_Title, charsmax(s_Title), "\yКупить VIP / Admin ^n\wНа вашем счету: [\y%d\w] руб.", floatround(i_wallet))
	
	VIPShopMenu = menu_create(s_Title, "VIPShopMenu_handler", 1)

	for (new i = 0; i < arrSize; ++i)
	{
		static s_ItemName[110], s_ItemNum[4]
		ArrayGetArray(g_ServiceInfo, i, Data)
		
		//проверяем 
		new service_have = 0, no_limit = 0
		if(TrieKeyExists(admins, get_id_key(id)))
			TrieGetArray(admins, get_id_key(id), adminData, charsmax(adminData))
		if (Data[ServiceId] == adminData[AdminServiceId])
		{
			if(equali(adminData[AdminExpired], "0000", 4))
				no_limit = 1
			else
				service_have = 1
		}

		else if(pl_ServiceInfo)
		{
			for (new index = 0; index < ArraySize(pl_ServiceInfo); ++index)
			{
				ArrayGetArray(pl_ServiceInfo, index, pl_Data)
				if (Data[ServiceId] == pl_Data[AdminServiceId])
				{
					if(equali(pl_Data[AdminExpired], "0000", 4))
						no_limit = 1
					else
						service_have = 1
					break
				}
			}
		}

		formatex(s_ItemName, charsmax(s_ItemName), "%s%s   [%d руб.]	%s", no_limit? "\d" : "", Data[ServiceName], Data[ServicePrice],
			service_have ? "\r[Продлить]" : "")
		num_to_str(i, s_ItemNum, charsmax(s_ItemNum))
		menu_additem(VIPShopMenu, s_ItemName, s_ItemNum, 0)
	}
	
	menu_setprop(VIPShopMenu, MPROP_EXITNAME, "\yВыход")
	
	return menu_display(id, VIPShopMenu, 0)                                 
}

public VIPShopMenu_handler(id, menu, item)
{
	if(item == MENU_EXIT)
		return menu_destroy(menu)
	
	new cmd[3], access, callback
	menu_item_getinfo(menu, item, access, cmd, 2,_,_, callback)

	new i_wallet = floatround(get_user_shilings(id))
	new i_Key = str_to_num(cmd)
	
	ArrayGetArray(g_ServiceInfo, i_Key, Data)
	if((i_wallet - Data[ServicePrice]) < 0)
		return client_print_color(id, 0, "^1[^4SHOP^1] ^1Недостаточно средств для покупки")

	new temp_id[3]
	
	num_to_str(id, temp_id, charsmax(temp_id))
	if(TrieKeyExists(admins, temp_id))
		TrieGetArray(admins, temp_id, adminData, charsmax(adminData))
	
	if ((equali(adminData[AdminExpired], "0000", 4)) && (Data[ServiceId] == adminData[AdminServiceId]))
		return client_print_color(id, 0, "^1[^4SHOP^1] ^1Нельзя продлить Вечное! ))")
	

	static steamID[32]
	get_user_authid(id, steamID,  charsmax(steamID))

	pl_ServiceInfo = get_user_services(steamID, charsmax(steamID))
	
	static pData[4],insertID[330]
	pData[0] = 2
	pData[1] = id
	pData[2] = i_Key
	pData[3] = 1	//1 /2 //покупка / продление
		
	if(pl_ServiceInfo)
	{
		for (new index = 0; index < ArraySize(pl_ServiceInfo); ++index)
		{
			ArrayGetArray(pl_ServiceInfo, index, pl_Data)
			if (Data[ServiceId] == pl_Data[AdminServiceId])
			{
				if(equali(pl_Data[AdminExpired], "0000", 4))
				{
					return client_print_color(id, 0, "^1[^4SHOP^1] ^1Нельзя продлить Вечное! ))")
				}
				pData[3] = 2
				break
			}
		}
	}

	static ins_Time[28]
	format_time(ins_Time, charsmax(ins_Time), "%Y-%m-%d %H:%M:%S", (get_systime() + 24*60*60* Data[ServiceTime]));
	switch(pData[3])
	{
		case 1:
			formatex(insertID, charsmax(insertID), 
			"INSERT INTO admins (name, type, server, user_id) values ('%s', 'ce', '%d', '%d');\
			INSERT INTO admins_services (rights_und, service_time, ending_date, admin_id) values \
			('%s', '%d', '%s', LAST_INSERT_ID());",
			steamID, ServerID, is_registered_user(id), Data[ServiceFlags], Data[ServiceTime], ins_Time)
		case 2:
			formatex(insertID, charsmax(insertID),	"UPDATE admins_services SET `service_time`= `service_time`+'%d',\
			`ending_date`= (SELECT DATE_ADD(`ending_date`, INTERVAL '%d' DAY)) WHERE `admin_id` = '%d'",
			Data[ServiceTime], Data[ServiceTime], get_AdminID(id))
	}

	SQL_ThreadQuery(g_SqlX, "Handler_post", insertID, pData, sizeof(pData))
	
	return menu_destroy(menu)
}    

public plugin_end()
{
	if(g_ServiceInfo)
	ArrayDestroy(g_ServiceInfo)
}