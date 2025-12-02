---@class ParsedPacket
---@field header? { id: number, size: number, sync: number }

---@class GP_SERV_COMMAND_GUILD_BUY : ParsedPacket
---@field ItemNo number
---@field Count number
---@field Trade number

---@class GP_SERV_COMMAND_GUILD_BUYLIST : ParsedPacket
---@field List table[] -- Fixed size 30
---@field Count number
---@field Stat number

---@class GP_SERV_COMMAND_PACKETCONTROL : ParsedPacket
---@field PacketCnt number
---@field padding00 number[] -- Fixed size 5

---@class GP_SERV_COMMAND_GUILD_SELLLIST : ParsedPacket
---@field List table[] -- Fixed size 30
---@field Count number
---@field Stat number

---@class GP_SERV_COMMAND_BAZAAR_LIST : ParsedPacket
---@field Price number
---@field ItemNum number
---@field TaxRate number
---@field ItemNo number
---@field ItemIndex number
---@field Attr any -- raw, 24 bytes
---@field padding00 any -- raw, 3 bytes

---@class GP_SERV_COMMAND_ENTERZONE : ParsedPacket
---@field EnterZoneTbl number[] -- Fixed size 48

---@class GP_SERV_COMMAND_MESSAGE : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field MesNo number
---@field Attr number

---@class GP_SERV_COMMAND_LOGIN : ParsedPacket
---@field PosHead table -- Nested struct
---@field ZoneNo number
---@field ntTime number
---@field ntTimeSec number
---@field GameTime number
---@field EventNo number
---@field MapNumber number
---@field GrapIDTbl number[] -- Fixed size 9
---@field MusicNum number[] -- Fixed size 5
---@field SubMapNumber number
---@field EventNum number
---@field EventPara number
---@field EventMode number
---@field WeatherNumber number
---@field WeatherNumber2 number
---@field WeatherTime number
---@field WeatherTime2 number
---@field WeatherOffsetTime number
---@field WeatherOffsetTime2 number
---@field ShipStart number
---@field ShipEnd number
---@field IsMonstrosity number
---@field LoginState number
---@field name string -- 16 bytes
---@field certificate number[] -- Fixed size 2
---@field unknown00 number
---@field ZoneSubNo number
---@field PlayTime number
---@field DeadCounter number
---@field MyroomSubMapNumber number
---@field unknown01 number
---@field MyroomMapNumber number
---@field SendCount number
---@field MyRoomExitBit number
---@field MogZoneFlag number
---@field Dancer any -- raw, 80 bytes
---@field ConfData any -- raw, 12 bytes
---@field Ex number

---@class GP_SERV_COMMAND_LOGOUT : ParsedPacket
---@field LogoutState number
---@field Iwasaki number[] -- Fixed size 16
---@field GP_SERV_LOGOUTSUB any -- Computed
---@field cliErrCode number

---@class GP_SERV_COMMAND_BAZAAR_SALE : ParsedPacket
---@field ItemNum number
---@field ItemNo number
---@field sName string -- 16 bytes
---@field padding00 any -- raw, 2 bytes

---@class GP_SERV_COMMAND_CHAR_PC : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field SendFlg_num number
---@field SendFlg any -- Computed
---@field dir number
---@field x number
---@field z number
---@field y number
---@field Flags0_num number
---@field Flags0 any -- Computed
---@field Speed number
---@field SpeedBase number
---@field Hpp number
---@field server_status number
---@field Flags1_num number
---@field Flags1 any -- Computed
---@field Flags2_num number
---@field Flags2 any -- Computed
---@field Flags3_num number
---@field Flags3 any -- Computed
---@field BtTargetID number
---@field CostumeId number
---@field BallistaInfo number
---@field Flags4_num number
---@field Flags4 any -- Computed
---@field CustomProperties number[] -- Fixed size 2
---@field PetActIndex number
---@field MonstrosityFlags number
---@field MonstrosityNameId1 number
---@field MonstrosityNameId2 number
---@field Flags5_num number
---@field Flags5 any -- Computed
---@field ModelHitboxSize number
---@field Flags6_num number
---@field Flags6 any -- Computed
---@field GrapIDTbl number[] -- Fixed size 9
---@field name string -- 16 bytes

