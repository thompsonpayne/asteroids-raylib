const std = @import("std");

const rl = @import("raylib");

const asteroid_mod = @import("asteroid.zig");
const Asteroid = asteroid_mod.Asteroid;
const bullet_mod = @import("bullet.zig");
const Bullet = bullet_mod.Bullet;
const camera_mod = @import("camera.zig");
const Camera = camera_mod.Camera;
const game_state_mod = @import("game_state.zig");
const GameState = game_state_mod.GameState;
const TitleScreen = game_state_mod.TitleScreen;
const particles_mod = @import("particles.zig");
const Particle = particles_mod.Particle;
const ship_mod = @import("ship.zig");
const Ship = ship_mod.Ship;
const text_mod = @import("text.zig");
const utils = @import("utils.zig");
const MAX_BULLETS = utils.MAX_BULLETS;
const BULLET_SPEED = utils.BULLET_SPEED;
const SCREEN_WIDTH = utils.SCREEN_WIDTH;
const SCREEN_HEIGHT = utils.SCREEN_HEIGHT;
const MAX_ASTEROIDS = utils.MAX_ASTEROIDS;
const MAX_PARTICLES = utils.MAX_PARTICLES;
const ACCELERATION = utils.ACCELERATION;

pub fn main() !void {
    var bullets: [MAX_BULLETS]Bullet = bullet_mod.init();
    var asteroids: [MAX_ASTEROIDS]Asteroid = asteroid_mod.init();
    var particles: [MAX_PARTICLES]Particle = particles_mod.init();
    var game_state: GameState = .title;
    var title_screen = TitleScreen.init();
    var camera = Camera.init();

    var gpa = std.heap.DebugAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            std.debug.print("Leaking!!", .{});
        }
    }
    const allocator = gpa.allocator();

    var text_list = try std.ArrayList(text_mod.Text).initCapacity(allocator, 512);
    defer text_list.deinit(allocator);

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "DAsteroids");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const ship_texture = try rl.loadTexture("src/assets/ship.png");
    var ship: Ship = .init(.{ .x = SCREEN_WIDTH / 2.0, .y = SCREEN_HEIGHT / 2.0 }, ship_texture);
    defer ship.deinit();

    var print_buf: [1024]u8 = undefined;

    // NOTE: Game loop
    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        rl.beginDrawing();
        rl.clearBackground(.black);

        switch (game_state) {
            .title => {
                const gs = title_screen.handleNavigate();
                if (gs) |g| {
                    game_state = g;
                    try title_screen.draw();
                } else {
                    break;
                }
            },
            .game_over => {
                rl.drawText("Haha loser!", 600, 450, 20.0, .red);
            },
            .playing => {
                camera.update(dt);

                {
                    camera.begin();

                    ship.handleMovement(dt);
                    try ship.draw(&particles);

                    // draw asteroids
                    asteroid_mod.draw(&asteroids, dt);
                    asteroid_mod.handleCollisionOnEachOther(&asteroids, &particles);

                    try ship.handleShooting(
                        allocator,
                        &bullets,
                        &asteroids,
                        &particles,
                        &text_list,
                        &camera,
                        dt,
                    );
                    ship.handleAsteroidCollision(&asteroids, &particles, &camera);

                    particles_mod.update(&particles, dt);

                    var i: usize = 0;
                    while (i < text_list.items.len) {
                        var item = &text_list.items[i];
                        item.age(dt);
                        item.draw();
                        if (item.isExpired()) {
                            _ = text_list.swapRemove(i);
                        } else {
                            i += 1;
                        }
                    }

                    particles_mod.draw(&particles);

                    camera.end();
                }

                // debug - UI elements (outside camera)
                const speed = rl.Vector2.length(ship.velocity);
                rl.drawText(
                    rl.textFormat("Speed: %.2f", .{speed}),
                    SCREEN_WIDTH - 200.0,
                    10,
                    20,
                    .white,
                );
                rl.drawFPS(10, 10);

                const text_info = try std.fmt.bufPrintZ(
                    &print_buf,
                    "Text items: {d}\n",
                    .{text_list.items.len},
                );
                rl.drawText(text_info, 10, SCREEN_HEIGHT - 20, 14.0, .light_gray);
            },
        }

        rl.endDrawing();
    }
}
