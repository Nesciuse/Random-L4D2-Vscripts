function OnPostSpawn() {
	self.ConnectOutput("OnStartTouch", "AddToHillMovementThinker");
	self.ConnectOutput("OnEndTouch", "RemoveFromHillMovementThinker");
	self.__KeyValueFromInt("allowincap", 1);
	self.__KeyValueFromInt("spawnflags", 1);

	local hill_top_target = NetProps.GetPropString(self, "m_target");
	if(hill_top_target == "") {
		error("No hill top specified!");
		self.Kill();
		return;
	}
	local hill_top_ent;
	for(local ent; ent = Entities.FindByName(ent, hill_top_target);) {
		if(hill_top_ent) {
			error("Multiple entities found with targetname " + hill_top_target + "\nThere should be only one hill top");
			self.Kill();
			return;
		}
		hill_top_ent = ent;
	}
	if(hill_top_ent == null) {
		error("No hill top found");
		self.Kill();
		return;
	}
	hill_top <- hill_top_ent.GetOrigin();
	players_on_hill <- [];
	ensure_removal <- [];
	think_delay_default <- 0.1;
	think_delay <- 9999;
}

function AddToHillMovementThinker() {
    if(activator && activator.IsValid() && players_on_hill.find(activator) == null) {
        //printl("ADDING " + activator);
        players_on_hill.append(activator.weakref());
		if(think_delay > think_delay_default) {
			think_delay = think_delay_default;
			AddThinkToEnt(self, "HillMovementThinker");
		}
    }
}

function RemoveFromHillMovementThinker() {
    if(activator && activator.IsValid()) {
        local i = players_on_hill.find(activator);
        if(i == null || self.IsTouching(activator)) {
            return;
        }
        //printl("REMOVING " + activator);
        ensure_removal.append(activator);
        players_on_hill.remove(i);
    }
}

local array_cleanup_needed = false;
function HillMovementThinker() {

	if(players_on_hill.len() == 0) {
		think_delay += 3;
	}
    foreach(player in players_on_hill) {
        if(player == null || !player.IsValid()) {
            printl(player + " invalid ");
            array_cleanup_needed = true;
            continue;
        }
		if((player.GetButtonMask() & (4|131072)) || NetProps.GetPropInt(player, "m_Local.m_bDucked") ) {
            NetProps.SetPropFloat(player, "m_flConstraintSpeedFactor", 1);
            continue;
        }
        local pos = player.EyePosition();
        local dir = hill_top - pos;
        dir.Norm();
        local health = player.GetHealth() + player.GetHealthBuffer();
        local origin, maxspeed = NetProps.GetPropFloat(player, "m_flMaxspeed");
        if(maxspeed > 200) {
            origin = pos - dir*50492;
        }
        else if(maxspeed == 150) {
            origin = pos - dir*44484;
        }
        else {
            origin = pos - dir*30000;
        }
        NetProps.SetPropVector(player, "m_vecConstraintCenter", origin);
        NetProps.SetPropFloat(player, "m_flConstraintRadius", 60000);
        NetProps.SetPropFloat(player, "m_flConstraintWidth", 30000);
        NetProps.SetPropFloat(player, "m_flConstraintSpeedFactor", 0.1);
    }
    if(array_cleanup_needed) {
        players_on_hill = players_on_hill.filter(@(i,player) (player && player.IsValid()) );
        array_cleanup_needed = false;
    }
    foreach(player in ensure_removal) {
        NetProps.SetPropVector(player, "m_vecConstraintCenter", Vector());
        NetProps.SetPropFloat(player, "m_flConstraintRadius", 0);
        NetProps.SetPropFloat(player, "m_flConstraintWidth", 0);
        NetProps.SetPropFloat(player, "m_flConstraintSpeedFactor", 0);
    }
    ensure_removal.clear();
    return think_delay;
}