---@class GP_SERV_COMMAND_CHAR_NPC : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field SendFlg_num number
---@field SendFlg any -- Computed
---@field dir number
---@field x number
---@field z number
---@field y number
---@field Flags0_num number
---@field Flags0 any -- Computed
---@field Speed number
---@field SpeedBase number
---@field Hpp number
---@field server_status number
---@field Flags1_num number
---@field Flags1 any -- Computed
---@field Flags2_num number
---@field Flags2 any -- Computed
---@field Flags3_num number
---@field Flags3 any -- Computed
---@field SubAnimation any -- Computed
---@field BtTargetID number
---@field SubKind number
---@field Status number
---@field Data table -- Nested struct
---@field NPCType any -- Computed

---@class GP_SERV_COMMAND_EFFECT : ParsedPacket
---@field UniqueNo number       -- 0x04: Entity server ID
---@field ActIndex number       -- 0x08: Entity target index
---@field EffectNum number      -- 0x0A: Effect number (signed int16)
---@field Type number           -- 0x0C: Effect type (signed int8)
---@field Status number         -- 0x0D: Effect status (signed int8)
---@field Timer number          -- 0x0E: Effect timer

---@class GP_SERV_COMMAND_COMBINE_ANS : ParsedPacket
---@field Result number         -- 0x04: Synthesis result (0x00=Success, 0x01=Fail: Lost Crystal, etc.)
---@field Grade number          -- 0x05: Grade/quality of the synthesis result (-1 to +3 typically)
---@field Count number          -- 0x06: Number of items produced
---@field padding00 number      -- 0x07: Padding (unused)
---@field ItemNo number         -- 0x08: Item ID of the synthesized item
---@field BreakNo number[]      -- 0x0A: Array[8] of item IDs that broke during synthesis
---@field UpKind number[]       -- 0x1A: Array[4] of skill types that leveled up (signed int8)
---@field UpLevel number[]      -- 0x1E: Array[4] of skill level increases (signed int8)
---@field CrystalNo number      -- 0x22: Crystal item ID used for synthesis
---@field MaterialNo number[]   -- 0x24: Array[8] of material item IDs used
---@field padding01 number      -- 0x34: Padding (unused)

---@class GP_SERV_COMMAND_REQSUBMAPNUM : ParsedPacket
---@field MapNum number

---@class GP_SERV_COMMAND_REQLOGOUTINFO : ParsedPacket
---@field Mode number

---@class GP_SERV_COMMAND_GM : ParsedPacket

---@class GP_SERV_COMMAND_GMCOMMAND : ParsedPacket
---@field GMUniqueNo number

---@class GP_SERV_COMMAND_CHAT_STD : ParsedPacket
---@field Kind number
---@field Attr number
---@field Data number
---@field sName string -- 15 bytes
---@field Mes any -- raw, computed bytes
---@field KindString any -- Computed

---@class GP_SERV_COMMAND_ITEM_MAX : ParsedPacket
---@field ItemNum table[] -- Fixed size 18
---@field padding00 any -- raw, 14 bytes
---@field ItemNum2 table[] -- Fixed size 18
---@field padding01 any -- raw, 28 bytes

---@class GP_SERV_COMMAND_ITEM_SAME : ParsedPacket
---@field State number
---@field padding00 any -- raw, 3 bytes
---@field Flags number

---@class GP_SERV_COMMAND_ITEM_NUM : ParsedPacket
---@field ItemNum number
---@field Category number
---@field ItemIndex number
---@field LockFlg number

---@class GP_SERV_COMMAND_ITEM_LIST : ParsedPacket
---@field ItemNum number
---@field ItemNo number
---@field Category number
---@field ItemIndex number
---@field LockFlg number

