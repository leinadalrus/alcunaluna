package main

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import mini "vendor:miniaudio"
import sdl "vendor:sdl3"

main :: proc() {
	fmt.println("Alcuna Luna")

	audio_spec: sdl.AudioSpec
	obtained_spec: sdl.AudioSpec
	device_id: sdl.AudioDeviceID

	engine_config: mini.engine_config = mini.engine_config_init()
	engine_config.noDevice = true
	engine_config.channels = 2
	engine_config.sampleRate = 48000

	result: mini.result = mini.engine_init(&engine_config, &app_state.audio_engine)
	if result != .SUCCESS {
		fmt.eprintln("Failed to initialise audio engine.")
		os.exit(-1)
	}

	if !sdl.Init(sdl.INIT_VIDEO) {
		fmt.eprintfln("Couldn't initialize SDL: %s", sdl.GetError())
		return
	}
	defer sdl.Quit()

	if !sdl.CreateWindowAndRenderer(
		"Alcuna Luna",
		960,
		540,
		sdl.WINDOW_RESIZABLE,
		&app_state.window,
		&app_state.renderer,
	) {
		fmt.eprintfln("Couldn't create window/renderer: %s", sdl.GetError())
		return
	}
	defer {
		sdl.DestroyRenderer(app_state.renderer)
		sdl.DestroyWindow(app_state.window)
	}
}

// Event callback functions

initialise_sound :: proc(filepath: string, sound: ^Sound, state: ^AppState) -> int {
	spec: ^sdl.AudioSpec = nil
	if spec == nil {
		spec = new(sdl.AudioSpec)
	}

	sound.sound_data = nil
	sound.sound_length = nil

	sound.audio_stream = sdl.CreateAudioStream(spec, spec)
	if &sound.audio_stream == nil {
		fmt.println("Failed to create audio stream")
		return 1
	}

	if !sdl.BindAudioStream(app_state.audio_device_id, sound.audio_stream) {
		fmt.println("Failed to bind audio stream")
		return 1
	}
	defer sdl.free(spec)

	return 0
}

form_sine_wave_yt :: proc(
	amplitude: f32,
	angular: f32,
	independent: f32,
	phase: f32,
) -> f32 {return amplitude * math.sin(angular * independent + phase)}

form_cosine_wave_xt :: proc(
	amplitude: f32,
	angular: f32,
	independent: f32,
	phase: f32,
) -> f32 {return amplitude * math.cos(angular * independent + phase)}


data_callback :: proc "c" (p_user_data: rawptr, p_buffer: rawptr, buffer_size: u32) {
	frame_buffer_size: u32 =
		buffer_size /
		mini.get_bytes_per_frame(
			mini.format.f32,
			mini.engine_get_channels(&app_state.audio_engine),
		)
	mini.engine_read_pcm_frames(
		&app_state.audio_engine,
		p_buffer,
		cast(u64)(frame_buffer_size),
		nil,
	)
}

// Data structures

app_state := AppState{} // Singleton, can turn into a Dependency Injection design-pattern later if needed
AppState :: struct {
	is_running:      i8,
	window:          ^sdl.Window,
	renderer:        ^sdl.Renderer,
	audio_device_id: sdl.AudioDeviceID,
	audio_engine:    mini.engine,
}

AudioEngine :: struct {
	trackers:  []Tracker,
	waveforms: []Waveform,
}

Waveform :: struct {
	sounds:    []Sound,
	amplitude: Amplitude,
}

Tracker :: struct {
	track: AudioTrack,
}

AudioTrack :: struct {
	clips:       [dynamic]AudioClip,
	filepath:    string,
	sample_rate: f32,
	playhead:    f32,
	channels:    u32,
	// `uint` is not an alias for `u32`
	is_playing:  int,
}

AudioClip :: struct {
	filename: string,
	samples:  []f32,
	channels: u32,
	index:    int,
}

Sound :: struct {
	sound_data:   ^u32,
	// `uintptr` is not an alias for `^u32`
	sound_length: ^u32,
	audio_stream: ^sdl.AudioStream,
}

Amplitude :: struct {
	radius: f32,
	point:  Vector2,
}

Vector2 :: struct {
	x: f32,
	y: f32,
}
