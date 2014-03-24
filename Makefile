# either add spcomp to your system path or add the full location to it here as SMC
SMC = spcomp
FLAGS = "-O2 -t4"
SRC = csgo/addons/sourcemod/scripting/teamselect.sp
OUT = csgo/addons/sourcemod/plugins/teamselect
TRANS = csgo/addons/sourcemod/translations
BINARY = csgo/addons/sourcemod/plugins/teamselect.smx

build: clean
	mkdir -p csgo/addons/sourcemod/plugins
	$(SMC) ${SRC} ${FLAGS} -o=${OUT}

clean:
	rm -rf *.smx *.zip

package: build
	zip -r teamselect csgo
