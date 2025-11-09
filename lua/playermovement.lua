Hooks:PostHook(PlayerMovement,"_setup_states","glorykills_registerstate",function(self)
	self._states.execution = PlayerStateExecution:new(self._unit)
end)


function PlayerMovement:anim_execution_generic(unit,a)
	Print("player anim_execution_generic",a)
end
function PlayerMovement:anim_execution_exit(unit,a)
	Print("player anim_execution_exit",a)
	
	if alive(GloryKills.unit) then
		GloryKills.unit:set_position(Vector3(0, 0, -10000))
	end
end


function PlayerMovement:anim_execution_slap(unit,a)
	Print("player anim_execution_slap",a)

end
function PlayerMovement:anim_execution_punchthroat(unit,a)
	Print("player anim_execution_punchthroat",a)

end
function PlayerMovement:anim_execution_grab(unit,a)
	Print("player anim_execution_grab",a)

end
function PlayerMovement:anim_execution_kill(unit,a)
	Print("player anim_execution_kill",a)

end