
-- these aren't being triggered from the anim, idk why
function HuskPlayerMovement:anim_execution_slap(...)

end
function HuskPlayerMovement:anim_execution_punch(...)

end
function HuskPlayerMovement:anim_execution_grab(...)

end
function HuskPlayerMovement:anim_execution_generic(s)
--	Print("Animation callback:",s)
end

function HuskPlayerMovement:anim_execution_kill(...)
end

function HuskPlayerMovement:anim_start_execution(...)
--	Print("HuskPlayerMovement:anim_start_execution()")
end

function HuskPlayerMovement:anim_stop_execution(...)
--	Print("HuskPlayerMovement:anim_stop_execution()")
	local player = managers.player:local_player()
	local mov_ext = alive(player) and player:movement()
	local state = mov_ext and mov_ext:current_state()
	if state then 
		if state.on_execution_complete then
			state:on_execution_complete()
		end
	end
end

--]]