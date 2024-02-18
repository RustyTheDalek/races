INSTALLATION
------------

Create a **`races/`** folder under your server **`resources/`** folder.  Place **`fxmanifest.lua`**, **`races_client.lua`**, **`races_server.lua`**, **`port.lua`**, **`raceData.json`** and **`vehicles.txt`** in the **`resources/races/`** folder.  Create an **`html/`** folder under your server **`resources/races/`** folder.  Place **`index.css`**, **`index.html`**, **`index.js`** and **`reset.css`** in the **`resources/races/html/`** folder.  Add **`ensure races`** to your **`server.cfg`** file.

CLIENT COMMANDS
---------------
Required arguments are in square brackets.  Optional arguments are in parentheses.\
**`/races`** - display list of available **`/races`** commands\
**`/races edit`** - toggle editing track waypoints\
**`/races clear`** - clear track waypoints\
**`/races reverse`** - reverse order of track waypoints

For the following **`/races`** commands, [access] = {'pvt', 'pub'} where 'pvt' operates on a private track and 'pub' operates on a public track\
**`/races load [access] [name]`** - load private or public track saved as [name]\
**`/races save [access] [name]`** - save new private or public track as [name]\
**`/races overwrite [access] [name]`** - overwrite existing private or public track saved as [name]\
**`/races delete [access] [name]`** - delete private or public track saved as [name]\
**`/races blt [access] [name]`** - list 10 best lap times of private or public track saved as [name]\
**`/races list [access]`** - list saved private or public tracks

For the following **`/races register`** commands, (tier) defaults to none, (specialClass) defaults to none, (laps) defaults to 1 lap and (DNF timeout) defaults to 120 seconds\
**`/races register (tier) (specialClass) (laps) (DNF timeout)`** - register your race with no vehicle restrictions\
**`/races register (tier) (specialClass) (laps) (DNF timeout) rest [vehicle]`** - register your race restricted to [vehicle]\
**`/races register (tier) (specialClass) (laps) (DNF timeout) class [class]`** - register your race restricted to vehicles of type [class]; if [class] is '-1' then use custom vehicle list\
**`/races register (tier) (specialClass) (laps) (DNF timeout) rand (class) (vehicle)`** - register your race changing vehicles randomly every lap; (class) defaults to any; (vehicle) defaults to any

**`/races unregister`** - unregister your race\
**`/races start (delay)`** - start your registered race; (delay) defaults to 30 seconds

**`/races vl add [vehicle]`** - add [vehicle] to vehicle list\
**`/races vl delete [vehicle]`** - delete [vehicle] from vehicle list\
**`/races vl addClass [class]`** - add all vehicles of type [class] to vehicle list\
**`/races vl deleteClass [class]`** - delete all vehicles of type [class] from vehicle list\
**`/races vl addAll`** - add all vehicles to vehicle list\
**`/races vl deleteAll`** - delete all vehicles from vehicle list\
**`/races vl list`** - list all vehicles in vehicle list

For the following **`/races vl`** commands, [access] = {'pvt', 'pub'} where 'pvt' operates on a private vehicle list and 'pub' operates on a public vehicle list\
**`/races vl loadLst [access] [name]`** - load private or public vehicle list saved as [name]\
**`/races vl saveLst [access] [name]`** - save new private or public vehicle list as [name]\
**`/races vl overwriteLst [access] [name]`** - overwrite existing private or public vehicle list saved as [name]\
**`/races vl deleteLst [access] [name]`** - delete private or public vehicle list saved as [name]\
**`/races vl listLsts [access]`** - list saved private or public vehicle lists

**`/races leave`** - leave a race that you joined\
**`/races rivals`** - list competitors in a race that you joined\
**`/races respawn`** - respawn at last waypoint\
**`/races results`** - view latest race results\
**`/races spawn (vehicle)`** - spawn a vehicle; (vehicle) defaults to 'adder'\
**`/races lvehicles (class)`** - list available vehicles of type (class); otherwise list all available vehicles if (class) is not specified\
**`/races speedo (unit)`** - change unit of speed measurement to (unit) = {imperial, metric}; otherwise toggle display of speedometer if (unit) is not specified\
**`/races panel (panel)`** - display (panel) = {edit, register, list} panel; otherwise display main panel if (panel) is not specified

**IF YOU DO NOT WANT TO TYPE CHAT COMMANDS, YOU CAN BRING UP A CLICKABLE INTERFACE BY TYPING `'/races panel'`, `'/races panel edit'`, `'/races panel register'`, OR `'/races panel list'`.**

