const std = @import("std");
const win = std.os.windows;
const WINAPI = win.WINAPI;
const main = @import("main.zig");
const MSG = main.MSG;

const HACCEL = *opaque {};
const ACCEL = extern struct {
    fVirt: u8,
    // bPadding: u8 = 0,
    key: u16,
    cmd: u16,
};

pub extern "user32" fn CreateAcceleratorTableA([*]ACCEL, i32) callconv(WINAPI) ?HACCEL;
pub extern "user32" fn TranslateAcceleratorA(?*const anyopaque, HACCEL, *MSG) callconv(WINAPI) i32;

pub const default = [_]ACCEL{
    .{
        .fVirt = 0x09,
        .key = '0',
        .cmd = '0',
    },
    .{
        .fVirt = 0x09,
        .key = 0xBB,
        .cmd = '+',
    },
    .{
        .fVirt = 0x09,
        .key = 0xBD,
        .cmd = '-',
    },
    .{
        .fVirt = 0x0D,
        .key = 'T',
        .cmd = 't',
    },
    .{
        .fVirt = 0x09,
        .key = 'L',
        .cmd = 'L',
    },
    .{
        .fVirt = 0x09,
        .key = 'N',
        .cmd = 'N',
    },
    .{
        .fVirt = 0x09,
        .key = 'O',
        .cmd = 'O',
    },
    .{
        .fVirt = 0x09,
        .key = 'R',
        .cmd = 'R',
    },
    .{
        .fVirt = 0x09,
        .key = 'S',
        .cmd = 'S',
    },
    .{
        .fVirt = 0x09,
        .key = 'T',
        .cmd = 'T',
    },
    .{
        .fVirt = 0x09,
        .key = 'K',
        .cmd = 'K',
    },
    .{
        .fVirt = 0x09,
        .key = 'W',
        .cmd = 'W',
    },
    .{
        .fVirt = 0x01,
        .key = 0x7A,
        .cmd = 0xF11,
    },
};
