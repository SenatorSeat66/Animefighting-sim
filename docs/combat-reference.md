<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:e5d4f97dfc5ae23d1410c3b0ae11c46879f07822171246202a64e3c1ecd55aec -->

# Shadow Fighting — combat reference

## User direction

Android game named **Shadow Fighting**, made in Unity 6 with Blender, inspired by the silhouette presentation of Shadow Fight 2 and the combat in [Sekiro's Combat Is Still Best by ONGBAL](https://www.youtube.com/watch?v=dReREg4Dtyc). The user requested three hours of development, a final APK around 450 MB using real game content, and delivery through GitHub Releases. These are delivery requirements, not claims that they have been met.

## Footage and analysis method

The MediaFire file supplied by the user was successfully downloaded on 2026-11-10. The file is 38,181,656 bytes, 640×360, H.264/AAC, 30 fps, 419.666667 seconds. SHA-256: `b7466a2448812a554d8a29b844af8957834abf0450a26db21010f7c398491cd0`. A local reference copy is in the task's `inputs/combat-reference.mp4`, outside the game repository and game build. It is reference footage, not a licensed game asset.

Inspected timestamped contact sheets at one-second intervals across the complete duration and consecutive native frames for selected exchanges (37.50–38.70 and 383.00–384.20), plus ten samples per second at 370–373. The complete file was decoded to check readability. This is full-duration coverage with selected frame-level analysis, not manual inspection of every frame. The original YouTube and temporary download failures are superseded by the working MediaFire copy.

The HUD is mostly hidden; controller inputs, collision data, damage values, guard rules, and exact timing windows are not observable. The footage may use modified encounters; the source does not establish a vanilla ruleset.

## Encounter observations

| Interval | Encounter label from YouTube chapters | Observable behavior and adaptation |
|---|---|---|
| 0:00–1:37 | Juzou | Heavy opponent, large overhead and lateral sword motions, short defensive contacts alternating with attacks, red danger signals, fire effects, close finish at about 1:33–1:35. Adapt as a slower heavy boss with readable anticipation and delayed follow-ups. |
| 1:37–3:28 | Nightjar Elite | Agile opponent, retreating and advancing movements, repeated close weapon contacts, airborne actions, explosive effects (about 1:49, 2:34, 3:14), finish near 3:24–3:27. Adapt as a mobile opponent with burst pressure and recoveries. |
| 3:28–5:10 | Lone Shadow | Fast close sword exchanges, changing distances, red warnings, intermittent fire effects, final close animation about 5:06–5:08. Adapt as a combo fighter with a sweep response check. |
| 5:10–6:52 | Seven Spear | Longer reach, broad arcs, extended thrust-like attacks, danger warnings, defensive contacts and close counter animations. End sequence near 6:45–6:48 followed by reward overlay. Adapt as a reach opponent with distinct thrust and sweep telegraphs. |
| 6:52–6:59.67 | Outro | Movement and traversal after the encounter; not additional combat evidence. |

## Selected frame-level findings

- At 37.50–38.70, the heavy enemy raises its weapon while the player remains close. A contact spark appears around sample 10 (~37.83), followed by another much larger ring-like flash around sample 28 (~38.43). There are roughly 18 source frames between these visual onsets (~0.60 s). This is a spacing estimate between visible effects, not a measured input or parry window.
- At 370–373, a bright contact effect occurs around 370.7, a red danger cue is visible around 371.2–371.8, an extended spear action follows around 372.0–372.2, and close interaction occurs around 372.4 onward. The evidence supports a warning/action/response sequence; it does not prove the player's button choice.
- At 383.00–384.20, an orange ring develops around sample 5–8, dissipates, and the spear opponent then moves through an extended pose. Contact feedback is brief enough to need a distinct flash and sound in the mobile adaptation.

## Combat direction for implementation

Use a side-on, single-lane duel with original black silhouettes against layered landscapes. Translate the reference into:

1. Attack anticipation, contact, recovery, and openings that remain legible on a small screen.
2. Tap guard for a short perfect-deflection interval; holding guard gives a weaker defense.
3. Separate vitality and posture. Accurate defense damages enemy posture; prolonged pressure prevents immediate recovery. Posture break creates a timed finisher opening.
4. Red danger cues and readable weapon poses. Sweeps require jumping; thrusts can be countered by a timed forward step. These counter rules are proposed game rules, not established by the hidden inputs in the video.
5. Different enemy combo rhythms, reach, and pauses, with attacks selected independently of the player's immediate button choice.
6. Bright gold sparks, weapon trails, short hit pauses, distinct impact audio, and restrained camera movement.
7. Touch controls for movement, attack, guard, jump, step, and a limited fire ability. Include an interactive lesson before the campaign.

All numeric timing and balance values in the project are original tuning choices. Exact source-game frame data cannot be recovered from this recording alone.

## Open delivery gates

A licensed Unity editor, successful Android compilation, install/launch verification, gameplay testing, actual APK size verification, and an uploaded GitHub release are required before describing this as a finished Android game. Do not pad a package or include the reference video to approach 450 MB. Do not publish an unverified file as a completed APK.


<!-- /coderabbit-ai-generated:v1 -->