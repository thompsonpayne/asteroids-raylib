const std = @import("std");
const rl = @import("raylib");
const utils = @import("utils.zig");
const MAX_ASTEROIDS = utils.MAX_ASTEROIDS;
const rand = std.crypto.random;
const SPREAD_DEGREE = 360.0;

pub const Asteroid = struct {
    active: bool,
    position: rl.Vector2,
    velocity: rl.Vector2,
    rotation: f32,
    radius: f32,
};

pub fn initAsteroids() [MAX_ASTEROIDS]Asteroid {
    var asteroids: [MAX_ASTEROIDS]Asteroid = undefined;

    for (0..MAX_ASTEROIDS) |i| {
        asteroids[i].active = false;
    }

    for (0..5) |_| {
        const rand_x = @as(f32, @floatFromInt(rl.getRandomValue(0, 800)));
        const rand_y = @as(f32, @floatFromInt(rl.getRandomValue(0, 600)));

        spawn(&asteroids, .{ .x = rand_x, .y = rand_y }, 40.0);
    }

    return asteroids;
}

pub fn spawn(asteroids: *[MAX_ASTEROIDS]Asteroid, pos: rl.Vector2, size: f32) void {
    // find dead asteroid to recycle
    blk: for (0..MAX_ASTEROIDS) |i| {
        var a = &asteroids[i];
        if (!a.active) {
            a.active = true;
            a.position = pos;
            a.radius = size;

            const rand_factor = rand.float(f32) * 2.0 - 1.0; // rand from -1 to 1
            const rand_offset = rand_factor * SPREAD_DEGREE;

            a.rotation = rand_offset;

            const vx = @as(f32, @floatFromInt(rl.getRandomValue(-100, 100)));
            const vy = @as(f32, @floatFromInt(rl.getRandomValue(-100, 100)));

            a.velocity = rl.Vector2{ .x = vx, .y = vy };
            break :blk;
        }
    }
}
