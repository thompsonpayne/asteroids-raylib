const std = @import("std");
const rl = @import("raylib");
const utils = @import("utils.zig");
const bullet_mod = @import("bullet.zig");
const asteroid_mod = @import("asteroid.zig");

const Bullet = bullet_mod.Bullet;
const Asteroid = asteroid_mod.Asteroid;

const ROTATION_SPEED = utils.ROTATION_SPEED;
const ACCELERATION = utils.ACCELERATION;
const SCREEN_HEIGHT = utils.SCREEN_HEIGHT;
const SCREEN_WIDTH = utils.SCREEN_WIDTH;
const DRAG = utils.DRAG;
const MAX_BULLETS = utils.MAX_BULLETS;
const BULLET_LIFE = utils.BULLET_LIFE;
const BULLET_SPEED = utils.BULLET_SPEED;

const MAX_ASTEROIDS = utils.MAX_ASTEROIDS;
const wrapObject = utils.wrapObject;

pub const Ship = struct {
    position: rl.Vector2,
    velocity: rl.Vector2, // speed x, speed y
    rotation: f32, // direction facing (degree)

    pub fn draw(self: *Ship) void {
        const rotation = self.rotation;
        const position = self.position;

        const length: f32 = 25.0; // nose length
        const width: f32 = 12.0; // wings width

        // The three points of our triangle relative to (0,0)
        // We assume 0 degrees is facing RIGHT (Positive X)
        const p1 = rl.Vector2{ .x = length, .y = 0 }; //nose
        const p2 = rl.Vector2{ .x = -length, .y = -width }; //back left
        const p3 = rl.Vector2{ .x = -length, .y = width }; //back left

        const rads = rotation * (std.math.pi / 180.0);
        const s = std.math.sin(rads);
        const c = std.math.cos(rads);

        // Rotate and Move each point
        // Formula:
        // new_x = (x * cos) - (y * sin) + ship_x
        // new_y = (x * sin) + (y * cos) + ship_y

        const nose = rl.Vector2{
            .x = (p1.x * c) - (p1.y * s) + position.x,
            .y = (p1.x * s) + (p1.y * c) + position.y,
        };

        const left_wing = rl.Vector2{
            .x = (p2.x * c) - (p2.y * s) + position.x,
            .y = (p2.x * s) + (p2.y * c) + position.y,
        };

        const right_wing = rl.Vector2{
            .x = (p3.x * c) - (p3.y * s) + position.x,
            .y = (p3.x * s) + (p3.y * c) + position.y,
        };

        // 4. Draw the lines connecting them
        rl.drawLineV(nose, left_wing, rl.Color.white); // Nose -> Left
        rl.drawLineV(left_wing, right_wing, rl.Color.white); // Left -> Right (The back)
        rl.drawLineV(right_wing, nose, rl.Color.white); // Right -> Nose
    }

    pub fn handleMovement(ship: *Ship, dt: f32) void {
        if (rl.isKeyDown(.right)) {
            ship.rotation += dt * ROTATION_SPEED;
        }

        if (rl.isKeyDown(.left)) {
            ship.rotation -= dt * ROTATION_SPEED;
        }

        if (rl.isKeyDown(.up)) {
            // thrust and rotation
            const rads = ship.rotation * (std.math.pi / 180.0);

            const force_x = std.math.cos(rads) * ACCELERATION * dt;
            const force_y = std.math.sin(rads) * ACCELERATION * dt;

            ship.velocity.x += force_x;
            ship.velocity.y += force_y;
        }

        ship.position.x += ship.velocity.x * dt;
        ship.position.y += ship.velocity.y * dt;

        // drag down the velocity
        ship.velocity.x *= DRAG;
        ship.velocity.y *= DRAG;

        wrapObject(&ship.position);
    }

    pub fn handleShooting(ship: *Ship, bullets: *[MAX_BULLETS]Bullet, asteroids: *[MAX_ASTEROIDS]Asteroid, dt: f32) void {
        if (rl.isKeyPressed(.space)) {
            // NOTE: shooting
            blk: for (0..MAX_BULLETS) |i| {
                var bullet = &bullets[i];

                if (!bullet.active) {
                    // wake bullet up
                    bullet.active = true;
                    bullet.life_time = BULLET_LIFE;

                    bullet.position = ship.position;

                    const rads = ship.rotation * (std.math.pi / 180.0);
                    bullet.velocity.x = (std.math.cos(rads) * BULLET_SPEED) + ship.velocity.x;
                    bullet.velocity.y = (std.math.sin(rads) * BULLET_SPEED) + ship.velocity.y;
                    break :blk;
                }
            }
        }

        // NOTE: bulelt vs asteroid collision
        blk: for (0..MAX_BULLETS) |b_idx| {
            var bullet = &bullets[b_idx];

            if (bullet.active) {
                // Move
                bullet.position.x += bullet.velocity.x * dt;
                bullet.position.y += bullet.velocity.y * dt;

                // bullet out of screen, kill bullet
                if (bullet.position.y > SCREEN_HEIGHT or bullet.position.y < 0 or bullet.position.x > SCREEN_WIDTH or bullet.position.x < 0) {
                    bullet.active = false;
                }

                // age bullet
                bullet.life_time -= dt;

                // kill if too old
                if (bullet.life_time <= 0) {
                    bullet.active = false;
                }
            }

            for (0..MAX_ASTEROIDS) |a_idx| {
                var asteroid = &asteroids[a_idx];

                if (!asteroid.active) continue;

                if (rl.checkCollisionCircles(bullet.position, 2.0, asteroid.position, asteroid.radius)) {
                    // bullet hit asteroid

                    bullet.active = false;
                    asteroid.active = false;

                    if (asteroid.radius > 20.0) {
                        const new_size = asteroid.radius / 2.0;

                        asteroid_mod.spawn(
                            asteroids,
                            .{ .x = asteroid.position.x - 20, .y = asteroid.position.y - 20 },
                            new_size,
                        );

                        asteroid_mod.spawn(
                            asteroids,
                            .{ .x = asteroid.position.x + 20, .y = asteroid.position.y + 20 },
                            new_size,
                        );
                    }

                    break :blk;
                }
            }
        }

        for (bullets) |b| {
            if (b.active) {
                rl.drawCircleV(b.position, 2.0, .ray_white);
            }
        }
    }

    pub fn handleAsteroidCollision(self: *Ship, asteroids: *[MAX_ASTEROIDS]Asteroid) void {
        for (asteroids) |a| {
            // TODO: add ship radius config
            if (rl.checkCollisionCircles(self.position, 15.0, a.position, a.radius)) {
                self.position.x = 400;
                self.position.y = 300;

                self.velocity.x = 0;
                self.velocity.y = 0;
            }
        }
    }
};