SERVER COMMANDS
---------------
Required arguments are in square brackets.  Optional arguments are in parentheses.\
**`races`** - display list of available **`races`** commands\
**`races export [name]`** - export public track saved as [name] without best lap times to file named **`[name].json`**\
**`races import [name]`** - import track file named **`[name].json`** into public tracks without best lap times\
**`races exportwblt [name]`** - export public track saved as [name] with best lap times to file named **`[name].json`**\
**`races importwblt [name]`** - import track file named **`[name].json`** into public tracks with best lap times

**IF YOU WANT TO PRESERVE TRACKS FROM A PREVIOUS VERSION OF THESE SCRIPTS, YOU SHOULD UPDATE `raceData.json` AND ANY EXPORTED TRACKS BY EXECUTING THE FOLLOWING COMMANDS BEFORE CLIENTS CONNECT TO THE SERVER TO USE THE NEW TRACK DATA FORMAT WHICH INCLUDES WAYPOINT RADIUS SIZES.**

**`races updateRaceData`** - update **`raceData.json`** to new format\
**`races updateTrack [name]`** - update exported track **`[name].json`** to new format

SAMPLE TRACKS
-------------
There are six sample tracks:  '00', '01', '02', '03', '04' and '05' saved in the public tracks list.  You can load sample track '00' by typing **`/races load pub 00`**.  To use the loaded track in a race, you need to register the race by typing **`/races register`**.  Go to the registration waypoint of the race indicated by a purple circled star blip on the waypoint map and a purple cylinder checkpoint in the world.  When prompted to join, type 'E' or press right DPAD to join.  Wait for other people to join if you want, then type **`/races start`**.

There are backups of the sample tracks in the **`sampletracks/`** folder with the extension '.json'.  Track '00' is backed up as **`sampletracks/00.json`**.  If any of the sample tracks were deleted from the public list of tracks, you can restore them.  Copy the deleted track from the **`sampletracks/`** folder to the **`resources/races/`** folder.  In the server console, type **`races import 00`** to import track '00' back into the public tracks list.

QUICK GUIDE FOR RACE CREATORS
-----------------------------
Type **`/races edit`** until you see the message **`Editing started`**.  Add at least 2 waypoints on the waypoint map or in the world by pressing 'Enter' on a keyboard, 'A' button on an Xbox controller or 'Cross' button on a DualShock controller.  Type **`/races edit`** again until you see the message **`Editing stopped`**.  Save the track if you want by typing **`/races save pvt mytrack`**.  Register your race by typing **`/races register`**.  At the starting waypoint of the track, a purple circled star blip will appear on the waypoint map and a purple cylinder checkpoint will appear in the world.  This is the registration waypoint which all players will see.  Players who want to join, maybe including yourself, need to move towards the registration waypoint until prompted to join.  Once prompted to join, type 'E' or press right DPAD to join.  Once other people have joined, you can start the race by typing **`/races start`**.

QUICK GUIDE FOR RACING
----------------------
There are seven possible types of race you can join:  1. Any vehicle can be used, 2. Restricted to a specific vehicle, 3. Restricted to a specific vehicle class, 4. Vehicles change randomly every lap, 5. Vehicles change randomly every lap and racers start in a specified vehicle, 6. Vehicles change randomly every lap to one in a specific class, 7. Vehicles change randomly every lap to one in a specific class and racers start in a specified vehicle.

Look for purple circled star blips on the waypoint map.  There will be corresponding purple cylinder checkpoints in the world.  The label for the blip in the waypoint map will indicate the player who registered the race, the car tier and the type of race.

If the race is restricted to a specific vehicle, the label will include **'using [vehicle]'** where [vehicle] is the name of the restricted vehicle.  You must be in that vehicle when prompted to join the race.  If permission to spawn vehicles is given or not required, you can spawn the restricted vehicle by typing **`/races spawn [vehicle]`** where [vehicle] is the restricted vehicle.  For example, if the label shows **using 'adder'**, you can spawn the vehicle by typing **`/races spawn adder`**.

If the race is restricted to a specific vehicle class, the label will include **'using [class] vehicle class'** where [class] is the vehicle class.  The class number will be in parentheses.  You must be in a vehicle of that class when prompted to join the race.  If the class is Custom (-1), you can view which vehicles are allowed in the race by getting out of any vehicle you are in, walking into the registration waypoint on foot and trying to join the race.  The chat window will list which vehicles you can use in the class Custom (-1) race.  If the class is not Custom (-1), you can list vehicles in the class by typing **`/races lvehicles [class]`** where [class] is the vehicle class number.

