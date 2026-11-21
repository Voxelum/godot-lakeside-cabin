# Courier

Original woodland postal mapmaker, built from editable Godot mesh instances and named material subresources in `Courier.tscn`. Model origin is ground-centered, forward is local +Z, and the neutral crown is approximately 1.83 m above the soles. Instance the scene as a visual child; it owns no collider or movement input. Anonymous materials in the inspector correspond to the named tscn IDs.

- `pose_world(direction: Vector3, horizontal_distance: float, dt: float)` takes a world XZ heading, the actual horizontal travel since the previous call (meters), and elapsed seconds. Call after applying movement. Zero heading keeps previous facing. Call with zero distance during idle to retain breath and blink.
- `reset_pose(direction: Vector3)` immediately faces the supplied world heading and plants the neutral stance; call after arrival/teleport.
- Left telemetry: `Facing/Hips/ThighL/CalfL/BootL/{HeelContact,ToeContact}`. Right: `Facing/Hips/ThighR/CalfR/BootR/{HeelContact,ToeContact}`. `CalfL/R.rotation.x` is knee flexion in radians. `BootL/R.rotation.x` is relative to the calf; use the composed basis for sole pitch.
- Analytic sagittal IK follows a distance-driven 1.24 m cycle, with 60% stance. Heel and toe rock over a held support point; the swing uses a Hermite fore/aft path and sine-squared lift. On stop, the current stagger is retained as the lifted foot settles, instead of sliding both feet back to the neutral pose. Startup blends over the first 0.20 m. Exact contact lock applies to steady straight-line travel, not to turns or the startup blend.

## Isolated headless check

Copy this directory into `art/courier` in a scratch Godot project (`project.godot` can contain only `config_version=5`), then run `godot --headless --path <scratch> --script res://art/courier/VerifyCourier.gd`. The script instances the actual scene, checks immediate ±Z facing, advances it 1 mm per sample in +Z, then measures global toe/heel markers and left knee flexion after startup over nearly two full cycles; it also checks return to grounded idle. On Godot 4.7.2 the measured peak knee was 84.456°, the peak lift of the lower sole edge was 0.172 m, the floor minimum and incremental straight-line stance slip rounded to 0.000000 m, and the maximum incremental toe displacement was 0.003750 m. Headless checks do not establish graphical readability at either camera size.
