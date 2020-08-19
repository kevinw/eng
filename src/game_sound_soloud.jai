#import "soloud";

Voice_Handle :: u32; // TODO: this should probably be handled better by the soloud bindings

Sound_State :: struct {
    soloud: *Soloud;
    fx: struct {
        footstep1: *Wav;
        footstep2: *Wav;
        chomp: *Wav;
    };

    bgm: *WavStream;
    bgm_voice: Voice_Handle;
};


#scope_file
create_and_load_wav :: (filename: *u8) -> *Wav {
    wav := Wav_create();
    assert(wav != null);

    res := Wav_load(wav, filename);
    assert(res == 0);

    return wav;
}

create_and_load_wavstream :: (filename: *u8) -> *WavStream {
    wavstream := WavStream_create();
    assert(wavstream != null);

    res := WavStream_load(wavstream, filename);
    assert(res == 0);
    
    return wavstream;
}
#scope_module

sound_init :: (using state: *Sound_State) {
    soloud =  Soloud_create();
    assert(soloud != null);

    Soloud_init(soloud, SOLOUD_CLIP_ROUNDOFF);

    fx.footstep1 = create_and_load_wav("resources/sfx/footsteps/wood1.wav");
    fx.footstep2 = create_and_load_wav("resources/sfx/footsteps/wood2.wav");
    fx.chomp     = create_and_load_wav("resources/sfx/521253__maugusto-sfx__eatingsfx.wav");
    bgm          = create_and_load_wavstream("resources/music/Jivasifoki.mp3");

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
    #if SOUND_ENABLED
        Soloud_update3dAudio(soloud);
}