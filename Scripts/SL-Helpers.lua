------------------------------------------------------------------------------
-- call this to draw a Quad with a border
-- width of quad, height of quad, and border width, in pixels

function Border(width, height, bw)
	return Def.ActorFrame {
		Def.Quad {
			InitCommand=cmd(zoomto, width-2*bw, height-2*bw;  MaskSource,true)
		},
		Def.Quad {
			InitCommand=cmd(zoomto,width,height; MaskDest)
		},
		Def.Quad {
			InitCommand=cmd(diffusealpha,0; clearzbuffer,true)
		},
	}
end


------------------------------------------------------------------------------
-- Misc Lua functions that didn't fit anywhere else...

-- return true or nil
CurrentGameIsSupported = function()
	-- a hardcoded list of games that Simply Love supports
	local support = {
		dance	= true,
		pump = true,
		techno = true,
		para = true,
		kb7 = true
	}
	return support[GAMESTATE:GetCurrentGame():GetName()]
end


-- helper function used to detmerine which timing_window a given offset belongs to
function DetermineTimingWindow(offset)
	for i=1,5 do
		if math.abs(offset) < SL.Preferences[SL.Global.GameMode]["TimingWindowSecondsW"..i] + SL.Preferences[SL.Global.GameMode]["TimingWindowAdd"] then
			return i
		end
	end
	return 5
end


function GetCredits()
	local coins = GAMESTATE:GetCoins()
	local coinsPerCredit = PREFSMAN:GetPreference('CoinsPerCredit')
	local credits = math.floor(coins/coinsPerCredit)
	local remainder = coins % coinsPerCredit

	local r = {
		Credits=credits,
		Remainder=remainder,
		CoinsPerCredit=coinsPerCredit
	}
	return r
end

-- Used in Metrics.ini for ScreenRankingSingle and ScreenRankingDouble
function GetStepsTypeForThisGame(type)
	local game = GAMESTATE:GetCurrentGame():GetName()
	-- capitalize the first letter
	game = game:gsub("^%l", string.upper)

	return "StepsType_" .. game .. "_" .. type
end


function GetNotefieldX( player )
	local p = ToEnumShortString(player)

	local IsPlayingDanceSolo = (GAMESTATE:GetCurrentStyle():GetStepsType() == "StepsType_Dance_Solo")
	local IsUsingSoloSingles = PREFSMAN:GetPreference('Center1Player') or IsPlayingDanceSolo
	local NumPlayersEnabled = GAMESTATE:GetNumPlayersEnabled()
	local NumSidesJoined = GAMESTATE:GetNumSidesJoined()

	if IsUsingSoloSingles and NumPlayersEnabled == 1 and NumSidesJoined == 1 then return _screen.cx end
	if GAMESTATE:GetCurrentStyle():GetStyleType() == "StyleType_OnePlayerTwoSides" then return _screen.cx end

	local NumPlayersAndSides = ToEnumShortString( GAMESTATE:GetCurrentStyle():GetStyleType() )
	return THEME:GetMetric("ScreenGameplay","Player".. p .. NumPlayersAndSides .."X")
end

function GetNotefieldWidth()

	-- double
	if GAMESTATE:GetCurrentStyle():GetStyleType() == "StyleType_OnePlayerTwoSides" then
		return _screen.w*1.058/GetScreenAspectRatio()

	-- dance solo
	elseif GAMESTATE:GetCurrentStyle():GetStepsType() == "StepsType_Dance_Solo" then
		return _screen.w*0.8/GetScreenAspectRatio()

	-- single
	else
		return _screen.w*0.529/GetScreenAspectRatio()
	end
end

------------------------------------------------------------------------------
-- Define what is necessary to maintain and/or increment your combo, per Gametype.
-- For example, in dance Gametype, TapNoteScore_W3 (window #3) is commonly "Great"
-- so in dance, a "Great" will not only maintain a player's combo, it will also increment it.
--
-- We reference this function in Metrics.ini under the [Gameplay] section.
function GetComboThreshold( MaintainOrContinue )
	local CurrentGame = GAMESTATE:GetCurrentGame():GetName()

	local ComboThresholdTable = {
		dance	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
		pump	=	{ Maintain = "TapNoteScore_W4", Continue = "TapNoteScore_W4" },
		techno	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
		kb7		=	{ Maintain = "TapNoteScore_W4", Continue = "TapNoteScore_W4" },
		-- these values are chosen to match Deluxe's PARASTAR
		para	=	{ Maintain = "TapNoteScore_W5", Continue = "TapNoteScore_W3" },

		-- I don't know what these values are supposed to actually be...
		popn	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
		beat	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
		kickbox	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },

		-- lights is not a playable game mode, but it is, oddly, a selectable one within the operator menu
		-- include dummy values here to prevent Lua errors in case players accidentally switch to lights
		lights =	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
	}


	if CurrentGame ~= "para" then
		if SL.Global.GameMode == "StomperZ" or SL.Global.GameMode=="ECFA" then
			ComboThresholdTable.dance.Maintain = "TapNoteScore_W4"
			ComboThresholdTable.dance.Continue = "TapNoteScore_W4"
		end
	end

	return ComboThresholdTable[CurrentGame][MaintainOrContinue]
