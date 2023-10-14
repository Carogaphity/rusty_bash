//SPDX-FileCopyrightText: 2022 Ryuichi Ueda ryuichiueda@gmail.com
//SPDX-License-Identifier: BSD-3-Clause

pub mod pipe;
pub mod redirect;

use std::os::unix::prelude::RawFd;
use nix::{fcntl, unistd};
use nix::errno::Errno;

fn close(fd: RawFd, err_str: &str){
    if fd >= 0 {
        unistd::close(fd).expect(err_str);
    }
}

fn replace(from: RawFd, to: RawFd) -> bool {
    if from < 0 || to < 0 {
        return false;
    }

    match unistd::dup2(from, to) {
        Ok(_) => {
            close(from, &format!("sush(fatal): {}: cannot be closed", from));
            true
        },
        Err(Errno::EBADF) => {
            eprintln!("sush: {}: Bad file descriptor", to);
            false
        },
        Err(_) => {
            eprintln!("sush: dup2 Unknown error");
            false
        },
    }
}

fn share(from: RawFd, to: RawFd) {
    if from < 0 || to < 0 {
        return;
    }
    unistd::dup2(from, to).expect("Can't copy file descriptors");
}

fn backup(from: RawFd) -> RawFd {
    fcntl::fcntl(from, fcntl::F_DUPFD_CLOEXEC(10))
           .expect("Can't allocate fd for backup")
}