If the race changes vehicles randomly every lap, the label will include **'using random vehicles'**.  If a vehicle is specified after the **'using random vehicles'** message, racers will be placed in the specified vehicle when the race starts.

If the race changes vehicles randomly every lap to one of a specific class, the label will include **'using random [class] vehicle class'** where [class] is the vehicle class.  The class number will be in parentheses.  If a vehicle is specified after the **'using random [class] vehicle class'** message, racers will be placed in the specified vehicle when the race starts.

Move towards the registration waypoint until you are prompted to join.  Type 'E' or press right DPAD to join.  The player who registered the race will be the one who starts the race.  Once they start the race, your vehicle will be frozen until the start delay has expired and the race has officially begun.  Follow the checkpoints until the finish.  The results of the race will be broadcast to all racers who joined.  Prize money will be distributed to all finishers.  If you want to see the results again, type **`/races results`**.

CLIENT COMMAND DETAILS
----------------------
Type **`/races`** to see the list of available **`/races`** commands.  If you cannot see all the commands, type 'T' for chat and use the 'Page Up' and 'Page Down' keys to scroll.  Type 'Esc' when done.

**`/races edit`**\
**`/races reverse`**\
**`/races save [access] [name]`**\
**`/races overwrite [access] [name]`**\
**`/races delete [access] [name]`**

**`/races register (tier) (specialClass) (laps) (DNF timeout) `**\
**`/races register (tier) (specialClass) (laps) (DNF timeout) rest [vehicle]`**\
**`/races register (tier) (specialClass) (laps) (DNF timeout) class [class]`**\
**`/races register (tier) (specialClass) (laps) (DNF timeout) rand (class) (vehicle)`**\
**`/races unregister`**\
**`/races start (delay)`**\
**`/races vl add [vehicle]`**\
**`/races vl delete [vehicle]`**\
**`/races vl addClass [class]`**\
**`/races vl deleteClass [class]`**\
**`/races vl addAll`**\
**`/races vl deleteAll`**\
**`/races vl list`**\
**`/races vl loadLst [access] [name]`**\
**`/races vl saveLst [access] [name]`**\
**`/races vl overwriteLst [access] [name]`**\
**`/races vl deleteLst [access] [name]`**\
**`/races vl listLsts [access]`**

**`/races spawn (vehicle)`**

Type **`/races edit`** until you see the message **`Editing started`** to start editing waypoints.  Once you are finished, type **`/races edit`** until you see the message **`Editing stopped`** to stop editing.  You cannot edit waypoints if you are joined to a race.  Leave the race or finish it first.

There are four types of track waypoints and one type of registration waypoint.  Each track waypoint will have a corresponding blip on the waypoint map and, when editing, a corresponding checkpoint in the world.  A combined start/finish waypoint is a yellow checkered flag blip/checkpoint.  A start waypoint is a green checkered flag blip/checkpoint.  A finish waypoint is a white checkered flag blip/checkpoint.  A waypoint that is not a start and/or finish waypoint is a blue numbered blip/checkpoint.  A registration waypoint is a purple blip/checkpoint.  When you stop editing, all the checkpoints in the world, except for registration checkpoints, will disappear, but all the blips on the waypoint map will remain.

Clicking a point on the waypoint map is done by moving the point you want to click on the waypoint map under the crosshairs and pressing 'Enter' on a keyboard, 'A' button on an Xbox controller or 'Cross' button on a DualShock controller.  'Clicking' a point in the world is done by moving to the point you want to 'click' and pressing 'Enter' on a keyboard, 'A' button on an Xbox controller or 'Cross' button on a DualShock controller.

Selecting a waypoint is done by clicking on an existing waypoint.  The corresponding blip on the waypoint map and checkpoint in the world will turn red.  When selecting a waypoint in the world, you will be prompted to select the checkpoint once you are close enough.  Unselecting a waypoint is done by clicking on the waypoint again.  This will turn the waypoint color back to its original color.

To add a waypoint after the last waypoint, unselect any waypoints and click on an empty spot where you want to add the waypoint.  The first waypoint you add will be a yellow checkered flag blip/checkpoint.  The last added waypoint after the first will become a white checkered flag blip/checkpoint.  Adding waypoints after the first will change the first waypoint into a green checkered flag blip/checkpoint.  Waypoints between the first and last waypoints will become blue numbered blips/checkpoints.

