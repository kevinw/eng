TODO_beats :: () {
    // Update beats
    if false  && nearest_marker != null {
        time_since_marker := beat_timer - context.state.nearest_marker.time;
        alpha := max(cast(float64)0.0, 1.0 - Math.abs(time_since_marker));
        color := Vector4.{1, 1, 1, 1};
        if time_since_marker < 0 color = Vector4.{0, 0, 0, 1};
        color.w = cast(float32)alpha;
        draw_text(tprint("%", nearest_marker.beat_type), 596, 5, 20, ColorFromNormalized(color));
    }
}
