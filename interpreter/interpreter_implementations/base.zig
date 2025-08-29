pub const ExtraWork = enum(u8) {
    match_window_to_resolution,
    resolution_changed,
    update_screen,
    exit,
};
