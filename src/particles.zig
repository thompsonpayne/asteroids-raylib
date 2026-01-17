const std = @import("std");
const rl = @import("raylib");
const utils = @import("utils.zig");
const MAX_PARTICLES = utils.MAX_PARTICLES;
const DRAG = utils.DRAG;

const ParticleType = enum {
    explosion,
    sparks,
    debris,
};

pub const Particle = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    lifetime: f32,
    max_lifetime: f32,
    color: rl.Color,
    size: f32,
    initial_size: f32,
    active: bool,
};

const ParticleConfig = struct {
    speed_min: f32,
    speed_max: f32,
    lifetime_min: f32,
    lifetime_max: f32,
    size_min: f32,
    size_max: f32,
    color_start: rl.Color,
    color_end: rl.Color,
};

const EXPLOSION_CONFIG: ParticleConfig = .{
    .speed_min = 100,
    .speed_max = 300,
    .lifetime_min = 0.3,
    .lifetime_max = 0.5,
    .size_min = 3,
    .size_max = 6,
    .color_start = .yellow,
    .color_end = .{ .r = 255, .g = 69, .b = 0, .a = 255 },
};

const SPARKS_CONFIG: ParticleConfig = .{
    .speed_min = 200,
    .speed_max = 400,
    .lifetime_min = 0.1,
    .lifetime_max = 0.2,
    .size_min = 2,
    .size_max = 3,
    .color_start = .white,
    .color_end = .orange,
};

const DEBRIS_CONFIG: ParticleConfig = .{
    .speed_min = 50,
    .speed_max = 150,
    .lifetime_min = 0.5,
    .lifetime_max = 1.0,
    .size_min = 4,
    .size_max = 8,
    .color_start = .{ .r = 180, .g = 180, .b = 180, .a = 255 },
    .color_end = .{ .r = 100, .g = 100, .b = 100, .a = 255 },
};

pub fn init() [MAX_PARTICLES]Particle {
    var particles: [MAX_PARTICLES]Particle = undefined;

    for (&particles) |*p| {
        p.active = false;
        p.velocity = .{ .x = 0, .y = 0 };
        p.position = .{ .x = 0, .y = 0 };
        p.lifetime = 0;
        p.max_lifetime = 0;
        p.color = .dark_gray;
        p.size = 0;
        p.initial_size = 0;
    }

    return particles;
}

fn getConfig(particle_type: ParticleType) ParticleConfig {
    return switch (particle_type) {
        .explosion => EXPLOSION_CONFIG,
        .sparks => SPARKS_CONFIG,
        .debris => DEBRIS_CONFIG,
    };
}

fn lerpColor(c1: rl.Color, c2: rl.Color, t: f32) rl.Color {
    const rt = @as(f32, 1.0) - t;
    return .{
        .r = @intFromFloat(@as(f32, @floatFromInt(c1.r)) * rt + @as(f32, @floatFromInt(c2.r)) * t),
        .g = @intFromFloat(@as(f32, @floatFromInt(c1.g)) * rt + @as(f32, @floatFromInt(c2.g)) * t),
        .b = @intFromFloat(@as(f32, @floatFromInt(c1.b)) * rt + @as(f32, @floatFromInt(c2.b)) * t),
        .a = @intFromFloat(@as(f32, @floatFromInt(c1.a)) * rt + @as(f32, @floatFromInt(c2.a)) * t),
    };
}

pub fn spawn(
    particles: *[MAX_PARTICLES]Particle,
    pos: rl.Vector2,
    particle_type: ParticleType,
) void {
    const config = getConfig(particle_type);

    const count = switch (particle_type) {
        .explosion => @as(usize, 20),
        .sparks => @as(usize, 10),
        .debris => @as(usize, 6),
    };

    var spawned: usize = 0;
    for (particles) |*p| {
        if (!p.active and spawned < count) {
            spawned += 1;

            const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * (std.math.pi / 180.0);
            const speed = std.crypto.random.float(f32) * (config.speed_max - config.speed_min) + config.speed_min;

            p.active = true;
            p.velocity = .{
                .x = std.math.cos(angle) * speed,
                .y = std.math.sin(angle) * speed,
            };
            p.position = .{ .x = pos.x, .y = pos.y };
            p.size = std.crypto.random.float(f32) * (config.size_max - config.size_min) + config.size_min;
            p.initial_size = p.size;
            p.lifetime = std.crypto.random.float(f32) * (config.lifetime_max - config.lifetime_min) + config.lifetime_min;
            p.max_lifetime = p.lifetime;
            p.color = config.color_start;
        }
    }
}

pub fn update(particles: *[MAX_PARTICLES]Particle, dt: f32) void {
    for (particles) |*p| {
        if (p.active) {
            p.position.x += p.velocity.x * dt;
            p.position.y += p.velocity.y * dt;

            p.velocity.x *= DRAG;
            p.velocity.y *= DRAG;

            p.lifetime -= dt;

            const life_ratio = p.lifetime / p.max_lifetime;
            const size_ratio = @max(0.0, life_ratio);

            p.size = p.initial_size * size_ratio;

            p.active = p.lifetime > 0;
        }
    }
}

pub fn draw(particles: *[MAX_PARTICLES]Particle) void {
    for (particles) |*p| {
        if (p.active) {
            const life_ratio = p.lifetime / p.max_lifetime;
            const size_ratio = @max(0.0, life_ratio);

            p.size = p.initial_size * size_ratio;

            const speed = std.math.sqrt(p.velocity.x * p.velocity.x + p.velocity.y * p.velocity.y);

            const config: ParticleConfig = if (speed > 250) SPARKS_CONFIG else if (p.initial_size > 5) DEBRIS_CONFIG else EXPLOSION_CONFIG;

            p.color = lerpColor(config.color_start, config.color_end, 1.0 - life_ratio);

            if (p.size < 1.0) {
                p.active = false;
            } else {
                rl.drawCircle(
                    @intFromFloat(p.position.x),
                    @intFromFloat(p.position.y),
                    p.size,
                    p.color,
                );
            }
        }
    }
}
