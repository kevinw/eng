
#scope_module
#import "Basic";
#import "soloud";
#import "toolbelt";
#scope_export

Voice_Handle :: u32; // TODO: this should probably be an actual type in the Soloud bindings

Sound_State :: struct {
    soloud: *Soloud;
    fx: struct {
        footstep1,
        footstep2,
        chomp,
        sword_swing,
        whack,
        landing
        : *Wav;
    };
    bgm: *WavStream;
    bgm_voice: Voice_Handle;
};

soloud_state :: inline () -> *Soloud { return context.state.sound_state.soloud; }

set_volume :: (voice_handle: Voice_Handle, volume: float) {
    Soloud_setVolume(soloud_state(), voice_handle, volume);
}

seek :: (voice_handle: Voice_Handle, time_seconds: float64) {
    Soloud_seek(soloud_state(), voice_handle, time_seconds);
}

get_stream_time :: (voice_handle: Voice_Handle) -> float64 {
    return Soloud_getStreamTime(soloud_state(), voice_handle);
}

play_sound :: (wav: *Wav, volume := 1.0) {
    Soloud_play(soloud_state(), wav, volume);
}

play_sfx :: ($name: string) {
    wav := get_field_value(*context.state.sound_state.fx, name, *Wav);
    Soloud_play(soloud_state(), wav);
}

sound_init :: (using state: *Sound_State) {
    soloud =  Soloud_create();
    assert(soloud != null);

    Soloud_init(soloud, SOLOUD_CLIP_ROUNDOFF);

    fx.footstep1   = create_and_load_wav("resources/sfx/footsteps/wood1.wav");
    fx.footstep2   = create_and_load_wav("resources/sfx/footsteps/wood2.wav");
    fx.chomp       = create_and_load_wav("resources/sfx/521253__maugusto-sfx__eatingsfx.wav");
    fx.sword_swing = create_and_load_wav("resources/sfx/sword_swing.wav", 0.4);
    fx.whack       = create_and_load_wav("resources/sfx/whack.mp3", 0.4);
    fx.landing     = create_and_load_wav("resources/sfx/landing.wav", 0.3);
    bgm            = create_and_load_wavstream("resources/music/Jivasifoki.mp3");

    WavStream_setLooping(bgm, xx true);
    WavStream_setVolume(bgm, 0.1);

    // TODO delete the sfx

    Soloud_set3dListenerUp(soloud, 0, 1, 0); // for a 2D game, we'll just use a basic unchanging up vector

    bgm_voice = Soloud_play(soloud, bgm);
}

sound_deinit :: (using state: *Sound_State) {
    Soloud_deinit(soloud);
    Soloud_destroy(soloud);
}

sound_update :: (using state: *Sound_State) {
    Soloud_update3dAudio(soloud);
}

#scope_file
create_and_load_wav :: (filename: *u8, volume:float = -1.0) -> *Wav {
    wav := Wav_create();
    assert(wav != null);

    res := Wav_load(wav, filename);
    assert(res == 0);

    if volume != -1.0
        Wav_setVolume(wav, volume);

    return wav;
}

create_and_load_wavstream :: (filename: *u8) -> *WavStream {
    wavstream := WavStream_create();
    assert(wavstream != null);

    res := WavStream_load(wavstream, filename);
    assert(res == 0);
    
    return wavstream;
}
