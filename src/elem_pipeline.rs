//SPDX-FileCopyrightText: 2022 Ryuichi Ueda ryuichiueda@gmail.com
//SPDX-License-Identifier: BSD-3-Clause

use crate::{ShellCore, Feeder};
use crate::abst_script_elem::ScriptElem;
use crate::Command;
use crate::elem_arg_delimiter::ArgDelimiter;
use nix::unistd::{Pid, pipe};
use crate::scanner::scanner_end_paren;

/* command: delim arg delim arg delim arg ... eoc */
pub struct Pipeline {
    pub commands: Vec<Box<dyn ScriptElem>>,
    //pub commands: Vec<Box<Command>>,
    pub text: String,
    pub expansion: bool,
    pub expansion_str: String, 
}

impl ScriptElem for Pipeline {

    fn exec(&mut self, conf: &mut ShellCore) -> Option<Pid>{
        if self.expansion {
            self.set_command_expansion_pipe();
        }

        let len = self.commands.len();
        let mut prevfd = -1;
        for (i, c) in self.commands.iter_mut().enumerate() {
            let mut p = (-1, -1);
            if i != len-1 {
                p = pipe().expect("Pipe cannot open");
            };
            c.set_pipe(p.0, p.1, prevfd);

            let _ = c.exec(conf);
            prevfd = c.set_parent_io();
        }

        for c in &self.commands {
            if let Some(p) = c.get_pid() {
                self.expansion_str += &self.wait(&c, p, conf);
            }
        }
        None
    }
}

impl Pipeline {
    pub fn new() -> Pipeline{
        Pipeline {
            commands: vec!(),
            expansion: false,
            expansion_str: "".to_string(),
            text: "".to_string(),
        }
    }

    fn set_command_expansion_pipe(&mut self){
        let x = self.commands.len();
        let c = &mut self.commands[x-1];
        let p = pipe().expect("Pipe cannot open");
        c.set_expansion(p.0, p.1);
    }

    pub fn parse(text: &mut Feeder, conf: &mut ShellCore) -> Option<Pipeline> {
        let mut ans = Pipeline::new();

        loop {
            if let Some(c) = Command::parse(text, conf) {
                let mut eoc = "".to_string();
                if let Some(e) = c.args.last() {
                    eoc = e.text();
                }

                ans.text += &c.text.clone();
                ans.commands.push(Box::new(c));

                if eoc != "|" {
                    break;
                }

                if let Some(d) = ArgDelimiter::parse(text) {
                    ans.text += &d.text.clone();
                }

                let subshell_end = scanner_end_paren(text, 0);
                if subshell_end == 1 {
                    break;
                }

            }else{
                break;
            }
        }

        if ans.commands.len() > 0 {
            Some(ans)
        }else{
            None
        }
    }
}
