#!/bin/bash

toggle_state=$(/bin/launchctl getenv MTL_HUD_ENABLED)

if [[ $toggle_state -eq 0 ]]; then 
	toggle=1; 
else 
	toggle=0; 
fi

echo "Setting MTL_HUD_ENABLED to $toggle. (Was $toggle_state)"

/bin/launchctl setenv MTL_HUD_ENABLED $toggle
