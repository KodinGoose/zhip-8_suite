const std = @import("std");
const C = @import("c.zig").C;
const rect = @import("rect.zig");
const point = @import("point.zig");

pub const WindowFlags = packed struct {
    fullsceen: bool = false,
    opengl: bool = false,
    occluded: bool = false,
    hidden: bool = false,
    borderless: bool = false,
    resizable: bool = false,
    minimized: bool = false,
    maximized: bool = false,
    mouse_grabbed: bool = false,
    input_focus: bool = false,
    mouse_focus: bool = false,
    external: bool = false,
    modal: bool = false,
    high_pixel_fidelity: bool = false,
    mouse_capture: bool = false,
    mouse_relative_mode: bool = false,
    always_on_top: bool = false,
    utility: bool = false,
    tooltip: bool = false,
    popup_menu: bool = false,
    keyboard_grabbed: bool = false,
    padding1: u7 = 0,
    vulkan: bool = false,
    metal: bool = false,
    transparent: bool = false,
    not_focusable: bool = false,
    padding2: u32 = 0,

    pub fn toSDL(self: WindowFlags) C.SDL_WindowFlags {
        return @bitCast(self);
    }

    pub fn fromSDL(flags: C.SDL_WindowFlags) WindowFlags {
        return @bitCast(flags);
    }
};

pub const Window = struct {
    sdl: *C.SDL_Window,

    pub fn init(title: [*:0]const u8, w: i32, h: i32, flags: WindowFlags) !Window {
        return .{ .sdl = C.SDL_CreateWindow(title, w, h, flags.toSDL()) orelse return error.CouldntCreateWindow };
    }

    pub fn deinit(self: Window) void {
        C.SDL_DestroyWindow(self.sdl);
    }

    pub const WinSize = struct { width: i32, height: i32 };

    pub fn getWinSize(self: Window) !WinSize {
        var width: i32 = 0;
        var height: i32 = 0;
        const err = !C.SDL_GetWindowSizeInPixels(self.sdl, &width, &height);
        if (err) return error.CouldntGetWindowSize;
        return .{ .width = width, .height = height };
    }

    pub fn setWinSize(self: Window, width: i32, height: i32) !void {
        if (!C.SDL_SetWindowSize(self.sdl, width, height)) return error.CouldntSetWindowSize;
    }

    pub fn toggleFullscreen(self: Window) !void {
        const flags = WindowFlags.fromSDL(C.SDL_GetWindowFlags(self.sdl));
        const err = !C.SDL_SetWindowFullscreen(self.sdl, !flags.fullsceen);
        if (err) return error.CouldntToggleWindowFullscreen;
    }

    /// Only returns error on timeout
    /// TODO: Utilizes workaround to work around some systems being too slow and timing out
    /// This is a known issue and is set to be resolved by sdl v3.4.0 as of writing
    pub fn sync(self: Window) !void {
        var err: bool = undefined;
        for (0..5) |_| {
            err = !C.SDL_SyncWindow(self.sdl);
            if (!err) return;
        }
        return error.CouldntSyncWindow;
    }
};

