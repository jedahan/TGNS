//NS2 EnhancedLogging and Tracking of events
	
if kDAKConfig and kDAKConfig.EnhancedLogging then

	Script.Load("lua/DAKLoader_Class.lua")

	local EnhancedLoggingFile = nil
	local lastlogupdate = 0
	local pendinglogsave = false
	local EnhancedLog = { }

	//*******************************************************************************************************************************
	//Formatting Functions
	//*******************************************************************************************************************************
	
	local function GetMonthDaysString(year, days)
		local MDays = { }
		table.insert(MDays, 31) //Jan
		table.insert(MDays, 28) //Feb
		table.insert(MDays, 31) //Mar
		table.insert(MDays, 30) //Apr
		table.insert(MDays, 31) //May
		table.insert(MDays, 30) //Jun
		table.insert(MDays, 31) //Jul
		table.insert(MDays, 31) //Aug
		table.insert(MDays, 30) //Sep
		table.insert(MDays, 31) //Oct
		table.insert(MDays, 30) //Nov
		table.insert(MDays, 31) //Dec
		local tdays = days
		local month = 1
		if math.mod((year - 1972), 4) == 0 then
			MDays[2] = 29
		end
		for i = 1, 12 do
			if tdays <= MDays[i] then
				return month, tdays
			else
				tdays = tdays - MDays[i]
			end
			month = month + 1
		end	
		return month, tdays
	end

	local function GetDateTimeString(logfile)
	
		local st = Shared.GetSystemTime()
		local DST = 0
		local TIMEZONE = 0
		if kDAKConfig.EnhancedLogging.kServerTimeZoneAdjustment then
			TIMEZONE = kDAKConfig.EnhancedLogging.kServerTimeZoneAdjustment
		end
		local Days = math.floor(st / 86400)
		st = st - (Days * 86400)
		local Month = 1
		local Year = math.floor(Days / 365)
		Days = Days - (Year * 365)
		Year = Year + 1970
		Days = Days - math.floor((Year - 1972) / 4) + 1
		Month, Day = GetMonthDaysString(Year, Days)
		if Month == 11 and Day <= 2 or Month < 11 and Month > 3 or Month == 3 and Day >= 10 then
			DST = 1		
		end
		local Hours = math.floor(st / 3600)
		st = st - (Hours * 3600)
		Hours = Hours + DST + TIMEZONE
		local Minutes = math.floor(st / 60)
		st = st - (Minutes * 60)
		local DateTime 
		if logfile then
			DateTime = string.format("%s-%s-%s - ", Month, Day, Year)
			if Hours < 10 then
				DateTime = DateTime .. string.format("0%s", Hours)
			else
				DateTime = DateTime .. string.format("%s", Hours)
			end
			if Minutes < 10 then
				DateTime = DateTime .. string.format("-0%s", Minutes)
			else
				DateTime = DateTime .. string.format("-%s", Minutes)
			end
			return DateTime
		end
		DateTime = string.format("%s/%s/%s - ", Month, Day, Year)
		if Hours < 10 then
			DateTime = DateTime .. string.format("0%s", Hours)
		else
			DateTime = DateTime .. string.format("%s", Hours)
		end
		if Minutes < 10 then
			DateTime = DateTime .. string.format(":0%s:", Minutes)
		else
			DateTime = DateTime .. string.format(":%s:", Minutes)
		end
		if st < 10 then
			DateTime = DateTime .. string.format("0%s", st)
		else
			DateTime = DateTime .. string.format("%s", st)
		end
		return DateTime
		
	end
	
	local function GetTimeStamp()
		return string.format("L " .. string.format(GetDateTimeString(false)) .. " - ")
	end
		
	//*******************************************************************************************************************************
	//PlayerID Functions
	//*******************************************************************************************************************************
	
	local function GetPlayerList()

		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		table.sort(playerList, function(p1, p2) return p1:GetName() < p2:GetName() end)
		return playerList
		
	end

	/**
	 * Iterates over all players sorted in alphabetically calling the passed in function.
	 */
	local function AllPlayers(doThis)

		return function(client)
		
			local playerList = GetPlayerList()
			for p = 1, #playerList do
			
				local player = playerList[p]
				doThis(player, client, p)
				
			end
			
		end
		
	end

	local function GetPlayerMatchingSteamId(steamId)

		assert(type(steamId) == "number")
		
		local match = nil
		
		local function Matches(player)
		
			local playerClient = Server.GetOwner(player)
			if playerClient:GetUserId() == steamId then
				match = player
			end
			
		end
		AllPlayers(Matches)()
		
		return match
		
	end

	local function GetPlayerMatchingName(name)

		assert(type(name) == "string")
		
		local match = nil
		
		local function Matches(player)
		
			if player:GetName() == name then
				match = player
			end
			
		end
		AllPlayers(Matches)()
		
		return match
		
	end

	local function GetPlayerMatching(id)

		local idNum = tonumber(id)
		if idNum then
			return GetPlayerMatchingGameId(idNum) or GetPlayerMatchingSteamId(idNum)
		elseif type(id) == "string" then
			return GetPlayerMatchingName(id)
		end
		
	end
	
	//*******************************************************************************************************************************
	//Log Formatting Functions
	//*******************************************************************************************************************************
	
	local function GetClientUIDString(client)
	
		if client ~= nil then
			local player = client:GetControllingPlayer()
			local name = "N/A"
			local teamnumber = 0
			if player ~= nil then
				name = player:GetName()
				teamnumber = player:GetTeamNumber()
			end
			return string.format("<%s><%s><%s><%s>", name, ToString(GetGameIdMatchingClient(client)), client:GetUserId(), teamnumber)
		end
		return ""
		
	end
	
	local function GetClientIPAddress(client)
	
		if client ~= nil then
			return string.format(" address %s", IPAddressToString(Server.GetClientAddress(client)))
		end
		return ""
	end
	
	local function GetFormattedPositions(attackerOrigin, targetOrigin)
		
		if attackerOrigin ~= nil and targetOrigin ~= nil then
			local attackerx = string.format("%.3f", attackerOrigin.x)
			local attackery = string.format("%.3f", attackerOrigin.y)
			local attackerz = string.format("%.3f", attackerOrigin.z)
			local targetx = string.format("%.3f", targetOrigin.x)
			local targety = string.format("%.3f", targetOrigin.y)
			local targetz = string.format("%.3f", targetOrigin.z)
			return string.format("(attacker_position %f %f %f) (victim_position %f %f %f)", attackerx, attackery, attackerz, targetx, targety, targetz)
			
		end
		
		return ""
	end
	
		
	//*******************************************************************************************************************************
	//Logging Functions
	//*******************************************************************************************************************************
	
	local function SaveEnhancedLog()

		local ELogFile = assert(io.open("config://" .. kDAKConfig.EnhancedLogging.kEnhancedLoggingSubDir .. "\\" .. EnhancedLoggingFile, "w"))
		if ELogFile then
			for i = 1, #EnhancedLog do
				ELogFile:write(EnhancedLog[i] .. "\n")
			end
			ELogFile:close()
		end		
		lastlogupdate = Shared.GetTime()
		pendinglogsave = false
		
	end
	
	local function PrintToEnhancedLog(logstring)

		if EnhancedLoggingFile == nil and Shared.GetMapName() ~= "" then
			EnhancedLoggingFile = string.format("%s - %s.txt", GetDateTimeString(true), tostring(Shared.GetMapName()))
		end
		table.insert(EnhancedLog, logstring)
		if EnhancedLoggingFile == nil then
			return
		end
		if lastlogupdate + kDAKConfig.EnhancedLogging.kLogWriteDelay < Shared.GetTime() then
			SaveEnhancedLog()
		else
			pendinglogsave = true
		end
		
		//Append doesnt crash atleast now, still doesnt work tho which is prettty meh.
		/*local ELogFile = io.open("config://" .. kDAKConfig.EnhancedLogging.kEnhancedLoggingSubDir .. "\\" .. EnhancedLoggingFile, "a+")
		if ELogFile then
			ELogFile:seek("end")
			ELogFile:write(logstring .. "\n")
			ELogFile:close()
		else
			local ELogFile = io.open("config://" .. kDAKConfig.EnhancedLogging.kEnhancedLoggingSubDir .. "\\" .. EnhancedLoggingFile, "w")
			if ELogFile then
				ELogFile:write(logstring .. "\n")
				ELogFile:close()
			end
		end*/
	
	end
	
	function EnhancedLogMessage(message)
		PrintToEnhancedLog(GetTimeStamp() .. message)
	end

	function EnhancedLoggingAllAdmins(commandname, client, parm1)
	
		local playerRecords = Shared.GetEntitiesWithClassname("Player")
		local message
		if client ~= nil then
			message = GetTimeStamp() .. GetClientUIDString(client) .. " executed " .. commandname
		else
			message = GetTimeStamp() .. "ServerConsole" .. " executed " .. commandname
		end
		if parm1 ~= nil then
			message = message .. " " .. parm1
		end
		for _, player in ientitylist(playerRecords) do
		
			local playerClient = Server.GetOwner(player)
			if playerClient ~= nil then
				if playerClient ~= client and DAKGetClientCanRunCommand(playerClient, commandname) then
					ServerAdminPrint(playerClient, message)
				end
			end
		
		end
		PrintToEnhancedLog(message)
		Shared.Message(string.format(message))
	end
	
	local function OnCommandSVSwitchTeam(client, playerId, team)
		if playerId ~= nil and team ~= nil then 
			local switchedplayer = GetPlayerMatching(playerId)
			local switchedclient = Server.GetOwner(switchedplayer)
			if switchedclient ~= nil then
				PrintToAllAdmins("sv_switchteam", client, string.format(" on %s to team %s.", GetClientUIDString(switchedclient), team))
			end
		end
	end
	
	local function OnCommandSVKick(client, playerId)
		if playerId ~= nil then 
			local kickedplayer = GetPlayerMatching(playerId)
			local kickedclient = Server.GetOwner(kickedplayer)
			if kickedclient ~= nil then
				PrintToAllAdmins("sv_kick", client, string.format(" on %s.", GetClientUIDString(kickedclient)))
			end
		end
	end
	
	local function OnCommandSVSlay(client, playerId)
		if playerId ~= nil then 
			local slayedplayer = GetPlayerMatching(playerId)
			local slayedclient = Server.GetOwner(slayedplayer)
			if slayedclient ~= nil then
				PrintToAllAdmins("sv_slay", client, string.format(" on %s.", GetClientUIDString(slayedclient)))
			end
		end
	end
	
	local function OnCommandSVBan(client, playerId, duration, ...)
	
		if playerId ~= nil then
			if duration == nil then duration = 0 end
			local bannedplayer = GetPlayerMatching(playerId)
			local bannedclient = Server.GetOwner(bannedplayer)
			if bannedclient ~= nil then
				PrintToAllAdmins("sv_ban", client, string.format(" on %s for %s for %s.", GetClientUIDString(bannedclient), duration, StringConcatArgs(...)))
			elseif tonumber(playerId) > 0 then
				PrintToAllAdmins("sv_ban", client, string.format(" on SteamID:%s for %s for %s.", playerId, duration, StringConcatArgs(...)))
			end
		end
	end
	
	local function OnCommandSVUnBan(client, playerId)
		if playerId ~= nil then
			local unbannedplayer = GetPlayerMatching(playerId)
			local unbannedclient = Server.GetOwner(unbannedplayer)
			if unbannedclient ~= nil then
				PrintToAllAdmins("sv_unban", client, string.format(" on %s.", GetClientUIDString(unbannedclient)))
			elseif playerId > 0 then
				PrintToAllAdmins("sv_unban", client, string.format(" on SteamID:%s.", playerId))
			end
		end
	end
	
	Event.Hook("Console_sv_switchteam",               OnCommandSVSwitchTeam)
	Event.Hook("Console_sv_kick",               OnCommandSVKick)
	Event.Hook("Console_sv_slay",               OnCommandSVSlay)
	Event.Hook("Console_sv_ban",               OnCommandSVBan)
	Event.Hook("Console_sv_unban",               OnCommandSVUnBan)

	local function LogOnClientConnect(client)
	
		if client ~= nil then
			//Shared.Message( GetTimeStamp() .. GetClientUIDString(client) .. " connected," .. GetClientIPAddress(client))
			PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(client) .. " connected," .. GetClientIPAddress(client))
			return true
		else
			return false
		end
		
	end

	table.insert(kDAKOnClientDelayedConnect, function(client) return LogOnClientConnect(client) end)
	
	local function LogOnClientDisconnect(client)
		local reason = ""
		if client ~= nil then
			if client.disconnectreason ~= nil then
				reason = client.disconnectreason
			end
			//Shared.Message(GetTimeStamp() .. GetClientUIDString(client) .. " disconnected, " .. reason)
			PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(client) .. " disconnected, " .. reason)
			return true
		else
			return false
		end
		
	end

	table.insert(kDAKOnClientDisconnect, function(client) return LogOnClientDisconnect(client) end)
	
	local function UpdateServerEnhancedLogging()
		if pendinglogsave then
			if lastlogupdate + kDAKConfig.EnhancedLogging.kLogWriteDelay < Shared.GetTime() then
				SaveEnhancedLog()
			end
		end
	end

	DAKRegisterEventHook(kDAKOnServerUpdate, function(deltatime) return UpdateServerEnhancedLogging() end, 5)
	
	function OnCommandSetName(client, name)

		if client ~= nil and name ~= nil then

			local player = client:GetControllingPlayer()

			name = TrimName(name)

			if name ~= player:GetName() and name ~= kDefaultPlayerName and string.len(name) > 0 then
			
				PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(client) .. " changed name to " .. name .. ".")
				
			    local prevName = player:GetName()
				player:SetName(name)
				if prevName == kDefaultPlayerName then
					Server.Broadcast(nil, string.format("%s connected.", player:GetName()))
				elseif prevName ~= player:GetName() then
					Server.Broadcast(nil, string.format("%s is now known as %s.", prevName, player:GetName()))
				end
				
			end
		
		end
    
	end
	
	Event.Hook("Console_name",               OnCommandSetName)
		
	if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.GamerulesExtensions then
			
		local originalNS2CommandStructureLoginPlayer
		
		originalNS2CommandStructureLoginPlayer = Class_ReplaceMethod("CommandStructure", "LoginPlayer", 
			function(self, player)
			
				if player then
					local Client = Server.GetOwner(player)
					local teamNum = self:GetTeamNumber()
					if Client and teamNum then
						PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " logged into commander for team " .. ToString(teamNum))
					end
				end
				originalNS2CommandStructureLoginPlayer( self, player )
			end
		)
		
		local originalNS2CommandStructureLogout
		
		originalNS2CommandStructureLogout = Class_ReplaceMethod("CommandStructure", "Logout", 
			function(self)
			
				local commander = self:GetCommander()
				if commander then
					local Client = Server.GetOwner(commander)
					local teamNum = self:GetTeamNumber()
					if Client and teamNum then
						PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " logged out of commander for team " .. ToString(teamNum))
					end
				end
				originalNS2CommandStructureLogout( self )
			end
		)
		
		local originalNS2RecycleMixinOnResearchComplete
		
		originalNS2RecycleMixinOnResearchComplete = Class_ReplaceMethod("RecycleMixin", "OnResearchComplete", 
			function(self, researchId)
			
				local buildingID = self:GetId()
				local buildingname = self:GetClassName()
				if researchId == kTechId.Recycle then        
					PrintToEnhancedLog(GetTimeStamp() .. buildingname .. " id: " .. ToString(buildingID) .. " was recycled.")
				end
				originalNS2RecycleMixinOnResearchComplete( self, researchId )
			end
		)
		
		local originalNS2RecycleMixinOnResearch
		
		originalNS2RecycleMixinOnResearch = Class_ReplaceMethod("RecycleMixin", "OnResearch", 
			function(self, researchId)
			
				local buildingID = self:GetId()
				local buildingname = self:GetClassName()
				local team = self:GetTeam()
				if team then
					local commander = team:GetCommander()
					if commander then
						local Client = Server.GetOwner(commander)
						if researchId == kTechId.Recycle and Client then        
							PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " started recycle of " .. buildingname .. " id: " .. ToString(buildingID))
						end
					end
				end
				originalNS2RecycleMixinOnResearch( self, researchId )
			end
		)
		
		local originalNS2ConstructMixinOnInitialized
		
		originalNS2ConstructMixinOnInitialized = Class_ReplaceMethod("ConstructMixin", "OnInitialized", 
			function(self)
			
				local buildingID = self:GetId()
				local buildingname = self:GetClassName()
				local team = self:GetTeam()
				if team then
					local owner = self:GetOwner()
					if owner == nil then
						owner = team:GetCommander()
					end
					if owner then
						local Client = Server.GetOwner(owner)
						if researchId == kTechId.Recycle and Client then        
							PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " started construction of " .. buildingname .. " id: " .. ToString(buildingID))
						end
					end
				end
				originalNS2ConstructMixinOnInitialized( self )
			end
		)
		
	end
	
	function EnhancedLoggingChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)
		if client and steamId and steamId ~= 0 then
			PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(client) .. ConditionalValue(teamOnly, " teamsay ", " say ") .. message)
		else
			PrintToEnhancedLog(GetTimeStamp() .. playerName .. ConditionalValue(teamOnly, " teamsay ", " say ")  .. message)
		end
	end
	
	table.insert(kDAKOnClientChatMessage, function(message, playerName, steamId, teamNumber, teamOnly, client) return EnhancedLoggingChatMessage(message, playerName, steamId, teamNumber, teamOnly, client) end)
	
	local function EnhancedLoggingSetGameState(self, state, currentstate)

		if state ~= currentstate then
			if state == kGameState.Started then
				local version = ToString(Shared.GetBuildNumber())
				local map = Shared.GetMapName()
				PrintToEnhancedLog(GetTimeStamp() .. "game_started" .. " build " .. version .. " map " .. map)
			end
		end
		
	end
			
	table.insert(kDAKOnSetGameState, function(self, state, currentstate) return EnhancedLoggingSetGameState(self, state, currentstate) end)
	
	function EnhancedLoggingJoinTeam(player, newTeamNumber, force)
		local client = Server.GetOwner(player)
		if client ~= nil then
			PrintToEnhancedLog(GetTimeStamp() .. string.format("%s joined team %s.", GetClientUIDString(client), newTeamNumber))
		end
		return true
	end
	
	table.insert(kDAKOnTeamJoin, function(player, newTeamNumber, force) return EnhancedLoggingJoinTeam(player, newTeamNumber, force) end)
	
	function EnhancedLoggingEndGame(winningTeam)
	
		local gamerules = GetGamerules()
		if gamerules then
			local version = ToString(Shared.GetBuildNumber())
			local winner = ToString(winningTeam:GetTeamType())
			local length = string.format("%.2f", Shared.GetTime() - gamerules.gameStartTime)
			local map = Shared.GetMapName()
			local start_location1 = gamerules.startingLocationNameTeam1
			local start_location2 = gamerules.startingLocationNameTeam2
			PrintToEnhancedLog(GetTimeStamp() .. "game_ended" .. " build " .. version .. " winning_team " .. winner .. " game_length " .. length .. 
				" map " .. map .. " marine_start_loc " .. start_location1 .. " alien_start_loc " .. start_location2)
		end
		
	end
	
	table.insert(kDAKOnGameEnd, function(winningTeam) return EnhancedLoggingEndGame(winningTeam) end)

	function EnhancedLoggingCastVoteByPlayer(gamerules, voteTechId, player)
		if voteTechId == kTechId.VoteDownCommander1 or voteTechId == kTechId.VoteDownCommander2 or voteTechId == kTechId.VoteDownCommander3 then 
			local playerIndex = (voteTechId - kTechId.VoteDownCommander1 + 1)        
			local commanders = GetEntitiesForTeam("Commander", player:GetTeamNumber())
			
			if playerIndex <= table.count(commanders) then
				local targetCommander = commanders[playerIndex]
				if targetCommander ~= nil then
					local targetClient = Server.GetOwner(targetCommander)
					local Client = Server.GetOwner(targetClient)
					if targetClient and Client then
						PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " voted to eject " .. GetClientUIDString(targetClient))
					end
				end
			end
		end
		return true
	end
	
	table.insert(kDAKOnCastVoteByPlayer, function(self, voteTechId, player) return EnhancedLoggingCastVoteByPlayer(self, voteTechId, player) end)
	
	function EnhancedLoggingOnEntityKilled(targetEntity, attacker, doer, point, direction)
     
        if attacker and targetEntity and doer then
            local attackerOrigin = attacker:GetOrigin()
			local targetOrigin = targetEntity:GetOrigin()
			local attacker_client = Server.GetOwner(attacker)
			local target_client = Server.GetOwner(targetEntity)
			if target_client == nil and attacker_client == nil then
				PrintToEnhancedLog(GetTimeStamp() .. attacker:GetClassName() .. " killed " .. targetEntity:GetClassName() .. " with " .. doer:GetClassName() .. " at " .. GetFormattedPositions(attackerOrigin, targetOrigin))
			elseif target_client == nil then
				PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(attacker_client) .. " killed " .. targetEntity:GetClassName() .. " with " .. doer:GetClassName() .. " at " .. GetFormattedPositions(attackerOrigin, targetOrigin))
			elseif attacker_client == nil then
				PrintToEnhancedLog(GetTimeStamp() .. attacker:GetClassName() .. " killed " .. GetClientUIDString(target_client) .. " with " .. doer:GetClassName() .. " at " .. GetFormattedPositions(attackerOrigin, targetOrigin))
			else
				PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(attacker_client) .. " killed " .. GetClientUIDString(target_client) .. " with " .. doer:GetClassName() .. " at " .. GetFormattedPositions(attackerOrigin, targetOrigin))
			end
        end

    end
	
	table.insert(kDAKOnEntityKilled, function(targetEntity, attacker, doer, point, direction) return EnhancedLoggingOnEntityKilled(targetEntity, attacker, doer, point, direction) end)
	
end

Shared.Message("EnhancedLogging Loading Complete")