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

data_callback :: proc "c" (device: ^mini.device, output, input: rawptr, frame_count: u32) {
	decoder := (^mini.decoder)(device.pUserData)
	if decoder == nil {
		return
	}

	mini.decoder_read_pcm_frames(decoder, output, u64(frame_count), nil)
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