/// TODO: Finish this shit (2025.02.04)
pub const PixelFormat = enum(u32) {
    unknown = C.SDL_PIXELFORMAT_UNKNOWN,
    index1_lsb = C.SDL_PIXELFORMAT_INDEX1LSB,
    index1_msb = C.SDL_PIXELFORMAT_INDEX1MSB,
    index2_lsb = C.SDL_PIXELFORMAT_INDEX2LSB,
    index2_msb = C.SDL_PIXELFORMAT_INDEX2MSB,
    index4_lsb = C.SDL_PIXELFORMAT_INDEX4LSB,
    index4_msb = C.SDL_PIXELFORMAT_INDEX4MSB,
    index8 = C.SDL_PIXELFORMAT_INDEX8,
    rgb332 = C.SDL_PIXELFORMAT_RGB332,
    xrgb4444 = C.SDL_PIXELFORMAT_XRGB4444,
    xbgr4444 = C.SDL_PIXELFORMAT_XBGR4444,
    xrgb1555 = C.SDL_PIXELFORMAT_XRGB1555,
    xbgr1555 = C.SDL_PIXELFORMAT_XBGR1555,
    argb4444 = C.SDL_PIXELFORMAT_ARGB4444,
    rgba4444 = C.SDL_PIXELFORMAT_RGBA4444,
    abgr4444 = C.SDL_PIXELFORMAT_ABGR4444,
    bgra4444 = C.SDL_PIXELFORMAT_BGRA4444,
    argb1555 = C.SDL_PIXELFORMAT_ARGB1555,
    rgba5551 = C.SDL_PIXELFORMAT_RGBA5551,
    abgr1555 = C.SDL_PIXELFORMAT_ABGR1555,
    bgra5551 = C.SDL_PIXELFORMAT_BGRA5551,
    rgb565 = C.SDL_PIXELFORMAT_RGB565,
    bgr565 = C.SDL_PIXELFORMAT_BGR565,
    rgb24 = C.SDL_PIXELFORMAT_RGB24,
    bgr24 = C.SDL_PIXELFORMAT_BGR24,
    xrgb8888 = C.SDL_PIXELFORMAT_XRGB8888,
    rgbx8888 = C.SDL_PIXELFORMAT_RGBX8888,
    xbgr8888 = C.SDL_PIXELFORMAT_XBGR8888,
    bgrx8888 = C.SDL_PIXELFORMAT_BGRX8888,
    argb8888 = C.SDL_PIXELFORMAT_ARGB8888,
    rgba8888 = C.SDL_PIXELFORMAT_RGBA8888,
    abgr8888 = C.SDL_PIXELFORMAT_ABGR8888,
    bgra8888 = C.SDL_PIXELFORMAT_BGRA8888,

    pub fn toSDL(self: PixelFormat) C.SDL_PixelFormat {
        return @intFromEnum(self);
    }
};

pub const Pixel = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const ScaleMode = enum(i32) {
    /// Nearest pixel sampling
    nearest = C.SDL_SCALEMODE_NEAREST,
    /// Linear Filtering
    linear = C.SDL_SCALEMODE_LINEAR,

    pub fn toSDL(self: ScaleMode) C.SDL_ScaleMode {
        return @intFromEnum(self);
    }
};

pub const SurfaceFlags = packed struct {
    preallocated: bool = false,
    lock_needed: bool = false,
    locked: bool = false,
    simd_aligned: bool = false,
    _padding: u28 = 0,
};

