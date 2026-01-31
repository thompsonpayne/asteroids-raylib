const std = @import("std");

const rl = @import("raylib");

const utils = @import("utils.zig");
const MAX_PARTICLES = utils.MAX_PARTICLES;
const DRAG = utils.DRAG;

const ParticleType = enum {
    big_explosion,
    big_flash,
    shockwave,
    explosion,
    sparks,
    debris,
    thrust_sparkles,
};

pub const Particle = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    lifetime: f32,
    max_lifetime: f32,
    color: rl.Color,
    radius: ?f32,
    size: f32,
    initial_size: f32,
    active: bool,
    particle_type: ParticleType,
};

const SizeMode = enum {
    shrink,
    grow,
};

const ParticleConfig = struct {
    speed_min: f32,
    speed_max: f32,
    speed_power: f32,
    lifetime_min: f32,
    lifetime_max: f32,
    size_min: f32,
    size_max: f32,
    size_power: f32,
    size_mode: SizeMode,
    drag: f32,
    gravity: f32,
    radius: ?f32,
    color_start: rl.Color,
    color_end: rl.Color,
};

const EXPLOSION_CONFIG: ParticleConfig = .{
    .speed_min = 100,
    .speed_max = 300,
    .speed_power = 1.0,
    .lifetime_min = 0.3,
    .lifetime_max = 0.5,
    .size_min = 3,
    .radius = null,
    .size_max = 6,
    .size_power = 1.0,
    .size_mode = .shrink,
    .drag = DRAG,
    .gravity = 0,
    .color_start = .yellow,
    .color_end = .{ .r = 255, .g = 69, .b = 0, .a = 255 },
};

const BIG_EXPLOSION_CONFIG: ParticleConfig = .{
    .speed_min = 75,
    .speed_max = 260,
    .speed_power = 0.6,
    .lifetime_min = 0.6,
    .lifetime_max = 2.4,
    .size_min = 1,
    .size_max = 26,
    .size_power = 0.8,
    .size_mode = .shrink,
    .drag = 0.985,
    .gravity = 0,
    .radius = 30.0,
    .color_start = .{ .r = 255, .g = 255, .b = 200, .a = 255 },
    .color_end = .{ .r = 200, .g = 40, .b = 0, .a = 0 },
};

const BIG_FLASH_CONFIG: ParticleConfig = .{
    .speed_min = 0,
    .speed_max = 40,
    .speed_power = 1.0,
    .lifetime_min = 0.12,
    .lifetime_max = 0.2,
    .size_min = 24,
    .size_max = 42,
    .size_power = 0.6,
    .size_mode = .shrink,
    .drag = 0.9,
    .gravity = 0,
    .radius = null,
    .color_start = .{ .r = 255, .g = 240, .b = 220, .a = 255 },
    .color_end = .{ .r = 255, .g = 140, .b = 60, .a = 0 },
};

const SHOCKWAVE_CONFIG: ParticleConfig = .{
    .speed_min = 0,
    .speed_max = 0,
    .speed_power = 1.0,
    .lifetime_min = 0.4,
    .lifetime_max = 0.7,
    .size_min = 46,
    .size_max = 90,
    .size_power = 0.9,
    .size_mode = .grow,
    .drag = 1.0,
    .gravity = 0,
    .radius = null,
    .color_start = .{ .r = 255, .g = 180, .b = 120, .a = 140 },
    .color_end = .{ .r = 255, .g = 80, .b = 40, .a = 0 },
};

const SPARKS_CONFIG: ParticleConfig = .{
    .speed_min = 200,
    .speed_max = 400,
    .speed_power = 0.8,
    .lifetime_min = 0.1,
    .lifetime_max = 0.2,
    .size_min = 2,
    .size_max = 3,
    .size_power = 1.0,
    .size_mode = .shrink,
    .drag = DRAG,
    .gravity = 0,
    .radius = null,
    .color_start = .white,
    .color_end = .orange,
};

const DEBRIS_CONFIG: ParticleConfig = .{
    .speed_min = 50,
    .speed_max = 150,
    .speed_power = 1.2,
    .lifetime_min = 0.5,
    .lifetime_max = 1.0,
    .size_min = 4,
    .size_max = 8,
    .size_power = 1.1,
    .size_mode = .shrink,
    .drag = 0.99,
    .gravity = 120,
    .radius = null,
    .color_start = .{ .r = 180, .g = 180, .b = 180, .a = 255 },
    .color_end = .{ .r = 100, .g = 100, .b = 100, .a = 0 },
};

