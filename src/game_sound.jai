#import "soloud";

Voice_Handle :: u32; // TODO: this should probably be handled better by the soloud bindings

Sound_State :: struct {
    soloud: *Soloud;
    fx: struct {
        footstep1: *Wav;
        footstep2: *Wav;
    };

    bgm: *WavStream;
    bgm_voice: Voice_Handle;
};

sound_init :: (using state: *Sound_State) {
    soloud =  Soloud_create();
    Soloud_init(soloud, SOLOUD_CLIP_ROUNDOFF);

    res: s32;

    fx.footstep1 = Wav_create();
    res = Wav_load(fx.footstep1, "resources/sfx/footsteps/wood1.wav");
    assert(res == 0);

    fx.footstep2 = Wav_create();
    res = Wav_load(fx.footstep2, "resources/sfx/footsteps/wood2.wav");
    assert(res == 0);

    bgm = WavStream_create();
    res = WavStream_load(bgm, "resources/music/Jivasifoki.mp3");
    WavStream_setLooping(bgm, xx true);
    assert(res == 0);
    // TODO delete

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