pub const Surface = extern struct {
    flags: SurfaceFlags,
    format: PixelFormat,
    w: i32,
    h: i32,
    pitch: i32,
    pixels: ?*anyopaque,
    refcount: i32,
    reserved: ?*anyopaque,

    pub fn init(w: i32, h: i32, format: PixelFormat) !*Surface {
        const ret = C.SDL_CreateSurface(w, h, format.toSDL());
        if (ret == null) return error.CouldntInitializeSurface;
        return @ptrCast(ret);
    }

    /// Creates an exact copy of self
    pub fn copy(self: *Surface) !*Surface {
        const ret = C.SDL_DuplicateSurface(self.toSDL());
        if (ret == null) return error.CouldntCopySurface;
        return @ptrCast(ret);
    }

    pub fn deinit(self: *Surface) void {
        C.SDL_DestroySurface(self.toSDL());
    }

    pub fn toSDL(self: *Surface) *C.SDL_Surface {
        return @ptrCast(self);
    }

    pub fn fromSDL(surface: *C.SDL_Surface) *Surface {
        return @ptrCast(surface);
    }

    pub fn getFormatDetails(self: @This()) !*const C.SDL_PixelFormatDetails {
        const format_details = C.SDL_GetPixelFormatDetails(self.format.toSDL());
        if (format_details == null) return error.CouldntGetFormatDetails;
        return format_details;
    }

    pub fn lock(self: *Surface) !void {
        const err = !C.SDL_LockSurface(self.toSDL());
        if (err) return error.CouldntLockSurface;
    }

    pub fn unlock(self: *Surface) !void {
        const err = !C.SDL_UnlockSurface(self.toSDL());
        if (err) return error.CouldntUnlockSurface;
    }

    pub fn mustlock(self: *Surface) bool {
        return C.SDL_MUSTLOCK(self.toSDL());
    }

    /// Requires SDL_image
    pub fn load(file_name: [*:0]const u8) !*Surface {
        const ret = C.IMG_Load(file_name);
        if (ret == null) return error.CouldntLoadSurface;
        return @ptrCast(ret);
    }

    /// The values of "color" should be between 0 and 1
    pub fn clearSurface(self: *@This(), color: C.SDL_FColor) !void {
        if (!C.SDL_ClearSurface(self.toSDL(), color.r, color.g, color.b, color.a)) return error.CouldntClearSurface;
    }

    /// Assumes pixel format is 24 bit wide
    pub fn getPixel(self: *@This(), format_details: *const C.SDL_PixelFormatDetails, x: usize, y: usize) Pixel {
        // r, g, b and a here aren't necessearily the actual red, green, blue and alpha
        std.debug.assert(self.pixels != null);
        var pixel: Pixel = undefined;
        pixel.r = @as([*]u8, @ptrCast(self.pixels.?))[x * 3 + @as(u32, @bitCast(self.pitch)) * y + 0];
        pixel.g = @as([*]u8, @ptrCast(self.pixels.?))[x * 3 + @as(u32, @bitCast(self.pitch)) * y + 1];
        pixel.b = @as([*]u8, @ptrCast(self.pixels.?))[x * 3 + @as(u32, @bitCast(self.pitch)) * y + 2];
        pixel.a = 0;
        var red: u8 = undefined;
        var green: u8 = undefined;
        var blue: u8 = undefined;
        C.SDL_GetRGB(
            @as(u32, @bitCast(pixel)),
            format_details,
            null,
            &red,
            &green,
            &blue,
        );
        return .{ .r = red, .g = green, .b = blue, .a = undefined };
    }

    /// Assumes pixel format is 24 bit wide
    pub fn setPixel(self: *@This(), format_details: *const C.SDL_PixelFormatDetails, x: usize, y: usize, pixel: Pixel) void {
        const stupid_pixel = C.SDL_MapRGB(format_details, null, pixel.r, pixel.g, pixel.b);
        // r, g, b and a here aren't necessearily the actual red, green, blue and alpha
        @as([*]u8, @ptrCast(self.pixels.?))[x * 3 + @as(u32, @bitCast(self.pitch)) * y + 0] = @as(Pixel, @bitCast(stupid_pixel)).r;
        @as([*]u8, @ptrCast(self.pixels.?))[x * 3 + @as(u32, @bitCast(self.pitch)) * y + 1] = @as(Pixel, @bitCast(stupid_pixel)).g;
        @as([*]u8, @ptrCast(self.pixels.?))[x * 3 + @as(u32, @bitCast(self.pitch)) * y + 2] = @as(Pixel, @bitCast(stupid_pixel)).b;
    }

    /// Blit other surface to self
    pub fn blitSurface(self: *@This(), other: *Surface, x: i32, y: i32) !void {
        // SDL ignores the width and height argument
        var tmp_rect = rect.Irect{ .x = x, .y = y, .w = undefined, .h = undefined };
        if (!C.SDL_BlitSurface(other.toSDL(), null, self.toSDL(), tmp_rect.toSDL()))
            return error.CouldntBlitSurface;
    }

    pub fn blitRect(self: *@This(), rectangle: *rect.Irect, color: C.SDL_Color) !void {
        const format_details = try self.getFormatDetails();
        const stupid_color = C.SDL_MapRGBA(format_details, null, color.r, color.g, color.b, color.a);
        if (!C.SDL_FillSurfaceRect(self.toSDL(), rectangle.toSDL(), stupid_color)) return error.CouldntBlitRect;
    }

    pub fn scaleSurface(self: *Surface, w: i32, h: i32, scale_mode: ScaleMode) !*Surface {
        const ret = C.SDL_ScaleSurface(self.toSDL(), w, h, scale_mode.toSDL());
        if (ret == null) return error.CouldntScaleSurface;
        return @ptrCast(ret);
    }
};

pub const TextureAccess = enum(u32) {
    static = C.SDL_TEXTUREACCESS_STATIC,
    streaming = C.SDL_TEXTUREACCESS_STREAMING,
    target = C.SDL_TEXTUREACCESS_TARGET,

    pub fn toSDL(self: TextureAccess) C.SDL_TextureAccess {
        return @intFromEnum(self);
    }
};

pub const Texture = extern struct {
    format: PixelFormat,
    w: i32,
    h: i32,
    refcount: i32,

    pub fn deinit(self: *Texture) void {
        C.SDL_DestroyTexture(self.toSDL());
    }

    pub fn toSDL(self: *Texture) *C.SDL_Texture {
        return @ptrCast(self);
    }
};

/// TODO: This probably shouldn't be here
pub const FlipMode = enum(u32) {
    None = C.SDL_FLIP_NONE,
    Horizontal = C.SDL_FLIP_HORIZONTAL,
    Vertical = C.SDL_FLIP_VERTICAL,

    pub fn toSDL(self: FlipMode) C.SDL_FlipMode {
        return @intFromEnum(self);
    }
};

