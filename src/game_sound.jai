#import "Sound_Player";
#import "File";
#import "Random";

load_audio_file :: (name: string) -> *Mixer_Sound_Data {
    data : *Mixer_Sound_Data = null;

    file_data, success := read_entire_file(name);
    if !success return data;

    data = New(Mixer_Sound_Data);
    data.name = copy_string(name);
    data.buffer = file_data;
    data.type = Mixer_Sound_Data.Type.OGG_COMPRESSED;
    return data;
}

Sound_State :: struct {
    sound_player: *Sound_Player;

    fx: struct {
        footstep1: *Mixer_Sound_Data;
        footstep2: *Mixer_Sound_Data;
    };
};

sound_init :: (using state: *Sound_State) {
    window := GetWindowHandle();
    success := init(sound_player, window, true, true);
    assert(success, "did not initialize sound player");
}

sound_deinit :: (using state: *Sound_State) {
}

sound_update :: (using state: *Sound_State) {
}

//play_sound(game.arrow_sound, perturb=true, volume=0.2);

/*
        stream := play_sound(ambience, false);
        stream.flags |= stream.REPEATING;
        stream.user_volume_scale = 0.5;
*/

play_sound :: (using state: *Sound_State, data: *Mixer_Sound_Data, perturb: bool = true, volume := 0.7) -> *Sound_Stream {
    stream := make_stream(sound_player, data);
    assert(stream != null);

    if stream {
        stream.sound_data = data;
        num_source_samples: s64 = data.nsamples_times_nchannels / data.nchannels;
        stream.repeat_end_position = num_source_samples;
        stream.user_volume_scale = volume;
    }

    if perturb && stream {
        stream.user_volume_scale = random_get_within_range(volume, volume + 0.2);
        stream.desired_rate = random_get_within_range(0.7, 1.22);
    }
    
    return stream;
}
