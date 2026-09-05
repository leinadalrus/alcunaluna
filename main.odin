package main

import "core:fmt"
import "core:math"
import mini "vendor:miniaudio"
import sdl "vendor:sdl3"

CHANNELS :: 2
SAMPLE_RATE :: 48000

main :: proc() {
	fmt.println("Alcuna Luna")

	desired_spec: sdl.AudioSpec
	obtained_spec: sdl.AudioSpec
	device_id: sdl.AudioDeviceID

	engine_config: mini.engine_config = mini.engine_config_init()
	engine_config.noDevice = false
	engine_config.channels = CHANNELS
	engine_config.sampleRate = SAMPLE_RATE

	result: mini.result = mini.engine_init(&engine_config, &app_state.audio_engine)
	if result != .SUCCESS {
		panic("Failed to initialise audio engine.")
	}
	defer mini.engine_uninit(&app_state.audio_engine)

	if !sdl.InitSubSystem(sdl.INIT_AUDIO) {
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
