pub const ExtraWork = enum(u8) {
    toggle_window_size_lock,
    match_window_to_resolution,
    resolution_changed,
    update_screen,
    exit,
};
