const std = @import("std");
const rl = @import("raylib");
const utils = @import("utils.zig");
const MAX_ASTEROIDS = utils.MAX_ASTEROIDS;
const DRAG = utils.DRAG;
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

pub fn draw(asteroids: *[MAX_ASTEROIDS]Asteroid, dt: f32) void {
    for (asteroids) |*a| {
        if (a.active) {
            const rads = a.rotation * (std.math.pi / 180.0);

            const force_x = std.math.cos(rads) * 100.0 * dt;
            const force_y = std.math.sin(rads) * 100.0 * dt;

            a.velocity.x += force_x;
            a.velocity.y += force_y;

            a.position.x += a.velocity.x * dt;
            a.position.y += a.velocity.y * dt;

            a.velocity.x *= DRAG;
            a.velocity.y *= DRAG;

            utils.wrapObject(&a.position);

            rl.drawCircleLinesV(a.position, a.radius, .white);
        }
    }
}
