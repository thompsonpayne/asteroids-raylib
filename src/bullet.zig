const rl = @import("raylib");

const utils = @import("utils.zig");
const MAX_BULLETS = utils.MAX_BULLETS;

const BulletType = enum {
    normal,
    missile,
};

pub const Bullet = struct {
    active: bool,
    position: rl.Vector2,
    velocity: rl.Vector2,
    type: BulletType,
    rotation: f32,
    reloading: bool,
    life_time: f32, // seconds to live
};

pub fn init() [MAX_BULLETS]Bullet {
    var bullets: [MAX_BULLETS]Bullet = undefined;

    for (0..MAX_BULLETS) |i| {
        bullets[i] = Bullet{
            .reloading = false,
            .rotation = 90.0,
            .active = false,
            .position = .{ .x = 0, .y = 0 },
            .velocity = .{ .x = 0, .y = 0 },
            .life_time = 0,
            .type = .normal,
        };
    }

    return bullets;
}
