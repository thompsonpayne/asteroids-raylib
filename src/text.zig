const std = @import("std");
const utils = @import("utils.zig");
const rl = @import("raylib");

pub const Text = struct {
    content: [:0]const u8,
    life_time: f32,
    active: bool,
    x: i32,
    y: i32,

    pub fn age(self: *Text, dt: f32) void {
        if (self.life_time <= 0.0) {
            self.active = false;
        } else {
            self.life_time -= dt;
        }
    }

    pub fn isExpired(self: *Text) bool {
        return !self.active;
    }

    pub fn draw(self: *Text) void {
        if (self.active) {
            rl.drawText(self.content, self.x, self.y, 14.0, .yellow);
        }
    }
};
