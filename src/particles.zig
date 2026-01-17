const std = @import("std");
const rl = @import("raylib");
const utils = @import("utils.zig");
const MAX_PARTICLES = utils.MAX_PARTICLES;
const DRAG = utils.DRAG;

pub const Particle = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    lifetime: f32, // remaining life in seconds
    max_lifetime: f32,
    color: rl.Color,
    size: f32,
    active: bool,
};

pub fn init() [MAX_PARTICLES]Particle {
    var particles: [MAX_PARTICLES]Particle = undefined;

    for (&particles) |*p| {
        p.active = false;
        p.velocity = .{ .x = 0, .y = 0 };
        p.position = .{ .x = 0, .y = 0 };
        p.lifetime = 4;
        p.max_lifetime = 10;
        p.color = .dark_gray;
        p.size = 0;
    }

    return particles;
}

pub fn spawn(particles: *[MAX_PARTICLES]Particle, pos: rl.Vector2, size: f32) void {
    blk: for (particles) |*p| {
        if (!p.active) {
            p.active = true;
            const vx = @as(f32, @floatFromInt(rl.getRandomValue(-600, 600)));
            const vy = @as(f32, @floatFromInt(rl.getRandomValue(-600, 600)));

            p.velocity = .{ .x = vx, .y = vy };
            p.position = .{ .x = pos.x, .y = pos.y };
            p.size = size;
            p.lifetime = 4;

            break :blk;
        }
    }
}

pub fn draw(particles: *[MAX_PARTICLES]Particle, dt: f32) void {
    for (particles) |*p| {
        if (p.active) {
            const rand_rotation: f32 = @floatFromInt(rl.getRandomValue(0, 360));
            const rads = rand_rotation * (std.math.pi / 180.0);

            const force_x = std.math.cos(rads) * 200.0 * dt;
            const force_y = std.math.sin(rads) * 200.0 * dt;

            p.velocity.x += force_x;
            p.velocity.y += force_y;

            p.position.x += p.velocity.x * dt;
            p.position.y += p.velocity.y * dt;

            p.velocity.x *= DRAG - 0.05;
            p.velocity.y *= DRAG - 0.05;

            p.lifetime -= dt;
            // TODO: simple life time, to be enhanced
            if (p.lifetime <= 0) {
                p.active = false;
            }

            rl.drawCircle(@intFromFloat(p.position.x), @intFromFloat(p.position.y), p.size, .yellow);
        }
    }
}