---@class GP_SERV_COMMAND_ITEM_ATTR : ParsedPacket
---@field ItemNum number
---@field Price number
---@field ItemNo number
---@field Category number
---@field ItemIndex number
---@field LockFlg number
---@field Attr any -- raw, 24 bytes

---@class GP_SERV_COMMAND_ITEM_TRADE_REQ : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field padding00 number

---@class GP_SERV_COMMAND_ITEM_TRADE_RES : ParsedPacket
---@field UniqueNo number
---@field Kind number
---@field ActIndex number

---@class GP_SERV_COMMAND_ITEM_TRADE_LIST : ParsedPacket
---@field ItemNum number
---@field TradeCounter number
---@field ItemNo number
---@field ItemFreeSpaceNum number
---@field TradeIndex number
---@field Attr any -- raw, 24 bytes

---@class GP_SERV_COMMAND_ITEM_TRADE_MYLIST : ParsedPacket
---@field ItemNum number
---@field ItemNo number
---@field TradeIndex number
---@field ItemIndex number

---@class GP_SERV_COMMAND_TALKNUMWORK2 : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field MesNum number
---@field Type number
---@field Flags number
---@field padding00 number
---@field Num1 number[] -- Fixed size 4
---@field String1 string -- 32 bytes
---@field String2 string -- 16 bytes
---@field Num2 number[] -- Fixed size 8
---@field SpeakerName any -- Computed

---@class GP_SERV_COMMAND_BATTLE2 : ParsedPacket
---@field info_size number
---@field m_uID number
---@field trg_sum number
---@field res_sum number
---@field cmd_no number
---@field ActionType any -- Computed
---@field cmd_arg number
---@field info number
---@field target table[] -- Fixed size trg_sum

---@class GP_SERV_COMMAND_BATTLE_MESSAGE : ParsedPacket
---@field UniqueNoCas number
---@field UniqueNoTar number
---@field Data number
---@field Data2 number
---@field ActIndexCas number
---@field ActIndexTar number
---@field MessageNum number
---@field Type number
---@field padding00 number

---@class GP_SERV_COMMAND_TALKNUMWORK : ParsedPacket
---@field UniqueNo number
---@field num number[] -- Fixed size 4
---@field ActIndex number
---@field MesNum number
---@field Type number
---@field Flag number
---@field String string -- 32 bytes
---@field MessageNumber any -- Computed
---@field IgnoreValidation any -- Computed
---@field TypeLookup any -- Computed
---@field SpeakerName any -- Computed

---@class GP_SERV_COMMAND_EVENT : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field EventNum number
---@field EventPara number
---@field Mode number
---@field EventNum2 number
---@field EventPara2 number

---@class GP_SERV_COMMAND_EVENTSTR : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field EventNum number
---@field EventPara number
---@field Mode number
---@field String string[] -- Fixed size 4
---@field Data number[] -- Fixed size 8

---@class GP_SERV_COMMAND_EVENTNUM : ParsedPacket
---@field UniqueNo number
---@field num number[] -- Fixed size 8
---@field ActIndex number
---@field EventNum number
---@field EventPara number
---@field Mode number
---@field EventNum2 number
---@field EventPara2 number

---@class GP_SERV_COMMAND_TALKNUM : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field MesNum number
---@field Type number
---@field padding00 number
---@field padding01 number

---@class GP_SERV_COMMAND_SCHEDULOR : ParsedPacket
---@field UniqueNoCas number
---@field UniqueNoTar number
---@field id number
---@field ActIndexCast number
---@field ActIndexTar number
---@field FourCCString any -- Computed

---@class GP_SERV_COMMAND_MAPSCHEDULOR : ParsedPacket
---@field UniqueNoCas number
---@field UniqueNoTar number
---@field id number
---@field ActIndexCast number
---@field ActIndexTar number
---@field FourCCString any -- Computed

---@class GP_SERV_COMMAND_MAGICSCHEDULOR : ParsedPacket
---@field UniqueNoCas number
---@field UniqueNoTar number
---@field ActIndexCast number
---@field ActIndexTar number
---@field fileNum number
---@field type number
---@field padding00 number
---@field TypeName any -- Computed