If you want to add a waypoint between two consecutive waypoints, select the two waypoints first and then click on an empty spot where you want to add the waypoint.  The two waypoints you select must be consecutive waypoints.  You will not be able to select two non-consecutive waypoints.  After adding the waypoint, the two waypoints will become unselected.  You will not be able to add a waypoint between the first and last waypoints this way.  To add a waypoint between the first and last waypoints, unselect any waypoints and click on an empty spot where you want the waypoint.

**NOTE: The position number of a racer while in a race will be the most accurate if waypoints are added at every bend or corner in the track.**

You can delete a waypoint by making it the only selected waypoint, then pressing 'Spacebar' on a keyboard, 'X' button on an Xbox controller or 'Square' button on a DualShock controller.  Deleting a waypoint will delete the corresponding blip on the waypoint map and the corresponding checkpoint in the world.

You can move an existing waypoint by making it the only selected waypoint, then clicking an empty spot where you want to move it.  Moving a waypoint will move the corresponding blip on the waypoint map and the corresponding checkpoint in the world.

You can increase or decrease the radius of an existing waypoint in the world, but not in the waypoint map.  There are minimum and maximum radius limits to waypoints.  To increase the radius of the waypoint, select the waypoint, then press 'Up Arrow' on a keyboard or up DPAD.  To decrease the radius of the waypoint, select the waypoint, then press 'Down Arrow' on a keyboard or down DPAD.  When in a race, a player has passed a waypoint if they pass within the radius of the waypoint.  The waypoint will disappear and the next waypoint will appear.

For multi-lap races, the start and finish waypoint must be the same.  Select the finish waypoint first (white checkered flag), then select the start waypoint (green checkered flag).  The original start waypoint (green checkered flag) will become a yellow checkered flag.  This will be the start/finish waypoint.  The original finish waypoint (white checkered flag) will become a blue numbered waypoint.

You can separate the start/finish waypoint (yellow checkered flag) in one of two ways.  The first way is by unselecting any waypoints and adding a new waypoint.  The start/finish waypoint will become the start waypoint (green checkered flag).  The added waypoint will become the finish waypoint (white checkered flag).  The second way is by selecting the start/finish waypoint (yellow checkered flag) first, then selecting the highest numbered blue waypoint.  The start/finish waypoint will become the start waypoint (green checkered flag).  The highest numbered blue waypoint will become the finish waypoint (white checkered flag).

To reverse the order of waypoints, type **`/races reverse`**.  You can reverse waypoints if there are two or more waypoints.  You cannot reverse waypoints if you have joined a race. Leave the race or finish it first.

If you are editing waypoints and have not saved them as a track or you have loaded a saved track and modified any of its waypoints, the best lap times will not be saved if you register and start a race using the unsaved or modified track.  A modification to a saved track means adding, deleting, moving, increasing/decreasing radii, combining start/finish, separating start/finish or reversing waypoints.  Changes can only be undone by reloading the saved track.  If you have not saved your waypoints as a track or you loaded a saved track and modified any waypoints, you must save or overwrite the track to allow best lap times to be saved.  **NOTE THAT OVERWRITING A TRACK WILL DELETE ITS EXISTING BEST LAP TIMES.**

The commands **`/races save`**, **`/races overwrite`**, **`/races list`**, **`/races delete`**, **`/races load`** and **`/races blt`** operate on your private list of tracks if you specify **`pvt`** after the command or on the public list of tracks if you specify **`pub`** after the command.  Only you have access to your private list of tracks and can view and modify them.  All players have access to the public list of tracks and can view and modify them.

After you have set your waypoints, you can save them as a track.  Type **`/races save pvt mytrack`** to save the waypoints as **`mytrack`**.  **`mytrack`** must not exist.  You cannot save unless there are two or more waypoints in the track.  The best lap times for this track will be empty.  If you want to overwrite an existing track named **`mytrack`**, type **`/races overwrite pvt mytrack`**.  **NOTE THAT OVERWRITING A TRACK WILL DELETE ITS EXISTING BEST LAP TIMES.**

To list the tracks you have saved, type **`/races list pvt`**.  If you cannot see all the track names, type 'T' for chat and use the 'Page Up' and 'Page Down' keys to scroll.  Type 'Esc' when done.

If you want to delete a saved track named **`mytrack`**, type **`/races delete pvt mytrack`**.

To load the waypoints of a saved track named **`mytrack`**, type **`/races load pvt mytrack`**.  This will clear any current waypoints and load the waypoints from the saved track.  You cannot load a saved track if you have joined a race.  Leave the race or finish it first.

