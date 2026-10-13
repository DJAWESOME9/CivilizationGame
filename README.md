# Civilization: First Settlement

Build an ancient settlement from its first tents into a growing civilization.
Gather food, manage a changing population, research technologies, build homes
and farms, explore the surrounding land, and keep your people healthy through
the seasons. You can also host a shared world for up to eight civilizations,
trade resources, and raise armies to defend your settlement or raid rivals.

This is an actively developed strategy prototype. Its economy, combat and
multiplayer systems are still being tuned, and some planned systems are not yet
implemented. The game is a native desktop app made with Godot; recipients do
not need to install Godot.

## Project context and Obsidian

Read [AGENTS.md](AGENTS.md) before working on this project. Future project chats
should read and maintain the Obsidian [Development note](</Users/djfreeman/Library/Mobile Documents/iCloud~md~obsidian/Documents/DJ-Games/Civilization/Development.md>)
and [Ideation note](</Users/djfreeman/Library/Mobile Documents/iCloud~md~obsidian/Documents/DJ-Games/Civilization/Ideation.md>).
Development describes the current build; Ideation preserves design decisions and
conversation history. The full paths and update rules are in AGENTS.md.

## Download and open the game

The latest public release is **0.2.7 / build 9**, including scrollable Command panels and building options. Download the ZIP for your computer from
[Civilization releases on GitHub](https://github.com/DJAWESOME9/CivilizationGame/releases/latest):

- [Download for Mac](https://github.com/DJAWESOME9/CivilizationGame/releases/latest/download/Civilization-Mac.zip)
  — universal app for Intel and Apple Silicon Macs.
- [Download for Windows](https://github.com/DJAWESOME9/CivilizationGame/releases/latest/download/Civilization-Windows.zip)
  — 64-bit Intel/AMD PCs.

After the download finishes, extract the ZIP. On Mac, move `Civilization.app`
to Applications if you like, then open it. On Windows, choose **Extract All**
and run `Civilization.exe` from the extracted folder (not from inside the ZIP).
The first launch may take a moment while the operating system checks the app.

### If macOS says the app cannot be opened

The Mac download is ad-hoc signed but not notarized by Apple, so macOS may block
it the first time. If you downloaded the game from the official release link
above and trust that copy:

1. Try opening `Civilization.app` once, then dismiss the warning.
2. Open **Apple menu → System Settings → Privacy & Security**.
3. Scroll to the **Security** section. Find the message that Civilization was
   blocked, then click **Open Anyway**.
4. Confirm **Open Anyway** in the prompt and authenticate if macOS asks.
5. Open the app again and choose **Open** in the final confirmation.

The **Open Anyway** button is available for a limited time after you try to
open the blocked app. If it is missing, try opening the app once more and return
to Privacy & Security. Only bypass this warning for a copy you trust. Work or
school device policies may prevent allowing the app.

Windows may show an unknown-publisher warning because the prototype app is not
publisher-signed. Only continue if you trust the download source.

## Run from the project on macOS

Close the previous game window, then double-click `Launch.command`.
Alternatively open `project.godot` in Godot 4.7.2. The launcher uses the official
self-contained runtime in `.tools/`.

## Share the game with friends

After packaging, send `dist/Civilization-Mac.zip` to Mac friends and
`dist/Civilization-Windows.zip` to Windows friends through your preferred file
sharing service. Neither requires the Godot editor. Both include `START-HERE.txt`
with launch and multiplayer instructions. Mac supports Intel and Apple Silicon;
Windows targets x86_64 (Intel/AMD).

Friends extract their ZIP and open Civilization.app or Civilization.exe, then
use Multiplayer → Paste → Join world with your copied invitation. Keep your host
game open. Internet play still needs your public IP/hostname and a reachable,
forwarded UDP port; invitations do not provide a relay.

These private prototype builds are not publisher-notarized/signed. macOS may
require System Settings → Privacy & Security → Open Anyway for the trusted game;
Windows may display an unknown-publisher warning. The Mac app has an ad-hoc
signature. This is not an installer or an App Store release.

To rebuild both packages on this Mac, run `Build Packages.command`. It uses the
export presets and matching templates in `.tools/export_templates/`, then creates
the two ZIPs and `dist/SHA256SUMS.txt`. The official template archive was obtained
from the Godot 4.7.2 stable release. Building/exporting is not a gameplay test;
Windows gameplay and multiplayer between machines remain unverified.

## Automatic game updates

A startup script-loading error was found in published 0.2.3 (and earlier builds containing the horizontal technology tree). Published 0.2.4 / build 6 corrects it. If the game cannot reach Settings, recovery requires downloading the corrected ZIP and replacing the app; saves and multiplayer identity are stored separately. The corrected source opened the technology screen on macOS with a separate temporary profile, rendered it and exited cleanly without script errors. The native crash in the supplied report remains unconfirmed; Windows runtime and live updater installation remain unverified.

Version **0.2.7 / build 9** is published on [GitHub Releases](https://github.com/DJAWESOME9/CivilizationGame/releases/tag/v0.2.7).
Send friends the [Mac ZIP](https://github.com/DJAWESOME9/CivilizationGame/releases/download/v0.2.7/Civilization-Mac.zip)
or [Windows ZIP](https://github.com/DJAWESOME9/CivilizationGame/releases/download/v0.2.7/Civilization-Windows.zip).
Extract and open the game; Godot is not required. Earlier copies need one manual
replacement with this updater-enabled build. Live update installation remains untested.

Updater-enabled apps check GitHub Releases at startup and download signed game
content automatically, including while playing multiplayer. Downloaded changes
apply on restart. Settings → Game updates lets players turn automatic downloads
off, check manually, download an offered update, or queue a restart while in a
shared world. The queued restart runs after leaving the world, so the host can
choose when guests are disconnected. Every player must use the same game build
to join a shared world.

Friends who received the original 0.1.0 ZIPs must replace their app once with the
updater-enabled 0.2.0 build. Future compatible game releases can then update without
replacing the native app. Engine/bootstrap upgrades still need a new app download.
Saves and multiplayer identity stay outside the update files.

Release hosting: https://github.com/DJAWESOME9/CivilizationGame/releases
The updater trusts the bundled publisher public key and verifies release signatures,
pack sizes and SHA-256 hashes. It keeps the original app intact and installs game
content under the separate user-data updates folder. Failed downloads/checks do not
prevent playing the current game. No live update installation has been tested; see the isolated macOS source-launch check above.

Publishing instructions: [distribution/UPDATES.md](distribution/UPDATES.md).
Build Packages.command now also creates signed update.json and two platform PCKs.
New local code edits reach friends only after a new build is published as a GitHub
release; editing the project alone does not publish an update.

## Start playing

A fresh settlement has 30 adults, temporary shelter, a supply cache, and one
season's food before spoilage. **Gathering is the only initial production job;
Scouting is already unlocked.**
Choose **New settlement** to restart an existing save with these rules; the game
asks before replacing your local progress.

1. Open the technology tree. Toolmaking opens paths to fishing, woodcutting,
   stoneworking, and shelter building. Other foundations include basketry and planting.
2. Choose **Playtest: 1 day / second**, then **Resume**, or advance a season.
3. Learn Shelter Building to unlock construction and houses. Learn Storage for
   storehouses. Select an unlocked building, then click a clear hex in the starting
   zone. Materials are reserved upfront; builders complete it over time.
4. Planting unlocks farming/fields. Assign farmers after a field is completed.
   Crops grow outside winter and deliver harvests. Sanitation unlocks wells.
5. Select a technology card to see prerequisites/effects, then start it or queue
   one next technology. Switching preserves prior progress. Esc returns to the map.
   Learned technologies have green checkmarked badges; the queued technology has
   a blue arrow badge. The tree header shows the queue and total learned count.
   Scroll sideways through the tree with the mouse wheel, trackpad, or bottom
   scrollbar. The header and selected technology controls stay in place.
6. Open **Population & workforce priorities**. Set current percentages and enable
   automatic allocation to maintain them as the adult workforce changes. Manual
   worker changes disable that automation. Reduce an allocation before increasing
   another; percentage totals cannot exceed 100. Locked current jobs stay unavailable.
7. Train adults in an unlocked profession. Apprenticeships cost 1 food/2 wood,
   last 60 game days, and reduce work by 25% while learning. Specialists are allocated
   to matching jobs first and work more efficiently. School training is faster.
8. Build extra housing and maintain food/happiness to attract migrants. Births
   grow a separate child population; children consume food but cannot work before
   16. Future profession percentages guide their schooling once schools and the
   profession technologies exist. Adults retire at 65; old-age death varies
   individually from ages 65 to 75.

The expanded tree has 18 functional technologies. Basketry/hunting improve
food gathering; woodcutting and stoneworking unlock extraction; carpentry improves
construction; masonry increases house capacity; forestry enables replanting;
preservation reduces spoilage; crop rotation/waterworks improve farming; education
unlocks schools, more training places, child schooling, and +25% research.

## Time, controls, saves

World clock: one real day per season or year; 90 game days per season. Playtest
acceleration applies only while the app is running. Offline work uses the selected
world clock. Pause is a local playtest control. Manual advances stop at new food
crises; emergency food orders divert builders/quarriers into gathering.

Scroll/pinch or +/- zoom; right-drag or WASD/arrows pan; Q/E or middle-drag rotate.
H toggles hexes; R resets the camera; Tab collapses/restores all settlement panels.
Command tab contents and building-category lists scroll vertically when their
contents exceed the panel; the tab headers stay visible.
Each panel header has its own collapse/restore button. Panel choices persist locally.
Left- or right-drag moves the map; a click places a building or inspects land.
Click a building, field, construction site, tent, supply cache, cart, campfire,
tree, stone deposit, or riverbank object to open its details. Building benefits, construction
progress, and field growth update while the game runs. Close or Esc returns
to the map; clicking empty land still selects a scouting destination.
Click one of your soldiers at home, or an expedition's soldiers or banner, to
inspect the army. Your armies show troop count/type, commander, morale,
experience, training, supplies, formation, tactics and retreat orders.
Enemy armies show basic sightings; send scouts within sight to learn troop
count/type, formation and commander. Scout details retain their observation
date and may become outdated. Enemy morale, supplies, experience, destinations
and private orders stay hidden. Unseen armies retain only their dated sightings.
Esc closes management screens/cancels placement.
Close the window to save and exit. Autosave runs every 15 seconds; the local file
is `settlement.json` in Godot's application user-data directory. Existing version-1
saves are retained; legacy assignments to newly locked jobs are cleared.

## Prototype limits

Costs, rates, ages and happiness formulas are provisional. Population now has
individual age/profession/skill records; settlement resources remain aggregate.
Food consumption/spoilage, seasonal production, finite timber/stone, gathering
recovery, storage limits, construction, research and condition indicators run locally.
Citizens illustrate the actual workforce. Children grow gradually from 45% of
adult size at birth to full size at age 16, following their simulated age. Their
individual trips do not control deliveries; walking routes now detour around
visible trees and building footprints.

Always-online servers, diplomacy, territorial conquest, detailed battlefield movement, disease/disasters, detailed logistics,
device notifications and nested regional maps remain future work. Buildings still
share prototype models. Trees use original generated cutouts; terrain/buildings,
citizens and technology icons are project-authored. No reference-game assets were
extracted. Windows/Linux can open the source with Godot; packaged exports remain ahead.

## Happiness, rations, and food accounting

Click the **Happiness** indicator for the modifiers behind its actual score.
Food reserves, reduced/generous rations, untreated water, crowding, missing bedding,
winter exposure, lasting starvation hardship, and education affect the score.
Starting tents provide shelter but not permanent beds; houses include bedding.

At normal rations each adult consumes 1 food per 90-day season; children consume
half. Half rations consume 50% as much, with −15 happiness; generous rations use
125%, with +5 happiness. Food spoils too. Production can exceed consumption, so a
rising stockpile does not mean food use has stopped. The HUD shows daily food use
and recent production; the happiness panel separates actual production, consumption,
spoilage and overflow from the latest simulation interval. Harvests cause spikes.
Pause stops live game time, while elapsed offline work follows the world clock.

## Scouting and map visibility

Scouting is automatically unlocked in new and existing settlements. Use **Choose
destination on map**, click land outside camp, and dispatch three
settlers from the Exploration panel. You can send multiple parties to separate
destinations as long as three eligible adults and the trip's food are available.
Food packed is based on expected round-trip travel time and a possible city survey,
at the current ration level; longer trips cost more. The three settlers are removed
from the available workforce and ordinary food consumption while away. Each party
travels at a provisional 6 map units per game day before seasonal slowdowns, spending
up to 3 days surveying when they find a civilization at the destination; empty sites
add no on-site delay. Scouts face their travel direction on both legs and stop
walking while surveying. Existing missions
also use the faster travel rate. Click without dragging to inspect land; a
marker shows the selected destination. Clicking land opens a destination panel with
**Send 3 settlers to scout**; disabled actions explain missing food, unavailable
adults, or an invalid destination. Landscape objects offer
the same scouting action. River crossings remain unavailable in this
prototype, so destinations must be on the western bank.

Inspection panels let you keep clicking objects and land around the panel. Selecting
scenery updates the destination marker and Exploration controls too. Choose-destination
mode selects the land under your click even when scenery occupies it. There is no
default scouting destination; dispatch clears the selection so the next expedition
needs a fresh choice. The Exploration dispatch button shows the selected coordinates.

Scouts count as returned on entering the camp's 12-unit starting clearing and
immediately become available for work; they do not need to reach its center.
New scouting parties start at the camp boundary facing the selected destination,
and return to that boundary. New destinations must be outside the 12-unit camp area.
Already-active missions retain their original departure point and progress.

Click any scout to inspect the party's camp-to-destination-and-back route, current
position, travel/survey/return stage, stage progress, and estimated game days until
the next stage and return to camp. A small route map tracks the party and marks
the camp area and return point at its boundary. Estimates
update while the panel is open and use the current seasonal speed; a season change
can alter them. Close or Esc returns to the map.

The home region remains visible. Scouts reveal their route; surveyed land stays
known but fades when outside current sight. Returned reports can identify distant
woodland, stone ridges and fertile ground. These are potential expansion sites;
discovery does not instantly add materials or establish remote production. Manual
time advances stop when scouts return with news. Missions and exploration are saved
and continue offline. In shared worlds, scouts discover rival settlements and
expeditions on the main map. Information outside current sight stays dated; it
updates when scouts or your armies return to sight range. Discover a settlement
before offering barter or launching a raid against it.

Click a tree or stone (including river stones) to see its remaining wood or stone.
These sources shrink as collected and disappear when depleted. Logging and quarry
visuals move to the next source; Forestry regrowth restores woodland. Amounts
divide the existing finite settlement reserves among local scenery, preserving
older saves and existing production balance. Distant expansion and shared-world
ownership of individual deposits remain prototype limitations.

## Top status bar

The map has a persistent top bar for food, wood, stone, storage, happiness,
and research speed/current progress. Wood and stone show collected production per
game day from the latest simulation interval, after storage limits; construction
and equipment spending are separate. These rates also appear in resource details.
Click Food, Wood, Stone, or Storage for
live stock, worker, reserve, food-flow, and shared-capacity details. Switch
resources within the panel; Esc, Close, or clicking outside returns to the map.
Click Happiness for its modifiers or
Research to open the technology tree. Collapsing the side panels leaves these
indicators visible. Full-screen management views retain their own headings.

## Command panel

The main map's collapsible Command panel groups actions into Overview, Build,
People, Explore, and Military tabs. Overview shows settlement status and the
first-steps guide. Build contains Housing, Resources, Services, and Military
building categories. People contains worker assignments and a shortcut to
population priorities. Explore contains scouting controls. Military opens army
management. Time and event controls remain in their own panel. Scouting is
available from Explore from the start and appears as learned in the technology
tree; it requires no research.

## Settings

Use Settings at the top right for master, music, ambience and sound-effect volumes, persistent hex-line visibility,
fullscreen, zoom sensitivity, expanding HUD panels, and resetting the camera.
Changes apply immediately and persist locally. H toggles the same hex-line
preference; building placement temporarily shows the grid and restores the
preference afterward. Esc or clicking outside closes Settings. The simulation
continues if it was running. Original gentle instrumental music and woodland ambience loop in the background.
Buttons, building orders/completion, research, scouting, harvests, seasonal changes
and urgent food/combat events have sound cues. Audio continues while game time is
paused; set any slider to zero to mute that category. Event cues are limited during
fast-forward. The current published version is 0.2.7 / build 9; see the release notes for its changes.


## Multiplayer: direct hosting and joining

Open **Multiplayer** in the top bar. This first multiplayer foundation supports
up to eight independent civilizations, player-to-player barter, and raids. Zoom out
on the main map to see the wider shared world; send scouts to discover other
settlements. Known settlements and expeditions appear on this map, with dated
information outside current sight. Detailed battlefield movement and territorial
conquest remain future work.

### Host

1. Enter a civilization name and leave the default UDP port **24567**, or choose another.
2. Choose **1 real day per season**, **1 real day per year**, or a testing speed: **day = 10 seconds** / **day = 30 seconds**. **Saved clock / default** retains the saved speed (or uses one real day per season for a fresh world).
3. Click **Host world**. Resume uses the previously saved world's clock and civilizations.
   Unchecking Resume starts a fresh world and asks before replacing an existing world save.
4. Reopen Multiplayer, then use **Invite friends to this world → Copy invitation**.
   Send the copied text to your friends. The address defaults to a local network IP;
   choose the one reachable from their computers. For Internet play, enter your
   reachable public IP or hostname and forward the chosen UDP port on your router.
   Keep the host game open while people play.
5. AI opponents default to **zero**, leaving seven slots for other real players.
   Optional AI opponents share the eight civilization slots with humans.

### Join

On another computer with the same project version, launch the game, open
Multiplayer, click **Paste** to insert the invitation, then click **Join world**.
The invitation supplies the address and port automatically. You can also enter
the host's address and port manually. Invitations are text to paste into the game,
not browser links; they contain a connection address and world identifier, not
a player identity or an access password. Invite-only access control is not implemented.
The game rejects incompatible multiplayer protocol versions and invitations to
a different saved world. Use the same project build on every computer.
On this Mac, [Multiplayer Guest.command](Multiplayer%20Guest.command) opens a
second player profile; join **127.0.0.1**, port **24567**. That guest profile has
its own persistent identity and separate single-player save. Closing and reopening
the same profile reconnects to its civilization. A different device/profile creates
a new civilization, subject to the eight-civilization limit.

LAN play requires the host's UDP port to be reachable. Direct Internet connections
require a reachable host address and router/firewall configuration for that UDP
port. There is no relay, matchmaking, account service, or dedicated server yet.
The networking uses [Godot's ENet high-level multiplayer API](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html).

### If connecting fails

Connection status and error messages stay visible below the multiplayer tabs.
Only one window should host a given UDP port. If hosting fails, another game
may already be using it; join that host or choose another port and copy a new
invitation. A second window on this Mac must use `Multiplayer Guest.command`
and **Join world**, with address **127.0.0.1**.

For another computer on the same network, use the host's LAN address, allow
the game through the host firewall, and avoid guest Wi-Fi that isolates devices.
For friends elsewhere, the default LAN invitation cannot reach your computer:
enter a reachable public address and forward the selected **UDP** port to the
host computer. The host must remain open. A timeout after reaching the host
is reported separately from a failure to reach its address/port; both computers
must run the same game build.

### Shared simulation and saves

The host advances every civilization on one clock, checks commands, and sends
players their own authoritative state. Research, building, scouting, workforce,
training, rations and population policies submit orders to the host. Local pause,
playtest acceleration, world-clock changes, and New settlement are disabled in a
shared world. The season-advance control submits a vote; **every human civilization
owner must be connected and agree**. New connections and disconnections clear
votes. Significant condition changes and scout reports can interrupt an agreed jump.

Disconnected civilizations continue essential work while the host runs. If the host
closes, live play stops; resuming advances all saved civilizations over the elapsed
normal world-clock interval. The host stores `multiplayer_world.json`, including
civilizations and pending barter offers, separately from `settlement.json`.
**Leave world** returns to your original single-player settlement. Player identities
are stored locally; preserving the identity file is necessary to reclaim the same
civilization. Automatic host migration and transferring identities between devices
are not implemented.

### Barter

Use Multiplayer → **Barter**, select another civilization, choose materials and
amounts, and send an offer. The recipient selects the received offer and accepts or
declines it. Senders can cancel their pending offers. On acceptance the host checks
both inventories and both settlements' storage capacities, then transfers the
materials together. Up to four outgoing offers per civilization may be pending.
Transfers are immediate in this prototype; trade routes, transport costs, caravans
and diplomatic-contact requirements remain future work.

The original native World and Barter screens have been rendered and inspected.
The eight-slot expansion and invitation controls were inspected in source only;
no tests or renders were run for this update, per project instructions. Two-machine
connection, reconnect, synchronization, and multiplayer gameplay have not yet been
exercised; this is an initial multiplayer implementation, not a verified online release.


## Warfare foundation

**Buildings → Military** contains Training Grounds, Barracks, Palisade and Wall.
Research **Masonry** to unlock stone wall sections. Each costs **8 wood / 24 stone**
and **40 construction work**, occupies a clear building hex, and adds **20% defense
power** once completed (up to 60% from walls). Palisades provide up to 40%; their
combined fortification bonus is capped at 80%. Walls strengthen defenders in the
current aggregate combat system; they do not block movement or replace soldiers.
Training grounds train every soldier type; barracks provide military housing and
cap standing army size at **12 soldiers per completed barracks**. Barracks do not
accelerate training. Each completed training ground supports **six trainees at
full speed**; larger simultaneous intakes share throughput and take longer.
Military beds count toward comfort only while occupied by soldiers.

Click a **Training Grounds** on the map, then choose **Armies & commanders**
in its details panel. You can also open it from the Settlement panel, or
Multiplayer → **Warfare**. Recruitment uses actual adults, reserves them from
civilian labor and scouting/training assignments, pays equipment costs up front,
and preserves at least three available civilians. Training grounds and barracks
must both be completed before recruitment.

| Unit | Required technology | Equipment per soldier | Base training | Attack / defense |
| --- | --- | --- | --- | --- |
| Militia | Toolmaking | 1 wood | 10 game days | 1.0 / 0.8 |
| Spearmen | Stoneworking | 2 wood, 1 stone | 20 game days | 1.5 / 1.8 |
| Archers | Hunting | 3 wood, 1 stone | 30 game days | 1.8 / 0.9 |

Aren is a steadfast defensive commander; Mira favors fast marches and attacking;
Tovan has balanced bonuses and loses less morale on withdrawal. Each commander
leads one group. Appoint commanders to existing groups at home, choose tactics
(Advance, Hold ground, Flank, Skirmish), formations (Line, Shield wall, Loose),
a morale retreat threshold, and whether commanders may choose tactics themselves.
Orders can change while a battle is ongoing. Units, commanders, morale, experience,
tactics, formations, food and fortifications influence combat strength.

A trained army with at least 60 morale can raid another civilization in a
shared world after the target settlement is discovered. Scouting is available from the start. Food for the expedition is reserved at
launch. Marching time depends on regional distance; fighting resolves one round
per game day, for at most eight rounds. Armies can be recalled. They return over
time, deliver plunder/unspent provisions up to available storage space, and recover
morale at home. Combat casualties remove real people from the civilization.

Standing defense orders apply while the owner is offline:

- **Hold settlement:** ready armies defend; without a ready army, up to eight
  available civilians temporarily rally as weak, untrained emergency militia.
  This is self-defense, not training or a recruitable standing army.
- **Counterattack:** the same mobilization, with +10% defensive strength.
- **Preserve people:** no emergency civilian levy, earlier defensive withdrawals,
  and less of the settlement's stores exposed to plunder.

Ready reinforcements can join a battle. Low-morale defenders withdraw and recover;
palisades improve defense. An army away on expedition cannot defend its home.
Offline defenders have exactly the same resolution rules as online players. The
host must be running, or resume its save, for time to advance. Agreed fast-forward
stops at battle arrival, a fighting round, or return, as well as other major events.

Zoom out and pan the main map for civilization regions and expedition positions.
Scouts and armies reveal nearby activity; unseen enemy movements are not live
updates. Soldiers at home carry their equipment and drill near training grounds;
deployed groups appear along their routes. Combat is presently aggregate,
not individual soldiers maneuvering on a detailed battlefield. Battle reports,
armies, standing orders and campaigns persist through saves and reconnecting.
Territorial conquest, sieges, detailed tactical terrain, commander death/injury,
caravans, full army skill trees and device notifications are future work.

Successful hosting/joining now opens your civilization's main view automatically.
The multiplayer menu also has **Enter civilization** and **Back to civilization**.
The main map provides both the settlement view and the wider world through zooming.

Native warfare controls, the main view, and seasonal terrain were rendered and inspected.
Combat resolution and networking between two machines have not been exercised.
Military costs, capacities, timings and combat multipliers are provisional.

## Seasons

Spring, summer, autumn and winter each last 90 game days. The selected world
clock applies to every player. Hover over the date for the current seasonal effects.
Season changes announce themselves and interrupt agreed fast-forwarding.

| Season | Changes |
| --- | --- |
| Spring | Fresh green terrain; faster woodland recovery and crop growth. Travel is slightly slower than summer. |
| Summer | Strongest gathering, fishing and crop growth; food spoils faster. Fastest travel. |
| Autumn | Warm foliage and terrain; slower crops, fishing and travel. |
| Winter | Snowy terrain, icy-looking water and colder light. Crops stop growing and woodland stops regrowing. Gathering, fishing, logging, quarrying, construction and travel slow. Food spoils more slowly; inadequate housing reduces happiness. |

Winter travel runs at 65% of summer speed; gathering at 50%, fishing at 55%,
logging at 80%, and quarrying/construction at 75%. These are provisional balance
values. Research keeps progressing through every season. Winter river visuals
do not enable crossings. Weather events, snow accumulation and seasonal tree
geometry remain future work.

## Day and night

The circular clock beside the season shows the world hour. Its gold arc marks
daylight; the moving sun/moon marks the current time. Hover for sunrise and
sunset. One rotation equals one game day; it follows the saved shared simulation
clock and freezes when solo play is paused. New settlements begin at 08:00.

Sunlight moves across the landscape with warm dawn/dusk transitions, cool
moonlight, dimmer foliage and a flickering campfire. Summer daylight spans
05:00–19:00, winter 07:30–16:30, spring 06:00–18:00 and autumn 06:30–17:30.

Civilian figures rest in shelter at night, with a few beside the hearth. Ready
soldiers visibly patrol; trainees rest and scouts continue their journeys. This
is a visual daily routine: existing daily production/training rates already
include rest, and patrol animations do not add combat bonuses. Native sunset
and night views were rendered and inspected; shared-client synchronization
has not been exercised between machines.

### Multiplayer testing clock

Before hosting, select **Testing: day = 10 seconds** or **Testing: day = 30
seconds** in Multiplayer → World. Leave **Resume saved multiplayer world**
checked to apply it to your existing world. The host controls the shared clock;
all civilizations, production, research, travel and day/night lighting advance
together. Leave and rehost to change speeds. Test speeds are saved, but worlds
at these accelerated speeds pause while the host is closed; disconnected
players keep developing while the host is running.

Trees use solid procedural oak meshes with branching trunks, root flares and
layered canopies. Eight shared shape variants keep the forest varied while
seasonal foliage, daylight, shadows and exploration visibility follow the world.

## AI opponents

Open **World / Multiplayer → World**, uncheck **Resume saved multiplayer world**
to create a fresh world, and select **0–7 AI opponents** and **Easy**, **Normal**,
or **Hard** difficulty before choosing **Host world**. You can play alone; friends
can join any remaining slots within the eight-civilization limit. A fresh world
replaces the shared-world save after confirmation; your solo settlement stays separate.

AI settlements research, allocate workers, construct buildings, scout rivals,
train armies, defend, raid discovered civilizations, and respond to barter. They
pay the same costs and use the same production and combat rules as human players.
Easy makes decisions every 12 game days and begins raiding after day 720; Normal
acts every 6 days and may raid after day 540; Hard acts every 2 days and may raid
after day 360, maintaining larger armies. Raids still require discoveries, trained
soldiers, and provisions. Fair, affordable barter offers are accepted; other offers
are declined. AI currently responds to offers rather than initiating trade.

AI difficulty, decision schedules, civilizations, and campaigns persist in the
shared-world save. Resume retains saved opponents; creation controls are disabled
while resuming an existing save. Only human owners vote to advance time. The AI
and save/resume flows have been checked with automated local hosting tests; remote
multiplayer remains subject to the prototype limits above.

## Release 0.2.7 / build 9

Published as Latest with scrollable Command tab contents and building options.
It includes the tab selection fix and queued update restart. See [release notes](distribution/RELEASE-NOTES.txt).
