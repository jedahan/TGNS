// NotifyAdminOnMutePlayer

if kDAKConfig and kDAKConfig.NotifyAdminOnMutePlayer and kDAKConfig.DAKLoader then

	local function GetPlayerList()

		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		table.sort(playerList, function(p1, p2) return p1:GetName() < p2:GetName() end)
		return playerList
		
	end

	local function PMAllPlayersWithAccess(srcClient, message, command, showCommand)
		if srcClient then
			local srcPlayer = srcClient:GetControllingPlayer()
			if srcPlayer then
				srcName = srcPlayer:GetName()
			else
				srcName = kDAKConfig.DAKLoader.MessageSender
			end
		else
			srcName = kDAKConfig.DAKLoader.MessageSender
		end

		if showCommand then
			chatName =  command .. " - " .. srcName
		else
			chatName = srcName
		end

		consoleChatMessage = chatName ..": " .. message

		for _, player in pairs(GetPlayerList()) do
			local client = Server.GetOwner(player)
			if client ~= nil and DAKGetClientCanRunCommand(client, command) then
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, chatName, -1, kTeamReadyRoom, kNeutralTeamType, message), true)
				ServerAdminPrint(client, consoleChatMessage)
			end
		end
	end

	
	local originalOnMutePlayer
	
	local function OnMutePlayer(client, message)
		originalOnMutePlayer(client, message)
		clientIndex, isMuted = ParseMutePlayerMessage(message)
		for _, player in pairs(GetPlayerList()) do
			if player:GetClientIndex() == clientIndex then
				if isMuted then
					muteText = "muted"
				else
					muteText = "unmuted"
				end
				PMAllPlayersWithAccess(nil, client:GetControllingPlayer():GetName() .. " has " .. muteText .. " player " .. player:GetName(), "sv_canseemuted", false)
				break
			end
		end
	end

	// trying this without using Class_ReplaceMethod
	local originalHookNetworkMessage = Server.HookNetworkMessage
	
	Server.HookNetworkMessage = function(networkMessage, callback)
		if networkMessage == "MutePlayer" then
			originalOnMutePlayer = callback
			callback = OnMutePlayer
		end
		originalHookNetworkMessage(networkMessage, callback)

	end
	
	local function ListMutes(client)
		// build look up table for player names by clientindex
		playerNames = {}
		
		ServerAdminPrint(client, "Player Mutes:")
		for _, player in pairs(GetPlayerList()) do
			playerNames[player:GetClientIndex()] = player:GetName()
		end
		for _, player in pairs(GetPlayerList()) do
			for clientIndex, name in pairs(playerNames) do
				if player:GetClientMuted(clientIndex) then
					ServerAdminPrint(client, player:GetName() .. " : " .. name)
				end
			end
		end
	end
	
	DAKCreateServerAdminCommand("Console_sv_mutes", ListMutes, help)

/* 
	local originalHookNetworkMessage

	originalHookNetworkMessage = Class_ReplaceMethod("Server", "HookNetworkMessage", 
		function(networkMessage, callback)

			if networkMessage == "MutePlayer" then
				originalOnMutePlayer = callback
				callback = OnMutePlayer
			end
			originalHookNetworkMessage(networkMessage, callback)

		end
	)
*/
end

Shared.Message("NotifyAdminOnMutePlayer Loading Complete")