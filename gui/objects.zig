const sdl = @import("sdl_bindings");

pub const Text = struct {
    scaled_rect: sdl.rect.Frect = undefined,
    _rect: sdl.rect.Frect,
    _surface: *sdl.render.Surface,
    _scaled_surface: ?*sdl.render.Surface = null,
    _texture: ?*sdl.render.Texture = null,

    pub fn init(
        renderer: sdl.render.Renderer,
        text: [:0]const u8,
        foreground_color: sdl.C.SDL_Color,
        background_color: sdl.C.SDL_Color,
        x: f32,
        y: f32,
        pt_size: f32,
    ) !@This() {
        var font = try sdl.text.Font.load("font/Acme 9 Regular Xtnd.ttf", pt_size);
        defer font.deinit();
        var text_object = Text{
            ._surface = try sdl.text.renderText(font, text, foreground_color, background_color, .SOLID, true),
            ._rect = sdl.rect.Frect{ .x = x, .y = y, .w = undefined, .h = undefined },
        };
        text_object._rect.w = @floatFromInt(text_object._surface.w);
        text_object._rect.h = @floatFromInt(text_object._surface.h);
        try text_object.reset(renderer);
        return text_object;
    }

    pub fn deinit(self: *@This()) void {
        self._surface.deinit();
        if (self._texture != null) self._texture.?.deinit();
        self._texture = null;
    }

    pub fn reset(self: *@This(), renderer: sdl.render.Renderer) !void {
        if (self._scaled_surface != null) {
            self._scaled_surface.?.deinit();
            self._scaled_surface = null;
        }
        if (self._texture != null) {
            self._texture.?.deinit();
            self._texture = null;
        }
        self.scaled_rect = .{
            .x = self._rect.x,
            .y = self._rect.y,
            .w = self._rect.w,
            .h = self._rect.h,
        };
        self._scaled_surface = try self._surface.scaleSurface(
            @intFromFloat(@as(f32, @floatFromInt(self._surface.w))),
            @intFromFloat(@as(f32, @floatFromInt(self._surface.h))),
            .linear,
        );
        self._texture = try renderer.createTextureFromSurface(self._scaled_surface.?);
    }

    pub fn scale(self: *@This(), renderer: sdl.render.Renderer, scale_by: f32) !void {
        if (self._scaled_surface != null) {
            self._scaled_surface.?.deinit();
            self._scaled_surface = null;
        }
        if (self._texture != null) {
            self._texture.?.deinit();
            self._texture = null;
        }
        self.scaled_rect = .{
            .x = self._rect.x * scale_by,
            .y = self._rect.y * scale_by,
            .w = self._rect.w * scale_by,
            .h = self._rect.h * scale_by,
        };
        self._scaled_surface = try self._surface.scaleSurface(
            @intFromFloat(@as(f32, @floatFromInt(self._surface.w)) * scale_by),
            @intFromFloat(@as(f32, @floatFromInt(self._surface.h)) * scale_by),
            .linear,
        );
        self._texture = try renderer.createTextureFromSurface(self._scaled_surface.?);
    }

    pub fn draw(self: *@This(), renderer: sdl.render.Renderer) !void {
        if (self._texture == null) return error.TextureNotInitialised;
        try renderer.renderTexture(self._texture.?, null, &self._rect);
    }
};

pub const Button = struct {
    scaled_rect: sdl.rect.Frect = undefined,
    _rect: sdl.rect.Frect,
    _surface: *sdl.render.Surface,
    _scaled_surface: ?*sdl.render.Surface = null,
    _texture: ?*sdl.render.Texture = null,

    pub fn init(
        renderer: sdl.render.Renderer,
        text: [:0]const u8,
        text_color: sdl.C.SDL_Color,
        button_color: sdl.C.SDL_Color,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        pt_size: f32,
    ) !@This() {
        var font = try sdl.text.Font.load("font/Acme 9 Regular Xtnd.ttf", pt_size);
        defer font.deinit();
        const tmp_text = try sdl.text.renderText(font, text, text_color, undefined, .SOLID, true);
        defer tmp_text.deinit();
        var button_object = Button{
            ._rect = .{ .x = x, .y = y, .w = undefined, .h = undefined },
            ._surface = try sdl.render.Surface.init(@intFromFloat(w), @intFromFloat(h), .rgb24),
        };
        try button_object._surface.clearSurface(.{
            .r = @as(f32, @floatFromInt(button_color.r)) / 255,
            .g = @as(f32, @floatFromInt(button_color.g)) / 255,
            .b = @as(f32, @floatFromInt(button_color.b)) / 255,
            .a = @as(f32, @floatFromInt(button_color.a)) / 255,
        });
        try button_object._surface.blitSurface(tmp_text, 10, 5);
        var tmp_rect = sdl.rect.Irect{ .x = 0, .y = 0, .w = @intFromFloat(w), .h = @intFromFloat(h) };
        try button_object._surface.blitRect(
            &tmp_rect,
            .{ .r = button_color.r - 10, .g = button_color.g - 10, .b = button_color.b - 10, .a = button_color.a },
        );
        button_object._rect.w = @floatFromInt(button_object._surface.w);
        button_object._rect.h = @floatFromInt(button_object._surface.h);
        try button_object.reset(renderer);
        return button_object;
    }

    pub fn deinit(self: *@This()) void {
        self._surface.deinit();
        if (self._texture != null) self._texture.?.deinit();
        self._texture = null;
    }

    pub fn reset(self: *@This(), renderer: sdl.render.Renderer) !void {
        if (self._scaled_surface != null) {
            self._scaled_surface.?.deinit();
            self._scaled_surface = null;
        }
        if (self._texture != null) {
            self._texture.?.deinit();
            self._texture = null;
        }
        self.scaled_rect = .{
            .x = self._rect.x,
            .y = self._rect.y,
            .w = self._rect.w,
            .h = self._rect.h,
        };
        self._scaled_surface = try self._surface.scaleSurface(
            @intFromFloat(@as(f32, @floatFromInt(self._surface.w))),
            @intFromFloat(@as(f32, @floatFromInt(self._surface.h))),
            .linear,
        );
        self._texture = try renderer.createTextureFromSurface(self._scaled_surface.?);
    }

    pub fn scale(self: *@This(), renderer: sdl.render.Renderer, scale_by: f32) !void {
        if (self._scaled_surface != null) {
            self._scaled_surface.?.deinit();
            self._scaled_surface = null;
        }
        if (self._texture != null) {
            self._texture.?.deinit();
            self._texture = null;
        }
        self.scaled_rect = .{
            .x = self._rect.x * scale_by,
            .y = self._rect.y * scale_by,
            .w = self._rect.w * scale_by,
            .h = self._rect.h * scale_by,
        };
        self._scaled_surface = try self._surface.scaleSurface(
            @intFromFloat(@as(f32, @floatFromInt(self._surface.w)) * scale_by),
            @intFromFloat(@as(f32, @floatFromInt(self._surface.h)) * scale_by),
            .linear,
        );
        self._texture = try renderer.createTextureFromSurface(self._scaled_surface.?);
    }

    pub fn draw(self: *@This(), renderer: sdl.render.Renderer) !void {
        if (self._texture == null) return error._TextureNotInitialised;
        try renderer.renderTexture(self._texture.?, null, &self.scaled_rect);
    }
};
