#include <amxmodx>
#include <fakemeta>
#include <gamecms>

#define PLUGIN "GameCMS_Informer"
#define VERSION "2.0"
#define AUTHOR "zhorzh78"

#define MAX_PLAYERS	32
#define HUD_OFFSET	5478
#define hudUpdateInterval	5.0

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
#endif

enum _:InfoSetup
{
	is_registered,
	hud_active
}
new HUD_Setup[MAX_PLAYERS+1][InfoSetup]

new informerSyncObj
new map_valid, bool:gamecms_wallet, bool:shop_loaded

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_clcmd("say /offinfo","HUD_Off")
	
	informerSyncObj = CreateHudSyncObj()
	
	set_task(200.0, "anons", _, _, _, "b")
}

public anons()
{
	client_print_color(0, 0, "^4[Инфо] ^1Зарегистрируйся на  сайте ^4%s ^1и получай бонусы за игру", SiteUrl)
	client_print_color(0, 0, "^4[Инфо] ^1Для отключения информера о регистрации, напиши в чат ^4/offinfo")
}
	
public plugin_cfg()
{
	get_cvar_string("cms_url", SiteUrl, charsmax(SiteUrl))
}

public api_error()
{
	log_amx("Plugin paused. GameCMS_API is not loaded")
	return 	pause("a")
}

public map_validate(is_map_valid)
{
	gamecms_wallet = true
	shop_loaded = true
	map_valid = is_map_valid
}

public HUD_Off(id)
{
	HUD_Setup[id][hud_active] = 0
}

public client_putinserver(id)
{
	HUD_Setup[id][hud_active] = 1
	set_task(hudUpdateInterval,"Show_Hud_Informer",HUD_OFFSET + id,.flags="b")
}

public registered_user_connected(id)
{
	HUD_Setup[id][is_registered] = 1	
}

public client_disconnect(id)
{
	if(task_exists(HUD_OFFSET + id))
		remove_task(HUD_OFFSET + id)
	arrayset(HUD_Setup[id], 0, InfoSetup)
}

public Show_Hud_Informer(taskId)
{
	new id = taskId - HUD_OFFSET
	
	if(!HUD_Setup[id][hud_active])
		return PLUGIN_HANDLED
	
	new watchId = id
	new isAlive = is_user_alive(id)
	
	if(!is_user_connected(id))
	{
		remove_task(taskId)
		return PLUGIN_HANDLED
	}

	if(informerSyncObj != 0)
		ClearSyncHud(id,informerSyncObj)

	if(!isAlive)
	{
		watchId = pev(id, pev_iuser2)
		
		if(!watchId)
			return PLUGIN_HANDLED
	}

	new hudMessage[156], len, Data[4], Name[32]
	new bool:status = get_forum_data(watchId, Data, Name, charsmax(Name)) != 0 ? true : false
	new Float:wallet = get_user_shilings(watchId)
	
	if(!status)
		return PLUGIN_HANDLED
	
	switch(isAlive)
	{
		case 1:
		if(HUD_Setup[id][is_registered])
		{
			if(Data[3] > 0)
				len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nНовых сообщений: %d", Data[3])
			if(map_valid)
			{
				if(gamecms_wallet)
					len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nВ кошельке: %.2f руб.",
						_:wallet >= 0 ? wallet + 0.005 : wallet - 0.005)
				if(shop_loaded)
					len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nМагазин: / shop")
			}
		}
		else len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nЗарегистрируйтесь ^nна сайте %s ^nи получайте бонусы", SiteUrl)

		case 0:
		if(HUD_Setup[watchId][is_registered])
		{
			len += formatex(hudMessage[len], charsmax(hudMessage) - len, "Участник форума")
			len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nИмя: %s", Name)
			len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nРейтинг: %d", Data[2])
			len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nБлагодарностей: %d", Data[0])
			if(get_user_flags(id) & ADMIN_RCON)
				len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nВ кошельке: %.2f руб.", wallet)
		}
		else len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nДанный игрок ^nне зарегистрирован")
	}

	set_hudmessage(250, 100, 100, 0.75 , 0.42, .holdtime = hudUpdateInterval, .channel = 4)
	return ShowSyncHudMsg(id, informerSyncObj, hudMessage)
}