#if !defined MAX_PLAYERS
	#define MAX_PLAYERS	32
#endif

stock SiteUrl[33]; //example: http://site.com


enum _:AdminInfo
{
	AdminId,
	AdminAuthId[33],
	AdminPassword[33],
	AdminServiceFlags[33],
	AdminType[5],
	AdminExpired[32],
	AdminReason[33],
	AdminActive,
	AdminServiceId,
	AdminServiceName[33],
	AdminServiceTime
};

/*
	Получение данных участника форума
	
	@id - id игрока
	@Data - массив с данными участника форума
		Data[0] - количество "спасибо"
		Data[1] - количество ответов на форуме
		Data[2] - рейтинг на форуме
		Data[3] - количество новых личных сообщений
*/
native get_forum_data (id, Data[4], String[], Len)


/*
	Получение даты окончания услуги
	
	@id - id игрока
	@szDate - дата истечения срока услуги в формате ГГГГ-ММ-ДД
*/
native days_left_info (id, szDate[], iLen)


/*
	Возвращает причину отключения услуги
	
	@id - id игрока
	@szReason - причина отключения услуги
*/
native check_admin_active (id, szReason[], iLen)


/*
	Зарегистрированный игрок 0/1
	
	@id - id игрока
*/
native is_registered_user (id)


/*
	Получение информации о балансе кошелька зарегистрированного игрока
	
	@id - id игрока
*/
native Float:get_user_shilings (id)


/*
	Установка баланса кошелька зарегистрированного игрока
	
	@id - id игрока
	@Float:iData - новое значение баланса
*/
native Float:set_user_shilings (id, Float:iData)


/*
	Выполняется при заходе зарегистрированного игрока
	
	@id - id игрока
*/
forward registered_user_connected(id)


/*
	Выполняется при заходе зарегистрированного именинника
	
	@id - id игрока
	const szLogin[] - Имя игрока на сайте
	const SITE_URL[] - адрес сайта (квар "cms_url") для вывода поздравительного Motd
*/
forward birthday_boy_connect(id, const szLogin[], const SITE_URL[])


/*
	Выполняется при инициализации БД
	
	Handle:sqlTuple - Кешированные данные о соединении с БД
*/
forward init_database(Handle:sqlTuple)


/*
	Выполняется при неудачной инициализации БД.
	После выполнения, плагин останавливается.
*/
forward api_error()


/*
	Получение данных всех имеющихся на сервере админов
	
	@Array:handle - дескриптор массива с данными
*/
native Array:get_alladmins_data ()


/*
	Получение данных авторизовавшихся админов
	
	@Trie:handle - дескриптор массива с данными
*/
native Trie:get_admin_data ()


/*
	Получение данных о всех купленных доп. услугах
	
	@Array:handle - дескриптор массива с данными
*/
native Array:get_purchased_services()


/*
	Получение данных о купленных доп. услугах игрока
	
	@szAuth[] - steamID игрока
	@Array:handle - дескриптор массива с данными
*/
native Array:get_user_services(szAuth[], len)


/*
	Установка префикса в чат из БД
	
	@id - id игрока
	prefix[] - префикс игрока в чате
	type - тип префикса:
	1- личный префикс
	2- префикс группы (админ, вип и т.п.)
*/
forward set_user_prefix(id, prefix[], type)


/*
	Общее время, проведенное игроком на всех серверах проекта
	
	@index - индекс игрока
*/
native get_user_gametime (index)


/*
	Получение данных по ID админа
	
	@aID - ID администратора в БД сайта
	@Trie:handle - дескриптор массива с данными
*/
native Trie:get_admin_info(aID)


/*
	Получение ID админа
	
	@index - индекс игрока
*/
native get_AdminID (index)


/*
	Получение идентификатора текущего сервера в БД сайта
*/
native get_serverID ()

/*
	Выполняется при выдаче флагов игроку (авторизация админа)
	
	@id - id админа
	const szName[] - Ник админа
	adminID - ID админа в БД сайта
	Flags - Bitflag value- битсумма флагов
*/
forward admin_connect(id, const szName[], adminID, Flags)


stock get_id_key(index)
{
	new id_key[6]
	num_to_str(index, id_key, charsmax(id_key))
	
	return id_key
}


stock mysql_escape_string(string[],len)
{
	replace_all(string, len, "&#039;", "'")
	replace_all(string, len, "&lt;", "<")
	replace_all(string, len, "&gt;", ">")
	replace_all(string, len, "&quot;", "^"")	//"
	replace_all(string, len, "&amp;", "&")
}

stock mysql_insert_string(string[],len)
{
	replace_all(string, len, "'", "&#039;")
	replace_all(string, len, "<", "&lt;")
	replace_all(string, len, ">", "&gt;")
	replace_all(string, len, "^"", "&quot;")	//"
	replace_all(string, len, "&", "&amp;")
}

stock SQL_Error(const error[], errornum, failstate)
{
	switch(failstate)
	{
		case TQUERY_CONNECT_FAILED:
		{
			log_amx("[Error] Ошибка при соединении: %s (%d)", error, errornum);
			return 1;
		}
			
		case TQUERY_QUERY_FAILED:
		{
			log_amx("[Error] Ошибка при запросе: %s (%d)", error, errornum);
			return 1;
		}	 
	}
	
	return 0
}

stock ExplodeString(Output[][], Max, Size, Input[], Delimiter)
{
    new Idx, l = strlen(Input), Len
    do Len += (1 + copyc( Output[Idx], Size, Input[Len], Delimiter))
    while( (Len < l) && (++Idx < Max))
    return Idx
}