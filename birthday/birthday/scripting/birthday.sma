#include <amxmodx>
#include <gamecms>

#define PLUGIN "GameCMS_Birthday"
#define VERSION "1.0"
#define AUTHOR "zhorzh78"

#define VIP_FLAGS	"ab"	//установить флаги игроку. Если ВКЛ, ставить плагин ВЫШЕ плагинов ВИП
#define ST_CHAT //Можно включить, если нет других плагинов чата
//#define LT //Использовать Lite Translit для установки префикса. (Необходима доработка плагина LT)

#if defined ST_CHAT
	#define PREFIX  "^1[^4Именинник^1]"
#else
	#if defined LT
	#define PREFIX	"Именинник"
	#endif
#endif

new Motd_URL[256]
new server_name[128]

#if defined ST_CHAT
new is_b_player[33]
new g_maxplayers
#else
	#if defined PREFIX
	new MFHandle_Prefix	
	#endif
#endif

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	#if defined ST_CHAT
	register_message(get_user_msgid("SayText"),"Pref_SayText")
	g_maxplayers = get_maxplayers()
	#endif
	
	get_cvar_string("hostname", server_name, charsmax(server_name))
	replace_string(server_name, charsmax(server_name))
	
	#if !defined ST_CHAT
	forwards_create()
	#endif
}

public birthday_boy_connect(player, const szLogin[], const SITE_URL[])
{
	#if defined ST_CHAT
	is_b_player[player] = 1
	#endif
	
	copy(Motd_URL, charsmax(Motd_URL), SITE_URL)
	
	static szPl_Name[32]
	get_user_name(player, szPl_Name, charsmax(szPl_Name))
	
	set_hudmessage(255, 150, 50, -1.0, 0.65, 2, 0.1, 15.0, 0.1, 5.0)
	show_hudmessage(0, "Поздравьте с Днем Рождения ^nигрока %s ^nЕго имя: %s", szPl_Name, szLogin)
	
	new Data[2]; Data[0] = player 
	set_task(20.0, "showBirth", player, Data, charsmax(Data))
	
	#if defined VIP_FLAGS
	if(get_user_flags(player) & ADMIN_USER)		//Устанавливаем флаги игроку
		set_user_flags(player, read_flags(VIP_FLAGS))
	#endif
	
	//forward в LT на присвоение префикса
	#if defined LT
	new ret
	ExecuteForward(MFHandle_Prefix, ret, player, PREFIX)
	#endif
}

public showBirth(Data[])
{
	new id = Data[0]
	
	new pl_motd[256], pl_name[32], pl_ip[25]
	get_user_ip(id, pl_ip, charsmax(pl_ip))
	get_user_name(id, pl_name, charsmax(pl_name))
	replace_string(pl_name, charsmax(pl_name))

	formatex(pl_motd, charsmax(pl_motd), "%s/addons/birthday/birthday.php?pl_ip=%s&pl_name=%s&server_name=%s", Motd_URL, pl_ip, pl_name, server_name)
	show_motd(id, pl_motd,"")
}

#if defined ST_CHAT
public client_disconnect(id)
	is_b_player[id] = 0
	
public Pref_SayText(MsgID, MsgDEST, MsgENT)
{
	if(MsgDEST != MSG_ONE)
		return
	
	new id = get_msg_arg_int(1)
	if(!id || id > g_maxplayers || !is_b_player[id])
		return

	new chatIndefer[191], sayText[191]
	get_msg_arg_string(2, chatIndefer, 190)
	
	if(!equal(chatIndefer,"#Cstrike_Chat_All"))
	{
		add(sayText,charsmax(sayText), PREFIX)
		add(sayText,charsmax(sayText), " ")
		add(sayText,charsmax(sayText), chatIndefer)
	}
	else
	{
		add(sayText,charsmax(sayText), PREFIX);
		add(sayText,charsmax(sayText), " ^x03%s1^x01 : %s2")
	}
	
	set_msg_arg_string(2, sayText)
	
	return
}
#endif

stock forwards_create() 
{
	#if defined LT
	MFHandle_Prefix = CreateMultiForward("SearchClient", ET_IGNORE, FP_CELL, FP_STRING)	//forwart в LT на присвоение префикса
	#endif
	return PLUGIN_CONTINUE
}

stock replace_string(string[],len)
{
	replace_all(string, len, " ", "%20")
	replace_all(string, len, "#", "%23")
	replace_all(string, len, "/", "%2F")
	replace_all(string, len, "?", "%3F")
	replace_all(string, len, "=", "%3D")
	replace_all(string, len, "&", "%26")
}