#import "config";
#import "Text_File_Handler";
#import "Basic";
#import "String";

Beat_Type :: enum {
    Kick;
    Snare;
}

Marker :: struct {
    beat_type: Beat_Type;
    time: float64;
}

most_recent_marker :: (markers: []Marker, time: float64) -> (found: bool, marker: *Marker) {
    for it, n: markers {
        if it.time <= time continue;
        if n == 0
            return false, null;
        else
            return true, *markers[n - 1];
    }

    return false, null;
}

parse_reaper_project_file :: (filename: string) -> []Marker {
    handler: Text_File_Handler;
    handler.do_version_number = false;
    handler.strip_comments_from_ends_of_lines;
    defer deinit(*handler);

    start_file(*handler, "rpp", filename, "rpp parsing", optional=false);
    if handler.failed {
        Log.error();
        Log.print("could not open '%' for parsing\n", filename);
        assert(false);
        return .[];
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

    return markers;
}

