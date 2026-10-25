# Levels

Times are for a skilled player who knows the level. The owner cleared the old levels in 23-33 s, so they were too easy. Each level follows teach, then test, then twist. Checkpoints come every 25-35 s of play. Respawns never land in an archer's range (650 px) or within 200 px of a soldier's patrol. Two embers per level are hard to reach: they need UDAAN height, DRISHTI on a hidden stone, or TARANG on a cracked wall. `tests/test_config.gd` checks 2D reachability (jump, UDAAN and SETU ramps, using only taught mantras) and these spacing rules.

## Chapter 1: The Ash Pits
**c1_l1 The Ash Pits** (difficulty 2, ~40 s). Tutorial for movement, SETU, CHHAYA, JWALA and prana orbs. Retuned: a third guard holds the top ledge before the gate, gaps are tighter, checkpoints dropped from 4 to 3, and every prompt is 6 words or fewer. Vertical: the stair steps are 90 px or less.

**c1_l2 The Chain Ladder** (3, ~45 s). Teaches UDAAN on a 210 px cliff, which a SETU ramp can also climb. Retuned: adds thorn spikes (first at x=700, jumpable, with an ember over them), a fifth guard near the gate, a wider SETU pit (440 px), 3 checkpoints, and two hard embers (one mid-pit, one UDAAN-high).

**c1_l3 The Burning Steps** (4, ~70 s). New ideas: **crumbling ledges** and **archers**. Crumbles are taught as stairs over solid ground, then tested as a chain over a pit, then twisted into a descending chain with an archer covering the landing. The burning steps are a 120 px staircase with spikes on each tread, under archer fire. The finale is a barrier, a 4-HP soldier, crumbles, and an archer at the gate. The cracked-wall secret sits behind the spawn.

## Chapter 2: Mirror Marsh
**c2_l1 Mirror Marsh** (4, ~55 s). Teaches DRISHTI. Retuned: a third maya pit with a twist (a false stone at ground height posing as the far bank), the first archer in the marsh, a guard at the gate, and 3 checkpoints. The hidden steps rise 80 px or less.

**c2_l2 Drowned Lanterns** (5, ~80 s). New idea: **moving platforms**. The first one is a plain shuttle, then an elevator under an archer. Then a mover combined with hidden stones, then a three-lantern chain (vertical, horizontal, diagonal) with a false bait stone. The twist is a long mover under two false stones that look solid, ending at an elevator to the gate. SETU works as a costly fallback on every crossing.

**c2_l3 The Lying Bridge** (7, ~90 s). New idea: **flame jets**. They are taught on safe ground, then a pair is staggered. The bridge alternates real stones with false ones, the hidden real stones sit off-line, and a jet burns on the middle stone. Then a jet "wave" corridor, an archer duel across a maya pit, and a 500 px false floor hiding a hidden staircase. That staircase can only be crossed with DRISHTI, so an orb sits just before it. The finale is a descending maya bridge with a jet stone and an archer at the gate. It has 4 checkpoints and 5 orbs.

## Chapter 3: The Palace Walls
**c3_l1 Outer Gate** (6, ~85 s). Combines what came before, with tougher 4-5 HP soldiers. The route runs moat shuttle → gatehouse (perched archer, 4-HP soldier, gate barrier) → crumble climb up the wall → twin braziers on the wall top → courtyard brawl (two soldiers and a balcony archer) → inner moat (hidden stone, elevator, jet stone, crumble) → a 5-HP captain under two stacked archers → a crumble climb to the inner arch. The cracked-wall secret sits behind the spawn (440 px tall, so UDAAN cannot clear it).

**c3_l2 Gardens of Ash** (8, ~95 s). Fountains (jets) and terraces. The route runs 120 px terraces with spikes under an archer → a crumble-crumble-mover-crumble garden, where you must read the mover's timing before committing → a hedge barrier → a 500 px false "pool" → a four-jet wave → an elevator, crumble and ledge climb to a 5-HP soldier and an archer → a final hidden stone, crumble and two movers, under archer fire.

**c3_l3 The Smoke Stair** (9, ~105 s). A vertical climb, 1080 px up a tower. Six tiers are stacked 180 px apart. That is above jump height (160 px) and above a soldier's 160 px sight band, so you climb only at the connectors: crumble steps, elevators over the right-hand abyss, an UDAAN or SETU ramp at the left end of tier 2, and a crumble step on tier 4. A fall usually costs one tier, not a death. Tier 3 has a crumble gap and tier 5 a moving-platform gap. Jets sit only where nothing hangs above them (220 px flames). The top floor has a thorn door, a 5-HP captain and two archers. It has 5 checkpoints.

## Assumptions for the new entities (the levels depend on them)
- **Archer:** bolts fly at about 280 px/s toward where the hero was when fired. They pass through one-way ledges and stop at solid ground. Range is a straight-line distance (Euclidean) of 650 px. The first shot comes about 0.8 s after the hero enters range.
- **Jets:** each runs on a level clock (`t + offset`), so staggered offsets stay in phase. The 40 px hitbox rises 220 px. Show a short flicker telegraph before each burn. Two jets 150 px apart leave a safe 110 px pocket between them. Jets hurt only the hero.
- **Moving:** the platform starts at (x, y) and ping-pongs to (x+dx, y+dy). It is one-way and carries the hero.
- **Crumble:** only the hero triggers it. It returns after 3 s.
- **Spikes:** soldiers ignore them, and the hit grants the usual 1.2 s of invulnerability.
- **Soldiers on one-way platforms** (c3_l3 tiers 2 and 4) must stay on them. Their patrols keep the 140 px chase leash inside the platform.
- Defeated enemies stay dead after a respawn.
