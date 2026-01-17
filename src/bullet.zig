const rl = @import("raylib");
const utils = @import("utils.zig");
const MAX_BULLETS = utils.MAX_BULLETS;

pub const Bullet = struct {
    active: bool,
    position: rl.Vector2,
    velocity: rl.Vector2,
    life_time: f32, // seconds to live

};

pub fn init() [MAX_BULLETS]Bullet {
    var bullets: [MAX_BULLETS]Bullet = undefined;

    for (0..MAX_BULLETS) |i| {
        bullets[i] = Bullet{
            .active = false,
            .position = .{ .x = 0, .y = 0 },
            .velocity = .{ .x = 0, .y = 0 },
            .life_time = 0,
        };
    }

    return bullets;
}