---@class GP_SERV_COMMAND_EVENTMES : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field Number number
---@field MessageNumber any -- Computed
---@field UseEntityName any -- Computed

---@class GP_SERV_COMMAND_SHOP_LIST : ParsedPacket
---@field ShopItemOffsetIndex number
---@field Flags number
---@field padding00 number
---@field ShopItemTbl table[] -- Fixed size function: 00000164E6906070

---@class GP_SERV_COMMAND_SHOP_SELL : ParsedPacket
---@field Price number
---@field PropertyItemIndex number
---@field Type number
---@field padding00 number
---@field Count number

---@class GP_SERV_COMMAND_SHOP_OPEN : ParsedPacket
---@field ShopListNum number
---@field padding00 number

---@class GP_SERV_COMMAND_SHOP_BUY : ParsedPacket
---@field ShopItemIndex number
---@field BuyState number
---@field padding00 number
---@field Count number

---@class GP_SERV_COMMAND_BLACK_LIST : ParsedPacket
---@field List table[] -- Fixed size 12
---@field Stat number
---@field Num number
---@field padding00 number

---@class GP_SERV_COMMAND_BLACK_EDIT : ParsedPacket
---@field Data table -- Nested struct
---@field Mode number
---@field padding00 any -- raw, 3 bytes

---@class GP_SERV_COMMAND_TALKNUMNAME : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field MesNum number
---@field Type number
---@field padding00 number
---@field padding01 number
---@field sName string -- 16 bytes
---@field MessageNumber any -- Computed
---@field IgnoreValidation any -- Computed
---@field TypeLookup any -- Computed

---@class GP_SERV_COMMAND_LINKSHELL_MESSAGE : ParsedPacket
---@field stat_attr number
---@field Stat any -- Computed
---@field Attr any -- Computed
---@field levels_index number
---@field ReadLevel any -- Computed
---@field WriteLevel any -- Computed
---@field PubEditLevel any -- Computed
---@field Linkshell_Index any -- Computed
---@field SeqId number
---@field SMessage string -- 128 bytes
---@field UpdateTime number
---@field Modifier string -- 16 bytes
---@field OpType number
---@field padding00 number
---@field EncodedLsName any -- raw, 16 bytes
---@field ReadLevelString any -- Computed
---@field WriteLevelString any -- Computed
---@field OpTypeString any -- Computed

---@class GP_SERV_COMMAND_EQUIP_CLEAR : ParsedPacket
---@field padding00 number

---@class GP_SERV_COMMAND_EQUIP_LIST : ParsedPacket
---@field PropertyItemIndex number
---@field EquipKind number
---@field Category number
---@field padding00 number

---@class GP_SERV_COMMAND_GRAP_LIST : ParsedPacket
---@field GrapIDTbl table[] -- Fixed size 9
---@field padding00 number

---@class GP_SERV_COMMAND_EVENTUCOFF : ParsedPacket
---@field Mode number
---@field ModeType any -- Computed
---@field EventId any -- Computed
---@field ModeDescription any -- Computed

---@class GP_SERV_COMMAND_SYSTEMMES : ParsedPacket
---@field para number
---@field para2 number
---@field Number number
---@field padding00 number

---@class GP_SERV_COMMAND_SCENARIOITEM : ParsedPacket
---@field GetItemFlag number[] -- Fixed size 16
---@field LookItemFlag number[] -- Fixed size 16
---@field TableIndex number
---@field padding00 number

---@class GP_SERV_COMMAND_WPOS : ParsedPacket
---@field x number
---@field y number
---@field z number
---@field UniqueNo number
---@field ActIndex number
---@field Mode number
---@field dir number
---@field padding00 number

---@class GP_SERV_COMMAND_PENDINGNUM : ParsedPacket
---@field num number[] -- Fixed size 8

---@class GP_SERV_COMMAND_GROUP_SOLICIT_REQ : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field AnonFlag number
---@field Kind number
---@field sName string -- 16 bytes
---@field RaceNo number
---@field InviteType any -- Computed
---@field IsAnon any -- Computed
---@field HideMessage any -- Computed

