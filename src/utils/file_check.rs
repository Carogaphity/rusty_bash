//SPDX-FileCopyrightText: 2024 Ryuichi Ueda ryuichiueda@gmail.com
//SPDX-License-Identifier: BSD-3-Clause

use std::fs;
use std::fs::File;
use std::os::unix::fs::{FileTypeExt, PermissionsExt};
use std::path::Path;

pub fn exists(name: &str) -> bool {
    fs::metadata(name).is_ok()
}

pub fn is_regular_file(name: &str) -> bool {
    Path::new(name).is_file()
}

pub fn is_dir(name: &str) -> bool {
    Path::new(name).is_dir()
}

pub fn type_check(name: &str, tp: &str) -> bool {
    let meta = match fs::metadata(name) {
        Ok(m) => m,
        _     => return false,
    };

    match tp {
        "-b" => return meta.file_type().is_block_device(),
        "-c" => return meta.file_type().is_char_device(),
        "-p" => return meta.file_type().is_fifo(),
        _ => {},
    }

    let special_mode = (meta.permissions().mode()/0o1000)%8;
    match tp {
        "-g" => (special_mode%4)>>1 == 1,
        "-k" => special_mode%2 == 1,
        _ => false,
    }
}

pub fn is_symlink(name: &str) -> bool {
    Path::new(name).is_symlink()
}

pub fn is_readable(name: &str) -> bool {
    File::open(&name).is_ok()
}
