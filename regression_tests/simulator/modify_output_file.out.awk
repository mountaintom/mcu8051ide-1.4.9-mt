#! /usr/bin/gawk -f

# --------------------------------------------------------------------------
# Auxiliary script for regression tests environment
#
# Modify ouput files from simulator, file extension is `.out'
# --------------------------------------------------------------------------

# Ignore sim. engine version
/^MCU8051IDE SIM-ENGINE/ {
	$0="MCU8051IDE SIM-ENGINE"
}


# Just copy input to output
{
	print($0)
}
