local mvec_1 = Vector3()
Hooks:PostHook(PlayerCamera, "set_position", "glorykills_set_position", function (self, pos)
	local player = managers.player:local_player()
	if alive(player) then
		local mov_ext = player:movement()
		local state_name = mov_ext and mov_ext:current_state_name()
		if state_name == "execution" then
			if alive(GloryKills.unit) then
				local obj = GloryKills.unit:get_object(Idstring("eyeAim"))
				mvector3.set(mvec_1,obj:position())
				self._camera_controller:set_camera(mvec_1)
			end
		end
	end
end)

--[[
Hooks:PostHook(PlayerCamera, "set_rotation", "glorykills_set_rotation", function (self, rot)
	local player = managers.player:local_player()
	if alive(player) then
		local mov_ext = player:movement()
		local state_name = mov_ext and mov_ext:current_state_name()
		if state_name == "execution" then
			if alive(GloryKills.unit) then
				local obj = GloryKills.unit:get_object(Idstring("eyeAim"))
				self._camera_controller:set_camera(obj:rotation())
			end
		end
	end
end)
--]]