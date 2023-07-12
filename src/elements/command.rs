//SPDX-FileCopyrightText: 2022 Ryuichi Ueda ryuichiueda@gmail.com
//SPDX-License-Identifier: BSD-3-Clause

pub mod simple;
pub mod paren;
pub mod brace;

use crate::{ShellCore, Feeder, Script};
use self::simple::SimpleCommand;
use self::paren::ParenCommand;
use self::brace::BraceCommand;
use std::fmt;
use std::fmt::Debug;
use super::Pipe;

impl Debug for dyn Command {
    fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
        fmt.debug_struct("COMMAND").finish()
    }
}

pub trait Command {
    fn exec(&mut self, core: &mut ShellCore, pipe: &mut Pipe);
    fn get_text(&self) -> String;
}

pub fn eat_inner_script(feeder: &mut Feeder, core: &mut ShellCore, left: &str, ans: &mut Option<Script>) -> bool {
   if ! feeder.starts_with(left) {
       return false;
    }
    core.nest.push(left.to_string());
    feeder.consume(left.len());
    if let Some(s) = Script::parse(feeder, core) {
        core.nest.pop();
        *ans = Some(s);
        true
    }else{
        core.nest.pop();
        false
    }
}

pub fn parse(feeder: &mut Feeder, core: &mut ShellCore) -> Option<Box<dyn Command>> {
    if let Some(a) = SimpleCommand::parse(feeder, core){ Some(Box::new(a)) }
    else if let Some(a) = ParenCommand::parse(feeder, core) { Some(Box::new(a)) }
    else if let Some(a) = BraceCommand::parse(feeder, core) { Some(Box::new(a)) }
    else{ None }
}