end

-- -----------------------------------------------------------------------

function SetGameModePreferences()
	-- apply the preferences associated with this GameMode
	for key,val in pairs(SL.Preferences[SL.Global.GameMode]) do
		PREFSMAN:SetPreference(key, val)
	end

	-- If we're switching to Casual mode,
	-- we want to reduce the number of judgments,
	-- so turn Decents and WayOffs off now.
	if SL.Global.GameMode == "Casual" then
		SL.Global.ActiveModifiers.DecentsWayOffs = "Off"

	-- Otherwise, we want Decents and WayOffs enabled by default.
	else
 		SL.Global.ActiveModifiers.DecentsWayOffs = "On"
	end

	-- loop through human players and apply whatever mods need to be set now
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		-- Now that we've set the SL table for DecentsWayOffs appropriately,
		-- use it to apply DecentsWayOffs as a mod.
		local OptRow = CustomOptionRow( "DecentsWayOffs" )
		OptRow:LoadSelections( OptRow.Choices, player )

		-- using PREFSMAN to set the preference for MinTNSToHideNotes apparently isn't
		-- enough when switching gamemodes because MinTNSToHideNotes is also a PlayerOption.
		-- so, set the PlayerOption version of it now, too, to ensure that arrows disappear
		-- at the appropriate judgments during gameplay for this gamemode.
		GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):MinTNSToHideNotes(SL.Preferences[SL.Global.GameMode].MinTNSToHideNotes)
	end

	local prefix = {
		Competitive = "",
		ECFA = "ECFA-",
		StomperZ = "StomperZ-",
		Casual = "Casual-"
	}

	if PROFILEMAN:GetStatsPrefix() ~= prefix[SL.Global.GameMode] then
		PROFILEMAN:SetStatsPrefix(prefix[SL.Global.GameMode])
	end
end

-- -----------------------------------------------------------------------
-- the available OptionRows for an options screen can change depending on certain conditions
-- these functions start with all possible OptionRows and remove rows as needed
-- whatever string is finally returned is passed off to the pertinent LineNames= in Metrics.ini

function GetOperatorMenuLineNames()
	local lines = "System,KeyConfig,TestInput,Visual,GraphicsSound,Arcade,Input,Theme,MenuTimer,CustomSongs,Advanced,Profiles,Acknowledgments,ClearCredits,Reload"

	-- the TestInput screen only supports dance, pump, and techno; remove it when in other games
	local CurrentGame = GAMESTATE:GetCurrentGame():GetName()
	if not (CurrentGame=="dance" or CurrentGame=="pump" or CurrentGame=="techno") then
		lines = lines:gsub("TestInput,", "")
	end

	-- hide the OptionRow for ClearCredits if we're not in CoinMode_Pay; it doesn't make sense to show for at-home players
	-- note that (EventMode + CoinMode_Pay) will actually place you in CoinMode_Home
	if GAMESTATE:GetCoinMode() ~= "CoinMode_Pay" then
		lines = lines:gsub("ClearCredits,", "")
	end

	-- CustomSongs preferences don't exist in 5.0.x, which many players may still be using
	-- thus, if the preference for CustomSongsEnable isn't found in this version of SM, don't let players
	-- get into the CustomSongs submenu in the OperatorMenu by removing that OptionRow
	if not PREFSMAN:PreferenceExists("CustomSongsEnable") then
		lines = lines:gsub("CustomSongs,", "")
	end
	return lines
end


function GetSimplyLoveOptionsLineNames()
	local lines = "CasualMaxMeter,AutoStyle,DefaultGameMode,TimingWindowAdd,CustomFailSet,CreditStacking,MusicWheelStyle,MusicWheelSpeed,SelectProfile,SelectColor,EvalSummary,NameEntry,GameOver,HideStockNoteSksins,DanceSolo,GradesInMusicWheel,Nice,VisualTheme,RainbowMode"
	if Sprite.LoadFromCached ~= nil then
		lines = lines .. ",UseImageCache"
	end
	return lines
end