Type **`/races blt pvt mytrack`** to see the 10 best lap times recorded for **`mytrack`**.  Best lap times are recorded after a race has finished if the track was loaded, saved or overwritten without changing any waypoints before the race.  If you cannot see all the best lap times, type 'T' for chat and use the 'Page Up' and 'Page Down' keys to scroll.  Type 'Esc' when done.

Track waypoints and best lap times data is saved in the file **`resources/races/raceData.json`**.

You can clear all waypoints, except registration waypoints, by typing **`/races clear`**.  You cannot clear waypoints if you have joined a race. Leave the race or finish it first.

After you have set your track waypoints, you can register your race using the track.  This will advertise your race to all players.  Your track must have two or more waypoints.  At the starting waypoint of the track, a purple circled star blip will appear on the waypoint map and a purple cylinder checkpoint will appear in the world.  This will be the registration waypoint.  It will be visible to all players.

The registration waypoint on the waypoint map will be labeled with some information about the race.  The player who registered the race, the car tier and special classs.  If **'using [vehicle]'** is shown, the race is restricted to that vehicle.  If **'using [class] vehicle class'** is shown, the race is restricted to vehicles of type [class].  If **'using random vehicles'** is shown, the race will change vehicles randomly every lap.  If **'using random vehicles : [vehicle]'** is shown, the race will change vehicles randomly every lap and racers will start in the specified [vehicle].  If **'using random [class] vehicle class'** is shown, the race will change vehicles randomly every lap to one from that [class].  If **'using random [class] vehicle class : [vehicle]'** is shown, the race will change vehicles randomly every lap to one from that [class] and start in the specified [vehicle].  This allows racers to determine whether or not they can join the race without having to drive all the way to the registration waypoint.

Type **`/races register A1 2 180 no`** to register your race with a car-iter of A1, 2 laps, a DNF timeout of 180 seconds and no restrictions on the vehicle used. If you do not indicate a car tier, there will be none.  If you do not indicate the number of laps, the default is 1 lap.  If you do not indicate the DNF timeout, the default is 120 seconds.

If you want to restrict the vehicle used in a race, type **`/races register 100 2 180 no rest elegy2`** to restrict vehicles to **`elegy2`**.

If you want to restrict the vehicle class used in a race, type **`/races register 100 2 180 no class 0`** to restrict vehicles to class Compacts (0).

**If you want to create a race where only a custom list of vehicles are allowed or a race where vehicles change randomly every lap, you must create a vehicle list first before registering the race.**

Type **`/races vl add zentorno`** to add a **`zentorno`** to your vehicle list.  If you are creating a random race, you can add the same vehicle multiple times to your vehicle list.  This will increase the chances that a racer will be put in this vehicle after they complete a lap.

Type **`/races vl delete zentorno`** to delete a **`zentorno`** from your vehicle list.  If you have multiple **`zentorno`** vehicles in your list, only one will be deleted at a time.

If you want to add an entire class of vehicles to your vehicle list, type **`/races vl addClass 7`** to add all class Super (7) vehicles to your list.

If you want to delete an entire class of vehicles from your vehicle list, type **`/races vl deleteClass 9`** to delete all class Off-road (9) vehicles from your list.

If you want to add all vehicles to your vehicle list, type **`/races vl addAll`**.

If you want to delete all vehicles from your vehicle list, type **`/races vl deleteAll`**.

To list all the vehicles in your vehicle list, type **`/races vl list`**.

The commands **`/races vl saveLst`**, **`/races vl overwriteLst`**, **`/races vl listLsts`**, **`/races vl deleteLst`** and **`/races vl loadLst`** operate on your private list of vehicle lists if you specify **`pvt`** after the command or on the public list of vehicle lists if you specify **`pub`** after the command.  Only you have access to your private list of vehicle lists and can view and modify them.  All players have access to the public list of vehicle lists and can view and modify them.

Type **`/races vl saveLst pvt mylist`** to save your vehicle list as **`mylist`**.  **`mylist`** must not exist.  If you want to overwrite an existing vehicle list named **`mylist`**, type **`/races vl overwriteLst pvt mylist`**.

To list the vehicle lists you have saved, type **`/races vl listLsts pvt`**.  If you cannot see all the vehicle lists, type 'T' for chat and use the 'Page Up' and 'Page Down' keys to scroll.  Type 'Esc' when done.

If you want to delete a vehicle list named **`mylist`**, type **`/races vl deleteLst pvt mylist`**.

