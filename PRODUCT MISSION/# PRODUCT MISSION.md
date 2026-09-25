# PRODUCT MISSION  
  
Design and build a premium native application for iOS, iPadOS, and macOS that transforms user-controlled music playlists into continuously evolving, music-responsive ASCII/ANSI-art visual broadcasts suitable for YouTube Live and other future streaming destinations.  
  
The product should feel like a professional creative instrument rather than a novelty visualizer.  
  
Users should be able to:  
  
1. Build playlists from supported music sources.  
2. Analyze the playlist's musical characteristics, structure, genre, energy, and transitions.  
3. Automatically generate a coherent visual identity for the playlist.  
4. Render sophisticated animated ASCII/ANSI artwork that responds meaningfully to the music.  
5. Display tasteful now-playing information.  
6. Preview and customize the broadcast.  
7. Stream the resulting audiovisual program to a configurable YouTube Live endpoint.  
8. Leave the system running reliably as a continuous music channel.  
  
The experience must be accessible, approachable for casual users, powerful enough for creators, and competitive with modern streaming, music-visualization, VJ, and broadcast-production applications.  
  
---  
  
# DEVELOPMENT STRATEGY  
  
Development will use different models for different phases.  
  
## PHASE 1: ASTRA ONLY  
  
Astra's sole responsibility in the first phase is to develop the complete creative and technical strategy for the ASCII/ANSI animation and visualization system.  
  
Do NOT develop the complete application architecture yet.  
  
Do NOT spend significant effort designing authentication, playlist integrations, streaming APIs, general application navigation, or unrelated infrastructure.  
  
Astra should concentrate its intelligence on answering:  
  
"What would make the generated ASCII/ANSI broadcast visually extraordinary, musically intelligent, recognizable, varied, and compelling enough that someone might actually leave it playing on a screen?"  
  
Astra should produce a detailed specification that GPT-5.6 Sol can subsequently incorporate into the complete product plan.  
  
## PHASE 2: GPT-5.6 SOL  
  
GPT-5.6 Sol will combine Astra's visualization specification with the remaining product requirements and produce the complete:  
  
- product specification  
- UX architecture  
- application architecture  
- data model  
- integration architecture  
- playback architecture  
- rendering architecture  
- streaming architecture  
- platform strategy  
- implementation roadmap  
- testing strategy  
  
## PHASE 3: GPT-5.6 SOL, MEDIUM REASONING  
  
Implementation should then be performed using GPT-5.6 Sol at Medium reasoning where appropriate for cost efficiency, escalating reasoning only when architecture, debugging, concurrency, AVFoundation, rendering, streaming, or other difficult implementation problems justify it.  
  
---  
  
# ASTRA'S CURRENT ASSIGNMENT  
  
Develop the complete strategy for the generative ASCII/ANSI animation engine.  
  
The visualizer must NOT merely be:  
  
- an animated texture  
- an ASCII waveform  
- a spectrum analyzer made from characters  
- a rotating geometric object  
- a particle field  
- a generic equalizer  
- a shader converted into ASCII  
- random characters responding to amplitude  
- one visualization with different palettes  
  
Those techniques may exist as individual components, but they cannot constitute the experience.  
  
Instead, design a system capable of producing actual evolving visual performances.  
  
The system should feel closer to generative motion design, music visualization, demoscene graphics, terminal art, experimental animation, VJ performance, and broadcast design merged into a single visual language.  
  
---  
  
# MUSIC INTELLIGENCE  
  
Determine what musical information should drive the visual system.  
  
Consider analysis at multiple timescales.  
  
### Immediate audio characteristics  
  
Potential signals include:  
  
- amplitude  
- RMS  
- frequency spectrum  
- spectral centroid  
- spectral flux  
- transients  
- onset detection  
- beat  
- tempo  
- rhythmic density  
- bass energy  
- midrange activity  
- high-frequency energy  
- stereo characteristics  
  
### Musical structure  
  
Where technically practical, detect or infer:  
  
- intro  
- verse  
- pre-chorus  
- chorus  
- bridge  
- breakdown  
- buildup  
- drop  
- instrumental section  
- outro  
- major structural transitions  
  
