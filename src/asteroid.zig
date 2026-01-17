const std = @import("std");
const rl = @import("raylib");
const utils = @import("utils.zig");
const MAX_ASTEROIDS = utils.MAX_ASTEROIDS;
const DRAG = utils.DRAG;
const rand = std.crypto.random;
const SPREAD_DEGREE = 360.0;
const INIT_ASTEROIDS = utils.INIT_ASTEROIDS;

pub const Asteroid = struct {
    active: bool,
    position: rl.Vector2,
    velocity: rl.Vector2,
    rotation: f32,
    radius: f32,
};

pub fn init() [MAX_ASTEROIDS]Asteroid {
    var asteroids: [MAX_ASTEROIDS]Asteroid = undefined;

    for (0..MAX_ASTEROIDS) |i| {
        asteroids[i].active = false;
    }

    for (0..INIT_ASTEROIDS) |_| {
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

pub fn handleCollisionOnEachOther(asteroids: *[MAX_ASTEROIDS]Asteroid) void {
    for (0..MAX_ASTEROIDS - 1) |i| {
        var a1 = &asteroids[i];
        if (!a1.active) continue;

        for (i + 1..MAX_ASTEROIDS) |j| {
            var a2 = &asteroids[j];
            if (!a2.active) continue;

            if (rl.checkCollisionCircles(a1.position, a1.radius, a2.position, a2.radius)) {
                const delta = rl.Vector2.subtract(a1.position, a2.position);
                const distance = rl.Vector2.length(delta);

                const overlap = (a1.radius + a2.radius) - distance;

                // normalize vector (we need direction, not magnitude)
                const normal = rl.Vector2.normalize(delta);

                // NOTE: push apart handling
                // create a vector of half the overlap length in the direction of collision
                const push_vector = rl.Vector2.scale(normal, overlap * 0.5);
                a1.position = rl.Vector2.add(a1.position, push_vector);
                a2.position = rl.Vector2.subtract(a2.position, push_vector);

                // NOTE: bounce handling
                // how fast along the collision axis
                const relative_vel = rl.Vector2.subtract(a1.velocity, a2.velocity);

                const vel_normal = rl.Vector2.dotProduct(relative_vel, normal);

                if (vel_normal > 0) continue;

                // calculate impulse
                const restitution = 0.5;
                var scale_factor = -(1.0 + restitution) * vel_normal;
                scale_factor /= (1.0 / (a1.radius * a1.radius) + 1.0 / (a2.radius * a2.radius));

                // apply impulse
                const impulse = rl.Vector2.scale(normal, scale_factor);
                a1.velocity = rl.Vector2.add(a1.velocity, rl.Vector2.scale(impulse, 1.0 / (a1.radius * a1.radius)));
                a2.velocity = rl.Vector2.subtract(a2.velocity, rl.Vector2.scale(impulse, 1.0 / (a2.radius * a2.radius)));
            }
        }
    }
}
