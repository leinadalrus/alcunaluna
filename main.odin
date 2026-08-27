package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import micro "vendor:microui"
import mini "vendor:miniaudio"
import sdl "vendor:sdl3"

main :: proc() {
	fmt.println("Alcuna Luna")

	arguments := runtime.args__
	if len(arguments) < 2 {
		fmt.eprintln("No input file ...")
		os.exit(-1)
	}

	decoder: mini.decoder
	result := mini.decoder_init_file(arguments[1], nil, &decoder)
	if result != .SUCCESS {
		fmt.eprintln("Could not load file: %s", arguments[1])
		os.exit(-2)
	}

	device_config := mini.device_config_init(.playback)
	device_config.playback.format = decoder.outputFormat
	device_config.playback.channels = decoder.outputChannels
	device_config.sampleRate = decoder.outputSampleRate
	device_config.dataCallback = data_callback
	device_config.pUserData = &decoder

	device: mini.device
	if mini.device_init(nil, &device_config, &device) != .SUCCESS {
		fmt.eprintln("Failed to open playback device.")
		mini.decoder_uninit(&decoder)
		os.exit(-3)
	}

	if mini.device_start(&device) != .SUCCESS {
		fmt.eprintln("Failed to start playback device.")
		mini.device_uninit(&device)
		mini.decoder_uninit(&decoder)
		os.exit(-4)
	}

	mini.device_uninit(&device)
	mini.decoder_uninit(&decoder)
}

// Event callback functions

initialise_sound :: proc(filepath: string, sound: ^Sound, state: ^AppState) -> int {
	spec: ^sdl.AudioSpec = nil
	if spec == nil {
		spec = new(sdl.AudioSpec)
	}

	sound.sound_data = nil
	sound.sound_length = nil

	sound.audio_stream = sdl.CreateAudioStream(spec, spec)^
	if &sound.audio_stream == nil {
		fmt.println("Failed to create audio stream")
		return 1
	}

	if !sdl.BindAudioStream(app_state.audio_device_id, &sound.audio_stream) {
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


data_callback :: proc "c" (device: ^mini.device, output, input: rawptr, frame_count: u32) {
	decoder := (^mini.decoder)(device.pUserData)
	if decoder == nil {
		return
	}

	mini.decoder_read_pcm_frames(decoder, output, u64(frame_count), nil)
}

// Data structures

app_state := AppState{} // Singleton, can turn into a Dependency Injection design-pattern later if needed
AppState :: struct {
	is_running:      i8,
	window:          ^sdl.Window,
	renderer:        ^sdl.Renderer,
	audio_device_id: sdl.AudioDeviceID,
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