The visual system should understand the difference between reacting to a kick drum and responding to the arrival of a chorus.  
  
### Higher-level characteristics  
  
Explore signals such as:  
  
- genre  
- subgenre  
- mood  
- energy  
- valence  
- instrumentation  
- vocal presence  
- acoustic/electronic character  
- harmonic density  
- rhythmic complexity  
- perceived intensity  
  
Clearly distinguish between characteristics that can be reliably measured and characteristics requiring inference.  
  
---  
  
# PLAYLIST-LEVEL INTELLIGENCE  
  
Do not treat every track as an isolated visualization.  
  
Analyze the playlist as a complete program.  
  
Determine:  
  
- genre distribution  
- energy trajectory  
- tempo trajectory  
- stylistic clusters  
- abrupt changes  
- gradual transitions  
- recurring musical characteristics  
- opportunities for visual callbacks  
- overall visual identity  
  
Generate a "Visual DNA" for each playlist.  
  
This Visual DNA should establish persistent characteristics such as:  
  
- character vocabulary  
- typography  
- compositional tendencies  
- rendering behavior  
- transition language  
- motion grammar  
- visual motifs  
- spatial density  
- palette behavior  
- recurring scenes or entities  
  
Individual songs can dramatically transform the visual environment while still belonging to the same overall broadcast identity.  
  
---  
  
# VISUAL SCENE SYSTEM  
  
Design a modular scene architecture rather than one monolithic visualizer.  
  
Possible scene families might include:  
  
- ASCII architecture  
- landscapes  
- cityscapes  
- tunnels  
- machines  
- abstract organisms  
- impossible geometry  
- typographic worlds  
- celestial environments  
- terminal interfaces  
- character-driven scenes  
- data structures  
- procedural environments  
- kinetic typography  
- ASCII cinematography  
- simulated camera movement  
- narrative micro-scenes  
- reactive objects  
- generative creatures  
- surreal transformations  
  
Do not limit yourself to these examples.  
  
Find less obvious visual possibilities.  
  
The system should support layering so a scene might contain:  
  
BACKGROUND WORLD  
  
- STRUCTURAL ELEMENTS  
- MUSIC-REACTIVE OBJECTS  
- PARTICLES/ATMOSPHERICS  
- TYPOGRAPHY  
- TRANSIENT EFFECTS  
- CAMERA BEHAVIOR  
- BROADCAST GRAPHICS  
  
Define how these layers interact.  
  
---  
  
# ASCII/ANSI AS A MEDIUM  
  
ASCII must be treated as an artistic constraint rather than a degradation filter.  
  
Investigate the expressive capabilities of:  
  
- character density  
- glyph shape  
- Unicode block characters where appropriate  
- line-drawing characters  
- Braille characters where appropriate  
- ANSI color  
- foreground/background color relationships  
- character replacement  
- character-scale dithering  
- text distortion  
- terminal artifacts  
- scan behavior  
- cursor effects  
- character displacement  
- procedural typography  
- character morphing  
- negative space  
- density fields  
  
Determine when strict ASCII should be used versus an expanded ANSI/Unicode character vocabulary.  
  
The system should intentionally exploit characteristics unique to text-based imagery.  
  
---  
  
# TEMPORAL VISUAL GRAMMAR  
  
Create rules for visual behavior over time.  
  
Music visualization should occur at multiple temporal scales:  
  
MICRO:  
Individual beats, transients, percussion, and sonic events.  
  
MESO:  
Phrases, riffs, verses, choruses, buildups, drops, and instrumental passages.  
  
MACRO:  
Entire tracks and transitions between tracks.  
  
PROGRAM:  
The evolution of the complete playlist or live channel.  
  
Avoid constant maximum movement.  
  
Stillness, anticipation, negative space, escalation, visual release, and sudden transformation should all be available.  
  
The visual system should possess pacing.  
  
---  
  
# EFFECT SYSTEM  
  
Design a library of effects that can be orchestrated rather than randomly applied.  
  
Explore techniques such as:  
  
