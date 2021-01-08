#import "config";
#import "Text_File_Handler";
#import "Basic";
#import "String";
Math :: #import "Math";
screenlog :: #import "screenlog";

Beat_Type :: enum {
    Kick;
    Snare;
}

Marker :: struct {
    beat_type: Beat_Type;
    time: float64;
}

Song :: struct {
    Type :: enum {
        Explicit_Markers :: 0;
        Tempo :: 1;
    };

    type: Type;
    markers: []Marker;

    beats_per_minute: float;
    bpm_marker: Marker;
}

LATENCY_ADJUSTMENT := 0.25;

get_nearest_marker :: (using song: Song, last_marker: *Marker, time: float64) -> (marker: *Marker) {
    time += LATENCY_ADJUSTMENT;

    if song.type == .Tempo {
        beats_per_second := beats_per_minute * (1.0 / 60.0);
        beat := time / beats_per_second;
        fraction := Math.fmod(beat, 1.0);
        beat_int:int = cast(int)beat + (ifx fraction >= 0.5 then 1 else 0);
        bpm_marker.beat_type = ifx beat_int % 2 == 0 then Beat_Type.Kick else Beat_Type.Snare;
        bpm_marker.time = cast(float64)(beat_int) * beats_per_second;

        return *bpm_marker;
    } else {
        // TODO: actually use last_marker
        if last_marker != null {
            assert(last_marker >= *markers[0]);
            assert(last_marker <= *markers[markers.count - 1]);
        }

        for * after, n: markers {
            if after.time <= time continue;

            if n == 0 return after;
            before := *markers[n - 1];

            if Math.abs(after.time - time) > Math.abs(before.time - time)
                return after;
            else
                return before;
        }

        return *markers[markers.count - 1];
    }
}

most_recent_marker :: (using song: Song, time: float64) -> (found: bool, marker: *Marker) {
    if song.type == .Tempo 
        return false, null;

    // TODO: remember the last one. then we can just wait for the next one. this
    // shouldn't be a linear search :)
    for it, n: markers {
        if it.time <= time continue;
        if n == 0 return false, null;
        else return true, *markers[n - 1];
    }
    return false, null;
}

create_song_for_tempo :: (bpm: float) -> (bool, Song) {
    song: Song = .{ type = .Tempo };
    song.beats_per_minute = bpm;
    return true, song;
}

parse_reaper_project_file :: (filename: string) -> (bool, Song) {
    handler: Text_File_Handler;
    handler.do_version_number = false;
    handler.strip_comments_from_ends_of_lines;
    defer deinit(*handler);

    start_file(*handler, "rpp", filename, "rpp parsing", optional=false);
    if handler.failed {
        Log.error();
        Log.print("could not open '%' for parsing\n", filename);
        return false, .{};
    }

    markers: [..]Marker;
    for line: *handler {
        marker_str :: "MARKER ";
        if !begins_with(line, marker_str) continue;

        advance(*line, marker_str.count);
        n_str, rest, time_str, name: string;
        n_str, rest = break_by_spaces(line);
        time_str, rest = break_by_spaces(rest);
        name, rest = break_by_spaces(rest);

        n, n_ok := string_to_int(n_str);
        assert(n_ok, "could not turn '%' into an int", n_str);
        time, time_ok := string_to_float(time_str);
        assert(time_ok);

        marker: Marker;
        if name == {
            case "snare"; marker.beat_type = .Snare;
            case "kick";  marker.beat_type = .Kick;
            case; assert(false);
        }
        marker.time = time;
        array_add(*markers, marker);
    }

    song: Song;
    song.type = .Explicit_Markers;
    song.markers = markers;
    return true, song;
}