pub const Renderer = struct {
    sdl: *C.SDL_Renderer,

    pub fn init(window: Window) !Renderer {
        return .{ .sdl = C.SDL_CreateRenderer(window.sdl, null) orelse return error.CouldntCreateRenderer };
    }

    pub fn deinit(self: Renderer) void {
        C.SDL_DestroyRenderer(self.sdl);
    }

    pub fn createTexture(self: Renderer, format: PixelFormat, access: TextureAccess, w: i32, h: i32) !*Texture {
        std.debug.assert(@bitSizeOf(C.SDL_Texture) == 128);
        const ret = C.SDL_CreateTexture(self.sdl, format.toSDL(), access.toSDL(), w, h);
        if (ret == null) return error.CouldntCreateTexture;
        return @ptrCast(ret);
    }

    pub fn createTextureFromSurface(self: Renderer, surface: *Surface) !*Texture {
        std.debug.assert(@bitSizeOf(C.SDL_Texture) == 128);
        const ret = C.SDL_CreateTextureFromSurface(self.sdl, surface.toSDL());
        if (ret == null) return error.CouldntCreateTexture;
        return @ptrCast(ret);
    }

    /// Requires SDL_image
    pub fn loadTexture(self: Renderer, file_name: [*:0]const u8) !*Texture {
        std.debug.assert(@bitSizeOf(C.SDL_Texture) == 128);
        const ret = C.IMG_LoadTexture(self.sdl, file_name);
        if (ret == null) return error.CouldntLoadTexture;
        return @ptrCast(ret);
    }

    /// TODO: Check if rectangle really needs to be a pointer
    pub fn renderRect(self: Renderer, rectangle: *rect.Frect) !void {
        const err = !C.SDL_RenderRect(self.sdl, rectangle.toSDL());
        if (err) return error.CouldntRenderRect;
    }

    /// TODO: Check if rectangle really needs to be a pointer
    pub fn renderFillRect(self: Renderer, rectangle: *rect.Frect) !void {
        const err = !C.SDL_RenderFillRect(self.sdl, rectangle.toSDL());
        if (err) return error.CouldntRenderRect;
    }

    pub fn renderTexture(self: Renderer, texture: *Texture, source_rectangle: ?*rect.Frect, destination_rectangle: ?*rect.Frect) !void {
        const err = !C.SDL_RenderTexture(
            self.sdl,
            @ptrCast(texture),
            if (source_rectangle) |_| source_rectangle.?.toSDL() else null,
            if (destination_rectangle) |_| destination_rectangle.?.toSDL() else null,
        );
        if (err) return error.CouldntRenderTexture;
    }

    pub fn renderTextureRotated(
        self: Renderer,
        texture: *Texture,
        source_rectangle: ?*rect.Frect,
        destination_rectangle: ?*rect.Frect,
        angle: f64,
        center: ?*point.Fpoint,
        flip: FlipMode,
    ) !void {
        const err = !C.SDL_RenderTextureRotated(
            self.sdl,
            texture.toSDL(),
            if (source_rectangle) |_| source_rectangle.?.toSDL() else null,
            if (destination_rectangle) |_| destination_rectangle.?.toSDL() else null,
            angle,
            if (center) |_| center.?.toSDL() else null,
            flip.toSDL(),
        );
        if (err) return error.CouldntRenderTextureRotaded;
    }

    pub fn setRenderDrawColor(self: Renderer, r: u8, g: u8, b: u8, a: u8) !void {
        const err = !C.SDL_SetRenderDrawColor(self.sdl, r, g, b, a);
        if (err) return error.CouldntSetRenderDrawColor;
    }

    pub fn setRenderDrawColorFloat(self: Renderer, r: f32, g: f32, b: f32, a: f32) !void {
        const err = !C.SDL_SetRenderDrawColorFloat(self.sdl, r, g, b, a);
        if (err) return error.CouldntSetRenderDrawColor;
    }

    pub fn clear(self: Renderer) !void {
        const err = !C.SDL_RenderClear(self.sdl);
        if (err) return error.CouldntRenderClear;
    }

    pub fn present(self: Renderer) !void {
        const err = !C.SDL_RenderPresent(self.sdl);
        if (err) return error.CouldntRenderClear;
    }
};
