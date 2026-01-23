const std = @import("std");

const rl = @import("raylib");

const asteroid_mod = @import("asteroid.zig");
const Asteroid = asteroid_mod.Asteroid;
const bullet_mod = @import("bullet.zig");
const Bullet = bullet_mod.Bullet;
const camera_mod = @import("camera.zig");
const Camera = camera_mod.Camera;
const particles_mod = @import("particles.zig");
const Particle = particles_mod.Particle;
const text_mod = @import("text.zig");
const utils = @import("utils.zig");
const ROTATION_SPEED = utils.ROTATION_SPEED;
const ACCELERATION = utils.ACCELERATION;
const SCREEN_HEIGHT = utils.SCREEN_HEIGHT;
const SCREEN_WIDTH = utils.SCREEN_WIDTH;
const DRAG = utils.DRAG;
const MAX_BULLETS = utils.MAX_BULLETS;
const BULLET_LIFE = utils.BULLET_LIFE;
const BULLET_SPEED = utils.BULLET_SPEED;
const MISSILE_SPEED = utils.MISSILE_SPEED;
const MAX_PARTICLES = utils.MAX_PARTICLES;
const MAX_ASTEROIDS = utils.MAX_ASTEROIDS;
const MAX_MISSLES = utils.MAX_MISSLES;
const MAX_SHIP_SPEED = utils.MAX_SHIP_SPEED;
const wrapObject = utils.wrapObject;
const ShipDrawError = utils.ShipDrawError || std.fmt.BufPrintError;

// --- CONSTANTS FOR BEHAVIOR ---
const PHASE_1_DURATION = 0.4; // Seconds to curve/slow down
const MISSILE_TURN_RATE = 90.0; // How fast it curves initially
const LAUNCH_DRAG = 0.90; // How fast it slows down initially (0.90 - 0.99)
const BOOST_ACCEL = 1000.0; // How fast it speeds up in Phase 2

