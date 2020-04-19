#!/usr/bin/tclsh
# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2007, 2008, 2009, 2010, 2011, 2012 by Martin Ošmera     #
#    martin.osmera@gmail.com                                               #
#                                                                          #
#    Copyright (C) 2014 by Moravia Microsystems, s.r.o.                    #
#    martin.osmera@moravia-microsystems.com                                #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 2 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

# >>> File inclusion guard
if { ! [ info exists _SPELL_CHECK_TCL ] } {
set _SPELL_CHECK_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Spell checker interface used by the source code editor.
#
# Used spell checker is Hunspell.
#
#
# COMMUNICATION CONNECTIONS WITH HUNSPELL:
# -----------------------------------------
#
#     +-------------------+ (4)  +----------+ (5)  +------------------+
#     | receive_and_print |  |   | Hunspell |  |   | external_command |
#     |       (RAP)       | ---> |          | ---> |                  |
#     +-------------------+      +----------+      +------------------+
#               ^      |--(2)                               |--3
#          (1)--|      v                                    v
#         +--------------------------------------------------------+
#         |                   spell_check                          |
#         +--------------------------------------------------------+
#
# 1: Send a word to check along with commands to execute in case of correct and wrong spelling
# 2: Receive the identifier for IPC with the RAP (variable spellchecker_RAP_ID)
# 3: Receive response from the Hunspell via IPC
# 4: Send a word to check to the Hunspell via a pipe
# 5: Receive response from the Hunspell via a pipe
#
# --------------------------------------------------------------------------

## COMMON
	public common spellchecker_enabled			0	;# Bool: Flag spell checking enabled
	public common spellchecker_dictionary			{}	;# String: Dictionary to use (e.g. en_US or cs_CZ)
	public common spellchecker_process_pid			[list]	;# List of Ints: Process identifiers of the spell checker and support processes
	public common spellchecker_command_LIFO		[list]	;# List: LIFO for commands invoked by spell checker {correct_spelling_cmd wrong_spelling_cmd}
	public common spellchecker_RAP_ID			{}	;# String: Application name of ``receive_and_print'' for IPC
	public common spellchecker_attempts_to_restart		0	;# Int: Number of failed attempts to restart the spell checker process
	public common spellchecker_started_flag			;# None: When this variable is set that means that the spell checker process has been started
	public common spellchecker_start_failed		0	;# Bool: Flag spellchecker_started_flag was set but the spell checker process was not actually started
	public common spellchecker_start_timer			{}	;# AfterTimer: Watch dog timer for start of of the spell checker process
	public common available_dictionaries			[list]	;# List of Strings: Dictionaries available to the Hunspell
	public common hunspell_process				{}	;# Channel: Hunspell process invoked by command open in order to gain list of dictionaries

## PRIVATE
private variable spellcheck_line_pre		{}	;# String: Content of the line where change_detected_pre was performed
private variable spellcheck_line_number		{}	;# Int: Number of the last line where change_detected_pre was performed, see spellcheck_check_all
private variable spellcheck_lock		0	;# Bool: Inhibit method ``spellcheck_check_all''

## COMMON

## List: Language codes and language names according to: ISO-639-1
 # Format:
 #	{
 #		{ Language_Name  Language_Code }
 #		...
 #	}
	public common LANGUAGE_CODES_AND_NAMES {
	{{Abkhazian}		{ab}}	{{Afar}			{aa}}
	{{Afrikaans}		{af}}	{{Akan}			{ak}}
	{{Albanian}		{sq}}	{{Amharic}		{am}}
	{{Arabic}		{ar}}	{{Aragonese}		{an}}
	{{Armenian}		{hy}}	{{Assamese}		{as}}
	{{Avaric}		{av}}	{{Avestan}		{ae}}
	{{Aymara}		{ay}}	{{Azerbaijani}		{az}}
	{{Bambara}		{bm}}	{{Bashkir}		{ba}}
	{{Basque}		{eu}}	{{Belarusian}		{be}}
	{{Bengali}		{bn}}	{{Bihari languages}	{bh}}
	{{Bislama}		{bi}}	{{Bokmål, Norwegian}	{nb}}
	{{Bosnian}		{bs}}	{{Breton}		{br}}
	{{Bulgarian}		{bg}}	{{Burmese}		{my}}
	{{Castilian}		{es}}	{{Catalan}		{ca}}
	{{Central Khmer}	{km}}	{{Chamorro}		{ch}}
	{{Chechen}		{ce}}	{{Chewa}		{ny}}
	{{Chichewa}		{ny}}	{{Chinese}		{zh}}
	{{Chuang}		{za}}	{{Church Slavic}	{cu}}
	{{Church Slavonic}	{cu}}	{{Chuvash}		{cv}}
	{{Cornish}		{kw}}	{{Corsican}		{co}}
	{{Cree}			{cr}}	{{Croatian}		{hr}}
	{{Czech}		{cs}}	{{Danish}		{da}}
	{{Dhivehi}		{dv}}	{{Divehi}		{dv}}
	{{Dutch}		{nl}}	{{Dzongkha}		{dz}}
	{{English}		{en}}	{{Esperanto}		{eo}}
	{{Estonian}		{et}}	{{Ewe}			{ee}}
	{{Faroese}		{fo}}	{{Fijian}		{fj}}
	{{Finnish}		{fi}}	{{Flemish}		{nl}}
	{{French}		{fr}}	{{Fulah}		{ff}}
	{{Gaelic}		{gd}}	{{Galician}		{gl}}
	{{Ganda}		{lg}}	{{Georgian}		{ka}}
	{{German}		{de}}	{{Gikuyu}		{ki}}
	{{Greek, Modern}	{el}}	{{Greenlandic}		{kl}}
	{{Guarani}		{gn}}	{{Gujarati}		{gu}}
	{{Haitian}		{ht}}	{{Haitian Creole}	{ht}}
	{{Hausa}		{ha}}	{{Hebrew}		{he}}
	{{Herero}		{hz}}	{{Hindi}		{hi}}
	{{Hiri Motu}		{ho}}	{{Hungarian}		{hu}}
	{{Icelandic}		{is}}	{{Ido}			{io}}
	{{Igbo}			{ig}}	{{Indonesian}		{id}}
	{{Interlingue}		{ie}}	{{Inuktitut}		{iu}}
	{{Inupiaq}		{ik}}	{{Irish}		{ga}}
	{{Italian}		{it}}	{{Japanese}		{ja}}
	{{Javanese}		{jv}}	{{Kalaallisut}		{kl}}
	{{Kannada}		{kn}}	{{Kanuri}		{kr}}
	{{Kashmiri}		{ks}}	{{Kazakh}		{kk}}
	{{Kikuyu}		{ki}}	{{Kinyarwanda}		{rw}}
	{{Kirghiz}		{ky}}	{{Komi}			{kv}}
	{{Kongo}		{kg}}	{{Korean}		{ko}}
	{{Kuanyama}		{kj}}	{{Kurdish}		{ku}}
	{{Kwanyama}		{kj}}	{{Kyrgyz}		{ky}}
	{{Lao}			{lo}}	{{Latin}		{la}}
	{{Latvian}		{lv}}	{{Letzeburgesch}	{lb}}
	{{Limburgan}		{li}}	{{Limburger}		{li}}
	{{Limburgish}		{li}}	{{Lingala}		{ln}}
	{{Lithuanian}		{lt}}	{{Luba-Katanga}		{lu}}
	{{Luxembourgish}	{lb}}	{{Macedonian}		{mk}}
	{{Malagasy}		{mg}}	{{Malay}		{ms}}
	{{Malayalam}		{ml}}	{{Maldivian}		{dv}}
	{{Maltese}		{mt}}	{{Manx}			{gv}}
	{{Maori}		{mi}}	{{Marathi}		{mr}}
	{{Marshallese}		{mh}}	{{Moldavian}		{ro}}
	{{Moldovan}		{ro}}	{{Mongolian}		{mn}}
	{{Nauru}		{na}}	{{Navaho}		{nv}}
	{{Navajo}		{nv}}	{{Ndebele, North}	{nd}}
	{{Ndebele, South}	{nr}}	{{Ndonga}		{ng}}
	{{Nepali}		{ne}}	{{North Ndebele}	{nd}}
	{{Northern Sami}	{se}}	{{Norwegian}		{no}}
	{{Norwegian Bokmål}	{nb}}	{{Norwegian Nynorsk}	{nn}}
	{{Nuosu}		{ii}}	{{Nyanja}		{ny}}
	{{Nynorsk, Norwegian}	{nn}}	{{Occidental}		{ie}}
	{{Occitan}		{oc}}	{{Ojibwa}		{oj}}
	{{Old Bulgarian}	{cu}}	{{Old Church Slavonic}	{cu}}
	{{Old Slavonic}		{cu}}	{{Oriya}		{or}}
	{{Oromo}		{om}}	{{Ossetian}		{os}}
	{{Ossetic}		{os}}	{{Pali}			{pi}}
	{{Panjabi}		{pa}}	{{Pashto}		{ps}}
	{{Persian}		{fa}}	{{Polish}		{pl}}
	{{Portuguese}		{pt}}	{{Punjabi}		{pa}}
	{{Pushto}		{ps}}	{{Quechua}		{qu}}
	{{Romanian}		{ro}}	{{Romansh}		{rm}}
	{{Rundi}		{rn}}	{{Russian}		{ru}}
	{{Samoan}		{sm}}	{{Sango}		{sg}}
	{{Sanskrit}		{sa}}	{{Sardinian}		{sc}}
	{{Scottish Gaelic}	{gd}}	{{Serbian}		{sr}}
	{{Shona}		{sn}}	{{Sichuan Yi}		{ii}}
	{{Sindhi}		{sd}}	{{Sinhala}		{si}}
	{{Sinhalese}		{si}}	{{Slovak}		{sk}}
	{{Slovenian}		{sl}}	{{Somali}		{so}}
	{{Sotho, Southern}	{st}}	{{South Ndebele}	{nr}}
	{{Spanish}		{es}}	{{Sundanese}		{su}}
	{{Swahili}		{sw}}	{{Swati}		{ss}}
	{{Swedish}		{sv}}	{{Tagalog}		{tl}}
	{{Tahitian}		{ty}}	{{Tajik}		{tg}}
	{{Tamil}		{ta}}	{{Tatar}		{tt}}
	{{Telugu}		{te}}	{{Thai}			{th}}
	{{Tibetan}		{bo}}	{{Tigrinya}		{ti}}
	{{Tonga}		{to}}	{{Tsonga}		{ts}}
	{{Tswana}		{tn}}	{{Turkish}		{tr}}
	{{Turkmen}		{tk}}	{{Twi}			{tw}}
	{{Uighur}		{ug}}	{{Ukrainian}		{uk}}
	{{Urdu}			{ur}}	{{Uyghur}		{ug}}
	{{Uzbek}		{uz}}	{{Valencian}		{ca}}
	{{Venda}		{ve}}	{{Vietnamese}		{vi}}
	{{Volapük}		{vo}}	{{Walloon}		{wa}}
	{{Welsh}		{cy}}	{{Western Frisian}	{fy}}
	{{Wolof}		{wo}}	{{Xhosa}		{xh}}
	{{Yiddish}		{yi}}	{{Yoruba}		{yo}}
	{{Zhuang}		{za}}	{{Zulu}			{zu}}
}

## List: Country codes with names of their flags file in directory ``${::ROOT_DIRNAME}/icons/flag/''
 # Format:
 #	{
 #		{ Country_Name  Country_Code  Flag_File_Name_Without_Extension }
 #		...
 #	}
	public common COUNTRY_CODES_AND_FLAGS {
	{{Afghanistan}					AF	Afghanistan}
	{{Åland Islands}				AX	{}}
	{{Albania}					AL	Albania}
	{{Algeria}					DZ	Algeria}
	{{American Samoa}				AS	American_Samoa}
	{{Andorra}					AD	Andorra}
	{{Angola}					AO	Angola}
	{{Anguilla}					AI	Anguilla}
	{{Antarctica}					AQ	{}}
	{{Antigua And Barbuda}				AG	Antigua_and_Barbuda}
	{{Argentina}					AR	Argentina}
	{{Armenia}					AM	Armenia}
	{{Aruba}					AW	Aruba}
	{{Australia}					AU	Australia}
	{{Austria}					AT	Austria}
	{{Azerbaijan}					AZ	Azerbaijan}

	{{Bahamas}					BS	Bahamas}
	{{Bahrain}					BH	Bahrain}
	{{Bangladesh}					BD	Bangladesh}
	{{Barbados}					BB	Barbados}
	{{Belarus}					BY	Belarus}
	{{Belgium}					BE	Belgium}
	{{Belize}					BZ	Belize}
	{{Benin}					BJ	Benin}
	{{Bermuda}					BM	Bermuda}
	{{Bhutan}					BT	Bhutan}
	{{Bolivia, Plurinational State Of}		BO	Bolivia}
	{{Bosnia And Herzegovina}			BA	Bosnia}
	{{Botswana}					BW	Botswana}
	{{Bouvet Island}				BV	{}}
	{{Brazil}					BR	Brazil}
	{{British Indian Ocean Territory}		IO	{}}
	{{Brunei Darussalam}				BN	Brunei}
	{{Bulgaria}					BG	Bulgaria}
	{{Burkina Faso}					BF	Burkina_Faso}
	{{Burundi}					BI	Burundi}

	{{Cambodia}					KH	Cambodia}
	{{Cameroon}					CM	Cameroon}
	{{Canada}					CA	Canada}
	{{Cape Verde}					CV	Cape_Verde}
	{{Cayman Islands}				KY	Cayman_Islands}
	{{Central African Republic}			CF	Central_African_Republic}
	{{Chad}						TD	Chad}
	{{Chile}					CL	Chile}
	{{China}					CN	China}
	{{Christmas Island}				CX	Christmas_Island}
	{{Cocos (Keeling) Islands}			CC	{}}
	{{Colombia}					CO	Colombia}
	{{Comoros}					KM	Comoros}
	{{Congo}					CG	Republic_of_the_Congo}
	{{Congo, The Democratic Republic Of The}	CD	Democratic_Republic_of_the_Congo}
	{{Cook Islands}					CK	Cook_Islands}
	{{Costa Rica}					CR	Costa_Rica}
	{{Côte D'Ivoire}				CI	Cote_dIvoire}
	{{Croatia}					HR	Croatia}
	{{Cuba}						CU	Cuba}
	{{Cyprus}					CY	Cyprus}
	{{Czech Republic}				CZ	Czech_Republic}

	{{Denmark}					DK	Denmark}
	{{Djibouti}					DJ	Djibouti}
	{{Dominica}					DM	Dominica}
	{{Dominican Republic}				DO	Dominican_Republic}

	{{Ecuador}					EC	Ecuador}
	{{Egypt}					EG	Egypt}
	{{El Salvador}					SV	El_Salvador}
	{{Equatorial Guinea}				GQ	Equatorial_Guinea}
	{{Eritrea}					ER	Eritrea}
	{{Estonia}					EE	Estonia}
	{{Ethiopia}					ET	Ethiopia}

	{{Falkland Islands (Malvinas)}			FK	Falkland_Islands}
	{{Faroe Islands}				FO	Faroe_Islands}
	{{Fiji}						FJ	Fiji}
	{{Finland}					FI	Finland}
	{{France}					FR	France}
	{{French Guiana}				GF	{}}
	{{French Polynesia}				PF	French_Polynesia}
	{{French Southern Territories}			TF	{}}

	{{Gabon}					GA	Gabon}
	{{Gambia}					GM	Gambia}
	{{Georgia}					GE	Georgia}
	{{Germany}					DE	Germany}
	{{Ghana}					GH	Ghana}
	{{Gibraltar}					GI	Gibraltar}
	{{Greece}					GR	Greece}
	{{Greenland}					GL	Greenland}
	{{Grenada}					GD	Grenada}
	{{Guadeloupe}					GP	{}}
	{{Guam}						GU	Guam}
	{{Guatemala}					GT	Guatemala}
	{{Guernsey}					GG	{}}
	{{Guinea}					GN	Guinea}
	{{Guinea-Bissau}				GW	Guinea_Bissau}
	{{Guyana}					GY	Guyana}

	{{Haiti}					HT	Haiti}
	{{Heard Island And Mcdonald Islands}		HM	{}}
	{{Holy See (Vatican City State)}		VA	{}}
	{{Honduras}					HN	Honduras}
	{{Hong Kong}					HK	Hong_Kong}
	{{Hungary}					HU	Hungary}

	{{Iceland}					IS	Iceland}
	{{India}					IN	India}
	{{Indonesia}					ID	Indonesia}
	{{Iran, Islamic Republic Of}			IR	Iran}
	{{Iraq}						IQ	Iraq}
	{{Ireland}					IE	Ireland}
	{{Isle Of Man}					IM	{}}
	{{Israel}					IL	Israel}
	{{Italy}					IT	Italy}

	{{Jamaica}					JM	Jamaica}
	{{Japan}					JP	Japan}
	{{Jersey}					JE	{}}
	{{Jordan}					JO	Jordan}

	{{Kazakhstan}					KZ	Kazakhstan}
	{{Kenya}					KE	Kenya}
	{{Kiribati}					KI	Kiribati}
	{{Korea, Democratic People'S Republic Of}	KP	North_Korea}
	{{Korea, Republic Of}				KR	South_Korea}
	{{Kuwait}					KW	Kuwait}
	{{Kyrgyzstan}					KG	Kyrgyzstan}

	{{Lao People'S Democratic Republic}		LA	Laos}
	{{Latvia}					LV	Latvia}
	{{Lebanon}					LB	Lebanon}
	{{Lesotho}					LS	Lesotho}
	{{Liberia}					LR	Liberia}
	{{Libyan Arab Jamahiriya}			LY	Libya}
	{{Liechtenstein}				LI	Liechtenstein}
	{{Lithuania}					LT	Lithuania}
	{{Luxembourg}					LU	Luxembourg}

	{{Macao}					MO	Macao}
	{{Macedonia, The Former Yugoslav Republic Of}	MK	Macedonia}
	{{Madagascar}					MG	Madagascar}
	{{Malawi}					MW	Malawi}
	{{Malaysia}					MY	Malaysia}
	{{Maldives}					MV	Maldives}
	{{Mali}						ML	Mali}
	{{Malta}					MT	Malta}
	{{Marshall Islands}				MH	Marshall_Islands}
	{{Martinique}					MQ	Martinique}
	{{Mauritania}					MR	Mauritania}
	{{Mauritius}					MU	Mauritius}
	{{Mayotte}					YT	{}}
	{{Mexico}					MX	Mexico}
	{{Micronesia, Federated States Of}		FM	Micronesia}
	{{Moldova, Republic Of}				MD	Moldova}
	{{Monaco}					MC	Monaco}
	{{Mongolia}					MN	Mongolia}
	{{Montenegro}					ME	{}}
	{{Montserrat}					MS	Montserrat}
	{{Morocco}					MA	Morocco}
	{{Mozambique}					MZ	Mozambique}
	{{Myanmar}					MM	Myanmar}

	{{Namibia}					NA	Namibia}
	{{Nauru}					NR	Nauru}
	{{Nepal}					NP	Nepal}
	{{Netherlands}					NL	Netherlands}
	{{Netherlands Antilles}				AN	Netherlands_Antilles}
	{{New Caledonia}				NC	{}}
	{{New Zealand}					NZ	New_Zealand}
	{{Nicaragua}					NI	Nicaragua}
	{{Niger}					NE	Niger}
	{{Nigeria}					NG	Nigeria}
	{{Niue}						NU	Niue}
	{{Norfolk Island}				NF	Norfolk_Island}
	{{Northern Mariana Islands}			MP	{}}
	{{Norway}					NO	Norway}

	{{Oman}						OM	Oman}

	{{Pakistan}					PK	Pakistan}
	{{Palau}					PW	Palau}
	{{Palestinian Territory, Occupied}		PS	{}}
	{{Panama}					PA	Panama}
	{{Papua New Guinea}				PG	Papua_New_Guinea}
	{{Paraguay}					PY	Paraguay}
	{{Peru}						PE	Peru}
	{{Philippines}					PH	Philippines}
	{{Pitcairn}					PN	Pitcairn_Islands}
	{{Poland}					PL	Poland}
	{{Portugal}					PT	Portugal}
	{{Puerto Rico}					PR	Puerto_Rico}

	{{Qatar}					QA	Qatar}

	{{Réunion}					RE	{}}
	{{Romania}					RO	Romania}
	{{Russian Federation}				RU	Russian_Federation}
	{{Rwanda}					RW	Rwanda}

	{{Saint Barthélemy}				BL	{}}
	{{Saint Helena, Ascension And Tristan Da Cunha}	SH	{}}
	{{Saint Kitts And Nevis}			KN	Saint_Kitts_and_Nevis}
	{{Saint Lucia}					LC	Saint_Lucia}
	{{Saint Martin}					MF	{}}
	{{Saint Pierre And Miquelon}			PM	Saint_Pierre}
	{{Saint Vincent And The Grenadines}		VC	Saint_Vicent_and_the_Grenadines}
	{{Samoa}					WS	Samoa}
	{{San Marino}					SM	San_Marino}
	{{Sao Tome And Principe}			ST	Sao_Tome_and_Principe}
	{{Saudi Arabia}					SA	Saudi_Arabia}
	{{Senegal}					SN	Senegal}
	{{Serbia}					RS	{}}
	{{Seychelles}					SC	Seychelles}
	{{Sierra Leone}					SL	Sierra_Leone}
	{{Singapore}					SG	Singapore}
	{{Slovakia}					SK	Slovakia}
	{{Slovenia}					SI	Slovenia}
	{{Solomon Islands}				SB	Soloman_Islands}
	{{Somalia}					SO	Somalia}
	{{South Africa}					ZA	South_Africa}
	{{South Georgia And The South Sandwich Islands}	GS	South_Georgia}
	{{Spain}					ES	Spain}
	{{Sri Lanka}					LK	Sri_Lanka}
	{{Sudan}					SD	Sudan}
	{{Suriname}					SR	Suriname}
	{{Svalbard And Jan Mayen}			SJ	{}}
	{{Swaziland}					SZ	Swaziland}
	{{Sweden}					SE	Sweden}
	{{Switzerland}					CH	Switzerland}
	{{Syrian Arab Republic}				SY	Syria}

	{{Taiwan, Province Of China}			TW	Taiwan}
	{{Tajikistan}					TJ	Tajikistan}
	{{Tanzania, United Republic Of}			TZ	Tanzania}
	{{Thailand}					TH	Thailand}
	{{Timor-Leste}					TL	Timor-Leste}
	{{Togo}						TG	Togo}
	{{Tokelau}					TK	{}}
	{{Tonga}					TO	Tonga}
	{{Trinidad And Tobago}				TT	Trinidad_and_Tobago}
	{{Tunisia}					TN	Tunisia}
	{{Turkey}					TR	Turkey}
	{{Turkmenistan}					TM	Turkmenistan}
	{{Turks And Caicos Islands}			TC	Turks_and_Caicos_Islands}
	{{Tuvalu}					TV	Tuvalu}

	{{Uganda}					UG	Uganda}
	{{Ukraine}					UA	Ukraine}
	{{United Arab Emirates}				AE	UAE}
	{{United Kingdom}				GB	United_Kingdom}
	{{United States}				US	United_States_of_America}
	{{United States Minor Outlying Islands}		UM	{}}
	{{Uruguay}					UY	Uruguay}
	{{Uzbekistan}					UZ	Uzbekistan}

	{{Vanuatu}					VU	Vanuatu}
	{{Vatican City State}				VA	Vatican_City}
	{{Venezuela, Bolivarian Republic Of}		VE	Venezuela}
	{{Viet Nam}					VN	Vietnam}
	{{Virgin Islands, British}			VG	British_Virgin_Islands}
	{{Virgin Islands, U.S.}				VI	US_Virgin_Islands}

	{{Wallis And Futuna}				WF	Wallis_and_Futuna}
	{{Western Sahara}				EH	{}}

	{{Yemen}					YE	Yemen}
	{{Zambia}					ZM	Zambia}
	{{Zimbabwe}					ZW	Zimbabwe}
}

## Kill spell checker and its support processes
 # @return void
proc kill_spellchecker_process {} {
	# Reset some class variables
	set ::Editor::spellchecker_RAP_ID {}
	set ::Editor::spellchecker_command_LIFO [list]

	# Abort if the spell checker process is not running
	if {${::Editor::spellchecker_process_pid} == {}} {
		return
	}

	# Kill the spell checker and its support processes
	foreach pid ${::Editor::spellchecker_process_pid} {
		if {$pid == [pid] || $pid == 0} {
			continue
		}
		catch {
			exec -- kill $pid 2>/dev/null
		}
	}
	set ::Editor::spellchecker_process_pid {}
}

## Restart the spell checker process with new new configuration
 # @return void
proc restart_spellchecker_process {} {
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	kill_spellchecker_process

	if {[lsearch -ascii -exact ${::Editor::available_dictionaries} ${::Editor::spellchecker_dictionary}] == -1} {
		set ::Editor::spellchecker_enabled 0
		set ::Editor::spellchecker_dictionary {}
	} else {
		start_spellchecker_process
		wait_for_spellchecker_process
	}
}

## Start the spell checker (Hunspell) and its support processes
 # @return void
proc start_spellchecker_process {} {
	# Abort if either the feature is disabled or the Hunspell is not available
	if {!${::Editor::spellchecker_enabled} || !${::PROGRAM_AVAILABLE(hunspell)}} {
		return
	}
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# Start watch dog timer
	set ::Editor::spellchecker_start_timer [after 10000 {
		set ::Editor::spellchecker_start_failed 1
		set ::Editor::spellchecker_started_flag 1
	}]

	# Attempt to start the processes
	if {[catch {
		set ::Editor::spellchecker_process_pid [exec --			\
			tclsh ${::LIB_DIRNAME}/receive_and_print.tcl		\
				[tk appname]					\
				::Editor::set_spellchecker_RAP_ID		\
			| hunspell						\
				-a						\
				-i utf8						\
				-d ${::Editor::spellchecker_dictionary}		\
			| tclsh ${::LIB_DIRNAME}/external_command.tcl		\
				[tk appname]					\
				::Editor::spellchecker_exit_callback		\
				::Editor::spellchecker_receive_response		\
		&								\
		]
	}]} then {
		# FAILURE
		set ::Editor::spellchecker_start_failed 1
		set ::Editor::spellchecker_started_flag 1
	}
}

## Wait until the spell checker (Hunspell) and its support processes are started
 # @return void
proc wait_for_spellchecker_process {} {
	# Abort if either the feature is disabled or the Hunspell is not available
	if {!${::Editor::spellchecker_enabled} || !${::PROGRAM_AVAILABLE(hunspell)}} {
		return
	}
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# Wait until the spell checker (Hunspell) and its support processes are started
	vwait ::Editor::spellchecker_started_flag
	unset ::Editor::spellchecker_started_flag

	# Stop the watch dog timer
	catch {
		after cancel ${::Editor::spellchecker_start_timer}
	}

	# Handle spellchecker start-up failure
	if {${::Editor::spellchecker_start_failed}} {
		# Set some class variables
		set ::Editor::spellchecker_RAP_ID		{}
		set ::Editor::spellchecker_enabled		0
		set ::Editor::spellchecker_start_failed		0

		# Destroy the splash screen if displayed
		if {[winfo exists .splash]} {
			destroy .splash
		}

		# Display graphical error message
		tk_messageBox				\
			-parent .			\
			-type ok			\
			-icon error			\
			-title [mc "Hunspell error"]	\
			-message [mc "Unable to start the spell checker. Please try to re-install the hunspell. Spell checking function will not be available"]
	}
}

## Receive the identifier for IPC with the RAP
 # @parm String id - Appname of the receive_and_print process
 # @return void
proc set_spellchecker_RAP_ID {id} {
	set ::Editor::spellchecker_RAP_ID $id
}

## Handle Hunspell process termination
 #
 # It is assumed that the process terminates only on some error condition or
 # on an explicit request for termination. Aim of this method is attempt to
 # restart the Hunspell process and its support processes if it crashed for any
 # reason.
 #
 # @parm List args - Anything, it doesn't matter
 # @return void
proc spellchecker_exit_callback {args} {
	# Abort if the termination was intentional
	if {${::Editor::spellchecker_RAP_ID} == {}} {
		return
	}
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	set ::Editor::spellchecker_RAP_ID {}
	puts stderr "Spell checker process exited -- attempting to restart"

	# Attempt to restart
	incr ::Editor::spellchecker_attempts_to_restart
	if {${::Editor::spellchecker_attempts_to_restart} < 10} {
		start_spellchecker_process
	} else {
		puts stderr "Attempt to restart failed, to many attempts -- aborting"
		set spellchecker_attempts_to_restart 0
	}
}

## Receive response from the Hunspell
 # @parm List args - One line of the response
 # @return void
proc spellchecker_receive_response {args} {
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# We are interested only in the first field of the response
	set response [string trim [lindex $args 0]]

	# Handle the initial response (sent once the Hunspell is started)
	if {[lindex $response 0] == {@(#)}} {
		set spellchecker_command_LIFO [list]
		set ::Editor::spellchecker_started_flag 1
		return
	}

	# Decide what to do with the response
	switch -- $response {
		{} {		;# Empty response -- means nothing
		}
		{*} {		;# Word is correct
			catch {
				eval [lindex $spellchecker_command_LIFO {0 0}]
			}
			set spellchecker_command_LIFO [lreplace $spellchecker_command_LIFO 0 0]
		}
		default {	;# Everything else
			catch {
				eval [lindex $spellchecker_command_LIFO {0 1}]
			}
			set spellchecker_command_LIFO [lreplace $spellchecker_command_LIFO 0 0]
		}
	}
}

## Send a word to the Hunspell process for evaluation
 # @parm String word			- Work to check for correct spelling
 # @parm String wrong_command = {}	- Command to execute here if the word is badly spelled
 # @parm String correct_command = {}	- Command to execute here if the word is correctly spelled
 # @return void
proc spellchecker_check_word {word {wrong_command {}} {correct_command {}}} {
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# Abort if receive and print process has not been initialized
	if {${::Editor::spellchecker_RAP_ID} == {}} {
		return
	}

	# Append command to their queue
	lappend spellchecker_command_LIFO [list $correct_command $wrong_command]

	# Send the word to the Hunspell process
	if {!${::MICROSOFT_WINDOWS}} {
		::X::secure_send ${::Editor::spellchecker_RAP_ID} print_line "{$word}"
	} else {
		dde eval ${::Editor::spellchecker_RAP_ID} print_line "{$word}"
	}
}

## Refresh list of available spell checker dictionaries (refresh in GUI)
 # @return void
proc refresh_available_dictionaries {} {
	# Abort if the Hunspell program is not available
	if {!${::PROGRAM_AVAILABLE(hunspell)}} {
		return
	}
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# Set widget descriptor for the dictionary selection menu
	set m {.spell_checker_conf_menu}

	# Destroy the dictionary selection menu if it exists
	if {[winfo exists $m]} {
		destroy $m
	}

	# Create new dictionary selection menu
	menu $m			;# Main part
	menu $m.by_country	;# Cascade "Set dictionary by country"
	menu $m.by_language	;# Cascade "Set dictionary by language"

	# Define contents of the newly created menu
	$m add command \
		-label [mc "Refresh list of dictionaries"] \
		-image ::ICONS::16::reload \
		-compound left \
		-command {
			::Editor::refresh_available_dictionaries
			::Editor::adjust_spell_checker_config_button
		}
	$m add command \
		-label [mc "Turn off spell checking"] \
		-image ::ICONS::16::exit \
		-compound left \
		-command {::Editor::switch_SC_dictionary {}}
	$m add separator
	$m add cascade \
		-label [mc "Set dictionary by language"] \
		-menu $m.by_language
	$m add cascade \
		-label [mc "Set dictionary by country"] \
		-menu $m.by_country

	## Get list of available Hunspell dictionaries
	set ::Editor::available_dictionaries [list]
	 # Start watchdog timer for the Hunspell process
	set spellchecker_start_timer [after 10000 {
		catch {
			close ${::Editor::hunspell_process}
		}
	}]
	if {[catch {
		# Run Hunspell in a mode in which it prints available dictionaries
		if {!${::MICROSOFT_WINDOWS}} {
			set hunspell_process [open {| /bin/sh -c "hunspell -D 2>&1 | awk '{print(\$0)} /^LOADED DICTIONARY/ {exit 0}' || exit 1"} "r"]
		} else {
			puts stderr "Sorry, this feature is not implemented on MS Windows yet."
			error "Not available on Windows."
		}

	}]} then {
		# Error condition
		puts stderr "Unable to start the Hunspell process"

	} else {
		# Bool: Accept this line of output from the process
		set accept_flag 0

		# Read list of dictionaries (file names along with pats)
		while {![eof $hunspell_process]} {
			# Read line from the process
			set line [gets $hunspell_process]

			# Ignore everything besides section ``AVAILABLE DICTIONARIES''
			if {![string first {AVAILABLE DICTIONARIES} $line]} {
				set accept_flag 1
				continue
			} elseif {![string first {LOADED DICTIONARY:} $line]} {
				break
			} elseif {!$accept_flag} {
				continue
			}

			# Determinate language code and country code and append it to the
			#+ list of available dictionaries
			set line [lindex [split $line [file separator]] end]
			set line [split $line {_}]
			if {[lindex $line 0] == {hyph}} {
				continue
# 				set line [lreplace $line 0 0]
			}
			if {![string length [lindex $line 0]] || ![string length [lindex $line 1]]} {
				continue
			}
			if {![string is alpha [lindex $line 0]] || ![string is alpha [lindex $line 1]]} {
				continue
			}
			set dictionary [string tolower [lindex $line 0]]_[string toupper [lindex $line 1]]
			if {[lsearch -ascii -exact ${::Editor::available_dictionaries} $dictionary] == -1} {
				lappend ::Editor::available_dictionaries $dictionary
			}
		}
	}

	# Cancel the watchdog timer
	catch {
		after cancel $spellchecker_start_timer
	}

	# If there are no dictionaries available to use then abort right away
	if {![llength ${::Editor::available_dictionaries}]} {
		return
	}


	## Enrich the gained list with some additional information
	 #
	 # Format of the resulting list:
	 # {
	 #	{Language_code   Country_code   Country_name   Language_name   Flag_icon}
	 #	...
	 # }
	set available_dictionaries_complex [list]
	foreach dictionary ${::Editor::available_dictionaries} {
		# Determinate language code and country code
		set dictionary		[split $dictionary {_}]	;# List: Language and country codes, e.g. {en GB}
		set language_code	[lindex $dictionary 0]	;# String: Language code, e.g. "en"
		set country_code	[lindex $dictionary 1]	;# String: County code, e.g. "GB"
		set country_and_flag	{}			;# List: Country name and flag icon name, e.g. {"United Kingdom" United_Kingdom}
		set country_name	{}			;# String: Country name, e.g. "United Kingdom"
		set flag_icon		{}			;# String: Flag icon name, e.g. "United_Kingdom"
		set language_name	{}			;# String: Language name, e.g. "English"

		# Determinate country name and flag file name
		set idx [lsearch -ascii -exact -index 1 ${::Editor::COUNTRY_CODES_AND_FLAGS} $country_code]
		if {$idx != -1} {
			set country_and_flag [lindex ${::Editor::COUNTRY_CODES_AND_FLAGS} $idx]
			set country_name [lindex $country_and_flag 0]
			set flag_icon [lindex $country_and_flag 2]
		} else {
			set country_name $country_code
		}
		if {$flag_icon == {}} {
			set flag_icon {empty}
		}

		# Determinate language name
		set idx [lsearch -ascii -exact -index 1 ${::Editor::LANGUAGE_CODES_AND_NAMES} $language_code]
		if {$idx != -1} {
			set language_name [lindex ${::Editor::LANGUAGE_CODES_AND_NAMES} [list $idx 0]]
		} else {
			set language_name $language_code
		}

		if {$country_name == {}} {
			set country_name {???}
		}
		if {$language_name == {}} {
			set language_name {???}
		}

		# Append item to the resulting list
		lappend available_dictionaries_complex [list $language_code $country_code [mc $country_name] [mc $language_name] $flag_icon]
	}

	# Generate content of the "Set by country" menu
	set local_menu		{}
	set capital_leter	{}
	set last_capital_leter	{}
	foreach dictionary [lsort -dictionary -index 2 [lsort -dictionary -index 3 $available_dictionaries_complex]] {
		# Gain some facts about the dictionary file
		set language_code	[lindex $dictionary 0]
		set country_code	[lindex $dictionary 1]
		set country_name	[lindex $dictionary 2]
		set language_name	[lindex $dictionary 3]
		set flag_icon		[lindex $dictionary 4]

		# Create sub-menu if necessary
		set capital_leter [string toupper [string index $country_name 0]]

		if {$capital_leter != $last_capital_leter} {
			set last_capital_leter $capital_leter
			set local_menu [menu $m.by_country.m_[string tolower $capital_leter]]
			$m.by_country add cascade -label "$capital_leter ..." -menu $local_menu
		}

		# Create the menu item
		$local_menu add command \
			-command "::Editor::switch_SC_dictionary {${language_code}_${country_code}}" \
			-label "$country_name ($language_name)" \
			-image ::ICONS::flag::$flag_icon \
			-compound left
	}

	# Generate content of the "Set by language" menu
	set local_menu		{}
	set capital_leter	{}
	set last_capital_leter	{}
	foreach dictionary [lsort -dictionary -index 3 [lsort -dictionary -index 2 $available_dictionaries_complex]] {
		# Gain some facts about the dictionary file
		set language_code	[lindex $dictionary 0]
		set country_code	[lindex $dictionary 1]
		set country_name	[lindex $dictionary 2]
		set language_name	[lindex $dictionary 3]
		set flag_icon		[lindex $dictionary 4]

		# Create sub-menu if necessary
		set capital_leter [string toupper [string index $language_name 0]]
		if {$capital_leter != $last_capital_leter} {
			set last_capital_leter $capital_leter
			set local_menu [menu $m.by_language.m_[string tolower $capital_leter]]
			$m.by_language add cascade -label "$capital_leter ..." -menu $local_menu
		}

		# Create the menu item
		$local_menu add command \
			-command "::Editor::switch_SC_dictionary {${language_code}_${country_code}}" \
			-label "$language_name ($country_name)" \
			-image ::ICONS::flag::$flag_icon \
			-compound left
	}
}

## Switch current dictionary
 # @parm String dictionary - Dictionary name like: ``en_GB'' or ``en_AU''
 # @return void
proc switch_SC_dictionary {dictionary} {
	# Abort if the Hunspell program is not available
	if {!${::PROGRAM_AVAILABLE(hunspell)}} {
		return
	}

	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# Chech whether the requested dictionary is available
	if {[lsearch -ascii -exact ${::Editor::available_dictionaries} $dictionary] == -1} {
		set dictionary {}
	}

	# Empty dictionary name means disable the feature
	if {[string length $dictionary]} {
		set ::Editor::spellchecker_enabled 1
	} else {
		set ::Editor::spellchecker_enabled 0
	}

	# Adjust configuration button
	.statusbarSB configure \
		-image ::ICONS::16::player_time \
		-text "<>"

	# Clear spell checker's tags in all text editors
	foreach project ${::X::openedProjects} {
		foreach editor [$project cget -editors] {
			$editor spellchecker_clear_tags
		}
	}

	# Switch the dictionary
	set ::Editor::spellchecker_dictionary $dictionary
	restart_spellchecker_process
	adjust_spell_checker_config_button

	# Refresh all editors
	foreach project ${::X::openedProjects} {
		foreach editor [$project cget -editors] {
			$editor parseAll
		}
	}
}

## Adjust spell checker configuration button to current spell checker configuration
 # @return void
proc adjust_spell_checker_config_button {} {
	# Abort if the Hunspell program is not available
	if {!${::PROGRAM_AVAILABLE(hunspell)}} {
		return
	}
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# Spell checker configuration menu
	set m {.spell_checker_conf_menu}

	## Spell checker is DISABLED
	if {!$::Editor::spellchecker_enabled} {
		$m entryconfigure [mc "Turn off spell checking"] -state disabled
		.statusbarSB configure \
			-image ::ICONS::flag::empty \
			-text "none"

	## Spell checker is ENABLED
	} else {
		$m entryconfigure [mc "Turn off spell checking"] -state normal

		set c_l [split ${::Editor::spellchecker_dictionary} {_}]
		set idx [lsearch -ascii -exact -index 1 ${::Editor::COUNTRY_CODES_AND_FLAGS} [lindex $c_l 1]]
		if {$idx != -1} {
			set flag_icon [lindex ${::Editor::COUNTRY_CODES_AND_FLAGS} [list $idx 2]]
		} else {
			set flag_icon {empty}
		}

		.statusbarSB configure \
			-image ::ICONS::flag::$flag_icon \
			-text [lindex $c_l 0]
	}
}

## By calling this method we mark the target line as something which is a subject for a change
 # Purpose is to handle insertions of single characters and deletions of single characters
 # @note This method inhibits method spellcheck_check_all until spellcheck_change_detected_post is called
 # @see spellcheck_change_detected_post
 # @parm Int line_number = {} - Number of the target line, {} means the current line
 # @return void
private method spellcheck_change_detected_pre {{line_number {}}} {
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# Abort conditions
	if {!$spellchecker_enabled || !${::PROGRAM_AVAILABLE(hunspell)}} {
		return
	}

	# Inhibit method spellcheck_check_all until spellcheck_change_detected_post is called
	set spellcheck_lock 1

	# Adjust parameters
	if {$line_number == {}} {
		set line_number [expr {int([$editor index insert])}]
	}

	# Store the target line
	set spellcheck_line_number $line_number
	set spellcheck_line_pre [$editor get [list $line_number.0 linestart] [list $line_number.0 lineend]]
}

## By calling this method we finalize the process started by calling to method spellcheck_change_detected_pre
 # Purpose is to handle insertions of single characters and deletions of single characters
 # @see spellcheck_change_detected_pre
 # @parm Int line_number = {} - Number of the target line, {} means the current line
 # @return void
private method spellcheck_change_detected_post {{line_number {}}} {
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# Abort conditions
	if {!$spellchecker_enabled || !${::PROGRAM_AVAILABLE(hunspell)}} {
		return
	}

	# cancel the inhibition of method spellcheck_check_all
	set spellcheck_lock 0

	# Adjust parameters
	if {$line_number == {}} {
		set line_number [expr {int([$editor index insert])}]
	}

	# Determinate ranges of text indexes delimiting strings to check for spelling
	if {$prog_language == -1} {
		set target_ranges [list [list $line_number.0 [$editor index [list $line_number.0 lineend]]]]
	} else {
		set target_ranges [list]
		set range [list $line_number.0 $line_number.0]
		while {1} {
			set range [concat \
				[$editor tag nextrange tag_comment [lindex $range 1] [list $line_number.0 lineend]] \
				[$editor tag nextrange tag_c_comment [lindex $range 1] [list $line_number.0 lineend]] \
				[$editor tag nextrange tag_c_dox_comment [lindex $range 1] [list $line_number.0 lineend]] \
			]

			if {![llength $range]} {
				break
			}

			lappend target_ranges $range
		}
	}

	# Gain entire line from the editor
	set line [$editor get [list $line_number.0 linestart] [list $line_number.0 lineend]]

	if {[string length $line] > [string length $spellcheck_line_pre]} {
		set new_longer_that_org 1
	} else {
		set new_longer_that_org 0
	}

	# Compare the line to its previous content and check changed word(s)
	set fixed_shift 0	;# Total pre string shift from all cycles
	set force_check 0	;# Enforce spell check of the next word regardless the comparison
	foreach range $target_ranges {
		# Determinate start and end column
		scan [lindex $range 0] {%d.%d} _ start
		scan [lindex $range 1] {%d.%d} _ end

		set word	{}	;# String: Word to check
		set char	{}	;# Char: Character gained from the source line
		set idx_pre	$start	;# Int: Index in $spellcheck_line_pre
		set word_len	0	;# Int: Length of the word
		set skip_word	0	;# Bool: Flag skip this one word
		set change_detected 0	;# Bool: Flag the word was changed
		set char_next [string index $line $start] ;# Char: Same as char but maybe a little ahead

		# Take into accound shift from previous cycles
		incr idx_pre $fixed_shift

		for {set idx $start} {$idx < $end} {incr idx; incr idx_pre} {
			set char $char_next
			set char_next [string index $line [expr {$idx + 1}]]
			set char_pre_next [string index $spellcheck_line_pre [expr {$idx_pre + 1}]]
			set char_pre [string index $spellcheck_line_pre $idx_pre]

			if {[string is alnum $char]} {
				# If the word contains one or more digits, skip it, digits in a word
				#+ would cause Hunspell to behave in a way that we don't want here
				if {[string is digit $char]} {
					set skip_word 1
				}

				# Lines are different
				if {$char_pre != $char} {
					set change_detected 1

					# Character deleted  -- shift the pre string >> 1
					if {$char_pre_next == $char && !$new_longer_that_org} {
						incr idx_pre
						incr fixed_shift
					# Character inserted -- shift the pre string << 1
					} elseif {$char_pre == $char_next && $new_longer_that_org} {
						incr idx_pre -1
						incr fixed_shift -1
					}

				# Character appended at the end of the word -- shift the pre string << 1,
				#+ and check for the next word unconditionally
				} elseif {
					[string is alnum $char_pre_next]
						&&
					![string is alnum $char_next]
						&&
					$char_pre_next != $char_next
				} then {
					incr idx_pre -1
					incr fixed_shift -1
					set change_detected 1
					set force_check 1
				}

				# Append the character to the word
				append word $char
				incr word_len

				# This is not the last character in the line
				if {$idx < ($end - 1)} {
					continue
				# This IS the last character in the line
				} else {
					incr idx
				}
			}

			# Skip empty words
			if {!$word_len} {
				continue
			}

			# Send the word to the spell checker
			if {$change_detected && !$skip_word} {
				set change_detected 0
				$editor tag remove tag_wrong_spelling $line_number.$idx-${word_len}c-1c $line_number.$idx

				spellchecker_check_word $word \
					[list $editor tag add tag_wrong_spelling $line_number.$idx-${word_len}c $line_number.$idx] \
					[list $editor tag remove tag_wrong_spelling $line_number.$idx-${word_len}c $line_number.$idx]
			}

			# Enforce spell check of the next word regardless the comparison
			if {$force_check} {
				set force_check 0
				set change_detected 1
			}

			# Reset
			set word	{}
			set word_len	0
			set skip_word	0
		}
	}
}

## Check spelling on the specified line
 #
 # This method will not perform the task if $spellcheck_line_number is equal to
 # the given source line, unless the force parameter is set to true.
 # @note
 # Spell checking is performed only for comments unless the programming language
 # is not specified
 # @parm Int line_number	- Number of line to check
 # @parm Int force = 0		- 1: Force the method to perform the spell check; 2: Force even over $spellcheck_lock
 # @return void
public method spellcheck_check_all {line_number {force 0}} {
	# This function was not yet ported to MS Windows
	if {$::MICROSOFT_WINDOWS} {
		return
	}

	# Abort conditions
	if {($force != 2 && $spellcheck_lock) || !$spellchecker_enabled || !${::PROGRAM_AVAILABLE(hunspell)}} {
		return
	}
	if {!$force && ($spellcheck_line_number != $line_number)} {
		return
	}
	set spellcheck_line_number {}

	# Remove bad spelling tags
	$editor tag remove tag_wrong_spelling $line_number.0 [list $line_number.0 lineend]

	# Determinate ranges of text indexes delimiting strings to check for spelling
	if {$prog_language == -1} {
		set target_ranges [list [list $line_number.0 [$editor index [list $line_number.0 lineend]]]]
	} else {
		set target_ranges [list]
		set range [list $line_number.0 $line_number.0]
		while {1} {
			set range [concat \
				[$editor tag nextrange tag_comment [lindex $range 1] [list $line_number.0 lineend]] \
				[$editor tag nextrange tag_c_comment [lindex $range 1] [list $line_number.0 lineend]] \
				[$editor tag nextrange tag_c_dox_comment [lindex $range 1] [list $line_number.0 lineend]] \
			]

			if {![llength $range]} {
				break
			}

			lappend target_ranges $range
		}
	}

	# Gain entire line from the editor
	set line [$editor get $line_number.0 [list $line_number.0 lineend]]

	# Check spelling for the given ranges
	foreach range $target_ranges {
		# Determinate start and end column
		scan [lindex $range 0] {%d.%d} _ start
		scan [lindex $range 1] {%d.%d} _ end

		set word	{}	;# String: Word to check
		set char	{}	;# Char: Character gained from the source line
		set word_len	0	;# Int: Length of the word
		set skip_word	0	;# Bool: Flag skip this one word

		# Iterate over characters in the source line
		for {set idx $start} {$idx < $end} {incr idx} {
			set char [string index $line $idx]

			if {[string is alnum $char]} {
				# If the word contains one or more digits, skip it digits in a word
				#+ would cause Hunspell to behave in a way that we don't want here
				if {[string is digit $char]} {
					set skip_word 1
				}

				# Append the character to the word
				append word $char
				incr word_len

				# This is not the last character in the line
				if {$idx < ($end - 1)} {
					continue
				# This IS the last character in the line
				} else {
					incr idx
				}
			}

			# Skip empty words
			if {!$word_len} {
				continue
			}

			# Send the word to the spell checker
			if {!$skip_word} {
				spellchecker_check_word \
					$word \
					[list $editor tag add tag_wrong_spelling $line_number.$idx-${word_len}c $line_number.$idx]
			}

			# Reset
			set word {}
			set word_len	0
			set skip_word	0
		}
	}
}

## Clear all tags marking the misspelled words
 # @return void
public method spellchecker_clear_tags {} {
	$editor tag remove tag_wrong_spelling 0.0 end
}

# >>> File inclusion guard
}
# <<< File inclusion guard
