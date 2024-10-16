//SPDX-FileCopyrightText: 2022 Ryuichi Ueda ryuichiueda@gmail.com
//SPDX-License-Identifier: BSD-3-Clause

use crate::{error_message, ShellCore, Feeder, Script};
use super::{Command, Redirect};
use crate::elements::command;

#[derive(Debug, Clone)]
pub struct UntilCommand {
    pub text: String,
    pub until_script: Option<Script>,
    pub do_script: Option<Script>,
    pub redirects: Vec<Redirect>,
    force_fork: bool,
}

impl Command for UntilCommand {
    fn run(&mut self, core: &mut ShellCore, _: bool) {
        core.loop_level += 1;
        loop {
            core.suspend_e_option = true;
            self.until_script.as_mut()
                .expect(&error_message::internal_str("no script"))
                .exec(core);

            core.suspend_e_option = false;

            self.do_script.as_mut()
                .expect(&error_message::internal_str("no script"))
                .exec(core);

            if core.break_counter > 0 {
                core.break_counter -= 1;
                break;
            }
            if core.data.get_param("?") != "0" {
                core.data.set_param("?", "0");
                break;
            }
        }
        core.loop_level -= 1;
        if core.loop_level == 0 {
            core.break_counter = 0;
        }
    }

    fn get_text(&self) -> String { self.text.clone() }
    fn get_redirects(&mut self) -> &mut Vec<Redirect> { &mut self.redirects }
    fn set_force_fork(&mut self) { self.force_fork = true; }
    fn boxed_clone(&self) -> Box<dyn Command> {Box::new(self.clone())}
    fn force_fork(&self) -> bool { self.force_fork }
}

impl UntilCommand {
    fn new() -> UntilCommand {
        UntilCommand {
            text: String::new(),
            until_script: None,
            do_script: None,
            redirects: vec![],
            force_fork: false,
        }
    }

    pub fn parse(feeder: &mut Feeder, core: &mut ShellCore) -> Option<UntilCommand> {
        let mut ans = Self::new();
        if command::eat_inner_script(feeder, core, "until", vec!["do"], &mut ans.until_script, false)
        && command::eat_inner_script(feeder, core, "do", vec!["done"],  &mut ans.do_script, false) {
            ans.text.push_str("until");
            ans.text.push_str(&ans.until_script.as_mut().unwrap().get_text());
            ans.text.push_str("do");
            ans.text.push_str(&ans.do_script.as_mut().unwrap().get_text());
            ans.text.push_str(&feeder.consume(4)); //done

            command::eat_redirects(feeder, core, &mut ans.redirects, &mut ans.text);
            Some(ans)
        }else{
            None
        }
    }
}