- character explosions  
- cascading glyphs  
- text fragmentation  
- ASCII displacement  
- scanline deformation  
- terminal corruption  
- controlled glitch  
- perspective transformations  
- depth simulation  
- parallax  
- pseudo-volumetric effects  
- trails  
- echoes  
- temporal smearing  
- feedback  
- character rain  
- typographic shockwaves  
- wipes constructed from glyphs  
- palette inversions  
- character-density transitions  
- simulated signal failure  
- ASCII pixel sorting  
- scene fracture/reconstruction  
  
Effects should correspond to meaningful musical events.  
  
---  
  
# SONG TRANSITIONS  
  
Track changes must become part of the performance.  
  
Design transition strategies based on musical compatibility.  
  
For example, transitions might:  
  
- dissolve one ASCII world into another  
- preserve an object from the previous song  
- reconstruct the scene character-by-character  
- collapse into the song title  
- transition through negative space  
- morph one character vocabulary into another  
- perform a simulated terminal reset  
- create a visual bridge derived from both tracks  
  
Transitions should avoid repeatedly using the same technique.  
  
---  
  
# NOW-PLAYING INFORMATION  
  
Song metadata should appear during approximately:  
  
- the first 10 seconds of a track  
- the final 10 seconds of a track  
  
Information may include:  
  
- song title  
- artist  
- album  
- album artwork where licensing/source rules permit  
- year  
- elapsed/remaining time  
- optional user-defined channel branding  
  
Metadata should be integrated into the visual composition rather than simply placed in a static rectangle.  
  
Examples could include architectural signage, terminal output, kinetic typography, environmental text, perspective typography, or scene elements that reconstruct themselves into readable information.  
  
Readability always takes priority over novelty.  
  
Users should be able to configure which metadata appears and how long it remains visible.  
  
---  
  
# VISUAL CONTINUITY AND VARIATION  
  
Solve the repetition problem explicitly.  
  
A continuous channel might run for hours.  
  
The system therefore needs mechanisms for:  
  
- scene variation  
- controlled randomness  
- seeded generation  
- motif recurrence  
- scene mutation  
- palette evolution  
- alternative compositions  
- camera variation  
- transition variation  
- effect cooldowns  
- repetition detection  
  
A listener should not immediately recognize a small repeating animation loop.  
  
Develop a strategy for effectively unbounded visual variation while retaining intentional art direction.  
  
---  
  
# HUMAN ART DIRECTION  
  
Automation should not eliminate creative control.  
  
Design three levels of interaction:  
  
### AUTOMATIC  
  
The system analyzes the playlist and creates the complete visual identity automatically.  
  
### GUIDED  
  
Users select broad creative parameters such as:  
  
- visual theme  
- intensity  
- complexity  
- color behavior  
- ASCII strictness  
- motion intensity  
- glitch intensity  
- typography  
- camera behavior  
  
### ADVANCED  
  
Creators can control:  
  
- scene families  
- scene weighting  
- palettes  
- glyph sets  
- effect mappings  
- beat responses  
- frequency mappings  
- transition rules  
- typography  
- overlays  
- branding  
- scene duration  
- randomness seeds  
- visual presets  
  
Users should be able to save, duplicate, import, and export visual presets.  
  
---  
  
# ACCESSIBILITY  
  
The visualization system must accommodate users with different visual and sensory needs.  
  
Include:  
  
- Reduce Motion support  
- configurable animation intensity  
- flash/strobe suppression  
- WCAG-conscious text contrast  
- color-blind-safe modes  
- alternatives to color-only information  
- scalable interface typography  
- VoiceOver-compatible controls  
- keyboard navigation on iPadOS/macOS  
- sufficient hit targets  
- clear focus states  
  
Provide a "Photosensitivity Safe" mode that prevents rapid luminance changes and potentially dangerous flashing patterns.  
  
Accessibility must affect generated broadcast graphics where relevant, not merely the application's control interface.  
  
---  
  
# PERFORMANCE  
  
The eventual engine must run efficiently across Apple platforms.  
  
Explore appropriate use of:  
  
- Swift  
- SwiftUI  
- Metal  
- Metal compute  
- Core Image  
- Accelerate/vDSP  
- AVFoundation  
- Core Audio  
- Core ML where justified  
  
Do not assume machine learning is necessary for something deterministic signal processing can perform faster and more reliably.  
  
