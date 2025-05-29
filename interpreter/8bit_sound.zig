const std = @import("std");
const C = @import("sdl_bindings").C;

pub const AudioStream = struct {
    sdl: *C.SDL_AudioStream = undefined,
    wav_spec: C.SDL_AudioSpec = undefined,
    wav_buf: [*c]u8 = undefined,
    wav_data_len: u32 = undefined,

    pub fn init() !@This() {
        var stream = AudioStream{};
        if (!C.SDL_LoadWAV("beep.wav", &stream.wav_spec, &stream.wav_buf, &stream.wav_data_len)) return error.CouldntLoadWavFile;
        if (C.SDL_OpenAudioDeviceStream(C.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &stream.wav_spec, null, null)) |val| {
            stream.sdl = val;
        } else return error.CouldntOpenAudioDeviceStream;
        if (!C.SDL_ResumeAudioStreamDevice(stream.sdl)) return error.CouldntResumeAudioStreamDevice;
        return stream;
    }

    pub fn deinit(self: *@This()) void {
        C.SDL_DestroyAudioStream(self.sdl);
        C.SDL_free(self.wav_buf);
    }

    /// Deallocates all allocated memory before returning
    pub fn play_sound(self: *@This(), allocator: std.mem.Allocator, volume: u8) !void {
        if (C.SDL_GetAudioStreamQueued(self.sdl) >= self.wav_data_len) {
            return;
        }
        const samples = try allocator.alloc(u8, self.wav_data_len);
        defer allocator.free(samples);
        if (!C.SDL_MixAudio(@ptrCast(samples), self.wav_buf, self.wav_spec.format, self.wav_data_len, @as(f32, @floatFromInt(volume)) / 255.0)) return error.CouldnMixAudio;
        if (!C.SDL_PutAudioStreamData(self.sdl, @ptrCast(samples), @as(i32, @bitCast(self.wav_data_len)))) return error.CouldntPutAudioStreamData;
    }
};