To load the vehicle list named **`mylist`**, type **`/races vl loadLst pvt mylist`**.  This will clear your current vehicle list and load the vehicles from the saved list.

Vehicle list data is saved in the file **`resources/races/vehicleListData.json`**.

If you want to create a race where only a custom list of vehicles are allowed, type **`/races register 100 2 180 no class -1`**.  The allowed vehicles will come from a vehicle list that you created or loaded.

If you want to create a race where vehicles change randomly every lap, type **`/races register none 2 180 no rand`**. The randomly selected vehicles will come from a vehicle list that you created or loaded.  If you want to increase the chances of a specific vehicle appearing, you can add that vehicle multiple times to your vehicle list.

If you want to create a race where vehicles change randomly every lap to one selected from your vehicle list that are of class Compacts (0), type **`/races register 100 2 180 no rand 0`**.

If you want to create a race where vehicles change randomly every lap to one selected from your vehicle list and racers start in an **`adder`** vehicle, type **`/races register 100 2 180 no rand . adder`**.  The period between **`rand`** and **`adder`** indicates that vehicles can come from any class in your vehicle list.

If you want to create a race where vehicles change randomly every lap to one selected from your vehicle list that are of class Compacts (0) and racers start in a **`blista`** vehicle, type **`/races register 100 2 180 no rand 0 blista`**.  When you specify the class Compacts (0), the start vehicle must be of class Compacts (0).

The different classes of vehicle you can specify are listed here:

-1: Custom\
0: Compacts\
1: Sedans\
2: SUVs\
3: Coupes\
4: Muscle\
5: Sports Classics\
6: Sports\
7: Super\
8: Motorcycles\
9: Off-road\
10: Industrial\
11: Utility\
12: Vans\
13: Cycles\
14: Boats\
15: Helicopters\
16: Planes\
17: Service\
18: Emergency\
19: Military\
20: Commercial\
21: Trains

As a convenience, each class of vehicle has been separated into different files in the **`vehicles/`** folder.  Vehicles of class Compacts (0) have been placed in **`00.txt`**.  Vehicles of class Sedans (1) have been placed in **`01.txt`**.  Vehicles of other classes have been placed in similarly named files except for class Custom (-1).  Each of these files contain vehicles taken from **`vehicles.txt`**.  Vehicles that don't seem to be in my version of GTA 5 are in the **`uknown.txt`** file.

If you set the number of laps to 2 or more, the start and finish waypoints must be the same.  Instructions on how to do this are listed above.  You may only register one race at a time.  If you want to register a new race, but already registered one, you must unregister your current race first. You cannot register a race if you are currently editing waypoints.  Stop editing first.

You can unregister your race by typing **`/races unregister`**.  This will remove your race advertisement from all players.  This can be done before or after you have started the race.  **IF YOU ALREADY STARTED THE RACE AND THEN UNREGISTER IT, THE RACE WILL BE CANCELED.**

To join a race, players will need to be close enough to the registration waypoint to be prompted to join.  The registration waypoint will tell the player if it is an unsaved track or if it is a publicly or privately saved track along with its saved name, who registered the race, the cartier and the number of laps.

There are seven possible types of race you can join:  1. Any vehicle can be used, 2. Restricted to a specific vehicle, 3. Restricted to a specific vehicle class, 4. Vehicles change randomly every lap, 5. Vehicles change randomly every lap and racers start in a specified vehicle, 6. Vehicles change randomly every lap to one in a specific class, 7. Vehicles change randomly every lap to one in a specific class and racers start in a specified vehicle.  For race types 4, 5, 6 and 7.

If the race is restricted to specific vehicle, its name is shown at the registration waypoint.  Players will need to be in the restricted vehicle at the registration waypoint in order to join the race.  Players can spawn the restricted vehicle by typing **`/races spawn [vehicle]`** where [vehicle] is the restricted vehicle name.

If the race is restricted to a specific vehicle class, the class name and number is shown at the registration waypoint.  You must be in a vehicle of the restricted class to join the race.  If the class is Custom (-1), you can view which vehicles are allowed in the race by getting out of any vehicle you are in, walking into the registration waypoint on foot and trying to join the race.  The chat window will list which vehicles you can use in the class Custom (-1) race.  If the class is not Custom (-1), you can list vehicles of the class by typing **`/races lvehicles [class]`** where [class] is the vehicle class number.