Design graceful quality scaling based on device capabilities.  
  
Potential output targets should include:  
  
- 720p  
- 1080p  
- 1440p  
- 4K where hardware permits  
  
Rendering should remain deterministic enough for reliable broadcast operation.  
  
---  
  
# PREVIEW AND CREATOR EXPERIENCE  
  
The eventual UI should provide a live preview workspace comparable to a lightweight broadcast/VJ environment.  
  
Conceptually support:  
  
PREVIEW\  
PLAYLIST\  
NOW PLAYING\  
SCENE\  
VISUAL DNA\  
EFFECTS\  
OUTPUT\  
STREAM HEALTH  
  
The user should be able to change visual parameters while playback continues.  
  
Changes should appear immediately whenever technically feasible.  
  
Include:  
  
- undo/redo  
- reset parameter  
- reset section  
- preset comparison  
- favorite presets  
- duplicate preset  
- safe defaults  
  
Never make experimentation feel dangerous.  
  
---  
  
# PRODUCT-WIDE UX REQUIREMENTS FOR LATER GPT-5.6 SOL PHASE  
  
The complete application should follow Apple platform conventions rather than behaving like a single stretched interface running everywhere.  
  
iPhone should prioritize fast setup and monitoring.  
  
iPad should provide a richer creator workspace with touch, keyboard, pointer, and Stage Manager support.  
  
macOS should provide the most capable production environment with keyboard shortcuts, menu commands, resizable inspectors, drag-and-drop, contextual menus, multiple windows where useful, and professional workflow density.  
  
Support:  
  
- Dynamic Type  
- VoiceOver  
- Voice Control  
- Full Keyboard Access  
- Switch Control where applicable  
- Reduce Motion  
- Increase Contrast  
- Reduce Transparency  
- platform-standard focus behavior  
- localization-ready layouts  
  
Avoid tiny controls and unlabeled icon-only actions.  
  
Progressive disclosure should keep the default interface approachable while allowing substantial expert control.  
  
---  
  
# PLAYLIST UX  
  
The eventual application should make playlist construction extremely fast.  
  
Users should be able to:  
  
- drag tracks into playlists  
- multi-select  
- reorder  
- remove  
- search  
- sort  
- filter  
- inspect metadata  
- preview tracks  
- identify unavailable tracks  
- locate duplicates  
- save playlists  
- duplicate playlists  
  
Support importing compatible music from:  
  
- Apple Music/library sources  
- Spotify where permitted by Spotify's current APIs and terms  
- iCloud Drive  
- Files  
- local filesystem on macOS  
  
GPT-5.6 Sol must verify current API, DRM, playback, rebroadcast, and licensing limitations for every source rather than assuming that access to a user's library implies permission or technical ability to capture and livestream its audio.  
  
The architecture should clearly distinguish:  
  
PLAYLIST METADATA ACCESS\  
PLAYBACK ACCESS\  
RAW AUDIO ACCESS\  
AUDIO ANALYSIS ACCESS\  
REBROADCAST CAPABILITY  
  
These are not equivalent.  
  
---  
  
# ONBOARDING  
  
A new user should be capable of producing a first visualization quickly.  
  
Design a short progressive onboarding flow:  
  
CONNECT MUSIC\  
→ BUILD/SELECT PLAYLIST\  
→ CHOOSE VISUAL STYLE\  
→ PREVIEW\  
→ CONFIGURE STREAM\  
→ GO LIVE  
  
Advanced configuration should not block first success.  
  
Provide demo music or a non-streaming demonstration mode where licensing permits so users can understand the product before configuring external services.  
  
---  
  
# STREAMING UX  
  
Going live is a consequential action and must have a deliberate workflow.  
  
Before broadcast, provide a preflight check covering:  
  
- account/endpoint status  
- network connection  
- audio availability  
- video encoder  
- resolution  
- bitrate  
- frame rate  
- metadata  
- stream destination  
- estimated system load  
  
The user should see an unmistakable distinction between:  
  
OFFLINE\  
PREVIEWING\  
CONNECTING\  
LIVE\  
RECONNECTING\  
ERROR  
  
While live, expose useful health information without overwhelming the user:  
  
