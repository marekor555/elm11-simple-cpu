all: synth flash

synth: 
	LD_LIBRARY_PATH=/home/marekor/Applications/gowin/IDE/lib gw_sh build.tcl
flash:
	LD_LIBRARY_PATH=/home/marekor/Applications/gowin/IDE/lib programmer_cli --device GW1NR-9C --operation_index 5 --fs build/impl/pnr/build.fs

fix:
	pkexec modprobe -r ftdi_sio