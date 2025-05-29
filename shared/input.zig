const std = @import("std");

const Input = packed struct {
    down: bool = false,
    pressed: bool = false,
    released: bool = false,
};

pub const Inputs = struct {
    inputs: []Input,

    pub fn init(allocator: std.mem.Allocator, amount_of_inputs: usize) !@This() {
        return .{ .inputs = try allocator.alloc(Input, amount_of_inputs) };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.inputs);
    }

    pub fn keyDown(self: *@This(), val: usize) void {
        self.inputs[val].released = false;
        self.inputs[val].pressed = if (self.inputs[val].down) false else true;
        self.inputs[val].down = true;
    }

    pub fn keyUp(self: *@This(), val: usize) void {
        self.inputs[val].pressed = false;
        self.inputs[val].released = if (!self.inputs[val].down) false else true;
        self.inputs[val].down = false;
    }

    /// Call this function before event loop
    pub fn resetKeys(self: *@This()) void {
        for (0..self.inputs.len) |i| self.resetKey(i);
    }

    pub fn resetKey(self: *@This(), val: usize) void {
        self.inputs[val].pressed = false;
        self.inputs[val].released = false;
    }
};