- elapsed broadcast time  
- connection health  
- dropped frames  
- bitrate  
- encoder performance  
- audio state  
- current song  
- upcoming song  
  
Provide automatic reconnection and meaningful recovery behavior for temporary network failure.  
  
Never allow a temporary failure to silently terminate a multi-hour channel.  
  
---  
  
# ERROR DESIGN  
  
Avoid generic errors such as:  
  
"Something went wrong."  
  
Errors should identify:  
  
WHAT HAPPENED\  
WHY, IF KNOWN\  
WHETHER DATA IS SAFE\  
WHAT THE USER CAN DO  
  
Examples:  
  
"Spotify authorization expired. Your playlist is unchanged. Reconnect Spotify to continue."  
  
"Streaming connection lost. Playback and rendering are continuing locally while reconnection is attempted."  
  
"Three tracks cannot be analyzed because their audio data is unavailable."  
  
Failure states are part of the UX.  
  
---  
  
# SESSION RECOVERY  
  
Because users may construct long playlists and visual configurations, continuously preserve recoverable state.  
  
Unexpected termination should not destroy:  
  
- playlists  
- visual settings  
- stream configuration  
- presets  
- analysis results  
  
On relaunch, offer to restore the interrupted session where appropriate.  
  
---  
  
# FIRST-RUN AUTOMATION  
  
The automatic mode should demonstrate the application's strongest capability.  
  
A user should be able to select a playlist and choose:  
  
"Generate Visual Identity"  
  
The system then:  
  
ANALYZES PLAYLIST\  
→ GENERATES VISUAL DNA\  
→ ASSIGNS/MUTATES SCENES\  
→ BUILDS TRANSITION STRATEGY\  
→ CONFIGURES EFFECT MAPPINGS\  
→ GENERATES TYPOGRAPHIC SYSTEM\  
→ CREATES PREVIEW  
  
The resulting output should already feel intentionally art-directed.  
  
Manual controls should improve or personalize it rather than rescue a weak default result.  
  
---  
  
# COMPETITIVE PRODUCT PRINCIPLE  
  
Do not merely reproduce functionality from existing visualizer, streaming, or VJ applications.  
  
Study the interaction principles behind successful tools in categories such as:  
  
- music visualizers  
- VJ software  
- broadcast software  
- live-streaming software  
- music players  
- generative-art tools  
- creative coding environments  
  
Identify where those products create unnecessary friction.  
  
The opportunity is to combine:  
  
THE SIMPLICITY OF A MUSIC PLAYER  
  
- THE VISUAL SOPHISTICATION OF GENERATIVE ART  
- THE CONTROL OF A VJ TOOL  
- THE RELIABILITY OF BROADCAST SOFTWARE  
  
without inheriting the complexity of all four.  
  
---  
  
# ASTRA DELIVERABLE  
  
For this phase, produce a detailed ASCII/ANSI Visualization System Specification containing:  
  
1. Creative vision  
2. Design principles  
3. Visual DNA architecture  
4. Audio-analysis inputs  
5. Playlist-analysis model  
6. Temporal response model  
7. Scene architecture  
8. Scene families  
9. Layer/compositing architecture  
10. ASCII/ANSI rendering methodology  
11. Glyph strategy  
12. Color system  
13. Motion system  
14. Camera system  
15. Effect library  
16. Music-to-visual mapping system  
17. Song-transition engine  
18. Metadata/title treatment  
19. Variation and anti-repetition system  
20. Automatic art-direction system  
21. Guided controls  
22. Advanced controls  
23. Preset architecture  
24. Accessibility requirements  
25. Performance considerations  
26. Proposed rendering pipeline  
27. Deterministic vs. ML-generated components  
28. Technical risks  
29. Prototype experiments required  
30. Objective criteria for determining whether the resulting visualizer is genuinely engaging rather than merely reactive  
  
For major design decisions, explain WHY the approach is preferable and identify meaningful tradeoffs.  
  
End with a concrete specification that GPT-5.6 Sol can consume directly when designing the complete application.  
  
Do not begin implementing the application.  
  
Do not expand into the complete product architecture.  
  
Your job in this phase is to design the visual engine that will become the application's defining feature.  
