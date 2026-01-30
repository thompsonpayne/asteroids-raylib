const std = @import("std");
const text_mod = @import("text.zig");
const rand = std.crypto.random;

const rl = @import("raylib");

const particles_mod = @import("particles.zig");
const Particle = particles_mod.Particle;
const utils = @import("utils.zig");
const MAX_ASTEROIDS = utils.MAX_ASTEROIDS;
const DRAG = utils.DRAG;
const INIT_ASTEROIDS = utils.INIT_ASTEROIDS;
const MAX_PARTICLES = utils.MAX_PARTICLES;
const AsteroidDrawError = utils.AsteroidDrawError;

const SPREAD_DEGREE = 360.0;
pub const Asteroid = struct {
    active: bool,
    position: rl.Vector2,
    velocity: rl.Vector2,
    rotation: f32,
    radius: f32,
};

pub fn init(ship_position: rl.Vector2) [MAX_ASTEROIDS]Asteroid {
    var asteroids: [MAX_ASTEROIDS]Asteroid = undefined;

    for (0..MAX_ASTEROIDS) |i| {
        asteroids[i].active = false;
    }

    const spawn_radius: f32 = 50;
    const buffer: f32 = 60;
    const min_distance: f32 = spawn_radius + buffer;
    const min_distance_sq: f32 = min_distance * min_distance;

    for (0..INIT_ASTEROIDS) |_| {
        var pos: rl.Vector2 = undefined;

        while (true) {
            const rand_x = @as(f32, @floatFromInt(rl.getRandomValue(0, 800)));
            const rand_y = @as(f32, @floatFromInt(rl.getRandomValue(0, 600)));
            pos = .{ .x = rand_x, .y = rand_y };

            const delta = rl.Vector2.subtract(pos, ship_position);
            const dist_sq = delta.x * delta.x + delta.y * delta.y;

            if (dist_sq >= min_distance_sq) break;
        }

        spawn(&asteroids, pos, spawn_radius);
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

pub fn draw(asteroids: *[MAX_ASTEROIDS]Asteroid, dt: f32) AsteroidDrawError!void {
    var inactive: u16 = 0;
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
        } else {
            inactive += 1;
        }
    }

    if (inactive == asteroids.len) {
        return error.PlayerWin;
    }
}

pub fn handleCollisionWithExternal(
    allocator: std.mem.Allocator,
    asteroids: *[MAX_ASTEROIDS]Asteroid,
    particles: *[MAX_PARTICLES]Particle,
    text_list: *std.ArrayList(text_mod.Text),
) !void {
    for (0..MAX_ASTEROIDS - 1) |i| {
        var a1 = &asteroids[i];
        if (!a1.active) continue;

        for (i + 1..MAX_ASTEROIDS) |j| {
            var a2 = &asteroids[j];
            if (!a2.active) continue;

            if (rl.checkCollisionCircles(a1.position, a1.radius, a2.position, a2.radius)) {
                const delta = rl.Vector2.subtract(a1.position, a2.position);
                const distance = rl.Vector2.length(delta);

                const collision_point = rl.Vector2.subtract(
                    a1.position,
                    rl.Vector2.scale(rl.Vector2.normalize(delta), a1.radius),
                );
                particles_mod.spawn(particles, collision_point, .sparks);

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

        // collision from big explosions particles
        for (particles) |p| {
            if (p.particle_type != .big_explosion or !p.active or p.radius == null) continue;

            if (rl.checkCollisionCircles(a1.position, a1.radius, p.position, p.radius.?)) {
                try text_list.append(allocator, text_mod.Text{
                    .active = true,
                    .content = "Hell yeah!",
                    .life_time = 1.0,
                    .x = @intFromFloat(a1.position.x),
                    .y = @intFromFloat(a1.position.y),
                });

                particles_mod.spawn(particles, a1.position, .explosion);

                a1.active = false;

                // if normal bullet, split the a1, if not (missile), destroy it
                if (a1.radius > 20.0) {
                    const new_size = a1.radius / 2.0;

                    for (0..3) |_| {
                        spawn(
                            asteroids,
                            .{ .x = a1.position.x - 20, .y = a1.position.y - 20 },
                            new_size,
                        );
                    }

                    particles_mod.spawn(particles, a1.position, .debris);
                }
            }
        }
    }
}