---@class GP_SERV_COMMAND_GROUP_LIST : ParsedPacket
---@field UniqueNo number
---@field Hp number
---@field Mp number
---@field Tp number
---@field GAttr table -- Nested struct
---@field ActIndex number
---@field MemberNumber number
---@field MoghouseFlg number
---@field Kind number
---@field Hpp number
---@field Mpp number
---@field padding01 number
---@field ZoneNo number
---@field mjob_no number
---@field mjob_lv number
---@field sjob_no number
---@field sjob_lv number
---@field masterjob_lv number
---@field masterjob_flags number
---@field Name string -- 16 bytes
---@field PartyNo any -- Computed
---@field PartyLeaderFlg any -- Computed
---@field AllianceLeaderFlg any -- Computed
---@field PartyRFlg any -- Computed
---@field AllianceRFlg any -- Computed
---@field MasteryFlags any -- Computed

---@class GP_SERV_COMMAND_MUSIC : ParsedPacket
---@field Slot number
---@field MusicNum number
---@field SlotDescription any -- Computed

---@class GP_SERV_COMMAND_MUSICVOLUME : ParsedPacket
---@field time number
---@field volume number
---@field VolumePercentage any -- Computed

---@class GP_SERV_COMMAND_GROUP_COMLINK : ParsedPacket
---@field LinkshellNum number
---@field ItemIndex number
---@field Category number
---@field padding00 number

---@class GP_SERV_COMMAND_GROUP_CHECKID : ParsedPacket
---@field GroupID number

---@class GP_SERV_COMMAND_GROUP_LIST2 : ParsedPacket
---@field UniqueNo number
---@field Hp number
---@field Mp number
---@field Tp number
---@field GAttr table -- Nested struct
---@field ActIndex number
---@field MemberNumber number
---@field MoghouseFlg number
---@field Kind number
---@field Hpp number
---@field Mpp number
---@field padding01 number
---@field ZoneNo number
---@field mjob_no number
---@field mjob_lv number
---@field sjob_no number
---@field sjob_lv number
---@field masterjob_lv number
---@field masterjob_flags number
---@field Name string -- 16 bytes
---@field PartyNo any -- Computed
---@field PartyLeaderFlg any -- Computed
---@field AllianceLeaderFlg any -- Computed
---@field PartyRFlg any -- Computed
---@field AllianceRFlg any -- Computed
---@field MasteryFlags any -- Computed

---@class GP_SERV_COMMAND_TRACKING_LIST : ParsedPacket
---@field ActIndex number
---@field Level number
---@field Type number
---@field unused number
---@field x number
---@field z number
---@field sName string -- 16 bytes
---@field DotColor any -- Computed
---@field Hidden any -- Computed

---@class GP_SERV_COMMAND_TRACKING_STATE : ParsedPacket
---@field State number

---@class GP_SERV_COMMAND_GROUP_ATTR : ParsedPacket
---@field UniqueNo number
---@field Hp number
---@field Mp number
---@field Tp number
---@field ActIndex number
---@field Hpp number
---@field Mpp number
---@field Kind number
---@field MoghouseFlg number
---@field ZoneNo number
---@field MonstrosityFlag number
---@field MonstrosityNameId number
---@field mjob_no number
---@field mjob_lv number
---@field sjob_no number
---@field sjob_lv number
---@field masterjob_lv number
---@field masterjob_flags number
---@field MasteryFlags any -- Computed

---@class GP_SERV_COMMAND_GROUP_SOLICIT_NO : ParsedPacket
---@field Reason number
---@field padding00 any -- raw, 3 bytes

---@class GP_SERV_COMMAND_GUILD_OPEN : ParsedPacket
---@field Stat number
---@field padding00 any -- raw, 3 bytes
---@field Time number

---@class GP_SERV_COMMAND_GUILD_SELL : ParsedPacket
---@field ItemNo number
---@field Count number
---@field Trade number

