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
const GAMEOVER_TIMEOUT = 2.0;

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
    var gameover_timeout: f32 = GAMEOVER_TIMEOUT;

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

                    if (g == .playing) {
                        ship = .init(.{ .x = SCREEN_WIDTH / 2.0, .y = SCREEN_HEIGHT / 2.0 }, ship_texture);
                        bullets = bullet_mod.init();
                        asteroids = asteroid_mod.init();
                        particles = particles_mod.init();
                    }

                    try title_screen.draw();
                } else {
                    // quit game
                    break;
                }
            },
            .game_over => {
                if (gameover_timeout > 0) {
                    rl.drawText("Haha loser!", 600, 450, 20.0, .red);
                    gameover_timeout -= dt;
                } else {
                    gameover_timeout = GAMEOVER_TIMEOUT;
                    game_state = .title;
                }
            },
            .player_win => {
                const message = "Congrats. You've won! Press Enter to conitnue!";

                const title_dim = rl.measureTextEx(
                    try rl.getFontDefault(),
                    message,
                    40.0,
                    2.0,
                );

                rl.drawTextEx(
                    try rl.getFontDefault(),
                    message,
                    .{ .x = (SCREEN_WIDTH - title_dim.x) / 2.0, .y = (SCREEN_HEIGHT - title_dim.y) / 2.0 },
                    40.0,
                    2.0,
                    .ray_white,
                );

                if (rl.isKeyPressed(.kp_enter) or rl.isKeyPressed(.enter)) {
                    game_state = .title;
                }
            },
            .playing => {
                camera.update(dt);

                // NOTE: Camera wrap
                camera.begin();
                {
                    ship.handleMovement(dt);
                    ship.draw(&particles) catch |err| {
                        if (err == error.Die) {
                            game_state = .game_over;
                        } else {
                            std.debug.print("error drawing ship: {}\n", .{err});
                        }
                    };

                    // draw asteroids
                    asteroid_mod.draw(&asteroids, dt) catch |err| {
                        if (err == error.PlayerWin) {
                            // game_state = .player_win;
                            const message = "Congrats. You've won! Press Enter to conitnue!";

                            const title_dim = rl.measureTextEx(
                                try rl.getFontDefault(),
                                message,
                                40.0,
                                2.0,
                            );

                            rl.drawTextEx(
                                try rl.getFontDefault(),
                                message,
                                .{ .x = (SCREEN_WIDTH - title_dim.x) / 2.0, .y = (SCREEN_HEIGHT - title_dim.y) / 2.0 },
                                40.0,
                                2.0,
                                .green,
                            );

                            if (rl.isKeyPressed(.kp_enter) or rl.isKeyPressed(.enter)) {
                                game_state = .title;
                            }
                        }
                    };

                    try asteroid_mod.handleCollisionWithExternal(
                        allocator,
                        &asteroids,
                        &particles,
                        &text_list,
                    );

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
                }
                camera.end();

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

                // NOTE: Health display
                {
                    const health_text = try std.fmt.bufPrintZ(
                        &print_buf,
                        "Health: {d}%\n",
                        .{ship.health},
                    );
                    const color: rl.Color = switch (ship.health) {
                        0...20 => .red,
                        21...40 => .orange,
                        41...60 => .yellow,
                        61...80 => .green,
                        else => .dark_green,
                    };
                    rl.drawText(health_text, 10, SCREEN_HEIGHT - 20, 20.0, color);
                }
            },
        }

        rl.endDrawing();
    }
}
