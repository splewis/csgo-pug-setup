# either add spcomp to your system path or add the full location to it here as SMC
SMC = spcomp
FLAGS = "-O2 -t4"

build: clean
	mkdir -p csgo/addons/sourcemod/plugins
	$(SMC) csgo/addons/sourcemod/scripting/pugsetup.sp ${FLAGS} -o=csgo/addons/sourcemod/plugins/pugsetup
	$(SMC) csgo/addons/sourcemod/scripting/pugsetup_teamnames.sp ${FLAGS} -o=csgo/addons/sourcemod/plugins/pugsetup_teamnames

clean:
	rm -rf *.smx *.zip

package: build
	zip -r pugsetup csgo README.md LICENSE