---@class GP_SERV_COMMAND_BAZAAR_SELL : ParsedPacket
---@field UniqueNo number
---@field ItemNum number
---@field ActIndex number
---@field BazaarActIndex number
---@field sName string -- 16 bytes
---@field ItemIndex number
---@field padding00 any -- raw, 3 bytes

---@class GP_SERV_COMMAND_BAZAAR_SHOPPING : ParsedPacket
---@field UniqueNo number
---@field State number
---@field HideLevel number
---@field padding00 number
---@field ActIndex number
---@field sName string -- 16 bytes

---@class GP_SERV_COMMAND_BAZAAR_CLOSE : ParsedPacket
---@field sName string -- 16 bytes
---@field padding00 any -- raw, 4 bytes

---@class GP_SERV_COMMAND_BAZAAR_BUY : ParsedPacket
---@field State number
---@field sName string -- 16 bytes

---@class GP_SERV_COMMAND_WEATHER : ParsedPacket
---@field StartTime number
---@field WeatherNumber number
---@field WeatherOffsetTime number

---@class CLISTATUS
---@field hpmax number
---@field mpmax number
---@field mjob_no number
---@field mjob_lv number
---@field sjob_no number
---@field sjob_lv number
---@field exp_now number
---@field exp_next number
---@field bp_base table -- Array of 7 base stat values (STR, DEX, VIT, AGI, INT, MND, CHR)
---@field bp_adj table -- Array of 7 adjusted stat values
---@field atk number
---@field def number
---@field def_elem table -- Array of 8 elemental defense values
---@field designation number
---@field rank number
---@field rankbar number
---@field BindZoneNo number
---@field MonsterBuster number
---@field nation number
---@field myroom number
---@field su_lv number
---@field padding00 number
---@field highest_ilvl number
---@field ilvl number
---@field ilvl_mhand number
---@field ilvl_ranged number
---@field unity_info number
---@field unity_points1 number
---@field unity_points2 number
---@field unity_chat_color_flag number
---@field mastery_info number
---@field mastery_exp_now number
---@field mastery_exp_next number

---@class GP_SERV_COMMAND_CLISTATUS : ParsedPacket
---@field statusdata CLISTATUS

---@class GP_CLI_COMMAND_SHOP_BUY : ParsedPacket
---@field ItemNum number
---@field ShopNo number
---@field ShopItemIndex number
---@field PropertyItemIndex number
---@field padding00 any -- raw, 3 bytes

---@class GP_CLI_COMMAND_SHOP_SELL_REQ : ParsedPacket
---@field ItemNum number
---@field ItemNo number
---@field ItemIndex number
---@field padding00 number

---@class GP_CLI_COMMAND_SHOP_SELL_SET : ParsedPacket
---@field SellFlag number

---@class GP_CLI_COMMAND_BAZAAR_LIST : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field padding00 number

---@class GP_CLI_COMMAND_BAZAAR_BUY : ParsedPacket
---@field BazaarItemIndex number
---@field padding00 any -- raw, 3 bytes
---@field BuyNum number

---@class GP_CLI_COMMAND_BAZAAR_OPEN : ParsedPacket

---@class GP_CLI_COMMAND_BAZAAR_ITEMSET : ParsedPacket
---@field ItemIndex number
---@field padding00 any -- raw, 3 bytes
---@field Price number

---@class GP_CLI_COMMAND_BAZAAR_CLOSE : ParsedPacket
---@field AllListClearFlg number

---@class GP_CLI_COMMAND_EQUIP_SET : ParsedPacket
---@field PropertyItemIndex number
---@field EquipKind number
---@field Category number

---@class GP_CLI_COMMAND_POS : ParsedPacket
---@field x number
---@field z number
---@field y number
---@field MovTime number
---@field MoveFlame number
---@field dir number
---@field TargetMode number
---@field RunMode number
---@field GroundMode number
---@field unused number
---@field facetarget number
---@field TimeNow number