pub const Ship = struct {
    position: rl.Vector2,
    velocity: rl.Vector2, // speed x, speed y
    rotation: f32, // direction facing (degree)
    texture: rl.Texture2D,
    thrusting: bool,
    turbo_thrusting: bool,
    radius: f32,
    missiles_ammo: u16,
    reloading_time: f32,
    health: u8,
    hit_timer: f32,
    gameover_timer: f32,

    pub fn init(position: rl.Vector2, texture: rl.Texture2D) Ship {
        const scale = 0.1;
        const ship_width = @as(f32, @floatFromInt(texture.width)) * scale;

        return .{
            .position = position,
            .velocity = .{ .x = 0, .y = 0 },
            .rotation = -90,
            .texture = texture,
            .thrusting = false,
            .turbo_thrusting = false,
            .radius = ship_width / 4.5,
            .missiles_ammo = MAX_MISSLES,
            .reloading_time = 0,
            .health = 100,
            .hit_timer = 0,
            .gameover_timer = 0,
        };
    }

    pub fn deinit(self: *Ship) void {
        rl.unloadTexture(self.texture);
    }

    pub fn draw(self: *Ship, particles: *[MAX_PARTICLES]Particle) ShipDrawError!void {
        if (self.health <= 0) {
            particles_mod.spawn(particles, self.position, .big_explosion);
        }

        if (self.health <= 0 and self.gameover_timer == 0) {
            self.gameover_timer = 2.0;
        }

        if (self.health <= 0) {
            if (self.gameover_timer > 0) {
                self.gameover_timer -= rl.getFrameTime();
            } else {
                self.gameover_timer = 0;
                return error.Die;
            }
        }

        if (self.health > 0) {
            const texture = self.texture;

            const source = rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(texture.width),
                .height = @floatFromInt(texture.height),
            };

            const scale: f32 = 0.05;

            // destination rect (centered on ship position)
            const dest = rl.Rectangle{
                .x = self.position.x,
                .y = self.position.y,
                .width = @as(f32, @floatFromInt(texture.width)) * scale,
                .height = @as(f32, @floatFromInt(texture.height)) * scale,
            };

            // origin point for rotation (center of sprite)
            const origin = rl.Vector2{
                .x = dest.width / 2.0,
                .y = dest.height / 2.0,
            };

            if (self.thrusting or self.turbo_thrusting) {
                const rads = std.math.degreesToRadians(self.rotation);
                const cos_t = std.math.cos(rads);
                const sin_t = std.math.sin(rads);

                // Ship forward vector (x=cos, y=sin)
                const forward = rl.Vector2{ .x = cos_t, .y = sin_t };

                const speed = rl.Vector2.length(self.velocity);

                // Tail position (behind center)
                const offset = dest.width * 0.4;
                const tail = rl.Vector2{
                    .x = self.position.x - forward.x * offset,
                    .y = self.position.y - forward.y * offset,
                };
                if (self.turbo_thrusting) {
                    particles_mod.spawn(particles, tail, .thrust_sparkles);
                }

                // Flame dimensions
                const flicker = @as(f32, @floatFromInt(rl.getRandomValue(0, 10))) / 20.0; // 0.0 - 0.5
                const flame_len = dest.width * (speed / MAX_SHIP_SPEED + flicker);
                const flame_width = if (self.turbo_thrusting) dest.width * 0.4 else dest.width * 0.3;

                // Flame tip
                const tip = rl.Vector2{
                    .x = tail.x - forward.x * flame_len,
                    .y = tail.y - forward.y * flame_len,
                };

                // Flame base corners (perpendicular to forward)
                const perp = rl.Vector2{ .x = -forward.y, .y = forward.x };
                const p1 = rl.Vector2{
                    .x = tail.x + perp.x * flame_width * 0.5,
                    .y = tail.y + perp.y * flame_width * 0.5,
                };
                const p2 = rl.Vector2{
                    .x = tail.x - perp.x * flame_width * 0.5,
                    .y = tail.y - perp.y * flame_width * 0.5,
                };

                const t = std.math.clamp(speed / ACCELERATION, 0.0, 1.0);
                const outer_color = utils.lerpColor(.red, .sky_blue, t);
                // Draw outer flame
                rl.drawTriangle(p1, p2, tip, outer_color);

                // Inner flame
                const p1_i = rl.Vector2{
                    .x = tail.x + perp.x * flame_width * 0.3,
                    .y = tail.y + perp.y * flame_width * 0.3,
                };
                const p2_i = rl.Vector2{
                    .x = tail.x - perp.x * flame_width * 0.3,
                    .y = tail.y - perp.y * flame_width * 0.3,
                };
                const tip_i = rl.Vector2{
                    .x = tail.x - forward.x * flame_len * 0.6,
                    .y = tail.y - forward.y * flame_len * 0.6,
                };

                const inner_color = utils.lerpColor(.yellow, .ray_white, t);
                rl.drawTriangle(p1_i, p2_i, tip_i, inner_color);
            }

            rl.drawTexturePro(
                texture,
                source,
                dest,
                origin,
                self.rotation,
                .white,
            );

            var ammo_buf: [128]u8 = undefined;
            const ammo = try std.fmt.bufPrintZ(&ammo_buf, "Missiles:{d}", .{self.missiles_ammo});

            // var reloading_buf: [128]u8 = undefined;
            // const reloading_time = try std.fmt.bufPrintZ(&reloading_buf, "{d}", .{self.reloading_time});

            const color: rl.Color = if (self.missiles_ammo == 0) .red else .green;
            rl.drawText(ammo, SCREEN_WIDTH - 200, SCREEN_HEIGHT - 30, 20.0, color);

            if (self.reloading_time > 0) {
                rl.drawText(
                    "Reloading",
                    @intFromFloat(self.position.x),
                    @intFromFloat(self.position.y),
                    16.0,
                    .ray_white,
                );
            }

            if (self.hit_timer > 0) {
                self.hit_timer -= rl.getFrameTime();
                const blink_speed = 15.0;
                const phase = @mod(self.hit_timer * blink_speed, 1.0);
                if (phase > 0.5) {
                    const overlay_dest = rl.Rectangle{
                        .width = dest.width,
                        .height = dest.height,
                        .x = self.position.x,
                        .y = self.position.y,
                    };

                    rl.drawTexturePro(
                        texture,
                        source,
                        overlay_dest,
                        origin,
                        self.rotation,
                        .{ .r = 255, .g = 0, .b = 0, .a = 150 },
                    );
                }
            }
        }
    }

    pub fn handleMovement(self: *Ship, dt: f32) void {
        if (self.health <= 0) {
            return;
        }

        self.thrusting = false;
        self.turbo_thrusting = false;

        if (rl.isKeyDown(.d)) {
            self.rotation += dt * ROTATION_SPEED;
        }

        if (rl.isKeyDown(.a)) {
            self.rotation -= dt * ROTATION_SPEED;
        }

        if (rl.isKeyDown(.w)) {
            // thrust and rotation
            const rads = std.math.degreesToRadians(self.rotation);

            const force_x = std.math.cos(rads) * ACCELERATION * dt;
            const force_y = std.math.sin(rads) * ACCELERATION * dt;

            self.velocity.x += force_x;
            self.velocity.y += force_y;
            self.thrusting = true;
        }

        if (rl.isKeyDown(.w) and rl.isKeyDown(.left_shift)) {
            // thrust and rotation
            const rads = std.math.degreesToRadians(self.rotation);

            const force_x = std.math.cos(rads) * ACCELERATION * 1.4 * dt;
            const force_y = std.math.sin(rads) * ACCELERATION * 1.4 * dt;

            self.velocity.x += force_x;
            self.velocity.y += force_y;
            self.turbo_thrusting = true;
        }

        self.position.x += self.velocity.x * dt;
        self.position.y += self.velocity.y * dt;

        // drag down the velocity
        self.velocity.x *= DRAG;
        self.velocity.y *= DRAG;

        wrapObject(&self.position);
    }

    pub fn handleShooting(
        self: *Ship,
        allocator: std.mem.Allocator,
        bullets: *[MAX_BULLETS]Bullet,
        asteroids: *[MAX_ASTEROIDS]Asteroid,
        particles: *[MAX_PARTICLES]Particle,
        text_list: *std.ArrayList(text_mod.Text),
        camera: *Camera,
        dt: f32,
    ) !void {
        if (self.health <= 0) {
            return;
        }

        if (rl.isKeyPressed(.space) and rl.isKeyUp(.left_shift)) {
            // NOTE: shooting normal bullets
            blk: for (0..MAX_BULLETS) |i| {
                var bullet = &bullets[i];

                if (!bullet.active) {
                    // wake bullet up
                    bullet.active = true;
                    bullet.life_time = BULLET_LIFE;
                    bullet.type = .normal;

                    bullet.position = self.position;
                    bullet.rotation = self.rotation;

                    const rads = std.math.degreesToRadians(self.rotation);
                    bullet.velocity.x = (std.math.cos(rads) * BULLET_SPEED) + self.velocity.x;
                    bullet.velocity.y = (std.math.sin(rads) * BULLET_SPEED) + self.velocity.y;

                    break :blk;
                }
            }
        }

        if (rl.isKeyPressed(.space) and rl.isKeyDown(.left_shift)) {
            // NOTE: shooting missiles
            blk: for (0..MAX_BULLETS) |i| {
                var bullet = &bullets[i];

                if (!bullet.active and self.missiles_ammo > 0 and self.reloading_time == 0.0) {
                    // wake bullet up
                    bullet.active = true;
                    bullet.life_time = BULLET_LIFE;
                    bullet.type = .missile;

                    bullet.position = self.position;
                    bullet.rotation = self.rotation;

                    const rads = std.math.degreesToRadians(self.rotation);
                    bullet.velocity.x = (std.math.cos(rads) * MISSILE_SPEED) + self.velocity.x;
                    bullet.velocity.y = (std.math.sin(rads) * MISSILE_SPEED) + self.velocity.y;

                    if (self.missiles_ammo > 0) {
                        self.missiles_ammo -= 1;
                    }

                    if (self.missiles_ammo == 0) {
                        // trigger timeout for resetting missiles ammo
                        self.reloading_time = 3.0;
                    }

                    break :blk;
                }
            }
        }
        if (self.reloading_time > 0.0) {
            self.reloading_time -= dt;
        } else if (self.missiles_ammo == 0) {
            self.reloading_time = 0.0;
            self.missiles_ammo = MAX_MISSLES;
        }

        blk: for (0..MAX_BULLETS) |b_idx| {
            var bullet = &bullets[b_idx];

            if (bullet.active) {
                // NOTE: add curve to trajectory for missiles
                if (bullet.type == .missile) {
                    const time_alive = BULLET_LIFE - bullet.life_time;

                    if (bullet.snapshot_rotation == 0) {
                        bullet.snapshot_rotation = self.rotation;
                    }

                    if (time_alive < PHASE_1_DURATION) {
                        bullet.rotation -= MISSILE_TURN_RATE * dt;

                        const rads = std.math.degreesToRadians(bullet.rotation - 90);
                        bullet.velocity.x *= LAUNCH_DRAG;
                        bullet.velocity.y *= LAUNCH_DRAG;
                        const speed = rl.Vector2.length(bullet.velocity);
                        bullet.velocity.x = std.math.cos(rads) * speed;
                        bullet.velocity.y = std.math.sin(rads) * speed;
                        // bullet.velocity.x = std.math.cos(rads) + speed / BULLET_SPEED;
                        // bullet.velocity.y = std.math.sin(rads) + speed / BULLET_SPEED;
                    } else {
                        const rads = std.math.degreesToRadians(bullet.snapshot_rotation);
                        bullet.velocity.x += std.math.cos(rads) * BOOST_ACCEL * dt;
                        bullet.velocity.y += std.math.sin(rads) * BOOST_ACCEL * dt;

                        const MAX_SPEED = 1200.0;
                        const speed = rl.Vector2.length(bullet.velocity);
                        if (speed > MAX_SPEED) {
                            const scale = MAX_SPEED / speed;
                            bullet.velocity.x *= scale;
                            bullet.velocity.y *= scale;
                        }
                    }
                }

                // Move
                bullet.position.x += bullet.velocity.x * dt;
                bullet.position.y += bullet.velocity.y * dt;

                // bullet out of screen, kill bullet
                if (bullet.position.y > SCREEN_HEIGHT or bullet.position.y < 0 or bullet.position.x > SCREEN_WIDTH or bullet.position.x < 0) {
                    bullet.active = false;
                    bullet.snapshot_rotation = 0;
                }

                // age bullet
                bullet.life_time -= dt;

                // kill if too old
                if (bullet.life_time <= 0) {
                    bullet.active = false;
                    bullet.snapshot_rotation = 0;
                }
            }

            // NOTE: asteroids collision with bullet
            for (0..MAX_ASTEROIDS) |a_idx| {
                var asteroid = &asteroids[a_idx];

                if (!asteroid.active) continue;

                if (rl.checkCollisionCircles(
                    bullet.position,
                    2.0,
                    asteroid.position,
                    asteroid.radius,
                )) {

                    // spawn text
                    try text_list.append(allocator, text_mod.Text{
                        .active = true,
                        .content = "Hell yeah!",
                        .life_time = 1.0,
                        .x = @intFromFloat(asteroid.position.x),
                        .y = @intFromFloat(asteroid.position.y),
                    });

                    if (bullet.type == .normal) {
                        particles_mod.spawn(particles, asteroid.position, .explosion);
                        camera.trigger(5.0, 0.25);
                    } else if (bullet.type == .missile) {
                        particles_mod.spawn(particles, asteroid.position, .big_explosion);
                        camera.trigger(20.0, 0.25);
                    }

                    bullet.active = false;
                    bullet.snapshot_rotation = 0;
                    asteroid.active = false;

                    // if normal bullet, split the asteroid, if not (missile), destroy it
                    if (asteroid.radius > 20.0 and bullet.type == .normal) {
                        const new_size = asteroid.radius / 2.0;

                        for (0..3) |_| {
                            asteroid_mod.spawn(
                                asteroids,
                                .{ .x = asteroid.position.x - 20, .y = asteroid.position.y - 20 },
                                new_size,
                            );
                        }

                        particles_mod.spawn(particles, asteroid.position, .debris);
                    }

                    break :blk;
                }
            }
        }

        for (bullets) |b| {
            if (b.active) {
                if (b.type == .normal) {
                    rl.drawCircleV(b.position, 2.0, .ray_white);
                } else if (b.type == .missile) {
                    rl.drawCircleV(b.position, 4.0, .yellow);
                }
            }
        }
    }

    pub fn handleAsteroidCollision(self: *Ship, asteroids: *[MAX_ASTEROIDS]Asteroid, particles: *[MAX_PARTICLES]Particle, camera: *Camera) void {
        for (asteroids) |*a| {
            if (!a.active) continue;

            if (rl.checkCollisionCircles(self.position, self.radius, a.position, a.radius)) {
                // NOTE: Ship hit asteroid

                if (self.health > 0) {
                    self.health -= 20;
                }
                self.hit_timer = 1.0;

                const delta = rl.Vector2.subtract(self.position, a.position);
                const distance = rl.Vector2.length(delta);
                // normalize vector (we need direction, not magnitude)
                const normal = rl.Vector2.normalize(delta);

                const collision_point = rl.Vector2.subtract(
                    self.position,
                    rl.Vector2.scale(normal, self.radius),
                );
                particles_mod.spawn(particles, collision_point, .sparks);
                camera.trigger(15.0, 0.25);

                const overlap = (self.radius + a.radius) - distance;

                // push apart handling
                // create a vector of half the overlap length in the direction of collision
                const push_vector = rl.Vector2.scale(normal, overlap * 0.5);
                self.position = rl.Vector2.add(self.position, push_vector);
                a.position = rl.Vector2.subtract(a.position, push_vector);

                // bounce handling
                // how fast along the collision axis
                const relative_vel = rl.Vector2.subtract(self.velocity, a.velocity);

                const vel_normal = rl.Vector2.dotProduct(relative_vel, normal);

                if (vel_normal > 0) continue;

                // calculate impulse
                const restitution = 0.5;
                var scale_factor = -(1.0 + restitution) * vel_normal;
                scale_factor /= (1.0 / (self.radius * self.radius) + 1.0 / (a.radius * a.radius));

                // apply impulse
                const impulse = rl.Vector2.scale(normal, scale_factor);
                self.velocity = rl.Vector2.add(self.velocity, rl.Vector2.scale(impulse, 1.0 / (self.radius * self.radius)));
                a.velocity = rl.Vector2.subtract(a.velocity, rl.Vector2.scale(impulse, 1.0 / (a.radius * a.radius)));
            }
        }
    }
};