To join the race, type 'E' or press right DPAD.  Joining the race will clear any waypoints you previously set and load the track waypoints.  **NOTE THAT YOU CANNOT JOIN A RACE IF YOU ARE EDITING WAYPOINTS.  STOP EDITING FIRST.**  You can only join one race at a time.  If you want to join another race, leave your current one first.  **IF YOU DO NOT JOIN THE RACE YOU REGISTERED, YOU WILL NOT SEE THE RESULTS OF THE RACE.**

To list all competitors in the race that you joined, type **`/races rivals`**.  You will not be able to see competitors if you have not joined a race.  If you cannot see all the competitors, type 'T' for chat and use the 'Page Up' and 'Page Down' keys to scroll.  Type 'Esc' when done.

To respawn at the last waypoint the player has passed in a race type **`/races respawn`**.  You can also press 'X' on a keyboard, 'A' button on an Xbox controller or 'Cross' button on a DualShock controller for one second to respawn.  You can only respawn if you are currently in a race.

Once everyone who wants to join your registered race have joined, you can start the race.  Type **`/races start 10`** to start the race with a delay of 10 seconds before the actual start.  If you do not indicate a delay, the default is 30 seconds.  The minimum delay allowed is 5 seconds.  Any vehicles the players are in will be frozen until after the delay expires.  After the race has started, your race advertisement will be removed from all players.  The position of all human players will show up as green blips on the minimap and waypoint map.

The current race waypoint will have a yellow cylinder checkpoint appear in the world.  It will have an arrow indicating the direction of the next waypoint.  If a restricted vehicle or vehicle class was specified at the race registration waypoint, you will need to be in the restricted vehicle or a vehicle of the specified class when passing the waypoint to make the next waypoint appear.  If a restricted vehicle or vehicle class was not specified, you can pass the waypoint in any vehicle or on foot to make the next waypoint appear.  Once you pass the waypoint, it will disappear, a sound will play and the next waypoint will appear in the world.  Only the next three waypoints will be shown on the minimap at a time.  A blue route will be shown in your minimap to the current race waypoint.  Once you pass the current waypoint, it will disappear on the minimap and the next third waypoint along the route will appear on the minimap.  Once you leave or finish the race, all the race waypoints will reappear on the minimap.

Your current position, lap, waypoint, lap time, best lap time, total time, vehicle name and speed will display.  If someone has already finished the race, a DNF timeout will also appear.

If you want to leave a race you joined, type **`/races leave`**.  **IF YOU LEAVE AFTER THE RACE HAS STARTED, YOU WILL DNF.**

After the first racer finishes, there will be a DNF timeout for other racers.  They must finish within the timeout, otherwise they DNF.

As racers finish, their finishing time, best lap time and the vehicle name they used for their best lap time will be broadcast to players who joined the race.  If a racer DNF's, this will also be broadcast.

After all racers finish or DNF, the race results will be broadcast to players who joined the race.  Their position, name, finishing time, best lap time and name of the vehicle used for their best lap time will be displayed.  Best lap times will be recorded if the track was a saved track and waypoints were not modified.  Race results are saved to **`resources/races/results_[owner].txt`** where [owner] is the owner of the race.

If you want to look at the race results again, type **`/races results`**.  If you cannot see all the results, type 'T' for chat and use the 'Page Up' and 'Page Down' keys to scroll.  Type 'Esc' when done.

To spawn a vehicle, type **`/races spawn elegy2`** to spawn an **`elegy2`** vehicle.  If you do not indicate a vehicle name, the default is **`adder`**.  A list of vehicles you can spawn are listed in **`vehicles.txt`**.  This list has not been verified to work for all vehicles listed and there may be some missing.

To list vehicles that can be used for any race, type **`/races lvehicles`**.  To list vehicles of a specific class, type **`/races lvehicles 0`** to list class Compacts (0) vehicles.  The vehicles displayed come from the **`vehicles.txt`** file which should contain every vehicle.

To toggle the display of the speedometer at any time, type **`/races speedo`**.  The speedometer automatically displays when you are in a race and disappears when you finish or leave the race.  The default unit of measurement is imperial.  If you wish to change the unit of measurement type **`/races speedo (unit)`** where (unit) is either **`imperial`** for imperial or **`metric`** for metric.

Type **`/races panel`** to show the main panel.  Type **`/races panel edit`** to show the edit tracks panel.  Type **`/races panel register`** to show the register races panel. Type **`/races panel list`** to show the vehicle list panel.  All **`/races`** commands have a corresponding button and argument field(s) if needed.  Replies to the commands will show up in another panel as well as in chat.  There are buttons near the bottom that will let you switch to another panel if you click them.  To close the panel, type 'Escape' or click the 'Close' button at the bottom.