---@class GP_CLI_COMMAND_EVENTEND : ParsedPacket
---@field UniqueNo number
---@field EndPara number
---@field ActIndex number
---@field Mode number
---@field EventNum number
---@field EventPara number

---@class GP_CLI_COMMAND_EVENTENDXZY : ParsedPacket
---@field x number
---@field y number
---@field z number
---@field UniqueNo number
---@field EndPara number
---@field EventNum number
---@field EventPara number
---@field ActIndex number
---@field Mode number
---@field dir number

---@class GP_CLI_COMMAND_PASSWARDS : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field padding00 number
---@field String string -- 16 bytes

---@class GP_CLI_COMMAND_ITEM_DUMP : ParsedPacket
---@field ItemNum number
---@field Category number
---@field ItemIndex number

---@class GP_CLI_COMMAND_ITEM_MOVE : ParsedPacket
---@field ItemNum number
---@field Category1 number
---@field Category2 number
---@field ItemIndex1 number
---@field ItemIndex2 number

---@class GP_CLI_COMMAND_ITEM_ATTR : ParsedPacket
---@field Category number
---@field ItemIndex number

---@class GP_CLI_COMMAND_GUILD_BUY : ParsedPacket
---@field ItemNo number
---@field PropertyItemIndex number
---@field ItemNum number

---@class GP_CLI_COMMAND_GUILD_BUYLIST : ParsedPacket

---@class GP_CLI_COMMAND_REQSUBMAPNUM : ParsedPacket
---@field MapNum number

---@class GP_CLI_COMMAND_REQLOGOUTINFO : ParsedPacket
---@field Mode number

---@class GP_CLI_COMMAND_ITEM_TRADE_REQ : ParsedPacket
---@field UniqueNo number
---@field ActIndex number
---@field padding00 number

---@class GP_CLI_COMMAND_ITEM_TRADE_RES : ParsedPacket
---@field Kind number
---@field TradeCounter number

---@class GP_CLI_COMMAND_ITEM_TRADE_LIST : ParsedPacket
---@field ItemNum number
---@field ItemNo number
---@field ItemIndex number
---@field TradeIndex number

---@class GP_CLI_COMMAND_ITEM_TRANSFER : ParsedPacket
---@field UniqueNo number
---@field ItemNumTbl table[] -- Fixed size 10
---@field PropertyItemIndexTbl table[] -- Fixed size 10
---@field ActIndex number
---@field ItemNum number
---@field padding00 any -- raw, 3 bytes

---@class GP_CLI_COMMAND_CHAT_STD : ParsedPacket
---@field Kind number
---@field unknown00 number
---@field Str any -- raw, computed bytes
---@field MessageType any -- Computed

---@class GP_CLI_COMMAND_CHAT_NAME : ParsedPacket
---@field ChanNo number
---@field padding00 number
---@field padding01 number
---@field sName string -- 16 bytes

---@class GP_CLI_COMMAND_ITEM_USE : ParsedPacket
---@field UniqueNo number
---@field ItemNum number
---@field ActIndex number
---@field PropertyItemIndex number
---@field padding00 number
---@field Category number

---@class GP_CLI_COMMAND_ITEM_STACK : ParsedPacket
---@field Category number

---@class GP_CLI_COMMAND_ITEM_MAKE : ParsedPacket
---@field ItemNum number
---@field ItemNo number
---@field padding00 number

---@class GP_CLI_COMMAND_BLACK_LIST : ParsedPacket
---@field unknown00 number
---@field unknown01 number
---@field unknown02 number
---@field unknown03 number
---@field unknown04 number
---@field unknown05 number
---@field padding00 any -- raw, 3 bytes

---@class GP_CLI_COMMAND_BLACK_EDIT : ParsedPacket
---@field Data table -- Nested struct
---@field Mode number
---@field padding00 any -- raw, 3 bytes

---@class GP_CLI_COMMAND_GUILD_SELLLIST : ParsedPacket

---@class GP_CLI_COMMAND_GUILD_SELL : ParsedPacket
---@field ItemNo number
---@field PropertyItemIndex number
---@field ItemNum number