function GetPlayerOptions2LineNames()
	local mods = "Turn,Scroll,7,8,9,10,11,12,13,Attacks,Hide,ReceptorArrowsPosition,LifeMeterType,TargetStatus,TargetBar,ActionOnMissedTarget,GameplayExtras,MeasureCounterPosition,MeasureCounter,DecentsWayOffs,Vocalization,Characters,ScreenAfterPlayerOptions2"

	-- remove ReceptorArrowsPosition if GameMode isn't StomperZ
	if SL.Global.GameMode ~= "StomperZ" then
		mods = mods:gsub("ReceptorArrowsPosition", "")
	end

	-- remove DecentsWayOffs and LifeMeterType if GameMode is StomperZ
	if SL.Global.GameMode == "StomperZ" then
		mods = mods:gsub("DecentsWayOffs,", ""):gsub("LifeMeterType", "")
	end

	-- remove TargetStatus and TargetBar (IIDX pacemaker) if style is double
	if SL.Global.Gamestate.Style == "double" then
		mods = mods:gsub("TargetStatus,TargetBar,ActionOnMissedTarget,", "")
	end

	-- remove Vocalization if no voice packs were found in the filesystem
	if #FILEMAN:GetDirListing(GetVocalizeDir() , true, false) < 1 then
		mods = mods:gsub("Vocalization," ,"")
	end

	-- remove Characters if no dancing character directories were found
	if #CHARMAN:GetAllCharacters() < 1 then
		mods = mods:gsub("Characters,", "")
	end

	-- ActionOnMissedTarget can automatically fail or restart Gameplay when a target score
	-- becomes impossible to achieve; it really only makes sense in EventMode (i.e., not public arcades)
	-- a second check is performed in ./ScreenGameplay underlay/PerPlayer/TargetScore/default.lua
	-- to ensure it isn't accidentally brought into non-EventMode via player profile
	if not PREFSMAN:GetPreference("EventMode") then
		mods = mods:gsub("ActionOnMissedTarget,", "")
	end

	return mods
end

-- -----------------------------------------------------------------------
-- given a player, return a table of stepartist text for the current song or course
-- so that various screens (SSM, Eval) can cycle through these values and players
-- can see each for brief duration

GetStepsCredit = function(player)
	local t = {}

	if GAMESTATE:IsCourseMode() then
		local course = GAMESTATE:GetCurrentCourse()
		-- scripter
		if course:GetScripter() ~= "" then t[#t+1] = course:GetScripter() end
		-- description
		if course:GetDescription() ~= "" then t[#t+1] = course:GetDescription() end
	else
		local steps = GAMESTATE:GetCurrentSteps(player)
		-- credit
		if steps:GetAuthorCredit() ~= "" then t[#t+1] = steps:GetAuthorCredit() end
		-- description
		if steps:GetDescription() ~= "" then t[#t+1] = steps:GetDescription() end
		-- chart name
		if steps:GetChartName() ~= "" then t[#t+1] = steps:GetChartName() end
	end

	return t
end

-- -----------------------------------------------------------------------
BrighterOptionRows = function()
	if ThemePrefs.Get("RainbowMode") then return true end
	if PREFSMAN:GetPreference("EasterEggs") and MonthOfYear()==11 then return true end -- holiday cheer
	return false
end

-- -----------------------------------------------------------------------
-- account for the possibility that emojis shouldn't be diffused to Color.Black

DiffuseEmojis = function(bmt, text)
	-- loop through each char in the string, checking for emojis; if any are found
	-- don't diffuse that char to be any specific color by selectively diffusing it to be {1,1,1,1}
	for i=1, text:utf8len() do
		if text:utf8sub(i,i):byte() >= 240 then
			bmt:AddAttribute(i-1, { Length=1, Diffuse={1,1,1,1} } )
		end
	end
end

-- -----------------------------------------------------------------------
-- read the theme version from ThemeInfo.ini to display on ScreenTitleMenu underlay
-- this allows players to more easily identify what version of the theme they are currently using

GetThemeVersion = function()
	local file = IniFile.ReadFile( THEME:GetCurrentThemeDirectory() .. "ThemeInfo.ini" )
	if file then
		if file.ThemeInfo and file.ThemeInfo.Version then
			return file.ThemeInfo.Version
		end
	end
	return false
end

-- -----------------------------------------------------------------------
-- functions that attempt to handle the mess that is custom judgment graphic detection/loading

local function FilenameIsMultiFrameSprite(filename)
	-- look for the "[frames wide] x [frames tall]"
	-- and some sort of all-letters file extension
	-- Lua doesn't support an end-of-string regex marker...
	return string.match(filename, " %d+x%d+") and string.match(filename, "%.[A-Za-z]+")
end

function StripSpriteHints(filename)
	-- handle common cases here, gory details in /src/RageBitmapTexture.cpp
	return filename:gsub(" %d+x%d+", ""):gsub(" %(doubleres%)", ""):gsub(".png", "")
end

function GetJudgmentGraphics(mode)
	if mode == 'Casual' then mode = 'Competitive' end
	local path = THEME:GetPathG('', '_judgments/' .. mode)
	local files = FILEMAN:GetDirListing(path .. '/')
	local judgment_graphics = {}

	for k,filename in ipairs(files) do

		-- Filter out files that aren't judgment graphics
		-- e.g. hidden system files like .DS_Store
		if FilenameIsMultiFrameSprite(filename) then

			-- use regexp to get only the name of the graphic, stripping out the extension
			local name = StripSpriteHints(filename)

			-- Fill the table, special-casing Love so that it comes first.
			if name == "Love" then
				table.insert(judgment_graphics, 1, filename)
			else
				judgment_graphics[#judgment_graphics+1] = filename
			end
		end
	end

	-- "None" -> no graphic in Player judgment.lua
	judgment_graphics[#judgment_graphics+1] = "None"

	return judgment_graphics
end
