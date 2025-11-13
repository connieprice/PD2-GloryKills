if _G.IS_VR then
	return
end

Hooks:PostHook(NetworkPeer,"set_unit","glorykills_networkpeer_setunit",function(self, unit, character_name, team_id, visual_seed)
	if unit and self == managers.network:session():local_peer() and Utils:IsInGameState() then
		GloryKills:spawn_third_unit(unit,character_name,visual_seed) --,self:profile().outfit_string)
	end
end)
