#import "config";
#import "Text_File_Handler";
#import "Basic";
#import "String";
Math :: #import "Math";

Beat_Type :: enum {
    Kick;
    Snare;
}

Marker :: struct {
    beat_type: Beat_Type;
    time: float64;
}

get_nearest_marker :: (markers: []Marker, last_marker: *Marker, time: float64) -> (marker: *Marker) {
    // TODO: use last_marker
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

most_recent_marker :: (markers: []Marker, time: float64) -> (found: bool, marker: *Marker) {
    // TODO: remember the last one. then we can just wait for the next one. this
    // shouldn't be a linear search :)
    for it, n: markers {
        if it.time <= time continue;
        if n == 0 return false, null;
        else return true, *markers[n - 1];
    }
    return false, null;
}

parse_reaper_project_file :: (filename: string) -> (bool, []Marker) {
    handler: Text_File_Handler;
    handler.do_version_number = false;
    handler.strip_comments_from_ends_of_lines;
    defer deinit(*handler);

    start_file(*handler, "rpp", filename, "rpp parsing", optional=false);
    if handler.failed {
        Log.error();
        Log.print("could not open '%' for parsing\n", filename);
        return false, .[];
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
        assert(n_ok, tprint("could not turn '%' into an int", n_str));
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

    return true, markers;
}