Leaving a race or finishing it does not clear its track waypoints.  If you like the track, you can save it to your private list by typing **`/races save pvt nicetrack`**.

Multiple races can be registered and started simultaneously by different players.

SERVER COMMAND DETAILS
----------------------
Server commands are typed into the server console.

Type **`races`** to see the list of available **`races`** commands.

Type **`races export publictrack`** to export the public track saved as **`publictrack`** without best lap times to the file **`resources/races/publictrack.json`**.  You cannot export the track if **`resources/races/publictrack.json`** already exists.  You will need to remove or rename the existing file and then export again.

Type **`races import mytrack`** to import the track file named **`resources/races/mytrack.json`** into the public tracks list without best lap times.  You cannot import **`mytrack`** if it already exists in the public tracks list.  You will need to rename the file and then import with the new name.

Type **`races exportwblt publictrack`** to export the public track saved as **`publictrack`** with best lap times to the file **`resources/races/publictrack.json`**.  You cannot export the track if **`resources/races/publictrack.json`** already exists.  You will need to remove or rename the existing file and then export again.

Type **`races importwblt mytrack`** to import the track file named **`resources/races/mytrack.json`** into the public tracks list with best lap times.  You cannot import **`mytrack`** if it already exists in the public tracks list.  You will need to rename the file and then import with the new name.

**IF YOU WANT TO PRESERVE TRACKS FROM A PREVIOUS VERSION OF THESE SCRIPTS, YOU SHOULD UPDATE `raceData.json` AND ANY EXPORTED TRACKS BY EXECUTING THE FOLLOWING COMMANDS BEFORE CLIENTS CONNECT TO THE SERVER TO USE THE NEW TRACK DATA FORMAT WHICH INCLUDES WAYPOINT RADIUS SIZES.**

Type **`races updateRaceData`** to update **`resources/races/raceData.json`** to the new file **`resources/races/raceData_updated.json`**.  You will need to remove the old **`raceData.json`** file and then rename **`raceData_updated.json`** to **`raceData.json`** to use the new race data format.

Type **`races updateTrack mytrack`** to update the exported track **`resources/races/mytrack.json`** to the new file **`resources/races/mytrack_updated.json`**.  You will need to remove the old **`mytrack.json`** file and then rename **`mytrack_updated.json`** to **`mytrack.json`** to use the new track data format.  You will then be able to import the track using the new track data format.

EVENT LOGGING
-------------
If you want to save a log of certain events, change the line\
**`local saveLog <const> = false`**\
to\
**`local saveLog <const> = true`**\
in **`races_server.lua`**.  The following events will be saved to **`resources/races/log.txt`**:

1. Exporting a track
2. Importing a track
3. Updating raceData.json from an old format to the current format
4. Updating a track from an old format to the current format
5. Saving a track
6. Overwriting a track
7. Deleting a track
8. Saving a vehicle list
9. Overwriting a vehicle list
10. Deleting a vehicle list

SCREENSHOTS
-----------
Registration point\
<img src="screenshots/Screenshot%20(1).png" width="800">

Before race start\
<img src="screenshots/Screenshot%20(2).png" width="800">

In race\
<img src="screenshots/Screenshot%20(3).png" width="800">

In race\
<img src="screenshots/Screenshot%20(4).png" width="800">

Near finish\
<img src="screenshots/Screenshot%20(5).png" width="800">

Race results\
<img src="screenshots/Screenshot%20(6).png" width="800">

Editing waypoints in waypoint map\
<img src="screenshots/Screenshot%20(7).png" width="800">

Editing waypoints in world\
<img src="screenshots/Screenshot%20(8).png" width="800">

Main command button panel\
<img src="screenshots/Screenshot%20(9).png" width="800">

Edit tracks command button panel\
<img src="screenshots/Screenshot%20(10).png" width="800">

Register races command button panel\
<img src="screenshots/Screenshot%20(11).png" width="800">

Vehicle list command button panel\
<img src="screenshots/Screenshot%20(13).png" width="800">

VIDEOS
------
[Point-to-point race](https://www.youtube.com/watch?v=K8pEdsXJRtc)

[Multi-lap race](https://www.youtube.com/watch?v=TKibGh_11FA)

[Multi-lap random vehicle race](https://www.youtube.com/watch?v=Cwtz6t8Q82E)

LICENSE
-------
Copyright (c) 2022, Neil J. Tan
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
