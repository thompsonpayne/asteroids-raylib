const std = @import("std");

const rl = @import("raylib");

const SCREEN_WIDTH = 1280;
const SCREEN_HEIGHT = 720;

pub const Camera = struct {
    camera: rl.Camera2D,
    base_offset: rl.Vector2,
    shake_intensity: f32,
    shake_duration: f32,
    shake_timer: f32,

    pub fn init() Camera {
        const screen_center = rl.Vector2{ .x = SCREEN_WIDTH / 2.0, .y = SCREEN_HEIGHT / 2.0 };
        return .{
            .camera = .{
                .target = screen_center,
                .offset = screen_center,
                .rotation = 0,
                .zoom = 1,
            },
            .base_offset = screen_center,
            .shake_intensity = 0,
            .shake_duration = 0,
            .shake_timer = 0,
        };
    }

    pub fn trigger(self: *Camera, intensity: f32, duration: f32) void {
        self.shake_intensity = intensity;
        self.shake_duration = duration;
        self.shake_timer = duration;
    }

    pub fn update(self: *Camera, dt: f32) void {
        if (self.shake_timer > 0) {
            self.shake_timer -= dt;
            const t = if (self.shake_duration > 0) self.shake_timer / self.shake_duration else 0;
            const current_intensity = self.shake_intensity * t;

            const rx = @as(f32, @floatFromInt(rl.getRandomValue(-100, 100))) / 100.0 * current_intensity;
            const ry = @as(f32, @floatFromInt(rl.getRandomValue(-100, 100))) / 100.0 * current_intensity;

            self.camera.offset = .{
                .x = self.base_offset.x + rx,
                .y = self.base_offset.y + ry,
            };
        } else {
            self.camera.offset = self.base_offset;
            self.shake_intensity = 0;
        }
    }

    pub fn begin(self: *Camera) void {
        rl.beginMode2D(self.camera);
    }

    pub fn end(self: *Camera) void {
        _ = self;
        rl.endMode2D();
    }
};