const THRUST_SPARKLES_CONFIG: ParticleConfig = .{
    .speed_min = 30,
    .speed_max = 80,
    .speed_power = 1.0,
    .lifetime_min = 0.15,
    .lifetime_max = 0.3,
    .size_min = 1,
    .size_max = 2.5,
    .size_power = 1.0,
    .size_mode = .shrink,
    .drag = DRAG,
    .gravity = 0,
    .radius = 0,
    .color_start = .white,
    .color_end = .sky_blue,
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
        p.particle_type = .explosion;
    }

    return particles;
}

fn getConfig(particle_type: ParticleType) ParticleConfig {
    return switch (particle_type) {
        .explosion => EXPLOSION_CONFIG,
        .sparks => SPARKS_CONFIG,
        .debris => DEBRIS_CONFIG,
        .big_explosion => BIG_EXPLOSION_CONFIG,
        .big_flash => BIG_FLASH_CONFIG,
        .shockwave => SHOCKWAVE_CONFIG,
        .thrust_sparkles => THRUST_SPARKLES_CONFIG,
    };
}

fn spawnLayer(
    particles: *[MAX_PARTICLES]Particle,
    pos: rl.Vector2,
    particle_type: ParticleType,
    count: usize,
) void {
    const config = getConfig(particle_type);

    var spawned: usize = 0;
    for (particles) |*p| {
        if (!p.active and spawned < count) {
            spawned += 1;

            const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * (std.math.pi / 180.0);
            const speed_t = std.math.pow(f32, std.crypto.random.float(f32), config.speed_power);
            const speed = speed_t * (config.speed_max - config.speed_min) + config.speed_min;

            p.active = true;
            p.particle_type = particle_type;
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
            p.radius = config.radius;
        }
    }
}

pub fn spawn(
    particles: *[MAX_PARTICLES]Particle,
    pos: rl.Vector2,
    particle_type: ParticleType,
) void {
    switch (particle_type) {
        .big_explosion => {
            spawnLayer(particles, pos, .big_flash, 6);
            spawnLayer(particles, pos, .big_explosion, 70);
            spawnLayer(particles, pos, .sparks, 24);
            spawnLayer(particles, pos, .debris, 12);
            spawnLayer(particles, pos, .shockwave, 2);
        },
        else => {
            const count = switch (particle_type) {
                .explosion => @as(usize, 20),
                .sparks => @as(usize, 10),
                .debris => @as(usize, 6),
                .thrust_sparkles => @as(usize, 10),
                else => @as(usize, 10),
            };

            spawnLayer(particles, pos, particle_type, count);
        },
    }
}

pub fn update(particles: *[MAX_PARTICLES]Particle, dt: f32) void {
    for (particles) |*p| {
        if (p.active) {
            const config = getConfig(p.particle_type);

            p.position.x += p.velocity.x * dt;
            p.position.y += p.velocity.y * dt;

            if (config.gravity != 0) {
                p.velocity.y += config.gravity * dt;
            }

            p.velocity.x *= config.drag;
            p.velocity.y *= config.drag;

            p.lifetime -= dt;

            p.active = p.lifetime > 0;
        }
    }
}

pub fn draw(particles: *[MAX_PARTICLES]Particle) void {
    for (particles) |*p| {
        if (p.active) {
            const config = getConfig(p.particle_type);

            const life_ratio = @max(0.0, p.lifetime / p.max_lifetime);
            const size_t = switch (config.size_mode) {
                .shrink => std.math.pow(f32, life_ratio, config.size_power),
                .grow => std.math.pow(f32, 1.0 - life_ratio, config.size_power),
            };

            p.size = p.initial_size * size_t;

            p.color = utils.lerpColor(config.color_start, config.color_end, 1.0 - life_ratio);

            if (p.size < 0.6) {
                p.active = false;
            } else if (p.particle_type == .shockwave) {
                rl.drawCircleLines(
                    @intFromFloat(p.position.x),
                    @intFromFloat(p.position.y),
                    p.size,
                    p.color,
                );
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
