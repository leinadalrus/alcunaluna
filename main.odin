package main

import "core:fmt"
import "core:math"
import mini "vendor:miniaudio"
import sdl "vendor:sdl3"

CHANNELS :: 2
SAMPLE_RATE :: 48000

main :: proc() {
	fmt.println("Alcuna Luna")

	if !sdl.Init(sdl.INIT_VIDEO) {
		fmt.eprintfln("Couldn't initialise video: %s", sdl.GetError())
		panic("Failed to initialise SDL video.")
	}
	defer sdl.Quit()

	if !sdl.CreateWindowAndRenderer(
		"Alcuna Luna: waveform hybrid tracker",
		800,
		600,
		sdl.WINDOW_RESIZABLE,
		&app_state.window,
		&app_state.renderer,
	) {
		fmt.eprintfln("Couldn't create window/renderer: %s", sdl.GetError())
		panic("Couldn't create window/renderer.")
	}
	defer {
		sdl.DestroyRenderer(app_state.renderer)
		sdl.DestroyWindow(app_state.window)
	}

	if !sdl.SetRenderVSync(app_state.renderer, 1) {
		fmt.eprintfln("Couldn't set render vsync: %s", sdl.GetError())
		panic("Failed to set Render V-Sync.")
	}

	desired_spec: sdl.AudioSpec
	obtained_spec: sdl.AudioSpec
	device_id: sdl.AudioDeviceID

	engine_config: mini.engine_config = mini.engine_config_init()
	engine_config.noDevice = false
	engine_config.channels = CHANNELS
	engine_config.sampleRate = SAMPLE_RATE

	result: mini.result = mini.engine_init(&engine_config, &app_state.audio_engine)
	if result != .SUCCESS {
		fmt.eprintfln("Failed to initialise audio engine: %s", sdl.GetError())
		panic("Failed to initialise audio engine.")
	}
	defer mini.engine_uninit(&app_state.audio_engine)

	if !sdl.InitSubSystem(sdl.INIT_AUDIO) {
		fmt.eprintfln("Failed to initialise SDL audio subsystem: %s", sdl.GetError())
		panic("Failed to initialise SDL audio subsystem.")
	}
	defer sdl.QuitSubSystem(sdl.INIT_AUDIO)

	desired_sample_rate := mini.engine_get_sample_rate(&app_state.audio_engine)
	desired_spec.freq = cast(i32)desired_sample_rate
	desired_spec.format = .F32

	desired_channels := mini.engine_get_channels(&app_state.audio_engine)
	desired_spec.channels = cast(i32)desired_channels

	device_id = sdl.OpenAudioDevice(device_id, &desired_spec)
	if device_id == 0 {
		fmt.eprintfln("Failed to open audio device: %s", sdl.GetError())
		panic("Failed to open audio device.")
	}
	defer sdl.CloseAudioDevice(device_id)
	sdl.PauseAudioDevice(device_id)

	// Game update loop

	for {}
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

draw_waveform :: proc(clip: AudioClip) {
	audio_instance: AudioClipInstance = AudioClipInstance {
		x = 0,
		y = 0,
		w = 0,
		h = 0,
	}
	render_waveform(
		app_state.renderer,
		clip,
		audio_instance.x,
		audio_instance.y,
		audio_instance.w,
		audio_instance.h,
	)
	reposition_waveform(clip, audio_instance.x, audio_instance.y)
	resize_waveform(clip, audio_instance.w, audio_instance.h)
}

resize_waveform :: proc(clip: AudioClip, w: int, h: int) {}

reposition_waveform :: proc(clip: AudioClip, x: int, y: int) {}

render_waveform :: proc(
	renderer: ^sdl.Renderer,
	clip: AudioClip,
	x: int,
	y: int,
	w: int,
	h: int,
) {}

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

mix_audio :: proc(output: []f32, dt_samples: int, tracker_state: ^TrackerState) {}

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

TrackerState :: struct {
	tracks:     [dynamic]AudioTrack,
	tempo:      f32, // BPM (Beats Per Minute)
	playhead:   f64, // sample position within the track
	is_playing: int,
}

Tracker :: struct {
	track: AudioTrack,
}

AudioTrack :: struct {
	clips:    [dynamic]AudioClip,
	filepath: string,
	name:     string,
	mute:     int,
	solo:     int,
	gain:     f32,
}

AudioClip :: struct {
	filename:    string,
	name:        string,
	samples:     []f32,
	// `uint` is not an alias for `u32`
	sample_rate: u32,
	channels:    u32,
	start_tick:  u64,
	gain:        f32,
	pan:         f32, // -1.0 (left) to 1.0 (right)
	pitch:       f32,
	looped:      i8, // Do not use booleans to represent data
}

AudioClipInstance :: struct {
	w: int,
	h: int,
	x: int,
	y: int,
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
